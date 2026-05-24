import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app/theme/praticase_colors.dart';
import 'src/app/theme/praticase_theme.dart';
import 'src/app/praticase_app.dart';
import 'src/features/auth/data/auth_repository_factory.dart';
import 'src/features/cases/data/supabase_cases_repository.dart';
import 'src/features/home/data/supabase_home_repository.dart';
import 'src/features/oral_exam/data/supabase_oral_exam_repository.dart';
import 'src/features/progress/data/supabase_progress_repository.dart';
import 'src/features/theoretical_exam/data/supabase_theoretical_exam_repository.dart';
import 'src/shared/data/repository_timeout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final authRepository = await AuthRepositoryFactory.create();
    final client = Supabase.instance.client;
    runApp(
      PratiCaseApp(
        authRepository: authRepository,
        homeRepository: TimeoutHomeRepository(
          SupabaseHomeRepository(client: client),
        ),
        casesRepository: TimeoutCasesRepository(
          SupabaseCasesRepository(client: client),
        ),
        progressRepository: TimeoutProgressRepository(
          SupabaseProgressRepository(client: client),
        ),
        theoreticalExamRepository: TimeoutTheoreticalExamRepository(
          SupabaseTheoreticalExamRepository(client: client),
        ),
        oralExamRepository: SupabaseOralExamRepository(client: client),
      ),
    );
  } on PratiCaseConfigurationException catch (error) {
    runApp(_ConfigurationGate(message: error.message));
  }
}

class _ConfigurationGate extends StatelessWidget {
  const _ConfigurationGate({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PratiCase',
      debugShowCheckedModeBanner: false,
      theme: PratiCaseTheme.light(),
      home: Scaffold(
        backgroundColor: const Color(0xFFF7F9FB),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/auth/praticase_icon.png',
                    width: 72,
                    height: 72,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'PratiCase yapılandırması eksik',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: PratiCaseColors.navy,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF5F6D7E),
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
