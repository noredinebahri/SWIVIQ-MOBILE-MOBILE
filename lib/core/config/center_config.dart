import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';

/// Marque blanche : l'app publiée sur les stores est la même pour tous les
/// centres clients du SaaS. Au premier lancement, l'utilisateur saisit le
/// code de son centre (le slug du tenant) ; l'app mémorise l'identité du
/// centre et se pare à ses couleurs. Toutes les requêtes portent ensuite
/// l'en-tête X-Tenant-Id.
class CenterConfig {
  const CenterConfig({
    required this.tenantId,
    required this.name,
    required this.slug,
    this.logo,
    this.phone,
    this.color,
  });

  final int tenantId;
  final String name;
  final String slug;
  final String? logo;
  final String? phone;

  /// Couleur de marque « #RRGGBB » posée par le centre (optionnelle).
  final String? color;

  Color? get seedColor {
    final raw = color;
    if (raw == null) return null;
    final hex = raw.replaceFirst('#', '');
    if (hex.length != 6) return null;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }

  Map<String, dynamic> toJson() => {
        'tenantId': tenantId,
        'name': name,
        'slug': slug,
        'logo': logo,
        'phone': phone,
        'color': color,
      };

  static CenterConfig fromJson(Map<String, dynamic> json) => CenterConfig(
        tenantId: (json['tenantId'] as num).toInt(),
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        logo: json['logo'] as String?,
        phone: json['phone'] as String?,
        color: json['color'] as String?,
      );
}

class CenterConfigStore {
  static const _key = 'ox_center_config';

  static Future<CenterConfig?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return CenterConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(CenterConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(config.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Centre actif. `null` = premier lancement, l'écran « code du centre »
/// s'impose avant tout le reste (voir la redirection du routeur).
class CenterConfigNotifier extends Notifier<CenterConfig?> {
  @override
  CenterConfig? build() => null;

  /// Restaure la config au démarrage et arme l'en-tête tenant.
  Future<void> restore() async {
    final config = await CenterConfigStore.read();
    state = config;
    ApiClient.instance.tenantId = config?.tenantId;
  }

  /// Résout un code centre auprès du serveur, mémorise et applique.
  /// Lève [ApiException] avec un message affichable en cas d'échec.
  Future<CenterConfig> adopt(String code) async {
    final slug = code.trim().toLowerCase();
    final data = await ApiClient.instance
        .get('/public/mobile/center/${Uri.encodeComponent(slug)}');
    final center = (data is Map ? data['center'] : null) as Map?;
    if (center == null) {
      throw ApiException('Réponse inattendue du serveur.');
    }
    final config = CenterConfig.fromJson(Map<String, dynamic>.from(center));
    await CenterConfigStore.write(config);
    ApiClient.instance.tenantId = config.tenantId;
    state = config;
    return config;
  }

  /// Oublie le centre (et les sessions, gérées par l'appelant).
  Future<void> reset() async {
    await CenterConfigStore.clear();
    ApiClient.instance.tenantId = null;
    state = null;
  }
}

final centerConfigProvider =
    NotifierProvider<CenterConfigNotifier, CenterConfig?>(
        CenterConfigNotifier.new);

/// Vrai tant que la restauration initiale n'est pas terminée : le routeur ne
/// doit pas rediriger vers l'écran code-centre avant de savoir s'il y en a un.
final centerConfigReadyProvider = StateProvider<bool>((ref) => false);

/// Petit utilitaire pour les écrans : nom du centre ou repli générique.
String centerDisplayName(WidgetRef ref) =>
    ref.watch(centerConfigProvider)?.name ?? 'Mon centre';
