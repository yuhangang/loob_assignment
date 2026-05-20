import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/auth_bloc.dart';
import 'bloc/auth_event.dart';
import 'bloc/auth_state.dart';

enum LoginValidationError { phoneRequired, otpRequired, otpIncorrect }

class LoginState extends Equatable {
  final String selectedPrefix;
  final bool isOtpSent;
  final bool isLoading;
  final LoginValidationError? validationError;
  final String? authErrorMessage;

  const LoginState({
    this.selectedPrefix = '+60',
    this.isOtpSent = false,
    this.isLoading = false,
    this.validationError,
    this.authErrorMessage,
  });

  LoginState copyWith({
    String? selectedPrefix,
    bool? isOtpSent,
    bool? isLoading,
    LoginValidationError? Function()? validationError,
    String? Function()? authErrorMessage,
  }) {
    return LoginState(
      selectedPrefix: selectedPrefix ?? this.selectedPrefix,
      isOtpSent: isOtpSent ?? this.isOtpSent,
      isLoading: isLoading ?? this.isLoading,
      validationError: validationError != null
          ? validationError()
          : this.validationError,
      authErrorMessage: authErrorMessage != null
          ? authErrorMessage()
          : this.authErrorMessage,
    );
  }

  @override
  List<Object?> get props => [
    selectedPrefix,
    isOtpSent,
    isLoading,
    validationError,
    authErrorMessage,
  ];
}

class LoginCubit extends Cubit<LoginState> {
  final AuthBloc _authBloc;

  LoginCubit({required AuthBloc authBloc})
    : _authBloc = authBloc,
      super(const LoginState());

  void selectPrefix(String prefix) {
    emit(
      state.copyWith(
        selectedPrefix: prefix,
        validationError: () => null,
        authErrorMessage: () => null,
      ),
    );
  }

  void sendOtp(String phone) {
    final normalizedPhone = phone.trim();
    if (normalizedPhone.isEmpty) {
      emit(
        state.copyWith(
          validationError: () => LoginValidationError.phoneRequired,
          authErrorMessage: () => null,
        ),
      );
      return;
    }

    _authBloc.add(
      AuthSignInWithPhone('${state.selectedPrefix}$normalizedPhone'),
    );
  }

  void verifyOtp({required String phone, required String otp}) {
    final normalizedOtp = otp.trim();
    if (normalizedOtp.isEmpty) {
      emit(
        state.copyWith(
          validationError: () => LoginValidationError.otpRequired,
          authErrorMessage: () => null,
        ),
      );
      return;
    }
    if (normalizedOtp != '123456') {
      emit(
        state.copyWith(
          validationError: () => LoginValidationError.otpIncorrect,
          authErrorMessage: () => null,
        ),
      );
      return;
    }

    final normalizedPhone = phone.trim();
    final fullPhone = '${state.selectedPrefix}$normalizedPhone';
    _authBloc.add(
      AuthVerifyOtp(verificationId: fullPhone, code: normalizedOtp),
    );
  }

  void backToPhoneEntry() {
    emit(
      state.copyWith(
        isOtpSent: false,
        validationError: () => null,
        authErrorMessage: () => null,
      ),
    );
  }

  void handleAuthState(AuthState authState) {
    if (authState is AuthCodeSent) {
      emit(
        state.copyWith(
          isOtpSent: true,
          isLoading: false,
          validationError: () => null,
          authErrorMessage: () => null,
        ),
      );
    } else if (authState is Authenticated) {
      emit(
        state.copyWith(
          isLoading: false,
          validationError: () => null,
          authErrorMessage: () => null,
        ),
      );
    } else if (authState is AuthFailure) {
      emit(
        state.copyWith(
          isLoading: false,
          validationError: () => null,
          authErrorMessage: () => authState.message,
        ),
      );
    } else if (authState is AuthLoading) {
      emit(
        state.copyWith(
          isLoading: true,
          validationError: () => null,
          authErrorMessage: () => null,
        ),
      );
    }
  }
}
