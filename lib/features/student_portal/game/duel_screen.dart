import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme.dart';
import 'duel_repo.dart';
import 'game_models.dart';

/// ─────────────────────────── DUEL FANTÔME ───────────────────────────
///
/// Le joueur affronte le REJEU d'une partie réelle : celle d'un camarade,
/// ou la sienne. Les deux courent sur la même série de questions (générée
/// depuis la même graine) ; le fantôme répond aux instants exacts où son
/// auteur avait répondu. On voit donc l'adversaire progresser en direct,
/// alors qu'il a joué hier.
class DuelScreen extends ConsumerStatefulWidget {
  const DuelScreen({super.key, required this.ghost, required this.isSelf});

  final Ghost ghost;

  /// Duel contre son propre record (le fantôme s'appelle « Moi (record) »).
  final bool isSelf;

  @override
  ConsumerState<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends ConsumerState<DuelScreen> {
  static const _questionCount = GameGenerator.questionsPerRound;

  late final GameStage _stage = kGameStages.firstWhere(
    (s) => s.id == widget.ghost.stageId,
    orElse: () => kGameStages.first,
  );

  /// MÊME graine que le fantôme → exactement les mêmes questions.
  late final GameGenerator _gen =
      GameGenerator(_stage, widget.ghost.level, seed: widget.ghost.seed);

  final List<GameQuestion> _questions = [];
  final List<GhostStep> _myRun = [];

  int _myIndex = 0;
  int _myCorrect = 0;
  int _myScore = 0;
  int _ghostIndex = 0;
  int _ghostCorrect = 0;

  String? _picked;
  bool _over = false;

  final Stopwatch _questionClock = Stopwatch();
  final Stopwatch _totalClock = Stopwatch();
  Timer? _ghostTimer;

  /// Message d'ambiance ("Tu mènes !", "Il te double !").
  String _commentary = 'À vos marques…';

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _questionCount; i++) {
      _questions.add(_gen.next(i));
    }
    _start();
  }

  @override
  void dispose() {
    _ghostTimer?.cancel();
    super.dispose();
  }

  void _start() {
    _totalClock.start();
    _questionClock.start();
    _scheduleGhost();
    setState(() => _commentary = 'C\'est parti !');
  }

  /// Le fantôme « répond » au bout du temps qu'il avait réellement mis.
  void _scheduleGhost() {
    if (_ghostIndex >= widget.ghost.run.length ||
        _ghostIndex >= _questionCount) {
      return;
    }
    final step = widget.ghost.run[_ghostIndex];
    _ghostTimer?.cancel();
    _ghostTimer = Timer(Duration(milliseconds: max(300, step.ms)), () {
      if (!mounted || _over) return;
      setState(() {
        if (step.ok) _ghostCorrect++;
        _ghostIndex++;
        _updateCommentary();
      });
      if (_ghostIndex >= _questionCount) {
        _maybeFinish();
      } else {
        _scheduleGhost();
      }
    });
  }

  void _updateCommentary() {
    final diff = _myIndex - _ghostIndex;
    _commentary = switch (diff) {
      >= 3 => '🚀 Tu le distances !',
      2 => '💨 Tu mènes de 2 questions',
      1 => '👍 Tu es devant',
      0 => '⚔️ Au coude à coude',
      -1 => '⚠️ Il te dépasse',
      -2 => '😰 Il te mène de 2',
      _ => '🔥 Accélère, il s\'envole !',
    };
  }

  void _answer(String choice) {
    if (_picked != null || _over) return;
    final q = _questions[_myIndex];
    final ok = choice == q.answer;
    final ms = _questionClock.elapsedMilliseconds;

    setState(() {
      _picked = choice;
      _myRun.add(GhostStep(ms: ms, ok: ok));
      if (ok) {
        _myCorrect++;
        // Même barème que le jeu classique : rapidité récompensée.
        final bonus = max(0, 10 - (ms ~/ 1000)) * 10;
        _myScore += 100 + bonus;
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    });

    Future.delayed(const Duration(milliseconds: 550), () {
      if (!mounted || _over) return;
      setState(() {
        _myIndex++;
        _picked = null;
        _updateCommentary();
      });
      _questionClock
        ..reset()
        ..start();
      _maybeFinish();
    });
  }

  void _maybeFinish() {
    // La course s'arrête quand le joueur a terminé : le fantôme peut avoir
    // fini avant (il aura simplement « gagné » en arrivant le premier).
    if (_myIndex >= _questionCount && !_over) {
      _finish();
    }
  }

  Future<void> _finish() async {
    _over = true;
    _ghostTimer?.cancel();
    _totalClock.stop();
    _questionClock.stop();

    final totalMs = _totalClock.elapsedMilliseconds;
    // Victoire : plus de bonnes réponses ; à égalité, le plus rapide.
    final won = _myCorrect > _ghostCorrect ||
        (_myCorrect == _ghostCorrect && totalMs < widget.ghost.totalMs);

    // Ma partie devient mon nouveau fantôme si elle est meilleure.
    final prefs = await SharedPreferences.getInstance();
    final myBest = prefs.getInt('ox_duel_best') ?? 0;
    if (_myScore > myBest) {
      await prefs.setInt('ox_duel_best', _myScore);
      await DuelRepo.publish(
        stageId: _stage.id,
        level: widget.ghost.level,
        seed: widget.ghost.seed,
        run: _myRun,
        score: _myScore,
        correct: _myCorrect,
        totalMs: totalMs,
      );
    }

    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(won ? '🏅' : '💪', style: const TextStyle(fontSize: 46)),
            const SizedBox(height: 8),
            Text(
              won ? 'Duel remporté !' : 'Duel perdu',
              style: Theme.of(dialogContext)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            _scoreLine('Toi', _myCorrect, totalMs, won),
            const SizedBox(height: 6),
            _scoreLine(widget.ghost.name, _ghostCorrect,
                widget.ghost.totalMs, !won),
            const SizedBox(height: 12),
            Text('Score : $_myScore',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('quit'),
                child: const Text('Quitter'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop('retry'),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Revanche'),
              ),
            ],
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == 'retry') {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) =>
            DuelScreen(ghost: widget.ghost, isSelf: widget.isSelf),
      ));
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _scoreLine(String name, int correct, int ms, bool winner) {
    return Row(
      children: [
        Text(winner ? '🏆' : '  ', style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(name,
              style: TextStyle(
                  fontWeight: winner ? FontWeight.w800 : FontWeight.w500)),
        ),
        Text('$correct/$_questionCount  ·  ${(ms / 1000).toStringAsFixed(1)}s',
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(_stage.color);
    final done = _myIndex >= _questionCount;
    final q = done ? _questions.last : _questions[_myIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('⚔️ Duel · ${widget.ghost.name}'),
        backgroundColor: color.withValues(alpha: 0.12),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // La piste de course : deux coureurs qui avancent question
            // après question.
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _runner(
                    label: 'Toi',
                    emoji: '🏃',
                    progress: _myIndex / _questionCount,
                    correct: _myCorrect,
                    color: color,
                    bold: true,
                  ),
                  const SizedBox(height: 10),
                  _runner(
                    label: widget.ghost.name,
                    emoji: widget.isSelf ? '🕐' : '👻',
                    progress: _ghostIndex / _questionCount,
                    correct: _ghostCorrect,
                    color: AppColors.secondary400,
                    bold: false,
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _commentary,
                      key: ValueKey(_commentary),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    q.prompt,
                    key: ValueKey(_myIndex),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final choice in q.choices)
                    _choice(choice, q.answer, color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _runner({
    required String label,
    required String emoji,
    required double progress,
    required int correct,
    required Color color,
    required bool bold,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color,
              fontSize: 12.5,
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth - 26;
              return SizedBox(
                height: 26,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 11,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                      left: (w * progress.clamp(0, 1)),
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 20)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 6),
        Text('$correct',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: color, fontSize: 13)),
      ],
    );
  }

  Widget _choice(String choice, String answer, Color color) {
    final answered = _picked != null;
    final isAnswer = choice == answer;
    final isPicked = choice == _picked;

    Color bg = Colors.white;
    Color fg = color;
    Color border = color.withValues(alpha: 0.4);
    if (answered) {
      if (isAnswer) {
        bg = AppColors.success100;
        fg = AppColors.success600;
        border = AppColors.success500;
      } else if (isPicked) {
        bg = AppColors.danger100;
        fg = AppColors.danger600;
        border = AppColors.danger500;
      } else {
        fg = AppColors.secondary300;
        border = Colors.transparent;
      }
    }

    return SizedBox(
      width: 150,
      child: InkWell(
        onTap: answered ? null : () => _answer(choice),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 1.6),
          ),
          child: Center(
            child: Text(
              choice,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Choix de l'adversaire : camarades ayant publié une partie, ou un
/// fantôme d'entraînement quand personne n'a encore joué.
class DuelLobbyScreen extends ConsumerWidget {
  const DuelLobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rivals = ref.watch(rivalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('⚔️ Duel Fantôme')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(rivalsProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF334155)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚔️ Duel Fantôme',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'Affronte la partie enregistrée d’un camarade : mêmes '
                    'questions, son vrai rythme de réponse. Il n’a pas '
                    'besoin d’être connecté — tu cours contre son fantôme.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            rivals.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _trainingCard(context,
                  message:
                      'Adversaires indisponibles (hors connexion). Tu peux '
                      'quand même défier un fantôme d’entraînement.'),
              data: (list) {
                if (list.isEmpty) {
                  return _trainingCard(context,
                      message:
                          'Aucun camarade n’a encore publié de partie. '
                          'Défie le fantôme d’entraînement : ta partie '
                          'deviendra l’adversaire des autres !');
                }
                return Column(
                  children: [
                    for (final g in list) ...[
                      _rivalCard(context, g),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _rivalCard(BuildContext context, Ghost g) {
    final stage = kGameStages.firstWhere((s) => s.id == g.stageId,
        orElse: () => kGameStages.first);
    final color = Color(stage.color);
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DuelScreen(ghost: g, isSelf: false),
      )),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Text('👻', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(
                    '${stage.emoji} ${stage.name} · niveau ${g.level} · '
                    '${g.correct}/10 en ${(g.totalMs / 1000).toStringAsFixed(1)}s',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.secondary400),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${g.score}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: color)),
                const Text('Défier',
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.secondary400)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Fantôme généré : permet de jouer même sans adversaire réel.
  Widget _trainingCard(BuildContext context, {required String message}) {
    final rnd = Random();
    final seed = rnd.nextInt(1 << 31);
    // Un adversaire régulier à ~4 s par question : rythme d'un bon élève.
    final ghost = Ghost(
      studentId: 0,
      name: 'Fantôme d’entraînement',
      stageId: 1,
      level: 2,
      seed: seed,
      score: 900,
      correct: 8,
      totalMs: 40000,
      run: List.generate(
        GameGenerator.questionsPerRound,
        (i) => GhostStep(ms: 3200 + rnd.nextInt(1800), ok: i % 5 != 4),
      ),
    );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warning100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(message,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFFB45309), height: 1.35)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DuelScreen(ghost: ghost, isSelf: false),
            )),
            icon: const Text('👻', style: TextStyle(fontSize: 16)),
            label: const Text('Défier le fantôme d’entraînement'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          ),
        ),
      ],
    );
  }
}
