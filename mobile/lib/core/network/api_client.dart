import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/bloc/auth_event.dart';
import '../config/app_config.dart';
import '../di/injection.dart';

/// Configured Dio HTTP client with interceptors for auth, context, and logging.
class ApiClient {
  late final Dio dio;
  final AppConfig config;

  // Mutable context headers — updated by the app at runtime.
  String _countryCode;
  String _language;
  String? _authToken;

  ApiClient({required this.config})
    : _countryCode = config.defaultCountryCode,
      _language = _normalizeLanguage(config.defaultLanguage) {
    dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Order matters: auth first, then context, then logging last.
    dio.interceptors.addAll([
      _authInterceptor(),
      _contextInterceptor(),
      if (config.enableLogging) _loggingInterceptor(),
    ]);
  }

  // ── Public setters ─────────────────────────────────────────────────────────

  void setCountryCode(String code) => _countryCode = code;
  void setLanguage(String lang) => _language = _normalizeLanguage(lang);
  void setAuthToken(String? token) => _authToken = token;
  void setUserId(String? userId) {}

  static String _normalizeLanguage(String lang) {
    if (lang == 'ms') return 'ms-MY';
    if (lang == 'en') return 'en-US';
    if (lang == 'th') return 'th-TH';
    return lang;
  }

  // ── Interceptors ───────────────────────────────────────────────────────────

  /// Injects the Firebase ID token into the Authorization header,
  /// handles auto-refresh on 401s, and handles session timeout.
  Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        handler.next(options);
      },
      onError: (DioException error, handler) async {
        final response = error.response;
        if (response != null && response.statusCode == 401) {
          final responseData = response.data;
          final isInvalidTokenError =
              responseData is Map &&
              (responseData['error'] == 'invalid bearer token' ||
                  responseData['message'] == 'invalid bearer token');

          if (isInvalidTokenError) {
            debugPrint(
              '[API] Captured 401 invalid bearer token error. Attempting auto token refresh...',
            );

            try {
              final authService = sl<AuthService>();
              // Try to refresh token
              final newToken = await authService.getIdToken(forceRefresh: true);
              if (newToken != null) {
                // Update client token
                setAuthToken(newToken);

                // Clone request options and update headers
                final options = error.requestOptions;
                options.headers['Authorization'] = 'Bearer $newToken';

                // Retry request
                final cloneReq = await dio.request(
                  options.path,
                  options: Options(
                    method: options.method,
                    headers: options.headers,
                    responseType: options.responseType,
                    contentType: options.contentType,
                  ),
                  data: options.data,
                  queryParameters: options.queryParameters,
                );
                return handler.resolve(cloneReq);
              }
            } catch (refreshError) {
              debugPrint('[API] Automatic token refresh failed: $refreshError');
            }

            // Session Timeout!
            // 1. Sign out on the service
            try {
              await sl<AuthService>().signOut();
            } catch (_) {}

            // 2. Clear token in client
            setAuthToken(null);

            // 3. Emit Session Expired state to AuthBloc so that it handles logging out and triggering UI
            sl<AuthBloc>().add(const AuthSessionExpired());
          }
        }
        handler.next(error);
      },
    );
  }

  /// Injects the regional context headers required by the Go backend.
  Interceptor _contextInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['X-Country-Code'] = _countryCode;
        options.headers['X-Language'] = _language;
        options.headers['Accept-Language'] = _language;
        handler.next(options);
      },
    );
  }

  /// Pretty-prints requests and responses in debug mode.
  Interceptor _loggingInterceptor() {
    return LogInterceptor(
      requestHeader: true,
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      error: true,
      logPrint: (obj) => debugPrint('[API] $obj'),
    );
  }
}
