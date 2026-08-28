import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const kBaseUrl = 'https://atlasapi.swiviq.com/api/v1';
const kTokenKey = 'ox_jwt';

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

class TokenStore {
  static Future<String?> read() => _storage.read(key: kTokenKey);
  static Future<void> write(String token) =>
      _storage.write(key: kTokenKey, value: token);
  static Future<void> clear() => _storage.delete(key: kTokenKey);
}

/// Client HTTP unique : injecte le Bearer token, normalise les erreurs en
/// [ApiException] avec un message affichable.
class ApiClient {
  ApiClient._() {
    dio = Dio(BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
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

  Future<T> _run<T>(Future<Response<dynamic>> Function() call,
      T Function(dynamic data) map) async {
    try {
      final res = await call();
      return map(res.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) onUnauthorized?.call();
      final body = e.response?.data;
      String message;
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      } else if (body is Map && body['messageFr'] != null) {
        message = body['messageFr'].toString();
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        message = 'Connexion impossible. Vérifiez votre réseau.';
      } else {
        message = 'Une erreur est survenue ($status).';
      }
      throw ApiException(message, statusCode: status, body: body);
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _run(() => dio.get(path, queryParameters: query), (d) => d);

  Future<dynamic> post(String path, {Object? data}) =>
      _run(() => dio.post(path, data: data), (d) => d);

  Future<dynamic> put(String path, {Object? data}) =>
      _run(() => dio.put(path, data: data), (d) => d);

  Future<dynamic> patch(String path, {Object? data}) =>
      _run(() => dio.patch(path, data: data), (d) => d);

  Future<dynamic> delete(String path, {Object? data}) =>
      _run(() => dio.delete(path, data: data), (d) => d);
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.body});
  final String message;
  final int? statusCode;
  final dynamic body;

  @override
  String toString() => message;
}
