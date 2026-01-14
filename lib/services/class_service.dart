import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SchedulePayload {
  const SchedulePayload({
    required this.day,
    required this.start,
    required this.end,
  });

  final String day;
  final String start;
  final String end;

  Map<String, dynamic> toJson() => {'day': day, 'start': start, 'end': end};
}

class ClassService {
  ClassService(this.client);

  final SupabaseClient client;

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
            start: (row['start_time'] as String),
            end: (row['end_time'] as String),
          ),
        )
        .toList();
  }

  Future<List<ClassRecord>> fetchTeacherClasses() async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }

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

  int? _extractCount(dynamic nested) {
    if (nested is List && nested.isNotEmpty) {
      final first = nested.first;
      if (first is Map && first['count'] is int) {
        return first['count'] as int;
      }
    }
    return null;
  }

  // Cached fetch that avoids unnecessary network calls and tolerates failures.
  Future<List<ClassRecord>> getTeacherClasses({
    bool forceRefresh = false,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }

    final box = await Hive.openBox('dataCache');
    final cacheKey = 'teacherClasses:${user.id}';

    if (!forceRefresh) {
      final cached = box.get(cacheKey);
      if (cached is List) {
        try {
          return cached
              .map((e) => ClassRecord.fromMap(Map<String, dynamic>.from(e)))
              .toList();
        } catch (_) {
          // fall through to network if cache corrupted
        }
      }
    }

    try {
      final fresh = await fetchTeacherClasses();
      // persist
      await box.put(cacheKey, fresh.map((c) => c.toMap()).toList());
      return fresh;
    } catch (e) {
      // network failed: try cache
      final cached = box.get(cacheKey);
      if (cached is List) {
        return cached
            .map((e) => ClassRecord.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
      rethrow;
    }
  }

  // Update a single class in cache after editing
  Future<void> updateCachedClass(ClassRecord updated) async {
    final user = client.auth.currentUser;
    if (user == null) return;
    final box = await Hive.openBox('dataCache');
    final cacheKey = 'teacherClasses:${user.id}';
    final cached = box.get(cacheKey);
    if (cached is List) {
      final list = cached
          .map((e) => ClassRecord.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      final idx = list.indexWhere((c) => c.id == updated.id);
      if (idx != -1) {
        list[idx] = updated;
        await box.put(cacheKey, list.map((c) => c.toMap()).toList());
      }
    }
  }

  // Remove a class from cache after deletion
  Future<void> removeCachedClass(int classId) async {
    final user = client.auth.currentUser;
    if (user == null) return;
    final box = await Hive.openBox('dataCache');
    final cacheKey = 'teacherClasses:${user.id}';
    final cached = box.get(cacheKey);
    if (cached is List) {
      final list = cached
          .map((e) => ClassRecord.fromMap(Map<String, dynamic>.from(e)))
          .where((c) => c.id != classId)
          .toList();
      await box.put(cacheKey, list.map((c) => c.toMap()).toList());
    }
  }

  Future<void> createClassWithSchedules({
    required String name,
    required String icon,
    required List<SchedulePayload> schedules,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }

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
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }

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

  // Search students via DB function search_students
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

  // Add a student to a class (class_students junction table)
  Future<void> addStudentToClass({
    required AddStudentToClassParams params,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }

    final existing = await client
        .from('class_students')
        .select()
        .eq('class_id', params.classId)
        .eq('student_id', params.studentId)
        .maybeSingle();

    if (existing != null) {
      // Student already added to class, no action needed
      return;
    }

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
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }

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

  Future<ClassSession?> fetchActiveSession(int classId) async {
    final row = await client
        .from('class_sessions')
        .select(
          'id, class_id, schedule_id, session_date, start_time, end_time, attendance_code, is_active, created_at',
        )
        .eq('class_id', classId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .maybeSingle();

    if (row == null) return null;
    return ClassSession(
      id: row['id'] as int,
      classId: row['class_id'] as int,
      scheduleId: row['schedule_id'] as int?,
      sessionDate: row['session_date'] as String?,
      startTime: row['start_time'] as String?,
      endTime: row['end_time'] as String?,
      attendanceCode: row['attendance_code'] as String,
      isActive: row['is_active'] as bool? ?? false,
      createdAt: row['created_at'] as String?,
    );
  }

  Future<ClassSession> createClassSession({
    required int classId,
    required int? scheduleId,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }

    final now = DateTime.now().toUtc();
    final sessionDate = now.toIso8601String().split('T').first;
    final startTime = _hhmmss(now);
    final code = _randomCode();

    final rows = await client
        .from('class_sessions')
        .insert({
          'class_id': classId,
          'schedule_id': scheduleId,
          'session_date': sessionDate,
          'start_time': startTime,
          'end_time': null,
          'attendance_code': code,
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

  // Fetch recent sessions for all classes owned by the current teacher.
  Future<List<ClassSession>> fetchTeacherSessions({
    DateTime? from,
    DateTime? to,
  }) async {
    final classes = await fetchTeacherClasses();
    final ids = classes.map((c) => c.id).toList();
    if (ids.isEmpty) return [];

    final List<ClassSession> out = [];
    for (final classId in ids) {
      var q = client
          .from('class_sessions')
          .select(
            'id, class_id, schedule_id, session_date, start_time, end_time, attendance_code, is_active, created_at',
          )
          .eq('class_id', classId)
          .order('session_date', ascending: false);

      final rows = await q;
      // ignore: dead_code, unnecessary_type_check
      if (rows is! List) continue;
      out.addAll(
        (rows as List<dynamic>)
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

    // sort by date desc
    out.sort((a, b) => (b.sessionDate ?? '').compareTo(a.sessionDate ?? ''));
    return out;
  }

  // Try to count attendance records for a given session id. Returns 0 if none or on error.
  Future<int> fetchSessionAttendanceCount(int sessionId) async {
    try {
      final rows = await client
          .from('attendances')
          .select('id')
          .eq('session_id', sessionId);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  // Fetch attendances for a session and return student records where possible.
  Future<List<StudentRecord>> fetchSessionAttendances(int sessionId) async {
    try {
      // Try joining students if relation exists; fallback to student_id only.
      final rows = await client
          .from('attendances')
          .select('student_id, students(id, name, email)')
          .eq('session_id', sessionId);
      final out = <StudentRecord>[];
      for (final row in rows) {
        if (row['students'] != null) {
          final s = row['students'];
          out.add(
            StudentRecord(
              id: s['id'] as String,
              name: (s['name'] as String?) ?? 'Unnamed',
              email: s['email'] as String?,
            ),
          );
        } else if (row['student_id'] != null) {
          out.add(
            StudentRecord(
              id: row['student_id'].toString(),
              name: 'Student',
              email: null,
            ),
          );
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  // Delete a single session by id.
  Future<void> deleteSession(int sessionId) async {
    await client.from('class_sessions').delete().eq('id', sessionId);
  }

  // Fetch sessions for a single class.
  Future<List<ClassSession>> fetchSessionsForClass(int classId) async {
    final rows = await client
        .from('class_sessions')
        .select(
          'id, class_id, schedule_id, session_date, start_time, end_time, attendance_code, is_active, created_at',
        )
        .eq('class_id', classId)
        .order('session_date', ascending: false);
    return (rows as List<dynamic>)
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
        .toList();
  }

  Future<void> closeActiveSession(int classId) async {
    final now = DateTime.now().toUtc();
    final endTime = _hhmmss(now);

    await client
        .from('class_sessions')
        .update({'is_active': false, 'end_time': endTime})
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

class AddStudentToClassParams {
  final int classId;
  final String studentId;

  AddStudentToClassParams({required this.classId, required this.studentId});
}

class ClassRecord {
  ClassRecord({
    required this.id,
    required this.name,
    this.icon,
    this.teacherId,
    this.studentCount,
  });

  final int id;
  String name;
  String? icon;
  String? teacherId;
  int? studentCount;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'icon': icon,
    'teacher_id': teacherId,
    'student_count': studentCount,
  };

  static ClassRecord fromMap(Map<String, dynamic> map) => ClassRecord(
    id: map['id'] as int,
    name: map['name'] as String,
    icon: map['icon'] as String?,
    teacherId: map['teacher_id'] as String?,
    studentCount: map['student_count'] as int?,
  );
}

class ScheduleRecord {
  const ScheduleRecord({
    required this.id,
    required this.day,
    required this.start,
    required this.end,
  });

  final int id;
  final String day; // e.g., Monday
  final String start; // HH:mm:ss or HH:mm
  final String end; // HH:mm:ss or HH:mm

  String get startHm => _hm(start);
  String get endHm => _hm(end);

  static String _hm(String t) {
    // t may be '09:00:00' or '09:00'
    final parts = t.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return t;
  }
}

class StudentRecord {
  final String id;
  final String name;
  final String? email;

  StudentRecord({required this.id, required this.name, this.email});
}

class ClassSession {
  final int id;
  final int classId;
  final int? scheduleId;
  final String? sessionDate;
  final String? startTime;
  final String? endTime;
  final String attendanceCode;
  final bool isActive;
  final String? createdAt;

  ClassSession({
    required this.id,
    required this.classId,
    this.scheduleId,
    this.sessionDate,
    this.startTime,
    this.endTime,
    required this.attendanceCode,
    required this.isActive,
    this.createdAt,
  });
}
