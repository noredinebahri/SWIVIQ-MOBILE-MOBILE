import 'json_utils.dart';

/// Modèles de données de référence (niveaux, matières) partagés entre écrans.
class Level {
  Level({
    required this.id,
    required this.name,
    this.price = 0,
    this.actif = 1,
    this.typeLevel,
    this.levelGroupId,
    this.cycleId,
    this.maxStudents,
  });

  final int id;

  /// Nom BRUT tel qu'en base (espaces de fin conservés) : le filtre de la
  /// liste élèves compare ce nom exactement côté SQL — ne pas trimmer avant
  /// d'envoyer. Utiliser [displayName] pour l'affichage.
  final String name;
  final num price;
  final int actif;
  final int? typeLevel;

  /// Niveau supérieur (hiérarchie Cycle ▸ Niveau supérieur ▸ Niveau).
  final int? levelGroupId;
  final int? cycleId;
  final int? maxStudents;

  String get displayName => name.trim();

  factory Level.fromJson(Map<String, dynamic> j) => Level(
        id: asInt(j['id']),
        name: j['name']?.toString() ?? '',
        price: asNum(j['price']),
        actif: asInt(j['actif'], 1),
        typeLevel: asIntOrNull(j['type_level']),
        levelGroupId: asIntOrNull(j['levelGroupId']),
        cycleId: asIntOrNull(j['cycleId']),
        maxStudents: asIntOrNull(j['max_students']),
      );
}

/// Cycle scolaire (Primaire, Collège, Lycée…).
class LevelCycle {
  LevelCycle({required this.id, required this.name, this.sortOrder = 0});

  final int id;
  final String name;
  final int sortOrder;

  factory LevelCycle.fromJson(Map<String, dynamic> j) => LevelCycle(
        id: asInt(j['id']),
        name: j['name']?.toString() ?? '',
        sortOrder: asInt(j['sortOrder']),
      );
}

/// Niveau supérieur (groupe de niveaux dans un cycle).
class LevelGroup {
  LevelGroup({
    required this.id,
    required this.name,
    this.cycleId,
    this.sortOrder = 0,
  });

  final int id;
  final String name;
  final int? cycleId;
  final int sortOrder;

  factory LevelGroup.fromJson(Map<String, dynamic> j) => LevelGroup(
        id: asInt(j['id']),
        name: j['name']?.toString() ?? '',
        cycleId: asIntOrNull(j['cycleId']),
        sortOrder: asInt(j['sortOrder']),
      );
}

class Mater {
  Mater({
    required this.id,
    required this.name,
    this.category,
    this.defaultPrice = 0,
    this.levelId,
  });

  final int id;
  final String name;

  /// 'general' | 'communication' | 'language'
  final String? category;
  final num defaultPrice;
  final int? levelId;

  factory Mater.fromJson(Map<String, dynamic> j) => Mater(
        id: asInt(j['id']),
        name: j['name']?.toString().trim() ?? '',
        category: j['category']?.toString(),
        defaultPrice: asNum(j['default_price']),
        levelId: asIntOrNull(j['levelId']),
      );
}
