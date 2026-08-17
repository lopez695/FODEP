import 'package:flutter/material.dart';

import '../../../core/auth/session_controller.dart';

/// Écran de connexion. Sobre, sans promesse commerciale : c'est une porte
/// d'entrée vers des données prudentielles, pas une page d'accueil produit.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _navy = Color(0xFF172B4D);

  final TextEditingController _identifiant = TextEditingController();
  final TextEditingController _motDePasse = TextEditingController();
  final FocusNode _focusMotDePasse = FocusNode();

  bool _enCours = false;
  bool _masque = true;
  String? _erreur;

  @override
  void dispose() {
    _identifiant.dispose();
    _motDePasse.dispose();
    _focusMotDePasse.dispose();
    super.dispose();
  }

  Future<void> _soumettre() async {
    if (_enCours) return;
    final identifiant = _identifiant.text.trim();
    final motDePasse = _motDePasse.text;
    if (identifiant.isEmpty || motDePasse.isEmpty) {
      setState(() => _erreur = 'Renseignez votre identifiant et votre mot de passe.');
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    final erreur = await widget.session.connecter(
      identifiant: identifiant,
      motDePasse: motDePasse,
    );

    if (!mounted) return;
    setState(() {
      _enCours = false;
      _erreur = erreur;
      if (erreur != null) {
        // Le mot de passe est effacé après un échec : il ne doit pas rester
        // affiché à l'écran d'un poste partagé.
        _motDePasse.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE3E7EE)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 34, height: 3, color: _navy),
                  const SizedBox(height: 20),
                  const Text(
                    'Risk management',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pilotage des fonds propres - dispositif UMOA',
                    style: TextStyle(fontSize: 12, color: Color(0xFF5B6577)),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _identifiant,
                    autofocus: true,
                    enabled: !_enCours,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _focusMotDePasse.requestFocus(),
                    decoration: _decoration('Identifiant'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _motDePasse,
                    focusNode: _focusMotDePasse,
                    enabled: !_enCours,
                    obscureText: _masque,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _soumettre(),
                    decoration: _decoration('Mot de passe').copyWith(
                      suffixIcon: IconButton(
                        iconSize: 18,
                        icon: Icon(
                          _masque
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: const Color(0xFF5B6577),
                        ),
                        tooltip: _masque ? 'Afficher' : 'Masquer',
                        onPressed: () => setState(() => _masque = !_masque),
                      ),
                    ),
                  ),
                  if (_erreur != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB42318).withValues(alpha: 0.06),
                        border: Border.all(
                          color: const Color(0xFFB42318).withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              size: 15, color: Color(0xFFB42318)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _erreur!,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF0F1B2D)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 42,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _navy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      onPressed: _enCours ? null : _soumettre,
                      child: _enCours
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Se connecter',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Accès réservé. Les connexions sont enregistrées.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF98A2B3)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF5B6577)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: Color(0xFFE3E7EE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: Color(0xFFE3E7EE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: _navy),
      ),
    );
  }
}
