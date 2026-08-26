import 'package:flutter/material.dart';

/// Affiché quand le serveur local n'a pas répondu au lancement.
///
/// Cet écran remplace l'écran de connexion dans ce cas précis. Demander un
/// identifiant quand rien n'écoute à l'adresse visée envoie l'utilisateur
/// chercher une faute de frappe dans son mot de passe, alors que le serveur
/// est simplement éteint ou sur un autre port. L'adresse est donc affichée
/// telle qu'elle a été essayée.
class BackendInjoignableScreen extends StatefulWidget {
  const BackendInjoignableScreen({
    super.key,
    required this.adresse,
    required this.onReessayer,
  });

  /// Adresse réellement contactée, telle que résolue au démarrage.
  final String adresse;

  /// Relance la vérification. L'écran s'efface de lui-même dès qu'elle
  /// aboutit, sans redémarrer l'application.
  final Future<void> Function() onReessayer;

  @override
  State<BackendInjoignableScreen> createState() =>
      _BackendInjoignableScreenState();
}

class _BackendInjoignableScreenState extends State<BackendInjoignableScreen> {
  bool _enCours = false;

  Future<void> _reessayer() async {
    if (_enCours) return;
    setState(() => _enCours = true);
    try {
      await widget.onReessayer();
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 30, 32, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FODEP',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Le serveur local ne répond pas.',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "L'application a essayé de le joindre à cette adresse :",
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: SelectableText(
                      widget.adresse,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Démarrez le backend, puis réessayez. Si le port ne '
                    "correspond pas, relancez l'application avec "
                    '--dart-define=RWA_API_BASE_URL.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _enCours ? null : _reessayer,
                      child: _enCours
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Réessayer'),
                    ),
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
