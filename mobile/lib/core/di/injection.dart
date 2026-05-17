import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_service.dart';
import '../auth/mock_auth_service.dart';
import '../config/app_config.dart';
import '../localization/language_cubit.dart';
import '../network/api_client.dart';
import '../theme/theme_cubit.dart';
import '../../features/campaigns/data/repositories/campaign_repository.dart';
import '../../features/cart/data/repositories/cart_repository.dart';
import '../../features/home/data/repositories/home_repository.dart';
import '../../features/menu/data/repositories/menu_repository.dart';
import '../../features/orders/data/repositories/order_repository.dart';
import '../../features/settings/data/repositories/user_profile_repository.dart';
import '../../features/settings/presentation/user_profile_cubit.dart';
import '../../features/vouchers/data/repositories/voucher_repository.dart';

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
  sl.registerLazySingleton<AuthService>(() => MockAuthService());

  // ── Network ────────────────────────────────────────────────────────────────
  sl.registerLazySingleton<ApiClient>(() => ApiClient(config: sl<AppConfig>()));
  final authUser = sl<AuthService>().currentUser;
  sl<ApiClient>().setUserId(authUser?.uid);
  sl<ApiClient>().setAuthToken(await sl<AuthService>().getIdToken());

  // ── Repositories ───────────────────────────────────────────────────────────
  sl.registerLazySingleton<HomeRepository>(
    () => HomeRepository(client: sl<ApiClient>()),
  );
  sl.registerLazySingleton<MenuRepository>(
    () => MenuRepository(client: sl<ApiClient>()),
  );
  sl.registerLazySingleton<CartRepository>(
    () => CartRepository(client: sl<ApiClient>()),
  );
  sl.registerLazySingleton<OrderRepository>(
    () => OrderRepository(
      cartRepository: sl<CartRepository>(),
      authService: sl<AuthService>(),
      config: sl<AppConfig>(),
    ),
  );
  sl.registerLazySingleton<VoucherRepository>(
    () => VoucherRepository(
      client: sl<ApiClient>(),
      authService: sl<AuthService>(),
      config: sl<AppConfig>(),
    ),
  );
  sl.registerLazySingleton<UserProfileRepository>(
    () => UserProfileRepository(
      client: sl<ApiClient>(),
      authService: sl<AuthService>(),
      config: sl<AppConfig>(),
    ),
  );
  sl.registerLazySingleton<CampaignRepository>(
    () => CampaignRepository(client: sl<ApiClient>()),
  );

  // ── State ──────────────────────────────────────────────────────────────────
  sl.registerFactory<ThemeCubit>(() => ThemeCubit());
  sl.registerLazySingleton<UserProfileCubit>(
    () => UserProfileCubit(repository: sl<UserProfileRepository>()),
  );
  sl.registerLazySingleton<LanguageCubit>(
    () => LanguageCubit(
      prefs: sl<SharedPreferences>(),
      apiClient: sl<ApiClient>(),
      defaultLanguage: config.defaultLanguage,
    ),
  );
}
