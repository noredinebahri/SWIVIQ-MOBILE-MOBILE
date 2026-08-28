import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/config/center_config.dart';

/// Écran de connexion : dégradé animé, halos flottants, carte qui entre en
/// glissant, secousse sur erreur. Tout est fait avec les AnimationController
/// natifs — aucune dépendance supplémentaire.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  /// Halos d'arrière-plan en mouvement perpétuel.
  late final AnimationController _bg = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  /// Entrée de la carte (glisse + fondu), jouée une fois.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  /// Secousse horizontale de la carte quand la connexion échoue.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void dispose() {
    _bg.dispose();
    _intro.dispose();
    _shake.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .login(_emailCtrl.text.trim(), _passCtrl.text);
      if (mounted) context.go('/home');
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
      _shake.forward(from: 0);
    } catch (_) {
      setState(() {
        _error = 'Une erreur inattendue est survenue.';
        _loading = false;
      });
      _shake.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Dégradé de marque (primary900 → primary600).
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary900, AppColors.primary600],
              ),
            ),
            child: SizedBox.expand(),
          ),
          // Halos flottants.
          AnimatedBuilder(
            animation: _bg,
            builder: (context, _) {
              final t = _bg.value * 2 * math.pi;
              return Stack(
                children: [
                  _blob(
                    top: -60 + 24 * math.sin(t),
                    left: -40 + 18 * math.cos(t * 0.8),
                    size: 220,
                    opacity: 0.14,
                  ),
                  _blob(
                    top: 160 + 30 * math.cos(t * 0.6 + 1.2),
                    right: -70 + 22 * math.sin(t * 0.9),
                    size: 260,
                    opacity: 0.10,
                  ),
                  _blob(
                    bottom: -80 + 26 * math.sin(t * 0.7 + 2.4),
                    left: 40 + 30 * math.cos(t * 0.5),
                    size: 300,
                    opacity: 0.08,
                  ),
                ],
              );
            },
          ),
          // Contenu.
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _intro,
                    curve: Curves.easeOut,
                  ),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _intro,
                      curve: Curves.easeOutCubic,
                    )),
                    child: AnimatedBuilder(
                      animation: _shake,
                      builder: (context, child) {
                        final dx =
                            math.sin(_shake.value * math.pi * 4) * 8 *
                                (1 - _shake.value);
                        return Transform.translate(
                          offset: Offset(dx, 0),
                          child: child,
                        );
                      },
                      child: _card(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required double size,
    required double opacity,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: opacity),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context) {
    // La carte est toujours claire (écran de marque) : on force le thème
    // light à l'intérieur pour que les champs restent lisibles en mode sombre.
    return Theme(
      data: buildTheme(Brightness.light),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo dans un écrin blanc arrondi (le logo est sombre).
                    Center(
                      child: Container(
                        width: 92,
                        height: 92,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.secondary100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          // Marque blanche : le logo du centre adopté, repli
                          // sur le logo embarqué si absent ou injoignable.
                          child: Builder(builder: (context) {
                            final logo =
                                ref.watch(centerConfigProvider)?.logo;
                            if (logo == null || logo.isEmpty) {
                              return Image.asset('assets/images/logo.png',
                                  fit: BoxFit.cover);
                            }
                            return Image.network(
                              logo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.cover),
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      centerDisplayName(ref),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.secondary800,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Heureux de vous revoir ! Connectez-vous pour continuer.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.secondary400,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Bandeau d'erreur.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: _error == null
                          ? const SizedBox.shrink()
                          : Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.danger100,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: AppColors.danger600, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: AppColors.danger600,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Saisissez votre email'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _loading ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Saisissez votre mot de passe'
                          : null,
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _loading
                            ? const SizedBox(
                                key: ValueKey('spinner'),
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Se connecter',
                                key: ValueKey('label'),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed:
                          _loading ? null : () => context.push('/forgot'),
                      child: const Text('Mot de passe oublié ?'),
                    ),
                    const Divider(height: 20),
                    // Accès famille : connexion par numéro d'élève + téléphone.
                    TextButton.icon(
                      onPressed:
                          _loading ? null : () => context.go('/eleve/login'),
                      icon: const Icon(Icons.school_rounded, size: 18),
                      label: const Text('Espace élève'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
