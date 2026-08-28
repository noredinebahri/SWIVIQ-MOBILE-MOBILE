import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/json_utils.dart';

/// Classement du centre pour un jeu. Les scores sont envoyés au serveur à
/// chaque fin de partie ; seul le MEILLEUR score de chaque élève compte,
/// pour que rejouer ne fasse jamais perdre sa place.
class LeaderboardRepo {
  static final _api = ApiClient.instance;

  /// Envoie le résultat et retourne le rang mis à jour (null hors-ligne :
  /// le jeu doit rester jouable sans réseau).
  static Future<LeaderboardMe?> submit({
    required String game,
    required int score,
    required int stars,
  }) async {
    try {
      final data = await _api.post('/student/portal/game/score', data: {
        'game': game,
        'score': score,
        'stars': stars,
        'rounds': 1,
      });
      final payload = unwrap(data);
      if (payload is! Map) return null;
      final map = Map<String, dynamic>.from(payload);
      return LeaderboardMe(
        rank: asInt(map['rank']),
        total: asInt(map['total']),
        score: asInt(map['bestScore']),
        stars: asInt(map['stars']),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<({List<LeaderboardEntry> top, LeaderboardMe? me})> load(
      String game) async {
    final data = await _api.get('/student/portal/game/leaderboard',
        query: {'game': game});
    final payload = unwrap(data);
    final map = payload is Map ? Map<String, dynamic>.from(payload) : {};
    final top = (map['top'] as List? ?? [])
        .whereType<Map>()
        .map((e) => LeaderboardEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final meRaw = map['me'];
    final me = meRaw is Map
        ? LeaderboardMe(
            rank: asInt(meRaw['rank']),
            total: asInt(meRaw['total']),
            score: asInt(meRaw['score']),
            stars: asInt(meRaw['stars']),
          )
        : null;
    return (top: top, me: me);
  }
}

class LeaderboardEntry {
  LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.score,
    required this.stars,
    required this.isMe,
    this.levelName,
  });

  final int rank;
  final String name;
  final int score;
  final int stars;
  final bool isMe;
  final String? levelName;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) =>
      LeaderboardEntry(
        rank: asInt(j['rank']),
        name: j['name']?.toString() ?? 'Élève',
        score: asInt(j['score']),
        stars: asInt(j['stars']),
        isMe: asBool(j['isMe']),
        levelName: asStringOrNull(j['levelName']),
      );
}

class LeaderboardMe {
  LeaderboardMe({
    required this.rank,
    required this.total,
    required this.score,
    required this.stars,
  });

  final int rank;
  final int total;
  final int score;
  final int stars;
}

/// Écran de classement (icône 🏆 dans chaque jeu).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    required this.game,
    required this.title,
    required this.color,
  });

  /// 'math' ou 'culture'.
  final String game;
  final String title;
  final Color color;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<LeaderboardEntry>? _top;
  LeaderboardMe? _me;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final result = await LeaderboardRepo.load(widget.game);
      if (!mounted) return;
      setState(() {
        _top = result.top;
        _me = result.me;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          'Classement indisponible — connecte-toi à internet pour le voir.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🏆 ${widget.title}'),
        backgroundColor: widget.color.withValues(alpha: 0.12),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.wifi_off_rounded,
              size: 48, color: AppColors.secondary300),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: _load,
              child: const Text('Réessayer'),
            ),
          ),
        ],
      );
    }
    if (_top == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final top = _top!;
    if (top.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 60),
          Icon(Icons.emoji_events_outlined,
              size: 52, color: AppColors.secondary300),
          SizedBox(height: 12),
          Text(
            'Personne n’a encore joué.\nSois le premier du classement !',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (_me != null) _myCard(_me!),
        const SizedBox(height: 14),
        for (final e in top) ...[
          _row(e),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _myCard(LeaderboardMe me) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.color, widget.color.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ma place',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
              ),
              Text(
                '${me.rank}${me.rank == 1 ? 'ᵉʳ' : 'ᵉ'} / ${me.total}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Mon meilleur score',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
              ),
              Text(
                '${me.score}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(LeaderboardEntry e) {
    // Podium mis en avant : c'est ce qui donne envie de rejouer.
    final medal = switch (e.rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: e.isMe
            ? widget.color.withValues(alpha: 0.12)
            : (Theme.of(context).brightness == Brightness.dark
                ? AppColors.secondary700.withValues(alpha: 0.35)
                : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: e.isMe ? widget.color : AppColors.secondary200,
          width: e.isMe ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: medal != null
                ? Text(medal, style: const TextStyle(fontSize: 22))
                : Text(
                    '${e.rank}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary400,
                    ),
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.isMe ? '${e.name} (moi)' : e.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: e.isMe ? widget.color : null,
                  ),
                ),
                if (e.levelName != null)
                  Text(
                    e.levelName!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondary400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.star_rounded,
                  size: 15, color: Color(0xFFFACC15)),
              const SizedBox(width: 3),
              Text('${e.stars}',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Text(
                '${e.score}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: widget.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
