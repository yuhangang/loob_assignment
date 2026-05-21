import '../../../vouchers/data/models/voucher_model.dart';
import '../../../vouchers/data/models/voucher_validation_model.dart';
import '../../data/models/payment_method_model.dart';
import '../../data/models/checkout_response_model.dart';
import 'cart_item.dart';
import 'cart_state.dart';

class CheckoutState {
  final List<PaymentMethodModel> methods;
  final String? selectedMethod;
  final String fulfillment;
  final bool isLoadingMethods;
  final bool isCheckingOut;
  final String? error;
  final CheckoutResponseModel? checkout;
  final String? selectedVoucherCode;
  final List<VoucherModel> selectedVouchers;
  final VoucherValidationModel? voucherValidation;
  final CartItem? buyNowItem;
  final Set<String> mockPaidOrders;
  final String voucherCodeInput;

  const CheckoutState({
    this.methods = const [],
    this.selectedMethod,
    this.fulfillment = 'TAKEAWAY',
    this.isLoadingMethods = true,
    this.isCheckingOut = false,
    this.error,
    this.checkout,
    this.selectedVoucherCode,
    this.selectedVouchers = const [],
    this.voucherValidation,
    this.buyNowItem,
    this.mockPaidOrders = const {},
    this.voucherCodeInput = '',
  });

  String? get activeVoucherCode {
    final codes = activeVoucherCodes;
    return codes.isEmpty ? null : codes.first;
  }

  List<String> get activeVoucherCodes {
    final raw = selectedVoucherCode ?? voucherCodeInput.trim();
    return raw
        .split(RegExp(r'[\s,]+'))
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toSet()
        .toList();
  }

  int getSubtotal(CartState cart) {
    return buyNowItem != null ? buyNowItem!.totalPrice : cart.totalPrice;
  }

  int getTotalQuantity(CartState cart) {
    return buyNowItem != null ? buyNowItem!.quantity : cart.totalQuantity;
  }

  List<CartItem> getItems(CartState cart) {
    return buyNowItem != null ? [buyNowItem!] : cart.items;
  }

  int estimateVouchersDiscount(List<VoucherModel> vouchers, int subtotal) {
    var remainingSubtotal = subtotal;
    var totalDiscount = 0;
    for (final voucher in vouchers) {
      if (remainingSubtotal < voucher.minSpend) continue;

      var discount = 0;
      switch (voucher.discountType) {
        case 'PERCENTAGE':
          discount = (remainingSubtotal * voucher.discountValue / 100).round();
          final cap = voucher.maxDiscountCap;
          if (cap != null && discount > cap) {
            discount = cap;
          }
        case 'FIXED_AMOUNT':
          discount = voucher.discountValue;
      }
      if (discount > remainingSubtotal) {
        discount = remainingSubtotal;
      }
      totalDiscount += discount;
      remainingSubtotal -= discount;
    }
    return totalDiscount;
  }

  int currentVoucherDiscount(int subtotal) {
    final validation = voucherValidation;
    if (validation != null) {
      final active = activeVoucherCodes;
      if (active.contains(validation.code.toUpperCase())) {
        return validation.isValid ? validation.discountAmount : 0;
      }
    }
    return estimateVouchersDiscount(selectedVouchers, subtotal);
  }

  CheckoutState copyWith({
    List<PaymentMethodModel>? methods,
    String? Function()? selectedMethod,
    String? fulfillment,
    bool? isLoadingMethods,
    bool? isCheckingOut,
    String? Function()? error,
    CheckoutResponseModel? Function()? checkout,
    String? Function()? selectedVoucherCode,
    List<VoucherModel>? selectedVouchers,
    VoucherValidationModel? Function()? voucherValidation,
    CartItem? Function()? buyNowItem,
    Set<String>? mockPaidOrders,
    String? voucherCodeInput,
  }) {
    return CheckoutState(
      methods: methods ?? this.methods,
      selectedMethod: selectedMethod != null
          ? selectedMethod()
          : this.selectedMethod,
      fulfillment: fulfillment ?? this.fulfillment,
      isLoadingMethods: isLoadingMethods ?? this.isLoadingMethods,
      isCheckingOut: isCheckingOut ?? this.isCheckingOut,
      error: error != null ? error() : this.error,
      checkout: checkout != null ? checkout() : this.checkout,
      selectedVoucherCode: selectedVoucherCode != null
          ? selectedVoucherCode()
          : this.selectedVoucherCode,
      selectedVouchers: selectedVouchers ?? this.selectedVouchers,
      voucherValidation: voucherValidation != null
          ? voucherValidation()
          : this.voucherValidation,
      buyNowItem: buyNowItem != null ? buyNowItem() : this.buyNowItem,
      mockPaidOrders: mockPaidOrders ?? this.mockPaidOrders,
      voucherCodeInput: voucherCodeInput ?? this.voucherCodeInput,
    );
  }
}
