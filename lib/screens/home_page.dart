import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? email;
  String? name;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final box = await Hive.openBox('userBox');
    setState(() {
      email = box.get('email') as String?;
      name = box.get('name') as String?;
    });
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    final box = await Hive.openBox('userBox');
    await box.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Attender Home')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: colors.primaryContainer,
                child: Icon(
                  Icons.person_outline,
                  size: 42,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name ?? 'User',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(email ?? 'Email not available'),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
