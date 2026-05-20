import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/localization/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/tokens/spacing.dart';
import 'features/cart/presentation/bloc/cart_bloc.dart';
import 'features/cart/presentation/bloc/cart_state.dart';
import 'features/cart/presentation/widgets/active_overlay_bar.dart';
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
  bool get _isHomeTab => widget.navigationShell.currentIndex == 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchActiveOrder());
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
            widget.navigationShell.currentIndex &&
        _isHomeTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchActiveOrder());
    }
  }

  void _fetchActiveOrder() {
    if (!mounted || !_isHomeTab) return;
    final countryCode = context.read<CartBloc>().state.countryCode;
    context.read<ActiveOrderCubit>().fetchActiveOrder(countryCode: countryCode);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CartBloc, CartState>(
      listenWhen: (previous, current) =>
          previous.countryCode != current.countryCode,
      listener: (_, _) => _fetchActiveOrder(),
      child: Scaffold(
        body: Stack(
          children: [
            widget.navigationShell,
            if (_isHomeTab)
              BlocBuilder<CartBloc, CartState>(
                builder: (context, cartState) {
                  return BlocBuilder<ActiveOrderCubit, ActiveOrderState>(
                    builder: (context, activeOrderState) {
                      final activeOrder = activeOrderState.activeOrder;
                      if (cartState.totalQuantity == 0 && activeOrder == null) {
                        return const SizedBox.shrink();
                      }

                      return Positioned(
                        left: AppSpacing.pageHorizontal,
                        right: AppSpacing.pageHorizontal,
                        bottom: MediaQuery.paddingOf(context).bottom + 76.0,
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
      ),
    );
  }
}
