import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/models/schedule.dart';
import '../../core/repositories.dart';
import '../../core/widgets/common.dart';

/// Emploi du temps — lecture seule avec filtres (config, niveau, prof, jour).
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  List<ScheduleConfig> _configs = [];
  ScheduleConfig? _selectedConfig;
  List<ScheduleSlot> _slots = [];
  bool _loading = true;
  String? _error;

  // Filtres.
  /// Niveaux couverts par le niveau supérieur choisi (vide = tous).
  List<int> _levelIds = [];
  /// Le niveau supérieur choisi lui-même : les séances saisies « par niveau
  /// supérieur » portent cet id et AUCUN levelId — sans lui, le filtre les
  /// faisait disparaître alors que ce sont justement celles du prof.
  int? _levelGroupId;
  String? _levelName;
  bool get _hasLevelFilter => _levelGroupId != null || _levelIds.isNotEmpty;
  int? _teacherId;
  String? _teacherName;
  String? _dayFilter;

  static const _dayShort = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  /// Couleur stable dérivée de la matière.
  static const _subjectPalette = [
    AppColors.primary500,
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    AppColors.warning500,
    Color(0xFF6366F1),
    AppColors.success500,
    Color(0xFFF97316),
    Color(0xFF06B6D4),
    Color(0xFFA855F7),
  ];

  Color _subjectColor(String subject) =>
      _subjectPalette[subject.hashCode.abs() % _subjectPalette.length];

  String get _todayFr {
    // DateTime.weekday : 1 = lundi … 7 = dimanche, aligné sur kScheduleDays.
    return kScheduleDays[DateTime.now().weekday - 1];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final configs = await ScheduleRepo.configs();
      ScheduleConfig? selected = _selectedConfig;
      if (selected == null && configs.isNotEmpty) {
        selected = configs.firstWhere((c) => c.isActive,
            orElse: () => configs.first);
      }
      final slots =
          await ScheduleRepo.slots(scheduleConfigId: selected?.id);
      if (!mounted) return;
      setState(() {
        _configs = configs;
        _selectedConfig = selected;
        _slots = slots;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger l\'emploi du temps.';
        _loading = false;
      });
    }
  }

  Future<void> _switchConfig(ScheduleConfig config) async {
    setState(() {
      _selectedConfig = config;
      _loading = true;
      _error = null;
    });
    try {
      final slots = await ScheduleRepo.slots(scheduleConfigId: config.id);
      if (!mounted) return;
      setState(() {
        _slots = slots;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  List<ScheduleSlot> get _filtered {
    return _slots.where((s) {
      // Filtre par NIVEAU SUPÉRIEUR : garde les créneaux de TOUTES ses
      // branches (comme l'écran Absences).
      if (_hasLevelFilter &&
          !s.matchesScope(levelGroupId: _levelGroupId, levelIds: _levelIds)) {
        return false;
      }
      if (_teacherId != null && s.userId != _teacherId) return false;
      if (_dayFilter != null && s.day != _dayFilter) return false;
      return true;
    }).toList();
  }

  /// Sélection par NIVEAU SUPÉRIEUR uniquement : un choix = toutes ses
  /// branches. Les niveaux sans rattachement restent listés dans « Autres ».
  Future<void> _pickLevel() async {
    final levels = ref.read(levelsProvider).valueOrNull;
    if (levels == null || levels.isEmpty) return;
    final groups = ref.read(levelGroupsProvider).valueOrNull ?? [];
    final actifs = levels.where((l) => l.actif == 1).toList();

    // (label, levelIds, levelGroupId). Un niveau supérieur est proposé même
    // sans branche active : ses séances existent quand même.
    final choices = <(String, List<int>, int?)>[];
    for (final g in groups) {
      final ids =
          actifs.where((l) => l.levelGroupId == g.id).map((l) => l.id).toList();
      final hasSlots = _slots.any((s) => s.levelGroupId == g.id);
      if (ids.isNotEmpty || hasSlots) choices.add((g.name, ids, g.id));
    }
    final ungrouped = actifs.where((l) => l.levelGroupId == null).toList();

    final picked = await showModalBottomSheet<(String, List<int>, int?)>(
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
                child: Text('Filtrer par niveau supérieur',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              ListTile(
                leading: const Icon(Icons.clear_all_rounded),
                title: const Text('Tous les niveaux'),
                selected: !_hasLevelFilter,
                onTap: () =>
                    Navigator.of(sheetContext).pop(('', <int>[], null)),
              ),
              for (final c in choices)
                ListTile(
                  leading: const Icon(Icons.account_tree_rounded,
                      color: AppColors.primary600),
                  title: Text(c.$1,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(c.$2.isEmpty
                      ? 'Séances du niveau supérieur'
                      : '${c.$2.length} niveau${c.$2.length > 1 ? 'x' : ''}'),
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
                        .pop((l.displayName, [l.id], null)),
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
      _levelIds = picked.$2;
      _levelGroupId = picked.$3;
      _levelName = (picked.$2.isEmpty && picked.$3 == null) ? null : picked.$1;
    });
  }

  void _pickTeacher() {
    // Profs uniques présents dans les créneaux chargés.
    final seen = <int, String>{};
    for (final s in _slots) {
      if (s.userId != null && (s.teacherName ?? '').isNotEmpty) {
        seen[s.userId!] = s.teacherName!;
      }
    }
    if (seen.isEmpty) return;
    final entries = seen.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text('Filtrer par professeur',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final e in entries)
              ListTile(
                leading: InitialsAvatar(name: e.value, radius: 18),
                title: Text(e.value),
                selected: e.key == _teacherId,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _teacherId = e.key;
                    _teacherName = e.value;
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
    // Pré-chauffe le provider pour la feuille de filtre niveau.
    ref.watch(levelsProvider);
    ref.watch(levelGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emploi du temps'),
        actions: [
          if (_configs.length > 1)
            PopupMenuButton<ScheduleConfig>(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Version de l\'emploi du temps',
              onSelected: _switchConfig,
              itemBuilder: (_) => [
                for (final c in _configs)
                  PopupMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Icon(
                          c.id == _selectedConfig?.id
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          size: 20,
                          color: AppColors.primary500,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(c.name)),
                        if (c.isActive)
                          const StatusBadge.success('Active'),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const ListShimmer();
    if (_error != null) return ErrorRetry(message: _error!, onRetry: _load);

    final filtered = _filtered;

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: filtered.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 60),
                      EmptyState(
                        icon: Icons.event_note_rounded,
                        title: 'Aucun créneau',
                        subtitle:
                            'Aucun cours ne correspond aux filtres choisis.',
                      ),
                    ],
                  )
                : _buildDaySections(filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Niveau.
          !_hasLevelFilter
              ? ActionChip(
                  avatar: const Icon(Icons.account_tree_rounded, size: 18),
                  label: const Text('Niveau supérieur'),
                  onPressed: _pickLevel,
                )
              : InputChip(
                  avatar: const Icon(Icons.account_tree_rounded, size: 18),
                  label: Text(_levelName ?? ''),
                  selected: true,
                  onPressed: _pickLevel,
                  onDeleted: () => setState(() {
                    _levelIds = [];
                    _levelGroupId = null;
                    _levelName = null;
                  }),
                ),
          const SizedBox(width: 8),
          // Professeur.
          _teacherId == null
              ? ActionChip(
                  avatar: const Icon(Icons.person_rounded, size: 18),
                  label: const Text('Professeur'),
                  onPressed: _pickTeacher,
                )
              : InputChip(
                  avatar: const Icon(Icons.person_rounded, size: 18),
                  label: Text(_teacherName ?? ''),
                  selected: true,
                  onPressed: _pickTeacher,
                  onDeleted: () => setState(() {
                    _teacherId = null;
                    _teacherName = null;
                  }),
                ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 6),
            color: Theme.of(context).dividerTheme.color,
          ),
          const SizedBox(width: 8),
          // Jours.
          for (var i = 0; i < kScheduleDays.length; i++) ...[
            FilterChip(
              label: Text(_dayShort[i]),
              selected: _dayFilter == kScheduleDays[i],
              onSelected: (sel) => setState(() {
                _dayFilter = sel ? kScheduleDays[i] : null;
              }),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildDaySections(List<ScheduleSlot> slots) {
    final byDay = <String, List<ScheduleSlot>>{};
    for (final s in slots) {
      byDay.putIfAbsent(s.day, () => []).add(s);
    }
    final days =
        kScheduleDays.where((d) => byDay.containsKey(d)).toList();
    for (final d in days) {
      byDay[d]!.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    final today = _todayFr;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: days.length,
      itemBuilder: (context, i) {
        final day = days[i];
        final isToday = day == today;
        final daySlots = byDay[day]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
              child: Row(
                children: [
                  Text(
                    day,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isToday ? AppColors.primary600 : null,
                        ),
                  ),
                  const SizedBox(width: 8),
                  if (isToday) const StatusBadge.info('Aujourd\'hui'),
                  const Spacer(),
                  Text(
                    '${daySlots.length} cours',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.secondary400),
                  ),
                ],
              ),
            ),
            for (final s in daySlots)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SlotCard(
                  slot: s,
                  color: _subjectColor(s.subject),
                  highlighted: isToday,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.color,
    required this.highlighted,
  });

  final ScheduleSlot slot;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: highlighted
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.primary300.withValues(alpha: 0.6)),
            )
          : null,
      child: OxCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Colonne horaire colorée.
            Container(
              width: 70,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    slot.startTime,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Icon(Icons.arrow_downward_rounded,
                      size: 12, color: color.withValues(alpha: 0.7)),
                  Text(
                    slot.endTime,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.subject,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (slot.scopeLabel.isNotEmpty)
                        Text(
                          slot.scopeLabel,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.secondary400),
                        ),
                      if ((slot.group ?? '').isNotEmpty)
                        StatusBadge.info('Groupe ${slot.group}'),
                    ],
                  ),
                  if ((slot.teacherName ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            size: 14, color: AppColors.secondary400),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            slot.teacherName!,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.secondary500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (slot.roomLabel.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.secondary700
                      : AppColors.secondary100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.meeting_room_rounded,
                        size: 14, color: AppColors.secondary400),
                    const SizedBox(width: 4),
                    Text(
                      slot.roomLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
