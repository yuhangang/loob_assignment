import 'auth_service.dart';

/// Mock auth service for local development.
///
/// Returns a hardcoded user without requiring Firebase configuration.
class MockAuthService implements AuthService {
  AuthUser? _user;

  MockAuthService() {
    // Auto-sign-in with a mock user for development convenience.
    _user = const AuthUser(
      uid: 'mock_user_001',
      displayName: 'Dev User',
      phoneNumber: '+60123456789',
    );
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
    _user = const AuthUser(
      uid: 'mock_user_001',
      displayName: 'Dev User',
      phoneNumber: '+60123456789',
    );
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
  }

  @override
  Future<String?> getIdToken() async {
    return _user != null ? 'mock-jwt-token-for-development' : null;
  }
}
