import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_data_source.dart';
import '../models/app_config_model.dart';
import '../models/feed_response_model.dart';

class HomeRepositoryImpl implements IHomeRepository {
  final HomeRemoteDataSource _remote;

  const HomeRepositoryImpl({
    required HomeRemoteDataSource remote,
  }) : _remote = remote;

  @override
  Future<AppConfigModel> getAppConfig() => _remote.getAppConfig();

  @override
  Future<FeedResponseModel> getFeed() => _remote.getFeed();
}
