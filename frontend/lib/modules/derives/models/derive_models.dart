/// Registre des instruments dérivés, et l'état EP11 qu'il alimente.
///
/// L'EP11 déclare le risque de contrepartie porté par les dérivés : swaps de
/// taux, change à terme, contrats sur titres de propriété ou sur produits de
/// base. L'application n'en tenait aucune trace, et l'état partait à zéro — ce
/// qui affirme au régulateur que l'établissement n'en détient aucun.
///
/// Le vocabulaire est celui du formulaire : cinq natures de sous-jacent, trois
/// tranches de durée résiduelle, cinq catégories de contrepartie. Nommer les
/// choses autrement obligerait à traduire, c'est-à-dire à se tromper à deux
/// endroits au lieu d'un.
library;

/// Les cinq blocs de l'EP11, dans l'ordre où le formulaire les imprime.
enum NatureDerive {
  taux('taux', "Instruments de taux d'intérêt"),
  changeOr('change_or', "Instruments de taux de change et l'or"),
  titresPropriete('titres_propriete', 'Titres de propriété'),
  metauxPrecieux('metaux_precieux', "Métaux précieux (excepté l'or)"),
  autresProduitsDeBase('autres_produits_de_base', 'Autres produits de base');

  const NatureDerive(this.wire, this.label);

  final String wire;
  final String label;

  static NatureDerive fromWire(String value) => NatureDerive.values.firstWhere(
        (nature) => nature.wire == value,
        orElse: () => NatureDerive.taux,
      );
}

/// Les cinq colonnes de ventilation de l'EP11.
///
/// Ce sont les mêmes lettres que la nomenclature FODEP donne aux catégories
/// d'expositions, et les mêmes que les états EP12 à EP16.
enum CategorieContrepartieDerive {
  souverains('a', 'Souverains'),
  organismesPublics('b', 'Organismes publics hors administration centrale'),
  banquesMultilaterales('c', 'Banques multilatérales de développement'),
  institutionsFinancieres('d', 'Institutions financières'),
  entreprises('e', 'Entreprises');

  const CategorieContrepartieDerive(this.wire, this.label);

  final String wire;
  final String label;

  static CategorieContrepartieDerive fromWire(String value) =>
      CategorieContrepartieDerive.values.firstWhere(
        (categorie) => categorie.wire == value,
        orElse: () => CategorieContrepartieDerive.institutionsFinancieres,
      );
}

/// Les trois lignes de chaque bloc de l'EP11.
enum TrancheDuree {
  moins1An('moins_1_an', 'Durée < 1 an'),
  de1A5Ans('1_a_5_ans', 'Durée > 1 an jusqu\'à 5 ans'),
  plus5Ans('plus_5_ans', 'Durée > 5 ans');

  const TrancheDuree(this.wire, this.label);

  final String wire;
  final String label;

  static TrancheDuree fromWire(String value) => TrancheDuree.values.firstWhere(
        (tranche) => tranche.wire == value,
        orElse: () => TrancheDuree.moins1An,
      );
}

/// Un contrat dérivé du registre.
class Derive {
  const Derive({
    this.id,
    required this.contrepartie,
    required this.categorieContrepartie,
    required this.nature,
    this.typeContrat,
    this.devise = 'XOF',
    this.montantNotionnel = 0.0,
    this.coutRemplacement = 0.0,
    this.dateConclusion,
    required this.dateEcheance,
    this.commentaire,
    this.tranche = TrancheDuree.moins1An,
  });

  final int? id;
  final String contrepartie;
  final CategorieContrepartieDerive categorieContrepartie;
  final NatureDerive nature;
  final String? typeContrat;
  final String devise;

  /// Colonne (b) de l'EP11 : le montant notionnel du contrat.
  final double montantNotionnel;

  /// Colonne (a) : la valeur de marché du contrat quand elle est en faveur de
  /// l'établissement. Une valeur négative ne se déclare pas — le formulaire
  /// additionne (a) et (d), et y porter un nombre négatif réduirait
  /// l'exposition d'un contrat qui ne rapporte rien.
  final double coutRemplacement;

  final DateTime? dateConclusion;
  final DateTime dateEcheance;
  final String? commentaire;

  /// Tranche de durée résiduelle **à ce jour**, calculée par le serveur.
  ///
  /// Elle n'est pas saisie : elle change avec le temps, et l'écran doit
  /// montrer celle d'aujourd'hui, pas celle du jour de la saisie.
  final TrancheDuree tranche;

  factory Derive.fromJson(Map<String, dynamic> json) => Derive(
        id: (json['id'] as num?)?.toInt(),
        contrepartie: (json['contrepartie'] ?? '') as String,
        categorieContrepartie: CategorieContrepartieDerive.fromWire(
          (json['categorie_contrepartie'] ?? 'd') as String,
        ),
        nature: NatureDerive.fromWire((json['nature'] ?? 'taux') as String),
        typeContrat: json['type_contrat'] as String?,
        devise: (json['devise'] ?? 'XOF') as String,
        montantNotionnel:
            (json['montant_notionnel'] as num?)?.toDouble() ?? 0.0,
        coutRemplacement:
            (json['cout_remplacement'] as num?)?.toDouble() ?? 0.0,
        dateConclusion: _date(json['date_conclusion']),
        dateEcheance: _date(json['date_echeance']) ?? DateTime.now(),
        commentaire: json['commentaire'] as String?,
        tranche: TrancheDuree.fromWire((json['tranche'] ?? 'moins_1_an') as String),
      );

  static DateTime? _date(Object? valeur) {
    final texte = valeur as String?;
    if (texte == null || texte.isEmpty) return null;
    return DateTime.tryParse(texte);
  }

  static String _iso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toPayload() => {
        'contrepartie': contrepartie,
        'categorie_contrepartie': categorieContrepartie.wire,
        'nature': nature.wire,
        'type_contrat': typeContrat,
        'devise': devise,
        'montant_notionnel': montantNotionnel,
        'cout_remplacement': coutRemplacement,
        'date_conclusion':
            dateConclusion == null ? null : _iso(dateConclusion!),
        'date_echeance': _iso(dateEcheance),
        'commentaire': commentaire,
      };

  Derive copyWith({
    int? id,
    String? contrepartie,
    CategorieContrepartieDerive? categorieContrepartie,
    NatureDerive? nature,
    String? typeContrat,
    String? devise,
    double? montantNotionnel,
    double? coutRemplacement,
    DateTime? dateConclusion,
    DateTime? dateEcheance,
    String? commentaire,
  }) =>
      Derive(
        id: id ?? this.id,
        contrepartie: contrepartie ?? this.contrepartie,
        categorieContrepartie:
            categorieContrepartie ?? this.categorieContrepartie,
        nature: nature ?? this.nature,
        typeContrat: typeContrat ?? this.typeContrat,
        devise: devise ?? this.devise,
        montantNotionnel: montantNotionnel ?? this.montantNotionnel,
        coutRemplacement: coutRemplacement ?? this.coutRemplacement,
        dateConclusion: dateConclusion ?? this.dateConclusion,
        dateEcheance: dateEcheance ?? this.dateEcheance,
        commentaire: commentaire ?? this.commentaire,
        tranche: tranche,
      );
}

/// Une des quinze lignes de l'EP11, telle que le registre la remplit.
class LigneEp11 {
  const LigneEp11({
    required this.code,
    required this.nature,
    required this.tranche,
    required this.libelle,
    required this.nombreContrats,
    required this.coutRemplacement,
    required this.montantNotionnel,
    required this.ponderation,
    required this.notionnelPondere,
    required this.exposition,
    required this.ventilation,
  });

  final String code;
  final String nature;
  final String tranche;
  final String libelle;
  final int nombreContrats;

  /// (a) coût de remplacement.
  final double coutRemplacement;

  /// (b) montant notionnel.
  final double montantNotionnel;

  /// (c) pondération, imprimée par la BCEAO sur le formulaire — jamais choisie
  /// par l'application.
  final double ponderation;

  /// (d) = b × c.
  final double notionnelPondere;

  /// (e) = a + d.
  final double exposition;

  /// Répartition de (e) par catégorie de contrepartie, sous la lettre FODEP.
  final Map<String, double> ventilation;

  factory LigneEp11.fromJson(Map<String, dynamic> json) => LigneEp11(
        code: (json['code'] ?? '') as String,
        nature: (json['nature'] ?? '') as String,
        tranche: (json['tranche'] ?? '') as String,
        libelle: (json['libelle'] ?? '') as String,
        nombreContrats: (json['nombre_contrats'] as num?)?.toInt() ?? 0,
        coutRemplacement:
            (json['cout_remplacement'] as num?)?.toDouble() ?? 0.0,
        montantNotionnel:
            (json['montant_notionnel'] as num?)?.toDouble() ?? 0.0,
        ponderation: (json['ponderation'] as num?)?.toDouble() ?? 0.0,
        notionnelPondere:
            (json['notionnel_pondere'] as num?)?.toDouble() ?? 0.0,
        exposition: (json['exposition'] as num?)?.toDouble() ?? 0.0,
        ventilation:
            ((json['ventilation'] as Map<dynamic, dynamic>?) ?? const {}).map(
          (cle, valeur) =>
              MapEntry(cle.toString(), (valeur as num?)?.toDouble() ?? 0.0),
        ),
      );
}

/// L'EP11 tel que le registre le déclarera.
///
/// L'écran montre l'état, et non une somme de contrats : une saisie ne se
/// vérifie qu'en regardant la case où elle atterrit.
class SyntheseEp11 {
  const SyntheseEp11({
    required this.nombre,
    required this.totalNotionnel,
    required this.totalCoutRemplacement,
    required this.totalExposition,
    required this.lignes,
    required this.alertes,
  });

  final int nombre;
  final double totalNotionnel;
  final double totalCoutRemplacement;
  final double totalExposition;
  final List<LigneEp11> lignes;
  final List<String> alertes;

  factory SyntheseEp11.fromJson(Map<String, dynamic> json) => SyntheseEp11(
        nombre: (json['nombre'] as num?)?.toInt() ?? 0,
        totalNotionnel: (json['total_notionnel'] as num?)?.toDouble() ?? 0.0,
        totalCoutRemplacement:
            (json['total_cout_remplacement'] as num?)?.toDouble() ?? 0.0,
        totalExposition:
            (json['total_exposition'] as num?)?.toDouble() ?? 0.0,
        lignes: ((json['lignes'] as List<dynamic>?) ?? const [])
            .map((item) => LigneEp11.fromJson(item as Map<String, dynamic>))
            .toList(),
        alertes: ((json['alertes'] as List<dynamic>?) ?? const [])
            .map((item) => item.toString())
            .toList(),
      );
}
