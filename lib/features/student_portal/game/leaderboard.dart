import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/json_utils.dart';

/// Classement du centre pour un jeu, sous forme d'« arène mondiale »
/// mensuelle : chaque mois a son propre classement, verrouillé une fois le
/// mois terminé — le 1ᵉʳ de chaque jeu remporte alors une prime (50 DH).
///
/// Les scores sont envoyés au serveur à chaque fin de partie ; seul le
/// MEILLEUR score de chaque élève compte, pour que rejouer ne fasse jamais
/// perdre sa place.
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

  /// Charge l'arène du mois demandé (mois/année courants si omis).
  static Future<LeaderboardBoard> load(
    String game, {
    int? month,
    int? year,
  }) async {
    final query = <String, dynamic>{'game': game};
    if (month != null) query['month'] = month;
    if (year != null) query['year'] = year;
    final data = await _api.get('/student/portal/game/leaderboard',
        query: query);
    final payload = unwrap(data);
    final map =
        payload is Map ? Map<String, dynamic>.from(payload) : <String, dynamic>{};
    return LeaderboardBoard.fromJson(map);
  }
}

class LeaderboardEntry {
  LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.score,
    required this.stars,
    required this.isMe,
    required this.studentId,
    this.levelName,
    this.attempts = 0,
  });

  final int rank;
  final String name;
  final int score;
  final int stars;
  final bool isMe;
  final int studentId;
  final String? levelName;
  final int attempts;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) =>
      LeaderboardEntry(
        rank: asInt(j['rank']),
        name: j['name']?.toString() ?? 'Élève',
        score: asInt(j['score']),
        stars: asInt(j['stars']),
        isMe: asBool(j['isMe']),
        studentId: asInt(j['studentId']),
        levelName: asStringOrNull(j['levelName']),
        attempts: asInt(j['attempts']),
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

/// Gagnant du mois (non-null seulement quand le mois est verrouillé).
class LeaderboardWinner {
  LeaderboardWinner({
    required this.studentId,
    required this.name,
    required this.score,
    required this.prize,
  });

  final int studentId;
  final String name;
  final int score;
  final int prize;

  factory LeaderboardWinner.fromJson(Map<String, dynamic> j) =>
      LeaderboardWinner(
        studentId: asInt(j['studentId']),
        name: j['name']?.toString() ?? 'Élève',
        score: asInt(j['score']),
        prize: asInt(j['prize'], 50),
      );
}

/// Un mois sélectionnable dans le sélecteur de mois.
class LeaderboardMonth {
  LeaderboardMonth({
    required this.month,
    required this.year,
    required this.locked,
    required this.label,
  });

  final int month;
  final int year;
  final bool locked;
  final String label;

  factory LeaderboardMonth.fromJson(Map<String, dynamic> j) =>
      LeaderboardMonth(
        month: asInt(j['month']),
        year: asInt(j['year']),
        locked: asBool(j['locked']),
        label: j['label']?.toString() ?? '',
      );
}

/// Arène complète d'un mois : classement, ma place, gagnant éventuel et la
/// liste des mois disponibles pour naviguer entre eux.
class LeaderboardBoard {
  LeaderboardBoard({
    required this.game,
    required this.month,
    required this.year,
    required this.locked,
    required this.prize,
    required this.top,
    required this.months,
    this.me,
    this.winner,
  });

  final String game;
  final int month;
  final int year;
  final bool locked;
  final int prize;
  final List<LeaderboardEntry> top;
  final List<LeaderboardMonth> months;
  final LeaderboardMe? me;
  final LeaderboardWinner? winner;

  factory LeaderboardBoard.fromJson(Map<String, dynamic> j) {
    final now = DateTime.now();
    final meRaw = j['me'];
    final winnerRaw = j['winner'];
    return LeaderboardBoard(
      game: j['game']?.toString() ?? '',
      month: asInt(j['month'], now.month),
      year: asInt(j['year'], now.year),
      locked: asBool(j['locked']),
      prize: asInt(j['prize'], 50),
      top: asMapList(j['top']).map(LeaderboardEntry.fromJson).toList(),
      months: asMapList(j['months']).map(LeaderboardMonth.fromJson).toList(),
      me: meRaw is Map
          ? LeaderboardMe(
              rank: asInt(meRaw['rank']),
              total: asInt(meRaw['total']),
              score: asInt(meRaw['score']),
              stars: asInt(meRaw['stars']),
            )
          : null,
      winner: winnerRaw is Map
          ? LeaderboardWinner.fromJson(Map<String, dynamic>.from(winnerRaw))
          : null,
    );
  }
}

// ─────────────────────────── Emoji & couleurs par rang ───────────────────────────

/// Têtes de héros par rang : podium fixe, puis rotation déterministe.
const _rotatingHeroes = [
  '🧙‍♂️',
  '🥷',
  '🐉',
  '🦁',
  '🦅',
  '🧜‍♀️',
  '🧚',
  '🦊',
  '🐯',
  '🦄',
  '🐺',
  '🤖',
];

String _heroEmoji(int rank) {
  switch (rank) {
    case 1:
      return '👑';
    case 2:
      return '🦸‍♂️';
    case 3:
      return '🦸‍♀️';
    default:
      final idx = (rank - 4) % _rotatingHeroes.length;
      return _rotatingHeroes[idx < 0 ? 0 : idx];
  }
}

Color _rankColor(int rank, Color fallback) => switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => fallback,
    };

String _gameEmoji(String game) => game == 'culture' ? '📖' : '🎮';

const _frenchMonths = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _monthLabel(LeaderboardBoard board) {
  final match = board.months.firstWhere(
    (m) => m.month == board.month && m.year == board.year,
    orElse: () =>
        LeaderboardMonth(month: board.month, year: board.year, locked: board.locked, label: ''),
  );
  if (match.label.isNotEmpty) return match.label;
  final idx = board.month - 1;
  final name = (idx >= 0 && idx < 12) ? _frenchMonths[idx] : '';
  return _capitalize('$name ${board.year}'.trim());
}

/// Place le mois courant en tête, sans réordonner le reste.
List<LeaderboardMonth> _orderedMonths(LeaderboardBoard board) {
  final months = List<LeaderboardMonth>.from(board.months);
  final idx =
      months.indexWhere((m) => m.month == board.month && m.year == board.year);
  if (idx > 0) {
    months.insert(0, months.removeAt(idx));
  }
  return months;
}

/// Écran de classement (icône 🏆 dans chaque jeu) : arène mondiale mensuelle.
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
  LeaderboardBoard? _board;
  String? _error;
  int? _month;
  int? _year;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? month, int? year}) async {
    final targetMonth = month ?? _month;
    final targetYear = year ?? _year;
    try {
      final board = await LeaderboardRepo.load(widget.game,
          month: targetMonth, year: targetYear);
      if (!mounted) return;
      setState(() {
        _board = board;
        _month = board.month;
        _year = board.year;
        _error = null;
      });
    } on ApiException catch (e) {
      _onLoadError(e.message);
    } catch (_) {
      _onLoadError(
          'Classement indisponible — connecte-toi à internet pour le voir.');
    }
  }

  void _onLoadError(String message) {
    if (!mounted) return;
    if (_board != null) {
      // Une arène est déjà affichée : on garde ce qui marche plutôt que de
      // tout effacer pour l'échec d'un simple changement de mois.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } else {
      setState(() => _error = message);
    }
  }

  void _selectMonth(LeaderboardMonth m) {
    if (m.month == _month && m.year == _year) return;
    _load(month: m.month, year: m.year);
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    return Scaffold(
      appBar: AppBar(
        title: Text('${_gameEmoji(widget.game)} ${widget.title}'),
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
      bottomNavigationBar: board == null ? null : _bottomBar(board),
    );
  }

  Widget _buildBody() {
    if (_error != null && _board == null) {
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
              onPressed: () => _load(),
              child: const Text('Réessayer'),
            ),
          ),
        ],
      );
    }
    final board = _board;
    if (board == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _header(board),
          const SizedBox(height: 4),
          _listSection(board),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─────────────────────────── En-tête : mois, titre, podium ───────────────────────────

  Widget _header(LeaderboardBoard board) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.color,
            widget.color.withValues(alpha: 0.72),
            _rankColor(1, widget.color).withValues(alpha: 0.55),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: _ConfettiLayer()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (board.months.isNotEmpty) _monthChips(board),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(_gameEmoji(widget.game),
                      style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Arène mondiale',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _monthLabel(board),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (board.locked) _lockedBadge(),
                ],
              ),
              const SizedBox(height: 18),
              if (board.top.isNotEmpty)
                _Podium(
                  entries: board.top.take(3).toList(),
                  color: widget.color,
                ),
              const SizedBox(height: 14),
              _prizeBanner(board),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monthChips(LeaderboardBoard board) {
    final months = _orderedMonths(board);
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: months.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final m = months[i];
          final selected = m.month == board.month && m.year == board.year;
          return ChoiceChip(
            label: Text(m.locked ? '🔒 ${m.label}' : m.label),
            selected: selected,
            onSelected: (_) => _selectMonth(m),
            showCheckmark: false,
            selectedColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? widget.color : Colors.white,
            ),
          );
        },
      ),
    );
  }

  Widget _lockedBadge() {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        '🔒 Verrouillé',
        style: TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _prizeBanner(LeaderboardBoard board) {
    final winner = board.winner;
    final String text;
    if (winner != null) {
      text = '🏆 Gagnant : ${winner.name} — ${winner.prize} DH';
    } else if (!board.locked) {
      text = '🏆 Le 1ᵉʳ à la fin du mois gagne ${board.prize} DH';
    } else {
      text = '🏆 Aucun gagnant ce mois-ci — personne n’a joué.';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── Liste (rangs 4+) ───────────────────────────

  Widget _listSection(LeaderboardBoard board) {
    if (board.top.isEmpty) {
      return _emptyState();
    }
    final rest = board.top.where((e) => e.rank > 3).toList();
    if (rest.isEmpty) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          for (final e in rest) ...[
            _entryRow(e),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: [
          Icon(Icons.emoji_events_outlined,
              size: 52, color: AppColors.secondary300),
          SizedBox(height: 12),
          Text(
            'Personne n’a encore joué ce mois-ci — sois le premier !',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _entryRow(LeaderboardEntry e) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleParts = [
      if (e.levelName != null && e.levelName!.isNotEmpty) e.levelName!,
      if (e.attempts > 0) '${e.attempts} essai${e.attempts > 1 ? 's' : ''}',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: e.isMe
            ? widget.color.withValues(alpha: 0.14)
            : (isDark
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
            width: 28,
            child: Text(
              '${e.rank}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.secondary400),
            ),
          ),
          const SizedBox(width: 4),
          Text(_heroEmoji(e.rank), style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        e.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: e.isMe ? widget.color : null,
                        ),
                      ),
                    ),
                    if (e.isMe) _toiTag(),
                  ],
                ),
                if (subtitleParts.isNotEmpty)
                  Text(
                    subtitleParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.secondary400),
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

  Widget _toiTag() {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Toi',
        style:
            TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ─────────────────────────── Barre du bas : ma place ───────────────────────────

  Widget _bottomBar(LeaderboardBoard board) {
    final me = board.me;
    return SafeArea(
      minimum: EdgeInsets.zero,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [widget.color, widget.color.withValues(alpha: 0.78)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: me == null
            ? Row(
                children: [
                  const Icon(Icons.rocket_launch_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Joue une partie pour entrer dans l’arène !',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ta place : #${me.rank} sur ${me.total} · ${me.score} pts',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Podium des 3 premiers : avatars héros géants, pastilles or/argent/bronze.
class _Podium extends StatelessWidget {
  const _Podium({required this.entries, required this.color});

  /// Jusqu'à 3 entrées, triées par rang croissant.
  final List<LeaderboardEntry> entries;
  final Color color;

  LeaderboardEntry? _at(int i) => entries.length > i ? entries[i] : null;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _slot(_at(1), 2, 92)),
        Expanded(child: _slot(_at(0), 1, 122)),
        Expanded(child: _slot(_at(2), 3, 74)),
      ],
    );
  }

  Widget _slot(LeaderboardEntry? e, int rank, double pedestalHeight) {
    if (e == null) return const SizedBox();
    final rankColor = _rankColor(rank, color);
    final avatarSize = rank == 1 ? 68.0 : 54.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (e.isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Toi',
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          Container(
            width: avatarSize,
            height: avatarSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.92),
              border: Border.all(color: rankColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: rankColor.withValues(alpha: 0.6),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Text(_heroEmoji(rank),
                style: TextStyle(fontSize: rank == 1 ? 34 : 26)),
          ),
          const SizedBox(height: 6),
          Text(
            e.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          Text(
            '${e.score} pts',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            height: pedestalHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [rankColor, rankColor.withValues(alpha: 0.65)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confettis décoratifs (formes pures Flutter, positions fixes et
/// déterministes — pas d'assets, pas de dépendance).
class _ConfettiLayer extends StatelessWidget {
  const _ConfettiLayer();

  static const _dots = <_ConfettiDot>[
    _ConfettiDot(top: 2, left: 20, size: 10, color: Color(0x33FFFFFF)),
    _ConfettiDot(top: 16, left: 64, size: 7, color: Color(0x55FFD700), square: true),
    _ConfettiDot(top: 0, right: 34, size: 12, color: Color(0x40FFFFFF), square: true),
    _ConfettiDot(top: 28, right: 10, size: 8, color: Color(0x55FFFFFF)),
    _ConfettiDot(bottom: 34, left: 10, size: 9, color: Color(0x40FFD700)),
    _ConfettiDot(bottom: 12, left: 46, size: 6, color: Color(0x60FFFFFF), square: true),
    _ConfettiDot(bottom: 20, right: 54, size: 11, color: Color(0x33FFFFFF)),
    _ConfettiDot(bottom: 6, right: 18, size: 7, color: Color(0x55FFFFFF), square: true),
    _ConfettiDot(top: 44, left: 34, size: 6, color: Color(0x40FFFFFF)),
    _ConfettiDot(top: 50, right: 64, size: 9, color: Color(0x50FFD700), square: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(children: [for (final d in _dots) d.build()]);
  }
}

class _ConfettiDot {
  const _ConfettiDot({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.size,
    required this.color,
    this.square = false,
  });

  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double size;
  final Color color;
  final bool square;

  Widget build() {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: square ? 0.6 : 0,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: square ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: square ? BorderRadius.circular(2) : null,
          ),
        ),
      ),
    );
  }
}
