import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/schedule.dart';

/// Emploi du temps de l'élève conservé sur l'appareil.
///
/// Objectif : l'élève consulte ses cours SANS réseau. Le serveur renvoie une
/// `version` qui change dès qu'un créneau est créé, modifié ou supprimé (ou
/// qu'une nouvelle version d'emploi du temps est activée) : à la première
/// connexion réseau qui suit, la copie locale est ÉCRASÉE par la nouvelle et
/// l'élève est prévenu — jamais deux versions qui cohabitent.
class ScheduleCache {
  static const _slotsKey = 'ox_sched_slots';
  static const _versionKey = 'ox_sched_version';
  static const _savedAtKey = 'ox_sched_saved_at';

  /// Créneaux enregistrés (liste vide si rien en cache).
  static Future<List<ScheduleSlot>> readSlots() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_slotsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => ScheduleSlot.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<String?> readVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_versionKey);
  }

  /// Date du dernier enregistrement — affichée à l'élève hors-ligne pour
  /// qu'il sache de quand date ce qu'il regarde.
  static Future<DateTime?> readSavedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_savedAtKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Remplace intégralement la copie locale (l'ancienne version est écrasée).
  static Future<void> save({
    required List<Map<String, dynamic>> rawSlots,
    required String version,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_slotsKey, jsonEncode(rawSlots));
    await prefs.setString(_versionKey, version);
    await prefs.setInt(
        _savedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Purge (déconnexion de l'élève : les données ne doivent pas rester).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_slotsKey);
    await prefs.remove(_versionKey);
    await prefs.remove(_savedAtKey);
  }
}
