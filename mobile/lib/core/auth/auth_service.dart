/// Abstract auth service interface.
///
/// Allows swapping Firebase for a mock during development.
abstract class AuthService {
  /// The currently authenticated user, or `null` if signed out.
  AuthUser? get currentUser;

  /// Whether the user is currently authenticated.
  bool get isAuthenticated;

  /// Sign in with phone number (triggers OTP flow).
  Future<void> signInWithPhone(String phoneNumber);

  /// Verify the OTP code.
  Future<AuthUser> verifyOtp(String verificationId, String code);

  /// Initialize the authentication service and load persisted session from secure storage.
  Future<void> init();

  /// Sign out the current user.
  Future<void> signOut();

  /// Get the current JWT token for API calls.
  Future<String?> getIdToken({bool forceRefresh = false});
}

/// Lightweight user model for the auth layer.
class AuthUser {
  final String uid;
  final String? displayName;
  final String? phoneNumber;

  const AuthUser({
    required this.uid,
    this.displayName,
    this.phoneNumber,
  });
}
