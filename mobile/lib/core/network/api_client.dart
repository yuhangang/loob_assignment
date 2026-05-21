import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:loob_app/core/auth/auth_service.dart';
import 'package:loob_app/core/auth/bloc/auth_bloc.dart';
import 'package:loob_app/core/auth/bloc/auth_event.dart';
import 'package:loob_app/core/config/app_config.dart';
import 'package:loob_app/core/di/injection.dart';

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
      onRequest: (options, handler) async {
        if (_authToken != null) {
          if (_isTokenExpired(_authToken!)) {
            debugPrint(
              '[API] Token expired or close to expiry. Renewing before request...',
            );
            try {
              final authService = sl<AuthService>();
              final newToken = await authService.getIdToken(forceRefresh: true);
              if (newToken != null) {
                setAuthToken(newToken);
              }
            } catch (e) {
              debugPrint(
                '[API] Automatic pre-request token renewal failed: $e',
              );
            }
          }

          if (_authToken != null) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
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
              '[API] Captured 401 invalid bearer token error. Triggering session timeout...',
            );

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

  /// Checks if a JWT token is expired or close to expiry (with a 10-second buffer).
  bool _isTokenExpired(String token) {
    try {
      final segments = token.split('.');
      if (segments.length != 3) return true;

      // Base64Url decode payload
      final normalized = base64Url.normalize(segments[1]);
      final payloadBytes = base64Url.decode(normalized);
      final payloadString = utf8.decode(payloadBytes);
      final payload = json.decode(payloadString) as Map<String, dynamic>;

      final exp = payload['exp'] as int?;
      if (exp != null) {
        final expiryTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        // Expired if current time + 10s buffer exceeds expiryTime
        return DateTime.now()
            .add(const Duration(seconds: 10))
            .isAfter(expiryTime);
      }
    } catch (e) {
      debugPrint('[API] Error parsing JWT expiration: $e');
      return true; // Treat as expired if parsing fails
    }
    return true;
  }

  /// Injects the regional context headers required by the Go backend.
  Interceptor _contextInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers.putIfAbsent('X-Country-Code', () => _countryCode);
        options.headers.putIfAbsent('X-Language', () => _language);
        options.headers.putIfAbsent('Accept-Language', () => _language);
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
