import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../data/models/app_config_model.dart';
import '../data/models/feed_item_model.dart';
import '../data/repositories/home_repository.dart';
import '../../campaigns/data/models/campaign_model.dart';
import '../../campaigns/data/models/home_feed_model.dart';
import '../../campaigns/data/repositories/campaign_repository.dart';
import '../../menu/data/models/catalog_model.dart';
import '../../orders/data/models/local_order_model.dart';
import '../../orders/data/repositories/order_repository.dart';
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

  const HomeLoaded({
    required this.config,
    required this.feedItems,
    required this.banners,
    required this.recentOrders,
  });

  @override
  List<Object?> get props => [config, feedItems, banners, recentOrders];
}

class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── Cubit ────────────────────────────────────────────────────────────────────

class HomeCubit extends Cubit<HomeState> {
  final HomeRepository _repository;
  final CampaignRepository _campaignRepository;
  final OrderRepository _orderRepository;
  final AppConfig _appConfig;

  HomeCubit({
    HomeRepository? repository,
    CampaignRepository? campaignRepository,
    OrderRepository? orderRepository,
    AppConfig? appConfig,
  }) : _repository = repository ?? sl<HomeRepository>(),
       _campaignRepository = campaignRepository ?? sl<CampaignRepository>(),
       _orderRepository = orderRepository ?? sl<OrderRepository>(),
       _appConfig = appConfig ?? sl<AppConfig>(),
       super(HomeInitial());

  Future<void> loadHome({String? language, int? brandId}) async {
    emit(HomeLoading());
    try {
      final results = await Future.wait([
        _repository.getAppConfig(),
        _repository.getFeed(),
        _campaignRepository.getHomeFeed(
          countryCode: _appConfig.defaultCountryCode,
          language: language ?? _appConfig.defaultLanguage,
          brandId: brandId,
        ),
      ]);
      final config = results[0] as AppConfigModel;
      final feed = results[1];
      final campaignFeed = results[2] as HomeFeedModel;

      // Feed returns a FeedResponseModel but we only expose items.
      final feedItems = (feed as dynamic).items as List<FeedItemModel>;

      final storedOrderItems = _orderRepository.loadOrderAgainItems();
      final recentOrders = storedOrderItems.isNotEmpty
          ? storedOrderItems
          : _getMockRecentOrders(brandId);

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

  List<LocalOrderItemModel> _getMockRecentOrders(int? brandId) {
    final mockTealive1 = ProductModel(
      id: 100,
      skuCode: 'MY-TL-PMT',
      isAvailable: true,
      name: 'Signature Pearl Milk Tea',
      description: 'Classic milk tea finished with chewy pearls.',
      media: const MediaModel(
        imageUrlSm: '/cdn/promo_tealive.png',
        imageUrlLg: '/cdn/promo_tealive.png',
      ),
      basePrice: 800,
      dietaryTags: const ['halal', 'contains_dairy', 'caffeine'],
      customizationGroups: const [],
    );

    final mockTealive2 = ProductModel(
      id: 101,
      skuCode: 'MY-TL-GMT',
      isAvailable: true,
      name: 'Grass Jelly Milk Tea',
      description: 'Milk tea with grass jelly and a mellow finish.',
      media: const MediaModel(
        imageUrlSm: '/cdn/promo_tealive.png',
        imageUrlLg: '/cdn/promo_tealive.png',
      ),
      basePrice: 850,
      dietaryTags: const ['halal', 'contains_dairy', 'caffeine'],
      customizationGroups: const [],
    );

    final mockBaskbear1 = ProductModel(
      id: 103,
      skuCode: 'MY-BB-LAT',
      isAvailable: true,
      name: 'Sea Salt Oat Latte',
      description: 'Smooth espresso latte with oat milk.',
      media: const MediaModel(
        imageUrlSm: '/cdn/promo_baskbear.png',
        imageUrlLg: '/cdn/promo_baskbear.png',
      ),
      basePrice: 1100,
      dietaryTags: const ['halal', 'caffeine'],
      customizationGroups: const [],
    );

    final mockBaskbear2 = ProductModel(
      id: 102,
      skuCode: 'MY-BB-CHZ',
      isAvailable: true,
      name: 'Cheesy Chicken Toastie',
      description: 'Grilled toastie with chicken and cheese.',
      media: const MediaModel(
        imageUrlSm: '/cdn/promo_baskbear.png',
        imageUrlLg: '/cdn/promo_baskbear.png',
      ),
      basePrice: 1200,
      dietaryTags: const ['halal'],
      customizationGroups: const [],
    );

    if (brandId == 1) {
      return [_mockOrderItem(mockTealive1), _mockOrderItem(mockTealive2)];
    } else if (brandId == 2) {
      return [_mockOrderItem(mockBaskbear1), _mockOrderItem(mockBaskbear2)];
    } else {
      return [
        _mockOrderItem(mockTealive1),
        _mockOrderItem(mockBaskbear1),
        _mockOrderItem(mockTealive2),
        _mockOrderItem(mockBaskbear2),
      ];
    }
  }

  LocalOrderItemModel _mockOrderItem(ProductModel product) {
    return LocalOrderItemModel.fromProduct(
      product: product,
      quantity: 1,
      customizationOptionIds: const [],
      customizationOptions: const [],
    );
  }
}
