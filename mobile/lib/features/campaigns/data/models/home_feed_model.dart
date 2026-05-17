import 'campaign_model.dart';

/// Mapped from Go `campaigns.HomeFeed`.
class HomeFeedModel {
  final String countryCode;
  final String languageResolved;
  final List<CampaignModel> banners;
  final List<CampaignModel> modules;

  const HomeFeedModel({
    required this.countryCode,
    required this.languageResolved,
    required this.banners,
    required this.modules,
  });

  factory HomeFeedModel.fromJson(Map<String, dynamic> json) {
    final bannerList = json['banners'] as List<dynamic>? ?? [];
    final moduleList = json['modules'] as List<dynamic>? ?? [];
    return HomeFeedModel(
      countryCode: json['country_code'] as String? ?? '',
      languageResolved: json['language_resolved'] as String? ?? '',
      banners: bannerList
          .map((e) => CampaignModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      modules: moduleList
          .map((e) => CampaignModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
