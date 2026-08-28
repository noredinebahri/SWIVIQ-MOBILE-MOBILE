import 'dart:math';

/// Jeu « Défi Oxygène » — calcul mental progressif, 100 % hors-ligne.
///
/// Conçu pour occuper l'élève DANS l'application entre deux consultations :
/// des mondes thématiques, chacun avec 6 niveaux de difficulté croissante.
/// Les questions sont générées à la volée (jamais deux parties identiques),
/// avec une difficulté qui monte à l'intérieur même d'un niveau.

enum GameOp { add, sub, mul, div, mixed, compare }

/// Un monde = un thème (addition, soustraction…) et 6 niveaux.
class GameStage {
  const GameStage({
    required this.id,
    required this.name,
    required this.emoji,
    required this.op,
    required this.color,
  });

  final int id;
  final String name;
  final String emoji;
  final GameOp op;

  /// Couleur du monde (valeur ARGB, convertie en Color à l'affichage).
  final int color;

  /// 6 niveaux par monde.
  static const levelsPerStage = 6;
}

const kGameStages = <GameStage>[
  GameStage(
    id: 1,
    name: 'Additions',
    emoji: '➕',
    op: GameOp.add,
    color: 0xFF22C55E,
  ),
  GameStage(
    id: 2,
    name: 'Soustractions',
    emoji: '➖',
    op: GameOp.sub,
    color: 0xFF3B82F6,
  ),
  GameStage(
    id: 3,
    name: 'Multiplications',
    emoji: '✖️',
    op: GameOp.mul,
    color: 0xFFF97316,
  ),
  GameStage(
    id: 4,
    name: 'Divisions',
    emoji: '➗',
    op: GameOp.div,
    color: 0xFFA855F7,
  ),
  GameStage(
    id: 5,
    name: 'Comparaisons',
    emoji: '⚖️',
    op: GameOp.compare,
    color: 0xFF06B6D4,
  ),
  GameStage(
    id: 6,
    name: 'Défi mixte',
    emoji: '🔥',
    op: GameOp.mixed,
    color: 0xFFEF4444,
  ),
];

/// Une question : énoncé, bonne réponse et propositions.
class GameQuestion {
  GameQuestion({
    required this.prompt,
    required this.answer,
    required this.choices,
  });

  final String prompt;
  final String answer;
  final List<String> choices;
}

/// Générateur : la difficulté dépend du monde, du niveau (1-6) et de la
/// position de la question dans la manche (fin de manche = plus dur).
class GameGenerator {
  GameGenerator(this.stage, this.level, {int? seed})
      : _rnd = Random(seed ?? DateTime.now().microsecondsSinceEpoch);

  final GameStage stage;
  final int level;
  final Random _rnd;

  /// Nombre de questions d'une manche.
  static const questionsPerRound = 10;

  /// Secondes accordées par question (plus court quand le niveau monte).
  int secondsFor(int level) => switch (level) {
        1 => 20,
        2 => 18,
        3 => 15,
        4 => 13,
        5 => 11,
        _ => 9,
      };

  /// Amplitude des nombres : croît avec le niveau et l'avancée dans la manche.
  int _bound(int index) {
    final base = switch (stage.op) {
      GameOp.add => 10 * level,
      GameOp.sub => 10 * level,
      GameOp.mul => 3 + 2 * level,
      GameOp.div => 3 + 2 * level,
      GameOp.compare => 10 * level,
      GameOp.mixed => 6 + 3 * level,
    };
    // +50 % sur les dernières questions : la manche finit toujours plus dur.
    final ramp = 1 + (index / questionsPerRound) * 0.5;
    return max(3, (base * ramp).round());
  }

  GameQuestion next(int index) {
    final op = stage.op == GameOp.mixed
        ? [GameOp.add, GameOp.sub, GameOp.mul, GameOp.div][_rnd.nextInt(4)]
        : stage.op;
    final bound = _bound(index);

    switch (op) {
      case GameOp.add:
        final a = 1 + _rnd.nextInt(bound);
        final b = 1 + _rnd.nextInt(bound);
        return _numeric('$a + $b', a + b);

      case GameOp.sub:
        final a = 1 + _rnd.nextInt(bound);
        final b = 1 + _rnd.nextInt(bound);
        // Résultat positif : plus lisible pour les plus jeunes.
        final big = max(a, b), small = min(a, b);
        return _numeric('$big − $small', big - small);

      case GameOp.mul:
        final a = 2 + _rnd.nextInt(bound);
        final b = 2 + _rnd.nextInt(bound);
        return _numeric('$a × $b', a * b);

      case GameOp.div:
        // Division toujours juste : on part du résultat.
        final b = 2 + _rnd.nextInt(max(2, bound ~/ 2));
        final result = 2 + _rnd.nextInt(max(2, bound));
        return _numeric('${b * result} ÷ $b', result);

      case GameOp.compare:
        final a = 1 + _rnd.nextInt(bound);
        final b = 1 + _rnd.nextInt(bound);
        final left = _rnd.nextBool() ? '$a + ${1 + _rnd.nextInt(bound)}' : '$a';
        final right = _rnd.nextBool() ? '$b + ${1 + _rnd.nextInt(bound)}' : '$b';
        final lv = _eval(left), rv = _eval(right);
        final answer = lv > rv ? '>' : (lv < rv ? '<' : '=');
        return GameQuestion(
          prompt: '$left  ?  $right',
          answer: answer,
          choices: ['<', '=', '>'],
        );

      case GameOp.mixed:
        return next(index); // déjà résolu plus haut
    }
  }

  int _eval(String expr) {
    if (!expr.contains('+')) return int.parse(expr.trim());
    final parts = expr.split('+').map((e) => int.parse(e.trim()));
    return parts.reduce((a, b) => a + b);
  }

  /// Question à réponse numérique + 3 leurres crédibles (proches du résultat,
  /// jamais négatifs, jamais en double).
  GameQuestion _numeric(String prompt, int answer) {
    final choices = <int>{answer};
    var spread = max(2, (answer * 0.2).round());
    while (choices.length < 4) {
      final delta = 1 + _rnd.nextInt(spread + 2);
      final candidate = _rnd.nextBool() ? answer + delta : answer - delta;
      if (candidate >= 0 && candidate != answer) choices.add(candidate);
      spread++; // évite une boucle infinie sur les petits nombres
    }
    final list = choices.map((e) => e.toString()).toList()..shuffle(_rnd);
    return GameQuestion(
      prompt: prompt,
      answer: answer.toString(),
      choices: list,
    );
  }
}

/// Résultat d'une manche : étoiles selon le nombre de bonnes réponses.
int starsFor(int correct) {
  if (correct >= 10) return 3;
  if (correct >= 8) return 2;
  if (correct >= 6) return 1;
  return 0; // niveau non réussi
}
