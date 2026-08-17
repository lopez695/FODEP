import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../models/participation_models.dart';
import 'jauge_limite.dart';
import 'limites_participations_page.dart';
import 'tableau_maison.dart';

/// Carte « Participations », dans l'onglet Portefeuille du risque de crédit.
///
/// Une participation est une concentration comme une autre : un encours porté
/// sur une contrepartie unique, plafonné par les mêmes fonds propres que les
/// grands risques. Sa place est donc parmi les expositions, à côté des groupes
/// de clients liés, et non dans la vue d'ensemble.
///
/// Cinq limites l'encadrent : 25 % du capital de l'émetteur, 15 % des fonds
/// propres de base, 60 % des fonds propres effectifs, et deux qui y ajoutent
/// les immobilisations, que le dispositif additionne aux participations.
///
/// La carte répond à une question et une seule : « faut-il aller regarder ? ».
/// Elle l'annonce en une phrase et s'arrête là. Les assiettes, les cinq limites
/// nommées et le calcul de chacune sont derrière le bouton « Détails » : une
/// carte d'onglet qui les déroulerait toutes ferait défiler l'écran sans rien
/// apprendre à qui n'a rien à corriger.
class ParticipationsCard extends StatefulWidget {
  const ParticipationsCard({super.key, required this.api});

  final RwaApiService api;

  @override
  State<ParticipationsCard> createState() => _ParticipationsCardState();
}

class _ParticipationsCardState extends State<ParticipationsCard> {
  late Future<SyntheseParticipations> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchSyntheseParticipations();
  }

  /// Ouvre le détail des limites, d'où la saisie des participations est
  /// aussi accessible. Au retour, la carte relit sa synthèse : la page a pu
  /// faire ajouter ou supprimer une ligne.
  Future<void> _ouvrirLeDetail() async {
    await LimitesParticipationsPage.ouvrir(context, widget.api);
    if (!mounted) return;
    // Corps entre accolades : une flèche renverrait le Future affecté, que
    // setState refuse.
    setState(() {
      _future = widget.api.fetchSyntheseParticipations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Participations',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: tableauEntete,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Parts du capital d\'autres sociétés détenues par '
                        'l\'établissement',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: 12, color: _texteSecondaire),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Consultation, comme « Analyse » sur la carte des groupes de
                // clients liés : même traitement pour un même rôle. Un fond
                // teinté en faisait un troisième dessin pour rien.
                BoutonSecondaire(
                  libelle: 'Détails',
                  onPressed: _ouvrirLeDetail,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<SyntheseParticipations>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Text('Chargement impossible : ${snapshot.error}',
                      style: theme.textTheme.bodySmall);
                }
                return _Resume(synthese: snapshot.data!);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Mêmes teintes que les jauges : la carte et la page « Détails » parlent des
// mêmes limites, elles doivent les colorer pareil.
const Color _texteSecondaire = texteSecondaireLimites;

class _Resume extends StatelessWidget {
  const _Resume({required this.synthese});

  final SyntheseParticipations synthese;

  @override
  Widget build(BuildContext context) {
    // La carte ne porte que le verdict. Les assiettes, les cinq limites et le
    // calcul de chacune sont sur la page « Détails » : les répéter ici ferait
    // lire deux fois la même chose, et noierait la seule phrase qui appelle
    // une décision.
    return _Verdict(synthese: synthese);
  }
}

/// La phrase que la carte existe pour dire : faut-il aller regarder ?
///
/// Un dépassement passe avant une limite non mesurable, qui passe avant une
/// limite proche de son plafond : c'est l'ordre dans lequel il faut agir.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.synthese});

  final SyntheseParticipations synthese;

  ({EtatLimite etat, String titre, String detail}) _verdict() {
    final depassees = synthese.depassements;
    final inconnues = synthese.nonMesurables;
    final proches = synthese.limites
        .where((limite) =>
            EtatLimite.de(limite) == EtatLimite.procheDuPlafond)
        .toList();
    final total = synthese.limites.length;

    if (depassees.isNotEmpty) {
      final noms = depassees.map((limite) => limite.code).join(', ');
      return (
        etat: EtatLimite.depassee,
        titre: depassees.length == 1
            ? 'Une limite est dépassée'
            : '${depassees.length} limites sont dépassées',
        detail: 'À corriger avant l\'export : le FODEP déclarera le '
            'dépassement ($noms).',
      );
    }
    if (inconnues.isNotEmpty) {
      return (
        etat: EtatLimite.nonMesurable,
        titre: inconnues.length == 1
            ? 'Une limite n\'est pas mesurable'
            : '${inconnues.length} limites ne sont pas mesurables',
        detail: 'Il manque une donnée pour les calculer. Une limite sans '
            'dénominateur n\'est pas respectée : elle est inconnue.',
      );
    }
    if (proches.isNotEmpty) {
      return (
        etat: EtatLimite.procheDuPlafond,
        titre: 'Les $total limites sont respectées',
        detail: proches.length == 1
            ? 'Une d\'entre elles consomme plus de 80 % de son plafond : '
                '${proches.first.concerne ?? proches.first.libelle}.'
            : '${proches.length} d\'entre elles consomment plus de 80 % de '
                'leur plafond.',
      );
    }
    return (
      etat: EtatLimite.respectee,
      titre: 'Les $total limites sont respectées',
      detail: synthese.nombre == 0
          ? 'Aucune participation n\'est enregistrée : ces limites sont '
              'respectées faute d\'encours, pas après vérification.'
          : '${synthese.nombre} participation(s) suivie(s), toutes sous leur '
              'plafond avec plus de 20 % de marge.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verdict = _verdict();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: verdict.etat.couleur.withValues(alpha: 0.06),
        border: Border.all(color: verdict.etat.couleur.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(10),
      ),
      // Pas d'icône : l'état est déjà écrit en toutes lettres, et le titre le
      // répète en couleur. Un pictogramme de plus ne dirait rien de neuf — la
      // redondance utile est celle du mot, pas celle du symbole.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            verdict.titre,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: verdict.etat.couleur,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            verdict.detail,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontSize: 11.5, color: tableauTexteFort),
          ),
        ],
      ),
    );
  }
}
