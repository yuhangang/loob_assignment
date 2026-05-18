import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:loob_app/core/auth/auth_service.dart';
import 'package:loob_app/core/auth/bloc/auth_bloc.dart';
import 'package:loob_app/core/config/app_config.dart';
import 'package:loob_app/core/network/api_client.dart';

class FakeAuthService extends AuthService {
  int refreshCount = 0;
  bool signedOut = false;

  @override
  AuthUser? get currentUser => const AuthUser(uid: 'user_123', phoneNumber: '+60123456789');

  @override
  bool get isAuthenticated => true;

  @override
  Future<void> init() async {}

  @override
  Future<void> signInWithPhone(String phoneNumber) async {}

  @override
  Future<AuthUser> verifyOtp(String verificationId, String code) async {
    return const AuthUser(uid: 'user_123');
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      refreshCount++;
      return 'refreshed-jwt-token';
    }
    return 'initial-jwt-token';
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  late FakeAuthService fakeAuth;
  late ApiClient apiClient;

  setUp(() {
    final sl = GetIt.instance;
    sl.reset();
    fakeAuth = FakeAuthService();
    sl.registerSingleton<AuthService>(fakeAuth);
    sl.registerSingleton<AuthBloc>(AuthBloc(authService: fakeAuth));
    apiClient = ApiClient(config: AppConfig.dev());
  });

  group('ApiClient Interceptor Tests', () {
    test('Intercepts 401 invalid token, refreshes token and retries successfully', () async {
      int requestCount = 0;
      apiClient.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount++;
            if (requestCount == 1) {
              // Return 401 unauthorized invalid token on first request
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 401,
                    data: {'error': 'invalid bearer token'},
                  ),
                ),
              );
            } else {
              // Return 200 OK on retry
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'status': 'success'},
                ),
              );
            }
          },
        ),
      );

      final response = await apiClient.dio.get('/test-endpoint');
      expect(response.statusCode, 200);
      expect(response.data['status'], 'success');
      expect(fakeAuth.refreshCount, 1);
    });

    test('Logging interceptor is added when enableLogging is true', () {
      final client = ApiClient(config: AppConfig.dev(enableLogging: true));
      final hasLogInterceptor = client.dio.interceptors.any((i) => i is LogInterceptor);
      expect(hasLogInterceptor, isTrue);
    });

    test('Logging interceptor is not added when enableLogging is false', () {
      final client = ApiClient(config: AppConfig.dev(enableLogging: false));
      final hasLogInterceptor = client.dio.interceptors.any((i) => i is LogInterceptor);
      expect(hasLogInterceptor, isFalse);
    });
  });
}
