import 'package:flutter/material.dart';

import '../models/report_models.dart';

/// Ce que la déclaration affirmera, avant de la produire.
///
/// Les normes viennent de l'EP01 du classeur que l'export vient de renseigner,
/// lues par la même fonction que celle d'une déclaration déposée : une norme
/// se lit à l'identique qu'elle vienne d'un dépôt ou du portefeuille en base.
class AnalyseIndicateurs extends StatelessWidget {
  const AnalyseIndicateurs({super.key, required this.instantane, this.onReessayer});

  final AsyncSnapshot<AnalyseDeclaration> instantane;

  /// De quoi relancer l'analyse sans recharger la page. Absent là où l'appel
  /// se refait de lui-même au prochain rendu.
  final VoidCallback? onReessayer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (instantane.connectionState == ConnectionState.waiting) {
      return _cadre(
        theme,
        couleur: theme.colorScheme.outline,
        enfant: Row(
          children: [
            const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Text('Analyse de la déclaration en cours…',
                style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }

    if (instantane.hasError || !instantane.hasData) {
      // Le message vient d'`ApiException`, qui traduit le code de statut quand
      // le serveur n'a rien dit d'intelligible. Une page d'erreur HTML ne
      // s'affiche donc plus ici, balises comprises.
      final motif = instantane.error is Exception
          ? '${instantane.error}'
          : 'aucune donnée reçue';
      return _cadre(
        theme,
        couleur: const Color(0xFFB45309),
        enfant: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 17, color: Color(0xFFB45309)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "L'analyse des onze normes n'a pas abouti.",
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(motif, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (onReessayer != null) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onReessayer,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      );
    }

    final analyse = instantane.data!;
    final depassees = analyse.depassees;
    final aGerer = analyse.reservesAgir;
    final conforme = depassees.isEmpty;
    final couleur = conforme
        ? const Color(0xFF15803D)
        : (depassees.length > 2
            ? const Color(0xFFB91C1C)
            : const Color(0xFFB45309));

    return _cadre(
      theme,
      couleur: couleur,
      enfant: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(conforme ? Icons.verified_outlined : Icons.report_outlined,
                  size: 17, color: couleur),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  conforme
                      ? 'Les ${analyse.normes.length} normes mesurées sont '
                          'respectées'
                      : '${depassees.length} norme(s) sur '
                          '${analyse.normes.length} sont franchies',
                  style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700, color: couleur),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ce que la déclaration affirmera si elle est transmise en l\'état.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          if (depassees.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final norme in depassees) _ligneNorme(theme, norme, couleur),
          ],
          if (aGerer.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('${aGerer.length} réserve(s) demandent un geste avant '
                'transmission',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            for (final reserve in aGerer.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('• ${reserve.message}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ),
            if (aGerer.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                    '• et ${aGerer.length - 3} autre(s), reprises dans le '
                    'rapport de réserves joint à l\'export',
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.outline)),
              ),
          ],
        ],
      ),
    );
  }

  /// Une norme franchie : le seuil, le niveau observé, et l'écart entre les
  /// deux — c'est l'écart qui dit l'ampleur, pas le seul dépassement.
  Widget _ligneNorme(ThemeData theme, NormeAnalysee norme, Color couleur) {
    String pourcent(double? v) =>
        v == null ? '—' : '${(v * 100).toStringAsFixed(2)} %';
    final sens = norme.minimum == true ? 'minimum' : 'maximum';
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Text(norme.code,
                style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800, color: couleur)),
          ),
          Expanded(
            child: Text(norme.libelle,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 190,
            child: Text(
              '${pourcent(norme.observe)} pour ${pourcent(norme.seuil)} '
              '($sens)',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700, color: couleur),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cadre(ThemeData theme,
      {required Color couleur, required Widget enfant}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.05),
        border: Border.all(color: couleur.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: enfant,
    );
  }
}
