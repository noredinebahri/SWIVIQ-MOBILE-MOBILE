library;

/// Jeu « Défi Lecture » — culture littéraire sur les romans au programme de
/// la 1ʳᵉ année baccalauréat, entièrement hors-ligne.
///
/// Un monde = une œuvre. Chaque œuvre a 3 niveaux : Facile (repères et
/// personnages), Moyen (intrigue et détails), Difficile (analyse, thèmes,
/// citations). Les questions d'un niveau sont mélangées à chaque partie.

class CultureQuestion {
  const CultureQuestion({
    required this.prompt,
    required this.answer,
    required this.choices,
    this.hint,
  });

  final String prompt;
  final String answer;
  final List<String> choices;

  /// Court éclairage affiché après la réponse : le jeu doit aussi apprendre.
  final String? hint;
}

class NovelLevel {
  const NovelLevel({
    required this.name,
    required this.questions,
  });

  final String name;
  final List<CultureQuestion> questions;
}

class Novel {
  const Novel({
    required this.id,
    required this.title,
    required this.author,
    required this.emoji,
    required this.color,
    required this.levels,
  });

  final int id;
  final String title;
  final String author;
  final String emoji;
  final int color;
  final List<NovelLevel> levels;
}

/// Nombre de questions posées par manche (piochées dans le niveau).
const kCultureQuestionsPerRound = 8;

const kNovels = <Novel>[
  // ─────────────────────── Le Dernier Jour d'un condamné ───────────────────
  Novel(
    id: 101,
    title: "Le Dernier Jour d'un condamné",
    author: 'Victor Hugo',
    emoji: '⛓️',
    color: 0xFF64748B,
    levels: [
      NovelLevel(
        name: 'Facile',
        questions: [
          CultureQuestion(
            prompt: "Qui est l'auteur du « Dernier Jour d'un condamné » ?",
            answer: 'Victor Hugo',
            choices: ['Victor Hugo', 'Émile Zola', 'Guy de Maupassant', 'Albert Camus'],
            hint: 'Victor Hugo publie l’œuvre en 1829.',
          ),
          CultureQuestion(
            prompt: 'En quelle année le roman a-t-il été publié ?',
            answer: '1829',
            choices: ['1829', '1862', '1789', '1902'],
          ),
          CultureQuestion(
            prompt: 'Qui raconte l’histoire ?',
            answer: 'Le condamné lui-même',
            choices: [
              'Le condamné lui-même',
              'Le prêtre',
              'Le geôlier',
              'Un journaliste',
            ],
            hint: 'Récit à la première personne, comme un journal intime.',
          ),
          CultureQuestion(
            prompt: 'Quelle cause Victor Hugo défend-il dans cette œuvre ?',
            answer: 'L’abolition de la peine de mort',
            choices: [
              'L’abolition de la peine de mort',
              'Le droit de vote des femmes',
              'La liberté de la presse',
              'L’abolition de l’esclavage',
            ],
          ),
          CultureQuestion(
            prompt: 'Comment s’appelle la fille du condamné ?',
            answer: 'Marie',
            choices: ['Marie', 'Zineb', 'Antigone', 'Eurydice'],
            hint: 'Elle a trois ans et ne le reconnaît pas.',
          ),
          CultureQuestion(
            prompt: 'Quel instrument doit servir à l’exécution ?',
            answer: 'La guillotine',
            choices: ['La guillotine', 'La corde', 'Le fusil', 'Le poison'],
          ),
          CultureQuestion(
            prompt: 'Le nom du condamné est-il donné dans le récit ?',
            answer: 'Non, jamais',
            choices: [
              'Non, jamais',
              'Oui, dès le début',
              'Oui, à la fin',
              'Seulement dans la préface',
            ],
            hint: 'L’anonymat le rend universel : ce pourrait être n’importe qui.',
          ),
          CultureQuestion(
            prompt: 'Sous quelle forme le condamné écrit-il ?',
            answer: 'Un journal',
            choices: ['Un journal', 'Des lettres', 'Un poème', 'Une pièce de théâtre'],
          ),
        ],
      ),
      NovelLevel(
        name: 'Moyen',
        questions: [
          CultureQuestion(
            prompt: 'Dans quelle prison le condamné est-il d’abord enfermé ?',
            answer: 'Bicêtre',
            choices: ['Bicêtre', 'La Bastille', 'Fresnes', 'Sainte-Anne'],
          ),
          CultureQuestion(
            prompt: 'Où est-il transféré avant son exécution ?',
            answer: 'La Conciergerie',
            choices: ['La Conciergerie', 'Le Louvre', 'Bicêtre', 'L’Hôtel de Ville'],
          ),
          CultureQuestion(
            prompt: 'Sur quelle place l’exécution doit-elle avoir lieu ?',
            answer: 'La place de Grève',
            choices: [
              'La place de Grève',
              'La place de la Concorde',
              'La place Vendôme',
              'La place de la Bastille',
            ],
          ),
          CultureQuestion(
            prompt: 'Qu’est-ce que le « ferrement » auquel il assiste ?',
            answer: 'L’enchaînement des forçats avant leur départ',
            choices: [
              'L’enchaînement des forçats avant leur départ',
              'La fabrication de la guillotine',
              'La fermeture des cellules pour la nuit',
              'Une prière collective',
            ],
          ),
          CultureQuestion(
            prompt: 'Que se passe-t-il lorsque sa fille Marie vient le voir ?',
            answer: 'Elle ne le reconnaît pas',
            choices: [
              'Elle ne le reconnaît pas',
              'Elle le supplie de fuir',
              'Elle refuse d’entrer',
              'Elle lui apporte une lettre',
            ],
            hint: 'Elle le croit mort : c’est l’un des moments les plus déchirants.',
          ),
          CultureQuestion(
            prompt: 'Quel personnage religieux accompagne le condamné ?',
            answer: 'L’aumônier',
            choices: ['L’aumônier', 'Le fqih', 'Le rabbin', 'Le moine copiste'],
          ),
          CultureQuestion(
            prompt: 'Quel espoir le condamné garde-t-il jusqu’au bout ?',
            answer: 'La grâce du roi',
            choices: [
              'La grâce du roi',
              'Une évasion',
              'Un procès en appel',
              'Le pardon de la victime',
            ],
          ),
          CultureQuestion(
            prompt: 'Comment se termine le récit ?',
            answer: 'Au moment de l’exécution, brutalement',
            choices: [
              'Au moment de l’exécution, brutalement',
              'Par sa libération',
              'Par son évasion',
              'Par la mort de sa fille',
            ],
          ),
        ],
      ),
      NovelLevel(
        name: 'Difficile',
        questions: [
          CultureQuestion(
            prompt: 'À quel genre littéraire cette œuvre se rattache-t-elle ?',
            answer: 'Le roman à thèse',
            choices: [
              'Le roman à thèse',
              'Le roman policier',
              'Le conte philosophique',
              'La tragédie classique',
            ],
            hint: 'Le récit sert à défendre une idée : abolir la peine de mort.',
          ),
          CultureQuestion(
            prompt: 'Que contient la préface ajoutée en 1832 ?',
            answer: 'Un plaidoyer explicite contre la peine de mort',
            choices: [
              'Un plaidoyer explicite contre la peine de mort',
              'Le nom véritable du condamné',
              'La suite du récit',
              'Une dédicace au roi',
            ],
          ),
          CultureQuestion(
            prompt: 'Quel registre domine dans le récit ?',
            answer: 'Le registre pathétique',
            choices: [
              'Le registre pathétique',
              'Le registre comique',
              'Le registre épique',
              'Le registre didactique',
            ],
          ),
          CultureQuestion(
            prompt:
                'Pourquoi Hugo refuse-t-il de dire le crime commis par le condamné ?',
            answer: 'Pour que le lecteur juge la peine, non l’homme',
            choices: [
              'Pour que le lecteur juge la peine, non l’homme',
              'Parce que le condamné est innocent',
              'Parce qu’il l’a oublié',
              'Pour ménager le suspense',
            ],
          ),
          CultureQuestion(
            prompt: 'Quel est le point de vue narratif adopté ?',
            answer: 'Le point de vue interne',
            choices: [
              'Le point de vue interne',
              'Le point de vue omniscient',
              'Le point de vue externe',
              'Un point de vue alterné',
            ],
          ),
          CultureQuestion(
            prompt: 'Que symbolise la foule qui assiste aux exécutions ?',
            answer: 'La cruauté et l’indifférence de la société',
            choices: [
              'La cruauté et l’indifférence de la société',
              'La justice populaire',
              'Le soutien au condamné',
              'La force de la religion',
            ],
          ),
          CultureQuestion(
            prompt: 'Quelle est la fonction du chapitre consacré à la chanson en argot ?',
            answer: 'Montrer le monde des prisons et sa langue',
            choices: [
              'Montrer le monde des prisons et sa langue',
              'Alléger le récit par une chanson gaie',
              'Annoncer une évasion',
              'Faire l’éloge de la justice',
            ],
          ),
          CultureQuestion(
            prompt: 'Quel effet produit l’écriture au présent dans le journal ?',
            answer: 'Elle donne l’impression d’une agonie vécue en direct',
            choices: [
              'Elle donne l’impression d’une agonie vécue en direct',
              'Elle éloigne le lecteur des faits',
              'Elle crée un effet comique',
              'Elle situe l’action dans le passé',
            ],
          ),
        ],
      ),
    ],
  ),

  // ──────────────────────────────── Antigone ───────────────────────────────
  Novel(
    id: 102,
    title: 'Antigone',
    author: 'Jean Anouilh',
    emoji: '🏛️',
    color: 0xFFA855F7,
    levels: [
      NovelLevel(
        name: 'Facile',
        questions: [
          CultureQuestion(
            prompt: 'Qui a écrit la pièce « Antigone » étudiée au programme ?',
            answer: 'Jean Anouilh',
            choices: ['Jean Anouilh', 'Sophocle', 'Molière', 'Jean Racine'],
            hint: 'Anouilh réécrit en 1944 la tragédie antique de Sophocle.',
          ),
          CultureQuestion(
            prompt: 'Quel est le genre de cette œuvre ?',
            answer: 'Une tragédie',
            choices: ['Une tragédie', 'Une comédie', 'Un roman', 'Une nouvelle'],
          ),
          CultureQuestion(
            prompt: 'De qui Antigone est-elle la fille ?',
            answer: 'Œdipe',
            choices: ['Œdipe', 'Créon', 'Hémon', 'Tirésias'],
          ),
          CultureQuestion(
            prompt: 'Qui est Créon ?',
            answer: 'Le roi de Thèbes, oncle d’Antigone',
            choices: [
              'Le roi de Thèbes, oncle d’Antigone',
              'Le frère d’Antigone',
              'Le fiancé d’Antigone',
              'Un devin',
            ],
          ),
          CultureQuestion(
            prompt: 'Qui est Hémon ?',
            answer: 'Le fils de Créon et fiancé d’Antigone',
            choices: [
              'Le fils de Créon et fiancé d’Antigone',
              'Le frère d’Antigone',
              'Un garde',
              'Le messager',
            ],
          ),
          CultureQuestion(
            prompt: 'Comment s’appelle la sœur d’Antigone ?',
            answer: 'Ismène',
            choices: ['Ismène', 'Eurydice', 'Marie', 'Zineb'],
          ),
          CultureQuestion(
            prompt: 'Quel frère d’Antigone est privé de sépulture ?',
            answer: 'Polynice',
            choices: ['Polynice', 'Étéocle', 'Hémon', 'Œdipe'],
          ),
          CultureQuestion(
            prompt: 'Dans quelle ville se déroule l’action ?',
            answer: 'Thèbes',
            choices: ['Thèbes', 'Athènes', 'Sparte', 'Corinthe'],
          ),
        ],
      ),
      NovelLevel(
        name: 'Moyen',
        questions: [
          CultureQuestion(
            prompt: 'Quel personnage présente tous les autres au début de la pièce ?',
            answer: 'Le Prologue',
            choices: ['Le Prologue', 'La Nourrice', 'Le Chœur seul', 'Ismène'],
          ),
          CultureQuestion(
            prompt: 'Avec quoi Antigone recouvre-t-elle le corps de son frère ?',
            answer: 'Une petite pelle d’enfant',
            choices: [
              'Une petite pelle d’enfant',
              'Ses mains nues',
              'Une pioche volée',
              'Un drap',
            ],
            hint: 'La pelle de son enfance : un détail bouleversant.',
          ),
          CultureQuestion(
            prompt: 'Que font les trois gardes pendant la pièce ?',
            answer: 'Ils jouent aux cartes',
            choices: [
              'Ils jouent aux cartes',
              'Ils prient',
              'Ils dorment',
              'Ils chantent',
            ],
          ),
          CultureQuestion(
            prompt: 'Quelle punition Créon inflige-t-il finalement à Antigone ?',
            answer: 'Être emmurée vivante',
            choices: [
              'Être emmurée vivante',
              'La décapitation',
              'L’exil',
              'La prison à vie',
            ],
          ),
          CultureQuestion(
            prompt: 'Qui est Eurydice ?',
            answer: 'La femme de Créon',
            choices: [
              'La femme de Créon',
              'La sœur d’Antigone',
              'La nourrice',
              'La reine de Corinthe',
            ],
            hint: 'On la voit tricoter ; elle se donne la mort à la fin.',
          ),
          CultureQuestion(
            prompt: 'Que devient Hémon à la fin de la pièce ?',
            answer: 'Il se suicide',
            choices: [
              'Il se suicide',
              'Il devient roi',
              'Il part en exil',
              'Il épouse Ismène',
            ],
          ),
          CultureQuestion(
            prompt: 'Quel argument Créon utilise-t-il pour convaincre Antigone ?',
            answer: 'Il faut bien que quelqu’un gouverne et dise oui',
            choices: [
              'Il faut bien que quelqu’un gouverne et dise oui',
              'Les dieux l’exigent',
              'Le peuple la déteste',
              'Polynice ne le mérite pas… car il était pauvre',
            ],
          ),
          CultureQuestion(
            prompt: 'À qui Antigone dicte-t-elle une lettre avant de mourir ?',
            answer: 'Au garde, pour Hémon',
            choices: [
              'Au garde, pour Hémon',
              'À Ismène, pour Créon',
              'Au Prologue',
              'À la Nourrice',
            ],
          ),
        ],
      ),
      NovelLevel(
        name: 'Difficile',
        questions: [
          CultureQuestion(
            prompt: 'En quelle année « Antigone » d’Anouilh est-elle représentée ?',
            answer: '1944',
            choices: ['1944', '1829', '1954', '1902'],
            hint: 'En pleine Occupation : la pièce résonne comme un acte de résistance.',
          ),
          CultureQuestion(
            prompt: 'De quel auteur antique Anouilh s’inspire-t-il ?',
            answer: 'Sophocle',
            choices: ['Sophocle', 'Euripide', 'Homère', 'Eschyle'],
          ),
          CultureQuestion(
            prompt: 'Que symbolise l’opposition entre Antigone et Créon ?',
            answer: 'L’idéal absolu contre la raison d’État',
            choices: [
              'L’idéal absolu contre la raison d’État',
              'La jeunesse contre la vieillesse seulement',
              'La richesse contre la pauvreté',
              'La science contre la religion',
            ],
          ),
          CultureQuestion(
            prompt: 'Qu’est-ce que le « tragique » dans cette pièce ?',
            answer: 'Le destin est connu d’avance et inévitable',
            choices: [
              'Le destin est connu d’avance et inévitable',
              'Les personnages sont ridicules',
              'L’intrigue est pleine de rebondissements',
              'La fin est heureuse',
            ],
          ),
          CultureQuestion(
            prompt: 'Quel rôle joue le Chœur dans la pièce ?',
            answer: 'Il commente l’action et explique la tragédie',
            choices: [
              'Il commente l’action et explique la tragédie',
              'Il combat Créon',
              'Il remplace le roi',
              'Il chante uniquement',
            ],
          ),
          CultureQuestion(
            prompt: 'Pourquoi dit-on que cette Antigone est « moderne » ?',
            answer: 'Décor et langage sont contemporains, sans dieux visibles',
            choices: [
              'Décor et langage sont contemporains, sans dieux visibles',
              'Elle se déroule au Maroc',
              'Elle est écrite en vers',
              'Elle finit bien',
            ],
          ),
          CultureQuestion(
            prompt: 'Quelle est la véritable raison du refus d’Antigone ?',
            answer: 'Refuser un bonheur médiocre et les compromis',
            choices: [
              'Refuser un bonheur médiocre et les compromis',
              'La haine de son oncle',
              'L’amour d’Hémon',
              'L’ambition politique',
            ],
          ),
          CultureQuestion(
            prompt: 'Quelle est la situation finale de Créon ?',
            answer: 'Seul, il continue de gouverner malgré tout',
            choices: [
              'Seul, il continue de gouverner malgré tout',
              'Il abdique',
              'Il est exécuté',
              'Il part en exil',
            ],
          ),
        ],
      ),
    ],
  ),

  // ───────────────────────── La Boîte à merveilles ─────────────────────────
  Novel(
    id: 103,
    title: 'La Boîte à merveilles',
    author: 'Ahmed Sefrioui',
    emoji: '🎁',
    color: 0xFFF59E0B,
    levels: [
      NovelLevel(
        name: 'Facile',
        questions: [
          CultureQuestion(
            prompt: 'Qui est l’auteur de « La Boîte à merveilles » ?',
            answer: 'Ahmed Sefrioui',
            choices: [
              'Ahmed Sefrioui',
              'Driss Chraïbi',
              'Mohammed Khaïr-Eddine',
              'Tahar Ben Jelloun',
            ],
          ),
          CultureQuestion(
            prompt: 'Comment s’appelle le narrateur enfant ?',
            answer: 'Sidi Mohammed',
            choices: ['Sidi Mohammed', 'Abdellah', 'Bouchaïb', 'Moulay Larbi'],
          ),
          CultureQuestion(
            prompt: 'Dans quelle ville se déroule le récit ?',
            answer: 'Fès',
            choices: ['Fès', 'Marrakech', 'Rabat', 'Tanger'],
          ),
          CultureQuestion(
            prompt: 'Comment se nomme la maison où vit la famille ?',
            answer: 'Dar Chouafa',
            choices: ['Dar Chouafa', 'Dar El Makhzen', 'Dar Debibagh', 'Dar Batha'],
            hint: 'La maison de la voyante (chouafa), au rez-de-chaussée.',
          ),
          CultureQuestion(
            prompt: 'Quel est le métier du père, Sidi Abdeslem ?',
            answer: 'Tisserand',
            choices: ['Tisserand', 'Épicier', 'Forgeron', 'Menuisier'],
          ),
          CultureQuestion(
            prompt: 'Comment s’appelle la mère du narrateur ?',
            answer: 'Lalla Zoubida',
            choices: ['Lalla Zoubida', 'Rahma', 'Lalla Khadija', 'Fatma Bziouya'],
          ),
          CultureQuestion(
            prompt: 'Qu’est-ce que le « Msid » ?',
            answer: 'L’école coranique',
            choices: [
              'L’école coranique',
              'Le marché',
              'Le hammam',
              'La mosquée du vendredi',
            ],
          ),
          CultureQuestion(
            prompt: 'Que contient la fameuse boîte à merveilles ?',
            answer: 'De petits objets sans valeur, précieux pour l’enfant',
            choices: [
              'De petits objets sans valeur, précieux pour l’enfant',
              'Des bijoux en or',
              'Des livres anciens',
              'De l’argent économisé',
            ],
            hint: 'Boutons, billes, clous… un trésor imaginaire contre la solitude.',
          ),
        ],
      ),
      NovelLevel(
        name: 'Moyen',
        questions: [
          CultureQuestion(
            prompt: 'À quel genre appartient cette œuvre ?',
            answer: 'Le roman autobiographique',
            choices: [
              'Le roman autobiographique',
              'Le roman policier',
              'La tragédie',
              'Le conte merveilleux',
            ],
          ),
          CultureQuestion(
            prompt: 'Qui est la « chouafa » de la maison ?',
            answer: 'Une voyante',
            choices: ['Une voyante', 'Une couturière', 'Une institutrice', 'Une marchande'],
          ),
          CultureQuestion(
            prompt: 'Qui est Zineb ?',
            answer: 'La fille de Rahma',
            choices: [
              'La fille de Rahma',
              'La sœur du narrateur',
              'La femme du fqih',
              'La voisine du haut',
            ],
            hint: 'Sa disparition puis son retour donnent lieu à une grande fête.',
          ),
          CultureQuestion(
            prompt: 'Qui est Abdellah dans le récit ?',
            answer: 'L’épicier conteur',
            choices: [
              'L’épicier conteur',
              'Le maître du Msid',
              'Le père du narrateur',
              'Le marchand d’étoffes',
            ],
          ),
          CultureQuestion(
            prompt: 'Pourquoi le père part-il travailler loin de Fès ?',
            answer: 'Il a perdu son capital au souk',
            choices: [
              'Il a perdu son capital au souk',
              'Il a été emprisonné',
              'Il veut étudier',
              'Il fuit une querelle',
            ],
          ),
          CultureQuestion(
            prompt: 'Qui est Moulay Larbi ?',
            answer: 'Un fabricant de charrues, ami du père',
            choices: [
              'Un fabricant de charrues, ami du père',
              'Le maître du Msid',
              'Le mari de la chouafa',
              'Un voisin médecin',
            ],
          ),
          CultureQuestion(
            prompt: 'Que se passe-t-il lors de la visite à Sidi Ali Boughaleb ?',
            answer: 'L’enfant est griffé par un chat et tombe malade',
            choices: [
              'L’enfant est griffé par un chat et tombe malade',
              'Il retrouve son père',
              'Il perd sa boîte',
              'Il rencontre son maître',
            ],
          ),
          CultureQuestion(
            prompt: 'Comment le narrateur adulte considère-t-il son enfance ?',
            answer: 'Avec nostalgie, marquée par la solitude',
            choices: [
              'Avec nostalgie, marquée par la solitude',
              'Avec colère et rejet',
              'Avec indifférence',
              'Comme une période de richesse',
            ],
          ),
        ],
      ),
      NovelLevel(
        name: 'Difficile',
        questions: [
          CultureQuestion(
            prompt: 'En quelle année « La Boîte à merveilles » a-t-elle paru ?',
            answer: '1954',
            choices: ['1954', '1929', '1975', '2002'],
          ),
          CultureQuestion(
            prompt: 'Quelle particularité a l’incipit du roman ?',
            answer: 'Le narrateur adulte évoque sa solitude avant de replonger dans l’enfance',
            choices: [
              'Le narrateur adulte évoque sa solitude avant de replonger dans l’enfance',
              'Le roman commence par la mort du père',
              'Il commence par un dialogue au Msid',
              'Il commence à la fin de l’histoire',
            ],
          ),
          CultureQuestion(
            prompt: 'Que représente la boîte à merveilles sur le plan symbolique ?',
            answer: 'Un refuge imaginaire face à la solitude',
            choices: [
              'Un refuge imaginaire face à la solitude',
              'La richesse de la famille',
              'La réussite scolaire',
              'La tradition religieuse',
            ],
          ),
          CultureQuestion(
            prompt: 'Quel courant littéraire caractérise cette œuvre ?',
            answer: 'La littérature marocaine d’expression française',
            choices: [
              'La littérature marocaine d’expression française',
              'Le surréalisme',
              'Le classicisme',
              'Le nouveau roman',
            ],
          ),
          CultureQuestion(
            prompt: 'Quel aspect de la société le roman met-il surtout en valeur ?',
            answer: 'La vie traditionnelle de la médina de Fès',
            choices: [
              'La vie traditionnelle de la médina de Fès',
              'La vie politique du pays',
              'L’exode rural',
              'La colonisation militaire',
            ],
          ),
          CultureQuestion(
            prompt: 'Quel rôle jouent les femmes de Dar Chouafa dans le récit ?',
            answer: 'Elles animent la maison par leurs querelles et leurs fêtes',
            choices: [
              'Elles animent la maison par leurs querelles et leurs fêtes',
              'Elles sont absentes du récit',
              'Elles dirigent le commerce',
              'Elles enseignent au Msid',
            ],
          ),
          CultureQuestion(
            prompt: 'Quel est le point de vue narratif dominant ?',
            answer: 'Un narrateur adulte qui revit son regard d’enfant',
            choices: [
              'Un narrateur adulte qui revit son regard d’enfant',
              'Un narrateur omniscient extérieur',
              'Plusieurs narrateurs alternés',
              'Un narrateur témoin étranger à la famille',
            ],
          ),
          CultureQuestion(
            prompt: 'Pourquoi peut-on parler d’œuvre « ethnographique » ?',
            answer: 'Elle décrit minutieusement rites, croyances et coutumes',
            choices: [
              'Elle décrit minutieusement rites, croyances et coutumes',
              'Elle contient des statistiques',
              'Elle raconte une guerre',
              'Elle est écrite par un historien',
            ],
          ),
        ],
      ),
    ],
  ),

  // ───────────────── Il était une fois un vieux couple heureux ─────────────
  Novel(
    id: 104,
    title: 'Il était une fois un vieux couple heureux',
    author: 'Mohammed Khaïr-Eddine',
    emoji: '🏔️',
    color: 0xFF10B981,
    levels: [
      NovelLevel(
        name: 'Facile',
        questions: [
          CultureQuestion(
            prompt: 'Qui est l’auteur de cette œuvre ?',
            answer: 'Mohammed Khaïr-Eddine',
            choices: [
              'Mohammed Khaïr-Eddine',
              'Ahmed Sefrioui',
              'Driss Chraïbi',
              'Abdelkébir Khatibi',
            ],
          ),
          CultureQuestion(
            prompt: 'Comment s’appelle le vieux personnage principal ?',
            answer: 'Bouchaïb',
            choices: ['Bouchaïb', 'Sidi Mohammed', 'Moulay Larbi', 'Abdellah'],
          ),
          CultureQuestion(
            prompt: 'Dans quelle région du Maroc se déroule le récit ?',
            answer: 'Le Souss',
            choices: ['Le Souss', 'Le Rif', 'La région de Fès', 'Le Sahara oriental'],
          ),
          CultureQuestion(
            prompt: 'Dans quel type de lieu vit le vieux couple ?',
            answer: 'Un village de montagne',
            choices: [
              'Un village de montagne',
              'Une grande ville',
              'Un port',
              'Un camp nomade',
            ],
          ),
          CultureQuestion(
            prompt: 'Quelle activité artistique pratique le vieux ?',
            answer: 'Il écrit des poèmes',
            choices: [
              'Il écrit des poèmes',
              'Il peint des tableaux',
              'Il sculpte le bois',
              'Il joue du luth',
            ],
          ),
          CultureQuestion(
            prompt: 'La femme du vieux est-elle nommée dans le récit ?',
            answer: 'Non, elle est « la vieille »',
            choices: [
              'Non, elle est « la vieille »',
              'Oui, Zoubida',
              'Oui, Ismène',
              'Oui, Rahma',
            ],
          ),
          CultureQuestion(
            prompt: 'Quelle langue le vieux maîtrise-t-il en plus du berbère ?',
            answer: 'L’arabe',
            choices: ['L’arabe', 'L’anglais', 'L’espagnol', 'Le latin'],
          ),
          CultureQuestion(
            prompt: 'Le vieux couple est-il riche ?',
            answer: 'Non, il vit simplement mais sereinement',
            choices: [
              'Non, il vit simplement mais sereinement',
              'Oui, il possède des terres immenses',
              'Oui, grâce à un héritage',
              'Non, il mendie',
            ],
          ),
        ],
      ),
      NovelLevel(
        name: 'Moyen',
        questions: [
          CultureQuestion(
            prompt: 'Qu’a fait Bouchaïb avant de revenir vivre au village ?',
            answer: 'Il a beaucoup voyagé',
            choices: [
              'Il a beaucoup voyagé',
              'Il a toujours vécu au village',
              'Il a été militaire en Europe seulement',
              'Il a étudié à l’étranger sans jamais revenir',
            ],
          ),
          CultureQuestion(
            prompt: 'Quel fléau naturel menace régulièrement le village ?',
            answer: 'La sécheresse',
            choices: ['La sécheresse', 'Les inondations', 'Les tremblements de terre', 'Le froid polaire'],
          ),
          CultureQuestion(
            prompt: 'Quel phénomène social le roman dénonce-t-il ?',
            answer: 'L’exode rural qui vide les villages',
            choices: [
              'L’exode rural qui vide les villages',
              'L’industrialisation excessive',
              'La surpopulation des campagnes',
              'Le tourisme de masse',
            ],
          ),
          CultureQuestion(
            prompt: 'Comment le vieux considère-t-il la modernité ?',
            answer: 'Avec méfiance, sans la rejeter totalement',
            choices: [
              'Avec méfiance, sans la rejeter totalement',
              'Avec un enthousiasme total',
              'Avec indifférence complète',
              'Il l’ignore, ne la connaissant pas',
            ],
          ),
          CultureQuestion(
            prompt: 'Quelle valeur le couple incarne-t-il avant tout ?',
            answer: 'La sagesse et la simplicité',
            choices: [
              'La sagesse et la simplicité',
              'L’ambition et la réussite',
              'La révolte politique',
              'La quête de richesse',
            ],
          ),
          CultureQuestion(
            prompt: 'Quel est le rapport du vieux à l’écriture ?',
            answer: 'Elle est pour lui un art et une mémoire',
            choices: [
              'Elle est pour lui un art et une mémoire',
              'Il ne sait pas écrire',
              'Il écrit uniquement des lettres commerciales',
              'Il déteste écrire',
            ],
          ),
          CultureQuestion(
            prompt: 'Comment le récit présente-t-il la vie du couple ?',
            answer: 'Comme une vie modeste mais heureuse',
            choices: [
              'Comme une vie modeste mais heureuse',
              'Comme une succession de malheurs',
              'Comme une vie de luxe',
              'Comme une vie de conflits permanents',
            ],
          ),
          CultureQuestion(
            prompt: 'Quel rôle joue la nature dans l’œuvre ?',
            answer: 'Elle rythme la vie et façonne les hommes',
            choices: [
              'Elle rythme la vie et façonne les hommes',
              'Elle est absente du récit',
              'Elle n’est qu’un décor sans importance',
              'Elle est présentée comme hostile uniquement',
            ],
          ),
        ],
      ),
      NovelLevel(
        name: 'Difficile',
        questions: [
          CultureQuestion(
            prompt: 'Quel thème majeur traverse toute l’œuvre ?',
            answer: 'Tradition et modernité',
            choices: [
              'Tradition et modernité',
              'Guerre et paix',
              'Crime et châtiment',
              'Amour courtois',
            ],
          ),
          CultureQuestion(
            prompt: 'Pourquoi l’œuvre est-elle considérée comme un hommage ?',
            answer: 'Elle célèbre la culture amazighe et la mémoire du Souss',
            choices: [
              'Elle célèbre la culture amazighe et la mémoire du Souss',
              'Elle rend hommage à la France',
              'Elle glorifie la ville moderne',
              'Elle célèbre la guerre d’indépendance',
            ],
          ),
          CultureQuestion(
            prompt: 'Que signifie le titre « Il était une fois… » ?',
            answer: 'Il donne au récit une tonalité de conte',
            choices: [
              'Il donne au récit une tonalité de conte',
              'Il annonce une enquête policière',
              'Il indique un texte historique',
              'Il s’agit d’une erreur d’édition',
            ],
          ),
          CultureQuestion(
            prompt: 'Quelle est la structure dominante du récit ?',
            answer: 'Un récit fait de scènes de vie et de digressions',
            choices: [
              'Un récit fait de scènes de vie et de digressions',
              'Une intrigue policière serrée',
              'Un journal intime daté',
              'Un échange de lettres',
            ],
          ),
          CultureQuestion(
            prompt: 'Quel regard l’auteur porte-t-il sur les jeunes partis en ville ?',
            answer: 'Critique : ils perdent leurs repères et leurs racines',
            choices: [
              'Critique : ils perdent leurs repères et leurs racines',
              'Admiratif sans réserve',
              'Totalement indifférent',
              'Il ne les évoque jamais',
            ],
          ),
          CultureQuestion(
            prompt: 'Quel registre domine dans l’évocation du passé ?',
            answer: 'Le registre nostalgique',
            choices: [
              'Le registre nostalgique',
              'Le registre burlesque',
              'Le registre polémique',
              'Le registre fantastique',
            ],
          ),
          CultureQuestion(
            prompt: 'En quelle année ce roman a-t-il été publié ?',
            answer: '2002',
            choices: ['2002', '1954', '1975', '1944'],
          ),
          CultureQuestion(
            prompt: 'Quelle leçon le lecteur peut-il tirer de ce couple ?',
            answer: 'Le bonheur tient à peu, dans l’accord avec soi et sa terre',
            choices: [
              'Le bonheur tient à peu, dans l’accord avec soi et sa terre',
              'Il faut partir pour réussir',
              'La richesse fait le bonheur',
              'La tradition doit disparaître',
            ],
          ),
        ],
      ),
    ],
  ),
];
