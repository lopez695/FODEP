import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/utils/formatters.dart';
import '../models/participation_models.dart';
import 'jauge_limite.dart';
import 'participations_dialog.dart';
import 'tableau_maison.dart';

/// Le détail des cinq limites qui encadrent les participations.
///
/// La carte de l'onglet Portefeuille n'en donne que l'état : une jauge par
/// limite, et l'alerte s'il y en a une. Le calcul qui produit chaque ratio —
/// numérateur, dénominateur, marge restante — vit ici, parce qu'un ratio qu'on
/// ne peut pas refaire ne se conteste pas, mais que l'afficher en permanence
/// noierait la carte.
class LimitesParticipationsPage extends StatefulWidget {
  const LimitesParticipationsPage({super.key, required this.api});

  final RwaApiService api;

  static Future<void> ouvrir(BuildContext context, RwaApiService api) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LimitesParticipationsPage(api: api),
      ),
    );
  }

  @override
  State<LimitesParticipationsPage> createState() =>
      _LimitesParticipationsPageState();
}

class _LimitesParticipationsPageState extends State<LimitesParticipationsPage> {
  late Future<SyntheseParticipations> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchSyntheseParticipations();
  }

  void _recharger() {
    setState(() {
      _future = widget.api.fetchSyntheseParticipations();
    });
  }

  /// Saisie des participations : c'est elle qui nourrit toutes ces limites,
  /// sa place est donc ici, à côté de ce qu'elle produit.
  Future<void> _gerer() async {
    final modifie = await ParticipationsDialog.show(context, widget.api);
    if (modifie && mounted) _recharger();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 128,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: BoutonEnTete(
            icone: Icons.arrow_back,
            libelle: 'Retour',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(
          'Limites prudentielles sur les participations',
          style: theme.textTheme.titleMedium?.copyWith(
            color: tableauEntete,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          // La seule action de cette barre qui écrive quelque chose : c'est
          // elle qui nourrit les cinq limites affichées en dessous.
          BoutonEnTete(
            icone: Icons.edit_outlined,
            libelle: 'Gérer les participations',
            onPressed: _gerer,
            principal: true,
          ),
          const SizedBox(width: 10),
          BoutonEnTete(
            icone: Icons.refresh,
            libelle: 'Recalculer',
            onPressed: _recharger,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: FutureBuilder<SyntheseParticipations>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Chargement impossible : ${snapshot.error}'),
            );
          }
          final synthese = snapshot.data!;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
                children: [
                  Text(
                    'Chaque limite rapporte un encours à une assiette. Les '
                    'assiettes sont ci-dessous, les limites en dessous : la '
                    'jauge mesure la part du plafond consommée, et dépliez une '
                    'ligne pour le calcul qui la produit.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ASSIETTES',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Assiettes(synthese: synthese),
                  const SizedBox(height: 20),
                  cadreTableau(
                    context: context,
                    colonnes: const [
                      (libelle: 'Norme', flex: null, largeur: 72),
                      (libelle: 'Limite', flex: 5, largeur: null),
                      (libelle: 'Observé', flex: 2, largeur: null),
                      (libelle: 'Plafond', flex: 2, largeur: null),
                      (libelle: 'Consommation', flex: 4, largeur: null),
                      (libelle: 'Situation', flex: 3, largeur: null),
                      (libelle: '', flex: null, largeur: 40),
                    ],
                    lignes: [
                      for (var i = 0; i < synthese.limites.length; i++)
                        _LigneLimite(
                          limite: synthese.limites[i],
                          alternee: i.isOdd,
                        ),
                    ],
                  ),
                  if (synthese.alertes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    // Ambre, comme sur la carte : ces messages signalent une
                    // donnée absente, pas un plafond franchi.
                    for (final alerte in synthese.alertes)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: vigilanceFond,
                          border: Border.all(color: vigilanceBordure),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                size: 18, color: vigilanceTexte),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                alerte,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Les assiettes sur lesquelles les limites se calculent.
class _Assiettes extends StatelessWidget {
  const _Assiettes({required this.synthese});

  final SyntheseParticipations synthese;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = synthese.dateFondsPropres == null
        ? null
        : DateTime.tryParse(synthese.dateFondsPropres!);

    Widget tuile(String libelle, String valeur, String precision) {
      return Container(
        width: 232,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          border: Border.all(color: tableauBordure),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              libelle.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              valeur,
              style: theme.textTheme.titleMedium?.copyWith(
                color: tableauEntete,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              precision,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        tuile(
          'Total des participations',
          AppFormatters.millions(synthese.totalGeneral),
          'toutes catégories confondues',
        ),
        tuile(
          'Entités commerciales',
          AppFormatters.millions(synthese.totalEntitesCommerciales),
          '${synthese.nombreEntitesCommerciales} ligne(s) · assiette de RA008',
        ),
        tuile(
          'Fonds propres de base T1',
          synthese.fondsPropresT1 > 0
              ? AppFormatters.millions(synthese.fondsPropresT1)
              : 'non saisis',
          date == null
              ? 'dénominateur de RA007 et RA009'
              : 'au ${AppFormatters.shortDate(date)}',
        ),
        tuile(
          'Fonds propres effectifs',
          synthese.fondsPropresEffectifs > 0
              ? AppFormatters.millions(synthese.fondsPropresEffectifs)
              : 'non saisis',
          'dénominateur de RA008 et RA010',
        ),
        tuile(
          'Immobilisations nettes',
          AppFormatters.millions(synthese.immobilisationsNettes),
          'ajoutées aux participations dans RA009 et RA010',
        ),
      ],
    );
  }
}

/// Une limite dans le tableau, dépliable sur son calcul.
///
/// La ligne dit où en est la limite ; le dépliage dit comment on y arrive. Un
/// ratio qu'on ne peut pas refaire ne se conteste pas, mais l'afficher en
/// permanence noierait les six lignes sous les montants.
class _LigneLimite extends StatefulWidget {
  const _LigneLimite({required this.limite, required this.alternee});

  final LimitePrudentielle limite;
  final bool alternee;

  @override
  State<_LigneLimite> createState() => _LigneLimiteState();
}

class _LigneLimiteState extends State<_LigneLimite> {
  bool _ouvert = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limite = widget.limite;
    // Même état, même mot et même couleur que sur la carte du portefeuille :
    // deux écrans qui montrent la même limite ne doivent pas la qualifier
    // différemment.
    final situation = EtatLimite.de(limite);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          // Une ligne ouverte prend la teinte de son état et garde le fond de
          // son panneau : les deux se lisent comme un seul bloc.
          color: _ouvert
              ? situation.couleur.withValues(alpha: 0.08)
              : (widget.alternee ? tableauLigneAlternee : Colors.white),
          child: InkWell(
            onTap: () => setState(() => _ouvert = !_ouvert),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...celluleTableau(
                    largeur: 72,
                    enfant: Text(
                      limite.code,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  ...celluleTableau(
                    flex: 5,
                    enfant: Text(
                      limite.libelle,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tableauTexteFort,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ...celluleTableau(
                    flex: 2,
                    enfant: Text(
                      limite.mesurable
                          ? '${(limite.observe * 100).toStringAsFixed(2)} %'
                          : '—',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: situation.couleur,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ...celluleTableau(
                    flex: 2,
                    enfant: Text(
                      '${(limite.limite * 100).toStringAsFixed(0)} %',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tableauTexteFort,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ...celluleTableau(
                    flex: 4,
                    enfant: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value:
                                  limite.mesurable ? limite.remplissage : 0.0,
                              minHeight: 7,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                situation.couleur,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 42,
                          child: Text(
                            limite.mesurable
                                ? '${(limite.remplissage * 100).toStringAsFixed(0)} %'
                                : '—',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: situation.couleur,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...celluleTableau(
                    flex: 3,
                    enfant: Row(
                      children: [
                        Icon(situation.icone,
                            size: 14, color: situation.couleur),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            situation.libelle,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: situation.couleur,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...celluleTableau(
                    largeur: 40,
                    enfant: Icon(
                      _ouvert ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: _ouvert
                          ? situation.couleur
                          : theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Aucun filet entre la ligne et son panneau : il les séparerait alors
        // qu'ils forment un tout. Le filet ne revient qu'après.
        if (!_ouvert) Container(height: 0.5, color: tableauBordure),
        if (_ouvert) ...[
          _DetailLimite(limite: limite, situation: situation),
          Container(height: 0.5, color: tableauBordure),
        ],
      ],
    );
  }
}

/// Le calcul d'une limite, rattaché visuellement à sa ligne.
///
/// Deux choses le rattachent : un filet vertical de la couleur de l'état, qui
/// descend de la ligne dépliée, et un encadré dont la largeur est bornée. Sans
/// eux, les montants s'échouaient au bord droit du tableau, à un mètre du
/// libellé qu'ils chiffrent, et rien ne disait de quelle norme ils relevaient.
class _DetailLimite extends StatelessWidget {
  const _DetailLimite({required this.limite, required this.situation});

  final LimitePrudentielle limite;
  final EtatLimite situation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: situation.couleur.withValues(alpha: 0.04),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Le filet prolonge la ligne dépliée : c'est lui qui dit à quelle
            // norme appartient ce qui suit.
            Container(width: 3, color: situation.couleur),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(69, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          limite.code,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: situation.couleur,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Comment cette limite se calcule',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: texteSecondaireLimites,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: _Encadre(limite: limite, situation: situation),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      limite.concerne == null
                          ? 'Déclarée à l\'état ${limite.etat} du FODEP'
                          : 'Portée par ${limite.concerne} · déclarée à '
                              'l\'état ${limite.etat} du FODEP',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        color: texteSecondaireLimites,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le calcul dans son cadre : numérateur, dénominateur, résultat, marge.
///
/// L'ordre est celui d'une division posée. Chaque montant est aligné sous le
/// précédent, à une largeur bornée : un chiffre qu'il faut aller chercher à
/// l'autre bout de l'écran ne se rapproche pas de son libellé.
class _Encadre extends StatelessWidget {
  const _Encadre({required this.limite, required this.situation});

  final LimitePrudentielle limite;
  final EtatLimite situation;

  @override
  Widget build(BuildContext context) {
    final marge = limite.limite * limite.denominateur - limite.numerateur;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: tableauBordure),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LigneDeCalcul(
            intitule: limite.numerateurLibelle,
            valeur: AppFormatters.millions(limite.numerateur),
          ),
          _LigneDeCalcul(
            signe: '÷',
            intitule: limite.denominateurLibelle,
            valeur: limite.mesurable
                ? AppFormatters.millions(limite.denominateur)
                : 'non renseigné',
            alerte: !limite.mesurable,
          ),
          Container(height: 1, color: tableauBordure),
          _LigneDeCalcul(
            signe: '=',
            intitule: 'Niveau observé',
            valeur: limite.mesurable
                ? '${(limite.observe * 100).toStringAsFixed(2)} %'
                : '—',
            couleur: situation.couleur,
            gras: true,
          ),
          _LigneDeCalcul(
            intitule: 'Plafond réglementaire',
            valeur: '${(limite.limite * 100).toStringAsFixed(0)} %',
          ),
          Container(height: 1, color: tableauBordure),
          Container(
            color: situation.couleur.withValues(alpha: 0.06),
            child: _LigneDeCalcul(
              intitule: limite.mesurable
                  ? (limite.respectee
                      ? 'Marge restante avant le plafond'
                      : 'Excédent à résorber')
                  : 'Sans dénominateur, la limite est inconnue',
              valeur: limite.mesurable
                  ? AppFormatters.millions(
                      limite.respectee ? marge : limite.excedent,
                    )
                  : '—',
              couleur: situation.couleur,
              gras: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// Une ligne du calcul : son signe, son intitulé, son montant.
class _LigneDeCalcul extends StatelessWidget {
  const _LigneDeCalcul({
    required this.intitule,
    required this.valeur,
    this.signe,
    this.couleur,
    this.alerte = false,
    this.gras = false,
  });

  final String intitule;
  final String valeur;

  /// « ÷ » ou « = » : le signe rend la division lisible sans phrase.
  final String? signe;

  final Color? couleur;
  final bool alerte;
  final bool gras;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teinte = alerte
        ? limiteDepassee
        : (couleur ?? tableauTexteFort);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              signe ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: texteSecondaireLimites,
              ),
            ),
          ),
          Expanded(
            child: Text(
              intitule,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: gras ? FontWeight.w600 : FontWeight.w400,
                color: gras ? tableauTexteFort : texteSecondaireLimites,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            valeur,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: gras ? 13 : 12.5,
              fontWeight: FontWeight.w700,
              color: teinte,
            ),
          ),
        ],
      ),
    );
  }
}
