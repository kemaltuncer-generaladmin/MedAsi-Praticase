import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;
import 'package:praticase/src/app/praticase_app.dart';
import 'package:praticase/src/features/auth/data/auth_repository.dart';
import 'package:praticase/src/features/auth/domain/auth_user.dart';
import 'package:praticase/src/features/auth/domain/profile_setup.dart';
import 'package:praticase/src/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:praticase/src/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:praticase/src/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:praticase/src/features/auth/presentation/screens/login_screen.dart';
import 'package:praticase/src/features/auth/presentation/screens/register_screen.dart';
import 'package:praticase/src/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:praticase/src/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:praticase/src/features/cases/data/cases_repository.dart';
import 'package:praticase/src/features/cases/data/voice_exam_adapter.dart';
import 'package:praticase/src/features/cases/domain/osce_case.dart';
import 'package:praticase/src/features/cases/presentation/cases_screen.dart';
import 'package:praticase/src/features/home/data/home_repository.dart';
import 'package:praticase/src/features/home/domain/home_dashboard.dart';
import 'package:praticase/src/features/home/domain/recall_summary.dart';
import 'package:praticase/src/features/home/presentation/home_screen.dart';
import 'package:praticase/src/features/progress/data/progress_repository.dart';
import 'package:praticase/src/features/progress/domain/progress_models.dart';
import 'package:praticase/src/features/progress/presentation/progress_screens.dart';
import 'package:praticase/src/features/shell/presentation/praticase_shell.dart';
import 'package:praticase/src/features/store/data/store_controller.dart';
import 'package:praticase/src/features/store/data/storekit_repository.dart';
import 'package:praticase/src/features/store/data/storekit_service.dart';
import 'package:praticase/src/features/store/domain/gift_code_redemption.dart';
import 'package:praticase/src/features/store/domain/store_product.dart';
import 'package:praticase/src/features/store/domain/subscription_state.dart';
import 'package:praticase/src/features/store/domain/wallet_snapshot.dart';
import 'package:praticase/src/features/store/domain/wallet_transaction.dart';
import 'package:praticase/src/features/store/presentation/wallet_screen.dart';
import 'package:praticase/src/features/theoretical_exam/data/theoretical_exam_repository.dart';
import 'package:praticase/src/features/theoretical_exam/domain/theoretical_exam_models.dart';
import 'package:praticase/src/features/theoretical_exam/presentation/theoretical_exam_screen.dart';
import 'package:praticase/src/features/oral_exam/data/oral_exam_repository.dart';
import 'package:praticase/src/features/oral_exam/domain/oral_exam_models.dart';
import 'package:praticase/src/features/oral_exam/presentation/oral_exam_screens.dart';
import 'package:praticase/src/features/progress/presentation/store_screen.dart';
import 'package:praticase/src/features/shell/presentation/shell_navigation.dart';
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

  test('wallet AI usage events are parsed as MC debit movements', () {
    final transaction = WalletTransaction.fromMap({
      'id': 'usage-1',
      'kind': 'usage',
      'product_code': 'praticase-patient-turn',
      'product_name': 'Sanal hasta görüşmesi',
      'coin_amount': -0.10,
      'question_amount': 0,
      'remaining_coin_amount': 0,
      'remaining_question_amount': 0,
      'status': 'consumed',
      'expired': false,
      'occurred_at': '2026-05-26T12:00:00Z',
    });

    expect(transaction.isUsage, isTrue);
    expect(transaction.isCredit, isFalse);
    expect(transaction.coinAmount, -0.10);
  });

  test('wallet accepts shared Qlinik package identifiers', () {
    final product = PratiCaseStoreProduct.fromMap({
      'code': 'monthly_subscription',
      'name': 'Aylık Medasi Paketi',
      'description': 'Qlinik ve PratiCase için ortak paket.',
      'price_cents': 29900,
      'currency': 'TRY',
      'app_store_product_id': 'com.medasi.qlinik.monthly',
      'entitlement_kind': 'subscription',
      'interval': 'month',
      'duration_days': 30,
      'coin_amount': 250,
      'question_amount': 500,
    });

    expect(product.appStoreProductId, 'com.medasi.qlinik.monthly');
    expect(product.canPurchaseInPratiCase, isTrue);
    expect(product.isSubscription, isTrue);
  });

  test('wallet accepts Medasi Pay checkout URL variants', () {
    expect(
      paymentCheckoutUriFromResponse({
        'checkout': {'checkout_url': 'https://odeme.medasi.com.tr/c/abc'},
      })?.toString(),
      'https://odeme.medasi.com.tr/c/abc',
    );
    expect(
      paymentCheckoutUriFromResponse({
        'checkout': {
          'data': {'paymentUrl': 'https://odeme.medasi.com.tr/c/nested'},
        },
      })?.toString(),
      'https://odeme.medasi.com.tr/c/nested',
    );
    expect(
      paymentCheckoutUriFromResponse({
        'checkout': {'checkoutUrl': 'http://localhost:4173/c/dev'},
      })?.toString(),
      'http://localhost:4173/c/dev',
    );
    expect(
      paymentCheckoutUriFromResponse({
        'checkout': {'checkoutUrl': 'javascript:alert(1)'},
      }),
      isNull,
    );
  });

  test('wallet parses live profile balances returned as text', () {
    final snapshot = WalletSnapshot.fromStoreResponse({
      'profile': {'wallet_balance': '1459.20', 'question_quota': '2795'},
    });

    expect(snapshot.walletCoinBalance, 1459.20);
    expect(snapshot.questionQuota, 2795);
  });

  test('wallet reads products and shared profile from one store response', () {
    final catalog = WalletCatalog.fromStoreResponse({
      'profile': {'wallet_balance': '1459.20', 'question_quota': '2795'},
      'products': [
        {
          'code': 'monthly_subscription',
          'name': 'Aylık',
          'price_cents': 50000,
          'currency': 'TRY',
          'entitlement_kind': 'subscription',
          'interval': 'month',
          'duration_days': 30,
        },
      ],
    });

    expect(catalog.snapshot.walletCoinBalance, 1459.20);
    expect(catalog.snapshot.questionQuota, 2795);
    expect(catalog.products.single.name, 'Aylık');
  });

  test('gift code normalization matches AdminPanel and Qlinik redeem', () {
    expect(normalizeGiftCode('pc25-abcd-1234-efgh'), 'PC25ABCD1234EFGH');
    expect(formatGiftCodeInput('pc25abcd1234efgh'), 'PC25-ABCD-1234-EFGH');
    expect(normalizeGiftCode('eksik'), isEmpty);
  });

  test('recall summary sends only compact guidance context', () {
    const summary = RecallSummary(
      todayTotal: 6,
      weaknesses: [
        RecallWeakness(
          title: 'Akut batın - Ayırıcı tanı',
          riskLevel: 'high',
          topic: 'Akut batın',
        ),
      ],
      guidance: RecallGuidance(
        sentence: 'Önce akut batın ayrımını kısaca toparla.',
        action: 'Tek istasyon çöz.',
      ),
      action: 'Tek istasyon çöz.',
    );

    expect(summary.toSanitizedGuidanceInput(), {
      'source': 'recall_praticase_summary',
      'today_total': 6,
      'weaknesses': [
        {
          'title': 'Akut batın - Ayırıcı tanı',
          'risk_level': 'high',
          'topic': 'Akut batın',
        },
      ],
    });
  });

  testWidgets('wallet surfaces shared balance and live MC consumption', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 1200));
    final controller = StoreController(
      repository: _WalletStoreRepository(),
      service: _WalletStoreService(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WalletScreen(
            controller: controller,
            unreadNotificationCount: 0,
            onOpenNotifications: () {},
            onOpenProfile: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('100,00'), findsWidgets);
    expect(find.text('50'), findsWidgets);
    expect(find.text('MC tüketimi canlı takip edilir'), findsOneWidget);
    expect(find.textContaining('Sanal hasta görüşmesi'), findsOneWidget);
    expect(find.textContaining('-0,10 MC'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Qlinik MC Paketi'), findsOneWidget);
    expect(find.text('+25 MC'), findsOneWidget);
  });

  test('PratiCase purchase grants the shared Medasi wallet product', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final repository = _RecordingStoreKitRepository();
    final service = _RecordingStoreKitService();
    final controller = StoreController(
      repository: repository,
      service: service,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.refresh();
    await controller.purchase(repository.products.single);

    for (var i = 0; i < 20 && controller.busy; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(repository.verifiedProductCode, 'mc_25');
    expect(repository.verifiedAppStoreProductId, 'com.medasi.praticase.mc.25');
    expect(repository.verifiedProvider, 'app_store');
    expect(repository.verifiedPurchaseId, 'tx-praticase-mc-25');
    expect(service.completedPurchases, ['tx-praticase-mc-25']);
    expect(controller.statusMessage, 'Satın alma doğrulandı.');
    expect(controller.walletSnapshot.walletCoinBalance, 125);
    expect(controller.walletSnapshot.questionQuota, 50);
  });

  test(
    'Android purchases use Google Play Billing with visible status',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final repository = _RecordingStoreKitRepository();
      final service = _RecordingGooglePlayService();
      final controller = StoreController(
        repository: repository,
        service: service,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.refresh();

      expect(controller.supportsExternalCheckout, isFalse);

      await controller.purchase(repository.products.single);

      for (var i = 0; i < 20 && controller.busy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(repository.lastStoreProvider, 'google_play');
      expect(repository.verifiedProvider, 'google_play');
      expect(
        repository.verifiedAppStoreProductId,
        'com.medasi.praticase.mc.25',
      );
      expect(repository.verifiedVerificationSource, 'google_play');
      expect(repository.verifiedServerVerificationData, 'play-token-mc-25');
      expect(controller.statusMessage, 'Satın alma doğrulandı.');
    },
  );

  test(
    'PratiCase redeems AdminPanel gift code through shared wallet',
    () async {
      final repository = _GiftCodeStoreRepository();
      final controller = StoreController(
        repository: repository,
        service: _WalletStoreService(),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.refresh();
      await controller.redeemGiftCode('pc25-abcd-1234-efgh');

      expect(repository.redeemedCode, 'PC25ABCD1234EFGH');
      expect(controller.walletSnapshot.walletCoinBalance, 125);
      expect(controller.walletSnapshot.questionQuota, 60);
      expect(controller.walletSnapshot.aiQuota, 3);
      expect(
        controller.statusMessage,
        'Hediye kodu işlendi. Hakların güncellendi.',
      );
      expect(controller.transactions.single.productName, 'Hediye kodu');
    },
  );

  testWidgets('PratiCase auth entry renders common MedAsi login', (
    tester,
  ) async {
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

    expect(find.text("PratiCase'e Hoş Geldiniz 👋"), findsOneWidget);
    expect(find.text('MedAsi Ekosistemi'), findsOneWidget);
    expect(find.textContaining('MEDASI AILESINE HOŞ GELDINIZ'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);
  });

  testWidgets('late auth state opens authenticated shell', (tester) async {
    await _setIPhone14Viewport(tester);
    final authRepository = _StreamingAuthRepository();
    addTearDown(authRepository.dispose);

    await tester.pumpWidget(
      PratiCaseApp(
        authRepository: authRepository,
        homeRepository: _EmptyLiveHomeRepository(),
        casesRepository: _FakeCasesRepository(),
        progressRepository: _FakeProgressRepository(),
        theoreticalExamRepository: _FakeTheoreticalExamRepository(),
        oralExamRepository: _FakeOralExamRepository(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Giriş Yap'), findsOneWidget);

    authRepository.emit(
      const AuthUser(
        id: 'test-user',
        email: 'ayse@example.com',
        emailVerified: true,
        profileCompleted: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ana Sayfa'), findsWidgets);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('register exposes common MedAsi profile fields', (tester) async {
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

    expect(find.text('Aramıza Katılın ✨'), findsOneWidget);
    expect(find.text('Üniversite'), findsOneWidget);
    expect(find.text('Fakülte'), findsOneWidget);
    expect(find.text('Hesabımı Oluştur'), findsOneWidget);
    expect(find.textContaining('Kullanım Koşulları'), findsOneWidget);
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
          onCompleted: (_) {},
        ),
      ),
    );

    await tester.ensureVisible(find.text('Klinik Stajlar'));
    await tester.tap(find.text('Klinik Stajlar'));
    await tester.ensureVisible(find.text('Devam').last);
    await tester.tap(find.text('Devam').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devam').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devam').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bitir'));
    await tester.pumpAndSettle();

    expect(repository.completedProfile?.targetExam, 'Klinik Stajlar');
    expect(repository.completedProfile?.discipline, 'tip');
  });

  testWidgets('profile setup filters target exams by discipline', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileSetupScreen(
          repository: _TestAuthRepository(),
          fullName: 'Ayse Yilmaz',
          onBack: () {},
          onCompleted: (_) {},
        ),
      ),
    );

    expect(find.text('USMLE Step 2 CS'), findsOneWidget);

    await tester.ensureVisible(find.text('Hemşirelik'));
    await tester.tap(find.text('Hemşirelik'));
    await tester.pumpAndSettle();

    expect(find.text('USMLE Step 2 CS'), findsNothing);
    expect(find.text('Klinik Uygulama'), findsOneWidget);

    await tester.ensureVisible(find.text('Diş Hekimliği'));
    await tester.tap(find.text('Diş Hekimliği'));
    await tester.pumpAndSettle();

    expect(find.text('DUS Klinik Hazırlık'), findsOneWidget);
    expect(find.text('USMLE Step 2 CS'), findsNothing);
  });

  testWidgets('profile setup offers 1st through 6th year and graduate', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileSetupScreen(
          repository: _TestAuthRepository(),
          fullName: 'Ayse Yilmaz',
          onBack: () {},
          onCompleted: (_) {},
        ),
      ),
    );

    for (final grade in const [
      '1. Sınıf',
      '2. Sınıf',
      '3. Sınıf',
      '4. Sınıf',
      '5. Sınıf',
      '6. Sınıf',
      'Mezun',
    ]) {
      expect(find.text(grade), findsOneWidget);
    }
  });

  testWidgets('completed profile setup opens the authenticated shell', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);
    final authRepository = _PendingThenUnavailableAuthRepository();

    await tester.pumpWidget(
      PratiCaseApp(
        authRepository: authRepository,
        homeRepository: _EmptyLiveHomeRepository(),
        casesRepository: _FakeCasesRepository(),
        progressRepository: _FakeProgressRepository(),
        theoreticalExamRepository: _FakeTheoreticalExamRepository(),
        oralExamRepository: _FakeOralExamRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MedAsi Ekosistem Kurulumu'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.ensureVisible(find.text('Devam').last);
      await tester.tap(find.text('Devam').last);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Bitir'));
    await tester.tap(find.text('Bitir'));
    await tester.pumpAndSettle();

    expect(authRepository.completedProfile, isNotNull);
    expect(find.text('MedAsi Ekosistem Kurulumu'), findsNothing);
    expect(find.text('Ana Sayfa'), findsWidgets);
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
      find.text('Şifre Sıfırlama Kodu Gönder'),
      160,
    );
    await tester.tap(find.text('Şifre Sıfırlama Kodu Gönder'));
    await tester.pumpAndSettle();

    expect(repository.resetEmail, 'ayse@example.com');
    expect(
      find.text('Şifre sıfırlama kodu ayse@example.com adresine gönderildi.'),
      findsOneWidget,
    );
  });

  testWidgets('account security completes account deletion flow on iPhone 14', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);
    final repository = _RecordingAuthRepository();
    var accountDeleted = false;

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
          onAccountDeleted: () async => accountDeleted = true,
        ),
      ),
    );

    await tester.scrollUntilVisible(find.text('Hesabı Kalıcı Olarak Sil'), 160);
    await tester.tap(find.text('Hesabı Kalıcı Olarak Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Hesabımı Kalıcı Olarak Sil'),
      160,
    );
    await tester.tap(find.text('Hesabımı Kalıcı Olarak Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kalıcı Sil'));
    await tester.pumpAndSettle();

    expect(repository.deletedAccount, isTrue);
    expect(accountDeleted, isTrue);
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

  testWidgets(
    'voice anamnesis waits for patient speech before auto-listening',
    (tester) async {
      await _setViewport(tester, const Size(390, 1040));
      final repository = _ChatFlowCasesRepository();
      final voice = _InterruptedPlaybackVoiceExamAdapter();

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      expect(voice.listenStarts, 0);

      await tester.pump(const Duration(milliseconds: 900));

      expect(voice.listenStarts, 1);
    },
  );

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

    // Tapping queues the test in the basket; results only arrive after a bulk
    // fetch (sepet checkout).
    expect(repository.requested, isEmpty);
    expect(find.text('Seçilenleri Getir (1)'), findsOneWidget);

    await tester.tap(find.text('Seçilenleri Getir (1)'));
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

  testWidgets('diagnosis can advance without differential count or reasoning', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);
    final repository = _DiagnosisManagementCasesRepository()
      ..savedDiagnosis = const DiagnosisAnswer(
        primaryDiagnosis: '',
        reasoning: '',
        selectedOptionIds: [],
      );

    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosisScreen(
          repository: repository,
          sessionId: 'session-1',
          caseId: 'case-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, 'Yönetim Planına Geç');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Akut apandisit');
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
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

    await tester.enterText(find.byType(TextField).last, 'Sıvı');
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

  testWidgets('result Recall support screen renders a focused study plan', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);

    await tester.pumpWidget(
      MaterialApp(home: ResultAiSupportScreen(result: _supportResultSummary)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recall Planı'), findsOneWidget);
    expect(find.text('Recall çalışma yönlendirmesi'), findsOneWidget);
    expect(find.text('Öncelikli Çalışma Alanı'), findsOneWidget);
    expect(find.text('Hemen Çalışılacak Başlıklar'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Bir Sonraki Deneme Planı'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Bir Sonraki Deneme Planı'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Detaylı Raporu Aç'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Detaylı Raporu Aç'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('case report renders graded checklist table', (tester) async {
    await _setIPhone14Viewport(tester);

    await tester.pumpWidget(
      MaterialApp(home: CaseReportScreen(result: _supportResultSummary)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vaka Raporu'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Checklist Tablosu'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tam / Yarım / Sorulmadı'), findsOneWidget);
    expect(find.text('Tam: 1/3 · Yarım: 1 · Sorulmadı: 1'), findsOneWidget);
    expect(find.text('Ağrının başlangıcı'), findsOneWidget);
    expect(find.text('Ağrı yayılımı'), findsOneWidget);
    expect(find.text('İştahsızlık'), findsOneWidget);
    expect(find.text('Tam'), findsOneWidget);
    expect(find.text('Yarım'), findsOneWidget);
    expect(find.text('Sorulmadı'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

    await tester.tap(find.text('Seçilenleri Getir (1)'));
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

  testWidgets('home shows Recall today guidance when summary is available', (
    tester,
  ) async {
    await _setIPhone14Viewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            repository: _RecallHomeRepository(),
            casesRepository: _FakeCasesRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recall bugün'), findsOneWidget);
    expect(find.text('3 PratiCase tekrarı bekliyor'), findsOneWidget);
    expect(find.text('Akut batın - Ayırıcı tanı'), findsOneWidget);
    expect(find.text('Recall’a git'), findsOneWidget);
  });

  testWidgets('home shows Recall empty state quietly', (tester) async {
    await _setIPhone14Viewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            repository: _RecallEmptyHomeRepository(),
            casesRepository: _FakeCasesRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recall bugün'), findsOneWidget);
    expect(
      find.text('Bugün PratiCase için bekleyen Recall tekrarı yok.'),
      findsOneWidget,
    );
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

  testWidgets(
    'committee turn shows only the active examiner after one answer',
    (tester) async {
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
      await tester.pump(const Duration(milliseconds: 600));

      expect(repository.submittedAnswer, 'Akut koroner sendrom düşünürüm.');
      expect(find.text('Akut koroner sendrom düşünürüm.'), findsOneWidget);
      expect(find.text('İlk isteyeceğiniz tetkik nedir?'), findsOneWidget);
      expect(find.text('Şu an aktif • Klinik Akıl Hocası'), findsOneWidget);
      expect(find.text('Önceliklendirme doğru.'), findsNothing);
      expect(find.text('Gerekçeniz eksik kalıyor.'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('solo oral voice mode does not speak persona prefix', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 1100));
    final repository = _CommitteeOralExamRepository();
    final voice = _FakeVoiceExamAdapter();

    await tester.pumpWidget(
      MaterialApp(
        home: OralExamRoomScreen(
          repository: repository,
          session: repository.soloSession,
          voiceAdapter: voice,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.volume_off_rounded));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Cevap Ver'), findsOneWidget);

    await tester.tap(find.text('Cevap Ver'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      voice.spokenTexts.any((text) => text.contains('Sert Profesör:')),
      isFalse,
    );
    expect(
      voice.spokenTexts.any(
        (text) => text.contains('İlk isteyeceğiniz tetkik nedir?'),
      ),
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('committee oral voice mode does not speak persona prefix', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 1100));
    final repository = _CommitteeOralExamRepository();
    final voice = _FakeVoiceExamAdapter();

    await tester.pumpWidget(
      MaterialApp(
        home: OralExamRoomScreen(
          repository: repository,
          session: repository.panelSession,
          voiceAdapter: voice,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.volume_off_rounded));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('Cevap Ver'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      voice.spokenTexts.any((text) => text.contains('Sokratik Doçent:')),
      isFalse,
    );
    expect(
      voice.spokenTexts.any(
        (text) => text.contains('İlk isteyeceğiniz tetkik nedir?'),
      ),
      isTrue,
    );

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
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Bitir ve Değerlendir'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text(PratiCaseUserMessage.reportFailure), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
    expect(find.textContaining('502'), findsNothing);
  });

  testWidgets('shell uses side navigation on iPad portrait', (tester) async {
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

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Ana Sayfa'), findsWidgets);
  });

  testWidgets('shell switches to side navigation on web width', (tester) async {
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

    expect(find.byType(PratiCaseSideNavigation), findsOneWidget);
    expect(find.text('Cüzdan'), findsOneWidget);
  });

  testWidgets('shell fits the iPhone and iPad support matrix', (tester) async {
    for (final entry in _supportedDeviceViewports.entries) {
      await _setViewport(tester, entry.value);
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

      expect(tester.takeException(), isNull, reason: entry.key);
      expect(find.text('Ana Sayfa'), findsWidgets, reason: entry.key);
      expect(
        find.byType(PratiCaseSideNavigation),
        entry.value.width >= 900 ||
                (entry.value.shortestSide >= 600 && entry.value.width >= 720)
            ? findsOneWidget
            : findsNothing,
        reason: entry.key,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('auth entry and setup fit phone and tablet viewports', (
    tester,
  ) async {
    for (final entry in _authDeviceViewports.entries) {
      await _setViewport(tester, entry.value);
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(onCreateAccount: () {}, onLogin: () {}),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: '${entry.key} onboarding');
      expect(find.text('Devam'), findsOneWidget, reason: entry.key);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(
            repository: _TestAuthRepository(),
            fullName: 'Ayse Yilmaz',
            onBack: () {},
            onCompleted: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: '${entry.key} setup');
      expect(find.text('Devam'), findsOneWidget, reason: entry.key);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('common auth screens fit compact mobile viewports', (
    tester,
  ) async {
    final screens = <({String name, Widget Function() build, String anchor})>[
      (
        name: 'login',
        build: () => LoginScreen(
          repository: _TestAuthRepository(),
          onForgotPassword: () {},
          onRegister: () {},
          onSignedIn: (_) {},
        ),
        anchor: 'Giriş Yap',
      ),
      (
        name: 'register',
        build: () => RegisterScreen(
          repository: _TestAuthRepository(),
          onBack: () {},
          onLogin: () {},
          onRegistered: (_, _) {},
        ),
        anchor: 'Hesabımı Oluştur',
      ),
      (
        name: 'forgot',
        build: () => ForgotPasswordScreen(
          repository: _TestAuthRepository(),
          onBack: () {},
          onCodeSent: (_) {},
        ),
        anchor: 'Kod Gönder',
      ),
      (
        name: 'verify',
        build: () => VerifyEmailScreen(
          repository: _TestAuthRepository(),
          email: 'ayse@example.com',
          fullName: 'Ayşe Yılmaz',
          onBack: () {},
          onVerified: () {},
        ),
        anchor: 'Doğrula',
      ),
      (
        name: 'reset',
        build: () => ResetPasswordScreen(
          repository: _TestAuthRepository(),
          email: 'ayse@example.com',
          onBack: () {},
          onPasswordUpdated: () {},
        ),
        anchor: 'Şifreyi Güncelle',
      ),
      (
        name: 'profile-setup',
        build: () => ProfileSetupScreen(
          repository: _TestAuthRepository(),
          fullName: 'Ayşe Yılmaz',
          onBack: () {},
          onCompleted: (_) {},
        ),
        anchor: 'Devam',
      ),
    ];

    for (final viewport in _commonAuthCompatibilityViewports.entries) {
      await _setViewport(tester, viewport.value);
      for (final screen in screens) {
        await tester.pumpWidget(MaterialApp(home: screen.build()));
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: '${viewport.key} ${screen.name}',
        );
        await tester.ensureVisible(find.text(screen.anchor).last);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${viewport.key} ${screen.name} scrolled',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('common auth forms stay keyboard safe on compact phones', (
    tester,
  ) async {
    const size = Size(320, 568);
    const keyboardHeight = 260.0;
    await _setViewport(tester, size);

    final forms = <({String name, Widget Function() build, String anchor})>[
      (
        name: 'login',
        build: () => LoginScreen(
          repository: _TestAuthRepository(),
          onForgotPassword: () {},
          onRegister: () {},
          onSignedIn: (_) {},
        ),
        anchor: 'Giriş Yap',
      ),
      (
        name: 'register',
        build: () => RegisterScreen(
          repository: _TestAuthRepository(),
          onBack: () {},
          onLogin: () {},
          onRegistered: (_, _) {},
        ),
        anchor: 'Hesabımı Oluştur',
      ),
      (
        name: 'reset',
        build: () => ResetPasswordScreen(
          repository: _TestAuthRepository(),
          email: 'ayse@example.com',
          onBack: () {},
          onPasswordUpdated: () {},
        ),
        anchor: 'Şifreyi Güncelle',
      ),
    ];

    for (final form in forms) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: size,
              viewInsets: EdgeInsets.only(bottom: keyboardHeight),
            ),
            child: form.build(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: form.name);
      await tester.ensureVisible(find.text(form.anchor).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${form.name} keyboard');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('osce keyboard actions stay clear on supported viewports', (
    tester,
  ) async {
    for (final entry in _keyboardSafeViewports.entries) {
      final size = entry.value.$1;
      final keyboardHeight = entry.value.$2;
      await _setViewport(tester, size);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              viewInsets: EdgeInsets.only(bottom: keyboardHeight),
            ),
            child: DiagnosisScreen(
              repository: _DiagnosisManagementCasesRepository(),
              sessionId: 'session-1',
              caseId: 'case-1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.widgetWithText(FilledButton, 'Yönetim Planına Geç');
      expect(button, findsOneWidget, reason: entry.key);
      expect(tester.takeException(), isNull, reason: entry.key);
      expect(
        tester.getBottomLeft(button).dy,
        lessThan(size.height - keyboardHeight + 8),
        reason: entry.key,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Sınavlar').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Tek İstasyon').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Tek İstasyon Seç'), findsOneWidget);
    expect(find.text('OSCE İstasyonları'), findsNothing);
  });

  testWidgets('mini OSCE opens a three station picker', (tester) async {
    await _setViewport(tester, const Size(390, 1200));

    await tester.pumpWidget(
      MaterialApp(
        home: PratiCaseShell(
          authRepository: _TestAuthRepository(),
          homeRepository: _EmptyLiveHomeRepository(),
          casesRepository: _MiniOsceCasesRepository(),
          progressRepository: _MiniOsceProgressRepository(),
          theoreticalExamRepository: _FakeTheoreticalExamRepository(),
          oralExamRepository: _FakeOralExamRepository(),
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Sınavlar').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Mini OSCE').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Mini OSCE Seç'), findsOneWidget);
    expect(find.text('Tek İstasyon Seç'), findsNothing);
    expect(find.text('0/3 istasyon seçildi'), findsOneWidget);

    for (final title in const [
      'Akut Apandisit',
      'Ektopik Gebelik',
      'Testis Torsiyonu',
    ]) {
      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
      await tester.pump();
    }

    expect(find.text('1. İstasyon'), findsOneWidget);
    expect(find.text('2. İstasyon'), findsOneWidget);
    expect(find.text('3. İstasyon'), findsOneWidget);
    expect(find.text('Mini OSCE’yi Başlat'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
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

  testWidgets('theoretical setup confirms exhausted topic repeat', (
    tester,
  ) async {
    await _setViewport(tester, const Size(430, 1200));
    final repository = _ExhaustedTopicTheoreticalExamRepository();

    await tester.pumpWidget(
      MaterialApp(home: TheoreticalExamSetupScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dahiliye'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sepsis'));
    await tester.pumpAndSettle();

    expect(find.text('Konu tamamlandı'), findsOneWidget);
    expect(
      find.text(
        'Sepsis konusuyla ilgili tüm soruları çözdünüz. Tekrar çözmek ister misiniz?',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Tekrar Çöz'));
    await tester.pumpAndSettle();
    final startButton = find.widgetWithText(FilledButton, 'Denemeyi Başlat');
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    expect(repository.lastPlans.first.topics.single.metadataValue, 'Sepsis');
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

class _WalletStoreRepository extends StoreKitRepository {
  _WalletStoreRepository()
    : super(
        client: SupabaseClient(
          'https://example.supabase.co',
          'anon',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<WalletCatalog> loadWalletCatalog({
    String storeProvider = 'app_store',
  }) async {
    return const WalletCatalog(
      snapshot: WalletSnapshot(walletCoinBalance: 100, questionQuota: 50),
      products: [
        PratiCaseStoreProduct(
          code: 'mc_10',
          name: '10 MC',
          description: 'Recall işlemleri için Medasi Coin.',
          priceCents: 4000,
          currency: 'TRY',
          appStoreProductId: 'com.medasi.qlinik.mc.10',
          entitlementKind: 'one_time',
          interval: 'consumable',
          durationDays: 365,
          coinAmount: 10,
        ),
      ],
    );
  }

  @override
  Future<SubscriptionState> loadSubscriptionState() async {
    return const SubscriptionState(
      hasActiveSubscription: false,
      productCode: '',
      productName: '',
      expiresAt: null,
      periodStartedAt: null,
      willAutoRenew: false,
      environment: '',
      transactionId: '',
      originalTransactionId: '',
    );
  }

  @override
  Future<List<WalletTransaction>> loadWalletTransactions() async {
    return [
      WalletTransaction.fromMap({
        'id': 'purchase-qlinik-mc',
        'kind': 'one_time',
        'product_code': 'mc_25',
        'product_name': 'Qlinik MC Paketi',
        'coin_amount': 25,
        'question_amount': 0,
        'remaining_coin_amount': 25,
        'remaining_question_amount': 0,
        'status': 'active',
        'expired': false,
        'occurred_at': '2026-05-26T13:00:00Z',
      }),
      WalletTransaction.fromMap({
        'id': 'usage-1',
        'kind': 'usage',
        'product_code': 'praticase-patient-turn',
        'product_name': 'Sanal hasta görüşmesi',
        'coin_amount': -0.10,
        'question_amount': 0,
        'remaining_coin_amount': 0,
        'remaining_question_amount': 0,
        'status': 'consumed',
        'expired': false,
        'occurred_at': '2026-05-26T12:00:00Z',
      }),
    ];
  }
}

class _WalletStoreService extends StoreKitService {
  @override
  Future<bool> initialize() async => false;

  @override
  Future<List<PratiCaseStoreProduct>> attachStoreKitMetadata(
    List<PratiCaseStoreProduct> products,
  ) async => products;
}

class _RecordingStoreKitRepository extends StoreKitRepository {
  _RecordingStoreKitRepository()
    : super(
        client: SupabaseClient(
          'https://example.supabase.co',
          'anon',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final products = const [
    PratiCaseStoreProduct(
      code: 'mc_25',
      name: '25 MC',
      description: 'Medasi ekosistemi ortak coin paketi.',
      priceCents: 9900,
      currency: 'TRY',
      appStoreProductId: 'com.medasi.praticase.mc.25',
      entitlementKind: 'one_time',
      interval: 'consumable',
      durationDays: 365,
      coinAmount: 25,
    ),
  ];

  String? lastStoreProvider;
  String? verifiedProductCode;
  String? verifiedAppStoreProductId;
  String? verifiedProvider;
  String? verifiedPurchaseId;
  String? verifiedVerificationSource;
  String? verifiedServerVerificationData;

  @override
  Future<WalletCatalog> loadWalletCatalog({
    String storeProvider = 'app_store',
  }) async {
    lastStoreProvider = storeProvider;
    return WalletCatalog(
      products: products,
      snapshot: const WalletSnapshot(walletCoinBalance: 125, questionQuota: 50),
    );
  }

  @override
  Future<SubscriptionState> loadSubscriptionState() async {
    return const SubscriptionState(
      hasActiveSubscription: false,
      productCode: '',
      productName: '',
      expiresAt: null,
      periodStartedAt: null,
      willAutoRenew: false,
      environment: '',
      transactionId: '',
      originalTransactionId: '',
    );
  }

  @override
  Future<List<WalletTransaction>> loadWalletTransactions() async => const [];

  @override
  Future<SubscriptionState> verifyPurchase({
    required String productCode,
    required String appStoreProductId,
    required String provider,
    required String purchaseId,
    required String verificationSource,
    required String localVerificationData,
    required String serverVerificationData,
  }) async {
    verifiedProductCode = productCode;
    verifiedAppStoreProductId = appStoreProductId;
    verifiedProvider = provider;
    verifiedPurchaseId = purchaseId;
    verifiedVerificationSource = verificationSource;
    verifiedServerVerificationData = serverVerificationData;
    return const SubscriptionState(
      hasActiveSubscription: true,
      productCode: 'mc_25',
      productName: '25 MC',
      expiresAt: null,
      periodStartedAt: null,
      willAutoRenew: false,
      environment: 'sandbox',
      transactionId: 'tx-praticase-mc-25',
      originalTransactionId: 'tx-praticase-mc-25',
    );
  }
}

class _GiftCodeStoreRepository extends StoreKitRepository {
  _GiftCodeStoreRepository()
    : super(
        client: SupabaseClient(
          'https://example.supabase.co',
          'anon',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  String? redeemedCode;
  bool _redeemed = false;

  @override
  Future<WalletCatalog> loadWalletCatalog({
    String storeProvider = 'app_store',
  }) async {
    return WalletCatalog(
      products: const [],
      snapshot: _redeemed
          ? const WalletSnapshot(
              walletCoinBalance: 125,
              questionQuota: 60,
              aiQuota: 3,
            )
          : const WalletSnapshot(walletCoinBalance: 100, questionQuota: 50),
    );
  }

  @override
  Future<SubscriptionState> loadSubscriptionState() async {
    return const SubscriptionState(
      hasActiveSubscription: false,
      productCode: '',
      productName: '',
      expiresAt: null,
      periodStartedAt: null,
      willAutoRenew: false,
      environment: '',
      transactionId: '',
      originalTransactionId: '',
    );
  }

  @override
  Future<List<WalletTransaction>> loadWalletTransactions() async {
    if (!_redeemed) return const [];
    return [
      WalletTransaction.fromMap({
        'id': 'gift-code-1',
        'kind': 'gift',
        'product_code': 'gift_code',
        'product_name': 'Hediye kodu',
        'coin_amount': 25,
        'question_amount': 10,
        'remaining_coin_amount': 25,
        'remaining_question_amount': 10,
        'status': 'active',
        'expired': false,
        'occurred_at': '2026-06-04T12:00:00Z',
      }),
    ];
  }

  @override
  Future<GiftCodeRedemption> redeemGiftCode(String code) async {
    redeemedCode = normalizeGiftCode(code);
    _redeemed = true;
    return const GiftCodeRedemption(
      title: 'AdminPanel Hediye Kodu',
      coinAmount: 25,
      questionAmount: 10,
      aiQuestionAmount: 3,
      walletSnapshot: WalletSnapshot(
        walletCoinBalance: 125,
        questionQuota: 60,
        aiQuota: 3,
      ),
    );
  }
}

class _RecordingStoreKitService extends StoreKitService {
  final _updates = StreamController<PurchaseDetails>.broadcast();
  final completedPurchases = <String>[];

  @override
  Stream<PurchaseDetails> get purchaseUpdates => _updates.stream;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<List<PratiCaseStoreProduct>> attachStoreKitMetadata(
    List<PratiCaseStoreProduct> products,
  ) async => products;

  @override
  Future<bool> buy(PratiCaseStoreProduct product) async {
    _updates.add(
      PurchaseDetails(
        purchaseID: 'tx-praticase-mc-25',
        productID: product.appStoreProductId,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'local-jws',
          serverVerificationData: 'server-jws',
          source: 'app_store',
        ),
        transactionDate: '1780000000000',
        status: PurchaseStatus.purchased,
      )..pendingCompletePurchase = true,
    );
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases.add(purchase.purchaseID ?? '');
  }

  @override
  Future<void> dispose() async {
    await _updates.close();
    await super.dispose();
  }
}

class _RecordingGooglePlayService extends _RecordingStoreKitService {
  @override
  bool get isSupported => true;

  @override
  String get storeName => 'Google Play';

  @override
  String get verificationProvider => 'google_play';

  @override
  Future<bool> buy(PratiCaseStoreProduct product) async {
    _updates.add(
      PurchaseDetails(
        purchaseID: 'GPA.1234-5678-9012-34567',
        productID: product.appStoreProductId,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'play-local',
          serverVerificationData: 'play-token-mc-25',
          source: 'google_play',
        ),
        transactionDate: '1780000000000',
        status: PurchaseStatus.purchased,
      )..pendingCompletePurchase = true,
    );
    return true;
  }
}

class _FakeCasesRepository extends Fake implements CasesRepository {
  @override
  Future<List<OsceCaseSummary>> loadCases({
    String query = '',
    String? difficulty,
  }) async => const [];
}

class _MiniOsceCasesRepository extends Fake implements CasesRepository {
  @override
  Future<List<OsceCaseSummary>> loadCases({
    String query = '',
    String? difficulty,
  }) async => const [
    OsceCaseSummary(
      id: 'appendicitis',
      title: 'Akut Apandisit',
      branch: 'Genel Cerrahi',
      setting: 'Acil',
      difficulty: OsceDifficulty.medium,
      durationMinutes: 7,
      points: 100,
      solvedCount: 12,
      summary: 'Sağ alt kadran ağrısı ile başvuran hastayı değerlendir.',
      iconKey: 'abdomen',
      isBookmarked: false,
    ),
    OsceCaseSummary(
      id: 'ectopic',
      title: 'Ektopik Gebelik',
      branch: 'Kadın Doğum',
      setting: 'Acil',
      difficulty: OsceDifficulty.hard,
      durationMinutes: 7,
      points: 100,
      solvedCount: 9,
      summary: 'Alt karın ağrısı olan hastada acil yaklaşımı planla.',
      iconKey: 'pregnancy',
      isBookmarked: false,
    ),
    OsceCaseSummary(
      id: 'torsion',
      title: 'Testis Torsiyonu',
      branch: 'Üroloji',
      setting: 'Acil',
      difficulty: OsceDifficulty.hard,
      durationMinutes: 7,
      points: 100,
      solvedCount: 7,
      summary: 'Akut skrotum tablosunda kritik tanıyı değerlendir.',
      iconKey: 'urology',
      isBookmarked: false,
    ),
  ];
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

class _MiniOsceProgressRepository extends _FakeProgressRepository {
  @override
  Future<List<ExamModeItem>> loadExamModes() async => const [
    ExamModeItem(
      id: 'mini_osce',
      title: 'Mini OSCE',
      subtitle: '3 istasyon seç, arka arkaya tamamla.',
      iconKey: 'route',
      actionKey: 'mini_osce',
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

  OralExamSession get soloSession => OralExamSession(
    id: 'solo-session',
    durationSeconds: 900,
    caseBrief: 'Göğüs ağrısı ile başvuran hasta.',
    startedAt: DateTime.now(),
    personaId: 'lead',
    personaTitle: 'Sert Profesör',
    difficulty: 'Zor',
    branchId: 'dahiliye',
    branchTitle: 'Dahiliye',
    openingMessage: 'Bu hastada öncelikli tanınız nedir?',
    format: OralExamFormat.solo,
    panel: const [],
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

class _ExhaustedTopicTheoreticalExamRepository
    extends _RecordingTheoreticalExamRepository {
  @override
  Future<TheoreticalExamFilters> loadFilters() async {
    const sepsis = TheoreticalTopicOption(
      course: 'Dahiliye',
      topic: 'Enfeksiyon',
      metadataValue: 'Sepsis',
      totalCount: 20,
      remainingCount: 0,
    );
    return const TheoreticalExamFilters(
      courses: ['Dahiliye'],
      topicsByCourse: {
        'Dahiliye': ['Sepsis'],
      },
      topicOptionsByCourse: {
        'Dahiliye': [sepsis],
      },
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
          appStoreProductId: 'com.medasi.qlinik.intense',
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
  bool _finalDelivered = false;

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
    // Model a single spoken utterance: hands-free auto-resume reopens the mic,
    // but the simulated user only speaks once (further opens stay silent).
    if (!_finalDelivered) {
      _finalDelivered = true;
      onPartialText('Ağrınız');
      onFinalText('Ağrınız ne zaman başladı?');
    }
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

class _InterruptedPlaybackVoiceExamAdapter implements VoiceExamAdapter {
  final _controller = StreamController<VoiceExamState>.broadcast();
  VoiceExamState _state = const VoiceExamState();
  int listenStarts = 0;

  @override
  VoiceExamState get state => _state;

  @override
  Stream<VoiceExamState> get states => _controller.stream;

  @override
  Future<void> initialize() async {
    _emit(const VoiceExamState(available: true, initialized: true));
  }

  @override
  Future<void> startListening({
    required void Function(String text) onFinalText,
    required void Function(String text) onPartialText,
  }) async {
    listenStarts++;
    _emit(_state.copyWith(listening: true));
  }

  @override
  Future<void> stopListening() async {
    _emit(_state.copyWith(listening: false));
  }

  @override
  Future<void> speak(String text) async {
    _emit(_state.copyWith(speaking: true));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    _emit(_state.copyWith(speaking: false));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _emit(_state.copyWith(speaking: true));
    await Future<void>.delayed(const Duration(milliseconds: 360));
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

class _RecallHomeRepository extends Fake implements HomeRepository {
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
      recallSummary: RecallSummary(
        todayTotal: 3,
        weaknesses: [
          RecallWeakness(
            title: 'Akut batın - Ayırıcı tanı',
            riskLevel: 'high',
            topic: 'Akut batın',
          ),
        ],
        guidance: RecallGuidance(
          sentence: 'Önce akut batın ayrımını toparla.',
          action: 'Tek istasyon çöz.',
        ),
        action: 'Tek istasyon çöz.',
      ),
      unreadNotificationCount: 0,
    );
  }
}

class _RecallEmptyHomeRepository extends Fake implements HomeRepository {
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
      recallSummary: RecallSummary(
        todayTotal: 0,
        weaknesses: [],
        guidance: RecallGuidance.empty(),
        action: '',
      ),
      unreadNotificationCount: 0,
    );
  }
}

const _supportedDeviceViewports = <String, Size>{
  'iPhone 11': Size(414, 896),
  'iPhone 17 Pro': Size(402, 874),
  'iPhone 17 Pro Max': Size(440, 956),
  'iPad 5 / iPad mini 2 portrait': Size(768, 1024),
  'latest iPad mini portrait': Size(744, 1133),
  'iPad Pro 11 portrait': Size(834, 1194),
  'iPad Pro landscape': Size(1366, 1024),
};

const _authDeviceViewports = <String, Size>{
  'iPhone 11': Size(414, 896),
  'iPhone 17 Pro': Size(402, 874),
  'iPad 5 portrait': Size(768, 1024),
  'iPad Pro landscape': Size(1366, 1024),
};

const _commonAuthCompatibilityViewports = <String, Size>{
  'iPhone SE compact': Size(320, 568),
  'compact Android': Size(360, 740),
  'iPhone 14': Size(390, 844),
  'mobile landscape': Size(844, 390),
  'iPad 5 portrait': Size(768, 1024),
};

const _keyboardSafeViewports = <String, (Size, double)>{
  'iPhone 11 keyboard': (Size(414, 896), 336),
  'iPhone 17 Pro keyboard': (Size(402, 874), 336),
  'iPad mini keyboard': (Size(744, 1133), 380),
  'iPad Pro landscape keyboard': (Size(1366, 1024), 360),
};

const _supportResultSummary = ExamResultSummary(
  sessionId: 'session-1',
  caseTitle: 'Akut Apandisit',
  totalScore: 62,
  maxScore: 100,
  percentage: 62,
  categoryScores: [
    ResultCategoryScore(title: 'Anamnez', score: 18, maxScore: 30),
    ResultCategoryScore(title: 'Fizik Muayene', score: 8, maxScore: 20),
    ResultCategoryScore(title: 'Tetkikler', score: 11, maxScore: 15),
  ],
  strongPoints: ['Ana şikayeti açtın.'],
  improvementPoints: ['Ağrı karakterini daha net yapılandır.'],
  criticalMistakes: ['Peritonit bulgularını geciktirme.'],
  unnecessaryTests: ['Kontrastsız BT'],
  missedTests: ['CRP'],
  missedHistory: ['İştahsızlık'],
  missedPhysicalExam: ['Rebound ve defans'],
  idealApproach:
      'Ağrı özellikleri, eşlik eden bulgular ve hedefe yönelik batın muayenesiyle ilerle.',
  checklistSections: [
    ResultChecklistSection(
      title: 'Anamnez',
      key: 'history',
      coveredCount: 1,
      totalCount: 3,
      items: [
        ResultChecklistItem(
          label: 'Ağrının başlangıcı',
          status: 'covered',
          evidence: 'Ne zaman başladı diye sordu.',
        ),
        ResultChecklistItem(
          label: 'Ağrı yayılımı',
          status: 'partial',
          note: 'Yeri soruldu, yayılım derinleştirilmedi.',
        ),
        ResultChecklistItem(label: 'İştahsızlık', status: 'missed'),
      ],
    ),
  ],
);

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
  Stream<AuthUser?> authStateChanges() => const Stream<AuthUser?>.empty();

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = true,
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
  Future<void> deleteAccount() async {}

  @override
  Future<void> signOut() async {}
}

class _RecordingAuthRepository extends _TestAuthRepository {
  ProfileSetup? completedProfile;
  String? resetEmail;
  bool deletedAccount = false;

  @override
  Future<void> sendPasswordResetCode(String email) async {
    resetEmail = email;
  }

  @override
  Future<AuthUser> completeProfile(ProfileSetup setup) async {
    completedProfile = setup;
    return super.completeProfile(setup);
  }

  @override
  Future<void> deleteAccount() async {
    deletedAccount = true;
  }
}

class _StreamingAuthRepository extends _TestAuthRepository {
  final _controller = StreamController<AuthUser?>.broadcast();

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  void emit(AuthUser? user) => _controller.add(user);

  void dispose() => _controller.close();
}

class _PendingThenUnavailableAuthRepository extends _TestAuthRepository {
  int _currentUserCalls = 0;
  ProfileSetup? completedProfile;

  @override
  Future<AuthUser?> currentUser() async {
    _currentUserCalls++;
    if (_currentUserCalls == 1) {
      return const AuthUser(
        id: 'test-user',
        email: 'ayse@example.com',
        fullName: 'Ayse Yilmaz',
        emailVerified: true,
      );
    }
    return null;
  }

  @override
  Future<AuthUser> completeProfile(ProfileSetup setup) async {
    completedProfile = setup;
    return const AuthUser(
      id: 'test-user',
      email: 'ayse@example.com',
      fullName: 'Ayse Yilmaz',
      emailVerified: true,
      profileCompleted: true,
    );
  }
}
