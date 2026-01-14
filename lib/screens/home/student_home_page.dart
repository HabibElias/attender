import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'home_components.dart';

class StudentHomePage extends StatefulWidget {
  final String? name;
  final String? email;
  final VoidCallback onSignOut;

  const StudentHomePage({
    super.key,
    required this.name,
    required this.email,
    required this.onSignOut,
  });

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  int _index = 0;

  List<_TabConfig> get _tabs => [
    _TabConfig(
      label: 'Home',
      icon: Icons.home_outlined,
      content: _buildOverview(),
    ),
    _TabConfig(
      label: 'Classes',
      icon: Icons.class_outlined,
      content: const PlaceholderTab(label: 'Classes'),
    ),
    _TabConfig(
      label: 'Attendance',
      icon: Icons.bar_chart_outlined,
      content: const PlaceholderTab(label: 'Attendance'),
    ),
    _TabConfig(
      label: 'Profile',
      icon: Icons.person_outline,
      content: ProfileCard(
        name: widget.name,
        email: widget.email,
        role: 'student',
        onSignOut: widget.onSignOut,
      ),
    ),
  ];

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
    );
  }

  Widget _buildOverview() {
    final box = Hive.box('authBox');
    final primary = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    box.get('name') ?? 'Student',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Student dashboard',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout_outlined),
                tooltip: 'Sign out',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatCard(
                label: 'My Classes',
                value: '5',
                color: primary,
                icon: Icons.class_outlined,
              ),
              const StatCard(
                label: 'Present Today',
                value: '3/5',
                color: Colors.green,
                icon: Icons.task_alt,
              ),
              const StatCard(
                label: 'Absent Today',
                value: '2',
                color: Colors.red,
                icon: Icons.close,
              ),
              const StatCard(
                label: 'Attendance',
                value: '86%',
                color: Colors.indigo,
                icon: Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Quick Actions',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ActionButton(
                  label: 'View Schedule',
                  color: primary,
                  icon: Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: ActionButton(
                  label: 'Request Leave',
                  color: Colors.green,
                  icon: Icons.outbox_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Recent Classes',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const ClassTile(
            course: 'Mobile Computing',
            section: 'CS-401 · 9:00 AM',
            status: 'Present',
            accent: Color(0xFFE9D5FF),
            icon: Icons.devices,
          ),
          const ClassTile(
            course: 'Database Systems',
            section: 'CS-301 · 11:00 AM',
            status: 'Present',
            accent: Color(0xFFDDEBFF),
            icon: Icons.table_chart_outlined,
          ),
          const ClassTile(
            course: 'Machine Learning',
            section: 'CS-501 · 2:00 PM',
            status: 'Absent',
            accent: Color(0xFFFFE4D5),
            icon: Icons.memory,
          ),
          const SizedBox(height: 14),
          const AlertCard(
            title: 'Attendance Reminder',
            message:
                'You have 2 absences this month. Keep attendance above 75%.',
            color: Color(0xFFFFF7E8),
            iconColor: Colors.orange,
          ),
        ],
      ),
    );
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
