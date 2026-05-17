/// App deployment flavor.
///
/// Encodes both region (MY / TH) and environment tier (dev / staging / prod)
/// so every part of the app — API base URL, country code, language — is
/// derived from a single, explicit value passed at launch.
enum AppEnv {
  devMY,
  devTH,
  stagingMY,
  stagingTH,
  prodMY,
  prodTH,
}

/// Application environment configuration.
///
/// Provides base URLs and default settings for each deployment target.
/// Construct via [AppConfig.fromEnv] for flavor-aware bootstrapping, or use
/// the named factories directly for tests.
class AppConfig {
  final AppEnv env;
  final String baseUrl;
  final String cdnBaseUrl;
  final String defaultCountryCode;
  final String defaultLanguage;
  final String appName;

  const AppConfig({
    required this.env,
    required this.baseUrl,
    required this.cdnBaseUrl,
    this.defaultCountryCode = 'MY',
    this.defaultLanguage = 'en',
    this.appName = 'Loob',
  });

  /// Constructs the correct [AppConfig] for the given [AppEnv] flavor.
  factory AppConfig.fromEnv(AppEnv env) {
    switch (env) {
      case AppEnv.devMY:
        return const AppConfig(
          env: AppEnv.devMY,
          baseUrl: 'http://localhost:8080',
          cdnBaseUrl: 'http://localhost:8080/cdn',
          defaultCountryCode: 'MY',
          defaultLanguage: 'en',
        );
      case AppEnv.devTH:
        return const AppConfig(
          env: AppEnv.devTH,
          baseUrl: 'http://localhost:8080',
          cdnBaseUrl: 'http://localhost:8080/cdn',
          defaultCountryCode: 'TH',
          defaultLanguage: 'th',
        );
      case AppEnv.stagingMY:
        return const AppConfig(
          env: AppEnv.stagingMY,
          baseUrl: 'https://staging-api.loob.com',
          cdnBaseUrl: 'https://staging-cdn.loob.com',
          defaultCountryCode: 'MY',
          defaultLanguage: 'en',
        );
      case AppEnv.stagingTH:
        return const AppConfig(
          env: AppEnv.stagingTH,
          baseUrl: 'https://staging-api.loob.com',
          cdnBaseUrl: 'https://staging-cdn.loob.com',
          defaultCountryCode: 'TH',
          defaultLanguage: 'th',
        );
      case AppEnv.prodMY:
        return const AppConfig(
          env: AppEnv.prodMY,
          baseUrl: 'https://api.loob.com',
          cdnBaseUrl: 'https://cdn.loob.com',
          defaultCountryCode: 'MY',
          defaultLanguage: 'en',
        );
      case AppEnv.prodTH:
        return const AppConfig(
          env: AppEnv.prodTH,
          baseUrl: 'https://api.loob.com',
          cdnBaseUrl: 'https://cdn.loob.com',
          defaultCountryCode: 'TH',
          defaultLanguage: 'th',
        );
    }
  }

  // ── Convenience factories (kept for tests / legacy callers) ────────────────

  /// Local development — Malaysia region (default).
  factory AppConfig.dev() => AppConfig.fromEnv(AppEnv.devMY);

  /// Staging — Malaysia region.
  factory AppConfig.staging() => AppConfig.fromEnv(AppEnv.stagingMY);

  /// Production — Malaysia region.
  factory AppConfig.production() => AppConfig.fromEnv(AppEnv.prodMY);
}
