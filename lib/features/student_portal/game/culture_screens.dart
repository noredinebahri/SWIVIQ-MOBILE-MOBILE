import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme.dart';
import 'culture_models.dart';
import 'game_arena.dart';
import 'leaderboard.dart';

/// Progression du jeu de culture (clés distinctes du jeu de calcul).
class CultureProgress {
  static const _key = 'ox_culture_stars';

  static Future<Map<String, int>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final map = <String, int>{};
    for (final entry in raw) {
      final parts = entry.split('=');
      if (parts.length == 2) map[parts[0]] = int.tryParse(parts[1]) ?? 0;
    }
    return map;
  }

  static const _scoreKey = 'ox_culture_score';

  static Future<void> record(int novelId, int level, int stars) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await all();
    final k = '$novelId-$level';
    if (stars > (map[k] ?? 0)) {
      map[k] = stars;
      await prefs.setStringList(
          _key, map.entries.map((e) => '${e.key}=${e.value}').toList());
    }
  }

  /// Score cumulé du joueur (base du classement du centre).
  static Future<int> bestScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scoreKey) ?? 0;
  }

  static Future<void> addScore(int points) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_scoreKey, (prefs.getInt(_scoreKey) ?? 0) + points);
  }

  static Future<int> totalStars() async {
    final map = await all();
    return map.values.fold<int>(0, (sum, v) => sum + v);
  }

  /// Le niveau 1 d'une œuvre est toujours ouvert : l'élève doit pouvoir
  /// réviser le roman qu'il étudie en ce moment, sans devoir finir les autres.
  static bool isUnlocked(Map<String, int> stars, int novelId, int level) =>
      level == 1 || (stars['$novelId-${level - 1}'] ?? 0) > 0;
}

/// Carte du jeu : une œuvre par bloc, ses niveaux en dessous.
class CultureMapScreen extends StatefulWidget {
  const CultureMapScreen({super.key});

  @override
  State<CultureMapScreen> createState() => _CultureMapScreenState();
}

class _CultureMapScreenState extends State<CultureMapScreen> {
  Map<String, int> _stars = {};
  bool _loading = true;

  void _openLeaderboard() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const LeaderboardScreen(
        game: 'culture',
        title: 'Défi Lecture',
        color: Color(0xFF7C3AED),
      ),
    ));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stars = await CultureProgress.all();
    if (!mounted) return;
    setState(() {
      _stars = stars;
      _loading = false;
    });
  }

  Future<void> _play(Novel novel, int levelIndex) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CulturePlayScreen(novel: novel, levelIndex: levelIndex),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final total = _stars.values.fold<int>(0, (s, v) => s + v);
    final maxStars = kNovels.length * 3 * 3;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📖 Défi Lecture',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                'Les œuvres au programme de 1ʳᵉ Bac',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFFACC15), size: 22),
                  const SizedBox(width: 6),
                  Text('$total / $maxStars étoiles',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  // Accès direct au classement du centre.
                  InkWell(
                    onTap: _openLeaderboard,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🏆', style: TextStyle(fontSize: 15)),
                          SizedBox(width: 6),
                          Text('Classement',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: maxStars == 0 ? 0 : total / maxStars,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor:
                      const AlwaysStoppedAnimation(Color(0xFFFACC15)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (final novel in kNovels) ...[
          _novelCard(novel),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _novelCard(Novel novel) {
    final color = Color(novel.color);
    final earned = List.generate(novel.levels.length,
            (i) => _stars['${novel.id}-${i + 1}'] ?? 0)
        .fold<int>(0, (s, v) => s + v);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(novel.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(novel.title,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: color)),
                    Text(novel.author,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.secondary400)),
                  ],
                ),
              ),
              const Icon(Icons.star_rounded,
                  size: 18, color: Color(0xFFFACC15)),
              const SizedBox(width: 4),
              Text('$earned/${novel.levels.length * 3}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < novel.levels.length; i++) ...[
                Expanded(child: _levelTile(novel, i, color)),
                if (i < novel.levels.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _levelTile(Novel novel, int index, Color color) {
    final level = index + 1;
    final stars = _stars['${novel.id}-$level'] ?? 0;
    final unlocked = CultureProgress.isUnlocked(_stars, novel.id, level);

    return InkWell(
      onTap: unlocked ? () => _play(novel, index) : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: unlocked ? Colors.white : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unlocked ? color.withValues(alpha: 0.5) : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Column(
          children: [
            if (!unlocked)
              const Icon(Icons.lock_rounded,
                  size: 18, color: AppColors.secondary300)
            else
              Text(
                novel.levels[index].name,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var s = 1; s <= 3; s++)
                  Icon(
                    s <= stars
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 13,
                    color: s <= stars
                        ? const Color(0xFFFACC15)
                        : AppColors.secondary300,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Manche de questions sur une œuvre.
class CulturePlayScreen extends StatefulWidget {
  const CulturePlayScreen({
    super.key,
    required this.novel,
    required this.levelIndex,
  });

  final Novel novel;
  final int levelIndex;

  @override
  State<CulturePlayScreen> createState() => _CulturePlayScreenState();
}

class _CulturePlayScreenState extends State<CulturePlayScreen> {
  late List<CultureQuestion> _questions;
  late List<String> _choices;
  int _index = 0;
  int _correct = 0;
  String? _picked;
  bool _finished = false;

  /// Manche ouverte par le serveur (null hors-ligne : la manche ne compte pas).
  ArenaAttempt? _attempt;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    final pool = [...widget.novel.levels[widget.levelIndex].questions]
      ..shuffle(rnd);
    _questions = pool.take(kCultureQuestionsPerRound).toList();
    _shuffleChoices();
    _open();
  }

  /// Ouverture de la manche côté serveur : attente croissante ou jeu fermé
  /// → explication puis fermeture de l'écran ; hors-ligne → on joue sans
  /// classement.
  Future<void> _open() async {
    try {
      final a = await GameArena.start('culture');
      if (mounted) setState(() => _attempt = a);
    } on ArenaBlocked catch (b) {
      if (!mounted) return;
      if (b.code == 'OFFLINE') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(b.message)));
        return;
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
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _shuffleChoices() {
    _choices = [..._questions[_index].choices]..shuffle(Random());
  }

  CultureQuestion get _q => _questions[_index];

  void _answer(String choice) {
    if (_picked != null) return;
    final ok = choice == _q.answer;
    setState(() {
      _picked = choice;
      if (ok) _correct++;
    });
    HapticFeedback.lightImpact();
  }

  void _next() {
    if (_index + 1 >= _questions.length) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _picked = null;
      _shuffleChoices();
    });
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    // 3 étoiles = sans faute, 2 = 75 %, 1 = 50 %.
    final total = _questions.length;
    final ratio = _correct / total;
    final stars = _correct == total
        ? 3
        : ratio >= 0.75
            ? 2
            : ratio >= 0.5
                ? 1
                : 0;
    await CultureProgress.record(
        widget.novel.id, widget.levelIndex + 1, stars);
    // Points de la manche : bonnes réponses + bonus selon le niveau (les
    // niveaux difficiles rapportent davantage).
    final points = _correct * 100 + stars * 50 * (widget.levelIndex + 1);
    await CultureProgress.addScore(points);
    // Arène du mois : seule une manche ouverte par le serveur compte, avec
    // les points de LA manche (durée et plafond vérifiés côté serveur).
    LeaderboardMe? me;
    if (_attempt != null) {
      final r = await GameArena.finish(_attempt!, won: stars > 0, score: points, stars: stars);
      me = r?.me;
      _attempt = null;
      if (r != null && !r.accepted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Manche non comptée au classement (partie trop rapide ou invalide).'),
        ));
      }
    }
    if (!mounted) return;

    final color = Color(widget.novel.color);
    final hasNext = widget.levelIndex + 1 < widget.novel.levels.length;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(stars > 0 ? '📚' : '💪',
                style: const TextStyle(fontSize: 46)),
            const SizedBox(height: 8),
            Text(
              stars > 0 ? 'Bravo !' : 'À revoir',
              style: Theme.of(dialogContext)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var s = 1; s <= 3; s++)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: s <= stars ? 1 : 0.35),
                    duration: Duration(milliseconds: 300 + s * 180),
                    curve: Curves.elasticOut,
                    builder: (context, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: Icon(Icons.star_rounded,
                        size: 44,
                        color: s <= stars
                            ? const Color(0xFFFACC15)
                            : AppColors.secondary200),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('$_correct / $total bonnes réponses',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('+$points points',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color)),
            if (me != null) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () => Navigator.of(dialogContext).pop('board'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        me.rank == 1
                            ? '1ᵉʳ du centre sur ${me.total} joueurs !'
                            : '${me.rank}ᵉ sur ${me.total} joueurs',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: color),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right_rounded,
                          color: color, size: 18),
                    ],
                  ),
                ),
              ),
            ],
            if (stars == 0) ...[
              const SizedBox(height: 8),
              const Text(
                'Il faut la moitié des bonnes réponses pour débloquer le niveau suivant.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5, color: AppColors.secondary400),
              ),
            ],
          ],
        ),
        actions: [
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('board'),
                child: const Text('🏆 Classement'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop('retry'),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Rejouer'),
              ),
              const SizedBox(width: 6),
              // « Suivant » seulement si le niveau est réussi et qu'il en
              // reste un dans cette œuvre.
              if (stars > 0 && hasNext)
                FilledButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop('next'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Suivant'),
                  style: FilledButton.styleFrom(backgroundColor: color),
                )
              else
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop('quit'),
                  style: FilledButton.styleFrom(backgroundColor: color),
                  child: const Text('Terminer'),
                ),
            ],
          ),
        ],
      ),
    );

    if (!mounted) return;
    switch (action) {
      case 'retry':
        _restart();
      case 'next':
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => CulturePlayScreen(
            novel: widget.novel,
            levelIndex: widget.levelIndex + 1,
          ),
        ));
      case 'board':
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LeaderboardScreen(
            game: 'culture',
            title: 'Défi Lecture',
            color: Color(widget.novel.color),
          ),
        ));
        if (mounted) Navigator.of(context).pop();
      default:
        Navigator.of(context).pop();
    }
  }

  void _restart() {
    setState(() {
      final pool = [...widget.novel.levels[widget.levelIndex].questions]
        ..shuffle(Random());
      _questions = pool.take(kCultureQuestionsPerRound).toList();
      _index = 0;
      _correct = 0;
      _picked = null;
      _finished = false;
      _shuffleChoices();
    });
    // Rejouer = nouvelle manche : le serveur décide à nouveau (attente).
    _open();
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.novel.color);
    final answered = _picked != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.novel.emoji} ${widget.novel.levels[widget.levelIndex].name}',
        ),
        backgroundColor: color.withValues(alpha: 0.12),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (_index + 1) / _questions.length,
                      minHeight: 6,
                      backgroundColor: color.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${_index + 1} / ${_questions.length}',
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.secondary400),
                      ),
                      Text(
                        '$_correct bonne(s)',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: color),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _q.prompt,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final choice in _choices) ...[
                    _choiceTile(choice, color),
                    const SizedBox(height: 10),
                  ],
                  // Éclairage pédagogique après la réponse.
                  if (answered && _q.hint != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary500.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline_rounded,
                              size: 18, color: AppColors.primary600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _q.hint!,
                              style: const TextStyle(
                                  fontSize: 13, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (answered)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      minimumSize: const Size(0, 52),
                    ),
                    child: Text(_index + 1 >= _questions.length
                        ? 'Voir le résultat'
                        : 'Question suivante'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _choiceTile(String choice, Color color) {
    final answered = _picked != null;
    final isAnswer = choice == _q.answer;
    final isPicked = choice == _picked;

    Color bg = Colors.white;
    Color border = color.withValues(alpha: 0.35);
    Color fg = AppColors.secondary600;
    IconData? icon;

    if (answered) {
      if (isAnswer) {
        bg = AppColors.success100;
        border = AppColors.success500;
        fg = AppColors.success600;
        icon = Icons.check_circle_rounded;
      } else if (isPicked) {
        bg = AppColors.danger100;
        border = AppColors.danger500;
        fg = AppColors.danger600;
        icon = Icons.cancel_rounded;
      } else {
        fg = AppColors.secondary300;
        border = Colors.transparent;
      }
    }

    return InkWell(
      onTap: answered ? null : () => _answer(choice),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                choice,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  height: 1.3,
                ),
              ),
            ),
            if (icon != null) Icon(icon, color: fg, size: 20),
          ],
        ),
      ),
    );
  }
}
