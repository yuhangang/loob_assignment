import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_service.dart';

/// Mock auth service for local development.
///
/// Returns a hardcoded user without requiring Firebase configuration.
class MockAuthService implements AuthService {
  AuthUser? _user;
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _cachedToken;
  DateTime? _tokenExpiry;

  MockAuthService();

  @override
  Future<void> init() async {
    try {
      final uid = await _secureStorage.read(key: 'auth_user_uid');
      final phone = await _secureStorage.read(key: 'auth_user_phone');
      final displayName = await _secureStorage.read(key: 'auth_user_display_name');
      final token = await _secureStorage.read(key: 'auth_token');

      if (uid != null && token != null) {
        _user = AuthUser(
          uid: uid,
          displayName: displayName == null || displayName.isEmpty ? null : displayName,
          phoneNumber: phone == null || phone.isEmpty ? null : phone,
        );
        _cachedToken = token;
        
        // Try parsing expiry from stored token
        try {
          final segments = token.split('.');
          if (segments.length == 3) {
            final payloadData = base64Url.decode(base64Url.normalize(segments[1]));
            final payload = json.decode(utf8.decode(payloadData)) as Map<String, dynamic>;
            final exp = payload['exp'] as int?;
            if (exp != null) {
              _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
            }
          }
        } catch (e) {
          debugPrint('[MockAuthService] Error parsing stored token: $e');
        }
      }
    } catch (e) {
      debugPrint('[MockAuthService] Initialization failed: $e');
    }
  }

  @override
  AuthUser? get currentUser => _user;

  @override
  bool get isAuthenticated => _user != null;

  @override
  Future<void> signInWithPhone(String phoneNumber) async {
    // No-op in mock mode.
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<AuthUser> verifyOtp(String verificationId, String code) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _user = AuthUser(
      uid: 'mock_user_001',
      displayName: 'Dev User',
      phoneNumber: verificationId, // Use the verified phone number
    );

    // Save to secure storage
    await _secureStorage.write(key: 'auth_user_uid', value: _user!.uid);
    await _secureStorage.write(key: 'auth_user_phone', value: _user!.phoneNumber ?? '');
    await _secureStorage.write(key: 'auth_user_display_name', value: _user!.displayName ?? '');

    // Force refresh / generate a new token and cache/save it
    await getIdToken(forceRefresh: true);

    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _cachedToken = null;
    _tokenExpiry = null;
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'auth_user_uid');
    await _secureStorage.delete(key: 'auth_user_phone');
    await _secureStorage.delete(key: 'auth_user_display_name');
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (_user == null) return null;

    // Return cached token if not expired and not forceRefresh
    if (!forceRefresh && _cachedToken != null && _tokenExpiry != null && _tokenExpiry!.isAfter(DateTime.now())) {
      return _cachedToken;
    }

    // Generate a fresh token. Let's make it expire in 1 hour.
    final duration = const Duration(hours: 1);
    _tokenExpiry = DateTime.now().add(duration);

    final header = {'alg': 'none', 'typ': 'JWT'};
    final payload = {
      'aud': 'mock-project-id',
      'iss': 'https://securetoken.google.com/mock-project-id',
      'sub': _user!.uid,
      'exp': _tokenExpiry!.millisecondsSinceEpoch ~/ 1000,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'phone_number': _user!.phoneNumber,
    };
    final headerStr = base64Url.encode(utf8.encode(json.encode(header))).replaceAll('=', '');
    final payloadStr = base64Url.encode(utf8.encode(json.encode(payload))).replaceAll('=', '');
    _cachedToken = '$headerStr.$payloadStr.mock-signature';

    // Store the updated token
    await _secureStorage.write(key: 'auth_token', value: _cachedToken!);

    return _cachedToken;
  }
}
