import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'response_cache.dart';

const kBaseUrl = 'https://atlasapi.swiviq.com/api/v1';
const kTokenKey = 'ox_jwt';

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

class TokenStore {
  static String? _cached;
  static bool _loaded = false;

  /// Lecture mémoïsée : le coffre chiffré coûte un aller-retour plateforme à
  /// chaque appel, et CHAQUE requête le lisait. Une centaine de requêtes par
  /// session, c'est une centaine de lectures évitées.
  static Future<String?> read() async {
    if (_loaded) return _cached;
    _cached = await _storage.read(key: kTokenKey);
    _loaded = true;
    return _cached;
  }

  static Future<void> write(String token) async {
    _cached = token;
    _loaded = true;
    await _storage.write(key: kTokenKey, value: token);
  }

  static Future<void> clear() async {
    _cached = null;
    _loaded = true;
    await _storage.delete(key: kTokenKey);
    // Un autre compte ne doit rien retrouver du précédent.
    await ResponseCache.instance.clear();
  }
}

/// Politique de cache d'un GET.
enum CachePolicy {
  /// Réseau uniquement (comportement historique).
  network,

  /// Copie locale si récente (< [ApiClient.freshFor]), sinon réseau ; repli
  /// sur la copie locale quel que soit son âge si le réseau échoue.
  cacheFirst,

  /// Réseau d'abord, repli sur la copie locale (même ancienne) si le réseau
  /// échoue — l'écran ne se vide jamais parce que la 4G a lâché.
  networkFirst,
}

/// Client HTTP unique.
///
/// Ce que le client garantit, quel que soit l'état du réseau ou du serveur :
///
///  * **Relance avec recul exponentiel** (GET et autres lectures) sur les
///    coupures réseau, les 502/503/504 et les 429 — en respectant
///    `Retry-After`. Jamais sur un POST : on ne veut pas payer deux fois ni
///    enregistrer deux absences.
///  * **Disjoncteur** : après 5 échecs serveur d'affilée, plus aucun appel
///    pendant 20 s (puis un seul appel d'essai). Cent téléphones qui
///    martèlent un serveur en difficulté l'empêchent de se relever ; le
///    disjoncteur est ce qui lui laisse l'air de respirer.
///  * **Fusion des GET identiques en vol** : deux écrans qui demandent la
///    même liste au même instant ne déclenchent qu'UNE requête.
///  * **Limite de concurrence** (6 requêtes en parallèle) : un écran qui
///    en lance quinze ne sature ni la radio du téléphone ni le serveur.
///  * **Cache disque + ETag** ([CachePolicy]) : affichage instantané,
///    hors-ligne fonctionnel, et 304 gratuits quand rien n'a changé.
///  * **401** → déconnexion globale (callback) ; **429** → message clair.
class ApiClient {
  ApiClient._() {
    dio = Dio(BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 25),
      headers: {'Content-Type': 'application/json'},
      // 304 = « rien de neuf » : on le traite nous-mêmes, pas comme une erreur.
      validateStatus: (s) => s != null && (s < 400 || s == 304),
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStore.read();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // Marque blanche : le backend SaaS isole les données par tenant.
        if (tenantId != null) {
          options.headers['X-Tenant-Id'] = tenantId.toString();
        }
        options.headers['X-Client'] = 'oxygene-mobile';
        handler.next(options);
      },
    ));
  }

  static final ApiClient instance = ApiClient._();
  late final Dio dio;

  /// Tenant du centre adopté (marque blanche). Posé par CenterConfigNotifier
  /// au démarrage et à chaque changement de centre ; null tant qu'aucun code
  /// centre n'a été saisi.
  int? tenantId;

  /// Callback branché par la couche auth : appelé sur 401 pour forcer la
  /// déconnexion globale.
  void Function()? onUnauthorized;

  /// Notifié quand le disjoncteur s'ouvre/se ferme (bandeau « serveur
  /// indisponible » dans l'interface).
  void Function(bool open)? onCircuitChanged;

  /// Âge en dessous duquel une copie locale est servie SANS appel réseau
  /// avec [CachePolicy.cacheFirst].
  Duration freshFor = const Duration(seconds: 30);

  // ─────────────────────────── Disjoncteur ───────────────────────────
  int _consecutiveFailures = 0;
  DateTime? _circuitOpenUntil;
  static const _circuitThreshold = 5;
  static const _circuitCooldown = Duration(seconds: 20);

  bool get circuitOpen =>
      _circuitOpenUntil != null && DateTime.now().isBefore(_circuitOpenUntil!);

  void _recordSuccess() {
    if (_consecutiveFailures > 0 || _circuitOpenUntil != null) {
      final wasOpen = _circuitOpenUntil != null;
      _consecutiveFailures = 0;
      _circuitOpenUntil = null;
      if (wasOpen) onCircuitChanged?.call(false);
    }
  }

  void _recordServerFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= _circuitThreshold && !circuitOpen) {
      _circuitOpenUntil = DateTime.now().add(_circuitCooldown);
      onCircuitChanged?.call(true);
    }
  }

  // ───────────────────── Concurrence et fusion des GET ─────────────────────
  static const _maxConcurrent = 6;
  int _active = 0;
  final _waiting = <Completer<void>>[];
  final _inflightGets = <String, Future<Response<dynamic>>>{};

  Future<void> _acquire() async {
    if (_active < _maxConcurrent) {
      _active++;
      return;
    }
    final c = Completer<void>();
    _waiting.add(c);
    await c.future;
    _active++;
  }

  void _release() {
    _active--;
    if (_waiting.isNotEmpty) _waiting.removeAt(0).complete();
  }

  // ─────────────────────────── Relances ───────────────────────────
  static const _maxRetries = 3;
  final _random = Random();

  bool _isRetryable(DioException e) {
    final status = e.response?.statusCode;
    if (status == 429 || status == 502 || status == 503 || status == 504) {
      return true;
    }
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  Duration _backoff(int attempt, DioException e) {
    final retryAfter = e.response?.headers.value('retry-after');
    if (retryAfter != null) {
      final secs = int.tryParse(retryAfter.trim());
      if (secs != null && secs > 0 && secs <= 60) return Duration(seconds: secs);
    }
    // 0,6 s · 1,2 s · 2,4 s, ± 30 % de gigue : cent téléphones qui retentent
    // ne le font pas au même instant.
    final base = 600 * pow(2, attempt).toInt();
    final jitter = (base * 0.3 * (_random.nextDouble() * 2 - 1)).round();
    return Duration(milliseconds: base + jitter);
  }

  Future<Response<dynamic>> _withRetry(
    Future<Response<dynamic>> Function() call, {
    required bool idempotent,
  }) async {
    if (circuitOpen) {
      throw ApiException(
        'Serveur momentanément indisponible. Nouvelle tentative dans quelques secondes.',
        statusCode: 503,
        circuitOpen: true,
      );
    }
    var attempt = 0;
    while (true) {
      await _acquire();
      Response<dynamic> res;
      try {
        res = await call();
      } on DioException catch (e) {
        _release();
        final status = e.response?.statusCode;
        final serverSide = status == null || status >= 500 || status == 429;
        if (serverSide) _recordServerFailure();
        if (idempotent &&
            attempt < _maxRetries &&
            _isRetryable(e) &&
            !circuitOpen) {
          attempt++;
          await Future.delayed(_backoff(attempt - 1, e));
          continue;
        }
        rethrow;
      } catch (_) {
        _release();
        rethrow;
      }
      _release();
      _recordSuccess();
      return res;
    }
  }

  ApiException _toException(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) onUnauthorized?.call();
    final body = e.response?.data;
    String message;
    if (status == 429) {
      message = 'Trop de demandes en même temps. Patientez quelques secondes.';
    } else if (body is Map && body['message'] != null) {
      message = body['message'].toString();
    } else if (body is Map && body['messageFr'] != null) {
      message = body['messageFr'].toString();
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      message = 'Connexion impossible. Vérifiez votre réseau.';
    } else if (status != null && status >= 500) {
      message = 'Le serveur rencontre un problème ($status). Réessayez dans un instant.';
    } else {
      message = 'Une erreur est survenue ($status).';
    }
    return ApiException(message, statusCode: status, body: body);
  }

  Future<T> _run<T>(
    Future<Response<dynamic>> Function() call,
    T Function(dynamic data) map, {
    bool idempotent = false,
  }) async {
    try {
      final res = await _withRetry(call, idempotent: idempotent);
      return map(res.data);
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  // ─────────────────────────── API publique ───────────────────────────

  /// GET. Avec [cache] autre que [CachePolicy.network], la copie disque est
  /// utilisée selon la politique ; `onRefreshed` est appelé si un appel
  /// réseau a rapporté une donnée différente de celle servie depuis le
  /// cache (pour rafraîchir l'écran après un affichage instantané).
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    CachePolicy cache = CachePolicy.network,
    void Function(dynamic fresh)? onRefreshed,
  }) async {
    if (cache == CachePolicy.network) {
      return _getNetwork(path, query);
    }
    final token = await TokenStore.read();
    final tail = token == null || token.length < 12
        ? null
        : token.substring(token.length - 12);
    final key = ResponseCache.keyFor(path, query, tail);
    final cached = await ResponseCache.instance.read(key);

    if (cache == CachePolicy.cacheFirst && cached != null && cached.age < freshFor) {
      // Frais : on sert la copie et on ne touche pas au réseau.
      return cached.data;
    }

    if (cache == CachePolicy.cacheFirst && cached != null) {
      // Copie périmée : on la sert tout de suite, le réseau rafraîchit
      // derrière (stale-while-revalidate) et prévient si ça a changé.
      unawaited(_revalidate(path, query, key, cached, onRefreshed));
      return cached.data;
    }

    // networkFirst, ou cacheFirst sans copie : réseau, repli sur la copie.
    try {
      return await _getNetworkCached(path, query, key, cached);
    } on ApiException catch (e) {
      if (cached != null && (e.statusCode == null || e.statusCode! >= 500 || e.statusCode == 429)) {
        return cached.data;
      }
      rethrow;
    }
  }

  Future<void> _revalidate(
    String path,
    Map<String, dynamic>? query,
    String key,
    CacheEntry cached,
    void Function(dynamic fresh)? onRefreshed,
  ) async {
    try {
      final fresh = await _getNetworkCached(path, query, key, cached);
      if (onRefreshed != null && !identical(fresh, cached.data)) {
        onRefreshed(fresh);
      }
    } catch (_) {
      // Hors-ligne : la copie servie reste la bonne réponse.
    }
  }

  Future<dynamic> _getNetworkCached(
    String path,
    Map<String, dynamic>? query,
    String key,
    CacheEntry? cached,
  ) async {
    final headers = <String, dynamic>{};
    if (cached?.etag != null) headers['If-None-Match'] = cached!.etag;
    final res = await _rawGet(path, query, headers);
    if (res.statusCode == 304 && cached != null) {
      unawaited(ResponseCache.instance.touch(key));
      return cached.data;
    }
    final etag = res.headers.value('etag');
    unawaited(ResponseCache.instance.write(key, res.data, etag: etag));
    return res.data;
  }

  Future<dynamic> _getNetwork(String path, Map<String, dynamic>? query) async {
    final res = await _rawGet(path, query, const {});
    return res.data;
  }

  /// GET brut avec fusion des appels identiques en vol.
  Future<Response<dynamic>> _rawGet(
    String path,
    Map<String, dynamic>? query,
    Map<String, dynamic> headers,
  ) async {
    final flightKey = ResponseCache.keyFor(path, query, headers['If-None-Match']?.toString());
    final existing = _inflightGets[flightKey];
    if (existing != null) {
      try {
        return await existing;
      } on DioException catch (e) {
        throw _toException(e);
      }
    }
    final future = _withRetry(
      () => dio.get(path, queryParameters: query, options: Options(headers: headers)),
      idempotent: true,
    );
    _inflightGets[flightKey] = future;
    try {
      return await future;
    } on DioException catch (e) {
      throw _toException(e);
    } finally {
      _inflightGets.remove(flightKey);
    }
  }

  Future<dynamic> post(String path, {Object? data}) =>
      _run(() => dio.post(path, data: data), (d) => d);

  Future<dynamic> put(String path, {Object? data}) =>
      _run(() => dio.put(path, data: data), (d) => d, idempotent: true);

  Future<dynamic> patch(String path, {Object? data}) =>
      _run(() => dio.patch(path, data: data), (d) => d);

  Future<dynamic> delete(String path, {Object? data}) =>
      _run(() => dio.delete(path, data: data), (d) => d, idempotent: true);
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.body, this.circuitOpen = false});
  final String message;
  final int? statusCode;
  final dynamic body;

  /// Vrai quand l'appel n'est même pas parti : le disjoncteur est ouvert.
  final bool circuitOpen;

  bool get isNetwork => statusCode == null;
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => message;
}
