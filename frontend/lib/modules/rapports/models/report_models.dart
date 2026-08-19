// Ce fichier decrit les donnees du module rapports.
import 'dart:typed_data';

import '../../../core/utils/currency_conversion.dart';

/// Ligne détaillée d'un rapport exportable.
class ReportLine {
  const ReportLine({
    required this.source,
    required this.itemId,
    required this.counterparty,
    required this.amount,
    required this.ead,
    required this.rwa,
    required this.capital,
  });

  final String source;
  final String itemId;
  final String counterparty;
  final double amount;
  final double ead;
  final double rwa;
  final double capital;

  factory ReportLine.fromJson(Map<String, dynamic> json) {
    return ReportLine(
      source: json['source'] as String,
      itemId: json['item_id'] as String,
      counterparty: json['counterparty'] as String,
      amount: (json['amount'] as num).toDouble(),
      ead: (json['ead'] as num).toDouble(),
      rwa: (json['rwa'] as num).toDouble(),
      capital: (json['capital'] as num).toDouble(),
    );
  }
}

/// Représente un rapport généré et stocké.
class ReportRecord {
  const ReportRecord({
    required this.id,
    required this.createdAt,
    required this.period,
    required this.reportType,
    required this.currency,
    required this.exposureScope,
    required this.includeCategoryChart,
    required this.includeRatingChart,
    required this.exports,
    required this.lines,
  });

  final String id;
  final DateTime createdAt;
  final String period;
  final String reportType;
  final String currency;
  final String exposureScope;
  final bool includeCategoryChart;
  final bool includeRatingChart;
  final Map<String, String> exports;
  final List<ReportLine> lines;

  factory ReportRecord.fromJson(Map<String, dynamic> json) {
    return ReportRecord(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      period: json['period'] as String,
      reportType: json['report_type'] as String,
      currency: normalizeCurrencyCode(json['currency'] as String),
      exposureScope: json['exposure_scope'] as String,
      includeCategoryChart: json['include_category_chart'] as bool,
      includeRatingChart: json['include_rating_chart'] as bool,
      exports: (json['exports'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      ),
      lines: (json['lines'] as List<dynamic>? ?? [])
          .map((item) => ReportLine.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Données complètes de l'écran rapports.
class ReportsModuleData {
  const ReportsModuleData({
    required this.reports,
  });

  final List<ReportRecord> reports;
}

/// Paramètres saisis avant génération d'un rapport.
class ReportDraft {
  const ReportDraft({
    required this.period,
    required this.reportType,
    required this.currency,
    required this.exposureScope,
    required this.includeCategoryChart,
    required this.includeRatingChart,
  });

  final String period;
  final String reportType;
  final String currency;
  final String exposureScope;
  final bool includeCategoryChart;
  final bool includeRatingChart;

  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'report_type': reportType,
      'currency': currency,
      'exposure_scope': exposureScope,
      'include_category_chart': includeCategoryChart,
      'include_rating_chart': includeRatingChart,
    };
  }
}

/// Classeur FODEP renvoyé par le backend, avec ses réserves de lecture.
///
/// Ce qu'une réserve de lecture attend du déclarant.
///
/// Toutes n'appellent pas le même geste. L'écran les présentait d'affilée sous
/// une même consigne — « complétez-les à la main » — alors qu'on ne complète
/// ni une convention de report, ni un poste que l'établissement ne détient
/// pas. Les remarques qui demandaient vraiment une action se lisaient comme
/// les autres, c'est-à-dire pas du tout.
enum NatureReserve {
  /// Un geste avant de transmettre : compléter une saisie, reprendre un
  /// import, vérifier une valeur.
  aVerifier('a_verifier'),

  /// Un choix de l'application pour loger ses données dans le formulaire, là
  /// où celui-ci n'offre pas la ligne attendue. Celui qui signe l'endosse.
  convention('convention'),

  /// Un constat sur la déclaration produite : un poste à zéro faute d'objet,
  /// un décompte. Se lit, ne se corrige pas.
  information('information');

  const NatureReserve(this.code);

  final String code;

  /// Une nature inconnue est traitée comme une vérification : mieux vaut
  /// montrer une remarque de trop en tête de liste que la reléguer.
  static NatureReserve depuis(String? code) => values.firstWhere(
        (nature) => nature.code == code,
        orElse: () => NatureReserve.aVerifier,
      );
}

/// Une remarque de lecture accompagnant la déclaration.
class ReserveFodep {
  const ReserveFodep({required this.nature, required this.message});

  final NatureReserve nature;
  final String message;

  /// Accepte aussi une réserve transmise en texte brut, comme le faisaient les
  /// versions antérieures : un poste de travail dont le backend n'a pas encore
  /// été relancé ne doit pas perdre ses réserves.
  factory ReserveFodep.depuisJson(Object? brut) {
    if (brut is Map) {
      return ReserveFodep(
        nature: NatureReserve.depuis(brut['nature'] as String?),
        message: brut['message'] as String? ?? '',
      );
    }
    return ReserveFodep(
      nature: NatureReserve.aVerifier,
      message: brut?.toString() ?? '',
    );
  }
}

/// [anomalies] liste les postes que l'application ne sait pas encore
/// alimenter, ou dont la règle du formulaire s'écarte de celle retenue
/// ailleurs dans l'outil. Elles doivent être lues avant de transmettre la
/// déclaration à la plate-forme de reporting de la BCEAO.
class FodepExport {
  const FodepExport({
    required this.bytes,
    required this.fileName,
    this.anomalies = const [],
  });

  final Uint8List bytes;
  final String fileName;
  final List<ReserveFodep> anomalies;
}

/// Une cellule du formulaire, avec ce qu'il faut pour la redessiner.
class CelluleFodep {
  const CelluleFodep({
    this.texte = '',
    this.gras = false,
    this.droite = false,
    this.centre = false,
    this.colonnes = 1,
    this.fond,
    this.bordures = '',
    this.taille,
  });

  final String texte;

  /// Le formulaire met ses intitulés et ses totaux en gras.
  final bool gras;

  /// Les montants et les ratios y sont cadrés à droite.
  final bool droite;

  /// Les en-têtes de colonne y sont centrés.
  final bool centre;

  /// Colonnes couvertes, reprises des fusions du formulaire.
  final int colonnes;

  /// Couleur de fond en RVB (« FFF2CC »), telle que le classeur la porte. Le
  /// formulaire teinte les cases à renseigner : sans elles, on ne distingue
  /// plus ce que l'établissement déclare de ce qu'on lui demande.
  final String? fond;

  /// Côtés bordés, parmi « l », « r », « t » et « b ». Le formulaire n'encadre
  /// que ses tableaux ; c'est aussi ce qui rend continues ses fusions
  /// verticales.
  final String bordures;

  /// Taille de police du classeur : 10 pour le corps, jusqu'à 20 pour les
  /// titres.
  final double? taille;

  factory CelluleFodep.fromJson(Map<String, dynamic> json) => CelluleFodep(
        texte: json['texte'] as String? ?? '',
        gras: json['gras'] == true,
        droite: json['droite'] == true,
        centre: json['centre'] == true,
        colonnes: (json['colonnes'] as num?)?.toInt() ?? 1,
        fond: json['fond'] as String?,
        bordures: json['bordures'] as String? ?? '',
        taille: (json['taille'] as num?)?.toDouble(),
      );
}

/// Une ligne du formulaire.
class LigneFodep {
  const LigneFodep({
    this.cellules = const [],
    this.hauteur,
    this.entete = false,
  });

  final List<CelluleFodep> cellules;

  /// Hauteur réglée dans le classeur, en points. Le formulaire aère ses lignes
  /// et donne à ses en-têtes deux ou trois fois la hauteur d'une ligne de
  /// données.
  final double? hauteur;

  /// Ligne d'en-tête, réimprimée en haut de chaque page. Le classeur les
  /// désigne lui-même, par son réglage « lignes à répéter en haut ».
  final bool entete;

  factory LigneFodep.fromJson(Map<String, dynamic> json) => LigneFodep(
        hauteur: (json['hauteur'] as num?)?.toDouble(),
        entete: json['entete'] == true,
        cellules: [
          for (final cellule in (json['cellules'] as List<dynamic>?) ?? const [])
            CelluleFodep.fromJson(cellule as Map<String, dynamic>),
        ],
      );
}

/// Un état du FODEP, réduit à ses lignes porteuses de valeur.
class EtatFodep {
  const EtatFodep({
    required this.nom,
    this.largeurs = const [],
    this.paysage = true,
    this.lignes = const [],
  });

  final String nom;

  /// Largeurs des colonnes dans l'unité d'Excel. Les conserver évite un PDF aux
  /// colonnes égales, où l'intitulé d'un poste serait aussi étroit que la
  /// colonne d'un code DISPRU.
  final List<double> largeurs;

  /// Orientation réglée dans le classeur. Dix-neuf états du FODEP sont en
  /// portrait : les imprimer tous en paysage étirait leurs colonnes sur une
  /// page trois fois trop large pour elles.
  final bool paysage;

  final List<LigneFodep> lignes;

  /// Lignes d'en-tête, à réimprimer en haut de chaque page.
  List<LigneFodep> get entetes =>
      [for (final ligne in lignes) if (ligne.entete) ligne];

  /// Lignes du corps, celles que la pagination fait défiler.
  List<LigneFodep> get corps =>
      [for (final ligne in lignes) if (!ligne.entete) ligne];

  factory EtatFodep.fromJson(Map<String, dynamic> json) => EtatFodep(
        nom: json['nom'] as String? ?? '',
        paysage: json['paysage'] as bool? ?? true,
        largeurs: [
          for (final largeur in (json['largeurs'] as List<dynamic>?) ?? const [])
            (largeur as num).toDouble(),
        ],
        lignes: [
          for (final ligne in (json['lignes'] as List<dynamic>?) ?? const [])
            LigneFodep.fromJson(ligne as Map<String, dynamic>),
        ],
      );
}

/// Le FODEP renseigné, rendu lisible pour en faire un PDF.
///
/// Le classeur reste la pièce déclarative ; ceci en est la lecture. L'extraction
/// est faite par le backend : la bibliothèque Excel du poste de travail échoue à
/// décoder ce formulaire, qu'openpyxl vient pourtant d'écrire.
class ContenuFodep {
  const ContenuFodep({
    required this.nomFichier,
    required this.dateArrete,
    required this.anomalies,
    required this.etats,
  });

  final String nomFichier;
  final DateTime? dateArrete;

  /// Mêmes réserves que celles de [FodepExport] : elles doivent être lues
  /// avant de transmettre.
  final List<ReserveFodep> anomalies;

  final List<EtatFodep> etats;

  factory ContenuFodep.fromJson(Map<String, dynamic> json) => ContenuFodep(
        nomFichier: json['nom_fichier'] as String? ?? 'FODEP.xlsx',
        dateArrete: DateTime.tryParse('${json['date_arrete']}'),
        anomalies: [
          for (final anomalie in (json['anomalies'] as List<dynamic>?) ?? const [])
            ReserveFodep.depuisJson(anomalie),
        ],
        etats: [
          for (final etat in (json['etats'] as List<dynamic>?) ?? const [])
            EtatFodep.fromJson(etat as Map<String, dynamic>),
        ],
      );
}

/// Où en est une norme prudentielle d'une déclaration analysée.
enum SituationNorme {
  respectee('respectee', 'Respectée'),
  depassee('depassee', 'Dépassée'),
  nonMesuree('non_mesuree', 'Non mesurée');

  const SituationNorme(this.wire, this.libelle);

  final String wire;
  final String libelle;

  static SituationNorme fromWire(String? valeur) => SituationNorme.values
      .firstWhere((s) => s.wire == valeur, orElse: () => SituationNorme.nonMesuree);
}

/// Une des onze normes de l'EP01, confrontée à son seuil.
class NormeAnalysee {
  const NormeAnalysee({
    required this.code,
    required this.libelle,
    required this.situation,
    this.reference = '',
    this.seuil,
    this.observe,
    this.minimum,
    this.ecart,
  });

  final String code;
  final String libelle;

  /// État du FODEP qui produit le niveau observé.
  final String reference;

  final double? seuil;
  final double? observe;

  /// `true` pour un plancher — ratios de fonds propres, levier —, `false` pour
  /// un plafond. Nul quand le sens de la norme est inconnu de l'outil.
  final bool? minimum;

  final SituationNorme situation;

  /// Marge restante, ou montant du dépassement, en points du ratio.
  final double? ecart;

  factory NormeAnalysee.fromJson(Map<String, dynamic> json) => NormeAnalysee(
        code: json['code'] as String? ?? '',
        libelle: json['libelle'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        seuil: (json['seuil'] as num?)?.toDouble(),
        observe: (json['observe'] as num?)?.toDouble(),
        minimum: json['minimum'] as bool?,
        situation: SituationNorme.fromWire(json['situation'] as String?),
        ecart: (json['ecart'] as num?)?.toDouble(),
      );
}

/// Statut d'un contrôle de cohérence.
enum StatutControle {
  exact('exact', 'Exact'),
  arrondi('arrondi', 'Arrondi'),
  ecart('ecart', 'Écart');

  const StatutControle(this.wire, this.libelle);

  final String wire;
  final String libelle;

  static StatutControle fromWire(String? valeur) => StatutControle.values
      .firstWhere((s) => s.wire == valeur, orElse: () => StatutControle.exact);
}

/// Un total du formulaire, confronté à la somme de ses lignes.
///
/// Les normes disent si la déclaration respecte le dispositif ; ces contrôles
/// disent si elle se contredit. Un total qui ne suit pas ses lignes fait rejeter
/// le dépôt sans qu'aucune norme ne soit en cause.
class ControleCoherence {
  const ControleCoherence({
    required this.etat,
    required this.libelle,
    required this.colonne,
    required this.attendu,
    required this.constate,
    required this.ecart,
    required this.tolerance,
    required this.statut,
  });

  final String etat;
  final String libelle;

  /// Colonne vérifiée, telle que le formulaire l'intitule.
  final String colonne;

  /// Somme des lignes de la section.
  final double attendu;

  /// Valeur portée par la ligne de total.
  final double constate;

  final double ecart;

  /// Dérive maximale imputable aux arrondis : une demi-unité par ligne sommée.
  final double tolerance;

  final StatutControle statut;

  factory ControleCoherence.fromJson(Map<String, dynamic> json) =>
      ControleCoherence(
        etat: json['etat'] as String? ?? '',
        libelle: json['libelle'] as String? ?? '',
        colonne: json['colonne'] as String? ?? '',
        attendu: (json['attendu'] as num?)?.toDouble() ?? 0,
        constate: (json['constate'] as num?)?.toDouble() ?? 0,
        ecart: (json['ecart'] as num?)?.toDouble() ?? 0,
        tolerance: (json['tolerance'] as num?)?.toDouble() ?? 0,
        statut: StatutControle.fromWire(json['statut'] as String?),
      );
}

/// Ce qu'un état porte : combien de lignes, et s'il est entièrement à zéro.
class EtatRenseigne {
  const EtatRenseigne({
    required this.nom,
    required this.lignes,
    required this.toutAZero,
  });

  final String nom;
  final int lignes;

  /// Aucune valeur numérique non nulle. L'état est déclaré, mais ne dit rien.
  final bool toutAZero;

  factory EtatRenseigne.fromJson(Map<String, dynamic> json) => EtatRenseigne(
        nom: json['nom'] as String? ?? '',
        lignes: (json['lignes'] as num?)?.toInt() ?? 0,
        toutAZero: json['tout_a_zero'] == true,
      );
}

/// Verdict d'ensemble sur une déclaration déposée.
class AnalyseDeclaration {
  const AnalyseDeclaration({
    required this.nomFichier,
    required this.pages,
    this.normes = const [],
    this.controles = const [],
    this.inventaire = const [],
    this.classeur = false,
    this.avertissements = const [],
  });

  final String nomFichier;
  final int pages;
  final List<NormeAnalysee> normes;

  /// Contrôles de cohérence interne. Vides pour une impression : sommer des
  /// nombres extraits d'un PDF ne prouverait rien.
  final List<ControleCoherence> controles;

  /// Les états du formulaire, et ce qu'ils portent.
  final List<EtatRenseigne> inventaire;

  /// `true` quand la lecture a porté sur le classeur, la pièce transmise.
  final bool classeur;

  /// Ce qui empêche de conclure : PDF scanné, normes absentes, niveaux nuls.
  final List<String> avertissements;

  List<ControleCoherence> get ecarts => controles
      .where((controle) => controle.statut == StatutControle.ecart)
      .toList();

  List<EtatRenseigne> get etatsAZero =>
      inventaire.where((etat) => etat.toutAZero).toList();

  List<NormeAnalysee> get depassees => normes
      .where((norme) => norme.situation == SituationNorme.depassee)
      .toList();

  List<NormeAnalysee> get nonMesurees => normes
      .where((norme) => norme.situation == SituationNorme.nonMesuree)
      .toList();

  factory AnalyseDeclaration.fromJson(Map<String, dynamic> json) =>
      AnalyseDeclaration(
        nomFichier: json['nom_fichier'] as String? ?? '',
        pages: (json['pages'] as num?)?.toInt() ?? 0,
        classeur: json['classeur'] == true,
        normes: [
          for (final norme in (json['normes'] as List<dynamic>?) ?? const [])
            NormeAnalysee.fromJson(norme as Map<String, dynamic>),
        ],
        controles: [
          for (final controle
              in (json['controles'] as List<dynamic>?) ?? const [])
            ControleCoherence.fromJson(controle as Map<String, dynamic>),
        ],
        inventaire: [
          for (final etat in (json['inventaire'] as List<dynamic>?) ?? const [])
            EtatRenseigne.fromJson(etat as Map<String, dynamic>),
        ],
        avertissements: [
          for (final message
              in (json['avertissements'] as List<dynamic>?) ?? const [])
            '$message',
        ],
      );
}

/// Une case du FODEP que le déclarant renseigne lui-même.
///
/// L'adresse — l'état et la cellule — est la clé : elle ne bouge pas avec
/// l'ordre des lignes du formulaire. Le code DISPRU, l'intitulé de la ligne et
/// l'en-tête de colonne l'accompagnent pour que l'écran désigne la case comme
/// le formulaire la désigne, et non par une coordonnée Excel nue.
class CaseFodep {
  const CaseFodep({
    required this.etat,
    required this.cellule,
    required this.ligne,
    required this.code,
    required this.libelle,
    required this.colonne,
    this.typeSaisie = 'nombre',
    this.choix = const <String>[],
    this.valeur,
    this.texte,
    this.commentaire,
  });

  final String etat;
  final String cellule;
  final int ligne;

  /// Code DISPRU de la ligne, tel que la BCEAO l'identifie.
  final String code;

  final String libelle;
  final String colonne;

  /// Ce que la case attend, tel que son libellé le dit : `nombre` pour un
  /// montant, `texte` pour un nom, puis `code`, `telephone`, `email` et `date`
  /// pour l'attestation. L'écran en tire le clavier, les caractères qu'il
  /// laisse passer et le contrôle qu'il applique.
  final String typeSaisie;

  /// Valeurs proposées quand la case se choisit au lieu de se taper. Vide, la
  /// case reste une ligne de saisie libre. La liste vient du catalogue servi
  /// par le backend, jamais de l'écran : c'est le formulaire qui dit ce qu'une
  /// case accepte.
  final List<String> choix;

  bool get estUneListe => choix.isNotEmpty;

  /// Seul un montant est conservé en valeur numérique. Tout le reste est du
  /// texte, y compris ce qui n'est fait que de chiffres : un numéro de
  /// téléphone ou un CIB commençant par zéro le perdrait en devenant un
  /// nombre. Un type inconnu est traité comme du texte : mieux vaut conserver
  /// la frappe telle quelle que la filtrer sur une règle qu'on ne connait pas.
  bool get estTexte => typeSaisie != 'nombre';

  /// Valeur portée par le déclarant. `null` signifie « non renseignée » : la
  /// case retombera au zéro automatique de l'export.
  final double? valeur;

  /// Contenu textuel, pour les champs de l'attestation.
  final String? texte;

  final String? commentaire;

  bool get renseignee => valeur != null || (texte != null && texte!.isNotEmpty);

  CaseFodep copyWith({
    double? valeur,
    String? texte,
    String? commentaire,
    bool effacer = false,
  }) {
    return CaseFodep(
      etat: etat,
      cellule: cellule,
      ligne: ligne,
      code: code,
      libelle: libelle,
      colonne: colonne,
      typeSaisie: typeSaisie,
      choix: choix,
      valeur: effacer ? null : (valeur ?? this.valeur),
      texte: effacer ? null : (texte ?? this.texte),
      commentaire: commentaire ?? this.commentaire,
    );
  }

  factory CaseFodep.fromJson(Map<String, dynamic> json) => CaseFodep(
        etat: json['etat'] as String? ?? '',
        cellule: json['cellule'] as String? ?? '',
        ligne: (json['ligne'] as num?)?.toInt() ?? 0,
        code: json['code'] as String? ?? '',
        libelle: json['libelle'] as String? ?? '',
        colonne: json['colonne'] as String? ?? '',
        typeSaisie: json['type_saisie'] as String? ?? 'nombre',
        choix: <String>[
          for (final valeur in (json['choix'] as List<dynamic>? ?? const []))
            if (valeur is String) valeur,
        ],
        valeur: (json['valeur'] as num?)?.toDouble(),
        texte: json['texte'] as String?,
        commentaire: json['commentaire'] as String?,
      );

  Map<String, dynamic> toPayload() => {
        'etat': etat,
        'cellule': cellule,
        'ligne': ligne,
        'code': code,
        'libelle': libelle,
        'colonne': colonne,
        'type_saisie': typeSaisie,
        'valeur': valeur,
        'texte': texte,
        if (commentaire != null && commentaire!.isNotEmpty)
          'commentaire': commentaire,
      };
}

/// Un état que l'application n'alimente pas, et ses cases à saisir.
class EtatASaisir {
  const EtatASaisir({
    required this.etat,
    required this.intitule,
    required this.cases,
    required this.renseignees,
    this.obligatoire = false,
  });

  final String etat;
  final String intitule;
  final List<CaseFodep> cases;
  final int renseignees;

  /// Vrai pour ce que l'outil ne produira jamais — l'identité de
  /// l'établissement et les signatures. Les autres feuilles sont déjà
  /// déclarées à zéro et ne se complètent que si l'établissement est concerné.
  final bool obligatoire;

  /// Champs groupés par bloc du formulaire, pour l'attestation.
  Map<String, List<CaseFodep>> get parGroupe {
    final groupes = <String, List<CaseFodep>>{};
    for (final case_ in cases) {
      groupes.putIfAbsent(case_.code, () => []).add(case_);
    }
    return groupes;
  }

  /// Cases groupées par ligne du formulaire : une ligne DISPRU porte souvent
  /// plusieurs colonnes, et les séparer les rendrait illisibles.
  Map<int, List<CaseFodep>> get parLigne {
    final groupes = <int, List<CaseFodep>>{};
    for (final case_ in cases) {
      groupes.putIfAbsent(case_.ligne, () => []).add(case_);
    }
    return groupes;
  }

  factory EtatASaisir.fromJson(Map<String, dynamic> json) => EtatASaisir(
        etat: json['etat'] as String? ?? '',
        intitule: json['intitule'] as String? ?? '',
        cases: ((json['cases'] as List<dynamic>?) ?? const [])
            .map((item) => CaseFodep.fromJson(item as Map<String, dynamic>))
            .toList(),
        renseignees: (json['renseignees'] as num?)?.toInt() ?? 0,
        obligatoire: json['obligatoire'] == true,
      );
}

/// Catalogue des cases du FODEP restant à la charge du déclarant.
class SaisiesFodep {
  const SaisiesFodep({
    required this.etats,
    required this.totalCases,
    required this.totalRenseignees,
    this.dateArrete,
  });

  final List<EtatASaisir> etats;
  final int totalCases;
  final int totalRenseignees;

  /// Date d'arrêté retenue par le déclarant lors d'une saisie précédente.
  /// Nulle, l'écran repart de la date de fin du reporting.
  final DateTime? dateArrete;

  factory SaisiesFodep.fromJson(Map<String, dynamic> json) => SaisiesFodep(
        etats: ((json['etats'] as List<dynamic>?) ?? const [])
            .map((item) => EtatASaisir.fromJson(item as Map<String, dynamic>))
            .toList(),
        totalCases: (json['total_cases'] as num?)?.toInt() ?? 0,
        totalRenseignees: (json['total_renseignees'] as num?)?.toInt() ?? 0,
        dateArrete: DateTime.tryParse(json['date_arrete'] as String? ?? ''),
      );
}
