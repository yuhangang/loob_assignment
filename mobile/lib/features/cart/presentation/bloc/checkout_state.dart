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
  final VoucherModel? selectedVoucher;
  final VoucherValidationModel? voucherValidation;
  final CartItem? buyNowItem;
  final Set<String> mockPaidOrders;
  final String voucherCodeInput;

  const CheckoutState({
    this.methods = const [],
    this.selectedMethod,
    this.fulfillment = 'DINE_IN',
    this.isLoadingMethods = true,
    this.isCheckingOut = false,
    this.error,
    this.checkout,
    this.selectedVoucherCode,
    this.selectedVoucher,
    this.voucherValidation,
    this.buyNowItem,
    this.mockPaidOrders = const {},
    this.voucherCodeInput = '',
  });

  String? get activeVoucherCode {
    final code = selectedVoucherCode ?? voucherCodeInput.trim();
    return code.isEmpty ? null : code.toUpperCase();
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

  int estimateVoucherDiscount(VoucherModel voucher, int subtotal) {
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

  int currentVoucherDiscount(int subtotal) {
    final validation = voucherValidation;
    if (validation != null && validation.code == activeVoucherCode) {
      return validation.isValid ? validation.discountAmount : 0;
    }
    final selected = selectedVoucher;
    return selected == null
        ? 0
        : estimateVoucherDiscount(selected, subtotal);
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
    VoucherModel? Function()? selectedVoucher,
    VoucherValidationModel? Function()? voucherValidation,
    CartItem? Function()? buyNowItem,
    Set<String>? mockPaidOrders,
    String? voucherCodeInput,
  }) {
    return CheckoutState(
      methods: methods ?? this.methods,
      selectedMethod: selectedMethod != null ? selectedMethod() : this.selectedMethod,
      fulfillment: fulfillment ?? this.fulfillment,
      isLoadingMethods: isLoadingMethods ?? this.isLoadingMethods,
      isCheckingOut: isCheckingOut ?? this.isCheckingOut,
      error: error != null ? error() : this.error,
      checkout: checkout != null ? checkout() : this.checkout,
      selectedVoucherCode: selectedVoucherCode != null ? selectedVoucherCode() : this.selectedVoucherCode,
      selectedVoucher: selectedVoucher != null ? selectedVoucher() : this.selectedVoucher,
      voucherValidation: voucherValidation != null ? voucherValidation() : this.voucherValidation,
      buyNowItem: buyNowItem != null ? buyNowItem() : this.buyNowItem,
      mockPaidOrders: mockPaidOrders ?? this.mockPaidOrders,
      voucherCodeInput: voucherCodeInput ?? this.voucherCodeInput,
    );
  }
}
