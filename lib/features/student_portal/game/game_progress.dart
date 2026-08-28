import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Progression du joueur, conservée sur l'appareil (aucun réseau requis).
///
/// Clé : « stageId-level » → étoiles obtenues (0-3). Un niveau est débloqué
/// si le précédent a au moins 1 étoile ; le premier niveau de chaque monde
/// s'ouvre dès que le monde précédent est terminé (ou pour le monde 1).
class GameProgress {
  static const _starsKey = 'ox_game_stars';
  static const _bestKey = 'ox_game_best_score';
  static const _playedKey = 'ox_game_played';

  static Future<Map<String, int>> _stars() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_starsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((k, v) =>
          MapEntry(k.toString(), int.tryParse(v.toString()) ?? 0));
    } catch (_) {
      return {};
    }
  }

  static String _key(int stageId, int level) => '$stageId-$level';

  static Future<Map<String, int>> all() => _stars();

  static Future<int> starsOf(int stageId, int level) async {
    final map = await _stars();
    return map[_key(stageId, level)] ?? 0;
  }

  /// Enregistre le meilleur résultat : on ne perd jamais des étoiles déjà
  /// gagnées en rejouant moins bien.
  static Future<bool> record({
    required int stageId,
    required int level,
    required int stars,
    required int score,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _stars();
    final key = _key(stageId, level);
    final previous = map[key] ?? 0;
    final improved = stars > previous;
    if (improved) {
      map[key] = stars;
      await prefs.setString(_starsKey, jsonEncode(map));
    }
    final best = prefs.getInt(_bestKey) ?? 0;
    if (score > best) await prefs.setInt(_bestKey, score);
    await prefs.setInt(_playedKey, (prefs.getInt(_playedKey) ?? 0) + 1);
    return improved;
  }

  static Future<int> bestScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_bestKey) ?? 0;
  }

  static Future<int> gamesPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_playedKey) ?? 0;
  }

  static Future<int> totalStars() async {
    final map = await _stars();
    return map.values.fold<int>(0, (sum, v) => sum + v);
  }

  /// Un niveau est jouable si c'est le tout premier, ou si le niveau
  /// précédent (du même monde, ou le dernier du monde précédent) est réussi.
  static bool isUnlocked({
    required Map<String, int> stars,
    required int stageIndex,
    required int level,
    required int levelsPerStage,
  }) {
    if (stageIndex == 0 && level == 1) return true;
    if (level > 1) {
      return (stars['${stageIndex + 1}-${level - 1}'] ?? 0) > 0;
    }
    // Premier niveau d'un monde : le monde précédent doit être terminé.
    return (stars['$stageIndex-$levelsPerStage'] ?? 0) > 0;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_starsKey);
    await prefs.remove(_bestKey);
    await prefs.remove(_playedKey);
  }
}
