import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/tokens/spacing.dart';
import '../../../orders/presentation/bloc/active_order_cubit.dart';
import '../../../orders/presentation/bloc/active_order_state.dart';
import '../bloc/cart_bloc.dart';
import '../bloc/cart_state.dart';
import '../widgets/active_overlay_bar.dart';

/// Injects the [ActiveOverlayBar] directly into the Navigator's [Overlay] so it
/// always renders above modal bottom sheets and dialogs.
class ActiveOverlayManager extends StatefulWidget {
  const ActiveOverlayManager({super.key, required this.child});
  final Widget child;

  @override
  State<ActiveOverlayManager> createState() => _ActiveOverlayManagerState();
}

class _ActiveOverlayManagerState extends State<ActiveOverlayManager> {
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
      builder: (overlayContext) => ActiveOverlayBarPositioned(
        // Forward the BLoC context from the tree above this widget.
        cartCubitContext: context,
      ),
    );
    // Insert at the top of the navigator overlay so it floats above sheets.
    AppRouter.navigatorKey.currentState?.overlay?.insert(_overlayEntry!);
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

/// The actual positioned active bar, reads state from the ancestor BLoC context.
class ActiveOverlayBarPositioned extends StatefulWidget {
  const ActiveOverlayBarPositioned({super.key, required this.cartCubitContext});
  final BuildContext cartCubitContext;

  @override
  State<ActiveOverlayBarPositioned> createState() =>
      _ActiveOverlayBarPositionedState();
}

class _ActiveOverlayBarPositionedState
    extends State<ActiveOverlayBarPositioned> {
  @override
  void initState() {
    super.initState();
    _fetchActiveOrder();
    AppRouter.currentRouteNotifier.addListener(_fetchActiveOrder);
  }

  @override
  void dispose() {
    AppRouter.currentRouteNotifier.removeListener(_fetchActiveOrder);
    super.dispose();
  }

  void _fetchActiveOrder() {
    if (!mounted) return;
    final country = widget.cartCubitContext.read<CartBloc>().state.countryCode;
    widget.cartCubitContext.read<ActiveOrderCubit>().fetchActiveOrder(
      countryCode: country,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use the ancestor context to read cart state — the overlay context is
    // outside the BlocProvider tree.
    return BlocBuilder<CartBloc, CartState>(
      bloc: widget.cartCubitContext.read<CartBloc>(),
      builder: (_, cartState) {
        return BlocBuilder<ActiveOrderCubit, ActiveOrderState>(
          bloc: widget.cartCubitContext.read<ActiveOrderCubit>(),
          builder: (_, activeOrderState) {
            final activeOrder = activeOrderState.activeOrder;
            if (cartState.totalQuantity == 0 && activeOrder == null) {
              return const IgnorePointer(
                ignoring: true,
                child: SizedBox.shrink(),
              );
            }
            final mq = MediaQuery.of(widget.cartCubitContext);
            return Positioned(
              left: AppSpacing.pageHorizontal,
              right: AppSpacing.pageHorizontal,
              bottom: mq.padding.bottom + 76.0, // Above bottom nav
              child: ActiveOverlayBar(
                cartState: cartState,
                activeOrder: activeOrder,
              ),
            );
          },
        );
      },
    );
  }
}
