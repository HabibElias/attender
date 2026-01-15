import 'package:avatar_plus/avatar_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../home_components.dart';
import '../../../services/class_service.dart';
import 'class_icon_helper.dart';

class TeacherOverview extends StatefulWidget {
  const TeacherOverview({
    super.key,
    required this.onSignOut,
    required this.classService,
    required this.stats,
    required this.statsLoading,
    required this.statsError,
    required this.onRefresh,
  });

  final VoidCallback onSignOut;
  final ClassService classService;
  final TeacherDashboardStats? stats;
  final bool statsLoading;
  final String? statsError;
  final Future<void> Function() onRefresh;

  @override
  State<TeacherOverview> createState() => _TeacherOverviewState();
}

class _TeacherOverviewState extends State<TeacherOverview> {
  bool _recentLoading = true;
  String? _recentError;
  List<TeacherRecentSessionSummary> _recent = const [];

  @override
  void initState() {
    super.initState();
    _loadRecentSessions();
  }

  Future<void> _loadRecentSessions() async {
    setState(() {
      _recentLoading = true;
      _recentError = null;
    });

    try {
      final data = await widget.classService.fetchTeacherRecentSessions(
        limit: 3,
      );
      if (!mounted) return;
      setState(() => _recent = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _recentError = e.toString());
    } finally {
      if (mounted) setState(() => _recentLoading = false);
    }
  }

  static String _prettyTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $suffix';
  }

  static String _prettyDateShort(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Recent session';
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final box = Hive.box('authBox');

    final primary = colors.primary;
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([widget.onRefresh(), _loadRecentSessions()]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                if (box.get('sessionUser')['user_metadata']['avatar_url'] !=
                    null)
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
                IconButton(
                  onPressed: widget.onSignOut,
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.statsError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade400),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Could not load today\'s stats. Pull to refresh.',
                        style: TextStyle(color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StatCard(
                  label: 'Total Students',
                  value: widget.statsLoading
                      ? '—'
                      : widget.stats != null
                      ? '${widget.stats!.totalStudents}'
                      : '—',
                  color: primary,
                  icon: Icons.people_alt_outlined,
                ),
                const SizedBox(width: 12),
                StatCard(
                  label: 'Present Today',
                  value: widget.statsLoading
                      ? '—'
                      : widget.stats != null
                      ? '${widget.stats!.presentToday}'
                      : '—',
                  color: Colors.green,
                  icon: Icons.task_alt,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StatCard(
                  label: 'Absent Today',
                  value: widget.statsLoading
                      ? '—'
                      : widget.stats != null
                      ? '${widget.stats!.absentToday}'
                      : '—',
                  color: Colors.red,
                  icon: Icons.close,
                ),
                const SizedBox(width: 12),
                StatCard(
                  label: 'Attendance',
                  value: widget.statsLoading
                      ? '—'
                      : widget.stats != null
                      ? '${widget.stats!.attendancePercent.toStringAsFixed(0)}%'
                      : '—',
                  color: Colors.indigo,
                  icon: Icons.trending_up,
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
            if (_recentLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_recentError != null)
              Text(
                'Could not load recent sessions. Pull to refresh.',
                style: TextStyle(color: Colors.grey.shade700),
              )
            else if (_recent.isEmpty)
              Text(
                'No sessions yet.',
                style: TextStyle(color: Colors.grey.shade700),
              )
            else
              ..._recent.map((s) {
                const accents = [
                  Color(0xFFE9D5FF),
                  Color(0xFFDDEBFF),
                  Color(0xFFFFE4D5),
                  Color(0xFFD1FAE5),
                  Color(0xFFFDE68A),
                ];
                final accent = accents[s.classId % accents.length];
                final dateLabel = _prettyDateShort(s.sessionDate);
                final timeLabel = _prettyTime(s.startTime);
                final section = '$dateLabel · $timeLabel';
                final status = '${s.presentCount}/${s.totalStudents} Present';

                return ClassTile(
                  course: s.className,
                  section: section,
                  status: status,
                  accent: accent,
                  icon: classIconFor(s.classIcon),
                );
              }),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}
