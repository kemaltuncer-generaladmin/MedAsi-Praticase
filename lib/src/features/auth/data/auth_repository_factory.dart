import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_config.dart';
import 'praticase_auth_storage.dart';
import 'auth_repository.dart';
import 'supabase_auth_repository.dart';

abstract final class AuthRepositoryFactory {
  static Future<AuthRepository> create() async {
    final config = AuthConfig.fromEnvironment();
    if (!config.canUseSupabase) {
      throw const PratiCaseConfigurationException(
        'Uygulamaya erişim şu anda sağlanamıyor. Lütfen daha sonra tekrar dene veya destek ekibine ulaş.',
      );
    }

    final authStorage = PratiCaseAuthStorage(supabaseUrl: config.supabaseUrl);
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(localStorage: authStorage),
    );

    return SupabaseAuthRepository(
      client: Supabase.instance.client,
      config: config,
      authStorage: authStorage,
    );
  }
}

class PratiCaseConfigurationException implements Exception {
  const PratiCaseConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}
