import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'cache_store.dart';
import 'models.dart';

class ClassService {
  ClassService(this.client, {DataCacheStore? cache})
    : _cache = cache ?? const DataCacheStore();

  final SupabaseClient client;
  final DataCacheStore _cache;

  User _requireUser() {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }
    return user;
  }

  String _teacherClassesKey(String userId) => 'teacherClasses:$userId';
  String _studentClassesKey(String userId) => 'studentClasses:$userId';

  // -----------------------------
  // Schedules
  // -----------------------------

  Future<List<ScheduleRecord>> fetchClassSchedules(int classId) async {
    final rows = await client
        .from('schedules')
        .select('id, day_of_week, start_time, end_time')
        .eq('class_id', classId)
        .order('id');

    return (rows as List<dynamic>)
        .map(
          (row) => ScheduleRecord(
            id: row['id'] as int,
            day: row['day_of_week'] as String,
            start: row['start_time'] as String,
            end: row['end_time'] as String,
          ),
        )
        .toList();
  }

  // -----------------------------
  // Teacher classes
  // -----------------------------

  Future<List<ClassRecord>> fetchTeacherClasses() async {
    final user = _requireUser();

    final rows = await client
        .from('classes')
        .select('id, name, icon, teacher_id, created_at, class_students(count)')
        .eq('teacher_id', user.id)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map(
          (row) => ClassRecord(
            id: row['id'] as int,
            name: row['name'] as String,
            icon: row['icon'] as String?,
            teacherId: row['teacher_id'] as String?,
            studentCount: _extractCount(row['class_students']),
          ),
        )
        .toList();
  }

  Future<List<ClassRecord>> getTeacherClasses({
    bool forceRefresh = false,
  }) async {
    final user = _requireUser();
    final key = _teacherClassesKey(user.id);

    if (!forceRefresh) {
      final cached = await _cache.readList<ClassRecord>(
        key: key,
        fromMap: ClassRecord.fromMap,
      );
      if (cached != null) return cached;
    }

    try {
      final fresh = await fetchTeacherClasses();
      await _cache.writeList(
        key: key,
        value: fresh.map((c) => c.toMap()).toList(),
      );
      return fresh;
    } catch (_) {
      final cached = await _cache.readList<ClassRecord>(
        key: key,
        fromMap: ClassRecord.fromMap,
      );
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<void> updateCachedClass(ClassRecord updated) async {
    final user = client.auth.currentUser;
    if (user == null) return;

    await _cache.updateListItem<ClassRecord>(
      key: _teacherClassesKey(user.id),
      fromMap: ClassRecord.fromMap,
      toMap: (c) => c.toMap(),
      matches: (c) => c.id == updated.id,
      updated: updated,
    );
  }

  Future<void> removeCachedClass(int classId) async {
    final user = client.auth.currentUser;
    if (user == null) return;

    await _cache.removeListItem<ClassRecord>(
      key: _teacherClassesKey(user.id),
      fromMap: ClassRecord.fromMap,
      toMap: (c) => c.toMap(),
      shouldKeep: (c) => c.id != classId,
    );
  }

  int? _extractCount(dynamic nested) {
    if (nested is List && nested.isNotEmpty) {
      final first = nested.first;
      if (first is Map && first['count'] is int) {
        return first['count'] as int;
      }
    }
    return null;
  }

  // -----------------------------
  // Student classes
  // -----------------------------

  Future<List<StudentClassRecord>> fetchStudentClasses() async {
    _requireUser();

    // Uses Postgres RPC to fetch classes for the authenticated student
    final rows = await client.rpc('get_student_classes');

    return (rows as List<dynamic>)
        .map(
          (row) => StudentClassRecord(
            id: row['class_id'] as int,
            name: row['class_name'] as String,
            icon: row['class_icon'] as String?,
            teacherName: (row['teacher_name'] as String?) ?? 'Teacher',
            teacherEmail: row['teacher_email'] as String?,
          ),
        )
        .toList();
  }

  Future<List<StudentClassRecord>> getStudentClasses({
    bool forceRefresh = false,
  }) async {
    final user = _requireUser();
    final key = _studentClassesKey(user.id);

    if (!forceRefresh) {
      final cached = await _cache.readList<StudentClassRecord>(
        key: key,
        fromMap: StudentClassRecord.fromMap,
      );
      if (cached != null) return cached;
    }

    try {
      final fresh = await fetchStudentClasses();
      await _cache.writeList(
        key: key,
        value: fresh.map((c) => c.toMap()).toList(),
      );
      return fresh;
    } catch (_) {
      final cached = await _cache.readList<StudentClassRecord>(
        key: key,
        fromMap: StudentClassRecord.fromMap,
      );
      if (cached != null) return cached;
      rethrow;
    }
  }

  // -----------------------------
  // Attendance
  // -----------------------------

  Future<void> submitAttendance({required String code}) async {
    _requireUser();

    // If the RPC does not exist or errors, this will throw.
    await client.rpc('create_attendance', params: {'p_attendance_code': code});
  }

  Future<Set<int>> fetchAttendedSessionIds(Iterable<int> sessionIds) async {
    final user = _requireUser();
    final ids = sessionIds.toSet().toList();
    if (ids.isEmpty) return <int>{};

    final rows = await client
        .from('attendance')
        .select('session_id')
        .eq('student_id', user.id)
        .inFilter('session_id', ids);

    final out = <int>{};
    for (final row in (rows as List<dynamic>)) {
      final value = (row as Map<String, dynamic>)['session_id'];
      if (value is int) {
        out.add(value);
      } else if (value is num) {
        out.add(value.toInt());
      } else if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) out.add(parsed);
      }
    }
    return out;
  }

  Future<StudentDashboardStats> fetchStudentDashboardStats() async {
    _requireUser();
    final rows = await client.rpc('get_student_dashboard_stats');

    if (rows is List && rows.isNotEmpty) {
      final first = rows.first;
      if (first is Map<String, dynamic>) {
        return StudentDashboardStats.fromMap(first);
      }
    }

    throw StateError('No dashboard stats available');
  }

  Future<TeacherDashboardStats> fetchTeacherDashboardStats() async {
    _requireUser();
    final rows = await client.rpc('get_teacher_dashboard_stats');

    if (rows is List && rows.isNotEmpty) {
      final first = rows.first;
      if (first is Map<String, dynamic>) {
        return TeacherDashboardStats.fromMap(first);
      }
    }

    throw StateError('No dashboard stats available');
  }

  // -----------------------------
  // Class create/update/delete
  // -----------------------------

  Future<void> createClassWithSchedules({
    required String name,
    required String icon,
    required List<SchedulePayload> schedules,
  }) async {
    _requireUser();

    await client.rpc(
      'create_class_with_schedules',
      params: {
        'class_name': name,
        'class_icon': icon,
        'schedules': schedules.map((s) => s.toJson()).toList(),
      },
    );
  }

  Future<void> updateClassWithSchedules({
    required int classId,
    required String name,
    required String icon,
    required List<SchedulePayload> schedules,
  }) async {
    _requireUser();

    await client.rpc(
      'update_class_with_schedules',
      params: {
        'p_class_id': classId,
        'p_class_name': name,
        'p_class_icon': icon,
        'p_schedules': schedules.map((s) => s.toJson()).toList(),
      },
    );
  }

  Future<void> deleteClass(int classId) async {
    await client.from('classes').delete().eq('id', classId);
  }

  // -----------------------------
  // Students in class
  // -----------------------------

  Future<List<StudentRecord>> searchStudents(String query) async {
    final rows = await client.rpc('search_students', params: {'query': query});

    return (rows as List<dynamic>)
        .map(
          (row) => StudentRecord(
            id: row['id'] as String,
            name: (row['name'] as String?) ?? 'Unnamed',
            email: row['email'] as String?,
          ),
        )
        .toList();
  }

  Future<void> addStudentToClass({
    required AddStudentToClassParams params,
  }) async {
    _requireUser();

    final existing = await client
        .from('class_students')
        .select()
        .eq('class_id', params.classId)
        .eq('student_id', params.studentId)
        .maybeSingle();

    if (existing != null) return;

    final response = await client
        .from('class_students')
        .insert({'class_id': params.classId, 'student_id': params.studentId})
        .select()
        .maybeSingle();

    if (response == null) {
      throw Exception('Failed to add student to class');
    }
  }

  Future<void> removeStudentFromClass({
    required int classId,
    required String studentId,
  }) async {
    _requireUser();

    final response = await client
        .from('class_students')
        .delete()
        .eq('class_id', classId)
        .eq('student_id', studentId)
        .select()
        .maybeSingle();

    if (response == null) {
      throw Exception('Failed to remove student from class');
    }
  }

  Future<List<StudentRecord>> fetchClassStudents(int classId) async {
    final rows = await client.rpc(
      'get_class_students',
      params: {'p_class_id': classId},
    );

    return (rows as List<dynamic>)
        .map(
          (row) => StudentRecord(
            id: row['id'] as String,
            name: (row['name'] as String?) ?? 'Unnamed',
            email: row['email'] as String?,
          ),
        )
        .toList();
  }

  // -----------------------------
  // Sessions
  // -----------------------------

  Future<ClassSession?> fetchActiveSession(
    int classId, {
    bool isStudent = false,
  }) async {
    Map<String, dynamic>? row;

    if (isStudent) {
      row = await client
          .rpc('get_active_class_session', params: {'p_class_id': classId})
          .maybeSingle();
    } else {
      row = await client
          .from('class_sessions')
          .select(
            'id, class_id, schedule_id, session_date, start_time, end_time, attendance_code, is_active, created_at',
          )
          .eq('class_id', classId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .maybeSingle();
    }

    if (row == null) return null;

    return ClassSession(
      id: row['id'] as int,
      classId: row['class_id'] as int,
      scheduleId: row['schedule_id'] as int?,
      sessionDate: row['session_date'] as String?,
      startTime: row['start_time'] as String?,
      endTime: row['end_time'] as String?,
      attendanceCode: row['attendance_code'] as String?,
      isActive: row['is_active'] as bool? ?? false,
      createdAt: row['created_at'] as String?,
    );
  }

  Future<ClassSession> createClassSession({
    required int classId,
    required int? scheduleId,
  }) async {
    _requireUser();

    final now = DateTime.now().toUtc();
    final sessionDate = now.toIso8601String().split('T').first;

    final rows = await client
        .from('class_sessions')
        .insert({
          'class_id': classId,
          'schedule_id': scheduleId,
          'session_date': sessionDate,
          'start_time': _hhmmss(now),
          'end_time': null,
          'attendance_code': _randomCode(),
          'is_active': true,
        })
        .select()
        .single();

    return ClassSession(
      id: rows['id'] as int,
      classId: rows['class_id'] as int,
      scheduleId: rows['schedule_id'] as int?,
      sessionDate: rows['session_date'] as String?,
      startTime: rows['start_time'] as String?,
      endTime: rows['end_time'] as String?,
      attendanceCode: rows['attendance_code'] as String,
      isActive: rows['is_active'] as bool? ?? false,
      createdAt: rows['created_at'] as String?,
    );
  }

  Future<List<ClassSession>> fetchTeacherSessions({
    DateTime? from,
    DateTime? to,
  }) async {
    final classes = await fetchTeacherClasses();
    final ids = classes.map((c) => c.id).toList();
    if (ids.isEmpty) return [];

    final out = <ClassSession>[];

    for (final classId in ids) {
      var query = client
          .from('class_sessions')
          .select(
            'id, class_id, schedule_id, session_date, start_time, end_time, attendance_code, is_active, created_at',
          )
          .eq('class_id', classId);

      if (from != null) {
        query = query.gte(
          'session_date',
          from.toIso8601String().split('T').first,
        );
      }
      if (to != null) {
        query = query.lte(
          'session_date',
          to.toIso8601String().split('T').first,
        );
      }

      final rows =
          (await query.order('session_date', ascending: false))
              as List<dynamic>;

      out.addAll(
        rows
            .map(
              (row) => ClassSession(
                id: row['id'] as int,
                classId: row['class_id'] as int,
                scheduleId: row['schedule_id'] as int?,
                sessionDate: row['session_date'] as String?,
                startTime: row['start_time'] as String?,
                endTime: row['end_time'] as String?,
                attendanceCode: row['attendance_code'] as String,
                isActive: row['is_active'] as bool? ?? false,
                createdAt: row['created_at'] as String?,
              ),
            )
            .toList(),
      );
    }

    out.sort((a, b) => (b.sessionDate ?? '').compareTo(a.sessionDate ?? ''));
    return out;
  }

  Future<List<TeacherRecentSessionSummary>> fetchTeacherRecentSessions({
    int limit = 3,
  }) async {
    _requireUser();

    final classes = await fetchTeacherClasses();
    final ids = classes.map((c) => c.id).toList();
    if (ids.isEmpty) return const [];

    final rows = await client
        .from('class_sessions')
        .select(
          'id, class_id, session_date, start_time, created_at, classes(id, name, icon, class_students(count)), attendance(count)',
        )
        .inFilter('class_id', ids)
        .order('created_at', ascending: false)
        .limit(limit);

    final out = <TeacherRecentSessionSummary>[];
    for (final raw in (rows as List<dynamic>)) {
      final row = raw as Map<String, dynamic>;

      final classId = row['class_id'] as int;

      String className = 'Class';
      String? classIcon;
      int totalStudents = 0;

      final classObj = row['classes'];
      if (classObj is Map<String, dynamic>) {
        className = (classObj['name'] as String?) ?? className;
        classIcon = classObj['icon'] as String?;
        totalStudents = _extractCount(classObj['class_students']) ?? 0;
      } else if (classObj is List && classObj.isNotEmpty) {
        final first = classObj.first;
        if (first is Map<String, dynamic>) {
          className = (first['name'] as String?) ?? className;
          classIcon = first['icon'] as String?;
          totalStudents = _extractCount(first['class_students']) ?? 0;
        }
      }

      final presentCount = _extractCount(row['attendance']) ?? 0;

      out.add(
        TeacherRecentSessionSummary(
          sessionId: row['id'] as int,
          classId: classId,
          className: className,
          classIcon: classIcon,
          sessionDate: row['session_date'] as String?,
          startTime: row['start_time'] as String?,
          presentCount: presentCount,
          totalStudents: totalStudents,
        ),
      );
    }

    return out;
  }

  Future<int> fetchSessionAttendanceCount(int sessionId) async {
    try {
      final rows = await client
          .from('attendance')
          .select('id')
          .eq('session_id', sessionId);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<List<StudentRecord>> fetchSessionAttendances(int sessionId) async {
    try {
      List<Map<String, dynamic>> rows;
      // try {
      final rpcRows = await client.rpc(
        'get_session_attendances',
        params: {'p_session_id': sessionId},
      );

      rows = (rpcRows as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();

      final out = <StudentRecord>[];
      for (final row in rows) {
        if (row['students'] != null) {
          final s = row['students'];
          out.add(
            StudentRecord(
              id: s['student_id'] as String,
              name: (s['student_name'] as String?) ?? 'Unnamed',
              email: s['student_email'] as String?,
            ),
          );
        } else if (row['student_id'] != null) {
          out.add(
            StudentRecord(
              id: row['student_id'].toString(),
              name: row['student_name'].toString(),
              email: row['student_email']?.toString(),
            ),
          );
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteSession(int sessionId) async {
    await client.from('class_sessions').delete().eq('id', sessionId);
  }

  Future<List<ClassSession>> fetchSessionsForClass(
    int classId, {
    bool isStudent = false,
  }) async {
    List<Map<String, dynamic>> rows;
    if (isStudent) {
      try {
        final rpcRows = await client.rpc(
          'get_student_class_sessions',
          params: {'p_class_id': classId},
        );
        rows = (rpcRows as List<dynamic>)
            .map((e) => e as Map<String, dynamic>)
            .toList();
      } catch (e) {
        rows = [];
      }
    } else {
      rows = await client
          .from('class_sessions')
          .select(
            'id, class_id, schedule_id, session_date, start_time, end_time, attendance_code, is_active, created_at',
          )
          .eq('class_id', classId)
          .order('session_date', ascending: false);
    }

    return (rows as List<dynamic>)
        .map(
          (row) => ClassSession(
            id: row['id'] as int,
            classId: row['class_id'] as int,
            scheduleId: row['schedule_id'] as int?,
            sessionDate: row['session_date'] as String?,
            startTime: row['start_time'] as String?,
            endTime: row['end_time'] as String?,
            attendanceCode: row['attendance_code'] as String?,
            isActive: row['is_active'] as bool? ?? false,
            createdAt: row['created_at'] as String?,
          ),
        )
        .toList();
  }

  Future<void> closeActiveSession(int classId) async {
    final now = DateTime.now().toUtc();

    await client
        .from('class_sessions')
        .update({'is_active': false, 'end_time': _hhmmss(now)})
        .eq('class_id', classId)
        .eq('is_active', true);
  }

  String _hhmmss(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final length = 6 + rand.nextInt(3); // 6-8 chars
    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }
}
