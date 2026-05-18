import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../vouchers/domain/repositories/voucher_repository.dart';
import '../data/models/checkout_response_model.dart';
import 'bloc/cart_item.dart';
import 'bloc/cart_bloc.dart';
import 'bloc/cart_event.dart';
import 'bloc/cart_state.dart';
import 'bloc/checkout_cubit.dart';
import 'bloc/checkout_state.dart';
import 'widgets/checkout_amount_row.dart';
import 'widgets/checkout_collection_card.dart';
import 'widgets/checkout_item_tile.dart';
import 'widgets/checkout_section.dart';
import 'widgets/store_closed_warning.dart';

class CheckoutPage extends StatefulWidget {
  final CartItem? buyNowItem;

  const CheckoutPage({super.key, this.buyNowItem});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _voucherController = TextEditingController();

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  void _submitCheckout(BuildContext context, CartState cart) {
    context.read<CheckoutCubit>().submitCheckout(
      cart: cart,
      userId: context.read<CartBloc>().userId,
      errSelectPaymentMethod: context.l10n.selectPaymentMethodFirst,
      errSelectOutlet: context.l10n.selectOutletFirst,
      errStoreClosed: context.l10n.selectedStoreClosedCheckout,
      errCheckoutFailed: context.l10n.checkoutFailedMsg,
    );
  }

  void _confirmMockPayment(
    BuildContext context,
    CheckoutResponseModel checkout,
  ) {
    context.read<CheckoutCubit>().confirmMockPayment(
      checkout.orderTrackingId,
      () => context.read<CartBloc>().add(const CartCleared()),
    );
  }

  void _confirmRemoveItem(BuildContext parentContext, CartItem item) {
    final theme = Theme.of(parentContext);
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(parentContext.l10n.removeItemTitle),
        content: Text(parentContext.l10n.removeItemContent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(parentContext.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: () {
              parentContext.read<CartBloc>().add(
                CartItemQuantityUpdated(item: item, quantity: 0),
              );
              Navigator.pop(dialogContext);
            },
            child: Text(parentContext.l10n.itemUnavailableRemove),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveBuyNowItem(BuildContext parentContext) {
    final theme = Theme.of(parentContext);
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(parentContext.l10n.removeItemTitle),
        content: Text(parentContext.l10n.removeItemContent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(parentContext.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(parentContext);
            },
            child: Text(parentContext.l10n.itemUnavailableRemove),
          ),
        ],
      ),
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

    final quantity = result['quantity'] as int? ?? item.quantity;
    final action = result['action'] as String? ?? 'update';
    final selectionsMap = result['selections'] as Map<dynamic, dynamic>? ?? {};
    final selectedIds = <int>[];
    for (final ids in selectionsMap.values) {
      if (ids is List) {
        selectedIds.addAll(ids.whereType<int>());
      }
    }
    final selectedOptions = item.product.customizationGroups
        .expand((group) => group.options)
        .where((option) => selectedIds.contains(option.id))
        .toList();

    if (widget.buyNowItem != null) {
      if (action == 'buy_now') {
        context.read<CheckoutCubit>().updateBuyNowItemCustomizations(
          selectedOptions: selectedOptions,
          selectedIds: selectedIds,
          quantity: 1,
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
      create: (providerContext) =>
          CheckoutCubit(buyNowItem: widget.buyNowItem)..loadPaymentMethods(
            providerContext.read<CartBloc>().state.countryCode,
            providerContext.l10n.unableLoadPaymentMethods,
          ),
      child: BlocBuilder<CheckoutCubit, CheckoutState>(
        builder: (context, state) {
          return BlocBuilder<CartBloc, CartState>(
            builder: (context, cart) {
              final checkout = state.checkout;
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    checkout == null
                        ? context.l10n.checkoutTitle
                        : context.l10n.paymentTitle,
                  ),
                ),
                body: checkout == null
                    ? _buildCheckoutForm(context, cart, state)
                    : _buildPaymentResult(
                        context,
                        checkout,
                        cart.currency,
                        state,
                      ),
                bottomNavigationBar:
                    checkout == null &&
                        state
                            .getItems(cart)
                            .where((item) => item.isAvailable)
                            .isNotEmpty
                    ? _buildFloatingCheckoutButton(context, cart, state)
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFloatingCheckoutButton(
    BuildContext context,
    CartState cart,
    CheckoutState state,
  ) {
    final theme = Theme.of(context);
    final methods = state.methods
        .where((method) => state.getSubtotal(cart) >= method.minAmount)
        .toList(growable: false);
    final estimatedDiscount = state.currentVoucherDiscount(
      state.getSubtotal(cart),
    );
    final estimatedPayable = (state.getSubtotal(cart) - estimatedDiscount)
        .clamp(0, state.getSubtotal(cart));

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.totalAmount,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.6,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      estimatedPayable.toDisplayPrice(cart.currency),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed:
                      state.isCheckingOut ||
                          state.isLoadingMethods ||
                          methods.isEmpty ||
                          cart.isSelectedStoreClosed
                      ? null
                      : () => _submitCheckout(context, cart),
                  icon: state.isCheckingOut
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_rounded, size: 18),
                  label: Text(
                    state.isCheckingOut
                        ? context.l10n.placingOrder
                        : context.l10n.placeOrder,
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
    final methods = state.methods
        .where((method) => state.getSubtotal(cart) >= method.minAmount)
        .toList(growable: false);
    final selectedVoucher = state.selectedVoucher;
    final voucherValidation = state.voucherValidation;
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
                  onDecrease: () {
                    if (widget.buyNowItem != null) {
                      if (state.buyNowItem!.quantity > 1) {
                        context.read<CheckoutCubit>().updateBuyNowItemQuantity(
                          state.buyNowItem!.quantity - 1,
                        );
                      } else {
                        _confirmRemoveBuyNowItem(context);
                      }
                    } else {
                      if (item.quantity == 1) {
                        _confirmRemoveItem(context, item);
                      } else {
                        context.read<CartBloc>().add(
                          CartItemQuantityUpdated(
                            item: item,
                            quantity: item.quantity - 1,
                          ),
                        );
                      }
                    }
                  },
                  onIncrease: () {
                    if (widget.buyNowItem != null) {
                      context.read<CheckoutCubit>().updateBuyNowItemQuantity(
                        state.buyNowItem!.quantity + 1,
                      );
                    } else {
                      context.read<CartBloc>().add(
                        CartItemQuantityUpdated(
                          item: item,
                          quantity: item.quantity + 1,
                        ),
                      );
                    }
                  },
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
        CheckoutSection(
          title: context.l10n.fulfillmentLabel,
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'DINE_IN',
                label: Text(context.l10n.dineInOption),
              ),
              ButtonSegment(
                value: 'TAKEAWAY',
                label: Text(context.l10n.takeawayOption),
              ),
              ButtonSegment(
                value: 'DELIVERY',
                label: Text(context.l10n.deliveryOption),
              ),
            ],
            selected: {state.fulfillment},
            onSelectionChanged: (value) {
              context.read<CheckoutCubit>().selectFulfillment(value.first);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        CheckoutSection(
          title: context.l10n.voucherLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _voucherController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: context.l10n.optionalVoucherCode,
                        prefixIcon: const Icon(
                          Icons.confirmation_number_outlined,
                        ),
                      ),
                      onChanged: (value) {
                        context.read<CheckoutCubit>().onVoucherCodeChanged(
                          value,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton.icon(
                    onPressed: () => _showVouchersBottomSheet(context, cart),
                    icon: const Icon(Icons.local_activity_rounded, size: 18),
                    label: Text(context.l10n.browseBtn),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (state.activeVoucherCode != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.15,
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          voucherValidation != null &&
                                  voucherValidation.code ==
                                      state.activeVoucherCode &&
                                  !voucherValidation.isValid
                              ? voucherValidation.reason ??
                                    context.l10n.checkoutFailedMsg
                              : selectedVoucher == null
                              ? context.l10n.voucherWillBeValidated(
                                  state.activeVoucherCode!,
                                )
                              : context.l10n.voucherApplied(
                                  selectedVoucher.code,
                                ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          _voucherController.clear();
                          context.read<CheckoutCubit>().clearVoucher();
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          color: theme.colorScheme.primary,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        CheckoutSection(
          title: context.l10n.paymentTitle,
          child: state.isLoadingMethods
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: CircularProgressIndicator(),
                  ),
                )
              : methods.isEmpty
              ? Text(
                  context.l10n.noPaymentMethods,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                )
              : Column(
                  children: [
                    for (final method in methods)
                      ListTile(
                        onTap: () => context
                            .read<CheckoutCubit>()
                            .selectPaymentMethod(method.code),
                        leading: Icon(
                          state.selectedMethod == method.code
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: state.selectedMethod == method.code
                              ? theme.colorScheme.primary
                              : null,
                        ),
                        title: Text(method.displayName),
                        subtitle: Text(method.description),
                        trailing: Icon(
                          method.providerCode == 'mock_gateway'
                              ? Icons.bolt_rounded
                              : Icons.account_balance_wallet_outlined,
                        ),
                      ),
                  ],
                ),
        ),
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

  Widget _buildPaymentResult(
    BuildContext context,
    CheckoutResponseModel checkout,
    String currency,
    CheckoutState state,
  ) {
    final theme = Theme.of(context);
    final isPaid = state.mockPaidOrders.contains(checkout.orderTrackingId);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      children: [
        Icon(
          isPaid ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
          size: 72,
          color: isPaid ? Colors.green : theme.colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          isPaid
              ? context.l10n.mockPaymentApproved
              : context.l10n.paymentPending,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          checkout.orderTrackingId,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── Collection QR + PIN (shown once payment is confirmed) ────────
        if (isPaid) ...[
          CheckoutCollectionCard(trackingId: checkout.orderTrackingId),
          const SizedBox(height: AppSpacing.xl),
        ],

        CheckoutSection(
          title: context.l10n.paymentDetails,
          child: Column(
            children: [
              CheckoutAmountRow(
                label: context.l10n.subtotalLabel,
                value: checkout.subtotal.toDisplayPrice(currency),
              ),
              for (final charge in checkout.charges.where(
                (charge) => !charge.waived,
              ))
                CheckoutAmountRow(
                  label: charge.name.isEmpty ? charge.code : charge.name,
                  value: charge.amount.toDisplayPrice(currency),
                ),
              for (final charge in checkout.charges.where(
                (charge) => charge.waived,
              ))
                CheckoutAmountRow(
                  label: charge.name.isEmpty ? charge.code : charge.name,
                  value: context.l10n.waivedLabel,
                ),
              CheckoutAmountRow(
                label: context.l10n.taxLabel,
                value: checkout.taxAmount.toDisplayPrice(currency),
              ),
              if (checkout.discountAmount > 0)
                CheckoutAmountRow(
                  label: context.l10n.discountLabel,
                  value: '-${checkout.discountAmount.toDisplayPrice(currency)}',
                ),
              const Divider(height: AppSpacing.xl),
              CheckoutAmountRow(
                label: context.l10n.totalLabel,
                value: checkout.totalAmount.toDisplayPrice(currency),
                isTotal: true,
              ),
              if (checkout.payment != null) ...[
                const SizedBox(height: AppSpacing.md),
                CheckoutAmountRow(
                  label: context.l10n.methodLabel,
                  value: checkout.payment!.methodCode,
                ),
                CheckoutAmountRow(
                  label: context.l10n.providerLabel,
                  value: checkout.payment!.provider,
                ),
                CheckoutAmountRow(
                  label: context.l10n.statusLabel,
                  value: checkout.payment!.status,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (!isPaid)
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () => _confirmMockPayment(context, checkout),
              icon: const Icon(Icons.verified_rounded),
              label: Text(context.l10n.confirmMockPayment),
            ),
          )
        else
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                context.pushReplacement(
                  AppRouter.orderStatus,
                  extra: {'trackingId': checkout.orderTrackingId},
                );
              },
              icon: const Icon(Icons.receipt_long_rounded),
              label: Text(context.l10n.viewOrderStatus),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  void _showVouchersBottomSheet(BuildContext parentContext, CartState cart) {
    final theme = Theme.of(parentContext);
    final checkoutCubit = parentContext.read<CheckoutCubit>();

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (modalContext) {
        return BlocProvider.value(
          value: checkoutCubit,
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            expand: false,
            builder: (scrollContext, scrollController) {
              return FutureBuilder(
                future: sl<IVoucherRepository>().getWallet(
                  countryCode: cart.countryCode,
                  userId: scrollContext.read<CartBloc>().userId,
                ),
                builder: (futureContext, snapshot) {
                  return Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.sm,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              futureContext.l10n.selectVoucherTitle,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(futureContext),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Content
                      Expanded(
                        child: _buildBottomSheetContent(
                          futureContext,
                          snapshot,
                          cart,
                          scrollController,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetContent(
    BuildContext context,
    AsyncSnapshot snapshot,
    CartState cart,
    ScrollController scrollController,
  ) {
    final theme = Theme.of(context);

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.l10n.unableLoadVouchers,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                snapshot.error.toString(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.6,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final wallet = snapshot.data;
    final vouchers = wallet?.vouchers ?? const [];
    final state = context.read<CheckoutCubit>().state;

    if (vouchers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_activity_outlined,
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                size: 64,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.l10n.noVouchersAvailable,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.l10n.noActiveVouchersSub,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.6,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: vouchers.length,
      itemBuilder: (context, index) {
        final voucher = vouchers[index];
        final isEligible = state.getSubtotal(cart) >= voucher.minSpend;
        final isSelected = state.selectedVoucherCode == voucher.code;

        return Opacity(
          opacity: isEligible ? 1.0 : 0.6,
          child: Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              side: BorderSide(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.dividerColor.withValues(alpha: 0.08),
                width: isSelected ? 2 : 1,
              ),
            ),
            elevation: isSelected ? 2 : 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              onTap: isEligible
                  ? () {
                      context.read<CheckoutCubit>().selectVoucher(voucher);
                      _voucherController.text = voucher.code;
                      Navigator.pop(modalContextOf(context));
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Row(
                  children: [
                    // Discount badge container
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color:
                            (isEligible
                                    ? theme.colorScheme.primary
                                    : Colors.grey)
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          voucher.discountType == 'PERCENTAGE'
                              ? '${voucher.discountValue}%'
                              : voucher.discountValue.toDisplayPrice(
                                  cart.currency,
                                ),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: isEligible
                                ? theme.colorScheme.primary
                                : Colors.grey,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Details column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  voucher.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 16,
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            voucher.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.6),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(
                                    ClipboardData(text: voucher.code),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.l10n.voucherCodeCopied,
                                      ),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xxs,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (isEligible
                                                ? theme.colorScheme.primary
                                                : Colors.grey)
                                            .withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusSm,
                                    ),
                                    border: Border.all(
                                      color:
                                          (isEligible
                                                  ? theme.colorScheme.primary
                                                  : Colors.grey)
                                              .withValues(alpha: 0.15),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        voucher.code,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color: isEligible
                                                  ? theme.colorScheme.primary
                                                  : Colors.grey,
                                              letterSpacing: 0.5,
                                            ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 12,
                                        color:
                                            (isEligible
                                                    ? theme.colorScheme.primary
                                                    : Colors.grey)
                                                .withValues(alpha: 0.7),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (!isEligible)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xxs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusSm,
                                    ),
                                  ),
                                  child: Text(
                                    context.l10n.spendMoreToUse(
                                      (voucher.minSpend -
                                              state.getSubtotal(cart))
                                          .toDisplayPrice(cart.currency),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Helper to pop the modal bottom sheet
  BuildContext modalContextOf(BuildContext context) {
    return Navigator.of(context).context;
  }
}
