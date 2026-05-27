import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_user.dart' as domain;
import '../domain/profile_setup.dart';
import 'auth_config.dart';
import 'praticase_auth_storage.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({
    required SupabaseClient client,
    required AuthConfig config,
    PratiCaseAuthStorage? authStorage,
  }) : _client = client,
       _config = config,
       _authStorage = authStorage;

  final SupabaseClient _client;
  final AuthConfig _config;
  final PratiCaseAuthStorage? _authStorage;

  @override
  bool get isConfigured => true;

  @override
  Future<domain.AuthUser?> currentUser() async {
    final user = await _activeUser();
    if (user == null) return null;
    return user.toDomain(profileCompleted: await _profileCompleted(user));
  }

  @override
  Stream<domain.AuthUser?> authStateChanges() {
    return _client.auth.onAuthStateChange.asyncMap((state) async {
      if (state.event == AuthChangeEvent.signedOut) return null;
      final user = state.session?.user ?? _client.auth.currentUser;
      if (user == null) return null;
      return user.toDomain(profileCompleted: await _profileCompleted(user));
    });
  }

  @override
  Future<domain.AuthUser> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    try {
      await _authStorage?.setRememberMe(rememberMe);
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure('Giriş tamamlanamadı.');
      }
      return user.toDomain(profileCompleted: await _profileCompleted(user));
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
        data: {
          'full_name': fullName.trim(),
          'source_app': 'praticase',
          'accepted_terms': true,
          'consent_version': 'praticase-auth-v1',
        },
        emailRedirectTo: _config.redirectUrl,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure('Kayıt tamamlanamadı.');
      }
      await _tryUpsertProfile(
        user: user,
        fullName: fullName,
        acceptedTerms: true,
      );
      return user.toDomain();
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
      await _upsertProfile(user: user);
      return user.toDomain();
    } on AuthException catch (error) {
      throw AuthFailure(_friendlyMessage(error.message));
    }
  }

  @override
  Future<void> resendEmailVerification(String email) async {
    try {
      await _client.auth.resend(
        email: email.trim(),
        type: OtpType.signup,
        emailRedirectTo: _config.redirectUrl,
      );
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
      if (code.trim().isNotEmpty) {
        await _client.auth.verifyOTP(
          email: email.trim(),
          token: code,
          type: OtpType.recovery,
        );
      }
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (error) {
      throw AuthFailure(_friendlyMessage(error.message));
    }
  }

  @override
  Future<domain.AuthUser> completeProfile(ProfileSetup setup) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AuthFailure('Profil kurulumu için oturum gerekli.');
      }
      await _client
          .schema('praticase')
          .rpc(
            'complete_user_profile',
            params: {
              'p_grade': setup.grade,
              'p_class_level': _classLevel(setup.grade),
              'p_target_exam': setup.targetExam,
              'p_target_branches': setup.targetBranches,
              'p_target': _profileTarget(setup),
              'p_daily_goal': setup.dailyGoal,
              'p_exam_date': setup.examDate?.toIso8601String(),
            },
          );
      final refreshed = _client.auth.currentUser ?? user;
      return refreshed.toDomain(profileCompleted: true);
    } on AuthException catch (error) {
      throw AuthFailure(_friendlyMessage(error.message));
    } on PostgrestException catch (error) {
      throw AuthFailure(_friendlyMessage(error.message));
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  Future<User?> _activeUser() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;
    if (!session.isExpired) return session.user;
    try {
      final response = await _client.auth.refreshSession();
      return response.user ?? _client.auth.currentUser;
    } on AuthException {
      await _authStorage?.removePersistedSession();
      return null;
    }
  }

  Future<void> _tryUpsertProfile({
    required User user,
    String? fullName,
    bool acceptedTerms = false,
  }) async {
    try {
      await _upsertProfile(
        user: user,
        fullName: fullName,
        acceptedTerms: acceptedTerms,
      );
    } on Object {
      // Confirmed-email projects may not issue a session at signup time.
      // The shared profile row is created after OTP verification in that case.
    }
  }

  Future<void> _upsertProfile({
    required User user,
    String? fullName,
    bool acceptedTerms = false,
    ProfileSetup? setup,
  }) async {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final name = (fullName ?? metadata['full_name'] as String? ?? '').trim();
    final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final firstName = parts.isEmpty ? null : parts.first;
    final lastName = parts.length <= 1 ? null : parts.skip(1).join(' ');
    final now = DateTime.now().toUtc().toIso8601String();

    final profile = <String, dynamic>{
      'id': user.id,
      'email': user.email,
      'target': setup == null ? 'Staj + TUS' : _profileTarget(setup),
      'theme_key': 'clinical',
      'updated_at': now,
      if (setup != null) 'class_level': _classLevel(setup.grade),
      if (acceptedTerms) ...{
        'legal_terms_accepted_at': now,
        'privacy_notice_accepted_at': now,
        'consent_version': 'praticase-auth-v1',
      },
    };
    if (firstName != null) profile['first_name'] = firstName;
    if (lastName != null) profile['last_name'] = lastName;

    await _client.from('profiles').upsert(profile, onConflict: 'id');

    if (setup != null) {
      await _client.schema('praticase').from('user_app_settings').upsert({
        'user_id': user.id,
        'updated_at': now,
      }, onConflict: 'user_id');
    }
  }

  Future<bool> _profileCompleted(User user) async {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    if (metadata['praticase_profile_completed'] == true) return true;
    try {
      final profile = await _client
          .from('profiles')
          .select('class_level,target')
          .eq('id', user.id)
          .maybeSingle();
      final classLevel = profile?['class_level'];
      return classLevel is String && classLevel.trim().isNotEmpty;
    } on Object {
      return false;
    }
  }

  String _classLevel(String grade) {
    if (grade.startsWith('1')) return '1';
    if (grade.startsWith('2')) return '2';
    if (grade.startsWith('3')) return '3';
    if (grade.startsWith('4')) return '4';
    if (grade.startsWith('5')) return '5';
    if (grade.startsWith('6')) return '6';
    return 'Mezun';
  }

  String _profileTarget(ProfileSetup setup) {
    final branches = setup.targetBranches
        .map((branch) => branch.trim())
        .where((branch) => branch.isNotEmpty)
        .join(', ');
    if (branches.isEmpty) return setup.targetExam;
    return '${setup.targetExam} - $branches';
  }

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
