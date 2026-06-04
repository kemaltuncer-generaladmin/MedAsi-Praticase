import '../domain/auth_user.dart';
import '../domain/profile_setup.dart';

abstract interface class AuthRepository {
  bool get isConfigured;

  Future<AuthUser?> currentUser();

  Stream<AuthUser?> authStateChanges();

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = true,
  });

  Future<AuthUser> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetCode(String email);

  Future<AuthUser> verifyEmailCode({
    required String email,
    required String code,
  });

  Future<void> resendEmailVerification(String email);

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  Future<AuthUser> completeProfile(ProfileSetup setup);

  Future<void> deleteAccount();

  Future<void> signOut();
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
