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
import '../../rapports/models/report_models.dart';
import '../../rapports/widgets/analyse_indicateurs.dart';
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
    final couleur = _couleur();
    final details = <String>[
      'version ${cycle.version}',
      if (cycle.dateValidation != null) 'le ${cycle.dateValidation}',
      if (cycle.organe.isNotEmpty) cycle.organe,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: couleur.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Cycle PIEAFP ${cycle.exercice} · ${cycle.libelleStatut}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: couleur),
              ),
              Text(
                details.join(' · '),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Faire avancer le cycle',
            icon: Icon(Icons.more_vert, size: 18, color: couleur),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 17, color: AppTheme.warning),
              const SizedBox(width: 8),
              Text(
                'Données incomplètes',
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700, color: AppTheme.warning),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final message in messages)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('• $message', style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// L'exigence globale : minimum du Titre III, augmenté du coussin.
class _CarteExigenceGlobale extends StatelessWidget {
  const _CarteExigenceGlobale({required this.exigence});

  final ExigenceGlobale exigence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deficit = exigence.marge < 0;
    final couleur = deficit ? AppTheme.danger : AppTheme.success;

    return SectionCard(
      title: 'Exigence globale de fonds propres',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Tuile(
                libelle: 'Actifs pondérés (assiette)',
                valeur: AppFormatters.currency(exigence.aprTotal),
                aide: 'APR crédit + 12,5 × marché + 12,5 × opérationnel (§90)',
              ),
              _Tuile(
                libelle: 'Exigence globale',
                valeur: '${_pct(exigence.exigenceGlobale)} des APR',
                aide: '${_pct(exigence.minimumSolvabilite)} de minimum '
                    '+ ${_pct(exigence.coussinConservation)} de coussin',
              ),
              _Tuile(
                libelle: 'Fonds propres requis',
                valeur: AppFormatters.currency(exigence.fondsPropresRequis),
              ),
              _Tuile(
                libelle: 'Fonds propres disponibles',
                valeur:
                    AppFormatters.currency(exigence.fondsPropresDisponibles),
              ),
              _Tuile(
                libelle: deficit ? 'Déficit' : 'Matelas au-delà de l\'exigence',
                valeur: AppFormatters.currency(exigence.marge.abs()),
                couleur: couleur,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Coussin contracyclique et coussin systémique ne sont pas activés '
            'dans ce calcul : ils se paramètrent au cas par cas, l\'un par la '
            'Banque Centrale selon le cycle du crédit, l\'autre pour les '
            'établissements d\'importance systémique régionale.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 6),
          Text(
            'La cible interne du PIEAFP doit être SUPÉRIEURE à '
            '${_pct(exigence.exigenceGlobale)} : elle se définira à l\'écran '
            'Appétence au risque, avec les add-ons du Pilier 2.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontStyle: FontStyle.italic,
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
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 26,
              headingRowHeight: 36,
              dataRowMinHeight: 38,
              dataRowMaxHeight: 46,
              columns: const [
                DataColumn(label: Text('Ratio')),
                DataColumn(label: Text('Observé'), numeric: true),
                DataColumn(label: Text('Minimum'), numeric: true),
                DataColumn(label: Text('Avec coussin'), numeric: true),
                DataColumn(label: Text('Écart'), numeric: true),
                DataColumn(label: Text('FP requis'), numeric: true),
                DataColumn(label: Text('Situation')),
              ],
              rows: [
                for (final ratio in ratios)
                  DataRow(
                    cells: [
                      DataCell(Text(ratio.libelle)),
                      DataCell(Text(
                        _pct(ratio.observe),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      )),
                      DataCell(Text(_pct(ratio.minimum))),
                      DataCell(Text(_pct(ratio.exigenceAvecCoussin))),
                      DataCell(Text(
                        _points(ratio.ecartAvecCoussin),
                        style: TextStyle(
                          color: ratio.ecartAvecCoussin < 0
                              ? AppTheme.danger
                              : AppTheme.success,
                        ),
                      )),
                      DataCell(
                          Text(AppFormatters.currency(ratio.fondsPropresRequis))),
                      DataCell(_Pastille(
                        texte: _libelleSituation(ratio.situation),
                        couleur: _couleur(ratio.situation),
                      )),
                    ],
                  ),
              ],
            ),
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
    final theme = Theme.of(context);

    return SectionCard(
      title: 'Exigences par type de risque',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final exigence in socle.exigences) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exigence.libelle,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      // L'angle que la pondération standard ne capte pas :
                      // c'est là que le Pilier 2 ajoutera ses add-ons.
                      Text(
                        'Pilier 2 — ${exigence.anglePilier2}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _Chiffre(
                    libelle: 'APR',
                    valeur: AppFormatters.currency(exigence.apr),
                  ),
                ),
                Expanded(
                  child: _Chiffre(
                    libelle: 'Part',
                    valeur: _pct(exigence.part),
                  ),
                ),
                Expanded(
                  child: _Chiffre(
                    libelle: 'Exigence (8 %)',
                    valeur: AppFormatters.currency(exigence.exigence),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
          ],
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Total',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: _Chiffre(
                  libelle: 'APR total',
                  valeur: AppFormatters.currency(socle.aprTotal),
                ),
              ),
              const Expanded(child: SizedBox()),
              Expanded(
                child: _Chiffre(
                  libelle: 'Exigence totale',
                  valeur: AppFormatters.currency(socle.exigenceTotale),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Assiette du ratio de levier (EP33) : '
            '${AppFormatters.currency(socle.assietteLevier)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
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
            OutlinedButton.icon(
              onPressed: onDemander,
              icon: const Icon(Icons.fact_check_outlined, size: 17),
              label: const Text('Confronter aux onze normes'),
            )
          else
            FutureBuilder<AnalyseDeclaration>(
              future: future,
              builder: (context, instantane) =>
                  AnalyseIndicateurs(instantane: instantane),
            ),
        ],
      ),
    );
  }
}

class _Tuile extends StatelessWidget {
  const _Tuile({
    required this.libelle,
    required this.valeur,
    this.aide,
    this.couleur,
  });

  final String libelle;
  final String valeur;
  final String? aide;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 232,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (couleur ?? (isDark ? AppTheme.darkBorder : AppTheme.border))
            .withValues(alpha: couleur == null ? 0.35 : 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            libelle,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 4),
          Text(
            valeur,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: couleur,
            ),
          ),
          if (aide != null) ...[
            const SizedBox(height: 3),
            Text(
              aide!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({required this.libelle, required this.valeur});

  final String libelle;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          libelle,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        Text(
          valeur,
          style:
              theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
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
