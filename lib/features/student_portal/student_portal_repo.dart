import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/session.dart';
import '../../core/models/json_utils.dart';
import '../../core/models/schedule.dart';
import '../../core/models/student.dart';
import 'polycopie_cache.dart';
import 'schedule_cache.dart';

/// Espace élève : connexion par numéro d'élève + téléphone, puis lecture
/// seule de SES données (le jeton `scope: student` n'ouvre rien d'autre).
class StudentPortalRepo {
  static final _api = ApiClient.instance;

  /// Connexion. `identifier` = numéro d'élève ou numéro de centre.
  static Future<StudentSession> login({
    required String identifier,
    required String phone,
  }) async {
    final data = await _api.post('/student/portal/login', data: {
      'identifier': identifier.trim(),
      'phone': phone.trim(),
    });
    final token = (data as Map)['token']?.toString();
    if (token == null) throw ApiException('Réponse inattendue du serveur.');
    final session = StudentSession.fromToken(token);
    if (session == null) throw ApiException('Jeton invalide.');
    await TokenStore.write(token);
    return session;
  }

  static Future<Student> me() async {
    final data = await _api.get('/student/portal/me');
    final payload = unwrap(data);
    return Student.fromJson(Map<String, dynamic>.from(payload as Map));
  }

  /// « Pouls » : les versions seules (emploi du temps, polycopiés). Réponse
  /// minuscule, mise en cache 45 s côté serveur — c'est l'appel que le poll
  /// répète, les données complètes ne sont chargées qu'au changement.
  static Future<({String? schedule, String? polycopies})> pulse() async {
    final data = await _api.get('/student/portal/pulse');
    final map = data is Map ? data : const {};
    return (
      schedule: map['schedule']?.toString(),
      polycopies: map['polycopies']?.toString(),
    );
  }

  static Future<String?> cachedScheduleVersion() => ScheduleCache.readVersion();
  static Future<String?> cachedPolycopiesVersion() =>
      PolycopieCache.readVersion();

  /// Polycopiés DEPUIS LE SERVEUR, avec version. Écrit la copie hors-ligne
  /// et supprime les fichiers devenus obsolètes ou retirés à l'élève.
  /// `changed` = la liste ou un fichier a changé depuis la dernière fois.
  static Future<({List<StudentPolycopieFile> items, bool changed})>
      fetchPolycopies() async {
    final data = await _api.get('/student/portal/polycopies');
    final map = data is Map ? Map<String, dynamic>.from(data) : {};
    final rawItems = asMapList(data);
    final version = map['version']?.toString() ?? '';

    final previous = await PolycopieCache.readVersion();
    final changed =
        previous != null && previous.isNotEmpty && previous != version;

    final items = rawItems.map(StudentPolycopieFile.fromJson).toList();
    await PolycopieCache.saveList(items: rawItems, version: version);
    // Les supports retirés à l'élève ne restent pas sur son téléphone.
    await PolycopieCache.pruneMissing(items.map((e) => e.polycopieId).toSet());

    return (items: items, changed: changed);
  }

  /// Polycopiés utilisables hors-ligne : la copie locale.
  static Future<List<StudentPolycopieFile>> cachedPolycopies() async {
    final raw = await PolycopieCache.readList();
    return raw.map(StudentPolycopieFile.fromJson).toList();
  }

  /// Emploi du temps DEPUIS LE SERVEUR, avec sa version. Écrit aussitôt la
  /// copie hors-ligne (l'ancienne version est écrasée).
  /// `changed` = la version reçue diffère de celle déjà en cache.
  static Future<({List<ScheduleSlot> slots, String version, bool changed})>
      fetchSchedule() async {
    final data = await _api.get('/student/portal/schedule');
    final map = data is Map ? Map<String, dynamic>.from(data) : {};
    final rawSlots = asMapList(data);
    final version = map['version']?.toString() ?? '';

    final previous = await ScheduleCache.readVersion();
    final changed = previous != null && previous.isNotEmpty && previous != version;

    await ScheduleCache.save(rawSlots: rawSlots, version: version);
    return (
      slots: rawSlots.map(ScheduleSlot.fromJson).toList(),
      version: version,
      changed: changed,
    );
  }

  /// Emploi du temps utilisable hors-ligne : la copie locale.
  static Future<List<ScheduleSlot>> cachedSchedule() =>
      ScheduleCache.readSlots();

  /// Télécharge le polycopié et le CONSERVE sur l'appareil (consultable
  /// ensuite hors connexion). Retourne le chemin du fichier local.
  static Future<String> downloadPolycopie(StudentPolycopieFile p) async {
    final token = await TokenStore.read();
    final path = await PolycopieCache.pathFor(p.polycopieId);
    await Dio().download(
      '$kBaseUrl/student/portal/polycopie/${p.polycopieId}/file',
      path,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    await PolycopieCache.markDownloaded(p.polycopieId, p.fileVersion);
    return path;
  }

  /// Fichier déjà téléchargé et toujours à jour (null sinon).
  static Future<String?> localPolycopieFile(StudentPolycopieFile p) =>
      PolycopieCache.localFile(p.polycopieId, p.fileVersion);
}

/// Polycopié vu par l'élève : téléchargeable seulement une fois réglé.
class StudentPolycopieFile {
  StudentPolycopieFile({
    required this.polycopieId,
    required this.name,
    this.description,
    this.price = 0,
    this.paid = 0,
    this.remaining = 0,
    this.status = 'active',
    this.hasFile = false,
    this.fileName,
    this.downloadable = false,
    this.fileVersion,
  });

  final int polycopieId;
  final String name;
  final String? description;
  final num price;
  final num paid;
  final num remaining;
  final String status;
  final bool hasFile;
  final String? fileName;
  final bool downloadable;

  /// Version du fichier côté serveur : si elle change, la copie locale est
  /// périmée et doit être retéléchargée.
  final String? fileVersion;

  factory StudentPolycopieFile.fromJson(Map<String, dynamic> j) =>
      StudentPolycopieFile(
        polycopieId: asInt(j['polycopieId']),
        name: j['name']?.toString() ?? '',
        description: asStringOrNull(j['description']),
        price: asNum(j['price']),
        paid: asNum(j['paid']),
        remaining: asNum(j['remaining']),
        status: j['status']?.toString() ?? 'active',
        hasFile: asBool(j['hasFile']),
        fileName: asStringOrNull(j['fileName']),
        downloadable: asBool(j['downloadable']),
        fileVersion: asStringOrNull(j['fileVersion']),
      );
}

/// Session élève courante (null = pas d'élève connecté).
class StudentAuthNotifier extends Notifier<StudentSession?> {
  @override
  StudentSession? build() => null;

  Future<StudentSession> login(String identifier, String phone) async {
    final session =
        await StudentPortalRepo.login(identifier: identifier, phone: phone);
    state = session;
    return session;
  }

  Future<void> restore() async {
    final token = await TokenStore.read();
    state = token == null ? null : StudentSession.fromToken(token);
  }

  Future<void> logout() async {
    await TokenStore.clear();
    // Les données de l'élève ne doivent pas survivre à sa déconnexion.
    await ScheduleCache.clear();
    await PolycopieCache.clear();
    state = null;
  }
}

final studentAuthProvider =
    NotifierProvider<StudentAuthNotifier, StudentSession?>(
        StudentAuthNotifier.new);
