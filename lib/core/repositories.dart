import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'models/absence.dart';
import 'models/inscription.dart';
import 'models/json_utils.dart';
import 'models/polycopie.dart';
import 'models/advance.dart';
import 'models/records.dart';
import 'models/reference.dart';
import 'models/schedule.dart';
import 'models/student.dart';

final _api = ApiClient.instance;

// ─────────────────────────── Données de référence ───────────────────────────

final levelsProvider = FutureProvider<List<Level>>((ref) async {
  // Réponse : {success, payload: [...]} — asMapList déplie l'enveloppe.
  final data = await _api.get('/level/list');
  return asMapList(data).map(Level.fromJson).toList();
});

final matersProvider = FutureProvider<List<Mater>>((ref) async {
  final data = await _api.get('/maters/');
  return asMapList(data).map(Mater.fromJson).toList();
});

/// Niveaux supérieurs (hiérarchie Cycle ▸ Niveau supérieur ▸ Niveau).
final levelGroupsProvider = FutureProvider<List<LevelGroup>>((ref) async {
  final data = await _api.get('/level/groups');
  return asMapList(data).map(LevelGroup.fromJson).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
});

// ─────────────────────────────────── Élèves ──────────────────────────────────

class StudentsRepo {
  /// Filtre `level` = NOM du niveau (quirk backend), pas l'id.
  static Future<StudentPage> list({
    int page = 1,
    String? search,
    String? levelName,
    int? levelGroupId,
    int? actif,
    String? isFree,
  }) async {
    final query = <String, dynamic>{};
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (levelName != null && levelName.isNotEmpty) query['level'] = levelName;
    if (levelGroupId != null) query['levelGroupId'] = levelGroupId;
    if (actif != null) query['actif'] = actif;
    if (isFree != null) query['isFree'] = isFree;
    final data = await _api.get('/student/listByPagination/$page/60',
        query: query.isEmpty ? null : query);
    return StudentPage.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static Future<Student> byId(int id) async {
    final data = await _api.get('/student/byId/$id');
    final map = data is Map && data['student'] is Map
        ? data['student']
        : (data is Map && data['payload'] is Map ? data['payload'] : data);
    return Student.fromJson(Map<String, dynamic>.from(map as Map));
  }
}

// ────────────────────────────── Inscription ─────────────────────────────────

class InscriptionRepo {
  static Future<InscriptionConfig> config() async {
    // Réponse : {success, payload: {...}}
    final data = await _api.get('/inscription/config');
    final payload = unwrap(data);
    return InscriptionConfig.fromJson(
        Map<String, dynamic>.from(payload as Map));
  }

  static Future<Map<String, dynamic>> register(
      Map<String, dynamic> body) async {
    final data = await _api.post('/inscription/register', data: body);
    return Map<String, dynamic>.from(data as Map);
  }
}

// ───────────────────────────── Emploi du temps ──────────────────────────────

class ScheduleRepo {
  static Future<List<ScheduleConfig>> configs() async {
    final data = await _api.get('/schedule/config');
    return (data as List)
        .whereType<Map>()
        .map((e) => ScheduleConfig.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// L'emploi du temps sélectionné du centre (null si aucun). Sans lui, un
  /// `GET /schedule` nu renvoie les créneaux de TOUS les emplois jamais créés
  /// — l'accueil mélangeait alors septembre, octobre et les essais.
  static Future<ScheduleConfig?> activeConfig() async {
    final data = await _api.get('/schedule/config/active');
    if (data is! Map) return null;
    return ScheduleConfig.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<List<ScheduleSlot>> slots({int? scheduleConfigId}) async {
    final data = await _api.get('/schedule',
        query: scheduleConfigId == null
            ? null
            : {'scheduleConfigId': scheduleConfigId});
    return (data as List)
        .whereType<Map>()
        .map((e) => ScheduleSlot.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

// ──────────────────────────────── Absences ──────────────────────────────────

class AbsenceRepo {
  /// day = -1 → tout le mois.
  static Future<List<AbsenceEntry>> byLevel(
      int levelId, int month, int year, int day) async {
    final data = await _api.get('/absence/byLevel/$levelId/$month/$year/$day');
    return (data as List)
        .whereType<Map>()
        .map((e) => AbsenceEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Toggle : crée l'absence, ou la supprime si elle existait déjà.
  static Future<String> toggle({
    required int studentId,
    required int levelId,
    required String dateYmd,
    int? matterId,
    String? notes,
  }) async {
    final data = await _api.post('/absence/setAbsence', data: {
      'studentId': studentId,
      'levelId': levelId,
      'asbenceDate': dateYmd,
      if (matterId != null) 'matterId': matterId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return (data as Map)['action']?.toString() ?? 'created';
  }

  /// Enregistre un retard, ou convertit l'absence du jour en retard si elle
  /// existe (seule voie pour annuler une absence déjà pointée).
  /// Retourne l'action serveur : 'created' | 'converted' | 'updated'.
  static Future<String> retard({
    required int studentId,
    required int levelId,
    required String dateYmd,
    required int lateMinutes,
    int? matterId,
  }) async {
    final data = await _api.post('/absence/retard', data: {
      'studentId': studentId,
      'levelId': levelId,
      'date': dateYmd,
      'lateMinutes': lateMinutes,
      if (matterId != null) 'matterId': matterId,
    });
    return (data as Map)['action']?.toString() ?? 'created';
  }

  static Future<void> justify(
      int absenceId, String reason, int justifiedBy) async {
    await _api.post('/absence/$absenceId/justify', data: {
      'justificationReason': reason,
      'justifiedBy': justifiedBy,
    });
  }

  static Future<List<AbsenceLevelSummary>> reportLevels() async {
    final data = await _api.get('/absence/report/levels');
    final list = data is Map && data['data'] is List ? data['data'] : data;
    return (list as List)
        .whereType<Map>()
        .map((e) => AbsenceLevelSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<AbsenceLevelReport> levelReport(
      int levelId, int month, int year) async {
    final data = await _api.get('/absence/report/level/$levelId',
        query: {'month': month, 'year': year});
    return AbsenceLevelReport.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

// ──────────────────── Avances sur salaire des professeurs ───────────────────

class AdvanceRepo {
  static TeacherAdvance _one(dynamic data) {
    final d = unwrap(data);
    if (d is! Map) throw ApiException('Réponse inattendue.');
    return TeacherAdvance.fromJson(Map<String, dynamic>.from(d));
  }

  /// Le prof demande une avance sur le mois de paie choisi.
  static Future<TeacherAdvance> request({
    required num amount,
    required int month,
    required int year,
    String? reason,
    int? teacherId,
  }) async {
    final data = await _api.post('/teacher-advance', data: {
      'amount': amount,
      'month': month,
      'year': year,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (teacherId != null) 'teacherId': teacherId,
      'via': 'mobile',
    });
    return _one(data);
  }

  /// Mes demandes (prof connecté).
  static Future<List<TeacherAdvance>> mine({int? year}) async {
    final data = await _api.get('/teacher-advance/my', query: {
      if (year != null) 'year': year,
    });
    return asMapList(data).map(TeacherAdvance.fromJson).toList();
  }

  /// Direction : toutes les demandes (status: pending|approved|rejected|all).
  static Future<(List<TeacherAdvance>, int)> list({
    String status = 'pending',
    int? month,
    int? year,
  }) async {
    final data = await _api.get('/teacher-advance', query: {
      'status': status,
      if (month != null) 'month': month,
      if (year != null) 'year': year,
    });
    final rows = asMapList(data).map(TeacherAdvance.fromJson).toList();
    final pending = data is Map && data['counts'] is Map
        ? asInt(data['counts']['pending'])
        : rows.where((a) => a.isPending).length;
    return (rows, pending);
  }

  static Future<int> pendingCount() async {
    final data = await _api.get('/teacher-advance/pending-count');
    final d = unwrap(data);
    return d is Map ? asInt(d['pending']) : 0;
  }

  static Future<TeacherAdvanceDetail> detail(int id) async {
    final data = await _api.get('/teacher-advance/$id');
    final d = unwrap(data);
    if (d is! Map) throw ApiException('Réponse inattendue.');
    return TeacherAdvanceDetail.fromJson(Map<String, dynamic>.from(d));
  }

  static Future<TeacherAdvance> approve(int id, {String? note, num? amount}) async {
    final data = await _api.put('/teacher-advance/$id/approve', data: {
      if (note != null && note.isNotEmpty) 'note': note,
      if (amount != null) 'amount': amount,
    });
    return _one(data);
  }

  static Future<TeacherAdvance> reject(int id, {String? note}) async {
    final data = await _api.put('/teacher-advance/$id/reject', data: {
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return _one(data);
  }

  static Future<void> cancel(int id) async {
    await _api.put('/teacher-advance/$id/cancel', data: {});
  }
}

// ──────────────────── Records profs (séances + bulletins) ───────────────────

class RecordsRepo {
  /// Saisie d'une séance par le prof (part en attente de validation).
  ///
  /// [dateYmd] : date réelle de la séance (`YYYY-MM-DD`). Le serveur la
  /// range dans `createdAt`, comme le fait le formulaire web : sans elle, une
  /// séance d'hier saisie aujourd'hui tombait sur le mauvais jour — et sur
  /// le mauvais mois de paie en début de mois.
  static Future<void> createRecord({
    required int userId,
    required int levelId,
    required int recordTimeMinutes,
    required String description,
    String? dateYmd,
    int? levelGroupId,
  }) async {
    await _api.post('/teacher/create', data: {
      'userId': userId,
      'levelId': levelId,
      if (levelGroupId != null) 'levelGroupId': levelGroupId,
      'recordTime': recordTimeMinutes,
      'recordDescription': description,
      if (dateYmd != null) 'createdAt': dateYmd,
    });
  }

  /// Validation d'une séance par la direction (directeur ou manager).
  /// Même payload que le front web (records.component → activeRecord).
  static Future<void> validate(TeacherRecord r) async {
    await _api.put('/teacher/updateStatus', data: {
      'recordTime': r.recordTime,
      'id': r.id,
      'recordDescription': r.recordDescription,
      'active': 1,
      'user_id': r.userId,
      'level_id': r.levelId,
    });
  }

  /// Paie officielle d'un professeur, calculée par le serveur.
  static Future<TeacherPayroll> payroll(
    int professorId, {
    int? month,
    int? year,
    bool includePending = false,
  }) async {
    final data = await _api.get('/teacher/payroll/$professorId', query: {
      if (month != null) 'month': month,
      if (year != null) 'year': year,
      if (includePending) 'includePending': 'true',
      'includeStudents': 'false',
    });
    final payroll = data is Map ? data['payroll'] : null;
    if (payroll is! Map) {
      throw ApiException('Réponse paie inattendue.');
    }
    return TeacherPayroll.fromJson(Map<String, dynamic>.from(payroll));
  }

  /// Génère le rapport PDF des séances (serveur), avec envoi WhatsApp
  /// optionnel. Retourne {pdf: base64, fileName, stats, whatsapp?}.
  static Future<Map<String, dynamic>> generateReport({
    required int teacherId,
    required String periodType, // 'month' | 'week'
    int? weekNumber,
    bool sendWhatsApp = false,
  }) async {
    final data = await _api.post('/teacher-payment/generate-report', data: {
      'teacherId': teacherId,
      'periodType': periodType,
      if (weekNumber != null) 'weekNumber': weekNumber,
      'sendWhatsApp': sendWhatsApp,
    });
    if (data is Map && data['success'] == true) {
      return Map<String, dynamic>.from(data);
    }
    final message = data is Map ? data['error']?.toString() : null;
    throw ApiException(message ?? 'Impossible de générer le rapport.');
  }

  /// Records du prof connecté (204 → liste vide).
  static Future<List<TeacherRecord>> myRecords(int userId) async {
    final data = await _api.get('/teacher/getTeacherById/$userId');
    if (data == null || data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => TeacherRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Tous les records du centre (vue direction).
  static Future<List<TeacherRecord>> allRecords() async {
    final data = await _api.get('/teacher/getTeachers');
    if (data == null || data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => TeacherRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

// ─────────────────────────────── Paiements ──────────────────────────────────

/// Encaissement — mêmes endpoints et payloads que le profil paiement du web
/// (payment/add.component + profile/payment.component).
class PaymentsRepo {
  /// Référence auto « PAY-YYYYMMDD-XXXX » (même format que le web).
  static String generateReference() {
    final now = DateTime.now();
    final rand =
        (now.microsecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    final ymd = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return 'PAY-$ymd-$rand';
  }

  /// Paiement d'une mensualité : POST /payment/save.
  /// `price` = prix mensuel de référence, `amount` = montant réellement payé,
  /// le reste est calculé comme sur le web.
  static Future<Map<String, dynamic>> saveMonth({
    required int studentId,
    required int levelId,
    required int paymentMonth,
    required int paymentYear,
    required num price,
    required num amount,
    required String paymentMethod,
    String? checkNumber,
    String? bankReference,
    String? cardLastDigits,
    String? comment,
    bool sendWhatsApp = false,
  }) async {
    final now = DateTime.now();
    final dateYmd = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final reference = generateReference();
    final data = await _api.post('/payment/save', data: {
      'studentId': studentId,
      'paymentDate': dateYmd,
      'payment_month': paymentMonth,
      'payment_year': paymentYear,
      'amount': amount,
      'price': price,
      'rest': (price - amount) > 0 ? price - amount : 0,
      'levelId': levelId,
      'paymentMethod': paymentMethod,
      'status': 'confirme',
      'reference': reference,
      if (checkNumber != null && checkNumber.isNotEmpty)
        'checkNumber': checkNumber,
      if (bankReference != null && bankReference.isNotEmpty)
        'bankReference': bankReference,
      if (cardLastDigits != null && cardLastDigits.isNotEmpty)
        'cardLastDigits': cardLastDigits,
      'comment': comment ?? '',
      'generateReceipt': true,
      'rejected': 0,
      'outstandingPaymentIds': const [],
      'prorataInfo': null,
      'sendWhatsApp': sendWhatsApp,
      'createdAt': now.toIso8601String(),
    });
    final map = data is Map ? Map<String, dynamic>.from(data) : {'success': false};
    if (map['success'] != true) {
      throw ApiException(
          map['message']?.toString() ?? 'Un paiement existe déjà pour ce mois.');
    }
    map['reference'] = reference;
    return map;
  }

  /// Solde le reste d'un paiement partiel : POST /payment-manage/pay-rest/:id.
  static Future<void> payRest({
    required int paymentId,
    required num amount,
    required String paymentMethod,
    String? comment,
  }) async {
    await _api.post('/payment-manage/pay-rest/$paymentId', data: {
      'amount': amount,
      'paymentMethod': paymentMethod,
      'comment': comment ?? '',
    });
  }

  /// Statut des séances individuelles : GET /payment/individual-status/:id.
  static Future<Map<String, dynamic>> indivStatus(int studentId) async {
    final data = await _api.get('/payment/individual-status/$studentId');
    final payload = unwrap(data);
    return payload is Map
        ? Map<String, dynamic>.from(payload)
        : <String, dynamic>{};
  }

  /// Paiement des séances individuelles : POST /payment/save-individual.
  static Future<void> payIndividual({
    required int studentId,
    required num amount,
    required String paymentMethod,
    String? comment,
  }) async {
    await _api.post('/payment/save-individual', data: {
      'studentId': studentId,
      'amount': amount,
      'paymentDate': DateTime.now().toIso8601String(),
      'paymentMethod': paymentMethod,
      'reference': generateReference(),
      'comment': comment ?? 'Paiement séances individuelles',
    });
  }

  /// Paiement d'un polycopié : POST /payment/save-polycopie.
  static Future<void> payPolycopie({
    required int studentId,
    int? studentPolycopieId,
    required num amount,
    required String paymentMethod,
    String? comment,
  }) async {
    await _api.post('/payment/save-polycopie', data: {
      'studentId': studentId,
      if (studentPolycopieId != null)
        'studentPolycopieId': studentPolycopieId,
      'amount': amount,
      'paymentDate': DateTime.now().toIso8601String(),
      'paymentMethod': paymentMethod,
      'comment': comment ?? '',
    });
  }

  /// Statut de l'abonnement bibliothèque.
  static Future<Map<String, dynamic>> libraryStatus(int studentId) async {
    final data =
        await _api.get('/books/subscriptions/current-status/$studentId');
    return data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
  }

  /// Paiement de l'abonnement bibliothèque : POST /books/subscriptions/pay.
  static Future<void> payLibrary({
    required int studentId,
    required String paymentMethod,
    String? notes,
  }) async {
    await _api.post('/books/subscriptions/pay', data: {
      'studentId': studentId,
      'paymentMethod': paymentMethod,
      'notes': notes ?? 'Abonnement bibliothèque',
    });
  }
}

// ───────────────────────── Échéances (manager) ──────────────────────────────

/// Élève avec une échéance de paiement (moteur de relances du backend).
class DueEntry {
  DueEntry({
    required this.studentId,
    required this.name,
    required this.levelName,
    this.phone,
    this.monthlyAmount = 0,
    this.cyclesOwed = 1,
    this.amountDue = 0,
    this.daysLate = 0,
    this.dueDate,
    this.monthsOwed = 0,
    this.restDue = 0,
  });

  final int studentId;
  final String name;
  final String levelName;
  final String? phone;
  final num monthlyAmount;
  final int cyclesOwed;
  final num amountDue;
  final int daysLate;
  final DateTime? dueDate;

  /// Détail de la dette (sans statuts) : mois sans ligne de paiement, et
  /// restes des paiements partiels.
  final int monthsOwed;
  final num restDue;

  factory DueEntry.fromJson(Map<String, dynamic> j) => DueEntry(
        studentId: asInt(j['studentId']),
        name: j['name']?.toString() ?? '',
        levelName: j['levelName']?.toString().trim() ?? '',
        phone: asStringOrNull(j['phone']),
        monthlyAmount: asNum(j['monthlyAmount']),
        cyclesOwed: asInt(j['cyclesOwed'], 1),
        amountDue: asNum(j['amountDue']),
        daysLate: asInt(j['daysLate']),
        dueDate: DateTime.tryParse(j['dueDate']?.toString() ?? ''),
        monthsOwed: asInt(j['monthsOwed'], asInt(j['cyclesOwed'], 1)),
        restDue: asNum(j['restDue']),
      );
}

class CollectionsRepo {
  /// Liste des échéances : 'today' | 'tomorrow' | 'overdue' (rôles d/m).
  static Future<List<DueEntry>> list(String scope) async {
    final data = await _api.get('/payment/collections/list/$scope');
    return asMapList(data).map(DueEntry.fromJson).toList();
  }

  /// Relance WhatsApp du parent, envoyée par le BACKEND.
  static Future<void> remind(int studentId) async {
    await _api.post('/payment/collections/remind/$studentId');
  }

  /// Réglages relances + fenêtre de notification du manager.
  static Future<Map<String, dynamic>> config() async {
    final data = await _api.get('/settings/collections');
    final payload = unwrap(data);
    return payload is Map
        ? Map<String, dynamic>.from(payload)
        : <String, dynamic>{};
  }
}

// ─────────────────────────────── Polycopiés ─────────────────────────────────

class PolycopieRepo {
  static Future<List<Polycopie>> list({int? levelId, int? actif}) async {
    final data = await _api.get('/polycopie', query: {
      if (levelId != null) 'levelId': levelId,
      if (actif != null) 'actif': actif,
    });
    return asMapList(data).map(Polycopie.fromJson).toList();
  }

  static Future<void> create({
    required String name,
    required num price,
    int? levelId,
    String? groupName,
    int? subjectId,
    String? description,
  }) async {
    await _api.post('/polycopie', data: {
      'name': name,
      'price': price,
      if (levelId != null) 'levelId': levelId,
      if (groupName != null && groupName.isNotEmpty) 'groupName': groupName,
      if (subjectId != null) 'subjectId': subjectId,
      if (description != null && description.isNotEmpty)
        'description': description,
    });
  }

  static Future<void> update(int id, Map<String, dynamic> fields) async {
    await _api.put('/polycopie/$id', data: fields);
  }

  static Future<void> archive(int id) async {
    await _api.delete('/polycopie/$id');
  }

  static Future<List<StudentPolycopie>> forStudent(int studentId) async {
    final data = await _api.get('/polycopie/for-student/$studentId');
    return asMapList(data).map(StudentPolycopie.fromJson).toList();
  }

  static Future<void> assign(int studentId, int polycopieId) async {
    await _api.post('/polycopie/assign',
        data: {'studentId': studentId, 'polycopieId': polycopieId});
  }

  static Future<void> unassign(int studentId, int polycopieId) async {
    await _api.post('/polycopie/unassign',
        data: {'studentId': studentId, 'polycopieId': polycopieId});
  }
}

class StudentReportRepo {
  static Future<List<ReportGroup>> myGroups({int? month, int? year}) async {
    final data = await _api.get('/student-report/mes-groupes', query: {
      if (month != null) 'month': month,
      if (year != null) 'year': year,
    });
    return ((data as Map)['payload'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ReportGroup.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<ReportStudent>> groupStudents(
    int levelId,
    String group, {
    required String subject,
    int? month,
    int? year,
  }) async {
    final data =
        await _api.get('/student-report/groupe/$levelId/$group', query: {
      'subject': subject,
      if (month != null) 'month': month,
      if (year != null) 'year': year,
    });
    return ((data as Map)['payload'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ReportStudent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Enregistre l'évaluation. Avec [sendWhatsapp], le serveur la transmet
  /// ensuite au responsable de l'élève et rend le résultat de l'envoi ;
  /// l'enregistrement reste acquis même si l'envoi échoue. Null si l'envoi
  /// n'a pas été demandé.
  static Future<WhatsappSendResult?> saveEvaluation({
    required int studentId,
    required int levelId,
    required String group,
    required String subject,
    required String overall,
    int? month,
    int? year,
    List<String> strengths = const [],
    List<String> concerns = const [],
    num? teacherGrade,
    String? teacherComment,
    bool sendWhatsapp = false,
  }) async {
    final data = await _api.patch('/student-report/eleve/$studentId', data: {
      'levelId': levelId,
      'group': group,
      'subject': subject,
      'overall': overall,
      if (month != null) 'month': month,
      if (year != null) 'year': year,
      if (strengths.isNotEmpty) 'strengths': strengths,
      if (concerns.isNotEmpty) 'concerns': concerns,
      if (teacherGrade != null) 'teacherGrade': teacherGrade,
      if (teacherComment != null && teacherComment.isNotEmpty)
        'teacherComment': teacherComment,
      if (sendWhatsapp) 'sendWhatsapp': true,
    });
    if (!sendWhatsapp) return null;
    final payload = data is Map ? data['payload'] : null;
    final wa = payload is Map ? payload['whatsapp'] : null;
    if (wa is Map) {
      return WhatsappSendResult.fromJson(Map<String, dynamic>.from(wa));
    }
    return const WhatsappSendResult(
        sent: false, error: 'Réponse inattendue du serveur.');
  }

  /// Marque tous les élèves restants du groupe comme « correct ».
  static Future<int> markAllGood(
    int levelId,
    String group, {
    required String subject,
    int? month,
    int? year,
  }) async {
    final data = await _api
        .post('/student-report/groupe/$levelId/$group/tout-va-bien', data: {
      'subject': subject,
      if (month != null) 'month': month,
      if (year != null) 'year': year,
    });
    final payload = (data as Map)['payload'];
    return payload is Map ? (payload['created'] as num?)?.toInt() ?? 0 : 0;
  }
}
