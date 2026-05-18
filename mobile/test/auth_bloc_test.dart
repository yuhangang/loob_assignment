import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:loob_app/core/auth/auth_service.dart';
import 'package:loob_app/core/auth/bloc/auth_bloc.dart';
import 'package:loob_app/core/auth/bloc/auth_event.dart';
import 'package:loob_app/core/auth/bloc/auth_state.dart';
import 'package:loob_app/core/config/app_config.dart';
import 'package:loob_app/core/network/api_client.dart';

class FakeAuthService extends AuthService {
  AuthUser? _user;
  bool shouldThrow = false;

  @override
  AuthUser? get currentUser => _user;

  @override
  bool get isAuthenticated => _user != null;

  @override
  Future<void> init() async {}

  @override
  Future<void> signInWithPhone(String phoneNumber) async {
    if (shouldThrow) throw Exception('SMS rate limit exceeded');
  }

  @override
  Future<AuthUser> verifyOtp(String verificationId, String code) async {
    if (shouldThrow) throw Exception('Invalid OTP');
    _user = const AuthUser(uid: 'mock-123', phoneNumber: '+60123456789');
    return _user!;
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      'mock-jwt-token';

  @override
  Future<void> signOut() async {
    _user = null;
  }
}

void main() {
  late FakeAuthService fakeAuthService;

  setUp(() async {
    fakeAuthService = FakeAuthService();
    final slInstance = GetIt.instance;
    await slInstance.reset();
    slInstance.registerSingleton<AuthService>(fakeAuthService);
    slInstance.registerSingleton<ApiClient>(ApiClient(config: AppConfig.dev()));
  });

  group('AuthBloc tests', () {
    blocTest<AuthBloc, AuthState>(
      'emits Unauthenticated initially when user is logged out',
      build: () => AuthBloc(authService: fakeAuthService),
      act: (bloc) => bloc.add(const AuthCheckStatus()),
      expect: () => [const Unauthenticated()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits Authenticated initially when user is already logged in',
      build: () {
        fakeAuthService._user = const AuthUser(
          uid: 'mock-123',
          phoneNumber: '+60123456789',
        );
        return AuthBloc(authService: fakeAuthService);
      },
      act: (bloc) => bloc.add(const AuthCheckStatus()),
      expect: () => [
        const Authenticated(
          AuthUser(uid: 'mock-123', phoneNumber: '+60123456789'),
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'signInWithPhone success flow',
      build: () => AuthBloc(authService: fakeAuthService),
      act: (bloc) => bloc.add(const AuthSignInWithPhone('+60123456789')),
      expect: () => [const AuthLoading(), const AuthCodeSent('+60123456789')],
    );

    blocTest<AuthBloc, AuthState>(
      'signInWithPhone error flow',
      build: () {
        fakeAuthService.shouldThrow = true;
        return AuthBloc(authService: fakeAuthService);
      },
      act: (bloc) => bloc.add(const AuthSignInWithPhone('+60123456789')),
      expect: () => [const AuthLoading(), isA<AuthFailure>()],
    );

    blocTest<AuthBloc, AuthState>(
      'verifyOtp success flow',
      build: () => AuthBloc(authService: fakeAuthService),
      act: (bloc) => bloc.add(
        const AuthVerifyOtp(verificationId: '+60123456789', code: '123456'),
      ),
      expect: () => [
        const AuthLoading(),
        const Authenticated(
          AuthUser(uid: 'mock-123', phoneNumber: '+60123456789'),
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'verifyOtp failure flow',
      build: () {
        fakeAuthService.shouldThrow = true;
        return AuthBloc(authService: fakeAuthService);
      },
      act: (bloc) => bloc.add(
        const AuthVerifyOtp(verificationId: '+60123456789', code: '000000'),
      ),
      expect: () => [const AuthLoading(), isA<AuthFailure>()],
    );

    blocTest<AuthBloc, AuthState>(
      'signOut success flow',
      build: () {
        fakeAuthService._user = const AuthUser(
          uid: 'mock-123',
          phoneNumber: '+60123456789',
        );
        return AuthBloc(authService: fakeAuthService);
      },
      act: (bloc) => bloc.add(const AuthSignOut()),
      expect: () => [const AuthLoading(), const Unauthenticated()],
    );
  });
}
