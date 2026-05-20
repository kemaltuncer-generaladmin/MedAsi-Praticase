import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_user.dart' as domain;
import '../domain/profile_setup.dart';
import 'auth_config.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({
    required SupabaseClient client,
    required AuthConfig config,
  }) : _client = client,
       _config = config;

  final SupabaseClient _client;
  final AuthConfig _config;

  @override
  bool get isConfigured => true;

  @override
  Future<domain.AuthUser?> currentUser() async {
    return _client.auth.currentUser?.toDomain();
  }

  @override
  Future<domain.AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure('Giriş tamamlanamadı.');
      }
      return user.toDomain();
    } on AuthException catch (error) {
      throw AuthFailure(_friendlyMessage(error.message));
    }
  }

  @override
  Future<domain.AuthUser> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim(), 'source_app': 'praticase'},
        emailRedirectTo: _config.redirectUrl,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure('Kayıt tamamlanamadı.');
      }
      return user.toDomain();
    } on AuthException catch (error) {
      throw AuthFailure(_friendlyMessage(error.message));
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _config.redirectUrl,
      );
    } on AuthException catch (error) {
      throw AuthFailure(_friendlyMessage(error.message));
    }
  }

  @override
  Future<void> sendPasswordResetCode(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: _config.redirectUrl,
      );
    } on AuthException catch (error) {
      throw AuthFailure(_friendlyMessage(error.message));
    }
  }

  @override
  Future<domain.AuthUser> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    try {
      final response = await _client.auth.verifyOTP(
        email: email.trim(),
        token: code,
        type: OtpType.email,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure('Doğrulama tamamlanamadı.');
      }
      return user.toDomain();
    } on AuthException catch (error) {
      throw AuthFailure(_friendlyMessage(error.message));
    }
  }

  @override
  Future<void> resendEmailVerification(String email) async {
    try {
      await _client.auth.resend(email: email.trim(), type: OtpType.signup);
    } on AuthException catch (error) {
      throw AuthFailure(_friendlyMessage(error.message));
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _client.auth.verifyOTP(
        email: email.trim(),
        token: code,
        type: OtpType.recovery,
      );
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (error) {
      throw AuthFailure(_friendlyMessage(error.message));
    }
  }

  @override
  Future<domain.AuthUser> completeProfile(ProfileSetup setup) async {
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(
          data: {
            'praticase_profile_completed': true,
            'grade': setup.grade,
            'target_branches': setup.targetBranches,
            'daily_goal': setup.dailyGoal,
            'osce_exam_date': setup.examDate?.toIso8601String(),
          },
        ),
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure('Profil güncellenemedi.');
      }
      return user.toDomain(profileCompleted: true);
    } on AuthException catch (error) {
      throw AuthFailure(_friendlyMessage(error.message));
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  String _friendlyMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login')) {
      return 'E-posta veya şifre hatalı.';
    }
    if (lower.contains('email not confirmed')) {
      return 'E-posta adresin doğrulanmamış.';
    }
    if (lower.contains('already registered') ||
        lower.contains('already exists')) {
      return 'Bu e-posta ile kayıtlı bir hesap var.';
    }
    if (lower.contains('otp')) {
      return 'Doğrulama kodunu kontrol et.';
    }
    return 'İşlem tamamlanamadı. Lütfen tekrar dene.';
  }
}

extension on User {
  domain.AuthUser toDomain({bool? profileCompleted}) {
    final metadata = userMetadata ?? const <String, dynamic>{};
    return domain.AuthUser(
      id: id,
      email: email ?? '',
      fullName: metadata['full_name'] as String?,
      emailVerified: emailConfirmedAt != null,
      profileCompleted:
          profileCompleted ??
          (metadata['praticase_profile_completed'] as bool? ?? false),
    );
  }
}
