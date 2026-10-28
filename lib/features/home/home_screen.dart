import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/config/center_config.dart';
import '../../core/models/records.dart';
import '../../core/models/schedule.dart';
import '../../core/repositories.dart';
import '../../core/widgets/common.dart';

/// Tableau de bord d'accueil : salutation, stats du jour, accès rapides —
/// le contenu s'adapte au rôle et aux permissions.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<ScheduleSlot>? _todaySlots;
  List<TeacherRecord>? _myRecords;
  int? _totalStudents;
  bool _loading = true;

  static const _frenchDays = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  String get _todayName => _frenchDays[DateTime.now().weekday - 1];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = ref.read(authProvider).user;
    // Chaque bloc est indépendant : une erreur n'empêche pas les autres.
    await Future.wait([
      () async {
        try {
          // Uniquement l'emploi du temps sélectionné : sans ce filtre les
          // séances de tous les emplois (anciens compris) se superposaient.
          final active = await ScheduleRepo.activeConfig();
          final slots =
              await ScheduleRepo.slots(scheduleConfigId: active?.id);
          var today = slots.where((s) => s.day == _todayName).toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));
          if (user != null && user.isTeacher) {
            today = today.where((s) => s.userId == user.id).toList();
          }
          _todaySlots = today;
        } catch (_) {
          _todaySlots = null;
        }
      }(),
      () async {
        try {
          if (user != null && user.isTeacher) {
            _myRecords = await RecordsRepo.myRecords(user.id);
          }
        } catch (_) {}
      }(),
      () async {
        try {
          final page = await StudentsRepo.list(page: 1, actif: 1);
          _totalStudents = page.totalStudent;
        } catch (_) {}
      }(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final perms = ref.watch(permissionsProvider).valueOrNull;
    final theme = Theme.of(context);
    if (user == null) return const SizedBox.shrink();

    final greeting = switch (DateTime.now().hour) {
      >= 5 && < 12 => 'Bonjour',
      >= 12 && < 18 => 'Bon après-midi',
      _ => 'Bonsoir',
    };

    final now = DateTime.now();
    final monthRecords = _myRecords
        ?.where((r) =>
            r.createdAt != null &&
            r.createdAt!.month == now.month &&
            r.createdAt!.year == now.year)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.secondary200),
              ),
              child: Image.asset('assets/images/logo.png', height: 26),
            ),
            const SizedBox(width: 10),
            Text(centerDisplayName(ref)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/profile'),
            icon: InitialsAvatar(name: user.fullName, radius: 16),
            tooltip: 'Mon profil',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Bandeau de bienvenue ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary700, AppColors.primary500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, ${user.firstname} 👋',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.roleLabel,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (_totalStudents != null && (perms?.can('students.view') ?? true)) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _WhiteStat(
                            icon: Icons.school_rounded,
                            value: '$_totalStudents',
                            label: 'élèves actifs'),
                        if (_todaySlots != null) ...[
                          const SizedBox(width: 20),
                          _WhiteStat(
                              icon: Icons.calendar_today_rounded,
                              value: '${_todaySlots!.length}',
                              label: user.isTeacher
                                  ? 'séances aujourd\'hui'
                                  : 'créneaux aujourd\'hui'),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Suivi prof : séances du mois ──
            if (user.isTeacher && monthRecords != null) ...[
              OxCard(
                onTap: () => context.go('/records'),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.fact_check_rounded,
                          color: AppColors.primary700),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mes séances ce mois',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            '${monthRecords.length} séances · '
                            '${monthRecords.where((r) => r.isValidated).length} validées',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.secondary400),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.secondary400),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Emploi du temps du jour ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Aujourd\'hui — $_todayName',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                TextButton(
                  onPressed: () => context.go('/schedule'),
                  child: const Text('Tout voir'),
                ),
              ],
            ),
            if (_loading)
              const Column(children: [
                ShimmerBox(height: 72, radius: 16),
                SizedBox(height: 8),
                ShimmerBox(height: 72, radius: 16),
              ])
            else if (_todaySlots == null)
              OxCard(
                child: Row(children: [
                  const Icon(Icons.cloud_off_rounded,
                      color: AppColors.secondary400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Emploi du temps indisponible',
                        style: theme.textTheme.bodyMedium),
                  ),
                ]),
              )
            else if (_todaySlots!.isEmpty)
              OxCard(
                child: Row(children: [
                  const Icon(Icons.beach_access_rounded,
                      color: AppColors.primary400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        user.isTeacher
                            ? 'Aucune séance pour vous aujourd\'hui 🎉'
                            : 'Aucun créneau aujourd\'hui',
                        style: theme.textTheme.bodyMedium),
                  ),
                ]),
              )
            else
              Column(
                children: [
                  for (final slot in _todaySlots!.take(5)) ...[
                    _SlotTile(slot: slot),
                    const SizedBox(height: 8),
                  ],
                  if (_todaySlots!.length > 5)
                    TextButton(
                      onPressed: () => context.go('/schedule'),
                      child: Text('+ ${_todaySlots!.length - 5} autres créneaux'),
                    ),
                ],
              ),
            const SizedBox(height: 16),

            // ── Actions rapides ──
            Text('Actions rapides',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                if (perms == null || perms.can('students.edit'))
                  _QuickAction(
                    icon: Icons.person_add_rounded,
                    label: 'Inscription',
                    color: AppColors.primary600,
                    onTap: () => context.push('/inscription'),
                  ),
                if (perms == null || perms.canAny(['attendance.edit']))
                  _QuickAction(
                    icon: Icons.event_busy_rounded,
                    label: 'Marquer absences',
                    color: AppColors.danger500,
                    onTap: () => context.go('/absence'),
                  ),
                if (user.isTeacher ||
                    (perms?.can('teacher_clock.self') ?? false))
                  _QuickAction(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Pointage',
                    color: const Color(0xFF111111),
                    onTap: () => context.push('/pointage'),
                  ),
                if (user.isTeacher ||
                    (perms?.can('teachers.new_record') ?? false))
                  _QuickAction(
                    icon: Icons.add_task_rounded,
                    label: 'Nouvelle séance',
                    color: AppColors.success600,
                    onTap: () => context.push('/records/new'),
                  ),
                if (user.isTeacher ||
                    (perms?.canAny(['reports.create', 'reports.view']) ?? false))
                  _QuickAction(
                    icon: Icons.assignment_rounded,
                    label: 'Bulletins du mois',
                    color: const Color(0xFF8B5CF6),
                    onTap: () => context.push('/reports'),
                  ),
                if (perms == null || perms.can('attendance.view'))
                  _QuickAction(
                    icon: Icons.insights_rounded,
                    label: 'Rapport absences',
                    color: AppColors.warning500,
                    onTap: () => context.push('/absence/report'),
                  ),
                if (user.isAdmin || user.role == 's')
                  _QuickAction(
                    icon: Icons.menu_book_rounded,
                    label: 'Polycopiés',
                    color: const Color(0xFF0EA5E9),
                    onTap: () => context.push('/polycopie'),
                  ),
                if (user.isAdmin)
                  _QuickAction(
                    icon: Icons.request_quote_rounded,
                    label: 'Échéances',
                    color: const Color(0xFF16A34A),
                    onTap: () => context.push('/payments/due'),
                  ),
                _QuickAction(
                  icon: Icons.person_rounded,
                  label: 'Mon profil',
                  color: AppColors.secondary500,
                  onTap: () => context.push('/profile'),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _WhiteStat extends StatelessWidget {
  const _WhiteStat(
      {required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot});

  final ScheduleSlot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OxCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(slot.startTime,
                    style: const TextStyle(
                        color: AppColors.primary700,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                Text(slot.endTime,
                    style: const TextStyle(
                        color: AppColors.primary400, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot.subject,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  [
                    if (slot.scopeLabel.isNotEmpty) slot.scopeLabel,
                    if (slot.group != null && slot.group!.isNotEmpty)
                      'Grp ${slot.group}',
                    if (slot.teacherName != null) slot.teacherName!,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.secondary400),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (slot.room != null && slot.room!.isNotEmpty)
            StatusBadge.info(slot.roomLabel),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OxCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
