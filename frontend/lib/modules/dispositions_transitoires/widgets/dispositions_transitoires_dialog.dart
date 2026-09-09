import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/utils/formatters.dart';
import '../../dashboard/widgets/dashboard_design.dart';
import '../models/dispositions_transitoires_models.dart';

/// Saisie des dispositions transitoires sur les fonds propres (EP04).
///
/// Bâle III a rendu inadmissibles certains éléments de fonds propres au
/// 1er janvier 2018 et les retire par paliers. Quatorze montants suffisent à
/// l'état ; sept lignes s'en déduisent.
///
/// Le parti de l'écran : **le calcul se lit sous la saisie qui l'alimente**.
/// Les trois montants du stock sont suivis de leur total, puis du plafond, puis
/// du montant reconnu — chacun avec la formule que le formulaire imprime. Une
/// valeur ne se vérifie qu'en voyant ce qu'elle produit, et renvoyer le
/// déclarant à un tableau posé plus loin lui fait faire l'aller-retour à chaque
/// chiffre.
///
/// Deux choses ne se saisissent pas, et l'écran le dit plutôt que de les
/// présenter comme des cases oubliées : le capital social libéré, reporté de
/// l'EP03, et le taux de retrait, imprimé par la BCEAO sur le formulaire.
class DispositionsTransitoiresDialog extends StatefulWidget {
  const DispositionsTransitoiresDialog({
    super.key,
    required this.api,
    required this.exercice,
  });

  final RwaApiService api;

  /// Exercice visé. C'est celui des fonds propres déclarés : les dispositions
  /// se rattachent au même millésime, le montant encore en circulation
  /// changeant d'une année à l'autre.
  final int exercice;

  /// Retourne `true` si le contenu a changé, pour rafraîchir l'appelant.
  static Future<bool> show(
    BuildContext context,
    RwaApiService api,
    int exercice,
  ) async {
    final modifie = await showDialog<bool>(
      context: context,
      builder: (_) => DispositionsTransitoiresDialog(
        api: api,
        exercice: exercice,
      ),
    );
    return modifie ?? false;
  }

  @override
  State<DispositionsTransitoiresDialog> createState() =>
      _DispositionsTransitoiresDialogState();
}

/// Un champ de saisie, tel que le formulaire le nomme.
typedef _Champ = ({String cle, String code, String libelle, String? aide});

/// La saisie et l'état qu'elle produit, chargés ensemble.
typedef _Donnees = ({DispositionsTransitoires? saisie, SyntheseEp04 synthese});

class _DispositionsTransitoiresDialogState
    extends State<DispositionsTransitoiresDialog> {
  late Future<_Donnees> _future;
  final _controleurs = <String, TextEditingController>{};
  bool _modifie = false;
  bool _enregistrement = false;

  /// L'état tel qu'il partira, recalculé par le serveur après chaque
  /// enregistrement. Les formules vivent au même endroit que le formulaire ;
  /// les refaire ici finirait par en donner d'autres.
  SyntheseEp04? _etat;

  // ── Le stock de CET1 non admissible, et ce qu'il en reste ────────────────
  static const _stockCet1 = <_Champ>[
    (
      cle: 'part_capital_non_admissible',
      code: 'DT002',
      libelle: 'Part du capital social non admissible',
      aide: 'Primes d\'émission comprises',
    ),
    (
      cle: 'provisions_reglementees',
      code: 'DT003',
      libelle: 'Provisions réglementées',
      aide: null,
    ),
    (
      cle: 'fonds_affectes',
      code: 'DT004',
      libelle: 'Fonds affectés',
      aide: null,
    ),
  ];

  static const _circulationCet1 = <_Champ>[
    (
      cle: 'cet1_en_circulation',
      code: 'DT007',
      libelle: 'Montant réel encore en circulation',
      aide: 'À la date de déclaration',
    ),
  ];

  /// Ce que deviennent les éléments sortis du CET1.
  static const _devenirCet1 = <_Champ>[
    (
      cle: 'cet1_eligible_at1',
      code: 'FPI25',
      libelle: 'Reclassé en AT1',
      aide: 'Fonds propres de base additionnels',
    ),
    (
      cle: 'cet1_eligible_t2_autres',
      code: 'FPI33',
      libelle: 'Reclassé en T2 — autres instruments',
      aide: null,
    ),
    (
      cle: 'cet1_eligible_t2_provisions',
      code: 'FPI35',
      libelle: 'Reclassé en T2 — provisions réglementées',
      aide: null,
    ),
    (
      cle: 'cet1_eligible_t2_fonds_affectes',
      code: 'FPI36',
      libelle: 'Reclassé en T2 — fonds affectés',
      aide: null,
    ),
    (
      cle: 'cet1_exclu',
      code: 'DT009',
      libelle: 'Exclu des fonds propres',
      aide: null,
    ),
  ];

  // ── Le stock de T2 non admissible ────────────────────────────────────────
  static const _stockT2 = <_Champ>[
    (
      cle: 'part_dettes_non_admissible',
      code: 'DT011',
      libelle: 'Part des dettes subordonnées non admissible',
      aide: null,
    ),
    (
      cle: 'ecarts_reevaluation',
      code: 'DT012',
      libelle: 'Écarts de réévaluation',
      aide: null,
    ),
    (
      cle: 'autres_t2_non_admissibles',
      code: 'DT013',
      libelle: 'Autres éléments de T2 non admissibles',
      aide: null,
    ),
  ];

  static const _contexteT2 = <_Champ>[
    (
      cle: 'dettes_subordonnees_2018',
      code: 'DT010',
      libelle: 'Dettes subordonnées en circulation au 1er janvier 2018',
      aide: 'Après amortissement, s\'il y a lieu',
    ),
  ];

  static const _circulationT2 = <_Champ>[
    (
      cle: 't2_en_circulation',
      code: 'DT016',
      libelle: 'Montant réel encore en circulation',
      aide: 'Après amortissement jusqu\'à la date de déclaration',
    ),
  ];

  static List<_Champ> get _tousLesChamps => [
        ..._stockCet1,
        ..._circulationCet1,
        ..._devenirCet1,
        ..._contexteT2,
        ..._stockT2,
        ..._circulationT2,
      ];

  @override
  void initState() {
    super.initState();
    for (final champ in _tousLesChamps) {
      _controleurs[champ.cle] = TextEditingController();
    }
    _future = _charger();
  }

  @override
  void dispose() {
    for (final controleur in _controleurs.values) {
      controleur.dispose();
    }
    super.dispose();
  }

  Future<_Donnees> _charger() async {
    final saisie = widget.api.fetchDispositionsTransitoires(widget.exercice);
    final synthese = widget.api.fetchSyntheseEp04(widget.exercice);
    final donnees = (saisie: await saisie, synthese: await synthese);
    _remplirLesChamps(donnees.saisie);
    _etat = donnees.synthese;
    return donnees;
  }

  void _remplirLesChamps(DispositionsTransitoires? saisie) {
    if (saisie == null) return;
    final valeurs = saisie.toPayload();
    for (final champ in _tousLesChamps) {
      final valeur = valeurs[champ.cle];
      if (valeur is num && valeur != 0) {
        _controleurs[champ.cle]!.text = valeur.toStringAsFixed(0);
      }
    }
  }

  double _nombre(String cle) {
    final texte = _controleurs[cle]!
        .text
        .trim()
        .replaceAll(' ', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    return double.tryParse(texte) ?? 0.0;
  }

  /// Le calcul provisoire, le temps que le serveur rende le sien.
  ///
  /// Il ne remplace pas l'état : il le devance, pour que le total suive la
  /// frappe. Le formulaire fait foi, et c'est lui qu'on réaffiche après
  /// enregistrement.
  double get _totalCet1 =>
      _stockCet1.fold(0.0, (somme, champ) => somme + _nombre(champ.cle));

  double get _totalT2 =>
      _stockT2.fold(0.0, (somme, champ) => somme + _nombre(champ.cle));

  double get _taux => _etat?.tauxDeRetrait ?? 0.0;

  Future<void> _enregistrer() async {
    setState(() => _enregistrement = true);
    try {
      await widget.api.saveDispositionsTransitoires(
        DispositionsTransitoires(
          exercice: widget.exercice,
          partCapitalNonAdmissible: _nombre('part_capital_non_admissible'),
          provisionsReglementees: _nombre('provisions_reglementees'),
          fondsAffectes: _nombre('fonds_affectes'),
          cet1EnCirculation: _nombre('cet1_en_circulation'),
          cet1EligibleAt1: _nombre('cet1_eligible_at1'),
          cet1EligibleT2Autres: _nombre('cet1_eligible_t2_autres'),
          cet1EligibleT2Provisions: _nombre('cet1_eligible_t2_provisions'),
          cet1EligibleT2FondsAffectes:
              _nombre('cet1_eligible_t2_fonds_affectes'),
          cet1Exclu: _nombre('cet1_exclu'),
          dettesSubordonnees2018: _nombre('dettes_subordonnees_2018'),
          partDettesNonAdmissible: _nombre('part_dettes_non_admissible'),
          ecartsReevaluation: _nombre('ecarts_reevaluation'),
          autresT2NonAdmissibles: _nombre('autres_t2_non_admissibles'),
          t2EnCirculation: _nombre('t2_en_circulation'),
        ),
      );
      _modifie = true;
      // Corps entre accolades : une flèche renverrait le Future affecté, que
      // setState refuse.
      setState(() {
        _future = _charger();
      });
      _signaler('Dispositions enregistrées pour l\'exercice ${widget.exercice}.');
    } catch (erreur) {
      _signaler('Enregistrement impossible : $erreur', erreur: true);
    } finally {
      if (mounted) setState(() => _enregistrement = false);
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

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Dialog(
      backgroundColor: c.surfaceAlt,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dash.radius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _entete(c),
            Flexible(
              child: FutureBuilder<_Donnees>(
                future: _future,
                builder: (context, instantane) {
                  if (instantane.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 260,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (instantane.hasError) {
                    return _indisponible(c, instantane.error);
                  }
                  return _corps(c, instantane.data!.synthese);
                },
              ),
            ),
            _pied(c),
          ],
        ),
      ),
    );
  }

  // ── En-tête ──────────────────────────────────────────────────────────────

  Widget _entete(DashColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          bottom: BorderSide(color: c.border, width: Dash.hairline),
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Dash.radius),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ÉTAT EP04', style: DashText.eyebrow(c)),
                const SizedBox(height: 6),
                Text(
                  'Dispositions transitoires sur les fonds propres',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 660,
                  child: Text(
                    'Bâle III a rendu inadmissibles certains éléments de fonds '
                    'propres au 1er janvier 2018 et les retire par paliers. '
                    'Quatre lignes de cet état retombent dans l\'EP03 et '
                    'modifient les fonds propres déclarés.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: c.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          _tuileEntete(c, 'EXERCICE', '${widget.exercice}', null),
          const SizedBox(width: 10),
          _tuileEntete(
            c,
            'TAUX DE RETRAIT',
            _taux > 0 ? '${(_taux * 100).toStringAsFixed(0)} %' : '—',
            'Imprimé par la BCEAO',
          ),
        ],
      ),
    );
  }

  Widget _tuileEntete(DashColors c, String titre, String valeur, String? note) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(titre, style: DashText.eyebrow(c)),
          const SizedBox(height: 4),
          Text(valeur, style: DashText.hero(c, size: 20)),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(note, style: DashText.caption(c)),
          ],
        ],
      ),
    );
  }

  // ── Corps ────────────────────────────────────────────────────────────────

  Widget _corps(DashColors c, SyntheseEp04 synthese) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final alerte in synthese.alertes) ...[
            _bandeau(c, alerte),
            const SizedBox(height: 12),
          ],
          _reportEp03(c, synthese),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _blocCet1(c)),
              const SizedBox(width: 16),
              Expanded(child: _blocT2(c)),
            ],
          ),
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
            child: Text(
              message,
              style: TextStyle(fontSize: 12, height: 1.45, color: c.ink),
            ),
          ),
        ],
      ),
    );
  }

  /// Ce que l'état produit, en quatre chiffres.
  ///
  /// Placé en tête et non en pied : c'est la conséquence de toute la saisie, et
  /// le déclarant vient d'abord vérifier cela.
  Widget _reportEp03(DashColors c, SyntheseEp04 synthese) {
    const postes = <(String, String, String)>[
      ('FPI07', 'Conservé en CET1', '(i) = min(g, h)'),
      ('FPI25', 'Reclassé en AT1', ''),
      ('FPI33', 'Reclassé en T2', ''),
      ('FPI34', 'Conservé en T2', '(q) = min(o, p)'),
    ];
    return DashPanel(
      title: 'CE QUE L\'EP03 REPREND',
      unit: 'En millions de FCFA',
      child: Row(
        children: [
          for (final (code, libelle, formule) in postes) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _puce(c, code),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(libelle,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: c.muted)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    _montant(synthese.reportEp03[code] ?? 0.0),
                    style: DashText.hero(c, size: 22),
                  ),
                  if (formule.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(formule, style: DashText.caption(c)),
                  ],
                ],
              ),
            ),
            if (code != postes.last.$1)
              Container(
                width: Dash.hairline,
                height: 58,
                color: c.divider,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
          ],
        ],
      ),
    );
  }

  // ── Les deux blocs de saisie ─────────────────────────────────────────────

  Widget _blocCet1(DashColors c) {
    final total = _totalCet1;
    final plafond = total * _taux;
    final circulation = _nombre('cet1_en_circulation');
    final reconnu = plafond < circulation ? plafond : circulation;

    return DashPanel(
      title: 'A · ÉLÉMENTS DE CET1 NON ADMISSIBLES',
      unit: 'Saisie en FCFA · calculs en millions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sousTitre(c, 'Stock au 1er janvier 2018'),
          for (final champ in _stockCet1) _champSaisi(c, champ),
          _ligneCalculee(c, 'DT005', 'Total du stock', '(f) = c + d + e', total),
          _ligneCalculee(c, 'DT006', 'Maximum encore admissible',
              '(g) = f × ${(_taux * 100).toStringAsFixed(0)} %', plafond),
          const SizedBox(height: 14),
          _sousTitre(c, 'Aujourd\'hui'),
          for (final champ in _circulationCet1) _champSaisi(c, champ),
          _ligneCalculee(c, 'FPI07', 'Conservé dans le CET1',
              '(i) = min(g, h)', reconnu,
              accent: true),
          const SizedBox(height: 14),
          _sousTitre(c, 'Ce que devient le reste'),
          for (final champ in _devenirCet1) _champSaisi(c, champ),
        ],
      ),
    );
  }

  Widget _blocT2(DashColors c) {
    final total = _totalT2;
    final plafond = total * _taux;
    final circulation = _nombre('t2_en_circulation');
    final reconnu = plafond < circulation ? plafond : circulation;

    return DashPanel(
      title: 'B · ÉLÉMENTS DE T2 NON ADMISSIBLES',
      unit: 'Saisie en FCFA · calculs en millions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sousTitre(c, 'Pour mémoire'),
          for (final champ in _contexteT2) _champSaisi(c, champ),
          const SizedBox(height: 14),
          _sousTitre(c, 'Stock au 1er janvier 2018'),
          for (final champ in _stockT2) _champSaisi(c, champ),
          _ligneCalculee(c, 'DT014', 'Total du stock', '(n) = k + l + m', total),
          _ligneCalculee(c, 'DT015', 'Maximum encore admissible',
              '(o) = n × ${(_taux * 100).toStringAsFixed(0)} %', plafond),
          const SizedBox(height: 14),
          _sousTitre(c, 'Aujourd\'hui'),
          for (final champ in _circulationT2) _champSaisi(c, champ),
          _ligneCalculee(c, 'FPI34', 'Conservé dans le T2',
              '(q) = min(o, p)', reconnu,
              accent: true),
        ],
      ),
    );
  }

  Widget _sousTitre(DashColors c, String texte) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(texte.toUpperCase(), style: DashText.eyebrow(c)),
      );

  /// Un champ : le code en pastille, le libellé lisible en entier, le montant
  /// aligné à droite en chiffres tabulaires.
  Widget _champSaisi(DashColors c, _Champ champ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _puce(c, champ.code),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(champ.libelle,
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: c.ink)),
                if (champ.aide != null)
                  Text(champ.aide!, style: DashText.caption(c)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 178,
            child: TextField(
              controller: _controleurs[champ.cle],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9 .,]')),
              ],
              textAlign: TextAlign.right,
              // Le total suit la frappe : sans cela, il faudrait enregistrer
              // pour savoir si le chiffre qu'on vient de porter tombe juste.
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.ink,
                fontFeatures: Dash.tabular,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                hintStyle: TextStyle(color: c.faint, fontSize: 13),
                // La saisie est en francs, l'état se lit en millions : sans
                // ce rappel, l'écart d'un facteur un million ne se voit qu'à
                // la lecture du classeur.
                suffixText: 'FCFA',
                suffixStyle: TextStyle(fontSize: 9.5, color: c.faint),
                filled: true,
                fillColor: c.surfaceAlt,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide(color: c.border, width: Dash.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide(color: c.border, width: Dash.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide(color: c.accent, width: 1.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Une ligne que le formulaire fait calculer : elle se lit, ne se saisit pas.
  ///
  /// `accent` distingue les deux qui comptent — ce que le CET1 et le T2
  /// conservent réellement, et que l'EP03 reprend.
  Widget _ligneCalculee(
    DashColors c,
    String code,
    String libelle,
    String formule,
    double montant, {
    bool accent = false,
  }) {
    final teinte = accent ? c.accent : c.muted;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent
            ? c.accent.withValues(alpha: 0.07)
            : c.surfaceAlt.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: accent ? c.accent.withValues(alpha: 0.35) : c.divider,
          width: Dash.hairline,
        ),
      ),
      child: Row(
        children: [
          _puce(c, code, teinte: teinte),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(libelle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accent ? c.accent : c.ink,
                    )),
                Text(formule, style: DashText.caption(c)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 178,
            child: Text(
              _montant(montant),
              textAlign: TextAlign.right,
              style: DashText.value(c,
                  color: accent ? c.accent : c.ink, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// Le code DISPRU, en pastille : c'est l'adresse de la case sur le
  /// formulaire, et c'est par elle que le déclarant retrouve sa saisie.
  Widget _puce(DashColors c, String code, {Color? teinte}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: (teinte ?? c.muted).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        code,
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

  /// Les montants se lisent en millions de FCFA.
  ///
  /// C'est l'unité de la déclaration — « tous les montants doivent être
  /// déclarés en millions de franc CFA » (notice, § 2.3) — et c'est donc sous
  /// cette forme que le déclarant les retrouvera sur le classeur transmis.
  /// Onze chiffres alignés ne se lisent pas, et ne se comparent pas non plus à
  /// ce que porte le formulaire.
  String _montant(double valeur) =>
      valeur == 0 ? '—' : AppFormatters.millions(valeur);

  // ── Pied ─────────────────────────────────────────────────────────────────

  Widget _pied(DashColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border, width: Dash.hairline)),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(Dash.radius),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 14, color: c.faint),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Le capital social libéré (FPI01) est reporté de l\'EP03, et le '
              'taux de retrait relevé sur le formulaire : ni l\'un ni l\'autre '
              'ne se saisissent ici.',
              style: DashText.caption(c),
            ),
          ),
          const SizedBox(width: 16),
          TextButton(
            onPressed: () => Navigator.pop(context, _modifie),
            child: const Text('Fermer'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _enregistrement ? null : _enregistrer,
            icon: _enregistrement
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded, size: 16),
            label: const Text('Enregistrer'),
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _indisponible(DashColors c, Object? erreur) {
    return SizedBox(
      height: 260,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 32, color: c.faint),
              const SizedBox(height: 12),
              Text(
                _messageDeChargement(erreur, 'Dispositions indisponibles'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, height: 1.5, color: c.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ce qu'il faut comprendre d'une erreur de chargement.
///
/// « Not Found » ne dit rien à personne : c'est la réponse d'un serveur qui ne
/// connaît pas la route, donc antérieur à son ajout. Le piège est que le script
/// de lancement réutilise un backend déjà en écoute — relancer l'application ne
/// suffit pas, il faut arrêter le processus.
String _messageDeChargement(Object? erreur, String quoi) {
  final texte = '${erreur ?? ''}';
  final routeAbsente = texte.contains('Not Found') || texte.contains('404');
  if (routeAbsente) {
    return '$quoi : le serveur joint ne connaît pas cette route. Il date '
        "d'avant son ajout — arrêtez le backend puis relancez-le, le script "
        'réutilise celui qui écoute déjà.';
  }
  return '$quoi : $texte';
}
