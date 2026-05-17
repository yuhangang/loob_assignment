import 'feed_item_model.dart';

/// Mapped from Go `appconfig.FeedResponse`.
class FeedResponseModel {
  final List<FeedItemModel> items;

  const FeedResponseModel({required this.items});

  factory FeedResponseModel.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return FeedResponseModel(
      items: list
          .map((e) => FeedItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
