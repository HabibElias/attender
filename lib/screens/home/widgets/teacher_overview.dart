import 'package:avatar_plus/avatar_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../home_components.dart';

class TeacherOverview extends StatelessWidget {
  const TeacherOverview({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final box = Hive.box('authBox');

    final primary = colors.primary;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              if (box.get('sessionUser')['user_metadata']['avatar_url'] != null)
                CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(
                    box.get('sessionUser')['user_metadata']['avatar_url'],
                  ),
                )
              else
                AvatarPlus(box.get('name').toString(), height: 50, width: 50),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    box.get('name'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    box.get('sessionUser')['userMetadata'] ??
                        box.get('email') ??
                        "Teacher dashboard",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(onPressed: onSignOut, icon: const Icon(Icons.logout)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StatCard(
                label: 'Total Students',
                value: '156',
                color: primary,
                icon: Icons.people_alt_outlined,
              ),
              const SizedBox(width: 12),
              const StatCard(
                label: 'Present Today',
                value: '142',
                color: Colors.green,
                icon: Icons.task_alt,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const StatCard(
                label: 'Absent Today',
                value: '14',
                color: Colors.red,
                icon: Icons.close,
              ),
              const SizedBox(width: 12),
              const StatCard(
                label: 'Attendance',
                value: '91%',
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
                  label: 'Scan QR',
                  color: primary,
                  icon: Icons.qr_code_scanner,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: ActionButton(
                  label: 'Mark All',
                  color: Colors.green,
                  icon: Icons.done_all,
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
            status: '28/30 Present',
            accent: Color(0xFFE9D5FF),
            icon: Icons.devices,
          ),
          const ClassTile(
            course: 'Database Systems',
            section: 'CS-301 · 11:00 AM',
            status: '25/28 Present',
            accent: Color(0xFFDDEBFF),
            icon: Icons.table_chart_outlined,
          ),
          const ClassTile(
            course: 'Machine Learning',
            section: 'CS-501 · 2:00 PM',
            status: '22/26 Present',
            accent: Color(0xFFFFE4D5),
            icon: Icons.memory,
          ),
          const SizedBox(height: 14),
          const AlertCard(
            title: 'Low Attendance Alert',
            message: '3 students have attendance below 75%. Review required.',
            color: Color(0xFFFFF1F1),
            iconColor: Colors.red,
          ),
        ],
      ),
    );
  }
}
