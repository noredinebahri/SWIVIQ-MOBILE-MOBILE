import 'dart:convert';

import 'json_utils.dart';
import 'reference.dart';

/// Configuration du formulaire d'inscription : GET /inscription/config
/// (un seul appel qui alimente toutes les listes du formulaire).
///
/// La réponse est enveloppée : `{success, payload: {...}}` — le repo déplie
/// avant d'appeler fromJson.
class InscriptionConfig {
  InscriptionConfig({
    required this.levels,
    required this.subjects,
    required this.neighborhoods,
    required this.schools,
    required this.centers,
    required this.pricing,
    required this.discounts,
    required this.cycles,
    required this.levelGroups,
    required this.packs,
    required this.extras,
  });

  final List<Level> levels;
  final List<Mater> subjects;
  final List<NamedRef> neighborhoods;
  final List<NamedRef> schools;
  final List<NamedRef> centers;
  final List<LevelPricing> pricing;
  final List<PackDiscount> discounts;

  /// Hiérarchie scolaire : Cycle ▸ Niveau supérieur ▸ Niveau. Listes vides si
  /// la migration hiérarchie n'est pas jouée côté serveur (fallback : liste
  /// à plat des niveaux).
  final List<LevelCycle> cycles;
  final List<LevelGroup> levelGroups;

  /// Packs de matières par niveau (prix fixe) + options payantes (extras),
  /// comme sur le front web.
  final List<SubjectPack> packs;
  final List<ExtraOption> extras;

  List<SubjectPack> packsForLevel(int levelId) =>
      packs.where((p) => p.levelId == levelId).toList();

  factory InscriptionConfig.fromJson(Map<String, dynamic> j) =>
      InscriptionConfig(
        levels: (j['levels'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Level.fromJson(Map<String, dynamic>.from(e)))
            .where((l) => l.actif == 1)
            .toList(),
        subjects: (j['subjects'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Mater.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        neighborhoods: NamedRef.listFrom(j['neighborhoods']),
        schools: NamedRef.listFrom(j['schools']),
        centers: NamedRef.listFrom(j['centers']),
        pricing: (j['pricing'] as List? ?? [])
            .whereType<Map>()
            .map((e) => LevelPricing.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        discounts: (j['discounts'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PackDiscount.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        cycles: (j['levelCycles'] as List? ?? [])
            .whereType<Map>()
            .map((e) => LevelCycle.fromJson(Map<String, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
        levelGroups: (j['levelGroups'] as List? ?? [])
            .whereType<Map>()
            .map((e) => LevelGroup.fromJson(Map<String, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
        packs: (j['subjectPacks'] as List? ?? [])
            .whereType<Map>()
            .map((e) => SubjectPack.fromJson(Map<String, dynamic>.from(e)))
            .where((p) => p.actif == 1)
            .toList(),
        extras: ExtraOption.listFromSettings(j['settings']),
      );

  bool get hasHierarchy => cycles.isNotEmpty;

  /// Niveaux d'un cycle donné (via levelGroup ou cycleId direct).
  List<Level> levelsOfCycle(int cycleId) =>
      levels.where((l) => l.cycleId == cycleId).toList();

  /// Prix d'une matière pour un niveau — même règle que le front web
  /// (grille `pricing` uniquement, 0 si absente).
  num priceFor(int levelId, int materId, {bool individual = false}) {
    for (final p in pricing) {
      if (p.levelId == levelId && p.materId == materId) {
        return individual ? p.priceIndiv : p.price;
      }
    }
    return 0;
  }

  /// Remise applicable selon le nombre de matières choisies.
  num discountPercentFor(int levelId, int subjectCount) {
    num best = 0;
    for (final d in discounts) {
      if (d.levelId == levelId &&
          d.actif == 1 &&
          subjectCount >= d.minSubjects &&
          d.discountPercent > best) {
        best = d.discountPercent;
      }
    }
    return best;
  }
}

class NamedRef {
  NamedRef({required this.id, required this.name});
  final int id;
  final String name;

  static List<NamedRef> listFrom(dynamic raw) => (raw as List? ?? [])
      .whereType<Map>()
      .where((e) =>
          e['actif'] == null ||
          e['actif'] == 1 ||
          e['actif'] == true ||
          e['actif'] == '1')
      .map((e) => NamedRef(
            id: asInt(e['id']),
            name: e['name']?.toString() ?? '',
          ))
      .toList();
}

class LevelPricing {
  LevelPricing({
    required this.levelId,
    required this.materId,
    this.price = 0,
    this.priceIndiv = 0,
    this.actif = 1,
  });

  final int levelId;
  final int materId;
  final num price;
  final num priceIndiv;
  final int actif;

  factory LevelPricing.fromJson(Map<String, dynamic> j) => LevelPricing(
        levelId: asInt(j['levelId']),
        materId: asInt(j['materId']),
        price: asNum(j['price']),
        priceIndiv: asNum(j['priceIndiv']),
        actif: asInt(j['actif'], 1),
      );
}

class PackDiscount {
  PackDiscount({
    required this.levelId,
    required this.minSubjects,
    required this.discountPercent,
    this.actif = 1,
  });

  final int levelId;
  final int minSubjects;
  final num discountPercent;
  final int actif;

  factory PackDiscount.fromJson(Map<String, dynamic> j) => PackDiscount(
        levelId: asInt(j['levelId']),
        minSubjects: asInt(j['min_subjects']),
        discountPercent: asNum(j['discount_percent']),
        actif: asInt(j['actif'], 1),
      );
}

/// Pack de matières à prix fixe (ex. « pack essentiel » : 3 matières, 350 DH).
class SubjectPack {
  SubjectPack({
    required this.id,
    required this.name,
    required this.levelId,
    required this.price,
    required this.subjectIds,
    this.actif = 1,
  });

  final int id;
  final String name;
  final int levelId;
  final num price;
  final List<int> subjectIds;
  final int actif;

  factory SubjectPack.fromJson(Map<String, dynamic> j) {
    // `subjects` arrive en tableau via l'API, en chaîne JSON depuis la base.
    var raw = j['subjects'];
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        raw = const [];
      }
    }
    final ids = (raw is List)
        ? raw.map(asIntOrNull).whereType<int>().toList()
        : <int>[];
    return SubjectPack(
      id: asInt(j['id']),
      name: j['name']?.toString() ?? '',
      levelId: asInt(j['levelId']),
      price: asNum(j['price']),
      subjectIds: ids,
      actif: asInt(j['actif'], 1),
    );
  }
}

/// Option payante à l'inscription (settings.extras_options, JSON).
class ExtraOption {
  ExtraOption({required this.id, required this.label, required this.price});

  final String id;
  final String label;
  final num price;

  static List<ExtraOption> listFromSettings(dynamic settings) {
    try {
      final raw = settings is Map ? settings['extras_options'] : null;
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => ExtraOption(
                  id: e['id']?.toString() ?? '',
                  label: e['label']?.toString() ?? '',
                  price: asNum(e['price']),
                ))
            .toList();
      }
    } catch (_) {}
    return const [];
  }
}
