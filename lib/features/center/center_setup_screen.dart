import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/config/center_config.dart';

/// Premier lancement de l'app marque blanche : l'utilisateur saisit le code
/// de son centre (remis par le centre, en général sur le reçu d'inscription
/// ou par WhatsApp). L'app adopte alors le nom, le logo et les couleurs du
/// centre, et toutes les requêtes portent son tenant.
class CenterSetupScreen extends ConsumerStatefulWidget {
  const CenterSetupScreen({super.key});

  @override
  ConsumerState<CenterSetupScreen> createState() => _CenterSetupScreenState();
}

class _CenterSetupScreenState extends ConsumerState<CenterSetupScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Saisissez le code de votre centre.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config =
          await ref.read(centerConfigProvider.notifier).adopt(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bienvenue au centre ${config.name} !')),
      );
      context.go('/eleve/login');
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
        _error = 'Connexion impossible. Vérifiez votre réseau.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary700, AppColors.primary400],
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
                  const Icon(Icons.apartment_rounded,
                      size: 64, color: Colors.white),
                  const SizedBox(height: 10),
                  const Text(
                    'Bienvenue !',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'L\'application de votre centre : notes, emploi du temps, '
                    'paiements et messages, aux couleurs de votre centre.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: 0.9)),
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
                            controller: _codeController,
                            autocorrect: false,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _loading ? null : _submit(),
                            decoration: const InputDecoration(
                              labelText: 'Code du centre',
                              helperText:
                                  'Remis par votre centre (reçu, WhatsApp…)',
                              prefixIcon: Icon(Icons.qr_code_2_rounded),
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
                                  : const Text('Rejoindre mon centre'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Votre centre n\'a pas encore l\'application ?\n'
                    'Parlez-en à sa direction — atlasapp.swiviq.com',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12.5),
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
