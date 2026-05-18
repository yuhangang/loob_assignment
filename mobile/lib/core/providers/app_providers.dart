import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/cart/data/datasources/cart_remote_data_source.dart';
import '../../features/cart/presentation/bloc/cart_bloc.dart';
import '../../features/cart/presentation/bloc/cart_event.dart';
import '../../features/menu/domain/repositories/menu_repository.dart';
import '../../features/orders/presentation/bloc/active_order_cubit.dart';
import '../../features/settings/presentation/user_profile_cubit.dart';
import '../../features/vouchers/presentation/voucher_wallet_page.dart';
import '../auth/bloc/auth_bloc.dart';
import '../config/app_config.dart';
import '../di/injection.dart';
import '../localization/language_cubit.dart';
import '../theme/theme_cubit.dart';

/// Renders global BLoC/Cubit providers wrapper at the root of the application.
class AppProviders extends StatelessWidget {
  const AppProviders({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final config = sl<AppConfig>();
    final initialCountry =
        sl<SharedPreferences>().getString('user_preferred_country') ??
        config.defaultCountryCode;

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(create: (_) => sl<LanguageCubit>()),
        BlocProvider(create: (_) => sl<AuthBloc>()),
        BlocProvider(
          create: (context) {
            final cartBloc = CartBloc(
              remoteDataSource: CartRemoteDataSource(client: sl()),
              countryCode: initialCountry,
            );
            initCartStore(context, cartBloc, initialCountry);
            return cartBloc;
          },
        ),
        BlocProvider(create: (_) => sl<UserProfileCubit>()..loadProfile()),
        BlocProvider(create: (_) => VoucherCubit()..loadWallet()),
        BlocProvider(create: (_) => ActiveOrderCubit()),
      ],
      child: child,
    );
  }
}

/// Helper function to asynchronously initialize the cart store context based on the active brand.
Future<void> initCartStore(
  BuildContext context,
  CartBloc cartBloc,
  String countryCode,
) async {
  try {
    final themeCubit = context.read<ThemeCubit>();
    final brand = themeCubit.state;
    final brandId = brand.brandId ?? 1; // Default to Tealive if discover
    final stores = await sl<IMenuRepository>().listStores(
      countryId: countryCode,
      brandId: brandId,
    );
    if (stores.isNotEmpty) {
      final defaultStore = stores.first;
      cartBloc.add(CartSetStore(defaultStore));
    }
  } catch (_) {
    // Defer/fallback to no store (handled by backend or future selection)
  } finally {
    cartBloc.add(const CartLoadRequested());
    cartBloc.add(const CartAvailabilityPollStarted());
  }
}
