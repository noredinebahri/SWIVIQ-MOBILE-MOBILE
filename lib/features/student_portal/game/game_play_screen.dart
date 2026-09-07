import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import 'game_arena.dart';
import 'game_models.dart';
import 'game_progress.dart';
import 'leaderboard.dart';

/// Une manche : 10 questions, 3 vies, un chrono par question.
/// Le score récompense la vitesse et les séries de bonnes réponses.
class GamePlayScreen extends StatefulWidget {
  const GamePlayScreen({
    super.key,
    required this.stage,
    required this.level,
  });

  final GameStage stage;
  final int level;

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  late final GameGenerator _gen =
      GameGenerator(widget.stage, widget.level);
  late final int _seconds = _gen.secondsFor(widget.level);

  late GameQuestion _question;
  int _index = 0;
  int _correct = 0;
  int _lives = 3;
  int _score = 0;
  int _streak = 0;
  int _remaining = 0;
  Timer? _timer;

  /// Réponse touchée : verrouille les boutons le temps du retour visuel.
  String? _picked;
  bool _finished = false;

  /// Manche ouverte par le serveur (null hors-ligne : la manche ne compte pas).
  ArenaAttempt? _attempt;

  @override
  void initState() {
    super.initState();
    _open();
  }

  /// Demande l'ouverture d'une manche : le serveur peut refuser (attente
  /// croissante entre deux parties, jeu fermé au niveau) — on ferme alors
  /// l'écran après explication. Hors-ligne, on joue quand même.
  Future<void> _open() async {
    ArenaAttempt? attempt;
    try {
      attempt = await GameArena.start('math');
    } on ArenaBlocked catch (b) {
      if (!mounted) return;
      if (b.code != 'OFFLINE') {
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
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(b.message)));
    }
    if (!mounted) return;
    setState(() => _attempt = attempt);
    _nextQuestion();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _nextQuestion() {
    if (_index >= GameGenerator.questionsPerRound || _lives <= 0) {
      _finish();
      return;
    }
    setState(() {
      _question = _gen.next(_index);
      _picked = null;
      _remaining = _seconds;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        _answer(null); // temps écoulé = réponse manquée
      }
    });
  }

  void _answer(String? choice) {
    if (_picked != null || _finished) return;
    _timer?.cancel();
    final correct = choice != null && choice == _question.answer;

    setState(() {
      _picked = choice ?? '';
      if (correct) {
        _correct++;
        _streak++;
        // Points : base + bonus de rapidité + bonus de série.
        _score += 100 + _remaining * 10 + (_streak >= 3 ? 50 : 0);
        HapticFeedback.lightImpact();
      } else {
        _lives--;
        _streak = 0;
        HapticFeedback.mediumImpact();
      }
      _index++;
    });

    Future.delayed(const Duration(milliseconds: 750), () {
      if (mounted) _nextQuestion();
    });
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    final stars = starsFor(_correct);
    final improved = await GameProgress.record(
      stageId: widget.stage.id,
      level: widget.level,
      stars: stars,
      score: _score,
    );
    // Arène du mois : la manche n'est comptée que si le serveur l'a ouverte
    // (jeton) et la juge plausible (durée, plafond). Le score de la MANCHE
    // est envoyé, pas le cumul : le classement compare des parties.
    LeaderboardMe? me;
    if (_attempt != null) {
      final r = await GameArena.finish(_attempt!, won: stars > 0, score: _score, stars: stars);
      me = r?.me;
      _attempt = null;
      if (r != null && !r.accepted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Manche non comptée au classement (partie trop rapide ou invalide).'),
        ));
      }
    }
    // Progression (mondes, étoiles) sauvegardée sur le serveur.
    await GameArena.pushProgress('math', await GameProgress.snapshot());
    if (!mounted) return;
    await _showResult(stars, improved, me);
  }

  bool get _hasNextLevel => widget.level < GameStage.levelsPerStage;

  Future<void> _showResult(
      int stars, bool improved, LeaderboardMe? me) async {
    final color = Color(widget.stage.color);
    final passed = stars > 0;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              passed ? '🎉' : '💪',
              style: const TextStyle(fontSize: 46),
            ),
            const SizedBox(height: 8),
            Text(
              passed ? 'Niveau réussi !' : 'Presque !',
              style: Theme.of(dialogContext)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            // Étoiles animées.
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
                    child: Icon(
                      Icons.star_rounded,
                      size: 46,
                      color: s <= stars
                          ? const Color(0xFFFACC15)
                          : AppColors.secondary200,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$_correct / ${GameGenerator.questionsPerRound} bonnes réponses',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Score : $_score',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            if (improved) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '⭐ Nouveau meilleur résultat',
                  style: TextStyle(
                    color: AppColors.success600,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
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
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right_rounded, color: color, size: 18),
                    ],
                  ),
                ),
              ),
            ],
            if (!passed) ...[
              const SizedBox(height: 10),
              const Text(
                'Il faut 6 bonnes réponses pour débloquer le niveau suivant.',
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
              // « Suivant » n'a de sens que si le niveau est réussi et qu'il
              // reste un niveau dans ce monde.
              if (passed && _hasNextLevel)
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
        // Le niveau suivant s'ouvre dans la foulée : on remplace l'écran
        // pour ne pas empiler les manches dans l'historique.
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => GamePlayScreen(
            stage: widget.stage,
            level: widget.level + 1,
          ),
        ));
      case 'board':
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LeaderboardScreen(
            game: 'math',
            title: 'Défi Oxygène',
            color: Color(widget.stage.color),
          ),
        ));
        if (mounted) await _showResult(stars, improved, me);
      default:
        Navigator.of(context).pop();
    }
  }

  void _restart() {
    setState(() {
      _index = 0;
      _correct = 0;
      _lives = 3;
      _score = 0;
      _streak = 0;
      _finished = false;
    });
    // Rejouer = nouvelle manche : le serveur décide à nouveau (attente).
    _open();
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.stage.color);
    final progress = _index / GameGenerator.questionsPerRound;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.stage.emoji} ${widget.stage.name} · Niveau ${widget.level}'),
        backgroundColor: color.withValues(alpha: 0.12),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Vies, score, série.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Icon(
                      i < _lives
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: i < _lives
                          ? AppColors.danger500
                          : AppColors.secondary300,
                      size: 22,
                    ),
                  const Spacer(),
                  if (_streak >= 3) ...[
                    const Text('🔥', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Text('$_streak',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF97316))),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    '$_score pts',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            // Avancement dans la manche.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Question ${(_index + 1).clamp(1, GameGenerator.questionsPerRound)} / ${GameGenerator.questionsPerRound}',
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.secondary400),
            ),

            // Énoncé + chrono.
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Chrono circulaire : le temps devient rouge à la fin.
                    SizedBox(
                      width: 62,
                      height: 62,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: _remaining / _seconds,
                            strokeWidth: 5,
                            backgroundColor:
                                color.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation(
                              _remaining <= 3 ? AppColors.danger500 : color,
                            ),
                          ),
                          Text(
                            '$_remaining',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: _remaining <= 3
                                  ? AppColors.danger500
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        _question.prompt,
                        key: ValueKey(_index),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Réponses.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final choice in _question.choices)
                    _choiceButton(choice, color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choiceButton(String choice, Color color) {
    final answered = _picked != null;
    final isAnswer = choice == _question.answer;
    final isPicked = choice == _picked;

    // Après réponse : la bonne passe au vert, le mauvais choix au rouge.
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
          duration: const Duration(milliseconds: 200),
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
