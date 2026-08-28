import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/models/reference.dart';
import '../../core/models/student.dart';
import '../../core/repositories.dart';
import '../../core/widgets/common.dart';

/// Liste des élèves : recherche, filtres (niveau, statut, gratuit),
/// pagination infinie, tirer-pour-rafraîchir.
class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  final List<Student> _students = [];
  int _page = 1;
  int _totalPages = 1;
  int _totalStudent = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  // Filtres actifs.
  String? _levelName;

  /// Filtre par NIVEAU SUPÉRIEUR (hiérarchie) — exclusif avec _levelName.
  int? _levelGroupId;
  String? _levelGroupName;
  int? _actif;
  String? _isFree;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(refresh: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels > pos.maxScrollExtent - 300) _loadMore();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _load(refresh: true);
    });
  }

  Future<void> _load({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    }
    try {
      final page = await StudentsRepo.list(
        page: 1,
        search: _searchController.text.trim(),
        levelName: _levelName,
        levelGroupId: _levelGroupId,
        actif: _actif,
        isFree: _isFree,
      );
      if (!mounted) return;
      setState(() {
        _students
          ..clear()
          ..addAll(page.students);
        _page = page.currentPage;
        _totalPages = page.totalPages;
        _totalStudent = page.totalStudent;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _page >= _totalPages) return;
    setState(() => _loadingMore = true);
    try {
      final page = await StudentsRepo.list(
        page: _page + 1,
        search: _searchController.text.trim(),
        levelName: _levelName,
        levelGroupId: _levelGroupId,
        actif: _actif,
        isFree: _isFree,
      );
      if (!mounted) return;
      setState(() {
        _students.addAll(page.students);
        _page = page.currentPage;
        _totalPages = page.totalPages;
        _totalStudent = page.totalStudent;
        _loadingMore = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  bool get _hasMore => _page < _totalPages;

  // ───────────────────────────── Filtres ─────────────────────────────

  /// Filtre organisé par NIVEAU SUPÉRIEUR : on peut filtrer sur tout un
  /// niveau supérieur (toutes ses branches) ou sur un niveau précis.
  Future<void> _pickLevel() async {
    // (kind: 'all' | 'group' | 'level', id, label)
    final selected =
        await showModalBottomSheet<(String, int?, String?)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final levels = ref.watch(levelsProvider);
          final groups = ref.watch(levelGroupsProvider).valueOrNull ?? [];
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
              ),
              child: levels.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Impossible de charger les niveaux : $e'),
                ),
                data: (list) {
                  final actifs =
                      list.where((l) => l.actif == 1).toList(growable: false);
                  final byGroup = <int, List<Level>>{};
                  final ungrouped = <Level>[];
                  for (final l in actifs) {
                    if (l.levelGroupId != null &&
                        groups.any((g) => g.id == l.levelGroupId)) {
                      byGroup
                          .putIfAbsent(l.levelGroupId!, () => [])
                          .add(l);
                    } else {
                      ungrouped.add(l);
                    }
                  }
                  return ListView(
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
                        selected:
                            _levelName == null && _levelGroupId == null,
                        onTap: () => Navigator.of(sheetContext)
                            .pop(('all', null, null)),
                      ),
                      for (final g in groups)
                        if ((byGroup[g.id] ?? []).isNotEmpty) ...[
                          // Le niveau supérieur lui-même est sélectionnable :
                          // filtre sur TOUTES ses branches.
                          ListTile(
                            leading: const Icon(Icons.account_tree_rounded,
                                color: AppColors.primary600),
                            title: Text(
                              g.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary600),
                            ),
                            subtitle: Text(
                                '${byGroup[g.id]!.length} niveau(x) — tout le niveau supérieur'),
                            selected: _levelGroupId == g.id,
                            trailing: _levelGroupId == g.id
                                ? const Icon(Icons.check_rounded,
                                    color: AppColors.primary600)
                                : null,
                            onTap: () => Navigator.of(sheetContext)
                                .pop(('group', g.id, g.name)),
                          ),
                          for (final Level l in byGroup[g.id]!)
                            ListTile(
                              contentPadding: const EdgeInsets.only(
                                  left: 44, right: 20),
                              dense: true,
                              leading: const Icon(Icons.school_outlined,
                                  size: 20),
                              title: Text(l.displayName),
                              selected: _levelName == l.name,
                              trailing: _levelName == l.name
                                  ? const Icon(Icons.check_rounded,
                                      color: AppColors.primary600)
                                  : null,
                              onTap: () => Navigator.of(sheetContext)
                                  .pop(('level', l.id, l.name)),
                            ),
                        ],
                      if (ungrouped.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Text(
                            'AUTRES NIVEAUX',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.secondary400,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        for (final Level l in ungrouped)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.school_outlined,
                                size: 20),
                            title: Text(l.displayName),
                            selected: _levelName == l.name,
                            trailing: _levelName == l.name
                                ? const Icon(Icons.check_rounded,
                                    color: AppColors.primary600)
                                : null,
                            onTap: () => Navigator.of(sheetContext)
                                .pop(('level', l.id, l.name)),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
    if (selected == null) return;
    setState(() {
      switch (selected.$1) {
        case 'group':
          _levelGroupId = selected.$2;
          _levelGroupName = selected.$3;
          _levelName = null;
        case 'level':
          _levelName = selected.$3;
          _levelGroupId = null;
          _levelGroupName = null;
        default:
          _levelName = null;
          _levelGroupId = null;
          _levelGroupName = null;
      }
    });
    _load(refresh: true);
  }

  Future<void> _pickStatus() async {
    final v = await _pickOption(
      title: 'Statut',
      options: const [
        (value: '__all__', label: 'Tous'),
        (value: '1', label: 'Actifs'),
        (value: '0', label: 'Inactifs'),
      ],
      current: _actif?.toString(),
    );
    if (v == null) return;
    setState(() => _actif = v == '__all__' ? null : int.parse(v));
    _load(refresh: true);
  }

  Future<void> _pickFree() async {
    final v = await _pickOption(
      title: 'Gratuit',
      options: const [
        (value: '__all__', label: 'Tous'),
        (value: 'oui', label: 'Oui'),
        (value: 'non', label: 'Non'),
      ],
      current: _isFree,
    );
    if (v == null) return;
    setState(() => _isFree = v == '__all__' ? null : v);
    _load(refresh: true);
  }

  Future<String?> _pickOption({
    required String title,
    required List<({String value, String label})> options,
    String? current,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(title,
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            for (final o in options)
              ListTile(
                title: Text(o.label),
                selected: (current ?? '__all__') == o.value,
                trailing: (current ?? '__all__') == o.value
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary600)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(o.value),
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────── UI ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider).valueOrNull;
    final canRegister = perms == null || perms.can('students.edit');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Élèves'),
            if (!_loading && _error == null)
              Text(
                '$_totalStudent élève${_totalStudent > 1 ? 's' : ''}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.secondary400),
              ),
          ],
        ),
      ),
      floatingActionButton: canRegister
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/inscription'),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Inscription'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Rechercher un élève, un téléphone…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _load(refresh: true);
                        },
                      )
                    : null,
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _filterChip(
                  label: _levelGroupName ??
                      _levelName?.trim() ??
                      'Niveau supérieur',
                  active: _levelName != null || _levelGroupId != null,
                  icon: _levelGroupId != null
                      ? Icons.account_tree_rounded
                      : Icons.school_outlined,
                  onTap: _pickLevel,
                  onClear: () {
                    setState(() {
                      _levelName = null;
                      _levelGroupId = null;
                      _levelGroupName = null;
                    });
                    _load(refresh: true);
                  },
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: _actif == null
                      ? 'Statut'
                      : (_actif == 1 ? 'Actifs' : 'Inactifs'),
                  active: _actif != null,
                  icon: Icons.toggle_on_outlined,
                  onTap: _pickStatus,
                  onClear: () {
                    setState(() => _actif = null);
                    _load(refresh: true);
                  },
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: _isFree == null
                      ? 'Gratuit'
                      : (_isFree == 'oui' ? 'Gratuit : oui' : 'Gratuit : non'),
                  active: _isFree != null,
                  icon: Icons.card_giftcard_rounded,
                  onTap: _pickFree,
                  onClear: () {
                    setState(() => _isFree = null);
                    _load(refresh: true);
                  },
                ),
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool active,
    required IconData icon,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InputChip(
      avatar: Icon(
        icon,
        size: 18,
        color: active
            ? (isDark ? AppColors.primary300 : AppColors.primary700)
            : AppColors.secondary400,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
        color: active
            ? (isDark ? AppColors.primary300 : AppColors.primary700)
            : null,
      ),
      selected: active,
      selectedColor: isDark ? AppColors.primary900 : AppColors.primary100,
      showCheckmark: false,
      onPressed: onTap,
      onDeleted: active ? onClear : null,
      deleteIconColor:
          isDark ? AppColors.primary300 : AppColors.primary700,
    );
  }

  Widget _buildList() {
    if (_loading && _students.isEmpty) return const ListShimmer();
    if (_error != null && _students.isEmpty) {
      return ErrorRetry(message: _error!, onRetry: () => _load(refresh: true));
    }
    if (_students.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun élève trouvé',
        subtitle: 'Essayez de modifier la recherche ou les filtres.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: _students.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i >= _students.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            );
          }
          return _StudentCard(
            student: _students[i],
            onTap: () => context.push('/students/${_students[i].id}'),
          );
        },
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.student, required this.onTap});

  final Student student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final absencesThisMonth = student.absences
        .where((a) =>
            !a.isRetard &&
            a.date.month == now.month &&
            a.date.year == now.year)
        .length;
    final phone = student.phoneStudent?.isNotEmpty == true
        ? student.phoneStudent
        : student.phoneRespo;

    return OxCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(name: student.fullName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        student.fullName,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Identifiant de connexion à l'espace élève.
                    Text(
                      '#${student.id}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.primary600,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        student.levelName ?? 'Niveau inconnu',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.secondary400),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (student.group?.isNotEmpty == true) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary500.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Gr. ${student.group}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (phone != null && phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_rounded,
                          size: 13, color: AppColors.secondary400),
                      const SizedBox(width: 4),
                      Text(
                        phone,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.secondary400),
                      ),
                    ],
                  ),
                ],
                if (absencesThisMonth > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.danger100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$absencesThisMonth abs. ce mois',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              student.isActive
                  ? const StatusBadge.success('Actif')
                  : const StatusBadge.danger('Inactif'),
              if (student.free) ...[
                const SizedBox(height: 6),
                const StatusBadge.info('Gratuit'),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
