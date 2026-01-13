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
        .select('id, name, icon, teacher_id, created_at')
        .eq('teacher_id', user.id)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map(
          (row) => ClassRecord(
            id: row['id'] as int,
            name: row['name'] as String,
            icon: row['icon'] as String?,
            teacherId: row['teacher_id'] as String?,
          ),
        )
        .toList();
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
  });

  final int id;
  String name;
  String? icon;
  String? teacherId;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'icon': icon,
    'teacher_id': teacherId,
  };

  static ClassRecord fromMap(Map<String, dynamic> map) => ClassRecord(
    id: map['id'] as int,
    name: map['name'] as String,
    icon: map['icon'] as String?,
    teacherId: map['teacher_id'] as String?,
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
