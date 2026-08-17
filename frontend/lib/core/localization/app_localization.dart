import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_language.dart';

class AppLocalizationScope
    extends InheritedNotifier<ValueNotifier<AppLanguage>> {
  const AppLocalizationScope({
    super.key,
    required ValueNotifier<AppLanguage> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AppLanguage of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppLocalizationScope>();
    return scope?.notifier?.value ?? AppLocalizations.currentLanguage;
  }

  static ValueNotifier<AppLanguage>? maybeNotifierOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppLocalizationScope>();
    return scope?.notifier;
  }
}

class AppLocalizations {
  AppLocalizations._();

  static AppLanguage _currentLanguage = AppLanguage.francais;

  static AppLanguage get currentLanguage => _currentLanguage;

  static bool get isEnglish => _currentLanguage == AppLanguage.anglais;

  static void setCurrentLanguage(AppLanguage language) {
    if (_currentLanguage == language &&
        Intl.defaultLocale == language.intlLocale) {
      return;
    }
    _currentLanguage = language;
    Intl.defaultLocale = language.intlLocale;
  }

  static String translate(
    String source, {
    AppLanguage? language,
    Map<String, Object?> args = const {},
  }) {
    final activeLanguage = language ?? _currentLanguage;
    final resolved = switch (activeLanguage) {
      AppLanguage.francais => _frenchTranslations[source] ?? source,
      AppLanguage.anglais => _englishTranslations[source] ?? source,
    };

    if (args.isEmpty) {
      return resolved;
    }

    var output = resolved;
    args.forEach((key, value) {
      output = output.replaceAll('{{$key}}', value?.toString() ?? '');
    });
    return output;
  }
}

extension AppLocalizationContext on BuildContext {
  AppLanguage get appLanguage => AppLocalizationScope.of(this);

  String tr(
    String source, {
    Map<String, Object?> args = const {},
  }) {
    return AppLocalizations.translate(
      source,
      language: appLanguage,
      args: args,
    );
  }
}

extension AppLocalizationString on String {
  String tr(
    BuildContext context, {
    Map<String, Object?> args = const {},
  }) {
    return context.tr(this, args: args);
  }
}

const Map<String, String> _englishTranslations = {
  'Dashboard': 'Dashboard',
  'Vue d\'ensemble': 'Overview',
  'Tableau de bord': 'Dashboard',
  'Expositions': 'Exposures',
  'Risque de crédit': 'Credit risk',
  'Données de Marché': 'Market Data',
  'Données de mrché': 'Market Data',
  'Marché': 'Market',
  'Échéanciers & Flux': 'Schedules & Cash Flows',
  'Analyse & Risques': 'Analysis & Risk',
  'Stress Tests': 'Stress Tests',
  'Stress tests': 'Stress tests',
  'Stress test': 'Stress test',
  'ICAP': 'ICAP',
  'Capital planing': 'Capital planning',
  'Simulation': 'Simulation',
  'Référentiels': 'Reference Data',
  'Referentiels': 'Reference Data',
  'Pilotage global des encours, RWA, capital et couverture CRM.':
      'Global monitoring of exposures, RWA, capital and CRM coverage.',
  'Saisie, import, edition et suivi detaille des expositions du portefeuille.':
      'Capture, import, editing and detailed monitoring of portfolio exposures.',
  'Suivi des paramètres de marché utiles aux valorisations, stress et simulations.':
      'Monitoring market parameters used for valuation, stress and simulations.',
  'Vision des flux attendus, maturités et échéanciers de portefeuille.':
      'View of expected cash flows, maturities and portfolio schedules.',
  'Analyse du risque, des garanties et des impacts RWA.':
      'Analysis of risk, collateral and RWA impacts.',
  'Stress tests prudentiels et sensibilités du portefeuille.':
      'Prudential stress tests and portfolio sensitivities.',
  'Simulation de chocs et scénarios adverses sur le portefeuille et le capital.':
      'Simulation of shocks and adverse scenarios on the portfolio and capital.',
  'Evaluation interne de l’adéquation du capital et des besoins de solvabilité.':
      'Internal assessment of capital adequacy and solvency needs.',
  'Projection du capital, des besoins prudentiels et des marges de manoeuvre.':
      'Projection of capital, prudential requirements and management headroom.',
  'Simulation de scénarios RWA et capital minimum.':
      'Simulation of RWA scenarios and minimum capital.',
  'Référentiels, tables RW, CCF et notations de calcul.':
      'Reference data, RW tables, CCFs and rating grids.',
  'Navigation': 'Navigation',
  'Service': 'Service',
  'RWA Crédit': 'RWA Credit',
  'Outil de pilotage des fonds propres': 'Capital steering tool',
  'Passer en mode clair': 'Switch to light mode',
  'Passer en mode sombre': 'Switch to dark mode',
  "Devise d'affichage du portefeuille": 'Portfolio display currency',
  'XOF - FCFA BCEAO': 'XOF - BCEAO CFA franc',
  'EUR - Euro': 'EUR - Euro',
  'USD - Dollar americain': 'USD - US dollar',
  'Langue': 'Language',
  'Français': 'French',
  'Anglais': 'English',
  'Exporter': 'Export',
  'Nouvelle analyse': 'New analysis',
  'Portefeuille CRM': 'CRM portfolio',
  'Rechercher...': 'Search...',
  'RWA Avant': 'RWA before',
  'Avant mitigation': 'Before mitigation',
  'RWA Apres': 'RWA after',
  'Apres mitigation': 'After mitigation',
  'Couverture CRM': 'CRM coverage',
  'Moyenne portefeuille': 'Portfolio average',
  'Scenario': 'Scenario',
  'Aucun scenario CRM disponible.': 'No CRM scenario available.',
  'RW final {{value}}': 'Final RW {{value}}',
  'Emprunteur': 'Borrower',
  'Garant': 'Guarantor',
  'RW = {{value}}': 'RW = {{value}}',
  'ID': 'ID',
  'Couverture': 'Coverage',
  'RW Avant': 'RW Before',
  'RW Final': 'RW Final',
  'Economie Capital': 'Capital saving',
  'Tables de pondération, Credit Conversion Factors et notations de calcul.':
      'Weighting tables, Credit Conversion Factors and rating scales.',
  'Tables des Ponderations': 'Weight tables',
  'Segment': 'Segment',
  'Notation': 'Rating',
  'RW': 'RW',
  'Approche': 'Approach',
  'Tables des Credit Conversion Factors': 'Credit Conversion Factor tables',
  "Nature d'Engagement": 'Commitment type',
  'CCF': 'CCF',
  'Echelle des Notations': 'Rating scale',
  'Description': 'Description',
  'Suivi des taux, spreads, devises et paramètres externes utilisés dans les analyses.':
      'Monitoring rates, spreads, currencies and external parameters used in analysis.',
  'Indicateurs clés': 'Key indicators',
  'Courbe taux': 'Rate curve',
  'Point 10Y actualisé': 'Latest 10Y point',
  'Spread crédit': 'Credit spread',
  'Segment corporate': 'Corporate segment',
  'Taux spot': 'Spot rate',
  'Jeux de données suivis': 'Tracked datasets',
  'Courbes souveraines': 'Sovereign curves',
  'Disponible': 'Available',
  'Provider interne': 'Internal provider',
  'Spreads bancaires': 'Banking spreads',
  'Mis à jour': 'Updated',
  'Feed marché': 'Market feed',
  'FX & inflation': 'FX & inflation',
  'Banque centrale': 'Central bank',
  'Visualisation des maturités, remboursements, flux futurs et jalons du portefeuille.':
      'Visualization of maturities, repayments, future cash flows and portfolio milestones.',
  'Vue maturité': 'Maturity view',
  '0 - 3 mois': '0 - 3 months',
  '3 - 12 mois': '3 - 12 months',
  '1 - 5 ans': '1 - 5 years',
  '5 ans +': '5+ years',
  'Prochains flux': 'Upcoming cash flows',
  'Coupon obligataire': 'Bond coupon',
  'Amortissement prêt': 'Loan amortization',
  'Flux CRM attendu': 'Expected CRM flow',
  'Construction de scenarios RWA, CRM et capital minimum.':
      'Build RWA, CRM and minimum capital scenarios.',
  'Scenarios disponibles': 'Available scenarios',
  'Variation RW': 'RW variation',
  'Simuler une hausse ou baisse des ponderations.':
      'Simulate higher or lower risk weights.',
  'Effet CRM': 'CRM effect',
  'Tester une couverture garantie supplementaire.':
      'Test additional collateral coverage.',
  'Capital': 'Capital',
  'Mesurer l impact sur le capital minimum.':
      'Measure the impact on minimum capital.',
  'Sensibilites portefeuille sur notation, CCF, garanties et capital.':
      'Portfolio sensitivities on ratings, CCF, collateral and capital.',
  'Axes de stress': 'Stress axes',
  'Degradation notation': 'Rating downgrade',
  'Tester une migration adverse des contreparties.':
      'Test an adverse migration of counterparties.',
  'Hausse CCF': 'CCF increase',
  'Mesurer l effet des engagements hors bilan.':
      'Measure the effect of off-balance-sheet commitments.',
  'Choc capital': 'Capital shock',
  'Evaluer la sensibilite du ratio de solvabilite.':
      'Assess solvency ratio sensitivity.',
  'Choisir une date de reférence': 'Choose a reference date',
  'Dernière évaluation': 'Last valuation',
  'Vue d\'ensemble du portefeuille': 'Portfolio Overview',
  'Vue synthèse du portefeuille, des RWA et du capital prudentiel.':
      'Summary view of the portfolio, RWA and prudential capital.',
  'Import Excel impossible': 'Excel import failed',
  'Feuilles manquantes': 'Missing sheets',
  'Colonnes manquantes': 'Missing columns',
  'Indicateurs manquants': 'Missing indicators',
  'Points à corriger': 'Items to fix',
  'Colonnes détectées dans le fichier': 'Columns detected in the file',
  'Feuilles détectées dans le fichier': 'Sheets detected in the file',
  'Noms de feuilles attendus': 'Expected sheet names',
  'Colonnes attendues par feuille': 'Expected columns by sheet',
  'Indicateurs attendus': 'Expected indicators',
  'Fermer': 'Close',
  'Exposition totale brute': 'Gross exposure',
  'Risque residuel': 'Residual risk',
  'Exposition brute - Garanties': 'Gross exposure - Guarantees',
  'RWA crédit': 'Total RWA',
  'Capital minimum requis': 'Minimum capital required',
  'Ratio de solvabilite': 'Solvency ratio',
  'Densité RWA': 'RWA density',
  'Taux de défaut': 'Default rate',
  'Encours de défaut / Exposition brute':
      'Defaulted outstanding / Gross exposure',
  'Densité RWA du portefeuille': 'Portfolio RWA density',
  'RWA crédit / Exposition totale brute': 'Total RWA / Gross exposure',
  'RWA / Exposition brute': 'RWA / Gross exposure',
  'Risque faible': 'Low risk',
  'Risque moyen': 'Medium risk',
  'Monthly': 'Monthly',
  'Quarterly': 'Quarterly',
  'Yearly': 'Yearly',
  'Projection': 'Projection',
  'Unité: {{value}}': 'Unit: {{value}}',
  'milliards {{currency}}': 'billions {{currency}}',
  'millions {{currency}}': 'millions {{currency}}',
  'milliers {{currency}}': 'thousands {{currency}}',
  'Top 5 du RWA crédit par catégorie': 'Top 5 total RWA by category',
  'Top 5 de l\'exposition totale brute': 'Top 5 gross exposures',
  "Repartition de l'exposition par catégorie": 'Exposure breakdown by category',
  "Lecture directe de l'exposition brute et du RWA par segment d'exposition.":
      'Direct view of gross exposure and RWA by exposure segment.',
  'Répartition totale par type de CRM': 'Total breakdown by CRM type',
  'Attenuation du risque de crédit ( CRM )': 'Credit risk mitigation (CRM)',
  'Qualité de crédit moyenne du portefeuille':
      'Average portfolio credit quality',
  'Vue dynamique de la qualité de crédit à travers le risque pondéré moyen':
      'Dynamic view of credit quality through average risk weighting',
  'Aucune catégorie disponible': 'No category available',
  'Qualité bonne': 'Good quality',
  'Qualité moyenne': 'Balanced quality',
  'Qualité élevée': 'High pressure',
  'Qualité excellente': 'Excellent quality',
  'Qualité faible': 'Weak quality',
  'Strong quality': 'Strong quality',
  'Balanced quality': 'Balanced quality',
  'Higher pressure': 'Higher pressure',
  'Faible': 'Low',
  'Moyen': 'Medium',
  'Élevé': 'High',
  'peu risqué': 'low risk',
  'normal': 'normal',
  'alerte': 'alert',
  'Risque faible (densité)': 'Low risk',
  'Risque moyen (densité)': 'Medium risk',
  'Risque élevé (densité)': 'High risk',
  'Risque élevé': 'High risk',
  'Interprétation': 'Interpretation',
  'Actuel': 'Current',
  'Astuce': 'Tip',
  'Org. publics': 'Public bodies',
  'Institutions fin.': 'Financial inst.',
  'Clientèle détail': 'Retail',
  'Immo R': 'Res. RE',
  'Immo C': 'Comm. RE',
  'En souffrance': 'Past due',
  'Le risque faible désigne un portefeuille dont la consommation en RWA reste modérée. Il traduit en général une qualité de crédit saine et une pression limitée sur le capital réglementaire.':
      'Low risk refers to a portfolio whose RWA consumption remains moderate. It usually reflects sound credit quality and limited pressure on regulatory capital.',
  'Maintenir la qualité des contreparties, préserver les garanties efficaces et suivre les concentrations par secteur.':
      'Maintain counterparty quality, preserve effective collateral, and monitor sector concentrations.',
  'Le risque moyen correspond à une situation équilibrée, mais plus sensible aux variations de qualité de crédit. Il nécessite une surveillance régulière car les RWA peuvent augmenter plus rapidement en cas de dégradation.':
      'Medium risk reflects a balanced situation, but one that is more sensitive to changes in credit quality. It requires regular monitoring because RWAs can rise faster in the event of deterioration.',
  'Renforcer le suivi des expositions sensibles, revoir les couvertures disponibles et anticiper les besoins en capital.':
      'Strengthen monitoring of sensitive exposures, review available coverage, and anticipate capital needs.',
  'Le risque élevé décrit un portefeuille plus exigeant en capital et plus exposé aux détériorations de notation. Il signale une vulnérabilité accrue et appelle une attention prioritaire sur les expositions concernées.':
      'High risk describes a portfolio that is more capital-intensive and more exposed to rating deterioration. It signals greater vulnerability and calls for priority attention on the exposures concerned.',
  'Prioriser les actions de réduction de RWA, sécuriser les expositions les plus lourdes et renforcer rapidement les mécanismes de couverture.':
      'Prioritize RWA reduction actions, secure the heaviest exposures, and quickly strengthen coverage mechanisms.',
  'souverains': 'sovereigns',
  'organismes pub. hors Adm c':
      'public-sector entities outside central administration',
  'Expositions sur les BMD': 'MDB exposures',
  'institutions financières': 'financial institutions',
  'entreprises': 'corporates',
  'clientèle de détail': 'retail',
  "prêts garantis par l'immo R": 'residential real-estate secured loans',
  "prêts garantis par l'immo C": 'commercial real-estate secured loans',
  'créances en souffrance': 'past-due exposures',
  'créances à risque élevé': 'high-risk exposures',
  'autres actifs': 'other assets',
  'Hors bilan': 'Off-balance sheet',
  'CRM financee': 'Funded CRM',
  'CRM non financee': 'Unfunded CRM',
  'Parametres de la surete financee': 'Funded collateral parameters',
  'Parametres de la garantie non financee': 'Unfunded guarantee parameters',
  'Financée': 'Funded',
  'Non financée': 'Unfunded',
  'Aucune': 'None',
  'Saisissez, importez et suivez les expositions avec calcul automatique des zones UEMOA/CEMAC.':
      'Capture, import and monitor exposures with automatic UEMOA/CEMAC zone calculation.',
  "Renseignez la contrepartie, les montants, le traitement CRM et les impacts prudentiels avant d'enregistrer l'exposition.":
      'Capture the counterparty, amounts, CRM treatment and prudential impacts before saving the exposure.',
  'Créer une exposition': 'Create exposure',
  'Supprimer la sélection': 'Delete selection',
  'Importation...': 'Importing...',
  'Import': 'Import',
  'Export': 'Export',
  '{{count}} sélectionnée(s)': '{{count}} selected',
  'Périmètre filtré': 'Filtered scope',
  'Capital requis': 'Required capital',
  'Exigence réglementaire': 'Regulatory requirement',
  'Aperçu': 'Overview',
  "Vue d'ensemble du dossier": 'Exposure overview',
  'Repères prudentiels et indicateurs RWA':
      'Prudential reference points and RWA indicators',
  'Identité': 'Identity',
  'Identification de la contrepartie': 'Counterparty identification',
  'Classe prudentielle et pondération': 'Prudential class and risk weighting',
  'Finance': 'Finance',
  'Paramètres financiers': 'Financial parameters',
  'Montants, ventilation et devise': 'Amounts, split and currency',
  'CRM ?': 'CRM?',
  "Présence d'une CRM": 'CRM presence',
  'Vérification de la protection de crédit': 'Credit risk mitigation check',
  'Mécanisme de CRM': 'CRM mechanism',
  'Garantie, sûreté ou substitution de risque':
      'Guarantee, collateral or risk substitution',
  'Analyse': 'Review',
  'Commentaires et points d\'attention': 'Comments and attention points',
  'Observations métier et validation interne':
      'Business observations and internal validation',
  'Valider': 'Validate',
  'Contrôler puis enregistrer l\'exposition': 'Review and save the exposure',
  'Contrepartie': 'Counterparty',
  'Nom ou raison sociale': 'Name or legal entity',
  'Pays': 'Country',
  'Pays de résidence': 'Country of residence',
  'Tous': 'All',
  'Catégorie': 'Category',
  'Toutes': 'All',
  'Zone': 'Zone',
  'Hors zone': 'Outside zone',
  'Type CRM': 'CRM type',
  'Exposition ajoutee avec succes.': 'Exposure added successfully.',
  'Exposition mise a jour.': 'Exposure updated.',
  "Mettre à jour l'exposition": 'Update exposure',
  'Ajouter': 'Add',
  "Enregistrer l'exposition": 'Save exposure',
  'Enregistrer les modifications': 'Save changes',
  'Suppression impossible:': 'Deletion failed:',
  'Confirmer la suppression': 'Confirm deletion',
  'Cette action supprimera l exposition selectionnee dans le tableau et dans la base locale.':
      'This action will delete the selected exposure from the table and the local database.',
  'Cette action supprimera les expositions selectionnees dans le tableau et dans la base locale.':
      'This action will delete the selected exposures from the table and the local database.',
  'Annuler': 'Cancel',
  'Supprimer': 'Delete',
  '{{count}} exposition(s) supprimee(s) du tableau et de la base locale.':
      '{{count}} exposure(s) deleted from the table and the local database.',
  '{{deleted}} exposition(s) supprimee(s). {{missing}} introuvable(s): {{ids}}.':
      '{{deleted}} exposure(s) deleted. {{missing}} missing: {{ids}}.',
  'Aucune suppression effectuee. IDs introuvables: {{ids}}.':
      'No deletion performed. Missing IDs: {{ids}}.',
  'Aucune exposition supprimee.': 'No exposure deleted.',
  'Vue exportee au format CSV dans le presse-papiers.':
      'View exported as CSV to the clipboard.',
  'Importer Excel/CSV': 'Import Excel/CSV',
  'Selectionnez un classeur .xlsx ou collez un CSV/TSV, verifiez les lignes detectees, puis validez l import.':
      'Select an .xlsx workbook or paste CSV/TSV content, review the detected rows, then confirm the import.',
  'Importation du fichier Excel en cours...':
      'Excel file import in progress...',
  'Importation des donnees en cours...': 'Data import in progress...',
  'Aucune ligne exploitable detectee dans ce classeur. Verifiez que le fichier utilise le modele Excel RWA avec la feuille "Template donnees".':
      'No usable row detected in this workbook. Make sure the file uses the RWA Excel template with the "Template donnees" sheet.',
  '{{count}} ligne(s) detectee(s) dans {{filename}}.':
      '{{count}} row(s) detected in {{filename}}.',
  'Apercu Excel impossible. Le fichier doit etre un .xlsx au format du modele RWA.':
      'Excel preview failed. The file must be an .xlsx using the RWA template format.',
  'Apercu Excel impossible: {{error}}': 'Excel preview failed: {{error}}',
  'Choisir un fichier .xlsx': 'Choose an .xlsx file',
  'CSV/TSV lu, mais aucune ligne exploitable detectee. Colonnes minimales: contrepartie, pays, categorie, notation, montant.':
      'CSV/TSV read, but no usable row detected. Minimum columns: counterparty, country, category, rating, amount.',
  'Lecture CSV/TSV impossible: {{error}}': 'CSV/TSV read failed: {{error}}',
  'Choisir un CSV/TSV': 'Choose a CSV/TSV file',
  '{{count}} ligne(s) detectee(s)': '{{count}} row(s) detected',
  '{{count}} ligne(s) detectee(s) dans le texte colle.':
      '{{count}} row(s) detected in the pasted text.',
  'id;contrepartie;pays;categorie;notation;montant;placement;type_engagement;crm;devise;couverture':
      'id;counterparty;country;category;rating;amount;booking;commitment_type;crm;currency;coverage',
  '{{imported}} ligne(s) importee(s), dont {{off_balance}} hors bilan.':
      '{{imported}} row(s) imported, including {{off_balance}} off-balance-sheet.',
  'Importation impossible: {{error}}': 'Import failed: {{error}}',
  'Importer': 'Import',
  'Excel': 'Excel',
  'CSV': 'CSV',
  '{{count}} exposition(s) importee(s) depuis {{filename}}.':
      '{{count}} exposure(s) imported from {{filename}}.',
  'Aucune exposition detectee dans le fichier selectionne.':
      'No exposure detected in the selected file.',
  'Apercu Excel': 'Excel preview',
  'Aucune ligne detectee. Verifiez les en-tetes: contrepartie, pays, categorie, notation, montant.':
      'No row detected. Check the headers: counterparty, country, category, rating, amount.',
  'Collez des donnees avec une ligne d en-tetes ou choisissez un fichier CSV/TSV pour afficher l apercu.':
      'Paste data with a header row or choose a CSV/TSV file to display the preview.',
  'Apercu CSV/TSV': 'CSV/TSV preview',
  'Fiche exposition': 'Exposure form',
  'CRM': 'CRM',
  'Commentaire': 'Comment',
  'RW brut': 'Gross RW',
  'EAD': 'EAD',
  'RW final': 'Final RW',
  'Pondération de la contrepartie (RW)': 'Counterparty risk weight (RW)',
  'RWA': 'RWA',
  'Verifier les montants saisis.': 'Please verify the entered amounts.',
  'Echec de l enregistrement: {{error}}': 'Save failed: {{error}}',
  'LEADER DE L\'ALM ET DU RISK MANAGEMENT EN AFRIQUE SUBSAHARIENNE':
      'SUB-SAHARAN AFRICA ALM AND RISK MANAGEMENT LEADER',
  'Erreur: {{error}}': 'Error: {{error}}',
  'Rapport RWA importé avec succès (Attention indisponible pour le moment).':
      'RWA report successfully generated (feature temporarily unavailable).',
  'Nouvelle source importée: {{filename}}': 'New source imported: {{filename}}',
  'Import impossible: {{error}}': 'Import failed: {{error}}',
  'Merci de patienter pendant la mise à jour des données.':
      'Please wait while data is being updated.',
  'Edition prudente avec calcul automatique EAD, RW, RWA et capital dans la devise de saisie.':
      'Prudential editing with automatic EAD, RW, RWA and capital calculation in the input currency.',
  'Categorie prudentielle': 'Prudential category',
  'Montant brut': 'Gross amount',
  'Montant invalide': 'Invalid amount',
  'Devise': 'Currency',
  'Statut': 'Status',
  'Mode CRM': 'CRM mode',
  'Valeur du collateral': 'Collateral value',
  'Indice principal reconnu ?': 'Recognized main index?',
  'Obligation convertible': 'Convertible bond',
  "Choisissez Oui si l'obligation convertible reçue en garantie est incluse dans un indice principal reconnu.\nChoisissez Non dans le cas contraire.\nLa décote HC est de 20 % si Oui, contre 30 % si Non.":
      'Choose Yes if the convertible bond received as collateral is included in a recognized main index.\nChoose No otherwise.\nThe HC haircut is 20% for Yes, versus 30% for No.',
  'Type d emetteur': 'Issuer type',
  'Notation du collateral': 'Collateral rating',
  'Maturité': 'Maturity',
  'Maturité résiduelle': 'Residual maturity',
  'Hfx - Decote de change (%)': 'Hfx - FX haircut (%)',
  'Type de garantie': 'Guarantee type',
  'Nom du garant': 'Guarantor name',
  'Categorie du garant': 'Guarantor category',
  'Notation du garant': 'Guarantor rating',
  'Pourcentage de couverture': 'Coverage percentage',
  'Enregistrement...': 'Saving...',
  'Ajout de l exposition en cours...': 'Adding exposure...',
  'Mise à jour de l exposition en cours...': 'Updating exposure...',
  'Merci de patienter pendant l enregistrement.':
      'Please wait while the record is being saved.',
  'Champ requis': 'Required field',
  'Choisir une option': 'Choose an option',
  'Pourcentage invalide': 'Invalid percentage',
  'Nouvelle exposition prudentielle': 'New prudential exposure',
  'Enregistrer': 'Save',
  'Active': 'Active',
  'Echue': 'Expired',
  'En defaut': 'Defaulted',
  'Garantie etatique': 'Sovereign guarantee',
  'Assurance credit': 'Credit insurance',
  'Garantie bancaire': 'Bank guarantee',
  'souverain': 'sovereign',
  'autre': 'other',
  '<=1 an': '<=1 year',
  '1-3 ans': '1-3 years',
  '3-5 ans': '3-5 years',
  '5-10 ans': '5-10 years',
  '>10 ans': '>10 years',
  'Souverains': 'Sovereigns',
  'Organismes publics': 'Public-sector entities',
  'BMD': 'MDBs',
  'Institutions financieres': 'Financial institutions',
  'Entreprises': 'Corporates',
  'Clientele de detail': 'Retail clients',
  'Immobilier residentiel': 'Residential real estate',
  'Immobilier commercial': 'Commercial real estate',
  'Creances en souffrance': 'Past-due exposures',
  'Risque eleve': 'High-risk',
  'Créances à risque élevé': 'High-risk exposures',
  // Libellés prudentiels de catégorie sans préfixe lettre (le préfixe
  // "(a) ", "(b) "... a été retiré partout dans l'appli - voir
  // CATEGORY_OPTIONS dans rwa_calculation_service.py et exposureCategories
  // dans exposition_models.dart).
  'Organismes pub. hors Adm c':
      'Public-sector entities outside central administration',
  'Institutions financières': 'Financial institutions',
  'Clientèle de détail': 'Retail clients',
  "Prêts garantis par l'immo R": 'Residential real-estate secured loans',
  "Prêts garantis par l'immo C": 'Commercial real-estate secured loans',
  'Créances en souffrance': 'Past-due exposures',
  'Autres actifs': 'Other assets',
  // Libellés complets sans aucune abréviation (FULL_AGENT_LABELS côté
  // backend) : utilisés par les infobulles des graphiques du dashboard.
  'Organismes publics hors Administration centrale':
      'Public-sector entities outside central administration',
  'Banques multilatérales de développement':
      'Multilateral development banks',
  "Prêts garantis par l'immobilier résidentiel":
      'Residential real-estate secured loans',
  "Prêts garantis par l'immobilier commercial":
      'Commercial real-estate secured loans',
  '{{title}} - {{count}} ligne(s), affichage des {{preview}} premiere(s)':
      '{{title}} - {{count}} row(s), showing the first {{preview}}',
  'Infos calcul': 'Calculation info',
  'Categorie': 'Category',
  'Type spécifique d’exposition souveraine (le cas échéant)':
      'Specific type of sovereign exposure (if applicable)',
  'Cette exposition concerne-t-elle des souverains UEMOA/BCEAO ou leurs démembrements libellés et financés en FCFA, ou des institutions internationales ?':
      'Does this exposure concern UEMOA/BCEAO sovereigns or their entities denominated and funded in FCFA, or international institutions?',
  'Oui': 'Yes',
  'Non': 'No',
  'L’exposition respecte-t-elle les critères de classement en clientèle de détail ?':
      'Does the exposure meet the classification criteria for retail exposure?',
  'Destination : particulier ou PME/PMI': 'Destination: individual or SME',
  'Produits concernés : crédits CT/MT/LT, découverts, cartes de crédit, crédit-bail, facilités aux PME':
      'Relevant products: short/medium/long-term loans, overdrafts, credit cards, leasing and SME facilities',
  'Granularité : exposition ≤ 0,2 % du portefeuille retail global':
      'Granularity: exposure <= 0.2% of the overall retail portfolio',
  'Faible montant : encours agrégé par contrepartie ≤ 150 000 000 FCFA':
      'Low amount: aggregate outstanding per counterparty <= 150,000,000 FCFA',
  'Consentement BIC : accord du client pour transmission des données au BIC':
      'Credit bureau consent: client approval for sharing data with the BIC',
  'En cas de défaut, l’exposition relève de la catégorie des expositions en défaut.':
      'If the exposure is in default, it must be treated under the defaulted exposures category.',
  'Les actions, obligations et créances hypothécaires bénéficiant d’un régime spécifique ne relèvent pas de la clientèle de détail.':
      'Equities, bonds and mortgage claims benefiting from a specific regime must not be treated as retail exposures.',
  'Cas spécifique concerné': 'Relevant specific case',
  'Selectionner un cas': 'Select a case',
  'Expositions sur États de l’UEMOA et démembrements libellées et financées en FCFA':
      'Exposures to WAEMU States and their subdivisions denominated and funded in FCFA',
  'Expositions sur BCEAO libellées et financées en FCFA':
      'Exposures to the BCEAO denominated and funded in FCFA',
  'UEMOA': 'WAEMU',
  'CEDEAO': 'ECOWAS',
  'UA': 'AU',
  'UE': 'EU',
  'ONU': 'UN',
  'BRI': 'BIS',
  'FMI': 'IMF',
  'BCE': 'ECB',
  'FGD-UMOA': 'FGD-WAEMU',
  'Aucun de ces cas': 'None of these cases',
  'Cas préférentiel 0 % (historique)':
      'Legacy 0% preferential case (historical)',
  'Notation de la catégorie': 'Category rating',
  'Notation externe de la catégorie': 'External category rating',
  'L’exposition concerne-t-elle une BMD répondant aux critères suivants ?':
      'Does this exposure concern an MDB meeting the following criteria?',
  'Notation élevée, soutien actionnarial fort, capital et liquidité solides, gestion des risques prudente.':
      'High rating, strong shareholder support, solid capital and liquidity, prudent risk management.',
  'excellente notation long terme (majoritairement AAA)\n'
  'actionnariat composé en grande partie de souverains ≥ AA- ou financement surtout par capital versé\n'
  'fort soutien des actionnaires\n'
  'niveau adéquat de capital et de liquidité\n'
  'politiques de crédit et gestion des risques prudentes':
      '(a) excellent long-term rating (mostly AAA)\n(b) shareholding largely made up of sovereigns rated AA- or above, or financing mainly through paid-in capital\n(c) strong shareholder support\n(d) adequate capital and liquidity levels\n(e) prudent credit policies and risk management',
  'L’exposition concerne-t-elle une BMD des États de l’UEMOA libellée et financée en FCFA ?':
      'Does this exposure concern an MDB of WAEMU States denominated and funded in FCFA?',
  'La BMD respecte-t-elle les critères c), d) et e) ?':
      'Does the MDB meet criteria c), d) and e)?',
  'L’exposition concerne-t-elle l’une des institutions suivantes : BIRD, SFI, BAsD, BAD, BERD, BEI, FEI, BNI, BDC, BIsD, BDCE, AMGI ou BOAD libellée et financée en FCFA ?':
      'Does this exposure concern one of the following institutions denominated and funded in FCFA: IBRD, IFC, AfDB, ADB, EBRD, EIB, EIF, NIB, CDB, IsDB, ECDB, MIGA or BOAD?',
  "BIRD : Banque internationale pour la reconstruction et le développement\nSFI : Société financière internationale\nBAsD : Banque asiatique de développement\nBAD : Banque africaine de développement\nBERD : Banque européenne pour la reconstruction et le développement\nBEI : Banque européenne d'investissement\nFEI : Fonds européen d'investissement\nBNI : Banque nordique d'investissement\nBDC : Banque de développement des Caraïbes\nBIsD : Banque islamique de développement\nBDCE : Banque de développement des Caraïbes orientales\nAMGI : Agence multilatérale de garantie des investissements\nBOAD : Banque ouest-africaine de développement":
      'IBRD: International Bank for Reconstruction and Development\nIFC: International Finance Corporation\nAsDB: Asian Development Bank\nAfDB: African Development Bank\nEBRD: European Bank for Reconstruction and Development\nEIB: European Investment Bank\nEIF: European Investment Fund\nNIB: Nordic Investment Bank\nCDB: Caribbean Development Bank\nIsDB: Islamic Development Bank\nECDB: Eastern Caribbean Development Bank\nMIGA: Multilateral Investment Guarantee Agency\nBOAD: West African Development Bank',
  'Notation de la BMD': 'MDB rating',
  'Pondération automatique selon la notation sélectionnée.':
      'Automatic risk weight based on the selected rating.',
  "Banque hors UMOA soumise à des règles équivalentes à celles de l'UMOA":
      'Bank outside WAEMU subject to rules equivalent to those of WAEMU',
  'Banque en difficulté prudentielle': 'Bank in prudential difficulty',
  'Institution faisant partie des categories suivantes :':
      'Institution belonging to the following categories:',
  'Catégories concernées': 'Concerned categories',
  '(veuillez consulter le point infos pour en savoir plus)':
      '(please consult the info icon to learn more)',
  'Article 133': 'Article 133',
  'Article 134': 'Article 134',
  "(a) les entreprises du secteur bancaire\n(b) les services financiers des administrations de poste\n(c) les caisses nationales d'épargne\n(d) les autres institutions financières internationales.":
      '(a) banking sector firms\n(b) postal administration financial services\n(c) national savings institutions\n(d) other international financial institutions.',
  "Une pondération supérieure à 100 % est exigée lorsque le taux brut de dégradation du portefeuille entreprise dépasse sur deux trimestres consécutifs un seuil fixé par instruction de la BCEAO.\n\nUne pondération plus élevée est appliquée, lorsqu'une entreprise établie dans l'UMOA est soumise à une procédure de traitement prudentiel résultant de la production, par l'entreprise elle-même ou par son commissaire au compte, d'informations financières erronées.\n\n[[NOTE]]On entend par taux brut de dégradation du portefeuille, le rapport entre l'encours des créances en souffrance brutes telles que défini aux paragraphes 152 à 160 et le portefeuille de crédit brut de l'établissement. S'agissant des entreprises, le taux brut de dégradation du portefeuille est le rapport entre l'encours des créances en souffrance brutes enregistré au titre du portefeuille entreprises et l'encours total des crédits bruts octroyés à ce segment.":
      "A risk weight above 100% is required when the gross deterioration rate of the corporate portfolio exceeds, for two consecutive quarters, a threshold set by BCEAO instruction.\n\nA higher risk weight is applied when an undertaking established in WAEMU is subject to a prudential treatment procedure resulting from the production, by the undertaking itself or by its statutory auditor, of inaccurate financial information.\n\n[[NOTE]]The gross deterioration rate of the portfolio means the ratio between the outstanding amount of gross non-performing claims as defined in paragraphs 152 to 160 and the institution's gross credit portfolio. For corporates, it is the ratio between the outstanding amount of gross non-performing claims recorded for the corporate portfolio and the total outstanding amount of gross loans granted to that segment.",
  "Les expositions sur les entreprises d'investissement, autres que celles soumises à la loi uniforme portant réglementation bancaire doivent être pondérées, conformément aux règles afférentes aux créances sur les entreprises.\n\nEn outre, les expositions sur les entreprises non notées ne peuvent être affectées d’une pondération plus favorable que celle portant sur l’Etat dans lequel ces entreprises ont leur siège social.":
      'Exposures to investment firms, other than those subject to the uniform banking regulation law, must be risk-weighted in accordance with the rules applicable to claims on corporates.\n\nFurthermore, exposures to unrated corporates may not receive a more favorable risk weight than that applied to the State in which those corporates have their registered office.',
  'Le souverain est-il établi par les OCE ?':
      'Is the sovereign established by the OCEs?',
  'Sous-cas des souverains non notés': 'Unrated sovereign sub-case',
  'Le souverain est établi par les OCE':
      'The sovereign is established by the OCEs',
  'Si oui, la note OCE 0 à 7 détermine directement la pondération.':
      'If yes, the OCE score from 0 to 7 directly determines the risk weight.',
  'Échelle de 0 à 7': 'Scale from 0 to 7',
  'Pondération réglementaire': 'Regulatory risk weight',
  'Cas préférentiel historique à 0 % conservé.':
      'Historical 0% preferential case preserved.',
  'Cas prioritaire à 0 % appliqué : {{case}}':
      'Priority 0% case applied: {{case}}',
  'Pondération calculée selon la notation du souverain.':
      'Risk weight calculated from the sovereign rating.',
  'Pondération calculée selon la note OCE sélectionnée.':
      'Risk weight calculated from the selected OCE score.',
  'Souverain non noté hors OCE : la pondération standard de 100 % s\'applique.':
      'Unrated sovereign outside OCE: the standard 100% risk weight applies.',
  'Définition': 'Definition',
  'Précision': 'Note',
  'Exemples inclus': 'Included examples',
  'Type d’élément d’actif': 'Asset item type',
  'Les autres éléments d’actifs correspondent aux expositions non prises en compte dans les autres catégories prudentielles, hors éléments déjà déduits des fonds propres et hors expositions soumises à des exigences spécifiques.':
      'Other asset items correspond to exposures not captured in the other prudential categories, excluding items already deducted from own funds and exposures subject to specific requirements.',
  'Encaisse': 'Cash',
  'Valeurs assimilées à l’encaisse, y compris l’or':
      'Cash-equivalent items, including gold',
  'Valeurs à l’encaissement avec crédit immédiat':
      'Items for collection with immediate credit',
  'Participations non significatives non déduites des fonds propres':
      'Non-significant participations not deducted from own funds',
  'Immobilisations corporelles': 'Tangible fixed assets',
  'Immobilisations hors exploitation': 'Non-operating fixed assets',
  'Immobilisations incorporelles': 'Intangible fixed assets',
  'Autres actifs divers': 'Other miscellaneous assets',
  'Engagements en actions non déduits': 'Equity commitments not deducted',
  'Expositions sur entreprises financières non soumises à une réglementation équivalente UMOA':
      'Exposures to financial undertakings not subject to equivalent WAEMU regulation',
  'Autres éléments d’actifs non définis':
      'Other asset items not otherwise defined',
  'Participations significatives et impôts différés actifs non déduits':
      'Significant participations and deferred tax assets not deducted',
  'Expositions sur établissements non conformes aux ratios de solvabilité':
      'Exposures to institutions not compliant with solvency ratios',
  'comptes d’ordre, dépôts, débiteurs, FCP, stocks.':
      'memorandum accounts, deposits, debtors, mutual funds and inventories.',
  'hors engagements soumis à 250 % et hors actifs à risque élevé soumis à 150 %.':
      'excluding commitments subject to 250% and excluding high-risk assets subject to 150%.',
  'Niveau de risque hors bilan': 'Off-balance-sheet risk level',
  'Niveau de risque': 'Risk level',
  'Risque mineur': 'Minor risk',
  'Risque très élevé': 'Very high risk',
  'engagements révocables sans condition, à tout moment, sans préavis ou caducs automatiquement.':
      'unconditionally revocable commitments, cancellable at any time without notice, or commitments that lapse automatically.',
  'engagements ≤ 1 an non révocables sans condition ; lettres de crédit commerciales à court terme, crédits documentaires.':
      'commitments <= 1 year that are not unconditionally revocable; short-term commercial letters of credit and documentary credits.',
  'engagements > 1 an non révocables sans condition ; lettres de crédit documentaires non garanties par marchandises ; garanties de bonne exécution, de soumission, de tiers, crédits de confirmation.':
      'commitments > 1 year that are not unconditionally revocable; documentary letters of credit not guaranteed by goods; performance bonds, bid bonds, third-party guarantees and confirmation credits.',
  'facilités d’émission d’effets (FEE) et facilités de prise ferme renouvelables (FPR) ; substituts directs de crédit, garanties d’endettement, acceptations.':
      'note issuance facilities (NIFs) and revolving underwriting facilities (RUFs); direct credit substitutes, debt guarantees and acceptances.',
  'opérations assimilables à des pensions, repo ou prêts de titres ; cessions d’actifs avec recours, affacturage ou escompte ; engagements d’achat d’actifs à terme ; dépôts à terme contre terme ; fraction non versée d’actions ou titres partiellement libérés ; autres éléments hors bilan non classés.':
      'transactions similar to repos or securities lending; asset sales with recourse, factoring or discounting; forward asset purchase commitments; back-to-back term deposits; unpaid portion of shares or partially paid securities; other unclassified off-balance-sheet items.',
  'FCEC et hors bilan': 'CCF and off-balance sheet',
  'Définition : [[BREAK]]Les éléments de hors bilan recouvrent les garanties, les engagements, les instruments dérivés et d’autres accords contractuels non comptabilisés au bilan.\n\nApproche standard : [[BREAK]]Dans l’approche standard, chaque élément de hors bilan est converti en équivalent risque de crédit (ERC) au moyen d’un facteur de conversion en équivalent crédit (FCEC) qui sert à établir une projection de l’exposition potentielle au risque.\n\nCalcul de l’ERC : [[BREAK]]Le montant ERC d’une transaction de hors bilan est calculé en multipliant le montant correspondant à la portion non utilisée par le FCEC y relatif.\n\nCalcul des APR : [[BREAK]]Pour obtenir les APR de crédit sur les engagements de hors bilan, le montant ERC ainsi défini est ensuite multiplié par la pondération du risque qui dépend du type de contrepartie et de sa notation.\n\nCatégories de FCEC : [[BREAK]]Les FCEC applicables aux éléments de hors bilan sont répartis en cinq (5) catégories définies par ordre croissant selon le niveau de risque potentiel de la transaction.':
      'Definition: [[BREAK]]Off-balance-sheet items include guarantees, commitments, derivative instruments and other contractual arrangements not recognized on the balance sheet.\n\nStandardized approach: [[BREAK]]Under the standardized approach, each off-balance-sheet item is converted into a credit risk equivalent amount (CRE) using a credit conversion factor (CCF) to estimate the potential exposure to risk.\n\nCRE calculation: [[BREAK]]The CRE amount of an off-balance-sheet transaction is calculated by multiplying the amount corresponding to the unused portion by the related CCF.\n\nRWA calculation: [[BREAK]]To obtain credit RWA on off-balance-sheet commitments, the resulting CRE amount is then multiplied by the risk weight, which depends on the counterparty type and its rating.\n\nCCF categories: [[BREAK]]The CCFs applicable to off-balance-sheet items are divided into five (5) categories, defined in ascending order according to the potential risk level of the transaction.',
  'Ponderation appliquee': 'Applied risk weight',
  'Import données': 'Market data import',
  'Import données marché': 'Market data import',
  'Importation des fichiers nécessaires aux calculs de risque de marché.':
      'Import files required for market risk calculations.',
  'Centralisation des fichiers nécessaires aux calculs de VaR, sensibilités et stress marché.':
      'Centralization of files required for VaR, sensitivity and market stress calculations.',
  'Périmètre des données': 'Data scope',
  'Choisir le type de données marché à charger.':
      'Choose the type of market data to load.',
  'Source à importer': 'Source to import',
  'Charger le fichier qui alimentera le moteur marché.':
      'Load the file that will feed the market engine.',
  'Aucun fichier sélectionné': 'No file selected',
  'Formats acceptés : .xlsx, .csv, .json':
      'Accepted formats: .xlsx, .csv, .json',
  'Choisir un fichier': 'Choose a file',
  'Préparer l’import': 'Prepare import',
  'Préparation…': 'Preparing...',
  'Fichier marché prêt pour traitement.': 'Market file ready for processing.',
  'Format attendu': 'Expected format',
  'Structure minimale pour une intégration propre.':
      'Minimum structure for clean integration.',
  'Courbes de taux': 'Yield curves',
  'Points de courbe, maturités, rendements et taux zéro-coupon.':
      'Curve points, maturities, yields and zero-coupon rates.',
  'FX & devises': 'FX & currencies',
  'Taux de change, parités, dates de cotation et sources.':
      'Exchange rates, pairs, quotation dates and sources.',
  'Prix de marché': 'Market prices',
  'Prix actions, indices, obligations et instruments suivis.':
      'Equity prices, indices, bonds and tracked instruments.',
  'Historique P&L': 'P&L history',
  'Séries de pertes, gains, rendements et scénarios observés.':
      'Loss, gain, return and observed scenario series.',
  'Instrument': 'Instrument',
  'Valeur': 'Value',
  'Source': 'Source',
  'Visualisation': 'Visualization',
  'Visualisation d’indicateurs': 'Indicator visualization',
  'Tableau des données': 'Data table',
  'Données marché consolidées pour les calculs de risque.':
      'Consolidated market data for risk calculations.',
  'Date': 'Date',
  'Type': 'Type',
  'Variation': 'Change',
  'Taux': 'Rates',
  'Prix': 'Price',
  'Courbe UMOA 10Y': 'WAEMU 10Y curve',
  'Portefeuille trading': 'Trading portfolio',
  'Marché interne': 'Internal market',
  'Flux marché': 'Market feed',
  'Bourse': 'Exchange',
  'Risk management': 'Risk management',
  'Risque Crédit': 'Credit Risk',
  'Risque du Marché': 'Market Risk',
  'Pilotage RWA Crédit': 'RWA Credit Management',
  'Risque Opérationnel': 'Operational Risk',
  'Paramètres': 'Settings',
  'Défauts / Impayés': 'Defaults / Past dues',
  'Garanties': 'Guarantees',
  'Rapports': 'Reports',
  'Synthèse du module risque de crédit.': 'Credit risk module summary.',
  'Techniques de réduction du risque de crédit, couvertures et scénarios CRM.':
      'Credit risk mitigation techniques, coverages and CRM scenarios.',
  'Pilotage des engagements hors bilan, CCF, EAD et capital associé.':
      'Monitoring of off-balance-sheet commitments, CCF, EAD and related capital.',
  'Inventaire des garanties, couvertures et statuts relies aux expositions.':
      'Inventory of guarantees, coverages and statuses linked to exposures.',
  'Suivi des retards, incidents prudentiels et provisions estimées.':
      'Monitoring of delays, prudential incidents and estimated provisions.',
  'Analyse des concentrations sectorielles, geographiques et des plus fortes expositions.':
      'Analysis of sector concentrations, geographic concentrations and largest exposures.',
  'Exports et rapports de portefeuille, garanties et defauts.':
      'Portfolio, guarantee and default exports and reports.',
  'Evaluation des tensions de marché et des risques associés au portefeuille.':
      'Assessment of market stress and portfolio-related risks.',
  'Cartographie des risques operationnels et des controles internes.':
      'Mapping of operational risks and internal controls.',
  'Conseils et recommandations basés sur les expositions et les risques.':
      'Advice and recommendations based on exposures and risks.',
  'Generation de rapports de synthese, details et exports metier.':
      'Generation of summary reports, detailed reports and business exports.',
  'Risque de marché': 'Market risk',
  'Synthèse du risque de marché': 'Market risk summary',
  'Recommandations': 'Recommendations',
  'Evaluation des tendances de marché et impacts sur le portefeuille.':
      'Assessment of market trends and portfolio impacts.',
  'Analyse des variations de taux, des changes et des prix des actifs. Identifiez les sensibilités principales et surveillez les expositions critiques.':
      'Analysis of interest-rate, FX and asset-price movements. Identify key sensitivities and monitor critical exposures.',
  'Vérifiez la concentration sectorielle et géographique. Suivez la volatilité des taux et adaptez les limites internes si nécessaire.':
      'Review sector and geographic concentration. Monitor rate volatility and adjust internal limits where needed.',
  'VALUE AT RISK (VaR)': 'VALUE AT RISK (VaR)',
  'Mesure et simulation du risque de marché':
      'Market risk measurement and simulation',
  'Historique': 'Historical',
  'Paramétrique': 'Parametric',
  'VaR Historique': 'Historical VaR',
  'VaR Paramétrique': 'Parametric VaR',
  'VaR Monte-Carlo': 'Monte Carlo VaR',
  'Approche basée sur les distributions historiques des pertes et rendements.':
      'Approach based on historical loss and return distributions.',
  'Approche analytique basée sur la volatilité et la loi normale.':
      'Analytical approach based on volatility and the normal distribution.',
  'Simulation stochastique avancée du risque de marché.':
      'Advanced stochastic simulation of market risk.',
  'Paramètres de calcul': 'Calculation parameters',
  'Paramètres dynamiques': 'Dynamic parameters',
  'Paramètres de simulation': 'Simulation parameters',
  'Histogramme des pertes historiques': 'Historical loss histogram',
  'Queue rouge, seuil VaR et densité observée':
      'Red tail, VaR threshold and observed density',
  'Courbe normale Delta-Normale': 'Delta-normal curve',
  'Quantile, zone de perte et seuil VaR':
      'Quantile, loss zone and VaR threshold',
  'Distribution P&L simulée': 'Simulated P&L distribution',
  'Pertes, gains, queue critique et seuil VaR':
      'Losses, gains, critical tail and VaR threshold',
  'Niveau de confiance': 'Confidence level',
  'Horizon': 'Horizon',
  'Fenêtre historique': 'Historical window',
  'Type de portefeuille': 'Portfolio type',
  'Nombre de simulations': 'Number of simulations',
  'Distribution': 'Distribution',
  'Corrélations': 'Correlations',
  'Corrélation': 'Correlation',
  'Volatilité σ': 'Volatility σ',
  'Valeur du portefeuille': 'Portfolio value',
  'Duration modifiée': 'Modified duration',
  'Rendement attendu μ': 'Expected return μ',
  'Taux sans risque': 'Risk-free rate',
  'Paramètres avancés': 'Advanced settings',
  'Réinitialiser les paramètres par défaut': 'Reset default parameters',
  'Perte moyenne au-delà du seuil': 'Average loss beyond the threshold',
  'Pire perte observée': 'Worst observed loss',
  'Volatilité historique': 'Historical volatility',
  'Volatilité annualisée simulée': 'Simulated annualized volatility',
  'Queue extrême': 'Extreme tail',
  'Observations au-delà de la VaR': 'Observations beyond VaR',
  'Queue normale au-delà du quantile': 'Normal tail beyond the quantile',
  'Volatilité': 'Volatility',
  'Entrée principale du modèle': 'Main model input',
  'Ratio de Sharpe': 'Sharpe ratio',
  'Prime de risque / volatilité': 'Risk premium / volatility',
  'Sensibilité taux': 'Rate sensitivity',
  'Impact indicatif de 100 pb': 'Indicative 100 bp impact',
  'Scénarios extrêmes': 'Extreme scenarios',
  'Worst Case': 'Worst Case',
  'Pire scénario généré': 'Worst generated scenario',
  'Moyenne des scénarios de queue': 'Average of tail scenarios',
  'Comprendre la lecture historique': 'Understand the historical reading',
  'Comprendre la formule paramétrique': 'Understand the parametric formula',
  'Comprendre la simulation Monte-Carlo':
      'Understand the Monte Carlo simulation',
  'Formules - VaR historique': 'Formulas - Historical VaR',
  'Formules - VaR paramétrique': 'Formulas - Parametric VaR',
  'Formules - VaR Monte-Carlo': 'Formulas - Monte Carlo VaR',
  'Formules de calcul': 'Calculation formulas',
  'Variables': 'Variables',
  'Lᵢ : perte observée ; Rᵢ : rendement historique ; V : valeur du portefeuille ; α : niveau de confiance ; n : nombre d’observations ; Qα : quantile empirique.':
      'Lᵢ: observed loss; Rᵢ: historical return; V: portfolio value; α: confidence level; n: number of observations; Qα: empirical quantile.',
  'zα : quantile normal ; σ : volatilité ; D : duration/sensibilité ; ρ : corrélation ; μ : rendement attendu ; T : horizon en jours ouvrés ; φ : densité normale.':
      'zα: normal quantile; σ: volatility; D: duration/sensitivity; ρ: correlation; μ: expected return; T: horizon in business days; φ: normal density.',
  'Mᵢ : facteur de marché ; Eᵢ : choc spécifique ; ρ : corrélation ; εᵢ : choc corrélé ; Rᵢ : rendement simulé ; Lᵢ : perte simulée ; V : valeur du portefeuille ; N : scénarios.':
      'Mᵢ: market factor; Eᵢ: specific shock; ρ: correlation; εᵢ: correlated shock; Rᵢ: simulated return; Lᵢ: simulated loss; V: portfolio value; N: scenarios.',
  'Fréquence': 'Frequency',
  'gains ←': 'gains ←',
  'pertes sévères →': 'severe losses →',
  'P&L simulé': 'Simulated P&L',
  'Pertes / gains simulés': 'Simulated losses / gains',
  'Densité': 'Density',
  'Distribution historique des pertes': 'Historical loss distribution',
  'Distribution des pertes potentielles': 'Potential loss distribution',
  'Zone de pertes extrêmes': 'Extreme loss zone',
  '{{value}} des scénarios dépassent ce seuil':
      '{{value}} of scenarios exceed this threshold',
  'Seuil VaR historique': 'Historical VaR threshold',
  'Intervalle de pertes historiques': 'Historical loss interval',
  'Repère de pertes élevées : 95% des observations historiques restent sous ce niveau.':
      'High-loss marker: 95% of historical observations remain below this level.',
  'Queue extrême : 1% des observations historiques dépassent ce repère.':
      'Extreme tail: 1% of historical observations exceed this marker.',
  '{{count}} observations · {{probability}} des scénarios · cumul {{cumulative}} · P{{lower}}-P{{upper}}':
      '{{count}} observations · {{probability}} of scenarios · cumulative {{cumulative}} · P{{lower}}-P{{upper}}',
  '{{count}} observations · {{probability}} au-delà du seuil · ES {{expectedShortfall}}':
      '{{count}} observations · {{probability}} beyond the threshold · ES {{expectedShortfall}}',
  'Seuil VaR Delta-Normale': 'Delta-normal VaR threshold',
  'Queue de pertes extrêmes': 'Extreme loss tail',
  'Moyenne μ': 'Mean μ',
  'Distribution des pertes': 'Loss distribution',
  'Perte maximale probable sur {{horizon}} ; {{exceedance}} des scénarios dépassent ce seuil.':
      'Maximum probable loss over {{horizon}}; {{exceedance}} of scenarios exceed this threshold.',
  'Percentile {{percentile}} · zone critique au-delà du quantile.':
      'Percentile {{percentile}} · critical zone beyond the quantile.',
  'Centre de la distribution ajusté par le rendement attendu.':
      'Center of the distribution adjusted by expected return.',
  'Percentile {{percentile}} · σ* {{volatility}}.':
      'Percentile {{percentile}} · σ* {{volatility}}.',
  'Intervalle P&L': 'P&L interval',
  '{{count}} scénarios · {{probability}} · P{{lower}}-P{{upper}}':
      '{{count}} scenarios · {{probability}} · P{{lower}}-P{{upper}}',
  'Génération des scénarios': 'Scenario generation',
  'Revalorisation portefeuille': 'Portfolio revaluation',
  'Extraction de la VaR': 'VaR extraction',
  'Comparaison des méthodes VaR': 'VaR method comparison',
  'Lecture institutionnelle des arbitrages de calcul':
      'Institutional view of calculation trade-offs',
  'Méthode': 'Method',
  'Rapidité': 'Speed',
  'Robustesse': 'Robustness',
  'Complexité': 'Complexity',
  'Rapide': 'Fast',
  'Très rapide': 'Very fast',
  'Moyenne': 'Medium',
  'Lente': 'Slow',
  'Très forte': 'Very strong',
  'Élevée': 'High',
  'Exploite les pertes réellement observées pour estimer le quantile de perte.':
      'Uses actual observed losses to estimate the loss quantile.',
  'Utilise volatilité, corrélation et quantile pour produire un calcul rapide.':
      'Uses volatility, correlation and quantile to produce a fast calculation.',
  'Simule de nombreux scénarios pour capter les queues de distribution complexes.':
      'Simulates many scenarios to capture complex distribution tails.',
  'La méthode historique privilégie la lecture empirique, la paramétrique accélère le calcul, et Monte-Carlo renforce la robustesse au prix d’une complexité plus élevée.':
      'The historical method favors empirical reading, the parametric method speeds up calculation, and Monte Carlo strengthens robustness at the cost of higher complexity.',
  'Obligataire': 'Bonds',
  'Actions': 'Equities',
  'Mixte': 'Mixed',
  'Normale': 'Normal',
  'Empirique': 'Empirical',
  '1 jour': '1 day',
  '10 jours': '10 days',
  '1 mois': '1 month',
  'Recommendations à partir des expositions et des risques.':
      'Recommendations based on exposures and risks.',
  'Synthèse des observations': 'Observation summary',
  'Le module d’analyse agrège les données des expositions, du risque de marché et du risque opérationnel. Il aide à identifier les leviers d’amélioration et les zones de concentration.':
      'The analysis module aggregates exposure, market risk and operational risk data. It helps identify improvement levers and concentration areas.',
  'Actions recommandées': 'Recommended actions',
  'Priorisez les dispositifs de couverture et de mitigation. Renforcez la surveillance des expositions sensibles et formalisez les plans de correction.':
      'Prioritize coverage and mitigation mechanisms. Strengthen monitoring of sensitive exposures and formalize corrective action plans.',
  'Trajectoire prévisionnelle': 'Forecast trajectory',
  'Projetez l’évolution du capital disponible, des besoins réglementaires et des coussins afin de visualiser les marges de manoeuvre sur plusieurs horizons.':
      'Project available capital, regulatory needs and buffers to visualize management headroom across several horizons.',
  'Arbitrages de gestion': 'Management trade-offs',
  'Préparez les décisions de distribution, de croissance des encours et de renforcement du capital en fonction des contraintes prudentielles attendues.':
      'Prepare distribution, exposure growth and capital strengthening decisions based on expected prudential constraints.',
  'Périmètre d’évaluation': 'Assessment scope',
  'Regroupez les hypothèses de capital interne, les contraintes réglementaires et les risques matériels pour établir une lecture cohérente de l’adéquation du capital.':
      'Consolidate internal capital assumptions, regulatory constraints and material risks to establish a coherent view of capital adequacy.',
  'Décisions de pilotage': 'Steering decisions',
  'Identifiez les coussins disponibles, les limites de concentration et les besoins d’ajustement pour sécuriser la trajectoire prudentielle.':
      'Identify available buffers, concentration limits and adjustment needs to secure the prudential trajectory.',
  'Risque opérationnel': 'Operational risk',
  'Suivi des incidents et des controles internes liés aux processus.':
      'Monitoring of incidents and process-related internal controls.',
  'Principaux indicateurs opérationnels': 'Key operational indicators',
  'Métriques sur les pertes, les incidents et la qualité des processus. L’objectif est de limiter l’impact opérationnel sur les résultats.':
      'Metrics on losses, incidents and process quality. The objective is to limit the operational impact on results.',
  'Conseils pratiques': 'Practical guidance',
  'Renforcez les controles clés, formalisez les procédures et surveillez les événements opérationnels récurrents pour réduire les risques.':
      'Strengthen key controls, formalize procedures and monitor recurring operational events to reduce risk.',
  'Bibliothèque de scénarios': 'Scenario library',
  'Centralisez les stress de taux, de défaut, de concentration et de liquidité pour mesurer leur impact sur les RWA, le capital et la solvabilité.':
      'Centralize rate, default, concentration and liquidity stresses to measure their impact on RWA, capital and solvency.',
  'Lecture des impacts': 'Impact reading',
  'Comparez le scénario central aux hypothèses adverses, identifiez les seuils de rupture et préparez les actions de mitigation à suivre.':
      'Compare the central scenario with adverse assumptions, identify breakpoints and prepare follow-up mitigation actions.',

  // --- Module Importations ---
  'Gestion des Importations': 'Import Management',
  'Veuillez procéder à l\'importation de vos données afin de réaliser vos analyses.':
      'Please import your data in order to carry out your analyses.',
  'Risque de Crédit': 'Credit Risk',
  'Données risque de crédit chargées avec succès':
      'Credit risk data loaded successfully',
  'Risque de Marché': 'Market Risk',
  'Données risque de marché chargées avec succès':
      'Market risk data loaded successfully',
  'Données BIC / CCR3 chargées avec succès':
      'BIC / CCR3 data loaded successfully',
  'Données risque opérationnel chargées avec succès':
      'Operational risk data loaded successfully',
  'Fonds Propres': 'Own Funds',
  'Fonds propres réglementaires mis à jour avec succès':
      'Regulatory own funds updated successfully',
  'Quel type de fichier importer ?': 'Which file type do you want to import?',
  'Le module Risque Opérationnel accepte deux formats de fichier.':
      'The Operational Risk module accepts two file formats.',
  'Base prudentielle (pertes / incidents)':
      'Prudential base (losses / incidents)',
  'Registre des incidents et pertes opérationnelles, ligne par ligne.':
      'Register of operational incidents and losses, line by line.',
  'BIC / CCR3': 'BIC / CCR3',
  'Formulaire de saisie de l\'indicateur d\'activité - un onglet Excel par exercice.':
      'Business indicator input form - one Excel tab per fiscal year.',

  // --- Dashboard: import Fonds Propres ---
  'Modèle enregistré.': 'Template saved.',
  'Impossible d\'enregistrer : le fichier est probablement déjà ouvert '
          '(par exemple dans Excel). Fermez-le puis réessayez, ou choisissez '
          'un autre emplacement.':
      'Unable to save: the file is probably already open '
          '(for example in Excel). Close it and try again, or choose '
          'another location.',
  'Téléchargement impossible: {{error}}': 'Download failed: {{error}}',
  'Seuls les fichiers .xlsx sont acceptés.': 'Only .xlsx files are accepted.',
  'Poste non reconnu, ignoré : "{{label}}"':
      'Item not recognized, ignored: "{{label}}"',
  'Postes absents (laissés à 0) : {{missing}}':
      'Missing items (left at 0): {{missing}}',
  'Importation Fonds Propres Réglementaires': 'Regulatory Own Funds Import',
  'Lecture du fichier...': 'Reading file...',
  'Déposez le fichier pour lancer la lecture': 'Drop the file to start reading',
  'Déposez le fichier Fonds Propres ici': 'Drop the Own Funds file here',
  'L\'import remplace entièrement les fonds propres actuellement '
          'enregistrés (comme le formulaire "Mettre à jour").':
      'The import fully replaces the currently recorded own funds '
          '(like the "Update" form).',
  'Modèle Excel': 'Excel template',
  'Fichier accepté: .xlsx, avec les colonnes « Groupe », « Poste » et « Valeur ».':
      'Accepted file: .xlsx, with the "Group", "Item" and "Value" columns.',
  'Choisir un autre fichier': 'Choose another file',
  'Une ligne = un poste. Trois colonnes : « Groupe », « Poste », '
          '« Valeur ». 11 lignes (CET1, AT1, Tier 2).':
      'One row = one item. Three columns: "Group", "Item", "Value". '
          '11 rows (CET1, AT1, Tier 2).',
  'Poste': 'Item',
  'Un des 11 libellés du formulaire': 'One of the form\'s 11 labels',
  'Montant en FCFA': 'Amount in FCFA',
  'Télécharger le modèle': 'Download the template',
  'À vérifier': 'To review',
  'Changer': 'Change',
  'Fonds propres de base': 'Core own funds',
  'Fonds propres additionnels': 'Additional own funds',
  'Fonds propres complémentaires': 'Supplementary own funds',
  'Fonds Propres Globaux': 'Total Own Funds',
  'Import terminé': 'Import completed',
  'Échec de l\'import': 'Import failed',
  'Les fonds propres réglementaires ont été mis à jour.':
      'The regulatory own funds have been updated.',
  'Une erreur est survenue.': 'An error occurred.',
  'Actualiser le tableau de bord': 'Refresh the dashboard',
  'Vérifiez les valeurs ci-dessus avant d\'enregistrer.':
      'Review the values above before saving.',
  'Sélectionnez un fichier pour lancer la lecture.':
      'Select a file to start reading.',
  'Capital ordinaire': 'Ordinary capital',
  'Réserves': 'Reserves',
  'Résultats en report': 'Retained earnings',
  'Résultat éligible': 'Eligible income',
  'Réduction prudentielle (CET1)': 'Prudential reduction (CET1)',
  'Instruments additionnels (AT1)': 'Additional instruments (AT1)',
  'Primes d\'émission (AT1)': 'Issue premiums (AT1)',
  'Réduction prudentielle (AT1)': 'Prudential reduction (AT1)',
  'Dettes subordonnées (Tier 2)': 'Subordinated debt (Tier 2)',
  'Provisions générales (Tier 2)': 'General provisions (Tier 2)',
  'Réduction prudentielle (Tier 2)': 'Prudential reduction (Tier 2)',

  // --- Dashboard: grands risques ---
  'TOUS LES GRANDS RISQUES': 'ALL LARGE EXPOSURES',
  'Contrepartie / Groupe lié': 'Counterparty / Linked group',
  'Pays de risque': 'Risk country',
  'Risque Brut': 'Gross risk',
  'Risque Net': 'Net risk',
  'Ratio RN/FP (%)': 'Net risk / Own funds ratio (%)',
  'Conforme': 'Compliant',
  'Alerte': 'Alert',
  'Dans la norme': 'Within norm',
  'Dépassement': 'Breach',
  'Catégorie d\'exposition': 'Exposure category',
  'Part (%)': 'Share (%)',
  'TOP 10 DES GRANDS RISQUES': 'TOP 10 LARGE EXPOSURES',
  'Voir tous': 'View all',
  'Total': 'Total',
  'Sous cible': 'Below target',
  'SYNTHÈSE DES GRANDS RISQUES': 'LARGE EXPOSURES SUMMARY',
  'Total grands risques': 'Total large exposures',
  'Risque Net Total': 'Total net risk',
  'CLASSIFICATION PRUDENTIELLE': 'PRUDENTIAL CLASSIFICATION',
  'Module en construction': 'Module under construction',
  'Cette section sera disponible dans une prochaine version.': 'This section will be available in a future release.',
  'Expositions individuelles rapportées aux fonds propres effectifs': 'Individual exposures relative to effective own funds',
  '< 25 % des FP': '< 25% of own funds',
  '> 25 % des FP': '> 25% of own funds',
  'INDICATEURS DE SUIVI': 'MONITORING INDICATORS',
  'Concentration maximale': 'Maximum concentration',
  'Concentration moyenne': 'Average concentration',
  'Taux de conformité': 'Compliance rate',
  'Limite individuelle : 25 % des fonds propres effectifs': 'Individual limit: 25% of effective own funds',
  'Erreur lors de la sauvegarde : {{error}}': 'Error while saving: {{error}}',
  'Modifier les Fonds Propres': 'Edit Own Funds',
  'Devise de saisie :': 'Entry currency:',
  'Réduction prudentielle': 'Prudential reduction',
  'Instruments additionnels': 'Additional instruments',
  'Primes d\'émission': 'Issue premiums',
  'Dettes subordonnées': 'Subordinated debt',
  'Provisions générales': 'General provisions',
  'Fonds propres de base de catégorie 1': 'Category 1 core own funds',
  'Fonds propres additionnels de catégorie 1': 'Category 1 additional own funds',

  // --- Dashboard: exigences de fonds propres (dot plot) ---
  'Exigences de fonds propres': 'Capital requirements',
  'Solvabilité': 'Solvency',
  'Globale': 'Overall',
  'Détenus': 'Held',
  '{{label}} : Pilier 1 (en {{unit}})': '{{label}}: Pillar 1 (in {{unit}})',
  '{{label}} : Exigence globale (en {{unit}})': '{{label}}: Overall requirement (in {{unit}})',
  '{{label}} : Fonds propres détenus (en {{unit}})': '{{label}}: Own funds held (in {{unit}})',
  'Seuil minimum strict': 'Strict minimum threshold',
  'Montant équivalent': 'Equivalent amount',
  'Coussin de conservation': 'Conservation buffer',
  'Taux global exigé': 'Overall required rate',
  'Montant requis': 'Required amount',
  'Montant détenu': 'Amount held',
  'Ratio effectif': 'Effective ratio',
  'Montant exigé': 'Required amount',
  'Excédent de capital': 'Capital surplus',
  'Déficit de capital': 'Capital deficit',
  '(Seuil minimum × Actifs pondérés au risque)':
      '(Minimum threshold × Risk-weighted assets)',
  '(Taux global exigé × Actifs pondérés au risque)':
      '(Overall required rate × Risk-weighted assets)',
  '(Montant détenu - Montant exigé)': '(Amount held - Required amount)',

  // --- Dashboard: ratio de solvabilité (jauge) ---
  'RATIO DE SOLVABILITÉ': 'SOLVENCY RATIO',
  'En {{unit}} ({{currency}})': 'In {{unit}} ({{currency}})',
  'Fonds propres (Capital détenu)': 'Own funds (Capital held)',
  'Exigence minimale (9%)': 'Minimum requirement (9%)',
  'Coussin de sécurité (Excédent)': 'Safety buffer (Surplus)',
  'Ratio de Solvabilité global': 'Overall solvency ratio',
  'Min: 9%': 'Min: 9%',

  // --- Dashboard: grands risques (top contreparties) ---
  'Grands Risques (Top Contreparties)': 'Large Exposures (Top Counterparties)',
  'Méthodologie: Exposition Nette (Brut - Garanties) vs 25% des Fonds Propres':
      'Methodology: Net Exposure (Gross - Guarantees) vs 25% of Own Funds',
  'Aucune donnée de contrepartie.': 'No counterparty data.',
  'Consommation FP: {{value}}%': 'Own funds consumption: {{value}}%',
  'Limite 25% dépassée': '25% limit exceeded',

  // --- Dashboard: bandeau des ratios ---
  'Ratio CET1': 'CET1 Ratio',
  'Ratio Tier 1': 'Tier 1 Ratio',
  'Ratio de solvabilité': 'Solvency ratio',
  'Ratio de Levier': 'Leverage ratio',

  'Excédent': 'Surplus',
  'Sous surveillance': 'Under review',
  'Déficit': 'Deficit',
  'Seuil réglementaire :': 'Regulatory threshold:',
  'Pilier 1 ({{value}}%)': 'Pillar 1 ({{value}}%)',
  'Coussin ({{value}}%)': 'Buffer ({{value}}%)',

  // --- Dashboard: jauge de conformité grands risques ---
  'Conformité grands risques - plus forte exposition':
      'Large exposures compliance - highest exposure',
  'En % des fonds propres': 'As % of own funds',
  'Plus forte exposition': 'Highest exposure',
  'LIMITE RÉGLEMENTAIRE': 'REGULATORY LIMIT',
  "Seuil d'alerte interne : {{value}}%": 'Internal alert threshold: {{value}}%',

  // --- Dashboard: structure des RWA ---
  'STRUCTURE DES RWA': 'RWA STRUCTURE',
  'Total RWA': 'Total RWA',
  'Contribution aux exigences minimales (9%)':
      'Contribution to minimum requirements (9%)',
  'Crédit (Approche Standard)': 'Credit (Standard Approach)',
  'Marché (Modèles Internes)': 'Market (Internal Models)',
  'Opérationnel (Indicateur de Base)': 'Operational (Basic Indicator)',
  'Crédit': 'Credit',
  'Opérationnel': 'Operational',

  // --- Dashboard: fonds propres (treemap) ---
  'Fonds propres réglementaires': 'Regulatory own funds',
  'Mettre à jour': 'Update',
  'Capital Complémentaire': 'Complementary Capital',
  'Réduction prud.': 'Prudential reduction',
  'Instruments add.': 'Additional instruments',

  // --- Dashboard: ratios réglementaires & capital requis ---
  'Ratios Réglementaires & Capital Requis': 'Regulatory Ratios & Required Capital',
  'Cap. Requis: {{value}}': 'Required Capital: {{value}}',
  'Actuel: {{value}}%': 'Current: {{value}}%',
  'Min. exigé: {{value}}%': 'Min. required: {{value}}%',

  // --- Dashboard: capital détenu vs requis ---
  'Capital détenu vs capital requis': 'Capital held vs required capital',
  'En {{unit}} FCFA': 'In {{unit}} FCFA',
  'Détenu': 'Held',
  'Requis': 'Required',
  'Total FP': 'Total own funds',
  'Actualiser': 'Refresh',

  // --- Dashboard: exigences par type de risque ---
  'EXIGENCES DE FONDS PROPRES PAR TYPE DE RISQUE':
      'CAPITAL REQUIREMENTS BY RISK TYPE',
  'Capital Requis': 'Required Capital',
  'Aucune donnée disponible': 'No data available',
  '{{count}} expositions': '{{count}} exposures',
  'Part: {{value}}%': 'Share: {{value}}%',
  'Exposition totale: {{value}}': 'Total exposure: {{value}}',
  'RWA: {{value}}': 'RWA: {{value}}',

  // --- Dashboard: top metrics grid ---
  'Exposition brute': 'Gross exposure',
  'Nombre d\'expositions : {{count}}': 'Number of exposures: {{count}}',
  'EAD × RW (Taux de pondération)': 'EAD × RW (Risk weight)',
  'RWA × 9%': 'RWA × 9%',
  'Risque résiduel': 'Residual risk',
  'Exposition brute - Sûretés/Garanties': 'Gross exposure - Collateral/Guarantees',
  'Non-Performing Loans (NPL)': 'Non-Performing Loans (NPL)',
  'Prêts en défaut / Total des prêts': 'Defaulted loans / Total loans',

  // --- Dashboard: statuts ratio ---
  'Sous la cible': 'Below target',
  'Sous le minimum': 'Below minimum',

  // --- Dashboard: en-tête général & bandeau bas ---
  "Vue d'ensemble des indicateurs prudentiels": 'Overview of prudential indicators',
  'Fonds propres totaux': 'Total own funds',
  'Consommation des FP': 'Own funds consumption',
  'Nombre de grands risques': 'Number of large exposures',
  'Risques traités': 'Processed exposures',

  // --- Dashboard: treemap concentration ---
  'Concentration des risques - top 10 contreparties':
      'Risk concentration - top 10 counterparties',
  'Groupe A': 'Group A',
  'Groupe B': 'Group B',
  'Groupe C': 'Group C',
  'Groupe D': 'Group D',
  'Groupe E': 'Group E',
  'Autres': 'Other',

  // --- Dashboard: RWA total / capital requis (donut) ---
  'RWA TOTAL ET CAPITAL REQUIS': 'TOTAL RWA AND REQUIRED CAPITAL',
  'RWA TOTAL': 'TOTAL RWA',
  'CAPITAL MINIMUM REQUIS (9%)': 'MINIMUM CAPITAL REQUIRED (9%)',

  // --- Dashboard: libellés CRM recalculés (dashboard_screen.dart) ---
  'AUCUNE GARANTIE': 'NO GUARANTEE',
  'GARANTIE NON FINANCÉE': 'UNFUNDED GUARANTEE',
  'GARANTIE FINANCÉE': 'FUNDED GUARANTEE',

  // --- Dashboard: répartition par secteur (top10 chart) ---
  'RÉPARTITION PAR SECTEUR': 'BREAKDOWN BY SECTOR',
  'Top 5 de l\'EAD par catégorie': 'Top 5 EAD by category',
};

const Map<String, String> _frenchTranslations = {
  'Market Data': 'Données de Marché',
  'Market': 'Marché',
  'Schedules & Cash Flows': 'Échéanciers & Flux',
  'Analysis & Risk': 'Analyse & Risques',
  'Reference Data': 'Référentiels',
  'Portfolio display currency': "Devise d'affichage du portefeuille",
  'Switch to light mode': 'Passer en mode clair',
  'Switch to dark mode': 'Passer en mode sombre',
  'Language': 'Langue',
  'French': 'Français',
  'English': 'Anglais',
  'Export': 'Exporter',
  'New analysis': 'Nouvelle analyse',
  'Monthly': 'Mensuel',
  'Quarterly': 'Trimestriel',
  'Yearly': 'Annuel',
  'Strong quality': 'Qualité bonne',
  'Balanced quality': 'Qualité moyenne',
  'Higher pressure': 'Qualité élevée',
  'Risque faible (densité)': 'Risque faible',
  'Risque moyen (densité)': 'Risque moyen',
  'Risque élevé (densité)': 'Risque élevé',
  'Dashboard': 'Tableau de bord',
  'Overview': 'Vue d\'ensemble',
  'Exposures': 'Expositions',
  'Credit risk': 'Risque de crédit',
  'CRM financee': 'CRM financée',
  'CRM non financee': 'CRM non financée',
  'Parametres de la surete financee': 'Paramètres de la sûreté financée',
  'Parametres de la garantie non financee':
      'Paramètres de la garantie non financée',
};
