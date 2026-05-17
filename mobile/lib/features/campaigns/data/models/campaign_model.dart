/// Mapped from Go `campaigns.Campaign`.
class CampaignModel {
  final int id;
  final String type;
  final int? brandId;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String deepLink;
  final String webviewUrl;
  final int priority;
  final Map<String, dynamic> metadata;

  const CampaignModel({
    required this.id,
    required this.type,
    this.brandId,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.deepLink,
    this.webviewUrl = '',
    required this.priority,
    this.metadata = const {},
  });

  factory CampaignModel.fromJson(Map<String, dynamic> json) {
    return CampaignModel(
      id: json['id'] as int? ?? 0,
      type: json['type'] as String? ?? '',
      brandId: json['brand_id'] as int?,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      deepLink: json['deep_link'] as String? ?? '',
      webviewUrl: json['webview_url'] as String? ?? '',
      priority: json['priority'] as int? ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
}
