import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loob_app/features/menu/data/models/catalog_model.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/api_exception.dart';
import '../../../vouchers/data/models/voucher_model.dart';
import '../../../vouchers/domain/repositories/voucher_repository.dart';
import '../../data/models/checkout_request_model.dart';
import '../../domain/repositories/cart_repository.dart';
import 'cart_item.dart';
import 'cart_state.dart';
import 'checkout_state.dart';

class CheckoutCubit extends Cubit<CheckoutState> {
  final ICartRepository _cartRepository;
  final IVoucherRepository _voucherRepository;

  CheckoutCubit({
    ICartRepository? cartRepository,
    IVoucherRepository? voucherRepository,
    CartItem? buyNowItem,
  }) : _cartRepository = cartRepository ?? sl<ICartRepository>(),
       _voucherRepository = voucherRepository ?? sl<IVoucherRepository>(),
       super(CheckoutState(buyNowItem: buyNowItem));

  Future<void> loadPaymentMethods(String countryCode, String errorMsg) async {
    emit(state.copyWith(isLoadingMethods: true, error: () => null));
    try {
      final methods = await _cartRepository.listPaymentMethods(
        countryCode: countryCode,
      );
      emit(
        state.copyWith(
          methods: methods,
          selectedMethod: () => methods.isNotEmpty ? methods.first.code : null,
          isLoadingMethods: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoadingMethods: false, error: () => errorMsg));
    }
  }

  void selectPaymentMethod(String methodCode) {
    emit(state.copyWith(selectedMethod: () => methodCode));
  }

  void onVoucherCodeChanged(String value) {
    emit(
      state.copyWith(
        selectedVoucher: () => null,
        voucherValidation: () => null,
        selectedVoucherCode: () =>
            value.trim().isEmpty ? null : value.trim().toUpperCase(),
        voucherCodeInput: value,
      ),
    );
  }

  void selectVoucher(VoucherModel voucher) {
    emit(
      state.copyWith(
        voucherCodeInput: voucher.code,
        selectedVoucherCode: () => voucher.code,
        selectedVoucher: () => voucher,
        voucherValidation: () => null,
      ),
    );
  }

  void clearVoucher() {
    emit(
      state.copyWith(
        voucherCodeInput: '',
        selectedVoucherCode: () => null,
        selectedVoucher: () => null,
        voucherValidation: () => null,
      ),
    );
  }

  void updateBuyNowItemQuantity(int quantity) {
    if (state.buyNowItem == null) return;
    emit(
      state.copyWith(
        buyNowItem: () => state.buyNowItem!.copyWith(quantity: quantity),
      ),
    );
  }

  void updateBuyNowItemCustomizations({
    required List<CustomizationOptionModel> selectedOptions,
    required List<int> selectedIds,
    required int quantity,
  }) {
    if (state.buyNowItem == null) return;
    emit(
      state.copyWith(
        buyNowItem: () => state.buyNowItem!.copyWith(
          selectedOptions: selectedOptions,
          customizationOptionIds: selectedIds,
          quantity: quantity,
        ),
      ),
    );
  }

  Future<void> confirmMockPayment({
    required String orderTrackingId,
    required String transactionId,
    required String mockSecret,
    required VoidCallback onCartCleared,
  }) async {
    emit(state.copyWith(isCheckingOut: true, error: () => null));
    try {
      await _cartRepository.confirmMockPayment(
        transactionId: transactionId,
        secret: mockSecret,
      );
      final updatedPaidOrders = Set<String>.from(state.mockPaidOrders)
        ..add(orderTrackingId);
      emit(state.copyWith(
        mockPaidOrders: updatedPaidOrders,
        isCheckingOut: false,
      ));
      if (state.buyNowItem == null) {
        onCartCleared();
      }
    } catch (e) {
      final message = e is ApiException ? e.message : 'Failed to confirm payment';
      emit(state.copyWith(isCheckingOut: false, error: () => message));
    }
  }

  Future<void> submitCheckout({
    required CartState cart,
    required String userId,
    required String errSelectPaymentMethod,
    required String errSelectOutlet,
    required String errStoreClosed,
    required String errCheckoutFailed,
  }) async {
    if (state.selectedMethod == null) {
      emit(state.copyWith(error: () => errSelectPaymentMethod));
      return;
    }
    if (cart.storeId <= 0) {
      emit(state.copyWith(error: () => errSelectOutlet));
      return;
    }
    if (cart.isSelectedStoreClosed) {
      emit(state.copyWith(error: () => errStoreClosed));
      return;
    }

    emit(state.copyWith(isCheckingOut: true, error: () => null));

    final request = CheckoutRequestModel(
      userId: userId,
      storeId: cart.storeId,
      fulfillmentType: state.fulfillment,
      voucherCode: state.activeVoucherCode,
      paymentMethod: state.selectedMethod!,
      idempotencyKey:
          'mobile-${DateTime.now().microsecondsSinceEpoch}-${state.getTotalQuantity(cart)}',
      items: state
          .getItems(cart)
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

    final voucherCode = state.activeVoucherCode;
    if (voucherCode != null) {
      try {
        final validation = await _voucherRepository.validateVoucher(
          countryCode: cart.countryCode,
          body: {
            'store_id': request.storeId,
            'voucher_code': voucherCode,
            'payment_method': request.paymentMethod,
            'items': request.items.map((e) => e.toJson()).toList(),
          },
        );
        if (!validation.isValid) {
          emit(
            state.copyWith(
              isCheckingOut: false,
              voucherValidation: () => validation,
              error: () => validation.reason ?? errCheckoutFailed,
            ),
          );
          return;
        }
        emit(state.copyWith(voucherValidation: () => validation));
      } catch (e) {
        final message = e is ApiException ? e.message : errCheckoutFailed;
        emit(state.copyWith(isCheckingOut: false, error: () => message));
        return;
      }
    }

    try {
      final response = await _cartRepository.checkout(request.toJson());
      emit(state.copyWith(checkout: () => response, isCheckingOut: false));
    } catch (e) {
      final message = e is ApiException ? e.message : errCheckoutFailed;
      emit(state.copyWith(isCheckingOut: false, error: () => message));
    }
  }
}
