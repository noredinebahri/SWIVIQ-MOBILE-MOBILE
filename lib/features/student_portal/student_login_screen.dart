import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/config/center_config.dart';
import 'student_portal_repo.dart';

/// Connexion de l'espace élève : numéro d'élève + téléphone (celui de l'élève
/// ou du responsable, tel qu'enregistré au centre). Pas de mot de passe.
class StudentLoginScreen extends ConsumerStatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  ConsumerState<StudentLoginScreen> createState() =>
      _StudentLoginScreenState();
}

class _StudentLoginScreenState extends ConsumerState<StudentLoginScreen> {
  final _idController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _idController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final id = _idController.text.trim();
    final phone = _phoneController.text.trim();
    if (id.isEmpty || phone.isEmpty) {
      setState(() => _error = 'Renseignez le numéro d\'élève et le téléphone.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(studentAuthProvider.notifier).login(id, phone);
      if (!mounted) return;
      context.go('/eleve');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Connexion impossible. Réessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary600, AppColors.primary400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Marque blanche : le logo du centre adopté s'il en a un,
                  // sinon l'icône générique.
                  Builder(builder: (context) {
                    final logo = ref.watch(centerConfigProvider)?.logo;
                    if (logo == null || logo.isEmpty) {
                      return const Icon(Icons.school_rounded,
                          size: 64, color: Colors.white);
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        logo,
                        height: 72,
                        width: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.school_rounded,
                            size: 64,
                            color: Colors.white),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  Text(
                    centerDisplayName(ref),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Espace élève',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Consultez votre profil, vos polycopiés et votre emploi du temps.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9)),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          TextField(
                            controller: _idController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Numéro d\'élève',
                              helperText: 'Le numéro remis par le centre',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            onSubmitted: (_) => _loading ? null : _submit(),
                            decoration: const InputDecoration(
                              labelText: 'Téléphone',
                              helperText: 'Le vôtre ou celui du responsable',
                              prefixIcon: Icon(Icons.phone_rounded),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.danger100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                    color: AppColors.danger600, fontSize: 13),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _loading ? null : _submit,
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 52)),
                              child: _loading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white),
                                    )
                                  : const Text('Se connecter'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 18),
                    label: const Text('Espace personnel du centre',
                        style: TextStyle(color: Colors.white)),
                  ),
                  // Mauvais centre adopté (faute de frappe, déménagement…) :
                  // on peut toujours en changer sans réinstaller l'app.
                  TextButton.icon(
                    onPressed: () async {
                      await ref
                          .read(centerConfigProvider.notifier)
                          .reset();
                      if (context.mounted) context.go('/center');
                    },
                    icon: Icon(Icons.swap_horiz_rounded,
                        color: Colors.white.withValues(alpha: 0.7), size: 16),
                    label: Text('Changer de centre',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12.5)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
