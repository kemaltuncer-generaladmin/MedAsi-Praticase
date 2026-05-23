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
import 'package:praticase/src/features/cases/domain/osce_case.dart';
import 'package:praticase/src/features/cases/presentation/cases_screen.dart';
import 'package:praticase/src/features/home/data/home_repository.dart';
import 'package:praticase/src/features/home/domain/home_dashboard.dart';
import 'package:praticase/src/features/home/presentation/home_screen.dart';
import 'package:praticase/src/features/progress/data/progress_repository.dart';
import 'package:praticase/src/features/progress/domain/progress_models.dart';
import 'package:praticase/src/features/progress/presentation/progress_screens.dart';
import 'package:praticase/src/features/theoretical_exam/data/theoretical_exam_repository.dart';

void main() {
  testWidgets('PratiCase auth onboarding renders', (tester) async {
    await tester.pumpWidget(
      PratiCaseApp(
        authRepository: _TestAuthRepository(),
        homeRepository: _FakeHomeRepository(),
        casesRepository: _FakeCasesRepository(),
        progressRepository: _FakeProgressRepository(),
        theoreticalExamRepository: _FakeTheoreticalExamRepository(),
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

    expect(find.text('kemal.tuncer@medasi.com.tr'), findsOneWidget);
    expect(find.text('PratiCase Üyesi'), findsOneWidget);
    expect(find.text('İstatistiklerim'), findsOneWidget);
  });

  testWidgets('weak area analysis renders category score results', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: WeakAreaAnalysisScreen(repository: _ClinicalProgressRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zayıf Alan Analizi'), findsOneWidget);
    expect(find.text('Anamnez Derinliği'), findsOneWidget);
    expect(find.text('%40'), findsOneWidget);
    expect(find.text('%60'), findsOneWidget);
    expect(find.text('%70'), findsOneWidget);
  });

  testWidgets('notifications mark all read and notify live headers', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);
    final repository = _NotificationsProgressRepository();
    var changeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(
          repository: repository,
          onChanged: () async => changeCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 okunmamış bildirim var.'), findsOneWidget);
    await tester.tap(find.text('Tümünü Oku'));
    await tester.pumpAndSettle();

    expect(repository.markedAllRead, isTrue);
    expect(changeCount, 1);
    expect(find.text('Okunmamış bildirimin yok.'), findsOneWidget);
  });

  testWidgets('case library header exposes live notifications and profile', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);
    var openedNotifications = false;
    var openedProfile = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CasesScreen(
            repository: _CasesHeaderRepository(),
            unreadNotificationCount: 3,
            onOpenNotifications: () => openedNotifications = true,
            onOpenProfile: () => openedProfile = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Bildirimler'), findsOneWidget);
    expect(find.byTooltip('Profilim'), findsOneWidget);
    await tester.tap(find.byTooltip('Bildirimler'));
    await tester.tap(find.byTooltip('Profilim'));

    expect(openedNotifications, isTrue);
    expect(openedProfile, isTrue);
  });

  testWidgets('anamnesis room keeps opening line and sends patient turns', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);
    final repository = _ChatFlowCasesRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: PatientChatScreen(repository: repository, sessionId: 'session-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aday Yönergesi'), findsOneWidget);
    expect(
      find.text('Karın ağrısı ile başvuran hastayı değerlendiriniz.'),
      findsOneWidget,
    );
    expect(
      find.text('Hocam merhaba, karnımın sağ alt tarafı ağrıyor.'),
      findsOneWidget,
    );
    expect(find.text('Muayeneye Geç'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ağrınız ne zaman başladı?');
    await tester.tap(find.byTooltip('Gönder'));
    await tester.pumpAndSettle();

    expect(repository.lastQuestion, 'Ağrınız ne zaman başladı?');
    expect(find.text('Ağrınız ne zaman başladı?'), findsOneWidget);
    expect(find.text('Dün akşam başladı, giderek arttı.'), findsOneWidget);
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
    expect(find.text('Tek İstasyon'), findsOneWidget);
    expect(find.text('Genel Bakış'), findsOneWidget);
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

class _FakeTheoreticalExamRepository extends Fake
    implements TheoreticalExamRepository {}

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

class _ClinicalProgressRepository extends _ProfileProgressRepository {
  @override
  Future<ClinicalProgressSummary> loadClinicalProgressSummary() async {
    return const ClinicalProgressSummary(
      sessionCount: 2,
      categoryScores: [
        ClinicalSkillScore(
          category: 'history',
          label: 'Anamnez',
          score: 24,
          maxScore: 60,
        ),
        ClinicalSkillScore(
          category: 'diagnosis',
          label: 'Ayırıcı Tanı',
          score: 18,
          maxScore: 30,
        ),
        ClinicalSkillScore(
          category: 'management',
          label: 'Yönetim & Tedavi',
          score: 14,
          maxScore: 20,
        ),
      ],
    );
  }

  @override
  Future<List<CaseCollectionItem>> loadCaseHistory() async => const [];
}

class _NotificationsProgressRepository extends Fake
    implements ProgressRepository {
  bool markedAllRead = false;
  List<NotificationCard> notifications = [
    NotificationCard(
      id: '1',
      title: 'Yeni vaka',
      body: 'Akut batın istasyonu yayınlandı.',
      isRead: false,
      createdAt: DateTime(2026, 5, 23),
    ),
    NotificationCard(
      id: '2',
      title: 'Karne hazır',
      body: 'Sonucun görüntülenmeye hazır.',
      isRead: false,
      createdAt: DateTime(2026, 5, 22),
    ),
  ];

  @override
  Future<List<NotificationCard>> loadNotifications() async => notifications;

  @override
  Future<void> markAllNotificationsRead() async {
    markedAllRead = true;
    notifications = [
      for (final item in notifications)
        NotificationCard(
          id: item.id,
          title: item.title,
          body: item.body,
          isRead: true,
          createdAt: item.createdAt,
        ),
    ];
  }
}

class _CasesHeaderRepository extends Fake implements CasesRepository {
  @override
  Future<List<OsceCaseSummary>> loadCases({
    String query = '',
    String? difficulty,
  }) async {
    return const [
      OsceCaseSummary(
        id: 'case-1',
        title: 'Akut Apandisit',
        branch: 'Genel Cerrahi',
        setting: 'Acil',
        difficulty: OsceDifficulty.medium,
        durationMinutes: 7,
        points: 100,
        solvedCount: 0,
        summary: 'Karın ağrısı ile başvuran hastayı değerlendiriniz.',
        iconKey: 'abdomen',
        isBookmarked: false,
      ),
    ];
  }
}

class _ChatFlowCasesRepository extends Fake implements CasesRepository {
  _ChatFlowCasesRepository()
    : _session = ExamSessionOverview(
        id: 'session-1',
        caseId: 'case-1',
        caseTitle: 'Akut Apandisit',
        patient: _patient,
        currentStep: 'history',
        remainingPoints: 300,
        budgetPoints: 300,
        durationMinutes: 7,
        startedAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

  static const _patient = PatientProfile(
    name: 'Mert Yılmaz',
    age: '22',
    gender: 'Erkek',
    mainComplaint: 'Karın ağrısı',
    openingLine: 'Hocam merhaba, karnımın sağ alt tarafı ağrıyor.',
    applicationSetting: 'Acil',
    complaintDuration: '12 saat',
  );

  final ExamSessionOverview _session;
  final List<ChatMessage> _messages = [];
  String? lastQuestion;

  @override
  Future<ExamSessionOverview> loadSession(String sessionId) async => _session;

  @override
  Future<OsceCaseDetail> loadCaseDetail(String caseId) async {
    return const OsceCaseDetail(
      summary: OsceCaseSummary(
        id: 'case-1',
        title: 'Akut Apandisit',
        branch: 'Genel Cerrahi',
        setting: 'Acil',
        difficulty: OsceDifficulty.medium,
        durationMinutes: 7,
        points: 100,
        solvedCount: 0,
        summary: 'Karın ağrısı ile başvuran hastayı değerlendiriniz.',
        iconKey: 'abdomen',
        isBookmarked: false,
      ),
      candidatePrompt: 'Karın ağrısı ile başvuran hastayı değerlendiriniz.',
      patient: _patient,
      flowSteps: [],
      goals: [],
    );
  }

  @override
  Future<List<ChatMessage>> loadMessages(String sessionId) async {
    return List<ChatMessage>.unmodifiable(_messages);
  }

  @override
  Future<void> sendPatientQuestion({
    required String sessionId,
    required String message,
  }) async {
    lastQuestion = message;
    final now = DateTime(2026, 5, 23, 12);
    _messages
      ..add(
        ChatMessage(
          id: 'candidate-${_messages.length}',
          sender: 'candidate',
          message: message,
          createdAt: now,
        ),
      )
      ..add(
        ChatMessage(
          id: 'patient-${_messages.length}',
          sender: 'patient',
          message: 'Dün akşam başladı, giderek arttı.',
          createdAt: now.add(const Duration(seconds: 1)),
        ),
      );
  }

  @override
  Future<void> advanceSession({
    required String sessionId,
    required String step,
  }) async {}
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
