// Ce fichier affiche le parcours guide de creation et d'edition des expositions.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/state/portfolio_currency_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_conversion.dart';
import '../models/exposition_models.dart';

const double _exposureFormRadius = 2;
const double _wizardBorderWidth = 1.0;

bool _isExposureDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _wizardScreenColor(BuildContext context) => _isExposureDark(context)
    ? AppTheme.darkBackground
    : const Color(0xFFF4F7FB);

Color _wizardShellColor(BuildContext context) => _isExposureDark(context)
    ? const Color(0xFF0D172A)
    : const Color(0xFFF8FBFE);

Color _wizardPanelColor(BuildContext context) => _isExposureDark(context)
    ? const Color(0xFF101B31)
    : const Color(0xFFF1F6FD);

Color _wizardCardColor(BuildContext context) =>
    _isExposureDark(context) ? const Color(0xFF13233C) : Colors.white;

Color _wizardSoftCardColor(BuildContext context) => _isExposureDark(context)
    ? const Color(0xFF122038)
    : const Color(0xFFF6FAFD);

Color _wizardInputFillColor(BuildContext context) =>
    _isExposureDark(context) ? const Color(0xFF182A46) : Colors.white;

Color _wizardBorderColor(BuildContext context) => _isExposureDark(context)
    ? const Color(0xFF304763)
    : const Color(0xFFD7E1EC);

Color _wizardRightSectionBorderColor(BuildContext context) =>
    _isExposureDark(context)
        ? const Color(0x993A506B)
        : const Color(0x8FD7E1EC);

BorderSide _wizardBorderSide(
  BuildContext context, {
  Color? color,
  double width = _wizardBorderWidth,
}) =>
    BorderSide(
      color: color ?? _wizardBorderColor(context),
      width: width,
    );

Border _wizardBoxBorder(
  BuildContext context, {
  Color? color,
  double width = _wizardBorderWidth,
}) =>
    Border.all(
      color: color ?? _wizardBorderColor(context),
      width: width,
    );

Color _wizardTitleColor(BuildContext context) =>
    _isExposureDark(context) ? AppTheme.darkText : const Color(0xFF0F172A);

Color _wizardBodyTitleColor(BuildContext context) =>
    _isExposureDark(context) ? AppTheme.darkText : const Color(0xFF1E293B);

Color _wizardMutedColor(BuildContext context) =>
    _isExposureDark(context) ? AppTheme.darkMuted : const Color(0xFF64748B);

Color _wizardSubtleMutedColor(BuildContext context) => _isExposureDark(context)
    ? const Color(0xFFA3B1C8)
    : const Color(0xFF71839E);

String _capitalizeTooltipText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  final first = trimmed[0];
  final shouldCapitalize = RegExp(r'[a-zà-ÿ]').hasMatch(first);
  if (!shouldCapitalize) {
    return trimmed;
  }
  return '${first.toUpperCase()}${trimmed.substring(1)}';
}

String _normalizeTooltipSentence(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  final normalized = _capitalizeTooltipText(trimmed);
  if (RegExp(r'[.!?]$').hasMatch(normalized)) {
    return normalized;
  }
  return '$normalized.';
}

List<String> _expandTooltipMessageLines(String message) {
  final lines = <String>[];
  for (final rawLine in message.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      lines.add('');
      continue;
    }
    if (line.startsWith('[[CARD]]')) {
      lines.add(line);
      continue;
    }
    if (line.startsWith('[[NOTE]]')) {
      final noteText = line.replaceFirst('[[NOTE]]', '').trimLeft();
      lines.add('[[NOTE]]${_normalizeTooltipSentence(noteText)}');
      continue;
    }
    final segments = line
        .split(';')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty);
    lines.addAll(segments.map(_normalizeTooltipSentence));
  }
  return lines;
}

InlineSpan _buildTooltipCardSpan(String line) {
  final payload = line.replaceFirst('[[CARD]]', '').trimLeft();
  final parts = payload.split('|').map((part) => part.trim()).toList();
  final title = parts.isNotEmpty ? _capitalizeTooltipText(parts[0]) : '';
  final description = parts.length > 1 ? parts[1] : '';
  final formula = parts.length > 2 ? parts[2] : '';

  return WidgetSpan(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(3, 9, 3, 9),
        decoration: BoxDecoration(
          color: const Color(0xFF172845),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF2D4B7A),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11.4,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 10.9,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFE8EEF9),
                  height: 1.35,
                ),
              ),
            ],
            if (formula.isNotEmpty) ...[
              const SizedBox(height: 7),
              const Text(
                'Formule',
                style: TextStyle(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8FB4FF),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formula,
                style: const TextStyle(
                  fontSize: 10.8,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

InlineSpan _buildModernTooltipContent(String title, String message) {
  final lines = _expandTooltipMessageLines(message);

  if (lines.isEmpty) {
    return const TextSpan(text: '');
  }

  final spans = <InlineSpan>[
    TextSpan(
      text: '$title\n',
      style: const TextStyle(
        fontSize: 12.4,
        fontWeight: FontWeight.w500,
        color: Colors.white,
        height: 1.2,
      ),
    ),
  ];

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    if (line.isEmpty) {
      spans.add(const TextSpan(text: '\n'));
      continue;
    }
    if (line.startsWith('[[CARD]]')) {
      spans.add(_buildTooltipCardSpan(line));
      continue;
    }
    final isNote = line.startsWith('[[NOTE]]');
    if (isNote) {
      final noteText = line.replaceFirst('[[NOTE]]', '').trimLeft();
      spans.add(
        TextSpan(
          text: '$noteText${index == lines.length - 1 ? '' : '\n'}',
          style: const TextStyle(
            fontSize: 10.2,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
            color: Color(0xFFFFB86B),
            height: 1.35,
          ),
        ),
      );
      continue;
    }

    final separatorIndex = line.indexOf(':');
    final hasLabelValueFormat =
        separatorIndex > 0 && separatorIndex < line.length - 1;

    if (hasLabelValueFormat) {
      final label = line.substring(0, separatorIndex).trim();
      final detail = line.substring(separatorIndex + 1).trim();
      final shouldBreakDetailLine = detail.startsWith('[[BREAK]]');
      final normalizedDetail = _normalizeTooltipSentence(
        shouldBreakDetailLine
            ? detail.replaceFirst('[[BREAK]]', '').trimLeft()
            : detail,
      );
      spans.add(
        TextSpan(
          children: [
            const TextSpan(
              text: '• ',
              style: TextStyle(
                fontSize: 11.4,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8FB4FF),
                height: 1.5,
              ),
            ),
            TextSpan(
              text: _capitalizeTooltipText(label),
              style: const TextStyle(
                fontSize: 11.3,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.5,
              ),
            ),
            TextSpan(
              text: shouldBreakDetailLine
                  ? ' :\n  $normalizedDetail${index == lines.length - 1 ? '' : '\n'}'
                  : ' : $normalizedDetail${index == lines.length - 1 ? '' : '\n'}',
              style: const TextStyle(
                fontSize: 11.2,
                fontWeight: FontWeight.w500,
                color: Color(0xFFE8EEF9),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
      continue;
    }

    spans.add(
      TextSpan(
        children: [
          const TextSpan(
            text: '• ',
            style: TextStyle(
              fontSize: 11.4,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8FB4FF),
              height: 1.48,
            ),
          ),
          TextSpan(
            text: '$line${index == lines.length - 1 ? '' : '\n'}',
            style: const TextStyle(
              fontSize: 11.2,
              fontWeight: FontWeight.w500,
              color: Color(0xFFE8EEF9),
              height: 1.48,
            ),
          ),
        ],
      ),
    );
  }

  return TextSpan(children: spans);
}

class ExposureFormCard extends StatefulWidget {
  const ExposureFormCard({
    super.key,
    required this.api,
    required this.onSubmit,
    required this.onCancel,
    required this.ratings,
    this.initialDraft,
    this.title = 'Nouvelle exposition prudentielle',
    this.submitLabel = "Enregistrer l'exposition",
  });

  final RwaApiService api;
  final Future<void> Function(ExposureDraft draft) onSubmit;
  final VoidCallback onCancel;
  final List<String> ratings;
  final ExposureDraft? initialDraft;
  final String title;
  final String submitLabel;

  @override
  State<ExposureFormCard> createState() => _ExposureFormCardState();
}

class _ExposureFormCardState extends State<ExposureFormCard> {
  static const List<String> _supportedCurrencies = ['XOF', 'EUR', 'USD'];
  static const String _bmdCriteriaTooltip =
      'excellente notation long terme (majoritairement AAA)\n'
      'actionnariat composé en grande partie de souverains ≥ AA- ou financement surtout par capital versé\n'
      'fort soutien des actionnaires\n'
      'niveau adéquat de capital et de liquidité\n'
      'politiques de crédit et gestion des risques prudentes';
  static const String _bmdCdeCriteriaTooltip =
      'fort soutien des actionnaires\n'
      'niveau adéquat de capital et de liquidité\n'
      'politiques de crédit et gestion des risques prudentes';
  static const String _bmdInstitutionsTooltip =
      'BIRD : Banque internationale pour la reconstruction et le développement\n'
      'SFI : Société financière internationale\n'
      'BAsD : Banque asiatique de développement\n'
      'BAD : Banque africaine de développement\n'
      'BERD : Banque européenne pour la reconstruction et le développement\n'
      "BEI : Banque européenne d'investissement\n"
      "FEI : Fonds européen d'investissement\n"
      "BNI : Banque nordique d'investissement\n"
      'BDC : Banque de développement des Caraïbes\n'
      'BIsD : Banque islamique de développement\n'
      'BDCE : Banque de développement des Caraïbes orientales\n'
      'AMGI : Agence multilatérale de garantie des investissements\n'
      'BOAD : Banque ouest-africaine de développement';
  static const String _bankInstitutionWeakPrudentialTooltip =
      'L institution a des fonds propres négatifs, ne respecte pas les ratios de solvabilité, ou il s agit d une SFD non supervisée par la Commission Bancaire.';
  static const String _bankInstitutionEligibleCategoriesTooltip =
      '(a) les entreprises du secteur bancaire\n'
      '(b) les services financiers des administrations de poste\n'
      "(c) les caisses nationales d'épargne\n"
      '(d) les autres institutions financières internationales.';
  static const String _enterpriseArticle133Tooltip =
      'Une pondération supérieure à 100 % est exigée lorsque le taux brut de dégradation du portefeuille entreprise dépasse sur deux trimestres consécutifs un seuil fixé par instruction de la BCEAO.\n\n'
      "Une pondération plus élevée est appliquée, lorsqu'une entreprise établie dans l'UMOA est soumise à une procédure de traitement prudentiel résultant de la production, par l'entreprise elle-même ou par son commissaire au compte, d'informations financières erronées.\n\n"
      "[[NOTE]]On entend par taux brut de dégradation du portefeuille, le rapport entre l'encours des créances en souffrance brutes telles que défini aux paragraphes 152 à 160 et le portefeuille de crédit brut de l'établissement. S'agissant des entreprises, le taux brut de dégradation du portefeuille est le rapport entre l'encours des créances en souffrance brutes enregistré au titre du portefeuille entreprises et l'encours total des crédits bruts octroyés à ce segment.";
  static const String _offBalanceLowRiskTooltip =
      'engagements révocables sans condition, à tout moment, sans préavis ou caducs automatiquement.';
  static const String _offBalanceMinorRiskTooltip =
      'engagements ≤ 1 an non révocables sans condition ; lettres de crédit commerciales à court terme, crédits documentaires.';
  static const String _offBalanceMediumRiskTooltip =
      'engagements > 1 an non révocables sans condition ; lettres de crédit documentaires non garanties par marchandises ; garanties de bonne exécution, de soumission, de tiers, crédits de confirmation.';
  static const String _offBalanceHighRiskTooltip =
      'facilités d’émission d’effets (FEE) et facilités de prise ferme renouvelables (FPR) ; substituts directs de crédit, garanties d’endettement, acceptations.';
  static const String _offBalanceVeryHighRiskTooltip =
      'opérations assimilables à des pensions, repo ou prêts de titres ; cessions d’actifs avec recours, affacturage ou escompte ; engagements d’achat d’actifs à terme ; dépôts à terme contre terme ; fraction non versée d’actions ou titres partiellement libérés ; autres éléments hors bilan non classés.';
  static const String _offBalanceFcecTooltip =
      'Définition : [[BREAK]]Les éléments de hors bilan recouvrent les garanties, les engagements, les instruments dérivés et d’autres accords contractuels non comptabilisés au bilan.\n\n'
      'Approche standard : [[BREAK]]Dans l’approche standard, chaque élément de hors bilan est converti en équivalent risque de crédit (ERC) au moyen d’un facteur de conversion en équivalent crédit (FCEC) qui sert à établir une projection de l’exposition potentielle au risque.\n\n'
      'Calcul de l’ERC : [[BREAK]]Le montant ERC d’une transaction de hors bilan est calculé en multipliant le montant correspondant à la portion non utilisée par le FCEC y relatif.\n\n'
      'Calcul des APR : [[BREAK]]Pour obtenir les APR de crédit sur les engagements de hors bilan, le montant ERC ainsi défini est ensuite multiplié par la pondération du risque qui dépend du type de contrepartie et de sa notation.\n\n'
      'Catégories de FCEC : [[BREAK]]Les FCEC applicables aux éléments de hors bilan sont répartis en cinq (5) catégories définies par ordre croissant selon le niveau de risque potentiel de la transaction.';
  static const String _residentialMortgageCriteriaTooltip =
      'Ratio Prêt/Valeur (LTV) ≤ 90 %\n'
      'Ratio de couverture du service de la dette ≤ 40 %\n'
      'Accord du client pour la transmission des données au BIC';
  static const String _commercialRealEstateCriteriaTooltip =
      'Ratio Prêt/Valeur (LTV) ≤ 90 %\n'
      'Consentement du client à la transmission des données aux BIC';
  static const String _crmFinancedTooltip =
      'Une CRM financée est une protection de crédit reposant sur une sûreté réelle ou financière. Elle réduit l exposition en tenant compte de la valeur ajustée de la sûreté reçue.';
  static const String _collateralValueTooltip =
      'Montant de la sûreté ou du collatéral reçu. Cette valeur sera corrigée par les décotes réglementaires avant d être déduite de l exposition.';
  static const String _automaticHaircutsTooltip =
      "He : [[BREAK]]Décote appliquée à l'exposition. Elle peut varier selon la nature de l'opération ou de l'exposition.\n"
      'Hc : [[BREAK]]Décote appliquée à la sûreté selon le type, la note, l émetteur et la maturité.\n'
      'Hfx : [[BREAK]]Décote de change. 0 % si même devise ou paire FCFA/EUR, sinon 9 %.';
  static const String _convertibleMainIndexTooltip =
      "Choisissez Oui si l'obligation convertible reçue en garantie est incluse dans un indice principal reconnu.\n"
      'Choisissez Non dans le cas contraire.\n'
      'La décote Hc est de 20 % si Oui, contre 30 % si Non.';
  static const String _financedCrmCalculationTooltip =
      '[[CARD]]Eva|Exposition ajustée après décote He|Eva = Montant brut de l exposition × (1 + He)\n'
      '[[CARD]]Cva|Valeur ajustée de la sûreté après décotes Hc et Hfx|Cva = Valeur de la sûreté × (1 - Hc - Hfx)\n'
      '[[CARD]]EAD après CRM financée|Exposition nette après prise en compte de la sûreté|EAD = max(0, Eva - Cva)\n'
      '[[CARD]]Valeur de la sûreté|Montant du collatéral reçu avant application des décotes réglementaires|Valeur de la sûreté = Montant du collatéral reçu';
  static const String _basketTooltip =
      'Lorsque la sûreté est composée de plusieurs actifs, la décote globale est calculée comme la somme pondérée des décotes de chaque actif.';
  static const List<String> _nonFinancedCrmTypes = [
    'Garantie etatique',
    'Assurance credit',
    'Garantie bancaire',
  ];
  static const List<_WizardStepMeta> _stepMetas = [
    _WizardStepMeta(
      shortLabel: 'Aperçu',
      title: "Vue d'ensemble du dossier",
      subtitle: 'Repères prudentiels et indicateurs RWA',
      icon: Icons.shield_outlined,
    ),
    _WizardStepMeta(
      shortLabel: 'Identité',
      title: 'Identification de la contrepartie',
      subtitle: 'Contrepartie, pays, dates et notation',
      icon: Icons.badge_outlined,
    ),
    _WizardStepMeta(
      shortLabel: 'Catégorie',
      title: 'Catégorie d\'exposition',
      subtitle: 'Classe prudentielle et pondération',
      icon: Icons.account_tree_outlined,
    ),
    _WizardStepMeta(
      shortLabel: 'Finance',
      title: 'Paramètres financiers',
      subtitle: 'Montants, ventilation et devise',
      icon: Icons.account_balance_wallet_outlined,
    ),
    _WizardStepMeta(
      shortLabel: 'CRM ?',
      title: 'Présence d\'une CRM',
      subtitle: 'Vérification de la protection de crédit',
      icon: Icons.help_outline_rounded,
    ),
    _WizardStepMeta(
      shortLabel: 'Type CRM',
      title: 'Mécanisme de CRM',
      subtitle: 'Garantie, sûreté ou substitution de risque',
      icon: Icons.handshake_outlined,
    ),
    _WizardStepMeta(
      shortLabel: 'Analyse',
      title: 'Commentaires et points d\'attention',
      subtitle: 'Observations métier et validation interne',
      icon: Icons.edit_note_outlined,
    ),
    _WizardStepMeta(
      shortLabel: 'Valider',
      title: 'Validation finale',
      subtitle: 'Contrôler puis enregistrer l\'exposition',
      icon: Icons.task_alt_outlined,
    ),
  ];

  final _primaryFormKey = GlobalKey<FormState>();
  final _categoryFormKey = GlobalKey<FormState>();
  final _financialFormKey = GlobalKey<FormState>();
  final _crmFormKey = GlobalKey<FormState>();
  final _commentFormKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _countryController;
  final TextEditingController _exposureIdController = TextEditingController();
  final TextEditingController _grantDateController = TextEditingController();
  final TextEditingController _maturityDateController = TextEditingController();
  final ScrollController _rightPanelScrollController = ScrollController();
  late final TextEditingController _amountController;
  late final TextEditingController _onBalanceAmountController;
  late final TextEditingController _provisionsAmountController;
  late final TextEditingController _commentController;
  late final TextEditingController _collateralController;
  late final TextEditingController _fxHaircutController;
  late final TextEditingController _guarantorNameController;
  late final TextEditingController _guarantorCountryController;

  late String _categoryCode;
  late String _countryRating;
  late String _rating;
  late String _sovereignSpecialCase;
  late String _sovereignOceNote;
  bool? _publicBodyUemoaFcfaCase;
  bool? _publicBodyFinancesNonPublicActivity;
  bool? _bmdHighQualityCase;
  bool? _bmdUemoaFcfaCase;
  bool? _bmdUemoaCriteriaSatisfied;
  bool? _bmdListedInstitutionFcfaCase;
  String? _bankInstitutionCase;
  String? _otherAssetType;
  String? _offBalanceRiskLevel;
  bool? _retailEligibilityCriteriaSatisfied;
  bool? _residentialMortgageEligible;
  bool? _commercialRealEstateEligible;
  double? _defaultedExposureInitialRiskWeight;
  bool? _defaultedExposureResidentialMortgageInDefault;
  bool? _defaultedExposureProvisionAtLeastTwentyPercent;
  bool? _enterpriseExceedsBceaoDegradationThreshold;
  bool? _enterprisePrudentialProcedure;
  bool? _enterpriseInvestmentFirmWithoutBankingLaw;
  late String _currency;
  late String _status;
  late String _crmMode;
  bool? _crmExistsAnswer;
  late String _crmType;
  late String _collateralType;
  late String _collateralCurrency;
  late String _issuerType;
  late String _issuerRating;
  late String _maturityBucket;
  late String _guarantorCategoryCode;
  late String _guarantorRating;
  late String _guarantorCountryRating;
  late bool _convertibleMainIndex;
  late double _opcvmHighestHaircut;
  List<FinancedCrmBasketItem> _basketItems = const [];
  DateTime? _grantDate;
  DateTime? _maturityDate;

  int _currentStep = 1;
  late final TextEditingController _coveredAmountController;
  bool _sovereignPreferentialZeroWeight = false;
  bool _sovereignPriorityQuestionAnsweredYes = false;
  bool? _sovereignOceEstablished;
  bool _crmSelectionStage = true;
  bool _submitting = false;
  int _backendPreviewRequestId = 0;
  _ExposurePreview? _backendPreview;
  String? _generatedExposureId;
  bool _showStickyStepHeader = false;
  bool _expandStickyStepHeader = false;
  ScrollDirection _rightPanelScrollDirection = ScrollDirection.idle;
  bool _rightPanelScrollSyncScheduled = false;
  bool? _pendingShowStickyStepHeader;
  bool? _pendingExpandStickyStepHeader;
  ScrollDirection? _pendingRightPanelScrollDirection;
  bool _didResolveScopedCurrency = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    final isBlankDraft = _isBlankInitialDraft(draft);
    _nameController = TextEditingController(
      text: draft?.counterpartyName ?? '',
    );
    _generatedExposureId = isBlankDraft ? draft?.id : null;
    _exposureIdController.text = isBlankDraft ? '' : (draft?.id ?? '');
    _countryController = TextEditingController(text: draft?.country ?? '');
    _grantDate = draft?.grantDate;
    _maturityDate = draft?.maturityDate;
    _grantDateController.text = _formatDateForField(_grantDate);
    _maturityDateController.text = _formatDateForField(_maturityDate);
    _amountController = TextEditingController(
      text: draft?.loanTotalAmount == null || draft!.loanTotalAmount <= 0
          ? ''
          : draft.loanTotalAmount.toStringAsFixed(0),
    );
    _onBalanceAmountController = TextEditingController(
      text: draft?.onBalanceExposureAmount == null ||
              draft!.onBalanceExposureAmount <= 0
          ? ''
          : draft.onBalanceExposureAmount.toStringAsFixed(0),
    );
    _provisionsAmountController = TextEditingController(
      text: draft?.provisionsAmount == null || draft!.provisionsAmount! <= 0
          ? ''
          : draft.provisionsAmount!.toStringAsFixed(0),
    );
    _commentController = TextEditingController(text: draft?.comment ?? '');
    _collateralController = TextEditingController(
      text: draft?.collateralValue == null || draft!.collateralValue <= 0
          ? ''
          : draft.collateralValue.toStringAsFixed(0),
    );
    _fxHaircutController = TextEditingController(
      text: ((draft?.fxHaircut ?? 0) * 100).toStringAsFixed(2),
    );
    _guarantorNameController =
        TextEditingController(text: draft?.guarantorName ?? '');
    _guarantorCountryController =
        TextEditingController(text: draft?.guarantorCountry ?? '');
    _categoryCode =
        exposureCategories.any((item) => item.code == draft?.categoryCode)
            ? draft!.categoryCode
            : '';
    _countryRating = _initialSelectedValue(
      draft?.countryRating,
      options: _availableRatings,
    );
    _rating = _initialSelectedValue(
      draft?.rating,
      options: _counterpartyRatingOptionsForCategory(_categoryCode),
    );
    if ((_categoryCode == 'a' || _categoryCode == 'c') &&
        _rating.isNotEmpty &&
        !prudentialRatings.contains(_rating)) {
      _rating = '';
    }
    _sovereignSpecialCase = coerceSovereignSpecialCase(
      draft?.sovereignSpecialCase,
      fallbackToLegacy: draft?.sovereignPreferentialZeroWeight ?? false,
    );
    _sovereignPreferentialZeroWeight = hasSovereignPriorityZeroWeightCase(
      _sovereignSpecialCase,
      sovereignPreferentialZeroWeight:
          draft?.sovereignPreferentialZeroWeight ?? false,
    );
    _sovereignPriorityQuestionAnsweredYes =
        _sovereignSpecialCase != sovereignNoSpecialCase ||
            _sovereignPreferentialZeroWeight;
    _sovereignOceEstablished = _rating == 'Non noté' && draft != null
        ? (draft.sovereignOceEstablished || draft.sovereignOceNote.isNotEmpty)
        : null;
    _sovereignOceNote = _rating == 'Non noté' &&
            sovereignOceNotes.contains(draft?.sovereignOceNote)
        ? draft!.sovereignOceNote
        : '';
    _publicBodyUemoaFcfaCase = draft?.publicBodyUemoaFcfaCase;
    _publicBodyFinancesNonPublicActivity =
        draft?.publicBodyFinancesNonPublicActivity;
    _bmdHighQualityCase = draft?.bmdHighQualityCase;
    _bmdUemoaFcfaCase = draft?.bmdUemoaFcfaCase;
    _bmdUemoaCriteriaSatisfied = draft?.bmdUemoaCriteriaSatisfied;
    _bmdListedInstitutionFcfaCase = draft?.bmdListedInstitutionFcfaCase;
    _bankInstitutionCase =
        coerceBankInstitutionCase(draft?.bankInstitutionCase);
    _otherAssetType = coerceOtherAssetType(
      draft?.otherAssetType,
      fallbackToUndefined: _categoryCode == 'k' && draft != null,
    );
    _offBalanceRiskLevel = coerceOffBalanceRiskLevel(
      draft?.offBalanceRiskLevel,
      fallbackToVeryHigh: _shouldAskOffBalanceRiskLevel && draft != null,
    );
    _retailEligibilityCriteriaSatisfied =
        draft?.retailEligibilityCriteriaSatisfied;
    _residentialMortgageEligible = draft?.residentialMortgageEligible;
    _commercialRealEstateEligible = draft?.commercialRealEstateEligible;
    _defaultedExposureInitialRiskWeight =
        draft?.defaultedExposureInitialRiskWeight;
    _defaultedExposureResidentialMortgageInDefault =
        draft?.defaultedExposureResidentialMortgageInDefault;
    _defaultedExposureProvisionAtLeastTwentyPercent =
        draft?.defaultedExposureProvisionAtLeastTwentyPercent;
    _enterpriseExceedsBceaoDegradationThreshold =
        draft?.enterpriseExceedsBceaoDegradationThreshold;
    _enterprisePrudentialProcedure = draft?.enterprisePrudentialProcedure;
    _enterpriseInvestmentFirmWithoutBankingLaw =
        draft?.enterpriseInvestmentFirmWithoutBankingLaw;
    if (!_isPublicBodyCategory) {
      _publicBodyUemoaFcfaCase = null;
      _publicBodyFinancesNonPublicActivity = null;
    }
    if (!_isBmdCategory) {
      _bmdHighQualityCase = null;
      _bmdUemoaFcfaCase = null;
      _bmdUemoaCriteriaSatisfied = null;
      _bmdListedInstitutionFcfaCase = null;
    }
    if (!_isBankInstitutionCategory) {
      _bankInstitutionCase = null;
    }
    if (_categoryCode != 'k') {
      _otherAssetType = null;
    }
    if (!_shouldAskOffBalanceRiskLevel) {
      _offBalanceRiskLevel = null;
    }
    if (!_isRetailCategory) {
      _retailEligibilityCriteriaSatisfied = null;
    }
    if (!_isResidentialMortgageCategory) {
      _residentialMortgageEligible = null;
    }
    if (!_isCommercialRealEstateCategory) {
      _commercialRealEstateEligible = null;
    }
    if (!_isDefaultedExposureCategory) {
      _defaultedExposureInitialRiskWeight = null;
      _defaultedExposureResidentialMortgageInDefault = null;
      _defaultedExposureProvisionAtLeastTwentyPercent = null;
    }
    if (!_isEnterpriseLikeCategory) {
      _enterpriseExceedsBceaoDegradationThreshold = null;
      _enterprisePrudentialProcedure = null;
      _enterpriseInvestmentFirmWithoutBankingLaw = null;
    }
    _currency = _initialSelectedValue(
      normalizeCurrencyCode(draft?.currency ?? ''),
      options: _supportedCurrencies,
    );
    _status = draft?.status ?? 'Active';
    _crmMode = draft?.crmMode ?? 'Aucune';
    if (_isOffBalanceCategory && _crmMode != 'Aucune') {
      _crmMode = 'Aucune';
    }
    _crmExistsAnswer = _isOffBalanceCategory
        ? false
        : (isBlankDraft
            ? null
            : (draft == null
                ? (_crmMode == 'Aucune' ? null : true)
                : _crmMode != 'Aucune'));
    _crmType = _initialSelectedValue(
      draft?.crmType,
      options: _nonFinancedCrmTypes,
    );
    _collateralType = _initialSelectedValue(
      draft?.collateralType,
      options: financedCrmCollateralTypes,
    );
    _collateralCurrency = _initialSelectedValue(
      normalizeCurrencyCode(draft?.collateralCurrency ?? ''),
      options: _supportedCurrencies,
    );
    _issuerType = _initialSelectedValue(
      draft?.issuerType,
      options: financedCrmIssuerRoleOptions,
    );
    _issuerRating = _initialSelectedValue(
      draft?.issuerRating,
      options: financedCrmDebtRatings,
    );
    _maturityBucket = _initialSelectedValue(
      draft?.maturityBucket,
      options: financedCrmMaturityBuckets,
    );
    _convertibleMainIndex = draft?.convertibleMainIndex ?? true;
    _opcvmHighestHaircut =
        coerceFinancedCrmOpcvmHaircut(draft?.opcvmHighestHaircut);
    _basketItems = draft?.basketItems
            .map((item) => FinancedCrmBasketItem.fromJson(item.toJson()))
            .toList(growable: true) ??
        <FinancedCrmBasketItem>[];
    _guarantorCategoryCode = _initialSelectedValue(
      draft?.guarantorCategoryCode,
      options: guarantorEligibleCategoryCodes,
    );
    _guarantorRating = _initialSelectedValue(
      draft?.guarantorRating,
      options: _availableRatings,
    );
    _guarantorCountryRating = _initialSelectedValue(
      draft?.guarantorCountryRating,
      options: _availableRatings,
    );
    final grossAmt = draft?.grossAmount ?? 0.0;
    final coveredAmt = (draft?.crmCoveragePercent ?? 0.0) * grossAmt;
    _coveredAmountController = TextEditingController(
      text: coveredAmt > 0 ? coveredAmt.toStringAsFixed(0) : '',
    );
    _syncFinancedCollateralCurrencyToExposureIfNeeded();
    _syncBasketCollateralController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didResolveScopedCurrency || widget.initialDraft == null) {
      return;
    }
    _currency = _initialSelectedValue(
      normalizeCurrencyCode(
        PortfolioCurrencyScope.maybeOf(context, fallback: _currency),
      ),
      options: _supportedCurrencies,
    );
    _didResolveScopedCurrency = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _exposureIdController.dispose();
    _countryController.dispose();
    _grantDateController.dispose();
    _maturityDateController.dispose();
    _rightPanelScrollController.dispose();
    _amountController.dispose();
    _onBalanceAmountController.dispose();
    _provisionsAmountController.dispose();
    _commentController.dispose();
    _collateralController.dispose();
    _fxHaircutController.dispose();
    _guarantorNameController.dispose();
    _guarantorCountryController.dispose();
    _coveredAmountController.dispose();
    super.dispose();
  }

  List<String> get _availableRatings {
    final unique = <String>[];
    for (final raw in widget.ratings) {
      final value = _normalizeRatingLabel(raw);
      if (value.isEmpty || unique.contains(value)) {
        continue;
      }
      unique.add(value);
    }
    if (unique.isNotEmpty) {
      return unique;
    }
    return prudentialRatings
        .map(_normalizeRatingLabel)
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
  }

  String _normalizeRatingLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    switch (trimmed.toUpperCase()) {
      case 'NON_NOTE':
      case 'NON NOTE':
      case 'NON NOTÉ':
      case 'NON NOTEE':
        return 'Non noté';
      case '<_B-':
        return '< B-';
      default:
        return trimmed;
    }
  }

  String _initialSelectedValue(
    String? value, {
    required List<String> options,
  }) {
    final trimmed = _normalizeRatingLabel(value?.trim() ?? '');
    if (trimmed.isNotEmpty && options.contains(trimmed)) {
      return trimmed;
    }
    return '';
  }

  String? _selectedValueOrNull(
    String? value,
    List<String> options,
  ) {
    final trimmed = _normalizeRatingLabel(value?.trim() ?? '');
    if (trimmed.isEmpty || !options.contains(trimmed)) {
      return null;
    }
    return trimmed;
  }

  bool _isBlankInitialDraft(ExposureDraft? draft) {
    if (draft == null) {
      return false;
    }
    return draft.counterpartyName.trim().isEmpty &&
        draft.country.trim().isEmpty &&
        draft.countryRating.trim().isEmpty &&
        draft.categoryCode.trim().isEmpty &&
        draft.rating.trim().isEmpty &&
        draft.loanTotalAmount <= 0 &&
        draft.onBalanceExposureAmount <= 0 &&
        draft.currency.trim().isEmpty &&
        draft.crmMode == 'Aucune';
  }

  double? get _loanTotalAmountInput => _parseDecimal(_amountController.text);

  double? get _onBalanceExposureAmountInput =>
      _parseDecimal(_onBalanceAmountController.text);

  double? get _provisionsAmountInput =>
      _parseDecimal(_provisionsAmountController.text);

  bool get _hasInvalidOnBalanceAmount {
    final loanTotalAmount = _loanTotalAmountInput;
    final onBalanceExposureAmount = _onBalanceExposureAmountInput;
    if (loanTotalAmount == null || onBalanceExposureAmount == null) {
      return false;
    }
    return onBalanceExposureAmount > loanTotalAmount;
  }

  double get _derivedOffBalanceExposureAmount {
    final loanTotalAmount = _loanTotalAmountInput ?? 0.0;
    final onBalanceExposureAmount = _onBalanceExposureAmountInput ?? 0.0;
    final value = loanTotalAmount - onBalanceExposureAmount;
    return value <= 0 ? 0.0 : value;
  }

  bool get _shouldAskOffBalanceRiskLevel =>
      _derivedOffBalanceExposureAmount > 0;

  double _resolveEffectiveGrossAmount({
    required double loanTotalAmount,
    required double onBalanceExposureAmount,
  }) {
    if (_isOffBalanceCategory) {
      final value = loanTotalAmount - onBalanceExposureAmount;
      return value <= 0 ? 0.0 : value;
    }
    return onBalanceExposureAmount <= 0 ? 0.0 : onBalanceExposureAmount;
  }

  double get _computedCoverage {
    final gross = _isOffBalanceCategory
        ? _derivedOffBalanceExposureAmount *
            lookupOffBalanceFcec(_offBalanceRiskLevel)
        : (_onBalanceExposureAmountInput ?? 0.0) +
            (_derivedOffBalanceExposureAmount > 0
                ? _derivedOffBalanceExposureAmount *
                    lookupOffBalanceFcec(_offBalanceRiskLevel)
                : 0.0);
    final covered =
        double.tryParse(_coveredAmountController.text.replaceAll(',', '.')) ??
            0.0;
    return gross > 0 ? (covered / gross).clamp(0.0, 1.0) : 0.0;
  }

  List<String> _counterpartyRatingOptionsForCategory(String categoryCode) {
    if (categoryCode == 'a' ||
        categoryCode == 'b' ||
        categoryCode == 'c' ||
        categoryCode == 'd') {
      return prudentialRatings;
    }
    if (categoryCode == 'e') {
      return enterpriseRatingOptions;
    }
    return _availableRatings;
  }

  List<String> get _availableCountryOptions {
    final unique = <String>[];
    final seen = <String>{};

    void addCountry(String raw) {
      final value = canonicalCountryName(raw, fallback: raw).trim();
      final key = normalizedCountryName(value);
      if (value.isEmpty || key.isEmpty || seen.contains(key)) {
        return;
      }
      seen.add(key);
      unique.add(value);
    }

    addCountry(_countryController.text.trim());
    for (final raw in worldCountries) {
      addCountry(raw);
    }
    return unique;
  }

  List<String> get _availableGuarantorCountryOptions {
    final unique = <String>[];
    final seen = <String>{};

    void addCountry(String raw) {
      final value = canonicalCountryName(raw, fallback: raw).trim();
      final key = normalizedCountryName(value);
      if (value.isEmpty || key.isEmpty || seen.contains(key)) {
        return;
      }
      seen.add(key);
      unique.add(value);
    }

    addCountry(_guarantorCountryController.text.trim());
    for (final raw in worldCountries) {
      addCountry(raw);
    }
    return unique;
  }

  String get _detectedCountryZone {
    final value = _countryController.text.trim();
    if (value.isEmpty) {
      return context.tr('Non determinee');
    }
    return computeZone(value);
  }

  Color _zoneAccentColor(String zone) {
    switch (zone) {
      case 'UEMOA':
        return const Color(0xFF0F766E);
      case 'CEMAC':
        return const Color(0xFF2563EB);
      case 'Hors zone':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  List<String> get _availableCurrencyOptions {
    final values = <String>{..._supportedCurrencies};
    if (_currency.trim().isNotEmpty) {
      values.add(normalizeCurrencyCode(_currency));
    }
    if (_collateralCurrency.trim().isNotEmpty) {
      values.add(normalizeCurrencyCode(_collateralCurrency));
    }
    return values.toList()..sort();
  }

  FinancedCrmSnapshot get _financedCrmSnapshotPreview {
    final loanTotalAmount = _loanTotalAmountInput ?? 0.0;
    final onBalanceExposureAmount = _onBalanceExposureAmountInput ?? 0.0;
    final collateral = _parseDecimal(_collateralController.text) ?? 0.0;
    return computeFinancedCrmSnapshot(
      _draftFromValues(
        loanTotalAmount: loanTotalAmount,
        onBalanceExposureAmount: onBalanceExposureAmount,
        provisionsAmount: _provisionsAmountInput,
        collateralValue: collateral,
        fxHaircut: 0.0,
        comment: _commentController.text,
      ),
    );
  }

  String _formatReadonlyAmount(
    double amount, {
    String? sourceCurrency,
    String? targetCurrency,
  }) {
    final resolvedSourceCurrency =
        normalizeCurrencyCode(sourceCurrency ?? _currency);
    final resolvedTargetCurrency =
        normalizeCurrencyCode(targetCurrency ?? _currency);
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context);
    return formatCurrencyInDisplayUnit(
      amount,
      fromCurrency: resolvedSourceCurrency,
      toCurrency: resolvedTargetCurrency,
      amountUnit: amountUnit,
    );
  }

  double _convertBasketItemAmount(
    FinancedCrmBasketItem item, {
    required String toCurrency,
  }) {
    return convertAmount(
      item.value,
      fromCurrency: item.currency,
      toCurrency: toCurrency,
    );
  }

  double get _basketTotalInExposureCurrency => _basketItems.fold<double>(
        0.0,
        (total, item) =>
            total + _convertBasketItemAmount(item, toCurrency: _currency),
      );

  void _syncBasketCollateralController() {
    if (!financedCrmCollateralIsBasket(_collateralType)) {
      return;
    }
    final decimals = normalizeCurrencyCode(_currency) == 'XOF' ? 0 : 2;
    _collateralController.text =
        _basketTotalInExposureCurrency.toStringAsFixed(decimals);
  }

  void _syncFinancedCollateralCurrencyToExposureIfNeeded() {
    if (_collateralType == 'Liquidités dans la même devise') {
      _collateralCurrency = _currency;
    }
  }

  void _setCollateralType(String value) {
    setState(() {
      _collateralType = value;
      if (_collateralType == 'Liquidités dans la même devise') {
        _collateralCurrency = _currency;
      }
      if (!financedCrmCollateralRequiresIssuerRole(_collateralType)) {
        _issuerType = '';
      }
      if (!financedCrmCollateralRequiresRating(_collateralType)) {
        _issuerRating = '';
      }
      if (!financedCrmCollateralRequiresResidualMaturity(_collateralType)) {
        _maturityBucket = '';
      }
      if (!financedCrmCollateralSupportsConvertibleIndexQuestion(
          _collateralType)) {
        _convertibleMainIndex = true;
      }
      if (!financedCrmCollateralSupportsOpcvmHaircut(_collateralType)) {
        _opcvmHighestHaircut = 0.30;
      }
      if (financedCrmCollateralIsBasket(value) && _basketItems.isEmpty) {
        _basketItems = const [FinancedCrmBasketItem()];
      }
      _syncBasketCollateralController();
    });
  }

  void _addBasketItem() {
    setState(() {
      _basketItems = [
        ..._basketItems,
        FinancedCrmBasketItem(currency: _collateralCurrency),
      ];
      _syncBasketCollateralController();
    });
  }

  void _updateBasketItem(int index, FinancedCrmBasketItem item) {
    setState(() {
      final next = List<FinancedCrmBasketItem>.from(_basketItems);
      next[index] = item;
      _basketItems = next;
      _syncBasketCollateralController();
    });
  }

  void _removeBasketItem(int index) {
    setState(() {
      final next = List<FinancedCrmBasketItem>.from(_basketItems);
      next.removeAt(index);
      _basketItems = next;
      _syncBasketCollateralController();
    });
  }

  Widget _dropdownLabel(
    String text, {
    bool translate = false,
  }) {
    final normalizedText = _normalizeRatingLabel(text);
    return Text(
      translate ? normalizedText.tr(context) : normalizedText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }

  List<DropdownMenuItem<String>> _stringDropdownItems(
    List<String> items, {
    bool translate = false,
    String Function(String item)? displayTextBuilder,
  }) {
    final unique = <String>[];
    for (final raw in items) {
      final value = raw.trim();
      if (value.isEmpty || unique.contains(value)) {
        continue;
      }
      unique.add(value);
    }
    return unique
        .map(
          (item) => DropdownMenuItem<String>(
            value: item,
            child: _dropdownLabel(
              displayTextBuilder?.call(item) ?? item,
              translate: translate,
            ),
          ),
        )
        .toList(growable: false);
  }

  List<Widget> _selectedStringDropdownItems(
    List<String> items, {
    bool translate = false,
    String Function(String item)? displayTextBuilder,
  }) {
    final unique = <String>[];
    for (final raw in items) {
      final value = raw.trim();
      if (value.isEmpty || unique.contains(value)) {
        continue;
      }
      unique.add(value);
    }
    return unique
        .map(
          (item) => Align(
            alignment: Alignment.centerLeft,
            child: _dropdownLabel(
              displayTextBuilder?.call(item) ?? item,
              translate: translate,
            ),
          ),
        )
        .toList(growable: false);
  }

  InlineSpan _buildBankInstitutionTooltipContent(
    String title,
    String message,
  ) {
    final lines = _expandTooltipMessageLines(message);

    if (lines.isEmpty) {
      return const TextSpan(text: '');
    }

    final spans = <InlineSpan>[
      TextSpan(
        text: '$title\n',
        style: const TextStyle(
          fontSize: 12.4,
          fontWeight: FontWeight.w500,
          color: Colors.white,
          height: 1.2,
        ),
      ),
    ];

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (line.isEmpty) {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }
      if (line.startsWith('[[CARD]]')) {
        spans.add(_buildTooltipCardSpan(line));
        continue;
      }
      final isNote = line.startsWith('[[NOTE]]');
      if (isNote) {
        final noteText = line.replaceFirst('[[NOTE]]', '').trimLeft();
        spans.add(
          TextSpan(
            text: '$noteText${index == lines.length - 1 ? '' : '\n'}',
            style: const TextStyle(
              fontSize: 10.2,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: Color(0xFFFFB86B),
              height: 1.35,
            ),
          ),
        );
        continue;
      }

      final separatorIndex = line.indexOf(':');
      final hasLabelValueFormat =
          separatorIndex > 0 && separatorIndex < line.length - 1;

      if (hasLabelValueFormat) {
        final label = line.substring(0, separatorIndex).trim();
        final detail = line.substring(separatorIndex + 1).trim();
        final shouldBreakDetailLine = detail.startsWith('[[BREAK]]');
        final normalizedDetail = _normalizeTooltipSentence(
          shouldBreakDetailLine
              ? detail.replaceFirst('[[BREAK]]', '').trimLeft()
              : detail,
        );
        spans.add(
          TextSpan(
            children: [
              const TextSpan(
                text: '• ',
                style: TextStyle(
                  fontSize: 11.4,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8FB4FF),
                  height: 1.5,
                ),
              ),
              TextSpan(
                text: _capitalizeTooltipText(label),
                style: const TextStyle(
                  fontSize: 11.3,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
              TextSpan(
                text: shouldBreakDetailLine
                    ? ' :\n  $normalizedDetail${index == lines.length - 1 ? '' : '\n'}'
                    : ' : $normalizedDetail${index == lines.length - 1 ? '' : '\n'}',
                style: const TextStyle(
                  fontSize: 11.2,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFE8EEF9),
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
        continue;
      }

      spans.add(
        TextSpan(
          children: [
            const TextSpan(
              text: '• ',
              style: TextStyle(
                fontSize: 11.4,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8FB4FF),
                height: 1.48,
              ),
            ),
            TextSpan(
              text: '$line${index == lines.length - 1 ? '' : '\n'}',
              style: const TextStyle(
                fontSize: 11.2,
                fontWeight: FontWeight.w500,
                color: Color(0xFFE8EEF9),
                height: 1.48,
              ),
            ),
          ],
        ),
      );
    }

    return TextSpan(children: spans);
  }

  Widget _buildBankInstitutionInfoTooltip({
    required String title,
    required String message,
    required Widget child,
  }) {
    return Tooltip(
      richMessage: _buildBankInstitutionTooltipContent(title, message),
      constraints: const BoxConstraints(maxWidth: 350),
      waitDuration: const Duration(milliseconds: 140),
      showDuration: const Duration(seconds: 12),
      preferBelow: false,
      verticalOffset: 18,
      textAlign: TextAlign.start,
      padding: const EdgeInsets.fromLTRB(5, 3, 4, 3),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1C34),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2D4B7A), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
          ),
      child: child,
    );
  }

  Widget _bankInstitutionCaseDropdownLabel(
    String item, {
    bool includeInfoIcon = false,
  }) {
    final label = bankInstitutionCaseLabel(item);
    if (!includeInfoIcon) {
      return _dropdownLabel(label);
    }
    if (item == bankInstitutionWeakPrudentialCase) {
      return Row(
        children: [
          Expanded(child: _dropdownLabel(label)),
          const SizedBox(width: 8),
          _buildBankInstitutionInfoTooltip(
            title: context.tr('Critères'),
            message: _bankInstitutionWeakPrudentialTooltip.tr(context),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppTheme.accent.withAlpha(31),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: AppTheme.accent,
              ),
            ),
          ),
        ],
      );
    }
    if (item != bankInstitutionEligibleCategoriesCase) {
      return _dropdownLabel(label);
    }
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dropdownLabel(label),
              const SizedBox(height: 2),
              Text(
                context.tr(
                  '(veuillez consulter le point infos pour en savoir plus)',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 9.2,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.accent.withAlpha(170),
                      height: 1.15,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildBankInstitutionInfoTooltip(
          title: context.tr('Catégories concernées'),
          message: _bankInstitutionEligibleCategoriesTooltip.tr(context),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppTheme.accent.withAlpha(31),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: AppTheme.accent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _otherAssetTypeDropdownLabel(
    String item, {
    bool includeInfoIcon = false,
  }) {
    final label = _dropdownLabel(item);
    if (!includeInfoIcon) {
      return label;
    }

    String? tooltipTitle;
    String? tooltipMessage;
    if (item == otherAssetMiscellaneousType) {
      tooltipTitle = context.tr('Exemples inclus');
      tooltipMessage =
          context.tr('comptes d’ordre, dépôts, débiteurs, FCP, stocks.');
    } else if (item == otherAssetEquityCommitmentsType) {
      tooltipTitle = context.tr('Précision');
      tooltipMessage = context.tr(
        'hors engagements soumis à 250 % et hors actifs à risque élevé soumis à 150 %.',
      );
    }

    if (tooltipMessage == null || tooltipMessage.trim().isEmpty) {
      return label;
    }

    return Row(
      children: [
        Expanded(child: label),
        const SizedBox(width: 8),
        _buildBankInstitutionInfoTooltip(
          title: tooltipTitle ?? context.tr('Précision'),
          message: tooltipMessage,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppTheme.accent.withAlpha(31),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: AppTheme.accent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _offBalanceRiskLevelDropdownLabel(
    String item, {
    bool includeInfoIcon = false,
  }) {
    final label = _dropdownLabel(item);
    if (!includeInfoIcon) {
      return label;
    }

    final tooltipMessage = switch (item) {
      offBalanceLowRiskLevel => _offBalanceLowRiskTooltip,
      offBalanceMinorRiskLevel => _offBalanceMinorRiskTooltip,
      offBalanceMediumRiskLevel => _offBalanceMediumRiskTooltip,
      offBalanceHighRiskLevel => _offBalanceHighRiskTooltip,
      offBalanceVeryHighRiskLevel => _offBalanceVeryHighRiskTooltip,
      _ => '',
    };
    if (tooltipMessage.trim().isEmpty) {
      return label;
    }

    return Row(
      children: [
        _buildBankInstitutionInfoTooltip(
          title: item,
          message: tooltipMessage,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppTheme.accent.withAlpha(31),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: AppTheme.accent,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: label),
      ],
    );
  }

  Widget _buildFinancialStepHelper(BuildContext context) {
    if (!_shouldAskOffBalanceRiskLevel) {
      return const SizedBox.shrink();
    }

    return _buildFieldCard(
      context: context,
      title: 'Niveau de risque hors bilan',
      subtitle: '',
      icon: Icons.rule_folder_outlined,
      inlineTooltip: _offBalanceFcecTooltip,
      tooltipTitle: 'FCEC et hors bilan',
      tooltipMaxWidth: 460,
      child: DropdownButtonFormField<String>(
        initialValue: _offBalanceRiskLevel,
        isExpanded: true,
        decoration: _fieldDecoration(
          context,
          hint: context.tr('Choisir une option'),
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? context.tr('Champ requis')
            : null,
        selectedItemBuilder: (context) => offBalanceRiskLevelOptions
            .map(
              (item) => Align(
                alignment: Alignment.centerLeft,
                child: _offBalanceRiskLevelDropdownLabel(item),
              ),
            )
            .toList(growable: false),
        items: offBalanceRiskLevelOptions
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: _offBalanceRiskLevelDropdownLabel(
                  item,
                  includeInfoIcon: true,
                ),
              ),
            )
            .toList(growable: false),
        onChanged: _handleOffBalanceRiskLevelChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayCurrency = PortfolioCurrencyScope.maybeOf(context);
    final preview = _buildPreview();

    return Container(
      color: _wizardScreenColor(context),
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                const Divider(height: 1),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final useSplitLayout = constraints.maxWidth >= 980;
                      final contentWidth = constraints.maxWidth - 40;
                      final fixedMainCardHeight = useSplitLayout ? 528.0 : null;
                      final useFixedMainCard = fixedMainCardHeight != null;
                      final summaryPaneWidth = useSplitLayout
                          ? (contentWidth - 18) * 0.4
                          : contentWidth;
                      final kpiWidth = summaryPaneWidth >= 580
                          ? (summaryPaneWidth - 10) / 2
                          : summaryPaneWidth;

                      final leftColumn = _buildFixedSummaryColumn(
                        context,
                        preview,
                        displayCurrency,
                        kpiWidth,
                      );
                      final rightPanel = _buildCurrentRightPanel(
                        context,
                        preview,
                        displayCurrency,
                        fixedHeight: useFixedMainCard,
                      );

                      final sharedContent = useSplitLayout
                          ? Row(
                              crossAxisAlignment: useFixedMainCard
                                  ? CrossAxisAlignment.stretch
                                  : CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 6, child: rightPanel),
                                const SizedBox(width: 5),
                                Expanded(flex: 4, child: leftColumn),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                leftColumn,
                                const SizedBox(height: 4),
                                rightPanel,
                              ],
                            );

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(5, 4, 5, 5),
                        child: Container(
                          width: double.infinity,
                          constraints: fixedMainCardHeight == null
                              ? const BoxConstraints()
                              : BoxConstraints(
                                  minHeight: fixedMainCardHeight,
                                  maxHeight: fixedMainCardHeight,
                                ),
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: _wizardShellColor(context),
                            borderRadius:
                                BorderRadius.circular(_exposureFormRadius),
                            border: _wizardBoxBorder(context),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTopActionStepRow(context),
                              const SizedBox(height: 3),
                              if (useFixedMainCard)
                                Expanded(child: sharedContent)
                              else
                                sharedContent,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_submitting) _buildSavingOverlay(context),
        ],
      ),
    );
  }

  Widget _buildFixedSummaryColumn(
    BuildContext context,
    _ExposurePreview preview,
    String displayCurrency,
    double kpiWidth,
  ) {
    final compactKpiWidth = kpiWidth > 156 ? 156.0 : kpiWidth;
    final items = _buildIntroKpis(context, preview, displayCurrency);
    final isDark = _isExposureDark(context);
    final summaryShellBorderColor =
        isDark ? const Color(0xFF4F6FA3) : const Color(0xFFBED0F1);
    final summaryBackground = isDark
        ? const [Color(0xFF10234A), Color(0xFF16377A), Color(0xFF1A4697)]
        : const [Color(0xFFF8FBFF), Color(0xFFE3ECFF), Color(0xFFC9DAFF)];
    final summaryTitleColor =
        isDark ? AppTheme.darkText : const Color(0xFF153B7A);
    final summaryBodyColor =
        isDark ? const Color(0xFFD7E2F4) : const Color(0xFF5A709A);
    const summaryAccentStart = Color(0xFF3B82F6);
    const summaryAccentEnd = Color(0xFF0B3D91);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: summaryBackground,
          stops: const [0.0, 0.52, 1.0],
        ),
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        border: Border.all(
          color: summaryShellBorderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x26000000) : const Color(0x120B3D91),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, outerConstraints) {
          final hasBoundedOuterHeight = outerConstraints.maxHeight.isFinite;
          final summaryBody = Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 8.0;
                final availableWidth = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : compactKpiWidth * 2 + spacing;
                final columns = availableWidth >= 320 ? 2 : 1;
                final itemWidth = columns == 1
                    ? availableWidth
                    : (availableWidth - spacing * (columns - 1)) / columns;
                final hasBoundedHeight = constraints.maxHeight.isFinite;
                final illustrationWidth = availableWidth >= 430
                    ? 250.0
                    : availableWidth >= 340
                        ? 220.0
                        : 176.0;
                final kpiGrid = Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: item.fullSpan ? availableWidth : itemWidth,
                        child: _HeroKpiCard(
                          label: item.label,
                          value: item.value,
                          icon: item.icon,
                          accent: item.accent,
                          highlighted: item.highlighted,
                          compact: true,
                        ),
                      ),
                  ],
                );

                return SizedBox(
                  height: hasBoundedHeight ? constraints.maxHeight : null,
                  child: Stack(
                    children: [
                      Positioned(
                        right: -10,
                        bottom: hasBoundedHeight ? -8 : 8,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: isDark ? 0.10 : 0.17,
                            child: Icon(
                              Icons.account_balance_wallet_rounded,
                              size: illustrationWidth * 0.72,
                              color: isDark
                                  ? const Color(0xFFE7EEF9)
                                  : const Color(0xFF2D6CDF),
                            ),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Synthèse',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 15.8,
                                            color: summaryTitleColor,
                                            height: 1.05,
                                          ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      'Lecture rapide du profil RWA, des expositions et des échéances.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 10.5,
                                            color: summaryBodyColor,
                                            height: 1.45,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (hasBoundedHeight)
                            Expanded(
                              child: SingleChildScrollView(
                                child: kpiGrid,
                              ),
                            )
                          else
                            kpiGrid,
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 10,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      summaryAccentStart,
                      summaryAccentEnd,
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(_exposureFormRadius),
                    topRight: Radius.circular(_exposureFormRadius),
                  ),
                ),
              ),
              if (hasBoundedOuterHeight)
                Expanded(child: summaryBody)
              else
                summaryBody,
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopActionStepRow(BuildContext context) {
    final visibleStepCount = _stepMetas.length - 1;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _IntroActionButton(
                icon: Icons.restart_alt_rounded,
                accent: const Color(0xFFF59E0B),
                filled: true,
                onTap: _resetDraftValues,
              ),
              const SizedBox(width: 6),
              for (var visibleIndex = 0;
                  visibleIndex < visibleStepCount;
                  visibleIndex++) ...[
                _StepOverviewChip(
                  number: visibleIndex + 1,
                  isActive: visibleIndex + 1 == _currentStep,
                  isCompleted: visibleIndex + 1 < _currentStep,
                ),
                if (visibleIndex < visibleStepCount - 1)
                  const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentRightPanel(
      BuildContext context, _ExposurePreview preview, String displayCurrency,
      {required bool fixedHeight}) {
    final stickyHeight =
        _showStickyStepHeader ? (_expandStickyStepHeader ? 58.0 : 38.0) : 0.0;
    const panelBorderColor = Color(0x990B3D91);

    return Container(
      height: fixedHeight ? double.infinity : null,
      decoration: BoxDecoration(
        color: _wizardPanelColor(context),
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        border: Border.all(
          color: panelBorderColor,
          width: 0.55,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Column(
        mainAxisSize: fixedHeight ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: stickyHeight,
            child: stickyHeight <= 0
                ? null
                : Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _buildStickyStepHeader(context),
                  ),
          ),
          if (fixedHeight)
            Expanded(
              child: _buildRightPanelScrollable(
                context,
                preview,
                displayCurrency,
              ),
            )
          else
            _buildRightPanelScrollable(
              context,
              preview,
              displayCurrency,
            ),
          const SizedBox(height: 3),
          _buildInlineStepFooter(context),
        ],
      ),
    );
  }

  Widget _buildRightPanelScrollable(
    BuildContext context,
    _ExposurePreview preview,
    String displayCurrency,
  ) {
    return RawScrollbar(
      controller: _rightPanelScrollController,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      thickness: 2.5,
      radius: const Radius.circular(999),
      crossAxisMargin: 1,
      mainAxisMargin: 4,
      thumbColor: AppTheme.accent.withValues(
        alpha: _isExposureDark(context) ? 0.9 : 0.72,
      ),
      trackColor: _wizardBorderColor(context).withValues(alpha: 0.55),
      trackBorderColor: Colors.transparent,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleRightPanelScrollNotification,
        child: SingleChildScrollView(
          controller: _rightPanelScrollController,
          primary: false,
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          child: _buildCurrentRightStepContent(
            context,
            preview,
            displayCurrency,
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentRightStepContent(
    BuildContext context,
    _ExposurePreview preview,
    String displayCurrency,
  ) {
    switch (_currentStep) {
      case 1:
        return _PrimaryInformationStepScreen(
          title: _stepMetas[1].title,
          subtitle: _stepMetas[1].subtitle,
          formKey: _primaryFormKey,
          fields: [
            _buildFieldCard(
              context: context,
              title: 'Contrepartie',
              subtitle: 'Nom ou raison sociale',
              icon: Icons.business_outlined,
              child: TextFormField(
                controller: _nameController,
                decoration: _fieldDecoration(
                  context,
                  hint: context.tr('Nom de la contrepartie'),
                ),
                validator: _requiredValidator,
              ),
            ),
            _buildFieldCard(
              context: context,
              title: 'ID Exposition',
              subtitle: 'Identifiant de l’exposition',
              icon: Icons.tag_outlined,
              child: TextFormField(
                controller: _exposureIdController,
                readOnly: true,
                enableInteractiveSelection: false,
                decoration: _fieldDecoration(
                  context,
                  hint: _generatedExposureId?.isNotEmpty == true
                      ? _generatedExposureId!
                      : context.tr('Genere automatiquement'),
                ),
              ),
            ),
            _buildFieldCard(
              context: context,
              title: 'Date d octroi',
              subtitle: 'Date de mise en place',
              icon: Icons.event_available_outlined,
              child: TextFormField(
                controller: _grantDateController,
                readOnly: true,
                decoration: _fieldDecoration(
                  context,
                  hint: context.tr('Choisir une date'),
                  suffixIcon: const Icon(
                    Icons.calendar_month_outlined,
                    size: 18,
                    color: Color(0xFF7A8AA4),
                  ),
                ),
                validator: (_) =>
                    _grantDate == null ? context.tr('Champ requis') : null,
                onTap: () => _pickDate(
                  currentValue: _grantDate,
                  onChanged: (value) {
                    _grantDate = value;
                    _syncDateController(_grantDateController, value);
                    if (_maturityDate != null &&
                        value != null &&
                        _maturityDate!.isBefore(value)) {
                      _maturityDate = value;
                      _syncDateController(_maturityDateController, value);
                    }
                    setState(() {});
                  },
                ),
              ),
            ),
            _buildFieldCard(
              context: context,
              title: 'Date d echeance',
              subtitle: 'Date de fin prevue',
              icon: Icons.event_busy_outlined,
              child: TextFormField(
                controller: _maturityDateController,
                readOnly: true,
                decoration: _fieldDecoration(
                  context,
                  hint: context.tr('Choisir une date'),
                  suffixIcon: const Icon(
                    Icons.calendar_month_outlined,
                    size: 18,
                    color: Color(0xFF7A8AA4),
                  ),
                ),
                validator: (_) {
                  if (_maturityDate == null) {
                    return context.tr('Champ requis');
                  }
                  if (_grantDate != null &&
                      _maturityDate != null &&
                      _maturityDate!.isBefore(_grantDate!)) {
                    return context.tr('Echeance anterieure a l octroi');
                  }
                  return null;
                },
                onTap: () => _pickDate(
                  currentValue: _maturityDate,
                  firstDate: _grantDate ?? DateTime(2000),
                  onChanged: (value) {
                    _maturityDate = value;
                    _syncDateController(_maturityDateController, value);
                    setState(() {});
                  },
                ),
              ),
            ),
            _buildFieldCard(
              context: context,
              title: 'Pays',
              subtitle: 'Pays de residence',
              icon: Icons.public_outlined,
              child: DropdownButtonFormField<String>(
                initialValue: _countryController.text.trim().isEmpty
                    ? null
                    : canonicalCountryName(
                        _countryController.text.trim(),
                        fallback: _countryController.text.trim(),
                      ),
                isExpanded: true,
                menuMaxHeight: 320,
                decoration: _fieldDecoration(
                  context,
                  hint: context.tr('Selectionner un pays'),
                ),
                validator: (value) {
                  final country = (value ?? _countryController.text).trim();
                  return country.isEmpty ? context.tr('Champ requis') : null;
                },
                selectedItemBuilder: (context) => _selectedStringDropdownItems(
                  _availableCountryOptions,
                  displayTextBuilder: (item) =>
                      displayCountryName(item, fallback: item),
                ),
                items: _stringDropdownItems(
                  _availableCountryOptions,
                  displayTextBuilder: (item) =>
                      displayCountryName(item, fallback: item),
                ),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _countryController.text = value;
                  });
                },
              ),
            ),
            _buildFieldCard(
              context: context,
              title: 'Notation du pays',
              subtitle: 'Pays de residence',
              icon: Icons.flag_circle_outlined,
              child: DropdownButtonFormField<String>(
                initialValue:
                    _selectedValueOrNull(_countryRating, _availableRatings),
                isExpanded: true,
                decoration: _fieldDecoration(
                  context,
                  hint: context.tr('Choisir une option'),
                ),
                validator: _requiredSelectionValidator,
                selectedItemBuilder: (context) =>
                    _selectedStringDropdownItems(_availableRatings),
                items: _stringDropdownItems(_availableRatings),
                onChanged: (value) =>
                    setState(() => _countryRating = value ?? ''),
              ),
            ),
            _StepGridFullWidth(
              child: _buildFieldCard(
                context: context,
                title: 'Notation de la contrepartie',
                subtitle: 'Note de credit',
                icon: Icons.stars_outlined,
                child: DropdownButtonFormField<String>(
                  initialValue:
                      _selectedValueOrNull(_rating, _availableRatings),
                  isExpanded: true,
                  decoration: _fieldDecoration(
                    context,
                    hint: context.tr('Choisir une option'),
                  ),
                  validator: _requiredSelectionValidator,
                  selectedItemBuilder: (context) =>
                      _selectedStringDropdownItems(_availableRatings),
                  items: _stringDropdownItems(_availableRatings),
                  onChanged: _handleCounterpartyRatingChanged,
                ),
              ),
            ),
            if (_shouldAskCounterpartyOceQuestion)
              _StepGridFullWidth(
                child: _buildFieldCard(
                  context: context,
                  title: "La contrepartie est-elle notée par l'OCE ?",
                  subtitle:
                      'Si non, la pondération sera déduite de la notation du pays de résidence',
                  icon: Icons.fact_check_outlined,
                  child: DropdownButtonFormField<bool>(
                    initialValue: _sovereignOceEstablished,
                    isExpanded: true,
                    decoration: _fieldDecoration(
                      context,
                      hint: context.tr('Choisir une option'),
                    ),
                    validator: (value) =>
                        _shouldAskCounterpartyOceQuestion && value == null
                            ? context.tr('Champ requis')
                            : null,
                    items: [
                      DropdownMenuItem<bool>(
                        value: true,
                        child: Text(context.tr('Oui')),
                      ),
                      DropdownMenuItem<bool>(
                        value: false,
                        child: Text(context.tr('Non')),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _sovereignOceEstablished = value;
                        if (value != true) {
                          _sovereignOceNote = '';
                        }
                      });
                    },
                  ),
                ),
              ),
            if (_shouldShowCounterpartyOceNote)
              _buildFieldCard(
                context: context,
                title: 'Note OCE',
                subtitle: 'Échelle de 0 à 7',
                icon: Icons.filter_8_outlined,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedValueOrNull(
                      _sovereignOceNote, sovereignOceNotes),
                  isExpanded: true,
                  decoration: _fieldDecoration(
                    context,
                    hint: context.tr('Choisir une option'),
                  ),
                  validator: _requiredSelectionValidator,
                  selectedItemBuilder: (context) =>
                      _selectedStringDropdownItems(sovereignOceNotes),
                  items: _stringDropdownItems(sovereignOceNotes),
                  onChanged: (value) => setState(
                    () => _sovereignOceNote = value ?? '',
                  ),
                ),
              )
            else if (_shouldAskCounterpartyOceQuestion &&
                _sovereignOceEstablished == false)
              const _StepGridFullWidth(
                child: _InfoBanner(
                  icon: Icons.public_outlined,
                  accent: Color(0xFF2563EB),
                  text:
                      'La pondération sera déduite de la notation du pays de résidence.',
                ),
              ),
          ],
        );
      case 2:
        return _CategoryStepScreen(
          title: _stepMetas[2].title,
          subtitle: _stepMetas[2].subtitle,
          formKey: _categoryFormKey,
          content: _buildCategoryStepBody(context),
        );
      case 3:
        return _FinancialDataStepScreen(
          title: _stepMetas[3].title,
          subtitle: _stepMetas[3].subtitle,
          formKey: _financialFormKey,
          fields: [
            _buildFieldCard(
              context: context,
              title: 'Montant d\'exposition',
              subtitle: "Montant brut de l'opération",
              icon: Icons.payments_outlined,
              child: TextFormField(
                controller: _amountController,
                decoration: _fieldDecoration(
                  context,
                  hint: context.tr('Montant d\'exposition'),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                validator: _amountValidator,
                onChanged: _handleFinancialAmountsChanged,
              ),
            ),
            _buildFieldCard(
              context: context,
              title: 'Montant d\'exposition au bilan',
              subtitle: 'Part déjà inscrite au bilan',
              icon: Icons.account_balance_wallet_outlined,
              child: TextFormField(
                controller: _onBalanceAmountController,
                decoration: _fieldDecoration(
                  context,
                  hint: context.tr('Montant d\'exposition au bilan'),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                validator: _onBalanceAmountValidator,
                onChanged: _handleFinancialAmountsChanged,
              ),
            ),
            _buildFieldCard(
              context: context,
              title: 'Provisions',
              subtitle: 'Montant des provisions (optionnel)',
              icon: Icons.money_off_csred_outlined,
              child: TextFormField(
                controller: _provisionsAmountController,
                decoration: _fieldDecoration(
                  context,
                  hint: context.tr('Provisions'),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: _handleFinancialAmountsChanged,
              ),
            ),
            _buildFieldCard(
              context: context,
              title: 'Devise',
              subtitle: 'Devise de saisie',
              icon: Icons.currency_exchange_outlined,
              child: DropdownButtonFormField<String>(
                initialValue:
                    _selectedValueOrNull(_currency, _availableCurrencyOptions),
                decoration: _fieldDecoration(
                  context,
                  hint: context.tr('Choisir une option'),
                ),
                validator: _requiredSelectionValidator,
                items: const ['XOF', 'EUR', 'USD']
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _currency = value ?? '';
                  _syncFinancedCollateralCurrencyToExposureIfNeeded();
                }),
              ),
            ),
            _buildFieldCard(
              context: context,
              title: 'Montant d\'exposition hors bilan',
              subtitle:
                  'Déduit du montant d\'exposition et de l\'exposition au bilan',
              icon: Icons.calculate_outlined,
              child: InputDecorator(
                decoration: _fieldDecoration(
                  context,
                  errorText:
                      _hasInvalidOnBalanceAmount ? 'Valeur incorrecte' : null,
                ),
                child: Text(
                  _hasInvalidOnBalanceAmount
                      ? 'Valeur incorrecte'
                      : _formatReadonlyAmount(
                          _derivedOffBalanceExposureAmount,
                          sourceCurrency: _currency,
                          targetCurrency: displayCurrency,
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (_hasInvalidOnBalanceAmount
                          ? Theme.of(context).textTheme.bodySmall
                          : Theme.of(context).textTheme.titleMedium)
                      ?.copyWith(
                    fontWeight: _hasInvalidOnBalanceAmount
                        ? FontWeight.w500
                        : FontWeight.w500,
                    fontSize: _hasInvalidOnBalanceAmount ? 10.5 : null,
                    color: _hasInvalidOnBalanceAmount
                        ? AppTheme.danger
                        : const Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ),
          ],
          helper: _buildFinancialStepHelper(context),
        );
      case 4:
        return _CrmChoiceStepScreen(
          title: _stepMetas[4].title,
          subtitle: 'Qualification initiale de la couverture',
          questionText: 'Cette exposition bénéficie-t-elle d une CRM ?',
          selectedMode: _crmExistsAnswer == null
              ? ''
              : (_crmExistsAnswer! ? 'OUI' : 'NON'),
          choices: const [
            _ChoiceCardData(
              value: 'OUI',
              label: 'Oui',
              subtitle: 'Avec couverture',
              icon: Icons.check_circle_rounded,
              accent: Color(0xFF00C853),
            ),
            _ChoiceCardData(
              value: 'NON',
              label: 'Non',
              subtitle: 'Sans couverture',
              icon: Icons.cancel_rounded,
              accent: Color(0xFFFF3B30),
            ),
          ],
          onModeChanged: (value) => _setCrmExistsAnswer(value == 'OUI'),
        );
      case 5:
        if (_crmSelectionStage) {
          return _CrmChoiceStepScreen(
            title: _stepMetas[5].title,
            subtitle: 'Indiquez si la CRM est financée ou non financée',
            selectedMode: _crmMode,
            choices: [
              _ChoiceCardData(
                value: 'CRM financee',
                label: context.tr('CRM financee'),
                icon: Icons.shield_outlined,
                accent: const Color(0xFF0F766E),
              ),
              _ChoiceCardData(
                value: 'CRM non financee',
                label: context.tr('CRM non financee'),
                icon: Icons.handshake_outlined,
                accent: AppTheme.accent,
              ),
            ],
            onModeChanged: (value) {
              setState(() {
                _crmMode = value;
              });
            },
          );
        }
        return _CrmDetailsStepScreen(
          title:
              _crmMode == 'CRM financee' ? 'CRM financee' : 'CRM non financee',
          subtitle: _crmMode == 'CRM financee'
              ? 'Parametres de la surete financee'
              : 'Parametres de la garantie non financee',
          formKey: _crmFormKey,
          icon: _crmMode == 'CRM financee'
              ? Icons.shield_outlined
              : Icons.handshake_outlined,
          accent: _crmMode == 'CRM financee'
              ? const Color(0xFF0F766E)
              : AppTheme.accent,
          inlineTooltip:
              _crmMode == 'CRM financee' ? _crmFinancedTooltip : null,
          tooltipTitle: 'CRM financée',
          child: _buildCrmDynamicBody(context),
        );
      case 6:
        return _CommentStepScreen(
          title: _stepMetas[6].title,
          subtitle: _stepMetas[6].subtitle,
          formKey: _commentFormKey,
          commentField: TextFormField(
            controller: _commentController,
            maxLines: 8,
            decoration: _fieldDecoration(
              context,
              hint: context.tr(
                'Commentaire de suivi, hypothese de gestion ou precision de validation',
              ),
            ),
          ),
        );
      case 7:
        return _FinalDecisionStepScreen(
          title: _stepMetas[7].title,
          subtitle: _stepMetas[7].subtitle,
          submitLabel: widget.submitLabel,
          submitting: _submitting,
          onConfirm: _submit,
          onBack: _goBack,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  bool get _isSovereignCategory => _categoryCode == 'a';
  bool get _isPublicBodyCategory => _categoryCode == 'b';
  bool get _isBmdCategory => _categoryCode == 'c';
  bool get _isBankInstitutionCategory => _categoryCode == 'd';
  bool get _isRetailCategory => _categoryCode == 'f';
  bool get _isResidentialMortgageCategory => _categoryCode == 'g';
  bool get _isCommercialRealEstateCategory => _categoryCode == 'h';
  bool get _isDefaultedExposureCategory => _categoryCode == 'i';
  bool get _isOtherAssetsCategory => _categoryCode == 'k';
  bool get _isOffBalanceCategory => _categoryCode == 'l';
  bool get _isEnterpriseCategory => _categoryCode == 'e';
  bool get _shouldAskCounterpartyOceQuestion =>
      _rating == 'Non noté' && !_sovereignPriorityQuestionAnsweredYes;
  bool get _shouldShowCounterpartyOceNote =>
      _shouldAskCounterpartyOceQuestion && _sovereignOceEstablished == true;
  bool get _usesRetailEnterpriseLogic =>
      _isRetailCategory && _retailEligibilityCriteriaSatisfied == false;
  bool get _usesCommercialRealEstateEnterpriseLogic =>
      _isCommercialRealEstateCategory && _commercialRealEstateEligible == false;
  bool get _isEnterpriseLikeCategory =>
      _isEnterpriseCategory ||
      _usesRetailEnterpriseLogic ||
      _usesCommercialRealEstateEnterpriseLogic;
  bool get _shouldShowBmdListedInstitutionQuestion =>
      _isBmdCategory &&
      _bmdHighQualityCase == false &&
      ((_bmdUemoaFcfaCase == true && _bmdUemoaCriteriaSatisfied == false) ||
          _bmdUemoaFcfaCase == false);
  bool get _usesBankInstitutionMatrix =>
      _isBankInstitutionCategory &&
      _bankInstitutionCase == bankInstitutionEligibleCategoriesCase;
  bool get _shouldAskEnterprisePrudentialProcedure =>
      _isEnterpriseLikeCategory &&
      _enterpriseExceedsBceaoDegradationThreshold == false;
  bool get _shouldAskEnterpriseInvestmentFirm =>
      _isEnterpriseLikeCategory &&
      _enterpriseExceedsBceaoDegradationThreshold == false &&
      _enterprisePrudentialProcedure == false;
  bool get _usesDefaultedExposureCarryForward =>
      _isDefaultedExposureCategory &&
      (_defaultedExposureInitialRiskWeight ?? 0) > 1.0;
  bool get _shouldAskDefaultedResidentialQuestion =>
      _isDefaultedExposureCategory &&
      _defaultedExposureInitialRiskWeight != null &&
      _defaultedExposureInitialRiskWeight! <= 1.0;
  bool get _shouldAskDefaultedProvisionLevel =>
      _shouldAskDefaultedResidentialQuestion &&
      _defaultedExposureResidentialMortgageInDefault == false;
  bool get _hasBankInitialMaturityDates =>
      _grantDate != null && _maturityDate != null;

  void _handleCategoryChanged(String? value) {
    final nextCode = value ?? _categoryCode;
    final wasOffBalanceCategory = _isOffBalanceCategory;
    setState(() {
      _categoryCode = nextCode;
      if (!_isSovereignCategory) {
        _sovereignSpecialCase = sovereignNoSpecialCase;
        _sovereignPreferentialZeroWeight = false;
        _sovereignPriorityQuestionAnsweredYes = false;
      } else {
        _sovereignSpecialCase = coerceSovereignSpecialCase(
          _sovereignSpecialCase,
          fallbackToLegacy: _sovereignPreferentialZeroWeight,
        );
        _sovereignPreferentialZeroWeight = hasSovereignPriorityZeroWeightCase(
          _sovereignSpecialCase,
          sovereignPreferentialZeroWeight: _sovereignPreferentialZeroWeight,
        );
        _sovereignPriorityQuestionAnsweredYes =
            _sovereignSpecialCase != sovereignNoSpecialCase ||
                _sovereignPreferentialZeroWeight;
        if (!sovereignRatingOptions.contains(_rating)) {
          _rating = '';
        }
      }
      if (!_isPublicBodyCategory) {
        _publicBodyUemoaFcfaCase = null;
        _publicBodyFinancesNonPublicActivity = null;
      }
      if (!_isBmdCategory) {
        _bmdHighQualityCase = null;
        _bmdUemoaFcfaCase = null;
        _bmdUemoaCriteriaSatisfied = null;
        _bmdListedInstitutionFcfaCase = null;
      }
      if (!_isBankInstitutionCategory) {
        _bankInstitutionCase = null;
      }
      if (!_isOtherAssetsCategory) {
        _otherAssetType = null;
      }
      if (!_isRetailCategory) {
        _retailEligibilityCriteriaSatisfied = null;
      }
      if (!_isResidentialMortgageCategory) {
        _residentialMortgageEligible = null;
      }
      if (!_isCommercialRealEstateCategory) {
        _commercialRealEstateEligible = null;
      }
      if (!_isDefaultedExposureCategory) {
        _defaultedExposureInitialRiskWeight = null;
        _defaultedExposureResidentialMortgageInDefault = null;
        _defaultedExposureProvisionAtLeastTwentyPercent = null;
      }
      if (!_isEnterpriseLikeCategory) {
        _enterpriseExceedsBceaoDegradationThreshold = null;
        _enterprisePrudentialProcedure = null;
        _enterpriseInvestmentFirmWithoutBankingLaw = null;
      }
      if (_isOffBalanceCategory) {
        _crmExistsAnswer = false;
        _crmMode = 'Aucune';
        _crmSelectionStage = true;
      } else if (wasOffBalanceCategory && _crmMode == 'Aucune') {
        _crmExistsAnswer = null;
      }
      if ((_isBmdCategory || _isBankInstitutionCategory) &&
          !prudentialRatings.contains(_rating)) {
        _rating = '';
      }
      if (_isEnterpriseLikeCategory &&
          !enterpriseRatingOptions.contains(_rating)) {
        _rating = '';
      }
    });
  }

  String _retailCriteriaTooltip(BuildContext context) {
    return [
      context.tr('Destination : particulier ou PME/PMI'),
      context.tr(
          'Produits concernés : crédits CT/MT/LT, découverts, cartes de crédit, crédit-bail, facilités aux PME'),
      context
          .tr('Granularité : exposition ≤ 0,2 % du portefeuille retail global'),
      context.tr(
          'Faible montant : encours agrégé par contrepartie ≤ 150 000 000 FCFA'),
      context.tr(
          'Consentement BIC : accord du client pour transmission des données au BIC'),
    ].join('\n');
  }

  void _handlePublicBodyUemoaQuestionChanged(bool? value) {
    setState(() {
      _publicBodyUemoaFcfaCase = value;
      if (value != true) {
        _publicBodyFinancesNonPublicActivity = null;
      }
    });
  }

  void _handlePublicBodyNonPublicActivityChanged(bool? value) {
    setState(() {
      _publicBodyFinancesNonPublicActivity = value;
    });
  }

  void _handleBmdHighQualityChanged(bool? value) {
    setState(() {
      _bmdHighQualityCase = value;
      _bmdUemoaFcfaCase = null;
      _bmdUemoaCriteriaSatisfied = null;
      _bmdListedInstitutionFcfaCase = null;
    });
  }

  void _handleBmdUemoaQuestionChanged(bool? value) {
    setState(() {
      _bmdUemoaFcfaCase = value;
      _bmdUemoaCriteriaSatisfied = null;
      _bmdListedInstitutionFcfaCase = null;
    });
  }

  void _handleBmdUemoaCriteriaChanged(bool? value) {
    setState(() {
      _bmdUemoaCriteriaSatisfied = value;
      _bmdListedInstitutionFcfaCase = null;
    });
  }

  void _handleBmdListedInstitutionChanged(bool? value) {
    setState(() {
      _bmdListedInstitutionFcfaCase = value;
    });
  }

  void _handleBankInstitutionCaseChanged(String? value) {
    final resolvedValue = coerceBankInstitutionCase(value);
    setState(() {
      _bankInstitutionCase = resolvedValue;
      if (_usesBankInstitutionMatrix && !prudentialRatings.contains(_rating)) {
        _rating = '';
      }
    });
  }

  void _handleOtherAssetTypeChanged(String? value) {
    setState(() {
      _otherAssetType = coerceOtherAssetType(value);
    });
  }

  void _handleOffBalanceRiskLevelChanged(String? value) {
    setState(() {
      _offBalanceRiskLevel = coerceOffBalanceRiskLevel(value);
    });
  }

  void _handleFinancialAmountsChanged(String _) {
    setState(() {
      if (!_shouldAskOffBalanceRiskLevel) {
        _offBalanceRiskLevel = null;
      }
    });
    _financialFormKey.currentState?.validate();
  }

  void _handleEnterpriseBceaoDegradationChanged(bool? value) {
    setState(() {
      _enterpriseExceedsBceaoDegradationThreshold = value;
      if (value != false) {
        _enterprisePrudentialProcedure = null;
        _enterpriseInvestmentFirmWithoutBankingLaw = null;
      }
    });
  }

  void _handleEnterprisePrudentialProcedureChanged(bool? value) {
    setState(() {
      _enterprisePrudentialProcedure = value;
      if (value != false) {
        _enterpriseInvestmentFirmWithoutBankingLaw = null;
      }
    });
  }

  void _handleEnterpriseInvestmentFirmChanged(bool? value) {
    setState(() {
      _enterpriseInvestmentFirmWithoutBankingLaw = value;
    });
  }

  void _handleRetailEligibilityChanged(bool? value) {
    setState(() {
      _retailEligibilityCriteriaSatisfied = value;
      if (value != false) {
        _enterpriseExceedsBceaoDegradationThreshold = null;
        _enterprisePrudentialProcedure = null;
        _enterpriseInvestmentFirmWithoutBankingLaw = null;
      } else if (!enterpriseRatingOptions.contains(_rating)) {
        _rating = '';
      }
    });
  }

  void _handleResidentialMortgageEligibilityChanged(bool? value) {
    setState(() {
      _residentialMortgageEligible = value;
    });
  }

  void _handleCommercialRealEstateEligibilityChanged(bool? value) {
    setState(() {
      _commercialRealEstateEligible = value;
      if (value != false) {
        _enterpriseExceedsBceaoDegradationThreshold = null;
        _enterprisePrudentialProcedure = null;
        _enterpriseInvestmentFirmWithoutBankingLaw = null;
      } else if (!enterpriseRatingOptions.contains(_rating)) {
        _rating = '';
      }
    });
  }

  void _handleDefaultedExposureInitialRiskWeightChanged(double? value) {
    setState(() {
      _defaultedExposureInitialRiskWeight = value;
      if (value == null || value > 1.0) {
        _defaultedExposureResidentialMortgageInDefault = null;
        _defaultedExposureProvisionAtLeastTwentyPercent = null;
      }
    });
  }

  void _handleDefaultedExposureResidentialMortgageChanged(bool? value) {
    setState(() {
      _defaultedExposureResidentialMortgageInDefault = value;
      if (value != false) {
        _defaultedExposureProvisionAtLeastTwentyPercent = null;
      }
    });
  }

  void _handleDefaultedExposureProvisionLevelChanged(bool? value) {
    setState(() {
      _defaultedExposureProvisionAtLeastTwentyPercent = value;
    });
  }

  void _handleSovereignPriorityQuestionChanged(bool? value) {
    final answeredYes = value ?? false;
    setState(() {
      _sovereignPriorityQuestionAnsweredYes = answeredYes;
      if (!answeredYes) {
        _sovereignSpecialCase = sovereignNoSpecialCase;
        _sovereignPreferentialZeroWeight = false;
        _sovereignOceEstablished = null;
        _sovereignOceNote = '';
      } else if (_sovereignSpecialCase == sovereignNoSpecialCase) {
        _sovereignSpecialCase = sovereignLegacySpecialCase;
        _sovereignPreferentialZeroWeight = true;
        _sovereignOceEstablished = null;
        _sovereignOceNote = '';
      }
    });
  }

  void _handleCounterpartyRatingChanged(String? value) {
    final nextRating = value ?? '';
    setState(() {
      final wasUnrated = _rating == 'Non noté';
      _rating = nextRating;
      if (_rating != 'Non noté') {
        _sovereignOceEstablished = null;
        _sovereignOceNote = '';
      } else if (!wasUnrated) {
        _sovereignOceEstablished = null;
        _sovereignOceNote = '';
      }
    });
  }

  Widget _buildCategoryStepBody(BuildContext context) {
    final cards = <Widget>[
      _StepGridFullWidth(
        child: _buildFieldCard(
          context: context,
          title: 'Catégorie d\'exposition',
          subtitle: '',
          icon: Icons.account_tree_outlined,
          hideHeader: true,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedValueOrNull(
              _categoryCode,
              exposureCategories
                  .map((item) => item.code)
                  .toList(growable: false),
            ),
            isExpanded: true,
            decoration: _fieldDecoration(
              context,
              hint: context.tr('Choisir une option'),
            ),
            validator: _requiredSelectionValidator,
            selectedItemBuilder: (context) => exposureCategories
                .map(
                  (item) => Align(
                    alignment: Alignment.centerLeft,
                    child: _dropdownLabel(
                      item.prudentialLabel,
                      translate: true,
                    ),
                  ),
                )
                .toList(growable: false),
            items: exposureCategories
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.code,
                    child: _dropdownLabel(
                      item.prudentialLabel,
                      translate: true,
                    ),
                  ),
                )
                .toList(),
            onChanged: _handleCategoryChanged,
          ),
        ),
      ),
    ];

    if (_isPublicBodyCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title: 'Cas UEMOA en FCFA ?',
            subtitle:
                'Organisme public hors administration centrale des Etats de l UEMOA',
            icon: Icons.account_balance_outlined,
            child: DropdownButtonFormField<bool>(
              initialValue: _publicBodyUemoaFcfaCase,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handlePublicBodyUemoaQuestionChanged,
            ),
          ),
        ),
      );
    }

    if (_isPublicBodyCategory && _publicBodyUemoaFcfaCase == true) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title: "L'organisme finance-t-il une activité non publique ?",
            subtitle: '',
            icon: Icons.domain_verification_outlined,
            child: DropdownButtonFormField<bool>(
              initialValue: _publicBodyFinancesNonPublicActivity,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handlePublicBodyNonPublicActivityChanged,
            ),
          ),
        ),
      );
    }

    if (_isSovereignCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                'Cette exposition concerne-t-elle des souverains UEMOA/BCEAO ou leurs démembrements libellés et financés en FCFA, ou des institutions internationales ?',
            subtitle: '',
            icon: Icons.account_balance_outlined,
            child: DropdownButtonFormField<bool>(
              initialValue: _sovereignPriorityQuestionAnsweredYes,
              decoration: _fieldDecoration(context),
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleSovereignPriorityQuestionChanged,
            ),
          ),
        ),
      );
    }

    if (_isBmdCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                'L’exposition concerne-t-elle une BMD répondant aux critères suivants ?',
            subtitle: "Consultez l'icône pour en savoir plus sur les critères.",
            icon: Icons.account_balance_outlined,
            inlineTooltip: _bmdCriteriaTooltip,
            hideLeadingIcon: true,
            subtitleColor: AppTheme.accent,
            child: DropdownButtonFormField<bool>(
              initialValue: _bmdHighQualityCase,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleBmdHighQualityChanged,
            ),
          ),
        ),
      );
    }

    if (_isBmdCategory && _bmdHighQualityCase == false) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                'L’exposition concerne-t-elle une BMD des États de l’UEMOA libellée et financée en FCFA ?',
            subtitle: '',
            icon: Icons.account_balance_outlined,
            child: DropdownButtonFormField<bool>(
              initialValue: _bmdUemoaFcfaCase,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleBmdUemoaQuestionChanged,
            ),
          ),
        ),
      );
    }

    if (_isBmdCategory &&
        _bmdHighQualityCase == false &&
        _bmdUemoaFcfaCase == true) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title: 'La BMD respecte-t-elle les critères c), d) et e) ?',
            subtitle: '',
            icon: Icons.fact_check_outlined,
            inlineTooltip: _bmdCdeCriteriaTooltip,
            child: DropdownButtonFormField<bool>(
              initialValue: _bmdUemoaCriteriaSatisfied,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleBmdUemoaCriteriaChanged,
            ),
          ),
        ),
      );
    }

    if (_shouldShowBmdListedInstitutionQuestion) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                'L’exposition concerne-t-elle l’une des institutions suivantes : BIRD, SFI, BAsD, BAD, BERD, BEI, FEI, BNI, BDC, BIsD, BDCE, AMGI ou BOAD libellée et financée en FCFA ?',
            subtitle: 'Consulter l’icône info pour voir les sigles.',
            icon: Icons.account_balance_outlined,
            inlineTooltip: _bmdInstitutionsTooltip,
            tooltipTitle: 'Sigles',
            child: DropdownButtonFormField<bool>(
              initialValue: _bmdListedInstitutionFcfaCase,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleBmdListedInstitutionChanged,
            ),
          ),
        ),
      );
    }

    if (_isBankInstitutionCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title: "Situation de l'institution bancaire",
            subtitle: 'Choisir le traitement applicable',
            icon: Icons.account_balance_outlined,
            child: DropdownButtonFormField<String>(
              initialValue: _bankInstitutionCase,
              isExpanded: true,
              decoration: _fieldDecoration(context,
                  hint: context.tr('Choisir une option')),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.tr('Champ requis')
                  : null,
              selectedItemBuilder: (context) => bankInstitutionCaseOptions
                  .map(
                    (item) => Align(
                      alignment: Alignment.centerLeft,
                      child: _bankInstitutionCaseDropdownLabel(item),
                    ),
                  )
                  .toList(growable: false),
              items: bankInstitutionCaseOptions
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: _bankInstitutionCaseDropdownLabel(
                        item,
                        includeInfoIcon: true,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _handleBankInstitutionCaseChanged,
            ),
          ),
        ),
      );
    }

    if (_isOtherAssetsCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title: 'Type d’élément d’actif',
            subtitle: '',
            icon: Icons.inventory_2_outlined,
            inlineTooltip:
                'Les autres éléments d’actifs correspondent aux expositions non prises en compte dans les autres catégories prudentielles, hors éléments déjà déduits des fonds propres et hors expositions soumises à des exigences spécifiques.',
            tooltipTitle: 'Définition',
            placeInlineTooltipBeforeTitle: true,
            child: DropdownButtonFormField<String>(
              initialValue: _otherAssetType,
              isExpanded: true,
              decoration: _fieldDecoration(
                context,
                hint: context.tr('Choisir une option'),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.tr('Champ requis')
                  : null,
              selectedItemBuilder: (context) => otherAssetTypeOptions
                  .map(
                    (item) => Align(
                      alignment: Alignment.centerLeft,
                      child: _otherAssetTypeDropdownLabel(item),
                    ),
                  )
                  .toList(growable: false),
              items: otherAssetTypeOptions
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: _otherAssetTypeDropdownLabel(
                        item,
                        includeInfoIcon: true,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _handleOtherAssetTypeChanged,
            ),
          ),
        ),
      );
    }

    if (_isRetailCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                'L’exposition respecte-t-elle les critères de classement en clientèle de détail ?',
            subtitle: 'Consulter l’icône info pour voir les critères.',
            icon: Icons.groups_2_outlined,
            inlineTooltip: _retailCriteriaTooltip(context),
            tooltipTitle: 'Critères',
            child: DropdownButtonFormField<bool>(
              initialValue: _retailEligibilityCriteriaSatisfied,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleRetailEligibilityChanged,
            ),
          ),
        ),
      );
      if (_retailEligibilityCriteriaSatisfied == true) {
        cards.add(
          _StepGridFullWidth(
            child: _InfoBanner(
              icon: Icons.rule_folder_outlined,
              accent: const Color(0xFF2563EB),
              text:
                  '• ${context.tr('En cas de défaut, l’exposition relève de la catégorie des expositions en défaut.')}\n'
                  '• ${context.tr('Les actions, obligations et créances hypothécaires bénéficiant d’un régime spécifique ne relèvent pas de la clientèle de détail.')}',
            ),
          ),
        );
      }
    }

    if (_isResidentialMortgageCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                'L’exposition respecte-t-elle les conditions d’éligibilité des prêts garantis par l’immobilier résidentiel ?',
            subtitle: 'Consulter l’icône info pour voir les critères.',
            icon: Icons.home_work_outlined,
            inlineTooltip: _residentialMortgageCriteriaTooltip,
            tooltipTitle: 'Critères',
            child: DropdownButtonFormField<bool>(
              initialValue: _residentialMortgageEligible,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleResidentialMortgageEligibilityChanged,
            ),
          ),
        ),
      );

      if (_residentialMortgageEligible == false) {
        cards.add(
          const _StepGridFullWidth(
            child: _InfoBanner(
              icon: Icons.swap_horiz_rounded,
              accent: Color(0xFFF59E0B),
              text:
                  'La pondération de 35 % n’est pas appliquée.\nSélectionner une catégorie prudentielle appropriée pour poursuivre.',
            ),
          ),
        );
      }

      cards.add(
        const _StepGridFullWidth(
          child: _InfoBanner(
            icon: Icons.analytics_outlined,
            accent: Color(0xFF2563EB),
            text:
                'La pondération peut être relevée au-delà de 35 % si la qualité du portefeuille global se dégrade selon les seuils BCEAO.',
          ),
        ),
      );
    }

    if (_isCommercialRealEstateCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                'L’exposition respecte-t-elle les conditions d’éligibilité de l’immobilier commercial ?',
            subtitle: 'Consulter l’icône info pour voir les critères.',
            icon: Icons.business_outlined,
            inlineTooltip: _commercialRealEstateCriteriaTooltip,
            tooltipTitle: 'Critères',
            child: DropdownButtonFormField<bool>(
              initialValue: _commercialRealEstateEligible,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleCommercialRealEstateEligibilityChanged,
            ),
          ),
        ),
      );

      if (_commercialRealEstateEligible == false) {
        cards.add(
          const _StepGridFullWidth(
            child: _InfoBanner(
              icon: Icons.apartment_outlined,
              accent: Color(0xFFF59E0B),
              text:
                  'La pondération de 75 % n’est pas appliquée.\nL’exposition est traitée comme une créance sur une entreprise.',
            ),
          ),
        );
      }

      if (_commercialRealEstateEligible == true) {
        cards.add(
          const _StepGridFullWidth(
            child: _InfoBanner(
              icon: Icons.analytics_outlined,
              accent: Color(0xFF2563EB),
              text:
                  'La pondération peut être relevée au-delà de 75 % en cas de dégradation du portefeuille selon les règles applicables.',
            ),
          ),
        );
      }
    }

    if (_isDefaultedExposureCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                'Quelle est la pondération initiale de l’exposition avant défaut ?',
            subtitle: 'Sélectionner le niveau avant défaut',
            icon: Icons.percent_outlined,
            child: DropdownButtonFormField<double>(
              initialValue: _defaultedExposureInitialRiskWeight,
              isExpanded: true,
              decoration: _fieldDecoration(
                context,
                hint: context.tr('Choisir une option'),
              ),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              selectedItemBuilder: (context) =>
                  defaultedExposureInitialRiskWeightOptions
                      .map((item) => Text(_formatPercent(item)))
                      .toList(growable: false),
              items: defaultedExposureInitialRiskWeightOptions
                  .map(
                    (item) => DropdownMenuItem<double>(
                      value: item,
                      child: Text(_formatPercent(item)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _handleDefaultedExposureInitialRiskWeightChanged,
            ),
          ),
        ),
      );
    }

    if (_shouldAskDefaultedResidentialQuestion) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                'L’exposition est-elle un prêt immobilier résidentiel en défaut ?',
            subtitle: '',
            icon: Icons.home_outlined,
            child: DropdownButtonFormField<bool>(
              initialValue: _defaultedExposureResidentialMortgageInDefault,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleDefaultedExposureResidentialMortgageChanged,
            ),
          ),
        ),
      );
    }

    if (_shouldAskDefaultedProvisionLevel) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title: 'Quel est le niveau de provisions constitué sur l’encours ?',
            subtitle: '',
            icon: Icons.inventory_2_outlined,
            child: DropdownButtonFormField<bool>(
              initialValue: _defaultedExposureProvisionAtLeastTwentyPercent,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Provisions < 20 % de l’encours')),
                ),
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Provisions ≥ 20 % de l’encours')),
                ),
              ],
              onChanged: _handleDefaultedExposureProvisionLevelChanged,
            ),
          ),
        ),
      );
    }

    if (_usesDefaultedExposureCarryForward) {
      cards.add(
        const _StepGridFullWidth(
          child: _InfoBanner(
            icon: Icons.sync_alt_outlined,
            accent: Color(0xFF2563EB),
            text:
                'La même pondération que l’exposition avant défaut est conservée.',
          ),
        ),
      );
    }

    if (_isEnterpriseLikeCategory) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title: 'Le portefeuille entreprises dépasse-t-il le seuil BCEAO ?',
            subtitle: 'Deux trimestres consécutifs',
            icon: Icons.insights_outlined,
            inlineTooltip: _enterpriseArticle133Tooltip,
            tooltipTitle: 'Article 133',
            child: DropdownButtonFormField<bool>(
              initialValue: _enterpriseExceedsBceaoDegradationThreshold,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              isExpanded: true,
              decoration: _fieldDecoration(
                context,
                hint: context.tr('Choisir une option'),
              ),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleEnterpriseBceaoDegradationChanged,
            ),
          ),
        ),
      );
    }

    if (_shouldAskEnterprisePrudentialProcedure) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                "L'entreprise fait-elle l'objet d'une procédure prudentielle ?",
            subtitle: 'Vérification réglementaire',
            icon: Icons.policy_outlined,
            inlineTooltip: _enterpriseArticle133Tooltip,
            tooltipTitle: 'Article 133',
            child: DropdownButtonFormField<bool>(
              initialValue: _enterprisePrudentialProcedure,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              isExpanded: true,
              decoration: _fieldDecoration(
                context,
                hint: context.tr('Choisir une option'),
              ),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleEnterprisePrudentialProcedureChanged,
            ),
          ),
        ),
      );
    }

    if (_shouldAskEnterpriseInvestmentFirm) {
      cards.add(
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title:
                "S'agit-il d'une entreprise d'investissement non soumise à la loi bancaire ?",
            subtitle: 'Traitement spécifique',
            icon: Icons.corporate_fare_outlined,
            child: DropdownButtonFormField<bool>(
              initialValue: _enterpriseInvestmentFirmWithoutBankingLaw,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              validator: (value) =>
                  value == null ? context.tr('Champ requis') : null,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(context.tr('Oui')),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(context.tr('Non')),
                ),
              ],
              onChanged: _handleEnterpriseInvestmentFirmChanged,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepGrid(children: cards),
      ],
    );
  }

  Widget _buildInlineStepFooter(BuildContext context) {
    final isFirst = _currentStep == 1;
    final isLast = _currentStep == _stepMetas.length - 1;
    if (isLast) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _submitting || isFirst ? null : _goBack,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8.0),
            backgroundColor: _wizardCardColor(context),
            foregroundColor: _wizardMutedColor(context),
            side: _wizardBorderSide(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_exposureFormRadius),
            ),
          ),
          icon: const Icon(Icons.west_rounded, size: 14),
          label: Text(
            context.tr('Precedent'),
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 10.2,
            ),
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: _submitting ? null : _handlePrimaryAction,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8.0),
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_exposureFormRadius),
            ),
          ),
          icon: _submitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.east_rounded, size: 16),
          label: Text(
            context.tr('Suivant'),
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 10.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final isDark = _isExposureDark(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 3, 4, 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [
                    Color(0xFF13233D),
                    Color(0xFF0F2430),
                  ]
                : const [
                    Color(0xFFF8FBFF),
                    Color(0xFFF2FAF8),
                  ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(_exposureFormRadius),
          border: Border.all(
            color: isDark ? const Color(0x88293B58) : const Color(0x99DCE5F3),
            width: _wizardBorderWidth,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E3A8A),
                    Color(0xFF0F766E),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(_exposureFormRadius),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title.tr(context),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          color: _wizardTitleColor(context),
                          letterSpacing: -0.2,
                        ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    context.tr(
                      "Renseignez la contrepartie, les montants, le traitement CRM et les impacts prudentiels avant d'enregistrer l'exposition.",
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _wizardMutedColor(context),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF182944).withValues(alpha: 0.98)
                    : Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(_exposureFormRadius),
                border: Border.all(
                  color: isDark
                      ? const Color(0x8830435F)
                      : const Color(0x99D7E2F2),
                  width: _wizardBorderWidth,
                ),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: _submitting ? null : widget.onCancel,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: _wizardBodyTitleColor(context),
                ),
                tooltip: context.tr('Fermer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingOverlay(BuildContext context) {
    final isDark = _isExposureDark(context);
    return Positioned.fill(
      child: Container(
        color: (isDark ? Colors.black : Colors.white).withValues(
          alpha: isDark ? 0.36 : 0.46,
        ),
        alignment: Alignment.center,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: _wizardCardColor(context),
            borderRadius: BorderRadius.circular(_exposureFormRadius),
            border: _wizardBoxBorder(context),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.initialDraft == null
                          ? context.tr('Ajout de l exposition en cours...')
                          : context
                              .tr('Mise a jour de l exposition en cours...'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(
                        'Traitement en cours... Cette operation peut prendre quelques secondes.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _wizardMutedColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_KpiData> _buildIntroKpis(
    BuildContext context,
    _ExposurePreview preview,
    String displayCurrency,
  ) {
    final maturityMonths = (_grantDate != null && _maturityDate != null)
        ? _positiveMonthDifference(_grantDate!, _maturityDate!)
        : null;
    final residualMaturityMonths = _maturityDate != null
        ? _positiveMonthDifference(DateTime.now(), _maturityDate!)
        : null;
    final loanTotalAmount = _loanTotalAmountInput ?? 0.0;
    final onBalanceExposureAmount = _onBalanceExposureAmountInput ?? 0.0;
    final offBalanceExposureAmount = _derivedOffBalanceExposureAmount;
    final isOffBalance = _isOffBalanceCategory;
    final hasOffBalanceExposure = offBalanceExposureAmount > 0;
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context);
    final selectedOffBalanceFcec =
        _offBalanceRiskLevel == null || _offBalanceRiskLevel!.trim().isEmpty
            ? null
            : lookupOffBalanceFcec(_offBalanceRiskLevel);
    final counterpartyName = _nameController.text.trim();
    final residenceCountry = displayCountryName(
      _countryController.text.trim(),
      fallback: _countryController.text.trim(),
    );
    final detectedZone = _detectedCountryZone;
    final crmTypeLabel = switch (_crmMode) {
      'CRM financee' => 'Financée',
      'CRM non financee' => 'Non financée',
      _ => !_requiresCrmFlow
          ? 'Non applicable'
          : (_crmExistsAnswer == false ? 'Aucune' : 'À définir'),
    };
    final eadKpi = _KpiData(
      label: context.tr('EAD'),
      value: compactCurrencyForDisplay(
        preview.ead,
        fromCurrency: _currency,
        toCurrency: displayCurrency,
        amountUnit: amountUnit,
      ),
      icon: Icons.account_balance_wallet_outlined,
      accent: AppTheme.accent,
    );
    final rwaKpi = _KpiData(
      label: context.tr('RWA'),
      value: compactCurrencyForDisplay(
        preview.rwa,
        fromCurrency: _currency,
        toCurrency: displayCurrency,
        amountUnit: amountUnit,
      ),
      icon: Icons.analytics_outlined,
      accent: const Color(0xFF2563EB),
      highlighted: true,
      fullSpan: isOffBalance,
    );
    final creditCoverage = (double.tryParse(_coveredAmountController.text
                .replaceAll(' ', '')
                .replaceAll(',', '.')) ??
            0.0)
        .clamp(0.0, double.infinity);

    return [
      _KpiData(
        label: context.tr('Contrepartie'),
        value: counterpartyName.isEmpty ? '-' : counterpartyName,
        icon: Icons.business_outlined,
        accent: const Color(0xFF2563EB),
      ),
      _KpiData(
        label: context.tr('Pays de residence'),
        value: residenceCountry.isEmpty ? '-' : residenceCountry,
        icon: Icons.flag_circle_outlined,
        accent: const Color(0xFF0891B2),
      ),
      _KpiData(
        label: context.tr('Zone'),
        value: detectedZone,
        icon: Icons.travel_explore_outlined,
        accent: _zoneAccentColor(detectedZone),
      ),
      _KpiData(
        label: context.tr('Type de CRM'),
        value: crmTypeLabel,
        icon: Icons.handshake_outlined,
        accent: const Color(0xFF0F766E),
      ),
      _KpiData(
        label: context.tr('Maturité'),
        value: _formatMonthCount(maturityMonths),
        icon: Icons.date_range_outlined,
        accent: const Color(0xFF6366F1),
      ),
      _KpiData(
        label: context.tr('Maturité résiduelle'),
        value: _formatMonthCount(residualMaturityMonths),
        icon: Icons.timelapse_rounded,
        accent: const Color(0xFF7C3AED),
      ),
      _KpiData(
        label: context.tr('Montant d\'exposition'),
        value: compactCurrencyForDisplay(
          loanTotalAmount,
          fromCurrency: _currency,
          toCurrency: displayCurrency,
          amountUnit: amountUnit,
        ),
        icon: Icons.payments_outlined,
        accent: const Color(0xFF0284C7),
      ),
      _KpiData(
        label: context.tr('Montant d\'exposition au bilan'),
        value: compactCurrencyForDisplay(
          onBalanceExposureAmount,
          fromCurrency: _currency,
          toCurrency: displayCurrency,
          amountUnit: amountUnit,
        ),
        icon: Icons.account_balance_wallet_outlined,
        accent: const Color(0xFF0F766E),
      ),
      _KpiData(
        label: context.tr('Montant d\'exposition hors bilan'),
        value: compactCurrencyForDisplay(
          offBalanceExposureAmount,
          fromCurrency: _currency,
          toCurrency: displayCurrency,
          amountUnit: amountUnit,
        ),
        icon: Icons.calculate_outlined,
        accent: const Color(0xFF1D4ED8),
      ),
      if (_crmMode != 'CRM non financee') eadKpi,
      if (hasOffBalanceExposure)
        _KpiData(
          label: context.tr('Niveau de risque hors bilan'),
          value: _offBalanceRiskLevel ?? '-',
          icon: Icons.warning_amber_rounded,
          accent: const Color(0xFFDC2626),
        ),
      _KpiData(
        label: isOffBalance
            ? context.tr('FCEC')
            : context.tr('Pondération de la contrepartie (RW)'),
        value: _formatPercent(preview.finalRw),
        icon: isOffBalance ? Icons.rule_folder_outlined : Icons.tune_rounded,
        accent:
            isOffBalance ? const Color(0xFF2563EB) : const Color(0xFFF59E0B),
      ),
      if (!isOffBalance && hasOffBalanceExposure)
        _KpiData(
          label: context.tr('FCEC'),
          value: selectedOffBalanceFcec == null
              ? '-'
              : _formatPercent(selectedOffBalanceFcec),
          icon: Icons.rule_folder_outlined,
          accent: const Color(0xFF2563EB),
        ),
      if (_crmMode != 'CRM non financee') rwaKpi,
      if (_crmMode == 'CRM non financee') ...[
        _KpiData(
          label: context.tr('% Couverture'),
          value: _formatPercent(preview.ead > 0
              ? (creditCoverage / preview.ead).clamp(0.0, 1.0)
              : 0.0),
          icon: Icons.pie_chart_outline_rounded,
          accent: const Color(0xFF0891B2),
        ),
        _KpiData(
          label: context.tr('Part non couverte'),
          value: compactCurrencyForDisplay(
            (preview.ead - creditCoverage).clamp(0.0, double.infinity),
            fromCurrency: _currency,
            toCurrency: displayCurrency,
            amountUnit: amountUnit,
          ),
          icon: Icons.remove_circle_outline_rounded,
          accent: const Color(0xFFDC2626),
        ),
        eadKpi,
        rwaKpi,
      ],
    ];
  }

  Widget _buildCrmDynamicBody(BuildContext context) {
    if (_isOffBalanceCategory) {
      return const SizedBox.shrink();
    }

    if (_crmMode == 'Aucune') {
      return _InfoBanner(
        icon: Icons.info_outline,
        accent: const Color(0xFF64748B),
        text: context.tr(
          'Aucune attenuation selectionnee. Le RW final reste aligne sur le RW brut.',
        ),
      );
    }

    if (_crmMode == 'CRM financee') {
      return _buildFinancedCrmBody(context);
    }

    return _StepGrid(
      children: [
        _buildFieldCard(
          context: context,
          title: 'Type de garantie',
          subtitle: 'Garantie ou assurance',
          icon: Icons.workspace_premium_outlined,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedValueOrNull(_crmType, _nonFinancedCrmTypes),
            isExpanded: true,
            decoration: _fieldDecoration(
              context,
              hint: context.tr('Choisir une option'),
            ),
            validator: _crmMode == 'CRM non financee'
                ? _requiredSelectionValidator
                : null,
            selectedItemBuilder: (context) => _selectedStringDropdownItems(
              _nonFinancedCrmTypes,
              translate: true,
            ),
            items: _stringDropdownItems(
              _nonFinancedCrmTypes,
              translate: true,
            ),
            onChanged: (value) => setState(() => _crmType = value ?? ''),
          ),
        ),
        _buildFieldCard(
          context: context,
          title: 'Nom du garant',
          subtitle: 'Entite couvrante',
          icon: Icons.person_outline_rounded,
          child: TextFormField(
            controller: _guarantorNameController,
            decoration: _fieldDecoration(
              context,
              hint: context.tr('Nom du garant'),
            ),
            validator:
                _crmMode == 'CRM non financee' ? _requiredValidator : null,
          ),
        ),
        _buildFieldCard(
          context: context,
          title: 'Categorie du garant',
          subtitle: 'Profil prudentiel',
          icon: Icons.apartment_outlined,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedValueOrNull(
              _guarantorCategoryCode,
              guarantorEligibleCategoryCodes,
            ),
            isExpanded: true,
            decoration: _fieldDecoration(
              context,
              hint: context.tr('Choisir une option'),
            ),
            validator: _crmMode == 'CRM non financee'
                ? _requiredSelectionValidator
                : null,
            selectedItemBuilder: (context) => guarantorEligibleCategories
                .map(
                  (item) => Align(
                    alignment: Alignment.centerLeft,
                    child: _dropdownLabel(
                      item.prudentialLabel,
                      translate: true,
                    ),
                  ),
                )
                .toList(growable: false),
            items: guarantorEligibleCategories
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.code,
                    child: _dropdownLabel(
                      item.prudentialLabel,
                      translate: true,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(
              () => _guarantorCategoryCode = value ?? '',
            ),
          ),
        ),
        _buildFieldCard(
          context: context,
          title: 'Notation du garant',
          subtitle: 'Notation prise en compte',
          icon: Icons.star_border_rounded,
          child: DropdownButtonFormField<String>(
            initialValue:
                _selectedValueOrNull(_guarantorRating, _availableRatings),
            isExpanded: true,
            decoration: _fieldDecoration(
              context,
              hint: context.tr('Choisir une option'),
            ),
            validator: _crmMode == 'CRM non financee'
                ? _requiredSelectionValidator
                : null,
            selectedItemBuilder: (context) =>
                _selectedStringDropdownItems(_availableRatings),
            items: _stringDropdownItems(_availableRatings),
            onChanged: (value) =>
                setState(() => _guarantorRating = value ?? ''),
          ),
        ),
        _buildFieldCard(
          context: context,
          title: 'Pays de residence du garant',
          subtitle: '',
          icon: Icons.flag_outlined,
          child: DropdownButtonFormField<String>(
            initialValue: _guarantorCountryController.text.trim().isEmpty
                ? null
                : canonicalCountryName(
                    _guarantorCountryController.text.trim(),
                    fallback: _guarantorCountryController.text.trim(),
                  ),
            isExpanded: true,
            menuMaxHeight: 320,
            decoration: _fieldDecoration(
              context,
              hint: context.tr('Selectionner le pays du garant'),
            ),
            validator: _crmMode == 'CRM non financee'
                ? (value) {
                    final country =
                        (value ?? _guarantorCountryController.text).trim();
                    return country.isEmpty ? context.tr('Champ requis') : null;
                  }
                : null,
            selectedItemBuilder: (context) => _selectedStringDropdownItems(
              _availableGuarantorCountryOptions,
              displayTextBuilder: (item) =>
                  displayCountryName(item, fallback: item),
            ),
            items: _stringDropdownItems(
              _availableGuarantorCountryOptions,
              displayTextBuilder: (item) =>
                  displayCountryName(item, fallback: item),
            ),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _guarantorCountryController.text = value;
              });
            },
          ),
        ),
        _buildFieldCard(
          context: context,
          title: 'Notation du pays du garant',
          subtitle: '',
          icon: Icons.public_outlined,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedValueOrNull(
              _guarantorCountryRating,
              _availableRatings,
            ),
            isExpanded: true,
            decoration: _fieldDecoration(
              context,
              hint: context.tr('Choisir une option'),
            ),
            validator: _crmMode == 'CRM non financee'
                ? _requiredSelectionValidator
                : null,
            selectedItemBuilder: (context) =>
                _selectedStringDropdownItems(_availableRatings),
            items: _stringDropdownItems(_availableRatings),
            onChanged: (value) => setState(
              () => _guarantorCountryRating = value ?? '',
            ),
          ),
        ),
        _buildFieldCard(
          context: context,
          title: 'Part couverte',
          subtitle: '',
          icon: Icons.gpp_good_outlined,
          child: TextFormField(
            controller: _coveredAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: _fieldDecoration(
              context,
              hint: context.tr('Montant couvert'),
            ),
            onChanged: (_) => setState(() {}),
            validator:
                _crmMode == 'CRM non financee' ? _requiredValidator : null,
          ),
        ),
      ],
    );
  }

  Widget _buildFinancedCrmBody(BuildContext context) {
    final displayCurrency = PortfolioCurrencyScope.maybeOf(
      context,
      fallback: _currency,
    );
    final snapshot = _financedCrmSnapshotPreview;
    final isBasket = financedCrmCollateralIsBasket(_collateralType);
    final showIssuerRole = financedCrmCollateralRequiresIssuerRole(
      _collateralType,
    );
    final showRating = financedCrmCollateralRequiresRating(_collateralType);
    final showConvertibleIndexQuestion =
        financedCrmCollateralSupportsConvertibleIndexQuestion(_collateralType);
    final showOpcvmHaircut =
        financedCrmCollateralSupportsOpcvmHaircut(_collateralType);
    final collateralAmount = isBasket
        ? _basketTotalInExposureCurrency
        : (_parseDecimal(_collateralController.text) ?? 0.0);

    final regulatoryFields = <Widget>[
      if (showIssuerRole)
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title: 'Type d’émetteur',
            subtitle: 'Rôle réglementaire',
            icon: Icons.apartment_outlined,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedValueOrNull(
                _issuerType,
                financedCrmIssuerRoleOptions,
              ),
              isExpanded: true,
              decoration: _fieldDecoration(
                context,
                hint: context.tr('Choisir une option'),
              ),
              validator: _requiredSelectionValidator,
              selectedItemBuilder: (context) =>
                  _selectedStringDropdownItems(financedCrmIssuerRoleOptions),
              items: _stringDropdownItems(financedCrmIssuerRoleOptions),
              onChanged: (value) => setState(() => _issuerType = value ?? ''),
            ),
          ),
        ),
      if (showRating)
        _buildFieldCard(
          context: context,
          title: 'Notation de la sûreté',
          subtitle: 'Notation externe',
          icon: Icons.workspace_premium_outlined,
          child: DropdownButtonFormField<String>(
            initialValue:
                _selectedValueOrNull(_issuerRating, financedCrmDebtRatings),
            isExpanded: true,
            decoration: _fieldDecoration(
              context,
              hint: context.tr('Choisir une option'),
            ),
            validator: _requiredSelectionValidator,
            selectedItemBuilder: (context) =>
                _selectedStringDropdownItems(financedCrmDebtRatings),
            items: _stringDropdownItems(financedCrmDebtRatings),
            onChanged: (value) => setState(() => _issuerRating = value ?? ''),
          ),
        ),
      if (showConvertibleIndexQuestion)
        _StepGridFullWidth(
          child: _buildFieldCard(
            context: context,
            title: 'Indice principal reconnu ?',
            subtitle: 'Obligation convertible',
            icon: Icons.auto_graph_outlined,
            inlineTooltip: _convertibleMainIndexTooltip,
            tooltipTitle: 'Précision',
            child: DropdownButtonFormField<bool>(
              initialValue: _convertibleMainIndex,
              isExpanded: true,
              decoration: _fieldDecoration(context),
              items: const [
                DropdownMenuItem<bool>(value: true, child: Text('Oui')),
                DropdownMenuItem<bool>(value: false, child: Text('Non')),
              ],
              onChanged: (value) => setState(
                () => _convertibleMainIndex = value ?? true,
              ),
            ),
          ),
        ),
      if (showOpcvmHaircut)
        _buildFieldCard(
          context: context,
          title: 'Plus forte décote du fonds',
          subtitle: 'Actif le plus risqué',
          icon: Icons.stacked_bar_chart_outlined,
          child: DropdownButtonFormField<double>(
            initialValue: coerceFinancedCrmOpcvmHaircut(_opcvmHighestHaircut),
            isExpanded: true,
            decoration: _fieldDecoration(context),
            items: financedCrmOpcvmHaircutLevels
                .map(
                  (item) => DropdownMenuItem<double>(
                    value: item,
                    child: Text(formatFinancedCrmHaircutPercent(item)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => setState(
              () => _opcvmHighestHaircut = coerceFinancedCrmOpcvmHaircut(value),
            ),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepGrid(
          children: [
            _StepGridFullWidth(
              child: _buildFieldCard(
                context: context,
                title: 'Sûreté reçue',
                subtitle: 'Caractéristiques métier',
                icon: Icons.security_outlined,
                inlineTooltip: _collateralValueTooltip,
                tooltipTitle: 'Valeur de la sûreté',
                child: _StepGrid(
                  children: [
                    _buildFieldCard(
                      context: context,
                      title: 'Valeur de la sûreté',
                      subtitle: 'Valeur saisie',
                      icon: Icons.account_balance_outlined,
                      child: TextFormField(
                        controller: _collateralController,
                        readOnly: isBasket,
                        decoration: _fieldDecoration(
                          context,
                          hint: context.tr('Valeur de la sûreté'),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        validator: _crmMode == 'CRM financee'
                            ? _amountValidator
                            : null,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    _buildFieldCard(
                      context: context,
                      title: 'Type de sûreté',
                      subtitle: 'Nature du collatéral',
                      icon: Icons.widgets_outlined,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedValueOrNull(
                          _collateralType,
                          financedCrmCollateralTypes,
                        ),
                        isExpanded: true,
                        decoration: _fieldDecoration(
                          context,
                          hint: context.tr('Choisir une option'),
                        ),
                        validator: _crmMode == 'CRM financee'
                            ? _requiredSelectionValidator
                            : null,
                        selectedItemBuilder: (context) =>
                            _selectedStringDropdownItems(
                                financedCrmCollateralTypes),
                        items: _stringDropdownItems(financedCrmCollateralTypes),
                        onChanged: (value) => _setCollateralType(value ?? ''),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isBasket)
              _StepGridFullWidth(
                child: _buildFieldCard(
                  context: context,
                  title: 'Panier d actifs',
                  subtitle: 'Composition pondérée',
                  icon: Icons.inventory_2_outlined,
                  inlineTooltip: _basketTooltip,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var index = 0;
                          index < _basketItems.length;
                          index++) ...[
                        _buildBasketItemEditor(
                            context, index, _basketItems[index]),
                        if (index < _basketItems.length - 1)
                          const SizedBox(height: 3),
                      ],
                      const SizedBox(height: 3),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _addBasketItem,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Ajouter un actif'),
                        ),
                      ),
                      const SizedBox(height: 3),
                      const _InfoBanner(
                        icon: Icons.info_outline,
                        accent: Color(0xFF0F766E),
                        text:
                            'La devise, la pondération de chaque actif et la contribution au panier sont calculées exposition par exposition.',
                      ),
                    ],
                  ),
                ),
              ),
            if (regulatoryFields.isNotEmpty)
              _StepGridFullWidth(
                child: _buildFieldCard(
                  context: context,
                  title: 'Caractéristiques réglementaires',
                  subtitle: 'Émetteur, notation, durée et éligibilité',
                  icon: Icons.fact_check_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_StepGrid(children: regulatoryFields)],
                  ),
                ),
              ),
            _StepGridFullWidth(
              child: _buildFieldCard(
                context: context,
                title: 'Décotes',
                subtitle: 'He, Hc et Hfx calculées',
                icon: Icons.percent_rounded,
                inlineTooltip: _automaticHaircutsTooltip,
                tooltipTitle: 'He, Hc et Hfx',
                tooltipMaxWidth: 280,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildReadonlyMetricCard(
                        context: context,
                        label: 'He',
                        value: _formatPercent(snapshot.he),
                        icon: Icons.percent_rounded,
                        accent: const Color(0xFF2563EB),
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildReadonlyMetricCard(
                        context: context,
                        label: 'Hc',
                        value: _formatPercent(snapshot.hc),
                        icon: Icons.shield_moon_outlined,
                        accent: const Color(0xFFF59E0B),
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildReadonlyMetricCard(
                        context: context,
                        label: 'Hfx',
                        value: _formatPercent(snapshot.hfx),
                        icon: Icons.currency_exchange_outlined,
                        accent: const Color(0xFF0F766E),
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _StepGridFullWidth(
              child: _buildFieldCard(
                context: context,
                title: 'Calcul CRM financée',
                icon: Icons.calculate_outlined,
                inlineTooltip: _financedCrmCalculationTooltip,
                tooltipTitle: 'Calcul CRM financée',
                tooltipMaxWidth: 320,
                child: _AdaptiveMetricGrid(
                  children: [
                    _buildReadonlyMetricCard(
                      context: context,
                      label: 'Eva',
                      value: _formatReadonlyAmount(
                        snapshot.eva,
                        sourceCurrency: _currency,
                        targetCurrency: displayCurrency,
                      ),
                      icon: Icons.exposure_plus_1_outlined,
                      accent: const Color(0xFF2563EB),
                      compact: true,
                    ),
                    _buildReadonlyMetricCard(
                      context: context,
                      label: 'Cva',
                      value: _formatReadonlyAmount(
                        snapshot.cva,
                        sourceCurrency: _currency,
                        targetCurrency: displayCurrency,
                      ),
                      icon: Icons.savings_outlined,
                      accent: const Color(0xFF0F766E),
                      compact: true,
                    ),
                    _buildReadonlyMetricCard(
                      context: context,
                      label: 'EAD après CRM financée',
                      value: _formatReadonlyAmount(
                        snapshot.eadAfterFinancedCrm,
                        sourceCurrency: _currency,
                        targetCurrency: displayCurrency,
                      ),
                      icon: Icons.account_balance_wallet_outlined,
                      accent: const Color(0xFF7C3AED),
                      compact: true,
                    ),
                    _buildReadonlyMetricCard(
                      context: context,
                      label: 'RWA final',
                      value: _formatReadonlyAmount(
                        snapshot.rwaFinal,
                        sourceCurrency: _currency,
                        targetCurrency: displayCurrency,
                      ),
                      icon: Icons.analytics_outlined,
                      accent: const Color(0xFFF59E0B),
                      compact: true,
                    ),
                    _buildReadonlyMetricCard(
                      context: context,
                      label: 'Gain CRM',
                      value: _formatReadonlyAmount(
                        snapshot.crmGain,
                        sourceCurrency: _currency,
                        targetCurrency: displayCurrency,
                      ),
                      icon: Icons.trending_down_outlined,
                      accent: const Color(0xFF16A34A),
                      compact: true,
                    ),
                    _buildReadonlyMetricCard(
                      context: context,
                      label: 'Valeur de la sûreté',
                      value: _formatReadonlyAmount(
                        collateralAmount,
                        sourceCurrency:
                            isBasket ? _currency : _collateralCurrency,
                        targetCurrency: displayCurrency,
                      ),
                      icon: Icons.account_balance_outlined,
                      accent: const Color(0xFF0891B2),
                      compact: true,
                    ),
                  ],
                ),
              ),
            ),
            if (!snapshot.collateralEligible)
              _StepGridFullWidth(
                child: _InfoBanner(
                  icon: Icons.info_outline,
                  accent: const Color(0xFFDC2626),
                  text: snapshot.eligibilityReason.isEmpty
                      ? 'Cette sûreté n est pas éligible à la réduction réglementaire de l exposition. L exposition reste donc inchangée.'
                      : snapshot.eligibilityReason,
                ),
              )
            else if (snapshot.eadAfterFinancedCrm == 0)
              const _StepGridFullWidth(
                child: _InfoBanner(
                  icon: Icons.task_alt_outlined,
                  accent: Color(0xFF16A34A),
                  text:
                      'La sûreté ajustée couvre entièrement l exposition ajustée.',
                ),
              )
            else if (snapshot.cva > 0)
              const _StepGridFullWidth(
                child: _InfoBanner(
                  icon: Icons.pie_chart_outline_rounded,
                  accent: Color(0xFF0F766E),
                  text: "La sûreté couvre partiellement l'exposition.",
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildReadonlyMetricCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
    String? tooltip,
    bool compact = false,
  }) {
    final isDark = _isExposureDark(context);
    final cardPadding = compact ? 8.0 : 12.0;
    final valueGap = compact ? 1.0 : 4.0;
    final labelFontSize = compact ? 10.5 : null;
    final valueFontSize = compact ? 10.5 : null;
    final labelMaxLines = compact ? 2 : 1;
    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14233D) : Colors.white,
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        border: _wizardBoxBorder(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _wizardMutedColor(context),
                              fontWeight: FontWeight.w500,
                              fontSize: labelFontSize,
                              height: compact ? 1.12 : null,
                            ),
                        maxLines: labelMaxLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (tooltip != null && tooltip.isNotEmpty)
                      _buildInlineInfoButton(
                        context,
                        tooltip,
                        compact: compact,
                      ),
                  ],
                ),
                SizedBox(height: valueGap),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _wizardBodyTitleColor(context),
                        fontWeight: FontWeight.w500,
                        fontSize: valueFontSize,
                        height: compact ? 1.05 : null,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineInfoButton(
    BuildContext context,
    String message, {
    bool compact = false,
  }) {
    return Tooltip(
      message: message,
      preferBelow: false,
      textAlign: TextAlign.start,
      padding: const EdgeInsets.fromLTRB(5, 8, 3, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF172544),
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        border: Border.all(color: const Color(0xFF2F4D7F)),
      ),
      textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white,
            height: 1.4,
          ),
      child: Padding(
        padding: EdgeInsets.only(left: compact ? 4 : 6),
        child: Icon(
          Icons.info_outline,
          size: compact ? 13 : 15,
          color: const Color(0xFF3B82F6),
        ),
      ),
    );
  }

  Widget _buildBasketItemEditor(
    BuildContext context,
    int index,
    FinancedCrmBasketItem item,
  ) {
    final isDark = _isExposureDark(context);
    final showIssuerRole =
        financedCrmCollateralRequiresIssuerRole(item.collateralType);
    final showRating = financedCrmCollateralRequiresRating(item.collateralType);
    final showConvertibleIndexQuestion =
        financedCrmCollateralSupportsConvertibleIndexQuestion(
      item.collateralType,
    );
    final showOpcvmHaircut = financedCrmCollateralSupportsOpcvmHaircut(
      item.collateralType,
    );
    final basketItemValueInExposureCurrency = _convertBasketItemAmount(
      item,
      toCurrency: _currency,
    );
    final basketWeight = _basketTotalInExposureCurrency <= 0
        ? 0.0
        : (basketItemValueInExposureCurrency / _basketTotalInExposureCurrency)
            .clamp(0.0, 1.0)
            .toDouble();
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14233D) : Colors.white,
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        border: _wizardBoxBorder(context),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Actif ${index + 1}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              IconButton(
                onPressed: _basketItems.length <= 1
                    ? null
                    : () => _removeBasketItem(index),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _StepGrid(
            children: [
              _buildFieldCard(
                context: context,
                title: 'Type d actif',
                subtitle: '',
                icon: Icons.widgets_outlined,
                child: DropdownButtonFormField<String>(
                  initialValue:
                      financedCrmCollateralTypes.contains(item.collateralType)
                          ? item.collateralType
                          : financedCrmCollateralTypes.first,
                  isExpanded: true,
                  decoration: _fieldDecoration(context),
                  items: _stringDropdownItems(
                    financedCrmCollateralTypes
                        .where((value) => value != 'Panier d actifs')
                        .toList(growable: false),
                  ),
                  onChanged: (value) => _updateBasketItem(
                    index,
                    FinancedCrmBasketItem(
                      collateralType: value ?? item.collateralType,
                      value: item.value,
                      currency: item.currency,
                      issuerRole: item.issuerRole,
                      rating: item.rating,
                      residualMaturityBucket: item.residualMaturityBucket,
                      convertibleMainIndex: item.convertibleMainIndex,
                      opcvmHighestHaircut: item.opcvmHighestHaircut,
                    ),
                  ),
                ),
              ),
              _buildFieldCard(
                context: context,
                title: 'Valeur',
                subtitle: '',
                icon: Icons.payments_outlined,
                child: TextFormField(
                  initialValue:
                      item.value == 0 ? '' : item.value.toStringAsFixed(0),
                  decoration: _fieldDecoration(context),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onChanged: (value) => _updateBasketItem(
                    index,
                    FinancedCrmBasketItem(
                      collateralType: item.collateralType,
                      value: _parseDecimal(value) ?? 0.0,
                      currency: item.currency,
                      issuerRole: item.issuerRole,
                      rating: item.rating,
                      residualMaturityBucket: item.residualMaturityBucket,
                      convertibleMainIndex: item.convertibleMainIndex,
                      opcvmHighestHaircut: item.opcvmHighestHaircut,
                    ),
                  ),
                ),
              ),
              _buildFieldCard(
                context: context,
                title: 'Devise',
                subtitle: '',
                icon: Icons.currency_exchange_outlined,
                child: DropdownButtonFormField<String>(
                  initialValue: _availableCurrencyOptions.contains(
                    normalizeCurrencyCode(item.currency),
                  )
                      ? normalizeCurrencyCode(item.currency)
                      : _collateralCurrency,
                  isExpanded: true,
                  decoration: _fieldDecoration(context),
                  items: _availableCurrencyOptions
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => _updateBasketItem(
                    index,
                    FinancedCrmBasketItem(
                      collateralType: item.collateralType,
                      value: item.value,
                      currency: value ?? item.currency,
                      issuerRole: item.issuerRole,
                      rating: item.rating,
                      residualMaturityBucket: item.residualMaturityBucket,
                      convertibleMainIndex: item.convertibleMainIndex,
                      opcvmHighestHaircut: item.opcvmHighestHaircut,
                    ),
                  ),
                ),
              ),
              if (showIssuerRole)
                _buildFieldCard(
                  context: context,
                  title: 'Émetteur',
                  subtitle: '',
                  icon: Icons.apartment_outlined,
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        financedCrmIssuerRoleOptions.contains(item.issuerRole)
                            ? item.issuerRole
                            : financedCrmIssuerRoleOptions.last,
                    isExpanded: true,
                    decoration: _fieldDecoration(context),
                    items: _stringDropdownItems(financedCrmIssuerRoleOptions),
                    onChanged: (value) => _updateBasketItem(
                      index,
                      FinancedCrmBasketItem(
                        collateralType: item.collateralType,
                        value: item.value,
                        currency: item.currency,
                        issuerRole: value ?? item.issuerRole,
                        rating: item.rating,
                        residualMaturityBucket: item.residualMaturityBucket,
                        convertibleMainIndex: item.convertibleMainIndex,
                        opcvmHighestHaircut: item.opcvmHighestHaircut,
                      ),
                    ),
                  ),
                ),
              if (showRating)
                _buildFieldCard(
                  context: context,
                  title: 'Notation',
                  subtitle: '',
                  icon: Icons.workspace_premium_outlined,
                  child: DropdownButtonFormField<String>(
                    initialValue: financedCrmDebtRatings.contains(item.rating)
                        ? item.rating
                        : financedCrmDebtRatings.last,
                    isExpanded: true,
                    decoration: _fieldDecoration(context),
                    items: _stringDropdownItems(financedCrmDebtRatings),
                    onChanged: (value) => _updateBasketItem(
                      index,
                      FinancedCrmBasketItem(
                        collateralType: item.collateralType,
                        value: item.value,
                        currency: item.currency,
                        issuerRole: item.issuerRole,
                        rating: value ?? item.rating,
                        residualMaturityBucket: item.residualMaturityBucket,
                        convertibleMainIndex: item.convertibleMainIndex,
                        opcvmHighestHaircut: item.opcvmHighestHaircut,
                      ),
                    ),
                  ),
                ),
              if (showConvertibleIndexQuestion)
                _StepGridFullWidth(
                  child: _buildFieldCard(
                    context: context,
                    title: 'Indice principal reconnu ?',
                    subtitle: '',
                    icon: Icons.auto_graph_outlined,
                    inlineTooltip: _convertibleMainIndexTooltip,
                    tooltipTitle: 'Précision',
                    child: DropdownButtonFormField<bool>(
                      initialValue: item.convertibleMainIndex,
                      isExpanded: true,
                      decoration: _fieldDecoration(context),
                      items: const [
                        DropdownMenuItem<bool>(value: true, child: Text('Oui')),
                        DropdownMenuItem<bool>(
                          value: false,
                          child: Text('Non'),
                        ),
                      ],
                      onChanged: (value) => _updateBasketItem(
                        index,
                        FinancedCrmBasketItem(
                          collateralType: item.collateralType,
                          value: item.value,
                          currency: item.currency,
                          issuerRole: item.issuerRole,
                          rating: item.rating,
                          residualMaturityBucket: item.residualMaturityBucket,
                          convertibleMainIndex:
                              value ?? item.convertibleMainIndex,
                          opcvmHighestHaircut: item.opcvmHighestHaircut,
                        ),
                      ),
                    ),
                  ),
                ),
              if (showOpcvmHaircut)
                _buildFieldCard(
                  context: context,
                  title: 'Plus forte décote du fonds',
                  subtitle: '',
                  icon: Icons.stacked_bar_chart_outlined,
                  child: DropdownButtonFormField<double>(
                    initialValue: coerceFinancedCrmOpcvmHaircut(
                      item.opcvmHighestHaircut,
                    ),
                    isExpanded: true,
                    decoration: _fieldDecoration(context),
                    items: financedCrmOpcvmHaircutLevels
                        .map(
                          (value) => DropdownMenuItem<double>(
                            value: value,
                            child: Text(
                              formatFinancedCrmHaircutPercent(value),
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) => _updateBasketItem(
                      index,
                      FinancedCrmBasketItem(
                        collateralType: item.collateralType,
                        value: item.value,
                        currency: item.currency,
                        issuerRole: item.issuerRole,
                        rating: item.rating,
                        residualMaturityBucket: item.residualMaturityBucket,
                        convertibleMainIndex: item.convertibleMainIndex,
                        opcvmHighestHaircut:
                            coerceFinancedCrmOpcvmHaircut(value),
                      ),
                    ),
                  ),
                ),
              _buildReadonlyMetricCard(
                context: context,
                label: 'Poids dans le panier',
                value: _formatPercent(basketWeight),
                icon: Icons.pie_chart_outline_rounded,
                accent: const Color(0xFF0F766E),
                tooltip: _basketTooltip,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldCard({
    required BuildContext context,
    required String title,
    String subtitle = '',
    required IconData icon,
    String? inlineTooltip,
    bool placeInlineTooltipBeforeTitle = false,
    bool hideLeadingIcon = false,
    String? iconTooltip,
    String tooltipTitle = 'Critères',
    double tooltipMaxWidth = 350,
    Color? subtitleColor,
    bool hideHeader = false,
    required Widget child,
  }) {
    final compactTextStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 11.6,
          fontWeight: FontWeight.w500,
          color: _wizardBodyTitleColor(context),
        );

    return _CompactFieldCard(
      title: title.tr(context),
      subtitle: subtitle.tr(context),
      icon: icon,
      inlineTooltip: inlineTooltip?.tr(context),
      placeInlineTooltipBeforeTitle: placeInlineTooltipBeforeTitle,
      hideLeadingIcon: true,
      iconTooltip: iconTooltip?.tr(context),
      tooltipTitle: tooltipTitle.tr(context),
      tooltipMaxWidth: tooltipMaxWidth,
      subtitleColor: subtitleColor,
      hideHeader: hideHeader,
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.copyWith(
                titleMedium: compactTextStyle,
                bodyLarge: compactTextStyle,
                bodyMedium: compactTextStyle,
              ),
        ),
        child: child,
      ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    String? hint,
    Widget? suffixIcon,
    String? errorText,
  }) {
    final restingBorderColor = _isExposureDark(context)
        ? const Color(0x88334862)
        : const Color(0x99D6E1EF);
    final disabledBorderColor = _isExposureDark(context)
        ? const Color(0x702A3C55)
        : const Color(0x8AE3EAF4);

    return InputDecoration(
      hintText: hint,
      errorText: errorText,
      isDense: true,
      filled: true,
      fillColor: _wizardInputFillColor(context),
      suffixIcon: suffixIcon,
      hintStyle: TextStyle(
        fontSize: 11.0,
        fontWeight: FontWeight.w500,
        color: _wizardMutedColor(context),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        borderSide: _wizardBorderSide(
          context,
          color: restingBorderColor,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        borderSide: _wizardBorderSide(
          context,
          color: restingBorderColor,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        borderSide: _wizardBorderSide(
          context,
          color: disabledBorderColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        borderSide: const BorderSide(color: AppTheme.accent, width: 1.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        borderSide: const BorderSide(color: AppTheme.danger, width: 0.9),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        borderSide: const BorderSide(color: AppTheme.danger, width: 1.0),
      ),
    );
  }

  Future<void> _handlePrimaryAction() async {
    if (_submitting) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (!_validateCurrentStep()) {
      return;
    }
    if (_currentStep == 3 && !_requiresCrmFlow) {
      await _goToStep(6);
      unawaited(_refreshBackendPreview());
      return;
    }
    if (_currentStep == 3 && _requiresCrmFlow) {
      await _goToStep(4);
      return;
    }
    if (_currentStep == 4 && _crmExistsAnswer == false) {
      await _goToStep(6);
      unawaited(_refreshBackendPreview());
      return;
    }
    if (_currentStep == 4 && _crmExistsAnswer == true) {
      setState(() {
        _crmSelectionStage = true;
      });
      await _goToStep(5);
      return;
    }
    if (_currentStep == 5 && _crmSelectionStage) {
      setState(() {
        _crmSelectionStage = false;
        _resetRightPanelStickyState();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_rightPanelScrollController.hasClients) {
          return;
        }
        _rightPanelScrollController.jumpTo(0);
      });
      return;
    }
    if (_currentStep == 5 && !_crmSelectionStage) {
      await _goToStep(6);
      unawaited(_refreshBackendPreview());
      return;
    }
    if (_currentStep == _stepMetas.length - 1) {
      await _submit();
      return;
    }
    await _goToStep(_currentStep + 1);
  }

  Future<void> _goBack() async {
    if (_currentStep <= 1) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (_currentStep == 5 && !_crmSelectionStage) {
      setState(() {
        _crmSelectionStage = true;
        _resetRightPanelStickyState();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_rightPanelScrollController.hasClients) {
          return;
        }
        _rightPanelScrollController.jumpTo(0);
      });
      return;
    }
    if (_currentStep == 6 && _requiresCrmFlow && _crmExistsAnswer == true) {
      setState(() {
        _crmSelectionStage = false;
      });
      await _goToStep(5);
      return;
    }
    if (_currentStep == 6 && _requiresCrmFlow && _crmExistsAnswer == false) {
      await _goToStep(4);
      return;
    }
    final previousStep =
        (_currentStep == 6 && !_requiresCrmFlow) ? 3 : _currentStep - 1;
    await _goToStep(previousStep);
  }

  Future<void> _goToStep(int target) async {
    var boundedTarget = target.clamp(1, _stepMetas.length - 1);
    if (!_requiresCrmFlow && (boundedTarget == 4 || boundedTarget == 5)) {
      boundedTarget = 6;
    }
    if (_crmExistsAnswer == false && boundedTarget == 5) {
      boundedTarget = 6;
    }
    if (_currentStep == boundedTarget) {
      return;
    }
    setState(() {
      _currentStep = boundedTarget;
      _resetRightPanelStickyState();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_rightPanelScrollController.hasClients) {
        return;
      }
      _rightPanelScrollController.jumpTo(0);
    });
  }

  bool _handleRightPanelScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    var nextDirection = _rightPanelScrollDirection;
    if (notification is UserScrollNotification) {
      nextDirection = notification.direction;
    }

    final offset = notification.metrics.pixels;
    final nextShowSticky = offset > 12;
    final nextExpandSticky = nextShowSticky &&
        (offset <= 64 || nextDirection == ScrollDirection.forward);

    if (nextShowSticky != _showStickyStepHeader ||
        nextExpandSticky != _expandStickyStepHeader ||
        nextDirection != _rightPanelScrollDirection) {
      _pendingShowStickyStepHeader = nextShowSticky;
      _pendingExpandStickyStepHeader = nextExpandSticky;
      _pendingRightPanelScrollDirection = nextDirection;
      if (!_rightPanelScrollSyncScheduled) {
        _rightPanelScrollSyncScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _rightPanelScrollSyncScheduled = false;
          if (!mounted) {
            return;
          }
          final resolvedShowSticky =
              _pendingShowStickyStepHeader ?? _showStickyStepHeader;
          final resolvedExpandSticky =
              _pendingExpandStickyStepHeader ?? _expandStickyStepHeader;
          final resolvedDirection =
              _pendingRightPanelScrollDirection ?? _rightPanelScrollDirection;
          _pendingShowStickyStepHeader = null;
          _pendingExpandStickyStepHeader = null;
          _pendingRightPanelScrollDirection = null;
          if (resolvedShowSticky != _showStickyStepHeader ||
              resolvedExpandSticky != _expandStickyStepHeader ||
              resolvedDirection != _rightPanelScrollDirection) {
            setState(() {
              _showStickyStepHeader = resolvedShowSticky;
              _expandStickyStepHeader = resolvedExpandSticky;
              _rightPanelScrollDirection = resolvedDirection;
            });
          }
        });
      }
    }
    return false;
  }

  void _resetRightPanelStickyState() {
    _showStickyStepHeader = false;
    _expandStickyStepHeader = false;
    _rightPanelScrollDirection = ScrollDirection.idle;
    _pendingShowStickyStepHeader = null;
    _pendingExpandStickyStepHeader = null;
    _pendingRightPanelScrollDirection = null;
  }

  bool get _requiresCrmFlow => !_isOffBalanceCategory;

  bool get _hasAnsweredCrmExistsQuestion => _crmExistsAnswer != null;

  bool get _hasSelectedCrmMode =>
      _crmMode == 'CRM financee' || _crmMode == 'CRM non financee';

  void _setCrmExistsAnswer(bool exists) {
    setState(() {
      _crmExistsAnswer = exists;
      if (!exists) {
        _crmMode = 'Aucune';
        _crmSelectionStage = true;
      }
    });
  }

  Color _currentStepAccent() {
    switch (_currentStep) {
      case 1:
        return AppTheme.accent;
      case 2:
        return const Color(0xFF2563EB);
      case 3:
        return const Color(0xFF0F766E);
      case 4:
        return const Color(0xFF2563EB);
      case 5:
        return const Color(0xFF0891B2);
      case 6:
        return const Color(0xFFF59E0B);
      case 7:
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF7C3AED);
    }
  }

  Widget _buildStickyStepHeader(BuildContext context) {
    final meta = _stepMetas[_currentStep];
    final accent = _currentStepAccent();
    final isExpanded = _expandStickyStepHeader;
    final isDark = _isExposureDark(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 10,
        vertical: isExpanded ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: _wizardCardColor(context),
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x22000000) : const Color(0x0A5B6B81),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: isExpanded ? 32 : 24,
            height: isExpanded ? 32 : 24,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(_exposureFormRadius),
            ),
            child: Icon(
              meta.icon,
              color: accent,
              size: isExpanded ? 17 : 14,
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                meta.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: _wizardBodyTitleColor(context),
                      fontSize: 12.2,
                      height: 1.0,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _resetDraftValues() {
    final draft = widget.initialDraft;
    final isBlankDraft = _isBlankInitialDraft(draft);
    setState(() {
      _backendPreviewRequestId += 1;
      _backendPreview = null;
      _nameController.text = draft?.counterpartyName ?? '';
      _generatedExposureId = isBlankDraft ? draft?.id : null;
      _exposureIdController.text = isBlankDraft ? '' : (draft?.id ?? '');
      _countryController.text = draft?.country ?? '';
      _countryRating = _initialSelectedValue(
        draft?.countryRating,
        options: _availableRatings,
      );
      _grantDate = draft?.grantDate;
      _maturityDate = draft?.maturityDate;
      _syncDateController(_grantDateController, _grantDate);
      _syncDateController(_maturityDateController, _maturityDate);
      _amountController.text =
          draft?.loanTotalAmount == null || draft!.loanTotalAmount <= 0
              ? ''
              : draft.loanTotalAmount.toStringAsFixed(0);
      _onBalanceAmountController.text =
          draft?.onBalanceExposureAmount == null ||
                  draft!.onBalanceExposureAmount <= 0
              ? ''
              : draft.onBalanceExposureAmount.toStringAsFixed(0);
      _commentController.text = draft?.comment ?? '';
      _collateralController.text =
          draft?.collateralValue == null || draft!.collateralValue <= 0
              ? ''
              : draft.collateralValue.toStringAsFixed(0);
      _fxHaircutController.text =
          ((draft?.fxHaircut ?? 0) * 100).toStringAsFixed(2);
      _guarantorNameController.text = draft?.guarantorName ?? '';
      _guarantorCountryController.text = draft?.guarantorCountry ?? '';
      _categoryCode =
          exposureCategories.any((item) => item.code == draft?.categoryCode)
              ? draft!.categoryCode
              : '';
      _rating = _initialSelectedValue(
        draft?.rating,
        options: _counterpartyRatingOptionsForCategory(_categoryCode),
      );
      if ((_categoryCode == 'a' ||
              _categoryCode == 'c' ||
              _categoryCode == 'd') &&
          _rating.isNotEmpty &&
          !prudentialRatings.contains(_rating)) {
        _rating = '';
      }
      if (_categoryCode == 'e' && !enterpriseRatingOptions.contains(_rating)) {
        _rating = '';
      }
      _bankInstitutionCase =
          coerceBankInstitutionCase(draft?.bankInstitutionCase);
      _sovereignSpecialCase = coerceSovereignSpecialCase(
        draft?.sovereignSpecialCase,
        fallbackToLegacy: draft?.sovereignPreferentialZeroWeight ?? false,
      );
      _sovereignPreferentialZeroWeight = hasSovereignPriorityZeroWeightCase(
        _sovereignSpecialCase,
        sovereignPreferentialZeroWeight:
            draft?.sovereignPreferentialZeroWeight ?? false,
      );
      _sovereignPriorityQuestionAnsweredYes =
          _sovereignSpecialCase != sovereignNoSpecialCase ||
              _sovereignPreferentialZeroWeight;
      _sovereignOceEstablished = _rating == 'Non noté' && draft != null
          ? (draft.sovereignOceEstablished || draft.sovereignOceNote.isNotEmpty)
          : null;
      _sovereignOceNote = _rating == 'Non noté' &&
              sovereignOceNotes.contains(draft?.sovereignOceNote)
          ? draft!.sovereignOceNote
          : '';
      _publicBodyUemoaFcfaCase = draft?.publicBodyUemoaFcfaCase;
      _publicBodyFinancesNonPublicActivity =
          draft?.publicBodyFinancesNonPublicActivity;
      _bmdHighQualityCase = draft?.bmdHighQualityCase;
      _bmdUemoaFcfaCase = draft?.bmdUemoaFcfaCase;
      _bmdUemoaCriteriaSatisfied = draft?.bmdUemoaCriteriaSatisfied;
      _bmdListedInstitutionFcfaCase = draft?.bmdListedInstitutionFcfaCase;
      _bankInstitutionCase =
          coerceBankInstitutionCase(draft?.bankInstitutionCase);
      _otherAssetType = coerceOtherAssetType(
        draft?.otherAssetType,
        fallbackToUndefined: _categoryCode == 'k' && draft != null,
      );
      _offBalanceRiskLevel = coerceOffBalanceRiskLevel(
        draft?.offBalanceRiskLevel,
        fallbackToVeryHigh: _shouldAskOffBalanceRiskLevel && draft != null,
      );
      _retailEligibilityCriteriaSatisfied =
          draft?.retailEligibilityCriteriaSatisfied;
      _residentialMortgageEligible = draft?.residentialMortgageEligible;
      _commercialRealEstateEligible = draft?.commercialRealEstateEligible;
      _defaultedExposureInitialRiskWeight =
          draft?.defaultedExposureInitialRiskWeight;
      _defaultedExposureResidentialMortgageInDefault =
          draft?.defaultedExposureResidentialMortgageInDefault;
      _defaultedExposureProvisionAtLeastTwentyPercent =
          draft?.defaultedExposureProvisionAtLeastTwentyPercent;
      _enterpriseExceedsBceaoDegradationThreshold =
          draft?.enterpriseExceedsBceaoDegradationThreshold;
      _enterprisePrudentialProcedure = draft?.enterprisePrudentialProcedure;
      _enterpriseInvestmentFirmWithoutBankingLaw =
          draft?.enterpriseInvestmentFirmWithoutBankingLaw;
      if (_categoryCode != 'b') {
        _publicBodyUemoaFcfaCase = null;
        _publicBodyFinancesNonPublicActivity = null;
      }
      if (_categoryCode != 'c') {
        _bmdHighQualityCase = null;
        _bmdUemoaFcfaCase = null;
        _bmdUemoaCriteriaSatisfied = null;
        _bmdListedInstitutionFcfaCase = null;
      }
      if (_categoryCode != 'd') {
        _bankInstitutionCase = null;
      }
      if (_categoryCode != 'k') {
        _otherAssetType = null;
      }
      if (!_shouldAskOffBalanceRiskLevel) {
        _offBalanceRiskLevel = null;
      }
      if (_categoryCode != 'f') {
        _retailEligibilityCriteriaSatisfied = null;
      }
      if (_categoryCode != 'g') {
        _residentialMortgageEligible = null;
      }
      if (_categoryCode != 'h') {
        _commercialRealEstateEligible = null;
      }
      if (_categoryCode != 'i') {
        _defaultedExposureInitialRiskWeight = null;
        _defaultedExposureResidentialMortgageInDefault = null;
        _defaultedExposureProvisionAtLeastTwentyPercent = null;
      }
      if (!_isEnterpriseLikeCategory) {
        _enterpriseExceedsBceaoDegradationThreshold = null;
        _enterprisePrudentialProcedure = null;
        _enterpriseInvestmentFirmWithoutBankingLaw = null;
      }
      _currency = _initialSelectedValue(
        normalizeCurrencyCode(draft?.currency ?? ''),
        options: _supportedCurrencies,
      );
      _status = draft?.status ?? 'Active';
      _crmMode = draft?.crmMode ?? 'Aucune';
      if (_categoryCode == 'l' && _crmMode != 'Aucune') {
        _crmMode = 'Aucune';
      }
      _crmExistsAnswer = _categoryCode == 'l'
          ? false
          : (isBlankDraft
              ? null
              : (draft == null
                  ? (_crmMode == 'Aucune' ? null : true)
                  : _crmMode != 'Aucune'));
      _crmType = _initialSelectedValue(
        draft?.crmType,
        options: _nonFinancedCrmTypes,
      );
      _collateralType = _initialSelectedValue(
        draft?.collateralType,
        options: financedCrmCollateralTypes,
      );
      _collateralCurrency = _initialSelectedValue(
        normalizeCurrencyCode(draft?.collateralCurrency ?? ''),
        options: _supportedCurrencies,
      );
      _issuerType = _initialSelectedValue(
        draft?.issuerType,
        options: financedCrmIssuerRoleOptions,
      );
      _issuerRating = _initialSelectedValue(
        draft?.issuerRating,
        options: financedCrmDebtRatings,
      );
      _maturityBucket = _initialSelectedValue(
        draft?.maturityBucket,
        options: financedCrmMaturityBuckets,
      );
      _convertibleMainIndex = draft?.convertibleMainIndex ?? true;
      _opcvmHighestHaircut =
          coerceFinancedCrmOpcvmHaircut(draft?.opcvmHighestHaircut);
      _basketItems = draft?.basketItems
              .map(
                (item) => FinancedCrmBasketItem.fromJson(item.toJson()),
              )
              .toList(growable: true) ??
          <FinancedCrmBasketItem>[];
      _guarantorCategoryCode = _initialSelectedValue(
        draft?.guarantorCategoryCode,
        options: guarantorEligibleCategoryCodes,
      );
      _guarantorRating = _initialSelectedValue(
        draft?.guarantorRating,
        options: _availableRatings,
      );
      _guarantorCountryRating = _initialSelectedValue(
        draft?.guarantorCountryRating,
        options: _availableRatings,
      );
      _syncFinancedCollateralCurrencyToExposureIfNeeded();
      _syncBasketCollateralController();
      final resetGrossAmt = draft?.grossAmount ?? 0.0;
      final resetCoveredAmt =
          (draft?.crmCoveragePercent ?? 0.0) * resetGrossAmt;
      _coveredAmountController.text =
          resetCoveredAmt > 0 ? resetCoveredAmt.toStringAsFixed(0) : '';
    });
  }

  bool _validateFinancedCrmInputs() {
    final onBalanceExposureAmount = _onBalanceExposureAmountInput;
    if (onBalanceExposureAmount == null || onBalanceExposureAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Le montant d exposition au bilan doit être strictement positif.',
            ),
          ),
        ),
      );
      return false;
    }

    if (financedCrmCollateralIsBasket(_collateralType)) {
      if (_basketItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Ajouter au moins un actif dans le panier.'),
            ),
          ),
        );
        return false;
      }
      if (_basketItems.any((item) => item.value <= 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Chaque actif du panier doit avoir une valeur strictement positive.',
              ),
            ),
          ),
        );
        return false;
      }
      return true;
    }

    final collateralValue = _parseDecimal(_collateralController.text);
    if (collateralValue == null || collateralValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'La valeur de la sûreté doit être strictement positive.',
            ),
          ),
        ),
      );
      return false;
    }
    return true;
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 1:
        return _primaryFormKey.currentState?.validate() ?? true;
      case 2:
        final isValid = _categoryFormKey.currentState?.validate() ?? true;
        if (!isValid) {
          return false;
        }
        if (_usesBankInstitutionMatrix && !_hasBankInitialMaturityDates) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  'Renseigner les dates d octroi et d echeance pour determiner la matrice bancaire.',
                ),
              ),
            ),
          );
          return false;
        }
        if (_isResidentialMortgageCategory &&
            _residentialMortgageEligible == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  'Cette exposition doit être reclassée dans une autre catégorie prudentielle.',
                ),
              ),
            ),
          );
          return false;
        }
        return true;
      case 3:
        final isValid = _financialFormKey.currentState?.validate() ?? true;
        if (!isValid) {
          return false;
        }
        return _validateFinancialAmounts();
      case 4:
        if (!_hasAnsweredCrmExistsQuestion) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Indiquer si une CRM existe ou non.'),
            ),
          );
          return false;
        }
        return true;
      case 5:
        if (_crmSelectionStage) {
          if (!_hasSelectedCrmMode) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Choisir si la CRM est financée ou non financée.',
                ),
              ),
            );
            return false;
          }
          return true;
        }
        final isValid = _crmFormKey.currentState?.validate() ?? true;
        if (!isValid) {
          return false;
        }
        if (_crmMode == 'CRM financee') {
          return _validateFinancedCrmInputs();
        }
        return true;
      case 6:
        return _commentFormKey.currentState?.validate() ?? true;
      default:
        return true;
    }
  }

  _ExposurePreview _buildPreview() {
    if (_currentStep >= 6 && _backendPreview != null) {
      return _backendPreview!;
    }
    return _buildLocalPreview();
  }

  _ExposurePreview _buildLocalPreview() {
    final loanTotalAmount = _loanTotalAmountInput ?? 0.0;
    final onBalanceExposureAmount = _onBalanceExposureAmountInput ?? 0.0;
    final collateral =
        double.tryParse(_collateralController.text.replaceAll(',', '.')) ?? 0.0;
    final metrics = computeDraftMetrics(
      _draftFromValues(
        loanTotalAmount: loanTotalAmount,
        onBalanceExposureAmount: onBalanceExposureAmount,
        provisionsAmount: _provisionsAmountInput,
        collateralValue: collateral,
        fxHaircut: 0.0,
        comment: _commentController.text,
      ),
    );
    return _ExposurePreview(
      ead: metrics.ead,
      finalRw: metrics.finalRw,
      rwa: metrics.rwa,
    );
  }

  ExposureDraft? _buildCurrentDraftOrNull() {
    final loanTotalAmount = _loanTotalAmountInput;
    final onBalanceExposureAmount = _onBalanceExposureAmountInput;
    final collateralValue = _crmMode == 'CRM financee'
        ? (_parseDecimal(_collateralController.text) ??
            _basketTotalInExposureCurrency)
        : 0.0;
    if (loanTotalAmount == null || onBalanceExposureAmount == null) {
      return null;
    }
    return _draftFromValues(
      loanTotalAmount: loanTotalAmount,
      onBalanceExposureAmount: onBalanceExposureAmount,
      provisionsAmount: _provisionsAmountInput,
      collateralValue: collateralValue,
      fxHaircut: 0.0,
      comment: _commentController.text.trim(),
    );
  }

  Future<void> _refreshBackendPreview() async {
    final draft = _buildCurrentDraftOrNull();
    if (draft == null) {
      return;
    }
    final requestId = ++_backendPreviewRequestId;
    if (mounted) {
      setState(() => _backendPreview = null);
    }
    try {
      final preview = await widget.api.previewExposure(draft);
      if (!mounted || requestId != _backendPreviewRequestId) {
        return;
      }
      setState(() {
        _backendPreview = _ExposurePreview(
          ead: preview.ead,
          finalRw: preview.finalRw,
          rwa: preview.rwa,
        );
      });
    } catch (_) {
      if (!mounted || requestId != _backendPreviewRequestId) {
        return;
      }
      setState(() => _backendPreview = null);
    }
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    final loanTotalAmount = _loanTotalAmountInput;
    final onBalanceExposureAmount = _onBalanceExposureAmountInput;
    final collateralValue = _crmMode == 'CRM financee'
        ? _parseDecimal(_collateralController.text)
        : 0.0;
    if (loanTotalAmount == null ||
        onBalanceExposureAmount == null ||
        collateralValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Verifier les montants saisis.'))),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final draft = _draftFromValues(
        loanTotalAmount: loanTotalAmount,
        onBalanceExposureAmount: onBalanceExposureAmount,
        provisionsAmount: _provisionsAmountInput,
        collateralValue: collateralValue,
        fxHaircut: 0.0,
        comment: _commentController.text.trim(),
      );
      await widget.onSubmit(draft);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Echec de l enregistrement: {{error}}',
              args: {'error': error},
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String? _requiredValidator(String? value) {
    return (value == null || value.trim().isEmpty)
        ? context.tr('Champ requis')
        : null;
  }

  String? _requiredSelectionValidator<T>(T? value) {
    if (value == null) {
      return context.tr('Champ requis');
    }
    if (value is String && value.trim().isEmpty) {
      return context.tr('Champ requis');
    }
    return null;
  }

  String? _amountValidator(String? value) {
    final parsed = _parseDecimal(value);
    if (parsed == null) {
      return context.tr('Montant invalide');
    }
    return parsed <= 0 ? context.tr('Montant positif requis') : null;
  }

  String? _onBalanceAmountValidator(String? value) {
    final parsed = _parseDecimal(value);
    if (parsed == null) {
      return context.tr('Montant invalide');
    }
    if (parsed < 0) {
      return context.tr('Montant positif requis');
    }
    final loanTotalAmount = _loanTotalAmountInput;
    if (loanTotalAmount != null && parsed > loanTotalAmount) {
      return 'Le montant au bilan ne peut pas dépasser le montant total du prêt.';
    }
    return null;
  }

  bool _validateFinancialAmounts() {
    final loanTotalAmount = _loanTotalAmountInput;
    final onBalanceExposureAmount = _onBalanceExposureAmountInput;
    if (loanTotalAmount == null || onBalanceExposureAmount == null) {
      return false;
    }
    if (onBalanceExposureAmount > loanTotalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le montant au bilan ne peut pas dépasser le montant total du prêt.',
          ),
        ),
      );
      return false;
    }
    final effectiveGrossAmount = _resolveEffectiveGrossAmount(
      loanTotalAmount: loanTotalAmount,
      onBalanceExposureAmount: onBalanceExposureAmount,
    );
    if (effectiveGrossAmount <= 0) {
      final message = _isOffBalanceCategory
          ? 'Le montant d\'exposition hors bilan doit être strictement positif.'
          : 'Le montant d\'exposition au bilan doit être strictement positif.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return false;
    }
    return true;
  }

  String _formatDateForField(DateTime? value) {
    if (value == null) {
      return '';
    }
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  int _positiveMonthDifference(DateTime start, DateTime end) {
    var months = (end.year - start.year) * 12 + (end.month - start.month);
    if (end.day < start.day) {
      months -= 1;
    }
    return months < 0 ? 0 : months;
  }

  String _formatMonthCount(int? months) {
    return '${months ?? 0} mois';
  }

  String _resolveFinancedCrmMaturityBucket({String? fallbackBucket}) {
    final fallback = financedCrmMaturityBuckets.contains(fallbackBucket)
        ? fallbackBucket!
        : financedCrmMaturityBuckets.first;
    if (_maturityDate == null) {
      return fallback;
    }

    final residualMonths = _positiveMonthDifference(
      DateTime.now(),
      _maturityDate!,
    );
    if (residualMonths <= 12) {
      return '<=1 an';
    }
    if (residualMonths <= 36) {
      return '1-3 ans';
    }
    if (residualMonths <= 60) {
      return '3-5 ans';
    }
    if (residualMonths <= 120) {
      return '5-10 ans';
    }
    return '>10 ans';
  }

  void _syncDateController(
    TextEditingController controller,
    DateTime? value,
  ) {
    controller.text = _formatDateForField(value);
  }

  Future<void> _pickDate({
    required DateTime? currentValue,
    required ValueChanged<DateTime?> onChanged,
    DateTime? firstDate,
  }) async {
    final minimumDate = firstDate ?? DateTime(2000);
    final today = DateTime.now();
    final initialDate = currentValue == null
        ? (today.isBefore(minimumDate) ? minimumDate : today)
        : (currentValue.isBefore(minimumDate) ? minimumDate : currentValue);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minimumDate,
      lastDate: DateTime(2100),
      helpText: context.tr('Selectionner une date'),
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  double? _parseDecimal(String? raw) {
    if (raw == null) {
      return null;
    }
    final normalized = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  ExposureDraft _draftFromValues({
    required double loanTotalAmount,
    required double onBalanceExposureAmount,
    double? provisionsAmount,
    required double collateralValue,
    required double fxHaircut,
    required String comment,
  }) {
    final trimmedId = _exposureIdController.text.trim();
    final resolvedSovereignSpecialCase = coerceSovereignSpecialCase(
      _sovereignSpecialCase,
      fallbackToLegacy: _sovereignPreferentialZeroWeight,
    );
    final sovereignPreferentialZeroWeight = hasSovereignPriorityZeroWeightCase(
      resolvedSovereignSpecialCase,
      sovereignPreferentialZeroWeight: _sovereignPreferentialZeroWeight,
    );
    final resolvedFinancedCrmMaturityBucket =
        _resolveFinancedCrmMaturityBucket(fallbackBucket: _maturityBucket);
    final grossAmount = _resolveEffectiveGrossAmount(
      loanTotalAmount: loanTotalAmount,
      onBalanceExposureAmount: onBalanceExposureAmount,
    );
    return ExposureDraft(
      id: trimmedId.isEmpty
          ? (_generatedExposureId ?? widget.initialDraft?.id)
          : trimmedId,
      counterpartyName: _nameController.text.trim(),
      country: _countryController.text.trim(),
      countryRating: _countryRating,
      categoryCode: _categoryCode,
      rating: _rating,
      grossAmount: grossAmount,
      loanTotalAmount: loanTotalAmount,
      onBalanceExposureAmount: onBalanceExposureAmount,
      provisionsAmount: provisionsAmount,
      currency: _currency,
      status: _status,
      crmMode: _crmMode,
      crmType: _crmMode == 'CRM non financee' ? _crmType : 'Cash collateral',
      collateralValue: _crmMode == 'CRM financee' ? collateralValue : 0.0,
      collateralCurrency:
          _crmMode == 'CRM financee' ? _collateralCurrency : _currency,
      collateralType: _crmMode == 'CRM financee'
          ? _collateralType
          : financedCrmCollateralTypes.first,
      issuerType: _crmMode == 'CRM financee' ? _issuerType : '',
      issuerRating: _crmMode == 'CRM financee' ? _issuerRating : '',
      maturityBucket: _crmMode == 'CRM financee'
          ? resolvedFinancedCrmMaturityBucket
          : financedCrmMaturityBuckets.first,
      fxHaircut: _crmMode == 'CRM financee' ? fxHaircut : 0.0,
      convertibleMainIndex:
          _crmMode == 'CRM financee' ? _convertibleMainIndex : true,
      opcvmHighestHaircut:
          _crmMode == 'CRM financee' ? _opcvmHighestHaircut : 0.30,
      basketItems: _crmMode == 'CRM financee'
          ? _basketItems
              .map(
                (item) => FinancedCrmBasketItem(
                  collateralType: item.collateralType,
                  value: item.value,
                  currency: item.currency,
                  issuerRole: item.issuerRole,
                  rating: item.rating,
                  residualMaturityBucket: _resolveFinancedCrmMaturityBucket(
                    fallbackBucket: item.residualMaturityBucket,
                  ),
                  convertibleMainIndex: item.convertibleMainIndex,
                  opcvmHighestHaircut: item.opcvmHighestHaircut,
                ),
              )
              .toList(growable: false)
          : const [],
      guarantorName: _crmMode == 'CRM non financee'
          ? _guarantorNameController.text.trim()
          : '',
      guarantorCategoryCode:
          _crmMode == 'CRM non financee' ? _guarantorCategoryCode : 'a',
      guarantorRating: _crmMode == 'CRM non financee' ? _guarantorRating : '',
      guarantorCountry: _crmMode == 'CRM non financee'
          ? _guarantorCountryController.text.trim()
          : '',
      guarantorCountryRating:
          _crmMode == 'CRM non financee' ? _guarantorCountryRating : '',
      crmCoveragePercent:
          _crmMode == 'CRM non financee' ? _computedCoverage : 0.0,
      comment: comment,
      analysisDate: widget.initialDraft?.analysisDate ?? DateTime.now(),
      grantDate: _grantDate,
      maturityDate: _maturityDate,
      sovereignSpecialCase: resolvedSovereignSpecialCase,
      sovereignPreferentialZeroWeight: sovereignPreferentialZeroWeight,
      sovereignOceEstablished: _sovereignOceEstablished == true,
      sovereignOceNote: _sovereignOceNote,
      publicBodyUemoaFcfaCase: _publicBodyUemoaFcfaCase,
      publicBodyFinancesNonPublicActivity: _publicBodyFinancesNonPublicActivity,
      bmdHighQualityCase: _bmdHighQualityCase,
      bmdUemoaFcfaCase: _bmdUemoaFcfaCase,
      bmdUemoaCriteriaSatisfied: _bmdUemoaCriteriaSatisfied,
      bmdListedInstitutionFcfaCase: _bmdListedInstitutionFcfaCase,
      bankInstitutionCase: _bankInstitutionCase,
      otherAssetType: _otherAssetType,
      offBalanceRiskLevel: _offBalanceRiskLevel,
      retailEligibilityCriteriaSatisfied: _retailEligibilityCriteriaSatisfied,
      residentialMortgageEligible: _residentialMortgageEligible,
      commercialRealEstateEligible: _commercialRealEstateEligible,
      defaultedExposureInitialRiskWeight: _defaultedExposureInitialRiskWeight,
      defaultedExposureResidentialMortgageInDefault:
          _defaultedExposureResidentialMortgageInDefault,
      defaultedExposureProvisionAtLeastTwentyPercent:
          _defaultedExposureProvisionAtLeastTwentyPercent,
      enterpriseExceedsBceaoDegradationThreshold:
          _enterpriseExceedsBceaoDegradationThreshold,
      enterprisePrudentialProcedure: _enterprisePrudentialProcedure,
      enterpriseInvestmentFirmWithoutBankingLaw:
          _enterpriseInvestmentFirmWithoutBankingLaw,
    );
  }

  String _formatPercent(double value) {
    return '${(value * 100).toStringAsFixed(0)} %';
  }
}

class _WizardStepMeta {
  const _WizardStepMeta({
    required this.shortLabel,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String shortLabel;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _KpiData {
  const _KpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.highlighted = false,
    this.fullSpan = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final bool highlighted;
  final bool fullSpan;
}

class _ChoiceCardData {
  const _ChoiceCardData({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
    this.subtitle = '',
  });

  final String value;
  final String label;
  final IconData icon;
  final Color accent;
  final String subtitle;
}

class _IntroActionButton extends StatelessWidget {
  const _IntroActionButton({
    required this.icon,
    required this.accent,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = filled ? accent : accent.withValues(alpha: 0.08);
    final foreground = filled ? Colors.white : accent;
    final borderColor = filled ? accent : accent.withValues(alpha: 0.22);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.14),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 12,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

class _CompactFieldCard extends StatelessWidget {
  const _CompactFieldCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.inlineTooltip,
    this.placeInlineTooltipBeforeTitle = false,
    this.hideLeadingIcon = true,
    this.iconTooltip,
    this.tooltipTitle = 'Critères',
    this.tooltipMaxWidth = 600,
    this.subtitleColor,
    this.hideHeader = false,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? inlineTooltip;
  final bool placeInlineTooltipBeforeTitle;
  final bool hideLeadingIcon;
  final String? iconTooltip;
  final String tooltipTitle;
  final double tooltipMaxWidth;
  final Color? subtitleColor;
  final bool hideHeader;
  final Widget child;

  InlineSpan _buildTooltipContent(String title, String message) {
    final lines = _expandTooltipMessageLines(message);

    if (lines.isEmpty) {
      return const TextSpan(text: '');
    }

    final spans = <InlineSpan>[
      TextSpan(
        text: '$title\n',
        style: const TextStyle(
          fontSize: 12.4,
          fontWeight: FontWeight.w500,
          color: Colors.white,
          height: 1.2,
        ),
      ),
    ];

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (line.isEmpty) {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }
      if (line.startsWith('[[CARD]]')) {
        spans.add(_buildTooltipCardSpan(line));
        continue;
      }
      final isNote = line.startsWith('[[NOTE]]');
      if (isNote) {
        final noteText = line.replaceFirst('[[NOTE]]', '').trimLeft();
        spans.add(
          TextSpan(
            text: '$noteText${index == lines.length - 1 ? '' : '\n'}',
            style: const TextStyle(
              fontSize: 10.2,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: Color(0xFFFFB86B),
              height: 1.35,
            ),
          ),
        );
        continue;
      }

      final separatorIndex = line.indexOf(':');
      final hasLabelValueFormat =
          separatorIndex > 0 && separatorIndex < line.length - 1;

      if (hasLabelValueFormat) {
        final label = line.substring(0, separatorIndex).trim();
        final detail = line.substring(separatorIndex + 1).trim();
        final shouldBreakDetailLine = detail.startsWith('[[BREAK]]');
        final normalizedDetail = _normalizeTooltipSentence(
          shouldBreakDetailLine
              ? detail.replaceFirst('[[BREAK]]', '').trimLeft()
              : detail,
        );
        spans.add(
          TextSpan(
            children: [
              const TextSpan(
                text: '• ',
                style: TextStyle(
                  fontSize: 11.4,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8FB4FF),
                  height: 1.5,
                ),
              ),
              TextSpan(
                text: _capitalizeTooltipText(label),
                style: const TextStyle(
                  fontSize: 11.3,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
              TextSpan(
                text: shouldBreakDetailLine
                    ? ' :\n  $normalizedDetail${index == lines.length - 1 ? '' : '\n'}'
                    : ' : $normalizedDetail${index == lines.length - 1 ? '' : '\n'}',
                style: const TextStyle(
                  fontSize: 11.2,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFE8EEF9),
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
        continue;
      }

      spans.add(
        TextSpan(
          children: [
            const TextSpan(
              text: '• ',
              style: TextStyle(
                fontSize: 11.4,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8FB4FF),
                height: 1.48,
              ),
            ),
            TextSpan(
              text: '$line${index == lines.length - 1 ? '' : '\n'}',
              style: const TextStyle(
                fontSize: 11.2,
                fontWeight: FontWeight.w500,
                color: Color(0xFFE8EEF9),
                height: 1.48,
              ),
            ),
          ],
        ),
      );
    }

    return TextSpan(children: spans);
  }

  Widget _buildModernTooltip({
    required BuildContext context,
    required String title,
    required String message,
    required Widget child,
  }) {
    return Tooltip(
      richMessage: _buildTooltipContent(title, message),
      constraints: BoxConstraints(maxWidth: tooltipMaxWidth),
      waitDuration: const Duration(milliseconds: 140),
      showDuration: const Duration(seconds: 12),
      preferBelow: false,
      verticalOffset: 18,
      textAlign: TextAlign.start,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1C34),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFF2D4B7A), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
          ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isExposureDark(context);
    final iconBadge = Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2B47) : const Color(0xFFF4F7FE),
        borderRadius: BorderRadius.circular(_exposureFormRadius),
      ),
      child: Icon(icon, size: 14, color: AppTheme.accent),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _wizardSoftCardColor(context),
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        border: Border.all(
          color: _wizardRightSectionBorderColor(context),
          width: _wizardBorderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hideHeader) ...[
            Row(
              children: [
                if (!hideLeadingIcon) ...[
                  if (iconTooltip != null && iconTooltip!.trim().isNotEmpty)
                    _buildModernTooltip(
                      context: context,
                      title: tooltipTitle,
                      message: iconTooltip!,
                      child: iconBadge,
                    )
                  else
                    iconBadge,
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (placeInlineTooltipBeforeTitle &&
                              inlineTooltip != null &&
                              inlineTooltip!.trim().isNotEmpty) ...[
                            _buildModernTooltip(
                              context: context,
                              title: tooltipTitle,
                              message: inlineTooltip!,
                              child: const Padding(
                                padding: EdgeInsets.only(top: 1.5),
                                child: Icon(
                                  Icons.info_outline_rounded,
                                  size: 14,
                                  color: AppTheme.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF0B3D91),
                                    fontSize: 12.0,
                                  ),
                            ),
                          ),
                          if (inlineTooltip != null &&
                              inlineTooltip!.trim().isNotEmpty &&
                              !placeInlineTooltipBeforeTitle) ...[
                            const SizedBox(width: 6),
                            _buildModernTooltip(
                              context: context,
                              title: tooltipTitle,
                              message: inlineTooltip!,
                              child: const Padding(
                                padding: EdgeInsets.only(top: 1.5),
                                child: Icon(
                                  Icons.info_outline_rounded,
                                  size: 14,
                                  color: AppTheme.accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: subtitleColor ??
                                        _wizardSubtleMutedColor(context),
                                    fontSize: 9.1,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
          ],
          child,
        ],
      ),
    );
  }
}

class _PrimaryInformationStepScreen extends StatelessWidget {
  const _PrimaryInformationStepScreen({
    required this.title,
    required this.subtitle,
    required this.formKey,
    required this.fields,
  });

  final String title;
  final String subtitle;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    return _StepSurface(
      title: title,
      subtitle: subtitle,
      icon: Icons.badge_outlined,
      accent: AppTheme.accent,
      child: Form(
        key: formKey,
        child: _StepGrid(children: fields),
      ),
    );
  }
}

class _CategoryStepScreen extends StatelessWidget {
  const _CategoryStepScreen({
    required this.title,
    required this.subtitle,
    required this.formKey,
    required this.content,
  });

  final String title;
  final String subtitle;
  final GlobalKey<FormState> formKey;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return _StepSurface(
      title: title,
      subtitle: subtitle,
      icon: Icons.account_tree_outlined,
      accent: const Color(0xFF2563EB),
      child: Form(
        key: formKey,
        child: content,
      ),
    );
  }
}

class _FinancialDataStepScreen extends StatelessWidget {
  const _FinancialDataStepScreen({
    required this.title,
    required this.subtitle,
    required this.formKey,
    required this.fields,
    required this.helper,
  });

  final String title;
  final String subtitle;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;
  final Widget helper;

  @override
  Widget build(BuildContext context) {
    return _StepSurface(
      title: title,
      subtitle: subtitle,
      icon: Icons.account_balance_wallet_outlined,
      accent: const Color(0xFF0F766E),
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepGrid(children: fields),
            const SizedBox(height: 4),
            helper,
          ],
        ),
      ),
    );
  }
}

class _CrmChoiceStepScreen extends StatelessWidget {
  const _CrmChoiceStepScreen({
    required this.title,
    required this.subtitle,
    this.questionText,
    required this.selectedMode,
    required this.choices,
    required this.onModeChanged,
  });

  final String title;
  final String subtitle;
  final String? questionText;
  final String selectedMode;
  final List<_ChoiceCardData> choices;
  final ValueChanged<String> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final isBinaryQuestion = choices.length == 2 &&
        choices.any((item) => item.value == 'OUI') &&
        choices.any((item) => item.value == 'NON');
    final questionAccent =
        isBinaryQuestion ? const Color(0xFF2563EB) : const Color(0xFF0F766E);
    final headerIcon =
        isBinaryQuestion ? Icons.fact_check_outlined : Icons.handshake_outlined;
    final headerAccent =
        isBinaryQuestion ? const Color(0xFF2563EB) : const Color(0xFF0F766E);
    final resolvedQuestionText = questionText ?? subtitle;
    return _StepSurface(
      title: title,
      subtitle: subtitle,
      icon: headerIcon,
      accent: headerAccent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 320),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              decoration: BoxDecoration(
                color: questionAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: questionAccent.withValues(alpha: 0.16),
                  width: _wizardBorderWidth,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        resolvedQuestionText,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: _wizardBodyTitleColor(context),
                              fontSize: 15.2,
                              height: 1.22,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isBinaryQuestion
                            ? 'Sélectionnez une réponse pour continuer.'
                            : "Choisir l'option la plus adaptée.",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _wizardMutedColor(context),
                              fontSize: 11.1,
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final item in choices)
                    _ModeChoiceCard(
                      label: item.label,
                      subtitle: item.subtitle,
                      icon: item.icon,
                      accent: item.accent,
                      selected: selectedMode == item.value,
                      onTap: () => onModeChanged(item.value),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrmDetailsStepScreen extends StatelessWidget {
  const _CrmDetailsStepScreen({
    required this.title,
    required this.subtitle,
    required this.formKey,
    required this.icon,
    required this.accent,
    required this.child,
    this.inlineTooltip,
    this.tooltipTitle = 'Critères',
  });

  final String title;
  final String subtitle;
  final GlobalKey<FormState> formKey;
  final IconData icon;
  final Color accent;
  final Widget child;
  final String? inlineTooltip;
  final String tooltipTitle;

  @override
  Widget build(BuildContext context) {
    return _StepSurface(
      title: title,
      subtitle: subtitle,
      icon: icon,
      accent: accent,
      inlineTooltip: inlineTooltip,
      tooltipTitle: tooltipTitle,
      child: Form(
        key: formKey,
        child: child,
      ),
    );
  }
}

class _CommentStepScreen extends StatelessWidget {
  const _CommentStepScreen({
    required this.title,
    required this.subtitle,
    required this.formKey,
    required this.commentField,
  });

  final String title;
  final String subtitle;
  final GlobalKey<FormState> formKey;
  final Widget commentField;

  @override
  Widget build(BuildContext context) {
    return _StepSurface(
      title: title,
      subtitle: subtitle,
      icon: Icons.edit_note_outlined,
      accent: const Color(0xFFF59E0B),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            commentField,
          ],
        ),
      ),
    );
  }
}

class _FinalDecisionStepScreen extends StatelessWidget {
  const _FinalDecisionStepScreen({
    required this.title,
    required this.subtitle,
    required this.submitLabel,
    required this.submitting,
    required this.onConfirm,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final String submitLabel;
  final bool submitting;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onBack;

  @override
  Widget build(BuildContext context) {
    return _StepSurface(
      title: title,
      subtitle: subtitle,
      icon: Icons.task_alt_outlined,
      accent: const Color(0xFF16A34A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 260),
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: [
              OutlinedButton.icon(
                onPressed: submitting ? null : () => onBack(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(144, 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  backgroundColor: _wizardCardColor(context),
                  foregroundColor: _wizardMutedColor(context),
                  side: _wizardBorderSide(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_exposureFormRadius),
                  ),
                ),
                icon: const Icon(Icons.west_rounded, size: 18),
                label: Text(
                  context.tr('Precedent'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: submitting ? null : () => onConfirm(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(196, 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_exposureFormRadius),
                  ),
                ),
                icon: submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.task_alt_rounded, size: 18),
                label: Text(
                  submitLabel.tr(context),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepSurface extends StatelessWidget {
  const _StepSurface({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.child,
    this.inlineTooltip,
    this.tooltipTitle = 'Critères',
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget child;
  final String? inlineTooltip;
  final String tooltipTitle;

  @override
  Widget build(BuildContext context) {
    final isDark = _isExposureDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _wizardCardColor(context),
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        border: Border.all(
          color: _wizardRightSectionBorderColor(context),
          width: _wizardBorderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(_exposureFormRadius),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: _wizardBodyTitleColor(context),
                                ),
                          ),
                        ),
                        if (inlineTooltip != null &&
                            inlineTooltip!.trim().isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            richMessage: _buildModernTooltipContent(
                              tooltipTitle,
                              inlineTooltip!,
                            ),
                            constraints: const BoxConstraints(maxWidth: 350),
                            waitDuration: const Duration(milliseconds: 140),
                            showDuration: const Duration(seconds: 12),
                            preferBelow: false,
                            verticalOffset: 18,
                            textAlign: TextAlign.start,
                            padding: const EdgeInsets.fromLTRB(5, 3, 4, 3),
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1C34),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF2D4B7A),
                                width: 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 18,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            textStyle: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white,
                                ),
                            child: const Padding(
                              padding: EdgeInsets.only(top: 1.5),
                              child: Icon(
                                Icons.info_outline_rounded,
                                size: 15,
                                color: AppTheme.accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _wizardSubtleMutedColor(context),
                            fontSize: 10.3,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          child,
        ],
      ),
    );
  }
}

class _StepGrid extends StatelessWidget {
  const _StepGrid({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final columns = constraints.maxWidth >= 440 ? 2 : 1;
        final itemWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(
                width: child is _StepGridFullWidth
                    ? constraints.maxWidth
                    : itemWidth,
                child: child is _StepGridFullWidth ? child.child : child,
              ),
          ],
        );
      },
    );
  }
}

class _AdaptiveMetricGrid extends StatelessWidget {
  const _AdaptiveMetricGrid({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final columns = constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 470
                ? 2
                : 1;
        final itemWidth = columns == 1
            ? constraints.maxWidth
            : ((constraints.maxWidth - spacing * (columns - 1)) / columns)
                .clamp(0.0, 180.0)
                .toDouble();
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(
                width: itemWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class _StepGridFullWidth extends StatelessWidget {
  const _StepGridFullWidth({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _HeroKpiCard extends StatelessWidget {
  const _HeroKpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.highlighted = false,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final bool highlighted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = _isExposureDark(context);
    final cardPadding = compact
        ? const EdgeInsets.fromLTRB(7, 7, 7, 7)
        : const EdgeInsets.fromLTRB(9, 8, 9, 8);
    final labelFontSize = compact ? 9.0 : 10.0;
    final valueFontSize = compact ? 10.5 : 11.5;
    final highlightBackground =
        isDark ? const Color(0xFF1D4ED8) : const Color(0xFF3B82F6);
    const highlightLabelColor = Color(0xFFDCE9FF);
    const highlightValueColor = Colors.white;
    final cardBackground = highlighted
        ? highlightBackground
        : compact
            ? (isDark ? const Color(0xFF172740) : const Color(0xFFF9FBFF))
            : (isDark ? const Color(0xFF14233D) : Colors.white);
    final cardGradient = highlighted
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark ? const Color(0xFF2563EB) : const Color(0xFF4F8DF8),
              isDark ? const Color(0xFF1D4ED8) : const Color(0xFF2563EB),
            ],
          )
        : null;
    final cardBorderColor = highlighted
        ? Colors.transparent
        : compact
            ? (isDark ? const Color(0xFF324A6A) : const Color(0xFFC9D8F3))
            : _wizardBorderColor(context);
    final cardShadowColor = highlighted
        ? const Color(0x3D2563EB)
        : compact
            ? (isDark ? const Color(0x22000000) : const Color(0x160B3D91))
            : (isDark ? const Color(0x22000000) : const Color(0x080F172A));
    final cardRadius = compact ? 2.0 : _exposureFormRadius;
    final labelColor = highlighted
        ? highlightLabelColor
        : isDark
            ? const Color(0xFF93C5FD)
            : const Color(0xFF0B3D91);
    final valueColor = highlighted
        ? highlightValueColor
        : compact && !isDark
            ? const Color(0xFF1B2559)
            : _wizardBodyTitleColor(context);

    return Container(
      padding: cardPadding,
      constraints: BoxConstraints(minHeight: compact ? 50 : 58),
      decoration: BoxDecoration(
        color: cardBackground,
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(
          color: cardBorderColor,
          width: highlighted ? 0 : _wizardBorderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: cardShadowColor,
            blurRadius: highlighted ? 20 : (compact ? 8 : 4),
            offset: highlighted ? const Offset(0, 10) : const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: labelColor,
                        fontWeight: FontWeight.w500,
                        fontSize: labelFontSize,
                        height: 1.1,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: valueFontSize,
                        color: valueColor,
                        height: 1.08,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepOverviewChip extends StatelessWidget {
  const _StepOverviewChip({
    required this.number,
    required this.isActive,
    required this.isCompleted,
  });

  final int number;
  final bool isActive;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final isDark = _isExposureDark(context);
    const activeBlue = Color(0xFF2563EB);
    const completedGreen = Color(0xFF22C55E);
    final accent = isActive
        ? activeBlue
        : isCompleted
            ? completedGreen
            : const Color(0xFF94A3B8);
    final background = isActive
        ? activeBlue
        : isCompleted
            ? completedGreen
            : (isDark ? const Color(0xFF13233C) : const Color(0xFFF8FAFC));
    final textColor = isActive || isCompleted ? Colors.white : accent;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isActive
              ? activeBlue
              : isCompleted
                  ? completedGreen
                  : (isDark
                      ? const Color(0xFF2B3B56)
                      : const Color(0xFFE2E8F0)),
          width: _wizardBorderWidth,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
              fontSize: 9,
            ),
      ),
    );
  }
}

class _ModeChoiceCard extends StatelessWidget {
  const _ModeChoiceCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = _isExposureDark(context);
    final cardShadow = selected
        ? accent.withValues(alpha: isDark ? 0.10 : 0.06)
        : (isDark ? const Color(0x22000000) : const Color(0x0D94A3B8));
    return SizedBox(
      width: 206,
      height: 50,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13233C) : Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.72)
                  : (isDark
                      ? const Color(0xFF2B3B56)
                      : const Color(0xFFDDE6F2)),
              width: selected ? 1.3 : _wizardBorderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: cardShadow,
                blurRadius: selected ? 22 : 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: _wizardBodyTitleColor(context),
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                        ),
                  ),
                  if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _wizardMutedColor(context),
                              fontWeight: FontWeight.w500,
                              fontSize: 10.2,
                              height: 1.1,
                            ),
                      ),
                    ],
                  ],
                ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.10)
                      : (isDark
                          ? const Color(0xFF162133)
                          : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? accent.withValues(alpha: 0.72)
                        : (isDark
                            ? const Color(0xFF40506A)
                            : const Color(0xFFC9D5E5)),
                    width: 1.2,
                  ),
                ),
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: accent,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.accent,
    required this.text,
  });

  final IconData icon;
  final Color accent;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = _isExposureDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(_exposureFormRadius),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
          width: _wizardBorderWidth,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _wizardBodyTitleColor(context),
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExposurePreview {
  const _ExposurePreview({
    required this.ead,
    required this.finalRw,
    required this.rwa,
  });

  final double ead;
  final double finalRw;
  final double rwa;
}
