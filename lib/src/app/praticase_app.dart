import 'package:flutter/material.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/auth_flow.dart';
import '../features/cases/data/cases_repository.dart';
import '../features/home/data/home_repository.dart';
import '../features/progress/data/progress_repository.dart';
import '../features/shell/presentation/praticase_shell.dart';
import '../features/theoretical_exam/data/theoretical_exam_repository.dart';
import 'theme/praticase_theme.dart';

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
    return MaterialApp(
      title: 'PratiCase',
      debugShowCheckedModeBanner: false,
      theme: PratiCaseTheme.light(),
      home: _restoringSession
          ? const _PratiCaseStartupScreen()
          : _gate == _SessionGate.authenticated
          ? PratiCaseShell(
              authRepository: widget.authRepository,
              homeRepository: widget.homeRepository,
              casesRepository: widget.casesRepository,
              progressRepository: widget.progressRepository,
              theoreticalExamRepository: widget.theoreticalExamRepository,
              onSignOut: _signOut,
            )
          : AuthFlow(
              authRepository: widget.authRepository,
              initialStep: _gate == _SessionGate.profilePending
                  ? AuthStep.profileSetup
                  : AuthStep.onboarding,
              initialEmail: _initialEmail,
              initialFullName: _initialFullName,
              onAuthenticated: () =>
                  setState(() => _gate = _SessionGate.authenticated),
            ),
    );
  }
}

enum _SessionGate { loggedOut, profilePending, authenticated }

class _PratiCaseStartupScreen extends StatelessWidget {
  const _PratiCaseStartupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF7F9FB),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
