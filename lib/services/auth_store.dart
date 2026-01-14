import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthCachedUser {
  final String? id;
  final String? email;
  final String? name;
  final String? role;
  final bool profileComplete;
  final Map<String, dynamic>? rawUser;

  const AuthCachedUser({
    this.id,
    this.email,
    this.name,
    this.role,
    this.rawUser,
    this.profileComplete = false,
  });
}

class AuthStore {
  static const _boxName = 'authBox';

  static Future<Box> _box() => Hive.openBox(_boxName);

  static Future<User?> get currentUser async {
    final box = await _box();
    final raw = box.get('sessionUser') as Map?;
    if (raw == null) return null;
    return User.fromJson(raw.cast<String, dynamic>());
  }

  static Future<void> saveSessionUser(Session session) async {
    final box = await _box();
    final user = session.user;
    final name = _resolveName(user);

    box
      ..put('sessionUser', user.toJson())
      ..put('id', user.id)
      ..put('email', user.email)
      ..put('name', name)
      ..put('profileComplete', box.get('profileComplete') ?? false);
  }

  static Future<void> setRole(String role) async {
    final box = await _box();
    box.put('role', role);
  }

  static Future<void> clearRole() async {
    final box = await _box();
    box.delete('role');
  }

  static Future<void> setProfileComplete(bool complete) async {
    final box = await _box();
    box.put('profileComplete', complete);
  }

  static Future<AuthCachedUser> load() async {
    final box = await _box();
    final raw = box.get('sessionUser') as Map?;
    final role = box.get('role') as String?;
    final profileComplete = box.get('profileComplete') as bool? ?? false;

    String? name = box.get('name') as String?;
    String? email = box.get('email') as String?;
    String? id = box.get('id') as String?;

    if (raw is Map<String, dynamic>) {
      name ??= _nameFromRaw(raw);
      email ??= raw['email'] as String?;
      id ??= raw['id'] as String?;
    }

    return AuthCachedUser(
      id: id,
      email: email,
      name: name,
      role: role,
      rawUser: raw?.cast<String, dynamic>(),
      profileComplete: profileComplete,
    );
  }

  static Future<void> clear() async {
    final box = await _box();
    await box.clear();
  }

  static String? _resolveName(User user) {
    final meta = user.userMetadata ?? <String, dynamic>{};
    final fullName = meta['full_name'] as String?;
    if (fullName != null && fullName.trim().isNotEmpty) return fullName.trim();
    final first = meta['first_name'] as String?;
    final last = meta['last_name'] as String?;
    final combined = [first, last].whereType<String>().join(' ').trim();
    return combined.isEmpty ? null : combined;
  }

  static String? _nameFromRaw(Map<String, dynamic> raw) {
    final meta = raw['user_metadata'];
    if (meta is Map<String, dynamic>) {
      final fullName = meta['full_name'] as String?;
      if (fullName != null && fullName.trim().isNotEmpty)
        return fullName.trim();
      final first = meta['first_name'] as String?;
      final last = meta['last_name'] as String?;
      final combined = [first, last].whereType<String>().join(' ').trim();
      if (combined.isNotEmpty) return combined;
    }
    return raw['name'] as String?;
  }
}
