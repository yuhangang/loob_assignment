import 'package:flutter_test/flutter_test.dart';
import 'package:loob_app/features/cart/data/models/checkout_response_model.dart';
import 'package:loob_app/features/cart/data/models/order_status_model.dart';
import 'package:loob_app/features/cart/data/models/payment_method_model.dart';
import 'package:loob_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:loob_app/features/cart/presentation/bloc/cart_item.dart';
import 'package:loob_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:loob_app/features/cart/presentation/bloc/checkout_cubit.dart';
import 'package:loob_app/features/menu/data/models/catalog_model.dart';
import 'package:loob_app/features/orders/data/models/local_order_model.dart';
import 'package:loob_app/features/orders/data/models/order_list_page_model.dart';
import 'package:loob_app/features/vouchers/data/models/voucher_model.dart';
import 'package:loob_app/features/vouchers/data/models/voucher_validation_model.dart';
import 'package:loob_app/features/vouchers/data/models/wallet_model.dart';
import 'package:loob_app/features/vouchers/domain/repositories/voucher_repository.dart';

class FakeCartRepository implements ICartRepository {
  @override
  Future<List<PaymentMethodModel>> listPaymentMethods({
    required String countryCode,
    int? brandId,
  }) async => const [];

  @override
  Future<CheckoutResponseModel> checkout(Map<String, dynamic> body) {
    throw UnimplementedError();
  }

  @override
  Future<List<OrderStatusModel>> listOrders({
    required String userId,
    required String countryCode,
    int page = 1,
    int limit = 20,
    List<String> statuses = const [],
  }) {
    throw UnimplementedError();
  }

  @override
  Future<OrderListPageModel> listOrdersPage({
    required String userId,
    required String countryCode,
    int page = 1,
    int limit = 20,
    List<String> statuses = const [],
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<LocalOrderItemModel>> listReorderItems({
    required String userId,
    required String countryCode,
    int limit = 8,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<OrderStatusModel> getOrderStatus(String trackingId) {
    throw UnimplementedError();
  }

  @override
  Future<OrderStatusModel> collectOrder(String trackingId) {
    throw UnimplementedError();
  }

  @override
  Future<void> confirmMockPayment({
    required String transactionId,
    required String secret,
  }) async {}
}

class FakeVoucherRepository implements IVoucherRepository {
  final List<List<String>> validationRequests = [];

  @override
  Future<WalletModel> getWallet({
    String? countryCode,
    String? userId,
    int brandId = 0,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<VoucherValidationModel> validateVoucher({
    String? countryCode,
    required Map<String, dynamic> body,
  }) async {
    final codes = (body['voucher_codes'] as List<dynamic>)
        .map((code) => code as String)
        .toList();
    validationRequests.add(codes);
    if (codes.length > 1) {
      return VoucherValidationModel(
        code: body['voucher_code'] as String,
        isValid: false,
        reason: 'voucher not eligible',
        eligibleSubtotal: 0,
        discountAmount: 0,
      );
    }
    return VoucherValidationModel(
      code: body['voucher_code'] as String,
      isValid: true,
      eligibleSubtotal: 1200,
      discountAmount: 100,
    );
  }
}

void main() {
  test('replaces current voucher when tapped voucher is valid alone', () async {
    final voucherRepository = FakeVoucherRepository();
    final cubit = CheckoutCubit(
      cartRepository: FakeCartRepository(),
      voucherRepository: voucherRepository,
    );
    cubit.selectVoucher(voucher('OLD10'));

    final result = await cubit.validateAndSelectVoucher(
      voucher: voucher('NEW10'),
      cart: cart(),
    );

    expect(result.isValid, isTrue);
    expect(result.replacedSelection, isTrue);
    expect(cubit.state.activeVoucherCodes, ['NEW10']);
    expect(cubit.state.selectedVouchers.map((v) => v.code), ['NEW10']);
    expect(voucherRepository.validationRequests, [
      ['OLD10', 'NEW10'],
      ['NEW10'],
    ]);
  });
}

VoucherModel voucher(String code) {
  return VoucherModel(
    id: code.hashCode,
    code: code,
    title: code,
    description: '',
    voucherType: 'CART_DISCOUNT',
    discountType: 'FIXED_AMOUNT',
    discountValue: 100,
    minSpend: 0,
    status: 'AVAILABLE',
    startsAt: '',
    expiresAt: '',
  );
}

CartState cart() {
  return CartState(
    storeId: 1,
    countryCode: 'MY',
    items: [
      CartItem(
        product: const ProductModel(
          id: 100,
          skuCode: 'SKU-100',
          isAvailable: true,
          name: 'Milk Tea',
          description: '',
          media: MediaModel(imageUrlSm: '', imageUrlLg: ''),
          basePrice: 1200,
          dietaryTags: [],
          customizationGroups: [],
        ),
        selectedOptions: const [],
        quantity: 1,
      ),
    ],
  );
}
