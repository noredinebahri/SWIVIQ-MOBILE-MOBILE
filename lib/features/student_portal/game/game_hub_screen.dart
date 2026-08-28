import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'culture_screens.dart';
import 'duel_screen.dart';
import 'game_map_screen.dart';

/// Menu des jeux de l'espace élève : calcul mental et culture littéraire.
/// Les deux fonctionnent entièrement hors connexion.
class GameHubScreen extends StatelessWidget {
  const GameHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Choisis ton défi',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Deux jeux, jouables sans connexion internet.',
          style: TextStyle(color: AppColors.secondary400),
        ),
        const SizedBox(height: 18),
        _gameCard(
          context,
          emoji: '🎮',
          title: 'Défi Oxygène',
          subtitle: 'Calcul mental — 6 mondes, 36 niveaux',
          detail: 'Additions, soustractions, multiplications, divisions, '
              'comparaisons et défi mixte, du plus facile au plus rapide.',
          colors: const [AppColors.primary600, AppColors.primary400],
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Défi Oxygène')),
              body: const GameMapScreen(),
            ),
          )),
        ),
        const SizedBox(height: 14),
        _gameCard(
          context,
          emoji: '📖',
          title: 'Défi Lecture',
          subtitle: 'Romans de 1ʳᵉ Bac — 4 œuvres, 3 niveaux chacune',
          detail: 'Le Dernier Jour d’un condamné, Antigone, La Boîte à '
              'merveilles, Il était une fois un vieux couple heureux.',
          colors: const [Color(0xFF7C3AED), Color(0xFFA855F7)],
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Défi Lecture')),
              body: const CultureMapScreen(),
            ),
          )),
        ),
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
        const SizedBox(height: 24),
      ],
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
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
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.play_circle_fill_rounded,
                    color: Colors.white, size: 34),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              detail,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
