// Modèles du module ICAAP / PIEAFP.
//
// Le PIEAFP part du Pilier 1 et lui ajoute ce que la formule standard ne capte
// pas. Ce premier écran porte le socle : ce que le dispositif exige, ce que
// l'établissement détient, et l'écart entre les deux.
import '../../dashboard/models/dashboard_models.dart';

const String statutBrouillon = 'brouillon';
const String statutValide = 'valide';
const String statutTransmis = 'transmis';

/// Où en est le cycle annuel du PIEAFP, pour un exercice donné.
class CycleIcaap {
  const CycleIcaap({
    required this.exercice,
    this.statut = statutBrouillon,
    this.dateValidation,
    this.organe = '',
    this.version = 1,
    this.commentaire = '',
  });

  final int exercice;
  final String statut;

  /// Date à laquelle l'organe délibérant a validé. Le rapport PIEAFP est un
  /// document de gouvernance : sans validation, il n'engage personne.
  final String? dateValidation;
  final String organe;
  final int version;
  final String commentaire;

  String get libelleStatut => switch (statut) {
        statutValide => 'Validé par l\'organe délibérant',
        statutTransmis => 'Transmis à la Commission Bancaire',
        _ => 'Brouillon',
      };

  factory CycleIcaap.fromJson(Map<String, dynamic> json) => CycleIcaap(
        exercice: (json['exercice'] as num?)?.toInt() ?? 0,
        statut: json['statut'] as String? ?? statutBrouillon,
        dateValidation: json['date_validation'] as String?,
        organe: json['organe'] as String? ?? '',
        version: (json['version'] as num?)?.toInt() ?? 1,
        commentaire: json['commentaire'] as String? ?? '',
      );
}

/// Ce qu'un type de risque consomme en fonds propres, au titre du Pilier 1.
class ExigenceRisque {
  const ExigenceRisque({
    required this.code,
    required this.libelle,
    required this.apr,
    required this.exigence,
    required this.part,
    required this.anglePilier2,
  });

  final String code;
  final String libelle;

  /// Actifs pondérés. Pour le marché et l'opérationnel, le dispositif (§90)
  /// pose APR = 12,5 × exigence : la conversion est faite en amont.
  final double apr;
  final double exigence;
  final double part;

  /// Ce que le PIEAFP devra examiner en plus de la formule standard.
  final String anglePilier2;

  factory ExigenceRisque.fromJson(Map<String, dynamic> json) => ExigenceRisque(
        code: json['code'] as String? ?? '',
        libelle: json['libelle'] as String? ?? '',
        apr: (json['apr'] as num?)?.toDouble() ?? 0.0,
        exigence: (json['exigence'] as num?)?.toDouble() ?? 0.0,
        part: (json['part'] as num?)?.toDouble() ?? 0.0,
        anglePilier2: json['angle_pilier2'] as String? ?? '',
      );
}

const String situationRespectee = 'respectee';
const String situationSousCoussin = 'sous_coussin';
const String situationDepassee = 'depassee';

/// Un ratio réglementaire, confronté à ses deux seuils.
///
/// Deux seuils, parce que le dispositif en pose deux : le minimum du Titre III
/// (§91), et ce même minimum augmenté du coussin de conservation. C'est le
/// second que l'EP01 de la déclaration mesure — 7,5 %, 8,5 % et 11,5 %.
class NiveauRatio {
  const NiveauRatio({
    required this.code,
    required this.libelle,
    required this.observe,
    required this.minimum,
    required this.exigenceAvecCoussin,
    required this.ecartMinimum,
    required this.ecartAvecCoussin,
    required this.situation,
    required this.fondsPropresRequis,
  });

  final String code;
  final String libelle;

  /// En points de pourcentage (9,0 pour 9 %), comme le reste de l'outil.
  final double observe;
  final double minimum;
  final double exigenceAvecCoussin;
  final double ecartMinimum;
  final double ecartAvecCoussin;
  final String situation;
  final double fondsPropresRequis;

  factory NiveauRatio.fromJson(Map<String, dynamic> json) => NiveauRatio(
        code: json['code'] as String? ?? '',
        libelle: json['libelle'] as String? ?? '',
        observe: (json['observe'] as num?)?.toDouble() ?? 0.0,
        minimum: (json['minimum'] as num?)?.toDouble() ?? 0.0,
        exigenceAvecCoussin:
            (json['exigence_avec_coussin'] as num?)?.toDouble() ?? 0.0,
        ecartMinimum: (json['ecart_minimum'] as num?)?.toDouble() ?? 0.0,
        ecartAvecCoussin:
            (json['ecart_avec_coussin'] as num?)?.toDouble() ?? 0.0,
        situation: json['situation'] as String? ?? situationRespectee,
        fondsPropresRequis:
            (json['fonds_propres_requis'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Le socle à couvrir avant toute exigence interne.
class ExigenceGlobale {
  const ExigenceGlobale({
    required this.aprTotal,
    required this.minimumSolvabilite,
    required this.coussinConservation,
    required this.coussinContracyclique,
    required this.coussinSystemique,
    required this.exigenceGlobale,
    required this.fondsPropresRequis,
    required this.fondsPropresDisponibles,
    required this.marge,
  });

  final double aprTotal;
  final double minimumSolvabilite;
  final double coussinConservation;

  /// Variable, activé par la Banque Centrale selon le cycle du crédit.
  final double coussinContracyclique;

  /// Applicable aux établissements d'importance systémique régionale.
  final double coussinSystemique;

  final double exigenceGlobale;
  final double fondsPropresRequis;
  final double fondsPropresDisponibles;

  /// Positif = matelas au-delà de l'exigence globale ; négatif = déficit.
  final double marge;

  factory ExigenceGlobale.fromJson(Map<String, dynamic> json) =>
      ExigenceGlobale(
        aprTotal: (json['apr_total'] as num?)?.toDouble() ?? 0.0,
        minimumSolvabilite:
            (json['minimum_solvabilite'] as num?)?.toDouble() ?? 0.0,
        coussinConservation:
            (json['coussin_conservation'] as num?)?.toDouble() ?? 0.0,
        coussinContracyclique:
            (json['coussin_contracyclique'] as num?)?.toDouble() ?? 0.0,
        coussinSystemique:
            (json['coussin_systemique'] as num?)?.toDouble() ?? 0.0,
        exigenceGlobale: (json['exigence_globale'] as num?)?.toDouble() ?? 0.0,
        fondsPropresRequis:
            (json['fonds_propres_requis'] as num?)?.toDouble() ?? 0.0,
        fondsPropresDisponibles:
            (json['fonds_propres_disponibles'] as num?)?.toDouble() ?? 0.0,
        marge: (json['marge'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Le Pilier 1 tel que le PIEAFP le prend pour point de départ.
class CapitalReglementaire {
  const CapitalReglementaire({
    required this.cycle,
    required this.fondsPropres,
    required this.exigences,
    required this.aprTotal,
    required this.exigenceTotale,
    required this.ratios,
    required this.exigenceGlobale,
    required this.assietteLevier,
    required this.avertissements,
  });

  final CycleIcaap cycle;
  final FondsPropresDetail fondsPropres;
  final List<ExigenceRisque> exigences;
  final double aprTotal;
  final double exigenceTotale;
  final List<NiveauRatio> ratios;
  final ExigenceGlobale exigenceGlobale;
  final double assietteLevier;

  /// Ce qui empêche de conclure. Le dispositif fait de l'intégrité des données
  /// un point de contrôle explicite : un socle calculé sur une brique absente
  /// doit le dire, pas afficher un zéro crédible.
  final List<String> avertissements;

  factory CapitalReglementaire.fromJson(Map<String, dynamic> json) =>
      CapitalReglementaire(
        cycle: CycleIcaap.fromJson(
            (json['cycle'] as Map<String, dynamic>?) ?? const {}),
        fondsPropres: FondsPropresDetail.fromJson(
            (json['fonds_propres'] as Map<String, dynamic>?) ?? const {}),
        exigences: ((json['exigences'] as List<dynamic>?) ?? const [])
            .map((e) => ExigenceRisque.fromJson(e as Map<String, dynamic>))
            .toList(),
        aprTotal: (json['apr_total'] as num?)?.toDouble() ?? 0.0,
        exigenceTotale: (json['exigence_totale'] as num?)?.toDouble() ?? 0.0,
        ratios: ((json['ratios'] as List<dynamic>?) ?? const [])
            .map((e) => NiveauRatio.fromJson(e as Map<String, dynamic>))
            .toList(),
        exigenceGlobale: ExigenceGlobale.fromJson(
            (json['exigence_globale'] as Map<String, dynamic>?) ?? const {}),
        assietteLevier: (json['assiette_levier'] as num?)?.toDouble() ?? 0.0,
        avertissements: ((json['avertissements'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}
