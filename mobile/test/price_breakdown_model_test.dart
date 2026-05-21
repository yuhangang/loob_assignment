import 'package:flutter_test/flutter_test.dart';
import 'package:loob_app/features/cart/data/models/checkout_response_model.dart';
import 'package:loob_app/features/cart/data/models/price_breakdown_model.dart';

void main() {
  group('PriceBreakdownModel', () {
    test('treats fully inclusive tax as informational only', () {
      const breakdown = PriceBreakdownModel(
        subtotal: 2280,
        charges: [
          ChargeLineModel(
            code: 'PACKAGING_FEE',
            name: 'Packaging fee',
            scope: 'ORDER',
            amount: 94,
            taxableAmount: 94,
            taxAmount: 6,
            totalAmount: 100,
            taxable: true,
            taxInclusive: false,
            waived: false,
          ),
        ],
        taxAmount: 78,
        discountAmount: 1000,
        totalAmount: 1380,
      );

      expect(breakdown.chargesTotal, 100);
      expect(breakdown.payableTaxAmount, 0);
      expect(breakdown.includedTaxAmount, 78);
    });

    test('keeps tax additive for tax-exclusive item totals', () {
      const breakdown = PriceBreakdownModel(
        subtotal: 1000,
        charges: [
          ChargeLineModel(
            code: 'PACKAGING_FEE',
            name: 'Packaging fee',
            scope: 'ORDER',
            amount: 100,
            taxableAmount: 100,
            taxAmount: 6,
            totalAmount: 106,
            taxable: true,
            taxInclusive: false,
            waived: false,
          ),
        ],
        taxAmount: 66,
        discountAmount: 0,
        totalAmount: 1166,
      );

      expect(breakdown.chargesTotal, 106);
      expect(breakdown.payableTaxAmount, 60);
      expect(breakdown.includedTaxAmount, 6);
    });
  });
}
