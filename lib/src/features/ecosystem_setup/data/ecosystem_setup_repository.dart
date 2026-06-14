import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ecosystem_setup_profile.dart';

class EcosystemSetupRepository {
  const EcosystemSetupRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  Future<EcosystemSetupProfile?> fetchCurrent() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final row = await _client
        .from('user_setup_profiles')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return EcosystemSetupProfile.fromJson(Map<String, dynamic>.from(row));
  }
}
