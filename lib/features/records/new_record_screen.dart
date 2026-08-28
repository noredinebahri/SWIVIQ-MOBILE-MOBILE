import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/repositories.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/level_picker.dart';
import 'records_screen.dart' show formatMinutes;

/// Saisie d'une nouvelle séance par le professeur.
class NewRecordScreen extends ConsumerStatefulWidget {
  const NewRecordScreen({super.key});

  @override
  ConsumerState<NewRecordScreen> createState() => _NewRecordScreenState();
}

class _NewRecordScreenState extends ConsumerState<NewRecordScreen> {
  static const _presets = [30, 45, 60, 90, 120, 150, 180];

  int? _levelId;
  String? _levelLabel;
  int _minutes = 60;
  final _descController = TextEditingController();
  bool _saving = false;

  Future<void> _pickLevel() async {
    final levels = ref.read(levelsProvider).valueOrNull;
    if (levels == null || levels.isEmpty) return;
    final groups = ref.read(levelGroupsProvider).valueOrNull ?? [];
    // Sélection par NIVEAU SUPÉRIEUR (hiérarchie) plutôt que la liste à plat.
    final picked = await showLevelHierarchyPicker(
      context,
      levels: levels,
      groups: groups,
      selectedId: _levelId,
      title: 'Niveau supérieur ▸ Niveau',
    );
    if (picked == null) return;
    final groupName = groups
        .where((g) => g.id == picked.levelGroupId)
        .map((g) => g.name)
        .firstOrNull;
    setState(() {
      _levelId = picked.id;
      _levelLabel = groupName != null
          ? '$groupName · ${picked.displayName}'
          : picked.displayName;
    });
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    if (_levelId == null) {
      showSnack(context, 'Choisissez un niveau.', error: true);
      return;
    }
    if (_minutes <= 0) {
      showSnack(context, 'La durée doit être positive.', error: true);
      return;
    }
    final description = _descController.text.trim();
    if (description.isEmpty) {
      showSnack(context, 'Décrivez le contenu de la séance.', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await RecordsRepo.createRecord(
        userId: user.id,
        levelId: _levelId!,
        recordTimeMinutes: _minutes,
        description: description,
      );
      if (!mounted) return;
      await _showSuccessDialog();
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Une erreur est survenue.', error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 550),
                curve: Curves.elasticOut,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: AppColors.success100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: AppColors.success600, size: 44),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Séance enregistrée',
                style: Theme.of(dialogContext)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Elle est en attente de validation par la direction.',
                style: Theme.of(dialogContext)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.secondary400),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setMinutes(int value) {
    setState(() => _minutes = value.clamp(15, 480).toInt());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final levelsAsync = ref.watch(levelsProvider);
    ref.watch(levelGroupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle séance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bandeau d'information sur le circuit de validation.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primary500.withValues(alpha: 0.15)
                  : AppColors.primary100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: isDark ? AppColors.primary300 : AppColors.primary700,
                    size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Votre séance sera visible par la direction pour validation.',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color:
                          isDark ? AppColors.primary200 : AppColors.primary800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Niveau supérieur',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                levelsAsync.when(
                  data: (levels) => InkWell(
                    onTap: _pickLevel,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.account_tree_rounded),
                        suffixIcon: Icon(Icons.expand_more_rounded),
                      ),
                      child: Text(
                        _levelLabel ?? 'Choisir le niveau supérieur',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _levelLabel == null
                              ? AppColors.secondary400
                              : null,
                          fontWeight: _levelLabel == null
                              ? FontWeight.w400
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  loading: () => const ShimmerBox(height: 52, radius: 14),
                  error: (_, __) => Row(
                    children: [
                      const Expanded(
                        child: Text('Impossible de charger les niveaux.'),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(levelsProvider),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Durée',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      onPressed:
                          _minutes > 15 ? () => _setMinutes(_minutes - 15) : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) => ScaleTransition(
                          scale: animation,
                          child: FadeTransition(opacity: animation, child: child),
                        ),
                        child: Text(
                          formatMinutes(_minutes),
                          key: ValueKey(_minutes),
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => _setMinutes(_minutes + 15),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in _presets)
                      ChoiceChip(
                        label: Text(formatMinutes(preset)),
                        selected: _minutes == preset,
                        onSelected: (_) => _setMinutes(preset),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Contenu de la séance, chapitre, remarques…',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Enregistrement…' : 'Enregistrer la séance'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
