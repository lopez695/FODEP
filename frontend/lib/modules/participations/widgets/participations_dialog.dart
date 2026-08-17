import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/utils/formatters.dart';
import '../models/participation_models.dart';
import 'jauge_limite.dart';
import 'tableau_maison.dart';

/// Saisie des participations de l'établissement.
///
/// Ces montants alimentent les états EP34 et EP35 du FODEP, et surtout trois
/// normes de l'EP01 : sans eux, le formulaire déclare « CONFORME » des limites
/// que rien n'a mesuré.
class ParticipationsDialog extends StatefulWidget {
  const ParticipationsDialog({super.key, required this.api});

  final RwaApiService api;

  /// Retourne `true` si le contenu a changé, pour rafraîchir l'appelant.
  static Future<bool> show(BuildContext context, RwaApiService api) async {
    final modifie = await showDialog<bool>(
      context: context,
      builder: (_) => ParticipationsDialog(api: api),
    );
    return modifie ?? false;
  }

  @override
  State<ParticipationsDialog> createState() => _ParticipationsDialogState();
}

/// Les participations et l'état des limites qu'elles alimentent.
///
/// Les deux sont chargés ensemble : une liste sans ses limites obligerait à
/// aller vérifier ailleurs l'effet de chaque ligne.
typedef _Donnees = ({
  List<Participation> participations,
  SyntheseParticipations synthese,
});

class _ParticipationsDialogState extends State<ParticipationsDialog> {
  late Future<_Donnees> _future;
  bool _modifie = false;

  @override
  void initState() {
    super.initState();
    _future = _charger();
  }

  Future<_Donnees> _charger() async {
    // Les deux appels partent ensemble : ils ne dépendent pas l'un de l'autre.
    final liste = widget.api.fetchParticipations();
    final synthese = widget.api.fetchSyntheseParticipations();
    return (participations: await liste, synthese: await synthese);
  }

  void _recharger() {
    // Corps entre accolades : une flèche renverrait le Future affecté, que
    // setState refuse.
    setState(() {
      _future = _charger();
    });
  }

  Future<void> _editer([Participation? existante]) async {
    final saisie = await showDialog<Participation>(
      context: context,
      builder: (_) => _FormulaireParticipation(participation: existante),
    );
    if (saisie == null) return;
    try {
      if (existante == null) {
        await widget.api.createParticipation(saisie);
      } else {
        await widget.api.updateParticipation(saisie);
      }
      _modifie = true;
      _recharger();
    } catch (erreur) {
      _signaler('Enregistrement impossible : $erreur');
    }
  }

  Future<void> _supprimer(Participation participation) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: const Text('Supprimer cette participation ?'),
        content: Text(
          '« ${participation.denomination} » ne figurera plus dans les états '
          'EP34 et EP35, ni dans le calcul des limites de l\'EP01.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexte, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexte, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await widget.api.deleteParticipation(participation.id);
      _modifie = true;
      _recharger();
    } catch (erreur) {
      _signaler('Suppression impossible : $erreur');
    }
  }

  void _signaler(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _enTete(theme),
            const Divider(height: 1, color: tableauBordure),
            Flexible(
              child: FutureBuilder<_Donnees>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return SizedBox(
                      height: 200,
                      child: Center(
                        child: Text('Chargement impossible : ${snapshot.error}'),
                      ),
                    );
                  }
                  final donnees = snapshot.data!;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Rappel(synthese: donnees.synthese),
                        const SizedBox(height: 18),
                        if (donnees.participations.isEmpty)
                          const _AucuneParticipation()
                        else
                          _Tableau(
                            participations: donnees.participations,
                            fondsPropresT1: donnees.synthese.fondsPropresT1,
                            onEditer: _editer,
                            onSupprimer: _supprimer,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1, color: tableauBordure),
            _piedDePage(theme),
          ],
        ),
      ),
    );
  }

  Widget _enTete(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.account_balance_outlined,
              size: 19,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Participations de l\'établissement',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: tableauEntete,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ce qui est saisi ici alimente les états EP34 à EP37 et les '
                  'cinq limites RA006 à RA010.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Fermer',
            onPressed: () => Navigator.pop(context, _modifie),
          ),
        ],
      ),
    );
  }

  Widget _piedDePage(ThemeData theme) {
    return Container(
      color: tableauLigneAlternee,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Le détail des limites — assiettes, calculs et marges — est sur '
              'l\'écran qui a ouvert cette saisie.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => _editer(),
            icon: const Icon(Icons.add, size: 17),
            label: const Text('Ajouter une participation'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              minimumSize: const Size(0, 38),
              textStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rappel de l'état des limites, sans les refaire.
///
/// Cette boîte sert à saisir, pas à analyser : le détail des cinq limites vit
/// sur la page qui l'a ouverte. Une ligne suffit ici à dire s'il faut y
/// retourner — et les alertes, elles, doivent se voir pendant la saisie,
/// puisque c'est la saisie qui les lève.
class _Rappel extends StatelessWidget {
  const _Rappel({required this.synthese});

  final SyntheseParticipations synthese;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final depassees = synthese.depassements.length;
    final inconnues = synthese.nonMesurables.length;

    final (String etat, Color couleur) = depassees > 0
        ? ('$depassees limite(s) dépassée(s)', theme.colorScheme.error)
        : inconnues > 0
            ? ('$inconnues limite(s) non mesurable(s)',
                theme.colorScheme.tertiary)
            : ('Les 5 limites sont respectées', theme.colorScheme.primary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                depassees > 0
                    ? Icons.error_outline
                    : inconnues > 0
                        ? Icons.help_outline
                        : Icons.check_circle_outline,
                size: 18,
                color: couleur,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  etat,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: couleur,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Total net ${AppFormatters.millions(synthese.totalGeneral)} · '
                'fonds propres T1 '
                '${AppFormatters.millions(synthese.fondsPropresT1)}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ),
        // Ambre, et non rouge : ces messages signalent une donnée absente, pas
        // un plafond franchi. Un dépassement, lui, se voit sur sa propre ligne.
        // Même traitement que sur la carte et sur la page des limites.
        for (final alerte in synthese.alertes)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: vigilanceFond,
                border: Border.all(color: vigilanceBordure),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: vigilanceTexte),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alerte,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        height: 1.35,
                        color: tableauTexteFort,
                      ),
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

class _AucuneParticipation extends StatelessWidget {
  const _AucuneParticipation();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_outlined,
                size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'Aucune participation enregistrée',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tant que cette liste est vide, l\'EP01 déclare « CONFORME » les '
              'trois limites sur les participations sans qu\'aucun encours ne '
              'l\'ait vérifié.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Colonnes du tableau de saisie.
///
/// Les montants étaient auparavant écrits en prose sous chaque nom — « Capital
/// 54 321 432 · brut 54 322 · net 5 432 » — donc l'intitulé se répétait à chaque
/// ligne et rien ne s'alignait d'une participation à l'autre : deux lignes ne se
/// comparaient pas. En colonnes, l'intitulé est écrit une fois et les chiffres
/// tombent les uns sous les autres.
///
/// Les deux dernières colonnes portent leur plafond dans leur titre : une
/// pastille « 22,5 % » ne dit pas à quoi elle se compare.
const List<ColonneTableau> _colonnesSaisie = [
  (libelle: 'Participation', flex: 6, largeur: null),
  (libelle: 'Capital de l\'émetteur', flex: 4, largeur: null),
  (libelle: 'Souscription brute', flex: 4, largeur: null),
  (libelle: 'Libéré net', flex: 4, largeur: null),
  (libelle: 'Part du capital\nmax 25 %', flex: 3, largeur: null),
  (libelle: 'Part des FP de base\nmax 15 %', flex: 3, largeur: null),
  // Deux boutons d'icône serrés, plus les marges de la cellule : en dessous de
  // cette largeur, la Row déborde de 16 pixels et Flutter le signale.
  (libelle: '', flex: null, largeur: 100),
];

class _Tableau extends StatelessWidget {
  const _Tableau({
    required this.participations,
    required this.fondsPropresT1,
    required this.onEditer,
    required this.onSupprimer,
  });

  final List<Participation> participations;

  /// Dénominateur de la limite individuelle de 15 %, venu des fonds propres.
  final double fondsPropresT1;

  final ValueChanged<Participation> onEditer;
  final ValueChanged<Participation> onSupprimer;

  @override
  Widget build(BuildContext context) {
    final parCategorie = <CategorieParticipation, List<Participation>>{};
    for (final participation in participations) {
      parCategorie.putIfAbsent(participation.categorie, () => []).add(participation);
    }

    // La grille du portefeuille, celle des groupes de clients liés et des
    // limites : la saisie porte les mêmes montants, elle doit se lire pareil.
    // `cadreTableau` accepte des lignes libres, d'où les bandeaux de catégorie
    // glissés entre les lignes de données plutôt qu'au-dessus du cadre.
    //
    // Aucune ListView ici : le corps du dialogue est déjà un
    // SingleChildScrollView, donc la hauteur reçue est infinie et une liste
    // défilante ne pourrait pas s'y dimensionner.
    return cadreTableau(
      context: context,
      colonnes: _colonnesSaisie,
      lignes: [
        for (final categorie in CategorieParticipation.values)
          if (parCategorie[categorie]?.isNotEmpty ?? false) ...[
            _BandeauCategorie(
              categorie: categorie,
              totalNet: parCategorie[categorie]!
                  .fold<double>(0, (somme, p) => somme + p.montantNet),
              nombre: parCategorie[categorie]!.length,
            ),
            for (var index = 0;
                index < parCategorie[categorie]!.length;
                index++)
              _Ligne(
                participation: parCategorie[categorie]![index],
                fondsPropresT1: fondsPropresT1,
                alternee: index.isOdd,
                onEditer: () => onEditer(parCategorie[categorie]![index]),
                onSupprimer: () => onSupprimer(parCategorie[categorie]![index]),
              ),
          ],
      ],
    );
  }
}

/// Bandeau d'une section de l'EP34, avec son total.
///
/// Le total est annoncé « net » : c'est le montant libéré qui alimente l'état,
/// pas la souscription, et un nombre nu à droite d'un intitulé n'apprend pas
/// lequel des deux il additionne.
class _BandeauCategorie extends StatelessWidget {
  const _BandeauCategorie({
    required this.categorie,
    required this.totalNet,
    required this.nombre,
  });

  final CategorieParticipation categorie;
  final double totalNet;
  final int nombre;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: tableauLigneAlternee,
        border: Border(bottom: BorderSide(color: tableauBordure, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              categorie.label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Text(
            '$nombre ligne(s)',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontSize: 11, color: theme.colorScheme.outline),
          ),
          const SizedBox(width: 14),
          Text(
            'net ${AppFormatters.decimalNumber(totalNet, maxDecimals: 0)}',
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tableauEntete,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un montant, aligné à droite et en chiffres de largeur fixe.
///
/// Sans largeur fixe, les colonnes de chiffres se décalent d'une ligne à
/// l'autre et les ordres de grandeur ne se comparent plus à l'œil.
class _Montant extends StatelessWidget {
  const _Montant(this.valeur);

  final double valeur;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        AppFormatters.decimalNumber(valeur, maxDecimals: 0),
        textAlign: TextAlign.right,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: tableauTexteFort,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
      ),
    );
  }
}

/// Une part rapportée à son plafond, colorée par l'état qu'elle atteint.
///
/// Le rouge du dépassement ne suffisait pas : une part qui consomme 90 % de son
/// plafond n'est pas dépassée, et se lisait donc comme n'importe quelle autre.
/// Même seuil de vigilance et mêmes teintes que les jauges de la page des
/// limites, pour que « proche du plafond » veuille dire la même chose partout.
class _Part extends StatelessWidget {
  const _Part({required this.part, required this.plafond, this.encadree = true});

  final double? part;

  /// Plafond réglementaire, ou `null` quand aucune limite ne vise cette ligne.
  final double? plafond;

  /// Une part hors du champ d'une limite reste grise : la colorer laisserait
  /// croire qu'elle est plafonnée.
  final bool encadree;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (part == null) {
      return Text(
        '—',
        style: theme.textTheme.bodySmall
            ?.copyWith(fontSize: 12, color: theme.colorScheme.outline),
      );
    }

    final Color couleur;
    if (!encadree || plafond == null) {
      couleur = limiteInconnue;
    } else if (part! > plafond!) {
      couleur = limiteDepassee;
    } else if (part! / plafond! >= EtatLimite.seuilDeVigilance) {
      couleur = limiteProche;
    } else {
      couleur = limiteRespectee;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${(part! * 100).toStringAsFixed(1)} %',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: couleur,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Action d'une ligne du tableau.
///
/// Aire de touche resserrée à 34 pixels : la cible par défaut de Material en
/// fait 40 et deux d'entre elles ne tiennent pas dans la colonne, ce que Flutter
/// signale par un débordement.
class _BoutonLigne extends StatelessWidget {
  const _BoutonLigne({
    required this.icone,
    required this.infobulle,
    required this.onPressed,
  });

  final IconData icone;
  final String infobulle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icone, size: 17),
      tooltip: infobulle,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      style: IconButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.participation,
    required this.fondsPropresT1,
    required this.alternee,
    required this.onEditer,
    required this.onSupprimer,
  });

  final Participation participation;
  final double fondsPropresT1;
  final bool alternee;
  final VoidCallback onEditer;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Les deux limites individuelles ne visent que les entités commerciales :
    // 25 % du capital de l'émetteur, 15 % des fonds propres de base. Les autres
    // catégories relèvent d'autres dispositions, leur part reste indicative.
    final commerciale =
        participation.categorie == CategorieParticipation.entiteCommerciale;
    final partCapital = participation.capitalEntreprise > 0
        ? participation.partDuCapital
        : null;
    final partT1 = commerciale && fondsPropresT1 > 0
        ? participation.montantNet / fondsPropresT1
        : null;

    return Container(
      decoration: BoxDecoration(
        color: alternee ? tableauLigneAlternee : Colors.white,
        border: const Border(
          bottom: BorderSide(color: tableauBordure, width: 0.5),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...celluleTableau(
              flex: 6,
              enfant: Text(
                participation.denomination,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: tableauTexteFort,
                ),
              ),
            ),
            ...celluleTableau(
              flex: 4,
              enfant: _Montant(participation.capitalEntreprise),
            ),
            ...celluleTableau(
              flex: 4,
              enfant: _Montant(participation.montantBrut),
            ),
            ...celluleTableau(
              flex: 4,
              enfant: _Montant(participation.montantNet),
            ),
            ...celluleTableau(
              flex: 3,
              enfant: Tooltip(
                message: commerciale
                    ? 'Souscription rapportée au capital de l\'émetteur · '
                        'plafond 25 % (norme RA006)'
                    : 'Part du capital de l\'émetteur. Aucune limite de l\'EP01 '
                        'ne vise cette catégorie.',
                child: _Part(
                  part: partCapital,
                  plafond: 0.25,
                  encadree: commerciale,
                ),
              ),
            ),
            ...celluleTableau(
              flex: 3,
              enfant: Tooltip(
                message: commerciale
                    ? 'Montant libéré rapporté aux fonds propres de base T1 · '
                        'plafond 15 % (norme RA007)'
                    : 'Limite réservée aux entités commerciales.',
                child: _Part(part: partT1, plafond: 0.15),
              ),
            ),
            ...celluleTableau(
              largeur: 100,
              enfant: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BoutonLigne(
                    icone: Icons.edit_outlined,
                    infobulle: 'Modifier',
                    onPressed: onEditer,
                  ),
                  _BoutonLigne(
                    icone: Icons.delete_outline,
                    infobulle: 'Supprimer',
                    onPressed: onSupprimer,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulaire d'une participation.
class _FormulaireParticipation extends StatefulWidget {
  const _FormulaireParticipation({this.participation});

  final Participation? participation;

  @override
  State<_FormulaireParticipation> createState() =>
      _FormulaireParticipationState();
}

class _FormulaireParticipationState extends State<_FormulaireParticipation> {
  final _cleFormulaire = GlobalKey<FormState>();
  late final TextEditingController _denomination;
  late final TextEditingController _capital;
  late final TextEditingController _brut;
  late final TextEditingController _net;
  late CategorieParticipation _categorie;

  @override
  void initState() {
    super.initState();
    final existante = widget.participation;
    _denomination = TextEditingController(text: existante?.denomination ?? '');
    _capital = TextEditingController(
        text: existante == null ? '' : '${existante.capitalEntreprise}');
    _brut = TextEditingController(
        text: existante == null ? '' : '${existante.montantBrut}');
    _net = TextEditingController(
        text: existante == null ? '' : '${existante.montantNet}');
    _categorie = existante?.categorie ?? CategorieParticipation.etablissement;
  }

  @override
  void dispose() {
    _denomination.dispose();
    _capital.dispose();
    _brut.dispose();
    _net.dispose();
    super.dispose();
  }

  double _valeur(TextEditingController controleur) =>
      double.tryParse(controleur.text.replaceAll(',', '.').trim()) ?? 0;

  String? _validerMontant(String? valeur) {
    if (valeur == null || valeur.trim().isEmpty) return null;
    final nombre = double.tryParse(valeur.replaceAll(',', '.').trim());
    if (nombre == null) return 'Montant invalide';
    if (nombre < 0) return 'Montant négatif';
    return null;
  }

  void _valider() {
    if (!(_cleFormulaire.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      Participation(
        id: widget.participation?.id ?? 0,
        denomination: _denomination.text.trim(),
        categorie: _categorie,
        capitalEntreprise: _valeur(_capital),
        montantBrut: _valeur(_brut),
        montantNet: _valeur(_net),
      ),
    );
  }

  /// Décoration commune : un cadre net, la même hauteur pour tous les champs.
  InputDecoration _decoration({String? suffixe}) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      suffixText: suffixe,
      suffixStyle: const TextStyle(fontSize: 12, color: texteSecondaireLimites),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        borderSide: BorderSide(color: tableauBordure),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  /// Un champ, son intitulé au-dessus, sa précision en dessous.
  ///
  /// L'intitulé est posé hors du cadre plutôt qu'en étiquette flottante : il
  /// reste lisible une fois le champ rempli, et tous les champs s'alignent à
  /// la même hauteur quelle que soit la longueur de leur aide.
  Widget _champ({
    required String intitule,
    required Widget enfant,
    String? aide,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            intitule,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: tableauTexteFort,
            ),
          ),
          const SizedBox(height: 6),
          enfant,
          if (aide != null) ...[
            const SizedBox(height: 5),
            Text(
              aide,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: texteSecondaireLimites,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _titreDeBloc(String libelle) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        libelle.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final creation = widget.participation == null;

    return Dialog(
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Form(
          key: _cleFormulaire,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _enTete(theme, creation),
              const Divider(height: 1, color: tableauBordure),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _titreDeBloc('Entreprise détenue'),
                      _champ(
                        intitule: 'Dénomination',
                        enfant: TextFormField(
                          controller: _denomination,
                          autofocus: true,
                          decoration: _decoration(),
                          validator: (valeur) =>
                              (valeur == null || valeur.trim().isEmpty)
                                  ? 'La dénomination est obligatoire'
                                  : null,
                        ),
                      ),
                      _champ(
                        intitule: 'Section de l\'EP34',
                        aide: 'Détermine les limites applicables : seules les '
                            'entités commerciales subissent RA006 à RA008',
                        enfant: DropdownButtonFormField<CategorieParticipation>(
                          initialValue: _categorie,
                          isExpanded: true,
                          decoration: _decoration(),
                          items: [
                            for (final categorie
                                in CategorieParticipation.values)
                              DropdownMenuItem(
                                value: categorie,
                                child: Text(categorie.label,
                                    overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (valeur) => setState(
                            () => _categorie = valeur ?? _categorie,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _titreDeBloc('Montants, en francs'),
                      _champ(
                        intitule: 'Capital de l\'entreprise émettrice',
                        aide: 'Dénominateur de la limite de 25 % · sans lui, '
                            'la part détenue ne se calcule pas',
                        enfant: TextFormField(
                          controller: _capital,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: _decoration(suffixe: 'FCFA'),
                          validator: _validerMontant,
                        ),
                      ),
                      _champ(
                        intitule: 'Montant brut souscrit',
                        aide: 'Numérateur de la limite de 25 %',
                        enfant: TextFormField(
                          controller: _brut,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: _decoration(suffixe: 'FCFA'),
                          validator: _validerMontant,
                        ),
                      ),
                      _champ(
                        intitule: 'Montant net libéré',
                        aide: 'Net de provisions · c\'est lui qui pèse dans '
                            'les totaux et dans la limite de 15 %',
                        enfant: TextFormField(
                          controller: _net,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: _decoration(suffixe: 'FCFA'),
                          validator: _validerMontant,
                        ),
                      ),
                      _Apercu(
                        capital: _valeur(_capital),
                        brut: _valeur(_brut),
                        net: _valeur(_net),
                        commerciale: _categorie ==
                            CategorieParticipation.entiteCommerciale,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: tableauBordure),
              _piedDePage(theme, creation),
            ],
          ),
        ),
      ),
    );
  }

  Widget _enTete(ThemeData theme, bool creation) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              creation ? Icons.add_business_outlined : Icons.edit_outlined,
              size: 19,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creation
                      ? 'Nouvelle participation'
                      : 'Modifier la participation',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: tableauEntete,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Une part du capital d\'une autre société · alimente les '
                  'états EP34 et EP35',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: texteSecondaireLimites,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Fermer',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _piedDePage(ThemeData theme, bool creation) {
    const forme = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(6)),
    );

    return Container(
      color: tableauLigneAlternee,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: texteSecondaireLimites,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              minimumSize: const Size(0, 38),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              shape: forme,
            ),
            child: const Text('Annuler'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _valider,
            icon: Icon(creation ? Icons.add : Icons.check, size: 17),
            label: Text(creation ? 'Ajouter' : 'Enregistrer'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              minimumSize: const Size(0, 38),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              shape: forme,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ce que la saisie produira, calculé pendant qu'on tape.
///
/// La part du capital décide de la limite de 25 % : la voir se former évite de
/// découvrir un dépassement à l'export. L'aperçu ne s'affiche que lorsque les
/// deux montants qui le composent sont saisis — annoncer « 0 % » sur un
/// formulaire vide n'apprendrait rien.
class _Apercu extends StatelessWidget {
  const _Apercu({
    required this.capital,
    required this.brut,
    required this.net,
    required this.commerciale,
  });

  final double capital;
  final double brut;
  final double net;

  /// Les trois premières limites ne visent que les entités commerciales.
  final bool commerciale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (capital <= 0 || brut <= 0) return const SizedBox.shrink();

    final part = brut / capital;
    final depasse = commerciale && part > 0.25;
    final couleur = depasse ? limiteDepassee : limiteRespectee;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.06),
        border: Border.all(color: couleur.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            depasse ? Icons.error_outline : Icons.check_circle_outline,
            size: 18,
            color: couleur,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Part du capital détenue : '
                  '${(part * 100).toStringAsFixed(2)} %',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: couleur,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  commerciale
                      ? (depasse
                          ? 'Au-dessus du plafond de 25 % : la norme RA006 '
                              'sera déclarée en infraction.'
                          : 'Sous le plafond de 25 % de la norme RA006.')
                      : 'Cette section n\'est pas visée par le plafond de '
                          '25 %, qui ne concerne que les entités commerciales.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    color: tableauTexteFort,
                  ),
                ),
                if (net > brut) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Le montant net dépasse le montant brut : le libéré ne '
                    'peut pas excéder la souscription.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: limiteDepassee,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
