import 'json_utils.dart';

/// Polycopié : support de cours facturé, éventuellement rattaché à un
/// niveau/groupe/matière/prof, avec fichier téléchargeable une fois réglé.
class Polycopie {
  Polycopie({
    required this.id,
    required this.name,
    required this.price,
    this.levelId,
    this.groupName,
    this.subjectId,
    this.teacherId,
    this.description,
    this.actif = 1,
    this.fileName,
    this.fileSize,
    this.createdAt,
  });

  final int id;
  final String name;
  final num price;
  final int? levelId;
  final String? groupName;
  final int? subjectId;
  final int? teacherId;
  final String? description;
  final int actif;
  final String? fileName;
  final int? fileSize;
  final DateTime? createdAt;

  bool get isActive => actif == 1;
  bool get hasFile => fileName != null && fileName!.isNotEmpty;

  factory Polycopie.fromJson(Map<String, dynamic> j) => Polycopie(
        id: asInt(j['id']),
        name: j['name']?.toString() ?? '',
        price: asNum(j['price']),
        levelId: asIntOrNull(j['levelId']),
        groupName: asStringOrNull(j['groupName']),
        subjectId: asIntOrNull(j['subjectId']),
        teacherId: asIntOrNull(j['teacherId']),
        description: asStringOrNull(j['description']),
        actif: asInt(j['actif'], 1),
        fileName: asStringOrNull(j['fileName']),
        fileSize: asIntOrNull(j['fileSize']),
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
      );
}

/// Affectation d'un polycopié à un élève (avec suivi de paiement).
class StudentPolycopie {
  StudentPolycopie({
    required this.assignmentId,
    required this.polycopieId,
    required this.name,
    required this.price,
    this.paid = 0,
    this.remaining = 0,
    this.status = 'active',
    this.paidAt,
    this.autoAssigned = false,
    this.description,
  });

  final int assignmentId;
  final int polycopieId;
  final String name;
  final num price;
  final num paid;
  final num remaining;

  /// 'active' | 'paid' | 'cancelled'
  final String status;
  final String? paidAt;
  final bool autoAssigned;
  final String? description;

  factory StudentPolycopie.fromJson(Map<String, dynamic> j) =>
      StudentPolycopie(
        assignmentId: asInt(j['assignmentId']),
        polycopieId: asInt(j['polycopieId']),
        name: j['name']?.toString() ?? '',
        price: asNum(j['price']),
        paid: asNum(j['paid']),
        remaining: asNum(j['remaining']),
        status: j['status']?.toString() ?? 'active',
        paidAt: asStringOrNull(j['paidAt']),
        autoAssigned: asBool(j['autoAssigned']),
        description: asStringOrNull(j['description']),
      );
}
