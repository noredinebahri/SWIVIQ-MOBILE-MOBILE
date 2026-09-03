import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Cache disque des réponses GET.
///
/// Une entrée = le corps JSON, la date, et l'ETag renvoyé par le serveur.
/// Elle sert à trois choses :
///  * afficher instantanément la dernière copie (stale-while-revalidate) ;
///  * continuer à fonctionner hors-ligne ;
///  * renvoyer `If-None-Match` — Express répond alors 304 sans corps, ce qui
///    coûte presque rien au serveur et rien au forfait data de l'élève.
///
/// Clé = chemin + requête, hachée (FNV-1a 64 bits) pour donner un nom de
/// fichier sûr. Les entrées ne sont jamais partagées entre comptes : la clé
/// inclut le suffixe du jeton (les 12 derniers caractères), donc un autre
/// élève sur le même téléphone ne voit pas la copie du précédent.
class ResponseCache {
  ResponseCache._();
  static final ResponseCache instance = ResponseCache._();

  final _memory = <String, CacheEntry>{};
  Directory? _dir;

  Future<Directory> _directory() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/api_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  static String keyFor(String path, Map<String, dynamic>? query, String? tokenTail) {
    final q = query == null || query.isEmpty
        ? ''
        : (query.entries.map((e) => '${e.key}=${e.value}').toList()..sort()).join('&');
    return _fnv1a('$path?$q#${tokenTail ?? ''}');
  }

  static String _fnv1a(String input) {
    var hash = 0xcbf29ce484222325;
    for (final unit in utf8.encode(input)) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  Future<CacheEntry?> read(String key) async {
    final mem = _memory[key];
    if (mem != null) return mem;
    try {
      final file = File('${(await _directory()).path}/$key.json');
      if (!await file.exists()) return null;
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final entry = CacheEntry(
        data: map['data'],
        etag: map['etag'] as String?,
        savedAt: DateTime.fromMillisecondsSinceEpoch((map['at'] as num).toInt()),
      );
      _memory[key] = entry;
      return entry;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, dynamic data, {String? etag}) async {
    final entry = CacheEntry(data: data, etag: etag, savedAt: DateTime.now());
    _memory[key] = entry;
    try {
      final file = File('${(await _directory()).path}/$key.json');
      await file.writeAsString(jsonEncode({
        'data': data,
        'etag': etag,
        'at': entry.savedAt.millisecondsSinceEpoch,
      }));
    } catch (_) {
      // Disque plein ou inaccessible : la copie mémoire suffit pour la session.
    }
  }

  /// Rafraîchit seulement la date (réponse 304 : le contenu n'a pas bougé).
  Future<void> touch(String key) async {
    final entry = _memory[key] ?? await read(key);
    if (entry == null) return;
    await write(key, entry.data, etag: entry.etag);
  }

  /// Purge complète — à la déconnexion, rien ne doit rester d'un compte.
  Future<void> clear() async {
    _memory.clear();
    try {
      final dir = await _directory();
      if (await dir.exists()) await dir.delete(recursive: true);
      _dir = null;
    } catch (_) {}
  }
}

class CacheEntry {
  CacheEntry({required this.data, required this.savedAt, this.etag});
  final dynamic data;
  final DateTime savedAt;
  final String? etag;

  Duration get age => DateTime.now().difference(savedAt);
}
