import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/json_utils.dart';
import 'leaderboard.dart';

/// Arène des jeux — le serveur décide.
///
/// Ce que l'app ne fait plus toute seule :
///  * quels jeux l'élève peut voir (réglé par la direction, par niveau
///    supérieur) → [ArenaConfig.games] ;
///  * quand il peut rejouer : après chaque partie finie ou perdue, attente de
///    base × nombre de parties du jour (2, 4, 6 min…) → [ArenaConfig.cooldown] ;
///  * si un score compte : une manche n'existe que si le serveur l'a ouverte
///    ([GameArena.start] → jeton) et fermée ([GameArena.finish]) — durée et
///    score sont vérifiés côté serveur, l'app ne peut rien « déclarer ».
///
/// Hors-ligne : la manche reste jouable (les jeux sont locaux) mais elle ne
/// compte pas au classement — c'est dit à l'élève.
class ArenaGame {
  ArenaGame({required this.id, required this.name, required this.emoji, required this.allowed});
  final String id;
  final String name;
  final String emoji;
  final bool allowed;
}

class ArenaCooldown {
  ArenaCooldown({required this.waitSeconds, required this.attemptsToday, required this.baseMinutes});
  final int waitSeconds;
  final int attemptsToday;
  final int baseMinutes;
  bool get active => waitSeconds > 0;
}

class ArenaConfig {
  ArenaConfig({required this.games, required this.cooldown, required this.month, required this.year, required this.prize});
  final List<ArenaGame> games;
  final ArenaCooldown cooldown;
  final int month;
  final int year;
  final int prize;

  bool allows(String gameId) => games.any((g) => g.id == gameId && g.allowed);
}

/// Manche ouverte par le serveur.
class ArenaAttempt {
  ArenaAttempt({required this.id, required this.token, required this.game});
  final int id;
  final String token;
  final String game;
}

class ArenaResult {
  ArenaResult({required this.accepted, this.reason, this.me, required this.waitSeconds, required this.attemptsToday});
  final bool accepted;
  final String? reason;
  final LeaderboardMe? me;
  final int waitSeconds;
  final int attemptsToday;
}

/// Refus du serveur à l'ouverture d'une manche.
class ArenaBlocked implements Exception {
  ArenaBlocked(this.code, this.message, {this.waitSeconds = 0});
  final String code; // COOLDOWN | NOT_ALLOWED | OFFLINE
  final String message;
  final int waitSeconds;
}

class GameArena {
  static final _api = ApiClient.instance;

  static Future<ArenaConfig> config() async {
    final data = await _api.get('/student/portal/game/config');
    final p = unwrap(data);
    final map = p is Map ? Map<String, dynamic>.from(p) : <String, dynamic>{};
    final cd = map['cooldown'] is Map ? Map<String, dynamic>.from(map['cooldown']) : <String, dynamic>{};
    return ArenaConfig(
      games: asMapList(map['games'])
          .map((g) => ArenaGame(
                id: g['id']?.toString() ?? '',
                name: g['name']?.toString() ?? '',
                emoji: g['emoji']?.toString() ?? '🎮',
                allowed: asBool(g['allowed']),
              ))
          .toList(),
      cooldown: ArenaCooldown(
        waitSeconds: asInt(cd['waitSeconds']),
        attemptsToday: asInt(cd['attemptsToday']),
        baseMinutes: asInt(cd['baseMinutes']) == 0 ? 2 : asInt(cd['baseMinutes']),
      ),
      month: asInt(map['month']),
      year: asInt(map['year']),
      prize: asInt(map['prize']),
    );
  }

  /// Ouvre une manche. Lève [ArenaBlocked] si le serveur refuse (attente,
  /// jeu fermé à ce niveau) ou si le réseau manque (code OFFLINE).
  static Future<ArenaAttempt> start(String game) async {
    try {
      final data = await _api.post('/student/portal/game/start', data: {'game': game});
      final p = unwrap(data);
      final map = p is Map ? Map<String, dynamic>.from(p) : <String, dynamic>{};
      return ArenaAttempt(id: asInt(map['attemptId']), token: map['token']?.toString() ?? '', game: game);
    } on ApiException catch (e) {
      final body = e.body is Map ? Map<String, dynamic>.from(e.body as Map) : <String, dynamic>{};
      if (e.statusCode == 429) {
        throw ArenaBlocked('COOLDOWN', body['message']?.toString() ?? e.message, waitSeconds: asInt(body['waitSeconds']));
      }
      if (e.statusCode == 403) throw ArenaBlocked('NOT_ALLOWED', body['message']?.toString() ?? e.message);
      throw ArenaBlocked('OFFLINE', 'Pas de connexion : cette manche ne comptera pas au classement.');
    } catch (_) {
      throw ArenaBlocked('OFFLINE', 'Pas de connexion : cette manche ne comptera pas au classement.');
    }
  }

  /// Ferme la manche. Ne lève jamais (hors-ligne → null).
  static Future<ArenaResult?> finish(ArenaAttempt attempt, {required bool won, required int score, required int stars}) async {
    try {
      final data = await _api.post('/student/portal/game/finish', data: {
        'attemptId': attempt.id,
        'token': attempt.token,
        'result': won ? 'win' : 'fail',
        'score': score,
        'stars': stars,
      });
      final p = unwrap(data);
      final map = p is Map ? Map<String, dynamic>.from(p) : <String, dynamic>{};
      final accepted = asBool(map['accepted']);
      return ArenaResult(
        accepted: accepted,
        reason: map['reason']?.toString(),
        me: accepted
            ? LeaderboardMe(rank: asInt(map['rank']), total: asInt(map['total']), score: asInt(map['monthBest']), stars: stars)
            : null,
        waitSeconds: asInt(map['waitSeconds']),
        attemptsToday: asInt(map['attemptsToday']),
      );
    } catch (_) {
      return null;
    }
  }

  /// Ouvre une manche depuis un écran de jeu : en cas d'attente ou de jeu
  /// fermé, explique et renvoie `null` (l'écran doit alors se fermer) ; hors
  /// ligne, prévient et renvoie `null` mais laisse jouer (`allowOffline`).
  static Future<ArenaAttempt?> gate(BuildContext context, String game, {bool allowOffline = true}) async {
    try {
      return await start(game);
    } on ArenaBlocked catch (b) {
      if (!context.mounted) return null;
      if (b.code == 'OFFLINE') {
        if (allowOffline) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(b.message)));
          return null;
        }
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(b.code == 'COOLDOWN' ? '⏳ Un peu de patience' : '🔒 Jeu fermé'),
          content: b.code == 'COOLDOWN'
              ? CooldownCountdown(seconds: b.waitSeconds, message: b.message)
              : Text(b.message),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
        ),
      );
      return null;
    }
  }
}

/// Compte à rebours « prochaine partie dans mm:ss ».
class CooldownCountdown extends StatefulWidget {
  const CooldownCountdown({super.key, required this.seconds, this.message, this.onDone, this.compact = false});
  final int seconds;
  final String? message;
  final VoidCallback? onDone;
  final bool compact;

  @override
  State<CooldownCountdown> createState() => _CooldownCountdownState();
}

class _CooldownCountdownState extends State<CooldownCountdown> {
  late int _left = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_left <= 1) {
        _timer?.cancel();
        setState(() => _left = 0);
        widget.onDone?.call();
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _label {
    final m = (_left ~/ 60).toString().padLeft(2, '0');
    final s = (_left % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return Text(_left == 0 ? 'Prêt !' : _label, style: const TextStyle(fontWeight: FontWeight.w800));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.message != null) Text(widget.message!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(_left == 0 ? 'C\'est reparti !' : _label,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 6),
        const Text('Chaque partie du jour ajoute 2 minutes d\'attente.',
            style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
      ],
    );
  }
}
