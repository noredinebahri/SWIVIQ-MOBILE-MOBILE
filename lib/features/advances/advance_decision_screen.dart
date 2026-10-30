import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/models/advance.dart';
import '../../core/repositories.dart';
import '../../core/widgets/common.dart';

const _amber = Color(0xFFF59E0B);
const _amberDark = Color(0xFFB45309);
const _ink = Color(0xFF0B1220);

/// Page de confirmation d'une avance sur salaire (direction / assistante).
///
/// Un ticket sombre porte la demande (qui, combien, pour quel mois), la paie
/// du mois recalculée en direct dit ce qu'il restera au professeur, puis la
/// décision : confirmer (montant ajustable) ou refuser, avec une note.
class AdvanceDecisionScreen extends ConsumerStatefulWidget {
  const AdvanceDecisionScreen({super.key, required this.advanceId});

  final int advanceId;

  @override
  ConsumerState<AdvanceDecisionScreen> createState() =>
      _AdvanceDecisionScreenState();
}

class _AdvanceDecisionScreenState extends ConsumerState<AdvanceDecisionScreen> {
  TeacherAdvanceDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _deciding = false;
  final _amountCtl = TextEditingController();
  final _noteCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountCtl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await AdvanceRepo.detail(widget.advanceId);
      if (!mounted) return;
      _amountCtl.text = fmtMoney(d.advance.amount);
      setState(() {
        _detail = d;
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
        _error = 'Impossible de lire la demande.';
        _loading = false;
      });
    }
  }

  TeacherAdvance get _adv => _detail!.advance;
  AdvanceLivePayroll? get _payroll => _detail?.payroll;

  num get _amount =>
      num.tryParse(_amountCtl.text.replaceAll(',', '.').trim()) ?? 0;
  num get _gross => _payroll?.grandTotal ?? 0;
  num get _otherAdvances {
    final p = _payroll;
    if (p == null) return 0;
    return _adv.isApproved
        ? (p.advancesTotal - _adv.amount).clamp(0, double.infinity)
        : p.advancesTotal;
  }

  num get _netAfter => _gross - _otherAdvances - _amount;
  bool get _exceeds => _payroll != null && _netAfter < 0;
  bool get _changed => _amount != _adv.amount;

  Future<void> _decide({required bool approve}) async {
    if (approve && _amount <= 0) {
      showSnack(context, 'Montant invalide.', error: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Confirmer l\'avance ?' : 'Refuser la demande ?'),
        content: Text(approve
            ? '${_adv.teacherName} recevra ${fmtMoney(_amount)} DH, retenus sur sa paie de ${_adv.periodLabel}.'
            : 'La demande de ${fmtMoney(_adv.amount)} DH de ${_adv.teacherName} sera refusée et le professeur prévenu.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: approve
                ? null
                : FilledButton.styleFrom(
                    backgroundColor: AppColors.danger500),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Confirmer' : 'Refuser'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deciding = true);
    try {
      final note = _noteCtl.text.trim();
      final res = approve
          ? await AdvanceRepo.approve(_adv.id,
              note: note, amount: _changed ? _amount : null)
          : await AdvanceRepo.reject(_adv.id, note: note);
      if (!mounted) return;
      setState(() => _deciding = false);
      await _showResult(res, approve: approve);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _deciding = false);
      showSnack(context, e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deciding = false);
      showSnack(context, 'Décision non enregistrée.', error: true);
    }
  }

  Future<void> _showResult(TeacherAdvance a, {required bool approve}) {
    final color = approve ? const Color(0xFF16A34A) : AppColors.danger500;
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isDismissible: false,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(24)),
              child: Icon(
                  approve ? Icons.check_rounded : Icons.close_rounded,
                  color: Colors.white,
                  size: 44),
            ),
            const SizedBox(height: 14),
            Text(approve ? 'AVANCE CONFIRMÉE' : 'DEMANDE REFUSÉE',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    fontSize: 12,
                    color: AppColors.secondary600)),
            Text('${fmtMoney(a.amount)} DH',
                style: const TextStyle(
                    fontSize: 44, fontWeight: FontWeight.w900, height: 1.1)),
            const SizedBox(height: 6),
            Text(
              approve
                  ? '${a.teacherName} est prévenu. L\'avance sera retenue sur la paie de ${a.periodLabel}.'
                  : '${a.teacherName} est prévenu de votre décision.',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avance sur salaire')),
      body: _loading
          ? const ListShimmer()
          : _error != null
              ? ErrorRetry(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      _ticket(),
                      const SizedBox(height: 14),
                      _payrollCard(),
                      if (_adv.isPending) ...[
                        const SizedBox(height: 14),
                        _decisionCard(),
                      ],
                      if (_detail!.history.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _historyCard(),
                      ],
                    ],
                  ),
                ),
    );
  }

  // ── ticket sombre : la demande ──
  Widget _ticket() {
    final a = _adv;
    final initials = a.teacherName
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();
    final (badgeBg, badgeFg) = switch (a.status) {
      'approved' => (const Color(0x2E22C55E), const Color(0xFFBBF7D0)),
      'rejected' => (const Color(0x2EEF4444), const Color(0xFFFECACA)),
      'cancelled' => (const Color(0x2E94A3B8), const Color(0xFFE2E8F0)),
      _ => (const Color(0x2EFBBF24), const Color(0xFFFDE68A)),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_ink, Color(0xFF1A1F38), _ink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
              color: _ink.withValues(alpha: 0.45),
              blurRadius: 30,
              offset: const Offset(0, 14)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFDE68A), Color(0xFFFBBF24)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(initials.isEmpty ? 'P' : initials,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Color(0xFF1F1300))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.teacherName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17)),
                    const Text('demande une avance sur salaire',
                        style: TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: badgeBg, borderRadius: BorderRadius.circular(999)),
                child: Text(a.statusLabel.toUpperCase(),
                    style: TextStyle(
                        color: badgeFg,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(colors: [
                  Colors.white,
                  Color(0xFFFDE68A),
                  Color(0xFFFBBF24)
                ]).createShader(r),
                child: Text(fmtMoney(a.amount),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2,
                        height: 1)),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 6),
                child: Text('DH',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _darkChip(Icons.calendar_month_rounded,
                  'Paie de ${a.periodLabel}'),
              _darkChip(
                  a.requestedVia == 'mobile'
                      ? Icons.phone_android_rounded
                      : Icons.laptop_rounded,
                  a.createdAt == null
                      ? ''
                      : DateFormat('dd/MM/yyyy HH:mm').format(a.createdAt!)),
              if (_payroll != null)
                _darkChip(Icons.tune_rounded, _payroll!.modeLabel),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              a.reason == null || a.reason!.isEmpty
                  ? 'Aucun motif indiqué'
                  : '« ${a.reason} »',
              style: TextStyle(
                  color: a.reason == null ? Colors.white54 : Colors.white,
                  fontStyle:
                      a.reason == null ? FontStyle.normal : FontStyle.italic,
                  fontSize: 14,
                  height: 1.4),
            ),
          ),
          if (!a.isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                    a.isApproved
                        ? Icons.verified_rounded
                        : Icons.person_off_rounded,
                    color: const Color(0xFFFDE68A),
                    size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [
                      a.isApproved
                          ? 'Confirmée'
                          : a.isRejected
                              ? 'Refusée'
                              : 'Annulée',
                      if (a.deciderName != null) 'par ${a.deciderName}',
                      if (a.decidedAt != null)
                        'le ${DateFormat('dd/MM HH:mm').format(a.decidedAt!)}',
                      if (a.decisionNote != null) '· « ${a.decisionNote} »',
                    ].join(' '),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _darkChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  // ── paie du mois en direct ──
  Widget _payrollCard() {
    final p = _payroll;
    final theme = Theme.of(context);
    return OxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.monitor_heart_rounded, size: 18, color: _amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Paie du mois en direct · ${_adv.periodLabel}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ]),
          Text('Recalculée à l\'instant, séances en attente comprises.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.secondary400)),
          const SizedBox(height: 12),
          if (p == null)
            const Text('La paie de ce mois n\'a pas pu être calculée.',
                style: TextStyle(color: _amberDark))
          else ...[
            if (p.hourlyTotal > 0 || p.sessionCount > 0)
              _line('Séances horaires',
                  '${p.sessionCount} séances · ${fmtMoney(p.totalHours)} h',
                  fmtMoney(p.hourlyTotal),
                  dot: const Color(0xFF38BDF8)),
            if (p.enrollmentTotal > 0)
              _line('Inscriptions (pourcentage)', null,
                  fmtMoney(p.enrollmentTotal),
                  dot: const Color(0xFFA78BFA)),
            if (p.individualTotal > 0)
              _line('Cours individuels', null, fmtMoney(p.individualTotal),
                  dot: const Color(0xFFFB7185)),
            if (p.polycopiesTotal > 0)
              _line('Polycopiés', null, fmtMoney(p.polycopiesTotal),
                  dot: const Color(0xFFFBBF24)),
            const Divider(height: 18),
            _line('Total brut', null, '${fmtMoney(_gross)} DH', bold: true),
            if (_otherAdvances > 0)
              _line('Avances déjà confirmées', null,
                  '- ${fmtMoney(_otherAdvances)}',
                  color: _amberDark),
            _line('Cette avance', null, '- ${fmtMoney(_amount)}',
                color: _amberDark, bold: true),
            const SizedBox(height: 10),
            _bar(),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _exceeds
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _exceeds
                        ? const Color(0xFFFECACA)
                        : const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('NET RESTANT APRÈS CONFIRMATION',
                        style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                            color: _exceeds
                                ? const Color(0xFF991B1B)
                                : const Color(0xFF065F46))),
                  ),
                  Text('${fmtMoney(_netAfter)} DH',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: _exceeds
                              ? const Color(0xFF991B1B)
                              : const Color(0xFF065F46))),
                ],
              ),
            ),
            if (_exceeds)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'L\'avance dépasse ce que le mois rapporte à ce jour : le professeur devra le reste au centre, ou les séances à venir le couvriront.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: const Color(0xFF991B1B)),
                ),
              )
            else if (_gross == 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    'Aucune séance ni inscription comptabilisée pour ce mois pour l\'instant.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.secondary400)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _bar() {
    final gross = _gross;
    final other = gross <= 0 ? 0.0 : (_otherAdvances / gross).clamp(0.0, 1.0);
    final total = gross <= 0
        ? (_amount > 0 ? 1.0 : 0.0)
        : ((_otherAdvances + _amount) / gross).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 10,
        child: LayoutBuilder(
          builder: (ctx, c) => Stack(children: [
            Container(color: const Color(0xFFF1F5F9)),
            AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: c.maxWidth * total,
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)]))),
            AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: c.maxWidth * other,
                color: const Color(0xFFD6D3D1)),
          ]),
        ),
      ),
    );
  }

  Widget _line(String label, String? sub, String value,
      {Color? dot, Color? color, bool bold = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (dot != null) ...[
            Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                    color: dot, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                        color: color)),
                if (sub != null)
                  Text(sub,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.secondary400)),
              ],
            ),
          ),
          Text(value,
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }

  // ── décision ──
  Widget _decisionCard() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: _amber.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.verified_user_rounded, size: 18, color: _amber),
            const SizedBox(width: 8),
            Text('Votre décision',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            ],
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            decoration: InputDecoration(
              labelText: 'Montant confirmé',
              suffixText: 'DH',
              helperText: _changed
                  ? 'Montant ajusté — demandé : ${fmtMoney(_adv.amount)} DH'
                  : null,
              helperStyle: const TextStyle(color: _amberDark),
              suffixIcon: _changed
                  ? IconButton(
                      tooltip: 'Revenir au montant demandé',
                      icon: const Icon(Icons.restart_alt_rounded),
                      onPressed: () =>
                          _amountCtl.text = fmtMoney(_adv.amount),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtl,
            maxLength: 255,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Note pour le professeur (facultatif)',
              hintText: 'Ex. : versée en espèces le 5, à retirer à l\'accueil…',
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _deciding ? null : () => _decide(approve: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger600,
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Refuser',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _deciding || _amount <= 0
                      ? null
                      : () => _decide(approve: true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _deciding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded),
                  label: Text('Confirmer · ${fmtMoney(_amount)} DH',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Le professeur est prévenu aussitôt (application et WhatsApp). Une avance confirmée est retenue automatiquement sur le net du mois.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.secondary400),
          ),
        ],
      ),
    );
  }

  Widget _historyCard() {
    final theme = Theme.of(context);
    return OxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Autres demandes ${_adv.year}',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final h in _detail!.history)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(
                  h.isApproved
                      ? Icons.check_circle_rounded
                      : h.isRejected
                          ? Icons.cancel_rounded
                          : h.isPending
                              ? Icons.hourglass_top_rounded
                              : Icons.do_not_disturb_on_rounded,
                  size: 18,
                  color: h.isApproved
                      ? AppColors.success600
                      : h.isRejected
                          ? AppColors.danger500
                          : AppColors.secondary400,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(h.periodLabel)),
                Text('${fmtMoney(h.amount)} DH',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text(h.statusLabel,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.secondary400)),
              ]),
            ),
        ],
      ),
    );
  }
}
