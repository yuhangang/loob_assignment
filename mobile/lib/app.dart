import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/injection.dart';
import 'core/config/app_config.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/language_cubit.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/brand.dart';
import 'core/theme/theme_cubit.dart';
import 'core/theme/tokens/spacing.dart';
import 'features/cart/data/datasources/cart_remote_data_source.dart';
import 'features/cart/presentation/bloc/cart_bloc.dart';
import 'features/cart/presentation/bloc/cart_event.dart';
import 'features/cart/presentation/bloc/cart_state.dart';
import 'features/cart/presentation/widgets/cart_floating_bar.dart';
import 'features/settings/presentation/user_profile_cubit.dart';
import 'features/vouchers/presentation/voucher_wallet_page.dart';
import 'shell.dart';

/// Injects the [CartFloatingBar] directly into the Navigator's [Overlay] so it
/// always renders above modal bottom sheets and dialogs.
class _CartOverlayManager extends StatefulWidget {
  const _CartOverlayManager({required this.child});
  final Widget child;

  @override
  State<_CartOverlayManager> createState() => _CartOverlayManagerState();
}

class _CartOverlayManagerState extends State<_CartOverlayManager> {
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    // Insert after the first frame so the Overlay is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _insertOverlay());
  }

  void _insertOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => _CartFloatingBarPositioned(
        // Forward the BLoC context from the tree above this widget.
        cartCubitContext: context,
      ),
    );
    // Insert at the top of the navigator overlay so it floats above sheets.
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The actual positioned cart bar, reads state from the ancestor BLoC context.
class _CartFloatingBarPositioned extends StatelessWidget {
  const _CartFloatingBarPositioned({required this.cartCubitContext});
  final BuildContext cartCubitContext;

  @override
  Widget build(BuildContext context) {
    // Use the ancestor context to read cart state — the overlay context is
    // outside the BlocProvider tree.
    return BlocBuilder<CartBloc, CartState>(
      bloc: cartCubitContext.read<CartBloc>(),
      builder: (_, cartState) {
        if (cartState.totalQuantity == 0) return const SizedBox.shrink();
        final mq = MediaQuery.of(cartCubitContext);
        return Positioned(
          left: AppSpacing.pageHorizontal,
          right: AppSpacing.pageHorizontal,
          bottom: mq.padding.bottom + 76.0, // Above bottom nav
          child: CartFloatingBar(cartState: cartState),
        );
      },
    );
  }
}

/// Root application widget.
///
/// Wraps the widget tree with [ThemeCubit] and [LanguageCubit] and dynamically
/// swaps [ThemeData] and active [Locale] upon user settings selection.
class LoobApp extends StatelessWidget {
  const LoobApp({super.key});

  @override
  Widget build(BuildContext context) {
    final config = sl<AppConfig>();

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(create: (_) => sl<LanguageCubit>()),
        BlocProvider(
          create: (_) => CartBloc(
            remoteDataSource: CartRemoteDataSource(client: sl()),
            userId: 'mock_user_001',
            countryCode: config.defaultCountryCode,
          )
            ..add(const CartLoadRequested()) // Hydrate from server on startup
            ..add(const CartAvailabilityPollStarted()), // Start periodic polling
        ),
        BlocProvider(create: (_) => sl<UserProfileCubit>()..loadProfile()),
        BlocProvider(create: (_) => VoucherCubit()..loadWallet()),
      ],
      child: BlocBuilder<LanguageCubit, Locale>(
        builder: (context, locale) {
          return BlocBuilder<ThemeCubit, LoobBrand>(
            builder: (context, brand) {
              return AnimatedTheme(
                data: AppTheme.fromBrand(brand),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                child: MaterialApp(
                  title: 'Loob',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.fromBrand(brand),
                  locale: locale,
                  supportedLocales: const [
                    Locale('en'),
                    Locale('ms'),
                  ],
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  navigatorKey: AppRouter.navigatorKey,
                  navigatorObservers: [AppRouter.routeObserver],
                  home: _CartOverlayManager(child: const AppShell()),
                  onGenerateRoute: AppRouter.onGenerateRoute,
                  // The CartFloatingBar is injected into the Navigator overlay
                  // (via _CartOverlayManager) so it renders above bottom sheets.
                  builder: (context, child) => child!,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
