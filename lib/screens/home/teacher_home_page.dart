import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_components.dart';
import '../../services/class_service.dart';
import 'widgets/create_class_sheet.dart';
import 'widgets/teacher_classes_page.dart';
import 'widgets/teacher_overview.dart';
import 'widgets/manage_sessions_page.dart';

class TeacherHomePage extends StatefulWidget {
  final String? name;
  final String? email;
  final VoidCallback onSignOut;

  const TeacherHomePage({
    super.key,
    required this.name,
    required this.email,
    required this.onSignOut,
  });

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  int _index = 0;
  late final ClassService _classService;
  final GlobalKey _classesKey = GlobalKey();

  List<_TabConfig> get _tabs => [
    _TabConfig(
      label: 'Home',
      icon: Icons.home_outlined,
      content: TeacherOverview(onSignOut: widget.onSignOut),
    ),
    _TabConfig(
      label: 'Classes',
      icon: Icons.menu_book_outlined,
      content: TeacherClassesPage(
        key: _classesKey,
        classService: _classService,
      ),
    ),
    _TabConfig(
      label: 'Manage',
      icon: Icons.dashboard_customize_outlined,
      content: ManageSessionsPage(classService: _classService),
    ),
    _TabConfig(
      label: 'Profile',
      icon: Icons.person_outline,
      content: ProfileCard(
        name: widget.name,
        email: widget.email,
        role: 'teacher',
        onSignOut: widget.onSignOut,
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _classService = ClassService(Supabase.instance.client);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: _tabs[_index].content,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: _tabs
            .map(
              (t) =>
                  BottomNavigationBarItem(icon: Icon(t.icon), label: t.label),
            )
            .toList(),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey.shade600,
      ),
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: AppBar(automaticallyImplyLeading: false),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateClassSheet,
        icon: const Icon(Icons.add),
        label: const Text(
          'New Class',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primary,
      ),
    );
  }

  Future<void> _openCreateClassSheet() async {
    final created = await showCreateClassSheet(
      context: context,
      classService: _classService,
    );

    if (created && mounted) {
      context.showSnack('Class created');
      (_classesKey.currentState as dynamic)?.refresh();
    }
  }
}

class _TabConfig {
  final String label;
  final IconData icon;
  final Widget content;

  const _TabConfig({
    required this.label,
    required this.icon,
    required this.content,
  });
}

extension on BuildContext {
  void showSnack(String msg) {
    ScaffoldMessenger.of(this).showSnackBar(SnackBar(content: Text(msg)));
  }
}
