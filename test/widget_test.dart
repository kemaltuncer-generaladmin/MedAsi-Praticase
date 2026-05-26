import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticase/src/app/praticase_app.dart';
import 'package:praticase/src/features/auth/data/auth_repository.dart';
import 'package:praticase/src/features/auth/domain/auth_user.dart';
import 'package:praticase/src/features/auth/domain/profile_setup.dart';
import 'package:praticase/src/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:praticase/src/features/auth/presentation/screens/login_screen.dart';
import 'package:praticase/src/features/auth/presentation/screens/register_screen.dart';
import 'package:praticase/src/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:praticase/src/features/cases/data/cases_repository.dart';
import 'package:praticase/src/features/cases/data/voice_exam_adapter.dart';
import 'package:praticase/src/features/cases/domain/osce_case.dart';
import 'package:praticase/src/features/cases/presentation/cases_screen.dart';
import 'package:praticase/src/features/home/data/home_repository.dart';
import 'package:praticase/src/features/home/domain/home_dashboard.dart';
import 'package:praticase/src/features/home/presentation/home_screen.dart';
import 'package:praticase/src/features/progress/data/progress_repository.dart';
import 'package:praticase/src/features/progress/domain/progress_models.dart';
import 'package:praticase/src/features/progress/presentation/progress_screens.dart';
import 'package:praticase/src/features/shell/presentation/praticase_shell.dart';
import 'package:praticase/src/features/store/data/store_controller.dart';
import 'package:praticase/src/features/theoretical_exam/data/theoretical_exam_repository.dart';
import 'package:praticase/src/features/theoretical_exam/domain/theoretical_exam_models.dart';
import 'package:praticase/src/features/theoretical_exam/presentation/theoretical_exam_screen.dart';
import 'package:praticase/src/features/oral_exam/data/oral_exam_repository.dart';
import 'package:praticase/src/features/oral_exam/domain/oral_exam_models.dart';
import 'package:praticase/src/features/oral_exam/presentation/oral_exam_screens.dart';
import 'package:praticase/src/features/progress/presentation/store_screen.dart';
import 'package:praticase/src/shared/data/user_facing_error.dart';

void main() {
  test('technical service detail is replaced with student-facing copy', () {
    expect(
      PratiCaseUserMessage.store('permission denied for table store_products'),
      PratiCaseUserMessage.storeFailure,
    );
    expect(
      PratiCaseUserMessage.report('error code: 502'),
      PratiCaseUserMessage.reportFailure,
    );
    expect(
      PratiCaseUserMessage.mentorMessage('{"mentor_message":"raw"}'),
      contains('klinik gerekçenle'),
    );
    expect(
      PratiCaseUserMessage.safe('session_id zorunlu.'),
      PratiCaseUserMessage.generalFailure,
    );
  });

  testWidgets('PratiCase auth onboarding renders', (tester) async {
    await tester.pumpWidget(
      PratiCaseApp(
        authRepository: _TestAuthRepository(),
        homeRepository: _FakeHomeRepository(),
        casesRepository: _FakeCasesRepository(),
        progressRepository: _FakeProgressRepository(),
        theoreticalExamRepository: _FakeTheoreticalExamRepository(),
        oralExamRepository: _FakeOralExamRepository(),
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

  testWidgets('login exposes email auth only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          repository: _TestAuthRepository(),
          onBack: () {},
          onForgotPassword: () {},
          onRegister: () {},
          onSignedIn: (_) {},
        ),
      ),
    );

    expect(find.text('Google ile devam et'), findsNothing);
    expect(find.text('Apple ile devam et'), findsNothing);
    expect(find.text('Giriş Yap'), findsOneWidget);
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
            storeControllerFactory: StoreController.new,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('kemal.tuncer@medasi.com.tr'), findsNothing);
    expect(find.text('PratiCase Öğrencisi'), findsOneWidget);
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
    expect(find.text('Sıralama'), findsNothing);
    await tester.tap(find.byTooltip('Bildirimler'));
    await tester.tap(find.byTooltip('Profilim'));

    expect(openedNotifications, isTrue);
    expect(openedProfile, isTrue);
  });

  testWidgets('anamnesis room keeps opening line and sends patient turns', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 1040));
    final repository = _ChatFlowCasesRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: PatientChatScreen(repository: repository, sessionId: 'session-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Mert Yılmaz'), findsOneWidget);
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

    final conversation = find.byType(ListView);
    final questionBubble = find.descendant(
      of: conversation,
      matching: find.text('Ağrınız ne zaman başladı?'),
    );
    final answerBubble = find.descendant(
      of: conversation,
      matching: find.text('Dün akşam başladı, giderek arttı.'),
    );

    expect(repository.lastQuestion, 'Ağrınız ne zaman başladı?');
    expect(questionBubble, findsOneWidget);
    expect(answerBubble, findsOneWidget);
    expect(
      tester.getTopLeft(questionBubble).dy,
      lessThan(tester.getTopLeft(answerBubble).dy),
    );
  });

  testWidgets('voice anamnesis controls can speak and auto-send final speech', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 1040));
    final repository = _ChatFlowCasesRepository();
    final voice = _FakeVoiceExamAdapter();

    await tester.pumpWidget(
      MaterialApp(
        home: PatientChatScreen(
          repository: repository,
          sessionId: 'session-1',
          voiceAdapter: voice,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sesli Sınav'));
    await tester.pumpAndSettle();

    expect(voice.initialized, isTrue);
    expect(
      voice.spokenTexts,
      contains('Hocam merhaba, karnımın sağ alt tarafı ağrıyor.'),
    );

    await tester.tap(find.byTooltip('Sesle yaz'));
    await tester.pumpAndSettle();

    expect(repository.lastQuestion, 'Ağrınız ne zaman başladı?');
    expect(find.text('Dün akşam başladı, giderek arttı.'), findsOneWidget);
  });

  testWidgets('physical exam asks for system before showing findings', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);
    final repository = _PhysicalExamCasesRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: PhysicalExamScreen(
          repository: repository,
          sessionId: 'session-1',
          caseId: 'case-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Önce muayene sistemini seç.'), findsOneWidget);
    expect(find.text('Batın'), findsOneWidget);
    expect(find.text('Rebound ve defans'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Tetkiklere Geç'),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Batın'));
    await tester.pumpAndSettle();

    expect(find.text('Batın Bulguları'), findsOneWidget);
    expect(find.text('Rebound ve defans'), findsOneWidget);
    expect(find.text('Sistem Değiştir'), findsOneWidget);

    await tester.tap(find.text('Rebound ve defans'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Tetkiklere Geç'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('tests screen asks for group and opens lab fallback result', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);
    final repository = _LabCasesRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: TestsScreen(
          repository: repository,
          sessionId: 'session-1',
          caseId: 'case-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Önce tetkik grubunu seç.'), findsOneWidget);
    expect(find.text('Laboratuvar'), findsOneWidget);
    expect(find.text('Hemogram'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Tanıya Geç'))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Laboratuvar'));
    await tester.pumpAndSettle();

    expect(find.text('Laboratuvar Tetkikleri'), findsOneWidget);
    expect(find.text('Hemogram'), findsOneWidget);
    expect(find.text('2 p'), findsNothing);

    await tester.tap(find.text('Hemogram'));
    await tester.pumpAndSettle();

    expect(repository.requested, contains('hemogram'));
    expect(find.text('Tetkik Sonucu'), findsOneWidget);
    expect(
      find.text('Lökosit yüksek, nötrofil hakimiyeti var.'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Tanıya Geç'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('diagnosis bottom action remains above keyboard', (tester) async {
    await _setViewport(tester, const Size(390, 844));
    final repository = _DiagnosisManagementCasesRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewInsets: EdgeInsets.only(bottom: 320),
          ),
          child: DiagnosisScreen(
            repository: repository,
            sessionId: 'session-1',
            caseId: 'case-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, 'Yönetim Planına Geç');
    expect(button, findsOneWidget);
    expect(tester.getBottomLeft(button).dy, lessThan(844 - 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('management requires an actual plan before result', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);
    final repository = _DiagnosisManagementCasesRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: ManagementPlanScreen(
          repository: repository,
          sessionId: 'session-1',
          caseId: 'case-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Sınavı Bitir ve Değerlendir'),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('İlk Yaklaşım'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sıvı resüsitasyonu'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Sınavı Bitir ve Değerlendir'),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byType(TextField).last,
      'Acil stabilizasyon, sıvı tedavisi ve cerrahi değerlendirme planlandı.',
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Sınavı Bitir ve Değerlendir'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('tests screen opens imaging fallback result', (tester) async {
    await _setIPhone14Viewport(tester);
    final repository = _LabCasesRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: TestsScreen(
          repository: repository,
          sessionId: 'session-1',
          caseId: 'case-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Görüntüleme'));
    await tester.pumpAndSettle();

    expect(find.text('Görüntüleme Tetkikleri'), findsOneWidget);
    expect(find.text('Batın USG'), findsOneWidget);

    await tester.tap(find.text('Batın USG'));
    await tester.pumpAndSettle();

    expect(repository.requested, contains('usg'));
    expect(find.text('Batın USG'), findsWidgets);
    expect(
      find.text('Sağ alt kadranda inflamasyon ile uyumlu görünüm.'),
      findsOneWidget,
    );
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

  testWidgets('home quick actions expose Teorik Sınav without Pratik Sınav', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);
    var openedTheoreticalExam = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            repository: _EmptyLiveHomeRepository(),
            casesRepository: _FakeCasesRepository(),
            onOpenTheoreticalExam: () => openedTheoreticalExam = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Teorik Sınav'), findsOneWidget);
    expect(find.text('Pratik Sınav'), findsNothing);
    await tester.tap(find.text('Teorik Sınav'));

    expect(openedTheoreticalExam, isTrue);
  });

  testWidgets('oral exam offers committee as an optional format', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 1100));

    await tester.pumpWidget(
      MaterialApp(
        home: OralExamSetupScreen(repository: _CommitteeOralExamRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tek Moderatör'), findsOneWidget);
    expect(find.text('Komite (3 Hoca)'), findsOneWidget);
    expect(find.text('Sözlü Sınavı Başlat'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(
        home: OralExamSetupScreen(
          repository: _CommitteeOralExamRepository(),
          initialFormat: OralExamFormat.panel,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Komiteye Çık'), findsOneWidget);
    expect(find.text('Karşındaki Komite'), findsOneWidget);
  });

  testWidgets('committee turn shows all three examiners after one answer', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 1100));
    final repository = _CommitteeOralExamRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: OralExamRoomScreen(
          repository: repository,
          session: repository.panelSession,
          voiceAdapter: _FakeVoiceExamAdapter(),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byType(TextField),
      'Akut koroner sendrom düşünürüm.',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(repository.submittedAnswer, 'Akut koroner sendrom düşünürüm.');
    expect(find.text('Akut koroner sendrom düşünürüm.'), findsOneWidget);
    expect(find.text('Önceliklendirme doğru.'), findsOneWidget);
    expect(find.text('Gerekçeniz eksik kalıyor.'), findsOneWidget);
    expect(find.text('İlk isteyeceğiniz tetkik nedir?'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('oral exam finalize hides provider errors and offers retry', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 1100));
    final repository = _FailingFinalizeOralExamRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: OralExamRoomScreen(
          repository: repository,
          session: repository.panelSession,
          voiceAdapter: _FakeVoiceExamAdapter(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Sınavı Bitir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bitir ve Değerlendir'));
    await tester.pumpAndSettle();

    expect(find.text(PratiCaseUserMessage.reportFailure), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
    expect(find.textContaining('502'), findsNothing);
  });

  testWidgets('shell keeps bottom navigation on iPad portrait', (tester) async {
    await _setViewport(tester, const Size(768, 1024));

    await tester.pumpWidget(
      MaterialApp(
        home: PratiCaseShell(
          authRepository: _TestAuthRepository(),
          homeRepository: _EmptyLiveHomeRepository(),
          casesRepository: _FakeCasesRepository(),
          progressRepository: _FakeProgressRepository(),
          theoreticalExamRepository: _FakeTheoreticalExamRepository(),
          oralExamRepository: _FakeOralExamRepository(),
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Ana Sayfa'), findsWidgets);
  });

  testWidgets('shell switches to navigation rail on web width', (tester) async {
    await _setViewport(tester, const Size(1200, 800));

    await tester.pumpWidget(
      MaterialApp(
        home: PratiCaseShell(
          authRepository: _TestAuthRepository(),
          homeRepository: _EmptyLiveHomeRepository(),
          casesRepository: _FakeCasesRepository(),
          progressRepository: _FakeProgressRepository(),
          theoreticalExamRepository: _FakeTheoreticalExamRepository(),
          oralExamRepository: _FakeOralExamRepository(),
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Cüzdan'), findsOneWidget);
  });

  testWidgets('single station opens a focused case picker', (tester) async {
    await _setIPhone14Viewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: PratiCaseShell(
          authRepository: _TestAuthRepository(),
          homeRepository: _EmptyLiveHomeRepository(),
          casesRepository: _FakeCasesRepository(),
          progressRepository: _SingleStationProgressRepository(),
          theoreticalExamRepository: _FakeTheoreticalExamRepository(),
          oralExamRepository: _FakeOralExamRepository(),
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sınavlar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tek İstasyon').first);
    await tester.pumpAndSettle();

    expect(find.text('Tek İstasyon Seç'), findsOneWidget);
    expect(find.text('OSCE İstasyonları'), findsNothing);
  });

  testWidgets('theoretical setup sends selected Medasi topics', (tester) async {
    await _setViewport(tester, const Size(390, 1200));
    final repository = _RecordingTheoreticalExamRepository();

    await tester.pumpWidget(
      MaterialApp(home: TheoreticalExamSetupScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dahiliye'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kardiyoloji'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sepsis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sepsis'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kalp yetmezliği'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kalp yetmezliği'));
    await tester.pumpAndSettle();
    final startButton = find.widgetWithText(FilledButton, 'Denemeyi Başlat');
    await tester.ensureVisible(startButton);
    await tester.pumpAndSettle();
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    expect(repository.lastCourses, {'Dahiliye', 'Kardiyoloji'});
    expect(repository.lastPlans.map((plan) => plan.course).toList(), [
      'Dahiliye',
      'Kardiyoloji',
    ]);
    expect(repository.lastPlans.first.questionCount, 10);
    expect(repository.lastPlans.first.topics.single.metadataValue, 'Sepsis');
    expect(
      repository.lastPlans.last.topics.single.metadataValue,
      'Kalp yetmezliği',
    );
    expect(find.text('Sepsis sorusu'), findsOneWidget);
  });

  testWidgets('theoretical setup limits topic count to course question count', (
    tester,
  ) async {
    await _setViewport(tester, const Size(430, 1200));
    final repository = _RecordingTheoreticalExamRepository();

    await tester.pumpWidget(
      MaterialApp(home: TheoreticalExamSetupScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dahiliye'));
    await tester.pumpAndSettle();

    for (final label in _RecordingTheoreticalExamRepository.dahiliyeTopics.take(
      10,
    )) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await tester.ensureVisible(find.text('Konu 11'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Konu 11'));
    await tester.pumpAndSettle();

    expect(
      find.text('Dahiliye için 10 soru seçili; en fazla 10 konu seçebilirsin.'),
      findsOneWidget,
    );
  });

  testWidgets('theoretical result syncs solved answers to progress', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);
    final repository = _RecordingTheoreticalExamRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: TheoreticalExamSessionScreen(
          repository: repository,
          questions: [_RecordingTheoreticalExamRepository.question],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('A seçeneği'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Bitir').last);
    await tester.pumpAndSettle();

    expect(repository.submittedAttempt?.selectedOptionIds, {'q-1': '0'});
    expect(find.text('İlerlemen kaydedildi'), findsOneWidget);
  });

  testWidgets('store product cards remain readable at large text scale', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: StoreScreen(repository: _StoreProgressRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Medasi Cüzdanı'), findsOneWidget);
    expect(find.text('Yoğun OSCE Hazırlık Paketi'), findsOneWidget);
    expect(find.textContaining('2.795 soru'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

class _FakeHomeRepository extends Fake implements HomeRepository {}

class _FakeCasesRepository extends Fake implements CasesRepository {
  @override
  Future<List<OsceCaseSummary>> loadCases({
    String query = '',
    String? difficulty,
  }) async => const [];
}

class _FakeProgressRepository extends Fake implements ProgressRepository {
  @override
  Stream<int> watchUnreadNotificationCount() => Stream.value(0);

  @override
  Stream<List<NotificationCard>> watchNotifications() =>
      Stream.value(const <NotificationCard>[]);

  @override
  Future<int> loadUnreadNotificationCount() async => 0;

  @override
  Future<List<ExamModeItem>> loadExamModes() async => const [];

  @override
  Future<ProfileCard> loadProfile() async {
    return const ProfileCard(
      displayName: 'Ayse Yilmaz',
      email: 'ayse@example.com',
      classLevel: '5',
      target: 'OSCE',
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

  @override
  Future<ClinicalProgressSummary> loadClinicalProgressSummary() async =>
      const ClinicalProgressSummary(sessionCount: 0, categoryScores: []);

  @override
  Future<List<BadgeCard>> loadBadges() async => const [];
}

class _SingleStationProgressRepository extends _FakeProgressRepository {
  @override
  Future<List<ExamModeItem>> loadExamModes() async => const [
    ExamModeItem(
      id: 'single_station',
      title: 'Tek İstasyon',
      subtitle: 'Bir vaka seç, süreli OSCE akışına gir.',
      iconKey: 'timer',
      actionKey: 'single_station',
    ),
  ];
}

class _FakeTheoreticalExamRepository extends Fake
    implements TheoreticalExamRepository {}

class _FakeOralExamRepository extends Fake implements OralExamRepository {}

class _CommitteeOralExamRepository extends Fake implements OralExamRepository {
  String? submittedAnswer;

  static const panel = [
    OralExamPersona(
      id: 'lead',
      title: 'Sert Profesör',
      difficulty: 'Zor',
      description: '',
      patienceLevel: 3,
      sortOrder: 1,
      panelRole: 'lead',
    ),
    OralExamPersona(
      id: 'second',
      title: 'Sokratik Doçent',
      difficulty: 'Orta',
      description: '',
      patienceLevel: 5,
      sortOrder: 2,
      panelRole: 'second',
    ),
    OralExamPersona(
      id: 'observer',
      title: 'Sabırlı Asistan',
      difficulty: 'Kolay',
      description: '',
      patienceLevel: 8,
      sortOrder: 3,
      panelRole: 'observer',
    ),
  ];

  OralExamSession get panelSession => OralExamSession(
    id: 'panel-session',
    durationSeconds: 900,
    caseBrief: 'Göğüs ağrısı ile başvuran hasta.',
    startedAt: DateTime.now(),
    personaId: 'lead',
    personaTitle: 'Sert Profesör',
    difficulty: 'Zor',
    branchId: 'dahiliye',
    branchTitle: 'Dahiliye',
    openingMessage: 'Bu hastada öncelikli tanınız nedir?',
    format: OralExamFormat.panel,
    panel: panel,
    activePersonaId: 'lead',
  );

  @override
  Future<OralExamCatalog> loadCatalog() async => const OralExamCatalog(
    personas: panel,
    branches: [
      OralExamBranch(
        id: 'dahiliye',
        title: 'Dahiliye',
        description: 'İç hastalıkları',
        sortOrder: 1,
      ),
    ],
    scenariosByBranch: {},
  );

  @override
  Future<OralExamTurnResult> sendAnswer({
    required String sessionId,
    required String message,
  }) async {
    submittedAnswer = message;
    return const OralExamTurnResult(
      mentorMessage: 'İlk isteyeceğiniz tetkik nedir?',
      mentorMessages: [
        OralExamMessage(
          speaker: 'mentor',
          message: 'Önceliklendirme doğru.',
          personaId: 'lead',
          personaTitle: 'Sert Profesör',
        ),
        OralExamMessage(
          speaker: 'mentor',
          message: 'Gerekçeniz eksik kalıyor.',
          personaId: 'observer',
          personaTitle: 'Sabırlı Asistan',
        ),
        OralExamMessage(
          speaker: 'mentor',
          message: 'İlk isteyeceğiniz tetkik nedir?',
          personaId: 'second',
          personaTitle: 'Sokratik Doçent',
          isFollowup: true,
        ),
      ],
      isFollowup: true,
      shouldEnd: false,
      remainingSeconds: 880,
      scoreDelta: 5,
      reasoningNote: '',
      isCorrect: true,
      activePersonaId: 'second',
      activePersonaTitle: 'Sokratik Doçent',
    );
  }
}

class _FailingFinalizeOralExamRepository extends _CommitteeOralExamRepository {
  @override
  Future<OralExamResult> finalizeSession(String sessionId) async {
    throw const OralExamUnavailable('error code: 502');
  }
}

class _RecordingTheoreticalExamRepository extends Fake
    implements TheoreticalExamRepository {
  Set<String> lastCourses = const {};
  List<TheoreticalCoursePlan> lastPlans = const [];
  TheoreticalExamAttempt? submittedAttempt;

  static const dahiliyeTopics = [
    'Sepsis',
    'Konu 2',
    'Konu 3',
    'Konu 4',
    'Konu 5',
    'Konu 6',
    'Konu 7',
    'Konu 8',
    'Konu 9',
    'Konu 10',
    'Konu 11',
    'Konu 12',
  ];

  static const question = TheoreticalQuestion(
    id: 'q-1',
    course: 'Dahiliye',
    topic: 'Sepsis',
    difficulty: 'medium',
    stem: 'Sepsis sorusu',
    correctOptionId: '0',
    explanation: 'Qlinik açıklaması',
    options: [
      TheoreticalQuestionOption(id: '0', label: 'A', text: 'A seçeneği'),
      TheoreticalQuestionOption(id: '1', label: 'B', text: 'B seçeneği'),
    ],
  );

  @override
  Future<TheoreticalExamFilters> loadFilters() async {
    return TheoreticalExamFilters(
      courses: ['Dahiliye', 'Kardiyoloji'],
      topicsByCourse: {
        'Dahiliye': dahiliyeTopics,
        'Kardiyoloji': ['Kalp yetmezliği'],
      },
      topicOptionsByCourse: {
        'Dahiliye': [
          for (final topic in dahiliyeTopics)
            TheoreticalTopicOption(
              course: 'Dahiliye',
              topic: 'Enfeksiyon',
              metadataValue: topic,
              totalCount: 20,
              remainingCount: 20,
            ),
        ],
        'Kardiyoloji': const [
          TheoreticalTopicOption(
            course: 'Kardiyoloji',
            topic: 'Kalp',
            metadataValue: 'Kalp yetmezliği',
            totalCount: 20,
            remainingCount: 20,
          ),
        ],
      },
    );
  }

  @override
  Future<List<TheoreticalQuestion>> loadQuestions({
    required Set<String> courses,
    Set<String> topics = const <String>{},
    List<TheoreticalCoursePlan> plans = const <TheoreticalCoursePlan>[],
    int limit = 20,
  }) async {
    lastCourses = Set<String>.from(courses);
    lastPlans = List<TheoreticalCoursePlan>.from(plans);
    return const [question];
  }

  @override
  Future<TheoreticalExamSubmissionResult> submitAttempt({
    required TheoreticalExamAttempt attempt,
    required Duration elapsed,
  }) async {
    submittedAttempt = attempt;
    return TheoreticalExamSubmissionResult(
      submittedCount: attempt.selectedOptionIds.length,
      syncedCount: attempt.selectedOptionIds.length,
      remainingQuestionQuota: 99,
    );
  }
}

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

class _StoreProgressRepository extends Fake implements ProgressRepository {
  @override
  Future<StoreCatalog> loadStoreCatalog() async {
    return const StoreCatalog(
      walletBalance: 1459.2,
      questionQuota: 2795,
      aiQuota: 0,
      products: [
        StoreProduct(
          code: 'osce-intense',
          name: 'Yoğun OSCE Hazırlık Paketi',
          description:
              'Vaka çözümü ve sözlü komite çalışmaları için ortak hak paketi.',
          priceCents: 29900,
          currency: 'TRY',
          questionAmount: 2795,
          coinAmount: 1459.2,
          appStoreProductId: 'com.medasi.praticase.intense',
          isFeatured: true,
          interval: 'month',
        ),
      ],
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
  Stream<List<NotificationCard>> watchNotifications() =>
      Stream.value(notifications);

  @override
  Stream<int> watchUnreadNotificationCount() =>
      Stream.value(notifications.where((item) => !item.isRead).length);

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

class _FakeVoiceExamAdapter implements VoiceExamAdapter {
  final _controller = StreamController<VoiceExamState>.broadcast();
  final spokenTexts = <String>[];
  VoiceExamState _state = const VoiceExamState();
  bool initialized = false;

  @override
  VoiceExamState get state => _state;

  @override
  Stream<VoiceExamState> get states => _controller.stream;

  @override
  Future<void> initialize() async {
    initialized = true;
    _emit(const VoiceExamState(available: true, initialized: true));
  }

  @override
  Future<void> startListening({
    required void Function(String text) onFinalText,
    required void Function(String text) onPartialText,
  }) async {
    await initialize();
    _emit(_state.copyWith(listening: true));
    onPartialText('Ağrınız');
    onFinalText('Ağrınız ne zaman başladı?');
    _emit(_state.copyWith(listening: false, partialText: ''));
  }

  @override
  Future<void> stopListening() async {
    _emit(_state.copyWith(listening: false));
  }

  @override
  Future<void> speak(String text) async {
    spokenTexts.add(text);
    _emit(_state.copyWith(speaking: true));
    _emit(_state.copyWith(speaking: false));
  }

  @override
  Future<void> stopSpeaking() async {
    _emit(_state.copyWith(speaking: false));
  }

  @override
  Future<void> setMuted(bool muted) async {
    _emit(_state.copyWith(muted: muted));
  }

  @override
  void dispose() {
    unawaited(_controller.close());
  }

  void _emit(VoiceExamState state) {
    _state = state;
    if (!_controller.isClosed) _controller.add(state);
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
    return List<ChatMessage>.unmodifiable(_messages.reversed);
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

class _PhysicalExamCasesRepository extends Fake implements CasesRepository {
  _PhysicalExamCasesRepository()
    : _session = ExamSessionOverview(
        id: 'session-1',
        caseId: 'case-1',
        caseTitle: 'Akut Apandisit',
        patient: _ChatFlowCasesRepository._patient,
        currentStep: 'physical_exam',
        remainingPoints: 300,
        budgetPoints: 300,
        durationMinutes: 7,
        startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      );

  final ExamSessionOverview _session;
  final Set<String> _selected = {};

  @override
  Future<ExamSessionOverview> loadSession(String sessionId) async => _session;

  @override
  Future<List<PhysicalExamGroup>> loadPhysicalExamGroups(String caseId) async {
    return const [
      PhysicalExamGroup(id: 'general', title: 'Genel Durum'),
      PhysicalExamGroup(id: 'abdomen', title: 'Batın'),
    ];
  }

  @override
  Future<List<PhysicalExamOption>> loadPhysicalExamOptions({
    required String sessionId,
    required String caseId,
  }) async {
    return [
      PhysicalExamOption(
        id: 'appearance',
        groupId: 'general',
        title: 'Genel görünüm',
        finding: 'Hasta ağrılı görünüyor.',
        pointValue: 2,
        isSelected: _selected.contains('appearance'),
      ),
      PhysicalExamOption(
        id: 'rebound',
        groupId: 'abdomen',
        title: 'Rebound ve defans',
        finding: 'Sağ alt kadranda rebound pozitif.',
        pointValue: 4,
        isSelected: _selected.contains('rebound'),
      ),
    ];
  }

  @override
  Future<void> selectPhysicalExam({
    required String sessionId,
    required String optionId,
  }) async {
    _selected.add(optionId);
  }

  @override
  Future<void> advanceSession({
    required String sessionId,
    required String step,
  }) async {}
}

class _LabCasesRepository extends Fake implements CasesRepository {
  _LabCasesRepository()
    : _session = ExamSessionOverview(
        id: 'session-1',
        caseId: 'case-1',
        caseTitle: 'Akut Apandisit',
        patient: _ChatFlowCasesRepository._patient,
        currentStep: 'tests',
        remainingPoints: 300,
        budgetPoints: 300,
        durationMinutes: 7,
        startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
      );

  final ExamSessionOverview _session;
  final Set<String> requested = {};

  @override
  Future<ExamSessionOverview> loadSession(String sessionId) async => _session;

  @override
  Future<List<TestGroup>> loadTestGroups(String caseId) async {
    return const [
      TestGroup(id: 'lab', title: 'Laboratuvar'),
      TestGroup(id: 'imaging', title: 'Görüntüleme'),
    ];
  }

  @override
  Future<List<TestOption>> loadTestOptions({
    required String sessionId,
    required String caseId,
  }) async {
    return [
      TestOption(
        id: 'hemogram',
        groupId: 'lab',
        title: 'Hemogram',
        result: 'Lökosit yüksek, nötrofil hakimiyeti var.',
        pointCost: 2,
        isSelected: requested.contains('hemogram'),
      ),
      TestOption(
        id: 'usg',
        groupId: 'imaging',
        title: 'Batın USG',
        result: 'Sağ alt kadranda inflamasyon ile uyumlu görünüm.',
        pointCost: 4,
        isSelected: requested.contains('usg'),
      ),
    ];
  }

  @override
  Future<void> requestTest({
    required String sessionId,
    required String optionId,
  }) async {
    requested.add(optionId);
  }

  @override
  Future<LabResultDetail?> loadLabResult(String testOptionId) async => null;

  @override
  Future<ImagingResultDetail?> loadImagingResult(String testOptionId) async =>
      null;

  @override
  Future<void> advanceSession({
    required String sessionId,
    required String step,
  }) async {}
}

class _DiagnosisManagementCasesRepository extends Fake
    implements CasesRepository {
  _DiagnosisManagementCasesRepository()
    : _session = ExamSessionOverview(
        id: 'session-1',
        caseId: 'case-1',
        caseTitle: 'Akut Apandisit',
        patient: _ChatFlowCasesRepository._patient,
        currentStep: 'diagnosis',
        remainingPoints: 300,
        budgetPoints: 300,
        durationMinutes: 7,
        startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

  final ExamSessionOverview _session;
  final selectedManagement = <String>{};
  DiagnosisAnswer? savedDiagnosis;
  ManagementPlanAnswer? savedManagement;

  @override
  Future<ExamSessionOverview> loadSession(String sessionId) async => _session;

  @override
  Future<DiagnosisAnswer?> loadDiagnosisAnswer(String sessionId) async {
    return savedDiagnosis ??
        const DiagnosisAnswer(
          primaryDiagnosis: 'Akut apandisit',
          reasoning: '',
          selectedOptionIds: [],
        );
  }

  @override
  Future<List<DiagnosisOption>> loadDiagnosisOptions({
    required String sessionId,
    required String caseId,
  }) async {
    return const [
      DiagnosisOption(
        id: 'appendicitis',
        title: 'Akut apandisit',
        isSelected: false,
      ),
      DiagnosisOption(
        id: 'renal-colic',
        title: 'Renal kolik',
        isSelected: false,
      ),
    ];
  }

  @override
  Future<void> saveDiagnosisAnswer({
    required String sessionId,
    required String primaryDiagnosis,
    required List<String> selectedOptionIds,
    required String reasoning,
  }) async {
    savedDiagnosis = DiagnosisAnswer(
      primaryDiagnosis: primaryDiagnosis,
      reasoning: reasoning,
      selectedOptionIds: selectedOptionIds,
    );
  }

  @override
  Future<ManagementPlanAnswer?> loadManagementPlan(String sessionId) async {
    return savedManagement;
  }

  @override
  Future<List<ManagementOption>> loadManagementOptions({
    required String sessionId,
    required String caseId,
  }) async {
    return [
      ManagementOption(
        id: 'iv-fluid',
        category: 'İlk Yaklaşım',
        title: 'Sıvı resüsitasyonu',
        pointValue: 4,
        isSelected: selectedManagement.contains('iv-fluid'),
      ),
      ManagementOption(
        id: 'surgery-consult',
        category: 'Konsültasyon',
        title: 'Genel cerrahi konsültasyonu',
        pointValue: 4,
        isSelected: selectedManagement.contains('surgery-consult'),
      ),
    ];
  }

  @override
  Future<void> saveManagementPlan({
    required String sessionId,
    required String diagnosis,
    required List<String> selectedOptionIds,
    required String note,
    String consultationDestination = '',
  }) async {
    selectedManagement
      ..clear()
      ..addAll(selectedOptionIds);
    savedManagement = ManagementPlanAnswer(
      diagnosis: diagnosis,
      note: note,
      selectedOptionIds: selectedOptionIds,
      consultationDestination: consultationDestination,
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
  await _setViewport(tester, const Size(390, 844));
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
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
