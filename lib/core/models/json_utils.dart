/// Helpers de parsing tolérants.
///
/// L'API renvoie souvent des nombres sous forme de chaînes (colonnes MySQL
/// DECIMAL/VARCHAR, ex. `"priceTotal": "400"`). Un cast Dart strict (`as num`)
/// plante alors toute la liste — ces helpers absorbent chaînes, nombres et
/// null indifféremment.
num? asNumOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim());
  if (v is bool) return v ? 1 : 0;
  return null;
}

num asNum(dynamic v, [num fallback = 0]) => asNumOrNull(v) ?? fallback;

int? asIntOrNull(dynamic v) => asNumOrNull(v)?.toInt();

int asInt(dynamic v, [int fallback = 0]) => asIntOrNull(v) ?? fallback;

bool asBool(dynamic v, [bool fallback = false]) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'oui';
  }
  return fallback;
}

String? asStringOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

/// Déplie les enveloppes de réponse du backend : certains endpoints renvoient
/// la donnée brute, d'autres `{success, payload}` ou `{success, data}`.
dynamic unwrap(dynamic data) {
  if (data is Map) {
    if (data.containsKey('payload')) return data['payload'];
    if (data.containsKey('data')) return data['data'];
  }
  return data;
}

List<Map<String, dynamic>> asMapList(dynamic data) {
  final unwrapped = unwrap(data);
  if (unwrapped is! List) return [];
  return unwrapped
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}
