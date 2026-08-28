import 'package:jwt_decoder/jwt_decoder.dart';

/// Utilisateur courant, décodé depuis le payload du JWT (le backend ne fournit
/// pas d'endpoint /me : tout vit dans le token).
class SessionUser {
  SessionUser({
    required this.id,
    required this.firstname,
    required this.lastname,
    required this.role,
    this.emailsec,
    this.email,
    this.phone,
    this.photo,
    this.function,
    this.tenantId,
  });

  final int id;
  final String firstname;
  final String lastname;

  /// 'd' directeur, 'm' manager, 'p' professeur, 's' secrétaire.
  final String role;
  final String? emailsec;
  final String? email;
  final String? phone;
  final String? photo;
  final String? function;
  final int? tenantId;

  String get fullName => '$firstname $lastname'.trim();

  String get initials {
    final f = firstname.isNotEmpty ? firstname[0] : '';
    final l = lastname.isNotEmpty ? lastname[0] : '';
    return (f + l).toUpperCase();
  }

  String get roleLabel => switch (role) {
        'd' => 'Directeur',
        'm' => 'Manager',
        'p' => 'Professeur',
        's' => 'Secrétaire',
        _ => role,
      };

  bool get isTeacher => role == 'p';
  bool get isAdmin => role == 'd' || role == 'm';

  static SessionUser? fromToken(String token) {
    try {
      if (JwtDecoder.isExpired(token)) return null;
      final payload = JwtDecoder.decode(token);
      final u = payload['user'];
      if (u is! Map) return null;
      return SessionUser(
        id: (u['id'] as num).toInt(),
        firstname: u['firstname']?.toString() ?? '',
        lastname: u['lastname']?.toString() ?? '',
        role: u['role']?.toString() ?? '',
        emailsec: u['emailsec']?.toString(),
        email: u['email']?.toString(),
        phone: u['phone']?.toString(),
        photo: u['photo']?.toString(),
        function: u['function']?.toString(),
        tenantId: (payload['tenantId'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Réponse de GET /permissions/my : codes plats + menu pré-filtré par rôle.
class UserPermissions {
  UserPermissions({required this.role, required this.codes, required this.menu});

  final String role;
  final Set<String> codes;
  final List<MenuEntry> menu;

  bool can(String code) => codes.contains(code);

  bool canAny(List<String> anyOf) => anyOf.any(codes.contains);

  static UserPermissions fromJson(Map<String, dynamic> data) {
    final perms = (data['permissions'] as List? ?? [])
        .map((e) => e.toString())
        .toSet();
    final menu = (data['menu'] as List? ?? [])
        .whereType<Map>()
        .map((m) => MenuEntry(
              route: m['route']?.toString() ?? '',
              permission: m['permission']?.toString(),
              icon: m['icon']?.toString() ?? '',
              label: m['label_fr']?.toString() ??
                  m['label']?.toString() ??
                  '',
            ))
        .toList();
    return UserPermissions(
      role: data['role']?.toString() ?? '',
      codes: perms,
      menu: menu,
    );
  }
}

class MenuEntry {
  MenuEntry({
    required this.route,
    required this.permission,
    required this.icon,
    required this.label,
  });

  final String route;
  final String? permission;
  final String icon;
  final String label;
}

/// Session de l'ESPACE ÉLÈVE (jeton `scope: student`).
///
/// Un même appareil ne peut avoir qu'une session à la fois : le jeton élève et
/// le jeton personnel partagent le même coffre, et c'est le `scope` du jeton
/// qui décide de l'espace ouvert au démarrage.
class StudentSession {
  StudentSession({
    required this.id,
    required this.firstname,
    required this.lastname,
    this.levelId,
  });

  final int id;
  final String firstname;
  final String lastname;
  final int? levelId;

  String get fullName => '$firstname $lastname'.trim();

  static StudentSession? fromToken(String token) {
    try {
      if (JwtDecoder.isExpired(token)) return null;
      final payload = JwtDecoder.decode(token);
      if (payload['scope'] != 'student') return null;
      final s = payload['user'] is Map ? payload['user']['student'] : null;
      if (s is! Map) return null;
      return StudentSession(
        id: (s['id'] as num).toInt(),
        firstname: s['firstname']?.toString() ?? '',
        lastname: s['lastname']?.toString() ?? '',
        levelId: (s['levelId'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}
