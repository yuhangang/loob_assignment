import '../../data/models/app_config_model.dart';
import '../../data/models/feed_response_model.dart';

abstract class IHomeRepository {
  Future<AppConfigModel> getAppConfig();
  Future<FeedResponseModel> getFeed();
}
