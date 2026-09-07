import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'culture_screens.dart';
import 'duel_screen.dart';
import 'game_arena.dart';
import 'game_map_screen.dart';
import 'game_progress.dart';
import 'leaderboard.dart';

/// Menu des jeux de l'espace élève.
///
/// La liste vient du serveur : la direction choisit quels jeux chaque niveau
/// supérieur peut voir, et le serveur impose une attente croissante entre
/// deux parties (2, 4, 6 min…). Hors-ligne, on montre tous les jeux : ils se
/// jouent sans réseau, seul le classement demande une connexion.
class GameHubScreen extends StatefulWidget {
  const GameHubScreen({super.key});

  @override
  State<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends State<GameHubScreen> {
  ArenaConfig? _config;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await GameArena.config();
      if (!mounted) return;
      setState(() {
        _config = c;
        _offline = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _offline = true);
    }
    // Progression sauvegardée sur le serveur (mondes, étoiles) : après une
    // réinstallation ou sur un autre téléphone, l'élève retrouve tout.
    final remote = await GameArena.pullProgress();
    if (remote['math'] != null) await GameProgress.merge(remote['math']!);
    if (remote['culture'] != null) await CultureProgress.merge(remote['culture']!);
    // Et l'inverse : ce que le téléphone a de plus part au serveur.
    await GameArena.pushProgress('math', await GameProgress.snapshot());
    await GameArena.pushProgress('culture', await CultureProgress.snapshot());
  }

  bool _allowed(String id) => _config == null ? true : _config!.allows(id);

  @override
  Widget build(BuildContext context) {
    final cd = _config?.cooldown;
    final prize = _config?.prize ?? 50;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Choisis ton défi',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            _offline
                ? 'Hors connexion : tu peux jouer, mais le classement attendra le réseau.'
                : 'Chaque mois, le 1ᵉʳ de chaque jeu gagne $prize DH. Joue, progresse, grimpe !',
            style: const TextStyle(color: AppColors.secondary400),
          ),
          const SizedBox(height: 14),
          if (cd != null && cd.active) _cooldownBanner(cd),
          if (_allowed('math'))
            _gameCard(
              context,
              emoji: '🎮',
              title: 'Défi Oxygène',
              subtitle: 'Calcul mental — 6 mondes, 36 niveaux',
              detail: 'Additions, soustractions, multiplications, divisions, '
                  'comparaisons et défi mixte, du plus facile au plus rapide.',
              colors: const [AppColors.primary600, AppColors.primary400],
              gameId: 'math',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Défi Oxygène')),
                  body: const GameMapScreen(),
                ),
              )),
            ),
          if (_allowed('culture')) ...[
            const SizedBox(height: 14),
            _gameCard(
              context,
              emoji: '📖',
              title: 'Défi Lecture',
              subtitle: 'Romans de 1ʳᵉ Bac — 4 œuvres, 3 niveaux chacune',
              detail: 'Le Dernier Jour d’un condamné, Antigone, La Boîte à '
                  'merveilles, Il était une fois un vieux couple heureux.',
              colors: const [Color(0xFF7C3AED), Color(0xFFA855F7)],
              gameId: 'culture',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Défi Lecture')),
                  body: const CultureMapScreen(),
                ),
              )),
            ),
          ],
          if (_allowed('math')) ...[
            const SizedBox(height: 14),
            _gameCard(
              context,
              emoji: '⚔️',
              title: 'Duel Fantôme',
              subtitle: 'Cours contre la partie enregistrée d\'un camarade',
              detail: 'Mêmes questions, son vrai rythme de réponse — il n\'a pas '
                  'besoin d\'être connecté. Ta meilleure partie devient à son '
                  'tour l\'adversaire des autres élèves.',
              colors: const [Color(0xFF0F172A), Color(0xFF334155)],
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const DuelLobbyScreen(),
              )),
            ),
          ],
          if (_config != null && !_allowed('math') && !_allowed('culture'))
            Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Column(
                children: const [
                  Text('🔒', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 8),
                  Text('Aucun jeu n\'est ouvert à ton niveau pour le moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.secondary400)),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _cooldownBanner(ArenaCooldown cd) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Row(
        children: [
          const Text('⏳', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Prochaine partie dans', style: TextStyle(fontSize: 12, color: Color(0xFF9A3412))),
                CooldownCountdown(seconds: cd.waitSeconds, compact: true, onDone: _load),
                Text('${cd.attemptsToday} partie(s) aujourd\'hui · +${cd.baseMinutes} min à chaque fois',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9A3412))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gameCard(
    BuildContext context, {
    required String emoji,
    required String title,
    required String subtitle,
    required String detail,
    required List<Color> colors,
    required VoidCallback onTap,
    String? gameId,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.32), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                      Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 34),
              ],
            ),
            const SizedBox(height: 12),
            Text(detail, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5, height: 1.35)),
            if (gameId != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.white.withValues(alpha: 0.18)),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LeaderboardScreen(game: gameId, title: title, color: colors.first),
                  )),
                  icon: const Text('🏆'),
                  label: const Text('Arène du mois'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
