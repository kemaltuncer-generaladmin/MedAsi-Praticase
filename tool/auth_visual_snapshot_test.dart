import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticase/src/features/auth/data/auth_repository.dart';
import 'package:praticase/src/features/auth/domain/auth_user.dart';
import 'package:praticase/src/features/auth/domain/profile_setup.dart';
import 'package:praticase/src/features/auth/presentation/screens/login_screen.dart';
import 'package:praticase/src/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:praticase/src/features/auth/presentation/screens/register_screen.dart';
import 'package:praticase/src/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:praticase/src/features/auth/presentation/screens/verify_email_screen.dart';

void main() {
  testWidgets('capture selected auth snapshot', (tester) async {
    await _loadSnapshotFonts();
    final selected = Platform.environment['AUTH_SNAPSHOT'] ?? 'login';
    final repository = _SnapshotAuthRepository();
    final scenario = _scenarioFor(selected, repository);
    await _capture(tester, scenario);
  });
}

_SnapshotScenario _scenarioFor(
  String selected,
  _SnapshotAuthRepository repository,
) {
  return switch (selected) {
    'register_top' => _SnapshotScenario(
      fileName: 'praticase_auth_register_320_top_widget_qa.png',
      size: const Size(320, 568),
      child: RegisterScreen(
        repository: repository,
        onBack: () {},
        onLogin: () {},
        onRegistered: (_, _) {},
      ),
    ),
    'register_bottom' => _SnapshotScenario(
      fileName: 'praticase_auth_register_320_bottom_widget_qa.png',
      size: const Size(320, 568),
      child: RegisterScreen(
        repository: repository,
        onBack: () {},
        onLogin: () {},
        onRegistered: (_, _) {},
      ),
      beforeShot: (tester) async {
        await tester.ensureVisible(find.text('Hesabımı Oluştur'));
        await tester.pump(const Duration(milliseconds: 600));
      },
    ),
    'reset' => _SnapshotScenario(
      fileName: 'praticase_auth_reset_320_widget_qa.png',
      size: const Size(320, 568),
      child: ResetPasswordScreen(
        repository: repository,
        email: 'ayse@example.com',
        onBack: () {},
        onPasswordUpdated: () {},
      ),
    ),
    'verify' => _SnapshotScenario(
      fileName: 'praticase_auth_verify_320_widget_qa.png',
      size: const Size(320, 568),
      child: VerifyEmailScreen(
        repository: repository,
        email: 'ayse@example.com',
        fullName: 'Ayşe Yılmaz',
        onBack: () {},
        onVerified: () {},
      ),
    ),
    'profile' => _SnapshotScenario(
      fileName: 'praticase_auth_profile_320_widget_qa.png',
      size: const Size(320, 568),
      child: ProfileSetupScreen(
        repository: repository,
        fullName: 'Ayşe Yılmaz',
        onBack: () {},
        onCompleted: (_) {},
      ),
    ),
    'landscape' => _SnapshotScenario(
      fileName: 'praticase_auth_login_landscape_widget_qa.png',
      size: const Size(844, 390),
      child: LoginScreen(
        repository: repository,
        onForgotPassword: () {},
        onRegister: () {},
        onSignedIn: (_) {},
      ),
    ),
    _ => _SnapshotScenario(
      fileName: 'praticase_auth_login_320_widget_qa.png',
      size: const Size(320, 568),
      child: LoginScreen(
        repository: repository,
        onForgotPassword: () {},
        onRegister: () {},
        onSignedIn: (_) {},
      ),
    ),
  };
}

Future<void> _capture(WidgetTester tester, _SnapshotScenario scenario) async {
  final outputDir = Directory('artifacts/figma_auth')
    ..createSync(recursive: true);
  final boundaryKey = GlobalKey();
  tester.view.physicalSize = scenario.size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'SnapshotFont', useMaterial3: true),
        home: scenario.child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  expect(tester.takeException(), isNull, reason: scenario.fileName);

  if (scenario.beforeShot != null) {
    await scenario.beforeShot!(tester);
    expect(
      tester.takeException(),
      isNull,
      reason: '${scenario.fileName} after scroll',
    );
  }

  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(
    '${outputDir.path}/${scenario.fileName}',
  ).writeAsBytesSync(byteData!.buffer.asUint8List());
}

Future<void> _loadSnapshotFonts() async {
  final textFont = FontLoader('SnapshotFont')
    ..addFont(_fontData('/System/Library/Fonts/SFNS.ttf'));
  await textFont.load();

  final iconFontPath =
      '/Users/kemaltuncer/.pub-cache/hosted/pub.dev/shared_preferences-2.5.5/extension/devtools/build/assets/fonts/MaterialIcons-Regular.otf';
  if (File(iconFontPath).existsSync()) {
    final iconFont = FontLoader('MaterialIcons')
      ..addFont(_fontData(iconFontPath));
    await iconFont.load();
  }
}

Future<ByteData> _fontData(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(Uint8List.fromList(bytes));
}

class _SnapshotScenario {
  const _SnapshotScenario({
    required this.fileName,
    required this.size,
    required this.child,
    this.beforeShot,
  });

  final String fileName;
  final Size size;
  final Widget child;
  final Future<void> Function(WidgetTester tester)? beforeShot;
}

class _SnapshotAuthRepository implements AuthRepository {
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
    return AuthUser(id: 'snapshot-user', email: email, emailVerified: true);
  }

  @override
  Future<AuthUser> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    return AuthUser(id: 'snapshot-user', email: email, fullName: fullName);
  }

  @override
  Future<void> sendPasswordResetCode(String email) async {}

  @override
  Future<AuthUser> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    return AuthUser(id: 'snapshot-user', email: email, emailVerified: true);
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
      id: 'snapshot-user',
      email: 'ayse@example.com',
      emailVerified: true,
      profileCompleted: true,
    );
  }

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> signOut() async {}
}
