import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRecord {
  final String id;
  final String role;

  const ProfileRecord({required this.id, required this.role});

  factory ProfileRecord.fromJson(Map<String, dynamic> json) {
    return ProfileRecord(
      id: json['id'] as String,
      role: json['role'] as String,
    );
  }
}

class ProfileService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<ProfileRecord?> fetchProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return ProfileRecord.fromJson(data);
  }

  static Future<ProfileRecord> upsertProfile({
    required String userId,
    required String role,
  }) async {
    // Uses backend function insert_profile to enforce security rules server-side.
    try {
      await _client.rpc(
        'insert_profile',
        params: {'p_user_id': userId, 'p_role': role},
      );
    } on PostgrestException catch (e) {
      // If already exists, fall through to return existing row.
      if (e.code != '23505') rethrow;
    }

    final created = await fetchProfile(userId);
    if (created == null) {
      throw Exception('Profile insertion failed');
    }
    return created;
  }
}
