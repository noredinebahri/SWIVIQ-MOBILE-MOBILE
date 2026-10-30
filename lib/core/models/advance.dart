import 'json_utils.dart';

/// Avance sur salaire d'un professeur (GET/POST /teacher-advance).
///
/// Workflow : pending → approved | rejected | cancelled. Une avance
/// confirmée est retenue automatiquement sur le net du mois de paie.
class TeacherAdvance {
  TeacherAdvance({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.teacherPhone,
    required this.amount,
    required this.month,
    required this.year,
    required this.periodLabel,
    required this.reason,
    required this.status,
    required this.payrollSnapshot,
    required this.requestedVia,
    required this.deciderName,
    required this.decidedAt,
    required this.decisionNote,
    required this.createdAt,
  });

  final int id;
  final int teacherId;
  final String teacherName;
  final String? teacherPhone;
  final num amount;
  final int month;
  final int year;
  final String periodLabel;
  final String? reason;
  final String status;
  final num? payrollSnapshot;
  final String requestedVia;
  final String? deciderName;
  final DateTime? decidedAt;
  final String? decisionNote;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get statusLabel => switch (status) {
        'pending' => 'En attente',
        'approved' => 'Confirmée',
        'rejected' => 'Refusée',
        'cancelled' => 'Annulée',
        _ => status,
      };

  factory TeacherAdvance.fromJson(Map<String, dynamic> j) {
    return TeacherAdvance(
      id: asInt(j['id']),
      teacherId: asInt(j['teacherId']),
      teacherName: j['teacherName']?.toString() ?? 'Professeur',
      teacherPhone: asStringOrNull(j['teacherPhone']),
      amount: asNum(j['amount']),
      month: asInt(j['month']),
      year: asInt(j['year']),
      periodLabel: j['periodLabel']?.toString() ?? '',
      reason: asStringOrNull(j['reason']),
      status: j['status']?.toString() ?? 'pending',
      payrollSnapshot: asNumOrNull(j['payrollSnapshot']),
      requestedVia: j['requestedVia']?.toString() ?? 'web',
      deciderName: asStringOrNull(j['deciderName']),
      decidedAt: DateTime.tryParse(j['decidedAt']?.toString() ?? '')?.toLocal(),
      decisionNote: asStringOrNull(j['decisionNote']),
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '')?.toLocal(),
    );
  }
}

/// Paie du mois recalculée en direct par le serveur (page de confirmation).
class AdvanceLivePayroll {
  AdvanceLivePayroll({
    required this.grandTotal,
    required this.hourlyTotal,
    required this.enrollmentTotal,
    required this.individualTotal,
    required this.polycopiesTotal,
    required this.sessionCount,
    required this.totalHours,
    required this.advancesTotal,
    required this.netTotal,
    required this.rateTypes,
  });

  final num grandTotal;
  final num hourlyTotal;
  final num enrollmentTotal;
  final num individualTotal;
  final num polycopiesTotal;
  final int sessionCount;
  final num totalHours;
  final num advancesTotal;
  final num netTotal;
  final List<String> rateTypes;

  String get modeLabel {
    final hourly = rateTypes.contains('hourly');
    final pct = rateTypes.any((t) => t != 'hourly');
    if (hourly && pct) return 'Séances + pourcentage';
    if (pct) return 'Payé au pourcentage';
    if (hourly) return 'Payé à la séance';
    return 'Barème non configuré';
  }

  factory AdvanceLivePayroll.fromJson(Map<String, dynamic> j) {
    return AdvanceLivePayroll(
      grandTotal: asNum(j['grandTotal']),
      hourlyTotal: asNum(j['hourlyTotal']),
      enrollmentTotal: asNum(j['enrollmentTotal']),
      individualTotal: asNum(j['individualTotal']),
      polycopiesTotal: asNum(j['polycopiesTotal']),
      sessionCount: asInt(j['sessionCount']),
      totalHours: asNum(j['totalHours']),
      advancesTotal: asNum(j['advancesTotal']),
      netTotal: asNum(j['netTotal']),
      rateTypes: (j['rateTypes'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class TeacherAdvanceDetail {
  TeacherAdvanceDetail({
    required this.advance,
    required this.payroll,
    required this.history,
  });

  final TeacherAdvance advance;
  final AdvanceLivePayroll? payroll;
  final List<TeacherAdvance> history;

  factory TeacherAdvanceDetail.fromJson(Map<String, dynamic> j) {
    return TeacherAdvanceDetail(
      advance: TeacherAdvance.fromJson(j),
      payroll: j['payroll'] is Map
          ? AdvanceLivePayroll.fromJson(Map<String, dynamic>.from(j['payroll']))
          : null,
      history: asMapList(j['history']).map(TeacherAdvance.fromJson).toList(),
    );
  }
}

String fmtMoney(num v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
