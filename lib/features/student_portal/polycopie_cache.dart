import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Polycopiés de l'élève conservés sur l'appareil : la LISTE (pour l'afficher
/// sans réseau) et les FICHIERS déjà téléchargés (pour les rouvrir hors
/// connexion).
///
/// Chaque fichier est mémorisé avec la `fileVersion` du serveur. Si le centre
/// remplace le support, la version change : la copie locale devient obsolète,
/// elle est supprimée, et l'élève est prévenu qu'une nouvelle version existe.
class PolycopieCache {
  static const _listKey = 'ox_poly_list';
  static const _versionKey = 'ox_poly_version';
  static const _savedAtKey = 'ox_poly_saved_at';

  /// polycopieId → version du fichier stocké localement.
  static const _fileVersionsKey = 'ox_poly_file_versions';

  // ── Liste ──────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> readList() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_listKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<String?> readVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_versionKey);
  }

  static Future<DateTime?> readSavedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_savedAtKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> saveList({
    required List<Map<String, dynamic>> items,
    required String version,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_listKey, jsonEncode(items));
    await prefs.setString(_versionKey, version);
    await prefs.setInt(_savedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  // ── Fichiers ───────────────────────────────────────────────────────────

  /// Dossier permanent des supports (survit aux redémarrages, contrairement
  /// au dossier temporaire).
  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/polycopies');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Map<String, String>> _fileVersions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_fileVersionsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _setFileVersions(Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fileVersionsKey, jsonEncode(map));
  }

  /// Chemin du fichier local, uniquement s'il correspond à [expectedVersion].
  /// Retourne null si absent ou périmé (le centre a remplacé le support).
  static Future<String?> localFile(
      int polycopieId, String? expectedVersion) async {
    final versions = await _fileVersions();
    final stored = versions['$polycopieId'];
    if (stored == null) return null;
    if (expectedVersion != null &&
        expectedVersion.isNotEmpty &&
        stored != expectedVersion) {
      // Support remplacé : la copie locale ne doit plus être proposée.
      await removeFile(polycopieId);
      return null;
    }
    final dir = await _dir();
    final file = File('${dir.path}/$polycopieId.bin');
    return await file.exists() ? file.path : null;
  }

  /// Chemin où écrire le téléchargement.
  static Future<String> pathFor(int polycopieId) async {
    final dir = await _dir();
    return '${dir.path}/$polycopieId.bin';
  }

  static Future<void> markDownloaded(
      int polycopieId, String? fileVersion) async {
    final versions = await _fileVersions();
    versions['$polycopieId'] = fileVersion ?? '';
    await _setFileVersions(versions);
  }

  static Future<void> removeFile(int polycopieId) async {
    final versions = await _fileVersions();
    versions.remove('$polycopieId');
    await _setFileVersions(versions);
    try {
      final dir = await _dir();
      final file = File('${dir.path}/$polycopieId.bin');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Supprime les fichiers dont le polycopié n'est plus attribué à l'élève.
  static Future<void> pruneMissing(Set<int> stillAssigned) async {
    final versions = await _fileVersions();
    for (final key in versions.keys.toList()) {
      final id = int.tryParse(key);
      if (id != null && !stillAssigned.contains(id)) {
        await removeFile(id);
      }
    }
  }

  /// Purge complète (déconnexion de l'élève).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_listKey);
    await prefs.remove(_versionKey);
    await prefs.remove(_savedAtKey);
    await prefs.remove(_fileVersionsKey);
    try {
      final dir = await _dir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}
