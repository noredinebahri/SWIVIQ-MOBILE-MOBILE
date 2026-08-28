import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/models/records.dart';
import '../../core/repositories.dart';
import '../../core/widgets/common.dart';

const _monthsFr = [
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

/// Groupes à évaluer pour le mois choisi (tunnel bulletins, étape 1).
class ReportGroupsScreen extends StatefulWidget {
  const ReportGroupsScreen({super.key});

  @override
  State<ReportGroupsScreen> createState() => _ReportGroupsScreenState();
}

class _ReportGroupsScreenState extends State<ReportGroupsScreen> {
  late int _month;
  late int _year;
  List<ReportGroup>? _groups;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await StudentReportRepo.myGroups(month: _month, year: _year);
      if (!mounted) return;
      setState(() {
        _groups = groups;
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

  void _shiftMonth(int delta) {
    var month = _month + delta;
    var year = _year;
    if (month < 1) {
      month = 12;
      year--;
    } else if (month > 12) {
      month = 1;
      year++;
    }
    setState(() {
      _month = month;
      _year = year;
    });
    _load();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month == now.month && _year == now.year;
  }

  Future<void> _openGroup(ReportGroup group) async {
    await context.push(Uri(
      path: '/reports/entry',
      queryParameters: {
        'levelId': '${group.levelId}',
        'group': group.group,
        'subject': group.subject,
        'levelName': group.levelName,
      },
    ).toString());
    // Au retour, la progression a pu changer.
    _load();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading && _groups == null) {
      body = const ListShimmer();
    } else if (_error != null) {
      body = ErrorRetry(message: _error!, onRetry: _load);
    } else if ((_groups ?? []).isEmpty) {
      body = const EmptyState(
        icon: Icons.assignment_outlined,
        title: 'Aucun groupe à évaluer ce mois',
        subtitle:
            'Les groupes issus de votre emploi du temps apparaîtront ici.',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: _groups!.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final group = _groups![index];
            return _GroupCard(group: group, onTap: () => _openGroup(group));
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Bulletins')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: OxCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _shiftMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${_monthsFr[_month - 1]} $_year',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _shiftMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          ),
          if (!_isCurrentMonth)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 15, color: AppColors.secondary400),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'La saisie se fait sur le mois en cours.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.secondary400),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onTap});

  final ReportGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final done = group.remaining == 0;
    final progressColor = done ? AppColors.success500 : AppColors.primary500;

    return OxCard(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: group.progress,
                  strokeWidth: 5,
                  backgroundColor: isDark
                      ? AppColors.secondary700
                      : AppColors.secondary200,
                  color: progressColor,
                ),
                Center(
                  child: Text(
                    '${(group.progress * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: progressColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${group.levelName} — Groupe ${group.group}',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.primary500.withValues(alpha: 0.18)
                            : AppColors.primary100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        group.subject,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.primary300
                              : AppColors.primary700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${group.done}/${group.total} évalués',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.secondary400),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          done
              ? const StatusBadge.success('Terminé')
              : StatusBadge.danger('${group.remaining} restants'),
        ],
      ),
    );
  }
}
