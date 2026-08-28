import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';

/// Coque de navigation : barre du bas filtrée selon les permissions de
/// l'utilisateur (GET /permissions/my).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _tabs = [
    (route: '/home', icon: Icons.dashboard_rounded, label: 'Accueil', perm: null),
    (
      route: '/students',
      icon: Icons.school_rounded,
      label: 'Élèves',
      perm: 'students.view'
    ),
    (
      route: '/schedule',
      icon: Icons.calendar_month_rounded,
      label: 'Emploi',
      perm: 'schedule.view'
    ),
    (
      route: '/absence',
      icon: Icons.event_busy_rounded,
      label: 'Absences',
      perm: 'attendance.view'
    ),
    (
      route: '/records',
      icon: Icons.fact_check_rounded,
      label: 'Séances',
      perm: 'teachers.view'
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider).valueOrNull;

    final visible = _tabs.where((t) {
      if (t.perm == null) return true;
      // Tant que les permissions chargent, on montre tout ; le serveur reste
      // le garde-fou final sur chaque endpoint.
      if (perms == null) return true;
      if (t.route == '/schedule') {
        return perms.canAny(['schedule.view', 'schedule.view_own']);
      }
      if (t.route == '/absence') {
        return perms.canAny(
            ['attendance.view', 'attendance.edit', 'attendance.view_own_levels']);
      }
      if (t.route == '/records') {
        return perms.canAny(
            ['teachers.view', 'teachers.new_record', 'teachers.view_records']);
      }
      return perms.can(t.perm!);
    }).toList();

    var index = visible.indexWhere((t) => location.startsWith(t.route));
    if (index < 0) index = 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(visible[i].route),
        destinations: [
          for (final t in visible)
            NavigationDestination(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }
}
