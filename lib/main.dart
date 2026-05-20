import 'package:flutter/material.dart';

import 'src/app/praticase_app.dart';
import 'src/features/auth/data/auth_repository_factory.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authRepository = await AuthRepositoryFactory.create();
  runApp(PratiCaseApp(authRepository: authRepository));
}
