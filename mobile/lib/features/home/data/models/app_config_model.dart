/// Mapped from Go `appconfig.AppConfig` response.
class AppConfigModel {
  final String appName;
  final String appIcon;
  final SplashScreenModel splashScreen;
  final String supportEmail;
  final String version;
  final FeatureTogglesModel featureToggles;
  final MarketingPopupModel marketingPopup;
  final ThemeConfigModel themeConfig;

  const AppConfigModel({
    required this.appName,
    required this.appIcon,
    required this.splashScreen,
    required this.supportEmail,
    required this.version,
    required this.featureToggles,
    required this.marketingPopup,
    required this.themeConfig,
  });

  factory AppConfigModel.fromJson(Map<String, dynamic> json) {
    return AppConfigModel(
      appName: json['app_name'] as String? ?? '',
      appIcon: json['app_icon'] as String? ?? '',
      splashScreen: SplashScreenModel.fromJson(
        json['splash_screen'] as Map<String, dynamic>? ?? {},
      ),
      supportEmail: json['support_email'] as String? ?? '',
      version: json['version'] as String? ?? '',
      featureToggles: FeatureTogglesModel.fromJson(
        json['feature_toggles'] as Map<String, dynamic>? ?? {},
      ),
      marketingPopup: MarketingPopupModel.fromJson(
        json['marketing_popup'] as Map<String, dynamic>? ?? {},
      ),
      themeConfig: ThemeConfigModel.fromJson(
        json['theme_config'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// Mapped from Go `appconfig.SplashScreen`.
class SplashScreenModel {
  final String imageUrl;
  final String backgroundColor;
  final int durationMs;

  const SplashScreenModel({
    required this.imageUrl,
    required this.backgroundColor,
    required this.durationMs,
  });

  factory SplashScreenModel.fromJson(Map<String, dynamic> json) {
    return SplashScreenModel(
      imageUrl: json['image_url'] as String? ?? '',
      backgroundColor: json['background_color'] as String? ?? '#ffffff',
      durationMs: json['duration_ms'] as int? ?? 2000,
    );
  }
}

/// Mapped from Go `appconfig.FeatureToggles`.
class FeatureTogglesModel {
  final bool deliveryEnabled;
  final bool pickupEnabled;
  final bool rewardsEnabled;

  const FeatureTogglesModel({
    required this.deliveryEnabled,
    required this.pickupEnabled,
    required this.rewardsEnabled,
  });

  factory FeatureTogglesModel.fromJson(Map<String, dynamic> json) {
    return FeatureTogglesModel(
      deliveryEnabled: json['delivery_enabled'] as bool? ?? true,
      pickupEnabled: json['pickup_enabled'] as bool? ?? true,
      rewardsEnabled: json['rewards_enabled'] as bool? ?? true,
    );
  }
}

/// Mapped from Go `appconfig.MarketingPopup`.
class MarketingPopupModel {
  final bool active;
  final String title;
  final String description;
  final String imageUrl;
  final String buttonText;
  final String link;

  const MarketingPopupModel({
    required this.active,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.buttonText,
    required this.link,
  });

  factory MarketingPopupModel.fromJson(Map<String, dynamic> json) {
    return MarketingPopupModel(
      active: json['active'] as bool? ?? false,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      buttonText: json['button_text'] as String? ?? '',
      link: json['link'] as String? ?? '',
    );
  }
}

/// Mapped from Go `appconfig.ThemeConfig`.
class ThemeConfigModel {
  final String primaryColor;
  final String accentColor;
  final String secondaryColor;

  const ThemeConfigModel({
    required this.primaryColor,
    required this.accentColor,
    required this.secondaryColor,
  });

  factory ThemeConfigModel.fromJson(Map<String, dynamic> json) {
    return ThemeConfigModel(
      primaryColor: json['primary_color'] as String? ?? '',
      accentColor: json['accent_color'] as String? ?? '',
      secondaryColor: json['secondary_color'] as String? ?? '',
    );
  }
}
