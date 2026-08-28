import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/models/records.dart';
import '../../core/repositories.dart';
import '../../core/widgets/common.dart';

/// Tunnel de saisie des bulletins : un élève à la fois, pensé mobile
/// (chaque sauvegarde est indépendante — une coupure réseau ne perd rien).
class ReportEntryScreen extends StatefulWidget {
  const ReportEntryScreen({
    super.key,
    required this.levelId,
    required this.group,
    required this.subject,
    required this.levelName,
  });

  final int levelId;
  final String group;
  final String subject;
  final String levelName;

  @override
  State<ReportEntryScreen> createState() => _ReportEntryScreenState();
}

class _ReportEntryScreenState extends State<ReportEntryScreen> {
  List<ReportStudent>? _students;
  bool _loading = true;
  String? _error;
  bool _bulkSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _students == null;
      _error = null;
    });
    try {
      final students = await StudentReportRepo.groupStudents(
        widget.levelId,
        widget.group,
        subject: widget.subject,
      );
      if (!mounted) return;
      setState(() {
        _students = students;
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

  int get _done => (_students ?? []).where((s) => s.isDone).length;
  int get _total => (_students ?? []).length;
  int get _remaining => _total - _done;

  Future<void> _openEvalSheet(int index) async {
    final student = _students![index];
    final result = await showModalBottomSheet<StudentEvaluation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EvalSheet(
        student: student,
        levelId: widget.levelId,
        group: widget.group,
        subject: widget.subject,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _students![index] = ReportStudent(
          id: student.id,
          firstname: student.firstname,
          lastname: student.lastname,
          evaluation: result,
        );
      });
      showSnack(context, 'Enregistré ✅');
    }
  }

  Future<void> _markAllGood() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tout va bien ?'),
        content: Text(
            'Marquer les $_remaining élèves restants comme « Correct » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _bulkSaving = true);
    try {
      final created = await StudentReportRepo.markAllGood(
        widget.levelId,
        widget.group,
        subject: widget.subject,
      );
      if (!mounted) return;
      showSnack(context, '$created élève${created > 1 ? 's' : ''} marqué${created > 1 ? 's' : ''}.');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) showSnack(context, 'Une erreur est survenue.', error: true);
    } finally {
      if (mounted) setState(() => _bulkSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading && _students == null) {
      body = const ListShimmer();
    } else if (_error != null && _students == null) {
      body = ErrorRetry(message: _error!, onRetry: _load);
    } else if ((_students ?? []).isEmpty) {
      body = const EmptyState(
        icon: Icons.group_off_outlined,
        title: 'Aucun élève dans ce groupe',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _ProgressHeader(done: _done, total: _total),
            const SizedBox(height: 16),
            for (var i = 0; i < _students!.length; i++) ...[
              _StudentCard(
                student: _students![i],
                onTap: () => _openEvalSheet(i),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 60),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.levelName} — Gr. ${widget.group}',
              style: const TextStyle(fontSize: 17),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.subject,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.secondary400),
            ),
          ],
        ),
      ),
      body: body,
      bottomNavigationBar: _remaining > 0 && _students != null && _error == null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: OutlinedButton.icon(
                  onPressed: _bulkSaving ? null : _markAllGood,
                  icon: _bulkSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.done_all_rounded),
                  label: Text('Tout va bien pour le reste ($_remaining)'),
                ),
              ),
            )
          : null,
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 1.0 : done / total;
    return OxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Progression',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '$done/$total évalués',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: done == total
                          ? AppColors.success600
                          : AppColors.primary600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                color: done == total
                    ? AppColors.success500
                    : AppColors.primary500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.student, required this.onTap});

  final ReportStudent student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final evaluation = student.evaluation;

    Widget subtitle;
    if (evaluation == null) {
      subtitle = Text(
        'À évaluer',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.secondary400),
      );
    } else {
      final overall = evaluation.overall;
      final badge = switch (overall) {
        'tres_bien' => StatusBadge.success(kOverallOptions[overall] ?? 'Évalué'),
        'difficultes' =>
          StatusBadge.danger(kOverallOptions[overall] ?? 'Évalué'),
        _ => StatusBadge.info(kOverallOptions[overall] ?? 'Évalué'),
      };
      subtitle = Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          badge,
          if (evaluation.teacherGrade != null)
            Text(
              '${_formatGrade(evaluation.teacherGrade!)}/20',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
        ],
      );
    }

    return OxCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                subtitle,
              ],
            ),
          ),
          const SizedBox(width: 8),
          student.isDone
              ? const Icon(Icons.check_circle_rounded,
                  color: AppColors.success500, size: 24)
              : const Icon(Icons.chevron_right_rounded,
                  color: AppColors.secondary400),
        ],
      ),
    );
  }
}

String _formatGrade(num grade) {
  return grade == grade.roundToDouble()
      ? grade.toInt().toString()
      : grade.toStringAsFixed(1).replaceAll('.', ',');
}

/// Feuille d'évaluation d'un élève.
class _EvalSheet extends StatefulWidget {
  const _EvalSheet({
    required this.student,
    required this.levelId,
    required this.group,
    required this.subject,
  });

  final ReportStudent student;
  final int levelId;
  final String group;
  final String subject;

  @override
  State<_EvalSheet> createState() => _EvalSheetState();
}

class _EvalSheetState extends State<_EvalSheet> {
  static const _overallStyles = [
    (code: 'tres_bien', emoji: '😃', color: AppColors.success600),
    (code: 'correct', emoji: '🙂', color: AppColors.primary600),
    (code: 'difficultes', emoji: '😟', color: AppColors.danger500),
  ];

  String? _overall;
  late final Set<String> _strengths;
  late final Set<String> _concerns;
  late bool _noGrade;
  late double _grade;
  late final TextEditingController _commentController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final evaluation = widget.student.evaluation;
    _overall = evaluation?.overall;
    _strengths = {...?evaluation?.strengths};
    _concerns = {...?evaluation?.concerns};
    _noGrade = evaluation?.teacherGrade == null;
    _grade = (evaluation?.teacherGrade ?? 10).toDouble().clamp(0, 20).toDouble();
    _commentController =
        TextEditingController(text: evaluation?.teacherComment ?? '');
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_overall == null) {
      showSnack(context, 'Choisissez une impression générale.', error: true);
      return;
    }
    setState(() => _saving = true);
    final comment = _commentController.text.trim();
    try {
      await StudentReportRepo.saveEvaluation(
        studentId: widget.student.id,
        levelId: widget.levelId,
        group: widget.group,
        subject: widget.subject,
        overall: _overall!,
        strengths: _strengths.toList(),
        concerns: _concerns.toList(),
        teacherGrade: _noGrade ? null : _grade,
        teacherComment: comment.isEmpty ? null : comment,
      );
      if (!mounted) return;
      Navigator.of(context).pop(StudentEvaluation(
        overall: _overall,
        strengths: _strengths.toList(),
        concerns: _concerns.toList(),
        teacherGrade: _noGrade ? null : _grade,
        teacherComment: comment.isEmpty ? null : comment,
      ));
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) showSnack(context, 'Une erreur est survenue.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: isDark ? AppColors.secondary800 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.secondary600 : AppColors.secondary300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                InitialsAvatar(name: widget.student.fullName, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.student.fullName,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Impression générale',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final style in _overallStyles) ...[
                  Expanded(
                    child: _OverallCard(
                      emoji: style.emoji,
                      label: kOverallOptions[style.code] ?? style.code,
                      color: style.color,
                      selected: _overall == style.code,
                      onTap: () => setState(() => _overall = style.code),
                    ),
                  ),
                  if (style != _overallStyles.last) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Points forts',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in kStrengthOptions.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: _strengths.contains(entry.key),
                    selectedColor: isDark
                        ? AppColors.success600.withValues(alpha: 0.25)
                        : AppColors.success100,
                    checkmarkColor: AppColors.success600,
                    onSelected: (selected) => setState(() {
                      selected
                          ? _strengths.add(entry.key)
                          : _strengths.remove(entry.key);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              "Points d'attention",
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in kConcernOptions.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: _concerns.contains(entry.key),
                    selectedColor: isDark
                        ? AppColors.danger500.withValues(alpha: 0.25)
                        : AppColors.danger100,
                    checkmarkColor: AppColors.danger600,
                    onSelected: (selected) => setState(() {
                      selected
                          ? _concerns.add(entry.key)
                          : _concerns.remove(entry.key);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Note /20',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (!_noGrade)
                  Text(
                    '${_formatGrade(_grade)}/20',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary600,
                    ),
                  ),
              ],
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Sans note'),
              value: _noGrade,
              onChanged: (value) => setState(() => _noGrade = value),
            ),
            if (!_noGrade)
              Slider(
                value: _grade,
                min: 0,
                max: 20,
                divisions: 40,
                label: _formatGrade(_grade),
                onChanged: (value) => setState(() => _grade = value),
              ),
            const SizedBox(height: 12),
            Text(
              'Commentaire',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Remarque pour les parents (optionnel)…',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({
    required this.emoji,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: isDark ? 0.22 : 0.1)
              : (isDark ? AppColors.secondary700 : AppColors.secondary100),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? color
                    : (isDark
                        ? AppColors.secondary300
                        : AppColors.secondary600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
