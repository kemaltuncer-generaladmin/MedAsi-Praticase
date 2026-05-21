import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app/praticase_app.dart';
import 'src/features/auth/data/auth_repository_factory.dart';
import 'src/features/cases/data/supabase_cases_repository.dart';
import 'src/features/home/data/supabase_home_repository.dart';
import 'src/features/progress/data/supabase_progress_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authRepository = await AuthRepositoryFactory.create();
  final homeRepository = authRepository.isConfigured
      ? SupabaseHomeRepository(client: Supabase.instance.client)
      : null;
  final casesRepository = authRepository.isConfigured
      ? SupabaseCasesRepository(client: Supabase.instance.client)
      : null;
  final progressRepository = authRepository.isConfigured
      ? SupabaseProgressRepository(client: Supabase.instance.client)
      : null;
  runApp(
    PratiCaseApp(
      authRepository: authRepository,
      homeRepository: homeRepository,
      casesRepository: casesRepository,
      progressRepository: progressRepository,
    ),
  );
}
