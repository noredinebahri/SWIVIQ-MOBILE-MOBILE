import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/models/schedule.dart';
import '../../core/models/student.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/widgets/common.dart';
import 'game/game_hub_screen.dart';
import 'polycopie_cache.dart';
import 'schedule_cache.dart';
import 'student_extras.dart';
import 'student_portal_repo.dart';

/// Espace élève : profil, polycopiés (téléchargeables une fois réglés) et
/// emploi du temps. Lecture seule.
class StudentSpaceScreen extends ConsumerStatefulWidget {
  const StudentSpaceScreen({super.key});

  @override
  ConsumerState<StudentSpaceScreen> createState() =>
      _StudentSpaceScreenState();
}

class _StudentSpaceScreenState extends ConsumerState<StudentSpaceScreen> {
  int _tab = 0;

  Student? _student;
  List<StudentPolycopieFile>? _polycopies;
  List<ScheduleSlot>? _slots;
  bool _loading = true;
  String? _error;
  final Set<int> _downloading = {};

  /// Emploi du temps affiché depuis la copie locale (pas de réseau).
  bool _scheduleOffline = false;
  DateTime? _scheduleSavedAt;

  /// Idem pour les polycopiés + chemins des fichiers déjà téléchargés.
  bool _polyOffline = false;
  DateTime? _polySavedAt;
  final Map<int, String> _localFiles = {};

  /// Recalcule quels supports sont disponibles hors connexion (un fichier
  /// périmé est supprimé par le cache lui-même).
  Future<void> _refreshLocalFiles(List<StudentPolycopieFile> items) async {
    for (final p in items) {
      final path = await StudentPortalRepo.localPolycopieFile(p);
      if (path != null) {
        _localFiles[p.polycopieId] = path;
      } else {
        _localFiles.remove(p.polycopieId);
      }
    }
  }

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

    // 1) La copie hors-ligne s'affiche TOUT DE SUITE : l'élève voit ses cours
    //    même sans réseau, sans attendre le serveur.
    final cached = await StudentPortalRepo.cachedSchedule();
    final cachedPolys = await StudentPortalRepo.cachedPolycopies();
    if ((cached.isNotEmpty || cachedPolys.isNotEmpty) && mounted) {
      final savedAt = await ScheduleCache.readSavedAt();
      final polySavedAt = await PolycopieCache.readSavedAt();
      await _refreshLocalFiles(cachedPolys);
      setState(() {
        if (cached.isNotEmpty) {
          _slots = cached;
          _scheduleOffline = true;
          _scheduleSavedAt = savedAt;
        }
        if (cachedPolys.isNotEmpty) {
          _polycopies = cachedPolys;
          _polyOffline = true;
          _polySavedAt = polySavedAt;
        }
        _loading = false;
      });
    }

    // 2) Puis on rafraîchit depuis le serveur.
    try {
      final me = await StudentPortalRepo.me();
      if (!mounted) return;
      setState(() {
        _student = me;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Hors-ligne avec une copie en poche : ce n'est pas une erreur
        // bloquante, l'emploi du temps reste consultable.
        if (_slots == null || _slots!.isEmpty) _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_slots == null || _slots!.isEmpty) {
          _error = 'Impossible de charger vos données.';
        }
      });
    }

    // 3) Polycopiés : la liste et les fichiers périmés sont remplacés.
    try {
      final result = await StudentPortalRepo.fetchPolycopies();
      if (!mounted) return;
      await _refreshLocalFiles(result.items);
      setState(() {
        _polycopies = result.items;
        _polyOffline = false;
        _polySavedAt = DateTime.now();
      });
      if (result.changed) {
        await NotificationService.instance.notifyPolycopiesUpdated();
        if (mounted) {
          showSnack(context, 'Vos polycopiés ont été mis à jour.');
        }
      }
    } catch (_) {
      // Hors-ligne : la copie locale reste affichée.
    }

    // 4) Emploi du temps : une nouvelle version REMPLACE l'ancienne copie et
    //    l'élève en est informé.
    try {
      final result = await StudentPortalRepo.fetchSchedule();
      if (!mounted) return;
      setState(() {
        _slots = result.slots;
        _scheduleOffline = false;
        _scheduleSavedAt = DateTime.now();
      });
      if (result.changed) {
        await NotificationService.instance.notifyScheduleUpdated();
        if (mounted) {
          showSnack(context,
              'Nouvel emploi du temps — votre copie a été mise à jour.');
        }
      }
    } catch (_) {
      // Pas de réseau : la copie locale déjà affichée fait le travail.
    }
  }

  /// Ouvre le support : la copie locale si elle existe (donc SANS réseau),
  /// sinon téléchargement puis conservation sur l'appareil.
  Future<void> _openPolycopie(StudentPolycopieFile p) async {
    final existing = _localFiles[p.polycopieId];
    if (existing != null) {
      await Share.shareXFiles([XFile(existing)], text: p.name);
      return;
    }

    setState(() => _downloading.add(p.polycopieId));
    try {
      final path = await StudentPortalRepo.downloadPolycopie(p);
      if (!mounted) return;
      setState(() => _localFiles[p.polycopieId] = path);
      await Share.shareXFiles([XFile(path)], text: p.name);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showSnack(
          context,
          'Téléchargement impossible — vérifiez votre connexion.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _downloading.remove(p.polycopieId));
    }
  }

  Future<void> _logout() async {
    await ref.read(studentAuthProvider.notifier).logout();
    if (mounted) context.go('/eleve/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_tab) {
          0 => 'Mon profil',
          1 => 'Mes polycopiés',
          2 => 'Mon emploi du temps',
          _ => 'Jeux',
        }),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profil'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'Polycopiés'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Emploi'),
          NavigationDestination(
              icon: Icon(Icons.sports_esports_outlined),
              selectedIcon: Icon(Icons.sports_esports_rounded),
              label: 'Jeu'),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Le jeu est autonome (hors-ligne, aucune donnée serveur) : il s'affiche
    // même si le chargement du profil a échoué.
    if (_tab == 3) return const GameHubScreen();
    if (_loading) return const ListShimmer();
    if (_error != null) return ErrorRetry(message: _error!, onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: switch (_tab) {
        0 => _profileTab(),
        1 => _polycopieTab(),
        _ => _scheduleTab(),
      },
    );
  }

  // ─────────────────────────────── Profil ───────────────────────────────

  Widget _profileTab() {
    final s = _student!;
    final now = DateTime.now();
    final absMonth = s.absences
        .where((a) =>
            !a.isRetard &&
            a.date.month == now.month &&
            a.date.year == now.year)
        .length;
    final retards = s.absences.where((a) => a.isRetard).length;
    final unpaidRest = s.payments.fold<num>(0, (sum, p) => sum + p.rest);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        OxCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              InitialsAvatar(name: s.fullName, radius: 34),
              const SizedBox(height: 12),
              Text(s.fullName,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                [
                  s.levelName ?? '',
                  if ((s.group ?? '').isNotEmpty) 'Groupe ${s.group}',
                ].where((e) => e.isNotEmpty).join(' · '),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.secondary400),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  s.isActive
                      ? const StatusBadge.success('Inscrit')
                      : const StatusBadge.danger('Inactif'),
                  if (s.priceTotal > 0)
                    StatusBadge.info('${_money(s.priceTotal)} / mois'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Accès rapides : contacter ses profs, déclarer sa sortie d'école.
        Row(
          children: [
            Expanded(
              child: _quickTile(
                icon: Icons.people_alt_rounded,
                label: 'Mes professeurs',
                color: AppColors.primary600,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const MyTeachersScreen(),
                )),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickTile(
                icon: Icons.school_rounded,
                label: 'Ma sortie d\'école',
                color: const Color(0xFF0EA5E9),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SchoolExitScreen(),
                )),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _stat('$absMonth', 'Absences ce mois',
                absMonth >= 3 ? AppColors.danger600 : AppColors.warning500),
            _stat('$retards', 'Retards', AppColors.primary600),
            _stat(_money(unpaidRest), 'Reste dû',
                unpaidRest > 0 ? AppColors.danger600 : AppColors.success600),
          ],
        ),
        const SizedBox(height: 16),
        if (s.subjects.isNotEmpty) ...[
          _sectionTitle('Mes matières', Icons.menu_book_outlined),
          const SizedBox(height: 8),
          OxCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sub in s.subjects)
                  Chip(
                    label: Text(sub.name ?? 'Matière'),
                    avatar: Icon(
                      sub.individual
                          ? Icons.person_rounded
                          : Icons.groups_rounded,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        _sectionTitle('Mon assiduité', Icons.event_available_rounded),
        const SizedBox(height: 8),
        OxCard(
          child: s.absences.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Aucune absence ni retard. Bravo ! 👏'),
                )
              : Column(
                  children: [
                    for (final a in s.absences.take(10))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              a.isRetard
                                  ? Icons.timer_rounded
                                  : Icons.event_busy_rounded,
                              size: 18,
                              color: a.isRetard
                                  ? AppColors.primary600
                                  : AppColors.danger600,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('EEEE d MMMM', 'fr')
                                        .format(a.date),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  if (a.matterName?.isNotEmpty == true)
                                    Text(a.matterName!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: AppColors
                                                    .secondary400)),
                                ],
                              ),
                            ),
                            if (a.isRetard)
                              StatusBadge.info('⏱ ${a.lateMinutes ?? '?'} min')
                            else if (a.isJustified)
                              const StatusBadge.success('Justifiée')
                            else
                              const StatusBadge.danger('Absente'),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _sectionTitle('Mes paiements', Icons.payments_outlined),
        const SizedBox(height: 8),
        OxCard(
          child: s.payments.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Aucun paiement enregistré.'),
                )
              : Column(
                  children: [
                    for (final p in s.payments.take(12))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.month != null && p.year != null
                                    ? '${_monthsFr[(p.month! - 1).clamp(0, 11)]} ${p.year}'
                                    : (p.paymentDate?.substring(0, 10) ??
                                        'Paiement'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text('${_money(p.price)} DH'),
                            const SizedBox(width: 8),
                            if (p.rest > 0)
                              StatusBadge.warning(
                                  'reste ${_money(p.rest)}')
                            else
                              const StatusBadge.success('Payé'),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ────────────────────────────── Polycopiés ──────────────────────────────

  Widget _polycopieTab() {
    final list = _polycopies ?? [];
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          EmptyState(
            icon: Icons.menu_book_rounded,
            title: 'Aucun polycopié',
            subtitle:
                'Vos supports de cours apparaîtront ici dès qu\'ils seront attribués.',
          ),
        ],
      );
    }
    final savedLabel = _polySavedAt == null
        ? null
        : DateFormat('d MMMM à HH:mm', 'fr').format(_polySavedAt!);
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: list.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          // Les supports déjà téléchargés restent lisibles sans réseau.
          final offlineCount = _localFiles.length;
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _polyOffline
                  ? AppColors.warning100
                  : AppColors.success100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _polyOffline
                      ? Icons.cloud_off_rounded
                      : Icons.cloud_done_rounded,
                  size: 18,
                  color: _polyOffline
                      ? const Color(0xFFB45309)
                      : AppColors.success600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (_polyOffline
                            ? 'Version hors connexion${savedLabel != null ? ' — le $savedLabel' : ''}'
                            : 'À jour${savedLabel != null ? ' — le $savedLabel' : ''}') +
                        (offlineCount > 0
                            ? ' · $offlineCount support(s) disponible(s) hors connexion'
                            : ''),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _polyOffline
                          ? const Color(0xFFB45309)
                          : AppColors.success600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        final p = list[index - 1];
        final busy = _downloading.contains(p.polycopieId);
        final offline = _localFiles.containsKey(p.polycopieId);
        return OxCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: p.downloadable
                      ? AppColors.success100
                      : AppColors.secondary100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  offline
                      ? Icons.offline_pin_rounded
                      : (p.downloadable
                          ? Icons.file_download_rounded
                          : Icons.lock_rounded),
                  color: offline || p.downloadable
                      ? AppColors.success600
                      : AppColors.secondary400,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style:
                            const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      offline
                          ? 'Disponible hors connexion · ${p.fileName ?? 'fichier'}'
                          : (p.downloadable
                              ? 'À télécharger · ${p.fileName ?? 'fichier'}'
                              : (p.remaining > 0
                                  ? 'À régler : ${_money(p.remaining)} DH'
                                  : 'Aucun fichier déposé pour le moment')),
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
              if (busy)
                const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else if (offline || p.downloadable)
                FilledButton.icon(
                  onPressed: () => _openPolycopie(p),
                  icon: Icon(
                      offline
                          ? Icons.folder_open_rounded
                          : Icons.download_rounded,
                      size: 18),
                  label: Text(offline ? 'Ouvrir' : 'Télécharger'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                )
              else if (p.remaining > 0)
                StatusBadge.warning('${_money(p.remaining)} DH'),
            ],
          ),
        );
      },
    );
  }

  // ──────────────────────────── Emploi du temps ────────────────────────────

  Widget _scheduleTab() {
    final slots = _slots ?? [];
    if (slots.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          EmptyState(
            icon: Icons.calendar_month_rounded,
            title: 'Emploi du temps indisponible',
            subtitle: 'Aucun cours n\'est encore planifié pour votre niveau.',
          ),
        ],
      );
    }
    final todayFr = kScheduleDays[DateTime.now().weekday - 1];
    final savedLabel = _scheduleSavedAt == null
        ? null
        : DateFormat('d MMMM à HH:mm', 'fr').format(_scheduleSavedAt!);
    final byDay = <String, List<ScheduleSlot>>{};
    for (final s in slots) {
      byDay.putIfAbsent(s.day, () => []).add(s);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    final days = kScheduleDays.where(byDay.containsKey).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Disponible hors connexion : l'élève sait ce qu'il regarde.
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _scheduleOffline
                ? AppColors.warning100
                : AppColors.success100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                _scheduleOffline
                    ? Icons.cloud_off_rounded
                    : Icons.cloud_done_rounded,
                size: 18,
                color: _scheduleOffline
                    ? const Color(0xFFB45309)
                    : AppColors.success600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _scheduleOffline
                      ? 'Version hors connexion${savedLabel != null ? ' — enregistrée le $savedLabel' : ''}'
                      : 'À jour${savedLabel != null ? ' — synchronisé le $savedLabel' : ''}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _scheduleOffline
                        ? const Color(0xFFB45309)
                        : AppColors.success600,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Row(
              children: [
                Text(
                  day,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: day == todayFr
                        ? AppColors.primary600
                        : AppColors.secondary400,
                  ),
                ),
                if (day == todayFr) ...[
                  const SizedBox(width: 8),
                  const StatusBadge.info("Aujourd'hui"),
                ],
              ],
            ),
          ),
          for (final s in byDay[day]!) ...[
            OxCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary500,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.subject,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        Text(
                          [
                            if (s.teacherName?.isNotEmpty == true)
                              s.teacherName!,
                            if ((s.room ?? '').isNotEmpty) 'Salle ${s.room}',
                          ].join(' · '),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.secondary400),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${s.startTime}\n${s.endTime}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  // ─────────────────────────────── Helpers ───────────────────────────────

  Widget _quickTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color color) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: color)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary400)),
            ],
          ),
        ),
      );

  Widget _sectionTitle(String title, IconData icon) => Row(
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

  static String _money(num v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
