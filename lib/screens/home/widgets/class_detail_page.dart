import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../services/class_service.dart';
import 'class_icon_helper.dart';
import 'edit_class_sheet.dart';
import 'add_students_page.dart';
import 'manage_session_detail_page.dart';
import 'manage_class_sessions_page.dart';

class ClassDetailPage extends StatefulWidget {
  const ClassDetailPage({
    super.key,
    required this.teacherId,
    required this.classService,
    required this.classId,
    required this.className,
    this.classIcon,
  });

  final ClassService classService;
  final int classId;
  final String className;
  final String? classIcon;
  final String? teacherId;

  @override
  State<ClassDetailPage> createState() => _ClassDetailPageState();
}

class _ClassDetailPageState extends State<ClassDetailPage> {
  bool _loading = true;
  bool _deleting = false;
  String? _error;
  List<ScheduleRecord> _schedules = const [];
  late String _className;
  String? _classIcon;
  late String _teacherId;
  List<StudentRecord> _addedStudents = [];
  String? _removingStudentId;
  Future<ClassSession?>? _sessionFuture;
  int? _selectedScheduleId;

  @override
  void initState() {
    super.initState();
    _className = widget.className;
    _classIcon = widget.classIcon;
    _teacherId = widget.teacherId ?? '';
    _sessionFuture = widget.classService.fetchActiveSession(widget.classId);
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scheds = await widget.classService.fetchClassSchedules(
        widget.classId,
      );
      List<StudentRecord> students = [];
      try {
        // Use dynamic to avoid compile-time error if the service doesn't declare fetchClassStudents.
        final res = await (widget.classService as dynamic).fetchClassStudents(
          widget.classId,
        );
        if (res is List<StudentRecord>) {
          students = res;
        } else if (res is List) {
          students = res.cast<StudentRecord>();
        }
      } catch (e) {
        // Service may not implement fetchClassStudents or the call failed; fall back to empty list.
        students = [];
      }
      if (!mounted) return;
      setState(() {
        _schedules = scheds;
        _addedStudents = students;
        _selectedScheduleId ??= _schedules.isNotEmpty
            ? _schedules.first.id
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateToAddStudents() async {
    final result = await showAddStudentsSheet(
      context: context,
      classService: widget.classService,
      classId: widget.classId,
    );

    if (result == true) {
      _load(); // Reload to refresh students list after adding
    }
  }

  void _refreshSession() {
    setState(() {
      _sessionFuture = widget.classService.fetchActiveSession(widget.classId);
    });
  }

  Future<void> _closeSession() async {
    try {
      await widget.classService.closeActiveSession(widget.classId);
    } catch (e) {
      _showSnack('Failed to close session: $e');
    } finally {
      _refreshSession();
    }
  }

  Future<void> _openSchedulePicker() async {
    if (_schedules.isEmpty) {
      // fallback to previous behavior
      await _startSessionWithSchedule(null);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.flash_on),
                title: const Text('Start session without schedule'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startSessionWithSchedule(null);
                },
              ),
              const Divider(height: 1),
              ..._schedules.map((s) {
                return ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(
                    '${s.day} • ${_prettyTime(s.start)} - ${_prettyTime(s.end)}',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmCreateForSchedule(s);
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startSessionWithSchedule(int? scheduleId) async {
    try {
      setState(() {
        _sessionFuture = widget.classService.createClassSession(
          classId: widget.classId,
          scheduleId: scheduleId,
        );
      });
      await _sessionFuture;
      _showSnack('Session started');
    } catch (e) {
      _showSnack('Failed to start session: $e');
      _refreshSession();
    }
  }

  Future<void> _confirmCreateForSchedule(ScheduleRecord s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create session'),
        content: Text(
          'Create session for ${s.day} • ${_prettyTime(s.start)} - ${_prettyTime(s.end)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _startSessionWithSchedule(s.id);
    }
  }

  Future<void> _removeStudent(String studentId) async {
    setState(() => _removingStudentId = studentId);
    try {
      await widget.classService.removeStudentFromClass(
        classId: widget.classId,
        studentId: studentId,
      );
      if (!mounted) return;
      setState(() {
        _addedStudents = _addedStudents
            .where((s) => s.id != studentId)
            .toList();
      });
      _showSnack('Student removed');
    } catch (e) {
      if (mounted) _showSnack('Failed to remove: $e');
    } finally {
      if (mounted) setState(() => _removingStudentId = null);
    }
  }

  Future<void> _confirmRemoveStudent(StudentRecord student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove student?'),
        content: Text('Remove ${student.name} from this class?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _removeStudent(student.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF0E58BC);
    final box = Hive.box('authBox');

    final isTeacher =
        box.get('role') == 'teacher' &&
        box.get('sessionUser')['id'] == _teacherId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      floatingActionButton: isTeacher
          ? FutureBuilder<ClassSession?>(
              future: _sessionFuture,
              builder: (context, snapshot) {
                final hasActive = snapshot.data?.isActive == true;
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return FloatingActionButton(
                    onPressed: null,
                    backgroundColor: accentColor,
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  );
                }
                if (hasActive) {
                  return FloatingActionButton.extended(
                    onPressed: _closeSession,
                    backgroundColor: Colors.redAccent,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Close Class'),
                  );
                }
                return FloatingActionButton.extended(
                  onPressed: _openSchedulePicker,
                  backgroundColor: accentColor,
                  icon: const Icon(Icons.qr_code),
                  label: const Text(
                    'Start Session',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              },
            )
          : null,
      body: Container(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(_error!),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
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
                              backgroundColor: accentColor.withOpacity(0.12),
                              child: Icon(
                                classIconFor(_classIcon),
                                color: accentColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _className,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black87,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _schedules.isEmpty
                                        ? 'No schedules yet'
                                        : '${_schedules.length} schedule(s) this week',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _addedStudents.isEmpty
                                        ? 'No students yet'
                                        : '${_addedStudents.length} student(s)',
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
                      ),
                      const SizedBox(height: 18),
                      FutureBuilder<ClassSession?>(
                        future: _sessionFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
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
                                children: const [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Loading session...'),
                                ],
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Text(
                              'Session load failed',
                              style: TextStyle(color: Colors.red.shade700),
                            );
                          }
                          final session = snapshot.data;
                          if (session == null || session.isActive != true) {
                            return const SizedBox.shrink();
                          }

                          return InkWell(
                            onTap: () async {
                              final nav = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ManageSessionDetailPage(
                                    classService: widget.classService,
                                    session: session,
                                  ),
                                ),
                              );
                              if (nav == true) _refreshSession();
                            },
                            child: Container(
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
                                    children: const [
                                      Icon(
                                        Icons.wifi_tethering,
                                        color: accentColor,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Active Session',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: QrImageView(
                                        data: session.attendanceCode,
                                        size: 140,
                                        eyeStyle: const QrEyeStyle(
                                          eyeShape: QrEyeShape.square,
                                          color: accentColor,
                                        ),
                                        dataModuleStyle:
                                            const QrDataModuleStyle(
                                              dataModuleShape:
                                                  QrDataModuleShape.square,
                                              color: Colors.black,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final nav = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ManageSessionDetailPage(
                                                    classService:
                                                        widget.classService,
                                                    session: session,
                                                  ),
                                            ),
                                          );
                                          if (nav == true) _refreshSession();
                                        },
                                        icon: const Icon(Icons.manage_search),
                                        label: const Text('Manage Session'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: accentColor,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Started at ${_prettyTime(session.startTime ?? '')}${session.sessionDate != null ? ' • ${session.sessionDate}' : ''}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Schedules',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      if (_schedules.isEmpty)
                        Container(
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
                            'No schedules yet. Tap Edit to add one.',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        )
                      else
                        Column(
                          children: _schedules
                              .map(
                                (s) => InkWell(
                                  onTap: () => _confirmCreateForSchedule(s),
                                  borderRadius: BorderRadius.circular(14),
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
                                            color: accentColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.calendar_today_outlined,
                                            color: accentColor,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          color: Colors.black45,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 18),
                      if (box.get('role') == 'teacher' &&
                          box.get('sessionUser')['id'] == _teacherId)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Students',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            if (_addedStudents.isEmpty)
                              Text('No students added yet.'),
                            for (var student in _addedStudents)
                              ListTile(
                                title: Text(student.name),
                                subtitle: Text(student.email ?? ''),
                                trailing: _removingStudentId == student.id
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () =>
                                            _confirmRemoveStudent(student),
                                      ),
                              ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      const SizedBox(height: 18),
                      if (box.get('role') == 'teacher' &&
                          box.get('sessionUser')['id'] == _teacherId)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Actions",
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              alignment: WrapAlignment.start,
                              spacing: 12,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _navigateToAddStudents,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.person_add_alt_1,
                                    size: 18,
                                  ),
                                  label: const Text('Add Students'),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ManageClassSessionsPage(
                                          classService: widget.classService,
                                          classId: widget.classId,
                                          className: _className,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.calendar_month,
                                    size: 18,
                                  ),
                                  label: const Text('Manage Sessions'),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _openEditSheet,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Edit'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _deleting ? null : _confirmDelete,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(
                                      color: Colors.redAccent,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: _deleting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                              Colors.redAccent,
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                        ),
                                  label: const Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _openEditSheet() async {
    final result = await showEditClassSheet(
      context: context,
      classService: widget.classService,
      classId: widget.classId,
      initialName: _className,
      initialIcon: _classIcon ?? kDefaultClassIcon,
      schedules: _schedules,
    );

    if (result != null) {
      setState(() {
        _className = result.name;
        _classIcon = result.icon;
      });
      await _load();
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete class?'),
        content: const Text(
          'This will remove the class and its schedules. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteClass();
    }
  }

  Future<void> _deleteClass() async {
    setState(() => _deleting = true);
    try {
      await widget.classService.deleteClass(widget.classId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        _showSnack('Failed to delete: $e');
      }
    }
  }

  String _prettyTime(String raw) {
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

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
