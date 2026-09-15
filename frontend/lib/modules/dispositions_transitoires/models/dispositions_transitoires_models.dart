/// Dispositions transitoires sur les fonds propres, et l'état EP04.
///
/// Bâle III a rendu inadmissibles certains éléments de fonds propres au
/// 1er janvier 2018, et les retire progressivement : un taux, appliqué au stock
/// de l'époque, dit combien on peut encore en compter, et le montant encore en
/// circulation le plafonne.
///
/// Quatre lignes de l'EP04 retombent dans l'EP03 — FPI07 en CET1, FPI25 en AT1,
/// FPI33 et FPI34 en T2. Sans elles, les fonds propres déclarés ignorent ce que
/// le dispositif transitoire laisse encore compter.
library;

/// Les quatorze montants que l'EP04 demande.
///
/// Le capital social libéré n'en fait pas partie : l'EP03 le déclare déjà, et
/// l'export le reporte. Le taux de retrait non plus — la BCEAO l'imprime sur le
/// formulaire.
class DispositionsTransitoires {
  const DispositionsTransitoires({
    required this.exercice,
    this.partCapitalNonAdmissible = 0.0,
    this.provisionsReglementees = 0.0,
    this.fondsAffectes = 0.0,
    this.cet1EnCirculation = 0.0,
    this.cet1EligibleAt1 = 0.0,
    this.cet1EligibleT2Autres = 0.0,
    this.cet1EligibleT2Provisions = 0.0,
    this.cet1EligibleT2FondsAffectes = 0.0,
    this.cet1Exclu = 0.0,
    this.dettesSubordonnees2018 = 0.0,
    this.partDettesNonAdmissible = 0.0,
    this.ecartsReevaluation = 0.0,
    this.autresT2NonAdmissibles = 0.0,
    this.t2EnCirculation = 0.0,
    this.commentaire,
  });

  final int exercice;

  // Bloc A — éléments de CET1 non admissibles.
  /// (c) DT002.
  final double partCapitalNonAdmissible;

  /// (d) DT003.
  final double provisionsReglementees;

  /// (e) DT004.
  final double fondsAffectes;

  /// (h) DT007 — plafonne la reconnaissance avec (g) : FPI07 = min(g, h).
  final double cet1EnCirculation;

  /// FPI25 — reclassé en fonds propres de base additionnels.
  final double cet1EligibleAt1;

  /// FPI33 — reclassé en T2, autres instruments.
  final double cet1EligibleT2Autres;

  /// FPI35 — reclassé en T2, provisions réglementées.
  final double cet1EligibleT2Provisions;

  /// FPI36 — reclassé en T2, fonds affectés.
  final double cet1EligibleT2FondsAffectes;

  /// DT009 — exclu des fonds propres.
  final double cet1Exclu;

  // Bloc B — éléments de T2 non admissibles.
  /// (j) DT010.
  final double dettesSubordonnees2018;

  /// (k) DT011.
  final double partDettesNonAdmissible;

  /// (l) DT012.
  final double ecartsReevaluation;

  /// (m) DT013.
  final double autresT2NonAdmissibles;

  /// (p) DT016 — plafonne avec (o) : FPI34 = min(o, p).
  final double t2EnCirculation;

  final String? commentaire;

  static double _d(Object? v) => (v as num?)?.toDouble() ?? 0.0;

  factory DispositionsTransitoires.fromJson(Map<String, dynamic> json) =>
      DispositionsTransitoires(
        exercice: (json['exercice'] as num).toInt(),
        partCapitalNonAdmissible: _d(json['part_capital_non_admissible']),
        provisionsReglementees: _d(json['provisions_reglementees']),
        fondsAffectes: _d(json['fonds_affectes']),
        cet1EnCirculation: _d(json['cet1_en_circulation']),
        cet1EligibleAt1: _d(json['cet1_eligible_at1']),
        cet1EligibleT2Autres: _d(json['cet1_eligible_t2_autres']),
        cet1EligibleT2Provisions: _d(json['cet1_eligible_t2_provisions']),
        cet1EligibleT2FondsAffectes:
            _d(json['cet1_eligible_t2_fonds_affectes']),
        cet1Exclu: _d(json['cet1_exclu']),
        dettesSubordonnees2018: _d(json['dettes_subordonnees_2018']),
        partDettesNonAdmissible: _d(json['part_dettes_non_admissible']),
        ecartsReevaluation: _d(json['ecarts_reevaluation']),
        autresT2NonAdmissibles: _d(json['autres_t2_non_admissibles']),
        t2EnCirculation: _d(json['t2_en_circulation']),
        commentaire: json['commentaire'] as String?,
      );

  Map<String, dynamic> toPayload() => {
        'exercice': exercice,
        'part_capital_non_admissible': partCapitalNonAdmissible,
        'provisions_reglementees': provisionsReglementees,
        'fonds_affectes': fondsAffectes,
        'cet1_en_circulation': cet1EnCirculation,
        'cet1_eligible_at1': cet1EligibleAt1,
        'cet1_eligible_t2_autres': cet1EligibleT2Autres,
        'cet1_eligible_t2_provisions': cet1EligibleT2Provisions,
        'cet1_eligible_t2_fonds_affectes': cet1EligibleT2FondsAffectes,
        'cet1_exclu': cet1Exclu,
        'dettes_subordonnees_2018': dettesSubordonnees2018,
        'part_dettes_non_admissible': partDettesNonAdmissible,
        'ecarts_reevaluation': ecartsReevaluation,
        'autres_t2_non_admissibles': autresT2NonAdmissibles,
        't2_en_circulation': t2EnCirculation,
        'commentaire': commentaire,
      };
}

/// Une ligne de l'EP04, avec son montant et son origine.
class LigneEp04 {
  const LigneEp04({
    required this.code,
    required this.libelle,
    required this.formule,
    required this.montant,
    required this.origine,
    required this.bloc,
  });

  final String code;
  final String libelle;

  /// La formule que le formulaire imprime en regard, quand il en imprime une.
  final String formule;
  final double montant;

  /// `saisie`, `reporte` (d'un autre état) ou `calcule`.
  ///
  /// Un déclarant qui cherche à corriger (i) doit comprendre qu'il ne se
  /// saisit pas, et que ce sont (g) et (h) qu'il faut reprendre.
  final String origine;
  final String bloc;

  bool get estCalculee => origine == 'calcule';
  bool get estReportee => origine == 'reporte';

  factory LigneEp04.fromJson(Map<String, dynamic> json) => LigneEp04(
        code: (json['code'] ?? '') as String,
        libelle: (json['libelle'] ?? '') as String,
        formule: (json['formule'] ?? '') as String,
        montant: (json['montant'] as num?)?.toDouble() ?? 0.0,
        origine: (json['origine'] ?? 'saisie') as String,
        bloc: (json['bloc'] ?? '') as String,
      );
}

/// L'EP04 tel que la déclaration le portera.
class SyntheseEp04 {
  const SyntheseEp04({
    this.exercice,
    required this.tauxDeRetrait,
    required this.lignes,
    required this.reportEp03,
    required this.renseigne,
    required this.alertes,
  });

  final int? exercice;

  /// Le taux (a), relevé sur le formulaire — jamais choisi par l'application.
  final double tauxDeRetrait;
  final List<LigneEp04> lignes;

  /// Les quatre montants qui retombent dans l'EP03.
  final Map<String, double> reportEp03;
  final bool renseigne;
  final List<String> alertes;

  factory SyntheseEp04.fromJson(Map<String, dynamic> json) => SyntheseEp04(
        exercice: (json['exercice'] as num?)?.toInt(),
        tauxDeRetrait: (json['taux_de_retrait'] as num?)?.toDouble() ?? 0.0,
        lignes: ((json['lignes'] as List<dynamic>?) ?? const [])
            .map((item) => LigneEp04.fromJson(item as Map<String, dynamic>))
            .toList(),
        reportEp03:
            ((json['report_ep03'] as Map<dynamic, dynamic>?) ?? const {}).map(
          (cle, valeur) =>
              MapEntry(cle.toString(), (valeur as num?)?.toDouble() ?? 0.0),
        ),
        renseigne: (json['renseigne'] as bool?) ?? false,
        alertes: ((json['alertes'] as List<dynamic>?) ?? const [])
            .map((item) => item.toString())
            .toList(),
      );
}
