import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/models/polycopie.dart';
import '../../core/models/student.dart';
import '../../core/repositories.dart';
import '../../core/widgets/common.dart';

/// Fiche détaillée d'un élève : contact, matières, paiements, polycopiés,
/// absences.
class StudentDetailScreen extends ConsumerStatefulWidget {
  const StudentDetailScreen({super.key, required this.studentId});

  final int studentId;

  @override
  ConsumerState<StudentDetailScreen> createState() =>
      _StudentDetailScreenState();
}

class _StudentDetailScreenState extends ConsumerState<StudentDetailScreen> {
  Student? _student;
  List<StudentPolycopie>? _polycopies;
  bool _loading = true;
  String? _error;

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
      final s = await StudentsRepo.byId(widget.studentId);
      if (!mounted) return;
      setState(() {
        _student = s;
        _loading = false;
      });
      // Chargement secondaire, non bloquant : la fiche s'affiche même si les
      // polycopiés échouent.
      try {
        final polys = await PolycopieRepo.forStudent(widget.studentId);
        if (mounted) setState(() => _polycopies = polys);
      } catch (_) {}
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de charger la fiche élève.';
      });
    }
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    showSnack(context, 'Copié : $value');
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      if (mounted) showSnack(context, 'Impossible d\'ouvrir le téléphone.');
    }
  }

  Future<void> _whatsapp(String phone) async {
    // Numéros marocains 06/07 → format international 212.
    var p = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (p.startsWith('0')) p = '212${p.substring(1)}';
    final uri = Uri.parse('https://wa.me/$p');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) showSnack(context, 'Impossible d\'ouvrir WhatsApp.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider).valueOrNull;
    final canPay = perms == null ||
        perms.canAny(['payments.create', 'payments.view', 'payments.edit']);
    return Scaffold(
      appBar: AppBar(title: const Text('Fiche élève')),
      floatingActionButton: canPay && _student != null
          ? FloatingActionButton.extended(
              onPressed: () async {
                final paid = await context
                    .push<bool>('/students/${widget.studentId}/pay');
                if (paid == true) _load();
              },
              icon: const Icon(Icons.point_of_sale_rounded),
              label: const Text('Encaisser'),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _DetailShimmer();
    if (_error != null) return ErrorRetry(message: _error!, onRetry: _load);
    final s = _student!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _header(s),
          const SizedBox(height: 12),
          _statsRow(s),
          const SizedBox(height: 16),
          _contactSection(s),
          const SizedBox(height: 16),
          _subjectsSection(s),
          const SizedBox(height: 16),
          _paymentsSection(s),
          if (_polycopies != null && _polycopies!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _polycopieSection(),
          ],
          const SizedBox(height: 16),
          _absencesSection(s),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ───────────────────────────── Sections ─────────────────────────────

  Widget _header(Student s) {
    final theme = Theme.of(context);
    return OxCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          InitialsAvatar(name: s.fullName, radius: 38),
          const SizedBox(height: 12),
          Text(
            s.fullName,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            [
              s.levelName ?? 'Niveau inconnu',
              if (s.group?.isNotEmpty == true) 'Groupe ${s.group}',
            ].join(' · '),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.secondary400),
          ),
          const SizedBox(height: 8),
          // Identifiant de connexion à l'espace élève : à communiquer à la
          // famille avec le téléphone déjà enregistré au dossier.
          InkWell(
            onTap: () => _copy('${s.id}'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary500.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.badge_outlined,
                      size: 16, color: AppColors.primary600),
                  const SizedBox(width: 6),
                  Text(
                    'N° élève ${s.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.copy_rounded,
                      size: 13, color: AppColors.primary600),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              s.isActive
                  ? const StatusBadge.success('Actif')
                  : const StatusBadge.danger('Inactif'),
              if (s.free) const StatusBadge.info('Gratuit'),
              if (s.priceTotal > 0)
                StatusBadge.info('${_money(s.priceTotal)} / mois'),
              if (s.discount > 0)
                StatusBadge.warning('Remise ${_money(s.discount)}'),
            ],
          ),
          // Actions rapides : appeler / WhatsApp (élève ou responsable).
          if (s.phoneStudent?.isNotEmpty == true ||
              s.phoneRespo?.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (s.phoneStudent?.isNotEmpty == true) ...[
                  _quickAction(
                    icon: Icons.call_rounded,
                    label: 'Élève',
                    color: AppColors.success600,
                    onTap: () => _call(s.phoneStudent!),
                  ),
                  const SizedBox(width: 10),
                ],
                if (s.phoneRespo?.isNotEmpty == true) ...[
                  _quickAction(
                    icon: Icons.call_rounded,
                    label: 'Parent',
                    color: AppColors.primary600,
                    onTap: () => _call(s.phoneRespo!),
                  ),
                  const SizedBox(width: 10),
                  _quickAction(
                    icon: Icons.chat_rounded,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: () => _whatsapp(s.phoneRespo!),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Rangée de statistiques : assiduité + finances en un coup d'œil.
  Widget _statsRow(Student s) {
    final now = DateTime.now();
    final absMonth = s.absences
        .where((a) =>
            !a.isRetard &&
            a.date.month == now.month &&
            a.date.year == now.year)
        .length;
    final absTotal = s.absences.where((a) => !a.isRetard).length;
    final retards = s.absences.where((a) => a.isRetard).length;
    final totalPaid = s.payments.fold<num>(0, (sum, p) => sum + p.price);
    final totalRest = s.payments.fold<num>(0, (sum, p) => sum + p.rest);

    Widget cell(String value, String label, Color color) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary400,
                  ),
                ),
              ],
            ),
          ),
        );

    return Row(
      children: [
        cell('$absMonth',
            'Abs. ce mois${absTotal > absMonth ? ' ($absTotal an)' : ''}',
            absMonth >= 3 ? AppColors.danger600 : AppColors.warning500),
        cell('$retards', 'Retards', AppColors.primary600),
        cell(_money(totalPaid), 'Total payé', AppColors.success600),
        cell(_money(totalRest), 'Reste dû',
            totalRest > 0 ? AppColors.danger600 : AppColors.secondary400),
      ],
    );
  }

  Widget _contactSection(Student s) {
    final rows = <Widget>[];
    if (s.phoneStudent?.isNotEmpty == true) {
      rows.add(_contactRow(
        icon: Icons.smartphone_rounded,
        label: 'Téléphone élève',
        value: s.phoneStudent!,
        isPhone: true,
      ));
    }
    if (s.respo?.isNotEmpty == true) {
      rows.add(_contactRow(
        icon: Icons.family_restroom_rounded,
        label: 'Responsable',
        value: s.respo!,
        copyable: false,
      ));
    }
    if (s.phoneRespo?.isNotEmpty == true) {
      rows.add(_contactRow(
        icon: Icons.phone_rounded,
        label: 'Téléphone responsable',
        value: s.phoneRespo!,
        isPhone: true,
      ));
    }
    if (s.email?.isNotEmpty == true) {
      rows.add(_contactRow(
        icon: Icons.mail_outline_rounded,
        label: 'Email',
        value: s.email!,
      ));
    }
    if (s.address?.isNotEmpty == true) {
      rows.add(_contactRow(
        icon: Icons.location_on_outlined,
        label: 'Adresse',
        value: s.address!,
        copyable: false,
      ));
    }
    if (s.institution?.isNotEmpty == true) {
      rows.add(_contactRow(
        icon: Icons.account_balance_outlined,
        label: 'École',
        value: s.institution!,
        copyable: false,
      ));
    }

    return _section(
      title: 'Contact',
      icon: Icons.contact_phone_outlined,
      child: rows.isEmpty
          ? const _EmptyLine('Aucune information de contact.')
          : Column(children: _withDividers(rows)),
    );
  }

  Widget _contactRow({
    required IconData icon,
    required String label,
    required String value,
    bool copyable = true,
    bool isPhone = false,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: copyable ? () => _copy(value) : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary500),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.secondary400),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (isPhone) ...[
              IconButton(
                tooltip: 'Appeler',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.call_rounded,
                    size: 20, color: AppColors.success600),
                onPressed: () => _call(value),
              ),
              IconButton(
                tooltip: 'WhatsApp',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chat_rounded,
                    size: 20, color: Color(0xFF25D366)),
                onPressed: () => _whatsapp(value),
              ),
            ] else if (copyable)
              const Icon(Icons.copy_rounded,
                  size: 16, color: AppColors.secondary300),
          ],
        ),
      ),
    );
  }

  Widget _subjectsSection(Student s) {
    return _section(
      title: 'Matières',
      icon: Icons.menu_book_outlined,
      child: s.subjects.isEmpty
          ? const _EmptyLine('Aucune matière enregistrée.')
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sub in s.subjects)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sub.individual
                          ? AppColors.warning100
                          : AppColors.primary500.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sub.name ?? 'Matière',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sub.individual
                                ? const Color(0xFFB45309)
                                : AppColors.primary700,
                          ),
                        ),
                        if (sub.individual) ...[
                          const SizedBox(width: 4),
                          const Text(
                            '· indiv.',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  static const _monthsFr = [
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

  static const _categoryLabels = {
    'group': 'Groupe',
    'individual': 'Individuel',
    'polycopie': 'Polycopié',
    'book': 'Livre',
  };

  Widget _paymentsSection(Student s) {
    final theme = Theme.of(context);
    final totalPaid =
        s.payments.fold<num>(0, (sum, p) => sum + p.price);
    final totalRest = s.payments.fold<num>(0, (sum, p) => sum + p.rest);
    return _section(
      title: 'Historique de paiements',
      icon: Icons.payments_outlined,
      child: s.payments.isEmpty
          ? const _EmptyLine('Aucun paiement enregistré.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bandeau totaux.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary500.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total payé',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.secondary400)),
                            Text(_money(totalPaid),
                                style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary600)),
                          ],
                        ),
                      ),
                      Text('${s.payments.length} paiement(s)',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.secondary400)),
                      if (totalRest > 0) ...[
                        const SizedBox(width: 10),
                        StatusBadge.warning('Reste ${_money(totalRest)}'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                ..._withDividers([
                  for (final p in s.payments)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: p.rest > 0
                                  ? AppColors.warning100
                                  : AppColors.success100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              p.rest > 0
                                  ? Icons.hourglass_bottom_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 18,
                              color: p.rest > 0
                                  ? const Color(0xFFB45309)
                                  : AppColors.success600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _money(p.price),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                    ),
                                    if (p.category != null &&
                                        p.category != 'group') ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        _categoryLabels[p.category] ??
                                            p.category!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                color:
                                                    AppColors.primary600),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  [
                                    if (p.month != null && p.year != null)
                                      '${_monthsFr[(p.month! - 1).clamp(0, 11)]} ${p.year}',
                                    if (p.paymentDate != null)
                                      'payé le ${_date(p.paymentDate!)}',
                                  ].join(' · '),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.secondary400),
                                ),
                              ],
                            ),
                          ),
                          if (p.rest > 0)
                            StatusBadge.warning('Reste ${_money(p.rest)}')
                          else
                            const StatusBadge.success('Soldé'),
                        ],
                      ),
                    ),
                ]),
              ],
            ),
    );
  }

  Widget _polycopieSection() {
    final theme = Theme.of(context);
    final polys = _polycopies!;
    return _section(
      title: 'Polycopiés',
      icon: Icons.menu_book_outlined,
      child: Column(
        children: _withDividers([
          for (final p in polys)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        Text(
                          [
                            '${p.price} DH',
                            if (p.paid > 0) 'payé ${p.paid} DH',
                            if (p.autoAssigned) 'auto',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.secondary400),
                        ),
                      ],
                    ),
                  ),
                  switch (p.status) {
                    'paid' => const StatusBadge.success('Payé'),
                    'cancelled' => const StatusBadge.danger('Annulé'),
                    _ => p.remaining > 0
                        ? StatusBadge.warning('Reste ${p.remaining} DH')
                        : const StatusBadge.info('En cours'),
                  },
                ],
              ),
            ),
        ]),
      ),
    );
  }

  /// Nombre d'entrées d'assiduité affichées (le reste derrière « Voir plus »).
  int _attendanceShown = 8;

  Widget _absencesSection(Student s) {
    final theme = Theme.of(context);
    final entries = s.absences; // déjà triées du plus récent au plus ancien
    final absences = entries.where((a) => !a.isRetard).length;
    final retards = entries.where((a) => a.isRetard).length;

    return _section(
      title: 'Assiduité',
      icon: Icons.event_busy_outlined,
      child: entries.isEmpty
          ? const _EmptyLine('Aucune absence ni retard. 👏')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    absences > 0
                        ? StatusBadge.danger(
                            '$absences absence${absences > 1 ? 's' : ''}')
                        : const StatusBadge.success('0 absence'),
                    if (retards > 0)
                      StatusBadge.info(
                          '⏱ $retards retard${retards > 1 ? 's' : ''}'),
                  ],
                ),
                const SizedBox(height: 10),
                ..._withDividers([
                  for (final a in entries.take(_attendanceShown))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: a.isRetard
                                  ? AppColors.primary500
                                      .withValues(alpha: 0.1)
                                  : AppColors.danger100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              a.isRetard
                                  ? Icons.timer_rounded
                                  : Icons.event_busy_rounded,
                              size: 16,
                              color: a.isRetard
                                  ? AppColors.primary600
                                  : AppColors.danger600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('EEEE d MMMM yyyy', 'fr')
                                      .format(a.date),
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w600),
                                ),
                                if (a.matterName?.isNotEmpty == true)
                                  Text(
                                    a.matterName!,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                            color: AppColors.secondary400),
                                  ),
                              ],
                            ),
                          ),
                          if (a.isRetard)
                            StatusBadge.info(
                                '⏱ ${a.lateMinutes ?? '?'} min')
                          else if (a.isJustified)
                            const StatusBadge.success('Justifiée')
                          else
                            const StatusBadge.danger('Absente'),
                        ],
                      ),
                    ),
                ]),
                if (entries.length > _attendanceShown)
                  Center(
                    child: TextButton.icon(
                      onPressed: () => setState(
                          () => _attendanceShown += 15),
                      icon: const Icon(Icons.expand_more_rounded, size: 18),
                      label: Text(
                          'Voir plus (${entries.length - _attendanceShown} autres)'),
                    ),
                  ),
              ],
            ),
    );
  }

  // ───────────────────────────── Helpers ─────────────────────────────

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return OxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary600),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> rows) {
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      out.add(rows[i]);
      if (i < rows.length - 1) out.add(const Divider(height: 1));
    }
    return out;
  }

  static String _money(num v) {
    final s = v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(2);
    return '$s DH';
  }

  static String _date(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return DateFormat('dd/MM/yyyy').format(d);
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.secondary400),
      ),
    );
  }
}

class _DetailShimmer extends StatelessWidget {
  const _DetailShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        OxCard(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              ShimmerBox(height: 76, width: 76, radius: 38),
              SizedBox(height: 12),
              ShimmerBox(width: 180, height: 20),
              SizedBox(height: 8),
              ShimmerBox(width: 120, height: 14),
            ],
          ),
        ),
        SizedBox(height: 16),
        OxCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 110, height: 18),
              SizedBox(height: 12),
              ShimmerBox(height: 14),
              SizedBox(height: 8),
              ShimmerBox(height: 14, width: 200),
            ],
          ),
        ),
        SizedBox(height: 16),
        OxCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 110, height: 18),
              SizedBox(height: 12),
              ShimmerBox(height: 14),
              SizedBox(height: 8),
              ShimmerBox(height: 14, width: 160),
            ],
          ),
        ),
      ],
    );
  }
}
