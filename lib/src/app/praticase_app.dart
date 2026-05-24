import 'package:flutter/material.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/auth_flow.dart';
import '../features/cases/data/cases_repository.dart';
import '../features/home/data/home_repository.dart';
import '../features/progress/data/progress_repository.dart';
import '../features/shell/presentation/praticase_shell.dart';
import '../features/theoretical_exam/data/theoretical_exam_repository.dart';
import 'theme/praticase_colors.dart';
import 'theme/praticase_motion.dart';
import 'theme/praticase_theme.dart';
import 'theme/praticase_tokens.dart';

class PratiCaseApp extends StatefulWidget {
  const PratiCaseApp({
    required this.authRepository,
    required this.homeRepository,
    required this.casesRepository,
    required this.progressRepository,
    required this.theoreticalExamRepository,
    super.key,
  });

  final AuthRepository authRepository;
  final HomeRepository homeRepository;
  final CasesRepository casesRepository;
  final ProgressRepository progressRepository;
  final TheoreticalExamRepository theoreticalExamRepository;

  @override
  State<PratiCaseApp> createState() => _PratiCaseAppState();
}

class _PratiCaseAppState extends State<PratiCaseApp> {
  _SessionGate _gate = _SessionGate.loggedOut;
  bool _restoringSession = true;
  String _initialEmail = '';
  String _initialFullName = '';

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final user = await widget.authRepository.currentUser();
    if (!mounted) return;
    setState(() {
      _initialEmail = user?.email ?? '';
      _initialFullName = user?.fullName ?? '';
      _gate = user == null
          ? _SessionGate.loggedOut
          : user.profileCompleted
          ? _SessionGate.authenticated
          : _SessionGate.profilePending;
      _restoringSession = false;
    });
  }

  Future<void> _signOut() async {
    await widget.authRepository.signOut();
    if (!mounted) return;
    setState(() => _gate = _SessionGate.loggedOut);
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    final String bodyKey;
    if (_restoringSession) {
      body = const _PratiCaseStartupScreen();
      bodyKey = 'startup';
    } else if (_gate == _SessionGate.authenticated) {
      body = PratiCaseShell(
        authRepository: widget.authRepository,
        homeRepository: widget.homeRepository,
        casesRepository: widget.casesRepository,
        progressRepository: widget.progressRepository,
        theoreticalExamRepository: widget.theoreticalExamRepository,
        onSignOut: _signOut,
      );
      bodyKey = 'shell';
    } else {
      body = AuthFlow(
        authRepository: widget.authRepository,
        initialStep: _gate == _SessionGate.profilePending
            ? AuthStep.profileSetup
            : AuthStep.onboarding,
        initialEmail: _initialEmail,
        initialFullName: _initialFullName,
        onAuthenticated: () =>
            setState(() => _gate = _SessionGate.authenticated),
      );
      bodyKey = 'auth';
    }

    return MaterialApp(
      title: 'PratiCase',
      debugShowCheckedModeBanner: false,
      theme: PratiCaseTheme.light(),
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
