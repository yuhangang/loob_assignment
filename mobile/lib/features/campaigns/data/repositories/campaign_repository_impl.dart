import '../../domain/repositories/campaign_repository.dart';
import '../datasources/campaign_remote_data_source.dart';
import '../models/home_feed_model.dart';

class CampaignRepositoryImpl implements ICampaignRepository {
  final CampaignRemoteDataSource _remote;

  const CampaignRepositoryImpl({
    required CampaignRemoteDataSource remote,
  }) : _remote = remote;

  @override
  Future<HomeFeedModel> getHomeFeed({
    required String countryCode,
    required String language,
    int? brandId,
  }) {
    return _remote.getHomeFeed(
      countryCode: countryCode,
      language: language,
      brandId: brandId,
    );
  }
}
