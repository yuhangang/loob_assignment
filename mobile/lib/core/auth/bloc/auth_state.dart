import 'package:equatable/equatable.dart';
import '../auth_service.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthCodeSent extends AuthState {
  final String phoneNumber;

  const AuthCodeSent(this.phoneNumber);

  @override
  List<Object?> get props => [phoneNumber];
}

class Authenticated extends AuthState {
  final AuthUser user;

  const Authenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class Unauthenticated extends AuthState {
  final bool sessionExpired;
  const Unauthenticated({this.sessionExpired = false});

  @override
  List<Object?> get props => [sessionExpired];
}

class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}
