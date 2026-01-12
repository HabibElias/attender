import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/profile_service.dart';
import 'home_page.dart';

class ProfileSetupPage extends StatefulWidget {
  final String userId;
  final String? email;
  final String? name;

  const ProfileSetupPage({
    super.key,
    required this.userId,
    this.email,
    this.name,
  });

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final List<String> _roles = ['student', 'teacher'];
  String? _selectedRole;
  bool _saving = false;

  Future<void> _saveProfile() async {
    if (_selectedRole == null) {
      _showSnack('Pick a role to continue');
      return;
    }
    setState(() => _saving = true);
    try {
      final profile = await ProfileService.upsertProfile(
        userId: widget.userId,
        role: _selectedRole!,
      );

      final box = await Hive.openBox('userBox');
      box.put('role', profile.role);
      box.put('profileComplete', true);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      _showSnack('Could not save profile: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your profile')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose your role',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                if (widget.email != null)
                  Text(widget.email!, style: TextStyle(color: colors.outline)),
                const SizedBox(height: 16),
                ..._roles.map(
                  (role) => Card(
                    elevation: 0,
                    child: RadioListTile<String>(
                      value: role,
                      groupValue: _selectedRole,
                      onChanged: _saving
                          ? null
                          : (val) => setState(() => _selectedRole = val),
                      title: Text(role[0].toUpperCase() + role.substring(1)),
                      subtitle: Text(
                        role == 'student'
                            ? 'Access classes and view attendance'
                            : 'Create and manage classes',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveProfile,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Save and continue'),
                ),
                const SizedBox(height: 12),
                if (_saving) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
