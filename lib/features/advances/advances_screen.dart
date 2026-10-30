import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/models/advance.dart';
import '../../core/repositories.dart';
import '../../core/widgets/common.dart';

const _amber = Color(0xFFF59E0B);

/// Boîte de réception des avances sur salaire (direction / assistante).
/// Chaque demande en attente s'ouvre sur la page de confirmation.
class AdvancesScreen extends ConsumerStatefulWidget {
  const AdvancesScreen({super.key});

  @override
  ConsumerState<AdvancesScreen> createState() => _AdvancesScreenState();
}

class _AdvancesScreenState extends ConsumerState<AdvancesScreen> {
  List<TeacherAdvance> _rows = [];
  int _pending = 0;
  bool _loading = true;
  String? _error;
  String _tab = 'pending';

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
      final (rows, pending) = await AdvanceRepo.list(status: _tab);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _pending = pending;
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
        _error = 'Impossible de lire les demandes.';
        _loading = false;
      });
    }
  }

  Future<void> _open(TeacherAdvance a) async {
    final changed = await context.push<bool>('/avances/${a.id}');
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _rows.fold<num>(0, (s, a) => s + a.amount);
    return Scaffold(
      appBar: AppBar(title: const Text('Avances sur salaire')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'pending',
                  label: Text(_pending > 0 ? 'Attente ($_pending)' : 'Attente'),
                ),
                const ButtonSegment(value: 'approved', label: Text('Confirmées')),
                const ButtonSegment(value: 'rejected', label: Text('Refusées')),
                const ButtonSegment(value: 'all', label: Text('Toutes')),
              ],
              selected: {_tab},
              showSelectedIcon: false,
              style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onSelectionChanged: (s) {
                setState(() => _tab = s.first);
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const ListShimmer()
                : _error != null
                    ? ErrorRetry(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _rows.isEmpty
                            ? ListView(children: [
                                const SizedBox(height: 60),
                                EmptyState(
                                  icon: _tab == 'pending'
                                      ? Icons.inbox_rounded
                                      : Icons.folder_open_rounded,
                                  title: _tab == 'pending'
                                      ? 'Aucune demande en attente'
                                      : 'Aucune demande',
                                  subtitle:
                                      'Les professeurs demandent une avance depuis « Mes statistiques & solde ».',
                                ),
                              ])
                            : ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 32),
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 10),
                                    child: Row(children: [
                                      Text('${_rows.length} demande(s)',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                  color: AppColors
                                                      .secondary400)),
                                      const Spacer(),
                                      Text('${fmtMoney(total)} DH',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                  fontWeight:
                                                      FontWeight.w800)),
                                    ]),
                                  ),
                                  for (final a in _rows) ...[
                                    _AdvanceCard(
                                        advance: a, onTap: () => _open(a)),
                                    const SizedBox(height: 10),
                                  ],
                                ],
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _AdvanceCard extends StatelessWidget {
  const _AdvanceCard({required this.advance, required this.onTap});

  final TeacherAdvance advance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = advance;
    final theme = Theme.of(context);
    final accent = a.isApproved
        ? AppColors.success600
        : a.isRejected
            ? AppColors.danger500
            : a.isPending
                ? _amber
                : AppColors.secondary300;
    final initials = a.teacherName
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();
    return OxCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 5,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFFDE68A), Color(0xFFFBBF24)]),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(initials.isEmpty ? 'P' : initials,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F1300))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.teacherName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                            [
                              a.periodLabel,
                              if (a.createdAt != null)
                                DateFormat('dd/MM HH:mm').format(a.createdAt!),
                            ].join(' · '),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.secondary400),
                          ),
                        ],
                      ),
                    ),
                    switch (a.status) {
                      'approved' => StatusBadge.success(a.statusLabel),
                      'rejected' => StatusBadge.danger(a.statusLabel),
                      'pending' => StatusBadge.warning(a.statusLabel),
                      _ => StatusBadge.info(a.statusLabel),
                    },
                  ]),
                  const SizedBox(height: 10),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(fmtMoney(a.amount),
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            height: 1)),
                    const SizedBox(width: 4),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 2),
                      child: Text('DH',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary400)),
                    ),
                    const Spacer(),
                    if (a.isPending)
                      const Icon(Icons.arrow_forward_rounded, color: _amber),
                  ]),
                  if (a.reason != null && a.reason!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('« ${a.reason} »',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: AppColors.secondary600)),
                  ],
                  if (a.isPending &&
                      a.payrollSnapshot != null &&
                      a.amount > a.payrollSnapshot!) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 15, color: AppColors.danger500),
                      const SizedBox(width: 4),
                      Text(
                          'Dépasse le brut à la demande (${fmtMoney(a.payrollSnapshot!)} DH)',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.danger500)),
                    ]),
                  ],
                  if (a.deciderName != null && !a.isPending) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${a.deciderName}${a.decidedAt != null ? ' · ${DateFormat('dd/MM HH:mm').format(a.decidedAt!)}' : ''}${a.decisionNote != null ? ' · « ${a.decisionNote} »' : ''}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.secondary400),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
