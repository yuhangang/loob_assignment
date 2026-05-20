import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:loob_app/features/cart/presentation/bloc/cart_state.dart';
import 'core/auth/bloc/auth_bloc.dart';
import 'core/auth/bloc/auth_state.dart';
import 'core/auth/widgets/session_timeout_dialog.dart';
import 'core/di/injection.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/language_cubit.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/brand.dart';
import 'core/theme/theme_cubit.dart';
import 'features/cart/presentation/bloc/cart_bloc.dart';
import 'features/cart/presentation/bloc/cart_event.dart';
import 'features/menu/domain/repositories/menu_repository.dart';
import 'features/settings/presentation/user_profile_cubit.dart';

/// Root application widget.
///
/// Wraps the widget tree with [ThemeCubit] and [LanguageCubit] and dynamically
/// swaps [ThemeData] and active [Locale] upon user settings selection.
class LoobApp extends StatelessWidget {
  const LoobApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppProviders(
      child: MultiBlocListener(
        listeners: [
          BlocListener<CartBloc, CartState>(
            listenWhen: (previous, current) =>
                previous.countryCode != current.countryCode,
            listener: (context, state) {
              if (state.countryCode == 'TH') {
                final languageCubit = context.read<LanguageCubit>();
                if (languageCubit.state.languageCode != 'en') {
                  languageCubit.switchLanguage('en');

                  final userProfileCubit = context.read<UserProfileCubit>();
                  final authState = context.read<AuthBloc>().state;
                  if (authState is Authenticated) {
                    userProfileCubit.updatePreferredLanguage('en');
                  }
                }
              }
            },
          ),
          BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is Unauthenticated) {
                context.read<UserProfileCubit>().reset();
                context.read<CartBloc>().add(const CartCleared());
                if (state.sessionExpired) {
                  showSessionTimeoutDialog(context);
                }
              } else if (state is Authenticated) {
                context.read<UserProfileCubit>().loadProfile();
                final cartBloc = context.read<CartBloc>();
                initCartStore(context, cartBloc, cartBloc.state.countryCode);
              }
            },
          ),
          BlocListener<UserProfileCubit, UserProfileState>(
            listener: (context, state) {
              if (state is UserProfileLoaded) {
                final profileCountry = state.profile.registeredCountryId;
                final cartBloc = context.read<CartBloc>();
                if (profileCountry.isNotEmpty &&
                    profileCountry != cartBloc.state.countryCode) {
                  final currency = profileCountry == 'TH' ? 'THB' : 'MYR';
                  cartBloc.add(
                    CartSwitchCountry(
                      countryCode: profileCountry,
                      currency: currency,
                    ),
                  );
                  initCartStore(context, cartBloc, profileCountry);
                }
              }
            },
          ),
          BlocListener<ThemeCubit, LoobBrand>(
            listener: (context, brand) async {
              final cartBloc = context.read<CartBloc>();
              final currentStore = cartBloc.state.selectedStore;
              final targetBrandId =
                  brand.brandId ?? 1; // Default to Tealive if discover

              // Only auto-resolve store if the cart's selected store is null
              // or its brand doesn't match the new brand theme.
              if (currentStore == null ||
                  currentStore.brandId != targetBrandId) {
                try {
                  final stores = await sl<IMenuRepository>().listStores(
                    countryId: cartBloc.state.countryCode,
                    brandId: targetBrandId,
                  );
                  if (stores.isNotEmpty && context.mounted) {
                    final latestStore = cartBloc.state.selectedStore;
                    if (latestStore == null ||
                        latestStore.brandId != targetBrandId) {
                      cartBloc.add(CartSetStore(stores.first));
                      cartBloc.add(const CartLoadRequested());
                    }
                  }
                } catch (_) {}
              }
            },
          ),
        ],
        child: BlocBuilder<LanguageCubit, Locale>(
          builder: (context, locale) {
            return BlocBuilder<ThemeCubit, LoobBrand>(
              builder: (context, brand) {
                return AnimatedTheme(
                  data: AppTheme.fromBrand(brand),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                  child: MaterialApp.router(
                    title: 'Loob',
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.fromBrand(brand),
                    locale: locale,
                    supportedLocales: const [Locale('en'), Locale('ms')],
                    localizationsDelegates: const [
                      AppLocalizations.delegate,
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    routerConfig: AppRouter.router,
                    builder: (context, child) => child!,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
