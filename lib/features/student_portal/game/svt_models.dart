/// Défi SVT — 2ᵉ Bac, unité 1 : « Libération de l'énergie emmagasinée dans
/// la matière organique » (cours du Pr. Monssif el Kaoune).
///
/// Six mondes du plus facile au plus difficile, trois niveaux chacun, huit
/// questions par manche tirées au hasard dans le niveau. Réutilise le moteur
/// du Défi Lecture (`Novel` / `NovelLevel` / `CultureQuestion`).
library;

import 'culture_models.dart';

CultureQuestion _q(String prompt, String answer, List<String> others, {String? hint}) =>
    CultureQuestion(prompt: prompt, answer: answer, choices: [answer, ...others], hint: hint);

const _stage1 = 201;
const _stage2 = 202;
const _stage3 = 203;
const _stage4 = 204;
const _stage5 = 205;
const _stage6 = 206;

final kSvtStages = <Novel>[
  // ───────────────────────── Monde 1 : Cellule & ATP (facile) ─────────────────────────
  Novel(
    id: _stage1,
    title: 'Cellule & ATP',
    author: 'Monde 1 · Facile',
    emoji: '🔋',
    color: 0xFF16A34A,
    levels: [
      NovelLevel(name: 'Niveau 1 · La cellule', questions: [
        _q("L'unité structurale fondamentale de tous les êtres vivants est…", 'la cellule', ['la mitochondrie', 'le noyau', 'la molécule d\'ATP']),
        _q('Le cytoplasme est limité par…', 'la membrane cytoplasmique', ['la paroi cellulosique', 'la membrane nucléaire', 'le réticulum']),
        _q('Quel organite est présent dans la cellule végétale mais absent de la cellule animale ?', 'le chloroplaste', ['la mitochondrie', 'le noyau', 'le ribosome']),
        _q('La paroi cellulosique caractérise…', 'la cellule végétale', ['la cellule animale', 'la bactérie', 'toutes les cellules']),
        _q("L'organite présent dans les cellules animales ET végétales, siège de la respiration, est…", 'la mitochondrie', ['le chloroplaste', 'la vacuole', 'la paroi']),
        _q('Les substances organiques consommées par la cellule pour produire de l\'énergie sont appelées…', 'des métabolites énergétiques', ['des enzymes', 'des organites', 'des déchets minéraux']),
        _q('La forme d\'énergie directement utilisable par la cellule est…', "l'ATP", ['le glucose', 'la chaleur', "l'O2"]),
        _q('Le transport actif, la synthèse cellulaire et la contraction musculaire ont en commun…', 'de consommer de l\'énergie', ['de libérer du CO2', 'de produire du glucose', 'de se dérouler dans le noyau']),
      ]),
      NovelLevel(name: 'Niveau 2 · La molécule d\'ATP', questions: [
        _q('ATP signifie…', 'adénosine triphosphate', ['adénine tétraphosphate', 'acide triphosphorique', 'adénosine diphosphate']),
        _q("L'ATP est formée d'une adénosine liée à…", 'trois groupements phosphate', ['deux groupements phosphate', 'un groupement phosphate', 'trois molécules de ribose']),
        _q("L'adénosine est composée d'un ribose et…", "d'une base azotée, l'adénine", ["d'un acide gras", "d'un phosphate", "d'un glucose"]),
        _q('Le ribose de l\'ATP est…', 'un pentose (sucre à 5 carbones)', ['un hexose', 'une base azotée', 'un acide aminé']),
        _q("L'hydrolyse de l'ATP donne…", 'ADP + Pi + énergie', ['AMP + 2 Pi', 'glucose + énergie', 'ATP + H2O']),
        _q("L'enzyme qui catalyse l'hydrolyse de l'ATP est…", "l'ATPase", ["l'ATP synthase", 'la déshydrogénase', 'la décarboxylase']),
        _q("L'enzyme qui catalyse la synthèse de l'ATP à partir d'ADP + Pi est…", "l'ATP synthase", ["l'ATPase", 'la catalase', 'la glycolase']),
        _q("L'hydrolyse d'une mole d'ATP libère environ…", '30,5 kJ', ['2840 kJ', '1360 kJ', '140 kJ']),
      ]),
      NovelLevel(name: 'Niveau 3 · ATP : la monnaie énergétique', questions: [
        _q("L'ATP a été mise en évidence…", 'dans toutes les cellules (animales, végétales, bactériennes)', ['seulement dans les cellules animales', 'seulement dans les muscles', 'seulement chez les bactéries']),
        _q('Les liaisons riches en énergie de l\'ATP se situent…', 'entre les groupements phosphate', ["entre l'adénine et le ribose", 'dans le ribose', "entre l'adénine et un phosphate uniquement"]),
        _q('La synthèse de l\'ATP par phosphorylation de l\'ADP…', "nécessite un apport d'énergie", ["libère de l'énergie", 'ne fait intervenir aucune enzyme', 'se fait sans phosphate']),
        _q("L'énergie libérée par l'hydrolyse de l'ATP est utilisée pour…", "les réactions consommatrices d'énergie", ['la formation du glucose', 'le rejet du CO2', 'la réduction du NAD+']),
        _q('Les deux réactions qui caractérisent l\'ATP (synthèse et hydrolyse) sont…', 'réversibles', ['irréversibles', 'identiques', 'spontanées sans enzyme']),
        _q("La cellule convertit l'énergie chimique du glucose en…", 'ATP', ['chaleur uniquement', 'O2', 'lumière']),
        _q("Une partie de l'énergie libérée lors de la dégradation du glucose est perdue sous forme de…", 'chaleur', ["d'ATP", "d'eau", 'de CO2']),
        _q('Le Pi de la réaction ATP → ADP + Pi désigne…', 'un phosphate inorganique', ['une protéine', 'un pentose', 'un proton']),
      ]),
    ],
  ),

  // ───────────────── Monde 2 : Respiration ou fermentation ? (levure) ─────────────────
  Novel(
    id: _stage2,
    title: 'Respiration ou fermentation ?',
    author: 'Monde 2 · Facile+',
    emoji: '🧪',
    color: 0xFF0EA5E9,
    levels: [
      NovelLevel(name: 'Niveau 1 · La levure en milieu aéré', questions: [
        _q('La levure de bière est…', 'un champignon unicellulaire', ['une bactérie', 'une algue', 'une cellule animale']),
        _q("Le montage EXAO permet de mesurer dans le milieu…", 'les concentrations d\'O2 et de CO2', ['la masse des levures', 'le pH uniquement', 'la quantité de lumière']),
        _q("Après injection de glucose en milieu aéré, la concentration d'O2…", 'diminue', ['augmente', 'reste constante', 'devient nulle immédiatement']),
        _q("Après injection de glucose en milieu aéré, la concentration de CO2…", 'augmente', ['diminue', 'reste constante', "s'annule"]),
        _q("L'augmentation de la température du milieu s'explique par…", "une libération d'énergie sous forme de chaleur", ['la présence de glucose', "l'entrée d'O2", 'la multiplication des levures']),
        _q("L'augmentation de la masse des levures traduit…", 'la multiplication des cellules', ["l'absorption d'eau", 'la fixation du CO2', 'la production de chaleur']),
        _q('En présence d\'O2, les levures utilisent…', 'la respiration cellulaire', ['la fermentation alcoolique', 'la photosynthèse', 'la fermentation lactique']),
        _q('La respiration cellulaire dégrade le glucose…', 'complètement en CO2 et H2O', ['partiellement en éthanol', 'partiellement en acide lactique', 'en acide pyruvique seulement']),
      ]),
      NovelLevel(name: 'Niveau 2 · Sans dioxygène', questions: [
        _q('En absence d\'O2, la levure réalise…', 'la fermentation alcoolique', ['la respiration cellulaire', 'la fermentation lactique', 'la photosynthèse']),
        _q('Les produits de la fermentation alcoolique sont…', "l'éthanol et le CO2", ["l'acide lactique et l'H2O", 'le CO2 et l\'H2O', "l'acide pyruvique et l'O2"]),
        _q("L'éthanol est…", 'un résidu organique encore riche en énergie', ['un déchet minéral sans énergie', 'un métabolite énergétique consommé', 'un transporteur d\'électrons']),
        _q('La fermentation libère…', "une faible quantité d'énergie", ["autant d'énergie que la respiration", "plus d'énergie que la respiration", "aucune énergie"]),
        _q("Une cellule de levure ayant séjourné en milieu aérobie présente…", 'de nombreuses mitochondries', ['aucune mitochondrie', 'des chloroplastes', 'une paroi plus épaisse']),
        _q('En milieu anaérobie, la cellule de levure…', 'ne présente pas de mitochondries', ['multiplie ses mitochondries', 'perd son noyau', 'forme des chloroplastes']),
        _q("L'organite impliqué dans la production d'énergie en milieu aérobie est…", 'la mitochondrie', ['la vacuole', 'le réticulum', "l'appareil de Golgi"]),
        _q('La faible augmentation de la masse des levures en anaérobie s\'explique par…', 'la faible énergie libérée par la fermentation', ["l'absence de glucose", 'la toxicité de l\'O2', "l'excès d'eau"]),
      ]),
      NovelLevel(name: 'Niveau 3 · Lire le graphique', questions: [
        _q("Dans l'expérience en récipient hermétique, de 0 à 200 s le milieu est…", 'aérobie : O2 encore présent, respiration', ['anaérobie dès le départ', 'sans glucose', 'sans levures']),
        _q("À partir de 200 s, l'O2 devient nul et…", "l'éthanol apparaît : fermentation alcoolique", ['le CO2 disparaît', 'le glucose augmente', 'la respiration s\'intensifie']),
        _q("Pendant toute l'expérience, la concentration de glucose…", 'diminue progressivement', ['augmente', 'reste constante', "s'annule à 200 s"]),
        _q("Le CO2 est produit…", 'par la respiration ET par la fermentation alcoolique', ['par la respiration seulement', 'par la fermentation seulement', 'par aucune des deux']),
        _q("Les deux voies métaboliques qui libèrent l'énergie du glucose sont…", 'la respiration et la fermentation', ['la photosynthèse et la respiration', 'la glycolyse et la digestion', "l'hydrolyse et la synthèse"]),
        _q("À la fin de l'expérience aérobie, on trouve plus d'eau produite que consommée car…", 'la respiration produit de l\'H2O', ['le glucose se transforme en eau', 'la fermentation produit de l\'eau', 'les levures absorbent le CO2']),
        _q("La fermentation se caractérise par…", "l'absence de consommation d'O2", ['une consommation intense d\'O2', 'une dégradation complète du glucose', 'la production de 38 ATP']),
        _q("Le résidu de la fermentation peut être…", 'organique uniquement, ou organique + minéral', ['minéral uniquement', 'de l\'eau uniquement', 'de l\'O2']),
      ]),
    ],
  ),

  // ───────────────────────────── Monde 3 : La glycolyse ─────────────────────────────
  Novel(
    id: _stage3,
    title: 'La glycolyse',
    author: 'Monde 3 · Moyen',
    emoji: '⚡',
    color: 0xFFF59E0B,
    levels: [
      NovelLevel(name: 'Niveau 1 · Où et quoi', questions: [
        _q('La glycolyse se déroule dans…', 'le cytoplasme (hyaloplasme)', ['la matrice mitochondriale', 'la membrane interne', 'le noyau']),
        _q('La glycolyse a besoin…', "d'aucun O2", ["d'O2 en grande quantité", 'de lumière', 'de chlorophylle']),
        _q('La glycolyse est une étape commune à…', 'la respiration et la fermentation', ['la respiration seulement', 'la fermentation seulement', 'la photosynthèse']),
        _q('Le produit final de la glycolyse est…', "l'acide pyruvique (pyruvate)", ["l'éthanol", 'le CO2', "l'acide lactique"]),
        _q('Une molécule de glucose donne…', '2 molécules d\'acide pyruvique', ['1 molécule d\'acide pyruvique', '3 molécules d\'acide pyruvique', '6 molécules de CO2']),
        _q('Le glucose est une molécule en…', 'C6', ['C3', 'C2', 'C4']),
        _q("L'acide pyruvique est une molécule en…", 'C3', ['C6', 'C2', 'C4']),
        _q('Chaque réaction de la glycolyse est catalysée par…', 'une enzyme spécifique', ['la lumière', "l'O2", 'un phosphate']),
      ]),
      NovelLevel(name: 'Niveau 2 · Les trois étapes', questions: [
        _q('La première étape de la glycolyse…', 'consomme 2 ATP', ['produit 4 ATP', 'réduit 2 NAD+', 'libère du CO2']),
        _q('Le glucose phosphate fixe un second phosphate et devient…', 'du fructose diphosphate', ['de l\'acide pyruvique', 'du glycéraldéhyde', 'de l\'acétyl-CoA']),
        _q('Le fructose diphosphate se scinde en…', '2 glycéraldéhyde phosphate (C3)', ['2 acides pyruviques', '3 molécules en C2', '6 CO2']),
        _q("Au cours de la 2ᵉ étape, le glycéraldéhyde phosphate subit…", 'une oxydation qui réduit le NAD+ en NADH,H+', ['une décarboxylation', 'une hydrolyse', 'une réduction par le FAD']),
        _q('La 3ᵉ étape transforme l\'acide glycérique diphosphate en…', 'acide pyruvique avec synthèse de 4 ATP', ['éthanol avec 2 ATP', 'acétyl-CoA', 'citrate']),
        _q('Le bilan NET en ATP de la glycolyse est…', '2 ATP (4 produits − 2 consommés)', ['4 ATP', '6 ATP', '38 ATP']),
        _q('La glycolyse réduit…', '2 NAD+ en 2 NADH,H+', ['2 FAD en 2 FADH2', '1 NAD+ en 1 NADH,H+', '4 NAD+']),
        _q("L'équation globale de la glycolyse est…", 'C6H12O6 + 2 NAD+ + 2 ADP + 2 Pi → 2 CH3-CO-COOH + 2 (NADH,H+) + 2 ATP', ['C6H12O6 + 6 O2 → 6 CO2 + 6 H2O', 'C6H12O6 → 2 éthanol + 2 CO2', 'CH3-CO-COOH + CoA → acétyl-CoA']),
      ]),
      NovelLevel(name: 'Niveau 3 · Oxydo-réduction', questions: [
        _q("NAD+ et FAD sont…", "des transporteurs d'électrons et de protons H+", ['des enzymes de la glycolyse', 'des molécules riches en phosphate', 'des sucres']),
        _q('La forme réduite du NAD+ est…', 'NADH,H+', ['NAD2', 'FADH2', 'NADP']),
        _q('La forme réduite du FAD est…', 'FADH2', ['FAD+', 'NADH,H+', 'FADP']),
        _q("Réduire un transporteur R'+, c'est…", 'lui faire fixer 2 e− et 2 H+', ['lui enlever 2 e−', 'lui ajouter un phosphate', 'le décarboxyler']),
        _q('Une oxydation correspond à…', "une perte d'électrons", ["un gain d'électrons", 'un gain de phosphate', 'une perte de CO2']),
        _q('Pour que la glycolyse se poursuive, il faut que NADH,H+…', 'soit réoxydé en NAD+', ['soit décarboxylé', 'reste réduit', 'soit hydrolysé']),
        _q('Le NADH,H+ est un composé…', "riche en énergie, capable de réduire d'autres substances", ['pauvre en énergie', 'minéral', 'qui contient du CO2']),
        _q("Dans l'écriture simplifiée R'+ + 2e− + 2H+ ⇌ R'H2, R'H2 représente…", 'NADH,H+ ou FADH2', ['NAD+ ou FAD', 'ATP', 'le glucose']),
      ]),
    ],
  ),

  // ─────────────────── Monde 4 : Mitochondrie & cycle de Krebs ───────────────────
  Novel(
    id: _stage4,
    title: 'Mitochondrie & cycle de Krebs',
    author: 'Monde 4 · Moyen+',
    emoji: '🔬',
    color: 0xFF7C3AED,
    levels: [
      NovelLevel(name: 'Niveau 1 · Structure et rôle', questions: [
        _q('La mitochondrie est limitée par…', 'deux membranes (externe et interne)', ['une seule membrane', 'une paroi cellulosique', 'aucune membrane']),
        _q('Les replis de la membrane interne s\'appellent…', 'les crêtes', ['les vacuoles', 'les ribosomes', 'les pores']),
        _q("L'espace situé à l'intérieur de la membrane interne est…", 'la matrice', ["l'espace intermembranaire", 'le cytosol', 'le stroma']),
        _q('Pour isoler les mitochondries, après le broyage on réalise…', 'des centrifugations (900 G puis 10 000 G)', ['une filtration', 'une distillation', 'une électrophorèse']),
        _q("Des mitochondries isolées, riches en O2, ne consomment PAS d'O2 quand on ajoute…", 'du glucose', ['de l\'acide pyruvique', "de l'ADP + Pi", 'du NADH,H+']),
        _q('Les mitochondries consomment de l\'O2 quand on leur fournit…', "de l'acide pyruvique", ['du glucose', 'de l\'éthanol', 'du CO2']),
        _q("Après ajout d'ADP + Pi, on observe…", "une forte consommation d'O2 et une forte synthèse d'ATP", ['un arrêt de la respiration', 'une production de glucose', 'une libération d\'éthanol']),
        _q('Le métabolite énergétique utilisé par la mitochondrie est…', "l'acide pyruvique issu de la glycolyse", ['le glucose', 'le CO2', "l'ATP"]),
      ]),
      NovelLevel(name: 'Niveau 2 · Membranes et enzymes', questions: [
        _q('La membrane interne est composée d\'environ…', '80 % de protéines et 20 % de lipides', ['50 % de protéines', '20 % de protéines', '100 % de lipides']),
        _q('Les crêtes de la membrane interne permettent…', 'une grande surface', ['le stockage du glucose', 'la fixation du CO2', 'la synthèse de lipides']),
        _q('Les sphères pédonculées de la membrane interne jouent le rôle…', "d'ATP synthétases", ['de décarboxylases', 'de transporteurs de glucose', 'de canaux à CO2']),
        _q('La matrice contient…', "de l'acide pyruvique, ATP, ADP, Pi, NAD+, FAD et des enzymes", ['du glucose et des chloroplastes', 'de la chlorophylle', 'uniquement de l\'eau']),
        _q('Une décarboxylation libère…', 'une molécule de CO2', ['une molécule d\'H2O', 'un ATP', 'un électron']),
        _q('Une déshydrogénation est…', 'une oxydation qui enlève des H+ fixés par NAD+ ou FAD', ['une réduction', 'une hydrolyse', 'une décarboxylation']),
        _q("Avec du glucose marqué au 14C, la radioactivité apparaît dans l'ordre…", 'glucose → pyruvate → acides du cycle de Krebs → CO2', ['CO2 → pyruvate → glucose', 'glucose → CO2 → pyruvate', 'pyruvate → glucose → éthanol']),
        _q('Le CO2 marqué est finalement retrouvé…', 'dans le milieu extracellulaire (rejeté)', ['dans le noyau', 'dans la membrane externe', 'dans le glucose']),
      ]),
      NovelLevel(name: 'Niveau 3 · Acétyl-CoA et Krebs', questions: [
        _q("Dans la matrice, l'acide pyruvique subit d'abord…", 'une décarboxylation et une déshydrogénation → acétyl-CoA', ['une réduction en éthanol', 'une phosphorylation', 'une hydrolyse']),
        _q("L'équation de formation de l'acétyl-CoA est…", 'CH3-CO-COOH + CoA + NAD+ → CH3-CO-CoA + NADH,H+ + CO2', ['CH3-CO-COOH → CH3-CH2-OH + CO2', 'C6H12O6 → 2 CH3-CO-COOH', 'ADP + Pi → ATP']),
        _q("L'acétyle (C2) se lie à l'acide oxaloacétique (C4) pour former…", "l'acide citrique (C6)", ["l'acide lactique (C3)", "l'éthanol (C2)", 'le glucose (C6)']),
        _q('Le cycle de Krebs régénère…', "l'acide oxaloacétique", ['le glucose', "l'ATP synthase", "l'O2"]),
        _q('Le bilan d\'UN tour de cycle de Krebs est…', '2 CO2, 3 NADH,H+, 1 FADH2, 1 ATP', ['6 CO2, 8 NADH,H+', '2 ATP, 2 NADH,H+', '38 ATP']),
        _q("Pour UNE molécule de pyruvate, la dégradation dans la matrice donne…", '3 CO2, 4 NADH,H+, 1 FADH2, 1 ATP', ['2 CO2, 2 NADH,H+', '6 CO2, 2 ATP', '1 CO2, 1 ATP']),
        _q("Pour UNE molécule de glucose, la dégradation du pyruvate dans la matrice donne…", '6 CO2, 8 NADH,H+, 2 FADH2, 2 ATP', ['3 CO2, 4 NADH,H+', '2 CO2, 2 ATP', '36 ATP']),
        _q("Le CO2 du cycle de Krebs provient de…", 'réactions de décarboxylation', ["la réduction de l'O2", "l'hydrolyse de l'ATP", 'la fixation du glucose']),
      ]),
    ],
  ),

  // ────────────────── Monde 5 : Chaîne respiratoire & ATP (difficile) ──────────────────
  Novel(
    id: _stage5,
    title: 'Chaîne respiratoire & ATP',
    author: 'Monde 5 · Difficile',
    emoji: '🔗',
    color: 0xFFDC2626,
    levels: [
      NovelLevel(name: 'Niveau 1 · Les transporteurs', questions: [
        _q('La chaîne respiratoire est localisée dans…', 'la membrane interne des mitochondries', ['la matrice', 'la membrane externe', 'le cytoplasme']),
        _q('Les transporteurs de la chaîne respiratoire sont…', 'des complexes enzymatiques d\'oxydo-réduction', ['des sucres', 'des lipides', 'des acides nucléiques']),
        _q('Le NADH,H+ est réoxydé par…', 'le complexe I', ['le complexe II', 'le complexe IV', 'la sphère pédonculée']),
        _q('Le FADH2 est réoxydé par…', 'le complexe II', ['le complexe I', 'le cytochrome C', "l'O2"]),
        _q("Le dernier accepteur des électrons de la chaîne respiratoire est…", "l'O2, réduit en H2O", ['le NAD+', 'le CO2', "l'acide pyruvique"]),
        _q('Le flux d\'électrons se fait spontanément…', 'dans le sens croissant des potentiels redox', ['dans le sens décroissant des potentiels redox', 'au hasard', 'vers le NADH,H+']),
        _q('Le premier donneur d\'électrons de la chaîne est le couple…', 'NADH,H+ / NAD+', ['O2 / H2O', 'ATP / ADP', 'glucose / pyruvate']),
        _q("Au cours de leur transport, les électrons…", "libèrent de l'énergie", ["absorbent de l'énergie", 'produisent du glucose', 'fixent du CO2']),
      ]),
      NovelLevel(name: 'Niveau 2 · Le gradient de protons', questions: [
        _q("L'énergie libérée par les électrons sert aux complexes I, III et IV à…", "pomper des H+ de la matrice vers l'espace intermembranaire", ['synthétiser du glucose', 'réduire le NAD+', 'fixer le CO2']),
        _q('Il s\'établit ainsi un gradient de H+ :', "concentration plus forte dans l'espace intermembranaire que dans la matrice", ['concentration plus forte dans la matrice', 'concentrations égales', 'H+ absents partout']),
        _q('La membrane interne est…', 'imperméable aux H+, sauf par les canaux des sphères pédonculées', ['perméable aux H+ partout', 'perméable au glucose', 'imperméable aux électrons']),
        _q("Le retour des H+ vers la matrice à travers les sphères pédonculées permet…", "la synthèse d'ATP (ADP + Pi + énergie → ATP)", ["l'hydrolyse de l'ATP", 'la décarboxylation', 'la réduction du FAD']),
        _q('Des particules submitochondriales SANS sphères pédonculées…', "ne synthétisent pas d'ATP", ['synthétisent plus d\'ATP', 'consomment du glucose', 'produisent de l\'éthanol']),
        _q('Si pHi = pHe (pas de gradient de H+)…', "il n'y a pas de synthèse d'ATP", ["la synthèse d'ATP est maximale", 'la chaîne s\'inverse', 'le CO2 augmente']),
        _q('Le FCCP rend la membrane interne perméable aux H+, donc…', 'le gradient disparaît : plus de synthèse d\'ATP', ["l'ATP augmente", 'les électrons s\'arrêtent', 'le glucose entre']),
        _q("Après injection d'O2 dans un milieu riche en R'H2, la concentration de H+ à l'extérieur…", 'augmente rapidement (pompage des H+)', ['diminue', 'reste nulle', "s'annule aussitôt"]),
      ]),
      NovelLevel(name: 'Niveau 3 · Le bilan de la respiration', questions: [
        _q('La réoxydation d\'un NADH,H+ permet la synthèse de…', '3 ATP', ['2 ATP', '1 ATP', '38 ATP']),
        _q("La réoxydation d'un FADH2 permet la synthèse de…", '2 ATP', ['3 ATP', '1 ATP', '4 ATP']),
        _q('Avec la navette malate-aspartate, le bilan de la respiration est…', '38 ATP', ['36 ATP', '2 ATP', '34 ATP']),
        _q('Avec la navette glycérol 3-phosphate, le bilan est…', '36 ATP', ['38 ATP', '2 ATP', '40 ATP']),
        _q("L'équation globale de la respiration est…", 'C6H12O6 + 6 O2 → 6 CO2 + 6 H2O + énergie (36 ou 38 ATP)', ['C6H12O6 → 2 éthanol + 2 CO2 + 2 ATP', 'C6H12O6 → 2 acide lactique + 2 ATP', '6 CO2 + 6 H2O → C6H12O6 + 6 O2']),
        _q("La réduction de l'O2 s'écrit…", '½ O2 + 2 e− + 2 H+ → H2O', ['O2 + C → CO2', 'O2 + 2 H+ → H2O2', '½ O2 + ATP → H2O']),
        _q('On parle de phosphorylation oxydative car…', "la phosphorylation de l'ADP est couplée à la réoxydation des R'H2 (qui nécessite l'O2)", ['le phosphate est oxydé', "l'ATP est réduit", 'le glucose est phosphorylé']),
        _q('Le monoxyde de carbone (CO) se fixe sur le complexe IV, donc…', "arrêt du transfert d'électrons → pas de gradient de H+ → pas d'ATP", ['plus d\'ATP produit', 'le NAD+ est réduit plus vite', 'le glucose s\'accumule']),
      ]),
    ],
  ),

  // ───────────────── Monde 6 : Fermentations & rendement (expert) ─────────────────
  Novel(
    id: _stage6,
    title: 'Fermentations & rendement',
    author: 'Monde 6 · Expert (type bac)',
    emoji: '🏆',
    color: 0xFF0F172A,
    levels: [
      NovelLevel(name: 'Niveau 1 · Les deux fermentations', questions: [
        _q('Dans la fermentation alcoolique, le pyruvate est décarboxylé en…', 'acétaldéhyde + CO2', ['acide lactique', 'acétyl-CoA', 'citrate']),
        _q("L'acétaldéhyde est ensuite…", 'réduit en éthanol par le NADH,H+', ['oxydé en CO2', 'transformé en glucose', 'décarboxylé']),
        _q('Le dernier accepteur des e− et H+ dans la fermentation alcoolique est…', "l'acétaldéhyde", ["l'O2", 'le pyruvate', 'le NAD+']),
        _q('Le dernier accepteur des e− et H+ dans la fermentation lactique est…', "l'acide pyruvique", ["l'acétaldéhyde", "l'O2", 'le FAD']),
        _q("Le bilan énergétique d'une fermentation est…", '2 ATP', ['36 ATP', '38 ATP', '4 ATP']),
        _q('Dans le lait, les lactobacilles transforment le glucose en…', 'acide lactique', ['éthanol', 'CO2 et H2O', 'lactose']),
        _q('La formation du yaourt s\'explique par…', "la baisse du pH (6,8 → 4,8) qui coagule les protéines du lait", ['la hausse du pH', "l'évaporation de l'eau", 'la production d\'éthanol']),
        _q('La fermentation lactique est réalisée par certaines bactéries et…', "les cellules musculaires de l'Homme", ['les chloroplastes', 'la levure de bière', 'les globules rouges']),
      ]),
      NovelLevel(name: 'Niveau 2 · Calculer le rendement', questions: [
        _q('Le rendement énergétique se calcule par…', 'r = (énergie des ATP produits / énergie totale du glucose) × 100', ['r = nombre d\'ATP × 100', 'r = 2840 / 30,5', 'r = énergie perdue × 100']),
        _q("L'oxydation complète d'une mole de glucose libère…", '2840 kJ', ['1360 kJ', '30,5 kJ', '140 kJ']),
        _q('Avec 38 ATP, le rendement de la respiration est d\'environ…', '40,8 %', ['38,7 %', '2,2 %', '100 %']),
        _q('Avec 36 ATP, le rendement de la respiration est d\'environ…', '38,7 %', ['40,8 %', '2,2 %', '50 %']),
        _q('Le rendement de la fermentation alcoolique est d\'environ…', '2,2 %', ['40 %', '20 %', '10 %']),
        _q("L'énergie encore emmagasinée dans une mole d'éthanol est…", '1360 kJ', ['0 kJ', '2840 kJ', '30,5 kJ']),
        _q("Chaleur perdue par la respiration (cas 38 ATP) : 2840 − 1159 =", '1681 kJ', ['1742 kJ', '59 kJ', '2840 kJ']),
        _q("L'énergie contenue dans les déchets minéraux CO2 et H2O est…", '0 kJ', ['140 kJ', '1360 kJ', '2840 kJ']),
      ]),
      NovelLevel(name: 'Niveau 3 · Sujet de bac (Nor. PC 2016)', questions: [
        _q('La personne NON entraînée présente…', 'moins de mitochondries et une activité enzymatique faible', ['plus de mitochondries', 'la même activité enzymatique', "plus d'ATP"]),
        _q('La personne non entraînée produit…', "plus d'acide lactique et consomme moins d'O2", ["moins d'acide lactique", "plus d'O2", 'plus de CO2']),
        _q("La fatigabilité élevée du non-entraîné s'explique par…", 'une voie anaérobie dominante → faible production d\'ATP', ['un excès d\'ATP', "un excès d'O2", 'une hyperactivité mitochondriale']),
        _q('La VMA (vitesse maximale aérobie) des fumeurs est…', 'plus faible que celle des non-fumeurs', ['plus élevée', 'identique', 'nulle']),
        _q('Chez les fumeurs, le CO se fixe sur…', "l'hémoglobine ET le complexe IV de la chaîne respiratoire", ['le glucose', 'le NAD+', 'les ribosomes']),
        _q('Le CO fixé sur le complexe IV provoque…', "l'arrêt du transfert d'électrons, l'absence de gradient de H+ et l'arrêt de la synthèse d'ATP", ["une synthèse accrue d'ATP", 'une réduction du NAD+', 'la formation de glucose']),
        _q("Après l'effort, le sang veineux des fumeurs montre…", "beaucoup d'acide lactique (500 mg/L) et un pH plus bas (7,35)", ['moins d\'acide lactique', 'un pH plus élevé', 'aucun changement']),
        _q('Les crampes des fumeurs s\'expliquent par…', 'fermentation lactique → acide lactique → baisse du pH → moins d\'ATP', ["un excès d'O2", 'une hausse du pH', "un excès d'ATP"]),
      ]),
    ],
  ),
];
