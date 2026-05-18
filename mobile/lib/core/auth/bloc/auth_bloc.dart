import 'package:flutter_bloc/flutter_bloc.dart';
import '../auth_service.dart';
import '../../network/api_client.dart';
import '../../di/injection.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;

  AuthBloc({AuthService? authService})
      : _authService = authService ?? sl<AuthService>(),
        super(
          (authService ?? sl<AuthService>()).isAuthenticated
              ? Authenticated((authService ?? sl<AuthService>()).currentUser!)
              : const Unauthenticated(),
        ) {
    on<AuthCheckStatus>(_onCheckStatus);
    on<AuthSignInWithPhone>(_onSignInWithPhone);
    on<AuthVerifyOtp>(_onVerifyOtp);
    on<AuthSignOut>(_onSignOut);
    on<AuthSessionExpired>(_onSessionExpired);
  }

  void _onCheckStatus(AuthCheckStatus event, Emitter<AuthState> emit) {
    final user = _authService.currentUser;
    if (user != null) {
      emit(Authenticated(user));
    } else {
      emit(const Unauthenticated());
    }
  }

  Future<void> _onSignInWithPhone(
    AuthSignInWithPhone event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authService.signInWithPhone(event.phoneNumber);
      emit(AuthCodeSent(event.phoneNumber));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onVerifyOtp(
    AuthVerifyOtp event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authService.verifyOtp(event.verificationId, event.code);
      final idToken = await _authService.getIdToken();
      sl<ApiClient>().setAuthToken(idToken);
      emit(Authenticated(user));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onSignOut(
    AuthSignOut event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authService.signOut();
      sl<ApiClient>().setAuthToken(null);
      emit(const Unauthenticated());
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authService.signOut();
      sl<ApiClient>().setAuthToken(null);
      emit(const Unauthenticated(sessionExpired: true));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }
}
