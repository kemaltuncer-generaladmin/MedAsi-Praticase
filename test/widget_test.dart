import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticase/src/app/praticase_app.dart';
import 'package:praticase/src/features/auth/data/auth_repository.dart';
import 'package:praticase/src/features/auth/domain/auth_user.dart';
import 'package:praticase/src/features/auth/domain/profile_setup.dart';
import 'package:praticase/src/features/auth/presentation/screens/register_screen.dart';
import 'package:praticase/src/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:praticase/src/features/cases/data/cases_repository.dart';
import 'package:praticase/src/features/home/data/home_repository.dart';
import 'package:praticase/src/features/progress/data/progress_repository.dart';
import 'package:praticase/src/features/progress/domain/progress_models.dart';
import 'package:praticase/src/features/progress/presentation/progress_screens.dart';

void main() {
  testWidgets('PratiCase auth onboarding renders', (tester) async {
    await tester.pumpWidget(
      PratiCaseApp(
        authRepository: _TestAuthRepository(),
        homeRepository: _FakeHomeRepository(),
        casesRepository: _FakeCasesRepository(),
        progressRepository: _FakeProgressRepository(),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsWidgets);
    expect(find.text('Klinik Akıl Yürütme Becerini Geliştir'), findsOneWidget);
    expect(find.text('Başla'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);
  });

  testWidgets('register requires explicit legal consent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(
          repository: _TestAuthRepository(),
          onBack: () {},
          onLogin: () {},
          onRegistered: (_, _) {},
        ),
      ),
    );

    await tester.enterText(_textFormFieldAt(0), 'Ayse');
    await tester.enterText(_textFormFieldAt(1), 'Yilmaz');
    await tester.enterText(_textFormFieldAt(2), 'ayse@example.com');
    await tester.enterText(_textFormFieldAt(3), 'Password1');
    await tester.enterText(_textFormFieldAt(4), 'Password1');
    await tester.ensureVisible(find.text('Hesap Oluştur'));
    await tester.tap(find.text('Hesap Oluştur'));
    await tester.pump();

    expect(
      find.text('Kullanım koşulları ve gizlilik politikasını kabul etmelisin.'),
      findsOneWidget,
    );
  });

  testWidgets('reset password requires OTP code', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResetPasswordScreen(
          repository: _TestAuthRepository(),
          email: 'ayse@example.com',
          onBack: () {},
          onPasswordUpdated: () {},
        ),
      ),
    );

    await tester.enterText(_textFormFieldAt(0), 'Password1');
    await tester.enterText(_textFormFieldAt(1), 'Password1');
    await tester.ensureVisible(find.text('Şifreyi Güncelle'));
    await tester.tap(find.text('Şifreyi Güncelle'));
    await tester.pump();

    expect(find.text('6 haneli doğrulama kodunu gir.'), findsOneWidget);
  });

  testWidgets('settings logout confirmation calls sign out callback', (
    tester,
  ) async {
    var signedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            repository: _ProfileProgressRepository(),
            onSignOut: () async => signedOut = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Çıkış Yap'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.tap(find.text('Çıkış Yap'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çıkış Yap').last);
    await tester.pumpAndSettle();

    expect(signedOut, isTrue);
  });
}

class _FakeHomeRepository extends Fake implements HomeRepository {}

class _FakeCasesRepository extends Fake implements CasesRepository {}

class _FakeProgressRepository extends Fake implements ProgressRepository {}

class _ProfileProgressRepository extends Fake implements ProgressRepository {
  @override
  Future<ProfileCard> loadProfile() async {
    return const ProfileCard(
      displayName: 'Ayse Yilmaz',
      email: 'ayse@example.com',
      classLevel: '5',
      target: 'Staj + TUS',
      totalPoints: 120,
      solvedCaseCount: 4,
      correctDiagnosisRate: 75,
      dailyStreak: 3,
      successRatePercent: 82,
      settings: AppSettings(
        displayMode: 'Açık',
        language: 'Türkçe',
        textSize: 'Orta',
        soundAndHaptics: true,
        dataUsage: 'Standart',
        offlineMode: false,
        caseDownloadsEnabled: false,
      ),
    );
  }
}

Finder _textFormFieldAt(int index) => find.byType(TextFormField).at(index);

class _TestAuthRepository implements AuthRepository {
  @override
  bool get isConfigured => true;

  @override
  Future<AuthUser?> currentUser() async => null;

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return AuthUser(id: 'test-user', email: email, emailVerified: true);
  }

  @override
  Future<AuthUser> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    return AuthUser(id: 'test-user', email: email, fullName: fullName);
  }

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> sendPasswordResetCode(String email) async {}

  @override
  Future<AuthUser> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    return AuthUser(id: 'test-user', email: email, emailVerified: true);
  }

  @override
  Future<void> resendEmailVerification(String email) async {}

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {}

  @override
  Future<AuthUser> completeProfile(ProfileSetup setup) async {
    return const AuthUser(
      id: 'test-user',
      email: 'test@example.com',
      emailVerified: true,
      profileCompleted: true,
    );
  }

  @override
  Future<void> signOut() async {}
}
