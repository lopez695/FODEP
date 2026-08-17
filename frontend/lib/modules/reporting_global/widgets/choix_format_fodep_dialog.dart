import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Format demandé pour l'export du FODEP.
enum FormatExportFodep {
  /// Le classeur produit par le backend, tel qu'il est transmis.
  classeur,

  /// Une mise en page du même classeur, pour relecture et archivage.
  pdf,
}

/// Demande sous quel format sortir le FODEP.
///
/// Les deux formats ne servent pas à la même chose et l'un n'est pas
/// interchangeable avec l'autre : seul le classeur porte les codes DISPRU aux
/// cases attendues par la plate-forme de reporting. Le dialogue le dit, plutôt
/// que de laisser croire à deux variantes du même fichier.
class ChoixFormatFodepDialog extends StatelessWidget {
  const ChoixFormatFodepDialog({super.key, this.dateArrete});

  /// Rappelée dans le dialogue : on n'exporte pas une déclaration sans savoir
  /// de quelle date elle parle.
  final String? dateArrete;

  static Future<FormatExportFodep?> demander(
    BuildContext context, {
    String? dateArrete,
  }) {
    return showDialog<FormatExportFodep>(
      context: context,
      builder: (_) => ChoixFormatFodepDialog(dateArrete: dateArrete),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Exporter le FODEP',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                dateArrete == null
                    ? 'Deux formats, deux usages.'
                    : 'Arrêté au $dateArrete · deux formats, deux usages.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 18),
              _Choix(
                icone: Icons.table_view_rounded,
                titre: 'Classeur Excel',
                detail: 'Le formulaire à transmettre à la BCEAO, ses cases '
                    'renseignées. C\'est la pièce déclarative.',
                mentionne: 'À transmettre',
                onChoisi: () =>
                    Navigator.pop(context, FormatExportFodep.classeur),
              ),
              const SizedBox(height: 10),
              _Choix(
                icone: Icons.picture_as_pdf_outlined,
                titre: 'Document PDF',
                detail: 'La même déclaration mise en page, état par état, pour '
                    'relecture, visa et archivage.',
                onChoisi: () => Navigator.pop(context, FormatExportFodep.pdf),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un format proposé : ce qu'il est, et à quoi il sert.
class _Choix extends StatelessWidget {
  const _Choix({
    required this.icone,
    required this.titre,
    required this.detail,
    required this.onChoisi,
    this.mentionne,
  });

  final IconData icone;
  final String titre;
  final String detail;

  /// Étiquette qui distingue la pièce déclarative de la copie de lecture.
  final String? mentionne;

  final VoidCallback onChoisi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onChoisi,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        titre,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (mentionne != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            mentionne!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                      height: 1.35,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                size: 20, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}
