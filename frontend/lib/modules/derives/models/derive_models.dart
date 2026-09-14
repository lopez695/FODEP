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

/// Les types de contrat proposés pour chaque nature de sous-jacent.
///
/// Le formulaire BCEAO ne demande pas le type : il sert à reconnaître sa propre
/// saisie. Une liste fermée évite qu'un même swap apparaisse sous trois
/// graphies ; la restreindre à la nature choisie évite un « swap de taux »
/// rangé parmi les produits de base.
extension TypesDeContrat on NatureDerive {
  List<String> get typesDeContrat => switch (this) {
        NatureDerive.taux => const [
            'Swap de taux',
            'FRA (accord de taux futur)',
            'Future sur taux',
            'Option sur taux (cap, floor, swaption)',
            'Autre',
          ],
        NatureDerive.changeOr => const [
            'Change à terme',
            'Swap de change',
            'Swap de devises',
            'Option de change',
            'Contrat sur or',
            'Autre',
          ],
        NatureDerive.titresPropriete => const [
            'Contrat à terme sur actions',
            'Future sur indice',
            'Option sur actions',
            'Swap sur actions',
            'Autre',
          ],
        NatureDerive.metauxPrecieux => const [
            'Contrat à terme sur métaux précieux',
            'Option sur métaux précieux',
            'Swap sur métaux précieux',
            'Autre',
          ],
        NatureDerive.autresProduitsDeBase => const [
            'Contrat à terme sur matières premières',
            'Option sur matières premières',
            'Swap sur matières premières',
            'Autre',
          ],
      };
}

/// Les devises qu'un contrat peut porter : celles que le serveur sait ramener
/// au franc CFA (`DEVISES_CONVERTIBLES`). Une autre y serait convertie au taux
/// de repli 1,0, comme si elle était déjà du franc — le serveur la refuse.
const devisesDerives = ['XOF', 'EUR', 'USD'];

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

  /// Tranche où tombe une échéance, lue à la date [reference].
  ///
  /// Mêmes bornes que le serveur (`tranche_de_duree`) : un an, cinq ans, sur
  /// une année civile moyenne de 365,25 jours. Elle ne sert qu'à l'aperçu du
  /// formulaire ; la tranche qui fait foi est celle que rend le serveur.
  static TrancheDuree pour(DateTime echeance, DateTime reference) {
    final annees = echeance.difference(reference).inDays / 365.25;
    if (annees <= 1) return TrancheDuree.moins1An;
    if (annees <= 5) return TrancheDuree.de1A5Ans;
    return TrancheDuree.plus5Ans;
  }

  static TrancheDuree fromWire(String value) => TrancheDuree.values.firstWhere(
        (tranche) => tranche.wire == value,
        orElse: () => TrancheDuree.moins1An,
      );
}

/// Un contrat dérivé du registre.
class Derive {
  const Derive({
    this.id,
    this.contrepartieId,
    this.categoriePrudentielle,
    this.notation,
    this.horsEp11 = false,
    this.sousJacentType = TypeSousJacent.autre,
    this.sousJacentRef,
    this.sousJacentLibelle,
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

  /// Identifiant de la contrepartie dans le portefeuille (`EXP-2026-…`).
  ///
  /// C'est lui que le serveur enregistre : le nom et la catégorie se lisent
  /// sur la fiche. `null` pour un contrat antérieur au rattachement.
  final String? contrepartieId;

  /// Catégorie prudentielle de la fiche, telle que le moteur la connaît.
  final String? categoriePrudentielle;
  final String? notation;

  /// Vrai quand la catégorie du tiers n'a pas de colonne sur l'EP11 : le
  /// contrat se range alors sous « Entreprises », repli du formulaire.
  final bool horsEp11;

  /// Ce que le contrat couvre : un crédit, une obligation, une action, ou
  /// rien de tel.
  final TypeSousJacent sousJacentType;

  /// Identifiant de l'exposition, ISIN ou ticker selon le type.
  final String? sousJacentRef;

  /// Recopie lisible, fournie par le serveur.
  final String? sousJacentLibelle;

  /// Nom lu sur la fiche de la contrepartie.
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
        contrepartieId: json['contrepartie_id'] as String?,
        categoriePrudentielle: json['categorie_prudentielle'] as String?,
        notation: json['notation'] as String?,
        horsEp11: (json['hors_ep11'] as bool?) ?? false,
        sousJacentType: TypeSousJacent.fromWire(
          (json['sous_jacent_type'] ?? 'autre') as String,
        ),
        sousJacentRef: json['sous_jacent_ref'] as String?,
        sousJacentLibelle: json['sous_jacent_libelle'] as String?,
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

  /// Ce qui part au serveur : l'identifiant de la contrepartie, jamais son
  /// nom ni sa catégorie, qu'il relit sur la fiche.
  Map<String, dynamic> toPayload() => {
        'contrepartie_id': contrepartieId,
        'sous_jacent_type': sousJacentType.wire,
        'sous_jacent_ref': sousJacentRef,
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
        contrepartieId: contrepartieId,
        categoriePrudentielle: categoriePrudentielle,
        notation: notation,
        horsEp11: horsEp11,
        sousJacentType: sousJacentType,
        sousJacentRef: sousJacentRef,
        sousJacentLibelle: sousJacentLibelle,
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

/// Ce à quoi un dérivé se rattache : ce qu'il couvre, ou sur quoi il porte.
///
/// Ce n'est pas la contrepartie. L'EP11 ventile celui qui a **signé** le
/// contrat ; l'émetteur d'une obligation ou d'une action couverte ne l'est pas.
/// Les deux ne coïncident que pour la couverture d'un crédit : le client qui
/// emprunte est aussi celui qui signe.
enum TypeSousJacent {
  credit('credit', "Crédit d'un client"),
  obligation('obligation', 'Obligation'),
  action('action', 'Action'),
  autre('autre', 'Autre');

  const TypeSousJacent(this.wire, this.label);

  final String wire;
  final String label;

  /// La nature que le sous-jacent impose : un dérivé sur une obligation porte
  /// sur les taux, un dérivé sur une action sur les titres de propriété. Le
  /// serveur applique la même règle.
  NatureDerive? get natureImposee => switch (this) {
        TypeSousJacent.obligation => NatureDerive.taux,
        TypeSousJacent.action => NatureDerive.titresPropriete,
        _ => null,
      };

  static TypeSousJacent fromWire(String value) =>
      TypeSousJacent.values.firstWhere(
        (type) => type.wire == value,
        orElse: () => TypeSousJacent.autre,
      );
}

DateTime? _dateOuNull(Object? valeur) {
  final texte = valeur as String?;
  if (texte == null || texte.isEmpty) return null;
  return DateTime.tryParse(texte);
}

/// Un crédit du portefeuille, que le client peut couvrir par un dérivé.
///
/// Il porte sa contrepartie : le client qui emprunte signe la couverture.
class CreditCouvrable {
  const CreditCouvrable({
    required this.id,
    required this.contrepartieId,
    required this.contrepartie,
    this.categoriePrudentielle,
    required this.categorieEp11,
    this.horsEp11 = false,
    this.notation,
    this.montantBrut = 0.0,
    this.devise = 'XOF',
    this.dateEcheance,
    this.statut,
  });

  final String id;
  final String contrepartieId;
  final String contrepartie;
  final String? categoriePrudentielle;
  final CategorieContrepartieDerive categorieEp11;
  final bool horsEp11;
  final String? notation;
  final double montantBrut;
  final String devise;
  final DateTime? dateEcheance;
  final String? statut;

  /// Ce que le champ affiche une fois le crédit choisi.
  String get libelle => '$contrepartie · $id';

  /// La contrepartie du dérivé qui le couvre : le client lui-même.
  ContrepartieDerive get contrepartieDerive => ContrepartieDerive(
        id: contrepartieId,
        nom: contrepartie,
        categoriePrudentielle: categoriePrudentielle,
        categorieEp11: categorieEp11,
        horsEp11: horsEp11,
        notation: notation,
      );

  factory CreditCouvrable.fromJson(Map<String, dynamic> json) =>
      CreditCouvrable(
        id: (json['id'] ?? '') as String,
        contrepartieId: (json['contrepartie_id'] ?? '') as String,
        contrepartie: (json['contrepartie'] ?? '') as String,
        categoriePrudentielle: json['categorie_prudentielle'] as String?,
        categorieEp11: CategorieContrepartieDerive.fromWire(
          (json['categorie_ep11'] ?? 'e') as String,
        ),
        horsEp11: (json['hors_ep11'] as bool?) ?? false,
        notation: json['notation'] as String?,
        montantBrut: (json['montant_brut'] as num?)?.toDouble() ?? 0.0,
        devise: (json['devise'] ?? 'XOF') as String,
        dateEcheance: _dateOuNull(json['date_echeance']),
        statut: json['statut'] as String?,
      );
}

/// Une obligation du portefeuille de marché.
///
/// Son émetteur n'est **pas** la contrepartie d'un dérivé qui la couvre.
class ObligationDetenue {
  const ObligationDetenue({
    required this.isin,
    required this.emetteur,
    this.devise = 'XOF',
    this.dateEcheance,
    this.valeurNominale = 0.0,
    this.quantite = 0,
    this.tauxCouponPct = 0.0,
  });

  final String isin;
  final String emetteur;
  final String devise;
  final DateTime? dateEcheance;
  final double valeurNominale;
  final int quantite;
  final double tauxCouponPct;

  String get libelle => '$isin · $emetteur';

  /// Encours nominal détenu : valeur nominale × quantité.
  double get encoursNominal => valeurNominale * quantite;

  factory ObligationDetenue.fromJson(Map<String, dynamic> json) =>
      ObligationDetenue(
        isin: (json['isin'] ?? '') as String,
        emetteur: (json['emetteur'] ?? '') as String,
        devise: (json['devise'] ?? 'XOF') as String,
        dateEcheance: _dateOuNull(json['date_echeance']),
        valeurNominale: (json['valeur_nominale'] as num?)?.toDouble() ?? 0.0,
        quantite: (json['quantite'] as num?)?.toInt() ?? 0,
        tauxCouponPct: (json['taux_coupon_pct'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Une action du portefeuille de marché.
class ActionDetenue {
  const ActionDetenue({
    required this.ticker,
    required this.libelle,
    this.secteur,
    this.quantite = 0,
  });

  final String ticker;
  final String libelle;
  final String? secteur;
  final int quantite;

  factory ActionDetenue.fromJson(Map<String, dynamic> json) => ActionDetenue(
        ticker: (json['ticker'] ?? '') as String,
        libelle: (json['libelle'] ?? '') as String,
        secteur: json['secteur'] as String?,
        quantite: (json['quantite'] as num?)?.toInt() ?? 0,
      );
}

/// Ce à quoi un dérivé peut se rattacher, par onglet du formulaire.
class SousJacents {
  const SousJacents({
    this.credits = const [],
    this.obligations = const [],
    this.actions = const [],
    this.alertes = const [],
  });

  static const vide = SousJacents();

  final List<CreditCouvrable> credits;
  final List<ObligationDetenue> obligations;
  final List<ActionDetenue> actions;

  /// Ce qui n'a pas pu être lu : un portefeuille de marché illisible
  /// n'empêche pas de couvrir un crédit.
  final List<String> alertes;

  factory SousJacents.fromJson(Map<String, dynamic> json) => SousJacents(
        credits: ((json['credits'] as List<dynamic>?) ?? const [])
            .map((e) => CreditCouvrable.fromJson(e as Map<String, dynamic>))
            .toList(),
        obligations: ((json['obligations'] as List<dynamic>?) ?? const [])
            .map((e) => ObligationDetenue.fromJson(e as Map<String, dynamic>))
            .toList(),
        actions: ((json['actions'] as List<dynamic>?) ?? const [])
            .map((e) => ActionDetenue.fromJson(e as Map<String, dynamic>))
            .toList(),
        alertes: ((json['alertes'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// Une contrepartie du portefeuille, telle que le sélecteur la propose.
///
/// L'identifiant est affiché à côté du nom : deux tiers peuvent porter le
/// même, et c'est par lui qu'on fait la correspondance avec le reste de l'outil.
class ContrepartieDerive {
  const ContrepartieDerive({
    required this.id,
    required this.nom,
    this.pays,
    this.categoriePrudentielle,
    required this.categorieEp11,
    this.horsEp11 = false,
    this.notation,
  });

  final String id;
  final String nom;
  final String? pays;
  final String? categoriePrudentielle;

  /// Colonne de l'EP11 où tomberait un dérivé sur ce tiers.
  final CategorieContrepartieDerive categorieEp11;
  final bool horsEp11;
  final String? notation;

  /// Ce que le champ affiche une fois le tiers choisi.
  String get libelle => '$nom · $id';

  factory ContrepartieDerive.fromJson(Map<String, dynamic> json) =>
      ContrepartieDerive(
        id: (json['id'] ?? '') as String,
        nom: (json['nom'] ?? '') as String,
        pays: json['pays'] as String?,
        categoriePrudentielle: json['categorie_prudentielle'] as String?,
        categorieEp11: CategorieContrepartieDerive.fromWire(
          (json['categorie_ep11'] ?? 'e') as String,
        ),
        horsEp11: (json['hors_ep11'] as bool?) ?? false,
        notation: json['notation'] as String?,
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
