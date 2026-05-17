import '../../../../core/network/api_client.dart';
import '../datasources/campaign_remote_data_source.dart';
import '../models/home_feed_model.dart';

/// Repository for campaign feed data.
class CampaignRepository {
  final CampaignRemoteDataSource _remote;

  CampaignRepository({required ApiClient client})
      : _remote = CampaignRemoteDataSource(client: client);

  Future<HomeFeedModel> getHomeFeed({
    required String countryCode,
    required String language,
    int? brandId,
  }) =>
      _remote.getHomeFeed(
        countryCode: countryCode,
        language: language,
        brandId: brandId,
      );
}

