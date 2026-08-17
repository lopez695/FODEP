import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/section_card.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../risque_credit_shared/models/credit_risk_models.dart';
import '../../risque_credit_shared/services/credit_risk_submodules_service.dart';
import '../../participations/widgets/groupes_clients_card.dart';
import '../../participations/widgets/participations_card.dart';
import 'package:fl_chart/fl_chart.dart';

const int _counterpartyTopCount = 10;
const int _issuerResidenceCountryTopCount = 10;
const int _concentrationViewModelVersion = 5;
const double _concentrationRadius = 8;
const List<String> _counterpartyRatingOrder = [
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

class ConcentrationScreen extends StatefulWidget {
  const ConcentrationScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<ConcentrationScreen> createState() => _ConcentrationScreenState();
}

class _ConcentrationScreenState extends State<ConcentrationScreen> {
  late final CreditRiskSubmodulesService _service;
  late Future<ConcentrationModuleData> _future;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _contentScrollController = ScrollController();
  final Map<String, _ConcentrationViewModel> _viewCache = {};
  StreamSubscription<int>? _portfolioSubscription;

  final String _selectedPeriod = '12M';
  final String _selectedCountry = 'Tous';
  final String _selectedRegion = 'Tous';
  final String _selectedSector = 'Tous';
  final String _selectedSegment = 'Tous';
  final String _selectedRating = 'Tous';
  final String _selectedStatus = 'Tous';
  final String _selectedDefault = 'Tous';
  final String _selectedGuarantee = 'Tous';
  int _selectedPortfolioTab = 0;

  @override
  void initState() {
    super.initState();
    _service = CreditRiskSubmodulesService(widget.api);
    _future = _service.fetchConcentrationModule();
    _portfolioSubscription = widget.api.portfolioRefreshStream.listen((_) {
      if (!mounted) {
        return;
      }
      _refresh();
    });
  }

  @override
  void dispose() {
    _portfolioSubscription?.cancel();
    _contentScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ConcentrationModuleData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final data = snapshot.data!;
        final view = _viewFor(data);

        return Column(
          children: [
            _buildFixedTopBar(context),
            Expanded(
              child: Scrollbar(
                controller: _contentScrollController,
                child: SingleChildScrollView(
                  controller: _contentScrollController,
                  padding: const EdgeInsets.all(AppTheme.pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _selectedPortfolioTab == 0
                        ? [
                            _buildCounterpartyAndGeographyRow(view),
                            const SizedBox(height: AppTheme.pageGap),
                            // Les groupes de clients liés décident du
                            // périmètre sur lequel la division des risques
                            // s'apprécie : ils se saisissent donc ici, au
                            // milieu des concentrations qu'ils déterminent.
                            GroupesClientsCard(api: widget.api),
                            const SizedBox(height: AppTheme.pageGap),
                            // Les participations sont une concentration comme
                            // une autre : un encours porté sur une contrepartie
                            // unique, plafonné par les mêmes fonds propres. Leur
                            // place est parmi les expositions du portefeuille,
                            // et non dans la vue d'ensemble.
                            ParticipationsCard(api: widget.api),
                            const SizedBox(height: AppTheme.pageGap),
                            _buildNplSection(view),
                          ]
                        : [
                            Padding(
                              padding: const EdgeInsets.only(top: 150),
                              child: Center(
                                child: Text(
                                  'Appétence aux risques de la banque',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: AppTheme.text,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                            ),
                          ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _selectPortfolioTab(int index) {
    if (_selectedPortfolioTab == index) {
      return;
    }
    setState(() => _selectedPortfolioTab = index);
    if (_contentScrollController.hasClients) {
      _contentScrollController.jumpTo(0);
    }
  }

  Widget _buildFixedTopBar(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Theme.of(context).cardColor,
        elevation: 2,
        shadowColor: const Color(0x1A0F172A),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Portefeuille',
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lecture des expositions, concentrations et signaux de vigilance.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.muted.withValues(alpha: 0.85),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                  ),
                ],
              ),
            ),
            _PortfolioTabNavigation(
              selectedIndex: _selectedPortfolioTab,
              onChanged: _selectPortfolioTab,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNplSection(_ConcentrationViewModel view) {
    final defaultExposures =
        view.exposureDetails.where((e) => e.isDefault).toList();
    final encoursNpl =
        defaultExposures.fold<double>(0.0, (sum, e) => sum + e.grossAmount);
    final countNpl = defaultExposures.length;
    final totalGross = view.totalGross;
    final nplRatio = totalGross > 0 ? (encoursNpl / totalGross) : 0.0;

    final provisions = defaultExposures.fold<double>(
        0.0, (sum, e) => sum + e.provisionsAmount);
    final coverageRatio = encoursNpl > 0 ? (provisions / encoursNpl) : 0.0;
    final provisionsTotalRatio =
        totalGross > 0 ? (provisions / totalGross) : 0.0;
    final nplNet = encoursNpl - provisions;

    // Un ratio réel mais minuscule (ex. 68 M de provisions sur 4 245 Md de
    // portefeuille = 0,0016 %) s'arrondirait à « 0,00 % » : trompeur pour un
    // rapport prudentiel - on affiche « < 0,01 % » à la place.
    String pctFin(double ratio) => ratio > 0 && ratio < 0.0001
        ? '< 0,01%'
        : AppFormatters.percent(ratio);

    Widget buildBaseCard(
        {required Widget child,
        EdgeInsetsGeometry? padding,
        Color? backgroundColor}) {
      return Container(
        padding: padding ?? const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: backgroundColor ?? Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(_concentrationRadius),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );
    }

    // --- Row helper for label/value pairs ---
    Widget buildRow(
        {required String label,
        String? formula,
        required String value,
        bool isLast = false}) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(value,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.indigo[900],
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5)),
              ],
            ),
          ),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                  height: 1,
                  color: const Color(0xFFDCE4F2)),
            ),
        ],
      );
    }

    // --- Inner sub-card ---
    Widget buildSubCard({required String title, required List<Widget> rows}) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Text(title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.indigo[900],
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
            ),
            ...rows,
          ],
        ),
      );
    }

    // --- Summary footer ---
    final summaryBar = Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Encours NPL :  ',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w500,
                            fontSize: 12)),
                    Text('${_amountMd(encoursNpl)} ${_amountUnitLabel()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Provisions totales :  ',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w500,
                            fontSize: 12)),
                    Text('${_amountMd(provisions)} ${_amountUnitLabel()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // --- Main block1 : one big outer card (like "Tombées de Flux") ---
    final block1 = buildBaseCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header matching the reference image
          Row(
            children: [
              Text('Indicateurs NPL et Provisions',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          // Sub-cards row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: buildSubCard(
                  title: 'Non Performing Loans',
                  rows: [
                    buildRow(
                        label: 'Ratio NPL',
                        formula: '(Encours NPL / Encours total)',
                        value: pctFin(nplRatio)),
                    buildRow(
                        label: 'Exposition nette',
                        formula: '(Encours NPL - Provisions)',
                        value: '${_amountMd(nplNet)} ${_amountUnitLabel()}',
                        isLast: true),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: AppTheme.pageGap / 4),
                  padding: const EdgeInsets.only(left: AppTheme.pageGap / 4),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                          color: const Color(0xFFDCE4F2)),
                    ),
                  ),
                  child: buildSubCard(
                    title: 'PROVISIONS',
                    rows: [
                      buildRow(
                          label: 'Provisions totales sur NPL',
                          formula: '(Somme des provisions)',
                          value:
                              '${_amountMd(provisions)} ${_amountUnitLabel()}'),
                      buildRow(
                          label: 'Taux de couverture',
                          formula: '(Provisions / Encours NPL)',
                          value: AppFormatters.percent(coverageRatio)),
                      buildRow(
                          label: 'Provisions / Encours total',
                          formula: '(Provisions / Encours total)',
                          value: pctFin(provisionsTotalRatio),
                          isLast: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Summary bar
          summaryBar,
        ],
      ),
    );

    double bucket1Amount = 0.0;
    double bucket2Amount = 0.0;
    double bucket3Amount = 0.0;
    double bucket4Amount = 0.0;
    
    for (final exp in defaultExposures) {
      if (exp.joursImpayes <= 30) {
        bucket1Amount += exp.grossAmount;
      } else if (exp.joursImpayes <= 90) {
        bucket2Amount += exp.grossAmount;
      } else if (exp.joursImpayes <= 180) {
        bucket3Amount += exp.grossAmount;
      } else {
        bucket4Amount += exp.grossAmount;
      }
    }

    final totalBuckets = bucket1Amount + bucket2Amount + bucket3Amount + bucket4Amount;
    final safeTotal = totalBuckets > 0 ? totalBuckets : 1.0; // avoid division by zero

    final chartEntries = [
      (
        label: '1 à 30 j',
        percent: bucket1Amount / safeTotal,
        amount: bucket1Amount,
        color: const Color(0xFF4ADE80)
      ),
      (
        label: '31 à 90 j',
        percent: bucket2Amount / safeTotal,
        amount: bucket2Amount,
        color: const Color(0xFF3B82F6)
      ),
      (
        label: '91 à 180 j',
        percent: bucket3Amount / safeTotal,
        amount: bucket3Amount,
        color: const Color(0xFFFBBF24)
      ),
      (
        label: 'Plus de 180 j',
        percent: bucket4Amount / safeTotal,
        amount: bucket4Amount,
        color: const Color(0xFFEF4444)
      ),
    ];

    // Le champ « jours d'impayés » existe dans la base et l'import Excel
    // (colonne optionnelle Jours_impayes), mais peut n'avoir jamais été
    // renseigné : tout classer en « 1 – 30 jours » serait alors un faux
    // confort prudentiel - on affiche un état explicite à la place.
    final joursRenseignes =
        defaultExposures.any((exp) => exp.joursImpayes > 0);

    final subBlockB = buildBaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Suivi du nombre de jours impayés',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          if (defaultExposures.isNotEmpty && !joursRenseignes)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 28, color: AppTheme.muted),
                      const SizedBox(height: 10),
                      Text(
                        'Jours d\'impayés non renseignés',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                                color: AppTheme.text,
                                fontWeight: FontWeight.w600,
                                fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Renseignez la colonne « Jours_impayes » dans '
                        'l\'import Excel des expositions pour activer '
                        'ce suivi.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
          Expanded(
            child: Center(
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 160,
                      child: _AnimatedVerticalBarChart(
                        entries: chartEntries
                            .map((e) => (e.percent, e.color))
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < chartEntries.length; i++) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: chartEntries[i].color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(chartEntries[i].label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                              color: AppTheme.text,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500)),
                                ),
                                Text(
                                    '${(chartEntries[i].percent * 100) > 0 && (chartEntries[i].percent * 100) < 1 ? '< 1' : (chartEntries[i].percent * 100).toInt()} %',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                            color: AppTheme.text,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                const SizedBox(width: 12),
                                Container(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                      '${_amountMd(chartEntries[i].amount)} ${_amountUnitLabel()}',
                                      textAlign: TextAlign.right,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                              color: AppTheme.muted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ),
                          ),
                          if (i < chartEntries.length - 1)
                            Divider(
                                height: 1,
                                color: Theme.of(context)
                                    .dividerColor
                                    .withValues(alpha: 0.5)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text('Nombre NPL :  ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text('$countNpl',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );

    // Top 5 NPL expositions
    final top5Npl = defaultExposures.toList()
      ..sort((a, b) => b.grossAmount.compareTo(a.grossAmount));
    final top5 = top5Npl.take(5).toList();

    final top5Table = Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Top 5 des plus grandes expositions NPL (brut)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          final isDark =
                              Theme.of(context).brightness == Brightness.dark;
                          return AlertDialog(
                            backgroundColor:
                                isDark ? AppTheme.darkCard : AppTheme.card,
                            title: Text(
                              'Toutes les expositions NPL',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: AppTheme.text,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            content: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: 800,
                                maxHeight: MediaQuery.of(context).size.height * 0.8,
                              ),
                              child: Container(
                                width: 800,
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFDCE4F2)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                                      color: const Color(0xFF001F4E),
                                      child: IntrinsicHeight(
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Container(
                                              width: 50,
                                              padding: const EdgeInsets.only(left: 12, top: 9, bottom: 9),
                                              alignment: Alignment.centerLeft,
                                              child: Text('N°', style: _tableHeaderStyle().copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                                            ),
                                            Container(width: 0.5, color: const Color(0xFFDCE4F2)),
                                            Expanded(
                                              flex: 4,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                                alignment: Alignment.centerLeft,
                                                child: Text('Contrepartie', style: _tableHeaderStyle().copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                                              ),
                                            ),

                                            Container(width: 0.5, color: const Color(0xFFDCE4F2)),
                                            Expanded(
                                              flex: 3,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                                alignment: Alignment.centerLeft,
                                                child: Text('Encours brut',
                                                    style: _tableHeaderStyle().copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                                              ),
                                            ),
                                            Container(width: 0.5, color: const Color(0xFFDCE4F2)),
                                            Expanded(
                                              flex: 3,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                                alignment: Alignment.centerLeft,
                                                child: Text('Provision',
                                                    style: _tableHeaderStyle().copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                                              ),
                                            ),
                                            Container(width: 0.5, color: const Color(0xFFDCE4F2)),
                                            Expanded(
                                              flex: 3,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                                alignment: Alignment.centerLeft,
                                                child: Text('Taux couv.',
                                                    style: _tableHeaderStyle().copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(height: 0.5, color: const Color(0xFFDCE4F2)),
                                    Flexible(
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        addSemanticIndexes: false,
                                        itemCount: top5Npl.length,
                                      separatorBuilder: (context, index) =>
                                          Container(height: 0.5, color: const Color(0xFFDCE4F2)),
                                      itemBuilder: (context, index) {
                                        final e = top5Npl[index];
                                        final coverageRate = e.grossAmount > 0
                                            ? (e.estimatedProvision /
                                                e.grossAmount)
                                            : 0.0;

                                        return Material(
                                          color: index.isOdd ? const Color(0xFFF8FAFC) : Colors.white,
                                          child: IntrinsicHeight(
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                Container(
                                                  width: 50,
                                                  padding: const EdgeInsets.only(left: 12, top: 9, bottom: 9),
                                                  alignment: Alignment.centerLeft,
                                                  child: Text(
                                                    '${index + 1}'.padLeft(2, '0'),
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                          color: AppTheme.muted,
                                                          fontWeight: FontWeight.w800,
                                                          fontSize: 12,
                                                        ),
                                                  ),
                                                ),
                                                Container(width: 0.5, color: const Color(0xFFDCE4F2)),
                                                Expanded(
                                                  flex: 4,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                                    alignment: Alignment.centerLeft,
                                                    child: Text(
                                                      e.counterpartyName,
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                            color: const Color(0xFF1E293B),
                                                            fontWeight: FontWeight.w700,
                                                            fontSize: 12,
                                                          ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),

                                                Container(width: 0.5, color: const Color(0xFFDCE4F2)),
                                                Expanded(
                                                  flex: 3,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                                    alignment: Alignment.centerLeft,
                                                    child: Text(
                                                      '${_amountMd(e.grossAmount)} ${_amountUnitLabel()}',
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                            color: const Color(0xFF001F4E),
                                                            fontWeight: FontWeight.w700,
                                                            fontSize: 12,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                Container(width: 0.5, color: const Color(0xFFDCE4F2)),
                                                Expanded(
                                                  flex: 3,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                                    alignment: Alignment.centerLeft,
                                                    child: Text(
                                                      '${_amountMd(e.estimatedProvision)} ${_amountUnitLabel()}',
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                            color: const Color(0xFF001F4E),
                                                            fontWeight: FontWeight.w700,
                                                            fontSize: 12,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                Container(width: 0.5, color: const Color(0xFFDCE4F2)),
                                                Expanded(
                                                  flex: 3,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                                    alignment: Alignment.centerLeft,
                                                    child: Text(
                                                      AppFormatters.percent(coverageRate),
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                            color: const Color(0xFF001F4E),
                                                            fontWeight: FontWeight.w900,
                                                            fontSize: 12,
                                                          ),
                                                    ),
                                                  ),
                                                ),
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
                          ),
                        );
                        },
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Voir toutes les expositions NPL',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: AppTheme.danger,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward,
                            color: AppTheme.danger, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
            color: const Color(0xFF001F4E),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 32,
                    padding: const EdgeInsets.only(left: 12, top: 9, bottom: 9),
                    alignment: Alignment.centerLeft,
                    child: Text('N°', style: _tableHeaderStyle().copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  Container(width: 0.5, color: const Color(0xFFDCE4F2)),
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      alignment: Alignment.centerLeft,
                      child: Text('Contrepartie', style: _tableHeaderStyle().copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),

                  Container(width: 0.5, color: const Color(0xFFDCE4F2)),
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      alignment: Alignment.centerLeft,
                      child: Text('Encours brut',
                          style: _tableHeaderStyle().copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  Container(width: 0.5, color: const Color(0xFFDCE4F2)),
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      alignment: Alignment.centerLeft,
                      child: Text('Provision',
                          style: _tableHeaderStyle().copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  Container(width: 0.5, color: const Color(0xFFDCE4F2)),
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      alignment: Alignment.centerLeft,
                      child: Text('Taux de couverture',
                          style: _tableHeaderStyle().copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Rows
          ...top5.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final coverageRate = e.grossAmount > 0
                ? (e.estimatedProvision / e.grossAmount)
                : 0.0;

            return Material(
              color: i.isOdd ? const Color(0xFFF8FAFC) : Colors.white,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 32,
                      padding: const EdgeInsets.only(left: 12, top: 9, bottom: 9),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${i + 1}'.padLeft(2, '0'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.muted,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                      ),
                    ),
                    Container(width: 0.5, color: const Color(0xFFDCE4F2)),
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          e.counterpartyName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF1E293B),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                    Container(width: 0.5, color: const Color(0xFFDCE4F2)),
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_amountMd(e.grossAmount)} ${_amountUnitLabel()}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF001F4E),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                        ),
                      ),
                    ),
                    Container(width: 0.5, color: const Color(0xFFDCE4F2)),
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_amountMd(e.estimatedProvision)} ${_amountUnitLabel()}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF001F4E),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                        ),
                      ),
                    ),
                    Container(width: 0.5, color: const Color(0xFFDCE4F2)),
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppFormatters.percent(coverageRate),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF001F4E),
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 310,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 21, child: block1),
                  const SizedBox(width: AppTheme.pageGap),
                  Expanded(flex: 20, child: subBlockB),
                ],
              ),
            ),
            top5Table,
          ],
        );
      },
    );
  }

  Widget _buildCounterpartyAndGeographyRow(_ConcentrationViewModel view) {
    const minRowWidth = 980.0;
    const rowHeight = 350.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        Widget content(double width) {
          return SizedBox(
            width: width,
            height: rowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildTopCounterparties(view)),
                const SizedBox(width: AppTheme.pageGap),
                Expanded(child: _buildSectorAndGeography(view)),
              ],
            ),
          );
        }

        final row = constraints.maxWidth >= minRowWidth
            ? content(constraints.maxWidth)
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: content(minRowWidth),
              );

        return SizedBox(
          height: rowHeight,
          child: row,
        );
      },
    );
  }

  Widget _buildSectorAndGeography(_ConcentrationViewModel view) {
    return _IssuerResidenceCountryCard(
      countryRows: view.countryDistribution
          .take(_issuerResidenceCountryTopCount)
          .toList(),
      zoneRows: view.regionDistribution,
    );
  }

  Widget _buildTopCounterparties(_ConcentrationViewModel view) {
    final visibleRows =
        view.counterpartyRows.take(_counterpartyTopCount).toList();

    return _TopCounterpartyExposureCard(
      rows: visibleRows,
      allRows: view.counterpartyRows,
    );
  }

  _ConcentrationViewModel _viewFor(ConcentrationModuleData data) {
    final key = [
      _concentrationViewModelVersion,
      identityHashCode(data),
      _searchController.text.trim().toLowerCase(),
      _selectedPeriod,
      _selectedCountry,
      _selectedRegion,
      _selectedSector,
      _selectedSegment,
      _selectedRating,
      _selectedStatus,
      _selectedDefault,
      _selectedGuarantee,
    ].join('|');

    return _viewCache.putIfAbsent(
      key,
      () => _ConcentrationViewModel.fromDetails(_filteredDetails(data)),
    );
  }

  List<ConcentrationExposureDetail> _filteredDetails(
    ConcentrationModuleData data,
  ) {
    if (data.exposureDetails.isEmpty) {
      return const <ConcentrationExposureDetail>[];
    }

    final latest = data.exposureDetails
        .map((item) => item.analysisDate)
        .reduce((left, right) => left.isAfter(right) ? left : right);
    final cutoff = _periodCutoff(_selectedPeriod, latest);
    final query = _searchController.text.trim().toLowerCase();

    return data.exposureDetails.where((item) {
      final matchesQuery = query.isEmpty ||
          item.id.toLowerCase().contains(query) ||
          item.counterpartyName.toLowerCase().contains(query) ||
          item.country.toLowerCase().contains(query) ||
          item.region.toLowerCase().contains(query) ||
          item.sector.toLowerCase().contains(query) ||
          item.rating.toLowerCase().contains(query);
      final matchesDate = !item.analysisDate.isBefore(cutoff);
      final matchesCountry =
          _selectedCountry == 'Tous' || item.country == _selectedCountry;
      final matchesRegion =
          _selectedRegion == 'Tous' || item.region == _selectedRegion;
      final matchesSector =
          _selectedSector == 'Tous' || item.sector == _selectedSector;
      final matchesSegment =
          _selectedSegment == 'Tous' || item.segment == _selectedSegment;
      final matchesRating =
          _selectedRating == 'Tous' || item.rating == _selectedRating;
      final matchesStatus =
          _selectedStatus == 'Tous' || item.status == _selectedStatus;
      final matchesDefault = _selectedDefault == 'Tous' ||
          (_selectedDefault == 'Oui' && item.isDefault) ||
          (_selectedDefault == 'Non' && !item.isDefault);
      final matchesGuarantee = _selectedGuarantee == 'Tous' ||
          (_selectedGuarantee == 'Oui' && item.hasGuarantee) ||
          (_selectedGuarantee == 'Non' && !item.hasGuarantee);

      return matchesQuery &&
          matchesDate &&
          matchesCountry &&
          matchesRegion &&
          matchesSector &&
          matchesSegment &&
          matchesRating &&
          matchesStatus &&
          matchesDefault &&
          matchesGuarantee;
    }).toList(growable: false);
  }

  DateTime _periodCutoff(String period, DateTime latest) {
    return switch (period) {
      '1M' => DateTime(latest.year, latest.month - 1, latest.day),
      '3M' => DateTime(latest.year, latest.month - 3, latest.day),
      '6M' => DateTime(latest.year, latest.month - 6, latest.day),
      'YTD' => DateTime(latest.year),
      _ => DateTime(latest.year, latest.month - 12, latest.day),
    };
  }

  void _refresh() {
    setState(() {
      _viewCache.clear();
      _future = _service.fetchConcentrationModule();
    });
  }
}

class _PortfolioTabNavigation extends StatelessWidget {
  const _PortfolioTabNavigation({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const _items = [
    'Analyse portefeuille crédit',
    'Alertes & décisions',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < _items.length; index++)
                _PortfolioTabButton(
                  label: _items[index],
                  selected: selectedIndex == index,
                  onTap: () => onChanged(index),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortfolioTabButton extends StatelessWidget {
  const _PortfolioTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final textColor = selected
        ? (isDark ? Colors.white : const Color(0xFF1E293B))
        : (isDark ? Colors.white70 : const Color(0xFF475569));

    final bgColor = selected
        ? (isDark ? const Color(0xFF334155) : Colors.white)
        : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: 32,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: textColor,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                height: 1,
              ),
        ),
      ),
    );
  }
}

class _ConcentrationViewModel {
  const _ConcentrationViewModel({
    required this.totalGross,
    required this.totalEad,
    required this.totalRwa,
    required this.totalCapital,
    required this.hhi,
    required this.hhiBadge,
    required this.topSectorLabel,
    required this.topSectorShare,
    required this.topCounterpartyName,
    required this.topCounterpartyShare,
    required this.sectorRows,
    required this.countryRows,
    required this.regionRows,
    required this.prudentialRows,
    required this.riskWeightRows,
    required this.rwaSectorRows,
    required this.counterpartyRows,
    required this.rwaCounterpartyRows,
    required this.exposureDetails,
    required this.sectorDistribution,
    required this.countryDistribution,
    required this.regionDistribution,
    required this.ratingDistribution,
    required this.quality,
    required this.trends,
    required this.alerts,
  });

  factory _ConcentrationViewModel.fromDetails(
    List<ConcentrationExposureDetail> details,
  ) {
    final totalGross =
        details.fold<double>(0.0, (sum, item) => sum + item.grossAmount);
    final totalEad = details.fold<double>(0.0, (sum, item) => sum + item.ead);
    final totalRwa = details.fold<double>(0.0, (sum, item) => sum + item.rwa);
    final totalCapital =
        details.fold<double>(0.0, (sum, item) => sum + item.capital);
    final sectorGroups = _groupDetails(details, (item) => item.sector);
    final countryGroups = _groupDetails(details, (item) => item.country);
    final regionGroups = _groupDetails(details, (item) => item.region);
    final prudentialGroups =
        _groupDetails(details, (item) => item.prudentialCategory);
    final counterpartyGroups =
        _groupDetails(details, (item) => item.counterpartyName);
    final riskWeightGroups =
        _groupDetails(details, (item) => _riskWeightBucket(item.riskWeight));

    final sectorRows = _sectorRows(sectorGroups, totalGross, totalRwa)
      ..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final countryRows = _breakdownRows(
      countryGroups,
      'Pays',
      totalGross,
      totalRwa,
    )..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final regionRows = _breakdownRows(
      regionGroups,
      'Région',
      totalGross,
      totalRwa,
    )..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final prudentialRows = _breakdownRows(
      prudentialGroups,
      'Catégorie prudentielle',
      totalGross,
      totalRwa,
    )..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final counterpartyRows = _counterpartyRows(counterpartyGroups, totalGross)
      ..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final rwaCounterpartyRows = [...counterpartyRows]
      ..sort((left, right) => right.rwa.compareTo(left.rwa));
    final exposureDetails = [...details]
      ..sort((left, right) => right.rwa.compareTo(left.rwa));
    final rwaSectorRows = [...sectorRows]
      ..sort((left, right) => right.rwa.compareTo(left.rwa));
    final riskWeightRows = _riskWeightRows(
      riskWeightGroups,
      totalEad,
      totalRwa,
    )..sort((left, right) => left.weight.compareTo(right.weight));
    final ratingDistribution = _ratingDistribution(details, totalGross);
    final hhi = _hhi(counterpartyRows.map((item) => item.share));
    final trends = _trends(details);

    return _ConcentrationViewModel(
      totalGross: totalGross,
      totalEad: totalEad,
      totalRwa: totalRwa,
      totalCapital: totalCapital,
      hhi: hhi,
      hhiBadge: _hhiBadge(hhi),
      topSectorLabel: sectorRows.isEmpty ? 'N/D' : sectorRows.first.sector,
      topSectorShare: sectorRows.isEmpty ? 0.0 : sectorRows.first.share,
      topCounterpartyName: counterpartyRows.isEmpty
          ? 'N/D'
          : counterpartyRows.first.counterpartyName,
      topCounterpartyShare:
          counterpartyRows.isEmpty ? 0.0 : counterpartyRows.first.share,
      sectorRows: sectorRows,
      countryRows: countryRows,
      regionRows: regionRows,
      prudentialRows: prudentialRows,
      riskWeightRows: riskWeightRows,
      rwaSectorRows: rwaSectorRows,
      counterpartyRows: counterpartyRows,
      rwaCounterpartyRows: rwaCounterpartyRows,
      exposureDetails: exposureDetails,
      sectorDistribution: _distribution(
        sectorRows.map((item) => (item.sector, item.grossAmount, item.share)),
      ),
      countryDistribution: _distribution(
        countryRows.map(
          (item) => (item.label, item.grossAmount, item.portfolioShare),
        ),
      ),
      regionDistribution: _distribution(
        regionRows.map(
          (item) => (item.label, item.grossAmount, item.portfolioShare),
        ),
      ),
      ratingDistribution: ratingDistribution,
      quality: _quality(details, totalGross, totalEad, trends),
      trends: trends,
      alerts: _alerts(
        latestDate: _latestDate(details),
        totalRwa: totalRwa,
        hhi: hhi,
        sectorRows: sectorRows,
        counterpartyRows: counterpartyRows,
        countryRows: countryRows,
        rwaCounterpartyRows: rwaCounterpartyRows,
        trends: trends,
      ),
    );
  }

  final double totalGross;
  final double totalEad;
  final double totalRwa;
  final double totalCapital;
  final double hhi;
  final String hhiBadge;
  final String topSectorLabel;
  final double topSectorShare;
  final String topCounterpartyName;
  final double topCounterpartyShare;
  final List<SectorConcentrationRow> sectorRows;
  final List<ConcentrationBreakdownRow> countryRows;
  final List<ConcentrationBreakdownRow> regionRows;
  final List<ConcentrationBreakdownRow> prudentialRows;
  final List<RiskWeightBucketRow> riskWeightRows;
  final List<SectorConcentrationRow> rwaSectorRows;
  final List<ConcentrationExposureRow> counterpartyRows;
  final List<ConcentrationExposureRow> rwaCounterpartyRows;
  final List<ConcentrationExposureDetail> exposureDetails;
  final List<DistributionEntry> sectorDistribution;
  final List<DistributionEntry> countryDistribution;
  final List<DistributionEntry> regionDistribution;
  final List<DistributionEntry> ratingDistribution;
  final PortfolioQualitySummary quality;
  final List<ConcentrationTrendPoint> trends;
  final List<ConcentrationAlert> alerts;
}

class _DetailAccumulator {
  _DetailAccumulator(this.label);

  final Object label;
  var exposureCount = 0;
  var grossAmount = 0.0;
  var ead = 0.0;
  var rwa = 0.0;
  var sector = 'Non renseigné';
  var country = 'Non renseigné';

  void add(ConcentrationExposureDetail item) {
    exposureCount += 1;
    grossAmount += item.grossAmount;
    ead += item.ead;
    rwa += item.rwa;
    if (sector == 'Non renseigné' || sector.isEmpty) {
      sector = item.sector;
    }
    if (country == 'Non renseigné' || country.isEmpty) {
      country = item.country;
    }
  }

  double get averageRiskWeight => ead == 0 ? 0.0 : rwa / ead;
}

Map<Object, _DetailAccumulator> _groupDetails(
  List<ConcentrationExposureDetail> details,
  Object Function(ConcentrationExposureDetail item) keyOf,
) {
  final groups = <Object, _DetailAccumulator>{};
  for (final item in details) {
    final key = keyOf(item);
    groups.putIfAbsent(key, () => _DetailAccumulator(key)).add(item);
  }
  return groups;
}

List<SectorConcentrationRow> _sectorRows(
  Map<Object, _DetailAccumulator> groups,
  double totalGross,
  double totalRwa,
) {
  return groups.values
      .map(
        (item) => SectorConcentrationRow(
          sector: item.label.toString(),
          exposureCount: item.exposureCount,
          grossAmount: item.grossAmount,
          ead: item.ead,
          rwa: item.rwa,
          averageRiskWeight: item.averageRiskWeight,
          rwaShare: totalRwa == 0 ? 0.0 : item.rwa / totalRwa,
          share: totalGross == 0 ? 0.0 : item.grossAmount / totalGross,
        ),
      )
      .toList(growable: false);
}

List<ConcentrationBreakdownRow> _breakdownRows(
  Map<Object, _DetailAccumulator> groups,
  String group,
  double totalGross,
  double totalRwa,
) {
  return groups.values
      .map(
        (item) => ConcentrationBreakdownRow(
          label: item.label.toString(),
          group: group,
          exposureCount: item.exposureCount,
          grossAmount: item.grossAmount,
          ead: item.ead,
          rwa: item.rwa,
          averageRiskWeight: item.averageRiskWeight,
          portfolioShare: totalGross == 0 ? 0.0 : item.grossAmount / totalGross,
          rwaShare: totalRwa == 0 ? 0.0 : item.rwa / totalRwa,
        ),
      )
      .toList(growable: false);
}

List<ConcentrationExposureRow> _counterpartyRows(
  Map<Object, _DetailAccumulator> groups,
  double totalGross,
) {
  return groups.values
      .map(
        (item) => ConcentrationExposureRow(
          exposureId: '${item.exposureCount} dossier(s)',
          counterpartyName: item.label.toString(),
          country: item.country,
          sector: item.sector,
          segment: item.sector,
          grossAmount: item.grossAmount,
          ead: item.ead,
          rwa: item.rwa,
          averageRiskWeight: item.averageRiskWeight,
          share: totalGross == 0 ? 0.0 : item.grossAmount / totalGross,
        ),
      )
      .toList(growable: false);
}

List<RiskWeightBucketRow> _riskWeightRows(
  Map<Object, _DetailAccumulator> groups,
  double totalEad,
  double totalRwa,
) {
  return groups.entries
      .map(
        (entry) => RiskWeightBucketRow(
          label: _riskWeightBucketLabel(entry.key as double),
          weight: entry.key as double,
          exposureCount: entry.value.exposureCount,
          ead: entry.value.ead,
          rwa: entry.value.rwa,
          portfolioShare: totalEad == 0 ? 0.0 : entry.value.ead / totalEad,
          rwaShare: totalRwa == 0 ? 0.0 : entry.value.rwa / totalRwa,
        ),
      )
      .toList(growable: false);
}

List<DistributionEntry> _distribution(
  Iterable<(String, double, double)> rows,
) {
  return rows
      .map(
        (item) => DistributionEntry(
          label: item.$1,
          amount: item.$2,
          percentage: item.$3,
        ),
      )
      .toList(growable: false);
}

List<DistributionEntry> _ratingDistribution(
  List<ConcentrationExposureDetail> details,
  double totalGross,
) {
  final totals = <String, double>{
    for (final rating in _counterpartyRatingOrder) rating: 0.0,
  };
  for (final item in details) {
    final rating = _normalizedRatingBucket(item.rating);
    totals.update(
      rating,
      (value) => value + item.grossAmount,
      ifAbsent: () => item.grossAmount,
    );
  }

  return [
    for (final rating in _counterpartyRatingOrder)
      DistributionEntry(
        label: rating,
        amount: totals[rating] ?? 0.0,
        percentage:
            totalGross == 0 ? 0.0 : (totals[rating] ?? 0.0) / totalGross,
      ),
  ];
}

PortfolioQualitySummary _quality(
  List<ConcentrationExposureDetail> details,
  double totalGross,
  double totalEad,
  List<ConcentrationTrendPoint> trends,
) {
  final defaultRows = details.where((item) => item.isDefault).toList();
  final defaultGross =
      defaultRows.fold<double>(0.0, (sum, item) => sum + item.grossAmount);
  final weightedPd = details.fold<double>(
    0.0,
    (sum, item) => sum + item.pd * item.ead,
  );
  final weightedLgd = details.fold<double>(
    0.0,
    (sum, item) => sum + item.lgd * item.ead,
  );
  final estimatedProvision = defaultRows.fold<double>(
    0.0,
    (sum, item) => sum + item.estimatedProvision,
  );
  final nplTrend =
      trends.length < 2 ? 0.0 : trends.last.npl - trends[trends.length - 2].npl;

  return PortfolioQualitySummary(
    nplRatio: totalGross == 0 ? 0.0 : defaultGross / totalGross,
    defaultRate: details.isEmpty ? 0.0 : defaultRows.length / details.length,
    defaultGross: defaultGross,
    riskCoverage: defaultGross == 0 ? 0.0 : estimatedProvision / defaultGross,
    averagePd: totalEad == 0 ? 0.0 : weightedPd / totalEad,
    averageLgd: totalEad == 0 ? 0.0 : weightedLgd / totalEad,
    nplTrend: nplTrend,
    defaultTrend: nplTrend,
    coverageTrend: 0.0,
  );
}

List<ConcentrationTrendPoint> _trends(
  List<ConcentrationExposureDetail> details,
) {
  final groups = <DateTime, List<ConcentrationExposureDetail>>{};
  for (final item in details) {
    final key = DateTime(item.analysisDate.year, item.analysisDate.month);
    groups.putIfAbsent(key, () => <ConcentrationExposureDetail>[]).add(item);
  }
  final dates = groups.keys.toList()..sort();

  return [
    for (final date in dates)
      ConcentrationTrendPoint(
        label: _monthLabel(date),
        date: date,
        ead: groups[date]!.fold<double>(0.0, (sum, item) => sum + item.ead),
        rwa: groups[date]!.fold<double>(0.0, (sum, item) => sum + item.rwa),
        npl: _nplRatio(groups[date]!),
        hhi: _hhiForDetails(groups[date]!),
      ),
  ];
}

List<ConcentrationAlert> _alerts({
  required DateTime latestDate,
  required double totalRwa,
  required double hhi,
  required List<SectorConcentrationRow> sectorRows,
  required List<ConcentrationExposureRow> counterpartyRows,
  required List<ConcentrationBreakdownRow> countryRows,
  required List<ConcentrationExposureRow> rwaCounterpartyRows,
  required List<ConcentrationTrendPoint> trends,
}) {
  final alerts = <ConcentrationAlert>[];
  // Fonds propres estimés en l'absence de saisie des fonds propres réels :
  // hypothèse d'un établissement au niveau de l'exigence globale de
  // solvabilité UMOA (9 % + coussin de conservation 2,5 % = 11,5 % des RWA).
  final ownFundsEstimate = totalRwa * 0.115;

  if (sectorRows.isNotEmpty && sectorRows.first.share > 0.25) {
    alerts.add(
      ConcentrationAlert(
        level: 'Secteur',
        severity: sectorRows.first.share > 0.40 ? 'Élevé' : 'Moyen',
        date: latestDate,
        message:
            '${sectorRows.first.sector} concentre ${AppFormatters.percent(sectorRows.first.share)} du portefeuille.',
        recommendation:
            'Revoir les limites sectorielles et arbitrer les nouvelles entrées.',
      ),
    );
  }
  if (counterpartyRows.isNotEmpty && ownFundsEstimate > 0) {
    final ratio = counterpartyRows.first.grossAmount / ownFundsEstimate;
    if (ratio > 0.10) {
      alerts.add(
        ConcentrationAlert(
          level: 'Client',
          severity: ratio > 0.25 ? 'Élevé' : 'Moyen',
          date: latestDate,
          message:
              '${counterpartyRows.first.counterpartyName} atteint ${AppFormatters.percent(ratio)} des fonds propres estimés.',
          recommendation:
              'Contrôler la limite single-name, les garanties et les sûretés mobilisables.',
        ),
      );
    }
  }
  if (hhi > 1800) {
    alerts.add(
      ConcentrationAlert(
        level: 'HHI',
        severity: hhi > 2500 ? 'Élevé' : 'Moyen',
        date: latestDate,
        message: 'Indice HHI à ${hhi.toStringAsFixed(0)}.',
        recommendation:
            'Diversifier le portefeuille ou renforcer les seuils internes.',
      ),
    );
  }
  if (countryRows.isNotEmpty && countryRows.first.portfolioShare > 0.25) {
    alerts.add(
      ConcentrationAlert(
        level: 'Pays',
        severity: countryRows.first.portfolioShare > 0.40 ? 'Élevé' : 'Moyen',
        date: latestDate,
        message:
            '${countryRows.first.label} représente ${AppFormatters.percent(countryRows.first.portfolioShare)} du portefeuille.',
        recommendation:
            'Tester les limites pays et les scénarios de stress souverain.',
      ),
    );
  }
  if (rwaCounterpartyRows.isNotEmpty && totalRwa > 0) {
    final topFiveRwa = rwaCounterpartyRows
        .take(5)
        .fold<double>(0.0, (sum, item) => sum + item.rwa);
    final share = topFiveRwa / totalRwa;
    if (share > 0.40) {
      alerts.add(
        ConcentrationAlert(
          level: 'RWA',
          severity: share > 0.60 ? 'Élevé' : 'Moyen',
          date: latestDate,
          message:
              '${AppFormatters.percent(share)} du RWA est porté par moins de 5 contreparties.',
          recommendation:
              'Prioriser les revues de rating, garanties et arbitrages RWA.',
        ),
      );
    }
  }
  if (trends.length >= 2 && trends[trends.length - 2].ead > 0) {
    final growth = (trends.last.ead - trends[trends.length - 2].ead) /
        trends[trends.length - 2].ead;
    if (growth > 0.15) {
      alerts.add(
        ConcentrationAlert(
          level: 'Croissance',
          severity: growth > 0.30 ? 'Élevé' : 'Moyen',
          date: latestDate,
          message:
              'Croissance EAD de ${AppFormatters.percent(growth)} sur la dernière période.',
          recommendation:
              'Vérifier les nouveaux engagements et leur consommation RWA.',
        ),
      );
    }
  }

  return alerts;
}

DateTime _latestDate(List<ConcentrationExposureDetail> details) {
  if (details.isEmpty) {
    return DateTime.now();
  }
  return details
      .map((item) => item.analysisDate)
      .reduce((left, right) => left.isAfter(right) ? left : right);
}

double _hhi(Iterable<double> shares) {
  return shares.fold<double>(
    0.0,
    (sum, share) => sum + math.pow(share * 100, 2).toDouble(),
  );
}

double _hhiForDetails(List<ConcentrationExposureDetail> details) {
  final totalGross =
      details.fold<double>(0.0, (sum, item) => sum + item.grossAmount);
  if (totalGross == 0) {
    return 0.0;
  }
  final totals = <String, double>{};
  for (final item in details) {
    totals.update(
      item.counterpartyName,
      (value) => value + item.grossAmount,
      ifAbsent: () => item.grossAmount,
    );
  }
  return _hhi(totals.values.map((amount) => amount / totalGross));
}

String _hhiBadge(double hhi) {
  if (hhi >= 1800) {
    return 'Élevé';
  }
  if (hhi >= 1000) {
    return 'Moyen';
  }
  return 'Faible';
}

double _riskWeightBucket(double weight) {
  const buckets = <double>[0.0, 0.20, 0.50, 0.75, 1.0, 1.50];
  return buckets.reduce(
    (closest, bucket) =>
        (weight - bucket).abs() < (weight - closest).abs() ? bucket : closest,
  );
}

String _riskWeightBucketLabel(double weight) {
  return '${(weight * 100).round()} %';
}

double _nplRatio(List<ConcentrationExposureDetail> details) {
  final totalGross =
      details.fold<double>(0.0, (sum, item) => sum + item.grossAmount);
  if (totalGross == 0) {
    return 0.0;
  }
  final defaultGross = details
      .where((item) => item.isDefault)
      .fold<double>(0.0, (sum, item) => sum + item.grossAmount);
  return defaultGross / totalGross;
}

String _normalizedRatingBucket(String rating) {
  final raw = rating.trim();
  if (raw.isEmpty || raw == '-') {
    return 'Non noté';
  }

  var normalized = raw
      .toUpperCase()
      .replaceAll('É', 'E')
      .replaceAll('È', 'E')
      .replaceAll('Ê', 'E')
      .replaceAll('Ë', 'E')
      .replaceAll('À', 'A')
      .replaceAll('Â', 'A')
      .replaceAll('Î', 'I')
      .replaceAll('Ï', 'I')
      .replaceAll('Ô', 'O')
      .replaceAll('Û', 'U')
      .replaceAll('Ù', 'U')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (normalized == 'NON NOTE' ||
      normalized == 'NON NOTEE' ||
      normalized == 'NON RENSEIGNE' ||
      normalized == 'NR' ||
      normalized == 'N/R' ||
      normalized == 'ND' ||
      normalized == 'N.D.' ||
      normalized == 'N/A') {
    return 'Non noté';
  }

  normalized = normalized.replaceAll(' ', '');
  if (normalized == '<B-' || normalized.startsWith('CCC')) {
    return '< B-';
  }
  if (normalized == 'CC' ||
      normalized == 'C' ||
      normalized == 'D' ||
      normalized == 'SD') {
    return '< B-';
  }
  if (normalized.contains('/')) {
    for (final part in normalized.split('/')) {
      final bucket = _normalizedRatingBucket(part);
      if (bucket != 'Non noté' && bucket != '< B-') {
        return bucket;
      }
    }
    return '< B-';
  }

  for (final rating in _counterpartyRatingOrder) {
    if (normalized == rating.replaceAll(' ', '').toUpperCase()) {
      return rating;
    }
  }

  return 'Non noté';
}

String _monthLabel(DateTime date) {
  const months = [
    'Janv.',
    'Févr.',
    'Mars',
    'Avr.',
    'Mai',
    'Juin',
    'Juil.',
    'Août',
    'Sept.',
    'Oct.',
    'Nov.',
    'Déc.',
  ];
  return months[date.month - 1];
}

TextStyle _tableHeaderStyle() {
  return const TextStyle(
    color: AppTheme.muted,
    fontWeight: FontWeight.w600,
    fontSize: 11,
  );
}

String _amountMd(double value, {int maxDecimals = 1}) {
  final scaled = value / PortfolioAmountUnitPreference.current.divisor;
  final decimals = maxDecimals.clamp(0, 5);

  if (scaled == 0) {
    return '0';
  }

  if (decimals > 0 &&
      PortfolioAmountUnitPreference.current.divisor >= 1000000000) {
    final precisionFloor = math.pow(10, -decimals).toDouble();
    if (scaled.abs() < precisionFloor) {
      final minimumLabel = '0,${''.padLeft(decimals - 1, '0')}1';
      return scaled.isNegative ? '-$minimumLabel' : '< $minimumLabel';
    }
  }

  // Fall through to normal formatting.

  return _formatFullFrenchNumber(scaled, decimals);
}

String _amountUnitLabel() => PortfolioAmountUnitPreference.current.label;

String _amountUnitFcfaLabel() => '${_amountUnitLabel()} FCFA';

String _formatFullFrenchNumber(double value, int decimals) {
  final fixed = value.abs().toStringAsFixed(decimals);
  final trimmed = decimals == 0
      ? fixed
      : fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  final parts = trimmed.split('.');
  final integer = parts.first;
  final decimal = parts.length > 1 ? parts[1] : '';
  final groups = <String>[];

  for (var end = integer.length; end > 0; end -= 3) {
    final start = math.max(0, end - 3);
    groups.insert(0, integer.substring(start, end));
  }

  final sign = value.isNegative ? '-' : '';
  final integerLabel = groups.isEmpty ? '0' : groups.join(' ');
  return decimal.isEmpty ? '$sign$integerLabel' : '$sign$integerLabel,$decimal';
}

class _RwaExposureColumnSpec {
  const _RwaExposureColumnSpec(
    this.label,
    this.width, {
    this.align = TextAlign.left,
  });

  final String label;
  final double width;
  final TextAlign align;

  _RwaExposureColumnSpec copyWith({double? width}) {
    return _RwaExposureColumnSpec(
      label,
      width ?? this.width,
      align: align,
    );
  }
}

const List<_RwaExposureColumnSpec> _rwaExposureColumns = [
  _RwaExposureColumnSpec('ID exposition', 118),
  _RwaExposureColumnSpec('Contrepartie', 230),
  _RwaExposureColumnSpec('Catégorie', 160),
  _RwaExposureColumnSpec('Pays', 120),
  _RwaExposureColumnSpec('EAD', 132, align: TextAlign.right),
  _RwaExposureColumnSpec('RWA', 132, align: TextAlign.right),
  _RwaExposureColumnSpec('Pondération', 122, align: TextAlign.center),
  _RwaExposureColumnSpec('Couverture CRM', 144, align: TextAlign.center),
  _RwaExposureColumnSpec('Contribution RWA', 164),
];

class _RwaExposureTableCard extends StatefulWidget {
  const _RwaExposureTableCard({
    required this.rows,
    required this.totalRwa,
  });

  final List<ConcentrationExposureDetail> rows;
  final double totalRwa;

  @override
  State<_RwaExposureTableCard> createState() => _RwaExposureTableCardState();
}

class _RwaExposureTableCardState extends State<_RwaExposureTableCard> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  String? _selectedRowId;
  var _sortColumnIndex = 5;
  var _sortAscending = false;

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final sortedRows = _sortedRows(rows);

    return SectionCard(
      title: '',
      child: rows.isEmpty
          ? const _EmptyInline(
              message:
                  'Aucune exposition RWA disponible sur le périmètre filtré.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RwaExposureSummaryStrip(
                  rows: rows,
                  totalRwa: widget.totalRwa,
                ),
                const SizedBox(height: 6),
                const _RwaAmountUnitLegend(),
                const SizedBox(height: 6),
                Expanded(child: _buildTable(context, sortedRows)),
              ],
            ),
    );
  }

  List<ConcentrationExposureDetail> _sortedRows(
    List<ConcentrationExposureDetail> rows,
  ) {
    final sortedRows = rows.toList(growable: false);
    sortedRows.sort((left, right) {
      final comparison = _compareRows(left, right, _sortColumnIndex);
      if (comparison != 0) {
        return _sortAscending ? comparison : -comparison;
      }
      return _compareText(left.id, right.id);
    });
    return sortedRows;
  }

  int _compareRows(
    ConcentrationExposureDetail left,
    ConcentrationExposureDetail right,
    int columnIndex,
  ) {
    return switch (columnIndex) {
      0 => _compareText(left.id, right.id),
      1 => _compareText(left.counterpartyName, right.counterpartyName),
      2 => _compareText(left.prudentialCategory, right.prudentialCategory),
      3 => _compareText(left.country, right.country),
      4 => left.ead.compareTo(right.ead),
      5 => left.rwa.compareTo(right.rwa),
      6 => left.riskWeight.compareTo(right.riskWeight),
      7 => left.crmCoverageRatio.compareTo(right.crmCoverageRatio),
      8 => _rwaContribution(left).compareTo(_rwaContribution(right)),
      _ => 0,
    };
  }

  int _compareText(String left, String right) {
    return left.toLowerCase().compareTo(right.toLowerCase());
  }

  double _rwaContribution(ConcentrationExposureDetail row) {
    if (widget.totalRwa <= 0) return 0;
    return row.rwa / widget.totalRwa;
  }

  void _sortByColumn(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = !_isNumericRwaColumn(columnIndex);
      }
    });

    if (_verticalController.hasClients) {
      _verticalController.jumpTo(0);
    }
  }

  bool _isNumericRwaColumn(int columnIndex) {
    return switch (columnIndex) {
      4 || 5 || 6 || 7 || 8 => true,
      _ => false,
    };
  }

  List<_RwaExposureColumnSpec> _expandedColumnsForWidth(
    double availableWidth,
    int fixedColumnIndex,
    List<int> scrollableColumnIndexes,
  ) {
    final fixedWidth = _rwaExposureColumns[fixedColumnIndex].width;
    final scrollableViewport = math.max(0.0, availableWidth - fixedWidth);
    final baseScrollableWidth = scrollableColumnIndexes.fold<double>(
      0.0,
      (sum, index) => sum + _rwaExposureColumns[index].width,
    );

    if (scrollableViewport <= baseScrollableWidth || baseScrollableWidth <= 0) {
      return _rwaExposureColumns;
    }

    final extraWidth = scrollableViewport - baseScrollableWidth;
    return List<_RwaExposureColumnSpec>.generate(
      _rwaExposureColumns.length,
      (index) {
        final column = _rwaExposureColumns[index];
        if (!scrollableColumnIndexes.contains(index)) {
          return column;
        }
        final ratio = column.width / baseScrollableWidth;
        return column.copyWith(width: column.width + extraWidth * ratio);
      },
      growable: false,
    );
  }

  Widget _buildTable(
    BuildContext context,
    List<ConcentrationExposureDetail> rows,
  ) {
    const headerHeight = 38.0;
    const rowHeight = 45.0;
    final bodyHeight = rows.length <= 7 ? rows.length * rowHeight : 306.0;
    final tableHeight = headerHeight + bodyHeight;
    const leftColumnIndex = 0;
    final scrollableColumnIndexes = List<int>.generate(
      _rwaExposureColumns.length - 1,
      (index) => index + 1,
      growable: false,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveColumns = _expandedColumnsForWidth(
          constraints.maxWidth,
          leftColumnIndex,
          scrollableColumnIndexes,
        );
        final scrollableColumns = scrollableColumnIndexes
            .map((index) => effectiveColumns[index])
            .toList(growable: false);
        final scrollableWidth = scrollableColumns.fold<double>(
          0.0,
          (sum, column) => sum + column.width,
        );
        final fixedWidth = effectiveColumns[leftColumnIndex].width;
        final centerViewportWidth =
            math.max(0.0, constraints.maxWidth - fixedWidth);
        final needsHorizontalScroll = scrollableWidth > centerViewportWidth;

        return Container(
          height: tableHeight,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(_concentrationRadius),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RwaExposurePinnedColumn(
                rows: rows,
                columns: effectiveColumns,
                columnIndex: leftColumnIndex,
                totalRwa: widget.totalRwa,
                verticalController: _verticalController,
                headerHeight: headerHeight,
                rowHeight: rowHeight,
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                onSort: _sortByColumn,
                selectedRowId: _selectedRowId,
                onRowSelected: _selectRow,
              ),
              Expanded(
                child: Scrollbar(
                  controller: _horizontalController,
                  thumbVisibility: needsHorizontalScroll,
                  notificationPredicate: (notification) =>
                      notification.metrics.axis == Axis.horizontal,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: scrollableWidth,
                      height: tableHeight,
                      child: Column(
                        children: [
                          _RwaExposureTableHeader(
                            columns: scrollableColumns,
                            columnIndexes: scrollableColumnIndexes,
                            sortColumnIndex: _sortColumnIndex,
                            sortAscending: _sortAscending,
                            onSort: _sortByColumn,
                          ),
                          Expanded(
                            child: Scrollbar(
                              controller: _verticalController,
                              thumbVisibility: rows.length > 7,
                              notificationPredicate: (notification) =>
                                  notification.metrics.axis == Axis.vertical,
                              child: ListView.builder(
                                addSemanticIndexes: false,
                                controller: _verticalController,
                                physics: const ClampingScrollPhysics(),
                                itemExtent: rowHeight,
                                itemCount: rows.length,
                                itemBuilder: (context, index) {
                                  return _RwaExposureDataRow(
                                    row: rows[index],
                                    index: index,
                                    totalRwa: widget.totalRwa,
                                    columns: effectiveColumns,
                                    columnIndexes: scrollableColumnIndexes,
                                    selected: _selectedRowId == rows[index].id,
                                    onSelected: _selectRow,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectRow(ConcentrationExposureDetail row) {
    if (_selectedRowId == row.id) return;
    setState(() => _selectedRowId = row.id);
  }
}

class _RwaExposureSummaryStrip extends StatelessWidget {
  const _RwaExposureSummaryStrip({
    required this.rows,
    required this.totalRwa,
  });

  final List<ConcentrationExposureDetail> rows;
  final double totalRwa;

  @override
  Widget build(BuildContext context) {
    final totalEad = rows.fold<double>(0.0, (sum, item) => sum + item.ead);
    final averageRiskWeight = totalEad <= 0 ? 0.0 : totalRwa / totalEad;
    final topExposure = rows.first;
    final topShare =
        totalRwa <= 0 ? 0.0 : (topExposure.rwa / totalRwa).clamp(0.0, 1.0);
    final defaultCount = rows.where((item) => item.isDefault).length;
    final tiles = [
      _RwaSummaryTile(
        label: 'RWA crédit',
        value: _amountMd(totalRwa),
        caption: 'capital consommé',
        color: AppTheme.accent,
      ),
      _RwaSummaryTile(
        label: 'EAD total',
        value: _amountMd(totalEad),
        caption: 'base exposée',
        color: AppTheme.success,
      ),
      _RwaSummaryTile(
        label: 'RW moyen',
        value: AppFormatters.percent(averageRiskWeight),
        caption: 'pondération moyenne',
        color: _riskWeightColor(averageRiskWeight),
      ),
      _RwaSummaryTile(
        label: 'Plus fort contributeur',
        value: AppFormatters.percent(topShare.toDouble()),
        caption: topExposure.counterpartyName,
        color: AppTheme.warning,
      ),
      _RwaSummaryTile(
        label: 'Défauts',
        value: '$defaultCount',
        caption: 'expositions marquées',
        color: defaultCount > 0 ? AppTheme.danger : AppTheme.success,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          AppTheme.accent.withValues(alpha: 0.035),
          Theme.of(context).cardColor,
        ),
        borderRadius: BorderRadius.circular(_concentrationRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 6.0;
          if (constraints.maxWidth >= 760) {
            return Row(
              children: [
                for (var index = 0; index < tiles.length; index++) ...[
                  Expanded(child: tiles[index]),
                  if (index != tiles.length - 1) const SizedBox(width: gap),
                ],
              ],
            );
          }

          final tileWidth = (constraints.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final tile in tiles)
                SizedBox(
                  width: tileWidth,
                  child: tile,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RwaSummaryTile extends StatelessWidget {
  const _RwaSummaryTile({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  final String label;
  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final surface = Color.alphaBlend(
      color.withValues(alpha: 0.022),
      Theme.of(context).cardColor,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_concentrationRadius),
        border: Border.all(
          color: color.withValues(alpha: 0.34),
          width: 0.85,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.muted,
                  fontSize: 10.2,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
          ),
        ],
      ),
    );
  }
}

class _RwaAmountUnitLegend extends StatelessWidget {
  const _RwaAmountUnitLegend();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: AppColors.concentrationPrimary,
          borderRadius: BorderRadius.circular(_concentrationRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.concentrationPrimary.withValues(alpha: 0.16),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.number,
              size: 12,
              color: Colors.white,
            ),
            const SizedBox(width: 5),
            Text(
              'Montants en ${_amountUnitFcfaLabel()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 10.4,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RwaExposureTableHeader extends StatelessWidget {
  const _RwaExposureTableHeader({
    required this.columns,
    required this.columnIndexes,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
  });

  final List<_RwaExposureColumnSpec> columns;
  final List<int> columnIndexes;
  final int sortColumnIndex;
  final bool sortAscending;
  final ValueChanged<int> onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      color: AppTheme.sidebarLight,
      child: Row(
        children: [
          for (var index = 0; index < columns.length; index++)
            _RwaExposureHeaderCell(
              column: columns[index],
              columnIndex: columnIndexes[index],
              sorted: sortColumnIndex == columnIndexes[index],
              ascending: sortAscending,
              onSort: onSort,
            ),
        ],
      ),
    );
  }
}

class _RwaExposureHeaderCell extends StatelessWidget {
  const _RwaExposureHeaderCell({
    required this.column,
    required this.columnIndex,
    required this.sorted,
    required this.ascending,
    required this.onSort,
  });

  final _RwaExposureColumnSpec column;
  final int columnIndex;
  final bool sorted;
  final bool ascending;
  final ValueChanged<int> onSort;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: column.width,
      height: double.infinity,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSort(columnIndex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: sorted
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: sorted
                      ? Colors.white.withValues(alpha: 0.78)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: _headerAlignment(column.align),
                  child: Padding(
                    padding: EdgeInsets.only(right: sorted ? 12 : 0),
                    child: Text(
                      column.label,
                      textAlign: column.align,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontSize: 11.2,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                            height: 1,
                          ),
                    ),
                  ),
                ),
                if (sorted)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      ascending
                          ? CupertinoIcons.chevron_up
                          : CupertinoIcons.chevron_down,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Alignment _headerAlignment(TextAlign align) {
  return switch (align) {
    TextAlign.right || TextAlign.end => Alignment.centerRight,
    TextAlign.center || TextAlign.justify => Alignment.center,
    _ => Alignment.centerLeft,
  };
}

class _RwaExposurePinnedColumn extends StatelessWidget {
  const _RwaExposurePinnedColumn({
    required this.rows,
    required this.columns,
    required this.columnIndex,
    required this.totalRwa,
    required this.verticalController,
    required this.headerHeight,
    required this.rowHeight,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
    required this.selectedRowId,
    required this.onRowSelected,
  });

  final List<ConcentrationExposureDetail> rows;
  final List<_RwaExposureColumnSpec> columns;
  final int columnIndex;
  final double totalRwa;
  final ScrollController verticalController;
  final double headerHeight;
  final double rowHeight;
  final int sortColumnIndex;
  final bool sortAscending;
  final ValueChanged<int> onSort;
  final String? selectedRowId;
  final ValueChanged<ConcentrationExposureDetail> onRowSelected;

  @override
  Widget build(BuildContext context) {
    final column = columns[columnIndex];
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.76);
    final shadowColor = const Color(0xFF0F172A).withValues(alpha: 0.08);
    final pinnedRows = Column(
      children: List.generate(
        rows.length,
        (index) => SizedBox(
          height: rowHeight,
          child: _RwaExposureDataRow(
            row: rows[index],
            index: index,
            totalRwa: totalRwa,
            columns: columns,
            columnIndexes: [columnIndex],
            selected: selectedRowId == rows[index].id,
            onSelected: onRowSelected,
            showSelectionStripe: true,
          ),
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          right: BorderSide(color: dividerColor),
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SizedBox(
        width: column.width,
        child: Column(
          children: [
            SizedBox(
              height: headerHeight,
              child: _RwaExposureTableHeader(
                columns: [column],
                columnIndexes: [columnIndex],
                sortColumnIndex: sortColumnIndex,
                sortAscending: sortAscending,
                onSort: onSort,
              ),
            ),
            Expanded(
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: verticalController,
                  builder: (context, child) {
                    final offset = verticalController.hasClients
                        ? verticalController.offset
                        : 0.0;
                    return Transform.translate(
                      offset: Offset(0, -offset),
                      child: child,
                    );
                  },
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: SizedBox(
                      height: rows.length * rowHeight,
                      child: pinnedRows,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RwaExposureDataRow extends StatefulWidget {
  const _RwaExposureDataRow({
    required this.row,
    required this.index,
    required this.totalRwa,
    required this.columns,
    required this.columnIndexes,
    required this.selected,
    required this.onSelected,
    this.showSelectionStripe = false,
  });

  final ConcentrationExposureDetail row;
  final int index;
  final double totalRwa;
  final List<_RwaExposureColumnSpec> columns;
  final List<int> columnIndexes;
  final bool selected;
  final ValueChanged<ConcentrationExposureDetail> onSelected;
  final bool showSelectionStripe;

  @override
  State<_RwaExposureDataRow> createState() => _RwaExposureDataRowState();
}

class _RwaExposureDataRowState extends State<_RwaExposureDataRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final rwaShare = widget.totalRwa <= 0
        ? 0.0
        : (row.rwa / widget.totalRwa).clamp(0.0, 1.0).toDouble();
    final riskColor = _riskWeightColor(row.riskWeight);
    final baseColor = widget.selected
        ? AppTheme.accent.withValues(alpha: 0.12)
        : widget.index.isEven
            ? Theme.of(context).cardColor
            : Color.alphaBlend(
                AppTheme.accent.withValues(alpha: 0.025),
                Theme.of(context).cardColor,
              );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hovered = true);
      }),
      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hovered = false);
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSelected(row),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: _hovered && !widget.selected
                ? Color.alphaBlend(
                    AppTheme.accent.withValues(alpha: 0.055),
                    Theme.of(context).cardColor,
                  )
                : baseColor,
          ),
          foregroundDecoration: BoxDecoration(
            border: Border(
              left: widget.selected && widget.showSelectionStripe
                  ? const BorderSide(color: AppTheme.accent, width: 2.5)
                  : BorderSide.none,
              bottom: BorderSide(
                color: widget.selected
                    ? AppTheme.accent.withValues(alpha: 0.26)
                    : Theme.of(context).dividerColor.withValues(alpha: 0.72),
              ),
            ),
          ),
          child: Row(
            children: [
              for (final columnIndex in widget.columnIndexes)
                _buildCell(
                  context,
                  columnIndex,
                  row,
                  rwaShare,
                  riskColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    int columnIndex,
    ConcentrationExposureDetail row,
    double rwaShare,
    Color riskColor,
  ) {
    final spec = widget.columns[columnIndex];
    return switch (columnIndex) {
      0 => _RwaTextCell(
          spec: spec,
          child: Text(
            row.id,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.text,
                  fontSize: 12,
                  fontFamily: AppTheme.dataFontFamily,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
        ),
      1 => _RwaTextCell(
          spec: spec,
          child: Text(
            row.counterpartyName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      2 => _RwaTextCell(
          spec: spec,
          child: Text(
            row.prudentialCategory,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      3 => _RwaTextCell(
          spec: spec,
          child: Text(
            row.country,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      4 => _RwaTextCell(
          spec: spec,
          child: _RwaAmountText(
            label: _amountMd(row.ead, maxDecimals: 5),
            color: AppTheme.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      5 => _RwaTextCell(
          spec: spec,
          child: _RwaAmountText(
            label: _amountMd(row.rwa, maxDecimals: 5),
            color: AppTheme.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
      6 => _RwaTextCell(
          spec: spec,
          child: Align(
            alignment: Alignment.center,
            child: _RwaBadge(
              label: AppFormatters.percent(row.riskWeight),
              color: riskColor,
            ),
          ),
        ),
      7 => _RwaTextCell(
          spec: spec,
          child: Align(
            alignment: Alignment.center,
            child: _RwaBadge(
              label: AppFormatters.percent(row.crmCoverageRatio),
              color: _crmCoverageColor(row.crmCoverageRatio),
            ),
          ),
        ),
      8 => _RwaTextCell(
          spec: spec,
          child: _RwaShareCell(share: rwaShare),
        ),
      _ => _RwaTextCell(
          spec: spec,
          child: const SizedBox.shrink(),
        ),
    };
  }
}

class _RwaTextCell extends StatelessWidget {
  const _RwaTextCell({
    required this.spec,
    required this.child,
  });

  final _RwaExposureColumnSpec spec;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: spec.width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: DefaultTextStyle.merge(
          textAlign: spec.align,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
          child: child,
        ),
      ),
    );
  }
}

class _RwaAmountText extends StatelessWidget {
  const _RwaAmountText({
    required this.label,
    required this.color,
    required this.fontWeight,
  });

  final String label;
  final Color color;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          label,
          maxLines: 1,
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontSize: 12,
                fontWeight: fontWeight,
                height: 1,
              ),
        ),
      ),
    );
  }
}

class _RwaShareCell extends StatelessWidget {
  const _RwaShareCell({required this.share});

  final double share;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppFormatters.percent(share),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.text,
                fontSize: 11.6,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(_concentrationRadius),
          child: Stack(
            children: [
              Container(
                height: 4,
                color: AppTheme.border.withValues(alpha: 0.72),
              ),
              FractionallySizedBox(
                widthFactor: share.clamp(0.0, 1.0).toDouble(),
                child: Container(
                  height: 4,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Color _crmCoverageColor(double value) {
  if (value >= 0.50) return AppTheme.success;
  if (value > 0) return AppColors.qualityAverage;
  return AppTheme.muted;
}

class _RwaBadge extends StatelessWidget {
  const _RwaBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 58),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(_concentrationRadius),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: 10.4,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
      ),
    );
  }
}

enum _GeographyCardMode { countries, zones }

class _IssuerResidenceCountryCard extends StatefulWidget {
  const _IssuerResidenceCountryCard({
    required this.countryRows,
    required this.zoneRows,
  });

  final List<DistributionEntry> countryRows;
  final List<DistributionEntry> zoneRows;

  @override
  State<_IssuerResidenceCountryCard> createState() =>
      _IssuerResidenceCountryCardState();
}

class _IssuerResidenceCountryCardState
    extends State<_IssuerResidenceCountryCard> {
  var _mode = _GeographyCardMode.zones;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppTheme.darkBorder : AppTheme.border;
    final showingCountries = _mode == _GeographyCardMode.countries;
    final title = showingCountries
        ? 'Top 10 des pays de résidence émetteurs'
        : 'Concentration géographique';

    return Card(
      margin: const EdgeInsets.all(6),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.concentrationPrimary,
                          fontSize: 13.4,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                _GeoCardModeSelector(
                  mode: _mode,
                  onChanged: (mode) => setState(() => _mode = mode),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Divider(color: border),
            const SizedBox(height: 7),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                child: showingCountries
                    ? _IssuerResidenceCountryBars(
                        key: const ValueKey('countries'),
                        rows: widget.countryRows,
                      )
                    : _ZoneDistributionView(
                        key: const ValueKey('zones'),
                        rows: widget.zoneRows,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeoCardModeSelector extends StatelessWidget {
  const _GeoCardModeSelector({
    required this.mode,
    required this.onChanged,
  });

  final _GeographyCardMode mode;
  final ValueChanged<_GeographyCardMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ModeSwitchGroup(
      items: [
        _ModeSwitchItem(
          label: 'Pays',
          icon: CupertinoIcons.flag,
          selected: mode == _GeographyCardMode.countries,
          onTap: () => onChanged(_GeographyCardMode.countries),
        ),
        _ModeSwitchItem(
          label: 'Zones',
          icon: CupertinoIcons.globe,
          selected: mode == _GeographyCardMode.zones,
          onTap: () => onChanged(_GeographyCardMode.zones),
        ),
      ],
    );
  }
}

class _ModeSwitchGroup extends StatelessWidget {
  const _ModeSwitchGroup({required this.items});

  final List<_ModeSwitchItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _ModeSwitchButton(item: items[index]),
          if (index != items.length - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _ModeSwitchItem {
  const _ModeSwitchItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
}

class _ModeSwitchButton extends StatelessWidget {
  const _ModeSwitchButton({required this.item});

  final _ModeSwitchItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.selected ? Colors.white : AppColors.concentrationPrimary;
    final background = item.selected
        ? AppColors.concentrationPrimary
        : AppColors.concentrationPrimary.withValues(alpha: 0.065);

    return Tooltip(
      message: item.label,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: item.selected
                  ? AppColors.concentrationPrimary
                  : AppColors.concentrationPrimary.withValues(alpha: 0.26),
            ),
            boxShadow: item.selected
                ? [
                    BoxShadow(
                      color: AppColors.concentrationPrimary
                          .withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 12, color: color),
              const SizedBox(width: 5),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IssuerResidenceCountryBars extends StatelessWidget {
  const _IssuerResidenceCountryBars({
    super.key,
    required this.rows,
  });

  final List<DistributionEntry> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyInline();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final rowHeight = constraints.maxHeight / rows.length;
        return Column(
          children: List.generate(rows.length, (index) {
            final row = rows[index];
            return SizedBox(
              height: rowHeight,
              child: _HorizontalShareRow(
                label: row.label,
                share: row.percentage,
                labelWidth: 124,
                color: AppColors.concentrationPrimary,
              ),
            );
          }),
        );
      },
    );
  }
}

class _ZoneDistributionView extends StatelessWidget {
  const _ZoneDistributionView({
    super.key,
    required this.rows,
  });

  final List<DistributionEntry> rows;

  @override
  Widget build(BuildContext context) {
    final entries = _standardZoneEntries(rows);
    final activeEntries = entries
        .where((item) => item.amount > 0 || item.percentage > 0)
        .toList(growable: false);
    if (activeEntries.isEmpty) {
      return const _EmptyInline(
        message: 'Aucune répartition par zone disponible.',
      );
    }

    final dominant = activeEntries.reduce(
      (left, right) => right.percentage > left.percentage ? right : left,
    );
    final colors = [for (final entry in entries) _geoZoneColor(entry.label)];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        final donutSize = math.min(
          compact ? 116.0 : 132.0,
          math.max(96.0, constraints.maxHeight - 12),
        );
        final legendWidth = compact ? 190.0 : 230.0;
        final contentWidth = donutSize + legendWidth + 32;

        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: math.min(constraints.maxWidth, contentWidth),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: donutSize,
                  child: Center(
                    child: _ZoneDonutChart(
                      entries: activeEntries,
                      colors: [
                        for (final entry in activeEntries)
                          _geoZoneColor(entry.label),
                      ],
                      size: donutSize,
                      dominant: dominant,
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                SizedBox(
                  width: legendWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const SizedBox(width: 17),
                            Expanded(
                              child: Text(
                                'Zone',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.muted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Montant',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 45,
                              child: Text(
                                'Part',
                                textAlign: TextAlign.right,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.muted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (var index = 0; index < entries.length; index++)
                        _ZoneLegendRow(
                          entry: entries[index],
                          color: colors[index],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ZoneDonutChart extends StatefulWidget {
  const _ZoneDonutChart({
    required this.entries,
    required this.colors,
    required this.size,
    required this.dominant,
  });

  final List<DistributionEntry> entries;
  final List<Color> colors;
  final double size;
  final DistributionEntry dominant;

  @override
  State<_ZoneDonutChart> createState() => _ZoneDonutChartState();
}

class _ZoneDonutChartState extends State<_ZoneDonutChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final strokeWidth = widget.size * 0.15;
    final centerSpaceRadius = (widget.size / 2) - strokeWidth;
    final totalShare = widget.entries.fold<double>(0.0, (sum, item) => sum + item.percentage);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 0,
              centerSpaceRadius: centerSpaceRadius,
              sections: widget.entries.asMap().entries.map((e) {
                final isTouched = e.key == touchedIndex;
                final radius = isTouched ? strokeWidth * 1.25 : strokeWidth;
                final share = totalShare <= 0 ? 0.0 : (e.value.percentage / totalShare).clamp(0.0, 1.0);
                final value = share * 100;
                return PieChartSectionData(
                  color: widget.colors[e.key % widget.colors.length],
                  value: value <= 0 ? 0.0001 : value,
                  title: '',
                  radius: radius,
                );
              }).toList(),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Concentration\npar zone\nmonétaire',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.text.withValues(alpha: 0.8),
                      fontSize: widget.size < 120 ? 8 : 10,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      letterSpacing: -0.2,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimatedVerticalBarChart extends StatefulWidget {
  final List<(double percent, Color color)> entries;
  const _AnimatedVerticalBarChart({required this.entries});

  @override
  State<_AnimatedVerticalBarChart> createState() => _AnimatedVerticalBarChartState();
}

class _AnimatedVerticalBarChartState extends State<_AnimatedVerticalBarChart> {
  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barTouchData: const BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index < 0 || index >= widget.entries.length) {
                  return const SizedBox.shrink();
                }
                const shortLabels = ['1-30', '31-90', '91-180', '>180'];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    shortLabels[index],
                    style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                );
              },
              reservedSize: 24,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value % 25 != 0) return const SizedBox.shrink();
                return Text(
                  '${value.toInt()}%',
                  style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                );
              },
              reservedSize: 32,
              interval: 25,
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) {
            return const FlLine(color: Color(0xFFE2E8F0), strokeWidth: 0.5, dashArray: [4, 4]);
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            bottom: BorderSide(color: Color(0xFF94A3B8), width: 0.5),
            left: BorderSide(color: Color(0xFF94A3B8), width: 0.5),
            top: BorderSide.none,
            right: BorderSide.none,
          ),
        ),
        barGroups: widget.entries.asMap().entries.map((e) {
          final percent = e.value.$1 * 100;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: percent <= 0 ? 0.5 : percent,
                color: e.value.$2,
                width: 14,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(3),
                  topRight: Radius.circular(3),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: 100,
                  color: e.value.$2.withValues(alpha: 0.08),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ZoneLegendRow extends StatelessWidget {
  const _ZoneLegendRow({
    required this.entry,
    required this.color,
  });

  final DistributionEntry entry;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(_concentrationRadius),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.text,
                    fontSize: 11.4,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_amountMd(entry.amount)} ${_amountUnitLabel()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.text.withValues(alpha: 0.65),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 45,
            child: Text(
              AppFormatters.percent(entry.percentage),
              maxLines: 1,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontSize: 11.2,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneMetricTile extends StatelessWidget {
  const _ZoneMetricTile({
    required this.label,
    required this.value,
    required this.color,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: emphasize ? 0.12 : 0.075),
        borderRadius: BorderRadius.circular(_concentrationRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.muted,
                  fontSize: 8.4,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontSize: emphasize ? 14.2 : 13.2,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
        ],
      ),
    );
  }
}

List<DistributionEntry> _standardZoneEntries(List<DistributionEntry> rows) {
  const labels = ['UEMOA', 'CEMAC', 'Hors zone'];
  final amounts = <String, double>{
    for (final label in labels) label: 0.0,
  };
  final percentages = <String, double>{
    for (final label in labels) label: 0.0,
  };

  for (final row in rows) {
    final label = _standardZoneLabel(row.label);
    amounts[label] = (amounts[label] ?? 0.0) + row.amount;
    percentages[label] = (percentages[label] ?? 0.0) + row.percentage;
  }

  return [
    for (final label in labels)
      DistributionEntry(
        label: label,
        amount: amounts[label] ?? 0.0,
        percentage: percentages[label] ?? 0.0,
      ),
  ];
}

String _standardZoneLabel(String label) {
  final normalized = label.toLowerCase();
  if (normalized.contains('cemac')) {
    return 'CEMAC';
  }
  if (normalized.contains('uemoa')) {
    return 'UEMOA';
  }
  return 'Hors zone';
}

Color _geoZoneColor(String label) {
  return switch (_standardZoneLabel(label)) {
    'UEMOA' => Colors.blue,
    'CEMAC' => const Color(0xFF0D9488),
    _ => AppColors.concentrationDeeper,
  };
}

class _SeeAllButton extends StatefulWidget {
  const _SeeAllButton({this.onPressed});
  final VoidCallback? onPressed;

  @override
  State<_SeeAllButton> createState() => _SeeAllButtonState();
}

class _SeeAllButtonState extends State<_SeeAllButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: (_hovered && widget.onPressed != null) ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: ElevatedButton(
          onPressed: widget.onPressed,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            overlayColor: Colors.transparent,
            elevation: _hovered ? 3 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: const Text(
            'Voir tout',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopCounterpartyExposureCard extends StatelessWidget {
  const _TopCounterpartyExposureCard({
    required this.rows,
    required this.allRows,
  });

  final List<ConcentrationExposureRow> rows;
  final List<ConcentrationExposureRow> allRows;

  void _showAllCounterparties(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : AppTheme.card,
          title: Text(
            'Toutes les expositions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.text,
                  fontWeight: FontWeight.w700,
                ),
          ),
          content: SizedBox(
            width: 800,
            height: MediaQuery.of(context).size.height * 0.7,
            child: ListView.separated(
              addSemanticIndexes: false,
              itemCount: allRows.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final row = allRows[index];
                final t = index / (allRows.isEmpty ? 1 : allRows.length);
                final c = t < 0.35
                    ? AppColors.concentrationDeeper
                    : t < 0.7
                        ? Colors.indigo
                        : Colors.blue;
                return SizedBox(
                  height: 28,
                  child: _HorizontalShareRow(
                    label: row.counterpartyName,
                    rank: index + 1,
                    share: row.share,
                    labelWidth: 500,
                    color: c,
                    valueColor: c,
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.text,
              ),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppTheme.darkBorder : AppTheme.border;

    return Card(
      margin: const EdgeInsets.all(6),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Top 10 des contreparties les plus exposées',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.concentrationPrimary,
                          fontSize: 13.4,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                  ),
                ),
                _SeeAllButton(
                  onPressed: rows.isEmpty
                      ? null
                      : () => _showAllCounterparties(context),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Divider(color: border),
            const SizedBox(height: 7),
            Expanded(
              child: _CounterpartyBars(rows: rows),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterpartyBars extends StatelessWidget {
  const _CounterpartyBars({required this.rows});

  final List<ConcentrationExposureRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyInline();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppTheme.darkBorder : AppTheme.border;

    return Column(
      children: List.generate(rows.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Divider(
            height: 1,
            thickness: 1,
            color: border.withValues(alpha: 0.5),
          );
        }
        
        final index = i ~/ 2;
        final row = rows[index];
        final t = index / (rows.isEmpty ? 1 : rows.length);
        final c = t < 0.35
            ? AppColors.concentrationDeeper
            : t < 0.7
                ? Colors.indigo
                : Colors.blue;
                
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: _HorizontalShareRow(
              label: row.counterpartyName,
              rank: index + 1,
              share: row.share,
              labelWidth: 260,
              color: c,
              valueColor: c,
            ),
          ),
        );
      }),
    );
  }
}

class _HorizontalShareRow extends StatefulWidget {
  const _HorizontalShareRow({
    required this.label,
    required this.share,
    required this.labelWidth,
    required this.color,
    this.valueColor,
    this.rank,
  });

  final String label;
  final double share;
  final double labelWidth;
  final Color color;
  final Color? valueColor;
  final int? rank;

  @override
  State<_HorizontalShareRow> createState() => _HorizontalShareRowState();
}

class _HorizontalShareRowState extends State<_HorizontalShareRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseShare = widget.share.clamp(0.0, 1.0).toDouble();
    final animatedShare =
        (_hovered ? baseShare * 1.045 : baseShare).clamp(0.0, 1.0).toDouble();
    final labelColor =
        _hovered ? AppTheme.text : AppTheme.text.withValues(alpha: 0.92);
    final valueColor = _hovered
        ? widget.color
        : widget.valueColor ?? AppColors.concentrationDark;
    final barHeight = _hovered ? 18.0 : 12.0;

    return MouseRegion(
      hitTestBehavior: HitTestBehavior.opaque,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Row(
        children: [
          SizedBox(
            width: widget.labelWidth,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: labelColor,
                        fontSize: 10.4,
                        fontWeight:
                            _hovered ? FontWeight.w700 : FontWeight.w600,
                        height: 1,
                      ) ??
                  TextStyle(
                    color: labelColor,
                    fontSize: 10.4,
                    fontWeight: _hovered ? FontWeight.w700 : FontWeight.w600,
                    height: 1,
                  ),
              child: Row(
                children: [
                  if (widget.rank != null)
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${widget.rank}',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  if (widget.rank != null)
                    const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: animatedShare),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              builder: (context, widthFactor, _) {
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: widget.color.withValues(
                          alpha: _hovered ? 0.14 : 0.09,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: widthFactor,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: widget.color.withValues(
                            alpha: _hovered ? 1 : 0.94,
                          ),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: _hovered
                              ? [
                                  BoxShadow(
                                    color: widget.color.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: valueColor,
                                        fontSize: 10.0,
                                        fontWeight: FontWeight.w700,
                                        height: 1,
                                      ) ??
                                  TextStyle(
                                    color: valueColor,
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  ),
                          child: Text(
                            AppFormatters.percent(widget.share, decimalDigits: 5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskWeightBucketCard extends StatefulWidget {
  const _RiskWeightBucketCard({
    required this.row,
    required this.isDominant,
  });

  final RiskWeightBucketRow row;
  final bool isDominant;

  @override
  State<_RiskWeightBucketCard> createState() => _RiskWeightBucketCardState();
}

class _RiskWeightBucketCardState extends State<_RiskWeightBucketCard> {
  @override
  Widget build(BuildContext context) {
    const accent = AppColors.panelAccent;
    final eadShare = widget.row.portfolioShare;
    final rwaShare = widget.row.rwaShare;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(_concentrationRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.row.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.text,
                                  fontSize: 13.6,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _riskWeightTone(widget.row.weight),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.text.withValues(alpha: 0.68),
                        fontSize: 8.2,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _RiskWeightShareMeter(
                    label: 'EAD',
                    share: eadShare,
                    amount: widget.row.ead,
                    shareLabel: 'Part portefeuille',
                    color: AppColors.riskWeightGreen,
                    valueColor: AppColors.riskWeightText,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _RiskWeightShareMeter(
                    label: 'RWA',
                    share: rwaShare,
                    amount: widget.row.rwa,
                    shareLabel: 'Part RWA',
                    color: AppColors.riskWeightDark,
                    valueColor: AppColors.riskWeightDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          _RiskWeightAmountLine(
            ead: widget.row.ead,
            rwa: widget.row.rwa,
            color: accent,
          ),
        ],
      ),
    );
  }
}

class _RiskWeightAmountLine extends StatelessWidget {
  const _RiskWeightAmountLine({
    required this.ead,
    required this.rwa,
    required this.color,
  });

  final double ead;
  final double rwa;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_amountMd(ead)} ${_amountUnitLabel()}',
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.text.withValues(alpha: 0.72),
                    fontSize: 8.4,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
        Icon(
          CupertinoIcons.arrow_right,
          size: 10,
          color: color.withValues(alpha: 0.72),
        ),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '${_amountMd(rwa)} ${_amountUnitLabel()}',
              maxLines: 1,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontSize: 8.4,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RiskWeightShareMeter extends StatefulWidget {
  const _RiskWeightShareMeter({
    required this.label,
    required this.share,
    required this.amount,
    required this.shareLabel,
    required this.color,
    required this.valueColor,
  });

  final String label;
  final double share;
  final double amount;
  final String shareLabel;
  final Color color;
  final Color valueColor;

  @override
  State<_RiskWeightShareMeter> createState() => _RiskWeightShareMeterState();
}

class _RiskWeightShareMeterState extends State<_RiskWeightShareMeter> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final heightFactor = widget.share.clamp(0.0, 1.0).toDouble();

    return Tooltip(
      message: [
        widget.label,
        '${widget.shareLabel.replaceFirst('Part ', '')} : ${AppFormatters.percent(widget.share)}',
        'Encours : ${_amountMd(widget.amount)} ${_amountUnitFcfaLabel()}',
      ].join('\n'),
      waitDuration: const Duration(milliseconds: 220),
      showDuration: const Duration(seconds: 4),
      padding: const EdgeInsets.fromLTRB(3, 8, 3, 8),
      margin: const EdgeInsets.symmetric(horizontal: 18),
      preferBelow: false,
      verticalOffset: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF101828),
        borderRadius: BorderRadius.circular(_concentrationRadius),
        border: Border.all(color: widget.color.withValues(alpha: 0.46)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 10.4,
        fontWeight: FontWeight.w700,
        height: 1.28,
      ),
      child: MouseRegion(
        onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _hovered = true);
        }),
        onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _hovered = false);
        }),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: widget.valueColor.withValues(
                          alpha: _hovered ? 1 : 0.92,
                        ),
                        fontSize: _hovered ? 8.4 : 8,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ) ??
                  TextStyle(
                    color: widget.valueColor
                        .withValues(alpha: _hovered ? 1 : 0.92),
                    fontSize: _hovered ? 8.4 : 8,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
              child: Text(
                AppFormatters.percent(widget.share),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 30,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: heightFactor),
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    builder: (context, fillFactor, _) {
                      return Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _hovered
                                  ? widget.color.withValues(alpha: 0.13)
                                  : AppColors.riskWeightTrack,
                              borderRadius:
                                  BorderRadius.circular(_concentrationRadius),
                            ),
                          ),
                          FractionallySizedBox(
                            heightFactor: fillFactor,
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    widget.color.withValues(
                                      alpha: _hovered ? 1 : 0.96,
                                    ),
                                    widget.color.withValues(
                                      alpha: _hovered ? 0.92 : 0.78,
                                    ),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  _concentrationRadius,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _riskWeightColor(double weight) {
  if (weight <= 0.001) {
    return const Color(0xFF0F9F6E);
  }
  if (weight <= 0.20) {
    return const Color(0xFF0EA5E9);
  }
  if (weight <= 0.50) {
    return const Color(0xFF4F46E5);
  }
  if (weight <= 0.75) {
    return const Color(0xFFF59E0B);
  }
  if (weight <= 1.0) {
    return const Color(0xFF7C3AED);
  }
  return const Color(0xFFE11D48);
}

String _riskWeightTone(double weight) {
  if (weight <= 0.001) {
    return 'Exposition neutralisée';
  }
  if (weight <= 0.20) {
    return 'Faible consommation';
  }
  if (weight <= 0.50) {
    return 'Risque modéré';
  }
  if (weight <= 0.75) {
    return 'Transition à suivre';
  }
  if (weight <= 1.0) {
    return 'Pondération standard';
  }
  return 'Capital intensif';
}

List<ConcentrationAlert> _rankedAlerts(List<ConcentrationAlert> alerts) {
  return alerts.toList(growable: false)
    ..sort(
      (left, right) =>
          _severityRank(right.severity).compareTo(_severityRank(left.severity)),
    );
}

String _selectedAlertHeaderTitle(ConcentrationAlert? alert) {
  if (alert == null) {
    return 'Aucune alerte active';
  }
  return _compactAlertHeaderTitle(alert.message);
}

String _compactAlertHeaderTitle(String message) {
  return message
      .replaceAll('des fonds propres estimés', 'des fonds propres')
      .replaceAll(RegExp(r'\.$'), '')
      .trim();
}

List<List<String>> _alertKpiNarratives(
  ConcentrationAlert? alert,
  _ConcentrationViewModel view,
) {
  return [[], [], [], [], [], []];
}

class _KpiInfographicStep {
  const _KpiInfographicStep({
    required this.title,
    required this.color,
    required this.icon,
  });

  final String title;
  final Color color;
  final IconData icon;
}

const List<_KpiInfographicStep> _alertsKpiSteps = [
  _KpiInfographicStep(
    title: 'SIGNAL',
    color: Color(0xFF263B52),
    icon: CupertinoIcons.exclamationmark_shield_fill,
  ),
  _KpiInfographicStep(
    title: 'RISQUE',
    color: Color(0xFFFF8500),
    icon: CupertinoIcons.gauge,
  ),
  _KpiInfographicStep(
    title: 'IMPACT',
    color: Color(0xFF94D600),
    icon: CupertinoIcons.chart_bar_alt_fill,
  ),
  _KpiInfographicStep(
    title: 'DÉCISION',
    color: Color(0xFF11B9B7),
    icon: CupertinoIcons.flag,
  ),
  _KpiInfographicStep(
    title: 'ACTION',
    color: Color(0xFF38A4E8),
    icon: CupertinoIcons.checkmark_rectangle,
  ),
  _KpiInfographicStep(
    title: 'CONTRÔLE',
    color: Color(0xFFB300C8),
    icon: CupertinoIcons.shield_lefthalf_fill,
  ),
];

class _AlertsKpiInfographic extends StatefulWidget {
  const _AlertsKpiInfographic({
    required this.alerts,
    required this.view,
  });

  final List<ConcentrationAlert> alerts;
  final _ConcentrationViewModel view;

  @override
  State<_AlertsKpiInfographic> createState() => _AlertsKpiInfographicState();
}

class _AlertsKpiInfographicState extends State<_AlertsKpiInfographic> {
  var _selectedAlertIndex = 0;

  @override
  void didUpdateWidget(covariant _AlertsKpiInfographic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedAlertIndex >= widget.alerts.length) {
      _selectedAlertIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rankedAlerts = _rankedAlerts(widget.alerts);
    final safeSelectedIndex = rankedAlerts.isEmpty
        ? 0
        : math.min(_selectedAlertIndex, rankedAlerts.length - 1);
    final selectedAlert =
        rankedAlerts.isEmpty ? null : rankedAlerts[safeSelectedIndex];
    final alertTitle = _selectedAlertHeaderTitle(selectedAlert);
    final narratives = _alertKpiNarratives(selectedAlert, widget.view);

    return LayoutBuilder(
      builder: (context, constraints) {
        const minWidth = 900.0;
        const infographicHeight = 440.0;
        final width = math.max(minWidth, constraints.maxWidth);
        final surface = Theme.of(context).cardColor;

        final content = SizedBox(
          width: width,
          height: infographicHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(_concentrationRadius),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF111827).withValues(alpha: 0.055),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: _AlertsKpiInfographicCanvas(
              width: width,
              alertCount: widget.alerts.length,
              alertTitle: alertTitle,
              alerts: rankedAlerts,
              selectedAlertIndex: safeSelectedIndex,
              onAlertSelected: (index) {
                if (index == _selectedAlertIndex) {
                  return;
                }
                setState(() => _selectedAlertIndex = index);
              },
              narratives: narratives,
            ),
          ),
        );

        if (constraints.maxWidth >= minWidth) {
          return content;
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: content,
        );
      },
    );
  }
}

class _AlertsKpiInfographicCanvas extends StatelessWidget {
  const _AlertsKpiInfographicCanvas({
    required this.width,
    required this.alertCount,
    required this.alertTitle,
    required this.alerts,
    required this.selectedAlertIndex,
    required this.onAlertSelected,
    required this.narratives,
  });

  final double width;
  final int alertCount;
  final String alertTitle;
  final List<ConcentrationAlert> alerts;
  final int selectedAlertIndex;
  final ValueChanged<int> onAlertSelected;
  final List<List<String>> narratives;

  @override
  Widget build(BuildContext context) {
    const headerHeight = 82.0;
    const headerGap = 8.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
      child: Column(
        children: [
          Center(
            child: _KpiHeaderBadge(
              width: math.min(520.0, width - 72),
              height: headerHeight,
              title: 'Alertes ($alertCount)',
              subtitle: alertTitle,
              alerts: alerts,
              selectedAlertIndex: selectedAlertIndex,
              onAlertSelected: onAlertSelected,
            ),
          ),
          const SizedBox(height: headerGap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0;
                    index < _alertsKpiSteps.length;
                    index++) ...[
                  Expanded(
                    child: _KpiStepCard(
                      step: _alertsKpiSteps[index],
                      narrativeItems: narratives[index],
                      index: index < 3 ? index + 1 : index - 2,
                    ),
                  ),
                  if (index == 2)
                    const _AlertGroupDivider(topExtension: headerGap)
                  else if (index != _alertsKpiSteps.length - 1)
                    const SizedBox(width: 3),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertGroupDivider extends StatelessWidget {
  const _AlertGroupDivider({required this.topExtension});

  final double topExtension;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFE11D48);

    return SizedBox(
      width: 26,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: Offset(0, -topExtension),
              child: SizedBox(
                width: 2.4,
                height: constraints.maxHeight + topExtension,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(_concentrationRadius),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _KpiStepCard extends StatefulWidget {
  const _KpiStepCard({
    required this.step,
    required this.narrativeItems,
    required this.index,
  });

  final _KpiInfographicStep step;
  final List<String> narrativeItems;
  final int index;

  @override
  State<_KpiStepCard> createState() => _KpiStepCardState();
}

class _KpiStepCardState extends State<_KpiStepCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final surface = Color.alphaBlend(
      step.color.withValues(alpha: _hovered ? 0.075 : 0.048),
      Theme.of(context).cardColor,
    );

    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hovered = true);
      }),
      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hovered = false);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(_concentrationRadius),
          border: Border.all(
            color: step.color.withValues(alpha: _hovered ? 0.34 : 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: step.color.withValues(alpha: _hovered ? 0.14 : 0.06),
              blurRadius: _hovered ? 14 : 9,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 31,
                  height: 31,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: step.color,
                    borderRadius: BorderRadius.circular(_concentrationRadius),
                  ),
                  child: Icon(
                    step.icon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.text,
                          fontSize: 12.7,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                  ),
                ),
                Text(
                  widget.index.toString().padLeft(2, '0'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: step.color.withValues(alpha: 0.82),
                        fontSize: 10.2,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(_concentrationRadius),
                ),
                child: _KpiNarrativeList(
                  items: widget.narrativeItems,
                  color: step.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiNarrativeList extends StatelessWidget {
  const _KpiNarrativeList({
    required this.items,
    required this.color,
  });

  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = SizedBox(
          width: constraints.maxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _KpiNarrativeBullet(
                  text: items[index],
                  color: color,
                ),
                if (index != items.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        );

        return Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: content,
          ),
        );
      },
    );
  }
}

class _KpiNarrativeBullet extends StatelessWidget {
  const _KpiNarrativeBullet({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colonIndex = text.indexOf(':');
    final hasLabel = colonIndex > 0;
    final label = hasLabel ? text.substring(0, colonIndex).trimRight() : '';
    final value = hasLabel ? text.substring(colonIndex + 1).trimLeft() : text;
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.text.withValues(alpha: 0.76),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.12,
          letterSpacing: 0,
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5.2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1.5),
            ),
            child: const SizedBox(width: 5.5, height: 5.5),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            textAlign: TextAlign.start,
            softWrap: true,
            text: TextSpan(
              style: baseStyle,
              children: [
                if (hasLabel)
                  TextSpan(
                    text: '$label:\n',
                    style: baseStyle?.copyWith(
                      color: AppTheme.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiHeaderBadge extends StatelessWidget {
  const _KpiHeaderBadge({
    required this.width,
    required this.height,
    required this.title,
    required this.subtitle,
    required this.alerts,
    required this.selectedAlertIndex,
    required this.onAlertSelected,
  });

  final double width;
  final double height;
  final String title;
  final String subtitle;
  final List<ConcentrationAlert> alerts;
  final int selectedAlertIndex;
  final ValueChanged<int> onAlertSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 6, 5, 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFDFDFD),
              Color(0xFFEDEDED),
            ],
          ),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: AppColors.alertCritical,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFF43113),
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                height: 0.95,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF4B5563),
                    fontSize: 10.6,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1,
                  ),
            ),
            if (alerts.length > 1) ...[
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: SizedBox(
                      height: 16,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: Row(
                          children: [
                            for (var index = 0;
                                index < alerts.length;
                                index++) ...[
                              _KpiAlertSelectorChip(
                                alert: alerts[index],
                                index: index,
                                selected: index == selectedAlertIndex,
                                onSelected: onAlertSelected,
                              ),
                              if (index < alerts.length - 1)
                                const SizedBox(width: 4),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KpiAlertSelectorChip extends StatelessWidget {
  const _KpiAlertSelectorChip({
    required this.alert,
    required this.index,
    required this.selected,
    required this.onSelected,
  });

  final ConcentrationAlert alert;
  final int index;
  final bool selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? const Color(0xFFF43113) : _severityColor(alert.severity);

    return Tooltip(
      richMessage: _alertSelectorTooltipMessage(alert, index, color),
      waitDuration: const Duration(milliseconds: 220),
      showDuration: const Duration(seconds: 6),
      constraints: const BoxConstraints(maxWidth: 330),
      padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
      margin: const EdgeInsets.symmetric(horizontal: 18),
      preferBelow: false,
      verticalOffset: 14,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(_concentrationRadius),
        border: Border.all(color: color.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? color : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: selected ? 0.0 : 0.58),
              ),
            ),
            child: Text(
              '${index + 1}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? Colors.white : color,
                    fontSize: 8.1,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

InlineSpan _alertSelectorTooltipMessage(
  ConcentrationAlert alert,
  int index,
  Color color,
) {
  final title = _compactAlertHeaderTitle(alert.message);
  final severity = alert.severity.trim().isEmpty ? 'Signal' : alert.severity;
  final scope = alert.level.trim().isEmpty ? 'Concentration' : alert.level;

  return TextSpan(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 10.4,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    children: [
      TextSpan(
        text: 'Alerte ${(index + 1).toString().padLeft(2, '0')}\n',
        style: TextStyle(
          color: color,
          fontSize: 11.8,
          fontWeight: FontWeight.w900,
          height: 1.2,
        ),
      ),
      TextSpan(
        text: '$severity • $scope\n',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.72),
          fontSize: 9.6,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
      const TextSpan(text: '\n'),
      TextSpan(
        text: title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.6,
          fontWeight: FontWeight.w800,
          height: 1.32,
        ),
      ),
    ],
  );
}

int _severityRank(String severity) {
  return switch (severity.toLowerCase()) {
    'élevé' || 'eleve' => 3,
    'moyen' => 2,
    _ => 1,
  };
}

Color _severityColor(String severity) {
  return switch (severity.toLowerCase()) {
    'élevé' || 'eleve' => AppTheme.danger,
    'moyen' => AppTheme.warning,
    _ => AppTheme.success,
  };
}

class _EmptyInline extends StatelessWidget {
  const _EmptyInline({
    this.message = 'Portefeuille vide',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(_concentrationRadius),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
