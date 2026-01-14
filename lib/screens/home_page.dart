import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_store.dart';
import 'home/student_home_page.dart';
import 'home/teacher_home_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _email;
  String? _name;
  String? _role;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final cached = await AuthStore.load();
    setState(() {
      _email = cached.email;
      _name = cached.name;
      _role = cached.role ?? 'student';
      _loading = false;
    });
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    await AuthStore.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isTeacher = (_role ?? 'student') == 'teacher';

    return isTeacher
        ? TeacherHomePage(name: _name, email: _email, onSignOut: _signOut)
        : StudentHomePage(name: _name, email: _email, onSignOut: _signOut);
  }
}
