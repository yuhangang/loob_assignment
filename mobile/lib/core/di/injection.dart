import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_service.dart';
import '../auth/mock_auth_service.dart';
import '../auth/bloc/auth_bloc.dart';
import '../config/app_config.dart';
import '../localization/language_cubit.dart';
import '../network/api_client.dart';
import '../theme/theme_cubit.dart';

// Campaigns
import '../../features/campaigns/domain/repositories/campaign_repository.dart';
import '../../features/campaigns/data/repositories/campaign_repository_impl.dart';
import '../../features/campaigns/data/datasources/campaign_remote_data_source.dart';

// Home
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/home/data/repositories/home_repository_impl.dart';
import '../../features/home/data/datasources/home_remote_data_source.dart';

// Menu
import '../../features/menu/domain/repositories/menu_repository.dart';
import '../../features/menu/data/repositories/menu_repository_impl.dart';
import '../../features/menu/data/datasources/menu_remote_data_source.dart';

// Cart
import '../../features/cart/domain/repositories/cart_repository.dart';
import '../../features/cart/data/repositories/cart_repository_impl.dart';
import '../../features/cart/data/datasources/cart_remote_data_source.dart';

// Orders
import '../../features/orders/domain/repositories/order_repository.dart';
import '../../features/orders/data/repositories/order_repository_impl.dart';

// Vouchers
import '../../features/vouchers/domain/repositories/voucher_repository.dart';
import '../../features/vouchers/data/repositories/voucher_repository_impl.dart';
import '../../features/vouchers/data/datasources/voucher_remote_data_source.dart';

// Settings
import '../../features/settings/domain/repositories/user_profile_repository.dart';
import '../../features/settings/data/repositories/user_profile_repository_impl.dart';
import '../../features/settings/data/datasources/user_profile_remote_data_source.dart';
import '../../features/settings/presentation/user_profile_cubit.dart';

/// Global service locator instance.
///
/// Under test conditions or storybooks, you can inject mocks into this locator.
final sl = GetIt.instance;

/// Registers all dependencies for the given [AppConfig] flavor.
///
/// Call this once at startup via [mainWithEnv] before [runApp].
Future<void> configureDependencies(AppConfig config) async {
  // ── Preferences ────────────────────────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  // ── Config ────────────────────────────────────────────────────────────────
  sl.registerSingleton<AppConfig>(config);

  // ── Auth ───────────────────────────────────────────────────────────────────
  final authService = MockAuthService();
  await authService.init();
  sl.registerSingleton<AuthService>(authService);

  // ── Network ────────────────────────────────────────────────────────────────
  sl.registerLazySingleton<ApiClient>(() => ApiClient(config: sl<AppConfig>()));
  final authUser = sl<AuthService>().currentUser;
  sl<ApiClient>().setUserId(authUser?.uid);
  sl<ApiClient>().setAuthToken(await sl<AuthService>().getIdToken());

  // ── Remote Data Sources ────────────────────────────────────────────────────
  sl.registerLazySingleton<CampaignRemoteDataSource>(
    () => CampaignRemoteDataSource(client: sl<ApiClient>()),
  );
  sl.registerLazySingleton<HomeRemoteDataSource>(
    () => HomeRemoteDataSource(client: sl<ApiClient>()),
  );
  sl.registerLazySingleton<MenuRemoteDataSource>(
    () => MenuRemoteDataSource(client: sl<ApiClient>()),
  );
  sl.registerLazySingleton<CartRemoteDataSource>(
    () => CartRemoteDataSource(client: sl<ApiClient>()),
  );
  sl.registerLazySingleton<VoucherRemoteDataSource>(
    () => VoucherRemoteDataSource(client: sl<ApiClient>()),
  );
  sl.registerLazySingleton<UserProfileRemoteDataSource>(
    () => UserProfileRemoteDataSource(client: sl<ApiClient>()),
  );

  // ── Repositories ───────────────────────────────────────────────────────────
  sl.registerLazySingleton<IHomeRepository>(
    () => HomeRepositoryImpl(remote: sl<HomeRemoteDataSource>()),
  );
  sl.registerLazySingleton<IMenuRepository>(
    () => MenuRepositoryImpl(remote: sl<MenuRemoteDataSource>()),
  );
  sl.registerLazySingleton<ICartRepository>(
    () => CartRepositoryImpl(remote: sl<CartRemoteDataSource>()),
  );
  sl.registerLazySingleton<IOrderRepository>(
    () => OrderRepositoryImpl(
      cartRepository: sl<ICartRepository>(),
      authService: sl<AuthService>(),
      config: sl<AppConfig>(),
    ),
  );
  sl.registerLazySingleton<IVoucherRepository>(
    () => VoucherRepositoryImpl(
      remote: sl<VoucherRemoteDataSource>(),
      authService: sl<AuthService>(),
      config: sl<AppConfig>(),
    ),
  );
  sl.registerLazySingleton<IUserProfileRepository>(
    () => UserProfileRepositoryImpl(
      remote: sl<UserProfileRemoteDataSource>(),
      authService: sl<AuthService>(),
      config: sl<AppConfig>(),
    ),
  );
  sl.registerLazySingleton<ICampaignRepository>(
    () => CampaignRepositoryImpl(remote: sl<CampaignRemoteDataSource>()),
  );

  // ── State ──────────────────────────────────────────────────────────────────
  sl.registerFactory<ThemeCubit>(() => ThemeCubit());
  sl.registerLazySingleton<AuthBloc>(
    () => AuthBloc(authService: sl<AuthService>()),
  );
  sl.registerLazySingleton<UserProfileCubit>(
    () => UserProfileCubit(repository: sl<IUserProfileRepository>()),
  );
  sl.registerLazySingleton<LanguageCubit>(
    () => LanguageCubit(
      prefs: sl<SharedPreferences>(),
      apiClient: sl<ApiClient>(),
      defaultLanguage: config.defaultLanguage,
    ),
  );
}
