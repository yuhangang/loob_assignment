import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/localization/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/tokens/spacing.dart';
import 'features/cart/presentation/bloc/cart_bloc.dart';
import 'features/cart/presentation/bloc/cart_state.dart';
import 'features/cart/presentation/widgets/active_overlay_bar.dart';
import 'features/home/data/models/app_config_model.dart';
import 'features/home/presentation/home_cubit.dart';
import 'features/home/presentation/widgets/marketing_popup_dialog.dart';
import 'features/orders/presentation/bloc/active_order_cubit.dart';
import 'features/orders/presentation/bloc/active_order_state.dart';

/// Bottom navigation scaffold managing the 4 top-level tabs using GoRouter.
class AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchActiveOrder());
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchActiveOrder());
    }
  }

  void _fetchActiveOrder() {
    if (!mounted) return;
    final countryCode = context.read<CartBloc>().state.countryCode;
    context.read<ActiveOrderCubit>().fetchActiveOrder(countryCode: countryCode);
  }

  void _showMarketingPopup(MarketingPopupModel popup) async {
    final claimed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => MarketingPopupDialog(popup: popup),
    );
    if (claimed == true && mounted) {
      context.read<HomeCubit>().claimPromo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<CartBloc, CartState>(
      listenWhen: (previous, current) =>
          previous.countryCode != current.countryCode,
      listener: (_, _) => _fetchActiveOrder(),
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, homeState) {
          final config = homeState is HomeLoaded ? homeState.config : null;
          final isPromoClaimed = homeState is HomeLoaded
              ? homeState.isPromoClaimed
              : false;

          return Scaffold(
            body: Stack(
              children: [
                widget.navigationShell,

                Positioned(
                  left: AppSpacing.pageHorizontal,
                  right: AppSpacing.pageHorizontal,
                  bottom: AppSpacing.pageVertical,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (config != null &&
                          config.marketingPopup.active &&
                          !isPromoClaimed)
                        FloatingActionButton.extended(
                          onPressed: () =>
                              _showMarketingPopup(config.marketingPopup),
                          label: Text(
                            config.marketingPopup.buttonText.isNotEmpty
                                ? config.marketingPopup.buttonText
                                : context.l10n.claimPromo,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          icon: const Icon(Icons.celebration_rounded),
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: theme.colorScheme.onSecondary,
                          elevation: 0.5,
                        ),
                      BlocBuilder<CartBloc, CartState>(
                        builder: (context, cartState) {
                          return BlocBuilder<
                            ActiveOrderCubit,
                            ActiveOrderState
                          >(
                            builder: (context, activeOrderState) {
                              final activeOrder = activeOrderState.activeOrder;
                              if (cartState.totalQuantity == 0 &&
                                  activeOrder == null) {
                                return const SizedBox.shrink();
                              }

                              return Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.md,
                                ),
                                child: ActiveOverlayBar(
                                  cartState: cartState,
                                  activeOrder: activeOrder,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            bottomNavigationBar: BottomNavigationBar(
              currentIndex: widget.navigationShell.currentIndex,
              onTap: (index) {
                if (index == 2) {
                  AppRouter.ordersRefreshSignal.value++;
                }
                widget.navigationShell.goBranch(
                  index,
                  initialLocation: index == widget.navigationShell.currentIndex,
                );
              },
              type: BottomNavigationBarType.fixed,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_outlined),
                  activeIcon: const Icon(Icons.home_rounded),
                  label: context.l10n.home,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.restaurant_menu_outlined),
                  activeIcon: const Icon(Icons.restaurant_menu_rounded),
                  label: context.l10n.menu,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.assignment_outlined),
                  activeIcon: const Icon(Icons.assignment_rounded),
                  label: context.l10n.orders,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.settings_outlined),
                  activeIcon: const Icon(Icons.settings_rounded),
                  label: context.l10n.settings,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
