import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/models/inscription.dart';
import '../../core/models/json_utils.dart';
import '../../core/models/reference.dart';
import '../../core/repositories.dart';
import '../../core/widgets/common.dart';

/// Formulaire d'inscription — parité fonctionnelle avec le front web :
/// packs de matières à prix fixe OU choix par matière (avec prix groupe et
/// prix individuel/heure), séances individuelles configurables, options
/// payantes (extras), remises multi-matières. Les formules de prix sont
/// portées telles quelles depuis inscription.component.ts (calculateTotal).
class InscriptionScreen extends ConsumerStatefulWidget {
  const InscriptionScreen({super.key});

  @override
  ConsumerState<InscriptionScreen> createState() => _InscriptionScreenState();
}

/// Configuration d'une matière sélectionnée (mêmes champs que le web).
class _SubjectSel {
  bool individual = false;
  bool indivOnly = false;
  int? teacherId;

  /// Heures de chaque séance individuelle (défaut : 1 séance de 2 h).
  List<double> sessionHours = [2];

  double get indivHours =>
      sessionHours.fold(0.0, (sum, h) => sum + h);
}

class _InscriptionScreenState extends ConsumerState<InscriptionScreen> {
  InscriptionConfig? _config;
  bool _loadingConfig = true;
  String? _configError;

  final _firstnameController = TextEditingController();
  final _lastnameController = TextEditingController();
  final _phoneStudentController = TextEditingController();
  final _respoController = TextEditingController();
  final _phoneRespoController = TextEditingController();

  String? _school;
  String? _neighborhood;
  int? _levelId;
  int? _cycleId;

  /// 'manual' (par matière) ou 'pack'.
  String _selectionMode = 'manual';
  SubjectPack? _selectedPack;

  /// materId → configuration de sélection.
  final Map<int, _SubjectSel> _sel = {};

  /// Extras cochés (ids).
  final Set<String> _extrasSel = {};

  /// Professeurs pour les cours individuels ({id, firstname, lastname}).
  List<Map<String, dynamic>> _teachers = [];

  String? _referralSource;
  bool _submitting = false;
  int _formEpoch = 0;

  static const _referralOptions = [
    (code: 'social_ads', label: 'Réseaux sociaux'),
    (code: 'word_of_mouth', label: 'Bouche à oreille'),
    (code: 'passerby', label: 'Passant'),
    (code: 'google', label: 'Google'),
    (code: 'referral', label: 'Parrainage'),
  ];

  static const _categoryLabels = {
    'general': 'Général',
    'communication': 'Communication',
    'language': 'Langues',
  };

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _firstnameController.dispose();
    _lastnameController.dispose();
    _phoneStudentController.dispose();
    _respoController.dispose();
    _phoneRespoController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loadingConfig = true;
      _configError = null;
    });
    try {
      final config = await InscriptionRepo.config();
      if (!mounted) return;
      setState(() {
        _config = config;
        _loadingConfig = false;
      });
      _loadTeachers();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingConfig = false;
        _configError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingConfig = false;
        _configError = 'Impossible de charger la configuration.';
      });
    }
  }

  Future<void> _loadTeachers() async {
    try {
      final data = await ApiClient.instance.get('/individuel/teachers');
      final list = data is Map && data['teachers'] is List
          ? data['teachers'] as List
          : const [];
      if (!mounted) return;
      setState(() {
        _teachers = list
            .whereType<Map>()
            .map((t) => Map<String, dynamic>.from(t))
            .toList();
      });
    } catch (_) {
      // Optionnel : sans liste de profs, le sélecteur est simplement masqué.
    }
  }

  // ───────────────────────── Prix (port du web) ─────────────────────────

  num _groupPrice(int materId) {
    final c = _config;
    final lvl = _levelId;
    if (c == null || lvl == null) return 0;
    return c.priceFor(lvl, materId);
  }

  num _indivPrice(int materId) {
    final c = _config;
    final lvl = _levelId;
    if (c == null || lvl == null) return 0;
    return c.priceFor(lvl, materId, individual: true);
  }

  /// Même logique que calculateTotal() du front.
  ({num subtotal, num packDiscount, num extrasTotal, num total})
      _computePrice() {
    final c = _config;
    final lvl = _levelId;
    num extrasTotal = 0;
    if (c != null) {
      for (final e in c.extras) {
        if (_extrasSel.contains(e.id)) extrasTotal += e.price;
      }
    }
    if (c == null || lvl == null) {
      return (subtotal: 0, packDiscount: 0, extrasTotal: extrasTotal, total: extrasTotal);
    }

    // Mode pack : prix fixe du pack + séances individuelles en supplément.
    final pack = _selectedPack;
    if (_selectionMode == 'pack' && pack != null) {
      num calc = pack.price;
      _sel.forEach((id, s) {
        if (s.individual) calc += _indivPrice(id) * s.indivHours;
      });
      return (
        subtotal: calc,
        packDiscount: 0,
        extrasTotal: extrasTotal,
        total: calc + extrasTotal,
      );
    }

    // Mode manuel.
    num groupTotal = 0;
    num indivTotal = 0;
    _sel.forEach((id, s) {
      if (s.individual) {
        indivTotal += _indivPrice(id) * s.indivHours;
        if (!s.indivOnly) groupTotal += _groupPrice(id);
      } else {
        groupTotal += _groupPrice(id);
      }
    });
    final calc = groupTotal + indivTotal;

    num packDiscount = 0;
    final groupCount = _sel.length;
    if (groupCount > 1) {
      final candidates = c.discounts
          .where((d) => d.levelId == lvl && groupCount >= d.minSubjects)
          .toList()
        ..sort((a, b) => b.minSubjects.compareTo(a.minSubjects));
      if (candidates.isNotEmpty) {
        packDiscount =
            (groupTotal * candidates.first.discountPercent / 100).round();
      }
    }

    return (
      subtotal: calc,
      packDiscount: packDiscount,
      extrasTotal: extrasTotal,
      total: calc - packDiscount + extrasTotal,
    );
  }

  /// Remise en cours (bannière) — sur les matières en groupe uniquement.
  PackDiscount? _currentDiscount() {
    final c = _config;
    final lvl = _levelId;
    if (c == null || lvl == null) return null;
    final groupCount =
        _sel.entries.where((e) => !e.value.individual).length;
    final candidates = c.discounts
        .where((d) => d.levelId == lvl && groupCount >= d.minSubjects)
        .toList()
      ..sort((a, b) => b.minSubjects.compareTo(a.minSubjects));
    return candidates.isEmpty ? null : candidates.first;
  }

  int? _nextDiscountThreshold() {
    final c = _config;
    final lvl = _levelId;
    if (c == null || lvl == null) return null;
    final groupCount =
        _sel.entries.where((e) => !e.value.individual).length;
    final next = c.discounts
        .where((d) => d.levelId == lvl && d.minSubjects > groupCount)
        .toList()
      ..sort((a, b) => a.minSubjects.compareTo(b.minSubjects));
    return next.isEmpty ? null : next.first.minSubjects;
  }

  // ───────────────────────── Sélection ─────────────────────────

  void _onLevelChanged(int? v) {
    setState(() {
      _levelId = v;
      // Même comportement que le web : changer de niveau réinitialise la
      // sélection de matières et le pack.
      _sel.clear();
      _selectedPack = null;
      _selectionMode = 'manual';
    });
  }

  void _selectPack(SubjectPack pack) {
    setState(() {
      _selectedPack = pack;
      _selectionMode = 'pack';
      // Auto-sélection des matières du pack ; on conserve les réglages
      // individuels des matières qui restent dans le pack.
      final kept = <int, _SubjectSel>{};
      for (final id in pack.subjectIds) {
        kept[id] = _sel[id] ?? _SubjectSel();
      }
      _sel
        ..clear()
        ..addAll(kept);
    });
  }

  void _switchToManual() {
    setState(() {
      _selectionMode = 'manual';
      _selectedPack = null;
      _sel.clear();
    });
  }

  void _toggleSubject(Mater m) {
    setState(() {
      if (_sel.containsKey(m.id)) {
        _sel.remove(m.id);
      } else {
        _sel[m.id] = _SubjectSel();
      }
    });
  }

  void _toggleIndividual(int materId) {
    final s = _sel[materId];
    if (s == null) return;
    setState(() {
      s.individual = !s.individual;
      if (s.individual) {
        s.sessionHours = [2];
        s.indivOnly = false;
      } else {
        s.indivOnly = false;
        s.teacherId = null;
      }
    });
  }

  void _setSessions(int materId, int count) {
    final s = _sel[materId];
    if (s == null) return;
    final c = count.clamp(1, 7);
    setState(() {
      final next = <double>[];
      for (var i = 0; i < c; i++) {
        next.add(i < s.sessionHours.length ? s.sessionHours[i] : 2);
      }
      s.sessionHours = next;
    });
  }

  void _setSessionHours(int materId, int index, double hours) {
    final s = _sel[materId];
    if (s == null || index >= s.sessionHours.length) return;
    setState(() {
      s.sessionHours[index] = hours.clamp(0.5, 4.0);
    });
  }

  // ───────────────────────── Soumission ─────────────────────────

  bool get _isValid =>
      _firstnameController.text.trim().isNotEmpty &&
      _lastnameController.text.trim().isNotEmpty &&
      _levelId != null &&
      _sel.isNotEmpty;

  Future<void> _submit() async {
    if (!_isValid) {
      showSnack(
        context,
        'Renseignez le prénom, le nom, le niveau et au moins une matière.',
        error: true,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final c = _config!;
      final subjectsById = {for (final m in c.subjects) m.id: m};
      final price = _computePrice();

      // Même payload que le front (inscription.component.ts → onSubmit).
      final subjectsPayload = <Map<String, dynamic>>[];
      _sel.forEach((id, s) {
        final m = subjectsById[id];
        final entry = <String, dynamic>{
          'id': id,
          if (m != null) 'name': m.name,
        };
        if (s.individual) {
          entry['individual'] = true;
          entry['indivSessions'] = s.sessionHours.length;
          entry['indivHours'] = s.indivHours;
          entry['indivPrice'] = _indivPrice(id);
          entry['indivOnly'] = s.indivOnly;
          entry['sessionDetails'] = [
            for (final h in s.sessionHours) {'hours': h},
          ];
          if (s.teacherId != null) entry['teacherId'] = s.teacherId;
        }
        subjectsPayload.add(entry);
      });

      final body = <String, dynamic>{
        'firstname': _firstnameController.text.trim(),
        'lastname': _lastnameController.text.trim(),
        'phoneStudent': _phoneStudentController.text.trim().isEmpty
            ? null
            : _phoneStudentController.text.trim(),
        'phoneRespo': _phoneRespoController.text.trim().isEmpty
            ? null
            : _phoneRespoController.text.trim(),
        'respo': _respoController.text.trim().isEmpty
            ? null
            : _respoController.text.trim(),
        'levelId': _levelId,
        'referralSource': _referralSource,
        'referredBy': null,
        'referrerUnknown': false,
        'subjects': subjectsPayload,
        'subjectCenters': const <String, dynamic>{},
        'neighborhood': _neighborhood,
        'school': _school,
        'siblingId': null,
        'pack_type': 'subjects',
        'priceTotal': price.total,
        'discount': price.packDiscount,
        'extras': [
          for (final e in c.extras)
            if (_extrasSel.contains(e.id))
              {'id': e.id, 'label': e.label, 'price': e.price},
        ],
      };
      final response = await InscriptionRepo.register(body);
      if (!mounted) return;
      setState(() => _submitting = false);
      await _showSuccessDialog(response);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showSnack(context, e.message, error: true);
    }
  }

  Future<void> _showSuccessDialog(Map<String, dynamic> response) async {
    final pricing = response['pricing'] is Map
        ? Map<String, dynamic>.from(response['pricing'] as Map)
        : const <String, dynamic>{};
    final payload = response['payload'] is Map
        ? Map<String, dynamic>.from(response['payload'] as Map)
        : const <String, dynamic>{};
    final priceTotal = asNumOrNull(pricing['priceTotal']);
    final discount = asNumOrNull(pricing['discount']);
    final siblingDiscount = asNumOrNull(pricing['siblingDiscount']);
    final studentId = asIntOrNull(payload['id']);
    final name =
        '${_firstnameController.text.trim()} ${_lastnameController.text.trim()}';

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: AppColors.success100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 44,
                  color: AppColors.success600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Inscription réussie !',
              style: Theme.of(dialogContext)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '$name est maintenant inscrit(e).',
              style: Theme.of(dialogContext)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.secondary400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (priceTotal != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary500.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _priceRow(dialogContext, 'Tarif mensuel',
                        _money(priceTotal),
                        bold: true),
                    if ((discount ?? 0) > 0) ...[
                      const SizedBox(height: 6),
                      _priceRow(dialogContext, 'Remise',
                          '- ${_money(discount!)}'),
                    ],
                    if ((siblingDiscount ?? 0) > 0) ...[
                      const SizedBox(height: 6),
                      _priceRow(dialogContext, 'Remise fratrie',
                          '- ${_money(siblingDiscount!)}'),
                    ],
                  ],
                ),
              ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('new'),
            child: const Text('Nouvelle inscription'),
          ),
          if (studentId != null)
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop('view'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: const Text('Voir la fiche'),
            ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == 'view' && studentId != null) {
      context.push('/students/$studentId');
    }
    _resetForm();
  }

  Widget _priceRow(BuildContext context, String label, String value,
      {bool bold = false}) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    );
  }

  void _resetForm() {
    setState(() {
      _firstnameController.clear();
      _lastnameController.clear();
      _phoneStudentController.clear();
      _respoController.clear();
      _phoneRespoController.clear();
      _school = null;
      _neighborhood = null;
      _levelId = null;
      _cycleId = null;
      _selectionMode = 'manual';
      _selectedPack = null;
      _sel.clear();
      _extrasSel.clear();
      _referralSource = null;
      _formEpoch++;
    });
  }

  // ───────────────────────────── UI ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inscription')),
      bottomNavigationBar: _config == null ? null : _summaryBar(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadingConfig) return const _FormShimmer();
    if (_configError != null) {
      return ErrorRetry(message: _configError!, onRetry: _loadConfig);
    }
    final config = _config!;
    return ListView(
      key: ValueKey('inscription-form-$_formEpoch'),
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          number: 1,
          title: 'Élève',
          child: Column(
            children: [
              TextField(
                controller: _firstnameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Prénom *',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lastnameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom *',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneStudentController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone élève',
                  prefixIcon: Icon(Icons.smartphone_rounded),
                ),
              ),
              const SizedBox(height: 12),
              _dropdown<String>(
                label: 'École',
                icon: Icons.account_balance_outlined,
                value: _school,
                items: [
                  for (final s in config.schools)
                    DropdownMenuItem(value: s.name, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() => _school = v),
              ),
              const SizedBox(height: 12),
              _dropdown<String>(
                label: 'Quartier',
                icon: Icons.location_on_outlined,
                value: _neighborhood,
                items: [
                  for (final n in config.neighborhoods)
                    DropdownMenuItem(value: n.name, child: Text(n.name)),
                ],
                onChanged: (v) => setState(() => _neighborhood = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          number: 2,
          title: 'Responsable',
          child: Column(
            children: [
              TextField(
                controller: _respoController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom du responsable',
                  prefixIcon: Icon(Icons.family_restroom_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneRespoController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone responsable',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          number: 3,
          title: 'Scolarité',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hiérarchie scolaire : filtre par cycle quand disponible.
              if (config.hasHierarchy) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Tous'),
                        selected: _cycleId == null,
                        onSelected: (_) => setState(() => _cycleId = null),
                      ),
                      for (final cycle in config.cycles) ...[
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(cycle.name),
                          selected: _cycleId == cycle.id,
                          onSelected: (_) => setState(() {
                            _cycleId = cycle.id;
                            final visible = config.levelsOfCycle(cycle.id);
                            if (_levelId != null &&
                                !visible.any((l) => l.id == _levelId)) {
                              _onLevelChanged(null);
                            }
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _dropdown<int>(
                label: 'Niveau *',
                icon: Icons.school_outlined,
                value: _levelId,
                items: [
                  for (final Level l in (_cycleId == null
                      ? config.levels
                      : config.levelsOfCycle(_cycleId!)))
                    DropdownMenuItem(
                        value: l.id, child: Text(l.displayName)),
                ],
                onChanged: _onLevelChanged,
              ),
              const SizedBox(height: 16),
              if (_levelId == null)
                _infoBanner(
                  'Choisissez d\'abord un niveau pour voir les matières, packs et tarifs.',
                  color: AppColors.warning100,
                  textColor: const Color(0xFFB45309),
                  icon: Icons.info_outline_rounded,
                )
              else
                ..._subjectsArea(config),
            ],
          ),
        ),
        // ── Options (extras) ──
        if (_levelId != null &&
            _sel.isNotEmpty &&
            config.extras.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionCard(
            number: 4,
            title: 'Options',
            child: Column(
              children: [
                for (final e in config.extras)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(e.label),
                    secondary: Text(
                      '+${_money(e.price)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary600,
                      ),
                    ),
                    value: _extrasSel.contains(e.id),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _extrasSel.add(e.id);
                      } else {
                        _extrasSel.remove(e.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _sectionCard(
          number: _levelId != null &&
                  _sel.isNotEmpty &&
                  config.extras.isNotEmpty
              ? 5
              : 4,
          title: 'Origine',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in _referralOptions)
                ChoiceChip(
                  label: Text(o.label),
                  selected: _referralSource == o.code,
                  onSelected: (sel) => setState(
                      () => _referralSource = sel ? o.code : null),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─────────────────── Zone matières (packs + manuel) ───────────────────

  List<Widget> _subjectsArea(InscriptionConfig config) {
    final packs = config.packsForLevel(_levelId!);
    return [
      // Sélecteur de mode quand des packs existent pour ce niveau.
      if (packs.isNotEmpty) ...[
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'pack',
              label: Text('Packs'),
              icon: Icon(Icons.inventory_2_outlined),
            ),
            ButtonSegment(
              value: 'manual',
              label: Text('Par matière'),
              icon: Icon(Icons.checklist_rounded),
            ),
          ],
          selected: {_selectionMode},
          onSelectionChanged: (s) {
            final mode = s.first;
            if (mode == 'manual') {
              _switchToManual();
            } else {
              setState(() => _selectionMode = 'pack');
            }
          },
        ),
        const SizedBox(height: 14),
      ],
      if (_selectionMode == 'pack' && packs.isNotEmpty)
        ..._packArea(config, packs)
      else
        ..._manualArea(config),
    ];
  }

  List<Widget> _packArea(InscriptionConfig config, List<SubjectPack> packs) {
    final subjectsById = {for (final m in config.subjects) m.id: m};
    return [
      for (final pack in packs) ...[
        _packCard(pack, subjectsById),
        const SizedBox(height: 10),
      ],
      if (_selectedPack != null) ...[
        const SizedBox(height: 6),
        Text(
          'Ajouter des séances individuelles',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final id in _selectedPack!.subjectIds)
          if (subjectsById[id] != null && _indivPrice(id) > 0)
            _indivConfigTile(subjectsById[id]!, packMode: true),
      ],
    ];
  }

  Widget _packCard(SubjectPack pack, Map<int, Mater> subjectsById) {
    final selected = _selectedPack?.id == pack.id;
    final names = pack.subjectIds
        .map((id) => subjectsById[id]?.name ?? '?')
        .join(', ');
    return InkWell(
      onTap: () => _selectPack(pack),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary500.withValues(alpha: 0.08)
              : Theme.of(context).brightness == Brightness.dark
                  ? AppColors.secondary700.withValues(alpha: 0.35)
                  : AppColors.secondary50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary500 : AppColors.secondary200,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color:
                  selected ? AppColors.primary600 : AppColors.secondary300,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pack.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    names,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.secondary400),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary600,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _money(pack.price),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _manualArea(InscriptionConfig config) {
    final theme = Theme.of(context);
    final widgets = <Widget>[];

    // Bannières remises (comme le web).
    final threshold = _nextDiscountThreshold();
    final groupCount =
        _sel.entries.where((e) => !e.value.individual).length;
    if (threshold != null) {
      widgets
        ..add(_infoBanner(
          'Ajoutez ${threshold - groupCount} matière(s) en groupe pour débloquer une réduction',
          color: AppColors.primary100,
          textColor: AppColors.primary700,
          icon: Icons.card_giftcard_rounded,
        ))
        ..add(const SizedBox(height: 8));
    }
    final current = _currentDiscount();
    if (current != null) {
      widgets
        ..add(_infoBanner(
          'Pack $groupCount matières : -${_fmtNum(current.discountPercent)}% sur les cours en groupe',
          color: AppColors.success100,
          textColor: AppColors.success600,
          icon: Icons.percent_rounded,
        ))
        ..add(const SizedBox(height: 8));
    }

    // Matières par catégorie.
    final byCategory = <String, List<Mater>>{};
    for (final m in config.subjects) {
      final cat = m.category ?? 'autres';
      byCategory.putIfAbsent(cat, () => []).add(m);
    }
    final orderedKeys = [
      'general',
      'communication',
      'language',
      ...byCategory.keys.where(
          (k) => !['general', 'communication', 'language'].contains(k)),
    ];

    for (final key in orderedKeys) {
      final maters = byCategory[key];
      if (maters == null || maters.isEmpty) continue;
      widgets
        ..add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(
            _categoryLabels[key] ?? 'Autres',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.secondary400,
              letterSpacing: 0.4,
            ),
          ),
        ))
        ..add(Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final m in maters) _subjectChip(m)],
        ));
    }

    // Récap des matières sélectionnées avec configuration individuelle.
    if (_sel.isNotEmpty) {
      final subjectsById = {for (final m in config.subjects) m.id: m};
      widgets
        ..add(const SizedBox(height: 16))
        ..add(Text(
          'Matières sélectionnées',
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ))
        ..add(const SizedBox(height: 8));
      for (final id in _sel.keys) {
        final m = subjectsById[id];
        if (m != null) widgets.add(_indivConfigTile(m));
      }
    }
    return widgets;
  }

  Widget _subjectChip(Mater m) {
    final selected = _sel.containsKey(m.id);
    final group = _groupPrice(m.id);
    final indiv = _indivPrice(m.id);
    final parts = <String>[m.name];
    if (group > 0) parts.add(_money(group));
    if (indiv > 0) parts.add('ind. ${_money(indiv)}/h');
    return FilterChip(
      label: Text(parts.join(' · ')),
      selected: selected,
      showCheckmark: true,
      onSelected: (_) => _toggleSubject(m),
    );
  }

  /// Carte de configuration d'une matière sélectionnée : prix, bascule
  /// individuel, « individuel uniquement », professeur, séances et heures.
  Widget _indivConfigTile(Mater m, {bool packMode = false}) {
    final s = packMode
        ? (_sel[m.id] ?? _SubjectSel())
        : _sel[m.id]!;
    if (packMode && !_sel.containsKey(m.id)) _sel[m.id] = s;

    final theme = Theme.of(context);
    final group = _groupPrice(m.id);
    final indiv = _indivPrice(m.id);
    final hasIndiv = indiv > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.secondary700.withValues(alpha: 0.35)
            : AppColors.secondary50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: s.individual
              ? AppColors.primary300
              : AppColors.secondary200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    Row(
                      children: [
                        if (!packMode && group > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Text(
                              '👥 ${_money(group)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.secondary400),
                            ),
                          ),
                        if (hasIndiv)
                          Text(
                            '👤 ${_money(indiv)}/h',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.primary600,
                                fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (hasIndiv) ...[
                Text('Individuel',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.secondary400)),
                Switch(
                  value: s.individual,
                  onChanged: (_) => _toggleIndividual(m.id),
                ),
              ],
              if (!packMode)
                IconButton(
                  tooltip: 'Retirer',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => _toggleSubject(m),
                ),
            ],
          ),
          if (s.individual) ...[
            const Divider(height: 16),
            if (!packMode)
              InkWell(
                onTap: () =>
                    setState(() => s.indivOnly = !s.indivOnly),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        s.indivOnly
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 20,
                        color: s.indivOnly
                            ? AppColors.primary600
                            : AppColors.secondary400,
                      ),
                      const SizedBox(width: 8),
                      const Text('Individuel uniquement (sans groupe)',
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
            if (_teachers.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: s.teacherId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Professeur',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  isDense: true,
                ),
                items: [
                  for (final t in _teachers)
                    DropdownMenuItem(
                      value: asInt(t['id']),
                      child: Text(
                          '${t['firstname'] ?? ''} ${t['lastname'] ?? ''}'
                              .trim()),
                    ),
                ],
                onChanged: (v) => setState(() => s.teacherId = v),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Séances/sem', style: TextStyle(fontSize: 13)),
                const Spacer(),
                _stepBtn(Icons.remove_rounded,
                    () => _setSessions(m.id, s.sessionHours.length - 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('${s.sessionHours.length}',
                      style:
                          const TextStyle(fontWeight: FontWeight.w700)),
                ),
                _stepBtn(Icons.add_rounded,
                    () => _setSessions(m.id, s.sessionHours.length + 1)),
              ],
            ),
            for (var i = 0; i < s.sessionHours.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Text('Séance ${i + 1}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.secondary400)),
                    const Spacer(),
                    _stepBtn(
                        Icons.remove_rounded,
                        () => _setSessionHours(
                            m.id, i, s.sessionHours[i] - 0.5)),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('${_fmtNum(s.sessionHours[i])} h',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                    ),
                    _stepBtn(
                        Icons.add_rounded,
                        () => _setSessionHours(
                            m.id, i, s.sessionHours[i] + 0.5)),
                  ],
                ),
              ),
            if (indiv > 0) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Individuel : ${_fmtNum(s.indivHours)} h × ${_money(indiv)} = ${_money(indiv * s.indivHours)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.primary600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.primary500.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary700),
      ),
    );
  }

  Widget _infoBanner(String text,
      {required Color color,
      required Color textColor,
      required IconData icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final price = _computePrice();
    final details = <String>[];
    if (price.packDiscount > 0) {
      details.add('Remise -${_money(price.packDiscount)}');
    }
    if (price.extrasTotal > 0) {
      details.add('Options +${_money(price.extrasTotal)}');
    }
    if (_selectionMode == 'pack' && _selectedPack != null) {
      details.add(_selectedPack!.name);
    }
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.secondary800 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total mensuel',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.secondary400),
                    ),
                    Text(
                      _money(price.total),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary600,
                      ),
                    ),
                    if (details.isNotEmpty)
                      Text(
                        details.join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.success600,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Inscrire l\'élève'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required int number,
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return OxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: AppColors.primary600,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: items,
      onChanged: onChanged,
    );
  }

  static String _money(num v) {
    final s = v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(2);
    return '$s DH';
  }

  static String _fmtNum(num v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _FormShimmer extends StatelessWidget {
  const _FormShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        OxCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 120, height: 18),
              SizedBox(height: 16),
              ShimmerBox(height: 52, radius: 14),
              SizedBox(height: 12),
              ShimmerBox(height: 52, radius: 14),
              SizedBox(height: 12),
              ShimmerBox(height: 52, radius: 14),
            ],
          ),
        ),
        SizedBox(height: 16),
        OxCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 140, height: 18),
              SizedBox(height: 16),
              ShimmerBox(height: 52, radius: 14),
              SizedBox(height: 12),
              ShimmerBox(height: 52, radius: 14),
            ],
          ),
        ),
        SizedBox(height: 16),
        OxCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 100, height: 18),
              SizedBox(height: 16),
              ShimmerBox(height: 36, radius: 10),
              SizedBox(height: 8),
              ShimmerBox(height: 36, radius: 10, width: 220),
            ],
          ),
        ),
      ],
    );
  }
}
