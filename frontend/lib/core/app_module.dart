import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// Ce fichier decrit les modules disponibles dans l'interface.
/// Enumération des modules disponibles dans l'application.
enum AppModule {
  importations,
  vueEnsemble,
  dashboardCredit,
  expositions,
  rwaEngine,
  crm,
  horsBilan,
  garanties,
  defautsImpayes,
  concentrationCredit,
  reportingCredit,
  risqueMarche,
  risqueMarcheImport,
  risqueMarcheVar,
  risqueMarcheIndicateurs,
  risqueMarcheCourbeTaux,
  risqueMarcheCalculPrudentiel,
  risqueMarcheAmortissementCrd,
  risqueMarchePilotage,
  risqueOperationnel,
  risqueOperationnelImport,
  risqueOperationnelIncidents,
  risqueOperationnelPertes,
  risqueOperationnelHistorique,
  risqueOperationnelReporting,
  risqueOperationnelUemoiCcr3,
  analyse,
  stressTest,
  icap,
  icapCapitalEconomique,
  icapCapitalReglementaire,
  icapAppetenceRisque,
  icapBuffersPrudentiels,
  icapProjectionCapital,
  icapAnalyseSolvabilite,
  icapPlansCapital,
  icapReportingIcaap,
  icapUemoaCemac,
  capitalPlaning,
  referentiels,
  rapports,
}

/// Extension qui expose les titres et sous-titres de chaque module.
extension AppModuleLabel on AppModule {
  String get title {
    switch (this) {
      case AppModule.importations:
        return 'Gestion des imports';
      case AppModule.vueEnsemble:
        return 'Vue d\'ensemble';
      case AppModule.dashboardCredit:
        return 'Dashboard Crédit';
      case AppModule.expositions:
        return 'Risque de crédit';
      case AppModule.rwaEngine:
        return 'Pilotage RWA Crédit';
      case AppModule.crm:
        return 'CRM';
      case AppModule.horsBilan:
        return 'Hors bilan';
      case AppModule.garanties:
        return 'Garanties';
      case AppModule.defautsImpayes:
        return 'Défauts / Impayés';
      case AppModule.concentrationCredit:
        return 'Concentration';
      case AppModule.reportingCredit:
        return 'Reporting';
      case AppModule.risqueMarche:
        return 'Risque du Marché';
      case AppModule.risqueMarcheImport:
        return 'Import données';
      case AppModule.risqueMarcheVar:
        return 'VaR';
      case AppModule.risqueMarcheIndicateurs:
        return 'Indicateurs clés';
      case AppModule.risqueMarcheCourbeTaux:
        return 'Courbe des taux';
      case AppModule.risqueMarcheCalculPrudentiel:
        return 'Calcul Prudentiel';
      case AppModule.risqueMarcheAmortissementCrd:
        return 'Amortissement CRD';
      case AppModule.risqueMarchePilotage:
        return 'Pilotage des Risques';
      case AppModule.risqueOperationnel:
        return 'Dashboard Opérationnel';
      case AppModule.risqueOperationnelImport:
        return 'Import données';
      case AppModule.risqueOperationnelIncidents:
        return 'Incidents';
      case AppModule.risqueOperationnelPertes:
        return 'Pertes opérationnelles';
      case AppModule.risqueOperationnelHistorique:
        return 'Historique événements';
      case AppModule.risqueOperationnelReporting:
        return 'Reporting global';
      case AppModule.risqueOperationnelUemoiCcr3:
        return 'CCR3 / Dispositif UEMOA';
      case AppModule.analyse:
        return 'Analyse';
      case AppModule.stressTest:
        return 'Stress Test';
      case AppModule.icap:
      case AppModule.icapCapitalEconomique:
      case AppModule.icapCapitalReglementaire:
      case AppModule.icapAppetenceRisque:
      case AppModule.icapBuffersPrudentiels:
      case AppModule.icapProjectionCapital:
      case AppModule.icapAnalyseSolvabilite:
      case AppModule.icapPlansCapital:
      case AppModule.icapReportingIcaap:
        return 'ICAAP';
      case AppModule.icapUemoaCemac:
        return 'Spécificités UEMOA / CEMAC';
      case AppModule.capitalPlaning:
        return 'Capital Planning';
      case AppModule.referentiels:
        return 'Paramètres';
      case AppModule.rapports:
        return 'Rapports';
    }
  }

  String get subtitle {
    switch (this) {
      case AppModule.importations:
        return 'Centre unifié pour toutes les importations de données de l\'outil.';
      case AppModule.vueEnsemble:
        return 'Synthèse du module risque de crédit.';
      case AppModule.dashboardCredit:
        return 'Tableau de bord spécifique au pilotage du risque de crédit.';
      case AppModule.expositions:
        return 'Saisie, import, edition et suivi detaille des expositions du portefeuille.';
      case AppModule.rwaEngine:
        return 'Suivi des expositions pondérées et du capital réglementaire.';
      case AppModule.crm:
        return 'Techniques de réduction du risque de crédit, couvertures et scénarios CRM.';
      case AppModule.horsBilan:
        return 'Pilotage des engagements hors bilan, CCF, EAD et capital associé.';
      case AppModule.garanties:
        return 'Inventaire des garanties, couvertures et statuts relies aux expositions.';
      case AppModule.defautsImpayes:
        return 'Suivi des retards, incidents prudentiels et provisions estimées.';
      case AppModule.concentrationCredit:
        return 'Analyse des concentrations sectorielles, geographiques et des plus fortes expositions.';
      case AppModule.reportingCredit:
        return 'Exports et rapports de portefeuille, garanties et defauts.';
      case AppModule.risqueMarche:
        return 'Evaluation des tensions de marché et des risques associés au portefeuille.';
      case AppModule.risqueMarcheImport:
        return 'Importation des fichiers nécessaires aux calculs de risque de marché.';
      case AppModule.risqueMarcheVar:
        return 'Value at Risk.';
      case AppModule.risqueMarcheIndicateurs:
        return 'Synthèse des indicateurs clés du portefeuille de marché.';
      case AppModule.risqueMarcheCourbeTaux:
        return "Courbes de taux UEMOA et CEMAC utilisées pour l'actualisation.";
      case AppModule.risqueMarcheCalculPrudentiel:
        return 'Calcul réglementaire et simulation des exigences en fonds propres.';
      case AppModule.risqueMarcheAmortissementCrd:
        return 'Evolution mensuelle du capital restant dû et des amortissements.';
      case AppModule.risqueMarchePilotage:
        return 'Tableau de bord, indicateurs, VaR et courbe des taux.';
      case AppModule.risqueOperationnel:
        return 'Vue d\'ensemble des KPI réglementaires et alertes opérationnelles.';
      case AppModule.risqueOperationnelImport:
        return 'Importation des pertes opérationnelles depuis un fichier Excel (.xlsx).';
      case AppModule.risqueOperationnelIncidents:
        return 'Déclaration et suivi des incidents opérationnels (Art. 313.b).';
      case AppModule.risqueOperationnelPertes:
        return 'Pertes, KRI, cartographie, contrôles, workflow et plans d\'actions (Art. 89).';
      case AppModule.risqueOperationnelHistorique:
        return 'Traçabilité complète de toutes les actions et modifications (Art. 314).';
      case AppModule.risqueOperationnelReporting:
        return 'Génération automatique du rapport réglementaire consolidé (Dashboard, Crédit, Marché, Opérationnel).';
      case AppModule.risqueOperationnelUemoiCcr3:
        return 'CCR3-COREP (BIC) et dispositif UEMOA : Indicateur de Base, Approche Standard et synthèse.';
      case AppModule.analyse:
        return 'Conseils et recommandations basés sur les expositions et les risques.';
      case AppModule.stressTest:
        return 'Simulation de chocs et scénarios adverses sur le portefeuille et le capital.';
      case AppModule.icap:
      case AppModule.icapCapitalEconomique:
      case AppModule.icapCapitalReglementaire:
      case AppModule.icapAppetenceRisque:
      case AppModule.icapBuffersPrudentiels:
      case AppModule.icapProjectionCapital:
      case AppModule.icapAnalyseSolvabilite:
      case AppModule.icapPlansCapital:
      case AppModule.icapReportingIcaap:
        return "Evaluation interne de l'adéquation du capital et des besoins de solvabilité.";
      case AppModule.icapUemoaCemac:
        return 'Comparaison des specificites reglementaires BCEAO (UEMOA) et COBAC (CEMAC).';
      case AppModule.capitalPlaning:
        return 'Projection du capital, des besoins prudentiels et des marges de manoeuvre.';
      case AppModule.referentiels:
        return 'Référentiels, tables RW, CCF et notations de calcul.';
      case AppModule.rapports:
        return 'Generation de rapports de synthese, details et exports metier.';
    }
  }

  IconData get icon {
    switch (this) {
      case AppModule.importations:
        return Icons.cloud_upload_outlined;
      case AppModule.vueEnsemble:
        return Icons.pie_chart_rounded;
      case AppModule.dashboardCredit:
        return Icons.dashboard_outlined;
      case AppModule.expositions:
        return Icons.credit_card_rounded;
      case AppModule.rwaEngine:
        return Icons.account_balance_rounded;
      case AppModule.crm:
        return Icons.verified_user_rounded;
      case AppModule.horsBilan:
        return Icons.file_copy_rounded;
      case AppModule.garanties:
        return Icons.verified_user_rounded;
      case AppModule.defautsImpayes:
        return Icons.warning_rounded;
      case AppModule.concentrationCredit:
        return Icons.center_focus_strong_rounded;
      case AppModule.reportingCredit:
        return Icons.summarize_rounded;
      case AppModule.risqueMarche:
        return Icons.show_chart_rounded;
      case AppModule.risqueMarcheImport:
        return CupertinoIcons.doc_text_fill;
      case AppModule.risqueMarcheVar:
        return Icons.multiline_chart_rounded;
      case AppModule.risqueMarcheIndicateurs:
        return CupertinoIcons.chart_bar_alt_fill;
      case AppModule.risqueMarcheCourbeTaux:
        return CupertinoIcons.waveform_path_ecg;
      case AppModule.risqueMarcheCalculPrudentiel:
        return Icons.calculate_rounded;
      case AppModule.risqueMarcheAmortissementCrd:
        return CupertinoIcons.graph_square_fill;
      case AppModule.risqueMarchePilotage:
        return Icons.dashboard_rounded;
      case AppModule.risqueOperationnel:
        return Icons.dashboard_outlined;
      case AppModule.risqueOperationnelImport:
        return Icons.upload_file_outlined;
      case AppModule.risqueOperationnelIncidents:
        return Icons.report_gmailerrorred_rounded;
      case AppModule.risqueOperationnelPertes:
        return Icons.monetization_on_outlined;
      case AppModule.risqueOperationnelHistorique:
        return Icons.schedule_rounded;
      case AppModule.risqueOperationnelReporting:
        return Icons.summarize_outlined;
      case AppModule.risqueOperationnelUemoiCcr3:
        return Icons.policy_outlined;
      case AppModule.analyse:
        return Icons.analytics_rounded;
      case AppModule.stressTest:
        return Icons.speed_rounded;
      case AppModule.icap:
      case AppModule.icapCapitalEconomique:
      case AppModule.icapCapitalReglementaire:
      case AppModule.icapAppetenceRisque:
      case AppModule.icapBuffersPrudentiels:
      case AppModule.icapProjectionCapital:
      case AppModule.icapAnalyseSolvabilite:
      case AppModule.icapPlansCapital:
      case AppModule.icapReportingIcaap:
        return Icons.account_balance_rounded;
      case AppModule.icapUemoaCemac:
        return Icons.compare_arrows_rounded;
      case AppModule.capitalPlaning:
        return Icons.open_in_new_rounded;
      case AppModule.referentiels:
        return Icons.tune_rounded;
      case AppModule.rapports:
        return Icons.description_rounded;
    }
  }
}
