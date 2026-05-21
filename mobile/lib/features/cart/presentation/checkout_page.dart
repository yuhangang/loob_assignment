import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:loob_app/features/menu/data/models/catalog_model.dart';
import 'package:loob_app/features/orders/presentation/bloc/active_order_cubit.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/loob_error_dialog.dart';
import '../../../core/widgets/loob_loading_overlay.dart';
import 'bloc/cart_bloc.dart';
import 'bloc/cart_event.dart';
import 'bloc/cart_item.dart';
import 'bloc/cart_state.dart';
import 'bloc/checkout_cubit.dart';
import 'bloc/checkout_state.dart';
import 'widgets/checkout_amount_row.dart';
import 'widgets/checkout_floating_button.dart';
import 'widgets/checkout_item_tile.dart';
import 'widgets/checkout_payment_result.dart';
import 'widgets/checkout_payment_section.dart';
import 'widgets/checkout_section.dart';
import 'widgets/checkout_voucher_section.dart';
import 'widgets/store_closed_warning.dart';
import 'widgets/vouchers_bottom_sheet.dart';

class CheckoutPage extends StatefulWidget {
  final CartItem? buyNowItem;

  const CheckoutPage({super.key, this.buyNowItem});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _voucherController = TextEditingController();
  bool _isRefreshingAvailability = false;
  bool _availabilityRefreshFailed = false;

  @override
  void initState() {
    super.initState();
    _refreshAvailabilityForSelectedStore();
  }

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  void _refreshAvailabilityForSelectedStore() {
    if (widget.buyNowItem != null) return;

    final cartBloc = context.read<CartBloc>();
    final storeId = cartBloc.state.storeId;
    if (storeId <= 0 || cartBloc.userId.isEmpty) return;

    _isRefreshingAvailability = true;
    _availabilityRefreshFailed = false;
    cartBloc.add(CartLoadRequested(storeId: storeId));
  }

  void _submitCheckout(BuildContext context, CartState cart) {
    final activeOrder = context.read<ActiveOrderCubit>().state.activeOrder;
    if (activeOrder != null) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.activeOrderWarningTitle),
          content: Text(context.l10n.activeOrderWarningContent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _performSubmit(context, cart);
              },
              child: Text(context.l10n.continueBtn),
            ),
          ],
        ),
      );
    } else {
      _performSubmit(context, cart);
    }
  }

  void _performSubmit(BuildContext context, CartState cart) {
    context.read<CheckoutCubit>().submitCheckout(
      cart: cart,
      userId: context.read<CartBloc>().userId,
      errSelectPaymentMethod: context.l10n.selectPaymentMethodFirst,
      errSelectOutlet: context.l10n.selectOutletFirst,
      errStoreClosed: context.l10n.selectedStoreClosedCheckout,
      errCheckoutFailed: context.l10n.checkoutFailedMsg,
    );
  }

  Future<void> _showEditItemSheet(
    BuildContext context,
    CartItem item,
    String currency,
  ) async {
    if (item.product.customizationGroups.isEmpty) return;

    final result = await context.push(
      AppRouter.productDetail,
      extra: {'product': item.product, 'currency': currency, 'cartItem': item},
    );
    if (!context.mounted || result is! Map<String, dynamic>) return;

    final resolvedProduct = result['product'] as ProductModel? ?? item.product;
    final quantity = item.quantity;
    final action = result['action'] as String? ?? 'update';
    final selectionsMap = result['selections'] as Map<dynamic, dynamic>? ?? {};
    final selectedIds = <int>[];
    for (final ids in selectionsMap.values) {
      if (ids is List) {
        selectedIds.addAll(ids.whereType<int>());
      }
    }
    final selectedOptions = resolvedProduct.customizationGroups
        .expand((group) => group.options)
        .where((option) => selectedIds.contains(option.id))
        .toList();

    if (widget.buyNowItem != null) {
      if (action == 'buy_now') {
        context.read<CheckoutCubit>().updateBuyNowItemCustomizations(
          selectedOptions: selectedOptions,
          selectedIds: selectedIds,
          quantity: quantity,
        );
      } else {
        context.read<CheckoutCubit>().updateBuyNowItemCustomizations(
          selectedOptions: selectedOptions,
          selectedIds: selectedIds,
          quantity: quantity,
        );
      }
    } else {
      if (action == 'add') {
        context.read<CartBloc>().add(
          CartItemAdded(
            product: item.product,
            selectedOptions: selectedOptions,
            customizationOptionIds: selectedIds,
            quantity: quantity,
          ),
        );
      } else {
        context.read<CartBloc>().add(
          CartItemConfigurationUpdated(
            item: item,
            selectedOptions: selectedOptions,
            quantity: quantity,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          CheckoutCubit(buyNowItem: widget.buyNowItem)..loadPaymentMethods(
            context.read<CartBloc>().state.countryCode,
            context.l10n.unableLoadPaymentMethods,
          ),
      child: BlocListener<CheckoutCubit, CheckoutState>(
        listenWhen: (previous, current) =>
            previous.isCheckingOut != current.isCheckingOut ||
            previous.error != current.error ||
            previous.checkout != current.checkout ||
            previous.selectedVoucherCode != current.selectedVoucherCode,
        listener: (context, state) {
          if (state.selectedVoucherCode != null &&
              state.selectedVoucherCode!.replaceAll(' ', '') !=
                  _voucherController.text.toUpperCase().replaceAll(' ', '')) {
            _voucherController.text = state.selectedVoucherCode!;
          } else if (state.selectedVoucherCode == null &&
              _voucherController.text.isNotEmpty) {
            _voucherController.clear();
          }

          if (state.isCheckingOut) {
            LoobLoadingOverlay.show(
              context,
              message: state.checkout == null
                  ? 'Securing your order...'
                  : 'Verifying payment...',
            );
          } else {
            LoobLoadingOverlay.hide();
          }

          if (state.checkout != null && !state.isCheckingOut) {
            final countryCode = context.read<CartBloc>().state.countryCode;
            context.read<ActiveOrderCubit>().fetchActiveOrder(
              countryCode: countryCode,
            );
          }

          if (state.error != null) {
            final error = state.error!;
            final isSelectOutletError = error == context.l10n.selectOutletFirst;

            // Clear error in cubit so listener can trigger again if same error occurs
            context.read<CheckoutCubit>().clearError();

            LoobErrorDialog.show(
              context,
              title: state.checkout == null
                  ? 'Checkout Failed'
                  : 'Payment Failed',
              message: error,
              actionLabel: isSelectOutletError
                  ? context.l10n.selectOutletTitle
                  : null,
              onActionPressed: isSelectOutletError
                  ? () => context.push(AppRouter.selectOutlet)
                  : null,
            );
          }
        },
        child: BlocListener<CartBloc, CartState>(
          listenWhen: (previous, current) =>
              previous.loadStatus != current.loadStatus,
          listener: (context, cart) {
            if (!_isRefreshingAvailability) return;
            if (cart.loadStatus == CartLoadStatus.loaded) {
              setState(() {
                _isRefreshingAvailability = false;
                _availabilityRefreshFailed = false;
              });
            } else if (cart.loadStatus == CartLoadStatus.error) {
              setState(() {
                _isRefreshingAvailability = false;
                _availabilityRefreshFailed = true;
              });
            }
          },
          child: BlocBuilder<CheckoutCubit, CheckoutState>(
            builder: (context, state) {
              return BlocBuilder<CartBloc, CartState>(
                builder: (context, cart) {
                  final checkout = state.checkout;
                  final canShowCheckoutButton =
                      !_isRefreshingAvailability &&
                      !_availabilityRefreshFailed &&
                      checkout == null &&
                      state
                          .getItems(cart)
                          .where((item) => item.isAvailable)
                          .isNotEmpty;

                  return PopScope(
                    canPop: checkout == null,
                    onPopInvokedWithResult: (didPop, result) {
                      if (didPop) return;
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: Scaffold(
                      appBar: AppBar(
                        title: Text(
                          checkout == null
                              ? context.l10n.checkoutTitle
                              : context.l10n.paymentTitle,
                        ),
                      ),
                      body: checkout == null
                          ? _buildCheckoutForm(context, cart, state)
                          : CheckoutPaymentResult(
                              checkout: checkout,
                              currency: cart.currency,
                              state: state,
                            ),
                      bottomNavigationBar: canShowCheckoutButton
                          ? CheckoutFloatingButton(
                              cart: cart,
                              state: state,
                              onCheckoutPressed: () =>
                                  _submitCheckout(context, cart),
                            )
                          : null,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutForm(
    BuildContext context,
    CartState cart,
    CheckoutState state,
  ) {
    final theme = Theme.of(context);

    if (_isRefreshingAvailability) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.l10n.checkingCheckoutAvailability,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_availabilityRefreshFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.checkoutAvailabilityRefreshFailed,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _availabilityRefreshFailed = false;
                  });
                  _refreshAvailabilityForSelectedStore();
                },
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    final estimatedDiscount = state.currentVoucherDiscount(
      state.getSubtotal(cart),
    );
    final estimatedPayable = (state.getSubtotal(cart) - estimatedDiscount)
        .clamp(0, state.getSubtotal(cart));

    if (state.getItems(cart).where((item) => item.isAvailable).isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
          child: Text(
            context.l10n.cartEmpty,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      children: [
        if (cart.isSelectedStoreClosed) ...[
          StoreClosedWarning(message: cart.selectedStoreClosureMessage),
          const SizedBox(height: AppSpacing.lg),
        ],
        CheckoutSection(
          title: context.l10n.orderSummary,
          child: Column(
            children: [
              for (final item
                  in state.getItems(cart).where((item) => item.isAvailable))
                CheckoutItemTile(
                  item: item,
                  currency: cart.currency,
                  onEdit: () =>
                      _showEditItemSheet(context, item, cart.currency),
                  onRemove: () {
                    if (widget.buyNowItem != null) {
                      Navigator.pop(context);
                    } else {
                      context.read<CartBloc>().add(CartItemRemoved(item));
                    }
                  },
                ),
              if (estimatedDiscount > 0)
                CheckoutAmountRow(
                  label: context.l10n.voucherLabel,
                  value: '-${estimatedDiscount.toDisplayPrice(cart.currency)}',
                ),
              if (estimatedDiscount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    context.l10n.taxAndTotalConfirm,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ),
              const Divider(height: AppSpacing.xl),
              CheckoutAmountRow(
                label: estimatedDiscount > 0
                    ? context.l10n.estimatedPayable
                    : context.l10n.subtotalLabel,
                value: estimatedPayable.toDisplayPrice(cart.currency),
                isTotal: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        CheckoutVoucherSection(
          voucherController: _voucherController,
          cart: cart,
          state: state,
          onBrowsePressed: () => VouchersBottomSheet.show(context, cart),
        ),
        const SizedBox(height: AppSpacing.lg),
        CheckoutPaymentSection(cart: cart, state: state),
        if (state.error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            state.error!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}
