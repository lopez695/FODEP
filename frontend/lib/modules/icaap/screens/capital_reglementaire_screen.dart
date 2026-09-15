// Le socle Pilier 1 du PIEAFP.
//
// Premier écran du menu ICAAP, et point de départ obligatoire du processus :
// le dispositif (Titre XI) pose que les fonds propres internes s'AJOUTENT aux
// exigences minimales, jamais ne s'y substituent. Tant qu'on ne sait pas ce
// que le Pilier 1 exige déjà, aucun add-on interne ne se justifie.
//
// Les chiffres viennent de la même lecture que le tableau de bord — l'écran ne
// recalcule rien. Deux écrans qui annonceraient des ratios différents ne
// seraient crédibles ni l'un ni l'autre.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';
import '../../participations/widgets/tableau_maison.dart'
    show tableauBordure, tableauEntete, tableauLigneAlternee;
import '../../rapports/models/report_models.dart';
import '../models/icaap_models.dart';

class CapitalReglementaireScreen extends StatefulWidget {
  const CapitalReglementaireScreen({super.key, required this.api});

  final RwaApiService api;

  @override
  State<CapitalReglementaireScreen> createState() =>
      _CapitalReglementaireScreenState();
}

class _CapitalReglementaireScreenState
    extends State<CapitalReglementaireScreen> {
  late Future<CapitalReglementaire> _future;
  StreamSubscription<int>? _abonnementPortefeuille;

  /// L'analyse de l'EP01 renseigne le classeur entier avant de le relire :
  /// elle se demande, elle ne s'impose pas au chargement de la page.
  Future<AnalyseDeclaration>? _normes;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchIcaapCapitalReglementaire();
    _abonnementPortefeuille = widget.api.portfolioRefreshStream.listen((_) {
      if (!mounted) return;
      setState(() {
        _future = widget.api.fetchIcaapCapitalReglementaire();
        _normes = null;
      });
    });
  }

  @override
  void dispose() {
    _abonnementPortefeuille?.cancel();
    super.dispose();
  }

  void _recharger() {
    setState(() {
      _future = widget.api.fetchIcaapCapitalReglementaire();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CapitalReglementaire>(
      future: _future,
      builder: (context, instantane) {
        if (instantane.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (instantane.hasError || !instantane.hasData) {
          return Center(
            child: Text('Socle réglementaire indisponible : '
                '${instantane.error ?? 'aucune donnée'}'),
          );
        }

        final socle = instantane.data!;
        return SingleChildScrollView(
          padding: AppSpacing.pageInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Capital réglementaire',
                subtitle: 'Le socle du Pilier 1 sur lequel le PIEAFP vient se '
                    'greffer. Les cibles internes lui sont supérieures, '
                    'jamais inférieures.',
                trailing: _BandeauCycle(
                  cycle: socle.cycle,
                  api: widget.api,
                  onChange: _recharger,
                ),
              ),
              AppSpacing.gapLg,
              if (socle.avertissements.isNotEmpty) ...[
                _Avertissements(messages: socle.avertissements),
                AppSpacing.gapLg,
              ],
              _CarteExigenceGlobale(exigence: socle.exigenceGlobale),
              AppSpacing.gapLg,
              _CarteRatios(ratios: socle.ratios),
              AppSpacing.gapLg,
              _CarteExigencesParRisque(socle: socle),
              AppSpacing.gapLg,
              _CarteNormes(
                future: _normes,
                // Sans les accolades, la fleche renvoie la Future a
                // setState, qui refuse un rappel asynchrone.
                onDemander: () => setState(() {
                  _normes = widget.api.fetchAnalyseFodepCourante();
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Où en est le cycle annuel du PIEAFP, et de quoi le faire avancer.
///
/// Le rapport PIEAFP est un document de gouvernance validé par l'organe
/// délibérant avant transmission : sa qualité conditionne l'appréciation
/// portée dans le cadre du PSPER. Un écran qui n'en garderait pas trace ne
/// documenterait aucune des neuf étapes du cycle.
class _BandeauCycle extends StatelessWidget {
  const _BandeauCycle({
    required this.cycle,
    required this.api,
    required this.onChange,
  });

  final CycleIcaap cycle;
  final RwaApiService api;
  final VoidCallback onChange;

  Color _couleur() => switch (cycle.statut) {
        statutTransmis => AppTheme.success,
        statutValide => const Color(0xFF2563EB),
        _ => AppTheme.warning,
      };

  Future<void> _changer(BuildContext context, String statut) async {
    var organe = cycle.organe.isEmpty
        ? 'Conseil d\'administration'
        : cycle.organe;

    if (statut == statutValide) {
      final controleur = TextEditingController(text: organe);
      final valide = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation du PIEAFP'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'La responsabilité finale incombe à l\'organe délibérant. '
                'Indiquez l\'organe qui valide : la pièce l\'engage.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controleur,
                decoration: const InputDecoration(labelText: 'Organe'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Valider'),
            ),
          ],
        ),
      );
      if (valide != true) return;
      organe = controleur.text.trim();
    }

    await api.majStatutCycleIcaap(
      cycle.exercice,
      statut: statut,
      organe: statut == statutBrouillon ? '' : organe,
    );
    onChange();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final couleur = _couleur();
    final details = <String>[
      'version ${cycle.version}',
      if (cycle.dateValidation != null) 'le ${cycle.dateValidation}',
      if (cycle.organe.isNotEmpty) cycle.organe,
    ];

    // Un état de gouvernance se lit comme un statut, pas comme une phrase :
    // l'exercice en surtitre, le statut en pastille, le reste en dessous. Les
    // deux lignes alignées à droite obligeaient à lire jusqu'au bout pour
    // savoir où en était le cycle.
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment_outlined, size: 18, color: couleur),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CYCLE PIEAFP ${cycle.exercice}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Pastille(texte: cycle.libelleStatut, couleur: couleur),
                  const SizedBox(width: 8),
                  Text(
                    details.join(' · '),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Faire avancer le cycle',
            icon: Icon(Icons.more_vert, size: 18, color: theme.colorScheme.outline),
            onSelected: (statut) => _changer(context, statut),
            itemBuilder: (context) => const [
              PopupMenuItem(value: statutBrouillon, child: Text('Brouillon')),
              PopupMenuItem(
                value: statutValide,
                child: Text('Validé par l\'organe délibérant'),
              ),
              PopupMenuItem(
                value: statutTransmis,
                child: Text('Transmis à la Commission Bancaire'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ce qui empêche de conclure sur le socle.
///
/// Le dispositif fait de l'intégrité des données un point de contrôle du
/// PIEAFP : une brique absente doit se voir, faute de quoi le socle affiche un
/// zéro aussi crédible qu'un encours mesuré.
class _Avertissements extends StatelessWidget {
  const _Avertissements({required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 17, color: AppTheme.warning),
              const SizedBox(width: 8),
              Text(
                messages.length > 1
                    ? 'Données incomplètes — ${messages.length} briques'
                    : 'Données incomplètes',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (rang, message) in messages.indexed) ...[
            if (rang > 0) const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 25, top: 6, right: 8),
                  child: SizedBox(
                    width: 4,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// L'exigence globale : minimum du Titre III, augmenté du coussin.
///
/// Les quatre premiers nombres se lisent dans l'ordre d'un calcul — l'assiette,
/// le taux exigé, ce qu'il faut détenir, ce qu'on détient — et le cinquième en
/// est la conclusion. Les poser tous les cinq sur la même ligne laissait au
/// lecteur le soin de deviner lequel découlait de l'autre.
class _CarteExigenceGlobale extends StatelessWidget {
  const _CarteExigenceGlobale({required this.exigence});

  final ExigenceGlobale exigence;

  @override
  Widget build(BuildContext context) {
    final deficit = exigence.marge < 0;

    return SectionCard(
      title: 'Exigence globale de fonds propres',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, contraintes) {
              // Quatre colonnes tant que la largeur le permet, puis deux : en
              // dessous, les intitulés se couperaient et les nombres se
              // liraient les uns sous les autres sans rapport entre eux.
              final colonnes = contraintes.maxWidth >= 1040
                  ? 4
                  : contraintes.maxWidth >= 560
                      ? 2
                      : 1;
              const ecart = 12.0;
              final largeur =
                  (contraintes.maxWidth - ecart * (colonnes - 1)) / colonnes;
              final tuiles = <({String libelle, String valeur, String aide})>[
                (
                  libelle: 'Actifs pondérés (assiette)',
                  valeur: AppFormatters.currency(exigence.aprTotal),
                  aide: 'APR crédit + 12,5 × marché + 12,5 × opérationnel (§ 90)',
                ),
                (
                  libelle: 'Exigence globale',
                  valeur: '${_pct(exigence.exigenceGlobale)} des APR',
                  aide: '${_pct(exigence.minimumSolvabilite)} de minimum '
                      '+ ${_pct(exigence.coussinConservation)} de coussin',
                ),
                (
                  libelle: 'Fonds propres requis',
                  valeur: AppFormatters.currency(exigence.fondsPropresRequis),
                  aide: 'Assiette × exigence globale',
                ),
                (
                  libelle: 'Fonds propres disponibles',
                  valeur:
                      AppFormatters.currency(exigence.fondsPropresDisponibles),
                  aide: 'Fonds propres effectifs déclarés',
                ),
              ];
              return Wrap(
                spacing: ecart,
                runSpacing: ecart,
                children: [
                  for (final (rang, tuile) in tuiles.indexed)
                    SizedBox(
                      width: largeur,
                      child: _Tuile(
                        rang: rang + 1,
                        libelle: tuile.libelle,
                        valeur: tuile.valeur,
                        aide: tuile.aide,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _BandeauMarge(exigence: exigence, deficit: deficit),
          const SizedBox(height: 12),
          _Notes(messages: [
            'Coussin contracyclique et coussin systémique ne sont pas activés '
                'dans ce calcul : ils se paramètrent au cas par cas, l\'un par '
                'la Banque Centrale selon le cycle du crédit, l\'autre pour les '
                'établissements d\'importance systémique régionale.',
            'La cible interne du PIEAFP doit être SUPÉRIEURE à '
                '${_pct(exigence.exigenceGlobale)} : elle se définit à l\'écran '
                'Appétence au risque, avec les add-ons du Pilier 2.',
          ]),
        ],
      ),
    );
  }
}

/// Ce que le socle laisse au-delà de l'exigence, ou ce qui lui manque.
///
/// C'est la conclusion des quatre tuiles, et la seule ligne de la section qui
/// appelle une décision : elle prend toute la largeur et une couleur qui ne dit
/// qu'une chose — au-dessus de l'exigence, ou en dessous.
class _BandeauMarge extends StatelessWidget {
  const _BandeauMarge({required this.exigence, required this.deficit});

  final ExigenceGlobale exigence;
  final bool deficit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final couleur = deficit ? AppTheme.danger : AppTheme.success;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: couleur.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            deficit ? Icons.warning_amber_rounded : Icons.verified_outlined,
            size: 20,
            color: couleur,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deficit
                      ? 'Déficit de fonds propres'
                      : 'Matelas au-delà de l\'exigence',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: couleur,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppFormatters.currency(exigence.fondsPropresDisponibles)} '
                  'disponibles pour '
                  '${AppFormatters.currency(exigence.fondsPropresRequis)} requis',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            AppFormatters.currency(exigence.marge.abs()),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: couleur,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Les quatre ratios, chacun face à ses deux seuils.
class _CarteRatios extends StatelessWidget {
  const _CarteRatios({required this.ratios});

  final List<NiveauRatio> ratios;

  Color _couleur(String situation) => switch (situation) {
        situationDepassee => AppTheme.danger,
        situationSousCoussin => AppTheme.warning,
        _ => AppTheme.success,
      };

  String _libelleSituation(String situation) => switch (situation) {
        situationDepassee => 'Sous le minimum',
        situationSousCoussin => 'Coussin entamé',
        _ => 'Respecté',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      title: 'Ratios réglementaires',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deux seuils, parce que le dispositif en pose deux : le minimum du '
            'Titre III, et ce minimum augmenté du coussin de conservation — '
            'c\'est le second que l\'EP01 de la déclaration mesure.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline, height: 1.45),
          ),
          const SizedBox(height: 12),
          // Une vraie grille plutôt qu'un `DataTable` : les colonnes de nombres
          // s'alignent sur leurs filets, un libellé long agrandit sa ligne au
          // lieu de pousser le tableau hors de l'écran, et la page reprend la
          // grille des autres tableaux de l'application.
          Table(
            border: _filetsTableau(context),
            columnWidths: const {
              0: FlexColumnWidth(2.6),
              1: FlexColumnWidth(1.05),
              2: FlexColumnWidth(1.0),
              3: FlexColumnWidth(1.2),
              4: FlexColumnWidth(1.0),
              5: FlexColumnWidth(1.4),
              6: FixedColumnWidth(148),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              _enteteTableau(const [
                (texte: 'Ratio', droite: false),
                (texte: 'Observé', droite: true),
                (texte: 'Minimum', droite: true),
                (texte: 'Avec coussin', droite: true),
                (texte: 'Écart', droite: true),
                (texte: 'FP requis', droite: true),
                (texte: 'Situation', droite: false),
              ]),
              for (final (rang, ratio) in ratios.indexed)
                TableRow(
                  decoration: BoxDecoration(
                    color: _fondLigne(context, rang,
                        alerte: ratio.situation != situationRespectee),
                  ),
                  children: [
                    _celluleTexte(context, ratio.libelle, fort: true),
                    _celluleNombre(
                      context,
                      _pct(ratio.observe),
                      couleur: _couleur(ratio.situation),
                      fort: true,
                    ),
                    _celluleNombre(context, _pct(ratio.minimum), attenue: true),
                    _celluleNombre(context, _pct(ratio.exigenceAvecCoussin)),
                    _celluleNombre(
                      context,
                      _points(ratio.ecartAvecCoussin),
                      couleur: ratio.ecartAvecCoussin < 0
                          ? AppTheme.danger
                          : AppTheme.success,
                    ),
                    _celluleNombre(
                      context,
                      AppFormatters.currency(ratio.fondsPropresRequis),
                    ),
                    _cellule(_Pastille(
                      texte: _libelleSituation(ratio.situation),
                      couleur: _couleur(ratio.situation),
                    )),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ce que chaque risque consomme, et ce que le PIEAFP devra y ajouter.
class _CarteExigencesParRisque extends StatelessWidget {
  const _CarteExigencesParRisque({required this.socle});

  final CapitalReglementaire socle;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Exigences par type de risque',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Table(
            border: _filetsTableau(context),
            columnWidths: const {
              0: FlexColumnWidth(3.0),
              1: FlexColumnWidth(1.3),
              2: FixedColumnWidth(168),
              3: FlexColumnWidth(1.3),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              _enteteTableau(const [
                (texte: 'Risque', droite: false),
                (texte: 'APR', droite: true),
                (texte: 'Part', droite: false),
                (texte: 'Exigence (8 %)', droite: true),
              ]),
              for (final (rang, exigence) in socle.exigences.indexed)
                TableRow(
                  decoration:
                      BoxDecoration(color: _fondLigne(context, rang)),
                  children: [
                    _cellule(_LibelleRisque(exigence: exigence)),
                    _celluleNombre(
                        context, AppFormatters.currency(exigence.apr)),
                    _cellule(_BarrePart(part: exigence.part)),
                    _celluleNombre(
                        context, AppFormatters.currency(exigence.exigence)),
                  ],
                ),
              // Le total ferme le tableau plutôt que de flotter en dessous :
              // c'est la somme des lignes qui précèdent, pas un autre chiffre.
              TableRow(
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.06),
                ),
                children: [
                  _celluleTexte(context, 'Total', fort: true),
                  _celluleNombre(
                    context,
                    AppFormatters.currency(socle.aprTotal),
                    fort: true,
                  ),
                  _cellule(const SizedBox.shrink()),
                  _celluleNombre(
                    context,
                    AppFormatters.currency(socle.exigenceTotale),
                    fort: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Notes(messages: [
            'Assiette du ratio de levier (EP33) : '
                '${AppFormatters.currency(socle.assietteLevier)}. Elle ne '
                'pondère rien : tout ce que l\'établissement expose y entre.',
          ]),
        ],
      ),
    );
  }
}

/// Le risque, et l'angle que la pondération standard ne capte pas.
class _LibelleRisque extends StatelessWidget {
  const _LibelleRisque({required this.exigence});

  final ExigenceRisque exigence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          exigence.libelle,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        // C'est là que le Pilier 2 ajoutera ses add-ons : la mention appartient
        // à la ligne du risque, pas à une note en bas de page.
        Text(
          'Pilier 2 — ${exigence.anglePilier2}',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline, height: 1.35),
        ),
      ],
    );
  }
}

/// La part d'un risque dans l'assiette : le nombre, et sa longueur.
///
/// Un pourcentage seul oblige à comparer quatre nombres de tête ; la barre
/// donne le classement d'un coup d'œil, et le nombre garde la précision.
class _BarrePart extends StatelessWidget {
  const _BarrePart({required this.part});

  final double part;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (part / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor:
                  (isDark ? AppTheme.darkBorder : AppTheme.border),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.accent),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 58,
          child: Text(
            _pct(part),
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// Les onze normes de l'EP01, à la demande.
///
/// Le socle dit ce que le dispositif exige ; l'EP01 dit ce que la déclaration
/// affirmera. Les confronter est le premier contrôle de cohérence du PIEAFP —
/// mais renseigner le classeur entier coûte quelques secondes, d'où le geste
/// explicite.
class _CarteNormes extends StatelessWidget {
  const _CarteNormes({required this.future, required this.onDemander});

  final Future<AnalyseDeclaration>? future;
  final VoidCallback onDemander;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      title: 'Conformité déclarée (EP01)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Les onze normes que la déclaration portera, confrontées à leurs '
            'seuils. Le classeur est renseigné puis relu : comptez quelques '
            'secondes.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 10),
          if (future == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkBorder
                      : AppTheme.border,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.fact_check_outlined,
                      size: 26, color: theme.colorScheme.outline),
                  const SizedBox(height: 10),
                  Text(
                    'Les onze normes n\'ont pas encore été relues.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Le socle dit ce que le dispositif exige ; l\'EP01 dit ce '
                    'que la déclaration affirmera.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onDemander,
                    icon: const Icon(Icons.fact_check_outlined, size: 17),
                    label: const Text('Confronter aux onze normes'),
                  ),
                ],
              ),
            )
          else
            FutureBuilder<AnalyseDeclaration>(
              future: future,
              builder: (context, instantane) => _ResumeNormes(
                instantane: instantane,
                onReessayer: onDemander,
              ),
            ),
        ],
      ),
    );
  }
}

/// Une tuile de la bande d'en-tête : un rang, un intitulé, un nombre, et ce
/// qui l'explique.
///
/// Fond de carte et filet plutôt qu'un aplat gris : quatre aplats côte à côte
/// pèsent plus que les nombres qu'ils portent. Le rang dit l'ordre de lecture,
/// puisque chaque tuile découle de la précédente.
/// L'issue de la confrontation, en une ligne.
///
/// Le détail — chaque norme franchie, chaque réserve — vit sur la page du FODEP
/// et dans le rapport joint à l'export, où il se lit à côté de ce qui le
/// produit. Le répéter ici en encadré ajoutait une deuxième version de la même
/// vérité au milieu d'une page qui parle du socle Pilier 1.
class _ResumeNormes extends StatelessWidget {
  const _ResumeNormes({required this.instantane, required this.onReessayer});

  final AsyncSnapshot<AnalyseDeclaration> instantane;
  final VoidCallback onReessayer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (instantane.connectionState == ConnectionState.waiting) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text('Analyse de la déclaration en cours…',
              style: theme.textTheme.bodySmall),
        ],
      );
    }

    if (instantane.hasError || !instantane.hasData) {
      // Le message vient d'`ApiException`, qui traduit le code de statut quand
      // le serveur n'a rien dit d'intelligible : une page d'erreur HTML ne
      // s'affiche donc pas ici, balises comprises.
      final motif = instantane.error is Exception
          ? '${instantane.error}'
          : 'aucune donnée reçue';
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_outlined,
              size: 17, color: AppTheme.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "L'analyse des onze normes n'a pas abouti : $motif",
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onReessayer,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Réessayer'),
          ),
        ],
      );
    }

    final analyse = instantane.data!;
    final franchies = analyse.depassees.length;
    final conforme = franchies == 0;
    final couleur = conforme ? AppTheme.success : AppTheme.warning;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(conforme ? Icons.verified_outlined : Icons.report_outlined,
            size: 17, color: couleur),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: conforme
                      ? '${analyse.normes.length} normes relues, aucune franchie. '
                      : '${analyse.normes.length} normes relues, '
                          '$franchies franchie(s). ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: couleur,
                  ),
                ),
                TextSpan(
                  text: 'Le détail des normes et des réserves accompagne '
                      "l'export du FODEP.",
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: onReessayer,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Relancer'),
        ),
      ],
    );
  }
}

class _Tuile extends StatelessWidget {
  const _Tuile({
    required this.rang,
    required this.libelle,
    required this.valeur,
    this.aide,
  });

  final int rang;
  final String libelle;
  final String valeur;
  final String? aide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$rang',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  libelle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valeur,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (aide != null) ...[
            const SizedBox(height: 4),
            Text(
              aide!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ce que le calcul d'une section ne dit pas, rassemblé sous elle.
class _Notes extends StatelessWidget {
  const _Notes({required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: (isDark ? AppTheme.darkBorder : AppTheme.border)
            .withValues(alpha: isDark ? 0.35 : 0.45),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (rang, message) in messages.indexed) ...[
            if (rang > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 14, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── La grille, commune aux deux tableaux de la page ─────────────────────────
//
// Elle reprend celle du portefeuille et du registre des dérivés : bandeau bleu
// marine, filets sur toutes les cellules, lignes alternées. Trois écrans qui
// dessineraient trois grilles obligeraient à réapprendre à lire à chaque page.

TableBorder _filetsTableau(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bordure = isDark ? AppTheme.darkBorder : tableauBordure;
  return TableBorder(
    top: BorderSide(color: bordure),
    bottom: BorderSide(color: bordure),
    left: BorderSide(color: bordure),
    right: BorderSide(color: bordure),
    horizontalInside: BorderSide(color: bordure),
    verticalInside: BorderSide(color: bordure),
  );
}

TableRow _enteteTableau(List<({String texte, bool droite})> colonnes) {
  return TableRow(
    decoration: const BoxDecoration(color: tableauEntete),
    children: [
      for (final colonne in colonnes)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            colonne.texte,
            textAlign: colonne.droite ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ),
    ],
  );
}

/// Le rembourrage qui écarte le contenu des filets.
Widget _cellule(Widget enfant) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: enfant,
    );

Widget _celluleTexte(BuildContext context, String texte, {bool fort = false}) {
  final theme = Theme.of(context);
  return _cellule(
    Text(
      texte,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: fort ? FontWeight.w700 : FontWeight.w400,
      ),
    ),
  );
}

/// Un nombre : aligné à droite, en chiffres de largeur fixe pour que les
/// colonnes se comparent d'un regard.
Widget _celluleNombre(
  BuildContext context,
  String texte, {
  Color? couleur,
  bool fort = false,
  bool attenue = false,
}) {
  final theme = Theme.of(context);
  return _cellule(
    Text(
      texte,
      textAlign: TextAlign.right,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: fort ? FontWeight.w700 : FontWeight.w500,
        color: couleur ?? (attenue ? theme.colorScheme.outline : null),
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

/// Fond d'une ligne : zébrage, sauf quand la situation appelle l'œil.
Color? _fondLigne(BuildContext context, int rang, {bool alerte = false}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (alerte) return AppTheme.warning.withValues(alpha: isDark ? 0.10 : 0.07);
  if (rang.isEven) return null;
  return isDark
      ? Colors.white.withValues(alpha: 0.02)
      : tableauLigneAlternee;
}

class _Pastille extends StatelessWidget {
  const _Pastille({required this.texte, required this.couleur});

  final String texte;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: couleur.withValues(alpha: 0.5)),
      ),
      child: Text(
        texte,
        style: TextStyle(
          color: couleur,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Les ratios arrivent déjà en points (9,0 pour 9 %).
String _pct(double valeur) =>
    '${AppFormatters.fixedDecimalNumber(valeur, decimals: 2)} %';

String _points(double valeur) {
  final signe = valeur > 0 ? '+' : '';
  return '$signe${AppFormatters.fixedDecimalNumber(valeur, decimals: 2)} pts';
}
