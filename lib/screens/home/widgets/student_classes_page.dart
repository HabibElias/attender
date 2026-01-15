import 'package:flutter/material.dart';

import '../../../services/class_service.dart';
import '../../student_class_detail_page.dart';
import 'class_icon_helper.dart';

class StudentClassesPage extends StatefulWidget {
  const StudentClassesPage({super.key, required this.classService});

  final ClassService classService;

  @override
  State<StudentClassesPage> createState() => _StudentClassesPageState();
}

class _StudentClassesPageState extends State<StudentClassesPage> {
  bool _loading = true;
  String? _error;
  List<StudentClassRecord> _classes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.classService.getStudentClasses(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() => _classes = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32, color: Colors.red),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _load(forceRefresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_classes.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(forceRefresh: true),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.class_outlined,
                  size: 48,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(height: 12),
                Text(
                  'No classes yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ask your teacher to add you to a class.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Classes',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap a class to view details and attend.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._classes.map(
            (c) => _StudentClassCard(
              classService: widget.classService,
              classRecord: c,
              onRefresh: () => _load(forceRefresh: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentClassCard extends StatefulWidget {
  const _StudentClassCard({
    required this.classService,
    required this.classRecord,
    required this.onRefresh,
  });

  final ClassService classService;
  final StudentClassRecord classRecord;
  final VoidCallback onRefresh;

  @override
  State<_StudentClassCard> createState() => _StudentClassCardState();
}

class _StudentClassCardState extends State<_StudentClassCard> {
  bool _loadingSched = true;
  String? _errorSched;
  List<ScheduleRecord> _schedules = const [];
  bool _loadingCount = true;
  int? _studentCount;

  static const _dayOrder = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loadingSched = true;
      _loadingCount = true;
      _errorSched = null;
    });
    try {
      final scheds = await widget.classService.fetchClassSchedules(
        widget.classRecord.id,
      );
      if (!mounted) return;
      setState(() {
        _schedules = scheds;
        _loadingSched = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorSched = e.toString();
        _loadingSched = false;
      });
    }

    try {
      final students = await widget.classService.fetchClassStudents(
        widget.classRecord.id,
      );
      if (!mounted) return;
      setState(() {
        _studentCount = students.length;
        _loadingCount = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCount = false);
    }
  }

  String _daysSummary() {
    if (_schedules.isEmpty) return 'No schedules';
    final daysSet = {for (final d in _schedules.map((s) => s.day)) d};
    if (daysSet.length == 7) return 'Daily';
    final ordered = _dayOrder.where(daysSet.contains).toList();
    final abbr = ordered.map((d) => d.substring(0, 3)).join(', ');
    return abbr;
  }

  String _studentCountLabel() {
    if (_loadingCount) return 'Students';
    final count = _studentCount;
    if (count == null) return 'Students';
    if (count == 0) return 'No students';
    if (count == 1) return '1 student';
    return '$count students';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                StudentClassDetailPage(classRecord: widget.classRecord),
          ),
        );
        if (mounted) {
          _loadMeta();
          widget.onRefresh();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.classRecord.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: accent.withOpacity(0.12),
                            child: Icon(
                              classIconFor(widget.classRecord.icon),
                              color: accent,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.group_outlined,
                            size: 16,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _studentCountLabel(),
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const Spacer(),
                          const Icon(Icons.circle, size: 6, color: Colors.grey),
                          const SizedBox(width: 6),
                          if (_loadingSched)
                            const Text(
                              'Loading...',
                              style: TextStyle(color: Colors.black54),
                            )
                          else if (_errorSched != null)
                            const Text(
                              '—',
                              style: TextStyle(color: Colors.black54),
                            )
                          else
                            Row(
                              children: [
                                const Icon(
                                  Icons.event_available_outlined,
                                  size: 16,
                                  color: Colors.black54,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _daysSummary(),
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Teacher: ${widget.classRecord.teacherName}${widget.classRecord.teacherEmail != null ? ' • ${widget.classRecord.teacherEmail}' : ''}',
                        style: TextStyle(color: Colors.grey.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
