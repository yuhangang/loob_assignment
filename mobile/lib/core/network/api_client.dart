import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// Configured Dio HTTP client with interceptors for auth, context, and logging.
class ApiClient {
  late final Dio dio;
  final AppConfig config;

  // Mutable context headers — updated by the app at runtime.
  String _countryCode;
  String _language;
  String? _authToken;
  String? _userId;

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
      if (kDebugMode) _loggingInterceptor(),
    ]);
  }

  // ── Public setters ─────────────────────────────────────────────────────────

  void setCountryCode(String code) => _countryCode = code;
  void setLanguage(String lang) => _language = _normalizeLanguage(lang);
  void setAuthToken(String? token) => _authToken = token;
  void setUserId(String? userId) => _userId = userId;

  static String _normalizeLanguage(String lang) {
    if (lang == 'ms') return 'ms-MY';
    if (lang == 'en') return 'en-US';
    if (lang == 'th') return 'th-TH';
    return lang;
  }

  // ── Interceptors ───────────────────────────────────────────────────────────

  /// Injects Firebase JWT (or mock) token into the Authorization header.
  Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        handler.next(options);
      },
    );
  }

  /// Injects the regional context headers required by the Go backend.
  Interceptor _contextInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['X-Country-Code'] = _countryCode;
        if (_userId != null && _userId!.isNotEmpty) {
          options.headers['X-User-Id'] = _userId;
        }
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
