import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../data/models/app_config_model.dart';
import '../data/models/feed_item_model.dart';
import '../domain/repositories/home_repository.dart';
import '../../campaigns/data/models/campaign_model.dart';
import '../../campaigns/data/models/home_feed_model.dart';
import '../../campaigns/domain/repositories/campaign_repository.dart';
import '../../orders/data/models/local_order_model.dart';
import '../../orders/domain/repositories/order_repository.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/injection.dart';

// ── State ────────────────────────────────────────────────────────────────────

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final AppConfigModel config;
  final List<FeedItemModel> feedItems;
  final List<CampaignModel> banners;
  final List<LocalOrderItemModel> recentOrders;
  final bool isPromoClaimed;

  const HomeLoaded({
    required this.config,
    required this.feedItems,
    required this.banners,
    required this.recentOrders,
    this.isPromoClaimed = false,
  });

  HomeLoaded copyWith({
    AppConfigModel? config,
    List<FeedItemModel>? feedItems,
    List<CampaignModel>? banners,
    List<LocalOrderItemModel>? recentOrders,
    bool? isPromoClaimed,
  }) {
    return HomeLoaded(
      config: config ?? this.config,
      feedItems: feedItems ?? this.feedItems,
      banners: banners ?? this.banners,
      recentOrders: recentOrders ?? this.recentOrders,
      isPromoClaimed: isPromoClaimed ?? this.isPromoClaimed,
    );
  }

  @override
  List<Object?> get props =>
      [config, feedItems, banners, recentOrders, isPromoClaimed];
}

class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── Cubit ────────────────────────────────────────────────────────────────────

class HomeCubit extends Cubit<HomeState> {
  final IHomeRepository _repository;
  final ICampaignRepository _campaignRepository;
  final IOrderRepository _orderRepository;
  final AppConfig _appConfig;

  HomeCubit({
    IHomeRepository? repository,
    ICampaignRepository? campaignRepository,
    IOrderRepository? orderRepository,
    AppConfig? appConfig,
  }) : _repository = repository ?? sl<IHomeRepository>(),
       _campaignRepository = campaignRepository ?? sl<ICampaignRepository>(),
       _orderRepository = orderRepository ?? sl<IOrderRepository>(),
       _appConfig = appConfig ?? sl<AppConfig>(),
       super(HomeInitial());

  Future<void> loadHome({
    String? countryCode,
    String? language,
    int? brandId,
  }) async {
    emit(HomeLoading());
    try {
      final results = await Future.wait([
        _repository.getAppConfig(),
        _repository.getFeed(),
        _campaignRepository.getHomeFeed(
          countryCode: countryCode ?? _appConfig.defaultCountryCode,
          language: language ?? _appConfig.defaultLanguage,
          brandId: brandId,
        ),
        _loadOrderAgainItems(countryCode ?? _appConfig.defaultCountryCode),
      ]);
      final config = results[0] as AppConfigModel;
      final feed = results[1];
      final campaignFeed = results[2] as HomeFeedModel;
      final recentOrders = results[3] as List<LocalOrderItemModel>;

      // Feed returns a FeedResponseModel but we only expose items.
      final feedItems = (feed as dynamic).items as List<FeedItemModel>;

      emit(
        HomeLoaded(
          config: config,
          feedItems: feedItems,
          banners: campaignFeed.banners,
          recentOrders: recentOrders,
        ),
      );
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }

  void claimPromo() {
    if (state is HomeLoaded) {
      emit((state as HomeLoaded).copyWith(isPromoClaimed: true));
    }
  }

  Future<List<LocalOrderItemModel>> _loadOrderAgainItems(
    String countryCode,
  ) async {
    try {
      return await _orderRepository.loadOrderAgainItems(
        countryCode: countryCode,
        limit: 8,
      );
    } catch (_) {
      return const [];
    }
  }
}
