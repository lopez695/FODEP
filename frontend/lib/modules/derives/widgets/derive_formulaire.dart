import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/formatters.dart';
import '../../dashboard/widgets/dashboard_design.dart';
import '../models/derive_models.dart';

/// Saisie d'un contrat dérivé.
///
/// On pense un dérivé par **ce qu'il couvre** : le crédit d'un client, une
/// obligation ou une action détenue, ou rien de tel — une devise, un indice.
/// Les onglets de l'en-tête choisissent ce sous-jacent, et la première section
/// du formulaire change avec eux.
///
/// Le sous-jacent n'est pas la contrepartie. L'EP11 ventile celui qui a
/// **signé** le contrat : l'émetteur d'une obligation ou d'une action couverte
/// ne l'est pas, et le prendre pour contrepartie rangerait un swap signé avec
/// une banque parmi les souverains. D'où une section « Signé avec » sous les
/// onglets Obligation et Action. Seul le crédit fait exception : le client qui
/// emprunte signe aussi sa couverture, et devient la contrepartie tout seul.
///
/// Le calcul se lit à côté de la saisie : le panneau « Ce que le contrat
/// déclarera » donne, à chaque frappe, la ligne de l'EP11, la colonne et
/// l'exposition. Sa pondération vient des lignes que le serveur a lues sur le
/// formulaire de la BCEAO ; le calcul qui fait foi reste celui de l'export.
class DeriveFormulaire extends StatefulWidget {
  const DeriveFormulaire({
    super.key,
    required this.contreparties,
    this.derive,
    this.lignes = const [],
    this.sousJacents = SousJacents.vide,
  });

  /// Les contreparties du portefeuille, parmi lesquelles on choisit.
  final List<ContrepartieDerive> contreparties;
  final Derive? derive;

  /// Les quinze lignes de l'EP11 telles que le serveur les a rendues, avec la
  /// pondération imprimée par la BCEAO. Vides, l'aperçu dit que la pondération
  /// sera lue à l'export.
  final List<LigneEp11> lignes;

  /// Les crédits, obligations et actions qu'un dérivé peut couvrir.
  final SousJacents sousJacents;

  static Future<Derive?> show(
    BuildContext context,
    List<ContrepartieDerive> contreparties, {
    Derive? derive,
    List<LigneEp11> lignes = const [],
    SousJacents sousJacents = SousJacents.vide,
  }) {
    return showDialog<Derive>(
      context: context,
      builder: (_) => DeriveFormulaire(
        contreparties: contreparties,
        derive: derive,
        lignes: lignes,
        sousJacents: sousJacents,
      ),
    );
  }

  @override
  State<DeriveFormulaire> createState() => _DeriveFormulaireState();
}

/// Les clés des champs, pour que les essais les trouvent sans dépendre de
/// leurs libellés, que la mise en page pose au-dessus des cases.
abstract final class DeriveFormulaireCles {
  static const contrepartie = ValueKey<String>('derive-contrepartie');
  static const credit = ValueKey<String>('derive-credit');
  static const obligation = ValueKey<String>('derive-obligation');
  static const action = ValueKey<String>('derive-action');
  static const nature = ValueKey<String>('derive-nature');
  static const typeContrat = ValueKey<String>('derive-type');
  static const devise = ValueKey<String>('derive-devise');
  static const notionnel = ValueKey<String>('derive-notionnel');
  static const cout = ValueKey<String>('derive-cout');
  static const commentaire = ValueKey<String>('derive-commentaire');
  static const fiche = ValueKey<String>('derive-fiche');
  static const ficheSousJacent = ValueKey<String>('derive-fiche-sous-jacent');
  static const apercu = ValueKey<String>('derive-apercu');

  static ValueKey<String> onglet(TypeSousJacent type) =>
      ValueKey<String>('derive-onglet-${type.wire}');
}

/// Au-delà, la liste des suggestions n'aide plus à choisir : mieux vaut
/// affiner la recherche.
const _suggestionsMax = 30;

/// En deçà, les deux colonnes se serreraient au point de tronquer les
/// libellés : l'aperçu passe sous la saisie.
const _largeurDeuxColonnes = 820.0;

/// En deçà, les onglets passent sous le titre plutôt qu'à sa droite.
const _largeurOngletsEnLigne = 860.0;

class _DeriveFormulaireState extends State<DeriveFormulaire> {
  final _cle = GlobalKey<FormState>();

  late final TextEditingController _notionnel;
  late final TextEditingController _coutRemplacement;
  late final TextEditingController _commentaire;

  late TypeSousJacent _onglet;
  CreditCouvrable? _credit;
  ObligationDetenue? _obligation;
  ActionDetenue? _action;

  /// Celui qui a signé le contrat : choisi sous les onglets Obligation, Action
  /// et Autre, déduit du crédit sous l'onglet Crédit.
  ContrepartieDerive? _selection;

  late NatureDerive _nature;

  /// Facultatif : `null` se lit « Non précisé ».
  String? _typeContrat;
  late String _devise;
  late DateTime _echeance;
  DateTime? _conclusion;

  @override
  void initState() {
    super.initState();
    final existant = widget.derive;
    _notionnel = TextEditingController(
        text: existant == null ? '' : _texte(existant.montantNotionnel));
    _coutRemplacement = TextEditingController(
        text: existant == null ? '' : _texte(existant.coutRemplacement));
    _commentaire = TextEditingController(text: existant?.commentaire ?? '');
    _typeContrat = existant?.typeContrat;
    _devise = (existant?.devise ?? 'XOF').toUpperCase();
    _nature = existant?.nature ?? NatureDerive.taux;
    _echeance = existant?.dateEcheance ??
        DateTime.now().add(const Duration(days: 365));
    _conclusion = existant?.dateConclusion;

    // Un nouveau contrat s'ouvre sur la couverture d'un crédit : c'est le cas
    // le plus courant dans une banque de la zone.
    _onglet = existant?.sousJacentType ?? TypeSousJacent.credit;
    final reference = existant?.sousJacentRef;
    if (reference != null) {
      switch (_onglet) {
        case TypeSousJacent.credit:
          _credit = _premier(widget.sousJacents.credits, (x) => x.id == reference);
        case TypeSousJacent.obligation:
          _obligation =
              _premier(widget.sousJacents.obligations, (x) => x.isin == reference);
        case TypeSousJacent.action:
          _action =
              _premier(widget.sousJacents.actions, (x) => x.ticker == reference);
        case TypeSousJacent.autre:
          break;
      }
    }

    final identifiant = existant?.contrepartieId;
    if (identifiant != null) {
      _selection = _premier(widget.contreparties, (x) => x.id == identifiant);
    }
    _selection ??= _credit?.contrepartieDerive;

    final imposee = _onglet.natureImposee;
    if (imposee != null) _nature = imposee;
  }

  static T? _premier<T>(Iterable<T> elements, bool Function(T) test) {
    for (final element in elements) {
      if (test(element)) return element;
    }
    return null;
  }

  static String _texte(double valeur) =>
      valeur == valeur.roundToDouble() ? valeur.toStringAsFixed(0) : '$valeur';

  @override
  void dispose() {
    _notionnel.dispose();
    _coutRemplacement.dispose();
    _commentaire.dispose();
    super.dispose();
  }

  double _nombre(TextEditingController controleur) {
    final texte = controleur.text
        .trim()
        .replaceAll(' ', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    return double.tryParse(texte) ?? 0.0;
  }

  /// Les types de la nature choisie, plus celui du contrat s'il n'y figure
  /// pas : un contrat enregistré avant la liste fermée garde son libellé.
  List<String> get _typesProposes {
    final types = [..._nature.typesDeContrat];
    final actuel = _typeContrat;
    if (actuel != null && !types.contains(actuel)) types.insert(0, actuel);
    return types;
  }

  /// Les devises convertibles, plus celle du contrat si elle n'y figure
  /// pas — pour qu'il s'ouvre ; le serveur la refusera à l'enregistrement.
  List<String> get _devisesProposees => [
        ...devisesDerives,
        if (!devisesDerives.contains(_devise)) _devise,
      ];

  TrancheDuree get _tranche => TrancheDuree.pour(_echeance, DateTime.now());

  /// La ligne de l'EP11 où tombe le contrat, telle que le serveur l'a rendue.
  LigneEp11? get _ligne {
    for (final ligne in widget.lignes) {
      if (ligne.nature == _nature.wire && ligne.tranche == _tranche.wire) {
        return ligne;
      }
    }
    return null;
  }

  /// Référence et libellé du sous-jacent choisi, selon l'onglet.
  (String?, String?) get _sousJacentChoisi => switch (_onglet) {
        TypeSousJacent.credit =>
          (_credit?.id, _credit == null ? null : 'Crédit ${_credit!.id}'),
        TypeSousJacent.obligation => (_obligation?.isin, _obligation?.libelle),
        TypeSousJacent.action => (_action?.ticker, _action?.libelle),
        TypeSousJacent.autre => (null, null),
      };

  /// Minuscules et sans accents : « Société Générale » se retrouve en tapant
  /// « societe ».
  static String _normaliser(String texte) {
    const accents = {
      'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'É': 'e', 'È': 'e',
    };
    final tampon = StringBuffer();
    for (final lettre in texte.toLowerCase().split('')) {
      tampon.write(accents[lettre] ?? lettre);
    }
    return tampon.toString();
  }

  void _appliquerNature(NatureDerive nature) {
    _nature = nature;
    // Un type propre à l'ancienne nature n'a plus de sens.
    if (_typeContrat != null && !_nature.typesDeContrat.contains(_typeContrat)) {
      _typeContrat = null;
    }
  }

  void _changerOnglet(TypeSousJacent type) {
    if (type == _onglet) return;
    setState(() {
      final quitteLeCredit = _onglet == TypeSousJacent.credit;
      _onglet = type;
      _credit = null;
      _obligation = null;
      _action = null;
      // La contrepartie déduite d'un crédit ne vaut que pour lui ; celle
      // qu'on a choisie à la main reste d'un onglet de titre à l'autre.
      if (quitteLeCredit || type == TypeSousJacent.credit) _selection = null;
      final imposee = type.natureImposee;
      if (imposee != null) _appliquerNature(imposee);
    });
  }

  Future<void> _choisirDate({required bool echeance}) async {
    final initiale = echeance ? _echeance : (_conclusion ?? DateTime.now());
    final choisie = await showDatePicker(
      context: context,
      initialDate: initiale,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (choisie == null) return;
    setState(() {
      if (echeance) {
        _echeance = choisie;
      } else {
        _conclusion = choisie;
      }
    });
  }

  void _valider() {
    if (!(_cle.currentState?.validate() ?? false)) return;
    final contrepartie = _selection!;
    final (reference, libelle) = _sousJacentChoisi;
    Navigator.pop(
      context,
      Derive(
        id: widget.derive?.id,
        contrepartieId: contrepartie.id,
        contrepartie: contrepartie.nom,
        categorieContrepartie: contrepartie.categorieEp11,
        categoriePrudentielle: contrepartie.categoriePrudentielle,
        notation: contrepartie.notation,
        horsEp11: contrepartie.horsEp11,
        sousJacentType: _onglet,
        sousJacentRef: reference,
        sousJacentLibelle: libelle,
        nature: _onglet.natureImposee ?? _nature,
        typeContrat: _typeContrat,
        devise: _devise,
        montantNotionnel: _nombre(_notionnel),
        coutRemplacement: _nombre(_coutRemplacement),
        dateConclusion: _conclusion,
        dateEcheance: _echeance,
        commentaire:
            _commentaire.text.trim().isEmpty ? null : _commentaire.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Dialog(
      backgroundColor: c.surfaceAlt,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dash.radius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Form(
          key: _cle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _entete(c),
              Flexible(
                child: LayoutBuilder(
                  builder: (context, contraintes) {
                    final large = contraintes.maxWidth >= _largeurDeuxColonnes;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                      child: large
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: _saisie(c)),
                                const SizedBox(width: 16),
                                Expanded(flex: 2, child: _apercu(c)),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _saisie(c),
                                const SizedBox(height: 16),
                                _apercu(c),
                              ],
                            ),
                    );
                  },
                ),
              ),
              _pied(c),
            ],
          ),
        ),
      ),
    );
  }

  // ── En-tête : le titre et les onglets de sous-jacent ─────────────────────

  String get _explicationOnglet => switch (_onglet) {
        TypeSousJacent.credit =>
          'Le client qui a emprunté signe aussi la couverture : il devient la '
              'contrepartie du contrat.',
        TypeSousJacent.obligation =>
          'Un dérivé lié à une obligation détenue porte sur les taux. Il est '
              'signé avec une banque ou un client, pas avec l\'émetteur.',
        TypeSousJacent.action =>
          'Un dérivé sur une action détenue porte sur les titres de propriété. '
              'Il est signé avec une banque ou un client, pas avec la société.',
        TypeSousJacent.autre =>
          'Un contrat sur une devise, un indice ou une matière première, sans '
              'position détenue.',
      };

  Widget _entete(DashColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 12, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          bottom: BorderSide(color: c.border, width: Dash.hairline),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, contraintes) {
          final enLigne = contraintes.maxWidth >= _largeurOngletsEnLigne;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.swap_horiz_rounded,
                        size: 20, color: c.accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('REGISTRE DES DÉRIVÉS · ÉTAT EP11',
                            style: DashText.eyebrow(c)),
                        const SizedBox(height: 4),
                        Text(
                          widget.derive == null
                              ? 'Ajouter un contrat dérivé'
                              : 'Modifier le contrat',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (enLigne) ...[const SizedBox(width: 12), _onglets(c)],
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, size: 20, color: c.muted),
                  ),
                ],
              ),
              if (!enLigne) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: _onglets(c),
                ),
              ],
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 52, right: 40),
                child: Text(
                  _explicationOnglet,
                  style: TextStyle(fontSize: 12, height: 1.4, color: c.muted),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _onglets(DashColors c) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final type in TypeSousJacent.values) _ongletBouton(c, type),
      ],
    );
  }

  static IconData _icone(TypeSousJacent type) => switch (type) {
        TypeSousJacent.credit => Icons.account_balance_wallet_outlined,
        TypeSousJacent.obligation => Icons.receipt_long_outlined,
        TypeSousJacent.action => Icons.show_chart_rounded,
        TypeSousJacent.autre => Icons.more_horiz_rounded,
      };

  Widget _ongletBouton(DashColors c, TypeSousJacent type) {
    final actif = type == _onglet;
    return InkWell(
      key: DeriveFormulaireCles.onglet(type),
      onTap: () => _changerOnglet(type),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: actif ? c.accent.withValues(alpha: 0.10) : c.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: actif ? c.accent.withValues(alpha: 0.55) : c.border,
            width: actif ? 1.2 : Dash.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icone(type), size: 15, color: actif ? c.accent : c.muted),
            const SizedBox(width: 6),
            Text(
              type.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
                color: actif ? c.accent : c.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pied ─────────────────────────────────────────────────────────────────

  Widget _pied(DashColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border, width: Dash.hairline)),
      ),
      child: Row(
        children: [
          Icon(Icons.link_rounded, size: 15, color: c.faint),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Nom, catégorie et notation viennent de la fiche de la '
              'contrepartie : ils ne se saisissent pas.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DashText.caption(c),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _valider,
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Enregistrer'),
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ── La saisie ────────────────────────────────────────────────────────────

  Widget _saisie(DashColors c) {
    final sections = <(String, List<Widget>)>[
      ..._sectionsSousJacent(c),
      ('CONTRAT', _contenuContrat(c)),
      ('MONTANTS', _contenuMontants(c)),
      ('ÉCHÉANCE', _contenuEcheance(c)),
      ('COMMENTAIRE', _contenuCommentaire(c)),
    ];
    // La clé suit l'onglet : changer d'onglet reconstruit les champs, qui
    // repartent de l'état du formulaire au lieu de garder une valeur que
    // l'onglet vient d'effacer ou d'imposer.
    return KeyedSubtree(
      key: ValueKey<String>('derive-saisie-${_onglet.wire}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _section(c, '${i + 1} · ${sections[i].$1}', sections[i].$2),
          ],
        ],
      ),
    );
  }

  List<(String, List<Widget>)> _sectionsSousJacent(DashColors c) {
    switch (_onglet) {
      case TypeSousJacent.credit:
        return [
          ("CRÉDIT D'UN CLIENT", [
            _rechercheCredit(c),
            if (_credit != null) ...[
              const SizedBox(height: 10),
              _ficheCredit(c, _credit!),
            ],
          ]),
        ];
      case TypeSousJacent.obligation:
        return [
          ('OBLIGATION', [
            _rechercheObligation(c),
            if (_obligation != null) ...[
              const SizedBox(height: 10),
              _ficheObligation(c, _obligation!),
            ],
          ]),
          ('SIGNÉ AVEC', _contenuContrepartie(c)),
        ];
      case TypeSousJacent.action:
        return [
          ('ACTION', [
            _rechercheAction(c),
            if (_action != null) ...[
              const SizedBox(height: 10),
              _ficheAction(c, _action!),
            ],
          ]),
          ('SIGNÉ AVEC', _contenuContrepartie(c)),
        ];
      case TypeSousJacent.autre:
        return [('CONTREPARTIE', _contenuContrepartie(c))];
    }
  }

  List<Widget> _contenuContrepartie(DashColors c) => [
        _recherche<ContrepartieDerive>(
          c,
          cle: DeriveFormulaireCles.contrepartie,
          elements: widget.contreparties,
          selection: _selection,
          libelle: (x) => x.libelle,
          titre: (x) => x.nom,
          detail: (x) =>
              '${x.categoriePrudentielle ?? 'Catégorie inconnue'} · '
              '${x.notation ?? 'non notée'}',
          pastille: (x) => x.id,
          correspond: (x, recherche) =>
              _normaliser(x.nom).contains(recherche) ||
              x.id.toLowerCase().contains(recherche),
          choisir: (x) => _selection = x,
          effacer: () => _selection = null,
          indice: 'Rechercher par nom ou identifiant (EXP-2026-…)',
          indiceVide:
              'Aucune contrepartie dans le portefeuille : importez-la d\'abord',
          messageRequis: 'Choisissez une contrepartie du portefeuille.',
        ),
        if (_selection != null) ...[
          const SizedBox(height: 10),
          _ficheContrepartie(c, _selection!),
        ],
      ];

  Widget _rechercheCredit(DashColors c) => _recherche<CreditCouvrable>(
        c,
        cle: DeriveFormulaireCles.credit,
        elements: widget.sousJacents.credits,
        selection: _credit,
        libelle: (x) => x.libelle,
        titre: (x) => x.contrepartie,
        detail: (x) =>
            '${_montantDevise(x.montantBrut, x.devise)} · échéance '
            '${x.dateEcheance == null ? '—' : _jour(x.dateEcheance!)}'
            '${x.statut == null ? '' : ' · ${x.statut}'}',
        pastille: (x) => x.id,
        correspond: (x, recherche) =>
            _normaliser(x.contrepartie).contains(recherche) ||
            x.id.toLowerCase().contains(recherche),
        choisir: (x) {
          _credit = x;
          _selection = x.contrepartieDerive;
          // L'échéance d'une couverture suit d'ordinaire celle du crédit.
          if (x.dateEcheance != null) _echeance = x.dateEcheance!;
        },
        effacer: () {
          _credit = null;
          _selection = null;
        },
        indice: 'Rechercher par client ou identifiant du crédit',
        indiceVide: 'Aucun crédit dans le portefeuille',
        messageRequis: 'Choisissez le crédit couvert.',
      );

  Widget _rechercheObligation(DashColors c) => _recherche<ObligationDetenue>(
        c,
        cle: DeriveFormulaireCles.obligation,
        elements: widget.sousJacents.obligations,
        selection: _obligation,
        libelle: (x) => x.libelle,
        titre: (x) => x.emetteur,
        detail: (x) =>
            'échéance ${x.dateEcheance == null ? '—' : _jour(x.dateEcheance!)}'
            ' · coupon ${AppFormatters.decimalNumber(x.tauxCouponPct)} %'
            ' · ${x.devise}',
        pastille: (x) => x.isin,
        correspond: (x, recherche) =>
            x.isin.toLowerCase().contains(recherche) ||
            _normaliser(x.emetteur).contains(recherche),
        choisir: (x) {
          _obligation = x;
          if (x.dateEcheance != null) _echeance = x.dateEcheance!;
        },
        effacer: () => _obligation = null,
        indice: 'Rechercher par ISIN ou émetteur',
        indiceVide: 'Aucune obligation dans le portefeuille de marché',
        messageRequis: "Choisissez l'obligation.",
      );

  Widget _rechercheAction(DashColors c) => _recherche<ActionDetenue>(
        c,
        cle: DeriveFormulaireCles.action,
        elements: widget.sousJacents.actions,
        selection: _action,
        libelle: (x) => x.libelle,
        titre: (x) => x.libelle,
        detail: (x) =>
            '${x.secteur ?? 'Secteur inconnu'} · '
            '${AppFormatters.integer(x.quantite)} titres',
        pastille: (x) => x.ticker == x.libelle ? null : x.ticker,
        correspond: (x, recherche) =>
            _normaliser(x.libelle).contains(recherche) ||
            x.ticker.toLowerCase().contains(recherche),
        choisir: (x) => _action = x,
        effacer: () => _action = null,
        indice: 'Rechercher par nom ou code',
        indiceVide: 'Aucune action dans le portefeuille de marché',
        messageRequis: "Choisissez l'action.",
      );

  /// Un champ de recherche dans une liste du portefeuille.
  ///
  /// Retoucher le texte après un choix l'annule : le contrat ne doit pas
  /// partir rattaché à un élément dont le nom n'est plus affiché.
  Widget _recherche<T extends Object>(
    DashColors c, {
    required Key cle,
    required List<T> elements,
    required T? selection,
    required String Function(T) libelle,
    required String Function(T) titre,
    required String Function(T) detail,
    required String? Function(T) pastille,
    required bool Function(T, String) correspond,
    required void Function(T) choisir,
    required VoidCallback effacer,
    required String indice,
    required String indiceVide,
    required String messageRequis,
  }) {
    return Autocomplete<T>(
      initialValue:
          TextEditingValue(text: selection == null ? '' : libelle(selection)),
      displayStringForOption: libelle,
      optionsBuilder: (valeur) {
        final recherche = _normaliser(valeur.text.trim());
        final trouves = recherche.isEmpty
            ? elements
            : elements.where((element) => correspond(element, recherche));
        return trouves.take(_suggestionsMax);
      },
      onSelected: (element) => setState(() => choisir(element)),
      fieldViewBuilder: (context, controleur, focus, soumettre) {
        return TextFormField(
          key: cle,
          controller: controleur,
          focusNode: focus,
          style: _style(c),
          decoration: _decoration(
            c,
            indice: elements.isEmpty ? indiceVide : indice,
            prefixe: Icon(Icons.search_rounded, size: 18, color: c.muted),
          ),
          onChanged: (texte) {
            if (selection != null && texte != libelle(selection)) {
              setState(effacer);
            }
          },
          validator: (_) => selection == null ? messageRequis : null,
        );
      },
      optionsViewBuilder: (context, choisirOption, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            color: c.surface,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320, maxWidth: 580),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, index) => Divider(
                    height: 1, thickness: Dash.hairline, color: c.divider),
                itemBuilder: (context, index) {
                  final element = options.elementAt(index);
                  final code = pastille(element);
                  return InkWell(
                    onTap: () => choisirOption(element),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  titre(element),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: c.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  detail(element),
                                  overflow: TextOverflow.ellipsis,
                                  style: DashText.caption(c),
                                ),
                              ],
                            ),
                          ),
                          if (code != null) ...[
                            const SizedBox(width: 10),
                            _puce(c, code),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _contenuContrat(DashColors c) {
    final imposee = _onglet.natureImposee;
    return [
      _champ(
        c,
        libelle: 'Nature du sous-jacent',
        aide: imposee == null
            ? 'Décide du bloc de l\'EP11, et donc de la pondération.'
            : 'Fixée par le sous-jacent : un dérivé sur '
                '${_onglet == TypeSousJacent.obligation ? 'une obligation' : 'une action'}'
                ' porte sur « ${imposee.label} ».',
        child: DropdownButtonFormField<NatureDerive>(
          key: DeriveFormulaireCles.nature,
          initialValue: _nature,
          isExpanded: true,
          style: _style(c),
          decoration: _decoration(c),
          disabledHint: Text(_nature.label, style: _style(c)),
          items: [
            for (final nature in NatureDerive.values)
              DropdownMenuItem(
                value: nature,
                child: Text(nature.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: imposee != null
              ? null
              : (valeur) => setState(() => _appliquerNature(valeur ?? _nature)),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _champ(
              c,
              libelle: 'Type de contrat',
              facultatif: true,
              // La liste dépend de la nature : sa clé aussi, pour que le
              // champ se reconstruise quand la nature change. Sans cela, il
              // garderait une valeur absente de ses nouveaux choix.
              child: KeyedSubtree(
                key: DeriveFormulaireCles.typeContrat,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey<String>('derive-type-${_nature.wire}'),
                  initialValue: _typeContrat,
                  isExpanded: true,
                  style: _style(c),
                  decoration: _decoration(c),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child:
                          Text('Non précisé', style: TextStyle(color: c.faint)),
                    ),
                    for (final type in _typesProposes)
                      DropdownMenuItem<String?>(
                        value: type,
                        child: Text(type, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (valeur) => setState(() => _typeContrat = valeur),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 112,
            child: _champ(
              c,
              libelle: 'Devise',
              // Seules les devises que le serveur sait convertir : une autre
              // passerait au taux de repli 1,0, comme du franc.
              child: DropdownButtonFormField<String>(
                key: DeriveFormulaireCles.devise,
                initialValue: _devise,
                isExpanded: true,
                style: _style(c).copyWith(
                    fontWeight: FontWeight.w600, letterSpacing: 0.6),
                decoration: _decoration(c),
                items: [
                  for (final devise in _devisesProposees)
                    DropdownMenuItem(value: devise, child: Text(devise)),
                ],
                onChanged: (valeur) =>
                    setState(() => _devise = valeur ?? _devise),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _contenuMontants(DashColors c) => [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _champ(
                c,
                code: '(b)',
                libelle: 'Montant notionnel',
                child: _champMontant(
                    c, DeriveFormulaireCles.notionnel, _notionnel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _champ(
                c,
                code: '(a)',
                libelle: 'Coût de remplacement',
                child: _champMontant(
                    c, DeriveFormulaireCles.cout, _coutRemplacement),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Le coût de remplacement est la valeur de marché du contrat quand '
          'elle est en faveur de l\'établissement ; zéro sinon. Les montants '
          'se saisissent en unités de la devise.',
          style: DashText.caption(c).copyWith(height: 1.4),
        ),
      ];

  List<Widget> _contenuEcheance(DashColors c) => [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _champ(
                c,
                libelle: 'Échéance',
                child: _champDate(
                    c, _echeance, () => _choisirDate(echeance: true)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _champ(
                c,
                libelle: 'Date de conclusion',
                facultatif: true,
                child: _champDate(
                    c, _conclusion, () => _choisirDate(echeance: false)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _dureeResiduelle(c),
      ];

  List<Widget> _contenuCommentaire(DashColors c) => [
        TextFormField(
          key: DeriveFormulaireCles.commentaire,
          controller: _commentaire,
          minLines: 2,
          maxLines: 3,
          style: _style(c),
          decoration: _decoration(c,
              indice: 'Référence interne, conditions particulières… '
                  '(facultatif)'),
        ),
      ];

  Widget _section(DashColors c, String titre, List<Widget> contenu) {
    return DashPanel(
      title: titre,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: contenu,
      ),
    );
  }

  /// Un champ : son libellé au-dessus, en entier, jamais tronqué dans la case.
  Widget _champ(
    DashColors c, {
    required String libelle,
    String? code,
    String? aide,
    bool facultatif = false,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (code != null) ...[_puce(c, code), const SizedBox(width: 6)],
            Flexible(
              child: Text(
                libelle,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
            ),
            if (facultatif) ...[
              const SizedBox(width: 6),
              Text('facultatif', style: DashText.caption(c)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        child,
        if (aide != null) ...[
          const SizedBox(height: 5),
          Text(aide, style: DashText.caption(c).copyWith(height: 1.35)),
        ],
      ],
    );
  }

  TextStyle _style(DashColors c) => TextStyle(fontSize: 13, color: c.ink);

  InputDecoration _decoration(
    DashColors c, {
    String? indice,
    Widget? prefixe,
    String? suffixe,
    Widget? suffixeIcone,
  }) {
    OutlineInputBorder bord(Color couleur, [double largeur = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: couleur, width: largeur),
        );
    return InputDecoration(
      isDense: true,
      hintText: indice,
      hintStyle: TextStyle(color: c.faint, fontSize: 13),
      filled: true,
      fillColor: c.surface,
      prefixIcon: prefixe,
      suffixText: suffixe,
      suffixStyle: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: c.faint),
      suffixIcon: suffixeIcone,
      errorMaxLines: 2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: bord(c.border),
      enabledBorder: bord(c.border),
      disabledBorder: bord(c.divider),
      focusedBorder: bord(c.accent, 1.4),
      errorBorder: bord(c.sousMinimum),
      focusedErrorBorder: bord(c.sousMinimum, 1.4),
    );
  }

  Widget _champMontant(
    DashColors c,
    Key cle,
    TextEditingController controleur,
  ) {
    return TextFormField(
      key: cle,
      controller: controleur,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 .,]'))],
      textAlign: TextAlign.right,
      // L'aperçu suit la frappe : sans cela, il faudrait enregistrer pour
      // savoir ce que le contrat déclarera.
      onChanged: (_) => setState(() {}),
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: c.ink,
        fontFeatures: Dash.tabular,
      ),
      decoration: _decoration(c, indice: '0', suffixe: _devise),
    );
  }

  Widget _champDate(DashColors c, DateTime? valeur, VoidCallback surTap) {
    return InkWell(
      onTap: surTap,
      borderRadius: BorderRadius.circular(6),
      child: InputDecorator(
        decoration: _decoration(
          c,
          suffixeIcone:
              Icon(Icons.calendar_today_rounded, size: 16, color: c.muted),
        ),
        child: Text(
          valeur == null ? 'Non renseignée' : _jour(valeur),
          style: TextStyle(
            fontSize: 13,
            color: valeur == null ? c.faint : c.ink,
            fontFeatures: Dash.tabular,
          ),
        ),
      ),
    );
  }

  /// La tranche se déduit de l'échéance : on la montre plutôt que de la
  /// demander, parce qu'elle change avec le temps.
  Widget _dureeResiduelle(DashColors c) {
    final ligne = _ligne;
    final duree = _tranche.label.replaceFirst('Durée ', '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 15, color: c.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Durée résiduelle aujourd\'hui : $duree'
              '${ligne == null ? '' : ' — ligne ${ligne.code} de l\'EP11'}',
              style: TextStyle(fontSize: 11.5, color: c.ink),
            ),
          ),
        ],
      ),
    );
  }

  // ── Les fiches ───────────────────────────────────────────────────────────

  Widget _cadreFiche(DashColors c, Key cle, List<Widget> contenu) {
    return Container(
      key: cle,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contenu,
      ),
    );
  }

  Widget _enteteFiche(DashColors c, String nom, String? code) {
    return Row(
      children: [
        Expanded(
          child: Text(
            nom,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: c.ink),
          ),
        ),
        if (code != null) ...[const SizedBox(width: 8), _puce(c, code)],
      ],
    );
  }

  Widget _mention(DashColors c, String texte, {Color? teinte}) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          texte,
          style: TextStyle(
              fontSize: 11, height: 1.35, color: teinte ?? c.muted),
        ),
      );

  /// Ce que la fiche de la contrepartie apporte : la colonne et la notation.
  Widget _ficheContrepartie(DashColors c, ContrepartieDerive contrepartie) {
    final repli = contrepartie.horsEp11;
    return _cadreFiche(c, DeriveFormulaireCles.fiche, [
      _enteteFiche(c, contrepartie.nom, contrepartie.id),
      const SizedBox(height: 10),
      Wrap(
        spacing: 22,
        runSpacing: 8,
        children: [
          _attribut(c, 'Catégorie prudentielle',
              contrepartie.categoriePrudentielle ?? 'Inconnue'),
          _attribut(
            c,
            'Colonne EP11',
            repli
                ? '${contrepartie.categorieEp11.label} (repli)'
                : contrepartie.categorieEp11.label,
            teinte: repli ? c.sousCible : c.accent,
          ),
          _attribut(c, 'Notation', contrepartie.notation ?? 'Non notée'),
          if (contrepartie.pays != null)
            _attribut(c, 'Pays', contrepartie.pays!),
        ],
      ),
      if (repli)
        _mention(
          c,
          'Sa catégorie n\'a pas de colonne sur l\'EP11 : le contrat se range '
          'sous « Entreprises », repli du formulaire.',
          teinte: c.sousCible,
        ),
    ]);
  }

  Widget _ficheCredit(DashColors c, CreditCouvrable credit) {
    return _cadreFiche(c, DeriveFormulaireCles.ficheSousJacent, [
      _enteteFiche(c, credit.contrepartie, credit.id),
      const SizedBox(height: 10),
      Wrap(
        spacing: 22,
        runSpacing: 8,
        children: [
          _attribut(c, 'Montant', _montantDevise(credit.montantBrut, credit.devise)),
          _attribut(c, 'Échéance',
              credit.dateEcheance == null ? '—' : _jour(credit.dateEcheance!)),
          if (credit.statut != null) _attribut(c, 'Statut', credit.statut!),
          _attribut(
            c,
            'Colonne EP11',
            credit.horsEp11
                ? '${credit.categorieEp11.label} (repli)'
                : credit.categorieEp11.label,
            teinte: credit.horsEp11 ? c.sousCible : c.accent,
          ),
          _attribut(c, 'Notation', credit.notation ?? 'Non notée'),
        ],
      ),
      _mention(c,
          'Contrepartie du contrat : le client lui-même, qui signe sa couverture.'),
    ]);
  }

  Widget _ficheObligation(DashColors c, ObligationDetenue obligation) {
    return _cadreFiche(c, DeriveFormulaireCles.ficheSousJacent, [
      _enteteFiche(c, obligation.emetteur, obligation.isin),
      const SizedBox(height: 10),
      Wrap(
        spacing: 22,
        runSpacing: 8,
        children: [
          _attribut(c, 'Échéance',
              obligation.dateEcheance == null ? '—' : _jour(obligation.dateEcheance!)),
          _attribut(c, 'Coupon',
              '${AppFormatters.decimalNumber(obligation.tauxCouponPct)} %'),
          _attribut(c, 'Encours nominal',
              _montantDevise(obligation.encoursNominal, obligation.devise)),
        ],
      ),
      _mention(c,
          'L\'émetteur n\'est pas la contrepartie du dérivé : indiquez ci-dessous '
          'qui a signé le contrat.'),
    ]);
  }

  Widget _ficheAction(DashColors c, ActionDetenue action) {
    return _cadreFiche(c, DeriveFormulaireCles.ficheSousJacent, [
      _enteteFiche(
          c, action.libelle, action.ticker == action.libelle ? null : action.ticker),
      const SizedBox(height: 10),
      Wrap(
        spacing: 22,
        runSpacing: 8,
        children: [
          _attribut(c, 'Secteur', action.secteur ?? 'Inconnu'),
          _attribut(c, 'Quantité détenue',
              '${AppFormatters.integer(action.quantite)} titres'),
        ],
      ),
      _mention(c,
          'La société n\'est pas la contrepartie du dérivé : indiquez ci-dessous '
          'qui a signé le contrat.'),
    ]);
  }

  Widget _attribut(DashColors c, String titre, String valeur, {Color? teinte}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(titre.toUpperCase(),
            style: DashText.eyebrow(c).copyWith(fontSize: 9.5)),
        const SizedBox(height: 3),
        Text(
          valeur,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: teinte ?? c.ink,
          ),
        ),
      ],
    );
  }

  // ── L'aperçu ─────────────────────────────────────────────────────────────

  /// Ce que le contrat déclarera sur l'EP11, à chaque frappe.
  Widget _apercu(DashColors c) {
    final ligne = _ligne;
    final notionnel = _nombre(_notionnel);
    final cout = _nombre(_coutRemplacement);
    final ponderation = ligne?.ponderation;
    final pondere = ponderation == null ? null : notionnel * ponderation;
    final exposition = cout + (pondere ?? 0);
    final (_, libelleSousJacent) = _sousJacentChoisi;

    return KeyedSubtree(
      key: DeriveFormulaireCles.apercu,
      child: DashPanel(
        title: 'CE QUE LE CONTRAT DÉCLARERA',
        unit: AppFormatters.libelleUnite(_devise == 'XOF' ? 'FCFA' : _devise),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ligneApercu(
              c,
              'Sous-jacent',
              libelleSousJacent ??
                  (_onglet == TypeSousJacent.autre ? 'Aucun' : 'À choisir'),
              attenue: libelleSousJacent == null,
            ),
            const SizedBox(height: 10),
            _ligneApercu(
              c,
              'Ligne de l\'EP11',
              ligne?.code ?? '—',
              detail: '${_nature.label}\n${_tranche.label}',
              puce: true,
            ),
            const SizedBox(height: 10),
            _ligneApercu(
              c,
              'Colonne de ventilation',
              _selection == null
                  ? 'À choisir'
                  : _selection!.horsEp11
                      ? '${_selection!.categorieEp11.label} (repli)'
                      : _selection!.categorieEp11.label,
              attenue: _selection == null,
            ),
            _separateur(c),
            _ligneApercu(c, '(a) Coût de remplacement', _montant(cout)),
            const SizedBox(height: 8),
            _ligneApercu(c, '(b) Notionnel', _montant(notionnel)),
            const SizedBox(height: 8),
            _ligneApercu(
              c,
              '(c) Pondération',
              ponderation == null
                  ? 'Lue à l\'export'
                  : '${(ponderation * 100).toStringAsFixed(1)} %',
              attenue: ponderation == null,
            ),
            const SizedBox(height: 8),
            _ligneApercu(c, '(d) = b × c',
                pondere == null ? '—' : _montant(pondere)),
            _separateur(c),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EXPOSITION DÉCLARÉE', style: DashText.eyebrow(c)),
                      const SizedBox(height: 2),
                      Text('(e) = a + d', style: DashText.caption(c)),
                    ],
                  ),
                ),
                Text(
                  exposition == 0 ? '—' : _montant(exposition),
                  style: DashText.hero(c, size: 22, color: c.accent),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Aperçu indicatif. La pondération est celle que la BCEAO imprime '
              'sur le formulaire ; le calcul qui fait foi est celui de '
              'l\'export.'
              '${_devise == 'XOF' ? '' : ' Les montants y seront convertis en FCFA.'}',
              style: DashText.caption(c).copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ligneApercu(
    DashColors c,
    String libelle,
    String valeur, {
    String? detail,
    bool puce = false,
    bool attenue = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(libelle, style: TextStyle(fontSize: 12, color: c.muted)),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(detail, style: DashText.caption(c).copyWith(height: 1.35)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        if (puce && valeur != '—')
          _puce(c, valeur, teinte: c.accent)
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              valeur,
              textAlign: TextAlign.right,
              style: DashText.value(
                c,
                color: attenue ? c.faint : c.ink,
                weight: attenue ? FontWeight.w500 : FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _separateur(DashColors c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Divider(height: 1, thickness: Dash.hairline, color: c.divider),
      );

  /// Les montants se lisent dans l'unité choisie en haut de l'écran.
  String _montant(double valeur) =>
      valeur == 0 ? '—' : AppFormatters.montant(valeur);

  String _montantDevise(double valeur, String devise) =>
      '${AppFormatters.montant(valeur)} $devise';

  /// Une pastille : code DISPRU, identifiant, ISIN ou ticker.
  Widget _puce(DashColors c, String texte, {Color? teinte}) {
    return Container(
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
    );
  }

  static String _jour(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
