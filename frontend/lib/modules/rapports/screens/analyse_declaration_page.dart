import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/report_models.dart';

/// Résultat de l'analyse d'une déclaration déposée.
///
/// Les onze normes de l'EP01, chacune confrontée à son seuil. La page dit aussi
/// le sens de la norme — plancher ou plafond — parce qu'un niveau observé ne se
/// juge pas sans lui : 12 % est conforme face à un minimum de 11,50 %, et ne
/// l'est pas face à un plafond de 10 %.
class AnalyseDeclarationPage extends StatelessWidget {
  const AnalyseDeclarationPage({super.key, required this.analyse});

  final AnalyseDeclaration analyse;

  static Future<void> ouvrir(
    BuildContext context,
    AnalyseDeclaration analyse,
  ) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AnalyseDeclarationPage(analyse: analyse),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final depassees = analyse.depassees.length;
    final nonMesurees = analyse.nonMesurees.length;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 128,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Retour'),
          ),
        ),
        title: Text(
          'Analyse de la déclaration',
          style:
              theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
            children: [
              Text(
                // Un classeur n'a pas de pages : ne les annoncer que pour une
                // impression, plutôt qu'un « 0 page(s) » qui n'a pas de sens.
                [
                  analyse.nomFichier,
                  // Le classeur est la pièce transmise, le PDF son impression :
                  // le lecteur doit savoir laquelle des deux il analyse, parce
                  // que les contrôles de cohérence n'existent que sur l'une.
                  analyse.classeur
                      ? 'classeur — pièce transmise'
                      : 'impression, ${analyse.pages} page(s)',
                  '${analyse.normes.length} norme(s) trouvée(s)',
                ].join(' · '),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 14),
              _Verdict(
                depassees: depassees,
                nonMesurees: nonMesurees,
                total: analyse.normes.length,
              ),
              if (analyse.avertissements.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final avertissement in analyse.avertissements)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _Vigilance(message: avertissement),
                  ),
              ],
              const SizedBox(height: 22),
              _Section(
                numero: 1,
                titre: 'Normes prudentielles',
                sousTitre: 'Les onze normes de l\'EP01, chacune confrontée à '
                    'son seuil. Le sens de la norme décide : un niveau observé '
                    'ne se juge pas sans savoir s\'il est plancher ou plafond.',
                compte: analyse.normes.length,
                enfant: analyse.normes.isEmpty
                    ? const _Absence(
                        message: 'Aucune norme lisible dans ce document.',
                      )
                    : _Tableau(normes: analyse.normes),
              ),
              const SizedBox(height: 22),
              _Section(
                numero: 2,
                titre: 'Cohérence interne',
                sousTitre: 'Chaque total du formulaire, confronté à la somme de '
                    'ses lignes. Un total qui contredit ses lignes fait rejeter '
                    'le dépôt sans qu\'aucune norme ne soit en cause.',
                compte: analyse.controles.length,
                enfant: analyse.controles.isEmpty
                    ? _Absence(
                        message: analyse.classeur
                            ? 'Aucun total vérifiable dans ce classeur.'
                            : 'Ces contrôles demandent le classeur. Sommer des '
                                'nombres extraits d\'un PDF ne prouverait rien, '
                                'faute de savoir à quelle ligne du formulaire '
                                'chacun appartient.',
                      )
                    : _Controles(controles: analyse.controles),
              ),
              if (analyse.inventaire.isNotEmpty) ...[
                const SizedBox(height: 22),
                _Section(
                  numero: 3,
                  titre: 'Carte de la déclaration',
                  sousTitre: 'Ce que chaque état porte. Un état entièrement à '
                      'zéro est déclaré comme les autres : rien n\'y distingue '
                      'un encours nul d\'un encours non mesuré.',
                  compte: analyse.inventaire.length,
                  enfant: _Inventaire(etats: analyse.inventaire),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Un volet de l'analyse : son rang, son intitulé, son intention, son contenu.
class _Section extends StatelessWidget {
  const _Section({
    required this.numero,
    required this.titre,
    required this.sousTitre,
    required this.compte,
    required this.enfant,
  });

  final int numero;
  final String titre;
  final String sousTitre;

  /// Nombre de lignes que porte le volet, annoncé dès l'intitulé.
  final int compte;

  final Widget enfant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$numero',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        titre,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$compte',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sousTitre,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.45,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        enfant,
      ],
    );
  }
}

/// Ce qu'un volet dit quand il n'a rien à montrer, et pourquoi.
class _Absence extends StatelessWidget {
  const _Absence({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall
            ?.copyWith(height: 1.45, color: theme.colorScheme.outline),
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.depassees,
    required this.nonMesurees,
    required this.total,
  });

  final int depassees;
  final int nonMesurees;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // L'ordre est celui dans lequel il faut agir : un dépassement se corrige,
    // une norme non mesurée se renseigne, le reste se lit.
    final (String titre, String detail, Color couleur) = depassees > 0
        ? (
            depassees == 1
                ? 'Une norme est dépassée'
                : '$depassees normes sont dépassées',
            'La déclaration n\'est pas conforme en l\'état.',
            AppTheme.danger,
          )
        : nonMesurees > 0
            ? (
                nonMesurees == 1
                    ? 'Une norme n\'est pas mesurée'
                    : '$nonMesurees normes ne sont pas mesurées',
                'Leur niveau observé est absent du document : elles ne sont ni '
                    'conformes ni dépassées, elles sont inconnues.',
                AppTheme.warning,
              )
            : (
                'Les $total normes sont respectées',
                'Chaque niveau observé se tient du bon côté de son seuil.',
                AppTheme.success,
              );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.07),
        border: Border.all(color: couleur.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: couleur),
          ),
          const SizedBox(height: 3),
          Text(detail, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Vigilance extends StatelessWidget {
  const _Vigilance({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppTheme.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tableau extends StatelessWidget {
  const _Tableau({required this.normes});

  final List<NormeAnalysee> normes;

  static String _pourcentage(double? valeur) =>
      valeur == null ? '—' : '${(valeur * 100).toStringAsFixed(2)} %';

  Color _couleur(SituationNorme situation) => switch (situation) {
        SituationNorme.respectee => AppTheme.success,
        SituationNorme.depassee => AppTheme.danger,
        SituationNorme.nonMesuree => AppTheme.warning,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entete = theme.textTheme.labelSmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.outline,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(64),
          1: FlexColumnWidth(5),
          2: FixedColumnWidth(74),
          3: FixedColumnWidth(90),
          4: FixedColumnWidth(90),
          5: FixedColumnWidth(90),
          6: FixedColumnWidth(112),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
            children: [
              _cellule(Text('Norme', style: entete)),
              _cellule(Text('Intitulé', style: entete)),
              _cellule(Text('Sens', style: entete)),
              _cellule(Text('Seuil', style: entete, textAlign: TextAlign.right)),
              _cellule(Text('Observé', style: entete, textAlign: TextAlign.right)),
              _cellule(Text('Marge', style: entete, textAlign: TextAlign.right)),
              _cellule(Text('Situation', style: entete)),
            ],
          ),
          for (final norme in normes)
            TableRow(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              children: [
                _cellule(Text(
                  norme.code,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700, fontSize: 12),
                )),
                _cellule(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      norme.libelle.isEmpty ? '—' : norme.libelle,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                    if (norme.reference.isNotEmpty)
                      Text(
                        'produit par ${norme.reference}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10.5,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                  ],
                )),
                _cellule(Text(
                  norme.minimum == null
                      ? '—'
                      : norme.minimum!
                          ? 'plancher'
                          : 'plafond',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    color: theme.colorScheme.outline,
                  ),
                )),
                _cellule(Text(_pourcentage(norme.seuil),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12))),
                _cellule(Text(
                  _pourcentage(norme.observe),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _couleur(norme.situation),
                  ),
                )),
                _cellule(Text(_pourcentage(norme.ecart),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12))),
                _cellule(_Etiquette(
                  libelle: norme.situation.libelle,
                  couleur: _couleur(norme.situation),
                )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cellule(Widget enfant) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: enfant,
      );
}

/// Les totaux vérifiés, avec ce qui les sépare de la somme de leurs lignes.
class _Controles extends StatelessWidget {
  const _Controles({required this.controles});

  final List<ControleCoherence> controles;

  static String _montant(double valeur) {
    final chiffres = valeur.abs().toStringAsFixed(0);
    final groupes = <String>[];
    for (var fin = chiffres.length; fin > 0; fin -= 3) {
      groupes.insert(0, chiffres.substring(fin - 3 < 0 ? 0 : fin - 3, fin));
    }
    return '${valeur < 0 ? '-' : ''}${groupes.join(' ')}';
  }

  Color _couleur(StatutControle statut) => switch (statut) {
        StatutControle.exact => AppTheme.success,
        StatutControle.arrondi => AppTheme.warning,
        StatutControle.ecart => AppTheme.danger,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entete = theme.textTheme.labelSmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.outline,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(64),
          1: FlexColumnWidth(5),
          2: FlexColumnWidth(3),
          3: FixedColumnWidth(104),
          4: FixedColumnWidth(104),
          5: FixedColumnWidth(88),
          6: FixedColumnWidth(96),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            children: [
              _cellule(Text('État', style: entete)),
              _cellule(Text('Total vérifié', style: entete)),
              _cellule(Text('Colonne', style: entete)),
              _cellule(Text('Somme des lignes',
                  style: entete, textAlign: TextAlign.right)),
              _cellule(
                  Text('Total porté', style: entete, textAlign: TextAlign.right)),
              _cellule(
                  Text('Écart', style: entete, textAlign: TextAlign.right)),
              _cellule(Text('Statut', style: entete)),
            ],
          ),
          for (final controle in controles)
            TableRow(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              children: [
                _cellule(Text(
                  controle.etat,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700, fontSize: 12),
                )),
                _cellule(Text(
                  controle.libelle,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                )),
                _cellule(Text(
                  controle.colonne,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    color: theme.colorScheme.outline,
                  ),
                )),
                _cellule(Text(_montant(controle.attendu),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12))),
                _cellule(Text(_montant(controle.constate),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12))),
                _cellule(Text(
                  controle.ecart == 0 ? '—' : _montant(controle.ecart),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _couleur(controle.statut),
                  ),
                )),
                _cellule(Tooltip(
                  message: controle.statut == StatutControle.arrondi
                      ? 'Écart imputable aux arrondis : le formulaire arrondit '
                          'chaque ligne, et la somme peut donc dériver d\'une '
                          'demi-unité par ligne (tolérance '
                          '${_montant(controle.tolerance)}).'
                      : controle.statut == StatutControle.ecart
                          ? 'Au-delà de ce que les arrondis expliquent '
                              '(tolérance ${_montant(controle.tolerance)}).'
                          : 'Le total suit exactement ses lignes.',
                  child: _Etiquette(
                    libelle: controle.statut.libelle,
                    couleur: _couleur(controle.statut),
                  ),
                )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cellule(Widget enfant) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: enfant,
      );
}

/// Les états du formulaire et ce qu'ils portent, en une grille compacte.
class _Inventaire extends StatelessWidget {
  const _Inventaire({required this.etats});

  final List<EtatRenseigne> etats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final etat in etats)
          Tooltip(
            message: etat.toutAZero
                ? '${etat.lignes} ligne(s), toutes à zéro : l\'état est déclaré '
                    'mais ne dit rien.'
                : '${etat.lignes} ligne(s) renseignée(s).',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: etat.toutAZero
                    ? AppTheme.warning.withValues(alpha: 0.07)
                    : null,
                border: Border.all(
                  color: etat.toutAZero
                      ? AppTheme.warning.withValues(alpha: 0.35)
                      : theme.dividerColor,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    etat.nom,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: etat.toutAZero ? AppTheme.warning : null,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    etat.toutAZero ? 'à zéro' : '${etat.lignes}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Etiquette extends StatelessWidget {
  const _Etiquette({required this.libelle, required this.couleur});

  final String libelle;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          libelle,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: couleur,
              ),
        ),
      ),
    );
  }
}
