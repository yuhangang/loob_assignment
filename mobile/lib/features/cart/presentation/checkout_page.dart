import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/di/injection.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../vouchers/data/models/voucher_model.dart';
import '../../vouchers/data/models/voucher_validation_model.dart';
import '../../vouchers/data/repositories/voucher_repository.dart';
import '../data/models/checkout_request_model.dart';
import '../data/models/checkout_response_model.dart';
import '../data/models/payment_method_model.dart';
import '../data/repositories/cart_repository.dart';
import 'bloc/cart_item.dart';
import 'bloc/cart_bloc.dart';
import 'bloc/cart_event.dart';
import 'bloc/cart_state.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final CartRepository _repository = sl<CartRepository>();
  final TextEditingController _voucherController = TextEditingController();
  final Set<String> _mockPaidOrders = <String>{};

  List<PaymentMethodModel> _methods = const [];
  String? _selectedMethod;
  String _fulfillment = 'DINE_IN';
  bool _isLoadingMethods = true;
  bool _isCheckingOut = false;
  String? _error;
  CheckoutResponseModel? _checkout;
  String? _selectedVoucherCode;
  VoucherModel? _selectedVoucher;
  VoucherValidationModel? _voucherValidation;

  String? get _activeVoucherCode {
    final code = _selectedVoucherCode ?? _voucherController.text.trim();
    return code.isEmpty ? null : code.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    final state = context.read<CartBloc>().state;
    _loadPaymentMethods(state.countryCode);
  }

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentMethods(String countryCode) async {
    setState(() {
      _isLoadingMethods = true;
      _error = null;
    });
    try {
      final methods = await _repository.listPaymentMethods(
        countryCode: countryCode,
      );
      if (!mounted) return;
      setState(() {
        _methods = methods;
        _selectedMethod = methods.isNotEmpty ? methods.first.code : null;
        _isLoadingMethods = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMethods = false;
        _error = context.l10n.unableLoadPaymentMethods;
      });
    }
  }

  Future<void> _submitCheckout(CartState cart) async {
    if (_selectedMethod == null) {
      setState(() => _error = context.l10n.selectPaymentMethodFirst);
      return;
    }
    if (cart.storeId <= 0) {
      setState(() => _error = context.l10n.selectOutletFirst);
      return;
    }
    if (cart.isSelectedStoreClosed) {
      setState(() => _error = context.l10n.selectedStoreClosedCheckout);
      return;
    }

    setState(() {
      _isCheckingOut = true;
      _error = null;
    });

    final request = CheckoutRequestModel(
      userId: context.read<CartBloc>().userId,
      storeId: cart.storeId,
      fulfillmentType: _fulfillment,
      voucherCode: _activeVoucherCode,
      paymentMethod: _selectedMethod!,
      idempotencyKey:
          'mobile-${DateTime.now().microsecondsSinceEpoch}-${cart.totalQuantity}',
      items: cart.items
          .where((item) => item.isAvailable)
          .map(
            (item) => CartItemModel(
              menuItemId: item.product.id,
              quantity: item.quantity,
              customizationOptionIds: item.selectedCustomizationIds,
            ),
          )
          .toList(),
    );

    final voucherCode = _activeVoucherCode;
    if (voucherCode != null) {
      try {
        final validation = await sl<VoucherRepository>().validateVoucher(
          countryCode: cart.countryCode,
          body: {
            'user_id': request.userId,
            'store_id': request.storeId,
            'voucher_code': voucherCode,
            'payment_method': request.paymentMethod,
            'items': request.items.map((e) => e.toJson()).toList(),
          },
        );
        if (!mounted) return;
        if (!validation.isValid) {
          setState(() {
            _isCheckingOut = false;
            _voucherValidation = validation;
            _error = validation.reason ?? context.l10n.checkoutFailedMsg;
          });
          return;
        }
        setState(() => _voucherValidation = validation);
      } catch (e) {
        if (!mounted) return;
        final message = e is ApiException
            ? e.message
            : context.l10n.checkoutFailedMsg;
        setState(() {
          _isCheckingOut = false;
          _error = message;
        });
        return;
      }
    }

    try {
      final response = await _repository.checkout(request.toJson());
      if (!mounted) return;
      setState(() {
        _checkout = response;
        _isCheckingOut = false;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : context.l10n.checkoutFailedMsg;
      setState(() {
        _isCheckingOut = false;
        _error = message;
      });
    }
  }

  void _confirmMockPayment(CheckoutResponseModel checkout) {
    setState(() => _mockPaidOrders.add(checkout.orderTrackingId));
    context.read<CartBloc>().add(const CartCleared());
  }

  int _estimateVoucherDiscount(VoucherModel voucher, int subtotal) {
    if (subtotal < voucher.minSpend) return 0;

    var discount = 0;
    switch (voucher.discountType) {
      case 'PERCENTAGE':
        discount = (subtotal * voucher.discountValue / 100).round();
        final cap = voucher.maxDiscountCap;
        if (cap != null && discount > cap) {
          discount = cap;
        }
      case 'FIXED_AMOUNT':
        discount = voucher.discountValue;
    }
    return discount > subtotal ? subtotal : discount;
  }

  int _currentVoucherDiscount(int subtotal) {
    final validation = _voucherValidation;
    if (validation != null && validation.code == _activeVoucherCode) {
      return validation.isValid ? validation.discountAmount : 0;
    }
    final selectedVoucher = _selectedVoucher;
    return selectedVoucher == null
        ? 0
        : _estimateVoucherDiscount(selectedVoucher, subtotal);
  }

  Future<void> _showEditItemSheet(
    BuildContext context,
    CartItem item,
    String currency,
  ) async {
    if (item.product.customizationGroups.isEmpty) return;

    final result = await Navigator.pushNamed(
      context,
      AppRouter.productDetail,
      arguments: {
        'product': item.product,
        'currency': currency,
        'cartItem': item,
      },
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, cart) {
        final checkout = _checkout;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              checkout == null
                  ? context.l10n.checkoutTitle
                  : context.l10n.paymentTitle,
            ),
          ),
          body: checkout == null
              ? _buildCheckoutForm(context, cart)
              : _buildPaymentResult(context, checkout, cart.currency),
          bottomNavigationBar:
              checkout == null &&
                  cart.items.where((item) => item.isAvailable).isNotEmpty
              ? _buildFloatingCheckoutButton(context, cart)
              : null,
        );
      },
    );
  }

  Widget _buildFloatingCheckoutButton(BuildContext context, CartState cart) {
    final theme = Theme.of(context);
    final methods = _methods
        .where((method) => cart.totalPrice >= method.minAmount)
        .toList(growable: false);
    final estimatedDiscount = _currentVoucherDiscount(cart.totalPrice);
    final estimatedPayable = (cart.totalPrice - estimatedDiscount).clamp(
      0,
      cart.totalPrice,
    );

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
                      _isCheckingOut ||
                          _isLoadingMethods ||
                          methods.isEmpty ||
                          cart.isSelectedStoreClosed
                      ? null
                      : () => _submitCheckout(cart),
                  icon: _isCheckingOut
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_rounded, size: 18),
                  label: Text(
                    _isCheckingOut
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

  Widget _buildCheckoutForm(BuildContext context, CartState cart) {
    final theme = Theme.of(context);
    final methods = _methods
        .where((method) => cart.totalPrice >= method.minAmount)
        .toList(growable: false);
    final selectedVoucher = _selectedVoucher;
    final voucherValidation = _voucherValidation;
    final estimatedDiscount = _currentVoucherDiscount(cart.totalPrice);
    final estimatedPayable = (cart.totalPrice - estimatedDiscount).clamp(
      0,
      cart.totalPrice,
    );

    if (cart.items.where((item) => item.isAvailable).isEmpty) {
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
          _StoreClosedWarning(message: cart.selectedStoreClosureMessage),
          const SizedBox(height: AppSpacing.lg),
        ],
        _Section(
          title: context.l10n.orderSummary,
          child: Column(
            children: [
              for (final item in cart.items.where((item) => item.isAvailable))
                _CheckoutItemTile(
                  item: item,
                  currency: cart.currency,
                  onDecrease: () {
                    context.read<CartBloc>().add(
                      CartItemQuantityUpdated(
                        item: item,
                        quantity: item.quantity - 1,
                      ),
                    );
                  },
                  onIncrease: () {
                    context.read<CartBloc>().add(
                      CartItemQuantityUpdated(
                        item: item,
                        quantity: item.quantity + 1,
                      ),
                    );
                  },
                  onEdit: () =>
                      _showEditItemSheet(context, item, cart.currency),
                  onRemove: () {
                    context.read<CartBloc>().add(CartItemRemoved(item));
                  },
                ),
              if (estimatedDiscount > 0)
                _AmountRow(
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
              _AmountRow(
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
        _Section(
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
            selected: {_fulfillment},
            onSelectionChanged: (value) {
              setState(() => _fulfillment = value.first);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Section(
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
                        setState(() {
                          _selectedVoucher = null;
                          _voucherValidation = null;
                          _selectedVoucherCode = value.trim().isEmpty
                              ? null
                              : value.trim().toUpperCase();
                        });
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
              if (_activeVoucherCode != null) ...[
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
                                      _activeVoucherCode &&
                                  !voucherValidation.isValid
                              ? voucherValidation.reason ??
                                    context.l10n.checkoutFailedMsg
                              : selectedVoucher == null
                              ? context.l10n.voucherWillBeValidated(
                                  _activeVoucherCode!,
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
                          setState(() {
                            _voucherController.clear();
                            _selectedVoucherCode = null;
                            _selectedVoucher = null;
                            _voucherValidation = null;
                          });
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
        _Section(
          title: context.l10n.paymentTitle,
          child: _isLoadingMethods
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
                        onTap: () =>
                            setState(() => _selectedMethod = method.code),
                        leading: Icon(
                          _selectedMethod == method.code
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: _selectedMethod == method.code
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
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _error!,
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
  ) {
    final theme = Theme.of(context);
    final isPaid = _mockPaidOrders.contains(checkout.orderTrackingId);

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
          _CheckoutCollectionCard(trackingId: checkout.orderTrackingId),
          const SizedBox(height: AppSpacing.xl),
        ],

        _Section(
          title: context.l10n.paymentDetails,
          child: Column(
            children: [
              _AmountRow(
                label: context.l10n.subtotalLabel,
                value: checkout.subtotal.toDisplayPrice(currency),
              ),
              for (final charge in checkout.charges.where(
                (charge) => !charge.waived,
              ))
                _AmountRow(
                  label: charge.name.isEmpty ? charge.code : charge.name,
                  value: charge.amount.toDisplayPrice(currency),
                ),
              for (final charge in checkout.charges.where(
                (charge) => charge.waived,
              ))
                _AmountRow(
                  label: charge.name.isEmpty ? charge.code : charge.name,
                  value: context.l10n.waivedLabel,
                ),
              _AmountRow(
                label: context.l10n.taxLabel,
                value: checkout.taxAmount.toDisplayPrice(currency),
              ),
              if (checkout.discountAmount > 0)
                _AmountRow(
                  label: context.l10n.discountLabel,
                  value: '-${checkout.discountAmount.toDisplayPrice(currency)}',
                ),
              const Divider(height: AppSpacing.xl),
              _AmountRow(
                label: context.l10n.totalLabel,
                value: checkout.totalAmount.toDisplayPrice(currency),
                isTotal: true,
              ),
              if (checkout.payment != null) ...[
                const SizedBox(height: AppSpacing.md),
                _AmountRow(
                  label: context.l10n.methodLabel,
                  value: checkout.payment!.methodCode,
                ),
                _AmountRow(
                  label: context.l10n.providerLabel,
                  value: checkout.payment!.provider,
                ),
                _AmountRow(
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
              onPressed: () => _confirmMockPayment(checkout),
              icon: const Icon(Icons.verified_rounded),
              label: Text(context.l10n.confirmMockPayment),
            ),
          )
        else
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pushReplacementNamed(
                  context,
                  AppRouter.orderStatus,
                  arguments: {'trackingId': checkout.orderTrackingId},
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

  void _showVouchersBottomSheet(BuildContext context, CartState cart) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder(
              future: sl<VoucherRepository>().getWallet(
                countryCode: cart.countryCode,
                userId: context.read<CartBloc>().userId,
              ),
              builder: (context, snapshot) {
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
                            context.l10n.selectVoucherTitle,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Content
                    Expanded(
                      child: _buildBottomSheetContent(
                        context,
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
        final isEligible = cart.totalPrice >= voucher.minSpend;
        final isSelected = _selectedVoucherCode == voucher.code;

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
                      setState(() {
                        _voucherController.text = voucher.code;
                        _selectedVoucherCode = voucher.code;
                        _selectedVoucher = voucher;
                        _voucherValidation = null;
                      });
                      Navigator.pop(context);
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
                              Text(
                                voucher.code,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: isEligible
                                      ? theme.colorScheme.primary
                                      : Colors.grey,
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
                                      (voucher.minSpend - cart.totalPrice)
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
}

class _CheckoutItemTile extends StatelessWidget {
  final CartItem item;
  final String currency;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _CheckoutItemTile({
    required this.item,
    required this.currency,
    required this.onDecrease,
    required this.onIncrease,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canConfigure = item.product.customizationGroups.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (item.selectedOptions.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        item.selectedOptions
                            .map((option) => option.name)
                            .join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ] else if (item.customizationOptionIds.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        context.l10n.configuredItem,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                item.totalPrice.toDisplayPrice(currency),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                item.unitPrice.toDisplayPrice(currency),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              _CheckoutQuantityStepper(
                quantity: item.quantity,
                onDecrease: onDecrease,
                onIncrease: onIncrease,
              ),
              if (canConfigure) ...[
                const SizedBox(width: AppSpacing.sm),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(context.l10n.choicesBtn),
                ),
              ],
              IconButton(
                tooltip: context.l10n.removeTooltip,
                onPressed: onRemove,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckoutQuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _CheckoutQuantityStepper({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: theme.dividerColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30),
            onPressed: onDecrease,
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30),
            onPressed: onIncrease,
          ),
        ],
      ),
    );
  }
}

class _StoreClosedWarning extends StatelessWidget {
  const _StoreClosedWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message.isEmpty
                  ? context.l10n.selectedStoreClosedCheckout
                  : message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _AmountRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
              color: isTotal ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Checkout Collection Card (compact QR + PIN) ──────────────────────────────

class _CheckoutCollectionCard extends StatelessWidget {
  final String trackingId;

  const _CheckoutCollectionCard({required this.trackingId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pin = trackingId._collectionPin;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  theme.colorScheme.primary.withValues(alpha: 0.25),
                  theme.colorScheme.secondary.withValues(alpha: 0.15),
                ]
              : [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
                ],
        ),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  context.l10n.yourCollectionCode,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // QR + PIN side by side
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // QR code
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: QrImageView(
                    data: trackingId,
                    version: QrVersions.auto,
                    size: 110,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF1A1A2E),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),

                const SizedBox(width: AppSpacing.xl),

                // PIN block
                Column(
                  children: [
                    Text(
                      'PIN',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.55,
                        ),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: pin
                          .split('')
                          .map((d) => _CheckoutPinDigit(digit: d))
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: trackingId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.orderIdCopied),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            trackingId,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.55),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.copy_rounded,
                            size: 11,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            Text(
              'Show this to the staff at the counter',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(
                  alpha: 0.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutPinDigit extends StatelessWidget {
  final String digit;

  const _CheckoutPinDigit({required this.digit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: 40,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        digit,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: theme.colorScheme.primary,
          height: 1,
        ),
      ),
    );
  }
}

extension on String {
  /// Last 4 numeric digits of the tracking ID used as collection PIN.
  String get _collectionPin {
    final digits = replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 4) return digits.substring(digits.length - 4);
    return digits.padLeft(4, '0');
  }
}
