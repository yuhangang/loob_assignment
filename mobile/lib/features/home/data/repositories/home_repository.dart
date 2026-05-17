import '../../../../core/network/api_client.dart';
import '../datasources/home_remote_data_source.dart';
import '../models/app_config_model.dart';
import '../models/feed_response_model.dart';

/// Repository mediating between the home data source and the presentation layer.
class HomeRepository {
  final HomeRemoteDataSource _remote;

  HomeRepository({required ApiClient client})
      : _remote = HomeRemoteDataSource(client: client);

  Future<AppConfigModel> getAppConfig() => _remote.getAppConfig();
  Future<FeedResponseModel> getFeed() => _remote.getFeed();
}

