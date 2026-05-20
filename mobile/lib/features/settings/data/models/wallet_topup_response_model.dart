import 'package:loob_app/features/cart/data/models/checkout_response_model.dart';

class WalletTopUpResponseModel {
  final PaymentTransactionResponseModel? payment;

  const WalletTopUpResponseModel({this.payment});

  factory WalletTopUpResponseModel.fromJson(Map<String, dynamic> json) {
    return WalletTopUpResponseModel(
      payment: json['payment'] != null
          ? PaymentTransactionResponseModel.fromJson(
              json['payment'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}
