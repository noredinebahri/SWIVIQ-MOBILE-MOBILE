import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/models/records.dart';
import '../../core/repositories.dart';
import '../../core/widgets/common.dart';

/// "1h30", "45 min", "2h" — format lisible d'une durée en minutes.
String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
}

/// Liste des séances : le prof voit les siennes, la direction voit tout.
class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  List<TeacherRecord>? _records;
  bool _loading = true;
  String? _error;

  /// 0 = toutes, 1 = en attente, 2 = validées.
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    // La direction arrive pour valider : on ouvre directement sur les
    // séances en attente (les 29 en attente seraient sinon noyées parmi
    // les ~1800 validées, triées par date).
    final user = ref.read(authProvider).user;
    if (user != null && user.isAdmin) _filter = 1;
    _load();
  }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    setState(() {
      _loading = _records == null;
      _error = null;
    });
    try {
      final records = user.isAdmin
          ? await RecordsRepo.allRecords()
          : await RecordsRepo.myRecords(user.id);
      records.sort((a, b) {
        // Les séances en attente d'abord (celles que la direction doit
        // traiter), puis par date décroissante.
        if (a.isValidated != b.isValidated) {
          return a.isValidated ? 1 : -1;
        }
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });
      if (!mounted) return;
      setState(() {
        _records = records;
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
        _error = 'Une erreur est survenue.';
        _loading = false;
      });
    }
  }

  List<TeacherRecord> get _filtered {
    final records = _records ?? [];
    return switch (_filter) {
      1 => records.where((r) => !r.isValidated).toList(),
      2 => records.where((r) => r.isValidated).toList(),
      _ => records,
    };
  }

  Future<void> _openNewRecord() async {
    await context.push('/records/new');
    _load();
  }

  /// Ids des séances en cours de validation (spinner sur le bouton).
  final Set<int> _validating = {};

  /// Validation par la direction (directeur ou manager). Le backend notifie
  /// le prof (WhatsApp) et l'app mobile du prof détecte la validation par
  /// polling → notification locale avec le solde du mois.
  Future<void> _validate(TeacherRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Valider cette séance ?'),
        content: Text(
          '${record.teacherName ?? 'Professeur'} · '
          '${record.levelName ?? ''} · ${formatMinutes(record.recordTime)}\n\n'
          'La séance sera comptée dans le solde du professeur et il en sera notifié.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _validating.add(record.id));
    try {
      await RecordsRepo.validate(record);
      if (!mounted) return;
      showSnack(context, 'Séance validée ✓ — le professeur sera notifié.');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _validating.remove(record.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final perms = ref.watch(permissionsProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final showBulletins = perms == null
        ? true
        : perms.canAny(['reports.create', 'reports.view']) || user.isTeacher;
    final showFab =
        user.isTeacher || (perms != null && perms.can('teachers.new_record'));

    Widget body;
    if (_loading && _records == null) {
      body = const ListShimmer();
    } else if (_error != null && _records == null) {
      body = ErrorRetry(message: _error!, onRetry: _load);
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _HeroSummary(records: _records ?? []),
            if (user.isTeacher) ...[
              const SizedBox(height: 12),
              _StatsCard(onTap: () => context.push('/records/stats')),
            ],
            if (showBulletins) ...[
              const SizedBox(height: 12),
              _BulletinsCard(onTap: () => context.push('/reports')),
            ],
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(
                    value: 0, label: Text('Toutes (${_records?.length ?? 0})')),
                ButtonSegment(
                    value: 1,
                    label: Text(
                        'En attente (${(_records ?? []).where((r) => !r.isValidated).length})')),
                ButtonSegment(
                    value: 2,
                    label: Text(
                        'Validées (${(_records ?? []).where((r) => r.isValidated).length})')),
              ],
              selected: {_filter},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
            const SizedBox(height: 12),
            if (_filtered.isEmpty)
              EmptyState(
                icon: Icons.fact_check_outlined,
                title: 'Aucune séance',
                subtitle: _filter == 0
                    ? 'Les séances enregistrées apparaîtront ici.'
                    : 'Aucune séance dans ce filtre.',
                action: showFab
                    ? FilledButton.icon(
                        onPressed: _openNewRecord,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Nouvelle séance'),
                      )
                    : null,
              )
            else
              for (final record in _filtered) ...[
                _RecordCard(
                  record: record,
                  showTeacher: user.isAdmin,
                  validating: _validating.contains(record.id),
                  // Seuls directeur (d) et manager (m) valident.
                  onValidate: user.isAdmin && !record.isValidated
                      ? () => _validate(record)
                      : null,
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(user.isTeacher ? 'Mes séances' : 'Séances'),
      ),
      body: body,
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              onPressed: _openNewRecord,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouvelle séance'),
            )
          : null,
    );
  }
}

/// Carte dégradée : résumé du mois en cours.
class _HeroSummary extends StatelessWidget {
  const _HeroSummary({required this.records});

  final List<TeacherRecord> records;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = records
        .where((r) =>
            r.createdAt != null &&
            r.createdAt!.year == now.year &&
            r.createdAt!.month == now.month)
        .toList();
    final totalMinutes =
        month.fold<int>(0, (sum, r) => sum + r.recordTime);
    final validated = month.where((r) => r.isValidated).length;
    final pending = month.length - validated;
    final hours = totalMinutes / 60;
    final hoursLabel = hours == hours.roundToDouble()
        ? hours.toInt().toString()
        : hours.toStringAsFixed(1).replaceAll('.', ',');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary600, AppColors.primary400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary600.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                'Ce mois-ci',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _HeroStat(value: '${month.length}', label: 'séances'),
              const SizedBox(width: 28),
              _HeroStat(value: '${hoursLabel}h', label: 'de cours'),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(
                icon: Icons.verified_rounded,
                label: '$validated validée${validated > 1 ? 's' : ''}',
              ),
              _HeroChip(
                icon: Icons.hourglass_top_rounded,
                label: '$pending en attente',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Accès rapide à la saisie des bulletins du mois.
class _BulletinsCard extends StatelessWidget {
  const _BulletinsCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OxCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primary500.withValues(alpha: 0.18)
                  : AppColors.primary100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.assignment_rounded,
                color: AppColors.primary600, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulletins des élèves',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Saisir les évaluations du mois',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.secondary400),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.secondary400),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.showTeacher,
    this.onValidate,
    this.validating = false,
  });

  final TeacherRecord record;
  final bool showTeacher;

  /// Non-null quand l'utilisateur peut valider cette séance (direction).
  final VoidCallback? onValidate;
  final bool validating;

  @override
  Widget build(BuildContext context) {
    final accent =
        record.isValidated ? AppColors.success500 : AppColors.warning500;
    final dateLabel = record.createdAt == null
        ? ''
        : DateFormat('dd/MM/yyyy · HH:mm').format(record.createdAt!);

    return OxCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showTeacher && record.teacherName != null) ...[
                      Row(
                        children: [
                          InitialsAvatar(name: record.teacherName!, radius: 13),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              record.teacherName!,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      record.recordDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (record.levelName != null)
                          _MiniChip(
                            icon: Icons.school_rounded,
                            label: record.levelName!,
                          ),
                        _MiniChip(
                          icon: Icons.schedule_rounded,
                          label: formatMinutes(record.recordTime),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dateLabel,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.secondary400),
                          ),
                        ),
                        record.isValidated
                            ? const StatusBadge.success('Validée')
                            : const StatusBadge.warning('En attente'),
                      ],
                    ),
                    if (onValidate != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: validating ? null : onValidate,
                          icon: validating
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.verified_rounded, size: 18),
                          label: Text(validating
                              ? 'Validation…'
                              : 'Valider la séance'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            backgroundColor: AppColors.success600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Accès aux statistiques et au rapport PDF du professeur.
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OxCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.success500.withValues(alpha: 0.18)
                  : AppColors.success100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.success600, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mes statistiques & solde',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Solde du mois, détail des séances, rapport PDF',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.secondary400),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.secondary400),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.secondary700 : AppColors.secondary100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.secondary400),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.secondary200 : AppColors.secondary600,
            ),
          ),
        ],
      ),
    );
  }
}
