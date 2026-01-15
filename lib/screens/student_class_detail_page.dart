import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/class_service.dart';
import 'home/widgets/class_icon_helper.dart';
import 'home/widgets/student_session_detail_page.dart';
import 'qr_scanner_page.dart';

class StudentClassDetailPage extends StatefulWidget {
  const StudentClassDetailPage({super.key, required this.classRecord});

  final StudentClassRecord classRecord;

  @override
  State<StudentClassDetailPage> createState() => _StudentClassDetailPageState();
}

class _StudentClassDetailPageState extends State<StudentClassDetailPage> {
  static const _accentColor = Color(0xFF0E58BC);

  late final ClassService _service;
  ClassSession? _active;
  bool _loading = true;
  String? _error;
  List<ScheduleRecord> _schedules = const [];
  String? _scheduleError;
  int? _studentCount;
  List<ClassSession> _pastSessions = const [];
  Set<int> _attendedSessionIds = const {};
  String? _sessionsError;
  bool _attendedActiveSession = false;
  final TextEditingController _codeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = ClassService(Supabase.instance.client);
    _load();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _scheduleError = null;
      _sessionsError = null;
      _attendedActiveSession = false;
    });
    ClassSession? session;
    List<ScheduleRecord> schedules = const [];
    String? scheduleError;
    int? studentCount;
    List<ClassSession> pastSessions = const [];
    Set<int> attendedSessionIds = const {};
    String? sessionsError;
    bool attendedActiveSession = false;

    try {
      session = await _service.fetchActiveSession(
        widget.classRecord.id,
        isStudent: true,
      );

      final active = session;
      if (active?.isActive == true) {
        final attended = await _service.fetchAttendedSessionIds([active!.id]);
        attendedActiveSession = attended.contains(active.id);
      }
    } catch (e) {
      _error = e.toString();
    }

    try {
      schedules = await _service.fetchClassSchedules(widget.classRecord.id);
    } catch (e) {
      scheduleError = e.toString();
    }

    try {
      final students = await _service.fetchClassStudents(widget.classRecord.id);
      studentCount = students.length;
    } catch (_) {
      // silently ignore; count is optional
    }

    try {
      final allSessions = await _service.fetchSessionsForClass(
        widget.classRecord.id,
        isStudent: true,
      );
      pastSessions = allSessions.where((s) => !s.isActive).take(12).toList();
      attendedSessionIds = await _service.fetchAttendedSessionIds(
        pastSessions.map((s) => s.id),
      );
    } catch (e) {
      sessionsError = e.toString();
    }

    if (!mounted) return;
    setState(() {
      _active = session;
      _schedules = schedules;
      _scheduleError = scheduleError;
      _studentCount = studentCount;
      _pastSessions = pastSessions;
      _attendedSessionIds = attendedSessionIds;
      _sessionsError = sessionsError;
      _attendedActiveSession = attendedActiveSession;
      _loading = false;
    });
  }

  Future<void> _submitCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    setState(() => _loading = true);
    try {
      await _service.submitAttendance(code: trimmed);
      if (!mounted) return;

      if (_active != null && _active!.isActive) {
        setState(() => _attendedActiveSession = true);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Attendance submitted')));
      _codeCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scan() async {
    final result = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScannerPage()));
    if (result != null) {
      _submitCode(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.classRecord;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: const Color(0xFFF5F7FB),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryCard(
                        classRecord: c,
                        schedules: _schedules,
                        scheduleError: _scheduleError,
                        studentCount: _studentCount,
                      ),
                      const SizedBox(height: 18),

                      if (_active != null && _active!.isActive)
                        _ActiveSessionCard(
                          session: _active!,
                          error: _error,
                          codeCtrl: _codeCtrl,
                          loading: _loading,
                          alreadyAttended: _attendedActiveSession,
                          onSubmit: _submitCode,
                          onScan: _scan,
                        )
                      else
                        _NoSessionCard(onRefresh: _load),

                      const SizedBox(height: 18),
                      Text(
                        'Class Sessions',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      _SessionsSection(
                        sessions: _pastSessions,
                        attendedSessionIds: _attendedSessionIds,
                        error: _sessionsError,
                        onRefresh: _load,
                        classService: _service,
                      ),

                      const SizedBox(height: 18),
                      Text(
                        'Schedules',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      _SchedulesSection(
                        schedules: _schedules,
                        scheduleError: _scheduleError,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.classRecord,
    required this.schedules,
    required this.scheduleError,
    required this.studentCount,
  });

  final StudentClassRecord classRecord;
  final List<ScheduleRecord> schedules;
  final String? scheduleError;
  final int? studentCount;

  @override
  Widget build(BuildContext context) {
    final scheduleLine = scheduleError != null
        ? 'Schedules unavailable'
        : schedules.isEmpty
        ? 'No schedules yet'
        : '${schedules.length} schedule(s) this week';
    final studentsLine = studentCount == null
        ? 'Students'
        : studentCount == 0
        ? 'No students yet'
        : '${studentCount!} student(s)';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: _StudentClassDetailPageState._accentColor
                .withOpacity(0.12),
            child: Icon(
              classIconFor(classRecord.icon),
              color: _StudentClassDetailPageState._accentColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classRecord.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scheduleLine,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  studentsLine,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Teacher: ${classRecord.teacherName}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _SchedulesSection extends StatelessWidget {
  const _SchedulesSection({
    required this.schedules,
    required this.scheduleError,
  });

  final List<ScheduleRecord> schedules;
  final String? scheduleError;

  @override
  Widget build(BuildContext context) {
    if (scheduleError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          scheduleError!,
          style: TextStyle(color: Colors.red.shade700),
        ),
      );
    }

    if (schedules.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          'No schedules yet.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      );
    }

    return Column(
      children: schedules
          .map(
            (s) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _StudentClassDetailPageState._accentColor
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_today_outlined,
                      color: _StudentClassDetailPageState._accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.day,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_prettyTime(s.start)} - ${_prettyTime(s.end)}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  static String _prettyTime(String raw) {
    // raw may be '09:00' or '09:00:00'; fall back to raw on parse issues
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $suffix';
  }
}

class _SessionsSection extends StatelessWidget {
  const _SessionsSection({
    required this.sessions,
    required this.attendedSessionIds,
    required this.error,
    required this.onRefresh,
    required this.classService,
  });

  final List<ClassSession> sessions;
  final Set<int> attendedSessionIds;
  final String? error;
  final VoidCallback onRefresh;
  final ClassService classService;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(error!, style: TextStyle(color: Colors.red.shade700)),
            ),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
      );
    }

    if (sessions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.history, color: Colors.black54),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No previous sessions yet.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
      );
    }

    return Column(
      children: sessions
          .map(
            (s) => _SessionCard(
              session: s,
              attended: attendedSessionIds.contains(s.id),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudentSessionDetailPage(
                    classService: classService,
                    session: s,
                    initiallyAttended: attendedSessionIds.contains(s.id),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.attended,
    required this.onTap,
  });

  final ClassSession session;
  final bool attended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = _prettyDate(session.sessionDate);
    final timeRange = _prettyRange(session.startTime, session.endTime);

    final chipBg = attended
        ? Colors.green.withOpacity(0.12)
        : Colors.red.withOpacity(0.12);
    final chipFg = attended ? Colors.green.shade800 : Colors.red.shade800;
    final chipText = attended ? 'Attended' : 'Missed';
    final chipIcon = attended ? Icons.check_circle : Icons.cancel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _StudentClassDetailPageState._accentColor.withOpacity(
                    0.1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.history,
                  color: _StudentClassDetailPageState._accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeRange,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(chipIcon, size: 18, color: chipFg),
                    const SizedBox(width: 6),
                    Text(
                      chipText,
                      style: TextStyle(
                        color: chipFg,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _prettyRange(String? start, String? end) {
    final s = start == null || start.isEmpty ? null : _prettyTime(start);
    final e = end == null || end.isEmpty ? null : _prettyTime(end);
    if (s == null && e == null) return 'Time unavailable';
    if (s != null && e != null) return '$s - $e';
    if (s != null) return 'Started at $s';
    return 'Ended at $e';
  }

  static String _prettyDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Session';
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
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  static String _prettyTime(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $suffix';
  }
}

class _NoSessionCard extends StatelessWidget {
  const _NoSessionCard({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.black54),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No active session right now. Refresh when your teacher starts one.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({
    required this.session,
    required this.error,
    required this.codeCtrl,
    required this.loading,
    required this.alreadyAttended,
    required this.onSubmit,
    required this.onScan,
  });

  final ClassSession session;
  final String? error;
  final TextEditingController codeCtrl;
  final bool loading;
  final bool alreadyAttended;
  final void Function(String code) onSubmit;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wifi_tethering,
                color: _StudentClassDetailPageState._accentColor,
              ),
              const SizedBox(width: 8),
              const Text(
                'Active Session',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(error!, style: TextStyle(color: Colors.red.shade700)),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (loading || alreadyAttended) ? null : onScan,
                        icon: Icon(
                          alreadyAttended
                              ? Icons.check_circle
                              : Icons.qr_code_scanner,
                        ),
                        label: Text(
                          alreadyAttended ? 'Already attended' : 'Scan QR',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _StudentClassDetailPageState._accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Started at ${_formatStart(session)}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  static String _formatStart(ClassSession session) {
    final raw = session.startTime ?? '';
    final pretty = raw.isEmpty ? '-' : _prettyTime(raw);
    final date = session.sessionDate;
    return date == null || date.isEmpty ? pretty : '$pretty • $date';
  }

  static String _prettyTime(String raw) {
    // raw may be '09:00' or '09:00:00'; fall back to raw on parse issues
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $suffix';
  }
}
