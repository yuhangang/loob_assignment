import 'package:flutter/foundation.dart';

/// App deployment flavor.
///
/// Encodes both region (MY / TH) and environment tier (dev / staging / prod)
/// so every part of the app — API base URL, country code, language — is
/// derived from a single, explicit value passed at launch.
enum AppEnv { dev, staging }

/// Application environment configuration.
///
/// Provides base URLs and default settings for each deployment target.
/// Construct via [AppConfig.fromEnv] for flavor-aware bootstrapping, or use
/// the named factories directly for tests.
class AppConfig {
  final AppEnv env;
  final String baseUrl;
  final String defaultCountryCode;
  final String defaultLanguage;
  final String appName;
  final bool enableLogging;
  final String mockGatewaySecret;

  const AppConfig({
    required this.env,
    required this.baseUrl,
    this.defaultCountryCode = 'MY',
    this.defaultLanguage = 'en',
    this.appName = 'Loob',
    this.enableLogging = kDebugMode,
    this.mockGatewaySecret = 'change-me-local-only',
  });

  /// Constructs the correct [AppConfig] for the given [AppEnv] flavor.
  factory AppConfig.fromEnv(AppEnv env, {bool? enableLogging}) {
    switch (env) {
      case AppEnv.dev:
        return AppConfig(
          env: AppEnv.dev,
          baseUrl: 'http://localhost:8080',
          defaultCountryCode: 'MY',
          defaultLanguage: 'en',
          enableLogging: enableLogging ?? kDebugMode,
          mockGatewaySecret: 'change-me-local-only',
        );

      case AppEnv.staging:
        return AppConfig(
          env: AppEnv.staging,
          baseUrl: 'https://staging-api.loob.com',
          defaultCountryCode: 'MY',
          defaultLanguage: 'en',
          enableLogging: enableLogging ?? kDebugMode,
          mockGatewaySecret: 'change-me-local-only',
        );
    }
  }

  // ── Convenience factories (kept for tests / legacy callers) ────────────────

  /// Local development — Malaysia region (default).
  factory AppConfig.dev({bool? enableLogging}) =>
      AppConfig.fromEnv(AppEnv.dev, enableLogging: enableLogging);

  /// Staging — Malaysia region.
  factory AppConfig.staging({bool? enableLogging}) =>
      AppConfig.fromEnv(AppEnv.staging, enableLogging: enableLogging);

  /// Constructs [AppConfig] using Dart environment defines (`--dart-define` / `--dart-define-from-file`).
  ///
  /// Falls back to the default MY development configuration if no env variables are specified.
  factory AppConfig.fromEnvironment() {
    const envStr = String.fromEnvironment('APP_ENV');
    const baseUrlDefine = String.fromEnvironment('BASE_URL');

    if (envStr.isEmpty && baseUrlDefine.isEmpty) {
      // Fallback to default MY dev flavor if neither APP_ENV nor BASE_URL are defined.
      return AppConfig.fromEnv(AppEnv.dev);
    }

    final env = _parseEnv(envStr);

    // Read individual values with fallbacks to the flavor-specific defaults
    final flavorDefault = AppConfig.fromEnv(env);

    const countryDefine = String.fromEnvironment('DEFAULT_COUNTRY_CODE');
    const languageDefine = String.fromEnvironment('DEFAULT_LANGUAGE');
    const appNameDefine = String.fromEnvironment('APP_NAME');
    const mockSecretDefine = String.fromEnvironment('MOCK_GATEWAY_SECRET');

    const hasLogging = bool.hasEnvironment('ENABLE_LOGGING');
    const loggingVal = bool.fromEnvironment('ENABLE_LOGGING');

    return AppConfig(
      env: env,
      baseUrl: baseUrlDefine.isNotEmpty ? baseUrlDefine : flavorDefault.baseUrl,
      defaultCountryCode: countryDefine.isNotEmpty
          ? countryDefine
          : flavorDefault.defaultCountryCode,
      defaultLanguage: languageDefine.isNotEmpty
          ? languageDefine
          : flavorDefault.defaultLanguage,
      appName: appNameDefine.isNotEmpty ? appNameDefine : flavorDefault.appName,
      enableLogging: hasLogging ? loggingVal : flavorDefault.enableLogging,
      mockGatewaySecret: mockSecretDefine.isNotEmpty
          ? mockSecretDefine
          : flavorDefault.mockGatewaySecret,
    );
  }

  static AppEnv _parseEnv(String value) {
    switch (value) {
      case 'staging':
        return AppEnv.staging;
      default:
        return AppEnv.dev;
    }
  }
}
