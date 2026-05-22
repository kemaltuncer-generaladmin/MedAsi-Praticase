import 'package:flutter/material.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/auth_flow.dart';
import '../features/cases/data/cases_repository.dart';
import '../features/home/data/home_repository.dart';
import '../features/progress/data/progress_repository.dart';
import '../features/shell/presentation/praticase_shell.dart';
import 'theme/praticase_theme.dart';

class PratiCaseApp extends StatefulWidget {
  const PratiCaseApp({
    required this.authRepository,
    required this.homeRepository,
    required this.casesRepository,
    required this.progressRepository,
    super.key,
  });

  final AuthRepository authRepository;
  final HomeRepository homeRepository;
  final CasesRepository casesRepository;
  final ProgressRepository progressRepository;

  @override
  State<PratiCaseApp> createState() => _PratiCaseAppState();
}

class _PratiCaseAppState extends State<PratiCaseApp> {
  bool _authenticated = false;
  bool _restoringSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final user = await widget.authRepository.currentUser();
    if (!mounted) return;
    setState(() {
      _authenticated =
          user?.profileCompleted == true || user?.emailVerified == true;
      _restoringSession = false;
    });
  }

  Future<void> _signOut() async {
    await widget.authRepository.signOut();
    if (!mounted) return;
    setState(() => _authenticated = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PratiCase',
      debugShowCheckedModeBanner: false,
      theme: PratiCaseTheme.light(),
      home: _restoringSession
          ? const _PratiCaseStartupScreen()
          : _authenticated
          ? PratiCaseShell(
              homeRepository: widget.homeRepository,
              casesRepository: widget.casesRepository,
              progressRepository: widget.progressRepository,
              onSignOut: _signOut,
            )
          : AuthFlow(
              authRepository: widget.authRepository,
              onAuthenticated: () => setState(() => _authenticated = true),
            ),
    );
  }
}

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
