import 'checkout_response_model.dart';

class PriceBreakdownModel {
  final int subtotal;
  final List<ChargeLineModel> charges;
  final int taxAmount;
  final int discountAmount;
  final int totalAmount;

  const PriceBreakdownModel({
    required this.subtotal,
    required this.charges,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
  });

  int get chargesTotal => charges
      .where((charge) => !charge.waived)
      .fold(0, (sum, charge) => sum + charge.totalAmount);

  int get payableTaxAmount {
    final computed = totalAmount - subtotal - chargesTotal + discountAmount;
    if (computed <= 0) {
      return 0;
    }
    if (computed >= taxAmount) {
      return taxAmount;
    }
    return computed;
  }

  int get includedTaxAmount {
    final included = taxAmount - payableTaxAmount;
    return included > 0 ? included : 0;
  }
}
