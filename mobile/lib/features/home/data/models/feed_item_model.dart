/// Mapped from Go `appconfig.FeedItem`.
class FeedItemModel {
  final String id;
  final String type; // NEWS, PROMOTION, EVENT
  final String title;
  final String description;
  final String imageUrl;
  final String link;

  const FeedItemModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.link,
  });

  factory FeedItemModel.fromJson(Map<String, dynamic> json) {
    return FeedItemModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      link: json['link'] as String? ?? '',
    );
  }
}
