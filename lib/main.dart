import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_providers.dart';
import 'core/config/center_config.dart';
import 'core/notifications/notification_service.dart';
import 'features/student_portal/student_portal_repo.dart';

/// Vrai quand le disjoncteur du client HTTP est ouvert (serveur en
/// difficulté) : un bandeau le dit à l'utilisateur au lieu de laisser chaque
/// écran échouer en silence.
final serverUnavailable = ValueNotifier<bool>(false);

Future<void> main() async {
  // ─── Filets de sécurité : l'application ne « plante » jamais ───
  //
  // Une exception non rattrapée dans un widget, une future oubliée, un
  // callback natif : par défaut Flutter affiche un écran rouge en debug et
  // ferme l'application en release. Ici tout est journalisé et absorbé ;
  // l'écran fautif montre un message discret avec « Réessayer », le reste de
  // l'application continue.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('Flutter error: ${details.exceptionAsString()}');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Uncaught: $error\n$stack');
      return true; // absorbé
    };
    ErrorWidget.builder = (details) => _ErrorFallback(details: details);

    // Dates en français (« mercredi 6 août 2026 ») pour DateFormat(..., 'fr').
    await initializeDateFormatting('fr');
    await Workmanager().initialize(notificationCallbackDispatcher);
    await NotificationService.instance.init();
    ApiClient.instance.onCircuitChanged = (open) => serverUnavailable.value = open;
    runApp(const ProviderScope(child: OxygeneApp()));
  }, (error, stack) {
    debugPrint('Zone error: $error\n$stack');
  });
}

/// Remplace l'écran rouge de Flutter par un message sobre : l'utilisateur
/// voit quoi faire, l'application reste ouverte.
class _ErrorFallback extends StatelessWidget {
  const _ErrorFallback({required this.details});
  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40, color: Colors.orange),
              const SizedBox(height: 12),
              const Text(
                'Un problème d\'affichage est survenu.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Revenez en arrière puis réessayez.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

class _OxygeneAppState extends ConsumerState<OxygeneApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// App masquée → le poll s'arrête (WorkManager veille) ; app de retour →
  /// vérification immédiate puis reprise de la cadence.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    NotificationService.instance
        .setForeground(state == AppLifecycleState.resumed);
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
      // Bandeau « serveur indisponible » au-dessus de tous les écrans.
      builder: (context, child) => _ServerBanner(child: child ?? const SizedBox()),
    );
  }
}

class _ServerBanner extends StatelessWidget {
  const _ServerBanner({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: serverUnavailable,
      builder: (context, open, _) {
        if (!open) return child;
        return Stack(
          children: [
            child,
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Material(
                  color: Colors.orange.shade700,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Serveur momentanément indisponible — nouvelle tentative automatique dans quelques secondes.',
                            style: TextStyle(color: Colors.white, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
