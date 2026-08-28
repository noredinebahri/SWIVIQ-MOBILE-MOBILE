import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/auth/auth_providers.dart';
import 'core/config/center_config.dart';
import 'core/notifications/notification_service.dart';
import 'features/student_portal/student_portal_repo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Dates en français (« mercredi 6 août 2026 ») pour DateFormat(..., 'fr').
  await initializeDateFormatting('fr');
  await Workmanager().initialize(notificationCallbackDispatcher);
  await NotificationService.instance.init();
  runApp(const ProviderScope(child: OxygeneApp()));
}

/// Mode sombre persistant (bonus confort).
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'ox_theme_mode';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    if (v == 'dark') state = ThemeMode.dark;
    if (v == 'light') state = ThemeMode.light;
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, next == ThemeMode.dark ? 'dark' : 'light');
  }
}

class OxygeneApp extends ConsumerStatefulWidget {
  const OxygeneApp({super.key});

  @override
  ConsumerState<OxygeneApp> createState() => _OxygeneAppState();
}

class _OxygeneAppState extends ConsumerState<OxygeneApp> {
  @override
  void initState() {
    super.initState();
    // Le tap sur une notification navigue directement vers l'écran cible
    // (ex. « élèves qui paient demain » → liste des échéances).
    NotificationService.instance.onTapRoute = (route) {
      ref.read(routerProvider).push(route);
    };
    // Restaure la session au démarrage puis lance le suivi notifications.
    Future.microtask(() async {
      // Marque blanche : le centre adopté d'abord — l'en-tête X-Tenant-Id doit
      // être armé avant la moindre requête, et le routeur attend ce signal
      // pour décider entre l'écran code-centre et la suite.
      await ref.read(centerConfigProvider.notifier).restore();
      ref.read(centerConfigReadyProvider.notifier).state = true;
      // Espace élève d'abord : son jeton porte `scope: student`, donc la
      // session personnel resterait vide de toute façon.
      await ref.read(studentAuthProvider.notifier).restore();
      if (ref.read(studentAuthProvider) != null) {
        // Élève connecté : surveille les nouvelles versions d'emploi du temps
        // (app ouverte et en tâche de fond).
        await NotificationService.instance.startWatching();
        final payload =
            await NotificationService.instance.takeLaunchPayload();
        if (payload == 'schedule_updated') {
          ref.read(routerProvider).push('/eleve');
        }
        return;
      }
      await ref.read(authProvider.notifier).restore();
      if (ref.read(authProvider).isLoggedIn) {
        await NotificationService.instance.startWatching();
        // App lancée depuis une notification (app tuée) : rejoue le tap.
        final payload =
            await NotificationService.instance.takeLaunchPayload();
        if (payload == 'payments_due') {
          ref.read(routerProvider).push('/payments/due');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final mode = ref.watch(themeModeProvider);

    // Démarre/arrête le suivi notifications selon l'état de connexion.
    ref.listen(authProvider, (prev, next) {
      if (prev?.isLoggedIn != true && next.isLoggedIn) {
        NotificationService.instance.startWatching();
      } else if (prev?.isLoggedIn == true && !next.isLoggedIn) {
        NotificationService.instance.stopWatching();
      }
    });

    // Idem pour l'espace élève (surveillance de l'emploi du temps).
    ref.listen(studentAuthProvider, (prev, next) {
      if (prev == null && next != null) {
        NotificationService.instance.startWatching();
      } else if (prev != null && next == null) {
        NotificationService.instance.stopWatching();
      }
    });

    // Marque blanche : le nom et la couleur de marque du centre adopté
    // habillent toute l'application.
    final center = ref.watch(centerConfigProvider);
    final seed = center?.seedColor;

    return MaterialApp.router(
      title: center?.name ?? 'Mon Centre',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light, seed: seed),
      darkTheme: buildTheme(Brightness.dark, seed: seed),
      themeMode: mode,
      routerConfig: router,
    );
  }
}
