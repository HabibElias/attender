import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<List<ClassRecord>> fetchTeacherClasses() async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }

    print('Fetching classes for user: ${user.id}');
    final rows = await client
        .from('classes')
        .select('id, name, icon, created_at')
        .eq('teacher_id', user.id)
        .order('created_at', ascending: false);

    print('Fetched classes: $rows');

    return (rows as List<dynamic>)
        .map(
          (row) => ClassRecord(
            id: row['id'] as int,
            name: row['name'] as String,
            icon: row['icon'] as String?,
          ),
        )
        .toList();
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
}

class ClassRecord {
  const ClassRecord({required this.id, required this.name, this.icon});

  final int id;
  final String name;
  final String? icon;
}
