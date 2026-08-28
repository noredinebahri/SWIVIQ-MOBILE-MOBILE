import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/models/polycopie.dart';
import '../../core/models/reference.dart';
import '../../core/repositories.dart';
import '../../core/widgets/common.dart';

/// Gestion des polycopiés (même périmètre que la section des paramètres du
/// front web) : liste avec filtres, création, modification, archivage.
/// À la création, le serveur affecte automatiquement le polycopié aux élèves
/// correspondants (niveau/groupe/matière).
class PolycopieScreen extends ConsumerStatefulWidget {
  const PolycopieScreen({super.key});

  @override
  ConsumerState<PolycopieScreen> createState() => _PolycopieScreenState();
}

class _PolycopieScreenState extends ConsumerState<PolycopieScreen> {
  List<Polycopie>? _items;
  String? _error;
  bool _loading = true;

  int? _filterLevelId;
  bool _showArchived = false;

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
      final items = await PolycopieRepo.list(
        levelId: _filterLevelId,
        actif: _showArchived ? 0 : 1,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
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
        _error = 'Impossible de charger les polycopiés.';
        _loading = false;
      });
    }
  }

  Future<void> _pickLevel() async {
    final levels = ref.read(levelsProvider).valueOrNull;
    if (levels == null) return;
    final picked = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('Tous les niveaux'),
              selected: _filterLevelId == null,
              onTap: () => Navigator.of(sheetContext).pop(-1),
            ),
            for (final l in levels.where((l) => l.actif == 1))
              ListTile(
                title: Text(l.displayName),
                selected: _filterLevelId == l.id,
                onTap: () => Navigator.of(sheetContext).pop(l.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _filterLevelId = picked == -1 ? null : picked);
    _load();
  }

  Future<void> _openEditor({Polycopie? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PolycopieEditor(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _archive(Polycopie p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archiver ce polycopié ?'),
        content: Text(
            '« ${p.name} » ne sera plus proposé aux nouvelles inscriptions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger600,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await PolycopieRepo.archive(p.id);
      if (!mounted) return;
      showSnack(context, 'Polycopié archivé.');
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final levels = ref.watch(levelsProvider).valueOrNull;
    final levelName = _filterLevelId == null
        ? null
        : levels
            ?.where((l) => l.id == _filterLevelId)
            .map((l) => l.displayName)
            .firstOrNull;
    final user = ref.watch(authProvider).user;
    final canManage = user != null && (user.isAdmin || user.role == 's');

    return Scaffold(
      appBar: AppBar(title: const Text('Polycopiés')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouveau'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  InputChip(
                    avatar: const Icon(Icons.school_outlined, size: 18),
                    label: Text(levelName ?? 'Niveau'),
                    selected: _filterLevelId != null,
                    onPressed: _pickLevel,
                    onDeleted: _filterLevelId == null
                        ? null
                        : () {
                            setState(() => _filterLevelId = null);
                            _load();
                          },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Archivés'),
                    selected: _showArchived,
                    onSelected: (v) {
                      setState(() => _showArchived = v);
                      _load();
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildList(levels, canManage)),
        ],
      ),
    );
  }

  Widget _buildList(List<Level>? levels, bool canManage) {
    if (_loading) return const ListShimmer();
    if (_error != null) {
      return ErrorRetry(message: _error!, onRetry: _load);
    }
    final items = _items ?? [];
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.menu_book_rounded,
        title: _showArchived
            ? 'Aucun polycopié archivé'
            : 'Aucun polycopié',
        subtitle: _showArchived
            ? null
            : 'Créez un polycopié : il sera automatiquement affecté aux élèves du niveau/groupe correspondant.',
      );
    }
    final levelById = {
      for (final l in (levels ?? <Level>[])) l.id: l.displayName
    };
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final p = items[i];
          return OxCard(
            onTap: canManage ? () => _openEditor(existing: p) : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: AppColors.primary700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (p.levelId != null)
                            levelById[p.levelId] ?? 'Niveau ${p.levelId}',
                          if (p.groupName != null &&
                              p.groupName!.isNotEmpty)
                            'Grp ${p.groupName}',
                          if (p.hasFile) '📎 ${p.fileName}',
                        ].join(' · '),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.secondary400),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (p.description != null &&
                          p.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          p.description!,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${p.price} DH',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary600,
                        fontSize: 16,
                      ),
                    ),
                    if (canManage && p.isActive)
                      IconButton(
                        tooltip: 'Archiver',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.archive_outlined,
                            size: 20, color: AppColors.secondary400),
                        onPressed: () => _archive(p),
                      ),
                    if (!p.isActive)
                      const StatusBadge.warning('Archivé'),
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

/// Feuille de création/modification d'un polycopié.
class _PolycopieEditor extends ConsumerStatefulWidget {
  const _PolycopieEditor({this.existing});

  final Polycopie? existing;

  @override
  ConsumerState<_PolycopieEditor> createState() => _PolycopieEditorState();
}

class _PolycopieEditorState extends ConsumerState<_PolycopieEditor> {
  late final _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _priceController = TextEditingController(
      text: widget.existing == null ? '' : '${widget.existing!.price}');
  late final _groupController =
      TextEditingController(text: widget.existing?.groupName ?? '');
  late final _descController =
      TextEditingController(text: widget.existing?.description ?? '');
  late int? _levelId = widget.existing?.levelId;
  late int? _subjectId = widget.existing?.subjectId;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _groupController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final price = num.tryParse(_priceController.text.trim());
    if (name.isEmpty || price == null) {
      showSnack(context, 'Nom et prix valides requis.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await PolycopieRepo.create(
          name: name,
          price: price,
          levelId: _levelId,
          groupName: _groupController.text.trim(),
          subjectId: _subjectId,
          description: _descController.text.trim(),
        );
      } else {
        await PolycopieRepo.update(widget.existing!.id, {
          'name': name,
          'price': price,
          'levelId': _levelId,
          'groupName': _groupController.text.trim().isEmpty
              ? null
              : _groupController.text.trim(),
          'subjectId': _subjectId,
          'description': _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
        });
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final levels = ref.watch(levelsProvider).valueOrNull ?? [];
    final maters = ref.watch(matersProvider).valueOrNull ?? [];
    final isNew = widget.existing == null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isNew ? 'Nouveau polycopié' : 'Modifier le polycopié',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (isNew) ...[
              const SizedBox(height: 6),
              Text(
                'Il sera automatiquement affecté aux élèves correspondants (niveau/groupe/matière).',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.secondary400),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom *',
                prefixIcon: Icon(Icons.menu_book_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Prix (DH) *',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _levelId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Niveau (optionnel)',
                prefixIcon: Icon(Icons.school_outlined),
              ),
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('Tous les niveaux')),
                for (final l in levels.where((l) => l.actif == 1))
                  DropdownMenuItem<int?>(
                      value: l.id, child: Text(l.displayName)),
              ],
              onChanged: (v) => setState(() => _levelId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _groupController,
              decoration: const InputDecoration(
                labelText: 'Groupe (optionnel, ex. A)',
                prefixIcon: Icon(Icons.group_outlined),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _subjectId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Matière (optionnel)',
                prefixIcon: Icon(Icons.auto_stories_outlined),
              ),
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('Toutes matières')),
                for (final m in maters)
                  DropdownMenuItem<int?>(value: m.id, child: Text(m.name)),
              ],
              onChanged: (v) => setState(() => _subjectId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optionnel)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(isNew ? 'Créer le polycopié' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
