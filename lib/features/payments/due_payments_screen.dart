import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/repositories.dart';
import '../../core/widgets/common.dart';

/// Échéances de paiement — page du manager/directeur (cible de la
/// notification du soir) : élèves attendus demain, aujourd'hui, et retards
/// avec compteur de jours + relance WhatsApp envoyée par le backend.
class DuePaymentsScreen extends ConsumerStatefulWidget {
  const DuePaymentsScreen({super.key, this.initialTab = 0});

  /// 0 = Demain, 1 = Aujourd'hui, 2 = En retard.
  final int initialTab;

  @override
  ConsumerState<DuePaymentsScreen> createState() =>
      _DuePaymentsScreenState();
}

class _DuePaymentsScreenState extends ConsumerState<DuePaymentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 3, vsync: this, initialIndex: widget.initialTab);

  final Map<String, List<DueEntry>?> _lists = {
    'tomorrow': null,
    'today': null,
    'overdue': null,
  };
  final Map<String, String?> _errors = {};
  final Set<int> _reminding = {};

  static const _scopes = ['tomorrow', 'today', 'overdue'];

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _loadScope(_scopes[_tabs.index]);
    });
    _loadScope(_scopes[widget.initialTab]);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadScope(String scope, {bool force = false}) async {
    if (!force && _lists[scope] != null) return;
    setState(() => _errors[scope] = null);
    try {
      final entries = await CollectionsRepo.list(scope);
      if (!mounted) return;
      setState(() => _lists[scope] = entries);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errors[scope] = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errors[scope] = 'Impossible de charger la liste.');
    }
  }

  Future<void> _remind(DueEntry e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Relancer par WhatsApp ?'),
        content: Text(
          '${e.name}\n${e.amountDue} DH dus (${e.cyclesOwed} mois)'
          '${e.daysLate > 0 ? ' · ${e.daysLate} j de retard' : ''}\n\n'
          'Le message de relance sera envoyé au parent (${e.phone}) '
          'depuis le WhatsApp du centre.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Envoyer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _reminding.add(e.studentId));
    try {
      await CollectionsRepo.remind(e.studentId);
      if (!mounted) return;
      showSnack(context, 'Relance WhatsApp envoyée à ${e.name} ✓');
    } on ApiException catch (err) {
      if (!mounted) return;
      showSnack(context, err.message, error: true);
    } finally {
      if (mounted) setState(() => _reminding.remove(e.studentId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Échéances de paiement'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            _countTab('Demain', _lists['tomorrow']),
            _countTab('Aujourd\'hui', _lists['today']),
            _countTab('En retard', _lists['overdue']),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final scope in _scopes) _scopeView(scope),
        ],
      ),
    );
  }

  Tab _countTab(String label, List<DueEntry>? list) =>
      Tab(text: list == null ? label : '$label (${list.length})');

  Widget _scopeView(String scope) {
    final error = _errors[scope];
    final list = _lists[scope];
    if (error != null) {
      return ErrorRetry(
          message: error, onRetry: () => _loadScope(scope, force: true));
    }
    if (list == null) return const ListShimmer();
    if (list.isEmpty) {
      return EmptyState(
        icon: scope == 'overdue'
            ? Icons.celebration_rounded
            : Icons.event_available_rounded,
        title: switch (scope) {
          'tomorrow' => 'Aucune échéance demain',
          'today' => 'Aucune échéance aujourd\'hui',
          _ => 'Aucun retard de paiement 🎉',
        },
        subtitle: scope == 'overdue'
            ? 'Tous les élèves sont à jour.'
            : null,
      );
    }
    final total = list.fold<num>(0, (sum, e) => sum + e.amountDue);
    return RefreshIndicator(
      onRefresh: () => _loadScope(scope, force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Bandeau total attendu.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary600, AppColors.primary400],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white70),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${list.length} élève(s) · ${_fmtNum(total)} DH attendus',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final e in list) ...[
            _entryCard(e, showLate: scope == 'overdue'),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _entryCard(DueEntry e, {required bool showLate}) {
    final theme = Theme.of(context);
    return OxCard(
      onTap: () => context.push('/students/${e.studentId}'),
      child: Row(
        children: [
          InitialsAvatar(name: e.name, radius: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (e.levelName.isNotEmpty) e.levelName,
                    if (e.dueDate != null)
                      'échéance ${DateFormat('dd/MM').format(e.dueDate!)}',
                    // Détail sans statuts : mois non payés + restes partiels.
                    if (e.monthsOwed > 0)
                      '${e.monthsOwed} mois non payé${e.monthsOwed > 1 ? 's' : ''}',
                    if (e.restDue > 0) 'reste ${_fmtNum(e.restDue)} DH',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.secondary400),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showLate && e.daysLate > 0) ...[
                  const SizedBox(height: 4),
                  e.daysLate >= 30
                      ? StatusBadge.danger(
                          '⏳ ${e.daysLate} jours de retard')
                      : StatusBadge.warning(
                          '⏳ ${e.daysLate} jours de retard'),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_fmtNum(e.amountDue)} DH',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary600,
                  fontSize: 15,
                ),
              ),
              if (e.phone != null)
                _reminding.contains(e.studentId)
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Relancer par WhatsApp',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.chat_rounded,
                            color: Color(0xFF25D366), size: 22),
                        onPressed: () => _remind(e),
                      ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtNum(num v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2);
}
