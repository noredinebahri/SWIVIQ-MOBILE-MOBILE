import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/models/json_utils.dart';
import '../../core/models/polycopie.dart';
import '../../core/models/student.dart';
import '../../core/repositories.dart';
import '../../core/widgets/common.dart';

/// Encaissement d'un élève — reprend exactement les flux du profil paiement
/// du front web : mensualité (grille année scolaire, méthodes de paiement
/// avec champs conditionnels), solde du reste, séances individuelles,
/// polycopiés et abonnement bibliothèque.
class StudentPaymentScreen extends ConsumerStatefulWidget {
  const StudentPaymentScreen({super.key, required this.studentId});

  final int studentId;

  @override
  ConsumerState<StudentPaymentScreen> createState() =>
      _StudentPaymentScreenState();
}

/// Méthodes de paiement du web (add.component).
const _kMethods = [
  (code: 'cash', label: 'Espèces', icon: Icons.payments_rounded),
  (code: 'cheque', label: 'Chèque', icon: Icons.edit_note_rounded),
  (code: 'virement', label: 'Virement', icon: Icons.account_balance_rounded),
  (code: 'carte', label: 'Carte', icon: Icons.credit_card_rounded),
];

const _kMonthsFr = [
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

class _StudentPaymentScreenState extends ConsumerState<StudentPaymentScreen> {
  Student? _student;
  Map<String, dynamic> _indiv = {};
  Map<String, dynamic> _library = {};
  List<StudentPolycopie> _polycopies = [];
  bool _loading = true;
  String? _error;
  bool _didPay = false;

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
      final results = await Future.wait([
        StudentsRepo.byId(widget.studentId),
        PaymentsRepo.indivStatus(widget.studentId)
            .catchError((_) => <String, dynamic>{}),
        PaymentsRepo.libraryStatus(widget.studentId)
            .catchError((_) => <String, dynamic>{}),
        PolycopieRepo.forStudent(widget.studentId)
            .catchError((_) => <StudentPolycopie>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _student = results[0] as Student;
        _indiv = results[1] as Map<String, dynamic>;
        _library = results[2] as Map<String, dynamic>;
        _polycopies = results[3] as List<StudentPolycopie>;
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
        _error = 'Impossible de charger les données de paiement.';
        _loading = false;
      });
    }
  }

  // ─────────────────── Année scolaire & statut des mois ───────────────────

  /// Mois de l'année scolaire courante : septembre → août.
  List<({int month, int year})> get _schoolYearMonths {
    final now = DateTime.now();
    final startYear = now.month >= 9 ? now.year : now.year - 1;
    return [
      for (var m = 9; m <= 12; m++) (month: m, year: startYear),
      for (var m = 1; m <= 8; m++) (month: m, year: startYear + 1),
    ];
  }

  /// Paiement groupe couvrant un mois donné (null si impayé).
  StudentPayment? _paymentOf(int month, int year) {
    for (final p in _student!.payments) {
      if (p.month == month &&
          p.year == year &&
          (p.category == null || p.category == 'group')) {
        return p;
      }
    }
    return null;
  }

  // ────────────────────────── Feuille de paiement ──────────────────────────

  /// Feuille commune : montant + méthode (champs conditionnels) + commentaire.
  /// Retourne null si annulé.
  Future<({num amount, String method, String? checkNumber, String? bankReference, String? cardLastDigits, String comment, bool whatsapp})?>
      _paymentSheet({
    required String title,
    required String subtitle,
    required num defaultAmount,
    num? referencePrice,
    bool showWhatsApp = false,
  }) async {
    final amountCtrl =
        TextEditingController(text: _fmtNum(defaultAmount));
    final checkCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final cardCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    var method = 'cash';
    var whatsapp = false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final amount = num.tryParse(
                  amountCtrl.text.trim().replaceAll(',', '.')) ??
              0;
          final rest = referencePrice == null
              ? 0
              : (referencePrice - amount).clamp(0, double.infinity);
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: Theme.of(sheetContext)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.secondary400)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    onChanged: (_) => setSheetState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Montant payé (DH) *',
                      prefixIcon: const Icon(Icons.payments_outlined),
                      helperText: referencePrice != null
                          ? 'Prix de référence : ${_fmtNum(referencePrice)} DH'
                              '${rest > 0 ? ' — reste ${_fmtNum(rest)} DH' : ' — soldé ✓'}'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Méthode de paiement',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in _kMethods)
                        ChoiceChip(
                          avatar: Icon(m.icon,
                              size: 16,
                              color: method == m.code
                                  ? AppColors.primary700
                                  : AppColors.secondary400),
                          label: Text(m.label),
                          selected: method == m.code,
                          onSelected: (_) =>
                              setSheetState(() => method = m.code),
                        ),
                    ],
                  ),
                  // Champs conditionnels selon la méthode (comme le web).
                  if (method == 'cheque') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: checkCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Numéro de chèque *',
                        prefixIcon: Icon(Icons.tag_rounded),
                      ),
                    ),
                  ],
                  if (method == 'virement') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: bankCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Référence bancaire *',
                        prefixIcon: Icon(Icons.account_balance_rounded),
                      ),
                    ),
                  ],
                  if (method == 'carte') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: cardCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: '4 derniers chiffres de la carte *',
                        prefixIcon: Icon(Icons.credit_card_rounded),
                        counterText: '',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Commentaire (optionnel)',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  if (showWhatsApp)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Envoyer le reçu par WhatsApp'),
                      value: whatsapp,
                      onChanged: (v) => setSheetState(() => whatsapp = v),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: amount <= 0
                          ? null
                          : () => Navigator.of(sheetContext).pop(true),
                      icon: const Icon(Icons.point_of_sale_rounded),
                      label: Text('Encaisser ${_fmtNum(amount)} DH'),
                      style:
                          FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result != true) return null;
    final amount =
        num.tryParse(amountCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return null;
    // Validation des champs conditionnels (mêmes règles que le web).
    if (method == 'cheque' && checkCtrl.text.trim().isEmpty) {
      if (mounted) {
        showSnack(context, 'Numéro de chèque requis.', error: true);
      }
      return null;
    }
    if (method == 'virement' && bankCtrl.text.trim().isEmpty) {
      if (mounted) {
        showSnack(context, 'Référence bancaire requise.', error: true);
      }
      return null;
    }
    if (method == 'carte' &&
        !RegExp(r'^\d{4}$').hasMatch(cardCtrl.text.trim())) {
      if (mounted) {
        showSnack(context, '4 chiffres de carte requis.', error: true);
      }
      return null;
    }
    return (
      amount: amount,
      method: method,
      checkNumber: checkCtrl.text.trim(),
      bankReference: bankCtrl.text.trim(),
      cardLastDigits: cardCtrl.text.trim(),
      comment: commentCtrl.text.trim(),
      whatsapp: whatsapp,
    );
  }

  // ─────────────────────────── Actions paiement ───────────────────────────

  Future<void> _payMonth(int month, int year) async {
    final s = _student!;
    final input = await _paymentSheet(
      title: 'Mensualité ${_kMonthsFr[month - 1]} $year',
      subtitle: '${s.fullName} · ${s.levelName ?? ''}',
      defaultAmount: s.priceTotal,
      referencePrice: s.priceTotal,
      showWhatsApp: true,
    );
    if (input == null) return;
    try {
      final res = await PaymentsRepo.saveMonth(
        studentId: s.id,
        levelId: s.levelId ?? 0,
        paymentMonth: month,
        paymentYear: year,
        price: s.priceTotal,
        amount: input.amount,
        paymentMethod: input.method,
        checkNumber: input.checkNumber,
        bankReference: input.bankReference,
        cardLastDigits: input.cardLastDigits,
        comment: input.comment,
        sendWhatsApp: input.whatsapp,
      );
      if (!mounted) return;
      _didPay = true;
      showSnack(context,
          'Paiement enregistré ✓  Réf : ${res['reference'] ?? ''}');
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    }
  }

  Future<void> _payRest(StudentPayment p) async {
    if (p.id == null) return;
    final s = _student!;
    final input = await _paymentSheet(
      title: 'Solder le reste',
      subtitle:
          '${s.fullName} · ${p.month != null ? _kMonthsFr[(p.month! - 1).clamp(0, 11)] : ''} ${p.year ?? ''} — reste ${_fmtNum(p.rest)} DH',
      defaultAmount: p.rest,
    );
    if (input == null) return;
    try {
      await PaymentsRepo.payRest(
        paymentId: p.id!,
        amount: input.amount,
        paymentMethod: input.method,
        comment: input.comment,
      );
      if (!mounted) return;
      _didPay = true;
      showSnack(context, 'Reste soldé ✓');
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    }
  }

  Future<void> _payIndiv() async {
    final s = _student!;
    final remaining = asNum(_indiv['indivRemaining']);
    final fee = asNum(_indiv['indivMonthlyFee']);
    final input = await _paymentSheet(
      title: 'Séances individuelles',
      subtitle:
          '${s.fullName} — dû mensuel ${_fmtNum(fee)} DH · reste ${_fmtNum(remaining)} DH',
      defaultAmount: remaining > 0 ? remaining : fee,
    );
    if (input == null) return;
    try {
      await PaymentsRepo.payIndividual(
        studentId: s.id,
        amount: input.amount,
        paymentMethod: input.method,
        comment: input.comment.isEmpty ? null : input.comment,
      );
      if (!mounted) return;
      _didPay = true;
      showSnack(context, 'Paiement individuel enregistré ✓');
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    }
  }

  Future<void> _payPolycopie(StudentPolycopie p) async {
    final s = _student!;
    final input = await _paymentSheet(
      title: 'Polycopié — ${p.name}',
      subtitle:
          '${s.fullName} — prix ${_fmtNum(p.price)} DH · reste ${_fmtNum(p.remaining)} DH',
      defaultAmount: p.remaining > 0 ? p.remaining : p.price,
    );
    if (input == null) return;
    try {
      await PaymentsRepo.payPolycopie(
        studentId: s.id,
        studentPolycopieId: p.assignmentId,
        amount: input.amount,
        paymentMethod: input.method,
        comment: input.comment.isEmpty ? null : input.comment,
      );
      if (!mounted) return;
      _didPay = true;
      showSnack(context, 'Polycopié payé ✓');
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    }
  }

  Future<void> _payLibrary() async {
    final s = _student!;
    final input = await _paymentSheet(
      title: 'Abonnement bibliothèque',
      subtitle: s.fullName,
      defaultAmount: 0,
    );
    if (input == null) return;
    try {
      await PaymentsRepo.payLibrary(
        studentId: s.id,
        paymentMethod: input.method,
        notes: input.comment.isEmpty ? 'Abonnement bibliothèque' : input.comment,
      );
      if (!mounted) return;
      _didPay = true;
      showSnack(context, 'Abonnement bibliothèque payé ✓');
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    }
  }

  // ─────────────────────────────────── UI ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_didPay);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Encaisser')),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const ListShimmer();
    if (_error != null) return ErrorRetry(message: _error!, onRetry: _load);
    final s = _student!;

    final withRest = s.payments.where((p) => p.rest > 0).toList();
    final indivFee = asNum(_indiv['indivMonthlyFee']);
    final indivRemaining = asNum(_indiv['indivRemaining']);
    final polysToPay =
        _polycopies.where((p) => p.status != 'cancelled').toList();
    final hasActiveLib = _library['hasActive'] == true;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // En-tête élève.
          OxCard(
            child: Row(
              children: [
                InitialsAvatar(name: s.fullName, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.fullName,
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        [
                          s.levelName ?? '',
                          '${_fmtNum(s.priceTotal)} DH / mois',
                        ].where((e) => e.isNotEmpty).join(' · '),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.secondary400),
                      ),
                    ],
                  ),
                ),
                if (s.free) const StatusBadge.info('Gratuit'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Mensualités (année scolaire) ──
          _sectionTitle('Mensualités', Icons.calendar_month_rounded),
          const SizedBox(height: 8),
          OxCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _schoolYearMonths)
                  _monthCell(m.month, m.year),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Touchez un mois impayé pour l\'encaisser. 🟢 payé · 🟠 reste dû · ⚪ impayé',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.secondary400),
          ),

          // ── Restes à solder ──
          if (withRest.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle('Restes à solder', Icons.hourglass_bottom_rounded),
            const SizedBox(height: 8),
            OxCard(
              child: Column(
                children: [
                  for (final p in withRest)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFB45309)),
                      title: Text(
                        p.month != null
                            ? '${_kMonthsFr[(p.month! - 1).clamp(0, 11)]} ${p.year ?? ''}'
                            : (p.paymentDate?.substring(0, 10) ?? 'Paiement'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                          'Payé ${_fmtNum(p.price)} DH — reste ${_fmtNum(p.rest)} DH'),
                      trailing: FilledButton(
                        onPressed: () => _payRest(p),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: const Text('Solder'),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // ── Séances individuelles ──
          if (indivFee > 0 || indivRemaining > 0) ...[
            const SizedBox(height: 16),
            _sectionTitle('Séances individuelles', Icons.person_rounded),
            const SizedBox(height: 8),
            OxCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dû mensuel : ${_fmtNum(indivFee)} DH',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        Text(
                          'Cumul payé : ${_fmtNum(asNum(_indiv['indivPaidCumulative']))} DH · reste ${_fmtNum(indivRemaining)} DH',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.secondary400),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: _payIndiv,
                    child: const Text('Payer'),
                  ),
                ],
              ),
            ),
          ],

          // ── Polycopiés ──
          if (polysToPay.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle('Polycopiés', Icons.menu_book_rounded),
            const SizedBox(height: 8),
            OxCard(
              child: Column(
                children: [
                  for (final p in polysToPay)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        p.status == 'paid'
                            ? Icons.check_circle_rounded
                            : Icons.menu_book_rounded,
                        color: p.status == 'paid'
                            ? AppColors.success500
                            : AppColors.primary600,
                      ),
                      title: Text(p.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${_fmtNum(p.price)} DH — payé ${_fmtNum(p.paid)} DH'),
                      trailing: p.status == 'paid' || p.remaining <= 0
                          ? const StatusBadge.success('Payé')
                          : FilledButton(
                              onPressed: () => _payPolycopie(p),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 38),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14),
                              ),
                              child: Text('${_fmtNum(p.remaining)} DH'),
                            ),
                    ),
                ],
              ),
            ),
          ],

          // ── Bibliothèque ──
          const SizedBox(height: 16),
          _sectionTitle('Bibliothèque', Icons.local_library_rounded),
          const SizedBox(height: 8),
          OxCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasActiveLib
                            ? 'Abonnement actif'
                            : 'Aucun abonnement actif',
                        style:
                            const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (hasActiveLib)
                        Text(
                          '${asInt(_library['daysRemaining'])} jour(s) restant(s)',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.secondary400),
                        ),
                    ],
                  ),
                ),
                hasActiveLib
                    ? const StatusBadge.success('Actif')
                    : FilledButton(
                        onPressed: _payLibrary,
                        child: const Text('Payer'),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary600),
        const SizedBox(width: 8),
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _monthCell(int month, int year) {
    final payment = _paymentOf(month, year);
    final now = DateTime.now();
    final isCurrent = month == now.month && year == now.year;
    final isPaid = payment != null && payment.rest <= 0;
    final isPartial = payment != null && payment.rest > 0;

    final bg = isPaid
        ? AppColors.success100
        : isPartial
            ? AppColors.warning100
            : Theme.of(context).brightness == Brightness.dark
                ? AppColors.secondary700.withValues(alpha: 0.4)
                : AppColors.secondary100;
    final fg = isPaid
        ? AppColors.success600
        : isPartial
            ? const Color(0xFFB45309)
            : AppColors.secondary600;

    return InkWell(
      onTap: payment == null
          ? () => _payMonth(month, year)
          : isPartial
              ? () => _payRest(payment)
              : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent ? AppColors.primary500 : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: Column(
          children: [
            Text(
              _kMonthsFr[month - 1].substring(0, 4),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isPaid
                  ? '✓ ${_fmtNum(payment.price)}'
                  : isPartial
                      ? 'reste ${_fmtNum(payment.rest)}'
                      : '—',
              style: TextStyle(fontSize: 11, color: fg),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtNum(num v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2);
}
