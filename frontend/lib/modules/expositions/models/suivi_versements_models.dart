// Modèles du suivi mensuel des versements et du cycle de vie prudentiel.

/// Un mois de suivi : versement reçu ou impayé.
class SuiviVersement {
  const SuiviVersement({
    required this.periode,
    required this.statut,
    this.montantVerse,
    this.commentaire,
  });

  final String periode;
  final String statut; // 'verse' | 'impaye'
  final double? montantVerse;
  final String? commentaire;

  bool get estVerse => statut == 'verse';

  factory SuiviVersement.fromJson(Map<String, dynamic> json) {
    return SuiviVersement(
      periode: json['periode'] as String,
      statut: json['statut'] as String,
      montantVerse: (json['montant_verse'] as num?)?.toDouble(),
      commentaire: json['commentaire'] as String?,
    );
  }
}

/// Une entrée du journal d'audit du suivi.
class SuiviJournalEntry {
  const SuiviJournalEntry({
    required this.operation,
    required this.creeLe,
    required this.payload,
  });

  final String operation;
  final String creeLe;
  final Map<String, dynamic> payload;

  factory SuiviJournalEntry.fromJson(Map<String, dynamic> json) {
    return SuiviJournalEntry(
      operation: json['operation'] as String,
      creeLe: (json['cree_le'] ?? '') as String,
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
    );
  }
}

/// Vue complète du suivi d'une exposition renvoyée par l'API.
class ExpositionSuivi {
  const ExpositionSuivi({
    required this.exposureId,
    required this.counterpartyName,
    required this.statutPrudentiel,
    required this.joursImpayes,
    required this.joursImpayesSuivis,
    required this.seuilJoursSouffrance,
    required this.declassementManuel,
    this.declassementMotif,
    this.declassementLe,
    required this.periodeCourante,
    this.dateOctroi,
    this.dateEcheance,
    this.maturite,
    this.maturiteResiduelle,
    this.notation,
    this.encours,
    this.montantInitial,
    this.montantHorsBilan,
    this.totalVerse,
    this.ead,
    this.devise,
    this.ponderation,
    this.rwa,
    required this.entries,
    required this.journal,
  });

  final String exposureId;
  final String counterpartyName;
  final String statutPrudentiel; // 'saine' | 'impayee' | 'douteuse'
  final int joursImpayes;
  final bool joursImpayesSuivis;
  final int seuilJoursSouffrance;
  final bool declassementManuel;
  final String? declassementMotif;
  final String? declassementLe;
  final String periodeCourante;
  final String? dateOctroi;
  final String? dateEcheance;
  final double? maturite;
  final double? maturiteResiduelle;
  final String? notation;

  /// Encours bilan restant dû : montant initial moins les versements reçus.
  final double? encours;

  /// Encours bilan d'origine, base immuable de l'amortissement.
  final double? montantInitial;

  /// Engagement hors bilan non tiré : jamais amorti par un versement.
  final double? montantHorsBilan;

  /// Cumul des versements enregistrés sur la ligne.
  final double? totalVerse;

  /// Assiette pondérée : encours bilan + hors bilan après facteur de conversion.
  final double? ead;
  final String? devise;
  final double? ponderation;
  final double? rwa;
  final List<SuiviVersement> entries;
  final List<SuiviJournalEntry> journal;

  bool get isDouteuse => statutPrudentiel == 'douteuse';
  bool get isImpayee => statutPrudentiel == 'impayee';

  /// La ligne porte-t-elle un engagement hors bilan ?
  ///
  /// Sans lui, l'encours bilan suffit à expliquer le RWA ; avec lui, le
  /// panneau doit montrer l'assiette complète sous peine d'afficher un RWA
  /// sans rapport apparent avec l'encours.
  bool get aDuHorsBilan => (montantHorsBilan ?? 0) > 0;

  String get statutLabel {
    switch (statutPrudentiel) {
      case 'douteuse':
        return 'Douteuse';
      case 'impayee':
        return 'Impayée';
      default:
        return 'Saine';
    }
  }

  SuiviVersement? entryForPeriode(String periode) {
    for (final entry in entries) {
      if (entry.periode == periode) {
        return entry;
      }
    }
    return null;
  }

  factory ExpositionSuivi.fromJson(Map<String, dynamic> json) {
    return ExpositionSuivi(
      exposureId: (json['exposure_id'] ?? '') as String,
      counterpartyName: (json['counterparty_name'] ?? '') as String,
      statutPrudentiel: (json['statut_prudentiel'] ?? 'saine') as String,
      joursImpayes: (json['jours_impayes'] as num?)?.toInt() ?? 0,
      joursImpayesSuivis: (json['jours_impayes_suivis'] ?? false) as bool,
      seuilJoursSouffrance:
          (json['seuil_jours_souffrance'] as num?)?.toInt() ?? 90,
      declassementManuel: (json['declassement_manuel'] ?? false) as bool,
      declassementMotif: json['declassement_motif'] as String?,
      declassementLe: json['declassement_le'] as String?,
      periodeCourante: (json['periode_courante'] ?? '') as String,
      dateOctroi: json['date_octroi'] as String?,
      dateEcheance: json['date_echeance'] as String?,
      maturite: (json['maturite'] as num?)?.toDouble(),
      maturiteResiduelle: (json['maturite_residuelle'] as num?)?.toDouble(),
      notation: json['notation'] as String?,
      encours: (json['encours'] as num?)?.toDouble(),
      montantInitial: (json['montant_initial'] as num?)?.toDouble(),
      montantHorsBilan: (json['montant_hors_bilan'] as num?)?.toDouble(),
      totalVerse: (json['total_verse'] as num?)?.toDouble(),
      ead: (json['ead'] as num?)?.toDouble(),
      devise: json['devise'] as String?,
      ponderation: (json['ponderation'] as num?)?.toDouble(),
      rwa: (json['rwa'] as num?)?.toDouble(),
      entries: (json['entries'] as List<dynamic>? ?? const [])
          .map((item) =>
              SuiviVersement.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
      journal: (json['journal'] as List<dynamic>? ?? const [])
          .map((item) => SuiviJournalEntry.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
    );
  }
}
