import 'package:flutter/material.dart';

import '../../../core/auth/session_controller.dart';

/// Gestion de l'équipe : ajouter un membre, suspendre un accès.
///
/// Chaque compte travaille dans sa propre base : ajouter quelqu'un ici lui
/// ouvre un espace vierge, alimenté du jeu de démonstration, qu'il alimente
/// ensuite sans jamais toucher aux données des autres.
class EquipeDialog extends StatefulWidget {
  const EquipeDialog({super.key, required this.session});

  final SessionController session;

  @override
  State<EquipeDialog> createState() => _EquipeDialogState();
}

class _EquipeDialogState extends State<EquipeDialog> {
  static const Color _navy = Color(0xFF172B4D);

  final TextEditingController _identifiant = TextEditingController();
  final TextEditingController _nom = TextEditingController();
  final TextEditingController _motDePasse = TextEditingController();

  List<Map<String, dynamic>> _membres = const [];
  String _role = 'consultation';
  String? _erreur;
  String? _succes;
  bool _chargement = true;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _identifiant.dispose();
    _nom.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    try {
      final membres = await widget.session.listerEquipe();
      if (!mounted) return;
      setState(() {
        _membres = membres;
        _chargement = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _erreur = exception.toString();
        _chargement = false;
      });
    }
  }

  Future<void> _ajouter() async {
    if (_envoi) return;
    setState(() {
      _envoi = true;
      _erreur = null;
      _succes = null;
    });

    final erreur = await widget.session.ajouterMembre(
      identifiant: _identifiant.text.trim(),
      motDePasse: _motDePasse.text,
      role: _role,
      nomComplet: _nom.text,
    );

    if (!mounted) return;
    if (erreur == null) {
      final ajoute = _identifiant.text.trim();
      _identifiant.clear();
      _nom.clear();
      _motDePasse.clear();
      setState(() {
        _envoi = false;
        _succes = '« $ajoute » ajouté. Son espace se créera à sa première '
            'connexion.';
      });
      await _charger();
    } else {
      setState(() {
        _envoi = false;
        _erreur = erreur;
      });
    }
  }

  Future<void> _basculerActivation(Map<String, dynamic> membre) async {
    final actif = membre['actif'] == true;
    final erreur = await widget.session.changerActivation(
      identifiant: membre['identifiant'] as String,
      actif: !actif,
    );
    if (!mounted) return;
    if (erreur != null) {
      setState(() => _erreur = erreur);
      return;
    }
    await _charger();
  }

  @override
  Widget build(BuildContext context) {
    final moi = widget.session.profil?.identifiant;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: SizedBox(
        width: 620,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Équipe',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Text(
                'Chaque membre dispose de son propre espace de données. '
                'Ce qu\'il importe n\'apparaît que chez lui.',
                style: TextStyle(fontSize: 12, color: Color(0xFF5B6577)),
              ),
              const SizedBox(height: 18),
              if (_chargement)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final membre in _membres)
                          _LigneMembre(
                            membre: membre,
                            estMoi: membre['identifiant'] == moi,
                            onBasculer: () => _basculerActivation(membre),
                          ),
                      ],
                    ),
                  ),
                ),
              const Divider(height: 28),
              const Text(
                'Ajouter un membre',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _identifiant,
                      decoration: _deco('Identifiant'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _nom,
                      decoration: _deco('Nom complet (facultatif)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _motDePasse,
                      obscureText: true,
                      decoration: _deco('Mot de passe (12 caractères min.)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      initialValue: _role,
                      decoration: _deco('Rôle'),
                      items: const [
                        DropdownMenuItem(
                          value: 'consultation',
                          child: Text('Consultation'),
                        ),
                        DropdownMenuItem(
                          value: 'edition',
                          child: Text('Édition'),
                        ),
                      ],
                      onChanged: (valeur) =>
                          setState(() => _role = valeur ?? 'consultation'),
                    ),
                  ),
                ],
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 12),
                Text(
                  _erreur!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB42318),
                  ),
                ),
              ],
              if (_succes != null) ...[
                const SizedBox(height: 12),
                Text(
                  _succes!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1B7A4B),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _navy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  onPressed: _envoi ? null : _ajouter,
                  child: Text(_envoi ? 'Ajout…' : 'Ajouter'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(3)),
      );
}

class _LigneMembre extends StatelessWidget {
  const _LigneMembre({
    required this.membre,
    required this.estMoi,
    required this.onBasculer,
  });

  final Map<String, dynamic> membre;
  final bool estMoi;
  final VoidCallback onBasculer;

  @override
  Widget build(BuildContext context) {
    final actif = membre['actif'] == true;
    final role = membre['role'] as String? ?? '';
    final nom = (membre['nom_complet'] as String?)?.trim();
    final derniere = membre['derniere_connexion'] as String?;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEDEFF4))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${membre['identifiant']}${estMoi ? '  (vous)' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: actif ? const Color(0xFF0F1B2D) : Colors.grey,
                  ),
                ),
                if (nom != null && nom.isNotEmpty)
                  Text(
                    nom,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF5B6577),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              role == 'edition' ? 'Édition' : 'Consultation',
              style: const TextStyle(fontSize: 12, color: Color(0xFF5B6577)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              derniere == null || derniere.isEmpty
                  ? 'Jamais connecté'
                  : 'Vu le ${derniere.substring(0, 10)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF98A2B3)),
            ),
          ),
          // On ne peut pas se suspendre soi-même : le serveur refuse, et le
          // bouton ne doit pas laisser croire le contraire.
          if (estMoi)
            const SizedBox(width: 90)
          else
            SizedBox(
              width: 90,
              child: TextButton(
                onPressed: onBasculer,
                child: Text(
                  actif ? 'Suspendre' : 'Réactiver',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
