import '../../data/models/home_feed_model.dart';

abstract class ICampaignRepository {
  Future<HomeFeedModel> getHomeFeed({
    required String countryCode,
    required String language,
    int? brandId,
  });
}
