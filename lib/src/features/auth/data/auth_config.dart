class AuthConfig {
  const AuthConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.redirectUrl,
  });

  static const _defaultMedasiAuthUrl = 'https://qlinik.medasi.com.tr';

  factory AuthConfig.fromEnvironment() {
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const flutterSupabaseUrl = String.fromEnvironment('FLUTTER_SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const redirectUrl = String.fromEnvironment(
      'AUTH_REDIRECT_URL',
      defaultValue: 'https://praticase.medasi.com.tr/auth/callback',
    );

    return AuthConfig(
      supabaseUrl: supabaseUrl.isNotEmpty
          ? supabaseUrl
          : flutterSupabaseUrl.isNotEmpty
          ? flutterSupabaseUrl
          : _defaultMedasiAuthUrl,
      supabaseAnonKey: supabaseAnonKey,
      redirectUrl: redirectUrl,
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String redirectUrl;

  bool get canUseSupabase => supabaseAnonKey.isNotEmpty;
}
