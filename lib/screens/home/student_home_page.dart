import 'package:avatar_plus/avatar_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/class_service.dart';
import 'home_components.dart';
import 'widgets/student_classes_page.dart';
import 'widgets/class_icon_helper.dart';
import '../qr_scanner_page.dart';

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
  late final ClassService _classService;
  bool _loading = true;
  String? _error;
  List<StudentClassRecord> _classes = const [];
  bool _statsLoading = true;
  String? _statsError;
  StudentDashboardStats? _stats;

  @override
  void initState() {
    super.initState();
    _classService = ClassService(Supabase.instance.client);
    _loadClasses();
    _loadStats();
  }

  Future<void> _loadClasses({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _classService.getStudentClasses(
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

  Future<void> _loadStats({bool forceRefresh = false}) async {
    setState(() {
      _statsLoading = true;
      _statsError = null;
    });
    try {
      final data = await _classService.fetchStudentDashboardStats();
      if (!mounted) return;
      setState(() => _stats = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _statsError = e.toString());
    } finally {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    final tabs = [
      _TabConfig(
        label: 'Home',
        icon: Icons.home_rounded,
        content: StudentOverview(
          onSignOut: widget.onSignOut,
          classService: _classService,
          classes: _classes,
          loading: _loading,
          error: _error,
          stats: _stats,
          statsLoading: _statsLoading,
          statsError: _statsError,
          onOpenScanTab: () => setState(() => _index = 2),
          onRefresh: () async {
            await Future.wait([
              _loadClasses(forceRefresh: true),
              _loadStats(forceRefresh: true),
            ]);
          },
        ),
      ),
      _TabConfig(
        label: 'Classes',
        icon: Icons.class_outlined,
        content: StudentClassesPage(classService: _classService),
      ),
      _TabConfig(
        label: 'Scan',
        icon: Icons.qr_code_scanner,
        content: QrScannerLauncherTab(classService: _classService),
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

    return Scaffold(
      body: tabs[_index].content,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: tabs
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
}

class QrScannerLauncherTab extends StatefulWidget {
  const QrScannerLauncherTab({super.key, required this.classService});

  final ClassService classService;

  @override
  State<QrScannerLauncherTab> createState() => _QrScannerLauncherTabState();
}

class _QrScannerLauncherTabState extends State<QrScannerLauncherTab> {
  String? _lastCode;
  bool _submitting = false;
  final TextEditingController _manualCtrl = TextEditingController();

  Future<void> _openScanner() async {
    final result = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScannerPage()));
    if (result != null && mounted) {
      setState(() => _lastCode = result);
      _submitCode(result);
    }
  }

  Future<void> _submitCode(String code) async {
    if (code.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await widget.classService.submitAttendance(code: code.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Attendance submitted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Scan QR',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scan an attendance QR',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'Use this scanner if your teacher shared a QR. The code will appear below so you can paste it into the class detail page if needed.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _openScanner,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text(
                  'Open Scanner',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            if (_lastCode != null) ...[
              const SizedBox(height: 16),
              Text(
                'Last code',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SelectableText(
                  _lastCode!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StudentOverview extends StatelessWidget {
  final VoidCallback onSignOut;
  final ClassService classService;
  final List<StudentClassRecord> classes;
  final bool loading;
  final String? error;
  final StudentDashboardStats? stats;
  final bool statsLoading;
  final String? statsError;
  final VoidCallback onOpenScanTab;
  final VoidCallback onRefresh;

  const StudentOverview({
    super.key,
    required this.onSignOut,
    required this.classService,
    required this.classes,
    required this.loading,
    required this.error,
    required this.stats,
    required this.statsLoading,
    required this.statsError,
    required this.onOpenScanTab,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('authBox');
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (box.get(
                                  'sessionUser',
                                )['user_metadata']['avatar_url'] !=
                                null)
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.transparent,
                                child: ClipOval(
                                  child: Image.network(
                                    box.get(
                                      'sessionUser',
                                    )['user_metadata']['avatar_url'],
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            AvatarPlus(
                                              box.get('name').toString(),
                                              height: 50,
                                              width: 50,
                                            ),
                                  ),
                                ),
                              )
                            else
                              AvatarPlus(
                                box.get('name').toString(),
                                height: 50,
                                width: 50,
                              ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  box.get('name') ?? 'Student',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  box.get('email') ?? 'Student dashboard',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onSignOut,
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
                      value: loading ? '—' : '${classes.length}',
                      color: primary,
                      icon: Icons.class_outlined,
                    ),
                    StatCard(
                      label: 'Attendance',
                      value: statsLoading
                          ? '—'
                          : stats != null
                          ? '${stats!.attendancePercent.toStringAsFixed(0)}%'
                          : '—',
                      color: Colors.indigo,
                      icon: Icons.trending_up,
                    ),
                    StatCard(
                      label: 'Today',
                      value: statsLoading
                          ? '—'
                          : stats != null
                          ? '${stats!.todayTotalSessions}'
                          : '—',
                      color: Colors.green,
                      icon: Icons.task_alt,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ActionButton(
                        label: 'Refresh classes',
                        color: primary,
                        icon: Icons.refresh,
                        onTap: onRefresh,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ActionButton(
                        label: 'Scan QR',
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.7),
                        icon: Icons.qr_code,
                        onTap: onOpenScanTab,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  "Today's Classes",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                StudentTodayClassesCard(
                  classService: classService,
                  classes: classes,
                  loading: loading,
                  error: error,
                ),
                const SizedBox(height: 18),
                Text(
                  'All Schedules',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                StudentWeeklyScheduleCard(
                  classService: classService,
                  classes: classes,
                  loading: loading,
                  error: error,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
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

class _ScheduleEvent {
  const _ScheduleEvent({
    required this.classRecord,
    required this.dayIndex,
    required this.dayLabel,
    required this.startHm,
    required this.endHm,
  });

  final StudentClassRecord classRecord;
  final int dayIndex; // 0=Mon ... 6=Sun
  final String dayLabel;
  final String startHm;
  final String endHm;

  String get timeLabel => '$startHm–$endHm';
}

int? _dayToIndex(String raw) {
  final v = raw.trim().toLowerCase();
  switch (v) {
    case 'monday':
    case 'mon':
      return 0;
    case 'tuesday':
    case 'tue':
    case 'tues':
      return 1;
    case 'wednesday':
    case 'wed':
      return 2;
    case 'thursday':
    case 'thu':
    case 'thur':
    case 'thurs':
      return 3;
    case 'friday':
    case 'fri':
      return 4;
    case 'saturday':
    case 'sat':
      return 5;
    case 'sunday':
    case 'sun':
      return 6;
    default:
      return null;
  }
}

String _indexToDayLabel(int i) {
  switch (i) {
    case 0:
      return 'Mon';
    case 1:
      return 'Tue';
    case 2:
      return 'Wed';
    case 3:
      return 'Thu';
    case 4:
      return 'Fri';
    case 5:
      return 'Sat';
    case 6:
      return 'Sun';
    default:
      return '';
  }
}

int _timeSortKey(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return 0;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  return h * 60 + m;
}

int _todayDayIndex() {
  final idx = DateTime.now().weekday - 1; // 0=Mon .. 6=Sun
  if (idx < 0) return 0;
  if (idx > 6) return 6;
  return idx;
}

class StudentWeeklyScheduleCard extends StatefulWidget {
  const StudentWeeklyScheduleCard({
    super.key,
    required this.classService,
    required this.classes,
    required this.loading,
    required this.error,
  });

  final ClassService classService;
  final List<StudentClassRecord> classes;
  final bool loading;
  final String? error;

  @override
  State<StudentWeeklyScheduleCard> createState() =>
      _StudentWeeklyScheduleCardState();
}

class _StudentWeeklyScheduleCardState extends State<StudentWeeklyScheduleCard> {
  Future<List<_ScheduleEvent>>? _future;
  List<int> _lastClassIds = const [];

  @override
  void initState() {
    super.initState();
    _kickoffIfNeeded();
  }

  @override
  void didUpdateWidget(covariant StudentWeeklyScheduleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _kickoffIfNeeded();
  }

  void _kickoffIfNeeded() {
    final ids = widget.classes.map((c) => c.id).toList()..sort();
    final changed =
        ids.length != _lastClassIds.length ||
        List.generate(
              ids.length,
              (i) => ids[i] == _lastClassIds[i],
            ).every((e) => e) ==
            false;
    if (!changed && _future != null) return;

    _lastClassIds = ids;
    _future = _loadSchedule();
  }

  Future<List<_ScheduleEvent>> _loadSchedule() async {
    final classes = widget.classes;
    if (classes.isEmpty) return const [];

    final results = await Future.wait(
      classes.map((c) async {
        try {
          final schedules = await widget.classService.fetchClassSchedules(c.id);
          return schedules.map((s) => (c, s)).toList();
        } catch (_) {
          return const <(StudentClassRecord, ScheduleRecord)>[];
        }
      }),
    );

    final out = <_ScheduleEvent>[];
    for (final perClass in results) {
      for (final pair in perClass) {
        final c = pair.$1;
        final s = pair.$2;
        final idx = _dayToIndex(s.day);
        if (idx == null) continue;
        out.add(
          _ScheduleEvent(
            classRecord: c,
            dayIndex: idx,
            dayLabel: _indexToDayLabel(idx),
            startHm: s.startHm,
            endHm: s.endHm,
          ),
        );
      }
    }

    out.sort((a, b) {
      final d = a.dayIndex.compareTo(b.dayIndex);
      if (d != 0) return d;
      return _timeSortKey(a.startHm).compareTo(_timeSortKey(b.startHm));
    });

    return out;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (widget.loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Could not load schedule. Pull to refresh.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.classes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          'Add classes to see your weekly schedule.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      );
    }

    return FutureBuilder<List<_ScheduleEvent>>(
      future: _future,
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <_ScheduleEvent>[];

        final byDay = <int, List<_ScheduleEvent>>{
          for (var i = 0; i < 7; i++) i: <_ScheduleEvent>[],
        };
        for (final e in events) {
          byDay[e.dayIndex]?.add(e);
        }
        for (final dayEvents in byDay.values) {
          dayEvents.sort(
            (a, b) =>
                _timeSortKey(a.startHm).compareTo(_timeSortKey(b.startHm)),
          );
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month, color: primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'All classes this week',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${events.length} session(s)',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(7, (dayIndex) {
                    final dayLabel = _indexToDayLabel(dayIndex);
                    final dayEvents =
                        byDay[dayIndex] ?? const <_ScheduleEvent>[];

                    return Container(
                      width: 150,
                      margin: EdgeInsets.only(right: dayIndex == 6 ? 0 : 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dayLabel,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              (snapshot.data == null))
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          else if (dayEvents.isEmpty)
                            Text(
                              '—',
                              style: TextStyle(color: Colors.grey.shade600),
                            )
                          else
                            ...dayEvents.map(
                              (e) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: primary.withOpacity(0.12),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.timeLabel,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      e.classRecord.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              if (snapshot.hasError) ...[
                const SizedBox(height: 10),
                Text(
                  'Some schedules may be missing. Pull to refresh.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class StudentTodayClassesCard extends StatefulWidget {
  const StudentTodayClassesCard({
    super.key,
    required this.classService,
    required this.classes,
    required this.loading,
    required this.error,
  });

  final ClassService classService;
  final List<StudentClassRecord> classes;
  final bool loading;
  final String? error;

  @override
  State<StudentTodayClassesCard> createState() =>
      _StudentTodayClassesCardState();
}

class _StudentTodayClassesCardState extends State<StudentTodayClassesCard> {
  Future<List<_ScheduleEvent>>? _future;
  List<int> _lastClassIds = const [];

  @override
  void initState() {
    super.initState();
    _kickoffIfNeeded();
  }

  @override
  void didUpdateWidget(covariant StudentTodayClassesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _kickoffIfNeeded();
  }

  void _kickoffIfNeeded() {
    final ids = widget.classes.map((c) => c.id).toList()..sort();
    final changed =
        ids.length != _lastClassIds.length ||
        List.generate(
              ids.length,
              (i) => ids[i] == _lastClassIds[i],
            ).every((e) => e) ==
            false;
    if (!changed && _future != null) return;

    _lastClassIds = ids;
    _future = _loadToday();
  }

  Future<List<_ScheduleEvent>> _loadToday() async {
    final todayIndex = _todayDayIndex();
    final classes = widget.classes;
    if (classes.isEmpty) return const [];

    final results = await Future.wait(
      classes.map((c) async {
        try {
          final schedules = await widget.classService.fetchClassSchedules(c.id);
          return schedules.map((s) => (c, s)).toList();
        } catch (_) {
          return const <(StudentClassRecord, ScheduleRecord)>[];
        }
      }),
    );

    final out = <_ScheduleEvent>[];
    for (final perClass in results) {
      for (final pair in perClass) {
        final c = pair.$1;
        final s = pair.$2;
        final idx = _dayToIndex(s.day);
        if (idx == null) continue;
        if (idx != todayIndex) continue;
        out.add(
          _ScheduleEvent(
            classRecord: c,
            dayIndex: idx,
            dayLabel: _indexToDayLabel(idx),
            startHm: s.startHm,
            endHm: s.endHm,
          ),
        );
      }
    }

    out.sort(
      (a, b) => _timeSortKey(a.startHm).compareTo(_timeSortKey(b.startHm)),
    );
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final todayLabel = _indexToDayLabel(_todayDayIndex());

    if (widget.loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Could not load today\'s classes. Pull to refresh.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.classes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          'No classes yet. Pull to refresh or ask your teacher to add you.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      );
    }

    return FutureBuilder<List<_ScheduleEvent>>(
      future: _future,
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <_ScheduleEvent>[];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.today, color: primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Scheduled for $todayLabel',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      snapshot.data == null)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      '${events.length} class(es)',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  snapshot.data == null)
                const SizedBox.shrink()
              else if (events.isEmpty)
                Text(
                  'No classes scheduled for today.',
                  style: TextStyle(color: Colors.grey.shade700),
                )
              else
                ...events.map(
                  (e) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            classIconFor(e.classRecord.icon),
                            color: primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.classRecord.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                e.timeLabel,
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Teacher: ${e.classRecord.teacherName}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (snapshot.hasError) ...[
                const SizedBox(height: 8),
                Text(
                  'Some schedules may be missing. Pull to refresh.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
