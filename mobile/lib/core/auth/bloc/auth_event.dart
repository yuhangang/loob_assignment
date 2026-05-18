import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckStatus extends AuthEvent {
  const AuthCheckStatus();
}

class AuthSignInWithPhone extends AuthEvent {
  final String phoneNumber;

  const AuthSignInWithPhone(this.phoneNumber);

  @override
  List<Object?> get props => [phoneNumber];
}

class AuthVerifyOtp extends AuthEvent {
  final String verificationId;
  final String code;

  const AuthVerifyOtp({required this.verificationId, required this.code});

  @override
  List<Object?> get props => [verificationId, code];
}

class AuthSignOut extends AuthEvent {
  const AuthSignOut();
}

class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}

