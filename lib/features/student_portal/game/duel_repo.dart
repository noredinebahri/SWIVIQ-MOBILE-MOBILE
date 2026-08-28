import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/json_utils.dart';

/// Duel Fantôme — on affronte l'ENREGISTREMENT d'une vraie partie.
///
/// Le principe : une partie est entièrement reproductible à partir de sa
/// graine (les questions sont générées, pas stockées). En conservant la
/// graine + le temps de réponse question par question, n'importe quel élève
/// peut rejouer exactement la même épreuve et courir contre le rythme réel
/// de son camarade — sans que les deux soient connectés en même temps.

/// Une réponse enregistrée : temps mis, et réussite.
class GhostStep {
  const GhostStep({required this.ms, required this.ok});

  final int ms;
  final bool ok;

  Map<String, dynamic> toJson() => {'ms': ms, 'ok': ok};

  factory GhostStep.fromJson(Map<String, dynamic> j) => GhostStep(
        ms: asInt(j['ms']),
        ok: asBool(j['ok']),
      );
}

/// L'adversaire : la meilleure partie d'un camarade.
class Ghost {
  const Ghost({
    required this.studentId,
    required this.name,
    required this.stageId,
    required this.level,
    required this.seed,
    required this.score,
    required this.correct,
    required this.totalMs,
    required this.run,
    this.levelName,
  });

  final int studentId;
  final String name;
  final int stageId;
  final int level;
  final int seed;
  final int score;
  final int correct;
  final int totalMs;
  final List<GhostStep> run;
  final String? levelName;

  factory Ghost.fromJson(Map<String, dynamic> j) => Ghost(
        studentId: asInt(j['studentId']),
        name: j['name']?.toString() ?? 'Élève',
        stageId: asInt(j['stageId'], 1),
        level: asInt(j['level'], 1),
        seed: asInt(j['seed']),
        score: asInt(j['score']),
        correct: asInt(j['correct']),
        totalMs: asInt(j['totalMs']),
        levelName: asStringOrNull(j['levelName']),
        run: (j['run'] as List? ?? [])
            .whereType<Map>()
            .map((e) => GhostStep.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class DuelRepo {
  static final _api = ApiClient.instance;

  /// Publie sa partie : elle devient l'adversaire des camarades.
  static Future<void> publish({
    required int stageId,
    required int level,
    required int seed,
    required List<GhostStep> run,
    required int score,
    required int correct,
    required int totalMs,
  }) async {
    try {
      await _api.post('/student/portal/game/ghost', data: {
        'game': 'math',
        'stageId': stageId,
        'level': level,
        'seed': seed.toString(),
        'run': run.map((e) => e.toJson()).toList(),
        'score': score,
        'correct': correct,
        'totalMs': totalMs,
      });
    } catch (_) {
      // Hors-ligne : la partie reste jouable, elle sera publiée plus tard.
    }
  }

  /// Adversaires disponibles (meilleures parties des camarades).
  static Future<List<Ghost>> rivals() async {
    final data = await _api.get('/student/portal/game/ghosts',
        query: {'game': 'math'});
    return asMapList(data).map(Ghost.fromJson).toList();
  }
}

final rivalsProvider = FutureProvider.autoDispose<List<Ghost>>((ref) async {
  return DuelRepo.rivals();
});
