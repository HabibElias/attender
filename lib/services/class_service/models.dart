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

class AddStudentToClassParams {
  AddStudentToClassParams({required this.classId, required this.studentId});

  final int classId;
  final String studentId;
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
  StudentRecord({required this.id, required this.name, this.email});

  final String id;
  final String name;
  final String? email;
}

class ClassSession {
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

  final int id;
  final int classId;
  final int? scheduleId;
  final String? sessionDate;
  final String? startTime;
  final String? endTime;
  final String? attendanceCode;
  final bool isActive;
  final String? createdAt;
}

class StudentClassRecord {
  StudentClassRecord({
    required this.id,
    required this.name,
    this.icon,
    required this.teacherName,
    this.teacherEmail,
  });

  final int id;
  final String name;
  final String? icon;
  final String teacherName;
  final String? teacherEmail;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'icon': icon,
    'teacher_name': teacherName,
    'teacher_email': teacherEmail,
  };

  static StudentClassRecord fromMap(Map<String, dynamic> map) =>
      StudentClassRecord(
        id: map['id'] as int,
        name: map['name'] as String,
        icon: map['icon'] as String?,
        teacherName: map['teacher_name'] as String? ?? 'Teacher',
        teacherEmail: map['teacher_email'] as String?,
      );
}

class StudentDashboardStats {
  const StudentDashboardStats({
    required this.todayActiveSessions,
    required this.pastSessionsToday,
    required this.attendanceRate,
  });

  final int todayActiveSessions;
  final int pastSessionsToday;
  final double attendanceRate; // 0..1

  int get todayTotalSessions => todayActiveSessions + pastSessionsToday;
  double get attendancePercent => attendanceRate * 100;

  factory StudentDashboardStats.fromMap(Map<String, dynamic> map) {
    int asInt(dynamic v) => v is int
        ? v
        : v is num
        ? v.toInt()
        : int.tryParse('$v') ?? 0;
    double asDouble(dynamic v) => v is double
        ? v
        : v is num
        ? v.toDouble()
        : double.tryParse('$v') ?? 0;

    return StudentDashboardStats(
      todayActiveSessions: asInt(map['today_active_sessions']),
      pastSessionsToday: asInt(map['past_sessions_today']),
      attendanceRate: asDouble(map['attendance_rate']),
    );
  }
}

class TeacherDashboardStats {
  const TeacherDashboardStats({
    required this.totalStudents,
    required this.presentToday,
    required this.absentToday,
    required this.attendanceRate,
  });

  final int totalStudents;
  final int presentToday;
  final int absentToday;
  final double attendanceRate; // 0..1

  int get totalMarkedToday => presentToday + absentToday;
  double get attendancePercent => attendanceRate * 100;

  factory TeacherDashboardStats.fromMap(Map<String, dynamic> map) {
    int asInt(dynamic v) => v is int
        ? v
        : v is num
        ? v.toInt()
        : int.tryParse('$v') ?? 0;
    double asDouble(dynamic v) => v is double
        ? v
        : v is num
        ? v.toDouble()
        : double.tryParse('$v') ?? 0;

    return TeacherDashboardStats(
      totalStudents: asInt(map['total_students']),
      presentToday: asInt(map['present_today']),
      absentToday: asInt(map['absent_today']),
      attendanceRate: asDouble(map['attendance_rate']),
    );
  }
}

class TeacherRecentSessionSummary {
  const TeacherRecentSessionSummary({
    required this.sessionId,
    required this.classId,
    required this.className,
    required this.classIcon,
    required this.sessionDate,
    required this.startTime,
    required this.presentCount,
    required this.totalStudents,
  });

  final int sessionId;
  final int classId;
  final String className;
  final String? classIcon;
  final String? sessionDate; // yyyy-mm-dd
  final String? startTime; // HH:mm:ss or HH:mm
  final int presentCount;
  final int totalStudents;
}
