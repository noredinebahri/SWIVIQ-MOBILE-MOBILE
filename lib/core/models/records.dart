import 'json_utils.dart';

/// Modèles "records" : séances d'enseignement (table `teachers`, 1 ligne =
/// 1 séance) et bulletins mensuels élèves (student-report).
class TeacherRecord {
  TeacherRecord({
    required this.id,
    required this.recordTime,
    required this.recordDescription,
    required this.active,
    this.levelId,
    this.levelName,
    this.teacherName,
    this.priceHour,
    this.createdAt,
    this.userId,
  });

  final int id;

  /// Durée en minutes.
  final int recordTime;
  final String recordDescription;

  /// 0 = en attente de validation, 1 = validé par la direction.
  final int active;
  final int? levelId;
  final String? levelName;
  final String? teacherName;
  final num? priceHour;
  final DateTime? createdAt;

  /// Id du professeur (users.id) — requis pour la validation par la direction.
  final int? userId;

  bool get isValidated => active == 1;

  factory TeacherRecord.fromJson(Map<String, dynamic> j) {
    String? teacherName;
    num? priceHour;
    int? userId = asIntOrNull(j['userId']);
    if (j['user'] is Map) {
      final u = j['user'] as Map;
      teacherName = '${u['firstname'] ?? ''} ${u['lastname'] ?? ''}'.trim();
      priceHour = asNumOrNull(u['priceHour']);
      userId ??= asIntOrNull(u['id']);
    }
    return TeacherRecord(
      id: asInt(j['id']),
      recordTime: asInt(j['recordTime'], 0),
      recordDescription: j['recordDescription']?.toString() ?? '',
      active: asInt(j['active'], 0),
      levelId: asIntOrNull(j['levelId']),
      levelName: j['level'] is Map ? j['level']['name']?.toString() : null,
      teacherName: teacherName?.isEmpty == true ? null : teacherName,
      priceHour: priceHour,
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
      userId: userId,
    );
  }
}

/// Paie serveur d'un professeur : GET /teacher/payroll/:professorId
/// Tous les montants viennent du serveur (moteur de paie officiel) —
/// rien n'est recalculé côté mobile.
class TeacherPayroll {
  TeacherPayroll({
    required this.grandTotal,
    required this.periodLabel,
    required this.hourlyTotal,
    required this.totalHours,
    required this.sessionCount,
    required this.enrollmentTotal,
    required this.enrollmentLevelCount,
    required this.enrollmentStudentCount,
    required this.sessions,
    required this.warnings,
  });

  final num grandTotal;
  final String periodLabel;
  final num hourlyTotal;
  final num totalHours;
  final int sessionCount;
  final num enrollmentTotal;
  final int enrollmentLevelCount;
  final int enrollmentStudentCount;
  final List<PayrollSession> sessions;
  final List<String> warnings;

  factory TeacherPayroll.fromJson(Map<String, dynamic> j) {
    final hourly =
        j['hourly'] is Map ? Map<String, dynamic>.from(j['hourly']) : {};
    final enrollment = j['enrollment'] is Map
        ? Map<String, dynamic>.from(j['enrollment'])
        : {};
    final period =
        j['period'] is Map ? Map<String, dynamic>.from(j['period']) : {};
    return TeacherPayroll(
      grandTotal: asNum(j['grandTotal']),
      periodLabel: period['label']?.toString() ?? '',
      hourlyTotal: asNum(hourly['total']),
      totalHours: asNum(hourly['totalHours']),
      sessionCount: asInt(hourly['sessionCount']),
      enrollmentTotal: asNum(enrollment['total']),
      enrollmentLevelCount: asInt(enrollment['levelCount']),
      enrollmentStudentCount: asInt(enrollment['studentCount']),
      sessions: (hourly['sessions'] as List? ?? [])
          .whereType<Map>()
          .map((s) => PayrollSession.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
      warnings: (j['warnings'] as List? ?? [])
          .map((w) => w is Map
              ? (w['message']?.toString() ?? w.toString())
              : w.toString())
          .toList(),
    );
  }
}

class PayrollSession {
  PayrollSession({
    required this.date,
    required this.description,
    required this.minutes,
    required this.hours,
    required this.pricePerHour,
    required this.amount,
    required this.pending,
    this.levelId,
  });

  final DateTime? date;
  final String description;
  final int minutes;
  final num hours;
  final num pricePerHour;
  final num amount;
  final bool pending;
  final int? levelId;

  factory PayrollSession.fromJson(Map<String, dynamic> j) => PayrollSession(
        date: DateTime.tryParse(j['date']?.toString() ?? ''),
        description: j['description']?.toString() ?? '',
        minutes: asInt(j['minutes']),
        hours: asNum(j['hours']),
        pricePerHour: asNum(j['pricePerHour']),
        amount: asNum(j['amount']),
        pending: asBool(j['pending']),
        levelId: asIntOrNull(j['levelId']),
      );
}

/// Groupe à évaluer ce mois : GET /student-report/mes-groupes
class ReportGroup {
  ReportGroup({
    required this.levelId,
    required this.levelName,
    required this.group,
    required this.subject,
    this.total = 0,
    this.done = 0,
    this.remaining = 0,
  });

  final int levelId;
  final String levelName;
  final String group;
  final String subject;
  final int total;
  final int done;
  final int remaining;

  double get progress => total == 0 ? 1 : done / total;

  factory ReportGroup.fromJson(Map<String, dynamic> j) => ReportGroup(
        levelId: asInt(j['levelId']),
        levelName: j['levelName']?.toString() ?? '',
        group: j['group']?.toString() ?? '',
        subject: j['subject']?.toString() ?? '',
        total: asInt(j['total'], 0),
        done: asInt(j['done'], 0),
        remaining: asInt(j['remaining'], 0),
      );
}

/// Élève dans le tunnel de saisie : GET /student-report/groupe/...
class ReportStudent {
  ReportStudent({
    required this.id,
    required this.firstname,
    required this.lastname,
    this.evaluation,
  });

  final int id;
  final String firstname;
  final String lastname;
  final StudentEvaluation? evaluation;

  String get fullName => '$firstname $lastname'.trim();
  bool get isDone => evaluation != null;

  factory ReportStudent.fromJson(Map<String, dynamic> j) => ReportStudent(
        id: asInt(j['id']),
        firstname: j['firstname']?.toString() ?? '',
        lastname: j['lastname']?.toString() ?? '',
        evaluation: j['evaluation'] is Map
            ? StudentEvaluation.fromJson(
                Map<String, dynamic>.from(j['evaluation'] as Map))
            : null,
      );
}

class StudentEvaluation {
  StudentEvaluation({
    this.overall,
    this.strengths = const [],
    this.concerns = const [],
    this.teacherGrade,
    this.teacherComment,
  });

  /// 'tres_bien' | 'correct' | 'difficultes'
  final String? overall;
  final List<String> strengths;
  final List<String> concerns;
  final num? teacherGrade;
  final String? teacherComment;

  factory StudentEvaluation.fromJson(Map<String, dynamic> j) =>
      StudentEvaluation(
        overall: j['overall']?.toString(),
        strengths:
            (j['strengths'] as List? ?? []).map((e) => e.toString()).toList(),
        concerns:
            (j['concerns'] as List? ?? []).map((e) => e.toString()).toList(),
        teacherGrade: asNumOrNull(j['teacherGrade']),
        teacherComment: j['teacherComment']?.toString(),
      );
}

/// Vocabulaires du backend (evaluation.rules.js) avec libellés FR.
const kOverallOptions = {
  'tres_bien': 'Très bien',
  'correct': 'Correct',
  'difficultes': 'En difficulté',
};

const kStrengthOptions = {
  'participe': 'Participe en classe',
  'progresse': 'Progresse',
  'travail_regulier': 'Travail régulier',
  'aide_les_autres': 'Aide les autres',
  'tres_assidu': 'Très assidu',
};

const kConcernOptions = {
  'devoirs_non_faits': 'Devoirs non faits',
  'comportement': 'Comportement',
  'concentration': 'Concentration',
  'absences': 'Absences',
  'ne_participe_pas': 'Ne participe pas',
  'ne_retient_pas': 'Ne retient pas',
};
