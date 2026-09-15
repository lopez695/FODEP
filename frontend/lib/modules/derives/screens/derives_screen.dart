import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../dashboard/widgets/dashboard_design.dart';
import '../../participations/widgets/tableau_maison.dart' show tableauEntete;
import '../models/derive_models.dart';
import '../widgets/derive_formulaire.dart';

/// Registre des instruments dérivés, et l'état EP11 qu'il alimente.
///
/// L'EP11 déclare le risque de contrepartie porté par les dérivés. L'écran
/// montre les deux : les contrats saisis, et les quinze lignes du formulaire
/// telles qu'elles partiront. Une saisie ne se vérifie qu'en regardant la case
/// où elle atterrit — un contrat rangé sous la mauvaise nature ou la mauvaise
/// durée ne se voit pas autrement.
///
/// Un registre vide déclare zéro. C'est légitime pour un établissement qui ne
/// traite pas de dérivés, mais ce n'est pas rien : le formulaire l'affirme au
/// régulateur, et l'écran le dit plutôt que de laisser croire à un oubli.
class DerivesScreen extends StatefulWidget {
  const DerivesScreen({super.key, required this.api});

  final RwaApiService api;

  @override
  State<DerivesScreen> createState() => _DerivesScreenState();
}

/// Les contrats et l'état qu'ils remplissent, chargés ensemble.
typedef _Donnees = ({
  List<Derive> contrats,
  SyntheseEp11 synthese,
  List<ContrepartieDerive> contreparties,
  SousJacents sousJacents,
});

class _DerivesScreenState extends State<DerivesScreen> {
  late Future<_Donnees> _future;

  /// Les tiers du portefeuille, que le formulaire propose au choix.
  List<ContrepartieDerive> _contreparties = const [];

  /// Les quinze lignes de l'EP11, avec la pondération imprimée par la
  /// BCEAO : l'aperçu du formulaire l'applique au contrat en cours de saisie.
  List<LigneEp11> _lignes = const [];

  /// Les crédits, obligations et actions qu'un dérivé peut couvrir.
  SousJacents _sousJacents = SousJacents.vide;

  @override
  void initState() {
    super.initState();
    _future = _charger();
  }

  Future<_Donnees> _charger() async {
    // Les quatre appels partent ensemble : ils ne dépendent pas l'un de l'autre.
    final contrats = widget.api.fetchDerives();
    final synthese = widget.api.fetchSyntheseEp11();
    final contreparties = widget.api.fetchContrepartiesDerives();
    final sousJacents = widget.api.fetchSousJacentsDerives();
    // `Future.wait` les écoute tous d'emblée. Attendus l'un après l'autre, un
    // échec du dernier survenu pendant l'attente du premier n'avait encore
    // aucun destinataire : Dart le signalait comme erreur non traitée, en plus
    // de l'afficher à l'écran.
    await Future.wait<Object?>(
        [contrats, synthese, contreparties, sousJacents]);
    final donnees = (
      contrats: await contrats,
      synthese: await synthese,
      contreparties: await contreparties,
      sousJacents: await sousJacents,
    );
    _contreparties = donnees.contreparties;
    _lignes = donnees.synthese.lignes;
    _sousJacents = donnees.sousJacents;
    return donnees;
  }

  void _recharger() {
    // Corps entre accolades : une flèche renverrait le Future affecté, que
    // setState refuse.
    setState(() {
      _future = _charger();
    });
  }

  Future<void> _editer([Derive? existant]) async {
    final saisi = await DeriveFormulaire.show(
      context,
      _contreparties,
      derive: existant,
      lignes: _lignes,
      sousJacents: _sousJacents,
    );
    if (saisi == null) return;
    try {
      if (existant == null) {
        await widget.api.createDerive(saisi);
      } else {
        await widget.api.updateDerive(saisi);
      }
      _recharger();
    } catch (erreur) {
      _signaler('Enregistrement impossible : $erreur', erreur: true);
    }
  }

  Future<void> _supprimer(Derive contrat) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: const Text('Retirer ce contrat ?'),
        content: Text(
          '${contrat.contrepartie} — ${contrat.nature.label}.\n\n'
          "Il sortira de l'EP11 : l'exposition déclarée baissera d'autant.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexte, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexte, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirme != true || contrat.id == null) return;
    try {
      await widget.api.deleteDerive(contrat.id!);
      _recharger();
    } catch (erreur) {
      _signaler('Suppression impossible : $erreur', erreur: true);
    }
  }

  void _signaler(String message, {bool erreur = false}) {
    if (!mounted) return;
    final c = DashColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: erreur ? c.sousMinimum : c.conforme,
    ));
  }

  /// Les montants se lisent dans l'unité choisie en haut de l'écran. Le
  /// classeur transmis, lui, les porte en millions (notice, § 2.3).
  String _montant(double valeur) =>
      valeur == 0 ? '—' : AppFormatters.montant(valeur);

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Container(
      color: c.surfaceAlt,
      child: FutureBuilder<_Donnees>(
        future: _future,
        builder: (context, instantane) {
          if (instantane.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (instantane.hasError) {
            return _indisponible(c, instantane.error);
          }
          final donnees = instantane.data!;
          return ListView(
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            children: [
              _entete(c, donnees.synthese),
              const SizedBox(height: 16),
              for (final alerte in donnees.synthese.alertes) ...[
                _bandeau(c, alerte),
                const SizedBox(height: 12),
              ],
              _contrats(c, donnees.contrats),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _etatEp11(c, donnees.synthese)),
                  const SizedBox(width: 16),
                  Expanded(flex: 1, child: _ventilation(c, donnees.synthese)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ── En-tête ──────────────────────────────────────────────────────────────

  Widget _entete(DashColors c, SyntheseEp11 synthese) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Dash.radius),
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ÉTAT EP11', style: DashText.eyebrow(c)),
                    const SizedBox(height: 6),
                    Text(
                      'Instruments dérivés',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 720,
                      child: Text(
                        'Swaps de taux, change à terme, contrats sur titres de '
                        'propriété ou produits de base. Chaque contrat est '
                        'décrit une fois ; l\'export en tire la ligne, la '
                        'pondération et l\'exposition du formulaire.',
                        style: TextStyle(
                            fontSize: 12, height: 1.45, color: c.muted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              FilledButton.icon(
                onPressed: () => _editer(),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Ajouter un contrat'),
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, thickness: Dash.hairline, color: c.divider),
          const SizedBox(height: 16),
          Row(
            children: [
              _tuile(c, 'CONTRATS', '${synthese.nombre}', null),
              _separateur(c),
              _tuile(c, '(b) NOTIONNEL',
                  _montant(synthese.totalNotionnel), AppFormatters.libelleUnite()),
              _separateur(c),
              _tuile(c, '(a) COÛT DE REMPLACEMENT',
                  _montant(synthese.totalCoutRemplacement), 'Valeur de marché'),
              _separateur(c),
              _tuile(c, '(e) EXPOSITION DÉCLARÉE',
                  _montant(synthese.totalExposition), 'a + (b × c)',
                  accent: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _separateur(DashColors c) => Container(
        width: Dash.hairline,
        height: 46,
        color: c.divider,
        margin: const EdgeInsets.symmetric(horizontal: 20),
      );

  Widget _tuile(DashColors c, String titre, String valeur, String? note,
      {bool accent = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(titre, style: DashText.eyebrow(c)),
          const SizedBox(height: 6),
          Text(valeur,
              style: DashText.hero(c,
                  size: 21, color: accent ? c.accent : c.ink)),
          if (note != null) ...[
            const SizedBox(height: 3),
            Text(note, style: DashText.caption(c)),
          ],
        ],
      ),
    );
  }

  Widget _bandeau(DashColors c, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: c.sousCible.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: c.sousCible, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: c.sousCible),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 12, height: 1.45, color: c.ink)),
          ),
        ],
      ),
    );
  }

  // ── Les contrats ─────────────────────────────────────────────────────────

  Widget _contrats(DashColors c, List<Derive> contrats) {
    if (contrats.isEmpty) return _registreVide(c);

    return DashPanel(
      title: 'CONTRATS ENREGISTRÉS',
      unit: 'Montants en ${AppFormatters.libelleUnite().toLowerCase()}',
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      // Un vrai `Table` plutôt que des `Row` juxtaposées : chaque cellule
      // porte ses propres filets, et une valeur trop longue agrandit sa
      // ligne au lieu de déborder sur le panneau voisin ou de se faire
      // couper par une ellipse invisible sans survol.
      child: Table(
        border: _filetsTableau(c),
        columnWidths: const {
          0: FlexColumnWidth(2.4),
          1: FlexColumnWidth(1.7),
          2: FlexColumnWidth(1.6),
          3: FlexColumnWidth(0.95),
          4: FlexColumnWidth(1.15),
          5: FlexColumnWidth(1.05),
          6: FlexColumnWidth(1.05),
          7: FixedColumnWidth(88),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: const BoxDecoration(color: tableauEntete),
            children: [
              _teteCelluleTable(c, 'Contrepartie'),
              _teteCelluleTable(c, 'Catégorie'),
              _teteCelluleTable(c, 'Nature'),
              _teteCelluleTable(c, 'Échéance'),
              _teteCelluleTable(c, 'Durée résiduelle'),
              _teteCelluleTable(c, '(b) Notionnel', droite: true),
              _teteCelluleTable(c, '(a) Coût rempl.', droite: true),
              _teteCelluleTable(c, ''),
            ],
          ),
          for (final (index, contrat) in contrats.indexed)
            _ligneContrat(c, contrat, paire: index.isEven),
        ],
      ),
    );
  }

  Widget _registreVide(DashColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Dash.radius),
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        children: [
          Icon(Icons.swap_horiz_rounded, size: 30, color: c.faint),
          const SizedBox(height: 12),
          Text('Aucun contrat enregistré',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: c.ink)),
          const SizedBox(height: 6),
          SizedBox(
            width: 460,
            child: Text(
              "L'EP11 partira à zéro, ce qui déclare au régulateur que "
              "l'établissement ne porte aucun engagement sur instruments de "
              'taux, de change, de propriété ou de produits de base.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.45, color: c.muted),
            ),
          ),
        ],
      ),
    );
  }

  TableRow _ligneContrat(DashColors c, Derive contrat, {required bool paire}) {
    return TableRow(
      decoration: BoxDecoration(color: paire ? null : c.surfaceAlt.withValues(alpha: 0.5)),
      children: [
        _celluleTable(
          c,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(contrat.contrepartie,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: c.ink)),
              // L'identifiant d'abord : c'est par lui que le contrat se
              // relie à la fiche de la contrepartie.
              if (contrat.contrepartieId != null ||
                  contrat.typeContrat != null ||
                  contrat.sousJacentLibelle != null)
                Text(
                  [
                    if (contrat.contrepartieId != null)
                      contrat.contrepartieId!,
                    if (contrat.typeContrat != null) contrat.typeContrat!,
                    // Ce que le contrat couvre, pour le reconnaître.
                    if (contrat.sousJacentLibelle != null)
                      'sur ${contrat.sousJacentLibelle!}',
                  ].join(' · '),
                  style: DashText.caption(c),
                ),
            ],
          ),
        ),
        _celluleTexteTable(
            c,
            contrat.horsEp11
                ? '${contrat.categorieContrepartie.label} (repli)'
                : contrat.categorieContrepartie.label),
        _celluleTexteTable(c, contrat.nature.label),
        _celluleTexteTable(c, _jour(contrat.dateEcheance)),
        _celluleTable(
          c,
          Align(
            alignment: Alignment.centerLeft,
            child: _puce(c, contrat.tranche.label),
          ),
        ),
        _celluleMontantTable(c, contrat.montantNotionnel, contrat.devise),
        _celluleMontantTable(c, contrat.coutRemplacement, contrat.devise),
        _celluleTable(
          c,
          // Les deux boutons sont contraints : sans cela `IconButton` impose
          // sa zone de clic de 40 pixels et la ligne déborde de sa colonne.
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _action(c, Icons.edit_outlined, 'Modifier',
                  () => _editer(contrat)),
              _action(c, Icons.delete_outline_rounded, 'Retirer',
                  () => _supprimer(contrat)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
      ],
    );
  }

  /// Un bouton d'action de ligne, réduit à la taille de son icône.
  ///
  /// `constraints` ne suffit pas : `IconButton` réserve par défaut une zone
  /// tactile de 48 pixels, que seule `tapTargetSize` libère. C'est ce qui
  /// faisait déborder la ligne de sa colonne.
  Widget _action(
          DashColors c, IconData icone, String infobulle, VoidCallback action) =>
      IconButton(
        tooltip: infobulle,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(icone, size: 16, color: c.muted),
        onPressed: action,
      );

  /// Les filets de la grille, communs aux deux tableaux de l'écran : le
  /// registre des contrats et l'état qu'il remplit se lisent l'un après
  /// l'autre, et deux grilles différentes donneraient à croire qu'ils ne
  /// parlent pas de la même chose.
  TableBorder _filetsTableau(DashColors c) => TableBorder(
        top: BorderSide(color: c.border, width: Dash.hairline),
        bottom: BorderSide(color: c.border, width: Dash.hairline),
        left: BorderSide(color: c.border, width: Dash.hairline),
        right: BorderSide(color: c.border, width: Dash.hairline),
        horizontalInside: BorderSide(color: c.divider, width: Dash.hairline),
        verticalInside: BorderSide(color: c.divider, width: Dash.hairline),
      );

  /// Cellule de `Table` générique : juste le rembourrage qui écarte le
  /// contenu des filets de la grille.
  Widget _celluleTable(DashColors c, Widget enfant,
          {EdgeInsets padding =
              const EdgeInsets.symmetric(horizontal: 10, vertical: 9)}) =>
      Padding(padding: padding, child: enfant);

  /// Cellule de texte : pas d'ellipse ni d'info-bulle, le texte s'enroule
  /// et agrandit sa ligne — rien n'est jamais caché.
  Widget _celluleTexteTable(DashColors c, String texte) => _celluleTable(
        c,
        Text(texte, style: TextStyle(fontSize: 11.5, color: c.muted)),
      );

  /// Un montant, avec sa devise d'origine quand elle n'est pas celle du
  /// formulaire : le déclarant doit voir qu'une conversion a eu lieu.
  Widget _celluleMontantTable(DashColors c, double valeur, String devise) {
    return _celluleTable(
      c,
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_montant(valeur), style: DashText.value(c)),
          if (devise != 'XOF') Text(devise, style: DashText.caption(c)),
        ],
      ),
    );
  }

  /// En-tête de colonne pour la `Table` des contrats : bleu marine et texte
  /// blanc, comme le bandeau des tableaux de l'onglet Portefeuille.
  Widget _teteCelluleTable(DashColors c, String texte, {bool droite = false}) =>
      _celluleTable(
        c,
        Text(
          texte,
          textAlign: droite ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      );

  static String _jour(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  // ── L'état tel qu'il partira ─────────────────────────────────────────────

  Widget _etatEp11(DashColors c, SyntheseEp11 synthese) {
    return DashPanel(
      title: 'EP11 — TEL QUE LA DÉCLARATION LE PORTERA',
      subtitle: 'La pondération (c) est imprimée par la BCEAO sur le '
          'formulaire ; (d) = b × c et (e) = a + d sont calculés.',
      unit: AppFormatters.libelleUnite(),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      // La même grille que le registre au-dessus : un libellé du formulaire
      // s'enroule dans sa cellule au lieu d'être coupé, et les quinze lignes
      // se comparent d'un coup d'œil à celles qui les ont remplies.
      child: Table(
        border: _filetsTableau(c),
        columnWidths: const {
          0: FixedColumnWidth(76),
          1: FlexColumnWidth(3.2),
          2: FixedColumnWidth(74),
          3: FlexColumnWidth(1.0),
          4: FlexColumnWidth(1.0),
          5: FixedColumnWidth(66),
          6: FlexColumnWidth(1.0),
          7: FlexColumnWidth(1.0),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: const BoxDecoration(color: tableauEntete),
            children: [
              _teteCelluleTable(c, 'Code'),
              _teteCelluleTable(c, 'Poste'),
              _teteCelluleTable(c, 'Contrats', droite: true),
              _teteCelluleTable(c, '(a)', droite: true),
              _teteCelluleTable(c, '(b)', droite: true),
              _teteCelluleTable(c, '(c)', droite: true),
              _teteCelluleTable(c, '(d)', droite: true),
              _teteCelluleTable(c, '(e)', droite: true),
            ],
          ),
          for (final (index, ligne) in synthese.lignes.indexed)
            _ligneEp11(c, ligne, paire: index.isEven),
        ],
      ),
    );
  }

  /// Les quinze lignes sont toutes affichées, y compris les vides.
  ///
  /// Elles partent toutes dans la déclaration : voir un zéro là où on
  /// attendait un contrat est précisément ce qu'on vient vérifier ici.
  TableRow _ligneEp11(DashColors c, LigneEp11 ligne, {required bool paire}) {
    final porte = ligne.nombreContrats > 0;
    return TableRow(
      // Une ligne qui porte un contrat se teinte de l'accent ; les autres
      // suivent le zébrage du registre. Les quinze partent dans la
      // déclaration, mais seules celles-là disent quelque chose.
      decoration: BoxDecoration(
        color: porte
            ? c.accent.withValues(alpha: 0.06)
            : (paire ? null : c.surfaceAlt.withValues(alpha: 0.5)),
      ),
      children: [
        _celluleTable(c, _puce(c, ligne.code, teinte: porte ? c.accent : null)),
        _celluleTable(
          c,
          Text(
            ligne.libelle,
            style: TextStyle(
              fontSize: 11.5,
              color: porte ? c.ink : c.muted,
              fontWeight: porte ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        _celluleNombreTable(c, porte ? '${ligne.nombreContrats}' : '—', porte),
        _celluleNombreTable(c, _montant(ligne.coutRemplacement), porte),
        _celluleNombreTable(c, _montant(ligne.montantNotionnel), porte),
        _celluleNombreTable(
          c,
          '${(ligne.ponderation * 100).toStringAsFixed(1)} %',
          false,
        ),
        _celluleNombreTable(c, _montant(ligne.notionnelPondere), porte),
        _celluleNombreTable(c, _montant(ligne.exposition), porte, accent: porte),
      ],
    );
  }

  /// Un nombre dans la grille : aligné à droite, atténué quand la ligne ne
  /// porte aucun contrat — elle déclare zéro, et l'écran le dit sans le crier.
  Widget _celluleNombreTable(DashColors c, String texte, bool porte,
          {bool accent = false}) =>
      _celluleTable(
        c,
        Text(
          texte,
          textAlign: TextAlign.right,
          style: DashText.value(c,
              color: accent ? c.accent : (porte ? c.ink : c.faint),
              weight: accent ? FontWeight.w700 : FontWeight.w500),
        ),
      );

  /// La ventilation de l'exposition par catégorie de contrepartie.
  ///
  /// Le formulaire l'étale sur cinq colonnes ; les poser à côté du tableau
  /// principal l'aurait rendu illisible, et elles se lisent aussi bien en
  /// total — la somme retombe par construction sur l'exposition déclarée.
  Widget _ventilation(DashColors c, SyntheseEp11 synthese) {
    final totaux = <String, double>{};
    for (final ligne in synthese.lignes) {
      ligne.ventilation.forEach((categorie, montant) {
        totaux[categorie] = (totaux[categorie] ?? 0) + montant;
      });
    }

    return DashPanel(
      title: 'VENTILATION (e)',
      unit: 'Par contrepartie',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final categorie in CategorieContrepartieDerive.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(categorie.label,
                        style: TextStyle(fontSize: 11.5, color: c.muted)),
                  ),
                  const SizedBox(width: 8),
                  Text(_montant(totaux[categorie.wire] ?? 0),
                      style: DashText.value(c,
                          color: (totaux[categorie.wire] ?? 0) > 0
                              ? c.ink
                              : c.faint)),
                ],
              ),
            ),
          Divider(height: 14, thickness: Dash.hairline, color: c.divider),
          Row(
            children: [
              Expanded(
                child: Text('Total',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: c.ink)),
              ),
              Text(_montant(synthese.totalExposition),
                  style: DashText.value(c,
                      color: c.accent, weight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Fragments communs ────────────────────────────────────────────────────

  /// Une pastille : code DISPRU ou tranche de durée. Courte, discrète, et
  /// alignée — c'est par elle qu'on retrouve la case sur le formulaire.
  Widget _puce(DashColors c, String texte, {Color? teinte}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: (teinte ?? c.muted).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          texte,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: teinte ?? c.muted,
            fontFeatures: Dash.tabular,
          ),
        ),
      ),
    );
  }

  Widget _indisponible(DashColors c, Object? erreur) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 32, color: c.faint),
            const SizedBox(height: 12),
            Text(
              _messageDeChargement(erreur, 'Registre des dérivés indisponible'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.5, color: c.muted),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
                onPressed: _recharger, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

/// Ce qu'il faut comprendre d'une erreur de chargement.
///
/// « Not Found » (404) et « Method Not Allowed » (405) ne disent rien à
/// personne : ce sont les réponses d'un serveur antérieur à la route. Le 404
/// quand le chemin lui est inconnu ; le 405 quand il le confond avec un autre —
/// un ancien backend prend « /derives/contreparties » pour la modification du
/// contrat « contreparties », et refuse la lecture. Le piège est que le script
/// de lancement réutilise un backend déjà en écoute : relancer l'application ne
/// suffit pas, il faut arrêter le processus.
String _messageDeChargement(Object? erreur, String quoi) {
  final texte = '${erreur ?? ''}';
  final routeAbsente = texte.contains('Not Found') ||
      texte.contains('404') ||
      texte.contains('Method Not Allowed') ||
      texte.contains('405');
  if (routeAbsente) {
    return '$quoi : le serveur joint ne connaît pas cette route. Il date '
        "d'avant son ajout — arrêtez le backend puis relancez-le, le script "
        'réutilise celui qui écoute déjà.';
  }
  return '$quoi : $texte';
}
