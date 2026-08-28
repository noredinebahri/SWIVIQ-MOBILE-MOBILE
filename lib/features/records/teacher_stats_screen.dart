import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/models/records.dart';
import '../../core/repositories.dart';
import '../../core/widgets/common.dart';
import 'records_screen.dart' show formatMinutes;

/// Statistiques du professeur : paie officielle du serveur (moteur de paie),
/// filtrable par mois/année, avec génération et téléchargement du rapport PDF
/// (et envoi WhatsApp optionnel) — même périmètre que l'écran records du web.
class TeacherStatsScreen extends ConsumerStatefulWidget {
  const TeacherStatsScreen({super.key, this.teacherId, this.teacherName});

  /// Si null : le prof connecté. La direction peut passer un autre prof.
  final int? teacherId;
  final String? teacherName;

  @override
  ConsumerState<TeacherStatsScreen> createState() =>
      _TeacherStatsScreenState();
}

class _TeacherStatsScreenState extends ConsumerState<TeacherStatsScreen> {
  TeacherPayroll? _payroll;
  bool _loading = true;
  String? _error;

  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  /// false = mois sélectionné, true = tout l'historique.
  bool _allTime = false;
  bool _includePending = true;

  bool _generatingReport = false;

  static const _monthNames = [
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

  int get _teacherId =>
      widget.teacherId ?? ref.read(authProvider).user?.id ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_teacherId == 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payroll = await RecordsRepo.payroll(
        _teacherId,
        month: _allTime ? null : _month,
        year: _allTime ? null : _year,
        includePending: _includePending,
      );
      if (!mounted) return;
      setState(() {
        _payroll = payroll;
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
        _error = 'Impossible de calculer la paie.';
        _loading = false;
      });
    }
  }

  // ─────────────────────── Rapport PDF ───────────────────────

  Future<void> _openReportSheet() async {
    var periodType = 'month';
    var weekNumber = 1;
    var sendWhatsApp = false;
    final weeksInMonth =
        (DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day / 7)
            .ceil();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rapport de séances',
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'PDF généré par le serveur pour ${_monthNames[DateTime.now().month - 1]} ${DateTime.now().year}.',
                style: Theme.of(sheetContext)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.secondary400),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'month', label: Text('Mois complet')),
                  ButtonSegment(value: 'week', label: Text('Semaine')),
                ],
                selected: {periodType},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    setSheetState(() => periodType = s.first),
              ),
              if (periodType == 'week') ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var w = 1; w <= weeksInMonth; w++)
                      ChoiceChip(
                        label: Text('Semaine $w'),
                        selected: weekNumber == w,
                        onSelected: (_) =>
                            setSheetState(() => weekNumber = w),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Envoyer aussi par WhatsApp'),
                subtitle: const Text(
                    'Le serveur envoie le PDF sur le WhatsApp du professeur'),
                value: sendWhatsApp,
                onChanged: (v) => setSheetState(() => sendWhatsApp = v),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _generateReport(
                    periodType: periodType,
                    weekNumber: periodType == 'week' ? weekNumber : null,
                    sendWhatsApp: sendWhatsApp,
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Générer le rapport'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateReport({
    required String periodType,
    int? weekNumber,
    required bool sendWhatsApp,
  }) async {
    setState(() => _generatingReport = true);
    try {
      final response = await RecordsRepo.generateReport(
        teacherId: _teacherId,
        periodType: periodType,
        weekNumber: weekNumber,
        sendWhatsApp: sendWhatsApp,
      );
      final pdfBase64 = response['pdf']?.toString();
      if (pdfBase64 == null || pdfBase64.isEmpty) {
        throw ApiException('Le serveur n\'a pas renvoyé de PDF.');
      }
      final bytes = base64Decode(pdfBase64);
      final dir = await getTemporaryDirectory();
      final fileName = response['fileName']?.toString() ??
          'rapport_professeur_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      setState(() => _generatingReport = false);

      final wa = response['whatsapp'];
      if (wa is Map && wa['success'] == true) {
        showSnack(context, 'Rapport généré — envoyé par WhatsApp ✓');
      } else if (sendWhatsApp && wa is Map && wa['success'] != true) {
        showSnack(context,
            'Rapport généré — échec WhatsApp : ${wa['error'] ?? 'inconnu'}',
            error: true);
      }

      // Partage/enregistrement : le prof choisit (WhatsApp, Drive, Fichiers…).
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Rapport de séances',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _generatingReport = false);
      showSnack(context, e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _generatingReport = false);
      showSnack(context, 'Impossible de générer le rapport.', error: true);
    }
  }

  // ─────────────────────────── UI ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final name = widget.teacherName;
    return Scaffold(
      appBar: AppBar(
        title: Text(name == null ? 'Mes statistiques' : 'Stats · $name'),
      ),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _generatingReport ? null : _openReportSheet,
            icon: _generatingReport
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(_generatingReport
                ? 'Génération en cours…'
                : 'Télécharger le rapport PDF'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _filtersCard(),
          const SizedBox(height: 16),
          if (_loading)
            const OxCard(
              child: Column(
                children: [
                  ShimmerBox(height: 90, radius: 14),
                  SizedBox(height: 12),
                  ShimmerBox(height: 52, radius: 12),
                  SizedBox(height: 8),
                  ShimmerBox(height: 52, radius: 12),
                ],
              ),
            )
          else if (_error != null)
            ErrorRetry(message: _error!, onRetry: _load)
          else if (_payroll != null) ...[
            _soldeCard(_payroll!),
            const SizedBox(height: 16),
            _sessionsCard(_payroll!),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _filtersCard() {
    return OxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_outlined,
                  size: 18, color: AppColors.secondary400),
              const SizedBox(width: 8),
              Text(
                'Période',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Par mois')),
              ButtonSegment(value: true, label: Text('Tout')),
            ],
            selected: {_allTime},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              setState(() => _allTime = s.first);
              _load();
            },
          ),
          if (!_allTime) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<int>(
                    initialValue: _month,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Mois', isDense: true),
                    items: [
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(
                            value: m, child: Text(_monthNames[m - 1])),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _month = v);
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    initialValue: _year,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Année', isDense: true),
                    items: [
                      for (var y = DateTime.now().year - 2;
                          y <= DateTime.now().year + 1;
                          y++)
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _year = v);
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Inclure les séances en attente'),
            value: _includePending,
            onChanged: (v) {
              setState(() => _includePending = v);
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _soldeCard(TeacherPayroll p) {
    final theme = Theme.of(context);
    final hoursLabel = p.totalHours == p.totalHours.roundToDouble()
        ? p.totalHours.toInt().toString()
        : p.totalHours.toStringAsFixed(1).replaceAll('.', ',');
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
              const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                _allTime
                    ? 'Solde total'
                    : 'Solde · ${_monthNames[_month - 1]} $_year',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${_fmtMoney(p.grandTotal)} DH',
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _whiteChip(Icons.event_rounded, '${p.sessionCount} séances'),
              _whiteChip(Icons.schedule_rounded, '${hoursLabel}h de cours'),
              if (p.enrollmentLevelCount > 0)
                _whiteChip(Icons.groups_rounded,
                    'Inscriptions ${_fmtMoney(p.enrollmentTotal)} DH'),
            ],
          ),
          if (p.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final w in p.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('⚠️ $w',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white70)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _whiteChip(IconData icon, String label) {
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

  Widget _sessionsCard(TeacherPayroll p) {
    final theme = Theme.of(context);
    if (p.sessions.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy_rounded,
        title: 'Aucune séance sur la période',
        subtitle: 'Changez de mois ou incluez les séances en attente.',
      );
    }
    return OxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Détail des séances',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < p.sessions.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.sessions[i].description.isEmpty
                              ? 'Séance'
                              : p.sessions[i].description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          [
                            if (p.sessions[i].date != null)
                              DateFormat('dd/MM/yyyy')
                                  .format(p.sessions[i].date!),
                            formatMinutes(p.sessions[i].minutes),
                            '${_fmtMoney(p.sessions[i].pricePerHour)} DH/h',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.secondary400),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_fmtMoney(p.sessions[i].amount)} DH',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary600,
                        ),
                      ),
                      if (p.sessions[i].pending)
                        const StatusBadge.warning('En attente'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _fmtMoney(num v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2);
}
