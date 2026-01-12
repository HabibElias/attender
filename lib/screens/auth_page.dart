import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_service.dart';
import 'home_page.dart';
import 'profile_setup_page.dart';
import 'sign_up_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _navigated = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) async {
        final session = data.session;
        if (session == null || _navigated) return;
        setState(() => _loading = false);
        await _handleSession(session);
      },
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _persistUser(Session session) async {
    final box = await Hive.openBox('userBox');
    box.put('id', session.user.id);
    box.put('email', session.user.email);
    box.put('name', session.user.userMetadata?['full_name']);
  }

  Future<void> _signInWithEmail() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final session = res.session;
      if (session != null) {
        await _handleSession(session);
      } else {
        _showSnack('Sign-in failed');
      }
    } on AuthException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Unexpected error');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      // For mobile, set the deep link redirect to match Android intent-filter and Supabase dashboard.
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter://callback',
      );
      // OAuth flow may complete via deep link; listen for auth state changes too.
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        await _handleSession(session);
      } else {
        _showSnack('Complete Google sign-in in browser...');
      }
    } on AuthException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Unexpected error');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> _handleSession(Session session) async {
    if (_navigated) return;
    _navigated = true;
    await _persistUser(session);
    final profile = await ProfileService.fetchProfile(session.user.id);
    final box = await Hive.openBox('userBox');
    if (profile != null) {
      box.put('role', profile.role);
      box.put('profileComplete', true);
      _goHome();
    } else {
      box.put('profileComplete', false);
      box.delete('role');
      _goProfileSetup(
        session.user.id,
        session.user.email,
        session.user.userMetadata?['full_name'],
      );
    }
  }

  void _goProfileSetup(String userId, String? email, String? name) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            ProfileSetupPage(userId: userId, email: email, name: name),
      ),
      (route) => false,
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to Attender')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sign in',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _loading ? null : _signInWithEmail,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Email'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _signInWithGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text('Sign in with Google'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary, width: 1.2),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SignUpPage(),
                                ),
                              );
                            },
                      child: const Text('Sign up'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_loading) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
