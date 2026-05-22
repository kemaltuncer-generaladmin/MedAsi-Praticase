import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_config.dart';
import 'auth_repository.dart';
import 'supabase_auth_repository.dart';

abstract final class AuthRepositoryFactory {
  static Future<AuthRepository> create() async {
    final config = AuthConfig.fromEnvironment();
    if (!config.canUseSupabase) {
      throw const PratiCaseConfigurationException(
        'SUPABASE_URL ve SUPABASE_ANON_KEY tanımlanmadan PratiCase başlatılamaz.',
      );
    }

    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
    );

    return SupabaseAuthRepository(
      client: Supabase.instance.client,
      config: config,
    );
  }
}

class PratiCaseConfigurationException implements Exception {
  const PratiCaseConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}
