import 'dart:async';

import 'package:flutter/material.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/auth_user.dart';
import '../features/auth/presentation/auth_flow.dart';
import '../features/cases/data/cases_repository.dart';
import '../features/home/data/home_repository.dart';
import '../features/oral_exam/data/oral_exam_repository.dart';
import '../features/progress/data/progress_repository.dart';
import '../features/shell/presentation/praticase_shell.dart';
import '../features/theoretical_exam/data/theoretical_exam_repository.dart';
import 'theme/praticase_accent.dart';
import 'theme/praticase_colors.dart';
import 'theme/praticase_motion.dart';
import 'theme/praticase_performance.dart';
import 'theme/praticase_theme.dart';
import 'theme/praticase_tokens.dart';

class PratiCaseApp extends StatefulWidget {
  const PratiCaseApp({
    required this.authRepository,
    required this.homeRepository,
    required this.casesRepository,
    required this.progressRepository,
    required this.theoreticalExamRepository,
    required this.oralExamRepository,
    super.key,
  });

  final AuthRepository authRepository;
  final HomeRepository homeRepository;
  final CasesRepository casesRepository;
  final ProgressRepository progressRepository;
  final TheoreticalExamRepository theoreticalExamRepository;
  final OralExamRepository oralExamRepository;

  @override
  State<PratiCaseApp> createState() => _PratiCaseAppState();
}

class _PratiCaseAppState extends State<PratiCaseApp> {
  _SessionGate _gate = _SessionGate.loggedOut;
  bool _restoringSession = true;
  String _initialEmail = '';
  String _initialFullName = '';
  StreamSubscription<AuthUser?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = widget.authRepository.authStateChanges().listen(
      _handleAuthStateChange,
      onError: (_) => _handleAuthStateChange(null),
    );
    _restoreSession();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    AuthUser? user;
    try {
      user = await widget.authRepository.currentUser();
    } on Object {
      user = null;
    }
    if (!mounted) return;
    _applySessionUser(user, restoringSession: false);
  }

  void _handleAuthStateChange(AuthUser? user) {
    if (!mounted) return;
    if (user == null) {
      setState(() {
        _initialEmail = '';
        _initialFullName = '';
        _gate = _SessionGate.loggedOut;
        _restoringSession = false;
      });
      return;
    }

    _applySessionUser(user, restoringSession: false);
  }

  void _applySessionUser(AuthUser? user, {required bool restoringSession}) {
    setState(() {
      _initialEmail = user?.email ?? '';
      _initialFullName = user?.fullName ?? '';
      _gate = user == null
          ? _SessionGate.loggedOut
          : user.profileCompleted
          ? _SessionGate.authenticated
          : _SessionGate.profilePending;
      _restoringSession = restoringSession;
    });
  }

  Future<void> _signOut() async {
    await widget.authRepository.signOut();
    if (!mounted) return;
    setState(() => _gate = _SessionGate.loggedOut);
  }

  Future<void> _completeAuthentication(AuthUser completedUser) async {
    if (completedUser.profileCompleted) {
      _applySessionUser(completedUser, restoringSession: false);
      return;
    }

    AuthUser? user;
    try {
      user = await widget.authRepository.currentUser();
    } on Object {
      user = null;
    }
    if (!mounted) return;
    if (user == null) {
      _applySessionUser(null, restoringSession: false);
      return;
    }
    _applySessionUser(user, restoringSession: false);
  }

  Widget _buildSessionBody({
    AuthStep? requestedAuthStep,
    ValueChanged<AuthUser>? onAuthenticated,
  }) {
    if (_restoringSession) {
      return const _PratiCaseStartupScreen();
    }
    if (_gate == _SessionGate.authenticated) {
      return PratiCaseShell(
        authRepository: widget.authRepository,
        homeRepository: widget.homeRepository,
        casesRepository: widget.casesRepository,
        progressRepository: widget.progressRepository,
        theoreticalExamRepository: widget.theoreticalExamRepository,
        oralExamRepository: widget.oralExamRepository,
        onSignOut: _signOut,
      );
    }

    return AuthFlow(
      authRepository: widget.authRepository,
      initialStep:
          requestedAuthStep ??
          (_gate == _SessionGate.profilePending
              ? AuthStep.profileSetup
              : AuthStep.onboarding),
      initialEmail: _initialEmail,
      initialFullName: _initialFullName,
      onAuthenticated:
          onAuthenticated ?? (user) => unawaited(_completeAuthentication(user)),
    );
  }

  String _sessionBodyKey() {
    if (_restoringSession) return 'startup';
    if (_gate == _SessionGate.authenticated) return 'shell';
    return 'auth';
  }

  Route<dynamic>? _onGenerateWebRoute(RouteSettings settings) {
    if (!PratiCasePerformance.web) return null;
    final step = _authStepForWebRoute(settings.name);
    if (step == null) return null;
    return _buildWebRoute(settings, requestedAuthStep: step);
  }

  Route<dynamic>? _onUnknownWebRoute(RouteSettings settings) {
    if (!PratiCasePerformance.web) return null;
    return _buildWebRoute(settings);
  }

  MaterialPageRoute<void> _buildWebRoute(
    RouteSettings settings, {
    AuthStep? requestedAuthStep,
  }) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (routeContext) => _buildSessionBody(
        requestedAuthStep: requestedAuthStep,
        onAuthenticated: (user) {
          unawaited(_completeAuthentication(user));
          Navigator.of(routeContext).popUntil((route) => route.isFirst);
        },
      ),
    );
  }

  AuthStep? _authStepForWebRoute(String? routeName) {
    final raw = routeName ?? '';
    final hashIndex = raw.indexOf('#');
    final routed = hashIndex >= 0 ? raw.substring(hashIndex + 1) : raw;
    final path = routed.split('?').first;
    return switch (path) {
      '/login' => AuthStep.login,
      '/register' => AuthStep.register,
      '/forgot-password' => AuthStep.forgotPassword,
      '/reset-password' => AuthStep.resetPassword,
      '/verify-email' => AuthStep.verifyEmail,
      '/profile-setup' => AuthStep.profileSetup,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildSessionBody();
    final bodyKey = _sessionBodyKey();

    return ListenableBuilder(
      listenable: PratiCaseAccent.instance,
      builder: (context, _) => MaterialApp(
        title: 'PratiCase',
        debugShowCheckedModeBanner: false,
        theme: PratiCaseTheme.light(accent: PratiCaseAccent.instance.primary),
        themeMode: ThemeMode.light,
        onGenerateRoute: PratiCasePerformance.web ? _onGenerateWebRoute : null,
        onUnknownRoute: PratiCasePerformance.web ? _onUnknownWebRoute : null,
        home: AnimatedSwitcher(
          duration: PratiCaseDurations.emphasized,
          switchInCurve: PratiCaseCurves.emphasized,
          switchOutCurve: PratiCaseCurves.exit,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(key: ValueKey(bodyKey), child: body),
        ),
      ),
    );
  }
}

enum _SessionGate { loggedOut, profilePending, authenticated }

class _PratiCaseStartupScreen extends StatelessWidget {
  const _PratiCaseStartupScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PratiCaseColors.softSurface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
              child: Image.asset(
                'assets/auth/praticase_icon.png',
                width: 72,
                height: 72,
              ),
            ),
            const SizedBox(height: 18),
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Prati'),
                  TextSpan(
                    text: 'Case',
                    style: TextStyle(color: PratiCaseColors.teal),
                  ),
                ],
              ),
              style: TextStyle(
                color: PratiCaseColors.navy,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 22),
            const PratiCaseSpinner(),
          ],
        ),
      ),
    );
  }
}
