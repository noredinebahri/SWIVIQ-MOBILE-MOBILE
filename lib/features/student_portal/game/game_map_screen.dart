import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'game_models.dart';
import 'game_play_screen.dart';
import 'game_progress.dart';
import 'leaderboard.dart';

/// Carte du jeu : les mondes et leurs niveaux, débloqués au fur et à mesure.
class GameMapScreen extends StatefulWidget {
  const GameMapScreen({super.key});

  @override
  State<GameMapScreen> createState() => _GameMapScreenState();
}

class _GameMapScreenState extends State<GameMapScreen> {
  Map<String, int> _stars = {};

  void _openLeaderboard() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const LeaderboardScreen(
        game: 'math',
        title: 'Défi Oxygène',
        color: AppColors.primary600,
      ),
    ));
  }

  int _total = 0;
  int _best = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stars = await GameProgress.all();
    final total = await GameProgress.totalStars();
    final best = await GameProgress.bestScore();
    if (!mounted) return;
    setState(() {
      _stars = stars;
      _total = total;
      _best = best;
      _loading = false;
    });
  }

  Future<void> _play(GameStage stage, int level) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GamePlayScreen(stage: stage, level: level),
      ),
    );
    _load(); // la progression a pu changer
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    const maxStars = 3 * GameStage.levelsPerStage * 6;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Bandeau de progression.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary600, AppColors.primary400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🎮 Défi Oxygène',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Calcul mental — 6 mondes, 36 niveaux',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFFACC15), size: 22),
                  const SizedBox(width: 6),
                  Text(
                    '$_total / $maxStars étoiles',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🏆',
                              style: TextStyle(fontSize: 15)),
                          const SizedBox(width: 6),
                          Text(
                            'Record $_best',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
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
                  value: maxStars == 0 ? 0 : _total / maxStars,
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

        for (var i = 0; i < kGameStages.length; i++) ...[
          _stageCard(kGameStages[i], i),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _stageCard(GameStage stage, int index) {
    final color = Color(stage.color);
    final stageStars = List.generate(
      GameStage.levelsPerStage,
      (i) => _stars['${stage.id}-${i + 1}'] ?? 0,
    ).fold<int>(0, (sum, v) => sum + v);

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
            children: [
              Text(stage.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  stage.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: color,
                  ),
                ),
              ),
              const Icon(Icons.star_rounded,
                  size: 18, color: Color(0xFFFACC15)),
              const SizedBox(width: 4),
              Text(
                '$stageStars/${GameStage.levelsPerStage * 3}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var level = 1;
                  level <= GameStage.levelsPerStage;
                  level++)
                _levelTile(stage, index, level, color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _levelTile(GameStage stage, int index, int level, Color color) {
    final stars = _stars['${stage.id}-$level'] ?? 0;
    final unlocked = GameProgress.isUnlocked(
      stars: _stars,
      stageIndex: index,
      level: level,
      levelsPerStage: GameStage.levelsPerStage,
    );

    return InkWell(
      onTap: unlocked ? () => _play(stage, level) : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 74,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: unlocked ? Colors.white : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unlocked
                ? color.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Column(
          children: [
            if (!unlocked)
              const Icon(Icons.lock_rounded,
                  size: 20, color: AppColors.secondary300)
            else
              Text(
                '$level',
                style: TextStyle(
                  fontSize: 18,
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
                    s <= stars ? Icons.star_rounded : Icons.star_border_rounded,
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
