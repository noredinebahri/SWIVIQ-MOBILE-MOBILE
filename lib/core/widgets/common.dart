import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Carte standard de l'app : coins arrondis, ombre douce (équivalent de la
/// shadow "soft" du front).
class OxCard extends StatelessWidget {
  const OxCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = Container(
      decoration: BoxDecoration(
        color: color ?? (isDark ? AppColors.secondary800 : Colors.white),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }
}

/// Pastille d'état colorée (actif/inactif, validé/en attente…).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.background,
  });

  const StatusBadge.success(this.label, {super.key})
      : color = AppColors.success600,
        background = AppColors.success100;

  const StatusBadge.warning(this.label, {super.key})
      : color = const Color(0xFFB45309),
        background = AppColors.warning100;

  const StatusBadge.danger(this.label, {super.key})
      : color = AppColors.danger600,
        background = AppColors.danger100;

  const StatusBadge.info(this.label, {super.key})
      : color = AppColors.primary700,
        background = AppColors.primary100;

  final String label;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Avatar rond avec initiales, couleur dérivée du nom (stable).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.radius = 22});

  final String name;
  final double radius;

  static const _palette = [
    AppColors.primary500,
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    AppColors.warning500,
    Color(0xFF6366F1),
    AppColors.success500,
    Color(0xFFF97316),
  ];

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final color = _palette[name.hashCode.abs() % _palette.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.72,
        ),
      ),
    );
  }
}

/// État vide illustré.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.secondary400),
                  textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Affichage d'erreur avec bouton réessayer.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.wifi_off_rounded,
      title: 'Oups…',
      subtitle: message,
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Réessayer'),
      ),
    );
  }
}

/// Squelette de chargement animé (shimmer maison, sans dépendance).
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({super.key, this.height = 16, this.width, this.radius = 8});

  final double height;
  final double? width;
  final double radius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: (isDark ? AppColors.secondary700 : AppColors.secondary200)
              .withValues(alpha: 0.4 + _c.value * 0.5),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Liste de squelettes pour les écrans liste.
class ListShimmer extends StatelessWidget {
  const ListShimmer({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const OxCard(
        child: Row(
          children: [
            ShimmerBox(height: 44, width: 44, radius: 22),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 160),
                  SizedBox(height: 8),
                  ShimmerBox(width: 100, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? AppColors.danger600 : AppColors.secondary800,
  ));
}

/// Bouton qui se verrouille pendant l'action asynchrone qu'il déclenche.
///
/// Un élève impatient touche trois fois « Enregistrer » : sans garde, trois
/// requêtes partent, et le serveur reçoit trois scores, trois absences, trois
/// paiements. Ici la deuxième touche est ignorée tant que la première n'est
/// pas revenue, et le bouton le montre (spinner).
class BusyButton extends StatefulWidget {
  const BusyButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.style,
    this.outlined = false,
  });

  final Future<void> Function()? onPressed;
  final Widget child;
  final Widget? icon;
  final ButtonStyle? style;
  final bool outlined;

  @override
  State<BusyButton> createState() => _BusyButtonState();
}

class _BusyButtonState extends State<BusyButton> {
  bool _busy = false;
  DateTime? _lastTap;

  Future<void> _handle() async {
    // Double-tap physique (< 400 ms) : même sans action en cours, on ignore.
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!).inMilliseconds < 400) {
      return;
    }
    _lastTap = now;
    if (_busy || widget.onPressed == null) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          )
        : widget.child;
    final onPressed = widget.onPressed == null || _busy ? null : _handle;
    if (widget.outlined) {
      return widget.icon != null && !_busy
          ? OutlinedButton.icon(
              onPressed: onPressed, icon: widget.icon!, label: label, style: widget.style)
          : OutlinedButton(onPressed: onPressed, style: widget.style, child: label);
    }
    return widget.icon != null && !_busy
        ? FilledButton.icon(
            onPressed: onPressed, icon: widget.icon!, label: label, style: widget.style)
        : FilledButton(onPressed: onPressed, style: widget.style, child: label);
  }
}

/// Garde anti-rafale pour un callback quelconque (tuiles, icônes, lignes de
/// liste) : la même action ne repart pas avant [window].
class TapThrottle {
  TapThrottle({this.window = const Duration(milliseconds: 500)});
  final Duration window;
  DateTime? _last;

  bool get allowed {
    final now = DateTime.now();
    if (_last != null && now.difference(_last!) < window) return false;
    _last = now;
    return true;
  }
}
