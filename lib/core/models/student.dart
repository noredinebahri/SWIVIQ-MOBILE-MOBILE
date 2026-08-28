import 'dart:convert';

import 'json_utils.dart';

/// Élève tel que renvoyé par GET /student/listByPagination (liste) et
/// GET /student/byId/:id (détail).
///
/// L'API renvoie certains nombres en chaînes (`"priceTotal": "400"`) et les
/// colonnes JSON en chaînes encodées : tout le parsing passe par les helpers
/// tolérants de json_utils.dart.
class Student {
  Student({
    required this.id,
    required this.firstname,
    required this.lastname,
    this.group,
    this.phoneStudent,
    this.phoneRespo,
    this.respo,
    this.email,
    this.priceTotal = 0,
    this.discount = 0,
    this.actif = 1,
    this.isFree = 'non',
    this.levelId,
    this.levelName,
    this.subjects = const [],
    this.absences = const [],
    this.payments = const [],
    this.address,
    this.institution,
    this.situationFamilly,
    this.dateActivation,
  });

  final int id;
  final String firstname;
  final String lastname;
  final String? group;
  final String? phoneStudent;
  final String? phoneRespo;
  final String? respo;
  final String? email;
  final num priceTotal;
  final num discount;
  final int actif;
  final String isFree;
  final int? levelId;
  final String? levelName;
  final List<StudentSubject> subjects;
  final List<StudentAbsenceEntry> absences;
  final List<StudentPayment> payments;
  final String? address;
  final String? institution;
  final String? situationFamilly;
  final String? dateActivation;

  String get fullName => '$firstname $lastname'.trim();
  bool get isActive => actif == 1;
  bool get free => isFree == 'oui';

  factory Student.fromJson(Map<String, dynamic> j) {
    List<StudentSubject> subjects = [];
    final rawSubjects = j['subjects'];
    try {
      final decoded =
          rawSubjects is String ? jsonDecode(rawSubjects) : rawSubjects;
      if (decoded is List) {
        subjects = decoded
            .map((s) {
              if (s is Map) {
                return StudentSubject.fromJson(Map<String, dynamic>.from(s));
              }
              // Anciens enregistrements : simple liste d'ids ou de noms.
              if (s is num) return StudentSubject(id: s.toInt());
              if (s is String) return StudentSubject(name: s);
              return null;
            })
            .whereType<StudentSubject>()
            .toList();
      }
    } catch (_) {}

    final absences = <StudentAbsenceEntry>[];
    if (j['absences'] is List) {
      for (final a in j['absences'] as List) {
        if (a is Map && a['asbenceDate'] != null) {
          final d = DateTime.tryParse(a['asbenceDate'].toString());
          if (d != null) {
            absences.add(StudentAbsenceEntry(
              date: d,
              matterId: asIntOrNull(a['matterId']),
              matterName: a['matter'] is Map
                  ? a['matter']['name']?.toString().trim()
                  : null,
              type: a['type']?.toString() ?? 'absence',
              lateMinutes: asIntOrNull(a['lateMinutes']),
              isJustified: asBool(a['isJustified']),
            ));
          }
        }
      }
    }
    absences.sort((a, b) => b.date.compareTo(a.date));

    // La liste renvoie `Payments`, la fiche détaillée renvoie `payments`.
    final payments = <StudentPayment>[];
    final rawPayments = j['Payments'] ?? j['payments'];
    if (rawPayments is List) {
      for (final p in rawPayments) {
        if (p is Map) {
          payments.add(StudentPayment.fromJson(Map<String, dynamic>.from(p)));
        }
      }
    }
    payments.sort((a, b) => (b.paymentDate ?? '').compareTo(a.paymentDate ?? ''));

    return Student(
      id: asInt(j['id']),
      firstname: j['firstname']?.toString() ?? '',
      lastname: j['lastname']?.toString() ?? '',
      group: asStringOrNull(j['group']),
      phoneStudent: asStringOrNull(j['phoneStudent']),
      phoneRespo: asStringOrNull(j['phoneRespo']),
      respo: asStringOrNull(j['respo']),
      email: asStringOrNull(j['email']),
      priceTotal: asNum(j['priceTotal']),
      discount: asNum(j['discount']),
      actif: asInt(j['actif'], 1),
      isFree: j['isFree']?.toString() ?? 'non',
      levelId: asIntOrNull(j['levelId']),
      levelName: j['Level'] is Map
          ? (j['Level']['name']?.toString().trim())
          : (j['level'] is Map ? j['level']['name']?.toString().trim() : null),
      subjects: subjects,
      absences: absences,
      payments: payments,
      address: asStringOrNull(j['address']),
      institution: asStringOrNull(j['institution']),
      situationFamilly: asStringOrNull(j['situationFamilly']),
      dateActivation: asStringOrNull(j['date_activation']),
    );
  }
}

/// Entrée d'assiduité (absence OU retard) de la fiche élève.
class StudentAbsenceEntry {
  StudentAbsenceEntry({
    required this.date,
    this.matterId,
    this.matterName,
    this.type = 'absence',
    this.lateMinutes,
    this.isJustified = false,
  });

  final DateTime date;
  final int? matterId;
  final String? matterName;

  /// 'absence' | 'retard' — un retard compte comme présent.
  final String type;
  final int? lateMinutes;
  final bool isJustified;

  bool get isRetard => type == 'retard';
}

class StudentSubject {
  StudentSubject({this.id, this.name, this.individual = false});
  final int? id;
  final String? name;
  final bool individual;

  factory StudentSubject.fromJson(Map<String, dynamic> j) => StudentSubject(
        id: asIntOrNull(j['id']),
        name: asStringOrNull(j['name']),
        individual: asBool(j['individual']),
      );
}

class StudentPayment {
  StudentPayment({
    this.id,
    this.price = 0,
    this.rest = 0,
    this.paymentDate,
    this.status,
    this.month,
    this.year,
    this.category,
    this.paymentMethod,
  });

  final int? id;
  final num price;
  final num rest;
  final String? paymentDate;

  /// 'paid' | 'partial' | 'pending' | 'overdue'…
  final String? status;
  final int? month;
  final int? year;

  /// 'group' | 'individual' | 'polycopie' | 'book'…
  final String? category;
  final String? paymentMethod;

  factory StudentPayment.fromJson(Map<String, dynamic> j) => StudentPayment(
        id: asIntOrNull(j['id']),
        price: asNum(j['price']),
        rest: asNum(j['rest']),
        paymentDate: asStringOrNull(j['paymentDate']),
        status: asStringOrNull(j['status']),
        month: asIntOrNull(j['payment_month']),
        year: asIntOrNull(j['payment_year']),
        category: asStringOrNull(j['category']),
        paymentMethod: asStringOrNull(j['paymentMethod']),
      );
}

class StudentPage {
  StudentPage({
    required this.students,
    required this.totalStudent,
    required this.totalPages,
    required this.currentPage,
  });

  final List<Student> students;
  final int totalStudent;
  final int totalPages;
  final int currentPage;

  factory StudentPage.fromJson(Map<String, dynamic> j) => StudentPage(
        students: (j['students'] as List? ?? [])
            .whereType<Map>()
            .map((s) => Student.fromJson(Map<String, dynamic>.from(s)))
            .toList(),
        totalStudent: asInt(j['totalStudent']),
        totalPages: asInt(j['totalPages']),
        currentPage: asInt(j['currentPage'], 1),
      );
}
