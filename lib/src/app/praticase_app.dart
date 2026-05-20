import 'package:flutter/material.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/auth_flow.dart';
import '../features/shell/presentation/praticase_shell.dart';
import 'theme/praticase_theme.dart';

class PratiCaseApp extends StatefulWidget {
  const PratiCaseApp({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<PratiCaseApp> createState() => _PratiCaseAppState();
}

class _PratiCaseAppState extends State<PratiCaseApp> {
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final user = await widget.authRepository.currentUser();
    if (!mounted || user == null) return;
    setState(
      () => _authenticated = user.profileCompleted || user.emailVerified,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PratiCase',
      debugShowCheckedModeBanner: false,
      theme: PratiCaseTheme.light(),
      home: _authenticated
          ? const PratiCaseShell()
          : AuthFlow(
              authRepository: widget.authRepository,
              onAuthenticated: () => setState(() => _authenticated = true),
            ),
    );
  }
}
