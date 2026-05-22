import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticase/src/app/praticase_app.dart';
import 'package:praticase/src/features/auth/data/auth_repository.dart';
import 'package:praticase/src/features/auth/domain/auth_user.dart';
import 'package:praticase/src/features/auth/domain/profile_setup.dart';
import 'package:praticase/src/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:praticase/src/features/auth/presentation/screens/register_screen.dart';
import 'package:praticase/src/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:praticase/src/features/cases/data/cases_repository.dart';
import 'package:praticase/src/features/home/data/home_repository.dart';
import 'package:praticase/src/features/home/domain/home_dashboard.dart';
import 'package:praticase/src/features/home/presentation/home_screen.dart';
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
            authRepository: _TestAuthRepository(),
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

  testWidgets('profile setup target exam is a live form value on iPhone 14', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);
    final repository = _RecordingAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileSetupScreen(
          repository: repository,
          fullName: 'Ayse Yilmaz',
          onBack: () {},
          onCompleted: () {},
        ),
      ),
    );

    await tester.tap(find.text('OSCE'));
    await tester.ensureVisible(find.text('PratiCase’e Başla'));
    await tester.tap(find.text('PratiCase’e Başla'));
    await tester.pumpAndSettle();

    expect(repository.completedProfile?.targetExam, 'OSCE');
  });

  testWidgets('account security sends reset email on iPhone 14', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);
    final repository = _RecordingAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: AccountSecurityScreen(
          authRepository: repository,
          profile: const ProfileCard(
            displayName: 'Ayse Yilmaz',
            email: 'ayse@example.com',
            classLevel: '5',
            target: 'OSCE - Genel Cerrahi',
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
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Şifre Sıfırlama Bağlantısı Gönder'),
      160,
    );
    await tester.tap(find.text('Şifre Sıfırlama Bağlantısı Gönder'));
    await tester.pumpAndSettle();

    expect(repository.resetEmail, 'ayse@example.com');
    expect(
      find.text(
        'Şifre sıfırlama bağlantısı ayse@example.com adresine gönderildi.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('profile screen keeps long email compact on iPhone 14', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(
            authRepository: _TestAuthRepository(),
            repository: _LongEmailProgressRepository(),
            onSignOut: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('kemal.tuncer'), findsOneWidget);
    expect(find.text('kemal.tuncer@medasi.com.tr'), findsOneWidget);
    expect(find.text('İstatistiklerim'), findsOneWidget);
  });

  testWidgets('home screen renders with live empty optional sections', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            repository: _EmptyLiveHomeRepository(),
            casesRepository: _FakeCasesRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Canlı veri bağlantısı gerekli'), findsNothing);
    expect(find.text('Devam Edilen Vaka'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Önerilen Vakalar'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Önerilen Vakalar'), findsOneWidget);
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

class _LongEmailProgressRepository extends Fake implements ProgressRepository {
  @override
  Future<ProfileCard> loadProfile() async {
    return const ProfileCard(
      displayName: '',
      email: 'kemal.tuncer@medasi.com.tr',
      classLevel: 'Mezun',
      target: 'TUS',
      totalPoints: 0,
      solvedCaseCount: 0,
      correctDiagnosisRate: 0,
      dailyStreak: 0,
      successRatePercent: 0,
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

class _EmptyLiveHomeRepository extends Fake implements HomeRepository {
  @override
  Future<HomeDashboard> loadDashboard() async {
    return const HomeDashboard(
      user: HomeUser(
        id: 'test-user',
        email: 'kemal.tuncer@medasi.com.tr',
        fullName: 'Kemal Tuncer',
      ),
      banners: [],
      stats: null,
      recommendedCases: [],
      unreadNotificationCount: 0,
    );
  }
}

Finder _textFormFieldAt(int index) => find.byType(TextFormField).at(index);

Future<void> _setIPhone14Viewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

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

class _RecordingAuthRepository extends _TestAuthRepository {
  ProfileSetup? completedProfile;
  String? resetEmail;

  @override
  Future<void> sendPasswordResetCode(String email) async {
    resetEmail = email;
  }

  @override
  Future<AuthUser> completeProfile(ProfileSetup setup) async {
    completedProfile = setup;
    return super.completeProfile(setup);
  }
}
