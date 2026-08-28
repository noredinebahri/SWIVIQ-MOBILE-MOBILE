import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/models/absence.dart';
import '../../core/models/json_utils.dart';
import '../../core/repositories.dart';
import '../../core/widgets/common.dart';

const kFrenchMonths = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

/// Absence ou retard d'un élève (avec matière) — depuis absenceStudentByGroup.
class _StudentAbsence {
  _StudentAbsence({
    required this.dateYmd,
    this.matterId,
    this.type = 'absence',
    this.lateMinutes,
  });

  /// 'yyyy-MM-dd'
  final String dateYmd;
  final int? matterId;

  /// 'absence' | 'retard' — un retard compte comme PRÉSENT.
  final String type;
  final int? lateMinutes;

  bool get isRetard => type == 'retard';
}

/// Élève du niveau+groupe sélectionné, avec ses absences du mois en cours
/// (GET /student/absenceStudentByGroup/:levelId/:group).
class _LevelStudent {
  _LevelStudent({
    required this.id,
    required this.firstname,
    required this.lastname,
    this.levelId,
    this.levelName,
    this.group,
    List<_StudentAbsence>? absences,
    Set<int>? subjectIds,
    Set<String>? subjectNames,
    this.hasSubjectData = false,
  })  : absences = absences ?? [],
        subjectIds = subjectIds ?? {},
        subjectNames = subjectNames ?? {};

  final int id;
  final String firstname;
  final String lastname;

  /// Niveau (branche) propre de l'élève — utilisé pour le pointage quand la
  /// sélection est un niveau supérieur multi-branches.
  final int? levelId;
  final String? levelName;
  final String? group;

  /// Mutable : mis à jour de façon optimiste au pointage.
  final List<_StudentAbsence> absences;

  /// Matières choisies par l'élève (inscription/packs) — ids et noms
  /// normalisés. Vide si l'élève n'a aucune donnée de matières.
  final Set<int> subjectIds;
  final Set<String> subjectNames;
  final bool hasSubjectData;

  String get fullName => '$firstname $lastname'.trim();

  /// L'élève étudie-t-il cette matière ? Best effort sur des données
  /// hétérogènes : id exact, nom normalisé égal, ou inclusion de nom
  /// (« math » ⊂ « mathématiques »). Sans donnée matières, on considère
  /// que oui (anciens dossiers incomplets — mieux vaut montrer que cacher).
  bool studies(int materId, String? materName) {
    if (!hasSubjectData) return true;
    if (subjectIds.contains(materId)) return true;
    final target = (materName ?? '').trim().toLowerCase();
    if (target.isEmpty) return subjectIds.isEmpty && subjectNames.isEmpty;
    for (final n in subjectNames) {
      if (n == target) return true;
      if (n.length >= 3 && (target.contains(n) || n.contains(target))) {
        return true;
      }
    }
    return false;
  }
}

/// Pointage des absences — écran principal du module.
class AbsenceScreen extends ConsumerStatefulWidget {
  const AbsenceScreen({super.key});

  @override
  ConsumerState<AbsenceScreen> createState() => _AbsenceScreenState();
}

class _AbsenceScreenState extends ConsumerState<AbsenceScreen> {
  /// Sélection par NIVEAU SUPÉRIEUR : un choix = TOUS ses niveaux/branches,
  /// chargés et fusionnés en une seule liste (comme la page web list-level).
  /// Un niveau sans rattachement (ex. Anglais) reste sélectionnable seul.
  List<int> _targetLevelIds = [];
  String? _levelName;
  int? _materId;
  String? _materName;

  /// Groupe obligatoire pour le pointage : A=0, B=1, C=2, D=3, E=4 (comme le
  /// front web).
  int? _group;

  static const _groupNames = ['A', 'B', 'C', 'D', 'E'];

  late int _month;
  late int _year;
  late int _selectedDay; // -1 = vue mois.

  List<_LevelStudent> _students = [];
  List<AbsenceEntry> _absences = [];
  final Set<int> _toggling = {};

  bool _loading = false;
  String? _error;

  /// 'levelId|group' déjà chargé (évite de recharger au changement de jour).
  String? _loadedKey;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
    _selectedDay = now.day;
  }

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return now.month == _month && now.year == _year;
  }

  String get _dateYmd =>
      '$_year-${_month.toString().padLeft(2, '0')}-${_selectedDay.toString().padLeft(2, '0')}';

  Future<void> _loadData({bool force = false}) async {
    final levelIds = _targetLevelIds;
    if (levelIds.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_selectedDay == -1) {
        // Vue mois : listes de chaque niveau du niveau supérieur, fusionnées.
        final results = await Future.wait([
          for (final id in levelIds)
            AbsenceRepo.byLevel(id, _month, _year, -1),
        ]);
        if (!mounted) return;
        setState(() {
          _absences = results.expand((e) => e).toList();
          _loading = false;
        });
        return;
      }

      // Vue jour (pointage) : élèves de TOUS les niveaux du niveau supérieur
      // (fusionnés), avec leurs absences du mois — chaque élève garde son
      // propre levelId pour le pointage, comme sur le web.
      final group = _group;
      if (group == null) {
        setState(() => _loading = false);
        return;
      }
      final key = '${levelIds.join(",")}|$group';
      if (!force && key == _loadedKey && _students.isNotEmpty) {
        // Changement de jour/matière seulement : les données du mois sont
        // déjà en mémoire, pas besoin de rappeler l'API.
        setState(() => _loading = false);
        return;
      }
      final raws = await Future.wait([
        for (final id in levelIds)
          ApiClient.instance.get('/student/absenceStudentByGroup/$id/$group'),
      ]);
      final list = <dynamic>[];
      for (final raw in raws) {
        if (raw is Map && raw['payload'] is List) {
          list.addAll(raw['payload'] as List);
        } else if (raw is List) {
          list.addAll(raw);
        }
      }
      _students = list
          .whereType<Map>()
          .map((m) {
            final absences = <_StudentAbsence>[];
            if (m['absences'] is List) {
              for (final a in m['absences'] as List) {
                if (a is Map && a['asbenceDate'] != null) {
                  absences.add(_StudentAbsence(
                    dateYmd: a['asbenceDate'].toString().substring(0, 10),
                    matterId: asIntOrNull(a['matterId']),
                    type: a['type']?.toString() ?? 'absence',
                    lateMinutes: asIntOrNull(a['lateMinutes']),
                  ));
                }
              }
            }
            // Matières de l'élève : JSON hétérogène (ids, noms libres,
            // parfois doublement encodé) — parsing tolérant.
            final subjectIds = <int>{};
            final subjectNames = <String>{};
            dynamic rawSubjects = m['subjects'];
            try {
              if (rawSubjects is String && rawSubjects.trim().isNotEmpty) {
                rawSubjects = jsonDecode(rawSubjects);
                // Certains dossiers sont doublement encodés.
                if (rawSubjects is String) {
                  rawSubjects = jsonDecode(rawSubjects);
                }
              }
              if (rawSubjects is List) {
                for (final s in rawSubjects) {
                  if (s is Map) {
                    final id = asIntOrNull(s['id']);
                    if (id != null) subjectIds.add(id);
                    final name =
                        s['name']?.toString().trim().toLowerCase();
                    if (name != null && name.isNotEmpty) {
                      subjectNames.add(name);
                    }
                  } else if (s is num) {
                    subjectIds.add(s.toInt());
                  } else if (s is String && s.trim().isNotEmpty) {
                    subjectNames.add(s.trim().toLowerCase());
                  }
                }
              }
            } catch (_) {}
            return _LevelStudent(
              id: asInt(m['id']),
              firstname: m['firstname']?.toString() ?? '',
              lastname: m['lastname']?.toString() ?? '',
              levelId: asIntOrNull(m['levelId']),
              levelName: m['level'] is Map
                  ? m['level']['name']?.toString().trim()
                  : null,
              group: m['group']?.toString(),
              absences: absences,
              subjectIds: subjectIds,
              subjectNames: subjectNames,
              hasSubjectData:
                  subjectIds.isNotEmpty || subjectNames.isNotEmpty,
            );
          })
          .toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
      _loadedKey = key;

      if (!mounted) return;
      setState(() => _loading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les absences.';
        _loading = false;
      });
    }
  }

  /// Absent pour LA matière et LE jour sélectionnés uniquement : le prof
  /// suivant (autre matière) part d'une liste vierge, et chaque jour repart
  /// de zéro. Un retard compte comme présent.
  bool _isAbsent(_LevelStudent s) => s.absences.any((a) =>
      a.dateYmd == _dateYmd && a.matterId == _materId && !a.isRetard);

  /// Retard du jour pour la matière sélectionnée (null si aucun).
  _StudentAbsence? _retardOf(_LevelStudent s) {
    for (final a in s.absences) {
      if (a.dateYmd == _dateYmd && a.matterId == _materId && a.isRetard) {
        return a;
      }
    }
    return null;
  }

  /// Absences du mois pour la matière sélectionnée (badge historique) —
  /// hors retards.
  int _monthCount(_LevelStudent s) => s.absences
      .where((a) => a.matterId == _materId && !a.isRetard)
      .length;

  Future<void> _toggleAbsence(_LevelStudent s) async {
    if (_toggling.contains(s.id) || _materId == null) return;

    // Le serveur toggle LA ligne du jour+matière, retard compris : basculer
    // un élève en retard supprime son retard (il redevient simplement
    // présent), pas d'absence créée.
    final hadRetard = _retardOf(s) != null;
    final wasAbsent = _isAbsent(s);

    void removeAll() => s.absences.removeWhere(
        (a) => a.dateYmd == _dateYmd && a.matterId == _materId);
    void addAbsence() =>
        s.absences.add(_StudentAbsence(dateYmd: _dateYmd, matterId: _materId));

    final backup = List<_StudentAbsence>.from(s.absences);
    setState(() {
      _toggling.add(s.id);
      // Optimiste.
      if (hadRetard || wasAbsent) {
        removeAll();
      } else {
        addAbsence();
      }
    });
    try {
      final action = await AbsenceRepo.toggle(
        studentId: s.id,
        // Le niveau PROPRE de l'élève (la sélection peut couvrir plusieurs
        // branches d'un niveau supérieur).
        levelId: s.levelId ?? _targetLevelIds.first,
        dateYmd: _dateYmd,
        matterId: _materId,
      );
      if (!mounted) return;
      // Réconciliation avec la réponse serveur.
      setState(() {
        removeAll();
        if (action == 'created') addAbsence();
        _toggling.remove(s.id);
      });
      if (hadRetard && action == 'deleted') {
        showSnack(context, 'Retard annulé — ${s.fullName} est présent(e).');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        s.absences
          ..clear()
          ..addAll(backup); // Retour arrière.
        _toggling.remove(s.id);
      });
      showSnack(context, e.message, error: true);
    }
  }

  /// Feuille Retard : choix de la durée (10-60 min), conversion d'une
  /// absence existante le cas échéant (spec cockpit §2.4).
  Future<void> _openRetardSheet(_LevelStudent s) async {
    if (_materId == null) return;
    final wasAbsent = _isAbsent(s);
    final existing = _retardOf(s);
    var minutes = existing?.lateMinutes ?? 10;
    const options = [10, 20, 30, 45, 60];
    if (!options.contains(minutes)) minutes = 10;

    final confirmed = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⏱ Retard — ${s.fullName}',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_materName ?? ''} · ${_selectedDay.toString().padLeft(2, '0')}/${_month.toString().padLeft(2, '0')}/$_year',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.secondary400),
                ),
                if (wasAbsent) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'L\'absence pointée sera convertie en retard : l\'élève sera compté présent.',
                      style:
                          TextStyle(fontSize: 13, color: Color(0xFFB45309)),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Text('Durée du retard',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in options)
                      ChoiceChip(
                        label: Text('$m min'),
                        selected: minutes == m,
                        onSelected: (_) =>
                            setSheetState(() => minutes = m),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(sheetContext).pop(minutes),
                    icon: const Icon(Icons.timer_rounded),
                    label: Text(existing != null
                        ? 'Modifier le retard'
                        : (wasAbsent
                            ? 'Convertir en retard'
                            : 'Enregistrer le retard')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed == null) return;

    setState(() => _toggling.add(s.id));
    try {
      await AbsenceRepo.retard(
        studentId: s.id,
        levelId: s.levelId ?? _targetLevelIds.first,
        dateYmd: _dateYmd,
        lateMinutes: confirmed,
        matterId: _materId,
      );
      if (!mounted) return;
      setState(() {
        // La ligne du jour devient un retard (conversion in-place).
        s.absences.removeWhere(
            (a) => a.dateYmd == _dateYmd && a.matterId == _materId);
        s.absences.add(_StudentAbsence(
          dateYmd: _dateYmd,
          matterId: _materId,
          type: 'retard',
          lateMinutes: confirmed,
        ));
        _toggling.remove(s.id);
      });
      showSnack(context,
          wasAbsent ? 'Absence convertie en retard ✓' : 'Retard enregistré ✓');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _toggling.remove(s.id));
      showSnack(context, e.message, error: true);
    }
  }

  void _changeMonth(int delta) {
    var m = _month + delta;
    var y = _year;
    if (m > 12) {
      m = 1;
      y++;
    } else if (m < 1) {
      m = 12;
      y--;
    }
    setState(() {
      _month = m;
      _year = y;
      // Le pointage jour n'est possible que sur le mois en cours (l'API ne
      // renvoie que les absences du mois courant) : sur un autre mois on
      // bascule en vue mois (consultation).
      final now = DateTime.now();
      if (_selectedDay > 0 && (m != now.month || y != now.year)) {
        _selectedDay = -1;
      }
    });
    _loadData();
  }

  /// Sélecteur PAR NIVEAU SUPÉRIEUR uniquement (comme /absence/list-level du
  /// web) : un choix = toutes les branches du niveau supérieur d'un coup.
  /// Les niveaux sans rattachement (ex. Anglais) restent listés tels quels.
  Future<void> _pickLevel() async {
    final levels = ref.read(levelsProvider).valueOrNull;
    if (levels == null || levels.isEmpty) return;
    final groups = ref.read(levelGroupsProvider).valueOrNull ?? [];
    final actifs = levels.where((l) => l.actif == 1).toList();

    // (label, levelIds)
    final choices = <(String, List<int>)>[];
    for (final g in groups) {
      final ids = actifs
          .where((l) => l.levelGroupId == g.id)
          .map((l) => l.id)
          .toList();
      if (ids.isNotEmpty) choices.add((g.name, ids));
    }
    final ungrouped =
        actifs.where((l) => l.levelGroupId == null).toList();

    final picked = await showModalBottomSheet<(String, List<int>)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text('Choisir le niveau supérieur',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              for (final c in choices)
                ListTile(
                  leading: const Icon(Icons.account_tree_rounded,
                      color: AppColors.primary600),
                  title: Text(c.$1,
                      style:
                          const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '${c.$2.length} niveau${c.$2.length > 1 ? 'x' : ''}'),
                  selected: _levelName == c.$1,
                  trailing: _levelName == c.$1
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.primary600)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(c),
                ),
              if (ungrouped.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Text(
                    'AUTRES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary400,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                for (final l in ungrouped)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.school_outlined, size: 20),
                    title: Text(l.displayName),
                    selected: _levelName == l.displayName,
                    onTap: () => Navigator.of(sheetContext)
                        .pop((l.displayName, [l.id])),
                  ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _levelName = picked.$1;
      _targetLevelIds = picked.$2;
      // Changer de sélection invalide le groupe et les élèves.
      _group = null;
      _students = [];
      _loadedKey = null;
    });
    _loadData();
  }

  void _pickMater() {
    final maters = ref.read(matersProvider).valueOrNull;
    if (maters == null || maters.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text('Choisir la matière',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final m in maters)
              ListTile(
                leading: const Icon(Icons.menu_book_rounded),
                title: Text(m.name),
                selected: m.id == _materId,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _materId = m.id;
                    _materName = m.name;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(levelsProvider);
    ref.watch(matersProvider);
    ref.watch(levelGroupsProvider);
    final perms = ref.watch(permissionsProvider).valueOrNull;
    final canEdit = perms == null || perms.canAny(['attendance.edit']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Absences'),
        actions: [
          IconButton(
            tooltip: 'Rapport d\'assiduité',
            icon: const Icon(Icons.insights_rounded),
            onPressed: () => context.push('/absence/report'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildControls(),
          Expanded(child: _buildBody(canEdit)),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: OxCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickLevel,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary500.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.school_rounded,
                              size: 20, color: AppColors.primary600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _levelName ?? 'Niveau supérieur',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _levelName == null
                                    ? AppColors.secondary400
                                    : null,
                              ),
                            ),
                          ),
                          const Icon(Icons.expand_more_rounded,
                              color: AppColors.secondary400),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _materId == null
                    ? ActionChip(
                        avatar: const Icon(Icons.menu_book_rounded,
                            size: 16, color: Color(0xFFB45309)),
                        label: const Text('Matière *'),
                        onPressed: _pickMater,
                      )
                    : InputChip(
                        avatar: const Icon(Icons.menu_book_rounded, size: 16),
                        label: Text(
                          _materName ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: true,
                        onPressed: _pickMater,
                      ),
              ],
            ),
            const SizedBox(height: 8),
            // Groupe obligatoire (A-E) : les élèves affichés sont ceux du
            // groupe, comme sur le web.
            Row(
              children: [
                const Icon(Icons.group_rounded,
                    size: 18, color: AppColors.secondary400),
                const SizedBox(width: 8),
                const Text('Groupe *',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var g = 0; g < _groupNames.length; g++)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(_groupNames[g]),
                              selected: _group == g,
                              onSelected: (_) {
                                setState(() {
                                  _group = g;
                                  _students = [];
                                  _loadedKey = null;
                                });
                                _loadData();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _changeMonth(-1),
                ),
                Expanded(
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        '${kFrenchMonths[_month - 1]} $_year',
                        key: ValueKey('$_month-$_year'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: const Text('Mois'),
                      selected: _selectedDay == -1,
                      onSelected: (_) {
                        setState(() => _selectedDay = -1);
                        _loadData();
                      },
                    ),
                  ),
                  for (var d = 1; d <= _daysInMonth; d++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          '$d',
                          style: TextStyle(
                            fontWeight:
                                _isCurrentMonth && d == DateTime.now().day
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                          ),
                        ),
                        selected: _selectedDay == d,
                        side: _isCurrentMonth && d == DateTime.now().day
                            ? const BorderSide(
                                color: AppColors.primary500, width: 1.4)
                            : null,
                        onSelected: (_) {
                          setState(() => _selectedDay = d);
                          _loadData();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool canEdit) {
    if (_targetLevelIds.isEmpty) {
      return const EmptyState(
        icon: Icons.school_rounded,
        title: 'Sélectionnez un niveau supérieur pour commencer',
        subtitle:
            'Puis choisissez le groupe et la matière pour pointer les absences.',
      );
    }
    if (_selectedDay == -1) {
      // Vue mois : consultation globale, niveau seul suffit.
      if (_loading) return const ListShimmer();
      if (_error != null) {
        return ErrorRetry(message: _error!, onRetry: _loadData);
      }
      return _buildMonthView();
    }
    // Pointage jour : groupe ET matière obligatoires.
    if (_group == null || _materId == null) {
      return EmptyState(
        icon: Icons.rule_rounded,
        title: _group == null
            ? 'Choisissez le groupe'
            : 'Choisissez la matière',
        subtitle:
            'La liste des élèves s\'affiche une fois le groupe et la matière sélectionnés — chaque matière a son propre pointage.',
      );
    }
    if (_loading) return const ListShimmer();
    if (_error != null) return ErrorRetry(message: _error!, onRetry: _loadData);
    return _buildDayView(canEdit);
  }

  // ─────────────────────────────── Vue jour ────────────────────────────────

  Widget _buildDayView(bool canEdit) {
    if (_students.isEmpty) {
      return EmptyState(
        icon: Icons.groups_rounded,
        title: 'Aucun élève dans le groupe ${_groupNames[_group ?? 0]}',
        subtitle: 'Essayez un autre groupe de ce niveau.',
      );
    }
    // Filtre par matière : seuls les élèves inscrits à la matière choisie
    // (via leurs matières ou leur pack) apparaissent. Les dossiers sans
    // données de matières restent visibles.
    final visible = _materId == null
        ? _students
        : _students
            .where((s) => s.studies(_materId!, _materName))
            .toList();
    final hiddenCount = _students.length - visible.length;
    if (visible.isEmpty) {
      return EmptyState(
        icon: Icons.menu_book_rounded,
        title: 'Aucun élève inscrit en ${_materName ?? 'cette matière'}',
        subtitle:
            '$hiddenCount élève(s) du groupe n\'ont pas cette matière dans leur inscription.',
      );
    }
    final absentCount = visible.where(_isAbsent).length;
    final total = visible.length;
    final presenceRate = total == 0 ? 1.0 : (total - absentCount) / total;

    return RefreshIndicator(
      onRefresh: () => _loadData(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SummaryBar(
            absentCount: absentCount,
            total: total,
            presenceRate: presenceRate,
            materName: _materName,
          ),
          if (hiddenCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '$hiddenCount élève(s) masqué(s) : matière non incluse dans leur inscription.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.secondary400),
              ),
            ),
          const SizedBox(height: 12),
          for (final s in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StudentRow(
                student: s,
                absent: _isAbsent(s),
                retardMinutes: _retardOf(s)?.lateMinutes,
                monthCount: _monthCount(s),
                busy: _toggling.contains(s.id),
                canEdit: canEdit,
                onToggle: () => _toggleAbsence(s),
                onRetard: () => _openRetardSheet(s),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────── Vue mois ────────────────────────────────

  Widget _buildMonthView() {
    if (_absences.isEmpty) {
      return const EmptyState(
        icon: Icons.celebration_rounded,
        title: 'Aucune absence ce mois',
        subtitle: 'Tous les élèves ont été présents. Bravo !',
      );
    }
    // Regroupe par élève.
    final byStudent = <String, List<AbsenceEntry>>{};
    for (final a in _absences) {
      byStudent.putIfAbsent('${a.id}|${a.fullName}', () => []).add(a);
    }
    final entries = byStudent.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return RefreshIndicator(
      onRefresh: () => _loadData(force: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final name = entries[i].key.split('|').last;
          final list = entries[i].value
            ..sort((a, b) => a.date.compareTo(b.date));
          final count = list.length;
          final badge = count >= 5
              ? StatusBadge.danger('$count absences')
              : count >= 3
                  ? StatusBadge.warning('$count absences')
                  : StatusBadge.info('$count absence${count > 1 ? 's' : ''}');
          return OxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InitialsAvatar(name: name, radius: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    badge,
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in list)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.danger500.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  AppColors.danger500.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          '${a.date.day.toString().padLeft(2, '0')}/${a.date.month.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Bandeau de synthèse dégradé avec compteur animé.
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.absentCount,
    required this.total,
    required this.presenceRate,
    this.materName,
  });

  final int absentCount;
  final int total;
  final double presenceRate;
  final String? materName;

  @override
  Widget build(BuildContext context) {
    final rateColor = presenceRate >= 0.9
        ? AppColors.success500
        : presenceRate >= 0.75
            ? AppColors.warning500
            : AppColors.danger500;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary600, AppColors.primary400],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary600.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Text(
                  '$absentCount',
                  key: ValueKey(absentCount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'absent${absentCount > 1 ? 's' : ''} sur $total élèves',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${(presenceRate * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (materName != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.menu_book_rounded,
                    size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  materName!,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: presenceRate,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation(rateColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne élève avec bascule présent/absent animée.
class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.student,
    required this.absent,
    required this.busy,
    required this.canEdit,
    required this.onToggle,
    this.onRetard,
    this.retardMinutes,
    this.monthCount = 0,
  });

  final _LevelStudent student;
  final bool absent;
  final bool busy;
  final bool canEdit;
  final VoidCallback onToggle;

  /// Ouvre la feuille Retard (durée 10-60 min).
  final VoidCallback? onRetard;

  /// Durée du retard du jour pour la matière sélectionnée (null = aucun).
  final int? retardMinutes;

  /// Absences du mois pour la matière sélectionnée.
  final int monthCount;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: absent
              ? AppColors.danger500.withValues(alpha: 0.35)
              : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: OxCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: canEdit && !busy ? onToggle : null,
        child: Row(
          children: [
            InitialsAvatar(name: student.fullName, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (monthCount > 0 || retardMinutes != null) ...[
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (retardMinutes != null)
                          StatusBadge.info('⏱ Retard $retardMinutes min'),
                        if (monthCount > 0)
                          monthCount >= 3
                              ? StatusBadge.danger(
                                  '$monthCount abs. ce mois')
                              : StatusBadge.warning(
                                  '$monthCount abs. ce mois'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (canEdit && onRetard != null && !busy)
              IconButton(
                tooltip: retardMinutes != null
                    ? 'Modifier le retard'
                    : (absent
                        ? 'Convertir l\'absence en retard'
                        : 'Pointer un retard'),
                onPressed: onRetard,
                icon: Icon(
                  Icons.timer_rounded,
                  size: 24,
                  color: retardMinutes != null
                      ? AppColors.primary600
                      : AppColors.secondary300,
                ),
              ),
            if (canEdit)
              busy
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: child,
                      ),
                      child: Container(
                        key: ValueKey(absent),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: (absent
                                  ? AppColors.danger500
                                  : AppColors.success500)
                              .withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          absent
                              ? Icons.cancel_rounded
                              : Icons.check_circle_rounded,
                          color: absent
                              ? AppColors.danger500
                              : AppColors.success500,
                          size: 26,
                        ),
                      ),
                    )
            else if (absent)
              const StatusBadge.danger('Absent'),
          ],
        ),
      ),
    );
  }
}
