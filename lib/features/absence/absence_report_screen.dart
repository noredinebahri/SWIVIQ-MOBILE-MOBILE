import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/models/absence.dart';
import '../../core/repositories.dart';
import '../../core/widgets/common.dart';
import 'absence_screen.dart' show kFrenchMonths;

/// Rapport d'assiduité par niveau — statistiques et détail par élève.
class AbsenceReportScreen extends ConsumerStatefulWidget {
  const AbsenceReportScreen({super.key});

  @override
  ConsumerState<AbsenceReportScreen> createState() =>
      _AbsenceReportScreenState();
}

class _AbsenceReportScreenState extends ConsumerState<AbsenceReportScreen> {
  List<AbsenceLevelSummary> _levels = [];
  int? _levelId;
  late int _month;
  late int _year;

  AbsenceLevelReport? _report;
  bool _loadingLevels = true;
  bool _loadingReport = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
    _loadLevels();
  }

  Future<void> _loadLevels() async {
    setState(() {
      _loadingLevels = true;
      _error = null;
    });
    try {
      final levels = await AbsenceRepo.reportLevels();
      if (!mounted) return;
      setState(() {
        _levels = levels;
        _loadingLevels = false;
        if (levels.isNotEmpty && _levelId == null) {
          _levelId = levels.first.id;
        }
      });
      if (_levelId != null) _loadReport();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loadingLevels = false;
      });
    }
  }

  Future<void> _loadReport() async {
    final levelId = _levelId;
    if (levelId == null) return;
    setState(() {
      _loadingReport = true;
      _error = null;
    });
    try {
      final report = await AbsenceRepo.levelReport(levelId, _month, _year);
      if (!mounted) return;
      setState(() {
        _report = report;
        _loadingReport = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loadingReport = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger le rapport.';
        _loadingReport = false;
      });
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
    });
    _loadReport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rapport d\'assiduité')),
      body: _loadingLevels
          ? const ListShimmer()
          : _levels.isEmpty
              ? (_error != null
                  ? ErrorRetry(message: _error!, onRetry: _loadLevels)
                  : const EmptyState(
                      icon: Icons.insights_rounded,
                      title: 'Aucun niveau',
                      subtitle: 'Aucune donnée d\'assiduité disponible.',
                    ))
              : Column(
                  children: [
                    _buildControls(),
                    Expanded(child: _buildReport()),
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
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final l in _levels)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('${l.name} (${l.studentCount})'),
                        selected: l.id == _levelId,
                        onSelected: (_) {
                          setState(() => _levelId = l.id);
                          _loadReport();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _changeMonth(-1),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${kFrenchMonths[_month - 1]} $_year',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReport() {
    if (_loadingReport) return const ListShimmer();
    if (_error != null) return ErrorRetry(message: _error!, onRetry: _loadReport);
    final report = _report;
    if (report == null) {
      return const EmptyState(
        icon: Icons.insights_rounded,
        title: 'Sélectionnez un niveau',
      );
    }

    final students = [...report.students]
      ..sort((a, b) => b.totalAbsences.compareTo(a.totalAbsences));

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _buildSummaryGrid(report.summary),
          const SizedBox(height: 12),
          if (students.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.celebration_rounded,
                title: 'Aucune absence',
                subtitle: 'Aucun élève absent sur cette période.',
              ),
            )
          else
            for (final s in students)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StudentReportCard(student: s),
              ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(AbsenceReportSummary s) {
    final rate = s.attendanceRate.toDouble();
    final rateColor = rate >= 90
        ? AppColors.success500
        : rate >= 75
            ? AppColors.warning500
            : AppColors.danger500;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: [
        _StatTile(
          icon: Icons.groups_rounded,
          label: 'Élèves',
          value: '${s.totalStudents}',
          color: AppColors.primary500,
        ),
        _StatTile(
          icon: Icons.event_busy_rounded,
          label: 'Absences',
          value: '${s.totalAbsences}',
          color: AppColors.danger500,
        ),
        _StatTile(
          icon: Icons.stacked_line_chart_rounded,
          label: 'Moyenne / élève',
          value: s.avgAbsences.toStringAsFixed(1),
          color: AppColors.warning500,
        ),
        _StatTile(
          icon: Icons.verified_rounded,
          label: 'Assiduité',
          value: '${rate.toStringAsFixed(0)}%',
          color: rateColor,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return OxCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondary400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte élève dépliable : statistiques, dates d'absence, contact parent.
class _StudentReportCard extends StatefulWidget {
  const _StudentReportCard({required this.student});

  final AbsenceStudentReport student;

  @override
  State<_StudentReportCard> createState() => _StudentReportCardState();
}

class _StudentReportCardState extends State<_StudentReportCard> {
  bool _expanded = false;

  StatusBadge get _behaviorBadge => switch (widget.student.behaviorLevel) {
        'excellent' => const StatusBadge.success('Excellent'),
        'good' => const StatusBadge.info('Bien'),
        'warning' => const StatusBadge.warning('À surveiller'),
        'critical' => const StatusBadge.danger('Critique'),
        _ => const StatusBadge.info('—'),
      };

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final rate = s.attendanceRate.toDouble();
    final rateColor = rate >= 90
        ? AppColors.success500
        : rate >= 75
            ? AppColors.warning500
            : AppColors.danger500;

    return OxCard(
      padding: const EdgeInsets.all(14),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: s.studentName, radius: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.studentName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _behaviorBadge,
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more_rounded,
                    color: AppColors.secondary400),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _countChip('${s.totalAbsences} abs.', AppColors.secondary500),
              const SizedBox(width: 6),
              _countChip(
                  '${s.justifiedAbsences} justifiées', AppColors.success600),
              const SizedBox(width: 6),
              _countChip('${s.unjustifiedAbsences} injustifiées',
                  AppColors.danger600),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (rate / 100).clamp(0.0, 1.0).toDouble(),
                    minHeight: 5,
                    backgroundColor:
                        AppColors.secondary200.withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation(rateColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${rate.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: rateColor,
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _buildExpanded(s),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _countChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildExpanded(AbsenceStudentReport s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        if (s.absenceDates.isNotEmpty) ...[
          const Text(
            'Dates d\'absence',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.secondary400,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in s.absenceDates)
                Tooltip(
                  message: d.isJustified
                      ? 'Justifiée${(d.notes ?? '').isNotEmpty ? ' — ${d.notes}' : ''}'
                      : 'Non justifiée',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: d.isJustified
                            ? AppColors.success500.withValues(alpha: 0.5)
                            : AppColors.danger500.withValues(alpha: 0.5),
                      ),
                      color: (d.isJustified
                              ? AppColors.success500
                              : AppColors.danger500)
                          .withValues(alpha: 0.06),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          d.isJustified
                              ? Icons.check_rounded
                              : Icons.priority_high_rounded,
                          size: 12,
                          color: d.isJustified
                              ? AppColors.success600
                              : AppColors.danger600,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatDate(d.date),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: d.isJustified
                                ? AppColors.success600
                                : AppColors.danger600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if ((s.parentName ?? '').isNotEmpty ||
            (s.parentPhone ?? '').isNotEmpty) ...[
          const Text(
            'Contact parent',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.secondary400,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.family_restroom_rounded,
                  size: 18, color: AppColors.secondary400),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [
                    if ((s.parentName ?? '').isNotEmpty) s.parentName!,
                    if ((s.parentPhone ?? '').isNotEmpty) s.parentPhone!,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if ((s.parentPhone ?? '').isNotEmpty)
                IconButton(
                  tooltip: 'Copier le numéro',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: s.parentPhone!));
                    showSnack(context, 'Numéro copié');
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }
}
