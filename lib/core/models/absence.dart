import 'json_utils.dart';

/// Modèles absences élèves.
///
/// NB : le backend orthographie `asbenceDate` (typo historique conservée dans
/// la base) — on la garde telle quelle dans les échanges API.
class AbsenceEntry {
  AbsenceEntry({
    required this.id,
    required this.firstname,
    required this.lastname,
    required this.date,
    this.levelName,
  });

  final int id;
  final String firstname;
  final String lastname;
  final DateTime date;
  final String? levelName;

  String get fullName => '$firstname $lastname'.trim();

  factory AbsenceEntry.fromJson(Map<String, dynamic> j) => AbsenceEntry(
        id: asInt(j['id']),
        firstname: j['firstname']?.toString() ?? '',
        lastname: j['lastname']?.toString() ?? '',
        levelName: j['levelName']?.toString(),
        date: DateTime.tryParse(j['asbenceDate']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class AbsenceLevelSummary {
  AbsenceLevelSummary({
    required this.id,
    required this.name,
    this.studentCount = 0,
  });

  final int id;
  final String name;
  final int studentCount;

  factory AbsenceLevelSummary.fromJson(Map<String, dynamic> j) =>
      AbsenceLevelSummary(
        id: asInt(j['id']),
        name: j['name']?.toString() ?? '',
        studentCount: asInt(j['studentCount'], 0),
      );
}

/// Rapport riche par niveau : GET /absence/report/level/:levelId
class AbsenceLevelReport {
  AbsenceLevelReport({
    required this.summary,
    required this.students,
  });

  final AbsenceReportSummary summary;
  final List<AbsenceStudentReport> students;

  factory AbsenceLevelReport.fromJson(Map<String, dynamic> j) {
    final data = j['data'] is Map ? Map<String, dynamic>.from(j['data']) : j;
    return AbsenceLevelReport(
      summary: AbsenceReportSummary.fromJson(
          Map<String, dynamic>.from(data['summary'] as Map? ?? {})),
      students: (data['students'] as List? ?? [])
          .whereType<Map>()
          .map((s) =>
              AbsenceStudentReport.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
    );
  }
}

class AbsenceReportSummary {
  AbsenceReportSummary({
    this.totalStudents = 0,
    this.totalAbsences = 0,
    this.avgAbsences = 0,
    this.attendanceRate = 100,
  });

  final int totalStudents;
  final int totalAbsences;
  final num avgAbsences;
  final num attendanceRate;

  factory AbsenceReportSummary.fromJson(Map<String, dynamic> j) =>
      AbsenceReportSummary(
        totalStudents: asInt(j['totalStudents'], 0),
        totalAbsences: asInt(j['totalAbsences'], 0),
        avgAbsences: asNum(j['avgAbsences'], 0),
        attendanceRate: asNum(j['attendanceRate'], 100),
      );
}

class AbsenceStudentReport {
  AbsenceStudentReport({
    required this.studentId,
    required this.studentName,
    this.parentName,
    this.parentPhone,
    this.totalAbsences = 0,
    this.justifiedAbsences = 0,
    this.unjustifiedAbsences = 0,
    this.attendanceRate = 100,
    this.behaviorLevel = 'excellent',
    this.absenceDates = const [],
  });

  final int studentId;
  final String studentName;
  final String? parentName;
  final String? parentPhone;
  final int totalAbsences;
  final int justifiedAbsences;
  final int unjustifiedAbsences;
  final num attendanceRate;

  /// 'excellent' | 'good' | 'warning' | 'critical'
  final String behaviorLevel;
  final List<AbsenceDateDetail> absenceDates;

  factory AbsenceStudentReport.fromJson(Map<String, dynamic> j) =>
      AbsenceStudentReport(
        studentId: asInt(j['studentId']),
        studentName: j['studentName']?.toString() ?? '',
        parentName: j['parentName']?.toString(),
        parentPhone: j['parentPhone']?.toString(),
        totalAbsences: asInt(j['totalAbsences'], 0),
        justifiedAbsences: asInt(j['justifiedAbsences'], 0),
        unjustifiedAbsences: asInt(j['unjustifiedAbsences'], 0),
        attendanceRate: asNum(j['attendanceRate'], 100),
        behaviorLevel: j['behaviorLevel']?.toString() ?? 'excellent',
        absenceDates: (j['absenceDates'] as List? ?? [])
            .whereType<Map>()
            .map((d) => AbsenceDateDetail.fromJson(Map<String, dynamic>.from(d)))
            .toList(),
      );
}

class AbsenceDateDetail {
  AbsenceDateDetail({required this.date, this.isJustified = false, this.notes});
  final String date;
  final bool isJustified;
  final String? notes;

  factory AbsenceDateDetail.fromJson(Map<String, dynamic> j) =>
      AbsenceDateDetail(
        date: j['date']?.toString() ?? '',
        isJustified: j['isJustified'] == true || j['isJustified'] == 1,
        notes: j['notes']?.toString(),
      );
}
