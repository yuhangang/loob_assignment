import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:loob_app/core/auth/auth_service.dart';
import 'package:loob_app/core/auth/bloc/auth_bloc.dart';
import 'package:loob_app/core/auth/bloc/auth_state.dart';
import 'package:loob_app/core/auth/login_cubit.dart';
import 'package:loob_app/core/config/app_config.dart';
import 'package:loob_app/core/network/api_client.dart';

class RecordingAuthService extends AuthService {
  AuthUser? _user;
  String? phoneRequested;
  String? verificationIdRequested;
  String? otpRequested;

  @override
  AuthUser? get currentUser => _user;

  @override
  bool get isAuthenticated => _user != null;

  @override
  Future<void> init() async {}

  @override
  Future<void> signInWithPhone(String phoneNumber) async {
    phoneRequested = phoneNumber;
  }

  @override
  Future<AuthUser> verifyOtp(String verificationId, String code) async {
    verificationIdRequested = verificationId;
    otpRequested = code;
    _user = AuthUser(uid: 'mock-123', phoneNumber: verificationId);
    return _user!;
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => null;

  @override
  Future<void> signOut() async {
    _user = null;
  }
}

void main() {
  late RecordingAuthService authService;
  late AuthBloc authBloc;

  setUp(() async {
    authService = RecordingAuthService();
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<ApiClient>(
      ApiClient(config: AppConfig.dev()),
    );
    authBloc = AuthBloc(authService: authService);
  });

  tearDown(() async {
    await authBloc.close();
    await GetIt.instance.reset();
  });

  group('LoginCubit', () {
    blocTest<LoginCubit, LoginState>(
      'emits phone validation error when phone is empty',
      build: () => LoginCubit(authBloc: authBloc),
      act: (cubit) => cubit.sendOtp('  '),
      expect: () => [
        const LoginState(validationError: LoginValidationError.phoneRequired),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      'uses selected prefix when requesting OTP',
      build: () => LoginCubit(authBloc: authBloc),
      act: (cubit) async {
        cubit.selectPrefix('+66');
        cubit.sendOtp(' 123456789 ');
        await expectLater(
          authBloc.stream,
          emitsInOrder([
            const AuthLoading(),
            const AuthCodeSent('+66123456789'),
          ]),
        );
      },
      expect: () => [const LoginState(selectedPrefix: '+66')],
      verify: (_) {
        expect(authService.phoneRequested, '+66123456789');
      },
    );

    blocTest<LoginCubit, LoginState>(
      'validates OTP before dispatching verification',
      build: () => LoginCubit(authBloc: authBloc),
      act: (cubit) => cubit.verifyOtp(phone: '123456789', otp: '000000'),
      expect: () => [
        const LoginState(validationError: LoginValidationError.otpIncorrect),
      ],
      verify: (_) {
        expect(authService.verificationIdRequested, isNull);
      },
    );

    blocTest<LoginCubit, LoginState>(
      'maps auth states onto login form state',
      build: () => LoginCubit(authBloc: authBloc),
      act: (cubit) {
        cubit.handleAuthState(const AuthLoading());
        cubit.handleAuthState(const AuthCodeSent('+60123456789'));
        cubit.handleAuthState(const AuthFailure('network failed'));
      },
      expect: () => [
        const LoginState(isLoading: true),
        const LoginState(isOtpSent: true),
        const LoginState(isOtpSent: true, authErrorMessage: 'network failed'),
      ],
    );
  });
}
