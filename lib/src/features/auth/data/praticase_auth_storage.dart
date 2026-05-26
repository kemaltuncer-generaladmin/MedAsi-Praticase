import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase session storage wrapper for the PratiCase "Beni hatirla" choice.
///
/// Supabase persists sessions by default. This wrapper keeps that default for
/// Medasi SSO continuity, while allowing a single sign-in to stay in memory only
/// when the user disables "Beni hatirla".
class PratiCaseAuthStorage extends LocalStorage {
  PratiCaseAuthStorage({required String supabaseUrl})
    : _delegate = SharedPreferencesLocalStorage(
        persistSessionKey: _persistSessionKey(supabaseUrl),
      );

  final SharedPreferencesLocalStorage _delegate;
  bool _persistNewSessions = true;

  Future<void> setRememberMe(bool rememberMe) async {
    _persistNewSessions = rememberMe;
    if (!rememberMe) {
      await _delegate.removePersistedSession();
    }
  }

  @override
  Future<void> initialize() => _delegate.initialize();

  @override
  Future<bool> hasAccessToken() => _delegate.hasAccessToken();

  @override
  Future<String?> accessToken() => _delegate.accessToken();

  @override
  Future<void> removePersistedSession() => _delegate.removePersistedSession();

  @override
  Future<void> persistSession(String persistSessionString) async {
    if (_persistNewSessions) {
      await _delegate.persistSession(persistSessionString);
      return;
    }
    await _delegate.removePersistedSession();
  }

  static String _persistSessionKey(String supabaseUrl) {
    final host = Uri.parse(supabaseUrl).host;
    final projectKey = host.split('.').first;
    return 'sb-$projectKey-auth-token';
  }
}
