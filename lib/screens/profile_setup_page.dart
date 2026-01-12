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

  Widget _buildRoleTile({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    final colors = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? colors.primary : Colors.grey.shade200,
          width: isSelected ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        onTap: _saving ? null : () => setState(() => _selectedRole = role),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: colors.primary.withOpacity(0.08),
          child: Icon(icon, color: colors.primary),
        ),
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
          ),
        ),
        trailing: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? colors.primary : Colors.grey.shade300,
              width: 2,
            ),
            color: isSelected ? colors.primary : Colors.transparent,
          ),
          child: isSelected
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F9FF), Color(0xFFFFF1F5)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'lib/images/attender_icon.png',
                    width: 88,
                    height: 88,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Set up your profile',
                    style: textTheme.headlineMedium?.copyWith(
                      color: colors.onBackground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose how you will use Attender',
                    style: textTheme.titleSmall?.copyWith(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (widget.email != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.email!,
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Select your role',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildRoleTile(
                          role: 'student',
                          title: 'Student',
                          subtitle:
                              'Access classes, mark attendance, stay on track',
                          icon: Icons.school_outlined,
                        ),
                        _buildRoleTile(
                          role: 'teacher',
                          title: 'Teacher',
                          subtitle:
                              'Create classes, manage sessions, review attendance',
                          icon: Icons.auto_stories_outlined,
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0E58BC),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            icon: const Icon(Icons.check_circle_outline),
                            label: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.1,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text('Save and continue'),
                          ),
                        ),
                        if (_saving) ...[
                          const SizedBox(height: 12),
                          const LinearProgressIndicator(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'You can not change this later in settings',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
