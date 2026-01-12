import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Session? get currentSession => _client.auth.currentSession;

  static Stream<AuthState> authStateChanges() => _client.auth.onAuthStateChange;

  static Future<AuthResponse> signInWithEmail(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  static Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.flutter://callback',
    );
  }

  static Future<AuthResponse> signUp(
    String email,
    String password, {
    String? firstName,
    String? lastName,
  }) async {
    final data = <String, dynamic>{};
    if (firstName != null && firstName.isNotEmpty) {
      data['first_name'] = firstName;
    }
    if (lastName != null && lastName.isNotEmpty) {
      data['last_name'] = lastName;
    }
    final full = [
      firstName,
      lastName,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    if (full.isNotEmpty) {
      data['full_name'] = full;
    }
    return _client.auth.signUp(email: email, password: password, data: data);
  }
}
