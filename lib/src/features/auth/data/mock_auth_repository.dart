import 'dart:async';

import '../domain/auth_user.dart';
import '../domain/profile_setup.dart';
import 'auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  AuthUser? _user;
  String? _pendingEmail;

  @override
  bool get isConfigured => false;

  @override
  Future<AuthUser?> currentUser() async => _user;

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _shortDelay();
    if (!_isEmail(email) || password.length < 8) {
      throw const AuthFailure('E-posta veya şifre hatalı.');
    }
    _user = AuthUser(
      id: 'mock-medasi-user',
      email: email,
      fullName: 'PratiCase Kullanıcısı',
      emailVerified: true,
    );
    return _user!;
  }

  @override
  Future<AuthUser> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await _shortDelay();
    if (fullName.trim().length < 3) {
      throw const AuthFailure('Ad soyad alanını kontrol et.');
    }
    if (!_isEmail(email)) {
      throw const AuthFailure('Geçerli bir e-posta gir.');
    }
    if (password.length < 8) {
      throw const AuthFailure('Şifre en az 8 karakter olmalı.');
    }
    _pendingEmail = email;
    _user = AuthUser(id: 'mock-medasi-user', email: email, fullName: fullName);
    return _user!;
  }

  @override
  Future<void> signInWithGoogle() async {
    await _shortDelay();
    _user = const AuthUser(
      id: 'mock-google-user',
      email: 'google@medasi.test',
      fullName: 'Google Kullanıcısı',
      emailVerified: true,
    );
  }

  @override
  Future<void> sendPasswordResetCode(String email) async {
    await _shortDelay();
    if (!_isEmail(email)) {
      throw const AuthFailure('Geçerli bir e-posta gir.');
    }
    _pendingEmail = email;
  }

  @override
  Future<AuthUser> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    await _shortDelay();
    if (code.length != 6) {
      throw const AuthFailure('Kod hatalı. Lütfen tekrar dene.');
    }
    _user = AuthUser(
      id: 'mock-medasi-user',
      email: email,
      fullName: _user?.fullName,
      emailVerified: true,
    );
    return _user!;
  }

  @override
  Future<void> resendEmailVerification(String email) async {
    await sendPasswordResetCode(email);
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _shortDelay();
    if (_pendingEmail != null && _pendingEmail != email) {
      throw const AuthFailure('Kod bu e-posta adresi için geçerli değil.');
    }
    if (code.length != 6 || newPassword.length < 8) {
      throw const AuthFailure('Kod veya yeni şifre hatalı.');
    }
  }

  @override
  Future<AuthUser> completeProfile(ProfileSetup setup) async {
    await _shortDelay();
    if (setup.targetBranches.isEmpty) {
      throw const AuthFailure('En az bir hedef branş seç.');
    }
    final existing = _user;
    _user = AuthUser(
      id: existing?.id ?? 'mock-medasi-user',
      email: existing?.email ?? 'ornek@mail.com',
      fullName: existing?.fullName,
      emailVerified: existing?.emailVerified ?? true,
      profileCompleted: true,
    );
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
  }

  bool _isEmail(String value) =>
      RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value);

  Future<void> _shortDelay() =>
      Future<void>.delayed(const Duration(milliseconds: 350));
}
