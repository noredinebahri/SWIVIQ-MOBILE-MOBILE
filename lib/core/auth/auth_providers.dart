import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'session.dart';

/// État global d'authentification. `user == null` → non connecté.
class AuthState {
  const AuthState({this.user, this.loading = false});
  final SessionUser? user;
  final bool loading;

  bool get isLoggedIn => user != null;

  AuthState copyWith({SessionUser? user, bool? loading, bool clearUser = false}) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        loading: loading ?? this.loading,
      );
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    ApiClient.instance.onUnauthorized = logoutSilently;
    return const AuthState(loading: true);
  }

  final _api = ApiClient.instance;

  /// Appelé au démarrage : restaure la session si un token valide existe.
  Future<void> restore() async {
    final token = await TokenStore.read();
    if (token == null) {
      state = const AuthState();
      return;
    }
    final user = SessionUser.fromToken(token);
    if (user == null) {
      await TokenStore.clear();
      state = const AuthState();
      return;
    }
    state = AuthState(user: user);
  }

  Future<SessionUser> login(String emailsec, String password) async {
    final data = await _api
        .post('/user/login', data: {'emailsec': emailsec, 'password': password});
    final token = (data as Map)['token']?.toString();
    if (token == null) throw ApiException('Réponse inattendue du serveur.');
    final user = SessionUser.fromToken(token);
    if (user == null) throw ApiException('Jeton invalide.');
    await TokenStore.write(token);
    state = AuthState(user: user);
    // Invalide le cache des permissions pour le nouvel utilisateur.
    ref.invalidate(permissionsProvider);
    return user;
  }

  Future<Map<String, dynamic>> forgotPassword(
      String emailsec, String tel) async {
    final data = await _api
        .post('/user/forgetPassword', data: {'emailsec': emailsec, 'tel': tel});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> logout() async {
    try {
      await _api.post('/user/logout');
    } catch (_) {
      // La déconnexion locale doit réussir même hors-ligne.
    }
    await logoutSilently();
  }

  Future<void> logoutSilently() async {
    await TokenStore.clear();
    state = const AuthState();
  }

  /// Met à jour infos et/ou mot de passe de l'utilisateur connecté.
  Future<void> updateProfile({
    String? firstname,
    String? lastname,
    String? email,
    String? phone,
    String? password,
    String? currentPassword,
  }) async {
    final user = state.user;
    if (user == null) throw ApiException('Non connecté.');
    final body = <String, dynamic>{};
    if (firstname != null) body['firstname'] = firstname;
    if (lastname != null) body['lastname'] = lastname;
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    if (password != null && password.isNotEmpty) {
      body['password'] = password;
      body['currentPassword'] = currentPassword;
    }
    await _api.put('/user/updateInfosTeacher/${user.id}', data: body);
    // Le backend ne renvoie pas l'objet à jour : on rafraîchit l'état local.
    state = AuthState(
      user: SessionUser(
        id: user.id,
        firstname: firstname ?? user.firstname,
        lastname: lastname ?? user.lastname,
        role: user.role,
        emailsec: user.emailsec,
        email: email ?? user.email,
        phone: phone ?? user.phone,
        photo: user.photo,
        function: user.function,
        tenantId: user.tenantId,
      ),
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Permissions de l'utilisateur connecté (GET /permissions/my).
final permissionsProvider = FutureProvider<UserPermissions>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isLoggedIn) {
    return UserPermissions(role: '', codes: {}, menu: []);
  }
  final data = await ApiClient.instance.get('/permissions/my');
  final payload = (data as Map)['data'];
  return UserPermissions.fromJson(Map<String, dynamic>.from(payload as Map));
});
