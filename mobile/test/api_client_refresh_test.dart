import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:loob_app/core/auth/auth_service.dart';
import 'package:loob_app/core/auth/bloc/auth_bloc.dart';
import 'package:loob_app/core/config/app_config.dart';
import 'package:loob_app/core/network/api_client.dart';

String createMockJwt({required bool expired}) {
  final header = {'alg': 'none', 'typ': 'JWT'};
  final expTime = expired
      ? DateTime.now().subtract(const Duration(minutes: 10))
      : DateTime.now().add(const Duration(hours: 1));
  final payload = {
    'exp': expTime.millisecondsSinceEpoch ~/ 1000,
    'sub': 'user_123',
  };
  final headerStr = base64Url.encode(utf8.encode(json.encode(header))).replaceAll('=', '');
  final payloadStr = base64Url.encode(utf8.encode(json.encode(payload))).replaceAll('=', '');
  return '$headerStr.$payloadStr.mock-signature';
}

class MockHttpClientAdapter implements HttpClientAdapter {
  int requestCount = 0;
  RequestOptions? lastRequestOptions;
  int responseStatusCode;
  String responseBody;

  MockHttpClientAdapter({
    this.responseStatusCode = 200,
    this.responseBody = '{"status": "success"}',
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    lastRequestOptions = options;
    return ResponseBody.fromString(
      responseBody,
      responseStatusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeAuthService extends AuthService {
  int refreshCount = 0;
  bool signedOut = false;
  String? currentToken;

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
      currentToken = createMockJwt(expired: false);
      return currentToken;
    }
    return currentToken;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  late FakeAuthService fakeAuth;
  late ApiClient apiClient;

  setUp(() async {
    final sl = GetIt.instance;
    await sl.reset();
    fakeAuth = FakeAuthService();
    sl.registerSingleton<AuthService>(fakeAuth);
    sl.registerSingleton<AuthBloc>(AuthBloc(authService: fakeAuth));
    apiClient = ApiClient(config: AppConfig.dev());
  });

  group('ApiClient Interceptor Tests', () {
    test('Automatically renews expired token before calling the API', () async {
      // 1. Generate an expired token and set it in the client and auth service
      final expiredToken = createMockJwt(expired: true);
      apiClient.setAuthToken(expiredToken);
      fakeAuth.currentToken = expiredToken;

      final mockAdapter = MockHttpClientAdapter();
      apiClient.dio.httpClientAdapter = mockAdapter;

      // 2. Make request
      final response = await apiClient.dio.get('/test-endpoint');

      // 3. Verify results
      expect(response.statusCode, 200);
      expect(response.data['status'], 'success');
      expect(fakeAuth.refreshCount, 1); // should have refreshed once

      // The token in the actual request header should be the refreshed (non-expired) one
      final lastRequestOptions = mockAdapter.lastRequestOptions;
      expect(lastRequestOptions, isNotNull);
      final authHeader = lastRequestOptions!.headers['Authorization'];
      expect(authHeader, isNotNull);
      expect(authHeader, startsWith('Bearer '));
      final sentToken = authHeader.substring(7);
      expect(sentToken, isNot(expiredToken));
      expect(sentToken, fakeAuth.currentToken);
    });

    test('Does not renew valid non-expired token before calling the API', () async {
      // 1. Generate a valid token and set it in the client
      final validToken = createMockJwt(expired: false);
      apiClient.setAuthToken(validToken);
      fakeAuth.currentToken = validToken;

      final mockAdapter = MockHttpClientAdapter();
      apiClient.dio.httpClientAdapter = mockAdapter;

      // 2. Make request
      final response = await apiClient.dio.get('/test-endpoint');

      // 3. Verify results
      expect(response.statusCode, 200);
      expect(fakeAuth.refreshCount, 0); // no refresh should have happened

      final authHeader = mockAdapter.lastRequestOptions!.headers['Authorization'];
      expect(authHeader, 'Bearer $validToken');
    });

    test('Triggers immediate session timeout when capturing 401 invalid bearer token error', () async {
      // 1. Generate a valid token so no pre-request refresh happens
      final validToken = createMockJwt(expired: false);
      apiClient.setAuthToken(validToken);
      fakeAuth.currentToken = validToken;

      // 2. Configure HTTP adapter to return 401 invalid bearer token
      final mockAdapter = MockHttpClientAdapter(
        responseStatusCode: 401,
        responseBody: '{"error": "invalid bearer token"}',
      );
      apiClient.dio.httpClientAdapter = mockAdapter;

      // 3. We expect the request to fail with a 401 DioException
      try {
        await apiClient.dio.get('/test-endpoint');
        fail('Should have thrown DioException');
      } catch (e) {
        expect(e, isA<DioException>());
        final dioError = e as DioException;
        expect(dioError.response?.statusCode, 401);
      }

      // 4. Verify session timeout was triggered immediately without another refresh attempt
      expect(fakeAuth.signedOut, isTrue); // signOut called
      expect(fakeAuth.refreshCount, 0); // no refresh should have been tried in onError
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

    test('Preserves request-specific country and language headers', () async {
      apiClient.setCountryCode('MY');
      apiClient.setLanguage('en-US');

      final mockAdapter = MockHttpClientAdapter();
      apiClient.dio.httpClientAdapter = mockAdapter;

      await apiClient.dio.get(
        '/test-endpoint',
        options: Options(
          headers: {
            'X-Country-Code': 'TH',
            'X-Language': 'th-TH',
            'Accept-Language': 'th-TH',
          },
        ),
      );

      final headers = mockAdapter.lastRequestOptions!.headers;
      expect(headers['X-Country-Code'], 'TH');
      expect(headers['X-Language'], 'th-TH');
      expect(headers['Accept-Language'], 'th-TH');
    });
  });
}
