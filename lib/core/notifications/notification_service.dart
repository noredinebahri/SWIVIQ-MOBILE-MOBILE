import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../api/api_client.dart';
import '../auth/session.dart';
import '../config/center_config.dart';
import '../models/records.dart';
import '../repositories.dart';
import '../../features/student_portal/student_portal_repo.dart';

/// Notifications ciblées par prof, sans dépendance Firebase : chaque appareil
/// interroge l'API avec le JWT de SON utilisateur, donc un prof ne peut voir
/// (et être notifié) que de SES propres records — le ciblage est garanti par
/// l'authentification elle-même.
///
/// Deux mécanismes complémentaires :
///  * un poll en avant-plan (app ouverte) toutes les 60 s ;
///  * une tâche périodique WorkManager (~15 min mini sur Android) quand
///    l'app est fermée.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  Timer? _foregroundTimer;
  static const _taskName = 'ox_records_check';
  static const _knownIdsKey = 'ox_known_validated_ids';
  static const _knownPendingKey = 'ox_known_record_ids';

  // Notification « élèves qui paient demain » (manager/directeur).
  static const _mpDateKey = 'ox_mp_date'; // jour des compteurs
  static const _mpSentKey = 'ox_mp_sent'; // notifications envoyées ce jour
  static const _mpLastKey = 'ox_mp_last'; // epoch ms du dernier envoi
  static const _mpClickedKey = 'ox_mp_clicked'; // jour où le manager a cliqué
  static const _mpConfigKey = 'ox_mp_config'; // cache du réglage serveur
  static const _mpConfigAtKey = 'ox_mp_config_at';
  static const managerPaymentsNotifId = 777001;
  static const scheduleUpdatedNotifId = 777002;
  static const polycopiesUpdatedNotifId = 777003;

  /// Navigation à effectuer quand une notification est touchée
  /// (branchée par main.dart sur le routeur).
  void Function(String route)? onTapRoute;

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS : les permissions se demandent à l'initialisation (pas d'appel
    // séparé comme sur Android). Sans cela, aucune notification n'apparaît
    // et le système ne redemande jamais.
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: (response) {
        _handleTap(response.payload);
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    // Sur iOS la demande passe par l'implémentation Darwin ; l'appel est
    // sans effet si l'utilisateur a déjà répondu.
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Payload de la notification qui a LANCÉ l'app (app tuée), à consommer
  /// au démarrage.
  Future<String?> takeLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      return details!.notificationResponse?.payload;
    }
    return null;
  }

  Future<void> _handleTap(String? payload) async {
    if (payload == 'payments_due') {
      // Le clic arrête les répétitions du jour.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_mpClickedKey, _todayYmd());
      onTapRoute?.call('/payments/due');
    } else if (payload == 'schedule_updated' ||
        payload == 'polycopies_updated') {
      onTapRoute?.call('/eleve');
    }
  }

  static String _todayYmd() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ───────────── Cadence du poll en avant-plan ─────────────
  //
  // Pas de Timer.periodic figé à 60 s : chaque cycle se replanifie lui-même
  // avec une gigue de ±20 % (des centaines de téléphones ne frappent pas le
  // serveur à la même seconde), l'intervalle double à chaque échec réseau
  // (jusqu'à 10 min) et revient à la normale au premier succès. En arrière-
  // plan (app masquée), le poll s'arrête : WorkManager prend le relais.
  static const _baseInterval = Duration(seconds: 90);
  static const _maxInterval = Duration(minutes: 10);
  Duration _currentInterval = _baseInterval;
  bool _watching = false;
  bool _foreground = true;
  bool _cycleRunning = false;
  final _jitter = Random();

  void _scheduleNext() {
    _foregroundTimer?.cancel();
    if (!_watching || !_foreground) return;
    final ms = _currentInterval.inMilliseconds;
    final delay = Duration(
        milliseconds: (ms * (0.8 + _jitter.nextDouble() * 0.4)).round());
    _foregroundTimer = Timer(delay, _runCycle);
  }

  Future<void> _runCycle() async {
    if (_cycleRunning) return;
    _cycleRunning = true;
    try {
      final ok = await checkNewRecords(notify: true);
      _currentInterval = ok
          ? _baseInterval
          : Duration(
              milliseconds: min(_currentInterval.inMilliseconds * 2,
                  _maxInterval.inMilliseconds));
    } finally {
      _cycleRunning = false;
      _scheduleNext();
    }
  }

  /// Appelé par l'app au changement d'état (premier plan / arrière-plan).
  void setForeground(bool foreground) {
    if (_foreground == foreground) return;
    _foreground = foreground;
    if (foreground) {
      // Retour au premier plan : vérification immédiate (l'utilisateur
      // regarde), puis reprise de la cadence.
      _currentInterval = _baseInterval;
      if (_watching) unawaited(_runCycle());
    } else {
      _foregroundTimer?.cancel();
    }
  }

  /// Démarre le suivi pour l'utilisateur connecté (appelé après login).
  Future<void> startWatching() async {
    _watching = true;
    _currentInterval = _baseInterval;
    // Amorce la mémoire des ids connus sans notifier (évite une rafale de
    // notifications au premier lancement).
    await checkNewRecords(notify: false);
    _scheduleNext();

    // Tâche de fond : sur Android elle tourne toutes les ~15 min. Sur iOS,
    // `registerPeriodicTask` n'existe pas — le système décide seul du moment
    // via BGTaskScheduler, et rien n'est garanti. La vérification à chaque
    // ouverture de l'app reste donc le filet de sécurité sur iPhone.
    try {
      if (Platform.isAndroid) {
        await Workmanager().registerPeriodicTask(
          _taskName,
          _taskName,
          frequency: const Duration(minutes: 15),
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        );
      } else if (Platform.isIOS) {
        await Workmanager().registerProcessingTask(
          _taskName,
          _taskName,
          initialDelay: const Duration(minutes: 15),
          constraints: Constraints(networkType: NetworkType.connected),
        );
      }
    } catch (_) {
      // Plateforme sans tâches de fond : le suivi en avant-plan suffit.
    }
  }

  Future<void> stopWatching() async {
    _watching = false;
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    await Workmanager().cancelByUniqueName(_taskName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_knownIdsKey);
    await prefs.remove(_knownPendingKey);
  }

  /// Compare l'état serveur aux ids déjà vus et notifie les nouveautés.
  /// Retourne `false` si le réseau ou le serveur a fait défaut (la cadence
  /// du poll s'espace alors).
  Future<bool> checkNewRecords({required bool notify}) async {
    try {
      final token = await TokenStore.read();
      if (token == null) return true;

      // Élève connecté : on surveille sa version d'emploi du temps, rien
      // d'autre (son jeton n'ouvre pas les écrans du personnel).
      final student = StudentSession.fromToken(token);
      if (student != null) {
        if (notify) return _checkStudentSchedule();
        return true;
      }

      final user = SessionUser.fromToken(token);
      if (user == null) return true;

      // Direction : notification du soir « élèves qui paient demain ».
      if (user.isAdmin && notify) {
        await _checkManagerPayments();
      }

      final records = await RecordsRepo.myRecords(user.id);
      final prefs = await SharedPreferences.getInstance();

      final knownValidated =
          (prefs.getStringList(_knownIdsKey) ?? []).toSet();
      final knownAll = (prefs.getStringList(_knownPendingKey) ?? []).toSet();

      final newlyValidated = <TeacherRecord>[];
      final newlyCreated = <TeacherRecord>[];
      for (final r in records) {
        final id = r.id.toString();
        if (r.isValidated && !knownValidated.contains(id)) {
          if (knownAll.contains(id)) newlyValidated.add(r);
          knownValidated.add(id);
        }
        if (!knownAll.contains(id)) {
          if (knownValidated.contains(id) == false &&
              prefs.containsKey(_knownPendingKey)) {
            newlyCreated.add(r);
          }
          knownAll.add(id);
        }
      }

      await prefs.setStringList(_knownIdsKey, knownValidated.toList());
      await prefs.setStringList(_knownPendingKey, knownAll.toList());

      if (!notify) return true;

      // Solde officiel du mois (moteur de paie serveur) pour enrichir la
      // notification de validation : « votre solde sera XX DH ce mois ».
      String? soldeSuffix;
      if (newlyValidated.isNotEmpty) {
        try {
          final now = DateTime.now();
          final payroll = await RecordsRepo.payroll(
            user.id,
            month: now.month,
            year: now.year,
          );
          final total = payroll.grandTotal;
          final totalLabel = total == total.roundToDouble()
              ? total.toStringAsFixed(0)
              : total.toStringAsFixed(2);
          soldeSuffix = ' Votre solde sera $totalLabel DH ce mois.';
        } catch (_) {
          // Paie indisponible : la notification part sans le solde.
        }
      }

      for (final r in newlyValidated) {
        await _show(
          id: r.id,
          title: 'Séance validée ✅',
          body:
              '${r.levelName ?? 'Votre séance'} · ${r.recordTime} min — validée par la direction.${soldeSuffix ?? ''}',
        );
      }
      for (final r in newlyCreated) {
        await _show(
          id: 100000 + r.id,
          title: 'Nouvelle séance enregistrée',
          body:
              '${r.levelName ?? 'Séance'} · ${r.recordTime} min — en attente de validation.',
        );
      }
      return true;
    } catch (_) {
      // Réseau indisponible : on retentera au prochain cycle.
      return false;
    }
  }

  /// Nouvelle version d'emploi du temps publiée ? Remplace la copie locale
  /// et prévient l'élève — y compris quand l'app est fermée (WorkManager).
  ///
  /// Un seul appel léger (`/pulse`, ~100 octets, mis en cache côté serveur)
  /// dit si quelque chose a changé ; l'emploi du temps complet et la liste
  /// des polycopiés ne sont rechargés QUE si leur version diffère de la
  /// copie locale. Avant : deux réponses complètes par cycle et par
  /// téléphone, pour ne rien apprendre 99 fois sur 100.
  Future<bool> _checkStudentSchedule() async {
    ({String? schedule, String? polycopies}) pulse;
    try {
      pulse = await StudentPortalRepo.pulse();
    } on ApiException catch (e) {
      // Serveur ancien sans /pulse : on retombe sur les appels complets.
      if (e.statusCode != 404) return false;
      return _checkStudentScheduleFull();
    } catch (_) {
      return false;
    }

    var ok = true;
    try {
      final local = await StudentPortalRepo.cachedScheduleVersion();
      if (pulse.schedule != null && pulse.schedule != local) {
        final result = await StudentPortalRepo.fetchSchedule();
        if (result.changed) await notifyScheduleUpdated();
      }
    } catch (_) {
      ok = false;
    }
    try {
      final local = await StudentPortalRepo.cachedPolycopiesVersion();
      if (pulse.polycopies != null && pulse.polycopies != local) {
        final polys = await StudentPortalRepo.fetchPolycopies();
        if (polys.changed) await notifyPolycopiesUpdated();
      }
    } catch (_) {
      ok = false;
    }
    return ok;
  }

  Future<bool> _checkStudentScheduleFull() async {
    var ok = true;
    try {
      final result = await StudentPortalRepo.fetchSchedule();
      if (result.changed) await notifyScheduleUpdated();
    } catch (_) {
      ok = false;
    }
    try {
      final polys = await StudentPortalRepo.fetchPolycopies();
      if (polys.changed) await notifyPolycopiesUpdated();
    } catch (_) {
      ok = false;
    }
    return ok;
  }

  // ─────────── Notification « élèves qui paient demain » ───────────
  //
  // Règles (réglables dans Paramètres ▸ Relance des paiements du web) :
  //  * première notification dans la fenêtre [managerNotifStart, hard end] —
  //    par défaut à partir de 19:20 ;
  //  * si le manager ne CLIQUE pas la notification : répétée jusqu'à
  //    `managerNotifRepeats` fois (défaut 3), toutes les
  //    `managerNotifIntervalMin` minutes (défaut 60), jamais après
  //    `managerNotifHardEnd` (défaut 23:50) ;
  //  * le clic ouvre directement la page Échéances et stoppe les rappels.

  static int _parseHhmm(String? v, int fallbackMin) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v ?? '');
    if (m == null) return fallbackMin;
    return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  }

  Future<Map<String, dynamic>> _managerConfig(SharedPreferences prefs) async {
    // Cache 6 h : le réglage change rarement, inutile d'interroger le serveur
    // à chaque cycle de 60 s.
    final cachedAt = prefs.getInt(_mpConfigAtKey) ?? 0;
    final cached = prefs.getString(_mpConfigKey);
    if (cached != null &&
        DateTime.now().millisecondsSinceEpoch - cachedAt < 6 * 3600 * 1000) {
      try {
        return Map<String, dynamic>.from(jsonDecode(cached) as Map);
      } catch (_) {}
    }
    final config = await CollectionsRepo.config();
    await prefs.setString(_mpConfigKey, jsonEncode(config));
    await prefs.setInt(
        _mpConfigAtKey, DateTime.now().millisecondsSinceEpoch);
    return config;
  }

  Future<void> _checkManagerPayments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayYmd();

      // Réinitialise les compteurs au changement de jour.
      if (prefs.getString(_mpDateKey) != today) {
        await prefs.setString(_mpDateKey, today);
        await prefs.setInt(_mpSentKey, 0);
        await prefs.setInt(_mpLastKey, 0);
      }

      if (prefs.getString(_mpClickedKey) == today) return; // déjà ouvert

      final config = await _managerConfig(prefs);
      if (config['managerNotifEnabled'] == false ||
          config['managerNotifEnabled'] == 0) {
        return;
      }
      final startMin =
          _parseHhmm(config['managerNotifStart']?.toString(), 19 * 60 + 20);
      final hardEndMin =
          _parseHhmm(config['managerNotifHardEnd']?.toString(), 23 * 60 + 50);
      final intervalMin = (config['managerNotifIntervalMin'] is num &&
              (config['managerNotifIntervalMin'] as num) > 0)
          ? (config['managerNotifIntervalMin'] as num).toInt()
          : 60;
      final maxRepeats = (config['managerNotifRepeats'] is num)
          ? (config['managerNotifRepeats'] as num).toInt()
          : 3;

      final now = DateTime.now();
      final nowMin = now.hour * 60 + now.minute;
      if (nowMin < startMin || nowMin > hardEndMin) return;

      final sent = prefs.getInt(_mpSentKey) ?? 0;
      // 1 première notification + maxRepeats rappels.
      if (sent >= 1 + maxRepeats) return;
      final lastMs = prefs.getInt(_mpLastKey) ?? 0;
      if (sent > 0 &&
          now.millisecondsSinceEpoch - lastMs < intervalMin * 60 * 1000) {
        return; // prochain rappel pas encore dû
      }

      final entries = await CollectionsRepo.list('tomorrow');
      if (entries.isEmpty) {
        // Rien à annoncer : on marque la journée comme traitée.
        await prefs.setString(_mpClickedKey, today);
        return;
      }

      final total =
          entries.fold<num>(0, (sum, e) => sum + e.amountDue);
      final names = entries.take(4).map((e) => e.name).join(', ');
      final more =
          entries.length > 4 ? ' et ${entries.length - 4} autre(s)' : '';
      await _show(
        id: managerPaymentsNotifId,
        title:
            '💰 ${entries.length} élève(s) doivent payer demain (${total.toStringAsFixed(0)} DH)',
        body:
            '$names$more.\nTouchez pour ouvrir la liste des échéances.',
        payload: 'payments_due',
      );
      await prefs.setInt(_mpSentKey, sent + 1);
      await prefs.setInt(_mpLastKey, now.millisecondsSinceEpoch);
    } catch (_) {
      // Réseau/serveur indisponible : on réessaiera au prochain cycle.
    }
  }

  /// Prévient l'élève qu'une nouvelle version de l'emploi du temps a
  /// remplacé la sienne. Le tap ouvre son espace.
  Future<void> notifyScheduleUpdated() async {
    await _show(
      id: scheduleUpdatedNotifId,
      title: '📅 Nouvel emploi du temps',
      body:
          'Votre emploi du temps a été mis à jour par le centre. '
          "L'ancienne version a été remplacée.",
      payload: 'schedule_updated',
    );
  }

  /// Prévient l'élève qu'un support a été ajouté ou remplacé.
  Future<void> notifyPolycopiesUpdated() async {
    await _show(
      id: polycopiesUpdatedNotifId,
      title: '📚 Polycopiés mis à jour',
      body: 'Un support a été ajouté ou remplacé par le centre. '
          'Ouvrez votre espace pour le télécharger.',
      payload: 'polycopies_updated',
    );
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'records',
        'Séances & validations',
        channelDescription:
            'Notifications quand une séance vous concernant est enregistrée ou validée.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF2563EB),
        styleInformation: BigTextStyleInformation(body),
      ),
      // iOS affiche titre + corps sans notion de canal ; le son et la
      // pastille suivent les réglages accordés à l'installation.
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }
}

/// Point d'entrée de la tâche de fond WorkManager (isolate séparé).
@pragma('vm:entry-point')
void notificationCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Isolat séparé : l'ApiClient y renaît vierge. Sans le tenant du centre
    // adopté (marque blanche), le poll interrogerait le mauvais périmètre.
    final center = await CenterConfigStore.read();
    ApiClient.instance.tenantId = center?.tenantId;
    final service = NotificationService.instance;
    await service.init();
    await service.checkNewRecords(notify: true);
    return true;
  });
}
