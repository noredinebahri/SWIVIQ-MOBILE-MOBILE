import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/widgets/common.dart';
import '../../main.dart';

/// Profil : informations personnelles, changement de mot de passe,
/// préférences (mode sombre) et déconnexion.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _infoFormKey = GlobalKey<FormState>();
  final _passFormKey = GlobalKey<FormState>();

  late final TextEditingController _firstnameCtrl;
  late final TextEditingController _lastnameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;

  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _savingInfo = false;
  bool _savingPass = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _firstnameCtrl = TextEditingController(text: user?.firstname ?? '');
    _lastnameCtrl = TextEditingController(text: user?.lastname ?? '');
    _emailCtrl =
        TextEditingController(text: user?.email ?? user?.emailsec ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _firstnameCtrl.dispose();
    _lastnameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveInfo() async {
    FocusScope.of(context).unfocus();
    if (!(_infoFormKey.currentState?.validate() ?? false)) return;
    setState(() => _savingInfo = true);
    try {
      await ref.read(authProvider.notifier).updateProfile(
            firstname: _firstnameCtrl.text.trim(),
            lastname: _lastnameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
          );
      if (mounted) showSnack(context, 'Profil mis à jour ✓');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Une erreur inattendue est survenue.', error: true);
      }
    } finally {
      if (mounted) setState(() => _savingInfo = false);
    }
  }

  Future<void> _savePassword() async {
    FocusScope.of(context).unfocus();
    if (!(_passFormKey.currentState?.validate() ?? false)) return;
    setState(() => _savingPass = true);
    try {
      await ref.read(authProvider.notifier).updateProfile(
            password: _newPassCtrl.text,
            currentPassword: _currentPassCtrl.text,
          );
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      if (mounted) showSnack(context, 'Mot de passe modifié ✓');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Une erreur inattendue est survenue.', error: true);
      }
    } finally {
      if (mounted) setState(() => _savingPass = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Déconnexion'),
        content:
            const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger600,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final theme = Theme.of(context);
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;

    if (user == null) {
      // Session terminée pendant que l'écran est ouvert.
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── En-tête ───
          Center(
            child: Column(
              children: [
                InitialsAvatar(name: user.fullName, radius: 42),
                const SizedBox(height: 12),
                Text(
                  user.fullName,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                StatusBadge.info(user.roleLabel),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Informations ───
          _sectionTitle(context, 'Informations'),
          OxCard(
            child: Form(
              key: _infoFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _firstnameCtrl,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Prénom',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Le prénom est requis'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _lastnameCtrl,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Le nom est requis'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      prefixIcon: Icon(Icons.phone_iphone_rounded),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _savingInfo ? null : _saveInfo,
                    icon: _savingInfo
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Enregistrer'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ─── Mot de passe ───
          _sectionTitle(context, 'Mot de passe'),
          OxCard(
            child: Form(
              key: _passFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _currentPassCtrl,
                    obscureText: _obscureCurrent,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe actuel',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                            () => _obscureCurrent = !_obscureCurrent),
                        icon: Icon(
                          _obscureCurrent
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Saisissez votre mot de passe actuel'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _newPassCtrl,
                    obscureText: _obscureNew,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Nouveau mot de passe',
                      prefixIcon: const Icon(Icons.lock_reset_rounded),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                        icon: Icon(
                          _obscureNew
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Saisissez un nouveau mot de passe';
                      }
                      if (v.length < 6) {
                        return 'Au moins 6 caractères';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmPassCtrl,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) =>
                        _savingPass ? null : _savePassword(),
                    decoration: InputDecoration(
                      labelText: 'Confirmer le nouveau mot de passe',
                      prefixIcon: const Icon(Icons.lock_person_outlined),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm),
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Confirmez le nouveau mot de passe';
                      }
                      if (v != _newPassCtrl.text) {
                        return 'Les mots de passe ne correspondent pas';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _savingPass ? null : _savePassword,
                    icon: _savingPass
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.key_rounded),
                    label: const Text('Changer le mot de passe'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ─── Préférences ───
          _sectionTitle(context, 'Préférences'),
          OxCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SwitchListTile(
              value: isDarkMode,
              onChanged: (_) =>
                  ref.read(themeModeProvider.notifier).toggle(),
              title: const Text('Mode sombre'),
              secondary: Icon(
                isDarkMode
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                color: theme.colorScheme.primary,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),

          // ─── Déconnexion ───
          OxCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            onTap: _confirmLogout,
            child: const ListTile(
              leading:
                  Icon(Icons.logout_rounded, color: AppColors.danger600),
              title: Text(
                'Se déconnecter',
                style: TextStyle(
                  color: AppColors.danger600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Icon(Icons.chevron_right_rounded,
                  color: AppColors.danger600),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
