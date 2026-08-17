// Modèles Dart du module Risque Opérationnel.

/// Conversion d'une exigence de fonds propres en équivalent RWA.
///
/// Le dispositif fixe ce multiplicateur à 12,5 dans la définition même du
/// ratio de solvabilité, indépendamment du ratio minimal de 9 % : ce sont deux
/// notions distinctes, et les confondre donne 1/0,09 = 11,11, soit un RWA
/// sous-évalué de 11 %. Le backend et le paramétrage en base appliquent 12,5.
const double kMultiplicateurRwaReglementaire = 12.5;

// SQLite stocke les booléens en INTEGER (0/1) ou parfois REAL (0.0/1.0)
bool _jBool(dynamic v) => v is bool ? v : (v is num ? v != 0 : false);

// ─── Incidents ────────────────────────────────────────────────────────────────

class RoIncident {
  const RoIncident({
    required this.id,
    required this.reference,
    required this.dateOccurrence,
    required this.description,
    required this.ligneMetier,
    required this.typeEvenement,
    required this.causeRacine,
    required this.perteBrute,
    required this.perteRecuperee,
    required this.perteNette,
    required this.statut,
    required this.significatif,
    required this.creeLe,
    required this.modifieLe,
  });

  final String id;
  final String reference;
  final String dateOccurrence;
  final String description;
  final String ligneMetier;
  final String typeEvenement;
  final String causeRacine;
  final double perteBrute;
  final double perteRecuperee;
  final double perteNette;
  final String statut;
  final bool significatif;
  final String creeLe;
  final String modifieLe;

  factory RoIncident.fromJson(Map<String, dynamic> j) => RoIncident(
        id: j['id'] as String,
        reference: j['reference'] as String,
        dateOccurrence: j['date_occurrence'] as String,
        description: j['description'] as String,
        ligneMetier: j['ligne_metier'] as String,
        typeEvenement: j['type_evenement'] as String,
        causeRacine: j['cause_racine'] as String? ?? '',
        perteBrute: (j['perte_brute'] as num?)?.toDouble() ?? 0,
        perteRecuperee: (j['perte_recuperee'] as num?)?.toDouble() ?? 0,
        perteNette: (j['perte_nette'] as num?)?.toDouble() ?? 0,
        statut: j['statut'] as String,
        significatif: _jBool(j['significatif']),
        creeLe: j['cree_le'] as String? ?? '',
        modifieLe: j['modifie_le'] as String? ?? '',
      );
}

// ─── KRI ──────────────────────────────────────────────────────────────────────

class RoKriDefinition {
  const RoKriDefinition({
    required this.id,
    required this.nom,
    required this.unite,
    required this.formule,
    required this.seuilAlerte,
    required this.seuilCritique,
    required this.sens,
    required this.frequence,
  });

  final String id;
  final String nom;
  final String unite;
  final String formule;
  final double seuilAlerte;
  final double seuilCritique;
  final String sens;
  final String frequence;

  factory RoKriDefinition.fromJson(Map<String, dynamic> j) => RoKriDefinition(
        id: j['id'] as String,
        nom: j['nom'] as String,
        unite: j['unite'] as String,
        formule: j['formule'] as String? ?? '',
        seuilAlerte: (j['seuil_alerte'] as num).toDouble(),
        seuilCritique: (j['seuil_critique'] as num).toDouble(),
        sens: j['sens'] as String,
        frequence: j['frequence'] as String,
      );
}

class RoKriValeur {
  const RoKriValeur({
    required this.id,
    required this.kriId,
    required this.dateMesure,
    required this.valeur,
    required this.commentaire,
    required this.creeLe,
  });

  final String id;
  final String kriId;
  final String dateMesure;
  final double valeur;
  final String commentaire;
  final String creeLe;

  factory RoKriValeur.fromJson(Map<String, dynamic> j) => RoKriValeur(
        id: j['id'] as String,
        kriId: j['kri_id'] as String,
        dateMesure: j['date_mesure'] as String,
        valeur: (j['valeur'] as num).toDouble(),
        commentaire: j['commentaire'] as String? ?? '',
        creeLe: j['cree_le'] as String? ?? '',
      );
}

class RoKriView {
  const RoKriView({
    required this.definition,
    required this.derniereValeur,
    required this.derniereDate,
    required this.statut,
    required this.historique,
  });

  final RoKriDefinition definition;
  final double? derniereValeur;
  final String? derniereDate;
  final String statut; // 'normal' | 'alerte' | 'critique' | 'non_renseigne'
  final List<RoKriValeur> historique;

  factory RoKriView.fromJson(Map<String, dynamic> j) => RoKriView(
        definition:
            RoKriDefinition.fromJson(j['definition'] as Map<String, dynamic>),
        derniereValeur: (j['derniere_valeur'] as num?)?.toDouble(),
        derniereDate: j['derniere_date'] as String?,
        statut: j['statut'] as String,
        historique: (j['historique'] as List<dynamic>)
            .map((e) => RoKriValeur.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class RoKriModuleData {
  const RoKriModuleData({required this.kriList, required this.kriHorsSeuil});

  final List<RoKriView> kriList;
  final int kriHorsSeuil;

  factory RoKriModuleData.fromJson(Map<String, dynamic> j) => RoKriModuleData(
        kriList: (j['kri_list'] as List<dynamic>)
            .map((e) => RoKriView.fromJson(e as Map<String, dynamic>))
            .toList(),
        kriHorsSeuil: j['kri_hors_seuil'] as int? ?? 0,
      );
}

// ─── Risques ──────────────────────────────────────────────────────────────────

class RoRisque {
  const RoRisque({
    required this.id,
    required this.nom,
    required this.categorie,
    required this.ligneMetier,
    required this.probabilite,
    required this.impact,
    required this.niveauBrut,
    required this.controleExistant,
    required this.efficaciteControle,
    required this.niveauResiduel,
    required this.niveauLabel,
    required this.planActionRef,
    required this.creeLe,
    required this.modifieLe,
  });

  final String id;
  final String nom;
  final String categorie;
  final String ligneMetier;
  final int probabilite;
  final int impact;
  final int niveauBrut;
  final String controleExistant;
  final int efficaciteControle;
  final double niveauResiduel;
  final String niveauLabel;
  final String planActionRef;
  final String creeLe;
  final String modifieLe;

  factory RoRisque.fromJson(Map<String, dynamic> j) => RoRisque(
        id: j['id'] as String,
        nom: j['nom'] as String,
        categorie: j['categorie'] as String,
        ligneMetier: j['ligne_metier'] as String,
        probabilite: j['probabilite'] as int,
        impact: j['impact'] as int,
        niveauBrut: j['niveau_brut'] as int,
        controleExistant: j['controle_existant'] as String? ?? '',
        efficaciteControle: j['efficacite_controle'] as int,
        niveauResiduel: (j['niveau_residuel'] as num).toDouble(),
        niveauLabel: j['niveau_label'] as String,
        planActionRef: j['plan_action_ref'] as String? ?? '',
        creeLe: j['cree_le'] as String? ?? '',
        modifieLe: j['modifie_le'] as String? ?? '',
      );
}

// ─── Contrôles ────────────────────────────────────────────────────────────────

class RoControle {
  const RoControle({
    required this.id,
    required this.reference,
    required this.perimetre,
    required this.typeControle,
    required this.frequence,
    required this.dateDernierTest,
    required this.prochaineDate,
    required this.resultat,
    required this.tauxConformite,
    required this.pointsConformes,
    required this.pointsControles,
    required this.nonConformites,
    required this.validateur,
    required this.creeLe,
    required this.modifieLe,
  });

  final String id;
  final String reference;
  final String perimetre;
  final String typeControle;
  final String frequence;
  final String dateDernierTest;
  final String prochaineDate;
  final String resultat;
  final double tauxConformite;
  final int pointsConformes;
  final int pointsControles;
  final String nonConformites;
  final String validateur;
  final String creeLe;
  final String modifieLe;

  factory RoControle.fromJson(Map<String, dynamic> j) => RoControle(
        id: j['id'] as String,
        reference: j['reference'] as String,
        perimetre: j['perimetre'] as String,
        typeControle: j['type_controle'] as String,
        frequence: j['frequence'] as String,
        dateDernierTest: j['date_dernier_test'] as String? ?? '',
        prochaineDate: j['prochaine_date'] as String? ?? '',
        resultat: j['resultat'] as String,
        tauxConformite: (j['taux_conformite'] as num?)?.toDouble() ?? 0,
        pointsConformes: j['points_conformes'] as int? ?? 0,
        pointsControles: j['points_controles'] as int? ?? 0,
        nonConformites: j['non_conformites'] as String? ?? '',
        validateur: j['validateur'] as String? ?? '',
        creeLe: j['cree_le'] as String? ?? '',
        modifieLe: j['modifie_le'] as String? ?? '',
      );
}

// ─── Plans d'actions ──────────────────────────────────────────────────────────

class RoPlan {
  const RoPlan({
    required this.id,
    required this.reference,
    required this.titre,
    required this.description,
    required this.typeAction,
    required this.source,
    required this.sourceRef,
    required this.responsable,
    required this.dateDebut,
    required this.dateEcheance,
    required this.joursRestants,
    required this.priorite,
    required this.statut,
    required this.avancement,
    required this.enRetard,
    required this.creeLe,
    required this.modifieLe,
  });

  final String id;
  final String reference;
  final String titre;
  final String description;
  final String typeAction;
  final String source;
  final String sourceRef;
  final String responsable;
  final String dateDebut;
  final String dateEcheance;
  final int joursRestants;
  final String priorite;
  final String statut;
  final int avancement;
  final bool enRetard;
  final String creeLe;
  final String modifieLe;

  factory RoPlan.fromJson(Map<String, dynamic> j) => RoPlan(
        id: j['id'] as String,
        reference: j['reference'] as String,
        titre: j['titre'] as String,
        description: j['description'] as String? ?? '',
        typeAction: j['type_action'] as String,
        source: j['source'] as String,
        sourceRef: j['source_ref'] as String? ?? '',
        responsable: j['responsable'] as String? ?? '',
        dateDebut: j['date_debut'] as String? ?? '',
        dateEcheance: j['date_echeance'] as String? ?? '',
        joursRestants: j['jours_restants'] as int? ?? 0,
        priorite: j['priorite'] as String,
        statut: j['statut'] as String,
        avancement: j['avancement'] as int? ?? 0,
        enRetard: _jBool(j['en_retard']),
        creeLe: j['cree_le'] as String? ?? '',
        modifieLe: j['modifie_le'] as String? ?? '',
      );
}

// ─── Historique ───────────────────────────────────────────────────────────────

class RoHistorique {
  const RoHistorique({
    required this.id,
    required this.dateEvenement,
    required this.utilisateur,
    required this.menu,
    required this.typeAction,
    required this.element,
    required this.ancienneValeur,
    required this.nouvelleValeur,
    required this.commentaire,
  });

  final int id;
  final String dateEvenement;
  final String utilisateur;
  final String menu;
  final String typeAction;
  final String element;
  final String ancienneValeur;
  final String nouvelleValeur;
  final String commentaire;

  factory RoHistorique.fromJson(Map<String, dynamic> j) => RoHistorique(
        id: j['id'] as int,
        dateEvenement: j['date_evenement'] as String,
        utilisateur: j['utilisateur'] as String? ?? 'Système',
        menu: j['menu'] as String,
        typeAction: j['type_action'] as String,
        element: j['element'] as String? ?? '',
        ancienneValeur: j['ancienne_valeur'] as String? ?? '',
        nouvelleValeur: j['nouvelle_valeur'] as String? ?? '',
        commentaire: j['commentaire'] as String? ?? '',
      );
}

// ─── Dashboard ────────────────────────────────────────────────────────────────

class RoDashboardWidget1 {
  const RoDashboardWidget1({
    required this.exigenceFondsPropres,
    required this.aprRisqueOp,
    required this.statutReglementaire,
  });

  final double exigenceFondsPropres;
  final double aprRisqueOp;
  final String statutReglementaire;

  factory RoDashboardWidget1.fromJson(Map<String, dynamic> j) =>
      RoDashboardWidget1(
        exigenceFondsPropres: (j['exigence_fonds_propres'] as num).toDouble(),
        aprRisqueOp: (j['apr_risque_op'] as num).toDouble(),
        statutReglementaire: j['statut_reglementaire'] as String,
      );
}

class RoDashboardWidget2 {
  const RoDashboardWidget2({
    required this.totalIncidentsMois,
    required this.pertesNettesMois,
    required this.incidentsNonClos,
    required this.evolutionPertesPct,
  });

  final int totalIncidentsMois;
  final double pertesNettesMois;
  final int incidentsNonClos;
  final double? evolutionPertesPct;

  factory RoDashboardWidget2.fromJson(Map<String, dynamic> j) =>
      RoDashboardWidget2(
        totalIncidentsMois: j['total_incidents_mois'] as int? ?? 0,
        pertesNettesMois: (j['pertes_nettes_mois'] as num?)?.toDouble() ?? 0,
        incidentsNonClos: j['incidents_non_clos'] as int? ?? 0,
        evolutionPertesPct: (j['evolution_pertes_pct'] as num?)?.toDouble(),
      );
}

class RoDashboardWidget3 {
  const RoDashboardWidget3({
    required this.actionsEnRetard,
    required this.controlesNonConformes,
    required this.kriHorsSeuil,
  });

  final int actionsEnRetard;
  final int controlesNonConformes;
  final int kriHorsSeuil;

  factory RoDashboardWidget3.fromJson(Map<String, dynamic> j) =>
      RoDashboardWidget3(
        actionsEnRetard: j['actions_en_retard'] as int? ?? 0,
        controlesNonConformes: j['controles_non_conformes'] as int? ?? 0,
        kriHorsSeuil: j['kri_hors_seuil'] as int? ?? 0,
      );
}

class RoEvolutionPoint {
  const RoEvolutionPoint({
    required this.mois,
    required this.perteBrute,
    required this.perteNette,
  });

  final String mois;
  final double perteBrute;
  final double perteNette;

  factory RoEvolutionPoint.fromJson(Map<String, dynamic> j) => RoEvolutionPoint(
        mois: j['mois'] as String,
        perteBrute: (j['perte_brute'] as num?)?.toDouble() ?? 0,
        perteNette: (j['perte_nette'] as num?)?.toDouble() ?? 0,
      );
}

class RoRepartitionItem {
  const RoRepartitionItem({required this.label, required this.valeur});

  final String label;
  final int valeur;

  factory RoRepartitionItem.fromJson(Map<String, dynamic> j) =>
      RoRepartitionItem(
        label: j['label'] as String,
        valeur: j['valeur'] as int? ?? 0,
      );
}

class RoDashboardData {
  const RoDashboardData({
    required this.widget1,
    required this.widget2,
    required this.widget3,
    required this.evolutionPertes,
    required this.repartitionLigneMetier,
    required this.repartitionType,
  });

  final RoDashboardWidget1 widget1;
  final RoDashboardWidget2 widget2;
  final RoDashboardWidget3 widget3;
  final List<RoEvolutionPoint> evolutionPertes;
  final List<RoRepartitionItem> repartitionLigneMetier;
  final List<RoRepartitionItem> repartitionType;

  factory RoDashboardData.fromJson(Map<String, dynamic> j) => RoDashboardData(
        widget1:
            RoDashboardWidget1.fromJson(j['widget1'] as Map<String, dynamic>),
        widget2:
            RoDashboardWidget2.fromJson(j['widget2'] as Map<String, dynamic>),
        widget3:
            RoDashboardWidget3.fromJson(j['widget3'] as Map<String, dynamic>),
        evolutionPertes: (j['evolution_pertes'] as List<dynamic>)
            .map((e) => RoEvolutionPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        repartitionLigneMetier: (j['repartition_ligne_metier'] as List<dynamic>)
            .map((e) => RoRepartitionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        repartitionType: (j['repartition_type'] as List<dynamic>)
            .map((e) => RoRepartitionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ─── BIC - Approche Standard CRR3 ────────────────────────────────────────────

class OpRiskInput {
  const OpRiskInput({
    required this.annee,
    this.interetsPercus = 0,
    this.interetsVerses = 0,
    this.revenuLeasing = 0,
    this.dividendesPercus = 0,
    this.autresProduits = 0,
    this.autresCharges = 0,
    this.commissionsPercues = 0,
    this.commissionsVersees = 0,
    this.resPfNegociation = 0,
    this.resPfBancaire = 0,
    this.tresorerie = 0,
    this.creancesEtabCredit = 0,
    this.creancesClientele = 0,
    this.provisions = 0,
    this.pnb = 0,
  });

  final int annee;
  final double interetsPercus;
  final double interetsVerses;
  final double revenuLeasing;
  final double dividendesPercus;
  final double autresProduits;
  final double autresCharges;
  final double commissionsPercues;
  final double commissionsVersees;
  final double resPfNegociation;
  final double resPfBancaire;
  final double tresorerie;
  final double creancesEtabCredit;
  final double creancesClientele;
  final double provisions;
  final double pnb;

  factory OpRiskInput.fromJson(Map<String, dynamic> j) => OpRiskInput(
        annee: j['annee'] as int,
        interetsPercus: (j['interets_percus'] as num? ?? 0).toDouble(),
        interetsVerses: (j['interets_verses'] as num? ?? 0).toDouble(),
        revenuLeasing: (j['revenus_leasing'] as num? ?? 0).toDouble(),
        dividendesPercus: (j['dividendes_percus'] as num? ?? 0).toDouble(),
        autresProduits: (j['autres_produits_exploitation'] as num? ?? 0).toDouble(),
        autresCharges: (j['autres_charges_exploitation'] as num? ?? 0).toDouble(),
        commissionsPercues: (j['commissions_percues'] as num? ?? 0).toDouble(),
        commissionsVersees: (j['commissions_versees'] as num? ?? 0).toDouble(),
        resPfNegociation: (j['resultat_portefeuille_negociation'] as num? ?? 0).toDouble(),
        resPfBancaire: (j['resultat_portefeuille_bancaire'] as num? ?? 0).toDouble(),
        tresorerie: (j['tresorerie_et_banques_centrales'] as num? ?? 0).toDouble(),
        creancesEtabCredit: (j['creances_etablissements_credit'] as num? ?? 0).toDouble(),
        creancesClientele: (j['creances_clientele'] as num? ?? 0).toDouble(),
        provisions: (j['provisions'] as num? ?? 0).toDouble(),
        pnb: (j['pnb'] as num? ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'interets_percus': interetsPercus,
        'interets_verses': interetsVerses,
        'revenus_leasing': revenuLeasing,
        'dividendes_percus': dividendesPercus,
        'autres_produits_exploitation': autresProduits,
        'autres_charges_exploitation': autresCharges,
        'commissions_percues': commissionsPercues,
        'commissions_versees': commissionsVersees,
        'resultat_portefeuille_negociation': resPfNegociation,
        'resultat_portefeuille_bancaire': resPfBancaire,
        'tresorerie_et_banques_centrales': tresorerie,
        'creances_etablissements_credit': creancesEtabCredit,
        'creances_clientele': creancesClientele,
        'provisions': provisions,
        'pnb': pnb,
      };
}

class OpRiskParametres {
  const OpRiskParametres({
    required this.seuilIldc,
    required this.coefTranche1,
    required this.coefTranche2,
    required this.coefTranche3,
    required this.seuil1Fcfa,
    required this.seuil2Fcfa,
    required this.multiplicateurRea,
    required this.tauxConversionEurFcfa,
  });

  final double seuilIldc;
  final double coefTranche1;
  final double coefTranche2;
  final double coefTranche3;
  final double seuil1Fcfa;
  final double seuil2Fcfa;
  final double multiplicateurRea;
  final double tauxConversionEurFcfa;

  factory OpRiskParametres.fromJson(Map<String, dynamic> j) => OpRiskParametres(
        seuilIldc: (j['seuil_ildc'] as num).toDouble(),
        coefTranche1: (j['coef_tranche1'] as num).toDouble(),
        coefTranche2: (j['coef_tranche2'] as num).toDouble(),
        coefTranche3: (j['coef_tranche3'] as num).toDouble(),
        seuil1Fcfa: (j['seuil1_fcfa'] as num).toDouble(),
        seuil2Fcfa: (j['seuil2_fcfa'] as num).toDouble(),
        multiplicateurRea: (j['multiplicateur_rea'] as num).toDouble(),
        tauxConversionEurFcfa: (j['taux_conversion_eur_fcfa'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'seuil_ildc': seuilIldc,
        'coef_tranche1': coefTranche1,
        'coef_tranche2': coefTranche2,
        'coef_tranche3': coefTranche3,
        'seuil1_fcfa': seuil1Fcfa,
        'seuil2_fcfa': seuil2Fcfa,
        'multiplicateur_rea': multiplicateurRea,
        'taux_conversion_eur_fcfa': tauxConversionEurFcfa,
      };
}

class OpRiskIldcDetail {
  const OpRiskIldcDetail({
    required this.ic, required this.ac, required this.plafondIldc,
    required this.plafondActif, required this.dividendes, required this.ildc,
  });
  final double ic, ac, plafondIldc, dividendes, ildc;
  final bool plafondActif;
  factory OpRiskIldcDetail.fromJson(Map<String, dynamic> j) => OpRiskIldcDetail(
        ic: (j['ic'] as num).toDouble(),
        ac: (j['ac'] as num).toDouble(),
        plafondIldc: (j['plafond_ildc'] as num).toDouble(),
        plafondActif: _jBool(j['plafond_actif']),
        dividendes: (j['dividendes'] as num).toDouble(),
        ildc: (j['ildc'] as num).toDouble(),
      );
}

class OpRiskScDetail {
  const OpRiskScDetail({required this.oi, required this.oe,
      required this.fi, required this.fe, required this.sc});
  final double oi, oe, fi, fe, sc;
  factory OpRiskScDetail.fromJson(Map<String, dynamic> j) => OpRiskScDetail(
        oi: (j['oi'] as num).toDouble(), oe: (j['oe'] as num).toDouble(),
        fi: (j['fi'] as num).toDouble(), fe: (j['fe'] as num).toDouble(),
        sc: (j['sc'] as num).toDouble(),
      );
}

class OpRiskFcDetail {
  const OpRiskFcDetail({required this.tc, required this.bc, required this.fc});
  final double tc, bc, fc;
  factory OpRiskFcDetail.fromJson(Map<String, dynamic> j) => OpRiskFcDetail(
        tc: (j['tc'] as num).toDouble(), bc: (j['bc'] as num).toDouble(),
        fc: (j['fc'] as num).toDouble(),
      );
}

class OpRiskBiDetail {
  const OpRiskBiDetail({required this.bi, required this.trancheActive,
      required this.bic, required this.margeAvantTrancheSuivante});
  final double bi, bic;
  final int trancheActive;
  final double? margeAvantTrancheSuivante;
  factory OpRiskBiDetail.fromJson(Map<String, dynamic> j) => OpRiskBiDetail(
        bi: (j['bi'] as num).toDouble(),
        trancheActive: j['tranche_active'] as int,
        bic: (j['bic'] as num).toDouble(),
        margeAvantTrancheSuivante: j['marge_avant_tranche_suivante'] == null
            ? null
            : (j['marge_avant_tranche_suivante'] as num).toDouble(),
      );
}

class OpRiskCalculResult {
  const OpRiskCalculResult({
    required this.annees, required this.inputs, required this.params,
    required this.ildcDetail, required this.scDetail, required this.fcDetail,
    required this.biDetail, required this.ofrCrr3, required this.reaCrr3,
    required this.ofrBia, required this.reaBia, required this.ecart,
    required this.donneesInsuffisantes,
  });

  final List<int> annees;
  final List<OpRiskInput> inputs;
  final OpRiskParametres params;
  final OpRiskIldcDetail ildcDetail;
  final OpRiskScDetail scDetail;
  final OpRiskFcDetail fcDetail;
  final OpRiskBiDetail biDetail;
  final double ofrCrr3, reaCrr3, ofrBia, reaBia, ecart;
  final bool donneesInsuffisantes;

  factory OpRiskCalculResult.fromJson(Map<String, dynamic> j) =>
      OpRiskCalculResult(
        annees: (j['annees'] as List<dynamic>).map((e) => e as int).toList(),
        inputs: (j['inputs'] as List<dynamic>)
            .map((e) => OpRiskInput.fromJson(e as Map<String, dynamic>))
            .toList(),
        params: OpRiskParametres.fromJson(j['params'] as Map<String, dynamic>),
        ildcDetail: OpRiskIldcDetail.fromJson(
            j['ildc_detail'] as Map<String, dynamic>),
        scDetail:
            OpRiskScDetail.fromJson(j['sc_detail'] as Map<String, dynamic>),
        fcDetail:
            OpRiskFcDetail.fromJson(j['fc_detail'] as Map<String, dynamic>),
        biDetail:
            OpRiskBiDetail.fromJson(j['bi_detail'] as Map<String, dynamic>),
        ofrCrr3: (j['ofr_crr3'] as num).toDouble(),
        reaCrr3: (j['rea_crr3'] as num).toDouble(),
        ofrBia: (j['ofr_bia'] as num).toDouble(),
        reaBia: (j['rea_bia'] as num).toDouble(),
        ecart: (j['ecart'] as num).toDouble(),
        donneesInsuffisantes: _jBool(j['donnees_insuffisantes']),
      );
}

// ─── BLOC A1 - AIB ────────────────────────────────────────────────────────────

class PnbAnnuelView {
  const PnbAnnuelView({
    required this.annee, required this.produitBrutTotal, required this.pnbPositif,
    required this.pnbRetenuAib, required this.sourceDocument, required this.modifieLe,
  });
  final int annee;
  final double produitBrutTotal;
  final bool pnbPositif;
  final double pnbRetenuAib;
  final String sourceDocument;
  final String modifieLe;

  factory PnbAnnuelView.fromJson(Map<String, dynamic> j) => PnbAnnuelView(
        annee: j['annee'] as int,
        produitBrutTotal: (j['produit_brut_total'] as num).toDouble(),
        pnbPositif: _jBool(j['pnb_positif']),
        pnbRetenuAib: (j['pnb_retenu_aib'] as num).toDouble(),
        sourceDocument: j['source_document'] as String? ?? '',
        modifieLe: j['modifie_le'] as String? ?? '',
      );
}

class ParametresAib {
  const ParametresAib({required this.alpha, required this.multiplicateurRwa, required this.ratioSolvabiliteMin});
  final double alpha;
  final double multiplicateurRwa;
  final double ratioSolvabiliteMin;

  factory ParametresAib.fromJson(Map<String, dynamic> j) => ParametresAib(
        alpha: (j['alpha'] as num).toDouble(),
        multiplicateurRwa: (j['multiplicateur_rwa'] as num).toDouble(),
        ratioSolvabiliteMin: (j['ratio_solvabilite_min'] as num).toDouble(),
      );
}

class AibCalculResult {
  const AibCalculResult({
    required this.anneesSaisies, required this.n, required this.sommePnbPositifs,
    required this.pnbMoyen, required this.alpha, required this.kIb,
    required this.aprAib, required this.capitalMinAib, required this.donneesInsuffisantes,
  });
  final List<PnbAnnuelView> anneesSaisies;
  final int n;
  final double sommePnbPositifs, pnbMoyen, alpha, kIb, aprAib, capitalMinAib;
  final bool donneesInsuffisantes;

  factory AibCalculResult.fromJson(Map<String, dynamic> j) => AibCalculResult(
        anneesSaisies: (j['annees_saisies'] as List<dynamic>)
            .map((e) => PnbAnnuelView.fromJson(e as Map<String, dynamic>))
            .toList(),
        n: j['n'] as int,
        sommePnbPositifs: (j['somme_pnb_positifs'] as num).toDouble(),
        pnbMoyen: (j['pnb_moyen'] as num).toDouble(),
        alpha: (j['alpha'] as num).toDouble(),
        kIb: (j['k_ib'] as num).toDouble(),
        aprAib: (j['apr_aib'] as num).toDouble(),
        capitalMinAib: (j['capital_min_aib'] as num).toDouble(),
        donneesInsuffisantes: _jBool(j['donnees_insuffisantes']),
      );
}

// ─── BLOC A2 - AS ─────────────────────────────────────────────────────────────

class BetaLigneView {
  const BetaLigneView({required this.ligneMetier, required this.beta, required this.description});
  final String ligneMetier;
  final double beta;
  final String description;

  factory BetaLigneView.fromJson(Map<String, dynamic> j) => BetaLigneView(
        ligneMetier: j['ligne_metier'] as String,
        beta: (j['beta'] as num).toDouble(),
        description: j['description'] as String? ?? '',
      );
}

class PnbParLigneView {
  const PnbParLigneView({
    required this.annee, required this.ligneMetier,
    required this.produitBrutLigne, required this.beta, required this.kLigne,
  });
  final int annee;
  final String ligneMetier;
  final double produitBrutLigne, beta, kLigne;

  factory PnbParLigneView.fromJson(Map<String, dynamic> j) => PnbParLigneView(
        annee: j['annee'] as int,
        ligneMetier: j['ligne_metier'] as String,
        produitBrutLigne: (j['produit_brut_ligne'] as num).toDouble(),
        beta: (j['beta'] as num).toDouble(),
        kLigne: (j['k_ligne'] as num).toDouble(),
      );
}

class ParametresAs {
  const ParametresAs({
    required this.asAutorisee, required this.dateAutorisation,
    required this.referenceAutorisation, required this.multiplicateurRwa,
    required this.ratioSolvabiliteMin,
  });
  final bool asAutorisee;
  final String dateAutorisation, referenceAutorisation;
  final double multiplicateurRwa, ratioSolvabiliteMin;

  factory ParametresAs.fromJson(Map<String, dynamic> j) => ParametresAs(
        asAutorisee: _jBool(j['as_autorisee']),
        dateAutorisation: j['date_autorisation'] as String? ?? '',
        referenceAutorisation: j['reference_autorisation'] as String? ?? '',
        multiplicateurRwa: (j['multiplicateur_rwa'] as num).toDouble(),
        ratioSolvabiliteMin: (j['ratio_solvabilite_min'] as num).toDouble(),
      );
}

class AsLigneDetail {
  const AsLigneDetail({required this.ligneMetier, required this.pnb, required this.beta, required this.kLigne});
  final String ligneMetier;
  final double pnb, beta, kLigne;

  factory AsLigneDetail.fromJson(Map<String, dynamic> j) => AsLigneDetail(
        ligneMetier: j['ligne_metier'] as String,
        pnb: (j['pnb'] as num).toDouble(),
        beta: (j['beta'] as num).toDouble(),
        kLigne: (j['k_ligne'] as num).toDouble(),
      );
}

class AsAnneeDetail {
  const AsAnneeDetail({
    required this.annee,
    required this.lignes,
    required this.kTotal,
    required this.kRetenu,
    required this.renseignee,
  });
  final int annee;
  final List<AsLigneDetail> lignes;
  final double kTotal, kRetenu;

  /// False quand aucun PNB par ligne n'a été saisi pour cet exercice :
  /// l'année est affichée mais exclue du calcul K_AS.
  final bool renseignee;

  factory AsAnneeDetail.fromJson(Map<String, dynamic> j) => AsAnneeDetail(
        annee: j['annee'] as int,
        lignes: (j['lignes'] as List<dynamic>)
            .map((e) => AsLigneDetail.fromJson(e as Map<String, dynamic>))
            .toList(),
        kTotal: (j['k_total'] as num).toDouble(),
        kRetenu: (j['k_retenu'] as num).toDouble(),
        renseignee: j['renseignee'] == null ? true : _jBool(j['renseignee']),
      );
}

class AsCalculResult {
  const AsCalculResult({
    required this.asAutorisee, required this.detailParAnnee,
    required this.kAs, required this.aprAs, required this.capitalMinAs,
    required this.donneesInsuffisantes,
  });
  final bool asAutorisee;
  final List<AsAnneeDetail> detailParAnnee;
  final double kAs, aprAs, capitalMinAs;
  final bool donneesInsuffisantes;

  factory AsCalculResult.fromJson(Map<String, dynamic> j) => AsCalculResult(
        asAutorisee: _jBool(j['as_autorisee']),
        detailParAnnee: (j['detail_par_annee'] as List<dynamic>)
            .map((e) => AsAnneeDetail.fromJson(e as Map<String, dynamic>))
            .toList(),
        kAs: (j['k_as'] as num).toDouble(),
        aprAs: (j['apr_as'] as num).toDouble(),
        capitalMinAs: (j['capital_min_as'] as num).toDouble(),
        donneesInsuffisantes: _jBool(j['donnees_insuffisantes']),
      );
}

// ─── Seuils + Synthèse ────────────────────────────────────────────────────────

class ParametresSeuils {
  const ParametresSeuils({required this.seuilInterne, required this.seuilDirection, required this.seuilConseil});
  final double seuilInterne, seuilDirection, seuilConseil;

  factory ParametresSeuils.fromJson(Map<String, dynamic> j) => ParametresSeuils(
        seuilInterne: (j['seuil_reporting_interne'] as num).toDouble(),
        seuilDirection: (j['seuil_reporting_direction'] as num).toDouble(),
        seuilConseil: (j['seuil_reporting_conseil'] as num).toDouble(),
      );
}

class SyntheseLigne {
  const SyntheseLigne({required this.methode, required this.k, required this.apr, required this.capitalMin, required this.disponible});
  final String methode;
  final double k, apr, capitalMin;
  final bool disponible;

  factory SyntheseLigne.fromJson(Map<String, dynamic> j) => SyntheseLigne(
        methode: j['methode'] as String,
        k: (j['k'] as num).toDouble(),
        apr: (j['apr'] as num).toDouble(),
        capitalMin: (j['capital_min'] as num).toDouble(),
        disponible: _jBool(j['disponible']),
      );
}

class SyntheseResult {
  const SyntheseResult({required this.lignes, required this.ecartBicVsAib, required this.ratioCouverture});
  final List<SyntheseLigne> lignes;
  final double? ecartBicVsAib;
  final double? ratioCouverture;

  factory SyntheseResult.fromJson(Map<String, dynamic> j) => SyntheseResult(
        lignes: (j['lignes'] as List<dynamic>)
            .map((e) => SyntheseLigne.fromJson(e as Map<String, dynamic>))
            .toList(),
        ecartBicVsAib: j['ecart_bic_vs_aib'] != null ? (j['ecart_bic_vs_aib'] as num).toDouble() : null,
        ratioCouverture: j['ratio_couverture'] != null ? (j['ratio_couverture'] as num).toDouble() : null,
      );
}

// ─── Décision de pilotage - Analyse et reporting (dispositif UEMOA) ─────────

class DecisionCritere {
  const DecisionCritere({
    required this.code,
    required this.libelle,
    required this.referenceReglementaire,
    required this.statut,
    required this.poids,
    required this.valeurObservee,
    required this.seuilReference,
    required this.commentaire,
  });

  final String code;
  final String libelle;
  final String referenceReglementaire;
  final String statut; // "conforme" | "attention" | "critique"
  final int poids;
  final String valeurObservee;
  final String seuilReference;
  final String commentaire;

  factory DecisionCritere.fromJson(Map<String, dynamic> j) => DecisionCritere(
        code: j['code'] as String,
        libelle: j['libelle'] as String,
        referenceReglementaire: j['reference_reglementaire'] as String,
        statut: j['statut'] as String,
        poids: (j['poids'] as num).toInt(),
        valeurObservee: j['valeur_observee'] as String,
        seuilReference: j['seuil_reference'] as String,
        commentaire: j['commentaire'] as String,
      );
}

class DecisionPilotageResult {
  const DecisionPilotageResult({
    required this.dateAnalyse,
    required this.niveauGlobal,
    required this.scoreGlobal,
    required this.scoreMax,
    required this.organeReporting,
    required this.organeReportingMotif,
    required this.criteres,
    required this.recommandations,
    required this.synthese,
  });

  final String dateAnalyse;
  final String niveauGlobal;
  final int scoreGlobal;
  final int scoreMax;
  final String organeReporting;
  final String organeReportingMotif;
  final List<DecisionCritere> criteres;
  final List<String> recommandations;
  final String synthese;

  factory DecisionPilotageResult.fromJson(Map<String, dynamic> j) => DecisionPilotageResult(
        dateAnalyse: j['date_analyse'] as String,
        niveauGlobal: j['niveau_global'] as String,
        scoreGlobal: (j['score_global'] as num).toInt(),
        scoreMax: (j['score_max'] as num).toInt(),
        organeReporting: j['organe_reporting'] as String,
        organeReportingMotif: j['organe_reporting_motif'] as String,
        criteres: (j['criteres'] as List<dynamic>)
            .map((e) => DecisionCritere.fromJson(e as Map<String, dynamic>))
            .toList(),
        recommandations: (j['recommandations'] as List<dynamic>).cast<String>(),
        synthese: j['synthese'] as String,
      );
}
