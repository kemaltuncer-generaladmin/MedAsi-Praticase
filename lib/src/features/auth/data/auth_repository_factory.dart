import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_config.dart';
import 'auth_repository.dart';
import 'mock_auth_repository.dart';
import 'supabase_auth_repository.dart';

abstract final class AuthRepositoryFactory {
  static Future<AuthRepository> create() async {
    final config = AuthConfig.fromEnvironment();
    if (!config.canUseSupabase) {
      return MockAuthRepository();
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
