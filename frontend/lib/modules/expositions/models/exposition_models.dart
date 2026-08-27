// Ce fichier decrit les donnees et regles du module expositions.

import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/prudentiel.dart';

String _normalizeExposureLabel(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll("'", ' ')
      .replaceAll('’', ' ')
      .replaceAll('-', ' ')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ô', 'o')
      .replaceAll('û', 'u')
      .replaceAll('ç', 'c')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ô', 'o')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'\s+'), ' ');
}

String _stripExposureCategoryCodePrefix(String value) {
  return value.replaceFirst(
    RegExp(r'^\s*\([a-z]\)\s*', caseSensitive: false),
    '',
  );
}

String _normalizeExposureCategoryLookupLabel(String value) {
  return _normalizeExposureLabel(_stripExposureCategoryCodePrefix(value));
}

class ExposureCategoryOption {
  const ExposureCategoryOption({
    required this.code,
    required this.label,
    required this.prudentialLabel,
    this.legacyLabel,
    this.fixedRiskWeight,
  });

  final String code;
  final String label;
  final String prudentialLabel;
  final String? legacyLabel;
  final double? fixedRiskWeight;
}

const List<ExposureCategoryOption> exposureCategories = [
  ExposureCategoryOption(
    code: 'a',
    label: 'Souverains',
    prudentialLabel: 'Souverains',
    legacyLabel: 'Souverains',
  ),
  ExposureCategoryOption(
    code: 'b',
    label: 'Organismes publics',
    prudentialLabel: 'Organismes pub. hors Adm c',
  ),
  ExposureCategoryOption(
    code: 'c',
    label: 'BMD',
    prudentialLabel: 'Expositions sur les BMD',
  ),
  ExposureCategoryOption(
    code: 'd',
    label: 'Institutions financieres',
    prudentialLabel: 'Institutions financières',
    legacyLabel: 'Banques',
  ),
  ExposureCategoryOption(
    code: 'e',
    label: 'Entreprises',
    prudentialLabel: 'Entreprises',
    legacyLabel: 'Entreprises',
  ),
  ExposureCategoryOption(
    code: 'f',
    label: 'Clientele de detail',
    prudentialLabel: 'Clientèle de détail',
    legacyLabel: 'Particuliers',
  ),
  ExposureCategoryOption(
    code: 'g',
    label: 'Immobilier residentiel',
    prudentialLabel: "Prêts garantis par l'immo R",
    fixedRiskWeight: 0.35,
  ),
  ExposureCategoryOption(
    code: 'h',
    label: 'Immobilier commercial',
    prudentialLabel: "Prêts garantis par l'immo C",
    fixedRiskWeight: 0.75,
  ),
  ExposureCategoryOption(
    code: 'i',
    label: 'Creances en souffrance',
    prudentialLabel: 'Créances en souffrance',
    fixedRiskWeight: 1.5,
  ),
  ExposureCategoryOption(
    code: 'j',
    label: 'Créances à risque élevé',
    prudentialLabel: 'Créances à risque élevé',
    legacyLabel: 'Risque eleve',
    fixedRiskWeight: 1.5,
  ),
  ExposureCategoryOption(
    code: 'k',
    label: 'Autres actifs',
    prudentialLabel: 'Autres actifs',
  ),
];

const List<String> financedCrmIssuerTypes = [
  'souverain',
  'autre',
];

const List<String> financedCrmCollateralRatings = [
  'AAA',
  'AA+',
  'AA',
  'AA-',
  'A+',
  'A',
  'A-',
  'BBB+',
  'BBB',
  'BBB-',
  'BB+',
  'BB',
  'BB-',
  'non_noté_état_umoa',
  'garanti_brvm',
  'bancaire_non_noté',
  'actions_brvm',
  'autres_actions',
  'opcvm',
  'liquidité',
];

const List<String> prudentialRatings = [
  'AAA',
  'AA+',
  'AA',
  'AA-',
  'A+',
  'A',
  'A-',
  'BBB+',
  'BBB',
  'BBB-',
  'BB+',
  'BB',
  'BB-',
  'B+',
  'B',
  'B-',
  '< B-',
  'Non noté',
];

const List<String> enterpriseRatingOptions = [
  'AAA',
  'AA+',
  'AA',
  'AA-',
  'A+',
  'A',
  'A-',
  'BBB+',
  'BBB',
  'BBB-',
  'BB+',
  'BB',
  'BB-',
  '< BB-',
  'Non noté',
];

const double residentialMortgageEligibleRiskWeight = 0.35;
const double commercialRealEstateEligibleRiskWeight = 0.75;
const List<double> defaultedExposureInitialRiskWeightOptions = [
  0.2,
  0.35,
  0.5,
  0.75,
  1.0,
  1.5,
  2.5,
];

const List<String> financedCrmMaturityBuckets = [
  '<=1 an',
  '1-3 ans',
  '3-5 ans',
  '5-10 ans',
  '>10 ans',
];

const List<String> financedCrmCollateralTypes = [
  'Liquidités dans la même devise',
  'Liquidités dans une devise différente',
  'Or',
  'Titre de dette souverain',
  'Titre non noté émis par un État de l UMOA',
  'Titre de dette émis par un autre émetteur',
  'Titre garanti par un agent agréé par la BRVM',
  'Titre bancaire non noté',
  'Action de l indice BRVM 10',
  'Action d un indice principal reconnu',
  'Autre action cotée à la BRVM ou sur une bourse reconnue',
  'Obligation convertible en action',
  'OPCVM / FI',
  'Panier d actifs',
  'Autre sûreté non éligible',
];

const List<String> financedCrmIssuerRoleOptions = [
  'emprunteur souverain',
  'autre émetteur',
];

const List<String> financedCrmDebtRatings = [
  'AAA',
  'AA+',
  'AA',
  'AA-',
  'A+',
  'A',
  'A-',
  'BBB+',
  'BBB',
  'BBB-',
  'BB+',
  'BB',
  'BB-',
  '< B-',
  'Non noté',
];

const List<double> financedCrmOpcvmHaircutLevels = [
  0.0,
  0.005,
  0.01,
  0.02,
  0.03,
  0.04,
  0.06,
  0.09,
  0.12,
  0.15,
  0.20,
  0.30,
];

const List<String> guarantorEligibleCategoryCodes = [
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
  'k',
];

const String sovereignNoSpecialCase = 'Aucun de ces cas';
const String sovereignLegacySpecialCase = 'Cas préférentiel 0 % (historique)';
const List<String> sovereignZeroWeightSpecialCases = [
  'Expositions sur États de l’UEMOA et démembrements libellées et financées en FCFA',
  'Expositions sur BCEAO libellées et financées en FCFA',
  'UEMOA',
  'CEDEAO',
  'UA',
  'UE',
  'ONU',
  'BRI',
  'FMI',
  'BCE',
  'FGD-UMOA',
];
const List<String> sovereignSpecialCaseOptions = [
  ...sovereignZeroWeightSpecialCases,
  sovereignNoSpecialCase,
];
const List<String> sovereignRatingOptions = [
  'AAA',
  'AA+',
  'AA',
  'AA-',
  'A+',
  'A',
  'A-',
  'BBB+',
  'BBB',
  'BBB-',
  'BB+',
  'BB',
  'BB-',
  'B+',
  'B',
  'B-',
  '< B-',
  'Non noté',
];

String coerceSovereignSpecialCase(
  String? value, {
  bool fallbackToLegacy = false,
}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isNotEmpty) {
    final normalized = _normalizeExposureLabel(trimmed);
    if (normalized == _normalizeExposureLabel(sovereignLegacySpecialCase)) {
      return sovereignLegacySpecialCase;
    }
    if (normalized == _normalizeExposureLabel(sovereignNoSpecialCase)) {
      return sovereignNoSpecialCase;
    }
    for (final option in sovereignZeroWeightSpecialCases) {
      if (_normalizeExposureLabel(option) == normalized) {
        return option;
      }
    }
  }
  return fallbackToLegacy ? sovereignLegacySpecialCase : sovereignNoSpecialCase;
}

bool hasSovereignPriorityZeroWeightCase(
  String? sovereignSpecialCase, {
  bool sovereignPreferentialZeroWeight = false,
}) {
  final normalized = coerceSovereignSpecialCase(
    sovereignSpecialCase,
    fallbackToLegacy: sovereignPreferentialZeroWeight,
  );
  return sovereignZeroWeightSpecialCases.contains(normalized) ||
      normalized == sovereignLegacySpecialCase ||
      sovereignPreferentialZeroWeight;
}

const Map<String, double> currencyRatesInXaf = {
  'XOF': 1.0,
  'EUR': 655.957,
  'USD': 600.0,
};

const Map<String, String> _financedCrmCollateralRatingLabelsByKey = {
  'AAA': 'AAA',
  'AA+': 'AA+',
  'AA': 'AA',
  'AA-': 'AA-',
  'A+': 'A+',
  'A': 'A',
  'A-': 'A-',
  'BBB+': 'BBB+',
  'BBB': 'BBB',
  'BBB-': 'BBB-',
  'BB+': 'BB+',
  'BB': 'BB',
  'BB-': 'BB-',
  '<_B-': '< B-',
  'NON_NOTE': 'Non noté',
  'NON_NOTE_ETAT_UMOA': 'non_noté_état_umoa',
  'GARANTI_BRVM': 'garanti_brvm',
  'BANCAIRE_NON_NOTE': 'bancaire_non_noté',
  'ACTIONS_BRVM': 'actions_brvm',
  'AUTRES_ACTIONS': 'autres_actions',
  'OPCVM': 'opcvm',
  'LIQUIDITE': 'liquidité',
};

ExposureCategoryOption exposureCategoryByCode(String code) {
  return exposureCategories.firstWhere(
    (item) => item.code == code,
    orElse: () => exposureCategories[4],
  );
}

ExposureCategoryOption? tryExposureCategoryByName(String label) {
  final normalized = _normalizeExposureCategoryLookupLabel(label);
  if (normalized.isEmpty) {
    return null;
  }
  if (normalized == _normalizeExposureCategoryLookupLabel('Hors bilan')) {
    return null;
  }
  for (final item in exposureCategories) {
    if (normalized == _normalizeExposureCategoryLookupLabel(item.label) ||
        normalized ==
            _normalizeExposureCategoryLookupLabel(item.prudentialLabel) ||
        normalized ==
            _normalizeExposureCategoryLookupLabel(item.legacyLabel ?? '')) {
      return item;
    }
  }
  return null;
}

ExposureCategoryOption exposureCategoryByName(String label) {
  final matched = tryExposureCategoryByName(label);
  if (matched != null) {
    return matched;
  }
  final normalized = _normalizeExposureCategoryLookupLabel(label);
  if (normalized == _normalizeExposureCategoryLookupLabel('Hors bilan')) {
    return exposureCategories.firstWhere(
      (item) => item.code == 'e',
      orElse: () => exposureCategories[4],
    );
  }
  return exposureCategories.firstWhere(
    (item) =>
        _normalizeExposureCategoryLookupLabel(item.label) == normalized ||
        _normalizeExposureCategoryLookupLabel(item.prudentialLabel) ==
            normalized ||
        _normalizeExposureCategoryLookupLabel(item.legacyLabel ?? '') ==
            normalized,
    orElse: () => exposureCategories[4],
  );
}

List<ExposureCategoryOption> get guarantorEligibleCategories =>
    exposureCategories
        .where((item) => guarantorEligibleCategoryCodes.contains(item.code))
        .toList(growable: false);

String normalizeFinancedCrmCollateralRating(String rating) {
  return rating
      .trim()
      .toUpperCase()
      .replaceAll('É', 'E')
      .replaceAll('È', 'E')
      .replaceAll('Ê', 'E')
      .replaceAll('À', 'A')
      .replaceAll('Â', 'A')
      .replaceAll('Î', 'I')
      .replaceAll('Ï', 'I')
      .replaceAll('Ô', 'O')
      .replaceAll('Û', 'U')
      .replaceAll('Ü', 'U')
      .replaceAll('Ç', 'C')
      .replaceAll(' ', '_');
}

String coerceFinancedCrmCollateralRating(String rating) {
  final normalized = normalizeFinancedCrmCollateralRating(rating);
  return _financedCrmCollateralRatingLabelsByKey[normalized] ??
      (financedCrmDebtRatings.contains(rating)
          ? rating
          : financedCrmDebtRatings.last);
}

String normalizeFinancedCrmCurrency(String currency) {
  final normalized = normalizeCurrencyCode(currency);
  if (normalized == 'XOF' || currency.trim().toUpperCase() == 'FCFA') {
    return 'FCFA';
  }
  return normalized;
}

bool isFinancedCrmDebtCollateral(String collateralType) {
  return [
    'Titre de dette souverain',
    'Titre non noté émis par un État de l UMOA',
    'Titre de dette émis par un autre émetteur',
    'Titre garanti par un agent agréé par la BRVM',
    'Titre bancaire non noté',
  ].contains(collateralType);
}

bool isFinancedCrmCollateralTypeEligible(String collateralType) {
  return collateralType != 'Autre sûreté non éligible';
}

bool financedCrmCollateralRequiresIssuerRole(String collateralType) {
  return [
    'Titre de dette souverain',
    'Titre non noté émis par un État de l UMOA',
    'Titre de dette émis par un autre émetteur',
    'Titre garanti par un agent agréé par la BRVM',
    'Titre bancaire non noté',
  ].contains(collateralType);
}

bool financedCrmCollateralRequiresRating(String collateralType) {
  return [
    'Titre de dette souverain',
    'Titre de dette émis par un autre émetteur',
  ].contains(collateralType);
}

bool financedCrmCollateralRequiresResidualMaturity(String collateralType) {
  return isFinancedCrmDebtCollateral(collateralType);
}

bool financedCrmCollateralSupportsConvertibleIndexQuestion(
  String collateralType,
) {
  return collateralType == 'Obligation convertible en action';
}

bool financedCrmCollateralSupportsOpcvmHaircut(String collateralType) {
  return collateralType == 'OPCVM / FI';
}

bool financedCrmCollateralIsBasket(String collateralType) {
  return collateralType == 'Panier d actifs';
}

String formatFinancedCrmHaircutPercent(double value) {
  final percent = value * 100;
  if ((percent - percent.roundToDouble()).abs() < 0.001) {
    return '${percent.toStringAsFixed(0)} %';
  }
  return '${percent.toStringAsFixed(1).replaceAll('.', ',')} %';
}

double coerceFinancedCrmOpcvmHaircut(double? value) {
  if (value == null) {
    return financedCrmOpcvmHaircutLevels.last;
  }
  for (final option in financedCrmOpcvmHaircutLevels) {
    if ((option - value).abs() < 0.0001) {
      return option;
    }
  }
  return financedCrmOpcvmHaircutLevels.last;
}

String bucketizeRating(String rating) {
  final normalized = rating.trim().toUpperCase();
  if (normalized == 'AAA/AA') {
    return 'AAA/AA';
  }
  if (normalized == 'BB/B') {
    return 'BB/B';
  }
  if (['AAA', 'AA+', 'AA', 'AA-'].contains(normalized)) {
    return 'AAA/AA';
  }
  if (['A+', 'A', 'A-'].contains(normalized)) {
    return 'A';
  }
  if (['BBB+', 'BBB', 'BBB-'].contains(normalized)) {
    return 'BBB';
  }
  if (['BB+', 'BB', 'BB-', 'B+', 'B', 'B-'].contains(normalized)) {
    return 'BB/B';
  }
  if (normalized == '< B-') {
    return '< B-';
  }
  return 'Non noté';
}

double lookupSovereignOceRiskWeight(String note) {
  switch (note.trim()) {
    case '0':
    case '1':
      return 0.0;
    case '2':
      return 0.2;
    case '3':
      return 0.5;
    case '4':
    case '5':
    case '6':
      return 1.0;
    case '7':
      return 1.5;
    default:
      return 1.0;
  }
}

double lookupCountryRatingRiskWeight(String countryRating) {
  switch (bucketizeRating(countryRating)) {
    case 'AAA/AA':
      return 0.0;
    case 'A':
      return 0.2;
    case 'BBB':
      return 0.5;
    case 'BB/B':
      return 1.0;
    case '< B-':
      return 1.5;
    default:
      return 1.0;
  }
}

double lookupUnratedCounterpartyRiskWeight({
  String? countryRating,
  bool oceEstablished = false,
  String oceNote = '',
}) {
  if (oceEstablished) {
    return lookupSovereignOceRiskWeight(oceNote);
  }
  return lookupCountryRatingRiskWeight(countryRating ?? 'Non noté');
}

bool _shouldApplyUnratedCounterpartyCountryFloor(String categoryCode) {
  // Le dispositif prudentiel ne prévoit ce plancher que pour les entreprises
  // non notées : leur pondération ne peut être plus favorable que celle de
  // l'État du siège. Les autres catégories conservent leur pondération
  // « non noté » propre (BMD 50 %, IF 50 %/20 %, détail 75 %, immobilier
  // 35 %/75 %...), qui ne doit pas être écrasée.
  return categoryCode == 'e';
}

double applyUnratedCounterpartyCountryFloor(
  double riskWeight,
  String rating, {
  required String categoryCode,
  String? countryRating,
}) {
  if (!_shouldApplyUnratedCounterpartyCountryFloor(categoryCode)) {
    return riskWeight;
  }
  if (bucketizeRating(rating) != 'Non noté') {
    return riskWeight;
  }
  final countryWeight =
      lookupCountryRatingRiskWeight(countryRating ?? 'Non noté');
  return riskWeight > countryWeight ? riskWeight : countryWeight;
}

const String bankInstitutionEquivalentRulesCase = 'equivalent_umoa_rules';
const String bankInstitutionWeakPrudentialCase = 'weak_prudential_case';
const String bankInstitutionEligibleCategoriesCase = 'eligible_categories_case';

const List<String> bankInstitutionCaseOptions = [
  bankInstitutionEquivalentRulesCase,
  bankInstitutionWeakPrudentialCase,
  bankInstitutionEligibleCategoriesCase,
];

String bankInstitutionCaseLabel(String value) {
  switch (value) {
    case bankInstitutionEquivalentRulesCase:
      return "Banque hors UMOA soumise à des règles équivalentes à celles de l'UMOA";
    case bankInstitutionWeakPrudentialCase:
      return 'Banque en difficulté prudentielle';
    case bankInstitutionEligibleCategoriesCase:
      return 'Institution faisant partie des categories suivantes :';
    default:
      return "Banque hors UMOA soumise à des règles équivalentes à celles de l'UMOA";
  }
}

const String otherAssetCashType = 'Encaisse';
const String otherAssetCashEquivalentType =
    'Valeurs assimilées à l’encaisse, y compris l’or';
const String otherAssetImmediateCollectionType =
    'Valeurs à l’encaissement avec crédit immédiat';
const String otherAssetNonSignificantParticipationsType =
    'Participations non significatives non déduites des fonds propres';
const String otherAssetTangibleFixedAssetsType = 'Immobilisations corporelles';

/// Distinguer les immobilisations hors exploitation ne change pas leur
/// pondération — 100 %, comme les corporelles, et la même ligne RC265 à
/// l'EP20 — mais c'est le seul moyen de renseigner l'EP36, dont la limite
/// prudentielle ne vise qu'elles, et la norme RA009 de l'EP01.
///
/// Cette nature manquait ici alors que l'import l'acceptait déjà : une ligne
/// importée sous ce libellé puis modifiée depuis l'écran retombait en
/// « Autres éléments d'actifs non définis », ce qui vidait l'EP36 sans le dire.
const String otherAssetNonOperatingFixedAssetsType =
    'Immobilisations hors exploitation';

/// Les incorporelles ne sont pas pondérées : elles se retranchent des fonds
/// propres de base. Les déclarer sous cette nature est le seul moyen de
/// renseigner le poste pour mémoire IM011 de l'EP3M, qui recense les
/// déductions. L'EP20 les ignore, sans quoi elles compteraient deux fois.
const String otherAssetIntangibleFixedAssetsType =
    'Immobilisations incorporelles';
const String otherAssetMiscellaneousType = 'Autres actifs divers';
const String otherAssetEquityCommitmentsType =
    'Engagements en actions non déduits';
const String otherAssetNonEquivalentFinancialCompaniesType =
    'Expositions sur entreprises financières non soumises à une réglementation équivalente UMOA';
const String otherAssetUndefinedType = 'Autres éléments d’actifs non définis';
const String otherAssetSignificantParticipationsAndDtaType =
    'Participations significatives et impôts différés actifs non déduits';
const String otherAssetNonCompliantInstitutionsType =
    'Expositions sur établissements non conformes aux ratios de solvabilité';

const List<String> otherAssetTypeOptions = [
  otherAssetCashType,
  otherAssetCashEquivalentType,
  otherAssetImmediateCollectionType,
  otherAssetNonSignificantParticipationsType,
  otherAssetTangibleFixedAssetsType,
  // Même rang que dans OTHER_ASSET_TYPE_OPTIONS du backend : les deux listes
  // valident la même colonne d'import, elles doivent offrir les mêmes choix.
  otherAssetNonOperatingFixedAssetsType,
  otherAssetIntangibleFixedAssetsType,
  otherAssetMiscellaneousType,
  otherAssetEquityCommitmentsType,
  otherAssetNonEquivalentFinancialCompaniesType,
  otherAssetUndefinedType,
  otherAssetSignificantParticipationsAndDtaType,
  otherAssetNonCompliantInstitutionsType,
];

const String offBalanceLowRiskLevel = 'Risque faible';
const String offBalanceMinorRiskLevel = 'Risque mineur';
const String offBalanceMediumRiskLevel = 'Risque moyen';
const String offBalanceHighRiskLevel = 'Risque élevé';
const String offBalanceVeryHighRiskLevel = 'Risque très élevé';

const List<String> offBalanceRiskLevelOptions = [
  offBalanceLowRiskLevel,
  offBalanceMinorRiskLevel,
  offBalanceMediumRiskLevel,
  offBalanceHighRiskLevel,
  offBalanceVeryHighRiskLevel,
];

String? coerceOtherAssetType(
  String? value, {
  bool fallbackToUndefined = false,
}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isNotEmpty) {
    final normalized = _normalizeExposureLabel(trimmed);
    for (final option in otherAssetTypeOptions) {
      if (normalized == _normalizeExposureLabel(option)) {
        return option;
      }
    }
    if (normalized == _normalizeExposureLabel('Autres actifs')) {
      return otherAssetUndefinedType;
    }
  }
  return fallbackToUndefined ? otherAssetUndefinedType : null;
}

double lookupOtherAssetRiskWeight(String? otherAssetType) {
  switch (coerceOtherAssetType(otherAssetType, fallbackToUndefined: true)) {
    case otherAssetCashType:
    case otherAssetCashEquivalentType:
      return 0.0;
    case otherAssetImmediateCollectionType:
      return 0.2;
    // Les incorporelles se retranchent des fonds propres de base : les pondérer
    // en plus les compterait deux fois, en moins du numérateur du ratio et en
    // plus de son dénominateur. L'EP20 du FODEP ne leur donne aucune ligne pour
    // cette raison, et l'écran doit afficher le même ratio que l'état transmis.
    case otherAssetIntangibleFixedAssetsType:
      return 0.0;
    case otherAssetSignificantParticipationsAndDtaType:
    case otherAssetNonCompliantInstitutionsType:
      return 2.5;
    default:
      return 1.0;
  }
}

String? inferOffBalanceRiskLevelFromFactor(double? factor) {
  if (factor == null) {
    return null;
  }
  const epsilon = 0.0001;
  if ((factor - 0.1).abs() <= epsilon) {
    return offBalanceLowRiskLevel;
  }
  if ((factor - 0.2).abs() <= epsilon) {
    return offBalanceMinorRiskLevel;
  }
  if ((factor - 0.5).abs() <= epsilon) {
    return offBalanceMediumRiskLevel;
  }
  if ((factor - 0.75).abs() <= epsilon) {
    return offBalanceHighRiskLevel;
  }
  if ((factor - 1.0).abs() <= epsilon) {
    return offBalanceVeryHighRiskLevel;
  }
  return null;
}

String? coerceOffBalanceRiskLevel(
  String? value, {
  bool fallbackToVeryHigh = false,
  double? factorHint,
}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isNotEmpty) {
    final normalized = _normalizeExposureLabel(trimmed);
    for (final option in offBalanceRiskLevelOptions) {
      if (normalized == _normalizeExposureLabel(option)) {
        return option;
      }
    }
  }
  final inferred = inferOffBalanceRiskLevelFromFactor(factorHint);
  if (inferred != null) {
    return inferred;
  }
  return fallbackToVeryHigh ? offBalanceVeryHighRiskLevel : null;
}

double lookupOffBalanceFcec(String? offBalanceRiskLevel) {
  switch (coerceOffBalanceRiskLevel(
    offBalanceRiskLevel,
    fallbackToVeryHigh: true,
  )) {
    case offBalanceLowRiskLevel:
      return 0.1;
    case offBalanceMinorRiskLevel:
      return 0.2;
    case offBalanceMediumRiskLevel:
      return 0.5;
    case offBalanceHighRiskLevel:
      return 0.75;
    case offBalanceVeryHighRiskLevel:
    default:
      return 1.0;
  }
}

double lookupEnterpriseRiskWeight(
  String rating, {
  bool enterpriseExceedsBceaoDegradationThreshold = false,
  bool enterprisePrudentialProcedure = false,
}) {
  if (enterpriseExceedsBceaoDegradationThreshold ||
      enterprisePrudentialProcedure) {
    return 1.5;
  }
  final normalized = rating.trim().toUpperCase();
  if (['AAA', 'AA+', 'AA', 'AA-'].contains(normalized)) {
    return 0.2;
  }
  if (['A+', 'A', 'A-'].contains(normalized)) {
    return 0.5;
  }
  if (['BBB+', 'BBB', 'BBB-', 'BB+', 'BB', 'BB-'].contains(normalized)) {
    return 1.0;
  }
  if (['< BB-', 'B+', 'B', 'B-', '< B-'].contains(normalized)) {
    return 1.5;
  }
  return 1.0;
}

double lookupResidentialMortgageRiskWeight(bool? isEligible) {
  return isEligible == true ? residentialMortgageEligibleRiskWeight : 1.0;
}

double lookupCommercialRealEstateRiskWeight(bool? isEligible) {
  return isEligible == true ? commercialRealEstateEligibleRiskWeight : 1.0;
}

double lookupDefaultedExposureRiskWeight(
  double? initialRiskWeight, {
  bool? isResidentialMortgageInDefault,
  bool? provisionAtLeastTwentyPercent,
}) {
  final resolvedInitialRiskWeight =
      (initialRiskWeight ?? 1.0).clamp(0.0, 2.5).toDouble();
  if (resolvedInitialRiskWeight > 1.0) {
    return resolvedInitialRiskWeight;
  }
  if (isResidentialMortgageInDefault == true) {
    return 1.0;
  }
  if (provisionAtLeastTwentyPercent == true) {
    return 1.0;
  }
  // Provisions inférieures à 20 % de l'encours, ou niveau de provisionnement
  // non renseigné : le dispositif impose 150 % ; l'hypothèse prudente
  // s'applique tant que l'effort de provisionnement n'est pas démontré.
  return 1.5;
}

String? coerceBankInstitutionCase(String? value) {
  if (value == null) {
    return null;
  }
  final normalized = _normalizeExposureLabel(value);
  for (final option in bankInstitutionCaseOptions) {
    if (normalized == _normalizeExposureLabel(option)) {
      return option;
    }
  }
  if (normalized.contains('equival') && normalized.contains('umoa')) {
    return bankInstitutionEquivalentRulesCase;
  }
  if (normalized.contains('degrad') ||
      normalized.contains('solvabil') ||
      normalized.contains('fonds propres')) {
    return bankInstitutionWeakPrudentialCase;
  }
  if (normalized.contains('categor') && normalized.contains('banc')) {
    return bankInstitutionEligibleCategoriesCase;
  }
  return null;
}

/// Retourne la date d'octroi seulement si elle est cohérente : un octroi
/// postérieur à l'échéance ou à la date d'analyse est une erreur de saisie ;
/// la maturité initiale devient alors indéterminée et le calcul retombe sur
/// le traitement long terme, prudent.
DateTime? resolveCoherentGrantDate(
  DateTime? grantDate,
  DateTime? maturityDate, [
  DateTime? analysisDate,
]) {
  if (grantDate == null) {
    return null;
  }
  if (maturityDate != null && grantDate.isAfter(maturityDate)) {
    return null;
  }
  if (analysisDate != null && grantDate.isAfter(analysisDate)) {
    return null;
  }
  return grantDate;
}

bool hasShortInitialMaturity(DateTime? grantDate, DateTime? maturityDate) {
  if (grantDate == null || maturityDate == null) {
    return false;
  }
  if (grantDate.isAfter(maturityDate)) {
    return false;
  }
  return computeInitialMaturityMonths(grantDate, maturityDate) <= 3;
}

int computeInitialMaturityMonths(DateTime grantDate, DateTime maturityDate) {
  var months = (maturityDate.year - grantDate.year) * 12 +
      maturityDate.month -
      grantDate.month;
  if (maturityDate.day < grantDate.day) {
    months -= 1;
  }
  return months < 0 ? 0 : months;
}

double lookupBankInstitutionRiskWeight(
  String rating, {
  required bool isShortInitialMaturity,
}) {
  final ratingBucket = bucketizeRating(rating);
  if (isShortInitialMaturity) {
    switch (ratingBucket) {
      case 'AAA/AA':
      case 'A':
      case 'BBB':
        return 0.2;
      case 'BB/B':
        return 0.5;
      case '< B-':
        return 1.5;
      default:
        return 0.2;
    }
  }
  switch (ratingBucket) {
    case 'AAA/AA':
      return 0.2;
    case 'A':
      return 0.5;
    case 'BBB':
      return 0.5;
    case 'BB/B':
      return 1.0;
    case '< B-':
      return 1.5;
    default:
      return 0.5;
  }
}

double lookupPrudentialRiskWeight(
  String categoryCode,
  String rating, {
  String? countryRating,
  String sovereignSpecialCase = sovereignNoSpecialCase,
  bool sovereignPreferentialZeroWeight = false,
  bool sovereignOceEstablished = false,
  String sovereignOceNote = '',
  bool? publicBodyUemoaFcfaCase,
  bool? publicBodyFinancesNonPublicActivity,
  bool? bmdHighQualityCase,
  bool? bmdUemoaFcfaCase,
  bool? bmdUemoaCriteriaSatisfied,
  bool? bmdListedInstitutionFcfaCase,
  String? bankInstitutionCase,
  String? otherAssetType,
  String? offBalanceRiskLevel,
  bool? retailEligibilityCriteriaSatisfied,
  bool? enterpriseExceedsBceaoDegradationThreshold,
  bool? enterprisePrudentialProcedure,
  bool? enterpriseInvestmentFirmWithoutBankingLaw,
  bool? residentialMortgageEligible,
  bool? commercialRealEstateEligible,
  double? defaultedExposureInitialRiskWeight,
  bool? defaultedExposureResidentialMortgageInDefault,
  bool? defaultedExposureProvisionAtLeastTwentyPercent,
  DateTime? grantDate,
  DateTime? maturityDate,
}) {
  final category = exposureCategoryByCode(categoryCode);
  final ratingBucket = bucketizeRating(rating);
  double finalize(double riskWeight) => applyUnratedCounterpartyCountryFloor(
        riskWeight,
        rating,
        categoryCode: categoryCode,
        countryRating: countryRating,
      );
  if (categoryCode == 'a' &&
      hasSovereignPriorityZeroWeightCase(
        sovereignSpecialCase,
        sovereignPreferentialZeroWeight: sovereignPreferentialZeroWeight,
      )) {
    return finalize(0.0);
  }
  // Souverain non noté : la classification OCE peut être utilisée quand elle
  // est établie ; sinon la grille s'applique (non noté : 100 %).
  if (categoryCode == 'a' &&
      ratingBucket == 'Non noté' &&
      sovereignOceEstablished) {
    return finalize(lookupSovereignOceRiskWeight(sovereignOceNote));
  }
  if (categoryCode == 'b' &&
      hasPublicBodyPreferentialUemoaCase(
        publicBodyUemoaFcfaCase,
        publicBodyFinancesNonPublicActivity,
      )) {
    return finalize(publicBodyUemoaFcfaRiskWeight);
  }
  if (categoryCode == 'b' &&
      hasPublicBodyEnterpriseOverride(
        publicBodyUemoaFcfaCase,
        publicBodyFinancesNonPublicActivity,
      )) {
    return lookupPrudentialRiskWeight(
      'e',
      rating,
      countryRating: countryRating,
      sovereignOceEstablished: sovereignOceEstablished,
      sovereignOceNote: sovereignOceNote,
    );
  }
  // Organisme public non noté : pondération de la grille (100 %), pas de
  // substitution par la notation du pays.
  if (categoryCode == 'c' &&
      hasBmdPriorityZeroWeightCase(
        bmdHighQualityCase: bmdHighQualityCase,
        bmdUemoaFcfaCase: bmdUemoaFcfaCase,
        bmdUemoaCriteriaSatisfied: bmdUemoaCriteriaSatisfied,
        bmdListedInstitutionFcfaCase: bmdListedInstitutionFcfaCase,
      )) {
    return finalize(0.0);
  }
  // BMD non notée hors cas préférentiels : pondération de la grille (50 %).
  if (categoryCode == 'd') {
    final resolvedBankInstitutionCase =
        coerceBankInstitutionCase(bankInstitutionCase);
    if (resolvedBankInstitutionCase == bankInstitutionEquivalentRulesCase) {
      return finalize(1.0);
    }
    if (resolvedBankInstitutionCase == bankInstitutionWeakPrudentialCase) {
      return finalize(2.5);
    }
    // Cas général (grilles du dispositif) : la pondération dépend de la
    // notation ET de la maturité initiale (seuil de 3 mois), y compris pour
    // les non notées (50 % à plus de 3 mois, 20 % à 3 mois ou moins).
    return finalize(lookupBankInstitutionRiskWeight(
      rating,
      isShortInitialMaturity: hasShortInitialMaturity(grantDate, maturityDate),
    ));
  }
  if (categoryCode == 'e') {
    // Entreprise non notée : 100 % (grille), avec plancher à la pondération
    // de l'État du siège appliqué par finalize.
    return finalize(lookupEnterpriseRiskWeight(
      rating,
      enterpriseExceedsBceaoDegradationThreshold:
          enterpriseExceedsBceaoDegradationThreshold == true,
      enterprisePrudentialProcedure: enterprisePrudentialProcedure == true,
    ));
  }
  if (categoryCode == 'g') {
    return finalize(
      lookupResidentialMortgageRiskWeight(residentialMortgageEligible),
    );
  }
  if (categoryCode == 'h') {
    if (commercialRealEstateEligible == false) {
      return lookupPrudentialRiskWeight(
        'e',
        rating,
        countryRating: countryRating,
        sovereignOceEstablished: sovereignOceEstablished,
        sovereignOceNote: sovereignOceNote,
        enterpriseExceedsBceaoDegradationThreshold:
            enterpriseExceedsBceaoDegradationThreshold,
        enterprisePrudentialProcedure: enterprisePrudentialProcedure,
        enterpriseInvestmentFirmWithoutBankingLaw:
            enterpriseInvestmentFirmWithoutBankingLaw,
      );
    }
    return finalize(
      lookupCommercialRealEstateRiskWeight(commercialRealEstateEligible),
    );
  }
  if (categoryCode == 'i') {
    return finalize(lookupDefaultedExposureRiskWeight(
      defaultedExposureInitialRiskWeight,
      isResidentialMortgageInDefault:
          defaultedExposureResidentialMortgageInDefault,
      provisionAtLeastTwentyPercent:
          defaultedExposureProvisionAtLeastTwentyPercent,
    ));
  }
  if (categoryCode == 'f') {
    if (retailEligibilityCriteriaSatisfied == false) {
      return lookupPrudentialRiskWeight(
        'e',
        rating,
        countryRating: countryRating,
        sovereignOceEstablished: sovereignOceEstablished,
        sovereignOceNote: sovereignOceNote,
        enterpriseExceedsBceaoDegradationThreshold:
            enterpriseExceedsBceaoDegradationThreshold,
        enterprisePrudentialProcedure: enterprisePrudentialProcedure,
        enterpriseInvestmentFirmWithoutBankingLaw:
            enterpriseInvestmentFirmWithoutBankingLaw,
        grantDate: grantDate,
        maturityDate: maturityDate,
      );
    }
    return finalize(0.75);
  }
  if (categoryCode == 'k') {
    return finalize(lookupOtherAssetRiskWeight(otherAssetType));
  }
  if (categoryCode == 'l') {
    return finalize(lookupOffBalanceFcec(offBalanceRiskLevel));
  }
  if (category.fixedRiskWeight != null) {
    return finalize(category.fixedRiskWeight!);
  }

  switch (categoryCode) {
    case 'a':
      switch (ratingBucket) {
        case 'AAA/AA':
          return 0.0;
        case 'A':
          return 0.2;
        case 'BBB':
          return 0.5;
        case 'BB/B':
          return finalize(1.0);
        case '< B-':
          return finalize(1.5);
        default:
          return finalize(1.0);
      }
    case 'b':
      switch (ratingBucket) {
        case 'AAA/AA':
          return finalize(0.2);
        case 'A':
          return finalize(0.5);
        case 'BBB':
          return finalize(1.0);
        case 'BB/B':
          return finalize(1.0);
        case '< B-':
          return finalize(1.5);
        default:
          return finalize(1.0);
      }
    case 'c':
      switch (ratingBucket) {
        case 'AAA/AA':
          return finalize(0.2);
        case 'A':
          return finalize(0.5);
        case 'BBB':
          return finalize(0.5);
        case 'BB/B':
          return finalize(1.0);
        case '< B-':
          return finalize(1.5);
        default:
          return finalize(0.5);
      }
    case 'd':
      switch (ratingBucket) {
        case 'AAA/AA':
          return finalize(0.2);
        case 'A':
          return finalize(0.5);
        case 'BBB':
          return finalize(0.5);
        case 'BB/B':
          return finalize(1.0);
        case '< B-':
          return finalize(1.5);
        default:
          return finalize(1.0);
      }
    default:
      return finalize(1.0);
  }
}

const List<String> uemoaCountries = [
  'Benin',
  'Burkina Faso',
  "Cote d'Ivoire",
  'Guinee-Bissau',
  'Mali',
  'Niger',
  'Senegal',
  'Togo',
];

const List<String> cemacCountries = [
  'Cameroun',
  'Centrafrique',
  'Tchad',
  'Congo',
  'Gabon',
  'Guinee equatoriale',
];

const List<String> worldCountries = [
  'Afghanistan',
  'Afrique du Sud',
  'Albanie',
  'Algerie',
  'Allemagne',
  'Andorre',
  'Angola',
  'Antigua-et-Barbuda',
  'Arabie saoudite',
  'Argentine',
  'Armenie',
  'Australie',
  'Autriche',
  'Azerbaidjan',
  'Bahamas',
  'Bahrein',
  'Bangladesh',
  'Barbade',
  'Belgique',
  'Belize',
  'Benin',
  'Bhoutan',
  'Bielorussie',
  'Birmanie',
  'Bolivie',
  'Bosnie-Herzegovine',
  'Botswana',
  'Bresil',
  'Brunei',
  'Bulgarie',
  'Burkina Faso',
  'Burundi',
  'Cambodge',
  'Cameroun',
  'Canada',
  'Cap-Vert',
  'Centrafrique',
  'Chili',
  'Chine',
  'Chypre',
  'Colombie',
  'Comores',
  'Congo',
  'Coree du Nord',
  'Coree du Sud',
  'Costa Rica',
  "Cote d'Ivoire",
  'Croatie',
  'Cuba',
  'Danemark',
  'Djibouti',
  'Dominique',
  'Egypte',
  'Emirats arabes unis',
  'Equateur',
  'Erythree',
  'Espagne',
  'Estonie',
  'Eswatini',
  'Etats-Unis',
  'Ethiopie',
  'Fidji',
  'Finlande',
  'France',
  'Gabon',
  'Gambie',
  'Georgie',
  'Ghana',
  'Grece',
  'Grenade',
  'Guatemala',
  'Guinee',
  'Guinee-Bissau',
  'Guinee equatoriale',
  'Guyana',
  'Haiti',
  'Honduras',
  'Hongrie',
  'Iles Marshall',
  'Iles Salomon',
  'Inde',
  'Indonesie',
  'Irak',
  'Iran',
  'Irlande',
  'Islande',
  'Israel',
  'Italie',
  'Jamaïque',
  'Japon',
  'Jordanie',
  'Kazakhstan',
  'Kenya',
  'Kirghizistan',
  'Kiribati',
  'Kosovo',
  'Koweit',
  'Laos',
  'Lesotho',
  'Lettonie',
  'Liban',
  'Liberia',
  'Libye',
  'Liechtenstein',
  'Lituanie',
  'Luxembourg',
  'Macedoine du Nord',
  'Madagascar',
  'Malaisie',
  'Malawi',
  'Maldives',
  'Mali',
  'Malte',
  'Maroc',
  'Maurice',
  'Mauritanie',
  'Mexique',
  'Micronesie',
  'Moldavie',
  'Monaco',
  'Mongolie',
  'Montenegro',
  'Mozambique',
  'Namibie',
  'Nauru',
  'Nepal',
  'Nicaragua',
  'Niger',
  'Nigeria',
  'Norvege',
  'Nouvelle-Zelande',
  'Oman',
  'Ouganda',
  'Ouzbekistan',
  'Pakistan',
  'Palaos',
  'Palestine',
  'Panama',
  'Papouasie-Nouvelle-Guinee',
  'Paraguay',
  'Pays-Bas',
  'Perou',
  'Philippines',
  'Pologne',
  'Portugal',
  'Qatar',
  'Republique centrafricaine',
  'Republique democratique du Congo',
  'Republique dominicaine',
  'Republique tcheque',
  'Roumanie',
  'Royaume-Uni',
  'Russie',
  'Rwanda',
  'Saint-Christophe-et-Nieves',
  'Sainte-Lucie',
  'Saint-Marin',
  'Saint-Vincent-et-les-Grenadines',
  'Salvador',
  'Samoa',
  'Sao Tome-et-Principe',
  'Senegal',
  'Serbie',
  'Seychelles',
  'Sierra Leone',
  'Singapour',
  'Slovaquie',
  'Slovenie',
  'Somalie',
  'Soudan',
  'Soudan du Sud',
  'Sri Lanka',
  'Suede',
  'Suisse',
  'Suriname',
  'Syrie',
  'Tadjikistan',
  'Taiwan',
  'Tanzanie',
  'Tchad',
  'Thailande',
  'Timor oriental',
  'Togo',
  'Tonga',
  'Trinite-et-Tobago',
  'Tunisie',
  'Turkmenistan',
  'Turquie',
  'Tuvalu',
  'Ukraine',
  'Uruguay',
  'Vanuatu',
  'Vatican',
  'Venezuela',
  'Vietnam',
  'Yemen',
  'Zambie',
  'Zimbabwe',
];

const List<String> managedCountries = [
  ...uemoaCountries,
  ...cemacCountries,
  'France',
  'Allemagne',
  'Espagne',
  'Italie',
  'Maroc',
  'Tunisie',
  'Nigeria',
  'Ghana',
];

const Map<String, String> _countryDisplayOverrides = {
  'algerie': 'Algérie',
  'armenie': 'Arménie',
  'azerbaidjan': 'Azerbaïdjan',
  'bahrein': 'Bahreïn',
  'benin': 'Bénin',
  'bielorussie': 'Biélorussie',
  'bosnie herzegovine': 'Bosnie-Herzégovine',
  'bresil': 'Brésil',
  'coree du nord': 'Corée du Nord',
  'coree du sud': 'Corée du Sud',
  'cote d ivoire': "Côte d'Ivoire",
  'egypte': 'Égypte',
  'emirats arabes unis': 'Émirats arabes unis',
  'equateur': 'Équateur',
  'erythree': 'Érythrée',
  'etats unis': 'États-Unis',
  'ethiopie': 'Éthiopie',
  'georgie': 'Géorgie',
  'grece': 'Grèce',
  'guinee': 'Guinée',
  'guinee bissau': 'Guinée-Bissau',
  'guinee equatoriale': 'Guinée équatoriale',
  'haiti': 'Haïti',
  'iles marshall': 'Îles Marshall',
  'iles salomon': 'Îles Salomon',
  'indonesie': 'Indonésie',
  'koweit': 'Koweït',
  'macedoine du nord': 'Macédoine du Nord',
  'nepal': 'Népal',
  'norvege': 'Norvège',
  'nouvelle zelande': 'Nouvelle-Zélande',
  'ouzbekistan': 'Ouzbékistan',
  'perou': 'Pérou',
  'republique centrafricaine': 'République centrafricaine',
  'republique democratique du congo': 'République démocratique du Congo',
  'republique dominicaine': 'République dominicaine',
  'republique tcheque': 'République tchèque',
  'sao tome et principe': 'Sao Tomé-et-Principe',
  'senegal': 'Sénégal',
  'slovenie': 'Slovénie',
  'suede': 'Suède',
  'taiwan': 'Taïwan',
  'thailande': 'Thaïlande',
  'trinite et tobago': 'Trinité-et-Tobago',
  'yemen': 'Yémen',
};

String _normalizeCountry(String value) {
  return value
      .toLowerCase()
      .replaceAll("'", ' ')
      .replaceAll('-', ' ')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ô', 'o')
      .replaceAll('û', 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String normalizedCountryName(String? value) {
  return _normalizeCountry(value ?? '');
}

String canonicalCountryName(String? value, {String fallback = ''}) {
  final normalized = _normalizeCountry(value ?? '');
  if (normalized.isEmpty) {
    return fallback;
  }
  for (final country in worldCountries) {
    if (_normalizeCountry(country) == normalized) {
      return country;
    }
  }
  return fallback;
}

String displayCountryName(String? value, {String fallback = ''}) {
  final fallbackValue = fallback.isNotEmpty ? fallback : (value ?? '');
  final canonical = canonicalCountryName(value, fallback: fallbackValue);
  final normalized = _normalizeCountry(canonical);
  if (normalized.isEmpty) {
    return fallbackValue;
  }
  return _countryDisplayOverrides[normalized] ?? canonical;
}

String computeZone(String country) {
  final normalized = _normalizeCountry(country);
  if (uemoaCountries.map(_normalizeCountry).contains(normalized)) {
    return 'UEMOA';
  }
  if (cemacCountries.map(_normalizeCountry).contains(normalized)) {
    return 'CEMAC';
  }
  return 'Hors zone';
}

double convertAmount(
  double amount, {
  required String fromCurrency,
  required String toCurrency,
}) {
  final normalizedFrom = normalizeCurrencyCode(fromCurrency);
  final normalizedTo = normalizeCurrencyCode(toCurrency);
  final fromRate = currencyRatesInXaf[normalizedFrom] ?? 1.0;
  final toRate = currencyRatesInXaf[normalizedTo] ?? 1.0;
  final amountInXaf = amount * fromRate;
  return amountInXaf / toRate;
}

class CounterpartyModel {
  const CounterpartyModel({
    required this.id,
    required this.name,
    required this.country,
    required this.countryRating,
    required this.category,
    required this.rating,
  });

  final String id;
  final String name;
  final String country;
  final String countryRating;
  final String category;
  final String rating;

  factory CounterpartyModel.fromJson(Map<String, dynamic> json) {
    return CounterpartyModel(
      id: json['id'] as String,
      name: json['name'] as String,
      country: json['country'] as String,
      countryRating: (json['country_rating'] ?? 'Non noté') as String,
      category: json['category'] as String,
      rating: json['rating'] as String,
    );
  }
}

class FinancedCrmBasketItem {
  const FinancedCrmBasketItem({
    this.collateralType = 'Liquidités dans la même devise',
    this.value = 0,
    this.currency = 'XOF',
    this.issuerRole = 'autre émetteur',
    this.rating = 'Non noté',
    this.residualMaturityBucket = '<=1 an',
    this.convertibleMainIndex = true,
    this.opcvmHighestHaircut = 0.30,
  });

  final String collateralType;
  final double value;
  final String currency;
  final String issuerRole;
  final String rating;
  final String residualMaturityBucket;
  final bool convertibleMainIndex;
  final double opcvmHighestHaircut;

  factory FinancedCrmBasketItem.fromJson(Map<String, dynamic>? json) {
    return FinancedCrmBasketItem(
      collateralType: (json?['collateral_type'] ??
          financedCrmCollateralTypes.first) as String,
      value: ((json?['value'] ?? 0) as num).toDouble(),
      currency: normalizeCurrencyCode((json?['currency'] ?? 'XOF') as String),
      issuerRole:
          (json?['issuer_role'] ?? financedCrmIssuerRoleOptions.last) as String,
      rating: coerceFinancedCrmCollateralRating(
        (json?['rating'] ?? financedCrmDebtRatings.last) as String,
      ),
      residualMaturityBucket: (json?['residual_maturity_bucket'] ??
          financedCrmMaturityBuckets.first) as String,
      convertibleMainIndex: (json?['convertible_main_index'] ?? true) as bool,
      opcvmHighestHaircut: coerceFinancedCrmOpcvmHaircut(
        ((json?['opcvm_highest_haircut'] ?? 0.30) as num).toDouble(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'collateral_type': collateralType,
      'value': value,
      'currency': currency,
      'issuer_role': issuerRole,
      'rating': rating,
      'residual_maturity_bucket': residualMaturityBucket,
      'convertible_main_index': convertibleMainIndex,
      'opcvm_highest_haircut': opcvmHighestHaircut,
    };
  }
}

class FinancedCrmSnapshot {
  const FinancedCrmSnapshot({
    required this.riskWeight,
    required this.he,
    required this.hc,
    required this.hfx,
    required this.eva,
    required this.cva,
    required this.eadAfterFinancedCrm,
    required this.rwaFinal,
    required this.crmGain,
    required this.collateralEligible,
    required this.eligibilityReason,
    required this.coveragePercent,
  });

  final double riskWeight;
  final double he;
  final double hc;
  final double hfx;
  final double eva;
  final double cva;
  final double eadAfterFinancedCrm;
  final double rwaFinal;
  final double crmGain;
  final bool collateralEligible;
  final String eligibilityReason;
  final double coveragePercent;
}

class ExposureCrmDetails {
  const ExposureCrmDetails({
    this.mode = 'Aucune',
    this.label = 'Aucune',
    this.collateralValue = 0,
    this.collateralCurrency = 'XOF',
    this.collateralType = 'Liquidités dans la même devise',
    this.issuerType = '',
    this.issuerRating = '',
    this.maturityBucket = '<=1 an',
    this.convertibleMainIndex = true,
    this.opcvmHighestHaircut = 0.30,
    this.basketItems = const [],
    this.fxHaircut = 0,
    this.exposureCurrency = 'XOF',
    this.riskWeight = 0,
    this.eligible = true,
    this.eligibilityReason = '',
    this.he = 0,
    this.hc = 0,
    this.hfx = 0,
    this.eva = 0,
    this.cva = 0,
    this.eadAfterFinancedCrm = 0,
    this.rwaFinal = 0,
    this.crmGain = 0,
    this.guarantorName = '',
    this.guarantorCategory = '',
    this.guarantorRating = '',
    this.guarantorCountry = '',
    this.guarantorCountryRating = '',
    this.coveragePercent = 0,
  });

  final String mode;
  final String label;
  final double collateralValue;
  final String collateralCurrency;
  final String collateralType;
  final String issuerType;
  final String issuerRating;
  final String maturityBucket;
  final bool convertibleMainIndex;
  final double opcvmHighestHaircut;
  final List<FinancedCrmBasketItem> basketItems;
  final double fxHaircut;
  final String exposureCurrency;
  final double riskWeight;
  final bool eligible;
  final String eligibilityReason;
  final double he;
  final double hc;
  final double hfx;
  final double eva;
  final double cva;
  final double eadAfterFinancedCrm;
  final double rwaFinal;
  final double crmGain;
  final String guarantorName;
  final String guarantorCategory;
  final String guarantorRating;
  final String guarantorCountry;
  final String guarantorCountryRating;
  final double coveragePercent;

  factory ExposureCrmDetails.fromJson(Map<String, dynamic>? json) {
    return ExposureCrmDetails(
      mode: (json?['mode'] ?? 'Aucune') as String,
      label: (json?['label'] ?? '') as String,
      collateralValue: ((json?['collateral_value'] ?? 0) as num).toDouble(),
      collateralCurrency: normalizeCurrencyCode(
        (json?['collateral_currency'] ?? 'XOF') as String,
      ),
      collateralType: (json?['collateral_type'] ??
          'Liquidités dans la même devise') as String,
      issuerType: (json?['issuer_type'] ?? '') as String,
      issuerRating: coerceFinancedCrmCollateralRating(
        (json?['issuer_rating'] ?? financedCrmDebtRatings.last) as String,
      ),
      maturityBucket: (json?['maturity_bucket'] ?? '<=1 an') as String,
      convertibleMainIndex: (json?['convertible_main_index'] ?? true) as bool,
      opcvmHighestHaircut: coerceFinancedCrmOpcvmHaircut(
        ((json?['opcvm_highest_haircut'] ?? 0.30) as num).toDouble(),
      ),
      basketItems: ((json?['basket_items'] as List<dynamic>? ?? const [])
          .map(
            (item) => FinancedCrmBasketItem.fromJson(
              item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false)),
      fxHaircut: ((json?['fx_haircut'] ?? 0) as num).toDouble(),
      exposureCurrency: normalizeCurrencyCode(
        (json?['exposure_currency'] ?? 'XOF') as String,
      ),
      riskWeight: ((json?['risk_weight'] ??
              json?['rw_determined'] ??
              json?['final_rw'] ??
              0) as num)
          .toDouble(),
      eligible:
          (json?['eligible'] ?? json?['collateral_eligible'] ?? true) as bool,
      eligibilityReason: (json?['eligibility_reason'] ??
          json?['ineligibility_reason'] ??
          '') as String,
      he: ((json?['he'] ?? 0) as num).toDouble(),
      hc: ((json?['hc'] ?? json?['haircut'] ?? 0) as num).toDouble(),
      hfx: ((json?['hfx'] ?? json?['fx_haircut'] ?? 0) as num).toDouble(),
      eva: ((json?['eva'] ?? 0) as num).toDouble(),
      cva: ((json?['cva'] ?? 0) as num).toDouble(),
      eadAfterFinancedCrm:
          ((json?['ead_after_financed_crm'] ?? json?['ead'] ?? 0) as num)
              .toDouble(),
      rwaFinal: ((json?['rwa_final'] ?? json?['rwa'] ?? 0) as num).toDouble(),
      crmGain: ((json?['crm_gain'] ?? 0) as num).toDouble(),
      guarantorName: (json?['guarantor_name'] ?? '') as String,
      guarantorCategory: (json?['guarantor_category'] ?? '') as String,
      guarantorRating: (json?['guarantor_rating'] ?? '') as String,
      guarantorCountry: (json?['guarantor_country'] ?? '') as String,
      guarantorCountryRating:
          (json?['guarantor_country_rating'] ?? '') as String,
      coveragePercent: ((json?['coverage_percent'] ??
              json?['crm_coverage_percent'] ??
              0) as num)
          .toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'label': label,
      'collateral_value': collateralValue,
      'collateral_currency': collateralCurrency,
      'collateral_type': collateralType,
      'issuer_type': issuerType,
      'issuer_rating': issuerRating,
      'maturity_bucket': maturityBucket,
      'convertible_main_index': convertibleMainIndex,
      'opcvm_highest_haircut': opcvmHighestHaircut,
      'basket_items': basketItems.map((item) => item.toJson()).toList(),
      'fx_haircut': fxHaircut,
      'exposure_currency': exposureCurrency,
      'risk_weight': riskWeight,
      'eligible': eligible,
      'eligibility_reason': eligibilityReason,
      'he': he,
      'hc': hc,
      'hfx': hfx,
      'eva': eva,
      'cva': cva,
      'ead_after_financed_crm': eadAfterFinancedCrm,
      'rwa_final': rwaFinal,
      'crm_gain': crmGain,
      'guarantor_name': guarantorName,
      'guarantor_category': guarantorCategory,
      'guarantor_rating': guarantorRating,
      'guarantor_country': guarantorCountry,
      'guarantor_country_rating': guarantorCountryRating,
      'coverage_percent': coveragePercent,
    };
  }
}

class ExposureRecord {
  const ExposureRecord({
    required this.id,
    required this.analysisDate,
    this.grantDate,
    this.maturityDate,
    required this.counterparty,
    required this.grossAmount,
    this.loanTotalAmount,
    this.onBalanceExposureAmount,
    this.offBalanceExposureAmount,
    this.provisionsAmount,
    this.joursImpayes = 0,
    this.actualReimbursements = const {},
    this.exposureMaturityMonths,
    this.residualMaturityMonths,
    this.countryRiskWeight,
    this.eadBilanAmount,
    this.eadHbAmount,
    this.eadHbCcfAmount,
    this.eadTotalAmount,
    this.rwaEbAmount,
    this.rwaHbAmount,
    required this.currency,
    required this.crmType,
    required this.crmCoveragePercent,
    required this.originalRw,
    required this.finalRw,
    required this.ead,
    required this.rwa,
    required this.capital,
    required this.comment,
    required this.status,
    this.statutPrudentiel = 'saine',
    this.declassementManuel = false,
    this.declassementMotif,
    this.declassementLe,
    required this.crmDetails,
    required this.sovereignSpecialCase,
    required this.sovereignPreferentialZeroWeight,
    required this.sovereignOceEstablished,
    required this.sovereignOceNote,
    required this.publicBodyUemoaFcfaCase,
    required this.publicBodyFinancesNonPublicActivity,
    required this.bmdHighQualityCase,
    required this.bmdUemoaFcfaCase,
    required this.bmdUemoaCriteriaSatisfied,
    required this.bmdListedInstitutionFcfaCase,
    required this.bankInstitutionCase,
    required this.otherAssetType,
    required this.offBalanceRiskLevel,
    required this.retailEligibilityCriteriaSatisfied,
    required this.residentialMortgageEligible,
    required this.commercialRealEstateEligible,
    required this.enterpriseExceedsBceaoDegradationThreshold,
    required this.enterprisePrudentialProcedure,
    required this.enterpriseInvestmentFirmWithoutBankingLaw,
    required this.defaultedExposureInitialRiskWeight,
    required this.defaultedExposureResidentialMortgageInDefault,
    required this.defaultedExposureProvisionAtLeastTwentyPercent,
  });

  final String id;
  final DateTime analysisDate;
  final DateTime? grantDate;
  final DateTime? maturityDate;
  final CounterpartyModel counterparty;
  final double grossAmount;
  final double? loanTotalAmount;
  final double? onBalanceExposureAmount;
  final double? offBalanceExposureAmount;
  final double? provisionsAmount;
  final int joursImpayes;
  final Map<DateTime, double> actualReimbursements;
  final int? exposureMaturityMonths;
  final int? residualMaturityMonths;
  final double? countryRiskWeight;
  final double? eadBilanAmount;
  final double? eadHbAmount;
  final double? eadHbCcfAmount;
  final double? eadTotalAmount;
  final double? rwaEbAmount;
  final double? rwaHbAmount;
  final String currency;
  final String crmType;
  final double crmCoveragePercent;
  final double originalRw;
  final double finalRw;
  final double ead;
  final double rwa;
  final double capital;
  final String comment;
  final String status;
  final String statutPrudentiel;
  final bool declassementManuel;
  final String? declassementMotif;
  final String? declassementLe;
  final ExposureCrmDetails crmDetails;
  final String sovereignSpecialCase;
  final bool sovereignPreferentialZeroWeight;
  final bool sovereignOceEstablished;
  final String sovereignOceNote;
  final bool? publicBodyUemoaFcfaCase;
  final bool? publicBodyFinancesNonPublicActivity;
  final bool? bmdHighQualityCase;
  final bool? bmdUemoaFcfaCase;
  final bool? bmdUemoaCriteriaSatisfied;
  final bool? bmdListedInstitutionFcfaCase;
  final String? bankInstitutionCase;
  final String? otherAssetType;
  final String? offBalanceRiskLevel;
  final bool? retailEligibilityCriteriaSatisfied;
  final bool? enterpriseExceedsBceaoDegradationThreshold;
  final bool? enterprisePrudentialProcedure;
  final bool? enterpriseInvestmentFirmWithoutBankingLaw;
  final bool? residentialMortgageEligible;
  final bool? commercialRealEstateEligible;
  final double? defaultedExposureInitialRiskWeight;
  final bool? defaultedExposureResidentialMortgageInDefault;
  final bool? defaultedExposureProvisionAtLeastTwentyPercent;

  ExposureCategoryOption get categoryOption =>
      exposureCategoryByName(counterparty.category);
  String get categoryCode => categoryOption.code;
  String get categoryLabel {
    final matchedCategory = tryExposureCategoryByName(counterparty.category);
    if (matchedCategory != null) {
      return matchedCategory.prudentialLabel;
    }
    final rawCategory = counterparty.category.trim();
    return rawCategory.isEmpty ? 'Non renseigné' : rawCategory;
  }

  String get ratingLabel => bucketizeRating(counterparty.rating);
  String get crmModeLabel => crmDetails.mode;
  String get zone => computeZone(counterparty.country);

  String get regimePrudentielLabel {
    switch (categoryCode) {
      case 'a':
        if (sovereignSpecialCase.isNotEmpty && sovereignSpecialCase != 'aucun_cas' && sovereignSpecialCase != 'Aucun de ces cas') {
          return sovereignSpecialCase;
        }
        if (sovereignPreferentialZeroWeight) {
          return 'Souverain UEMOA (0%)';
        }
        if (sovereignOceEstablished && sovereignOceNote.isNotEmpty) {
          return 'Note OCE: $sovereignOceNote';
        }
        return 'Standard';
      case 'b':
        if (publicBodyFinancesNonPublicActivity == true) {
          return 'Activité commerciale (Entreprise)';
        }
        if (publicBodyUemoaFcfaCase == true) {
          return 'Organisme public UEMOA (20%)';
        }
        return 'Standard';
      case 'c':
        if (bmdListedInstitutionFcfaCase == true) {
          return 'BMD liste officielle (0%)';
        }
        if (bmdHighQualityCase == true) {
          return 'BMD haute qualité (0%)';
        }
        if (bmdUemoaFcfaCase == true) {
          return 'BMD UEMOA (20%)';
        }
        return 'Standard';
      case 'd':
        if (bankInstitutionCase == 'equivalent_umoa_rules') {
          return 'Banque agréée UEMOA';
        }
        if (bankInstitutionCase == 'weak_prudential_case') {
          return 'Faible qualité';
        }
        return 'Standard';
      case 'e':
        if (enterpriseExceedsBceaoDegradationThreshold == true) {
          return 'Portefeuille dégradé (150%)';
        }
        if (enterprisePrudentialProcedure == true) {
          return 'Procédure prudentielle (150%)';
        }
        if (enterpriseInvestmentFirmWithoutBankingLaw == true) {
          return 'Inv. hors loi bancaire (100%)';
        }
        return 'Standard';
      case 'f':
        if (retailEligibilityCriteriaSatisfied == true) {
          return 'Détail éligible (75%)';
        } else if (retailEligibilityCriteriaSatisfied == false) {
          return 'Non éligible (100%)';
        }
        return 'Standard';
      case 'g':
        if (residentialMortgageEligible == true) {
          return 'Immo résidentiel (35%)';
        } else if (residentialMortgageEligible == false) {
          return 'Non éligible (100%)';
        }
        return 'Standard';
      case 'h':
        if (commercialRealEstateEligible == true) {
          return 'Immo commercial (50%)';
        } else if (commercialRealEstateEligible == false) {
          return 'Non éligible (100%)';
        }
        return 'Standard';
      case 'i':
        if (defaultedExposureResidentialMortgageInDefault == true) {
          if (defaultedExposureProvisionAtLeastTwentyPercent == true) {
            return 'Défaut immo Prov >= 20% (50%)';
          }
          return 'Défaut immo Prov < 20% (100%)';
        } else {
          if (defaultedExposureProvisionAtLeastTwentyPercent == true) {
            return 'Défaut autre Prov >= 20% (100%)';
          }
          return 'Défaut autre Prov < 20% (150%)';
        }
      case 'k':
        if (otherAssetType != null && otherAssetType!.isNotEmpty) {
          return otherAssetType!;
        }
        return 'Standard';
      default:
        return 'Standard';
    }
  }
  bool get isDefaultLike => status == 'En defaut' || categoryCode == 'i' || (joursImpayes > 90) || (provisionsAmount != null && provisionsAmount! > 0);

  bool get isDouteuse => statutPrudentiel == 'douteuse';
  bool get isImpayee => statutPrudentiel == 'impayee';
  String get statutPrudentielLabel {
    switch (statutPrudentiel) {
      case 'douteuse':
        return 'Douteuse';
      case 'impayee':
        return 'Impayée';
      default:
        return 'Saine';
    }
  }

  // Montants convertis en XOF, à utiliser pour TOUT calcul agrégé (totaux,
  // parts, densités…). Les champs bruts restent dans la devise d'origine pour
  // l'affichage unitaire ; la conversion vers la devise d'affichage se fait au
  // moment du rendu, jamais dans les calculs.
  double _toXof(double amount) =>
      convertCurrencyAmount(amount, fromCurrency: currency, toCurrency: 'XOF');
  double get grossAmountXof => _toXof(grossAmount);
  double get eadXof => _toXof(ead);
  double get rwaXof => _toXof(rwa);
  double get capitalXof => _toXof(capital);

  factory ExposureRecord.fromJson(Map<String, dynamic> json) {
    final counterparty = CounterpartyModel.fromJson(
      json['counterparty'] as Map<String, dynamic>,
    );
    final categoryCode = exposureCategoryByName(counterparty.category).code;
    final grossAmount = (json['gross_amount'] as num).toDouble();
    final crmType = (json['crm_type'] ?? 'Aucune') as String;
    final crmCoveragePercent =
        (json['crm_coverage_percent'] as num? ?? 0).toDouble();
    final rawCrmDetails = json['crm_details'] as Map<String, dynamic>?;
    final normalizedCrmType = crmType.toLowerCase();
    final legacySovereignPreferentialZeroWeight =
        (json['sovereign_preferential_zero_weight'] ?? false) as bool;
    final inferredCrmMode = normalizedCrmType.contains('garantie') ||
            normalizedCrmType.contains('assurance') ||
            normalizedCrmType.contains('non finance')
        ? 'CRM non financee'
        : normalizedCrmType.contains('cash') ||
                normalizedCrmType.contains('collateral') ||
                normalizedCrmType.contains('financee')
            ? 'CRM financee'
            : crmType == 'Aucune'
                ? 'Aucune'
                : 'CRM non financee';
    final crmDetails = ExposureCrmDetails.fromJson(
      rawCrmDetails ??
          {
            'mode': inferredCrmMode,
            'label': crmType,
            'coverage_percent': crmCoveragePercent,
          },
    );

    final Map<DateTime, double> parsedActualReimbursements = {};
    if (json['actual_reimbursements'] != null) {
      final map = json['actual_reimbursements'] as Map<String, dynamic>;
      for (final entry in map.entries) {
        try {
          final parts = entry.key.split('-'); // format "YYYY-MM"
          if (parts.length >= 2) {
            final monthKey = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
            parsedActualReimbursements[monthKey] = (entry.value as num).toDouble();
          }
        } catch (_) {}
      }
    }

    return ExposureRecord(
      id: json['id'] as String,
      analysisDate: DateTime.parse(json['analysis_date'] as String),
      grantDate: json['grant_date'] == null
          ? null
          : DateTime.parse(json['grant_date'] as String),
      maturityDate: json['maturity_date'] == null
          ? null
          : DateTime.parse(json['maturity_date'] as String),
      counterparty: counterparty,
      grossAmount: grossAmount,
      loanTotalAmount: (json['loan_total_amount'] as num?)?.toDouble(),
      onBalanceExposureAmount:
          (json['on_balance_exposure_amount'] as num?)?.toDouble(),
      offBalanceExposureAmount:
          (json['off_balance_exposure_amount'] as num?)?.toDouble(),
      provisionsAmount: (json['provisions_amount'] as num?)?.toDouble(),
      joursImpayes: (json['jours_impayes'] as num?)?.toInt() ?? 0,
      actualReimbursements: parsedActualReimbursements,
      exposureMaturityMonths:
          (json['exposure_maturity_months'] as num?)?.toInt(),
      residualMaturityMonths:
          (json['residual_maturity_months'] as num?)?.toInt(),
      countryRiskWeight: (json['country_risk_weight'] as num?)?.toDouble(),
      eadBilanAmount: (json['ead_bilan_amount'] as num?)?.toDouble(),
      eadHbAmount: (json['ead_hb_amount'] as num?)?.toDouble(),
      eadHbCcfAmount: (json['ead_hb_ccf_amount'] as num?)?.toDouble(),
      eadTotalAmount: (json['ead_total_amount'] as num?)?.toDouble(),
      rwaEbAmount: (json['rwa_eb_amount'] as num?)?.toDouble(),
      rwaHbAmount: (json['rwa_hb_amount'] as num?)?.toDouble(),
      currency: normalizeCurrencyCode((json['currency'] ?? 'XOF') as String),
      crmType: crmType,
      crmCoveragePercent: crmCoveragePercent == 0
          ? crmDetails.coveragePercent
          : crmCoveragePercent,
      originalRw: (json['original_rw'] as num).toDouble(),
      finalRw: (json['final_rw'] as num).toDouble(),
      ead: (json['ead'] as num).toDouble(),
      rwa: (json['rwa'] as num).toDouble(),
      capital: (json['capital'] as num).toDouble(),
      comment: (json['comment'] ?? '') as String,
      status: (json['status'] ?? 'Active') as String,
      statutPrudentiel: (json['statut_prudentiel'] ?? 'saine') as String,
      declassementManuel: (json['declassement_manuel'] ?? false) as bool,
      declassementMotif: json['declassement_motif'] as String?,
      declassementLe: json['declassement_le'] as String?,
      crmDetails: crmDetails,
      sovereignSpecialCase: coerceSovereignSpecialCase(
        json['sovereign_special_case'] as String?,
        fallbackToLegacy: legacySovereignPreferentialZeroWeight,
      ),
      sovereignPreferentialZeroWeight: legacySovereignPreferentialZeroWeight,
      sovereignOceEstablished:
          (json['sovereign_oce_established'] ?? false) as bool,
      sovereignOceNote: (json['sovereign_oce_note'] ?? '') as String,
      publicBodyUemoaFcfaCase: json['public_body_uemoa_fcfa_case'] as bool?,
      publicBodyFinancesNonPublicActivity:
          json['public_body_non_public_activity'] as bool?,
      bmdHighQualityCase: json['bmd_high_quality_case'] as bool?,
      bmdUemoaFcfaCase: json['bmd_uemoa_fcfa_case'] as bool?,
      bmdUemoaCriteriaSatisfied: json['bmd_uemoa_criteria_satisfied'] as bool?,
      bmdListedInstitutionFcfaCase:
          json['bmd_listed_institution_fcfa_case'] as bool?,
      bankInstitutionCase:
          coerceBankInstitutionCase(json['bank_institution_case'] as String?),
      otherAssetType: coerceOtherAssetType(
            json['other_asset_type'] as String?,
            fallbackToUndefined: categoryCode == 'k',
          ) ??
          (categoryCode == 'k' ? otherAssetUndefinedType : null),
      offBalanceRiskLevel: coerceOffBalanceRiskLevel(
            json['off_balance_risk_level'] as String?,
            fallbackToVeryHigh: categoryCode == 'l',
            factorHint: (json['final_rw'] as num?)?.toDouble(),
          ) ??
          (categoryCode == 'l' ? offBalanceVeryHighRiskLevel : null),
      retailEligibilityCriteriaSatisfied:
          json['retail_eligibility_criteria_satisfied'] as bool?,
      enterpriseExceedsBceaoDegradationThreshold:
          json['enterprise_exceeds_bceao_degradation_threshold'] as bool?,
      enterprisePrudentialProcedure:
          json['enterprise_prudential_procedure'] as bool?,
      enterpriseInvestmentFirmWithoutBankingLaw:
          json['enterprise_investment_firm_without_banking_law'] as bool?,
      residentialMortgageEligible:
          json['residential_mortgage_eligible'] as bool?,
      commercialRealEstateEligible:
          json['commercial_real_estate_eligible'] as bool?,
      defaultedExposureInitialRiskWeight:
          (json['defaulted_exposure_initial_risk_weight'] as num?)?.toDouble(),
      defaultedExposureResidentialMortgageInDefault:
          json['defaulted_exposure_residential_mortgage_in_default'] as bool?,
      defaultedExposureProvisionAtLeastTwentyPercent:
          json['defaulted_exposure_provision_at_least_twenty_percent'] as bool?,
    );
  }

  ExposureDraft toDraft() {
    final resolvedOnBalanceExposureAmount =
        onBalanceExposureAmount ?? (categoryCode == 'l' ? 0.0 : grossAmount);
    final resolvedLoanTotalAmount = loanTotalAmount ??
        (categoryCode == 'l'
            ? grossAmount
            : (grossAmount >= resolvedOnBalanceExposureAmount
                ? grossAmount
                : resolvedOnBalanceExposureAmount));
    return ExposureDraft(
      id: id,
      counterpartyName: counterparty.name,
      country: counterparty.country,
      countryRating: counterparty.countryRating,
      categoryCode: categoryCode,
      rating: counterparty.rating,
      grossAmount: grossAmount,
      loanTotalAmount: resolvedLoanTotalAmount,
      onBalanceExposureAmount: resolvedOnBalanceExposureAmount,
      provisionsAmount: provisionsAmount,
      joursImpayes: joursImpayes,
      currency: currency,
      status: status,
      crmMode: crmDetails.mode == 'Aucune' ? 'Aucune' : crmDetails.mode,
      crmType: crmType,
      collateralValue: crmDetails.collateralValue,
      collateralCurrency: crmDetails.collateralCurrency,
      collateralType: crmDetails.collateralType,
      issuerType: crmDetails.issuerType,
      issuerRating: crmDetails.issuerRating,
      maturityBucket: crmDetails.maturityBucket,
      fxHaircut: crmDetails.hfx == 0 ? crmDetails.fxHaircut : crmDetails.hfx,
      convertibleMainIndex: crmDetails.convertibleMainIndex,
      opcvmHighestHaircut: crmDetails.opcvmHighestHaircut,
      basketItems: crmDetails.basketItems,
      guarantorName: crmDetails.guarantorName,
      guarantorCategoryCode: crmDetails.guarantorCategory.isEmpty
          ? 'a'
          : exposureCategoryByName(crmDetails.guarantorCategory).code,
      guarantorRating: crmDetails.guarantorRating,
      guarantorCountry: crmDetails.guarantorCountry,
      guarantorCountryRating: crmDetails.guarantorCountryRating,
      crmCoveragePercent: crmCoveragePercent,
      comment: comment,
      analysisDate: analysisDate,
      grantDate: grantDate,
      maturityDate: maturityDate,
      sovereignSpecialCase: sovereignSpecialCase,
      sovereignPreferentialZeroWeight: sovereignPreferentialZeroWeight,
      sovereignOceEstablished: sovereignOceEstablished,
      sovereignOceNote: sovereignOceNote,
      publicBodyUemoaFcfaCase: publicBodyUemoaFcfaCase,
      publicBodyFinancesNonPublicActivity: publicBodyFinancesNonPublicActivity,
      bmdHighQualityCase: bmdHighQualityCase,
      bmdUemoaFcfaCase: bmdUemoaFcfaCase,
      bmdUemoaCriteriaSatisfied: bmdUemoaCriteriaSatisfied,
      bmdListedInstitutionFcfaCase: bmdListedInstitutionFcfaCase,
      bankInstitutionCase: bankInstitutionCase,
      otherAssetType: otherAssetType,
      offBalanceRiskLevel: offBalanceRiskLevel,
      retailEligibilityCriteriaSatisfied: retailEligibilityCriteriaSatisfied,
      enterpriseExceedsBceaoDegradationThreshold:
          enterpriseExceedsBceaoDegradationThreshold,
      enterprisePrudentialProcedure: enterprisePrudentialProcedure,
      enterpriseInvestmentFirmWithoutBankingLaw:
          enterpriseInvestmentFirmWithoutBankingLaw,
      residentialMortgageEligible: residentialMortgageEligible,
      commercialRealEstateEligible: commercialRealEstateEligible,
      defaultedExposureInitialRiskWeight: defaultedExposureInitialRiskWeight,
      defaultedExposureResidentialMortgageInDefault:
          defaultedExposureResidentialMortgageInDefault,
      defaultedExposureProvisionAtLeastTwentyPercent:
          defaultedExposureProvisionAtLeastTwentyPercent,
    );
  }
}

class ExposureSummary {
  const ExposureSummary({
    required this.totalExpositions,
    required this.totalEad,
    required this.totalRwa,
    required this.totalCapital,
  });

  final double totalExpositions;
  final double totalEad;
  final double totalRwa;
  final double totalCapital;

  factory ExposureSummary.fromJson(Map<String, dynamic> json) {
    return ExposureSummary(
      totalExpositions: (json['total_expositions'] as num).toDouble(),
      totalEad: (json['total_ead'] as num).toDouble(),
      totalRwa: (json['total_rwa'] as num).toDouble(),
      totalCapital: (json['total_capital'] as num).toDouble(),
    );
  }
}

class ExposureModuleData {
  const ExposureModuleData({
    required this.exposures,
    required this.summary,
  });

  final List<ExposureRecord> exposures;
  final ExposureSummary summary;
}

class ExposureDraft {
  const ExposureDraft({
    this.id,
    required this.counterpartyName,
    required this.country,
    required this.countryRating,
    required this.categoryCode,
    required this.rating,
    required this.grossAmount,
    required this.loanTotalAmount,
    required this.onBalanceExposureAmount,
    this.provisionsAmount,
    this.joursImpayes = 0,
    required this.currency,
    required this.status,
    required this.crmMode,
    required this.crmType,
    required this.collateralValue,
    this.collateralCurrency = 'XOF',
    this.collateralType = 'Liquidités dans la même devise',
    required this.issuerType,
    required this.issuerRating,
    required this.maturityBucket,
    required this.fxHaircut,
    this.convertibleMainIndex = true,
    this.opcvmHighestHaircut = 0.30,
    this.basketItems = const [],
    required this.guarantorName,
    required this.guarantorCategoryCode,
    required this.guarantorRating,
    required this.guarantorCountry,
    required this.guarantorCountryRating,
    required this.crmCoveragePercent,
    required this.comment,
    required this.analysisDate,
    this.grantDate,
    this.maturityDate,
    required this.sovereignSpecialCase,
    required this.sovereignPreferentialZeroWeight,
    required this.sovereignOceEstablished,
    required this.sovereignOceNote,
    required this.publicBodyUemoaFcfaCase,
    required this.publicBodyFinancesNonPublicActivity,
    required this.bmdHighQualityCase,
    required this.bmdUemoaFcfaCase,
    required this.bmdUemoaCriteriaSatisfied,
    required this.bmdListedInstitutionFcfaCase,
    required this.bankInstitutionCase,
    required this.otherAssetType,
    required this.offBalanceRiskLevel,
    required this.retailEligibilityCriteriaSatisfied,
    required this.enterpriseExceedsBceaoDegradationThreshold,
    required this.enterprisePrudentialProcedure,
    required this.enterpriseInvestmentFirmWithoutBankingLaw,
    required this.residentialMortgageEligible,
    required this.commercialRealEstateEligible,
    required this.defaultedExposureInitialRiskWeight,
    required this.defaultedExposureResidentialMortgageInDefault,
    required this.defaultedExposureProvisionAtLeastTwentyPercent,
  });

  final String? id;
  final String counterpartyName;
  final String country;
  final String countryRating;
  final String categoryCode;
  final String rating;
  final double grossAmount;
  final double loanTotalAmount;
  final double onBalanceExposureAmount;
  final double? provisionsAmount;
  final int joursImpayes;
  final String currency;
  final String status;
  final String crmMode;
  final String crmType;
  final double collateralValue;
  final String collateralCurrency;
  final String collateralType;
  final String issuerType;
  final String issuerRating;
  final String maturityBucket;
  final double fxHaircut;
  final bool convertibleMainIndex;
  final double opcvmHighestHaircut;
  final List<FinancedCrmBasketItem> basketItems;
  final String guarantorName;
  final String guarantorCategoryCode;
  final String guarantorRating;
  final String guarantorCountry;
  final String guarantorCountryRating;
  final double crmCoveragePercent;
  final String comment;
  final DateTime analysisDate;
  final DateTime? grantDate;
  final DateTime? maturityDate;
  final String sovereignSpecialCase;
  final bool sovereignPreferentialZeroWeight;
  final bool sovereignOceEstablished;
  final String sovereignOceNote;
  final bool? publicBodyUemoaFcfaCase;
  final bool? publicBodyFinancesNonPublicActivity;
  final bool? bmdHighQualityCase;
  final bool? bmdUemoaFcfaCase;
  final bool? bmdUemoaCriteriaSatisfied;
  final bool? bmdListedInstitutionFcfaCase;
  final String? bankInstitutionCase;
  final String? otherAssetType;
  final String? offBalanceRiskLevel;
  final bool? retailEligibilityCriteriaSatisfied;
  final bool? enterpriseExceedsBceaoDegradationThreshold;
  final bool? enterprisePrudentialProcedure;
  final bool? enterpriseInvestmentFirmWithoutBankingLaw;
  final bool? residentialMortgageEligible;
  final bool? commercialRealEstateEligible;
  final double? defaultedExposureInitialRiskWeight;
  final bool? defaultedExposureResidentialMortgageInDefault;
  final bool? defaultedExposureProvisionAtLeastTwentyPercent;

  ExposureCategoryOption get category => exposureCategoryByCode(categoryCode);
  ExposureCategoryOption get guarantorCategory =>
      exposureCategoryByCode(guarantorCategoryCode);
  double get offBalanceExposureAmount {
    final value = loanTotalAmount - onBalanceExposureAmount;
    return value <= 0 ? 0.0 : value;
  }

  String get backendCategory => category.prudentialLabel;

  String get backendCrmType {
    switch (crmMode) {
      case 'CRM financee':
        return 'Cash collateral';
      case 'CRM non financee':
        return crmType == 'Aucune' ? 'Garantie etatique' : crmType;
      default:
        return 'Aucune';
    }
  }

  Map<String, dynamic> get crmDetailsJson {
    final financedSnapshot =
        crmMode == 'CRM financee' ? computeFinancedCrmSnapshot(this) : null;
    return {
      'mode': crmMode,
      'label': crmType,
      'collateral_value': collateralValue,
      'collateral_currency': collateralCurrency,
      'collateral_type': collateralType,
      'issuer_type': issuerType,
      'issuer_rating': issuerRating,
      'maturity_bucket': maturityBucket,
      'convertible_main_index': convertibleMainIndex,
      'opcvm_highest_haircut': opcvmHighestHaircut,
      'basket_items': basketItems.map((item) => item.toJson()).toList(),
      'fx_haircut':
          crmMode == 'CRM financee' ? financedSnapshot!.hfx : fxHaircut,
      'exposure_currency': currency,
      'risk_weight': financedSnapshot?.riskWeight ?? 0.0,
      'eligible': financedSnapshot?.collateralEligible ?? true,
      'eligibility_reason': financedSnapshot?.eligibilityReason ?? '',
      'he': financedSnapshot?.he ?? 0.0,
      'hc': financedSnapshot?.hc ?? 0.0,
      'hfx': financedSnapshot?.hfx ?? 0.0,
      'eva': financedSnapshot?.eva ?? 0.0,
      'cva': financedSnapshot?.cva ?? 0.0,
      'ead_after_financed_crm':
          financedSnapshot?.eadAfterFinancedCrm ?? grossAmount,
      'rwa_final': financedSnapshot?.rwaFinal ?? 0.0,
      'crm_gain': financedSnapshot?.crmGain ?? 0.0,
      'guarantor_name': guarantorName,
      'guarantor_category': guarantorCategory.prudentialLabel,
      'guarantor_rating': guarantorRating,
      'guarantor_country': guarantorCountry,
      'guarantor_country_rating': guarantorCountryRating,
      'coverage_percent': crmMode == 'CRM financee'
          ? financedSnapshot?.coveragePercent ?? crmCoveragePercent
          : crmCoveragePercent,
    };
  }
}

const List<String> sovereignOceNotes = ['0', '1', '2', '3', '4', '5', '6', '7'];
const double publicBodyUemoaFcfaRiskWeight = 0.2;

bool hasPublicBodyPreferentialUemoaCase(
  bool? publicBodyUemoaFcfaCase,
  bool? publicBodyFinancesNonPublicActivity,
) {
  return publicBodyUemoaFcfaCase == true &&
      publicBodyFinancesNonPublicActivity == false;
}

bool hasPublicBodyEnterpriseOverride(
  bool? publicBodyUemoaFcfaCase,
  bool? publicBodyFinancesNonPublicActivity,
) {
  return publicBodyUemoaFcfaCase == true &&
      publicBodyFinancesNonPublicActivity == true;
}

bool hasBmdPriorityZeroWeightCase({
  bool? bmdHighQualityCase,
  bool? bmdUemoaFcfaCase,
  bool? bmdUemoaCriteriaSatisfied,
  bool? bmdListedInstitutionFcfaCase,
}) {
  return bmdHighQualityCase == true ||
      (bmdUemoaFcfaCase == true && bmdUemoaCriteriaSatisfied == true) ||
      bmdListedInstitutionFcfaCase == true;
}

class ExposureComputation {
  const ExposureComputation({
    required this.originalRw,
    required this.finalRw,
    required this.ead,
    required this.rwa,
    required this.capital,
    required this.effectiveCoverage,
    required this.haircut,
  });

  final double originalRw;
  final double finalRw;
  final double ead;
  final double rwa;
  final double capital;
  final double effectiveCoverage;
  final double haircut;
}

double _lookupOriginalRiskWeightForDraft(ExposureDraft draft) {
  return lookupPrudentialRiskWeight(
    draft.categoryCode,
    draft.rating,
    countryRating: draft.countryRating,
    sovereignSpecialCase: draft.sovereignSpecialCase,
    sovereignPreferentialZeroWeight: draft.sovereignPreferentialZeroWeight,
    sovereignOceEstablished: draft.sovereignOceEstablished,
    sovereignOceNote: draft.sovereignOceNote,
    publicBodyUemoaFcfaCase: draft.publicBodyUemoaFcfaCase,
    publicBodyFinancesNonPublicActivity:
        draft.publicBodyFinancesNonPublicActivity,
    bmdHighQualityCase: draft.bmdHighQualityCase,
    bmdUemoaFcfaCase: draft.bmdUemoaFcfaCase,
    bmdUemoaCriteriaSatisfied: draft.bmdUemoaCriteriaSatisfied,
    bmdListedInstitutionFcfaCase: draft.bmdListedInstitutionFcfaCase,
    bankInstitutionCase: draft.bankInstitutionCase,
    otherAssetType: draft.otherAssetType,
    offBalanceRiskLevel: draft.offBalanceRiskLevel,
    retailEligibilityCriteriaSatisfied:
        draft.retailEligibilityCriteriaSatisfied,
    enterpriseExceedsBceaoDegradationThreshold:
        draft.enterpriseExceedsBceaoDegradationThreshold,
    enterprisePrudentialProcedure: draft.enterprisePrudentialProcedure,
    enterpriseInvestmentFirmWithoutBankingLaw:
        draft.enterpriseInvestmentFirmWithoutBankingLaw,
    residentialMortgageEligible: draft.residentialMortgageEligible,
    commercialRealEstateEligible: draft.commercialRealEstateEligible,
    defaultedExposureInitialRiskWeight:
        draft.defaultedExposureInitialRiskWeight,
    defaultedExposureResidentialMortgageInDefault:
        draft.defaultedExposureResidentialMortgageInDefault,
    defaultedExposureProvisionAtLeastTwentyPercent:
        draft.defaultedExposureProvisionAtLeastTwentyPercent,
    grantDate: resolveCoherentGrantDate(
      draft.grantDate,
      draft.maturityDate,
      draft.analysisDate,
    ),
    maturityDate: draft.maturityDate,
  );
}

double _resolvedOnBalanceAmountForDraft(ExposureDraft draft) {
  if (draft.categoryCode == 'l') {
    return 0.0;
  }
  return draft.onBalanceExposureAmount < 0
      ? 0.0
      : draft.onBalanceExposureAmount;
}

double _resolvedOffBalanceCcfAmountForDraft(ExposureDraft draft) {
  final offBalanceAmount = draft.offBalanceExposureAmount;
  if (offBalanceAmount <= 0) {
    return 0.0;
  }
  return offBalanceAmount * lookupOffBalanceFcec(draft.offBalanceRiskLevel);
}

class _FinancedCrmCollateralOutcome {
  const _FinancedCrmCollateralOutcome({
    required this.eligible,
    required this.reason,
    required this.value,
    required this.hc,
    required this.hfx,
    required this.cva,
  });

  final bool eligible;
  final String reason;
  final double value;
  final double hc;
  final double hfx;
  final double cva;
}

double lookupFinancedCrmHfx({
  required String exposureCurrency,
  required String collateralCurrency,
}) {
  final exposure = normalizeFinancedCrmCurrency(exposureCurrency);
  final collateral = normalizeFinancedCrmCurrency(collateralCurrency);
  if (exposure == collateral) {
    return 0.0;
  }
  final isFcfaEuroPair = (exposure == 'FCFA' && collateral == 'EUR') ||
      (exposure == 'EUR' && collateral == 'FCFA');
  // Décote réglementaire pour asymétrie de devises (approche globale) : 8 %.
  return isFcfaEuroPair ? 0.0 : 0.08;
}

String _normalizeFinancedCrmMaturityBucket(String value) {
  return _normalizeMaturityBucket(value);
}

double _lookupDebtCollateralHaircut({
  required String collateralType,
  required String issuerRole,
  required String rating,
  required String maturityBucket,
}) {
  final normalizedRole = _normalizeExposureLabel(issuerRole);
  final sovereign = normalizedRole.contains('souverain');
  final bucket = _normalizeFinancedCrmMaturityBucket(maturityBucket);
  final normalizedRating = normalizeFinancedCrmCollateralRating(rating);

  if (collateralType == 'Titre non noté émis par un État de l UMOA') {
    if (bucket == '<=1 an') {
      return sovereign ? 0.005 : 0.01;
    }
    if (bucket == '1-3 ans' || bucket == '3-5 ans') {
      return sovereign
          ? 0.02
          : bucket == '1-3 ans'
              ? 0.03
              : 0.04;
    }
    if (bucket == '5-10 ans') {
      return sovereign ? 0.04 : 0.06;
    }
    return sovereign ? 0.04 : 0.12;
  }

  final isHighQuality = ['AAA', 'AA+', 'AA', 'AA-'].contains(normalizedRating);
  final isMediumQuality = [
    'A+',
    'A',
    'A-',
    'BBB+',
    'BBB',
    'BBB-',
  ].contains(normalizedRating);
  final isBbRange = ['BB+', 'BB', 'BB-'].contains(normalizedRating);

  if (collateralType == 'Titre garanti par un agent agréé par la BRVM' ||
      collateralType == 'Titre bancaire non noté') {
    if (bucket == '<=1 an') {
      return sovereign ? 0.01 : 0.02;
    }
    if (bucket == '1-3 ans') {
      return sovereign ? 0.03 : 0.04;
    }
    if (bucket == '3-5 ans') {
      return sovereign ? 0.03 : 0.06;
    }
    if (bucket == '5-10 ans') {
      return sovereign ? 0.06 : 0.12;
    }
    return sovereign ? 0.06 : 0.20;
  }

  if (isHighQuality) {
    if (bucket == '<=1 an') {
      return sovereign ? 0.005 : 0.01;
    }
    if (bucket == '1-3 ans') {
      return sovereign ? 0.02 : 0.03;
    }
    if (bucket == '3-5 ans') {
      return sovereign ? 0.02 : 0.04;
    }
    if (bucket == '5-10 ans') {
      return sovereign ? 0.04 : 0.06;
    }
    return sovereign ? 0.04 : 0.12;
  }

  if (isMediumQuality) {
    if (bucket == '<=1 an') {
      return sovereign ? 0.01 : 0.02;
    }
    if (bucket == '1-3 ans') {
      return sovereign ? 0.03 : 0.04;
    }
    if (bucket == '3-5 ans') {
      return sovereign ? 0.03 : 0.06;
    }
    if (bucket == '5-10 ans') {
      return sovereign ? 0.06 : 0.12;
    }
    return sovereign ? 0.06 : 0.20;
  }

  if (isBbRange && sovereign) {
    return 0.15;
  }

  return 0.0;
}

_FinancedCrmCollateralOutcome _evaluateSingleFinancedCollateral({
  required double exposureAmount,
  required String exposureCurrency,
  required double collateralValue,
  required String collateralCurrency,
  required String collateralType,
  required String issuerRole,
  required String rating,
  required String maturityBucket,
  required bool convertibleMainIndex,
  required double opcvmHighestHaircut,
}) {
  if (collateralValue <= 0) {
    return const _FinancedCrmCollateralOutcome(
      eligible: false,
      reason: 'Valeur de sûreté non renseignée.',
      value: 0.0,
      hc: 0.0,
      hfx: 0.0,
      cva: 0.0,
    );
  }

  if (!isFinancedCrmCollateralTypeEligible(collateralType)) {
    return const _FinancedCrmCollateralOutcome(
      eligible: false,
      reason: 'Cette sûreté n est pas reconnue par le dispositif prudentiel.',
      value: 0.0,
      hc: 0.0,
      hfx: 0.0,
      cva: 0.0,
    );
  }

  final normalizedRating = normalizeFinancedCrmCollateralRating(rating);
  final collateralValueInExposureCurrency = convertAmount(
    collateralValue,
    fromCurrency: collateralCurrency,
    toCurrency: exposureCurrency,
  ).clamp(0.0, double.infinity).toDouble();
  double hc = 0.0;
  var eligible = true;
  var reason = '';

  switch (collateralType) {
    case 'Liquidités dans la même devise':
    case 'Liquidités dans une devise différente':
      hc = 0.0;
      break;
    case 'Or':
    case 'Action de l indice BRVM 10':
    case 'Action d un indice principal reconnu':
      hc = 0.20;
      break;
    case 'Autre action cotée à la BRVM ou sur une bourse reconnue':
      hc = 0.30;
      break;
    case 'Obligation convertible en action':
      hc = convertibleMainIndex ? 0.20 : 0.30;
      break;
    case 'OPCVM / FI':
      hc = coerceFinancedCrmOpcvmHaircut(opcvmHighestHaircut);
      break;
    case 'Titre non noté émis par un État de l UMOA':
      hc = _lookupDebtCollateralHaircut(
        collateralType: collateralType,
        issuerRole: issuerRole,
        rating: rating,
        maturityBucket: maturityBucket,
      );
      break;
    case 'Titre garanti par un agent agréé par la BRVM':
    case 'Titre bancaire non noté':
      hc = _lookupDebtCollateralHaircut(
        collateralType: collateralType,
        issuerRole: issuerRole,
        rating: rating,
        maturityBucket: maturityBucket,
      );
      break;
    case 'Titre de dette souverain':
    case 'Titre de dette émis par un autre émetteur':
      if (normalizedRating == 'NON_NOTE') {
        eligible = false;
        reason =
            'La notation de la sûreté doit être renseignée pour ce titre de dette.';
      } else if (normalizedRating == '<_B-') {
        eligible = false;
        reason = 'Les titres en dessous de BB- ne sont pas éligibles.';
      } else if (['BB+', 'BB', 'BB-'].contains(normalizedRating) &&
          !_normalizeExposureLabel(issuerRole).contains('souverain')) {
        eligible = false;
        reason =
            'Un autre émetteur noté BB+ à BB- n est pas éligible à la CRM financée.';
      } else {
        hc = _lookupDebtCollateralHaircut(
          collateralType: collateralType,
          issuerRole: issuerRole,
          rating: rating,
          maturityBucket: maturityBucket,
        );
      }
      break;
    default:
      eligible = false;
      reason = 'Cette sûreté n est pas éligible à la réduction réglementaire.';
      break;
  }

  final hfx = lookupFinancedCrmHfx(
    exposureCurrency: exposureCurrency,
    collateralCurrency: collateralCurrency,
  );
  final cva = eligible
      ? (collateralValueInExposureCurrency * (1 - hc - hfx))
          .clamp(0.0, double.infinity)
          .toDouble()
      : 0.0;

  return _FinancedCrmCollateralOutcome(
    eligible: eligible,
    reason: reason,
    value: collateralValueInExposureCurrency,
    hc: hc,
    hfx: hfx,
    cva: cva,
  );
}

FinancedCrmSnapshot computeFinancedCrmSnapshot(ExposureDraft draft) {
  final riskWeight = _lookupOriginalRiskWeightForDraft(draft);
  final onBalanceAmount = _resolvedOnBalanceAmountForDraft(draft);
  final offBalanceCcfAmount = _resolvedOffBalanceCcfAmountForDraft(draft);
  final exposureAmount = onBalanceAmount + offBalanceCcfAmount;
  // Valeur ajustée de l'exposition : VAE = E × (1 + De). La décote
  // d'exposition De est nulle pour les prêts classiques.
  const he = 0.0;
  final eva = exposureAmount * (1 + he);

  _FinancedCrmCollateralOutcome outcome;
  if (financedCrmCollateralIsBasket(draft.collateralType) &&
      draft.basketItems.isNotEmpty) {
    var totalValue = 0.0;
    var totalCva = 0.0;
    var weightedHc = 0.0;
    var weightedHfx = 0.0;
    final ineligibleReasons = <String>[];
    for (final item in draft.basketItems) {
      final itemOutcome = _evaluateSingleFinancedCollateral(
        exposureAmount: exposureAmount,
        exposureCurrency: draft.currency,
        collateralValue: item.value,
        collateralCurrency: item.currency,
        collateralType: item.collateralType,
        issuerRole: item.issuerRole,
        rating: item.rating,
        maturityBucket: item.residualMaturityBucket,
        convertibleMainIndex: item.convertibleMainIndex,
        opcvmHighestHaircut: item.opcvmHighestHaircut,
      );
      totalValue += itemOutcome.value;
      totalCva += itemOutcome.cva;
      weightedHc += itemOutcome.value * itemOutcome.hc;
      weightedHfx += itemOutcome.value * itemOutcome.hfx;
      if (!itemOutcome.eligible && itemOutcome.reason.isNotEmpty) {
        ineligibleReasons.add(itemOutcome.reason);
      }
    }
    final hasEligiblePortion = totalCva > 0;
    final denominator = totalValue <= 0 ? 1.0 : totalValue;
    outcome = _FinancedCrmCollateralOutcome(
      eligible: hasEligiblePortion,
      reason: hasEligiblePortion
          ? ''
          : (ineligibleReasons.isEmpty
              ? 'Aucun actif éligible dans le panier.'
              : ineligibleReasons.first),
      value: totalValue,
      hc: (weightedHc / denominator).clamp(0.0, double.infinity).toDouble(),
      hfx: (weightedHfx / denominator).clamp(0.0, double.infinity).toDouble(),
      cva: totalCva.clamp(0.0, double.infinity).toDouble(),
    );
  } else {
    outcome = _evaluateSingleFinancedCollateral(
      exposureAmount: exposureAmount,
      exposureCurrency: draft.currency,
      collateralValue: draft.collateralValue,
      collateralCurrency: draft.collateralCurrency,
      collateralType: draft.collateralType,
      issuerRole: draft.issuerType,
      rating: draft.issuerRating,
      maturityBucket: draft.maturityBucket,
      convertibleMainIndex: draft.convertibleMainIndex,
      opcvmHighestHaircut: draft.opcvmHighestHaircut,
    );
  }

  // E* = max(0 ; VAE − VAS) : la valeur ajustée de la sûreté est déduite UNE
  // SEULE FOIS de l'exposition totale (bilan + hors bilan), puis le solde est
  // réparti au prorata des composantes pour l'affichage.
  final evaEb = onBalanceAmount * (1 + he);
  final evaHb = offBalanceCcfAmount * (1 + he);
  final evaTotal = evaEb + evaHb;
  final double eadBilanAmount;
  final double eadHbCcfAmount;
  if (outcome.eligible) {
    final eadTotalAfterCrm =
        (evaTotal - outcome.cva).clamp(0.0, double.infinity).toDouble();
    final allocationRatio = evaTotal > 0 ? eadTotalAfterCrm / evaTotal : 0.0;
    eadBilanAmount = evaEb * allocationRatio;
    eadHbCcfAmount = evaHb * allocationRatio;
  } else {
    eadBilanAmount = onBalanceAmount;
    eadHbCcfAmount = offBalanceCcfAmount;
  }
  final eadAfterFinancedCrm =
      (eadBilanAmount + eadHbCcfAmount).clamp(0.0, double.infinity).toDouble();
  final rwaFinal =
      ((eadBilanAmount * riskWeight) + (eadHbCcfAmount * riskWeight))
          .clamp(0.0, double.infinity)
          .toDouble();
  final crmGain = (exposureAmount - eadAfterFinancedCrm)
      .clamp(0.0, double.infinity)
      .toDouble();
  final coveragePercent = exposureAmount == 0
      ? 0.0
      : (crmGain / exposureAmount).clamp(0.0, 1.0).toDouble();

  return FinancedCrmSnapshot(
    riskWeight: riskWeight,
    he: he,
    hc: outcome.hc,
    hfx: outcome.hfx,
    eva: eva,
    cva: outcome.eligible ? outcome.cva : 0.0,
    eadAfterFinancedCrm: eadAfterFinancedCrm,
    rwaFinal: rwaFinal,
    crmGain: crmGain,
    collateralEligible: outcome.eligible,
    eligibilityReason: outcome.reason,
    coveragePercent: coveragePercent,
  );
}

ExposureComputation computeDraftMetrics(ExposureDraft draft) {
  final originalRw = _lookupOriginalRiskWeightForDraft(draft);
  final onBalanceAmount = _resolvedOnBalanceAmountForDraft(draft);
  final offBalanceCcfAmount = _resolvedOffBalanceCcfAmountForDraft(draft);
  final amount = onBalanceAmount + offBalanceCcfAmount;
  if (draft.categoryCode == 'l') {
    final fcec = lookupOffBalanceFcec(draft.offBalanceRiskLevel);
    final ead = draft.grossAmount * fcec;
    final rwa = ead;
    return ExposureComputation(
      originalRw: fcec,
      finalRw: fcec,
      ead: ead,
      rwa: rwa,
      capital: capitalMinimum(rwa),
      effectiveCoverage: 0.0,
      haircut: 0.0,
    );
  }
  var ead = amount;
  var finalRw = originalRw;
  var effectiveCoverage = 0.0;
  var haircut = 0.0;

  if (draft.crmMode == 'CRM financee') {
    final snapshot = computeFinancedCrmSnapshot(draft);
    haircut = snapshot.hc;
    effectiveCoverage = snapshot.coveragePercent;
    finalRw = originalRw;
    ead = snapshot.eadAfterFinancedCrm;
  } else if (draft.crmMode == 'CRM non financee') {
    effectiveCoverage = draft.crmCoveragePercent.clamp(0.0, 1.0).toDouble();
    final guarantorRw = lookupPrudentialRiskWeight(
      draft.guarantorCategoryCode,
      draft.guarantorRating.isEmpty ? draft.rating : draft.guarantorRating,
    );
    final coveredEad = ead * effectiveCoverage;
    final uncoveredEad = (ead - coveredEad).clamp(0.0, double.infinity);
    final rwa = (coveredEad * guarantorRw) + (uncoveredEad * originalRw);
    finalRw = ead == 0 ? 0.0 : (rwa / ead).clamp(0.0, 1.5).toDouble();
  }

  final rwa = ead * finalRw;
  return ExposureComputation(
    originalRw: originalRw,
    finalRw: finalRw,
    ead: ead,
    rwa: rwa,
    capital: capitalMinimum(rwa),
    effectiveCoverage: effectiveCoverage,
    haircut: haircut,
  );
}

String _normalizeMaturityBucket(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(' ', '');
  if (normalized == '<=1an' || normalized == '<=1ans') return '<=1 an';
  if (normalized == '1-3ans' || normalized == '1a3ans') return '1-3 ans';
  if (normalized == '3-5ans' ||
      normalized == '1a5ans' ||
      normalized == '1-5ans') {
    return '3-5 ans';
  }
  if (normalized == '5-10ans') return '5-10 ans';
  if (normalized == '>10ans' || normalized == '>5ans') return '>10 ans';
  return value;
}
