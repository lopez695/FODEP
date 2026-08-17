// Ce fichier affiche l'inventaire interactif des expositions.
import 'dart:async';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/localization/app_localization.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/state/portfolio_currency_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/utils/file_save.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';
import '../../referentiels/models/referentiels_models.dart';
import '../models/exposition_models.dart';
import '../widgets/exposure_form_card.dart';
import '../widgets/suivi_versements_dialog.dart';

enum _ExposureTableMode { full, dense, compact, minimal }

enum _ExposureExportFormat { excel, pdf }

class _DeleteSelectionDecision {
  const _DeleteSelectionDecision({
    required this.confirmed,
    required this.reindexIds,
  });

  final bool confirmed;
  final bool reindexIds;
}

class ExpositionsScreen extends StatefulWidget {
  const ExpositionsScreen({
    super.key,
    required this.api,
    required this.displayCurrencyListenable,
  });

  final RwaApiService api;
  final ValueNotifier<String> displayCurrencyListenable;

  @override
  State<ExpositionsScreen> createState() => _ExpositionsScreenState();
}

class _ExpositionsScreenState extends State<ExpositionsScreen> {
  static const double _mainTableMinWidth = 3000;
  static const double _fixedStatutColumnWidth = 130;
  static const double _fixedIdColumnWidth = 128;
  static const double _fixedEncoursColumnWidth = 140;
  static const double _fixedActionsColumnWidth = 146;
  static const double _controlGap = 8;
  static const double _filterControlHeight = 30;
  static const double _optionControlHeight = 34;
  static const double _textFilterControlHeight = 44;
  static const double _screenBorderRadius = 3;
  static const double _tableRowHeight = 36;
  static const String _filterId = 'id';
  static const String _filterCounterparty = 'counterparty';
  static const String _filterCountry = 'country';
  static const String _filterCategory = 'category';
  static const String _filterZone = 'zone';
  static const String _filterRating = 'rating';
  static const String _filterCrm = 'crm';
  static const List<String> _filterOptionKeys = [
    _filterId,
    _filterCounterparty,
    _filterCountry,
    _filterCategory,
    _filterZone,
    _filterRating,
    _filterCrm,
  ];

  late Future<void> _future;
  StreamSubscription<int>? _portfolioRefreshSubscription;
  final ScrollController _tableVerticalController = ScrollController();
  final ScrollController _fixedLeadingVerticalController = ScrollController();
  final ScrollController _fixedTrailingVerticalController = ScrollController();
  final ScrollController _tableHorizontalController = ScrollController();
  final TextEditingController _idFilterController = TextEditingController();
  final TextEditingController _counterpartyFilterController =
      TextEditingController();
  final TextEditingController _countryFilterController =
      TextEditingController();

  List<ExposureRecord> _allRows = const [];
  List<ExposureRecord> _visibleRows = const [];
  List<String> _ratings = prudentialRatings;
  String _categoryFilter = 'Toutes';
  String _zoneFilter = 'Toutes';
  String _ratingFilter = 'Toutes';
  String _crmFilter = 'Toutes';
  String _displayCurrency = 'XOF';
  String _activeFilterKey = _filterCounterparty;
  int _currentTabIndex = 0;
  int _selectedEvolutionChartIndex = 0;
  late Set<String> _visibleColumnKeys;
  String? _sortColumnKey = 'counterparty';
  bool _sortAscending = true;
  String? _selectedExposureId;
  bool _isDeleting = false;
  bool _isExporting = false;
  bool _hasLoadedReferentiels = false;
  bool _isSyncingTableVerticalScroll = false;

  @override
  void initState() {
    super.initState();
    _visibleColumnKeys = _defaultVisibleColumnKeys();
    _displayCurrency =
        normalizeCurrencyCode(widget.displayCurrencyListenable.value);
    widget.displayCurrencyListenable
        .addListener(_handleDisplayCurrencyChanged);
    _tableVerticalController.addListener(_syncTableVerticalScrollFromMain);
    _fixedLeadingVerticalController
        .addListener(_syncTableVerticalScrollFromLeading);
    _fixedTrailingVerticalController
        .addListener(_syncTableVerticalScrollFromTrailing);
    _future = _refresh();
    _portfolioRefreshSubscription =
        widget.api.portfolioRefreshStream.listen((_) {
      if (!mounted) {
        return;
      }
      _queueRefresh();
    });
  }

  @override
  void dispose() {
    _portfolioRefreshSubscription?.cancel();
    widget.displayCurrencyListenable
        .removeListener(_handleDisplayCurrencyChanged);
    _tableVerticalController.removeListener(_syncTableVerticalScrollFromMain);
    _fixedLeadingVerticalController
        .removeListener(_syncTableVerticalScrollFromLeading);
    _fixedTrailingVerticalController
        .removeListener(_syncTableVerticalScrollFromTrailing);
    _tableVerticalController.dispose();
    _fixedLeadingVerticalController.dispose();
    _fixedTrailingVerticalController.dispose();
    _tableHorizontalController.dispose();
    _idFilterController.dispose();
    _counterpartyFilterController.dispose();
    _countryFilterController.dispose();
    super.dispose();
  }

  void _syncTableVerticalScrollFromMain() {
    _syncTableVerticalScrollFrom(_tableVerticalController);
  }

  void _syncTableVerticalScrollFromLeading() {
    _syncTableVerticalScrollFrom(_fixedLeadingVerticalController);
  }

  void _syncTableVerticalScrollFromTrailing() {
    _syncTableVerticalScrollFrom(_fixedTrailingVerticalController);
  }

  void _syncTableVerticalScrollFrom(ScrollController source) {
    if (_isSyncingTableVerticalScroll || !source.hasClients) {
      return;
    }
    _isSyncingTableVerticalScroll = true;
    final sourceOffset = source.offset;
    for (final controller in [
      _tableVerticalController,
      _fixedLeadingVerticalController,
      _fixedTrailingVerticalController,
    ]) {
      if (controller == source || !controller.hasClients) {
        continue;
      }
      final targetOffset = sourceOffset.clamp(
        controller.position.minScrollExtent,
        controller.position.maxScrollExtent,
      );
      if ((controller.offset - targetOffset).abs() > 0.5) {
        controller.jumpTo(targetOffset);
      }
    }
    _isSyncingTableVerticalScroll = false;
  }

  void _handleDisplayCurrencyChanged() {
    final nextCurrency =
        normalizeCurrencyCode(widget.displayCurrencyListenable.value);
    if (!mounted || _displayCurrency == nextCurrency) return;
    setState(() {
      _displayCurrency = nextCurrency;
      _recomputeVisibleView();
    });
  }

  Future<void> _queueRefresh() {
    final refreshFuture = _refresh();
    if (mounted) {
      setState(() {
        _future = refreshFuture;
      });
    } else {
      _future = refreshFuture;
    }
    return refreshFuture;
  }

  @override
  Widget build(BuildContext context) {
    final screenBusyMessage = _screenBusyMessage;

    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            _allRows.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError && _allRows.isEmpty) {
          return Center(
            child: Text(
              context.tr('Erreur: {{error}}', args: {'error': snapshot.error}),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.all(15.0),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.zero,
                        child: PageHeader(
                          title: 'Tableau des expositions',
                          titleFontSize: 22,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          trailing: _buildHeaderActionButtons(_visibleRows),
                        ),
                      ),
                      const SizedBox(height: AppTheme.pageGap),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, areaConstraints) {
                            final sectionWidth = areaConstraints.maxWidth > 1760
                                ? 1760.0
                                : areaConstraints.maxWidth;
                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: SizedBox(
                                width: sectionWidth,
                                height: areaConstraints.maxHeight,
                                child: SectionCard(
                                  title: '',
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    children: [
                                      _buildTabSelector(context),
                                      if (_currentTabIndex == 2)
                                        Expanded(
                                          child: _buildEvolutionRemboursementsView(context),
                                        )
                                      else ...[
                                        _buildControlsPanel(
                                          context,
                                        ),
                                        const SizedBox(height: 10),
                                        Expanded(
                                          child: _buildScrollableExposureTable(
                                            context,
                                            _visibleRows,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0, left: 4.0, right: 16.0),
                                          child: Row(
                                            children: [
                                              Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFFFFECEC), border: Border.all(color: Colors.red.shade200, width: 0.5), borderRadius: BorderRadius.circular(2))),
                                              const SizedBox(width: 4),
                                              const Text('Expirée', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.amber)),
                                              const SizedBox(width: 8),
                                              Text('|', style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600] : Colors.grey[400])),
                                              const SizedBox(width: 8),
                                              Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFFE6F9EE), border: Border.all(color: Colors.green.shade200, width: 0.5), borderRadius: BorderRadius.circular(2))),
                                              const SizedBox(width: 4),
                                              const Text('Entièrement remboursée', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.amber)),
                                              const SizedBox(width: 8),
                                              Text('|', style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600] : Colors.grey[400])),
                                              const SizedBox(width: 8),
                                              Builder(
                                                builder: (ctx) {
                                                  final activesCount = _visibleRows.where((r) {
                                                    if (r.grossAmount <= 0) return false;
                                                    final rm = r.residualMaturityMonths ?? _durationInMonths(r.analysisDate, r.maturityDate);
                                                    if (rm <= 0) return false;
                                                    return true;
                                                  }).length;
                                                  final isDark = Theme.of(context).brightness == Brightness.dark;
                                                  final style = TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    fontStyle: FontStyle.italic,
                                                    color: isDark ? Colors.blue[300] : const Color(0xFF1E3A8A), // Deep blue
                                                  );
                                                  return Row(
                                                    children: [
                                                      Text("Nombre total d'expositions : ${_visibleRows.length}", style: style),
                                                      const SizedBox(width: 8),
                                                      Text('|', style: style.copyWith(color: isDark ? Colors.grey[600] : Colors.grey[400])),
                                                      const SizedBox(width: 8),
                                                      Text("Nombre d'expositions actives : $activesCount", style: style),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  if (screenBusyMessage != null)
                    Positioned.fill(
                      child: _buildScreenBusyOverlay(
                        context,
                        message: screenBusyMessage,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeaderActionButtons(List<ExposureRecord> visibleRows) {
    final isScreenBusy = _screenBusyMessage != null;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildHeaderActionButton(
          label: _isExporting
              ? context.tr('Exportation...')
              : context.tr('Export'),
          icon: Icons.file_download_outlined,
          iconWidget: _isExporting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : null,
          onPressed: isScreenBusy || visibleRows.isEmpty
              ? null
              : () => _exportView(visibleRows),
          color: const Color(0xFF14A44D),
        ),
      ],
    );
  }

  Widget _buildHeaderActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
    Widget? iconWidget,
  }) {
    return SizedBox(
      height: 30,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.0),
          backgroundColor: color,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_screenBorderRadius),
          ),
          visualDensity: VisualDensity.compact,
        ),
        icon: iconWidget ?? Icon(icon, size: 14),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  String? get _screenBusyMessage {
    if (_isDeleting) {
      return 'Suppression des expositions en cours...';
    }
    if (_isExporting) {
      return 'Exportation des expositions en cours...';
    }
    return null;
  }

  Widget _buildScreenBusyOverlay(
    BuildContext context, {
    required String message,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AbsorbPointer(
      absorbing: true,
      child: Container(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.22),
        alignment: Alignment.center,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14233D) : Colors.white,
            borderRadius: BorderRadius.circular(_screenBorderRadius),
            border: Border.all(
              color: isDark ? const Color(0xFF2A3C5E) : const Color(0xFFD9E4F6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
                      message,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(
                        'Merci de patienter pendant la mise à jour des données.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.muted,
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

  final TextStyle _tableHeadingStyle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 10,
    height: 1.0,
    letterSpacing: 0.18,
    color: const Color(0xFFF5F8FF),
  );

  TextStyle get _tableCellStyle {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 11.2,
      height: 1.1,
      fontWeight: FontWeight.w400,
      color: isDark ? const Color(0xFFF2F6FF) : AppTheme.text,
    );
  }

  Widget _buildScrollableExposureTable(
    BuildContext context,
    List<ExposureRecord> visibleRows,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13233E) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF304764) : AppTheme.border,
        ),
        borderRadius: BorderRadius.circular(_screenBorderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_screenBorderRadius),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const tableMode = _ExposureTableMode.full;
            final viewportWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth - 2
                : MediaQuery.sizeOf(context).width - 24;
            final columnKeys = _visibleTableColumnKeys(tableMode);
            final columnWidths = _mainTableColumnWidths(
              viewportWidth,
              tableMode,
              requestedKeys: columnKeys,
            );
            final leadingColumnKeys = columnKeys
                .where(_isLeadingFixedTableColumn)
                .toList(growable: false);
            final trailingColumnKeys = columnKeys
                .where(_isTrailingFixedTableColumn)
                .toList(growable: false);
            final scrollableColumnKeys = columnKeys
                .where((key) =>
                    !_isLeadingFixedTableColumn(key) &&
                    !_isTrailingFixedTableColumn(key))
                .toList(growable: false);
            final leadingWidths = _columnWidthsForKeys(
                leadingColumnKeys, columnKeys, columnWidths);
            final trailingWidths = _columnWidthsForKeys(
                trailingColumnKeys, columnKeys, columnWidths);
            final scrollableWidths = _columnWidthsForKeys(
                scrollableColumnKeys, columnKeys, columnWidths);
            final leadingWidth = _sumWidths(leadingWidths);
            final trailingWidth = _sumWidths(trailingWidths);
            final scrollableWidth = _sumWidths(scrollableWidths);

            return SizedBox(
              width: double.infinity,
              height: constraints.maxHeight,
              child: Row(
                children: [
                  Container(
                    width: leadingWidth,
                    height: constraints.maxHeight,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: isDark
                              ? const Color(0xFF304764)
                              : const Color(0xFFD6E0EF),
                          width: 1,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.20 : 0.06,
                          ),
                          blurRadius: 10,
                          offset: const Offset(3, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildStickyTableHeader(
                          leadingColumnKeys,
                          leadingWidths,
                          tableMode,
                          visibleRows,
                        ),
                        Expanded(
                          child: _buildFixedVirtualizedTableBody(
                            visibleRows,
                            leadingColumnKeys,
                            leadingWidths,
                            _fixedLeadingVerticalController,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Scrollbar(
                      controller: _tableHorizontalController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _tableHorizontalController,
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: SizedBox(
                          width: scrollableWidth,
                          height: constraints.maxHeight,
                          child: Column(
                            children: [
                              _buildStickyTableHeader(
                                scrollableColumnKeys,
                                scrollableWidths,
                                tableMode,
                                visibleRows,
                              ),
                              Expanded(
                                child: _buildVirtualizedTableBody(
                                  visibleRows,
                                  scrollableColumnKeys,
                                  scrollableWidths,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: trailingWidth,
                    height: constraints.maxHeight,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: isDark
                              ? const Color(0xFF304764)
                              : const Color(0xFFD6E0EF),
                          width: 1,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.20 : 0.06,
                          ),
                          blurRadius: 10,
                          offset: const Offset(-3, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildStickyTableHeader(
                          trailingColumnKeys,
                          trailingWidths,
                          tableMode,
                          visibleRows,
                        ),
                        Expanded(
                          child: _buildFixedVirtualizedTableBody(
                            visibleRows,
                            trailingColumnKeys,
                            trailingWidths,
                            _fixedTrailingVerticalController,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVirtualizedTableBody(
    List<ExposureRecord> rows,
    List<String> columnKeys,
    List<double> widths,
  ) {
    return Scrollbar(
      controller: _tableVerticalController,
      thumbVisibility: true,
      child: ListView.builder(addSemanticIndexes: false,
        controller: _tableVerticalController,
        physics: const ClampingScrollPhysics(),
        itemCount: rows.length,
        itemExtent: _tableRowHeight,
        itemBuilder: (context, index) {
          return RepaintBoundary(
            child: _buildVirtualizedTableRow(
              rows[index],
              index,
              columnKeys,
              widths,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFixedVirtualizedTableBody(
    List<ExposureRecord> rows,
    List<String> columnKeys,
    List<double> widths,
    ScrollController controller,
  ) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.builder(addSemanticIndexes: false,
        controller: controller,
        physics: const ClampingScrollPhysics(),
        itemCount: rows.length,
        itemExtent: _tableRowHeight,
        itemBuilder: (context, index) {
          return RepaintBoundary(
            child: _buildVirtualizedTableRow(
              rows[index],
              index,
              columnKeys,
              widths,
            ),
          );
        },
      ),
    );
  }



  static const List<String> _fullTableColumnKeys = [
    'id',
    'grant_date',
    'maturity_date',
    'exposure_maturity',
    'residual_maturity',
    'counterparty',
    'counterparty_rating',
    'country',
    'country_rating',
    'country_rw',
    'category',
    'rw',
    'loan_total',
    'encours_restant',
    'on_balance_amount',
    'off_balance_amount',
    'source_currency',
    'crm_exists',
    'crm_type',
    'ead_bilan',
    'ead_hb',
    'ead_hb_ccf',
    'ead_total',
    'rwa_eb',
    'rwa_hb',
    'rwa',
    'capital',
    'statut',
    'actions',
  ];

  static const List<String> _importedColumnKeys = [
    'id', 'grant_date', 'maturity_date', 'exposure_maturity', 'residual_maturity',
    'counterparty', 'counterparty_rating', 'country', 'country_rating', 'country_rw',
    'category', 'rw', 'loan_total', 'encours_restant', 'on_balance_amount', 'off_balance_amount',
    'source_currency', 'crm_exists', 'crm_type', 'actions',
  ];

  static const List<String> _calculatedColumnKeys = [
    'id', 'counterparty', 'encours_restant', 'ead_bilan', 'ead_hb', 'ead_hb_ccf', 'ead_total',
    'rwa_eb', 'rwa_hb', 'rwa', 'capital', 'statut', 'actions',
  ];

  static const List<String> _denseTableColumnKeys = [
    'id',
    'counterparty',
    'geo',
    'category',
    'rating',
    'gross',
    'ead',
    'rw',
    'rwa',
    'crm',
  ];

  static const List<String> _compactTableColumnKeys = [
    'id',
    'counterparty',
    'geo',
    'category',
    'gross',
    'rw',
    'rwa',
    'crm',
  ];

  static const List<String> _minimalTableColumnKeys = [
    'id',
    'counterparty',
    'category',
    'gross',
    'rwa',
    'crm',
  ];

  static const List<double> _mainTableWidthWeights = [
    0.20, // 0  id
    0.20, // 1  grant_date
    0.20, // 2  maturity_date
    0.20, // 3  exposure_maturity
    0.20, // 4  residual_maturity
    0.45, // 5  counterparty
    0.20, // 6  counterparty_rating
    0.20, // 7  country
    0.20, // 8  country_rating
    0.20, // 9  country_rw
    0.45, // 10 category
    0.20, // 11 rw
    0.20, // 12 loan_total
    0.20, // 13 encours_restant
    0.20, // 14 on_balance_amount
    0.20, // 14 off_balance_amount
    0.20, // 15 source_currency
    0.20, // 16 crm_exists
    0.20, // 17 crm_type
    0.20, // 18 ead_bilan
    0.20, // 19 ead_hb
    0.20, // 20 ead_hb_ccf
    0.20, // 21 ead_total
    0.20, // 22 rwa_eb
    0.20, // 23 rwa_hb
    0.20, // 24 rwa
    0.20, // 25 capital
    0.20, // 26 statut
    0.20, // 27 actions
  ];

  static const List<double> _denseTableWidthWeights = [
    0.70,
    1.75,
    1,
    1.15,
    0.75,
    1,
    1,
    0.65,
    1,
    1,
  ];

  static const List<double> _compactTableWidthWeights = [
    1.10,
    2.35,
    1.55,
    1.75,
    1.55,
    1.10,
    1.40,
    1.45,
  ];

  static const List<double> _minimalTableWidthWeights = [
    1.25,
    3.00,
    2.30,
    2.00,
    1.80,
    1.80,
  ];

  List<double> _scaledColumnWidths(
    double maxWidth,
    List<double> weights,
  ) {
    final totalWeight = weights.fold<double>(0, (sum, item) => sum + item);
    final usableWidth = maxWidth.clamp(0.0, double.infinity);
    return weights
        .map((weight) => usableWidth * (weight / totalWeight))
        .toList(growable: false);
  }

  List<String> _tableColumnKeysForMode(_ExposureTableMode mode) {
    switch (mode) {
      case _ExposureTableMode.full:
        return _currentTabIndex == 0 ? _importedColumnKeys : _calculatedColumnKeys;
      case _ExposureTableMode.dense:
        return _denseTableColumnKeys;
      case _ExposureTableMode.compact:
        return _compactTableColumnKeys;
      case _ExposureTableMode.minimal:
        return _minimalTableColumnKeys;
    }
  }

  List<double> _tableWeightsForMode(_ExposureTableMode mode) {
    switch (mode) {
      case _ExposureTableMode.full:
        final keys = _tableColumnKeysForMode(mode);
        return keys.map((k) => _mainTableWidthWeights[_fullTableColumnKeys.indexOf(k)]).toList(growable: false);
      case _ExposureTableMode.dense:
        return _denseTableWidthWeights;
      case _ExposureTableMode.compact:
        return _compactTableWidthWeights;
      case _ExposureTableMode.minimal:
        return _minimalTableWidthWeights;
    }
  }

  List<String> _visibleTableColumnKeys(_ExposureTableMode mode) {
    final sourceKeys = _tableColumnKeysForMode(mode);
    return sourceKeys
        .where((key) =>
            _isLockedTableColumn(key) || _visibleColumnKeys.contains(key))
        .toList(growable: false);
  }

  bool _isLeadingFixedTableColumn(String key) {
    return key == 'id';
  }

  bool _isTrailingFixedTableColumn(String key) {
    return key == 'encours_restant' || key == 'statut' || key == 'actions';
  }

  bool _isLockedTableColumn(String key) {
    return _isLeadingFixedTableColumn(key) || _isTrailingFixedTableColumn(key);
  }

  Set<String> _defaultVisibleColumnKeys() {
    return _fullTableColumnKeys.toSet();
  }

  Set<String> _normalizeVisibleColumnKeys(Set<String> keys) {
    return {
      for (final key in _fullTableColumnKeys)
        if (_isLockedTableColumn(key) || keys.contains(key)) key,
    };
  }

  double? _fixedTableColumnWidth(String key) {
    return switch (key) {
      'id' => _fixedIdColumnWidth,
      'encours_restant' => _fixedEncoursColumnWidth,
      'statut' => _fixedStatutColumnWidth,
      'actions' => _fixedActionsColumnWidth,
      _ => null,
    };
  }

  double _sumWidths(List<double> widths) {
    return widths.fold<double>(0, (sum, width) => sum + width);
  }

  List<double> _fitColumnWidthsToAvailableWidth(
    List<double> widths,
    double availableWidth,
  ) {
    if (!availableWidth.isFinite || widths.isEmpty) {
      return widths;
    }

    final totalWidth = _sumWidths(widths);
    if (totalWidth <= availableWidth || totalWidth <= 0) {
      return widths;
    }

    final scale = (availableWidth / totalWidth).clamp(0.0, 1.0).toDouble();
    return widths.map((width) => width * scale).toList(growable: false);
  }

  List<double> _columnWidthsForKeys(
    List<String> requestedKeys,
    List<String> sourceKeys,
    List<double> sourceWidths,
  ) {
    return requestedKeys
        .map((key) => sourceWidths[sourceKeys.indexOf(key)])
        .toList(growable: false);
  }

  List<double> _mainTableColumnWidths(
    double maxWidth,
    _ExposureTableMode mode, {
    List<String>? requestedKeys,
  }) {
    final sourceKeys = _tableColumnKeysForMode(mode);
    final weights = _tableWeightsForMode(mode);
    final columnKeys = requestedKeys ?? sourceKeys;
    if (mode != _ExposureTableMode.full) {
      return _scaledColumnWidths(
        maxWidth,
        columnKeys
            .map((key) => weights[sourceKeys.indexOf(key)])
            .toList(growable: false),
      );
    }

    final fixedWidth = columnKeys.fold<double>(
      0,
      (sum, key) => sum + (_fixedTableColumnWidth(key) ?? 0),
    );
    final scrollableWeights = <double>[
      for (final key in columnKeys)
        if (_fixedTableColumnWidth(key) == null)
          weights[sourceKeys.indexOf(key)],
    ];
    final scrollableWeightTotal =
        scrollableWeights.fold<double>(0, (sum, item) => sum + item);
    final fullFixedWidth = sourceKeys.fold<double>(
      0,
      (sum, key) => sum + (_fixedTableColumnWidth(key) ?? 0),
    );
    final fullScrollableWeights = <double>[
      for (var index = 0; index < sourceKeys.length; index++)
        if (_fixedTableColumnWidth(sourceKeys[index]) == null) weights[index],
    ];
    final fullScrollableWeightTotal =
        fullScrollableWeights.fold<double>(0, (sum, item) => sum + item);
    final selectedMinScrollableWidth = fullScrollableWeightTotal <= 0
        ? 0.0
        : (_mainTableMinWidth - fullFixedWidth) *
            (scrollableWeightTotal / fullScrollableWeightTotal);
    final minScrollableWidth =
        math.max(0.0, selectedMinScrollableWidth).toDouble();
    final availableScrollableWidth = math.max(
      (maxWidth - fixedWidth).clamp(0.0, double.infinity),
      minScrollableWidth,
    );

    return [
      for (final key in columnKeys)
        _fixedTableColumnWidth(key) ??
            availableScrollableWidth *
                (weights[sourceKeys.indexOf(key)] / scrollableWeightTotal),
    ];
  }

  Widget _tableFittedContent({
    required double width,
    required String text,
    required TextStyle style,
    String? tooltip,
    Alignment alignment = Alignment.centerLeft,
    TextAlign textAlign = TextAlign.left,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          style: style,
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );

    return SizedBox(
      width: width,
      child: tooltip == null || tooltip.trim().isEmpty
          ? content
          : Tooltip(
              message: tooltip,
              waitDuration: const Duration(milliseconds: 180),
              showDuration: const Duration(seconds: 4),
              preferBelow: false,
              verticalOffset: 14,
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9.0),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: TextStyle(
                color:
                    isDark ? const Color(0xFFF8FBFF) : const Color(0xFFF8FBFF),
                fontSize: 10.4,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF213252).withValues(alpha: 0.98)
                    : const Color(0xFF16325C).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(_screenBorderRadius),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF4D6C97)
                      : const Color(0xFF6F92C4),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: content,
            ),
    );
  }

  Widget _tableText(
    String text,
    double width, {
    String? tooltip,
    Alignment alignment = Alignment.centerLeft,
    TextAlign textAlign = TextAlign.left,
    TextStyle? style,
  }) {
    return _tableFittedContent(
      width: width,
      text: text,
      style: style ?? _tableCellStyle,
      tooltip: tooltip,
      alignment: alignment,
      textAlign: textAlign,
    );
  }

  Widget _tableAmountText(
    double value, {
    required String currencyCode,
    required double width,
    Alignment alignment = Alignment.centerLeft,
    TextAlign textAlign = TextAlign.left,
    TextStyle? style,
  }) {
    final unit = PortfolioAmountUnitScope.maybeOf(context);
    final scaledValue = value / unit.divisor;
    
    String compactValueStr = AppFormatters.decimalNumber(scaledValue, maxDecimals: 1);
    if (value > 0 && (compactValueStr == '0' || compactValueStr == '-0')) {
      compactValueStr = '< 0,1';
    } else if (value < 0 && (compactValueStr == '0' || compactValueStr == '-0')) {
      compactValueStr = '> -0,1';
    }
    
    final compactValue = '$compactValueStr ${unit.label}';
    return _tableFittedContent(
      width: width,
      text: compactValue,
      style: style ?? _tableCellStyle,
      alignment: alignment,
      textAlign: textAlign,
    );
  }

  double _loanTotalAmountValue(ExposureRecord row) {
    final onBalanceAmount = row.onBalanceExposureAmount ?? row.grossAmount;
    final loanTotalAmount = row.loanTotalAmount;
    if (loanTotalAmount != null) {
      return loanTotalAmount;
    }
    return row.grossAmount >= onBalanceAmount
        ? row.grossAmount
        : onBalanceAmount;
  }

  double _onBalanceAmountValue(ExposureRecord row) {
    return row.onBalanceExposureAmount ?? row.grossAmount;
  }

  double _offBalanceAmountValue(ExposureRecord row) {
    final offBalanceAmount = row.offBalanceExposureAmount;
    if (offBalanceAmount != null) {
      return offBalanceAmount;
    }
    final derivedAmount =
        _loanTotalAmountValue(row) - _onBalanceAmountValue(row);
    return derivedAmount > 0 ? derivedAmount : 0.0;
  }

  double _eadBilanAmountValue(ExposureRecord row) {
    return row.eadBilanAmount ?? row.ead;
  }

  double _eadHbAmountValue(ExposureRecord row) {
    return row.eadHbAmount ?? _offBalanceAmountValue(row);
  }

  double _eadHbCcfAmountValue(ExposureRecord row) {
    return row.eadHbCcfAmount ?? 0.0;
  }

  double _eadTotalAmountValue(ExposureRecord row) {
    return row.eadTotalAmount ?? row.ead;
  }

  double _rwaHbAmountValue(ExposureRecord row) {
    return row.rwaHbAmount ?? 0.0;
  }

  double _rwaEbAmountValue(ExposureRecord row) {
    final rwaEbAmount = row.rwaEbAmount;
    if (rwaEbAmount != null) {
      return rwaEbAmount;
    }
    final derivedAmount = row.rwa - _rwaHbAmountValue(row);
    return derivedAmount > 0 ? derivedAmount : 0.0;
  }

  double _rwPercentValue(ExposureRecord row) {
    return (row.finalRw * 100).clamp(0.0, double.infinity).toDouble();
  }

  Color _tableRowBackgroundColor(int index, {required bool isSelected, ExposureRecord? row}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (isSelected) {
      return isDark ? const Color(0xFF243B63) : const Color(0xFFDCEBFF);
    }
    
    if (row != null) {
      // Exposition entièrement remboursée (encours = 0)
      if (row.grossAmount <= 0) {
        return isDark ? const Color(0xFF1B3A2A) : const Color(0xFFE6F9EE);
      }
      // Exposition expirée (maturité résiduelle <= 0)
      final residualMaturity = row.residualMaturityMonths ?? _durationInMonths(row.analysisDate, row.maturityDate);
      if (residualMaturity <= 0) {
        return isDark ? const Color(0xFF4A2B2B) : const Color(0xFFFFECEC);
      }
    }

    final isEven = index.isEven;
    if (isDark) {
      return isEven ? const Color(0xFF111D33) : const Color(0xFF16243C);
    }
    return isEven ? Colors.white : const Color(0xFFF7FAFF);
  }

  String _compactCrmValue(String value) {
    switch (value) {
      case 'CRM financee':
        return 'Financée';
      case 'CRM non financee':
        return 'Non financée';
      default:
        return value;
    }
  }

  String _displayExposureCategory(String value) {
    final cleaned = value
        .replaceFirst(RegExp(r'^\([a-z]\)\s*', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty) {
      return value;
    }
    return cleaned
        .split(RegExp(r'\s+'))
        .map(_capitalizeExposureCategoryWord)
        .join(' ');
  }

  String _capitalizeExposureCategoryWord(String word) {
    if (word.isEmpty) {
      return word;
    }
    if (word.contains("'")) {
      return word.split("'").map(_capitalizeExposureCategorySegment).join("'");
    }
    return _capitalizeExposureCategorySegment(word);
  }

  String _capitalizeExposureCategorySegment(String value) {
    if (value.isEmpty) {
      return value;
    }
    if (value.toUpperCase() == value) {
      return value;
    }
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String _displayCountry(String value) {
    return displayCountryName(value, fallback: value);
  }

  String _compactGeoValue(ExposureRecord row) {
    final zone = switch (row.zone) {
      'Hors zone' => 'HZ',
      _ => row.zone,
    };
    return '${_displayCountry(row.counterparty.country)} / $zone';
  }

  int? _exposureIdOrder(String id) {
    if (!id.startsWith('CP')) {
      return null;
    }
    return int.tryParse(id.substring(2));
  }

  int _compareExposureIds(String left, String right) {
    final leftOrder = _exposureIdOrder(left);
    final rightOrder = _exposureIdOrder(right);
    if (leftOrder != null && rightOrder != null) {
      return leftOrder.compareTo(rightOrder);
    }
    if (leftOrder != null) {
      return -1;
    }
    if (rightOrder != null) {
      return 1;
    }
    return left.compareTo(right);
  }

  String _normalizeRatingForSort(String rating) {
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
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int _ratingSortRank(String rating) {
    final normalized = _normalizeRatingForSort(rating);
    const directRanks = <String, int>{
      'AAA': 0,
      'AA+': 1,
      'AA': 2,
      'AA-': 3,
      'AAA/AA': 3,
      'A+': 4,
      'A': 5,
      'A-': 6,
      'BBB+': 7,
      'BBB': 8,
      'BBB-': 9,
      'BB+': 10,
      'BB': 11,
      'BB-': 12,
      'BB/B': 12,
      'B+': 13,
      'B': 14,
      'B-': 15,
      '< B-': 16,
    };

    final directRank = directRanks[normalized];
    if (directRank != null) {
      return directRank;
    }

    if (normalized.contains('NON NOTE')) {
      return 17;
    }

    return switch (bucketizeRating(rating)) {
      'AAA/AA' => 3,
      'A' => 5,
      'BBB' => 8,
      'BB/B' => 12,
      '< B-' => 16,
      _ => 17,
    };
  }

  int _compareRatings(String left, String right) {
    final leftRank = _ratingSortRank(left);
    final rightRank = _ratingSortRank(right);
    if (leftRank != rightRank) {
      return leftRank.compareTo(rightRank);
    }
    return _normalizeRatingForSort(left)
        .compareTo(_normalizeRatingForSort(right));
  }

  List<String> _sortRatings(List<String> ratings) {
    final ordered = ratings
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: true);
    ordered.sort(_compareRatings);
    return ordered;
  }

  int _compareNullableDates(DateTime? left, DateTime? right) {
    if (left == null && right == null) {
      return 0;
    }
    if (left == null) {
      return -1;
    }
    if (right == null) {
      return 1;
    }
    return left.compareTo(right);
  }

  String _formatExposureDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return AppFormatters.shortDate(value);
  }

  int _durationInMonths(DateTime? start, DateTime? end) {
    if (start == null || end == null) {
      return 0;
    }
    var months = (end.year - start.year) * 12 + (end.month - start.month);
    if (end.day < start.day) {
      months -= 1;
    }
    return months < 0 ? 0 : months;
  }

  String _formatDurationMonths(int totalMonths) {
    return '$totalMonths mois';
  }

  String _exposureMaturityLabel(ExposureRecord row) {
    // Octroi incohérent (postérieur à l'échéance ou à la date d'analyse) ou
    // absent : la maturité initiale est indéterminée, on affiche un tiret
    // plutôt qu'un faux « 0 mois ».
    final coherentGrant = resolveCoherentGrantDate(
      row.grantDate,
      row.maturityDate,
      row.analysisDate,
    );
    if (coherentGrant == null) {
      return '-';
    }
    return _formatDurationMonths(
      row.exposureMaturityMonths ??
          _durationInMonths(coherentGrant, row.maturityDate),
    );
  }

  String _residualMaturityLabel(ExposureRecord row) {
    return _formatDurationMonths(
      row.residualMaturityMonths ??
          _durationInMonths(row.analysisDate, row.maturityDate),
    );
  }

  double _countryRiskWeightValue(ExposureRecord row) {
    return row.countryRiskWeight ??
        lookupPrudentialRiskWeight('a', row.counterparty.countryRating);
  }

  String _formatRiskWeight(double value) {
    final percent = value * 100;
    final decimals = percent == percent.roundToDouble() ? 0 : 1;
    return '${percent.toStringAsFixed(decimals)}%';
  }

  String _crmExistsLabel(ExposureRecord row) {
    return row.crmModeLabel == 'Aucune' ? 'Non' : 'Oui';
  }

  String _crmTypeTableValue(ExposureRecord row) {
    switch (row.crmModeLabel) {
      case 'CRM financee':
        return 'Financée';
      case 'CRM non financee':
        return 'Non financée';
      default:
        return 'aucune';
    }
  }

  String _columnLabelForKey(String key, _ExposureTableMode mode) {
    final String currencySuffix = (_displayCurrency == 'Origine' || _displayCurrency.toUpperCase() == 'ORIGINE') 
        ? '' 
        : ' (en $_displayCurrencyLabel)';

    switch (key) {
      case 'actions':
        return 'Actions';
      case 'analysis_date':
        return "Date d'analyse";
      case 'id':
        return 'ID Exposition';
      case 'grant_date':
        return "Date d'octroi";
      case 'maturity_date':
        return "Date d'échéance";
      case 'exposure_maturity':
        return "Maturité de l'exposition";
      case 'residual_maturity':
        return 'Maturité résiduelle';
      case 'counterparty':
        return 'Contrepartie';
      case 'counterparty_rating':
        return 'Notation externe contrepartie';
      case 'country':
        return 'Pays contrepartie';
      case 'country_rating':
        return 'Notation externe pays';
      case 'country_rw':
        return 'Pondération pays';
      case 'geo':
        return 'Geo';
      case 'source_currency':
        return 'Devise';
      case 'category':
        return "Catégorie d'exposition";
      case 'rating':
        return 'Notation';
      case 'gross':
        return 'Montant_exposition_brut$currencySuffix';
      case 'loan_total':
        return 'PRÊT TOTAL$currencySuffix';
      case 'encours_restant':
        return 'Encours restant$currencySuffix';
      case 'on_balance_amount':
        return 'Exposition au bilan$currencySuffix';
      case 'off_balance_amount':
        return 'Exposition au hors bilan$currencySuffix';
      case 'crm_exists':
        return 'CRM existe';
      case 'crm_type':
        return 'Type CRM';
      case 'ead_bilan':
        return 'Exposure at Default (En bilan)$currencySuffix';
      case 'ead_hb':
        return 'Exposure at Default (Hors bilan)$currencySuffix';
      case 'ead_hb_ccf':
        return 'Exposure at Default (Hors bilan ccf)$currencySuffix';
      case 'ead_total':
        return 'Exposure at Default Total$currencySuffix';
      case 'rw':
        return 'Pondération (RW)';
      case 'rwa_eb':
        return 'RWA (En bilan)$currencySuffix';
      case 'rwa_hb':
        return 'RWA (Hors bilan)$currencySuffix';
      case 'rwa':
        return 'RWA crédit$currencySuffix';
      case 'capital':
        return 'Capital minimum requis$currencySuffix';
      case 'statut':
        return 'Statut';
      case 'crm':
        return 'CRM';
      default:
        return key;
    }
  }

  Alignment _columnAlignment(String key) {
    if (key == 'ead' || key == 'rwa') {
      return Alignment.centerLeft;
    }
    if (key == 'rw') {
      return Alignment.centerLeft;
    }
    return Alignment.centerLeft;
  }

  TextAlign _columnTextAlign(String key) {
    if (key == 'ead' || key == 'rwa') {
      return TextAlign.left;
    }
    if (key == 'rw') {
      return TextAlign.left;
    }
    return TextAlign.left;
  }

  String? _sortKeyForColumn(String key) {
    switch (key) {
      case 'analysis_date':
      case 'id':
      case 'grant_date':
      case 'maturity_date':
      case 'exposure_maturity':
      case 'residual_maturity':
      case 'counterparty':
      case 'counterparty_rating':
      case 'country':
      case 'country_rating':
      case 'country_rw':
      case 'source_currency':
      case 'category':
      case 'rating':
      case 'gross':
      case 'loan_total':
      case 'encours_restant':
      case 'on_balance_amount':
      case 'off_balance_amount':
      case 'crm_exists':
      case 'crm_type':
      case 'ead_bilan':
      case 'ead_hb':
      case 'ead_hb_ccf':
      case 'ead_total':
      case 'rw':
      case 'rwa_eb':
      case 'rwa_hb':
      case 'rwa':
      case 'capital':
        return key;
      default:
        return null;
    }
  }

  Widget _buildStickyTableHeader(
    List<String> columnKeys,
    List<double> widths,
    _ExposureTableMode mode,
    List<ExposureRecord> rows,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fittedWidths = _fitColumnWidthsToAvailableWidth(
          widths,
          constraints.maxWidth,
        );

        return Container(
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF001F4E),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          child: Row(
            children: List<Widget>.generate(columnKeys.length, (index) {
              final key = columnKeys[index];
              final width = fittedWidths[index];
              final needsRightBorder = key == 'encours_restant' || key == 'statut';
              final innerWidth = needsRightBorder ? (width > 1 ? width - 1 : width) : width;
              return _buildStickyHeaderCell(
                width: innerWidth,
                label: _columnLabelForKey(key, mode),
                sortKey: _sortKeyForColumn(key),
                alignment: _columnAlignment(key),
                textAlign: _columnTextAlign(key),
                needsRightBorder: needsRightBorder,
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildStickyHeaderCell({
    required double width,
    required String label,
    required Alignment alignment,
    required TextAlign textAlign,
    String? sortKey,
    bool needsRightBorder = false,
  }) {
    final isSortable = sortKey != null;
    final isSorted = isSortable && _sortColumnKey == sortKey;
    final arrowIcon = _sortAscending
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return Container(
      width: width,
      height: 40,
      decoration: needsRightBorder ? BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ) : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: !isSortable ? null : () => _toggleSort(sortKey),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: alignment,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            style: _tableHeadingStyle,
                            textAlign: textAlign,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                        if (isSortable && isSorted) ...[
                          const SizedBox(width: 4),
                          Icon(
                            arrowIcon,
                            size: 15,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVirtualizedTableRow(
    ExposureRecord row,
    int rowIndex,
    List<String> columnKeys,
    List<double> widths,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedExposureId == row.id;
    final rowColor = _tableRowBackgroundColor(
      rowIndex,
      isSelected: isSelected,
      row: row,
    );
    final borderColor = isSelected
        ? (isDark ? const Color(0xFF5B7DB0) : const Color(0xFF8AB8FF))
        : (isDark ? const Color(0xFF25354E) : const Color(0xFFE4EAF3));

    return LayoutBuilder(
      builder: (context, constraints) {
        final fittedWidths = _fitColumnWidthsToAvailableWidth(
          widths,
          constraints.maxWidth,
        );

        return Container(
          height: _tableRowHeight,
          decoration: BoxDecoration(
            color: rowColor,
            border: Border(
              bottom: BorderSide(color: borderColor, width: 0.7),
            ),
          ),
          child: Row(
            children: List<Widget>.generate(columnKeys.length, (index) {
              final key = columnKeys[index];
              final width = fittedWidths[index];
              final needsRightBorder = key == 'encours_restant' || key == 'statut';
              final innerWidth = needsRightBorder ? (width > 1 ? width - 1 : width) : width;
              final cellContent = _tableCellForKey(row, key, innerWidth);
              
              Widget cell = cellContent;
              if (needsRightBorder) {
                cell = Container(
                  width: width,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: isDark ? const Color(0xFF304764) : const Color(0xFFD6E0EF),
                        width: 1,
                      ),
                    ),
                  ),
                  child: cellContent,
                );
              }

              if (key == 'actions') {
                return SizedBox(
                  width: width,
                  height: _tableRowHeight,
                  child: cell,
                );
              }

              return SizedBox(
                width: width,
                height: _tableRowHeight,
                child: InkWell(
                  onTap: () => _selectExposureRow(row),
                  onDoubleTap: _clearExposureSelection,
                  hoverColor: isSelected
                      ? Colors.transparent
                      : AppTheme.accent.withValues(alpha: isDark ? 0.12 : 0.06),
                  child: cell,
                ),
              );
            }),
          ),
        );
      },
    );
  }

  void _selectExposureRow(ExposureRecord row) {
    if (_selectedExposureId == row.id) {
      return;
    }
    setState(() => _selectedExposureId = row.id);
  }

  void _clearExposureSelection() {
    if (_selectedExposureId == null) {
      return;
    }
    setState(() => _selectedExposureId = null);
  }

  Widget _tableCellForKey(
    ExposureRecord row,
    String key,
    double width,
  ) {
    switch (key) {
      case 'actions':
        return _tableActionsCell(row, width);
      case 'analysis_date':
        return _tableText(_formatExposureDate(row.analysisDate), width);
      case 'id':
        return _tableText(
          row.id,
          width,
          style: _tableCellStyle.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFF7FAFF)
                : const Color(0xFF12213A),
          ),
        );
      case 'grant_date':
        return _tableText(_formatExposureDate(row.grantDate), width);
      case 'maturity_date':
        return _tableText(_formatExposureDate(row.maturityDate), width);
      case 'exposure_maturity':
        return _tableText(_exposureMaturityLabel(row), width);
      case 'residual_maturity':
        return _tableText(_residualMaturityLabel(row), width);
      case 'counterparty':
        return _tableText(row.counterparty.name, width);
      case 'counterparty_rating':
        return _tableText(row.counterparty.rating, width);
      case 'country':
        return _tableText(_displayCountry(row.counterparty.country), width);
      case 'country_rating':
        return _tableText(row.counterparty.countryRating, width);
      case 'country_rw':
        return _tableText(
            _formatRiskWeight(_countryRiskWeightValue(row)), width);
      case 'geo':
        return _tableText(_compactGeoValue(row), width);
      case 'source_currency':
        return _tableText(row.currency, width);
      case 'category':
        return _tableText(_displayExposureCategory(row.categoryLabel), width);
      case 'rating':
        return _tableText(row.ratingLabel.tr(context), width);
      case 'gross':
        return _tableAmountText(
          _convertRowAmount(row.grossAmount, row.currency),
          currencyCode: _displayCurrency == 'Origine' ? row.currency : _displayCurrency,
          width: width,
        );
      case 'loan_total':
        return _tableAmountText(
          _convertRowAmount(_loanTotalAmountValue(row), row.currency),
          currencyCode: _displayCurrency == 'Origine' ? row.currency : _displayCurrency,
          width: width,
        );
      case 'encours_restant':
        return _tableAmountText(
          _convertRowAmount(row.grossAmount, row.currency),
          currencyCode: _displayCurrency == 'Origine' ? row.currency : _displayCurrency,
          width: width,
        );
      case 'on_balance_amount':
        return _tableAmountText(
          _convertRowAmount(_onBalanceAmountValue(row), row.currency),
          currencyCode: _displayCurrency == 'Origine' ? row.currency : _displayCurrency,
          width: width,
        );
      case 'off_balance_amount':
        return _tableAmountText(
          _convertRowAmount(_offBalanceAmountValue(row), row.currency),
          currencyCode: _displayCurrency == 'Origine' ? row.currency : _displayCurrency,
          width: width,
        );
      case 'crm_exists':
        return _tableText(_crmExistsLabel(row), width);
      case 'crm_type':
        return _tableText(_crmTypeTableValue(row), width);
      case 'ead_bilan':
        return _tableAmountText(
          _convertRowAmount(_eadBilanAmountValue(row), row.currency),
          currencyCode: _displayCurrency == 'Origine' ? row.currency : _displayCurrency,
          width: width,
        );
      case 'ead_hb':
        return _tableAmountText(
          _convertRowAmount(_eadHbAmountValue(row), row.currency),
          currencyCode: _displayCurrency == 'Origine' ? row.currency : _displayCurrency,
          width: width,
        );
      case 'ead_hb_ccf':
        return _tableAmountText(
          _convertRowAmount(_eadHbCcfAmountValue(row), row.currency),
          currencyCode: _displayCurrency == 'Origine' ? row.currency : _displayCurrency,
          width: width,
        );
      case 'ead_total':
        return _tableAmountText(
          _convertRowAmount(_eadTotalAmountValue(row), row.currency),
          currencyCode: _displayCurrency == 'Origine' ? row.currency : _displayCurrency,
          width: width,
        );
      case 'rw':
        final rwPercent = _rwPercentValue(row);
        return _tableText(
          '${rwPercent.toStringAsFixed(1)}%',
          width,
          alignment: Alignment.centerLeft,
          textAlign: TextAlign.left,
          style: _tableCellStyle.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFF2F6FF)
                : AppTheme.text,
            fontWeight: FontWeight.w500,
          ),
        );
      case 'rwa_eb':
        return _tableAmountText(
          _convertRowAmount(_rwaEbAmountValue(row), row.currency),
          currencyCode: _displayCurrency == 'Origine' ? row.currency : _displayCurrency,
          width: width,
        );
      case 'rwa_hb':
        return _tableAmountText(
          _convertRowAmount(_rwaHbAmountValue(row), row.currency),
          currencyCode: _displayCurrency == 'Origine' ? row.currency : _displayCurrency,
          width: width,
        );
      case 'rwa':
        return _tableAmountText(
          _convertRowAmount(row.rwa, row.currency),
          currencyCode: _displayCurrency == 'Origine' ? row.currency : _displayCurrency,
          width: width,
        );
      case 'capital':
        return _tableAmountText(
          _convertRowAmount(row.capital, row.currency),
          currencyCode: _displayCurrency == 'Origine' ? row.currency : _displayCurrency,
          width: width,
        );
      case 'statut':
        return _tableStatutCell(row, width);
      case 'crm':
        return _tableText(
            _compactCrmValue(row.crmModeLabel.tr(context)), width);
      default:
        return _tableText('', width);
    }
  }

  Widget _tableStatutCell(ExposureRecord row, double width) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    late final Color background;
    late final Color foreground;
    switch (row.statutPrudentiel) {
      case 'douteuse':
        background = isDark ? const Color(0xFF4A1D22) : const Color(0xFFFBE7E7);
        foreground = isDark ? const Color(0xFFFF9B9B) : const Color(0xFFB3261E);
        break;
      case 'impayee':
        background = isDark ? const Color(0xFF4A3A15) : const Color(0xFFFBF1D9);
        foreground = isDark ? const Color(0xFFF0C368) : const Color(0xFF8A6100);
        break;
      default:
        background = isDark ? const Color(0xFF16351F) : const Color(0xFFE4F3E8);
        foreground = isDark ? const Color(0xFF7FD79A) : const Color(0xFF1B7A3D);
    }
    final label = row.statutPrudentielLabel;
    final showsDays = row.isImpayee && row.joursImpayes > 0;
    return Container(
      width: width,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (row.declassementManuel) ...[
              Icon(CupertinoIcons.lock_fill, size: 10, color: foreground),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                showsDays ? '$label · ${row.joursImpayes} j' : label,
                overflow: TextOverflow.ellipsis,
                style: _tableCellStyle.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableActionsCell(ExposureRecord row, double width) {
    final isDisabled = _isDeleting;
    final iconColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFEAF1FF)
        : AppTheme.text;
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2B3D59)
                : const Color(0xFFDCE7F6),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _tableActionIconButton(
            icon: CupertinoIcons.calendar_badge_plus,
            color: AppTheme.accent,
            enabled: !isDisabled,
            onPressed: () {
              _selectExposureRow(row);
              _openSuiviPanel(row);
            },
            semanticLabel: "Suivi des versements de l'exposition ${row.id}",
          ),
          const SizedBox(width: 3),
          _tableActionIconButton(
            icon: CupertinoIcons.pencil,
            color: iconColor,
            enabled: !isDisabled,
            onPressed: () {
              _selectExposureRow(row);
              _openEditPanel(row);
            },
            semanticLabel: "Modifier l'exposition ${row.id}",
          ),
          const SizedBox(width: 3),
          _tableActionIconButton(
            icon: CupertinoIcons.trash,
            color: AppTheme.danger,
            enabled: !isDisabled,
            onPressed: () {
              _selectExposureRow(row);
              _deleteSingleExposure(row);
            },
            semanticLabel: "Supprimer l'exposition ${row.id}",
          ),
        ],
      ),
    );
  }

  Future<void> _openSuiviPanel(ExposureRecord row) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => SuiviVersementsDialog(
        api: widget.api,
        exposureId: row.id,
        counterpartyName: row.counterparty.name,
      ),
    );
    if (changed == true && mounted) {
      await _refresh();
    }
  }

  Widget _tableActionIconButton({
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onPressed,
    required String semanticLabel,
  }) {
    final resolvedColor =
        enabled ? color : AppTheme.muted.withValues(alpha: 0.45);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_screenBorderRadius),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(_screenBorderRadius),
          child: SizedBox(
            width: 26,
            height: 26,
            child: Icon(icon, size: 18, color: resolvedColor),
          ),
        ),
      ),
    );
  }

  void _toggleSort(String column) {
    setState(() {
      if (_sortColumnKey != column) {
        _sortColumnKey = column;
        _sortAscending = true;
      } else if (_sortAscending) {
        _sortAscending = false;
      } else {
        _sortColumnKey = null;
        _sortAscending = true;
      }
      _recomputeVisibleView();
    });
  }

  Widget _buildTabSelector(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: _currentTabIndex,
          children: {
            0: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text('Données importées', style: TextStyle(fontSize: 13, fontWeight: _currentTabIndex == 0 ? FontWeight.w600 : FontWeight.w500)),
            ),
            1: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text('Indicateurs calculés', style: TextStyle(fontSize: 13, fontWeight: _currentTabIndex == 1 ? FontWeight.w600 : FontWeight.w500)),
            ),
            2: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text('Evolution des remboursements', style: TextStyle(fontSize: 13, fontWeight: _currentTabIndex == 2 ? FontWeight.w600 : FontWeight.w500)),
            ),
          },
          onValueChanged: (int? value) {
            if (value != null && value != _currentTabIndex) {
              setState(() {
                _currentTabIndex = value;
                _recomputeVisibleView();
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildControlsPanel(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final panelBorderColor =
        isDark ? const Color(0xFF22304B) : const Color(0xFFDDE7F6);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101C32) : const Color(0xFFF6F9FF),
        borderRadius: BorderRadius.circular(_screenBorderRadius),
        border: Border.all(color: panelBorderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x26040A16) : const Color(0x080F172A),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Theme(
        data: _compactControlsTheme(
          theme,
          minHeight: _optionControlHeight,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 3, vertical: 8.0),
          labelFontSize: 9.2,
          floatingLabelFontSize: 9.2,
          hintFontSize: 10.2,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth =
                constraints.maxWidth.isFinite ? constraints.maxWidth : 860.0;
            final isNarrow = availableWidth < 820;
            final selectorWidth = isNarrow ? availableWidth : 230.0;
            final columnChooserWidth =
                isNarrow ? availableWidth.clamp(0.0, 178.0).toDouble() : 178.0;
            final activeFieldWidth = isNarrow
                ? availableWidth
                : (availableWidth * 0.18).clamp(200.0, 300.0).toDouble();
            final addButton = _buildAddExposureButton(
              isDark: isDark,
              onPressed: _screenBusyMessage == null ? _openCreatePanel : null,
            );
            final controls = [
              _buildFilterSelectorControl(
                width: selectorWidth,
                isDark: isDark,
              ),
              _buildActiveFilterControl(width: activeFieldWidth),
              _buildColumnChooserButton(
                width: columnChooserWidth,
                isDark: isDark,
              ),
              _buildSortDirectionButton(isDark: isDark),
              _buildResetFiltersButton(isDark: isDark),
            ];

            if (!isNarrow) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  controls[0],
                  const SizedBox(width: _controlGap),
                  controls[1],
                  const SizedBox(width: _controlGap),
                  controls[2],
                  const SizedBox(width: _controlGap),
                  controls[3],
                  const SizedBox(width: _controlGap),
                  controls[4],
                  const Spacer(),
                  addButton,
                ],
              );
            }

            return Wrap(
              spacing: _controlGap,
              runSpacing: _controlGap,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...controls,
                addButton,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterSelectorControl({
    required double width,
    required bool isDark,
  }) {
    final borderColor =
        isDark ? const Color(0xFF2A4164) : const Color(0xFFD5E2F6);
    final fillColor =
        isDark ? const Color(0xFF13243F) : const Color(0xFFFFFFFF);
    final labelColor =
        isDark ? const Color(0xFFB8C8E8) : const Color(0xFF2563EB);

    return SizedBox(
      width: width,
      height: _optionControlHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(_screenBorderRadius),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0x18040A16)
                        : const Color(0x0A2563EB),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 40,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              color: fillColor,
              child: Text(
                'Filtre'.tr(context),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: labelColor,
                      fontSize: 8.2,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
              ),
            ),
          ),
          Positioned.fill(
            child: Row(
              children: [
                SizedBox(
                  width: _optionControlHeight,
                  height: _optionControlHeight,
                  child: Icon(
                    Icons.tune_rounded,
                    size: 15,
                    color: isDark ? const Color(0xFFDCEBFF) : AppTheme.accent,
                  ),
                ),
                Expanded(
                  child: SizedBox.expand(
                    child: _buildCompactDropdownField(
                      value: _activeFilterKey,
                      label: 'Filtre',
                      items: _filterOptionKeys,
                      displayTextBuilder: _filterOptionLabel,
                      onChanged: _selectFilterOption,
                      showFrame: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterControl({required double width}) {
    switch (_activeFilterKey) {
      case _filterId:
        return _buildCompactTextField(
          controller: _idFilterController,
          label: 'ID exposition',
          hint: 'Saisir un identifiant',
          width: width,
          height: _optionControlHeight,
        );
      case _filterCountry:
        return _buildCompactTextField(
          controller: _countryFilterController,
          label: 'Pays',
          hint: 'Saisir un pays',
          width: width,
          height: _optionControlHeight,
        );
      case _filterCategory:
        return SizedBox(
          width: width,
          height: _optionControlHeight,
          child: _buildCompactDropdownField(
            value: _categoryFilter,
            label: 'Catégorie',
            items: [
              'Toutes',
              ...exposureCategories.map((item) => item.prudentialLabel),
            ],
            displayTextBuilder: (item) =>
                item == 'Toutes' ? item : _displayExposureCategory(item),
            onChanged: (value) => setState(() {
              _categoryFilter = value ?? 'Toutes';
              _recomputeVisibleView();
            }),
          ),
        );
      case _filterZone:
        return SizedBox(
          width: width,
          height: _optionControlHeight,
          child: _buildCompactDropdownField(
            value: _zoneFilter,
            label: 'Zone',
            items: const ['Toutes', 'UEMOA', 'CEMAC', 'Hors zone'],
            onChanged: (value) => setState(() {
              _zoneFilter = value ?? 'Toutes';
              _recomputeVisibleView();
            }),
          ),
        );
      case _filterRating:
        return SizedBox(
          width: width,
          height: _optionControlHeight,
          child: _buildCompactDropdownField(
            value: _ratingFilter,
            label: 'Notation',
            items: ['Toutes', ..._ratings],
            onChanged: (value) => setState(() {
              _ratingFilter = value ?? 'Toutes';
              _recomputeVisibleView();
            }),
          ),
        );
      case _filterCrm:
        return SizedBox(
          width: width,
          height: _optionControlHeight,
          child: _buildCompactDropdownField(
            value: _crmFilter,
            label: 'Type CRM',
            items: const [
              'Toutes',
              'Aucune',
              'CRM financee',
              'CRM non financee',
            ],
            onChanged: (value) => setState(() {
              _crmFilter = value ?? 'Toutes';
              _recomputeVisibleView();
            }),
          ),
        );
      case _filterCounterparty:
      default:
        return _buildCompactTextField(
          controller: _counterpartyFilterController,
          label: 'Contrepartie',
          hint: 'Nom ou raison sociale',
          width: width,
          height: _optionControlHeight,
        );
    }
  }

  Widget _buildColumnChooserButton({
    required double width,
    required bool isDark,
  }) {
    final visibleCount =
        _visibleTableColumnKeys(_ExposureTableMode.full).length;

    return SizedBox(
      width: width,
      height: _optionControlHeight,
      child: Tooltip(
        message: 'Choisir les colonnes à afficher'.tr(context),
        child: OutlinedButton.icon(
          onPressed: _openColumnChooser,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            foregroundColor: isDark ? const Color(0xFFEAF1FF) : AppTheme.text,
            backgroundColor:
                isDark ? const Color(0xFF13243F) : const Color(0xFFFFFFFF),
            surfaceTintColor: Colors.transparent,
            minimumSize: Size(width, _optionControlHeight),
            side: BorderSide(
              color: isDark ? const Color(0xFF2A4164) : const Color(0xFFD5E2F6),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_screenBorderRadius),
            ),
            elevation: 1,
            shadowColor:
                isDark ? const Color(0x22040A16) : const Color(0x102563EB),
            textStyle: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10.8,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
          icon: const Icon(CupertinoIcons.eye_fill, size: 15),
          label: Text(
            'Colonnes ($visibleCount)'.tr(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildSortDirectionButton({required bool isDark}) {
    final enabled = _sortColumnKey != null;
    return _buildOptionIconButton(
      isDark: isDark,
      tooltip: _sortAscending ? 'Ordre croissant' : 'Ordre décroissant',
      icon: _sortAscending
          ? Icons.arrow_upward_rounded
          : Icons.arrow_downward_rounded,
      accentColor: AppTheme.accent,
      onPressed: enabled
          ? () => setState(() {
                _sortAscending = !_sortAscending;
                _recomputeVisibleView();
              })
          : null,
    );
  }

  Widget _buildResetFiltersButton({required bool isDark}) {
    return _buildOptionIconButton(
      isDark: isDark,
      tooltip: 'Réinitialiser les options',
      icon: Icons.restart_alt_rounded,
      accentColor: AppTheme.warning,
      onPressed: _resetFilters,
    );
  }

  Widget _buildAddExposureButton({
    required bool isDark,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;

    return SizedBox(
      height: _optionControlHeight,
      child: Tooltip(
        message: 'Créer une exposition'.tr(context),
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: enabled
                ? AppTheme.accent
                : (isDark ? const Color(0xFF1B2B47) : const Color(0xFFE8EEF8)),
            foregroundColor: enabled ? Colors.white : const Color(0xFF7A8AA4),
            disabledBackgroundColor:
                isDark ? const Color(0xFF1B2B47) : const Color(0xFFE8EEF8),
            disabledForegroundColor:
                isDark ? const Color(0xFF6F7E96) : const Color(0xFF8A98AC),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(116, _optionControlHeight),
            elevation: enabled ? 2 : 0,
            shadowColor:
                isDark ? const Color(0x22040A16) : const Color(0x242563EB),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_screenBorderRadius),
            ),
            visualDensity: VisualDensity.compact,
            textStyle: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10.4,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
          icon: const Icon(CupertinoIcons.plus, size: 14),
          label: Text(
            'Ajouter'.tr(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionIconButton({
    required bool isDark,
    required String tooltip,
    required IconData icon,
    required Color accentColor,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;

    return SizedBox(
      height: _optionControlHeight,
      width: _optionControlHeight,
      child: Tooltip(
        message: tooltip.tr(context),
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: accentColor,
            backgroundColor:
                isDark ? const Color(0xFF13243F) : const Color(0xFFFFFFFF),
            disabledForegroundColor:
                isDark ? const Color(0xFF61708B) : const Color(0xFF9AA8BA),
            surfaceTintColor: Colors.transparent,
            minimumSize: const Size(_optionControlHeight, _optionControlHeight),
            side: BorderSide(
              color: isDark ? const Color(0xFF2A4164) : const Color(0xFFD5E2F6),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_screenBorderRadius),
            ),
            shadowColor: enabled
                ? (isDark ? const Color(0x22040A16) : const Color(0x102563EB))
                : Colors.transparent,
            elevation: enabled ? 1 : 0,
          ),
          child: Icon(icon, size: 15),
        ),
      ),
    );
  }

  Future<void> _openColumnChooser() async {
    if (!mounted) {
      return;
    }

    final draftKeys = Set<String>.from(_visibleColumnKeys);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final surfaceColor =
            isDark ? const Color(0xFF101C32) : const Color(0xFFFFFFFF);
        final borderColor =
            isDark ? const Color(0xFF2A4164) : const Color(0xFFD5E2F6);
        final titleColor =
            isDark ? const Color(0xFFF2F6FF) : const Color(0xFF13203A);
        final mutedColor =
            isDark ? const Color(0xFFB8C8E8) : const Color(0xFF64748B);

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final currentTabKeys = _currentTabIndex == 0 ? _importedColumnKeys : _calculatedColumnKeys;
            final selectedKeys = _normalizeVisibleColumnKeys(draftKeys).where((k) => currentTabKeys.contains(k)).toList();
            final selectedCount = selectedKeys.length;

            return AlertDialog(
              backgroundColor: surfaceColor,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_screenBorderRadius),
                side: BorderSide(color: borderColor),
              ),
              titlePadding: const EdgeInsets.fromLTRB(5, 4, 5, 8),
              contentPadding: const EdgeInsets.fromLTRB(5, 8, 5, 8),
              actionsPadding: const EdgeInsets.fromLTRB(5, 8, 5, 4),
              title: Row(
                children: [
                  const Icon(
                    CupertinoIcons.eye_fill,
                    size: 17,
                    color: AppTheme.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Colonnes affichées'.tr(context),
                      style: TextStyle(
                        color: titleColor,
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                  ),
                  Text(
                    '$selectedCount/${currentTabKeys.length}',
                    style: TextStyle(
                      color: mutedColor,
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                height: 430,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Cochez les colonnes à afficher dans le tableau.'
                                .tr(context),
                            style: TextStyle(
                              color: mutedColor,
                              fontSize: 10.4,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setDialogState(() {
                            draftKeys.addAll(currentTabKeys);
                          }),
                          child: Text('Tout afficher'.tr(context)),
                        ),
                        TextButton(
                          onPressed: () => setDialogState(() {
                            draftKeys.removeAll(currentTabKeys);
                            draftKeys.addAll(
                              currentTabKeys.where(
                                _isLockedTableColumn,
                              ),
                            );
                          }),
                          child: Text('Réduire'.tr(context)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF13243F)
                              : const Color(0xFFF6F9FF),
                          borderRadius:
                              BorderRadius.circular(_screenBorderRadius),
                          border: Border.all(color: borderColor),
                        ),
                        child: ListView.separated(addSemanticIndexes: false,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: currentTabKeys.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: borderColor.withValues(alpha: 0.58),
                          ),
                          itemBuilder: (context, index) {
                            final key = currentTabKeys[index];
                            final locked = _isLockedTableColumn(key);
                            final checked = locked || draftKeys.contains(key);

                            return CheckboxListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: checked,
                              onChanged: locked
                                  ? null
                                  : (value) => setDialogState(() {
                                        if (value ?? false) {
                                          draftKeys.add(key);
                                        } else {
                                          draftKeys.remove(key);
                                        }
                                      }),
                              title: Text(
                                _columnLabelForKey(
                                  key,
                                  _ExposureTableMode.full,
                                ).tr(context),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: locked ? mutedColor : titleColor,
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11.2,
                                  fontWeight: FontWeight.w500,
                                  height: 1,
                                ),
                              ),
                              subtitle: locked
                                  ? Text(
                                      'Toujours visible'.tr(context),
                                      style: TextStyle(
                                        color: mutedColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                        height: 1.1,
                                      ),
                                    )
                                  : null,
                              activeColor: AppTheme.accent,
                              checkColor: Colors.white,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('Annuler'.tr(context)),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(draftKeys),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_screenBorderRadius),
                    ),
                  ),
                  child: Text('Appliquer'.tr(context)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _visibleColumnKeys = _normalizeVisibleColumnKeys(result);
      final visibleKeys = _visibleTableColumnKeys(_ExposureTableMode.full);
      if (_sortColumnKey != null && !visibleKeys.contains(_sortColumnKey)) {
        _sortColumnKey = 'id';
        _sortAscending = true;
        _recomputeVisibleView();
      }
    });

    if (_tableHorizontalController.hasClients) {
      _tableHorizontalController.jumpTo(0);
    }
  }

  String _filterOptionLabel(String key) {
    return switch (key) {
      _filterId => 'ID exposition',
      _filterCountry => 'Pays',
      _filterCategory => 'Catégorie',
      _filterZone => 'Zone',
      _filterRating => 'Notation',
      _filterCrm => 'Type CRM',
      _ => 'Contrepartie',
    };
  }

  void _selectFilterOption(String? key) {
    if (key == null || key == _activeFilterKey) {
      return;
    }
    setState(() {
      _activeFilterKey = key;
      _sortColumnKey = _sortKeyForFilter(key);
      _sortAscending = true;
      _clearInactiveFilters(key);
      _recomputeVisibleView();
    });
  }

  String _sortKeyForFilter(String filterKey) {
    return switch (filterKey) {
      _filterId => 'id',
      _filterCountry => 'country',
      _filterCategory => 'category',
      _filterZone => 'zone',
      _filterRating => 'rating',
      _filterCrm => 'crm',
      _ => 'counterparty',
    };
  }

  void _clearInactiveFilters(String activeKey) {
    if (activeKey != _filterId) {
      _idFilterController.clear();
    }
    if (activeKey != _filterCounterparty) {
      _counterpartyFilterController.clear();
    }
    if (activeKey != _filterCountry) {
      _countryFilterController.clear();
    }
    if (activeKey != _filterCategory) {
      _categoryFilter = 'Toutes';
    }
    if (activeKey != _filterZone) {
      _zoneFilter = 'Toutes';
    }
    if (activeKey != _filterRating) {
      _ratingFilter = 'Toutes';
    }
    if (activeKey != _filterCrm) {
      _crmFilter = 'Toutes';
    }
  }

  ThemeData _compactControlsTheme(
    ThemeData baseTheme, {
    double minHeight = _filterControlHeight,
    EdgeInsetsGeometry contentPadding =
        const EdgeInsets.symmetric(horizontal: 3, vertical: 4.0),
    double labelFontSize = 8.8,
    double floatingLabelFontSize = 8.8,
    double hintFontSize = 9.8,
  }) {
    final isDark = baseTheme.brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF22304B) : const Color(0xFFDCE5F1);
    final fillColor = isDark ? const Color(0xFF14233D) : Colors.white;
    final labelColor =
        isDark ? const Color(0xFF9FB3D4) : const Color(0xFF637792);
    final hintColor =
        isDark ? const Color(0xFF8EA1BF) : const Color(0xFF7B8AA3);

    return baseTheme.copyWith(
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        isDense: true,
        filled: true,
        fillColor: fillColor,
        constraints: BoxConstraints(
          minHeight: minHeight,
          maxHeight: minHeight,
        ),
        contentPadding: contentPadding,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: baseTheme.textTheme.labelMedium?.copyWith(
          color: labelColor,
          fontWeight: FontWeight.w500,
          fontSize: labelFontSize,
        ),
        floatingLabelStyle: baseTheme.textTheme.labelMedium?.copyWith(
          color: AppTheme.accent,
          fontWeight: FontWeight.w500,
          fontSize: floatingLabelFontSize,
        ),
        hintStyle: baseTheme.textTheme.bodyMedium?.copyWith(
          color: hintColor,
          fontSize: hintFontSize,
          fontWeight: FontWeight.w500,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 24,
          minHeight: 24,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 24,
          minHeight: 24,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_screenBorderRadius),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_screenBorderRadius),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_screenBorderRadius),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.2),
        ),
      ),
    );
  }

  Widget _buildCompactDropdownField({
    required String? value,
    required String label,
    String? hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String Function(String item)? displayTextBuilder,
    bool showFrame = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: isDark ? const Color(0xFFEAF1FF) : const Color(0xFF13203A),
          fontWeight: FontWeight.w500,
          fontSize: 11.4,
          height: 1.08,
        );

    final dropdown = DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        isDense: true,
        menuMaxHeight: 320,
        itemHeight: null,
        dropdownColor: isDark ? const Color(0xFF13243F) : Colors.white,
        borderRadius: BorderRadius.circular(_screenBorderRadius),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 16,
          color: isDark ? const Color(0xFF9FB3D4) : const Color(0xFF64748B),
        ),
        style: textStyle,
        hint: hint == null
            ? null
            : Text(
                hint.tr(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle?.copyWith(
                  color: Theme.of(context).hintColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
        selectedItemBuilder: (context) => items.map(
          (item) {
            final displayText = displayTextBuilder?.call(item) ?? item;
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                displayText.tr(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            );
          },
        ).toList(),
        items: items.map(
          (item) {
            final displayText = displayTextBuilder?.call(item) ?? item;
            return DropdownMenuItem<String>(
              value: item,
              child: SizedBox(
                height: 36,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    displayText.tr(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                ),
              ),
            );
          },
        ).toList(),
        onChanged: onChanged,
      ),
    );

    if (!showFrame) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 3, 3, 2),
        child: dropdown,
      );
    }

    return _buildOptionFieldFrame(label: label, child: dropdown);
  }

  Widget _buildOptionFieldFrame({
    required String label,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF2A4164) : const Color(0xFFD5E2F6);
    final fillColor = isDark ? const Color(0xFF13243F) : Colors.white;
    final labelColor =
        isDark ? const Color(0xFFB8C8E8) : const Color(0xFF2563EB);

    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(_screenBorderRadius),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0x18040A16)
                        : const Color(0x082563EB),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              color: fillColor,
              child: Text(
                label.tr(context),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: labelColor,
                      fontSize: 8.2,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(3, 3, 8, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    double? width,
    double height = _textFilterControlHeight,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: width,
      height: height,
      child: _buildOptionFieldFrame(
        label: label,
        child: SizedBox(
          height: 21,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Colors.transparent),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                hoverColor: Colors.transparent,
                isDense: false,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                hintText: hint.tr(context),
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? const Color(0xFF9FB3D4)
                          : const Color(0xFF6F7D92),
                      fontSize: 11.6,
                      fontWeight: FontWeight.w500,
                      height: 1.05,
                    ),
              ),
              cursorHeight: 15,
              maxLines: 1,
              strutStyle: const StrutStyle(
                fontSize: 11.6,
                height: 1.05,
                forceStrutHeight: true,
              ),
              textAlignVertical: TextAlignVertical.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    backgroundColor: Colors.transparent,
                    color: isDark ? const Color(0xFFEAF1FF) : AppTheme.text,
                    fontWeight: FontWeight.w500,
                    fontSize: 11.6,
                    height: 1.05,
                  ),
              onChanged: (_) => setState(_recomputeVisibleView),
            ),
          ),
        ),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _activeFilterKey = _filterCounterparty;
      _sortColumnKey = _sortKeyForFilter(_activeFilterKey);
      _sortAscending = true;
      _idFilterController.clear();
      _counterpartyFilterController.clear();
      _countryFilterController.clear();
      _categoryFilter = 'Toutes';
      _zoneFilter = 'Toutes';
      _ratingFilter = 'Toutes';
      _crmFilter = 'Toutes';
      _recomputeVisibleView();
    });
  }

  void _recomputeVisibleView() {
    final rows = _buildVisibleRows();
    _visibleRows = rows;
    if (_selectedExposureId != null &&
        rows.every((row) => row.id != _selectedExposureId)) {
      _selectedExposureId = null;
    }
  }

  List<ExposureRecord> _buildVisibleRows() {
    final idFilter = _idFilterController.text.trim().toLowerCase();
    final counterpartyFilter =
        _counterpartyFilterController.text.trim().toLowerCase();
    final countryFilter = normalizedCountryName(
      _countryFilterController.text.trim(),
    );

    final rows = _allRows.where((row) {
      final matchesId =
          idFilter.isEmpty || row.id.toLowerCase().contains(idFilter);
      final matchesCounterparty = counterpartyFilter.isEmpty ||
          row.counterparty.name.toLowerCase().contains(counterpartyFilter);
      final matchesCountry = countryFilter.isEmpty ||
          normalizedCountryName(row.counterparty.country)
              .contains(countryFilter);
      final matchesCategory =
          _categoryFilter == 'Toutes' || row.categoryLabel == _categoryFilter;
      final matchesZone = _zoneFilter == 'Toutes' || row.zone == _zoneFilter;
      final matchesRating =
          _ratingFilter == 'Toutes' || row.ratingLabel == _ratingFilter;
      final matchesCrm =
          _crmFilter == 'Toutes' || row.crmModeLabel == _crmFilter;

      return matchesId &&
          matchesCounterparty &&
          matchesCountry &&
          matchesCategory &&
          matchesZone &&
          matchesRating &&
          matchesCrm;
    }).toList();

    if (_sortColumnKey != null) {
      rows.sort((left, right) {
        final comparison = switch (_sortColumnKey) {
          'analysis_date' =>
            _compareNullableDates(left.analysisDate, right.analysisDate),
          'id' => _compareExposureIds(left.id, right.id),
          'grant_date' =>
            _compareNullableDates(left.grantDate, right.grantDate),
          'maturity_date' =>
            _compareNullableDates(left.maturityDate, right.maturityDate),
          'exposure_maturity' => _durationInMonths(
              left.grantDate,
              left.maturityDate,
            ).compareTo(
              _durationInMonths(right.grantDate, right.maturityDate),
            ),
          'residual_maturity' => _durationInMonths(
              left.analysisDate,
              left.maturityDate,
            ).compareTo(
              _durationInMonths(right.analysisDate, right.maturityDate),
            ),
          'counterparty' =>
            left.counterparty.name.compareTo(right.counterparty.name),
          'counterparty_rating' => _compareRatings(
              left.counterparty.rating, right.counterparty.rating),
          'country' => _displayCountry(left.counterparty.country)
              .compareTo(_displayCountry(right.counterparty.country)),
          'country_rating' => _compareRatings(left.counterparty.countryRating,
              right.counterparty.countryRating),
          'country_rw' => _countryRiskWeightValue(left)
              .compareTo(_countryRiskWeightValue(right)),
          'zone' => left.zone.compareTo(right.zone),
          'source_currency' => left.currency.compareTo(right.currency),
          'category' => _displayExposureCategory(left.categoryLabel)
              .compareTo(_displayExposureCategory(right.categoryLabel)),
          'rating' => _compareRatings(left.ratingLabel, right.ratingLabel),
          'loan_total' =>
            _convertRowAmount(_loanTotalAmountValue(left), left.currency)
                .compareTo(_convertRowAmount(
                    _loanTotalAmountValue(right), right.currency)),
          'encours_restant' =>
            _convertRowAmount(left.grossAmount, left.currency)
                .compareTo(_convertRowAmount(
                    right.grossAmount, right.currency)),
          'on_balance_amount' =>
            _convertRowAmount(_onBalanceAmountValue(left), left.currency)
                .compareTo(_convertRowAmount(
                    _onBalanceAmountValue(right), right.currency)),
          'off_balance_amount' =>
            _convertRowAmount(_offBalanceAmountValue(left), left.currency)
                .compareTo(_convertRowAmount(
                    _offBalanceAmountValue(right), right.currency)),
          'crm_exists' =>
            _crmExistsLabel(left).compareTo(_crmExistsLabel(right)),
          'crm_type' =>
            _crmTypeTableValue(left).compareTo(_crmTypeTableValue(right)),
          'ead_bilan' =>
            _convertRowAmount(_eadBilanAmountValue(left), left.currency)
                .compareTo(_convertRowAmount(
                    _eadBilanAmountValue(right), right.currency)),
          'ead_hb' => _convertRowAmount(_eadHbAmountValue(left), left.currency)
              .compareTo(
                  _convertRowAmount(_eadHbAmountValue(right), right.currency)),
          'ead_hb_ccf' =>
            _convertRowAmount(_eadHbCcfAmountValue(left), left.currency)
                .compareTo(_convertRowAmount(
                    _eadHbCcfAmountValue(right), right.currency)),
          'ead_total' =>
            _convertRowAmount(_eadTotalAmountValue(left), left.currency)
                .compareTo(_convertRowAmount(
                    _eadTotalAmountValue(right), right.currency)),
          'rw' => left.finalRw.compareTo(right.finalRw),
          'rwa_eb' => _convertRowAmount(_rwaEbAmountValue(left), left.currency)
              .compareTo(
                  _convertRowAmount(_rwaEbAmountValue(right), right.currency)),
          'rwa_hb' => _convertRowAmount(_rwaHbAmountValue(left), left.currency)
              .compareTo(
                  _convertRowAmount(_rwaHbAmountValue(right), right.currency)),
          'rwa' => _convertRowAmount(left.rwa, left.currency)
              .compareTo(_convertRowAmount(right.rwa, right.currency)),
          'capital' => _convertRowAmount(left.capital, left.currency)
              .compareTo(_convertRowAmount(right.capital, right.currency)),
          'crm' => left.crmModeLabel.compareTo(right.crmModeLabel),
          _ => _convertRowAmount(left.grossAmount, left.currency)
              .compareTo(_convertRowAmount(right.grossAmount, right.currency)),
        };
        return _sortAscending ? comparison : -comparison;
      });
    }

    return rows;
  }


  double _convertAmountForDisplay(double amount, String sourceCurrency) {
    return convertAmount(
      amount,
      fromCurrency: sourceCurrency,
      toCurrency: _displayCurrency,
    );
  }

  String get _displayCurrencyLabel {
    switch (normalizeCurrencyCode(_displayCurrency)) {
      case 'XOF':
        return 'FCFA';
      default:
        return normalizeCurrencyCode(_displayCurrency);
    }
  }

  double _convertRowAmount(double amount, String sourceCurrency) {
    return _convertAmountForDisplay(amount, sourceCurrency);
  }

  PortfolioAmountUnit get _amountUnit =>
      PortfolioAmountUnitScope.maybeOf(context);

  String _formatDisplayAmount(double value) {
    final scaled = value / _amountUnit.divisor;
    return '${AppFormatters.compactNumber(scaled)} ${_amountUnit.label} $_displayCurrencyLabel';
  }

  Future<void> _refresh() async {
    final moduleFuture = widget.api.fetchExpositionsModule();
    final referentielsFuture = _hasLoadedReferentiels
        ? Future<ReferentielsModuleData?>.value(null)
        : widget.api.fetchReferentiels().then<ReferentielsModuleData?>(
              (value) => value,
              onError: (_) => null,
            );

    final module = await moduleFuture;
    final referentiels = await referentielsFuture;

    if (!mounted) {
      return;
    }

    setState(() {
      _allRows = module.exposures;
      if (referentiels != null) {
        _ratings = _sortRatings(
            referentiels.ratings.map((item) => item.label).toList());
        _hasLoadedReferentiels = true;
      }
      if (_ratings.isEmpty) {
        _ratings = _sortRatings(prudentialRatings);
      }
      _recomputeVisibleView();
    });
  }

  void _upsertLocalExposure(ExposureRecord record) {
    final nextRows = _allRows.toList(growable: true);
    final index = nextRows.indexWhere((item) => item.id == record.id);
    if (index >= 0) {
      nextRows[index] = record;
    } else {
      nextRows.add(record);
    }

    setState(() {
      _allRows = nextRows;
      _recomputeVisibleView();
    });
  }

  Future<void> _openCreatePanel() async {
    final nextExposureId = await widget.api.fetchNextExposureId();
    final draft = ExposureDraft(
      id: nextExposureId,
      counterpartyName: '',
      country: '',
      countryRating: '',
      categoryCode: '',
      rating: '',
      grossAmount: 0,
      loanTotalAmount: 0,
      onBalanceExposureAmount: 0,
      currency: _displayCurrency,
      status: 'Active',
      crmMode: 'Aucune',
      crmType: '',
      collateralValue: 0,
      collateralCurrency: '',
      collateralType: '',
      issuerType: '',
      issuerRating: '',
      maturityBucket: '',
      fxHaircut: 0,
      guarantorName: '',
      guarantorCategoryCode: '',
      guarantorRating: '',
      guarantorCountry: '',
      guarantorCountryRating: '',
      crmCoveragePercent: 0,
      comment: '',
      analysisDate: DateTime.now(),
      sovereignSpecialCase: sovereignNoSpecialCase,
      sovereignPreferentialZeroWeight: false,
      sovereignOceEstablished: false,
      sovereignOceNote: '',
      publicBodyUemoaFcfaCase: null,
      publicBodyFinancesNonPublicActivity: null,
      bmdHighQualityCase: null,
      bmdUemoaFcfaCase: null,
      bmdUemoaCriteriaSatisfied: null,
      bmdListedInstitutionFcfaCase: null,
      bankInstitutionCase: null,
      otherAssetType: null,
      offBalanceRiskLevel: null,
      retailEligibilityCriteriaSatisfied: null,
      residentialMortgageEligible: null,
      commercialRealEstateEligible: null,
      defaultedExposureInitialRiskWeight: null,
      defaultedExposureResidentialMortgageInDefault: null,
      defaultedExposureProvisionAtLeastTwentyPercent: null,
      enterpriseExceedsBceaoDegradationThreshold: null,
      enterprisePrudentialProcedure: null,
      enterpriseInvestmentFirmWithoutBankingLaw: null,
    );
    await _showEditorPage(draft, isCreateMode: true);
  }

  Future<void> _openEditPanel(ExposureRecord row) async {
    await _showEditorPage(row.toDraft(), isCreateMode: false);
  }

  Future<void> _saveDraft(
    ExposureDraft draft, {
    required bool isCreateMode,
  }) async {
    final savedRecord = isCreateMode
        ? await widget.api.createExposure(draft)
        : await widget.api.updateExposure(draft);
    if (!mounted) {
      return;
    }

    _upsertLocalExposure(savedRecord);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF16A34A),
        content: Text(
          isCreateMode
              ? context.tr('Exposition ajoutee avec succes.')
              : context.tr('Exposition mise a jour.'),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _showEditorPage(
    ExposureDraft draft, {
    required bool isCreateMode,
  }) async {
    final routeCurrencyNotifier = widget.displayCurrencyListenable;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) {
          return Scaffold(
            backgroundColor: Colors.black.withValues(alpha: 0.22),
            body: SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: MediaQuery.of(routeContext).size.width > 1320
                      ? 560
                      : MediaQuery.of(routeContext).size.width,
                  height: double.infinity,
                  child: Material(
                    elevation: 16,
                    child: PortfolioCurrencyScope(
                      notifier: routeCurrencyNotifier,
                      child: ExposureFormCard(
                        api: widget.api,
                        initialDraft: draft,
                        ratings: _ratings,
                        title: isCreateMode
                            ? 'Créer une exposition'
                            : "Mettre à jour l'exposition",
                        submitLabel: isCreateMode
                            ? "Enregistrer l'exposition"
                            : 'Enregistrer les modifications',
                        onCancel: () => Navigator.of(routeContext).pop(),
                        onSubmit: (submittedDraft) async {
                          await _saveDraft(
                            submittedDraft,
                            isCreateMode: isCreateMode,
                          );
                          if (mounted && routeContext.mounted) {
                            Navigator.of(routeContext).pop();
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteSingleExposure(ExposureRecord row) async {
    if (_isDeleting) {
      return;
    }

    final decision = await _confirmDeleteSelection([row.id]);
    if (!decision.confirmed) {
      return;
    }

    try {
      if (mounted) {
        setState(() => _isDeleting = true);
      }
      final result = await widget.api.deleteExposures(
        [row.id],
        reindexIds: decision.reindexIds,
      );
      final deletedIds =
          List<String>.from(result['deleted_ids'] as List? ?? const []);
      final missingIds =
          List<String>.from(result['missing_ids'] as List? ?? const []);
      final reindexedIds = result['reindexed_ids'] == true;

      await _queueRefresh();
      if (mounted) {
        final message = _buildDeleteResultMessage(
          deletedIds: deletedIds,
          missingIds: missingIds,
          reindexedIds: reindexedIds,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _buildDeleteErrorMessage(
                error,
                reindexIds: decision.reindexIds,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<_DeleteSelectionDecision> _confirmDeleteSelection(
    List<String> ids,
  ) async {
    if (!mounted) {
      return const _DeleteSelectionDecision(
        confirmed: false,
        reindexIds: false,
      );
    }

    final previewIds = ids.take(6).join(', ');
    final remainingCount = ids.length - 6;
    var reindexIds = false;

    final decision = await showDialog<_DeleteSelectionDecision>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(context.tr('Confirmer la suppression')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ids.length == 1
                        ? context.tr(
                            'Cette action supprimera l exposition selectionnee dans le tableau et dans la base locale.',
                          )
                        : context.tr(
                            'Cette action supprimera les expositions selectionnees dans le tableau et dans la base locale.',
                          ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    remainingCount > 0
                        ? '$previewIds, et $remainingCount autre(s).'
                        : previewIds,
                    style:
                        Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                  ),
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: reindexIds,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      context.tr('Mettre a jour les IDs apres suppression'),
                    ),
                    subtitle: Text(
                      context.tr(
                        'Exemple: si CP003 est supprime, CP004 devient CP003.',
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        reindexIds = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(
                    const _DeleteSelectionDecision(
                      confirmed: false,
                      reindexIds: false,
                    ),
                  ),
                  child: Text(context.tr('Annuler')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(
                    _DeleteSelectionDecision(
                      confirmed: true,
                      reindexIds: reindexIds,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(context.tr('Supprimer')),
                ),
              ],
            );
          },
        );
      },
    );

    return decision ??
        const _DeleteSelectionDecision(
          confirmed: false,
          reindexIds: false,
        );
  }

  String _buildDeleteResultMessage({
    required List<String> deletedIds,
    required List<String> missingIds,
    required bool reindexedIds,
  }) {
    if (deletedIds.isNotEmpty && missingIds.isEmpty) {
      if (reindexedIds) {
        return context.tr(
          '{{count}} exposition(s) supprimee(s). Les IDs ont ete renumerotes automatiquement.',
          args: {'count': deletedIds.length},
        );
      }
      return context.tr(
        '{{count}} exposition(s) supprimee(s) du tableau et de la base locale.',
        args: {'count': deletedIds.length},
      );
    }
    if (deletedIds.isNotEmpty && missingIds.isNotEmpty) {
      final prefix = reindexedIds
          ? context.tr(
              '{{deleted}} exposition(s) supprimee(s) et IDs renumerotes.',
              args: {'deleted': deletedIds.length},
            )
          : context.tr(
              '{{deleted}} exposition(s) supprimee(s).',
              args: {'deleted': deletedIds.length},
            );
      return context.tr(
        '{{prefix}} {{missing}} introuvable(s): {{ids}}.',
        args: {
          'prefix': prefix,
          'missing': missingIds.length,
          'ids': missingIds.join(', '),
        },
      );
    }
    if (missingIds.isNotEmpty) {
      return context.tr(
        'Aucune suppression effectuee. IDs introuvables: {{ids}}.',
        args: {'ids': missingIds.join(', ')},
      );
    }
    return context.tr('Aucune exposition supprimee.');
  }

  String _buildDeleteErrorMessage(
    Object error, {
    required bool reindexIds,
  }) {
    if (reindexIds && error is ApiException && error.statusCode >= 500) {
      return context.tr(
        'Suppression impossible pendant la mise a jour des IDs. Redemarrez le backend Python puis reessayez.',
      );
    }
    return context.tr(
      'Suppression impossible: {{error}}',
      args: {'error': error},
    );
  }

  Future<void> _exportView(List<ExposureRecord> rows) async {
    final format = await _showExportFormatDialog();
    if (!mounted || format == null) {
      return;
    }

    setState(() => _isExporting = true);
    try {
      switch (format) {
        case _ExposureExportFormat.excel:
          await _exportExcelWorkbook();
          break;
        case _ExposureExportFormat.pdf:
          await _exportVisibleTablePdf(rows);
          break;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text(
            context.tr(
              'Export impossible: {{error}}',
              args: {'error': error},
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<_ExposureExportFormat?> _showExportFormatDialog() {
    Widget buildOption({
      required BuildContext dialogContext,
      required _ExposureExportFormat format,
      required IconData icon,
      required String title,
      required String subtitle,
      required Color accent,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(_screenBorderRadius),
        onTap: () => Navigator.of(dialogContext).pop(format),
        child: Ink(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(dialogContext).cardColor,
            borderRadius: BorderRadius.circular(_screenBorderRadius),
            border: Border.all(color: Theme.of(dialogContext).dividerColor),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(_screenBorderRadius),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(dialogContext)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(dialogContext)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return showDialog<_ExposureExportFormat>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.tr('Choisir le format d export')),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildOption(
                  dialogContext: dialogContext,
                  format: _ExposureExportFormat.excel,
                  icon: Icons.table_chart_rounded,
                  title: context.tr('Exporter en Excel'),
                  subtitle: context.tr(
                    'Classeur complet base sur le modele RWA.',
                  ),
                  accent: const Color(0xFF2E7D32),
                ),
                const SizedBox(height: 3),
                buildOption(
                  dialogContext: dialogContext,
                  format: _ExposureExportFormat.pdf,
                  icon: Icons.picture_as_pdf_rounded,
                  title: context.tr('Exporter en PDF'),
                  subtitle: context.tr(
                    'Tableau visible uniquement, au format paysage.',
                  ),
                  accent: const Color(0xFFB45309),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.tr('Fermer')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportExcelWorkbook() async {
    final bytes = await widget.api.downloadExposureExcelExport();
    final location = await getSaveLocation(
      suggestedName: 'export_expositions_rwa_${_exportTimestamp()}.xlsx',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Excel', extensions: ['xlsx']),
      ],
    );
    if (!mounted || location == null) {
      return;
    }

    await saveBytesAtLocation(
      location,
      bytes,
      requiredExtension: '.xlsx',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.success,
        content: Text(context.tr('Export Excel enregistre avec succes.')),
      ),
    );
  }

  Future<void> _exportVisibleTablePdf(List<ExposureRecord> rows) async {
    final pdfBytes = await _buildVisibleTablePdf(rows);
    final location = await getSaveLocation(
      suggestedName: 'export_expositions_rwa_${_exportTimestamp()}.pdf',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );
    if (!mounted || location == null) {
      return;
    }

    await saveBytesAtLocation(
      location,
      pdfBytes,
      requiredExtension: '.pdf',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.success,
        content: Text(context.tr('Export PDF enregistre avec succes.')),
      ),
    );
  }

  Future<Uint8List> _buildVisibleTablePdf(List<ExposureRecord> rows) async {
    final document = pw.Document();
    final pdfColumnKeys = _fullTableColumnKeys
        .where((key) => key != 'actions')
        .toList(growable: false);
    final headers = pdfColumnKeys
        .map((key) => _columnLabelForKey(key, _ExposureTableMode.full))
        .toList(growable: false);
    final pdfColumnWeights = pdfColumnKeys
        .map((key) => _mainTableWidthWeights[_fullTableColumnKeys.indexOf(key)])
        .toList(growable: false);
    final columnWidths = <int, pw.TableColumnWidth>{
      for (var index = 0; index < pdfColumnWeights.length; index++)
        index: pw.FlexColumnWidth(pdfColumnWeights[index]),
    };

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a3.landscape,
        margin: const pw.EdgeInsets.all(4),
        build: (_) => [
          pw.Table(
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(
                color: PdfColor.fromInt(0xFFE2E8F0),
                width: 0.6,
              ),
              verticalInside: pw.BorderSide(
                color: PdfColor.fromInt(0xFFE2E8F0),
                width: 0.6,
              ),
              top: pw.BorderSide(
                color: PdfColor.fromInt(0xFF24467A),
                width: 0.8,
              ),
              bottom: pw.BorderSide(
                color: PdfColor.fromInt(0xFFE2E8F0),
                width: 0.8,
              ),
              left: pw.BorderSide(
                color: PdfColor.fromInt(0xFFE2E8F0),
                width: 0.8,
              ),
              right: pw.BorderSide(
                color: PdfColor.fromInt(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
            columnWidths: columnWidths,
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF24467A),
                ),
                children: headers
                    .map(
                      (header) => _pdfTableCell(
                        header,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8.1,
                      ),
                    )
                    .toList(),
              ),
              for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: _pdfRowColor(rowIndex),
                  ),
                  children: pdfColumnKeys
                      .map((key) => _pdfCellForColumn(rows[rowIndex], key))
                      .toList(growable: false),
                ),
            ],
          ),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _pdfTableCell(
    String text, {
    PdfColor? color,
    pw.FontWeight? fontWeight,
    double fontSize = 8.4,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(
        text,
        maxLines: 2,
        style: pw.TextStyle(
          color: color ?? const PdfColor.fromInt(0xFF1F2A44),
          fontSize: fontSize,
          fontWeight: fontWeight ?? pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _pdfCellForColumn(ExposureRecord row, String key) {
    switch (key) {
      case 'analysis_date':
        return _pdfTableCell(_formatExposureDate(row.analysisDate));
      case 'id':
        return _pdfTableCell(row.id);
      case 'grant_date':
        return _pdfTableCell(_formatExposureDate(row.grantDate));
      case 'maturity_date':
        return _pdfTableCell(_formatExposureDate(row.maturityDate));
      case 'exposure_maturity':
        return _pdfTableCell(_exposureMaturityLabel(row));
      case 'residual_maturity':
        return _pdfTableCell(_residualMaturityLabel(row));
      case 'counterparty':
        return _pdfTableCell(row.counterparty.name);
      case 'counterparty_rating':
        return _pdfTableCell(row.counterparty.rating);
      case 'country':
        return _pdfTableCell(_displayCountry(row.counterparty.country));
      case 'country_rating':
        return _pdfTableCell(row.counterparty.countryRating);
      case 'country_rw':
        return _pdfTableCell(_formatRiskWeight(_countryRiskWeightValue(row)));
      case 'category':
        return _pdfTableCell(_displayExposureCategory(row.categoryLabel));
      case 'rw':
        return _pdfTableCell(
          _formatRiskWeight(row.finalRw),
          color: _pdfRwColor(_rwPercentValue(row)),
          fontWeight: pw.FontWeight.bold,
        );
      case 'gross':
        return _pdfTableCell(
          _formatDisplayAmount(
              _convertRowAmount(row.grossAmount, row.currency)),
        );
      case 'loan_total':
        return _pdfTableCell(
          _formatDisplayAmount(
              _convertRowAmount(_loanTotalAmountValue(row), row.currency)),
        );
      case 'encours_restant':
        return _pdfTableCell(
          _formatDisplayAmount(
              _convertRowAmount(row.grossAmount, row.currency)),
        );
      case 'on_balance_amount':
        return _pdfTableCell(
          _formatDisplayAmount(
              _convertRowAmount(_onBalanceAmountValue(row), row.currency)),
        );
      case 'off_balance_amount':
        return _pdfTableCell(
          _formatDisplayAmount(
              _convertRowAmount(_offBalanceAmountValue(row), row.currency)),
        );
      case 'source_currency':
        return _pdfTableCell(row.currency);
      case 'crm_exists':
        return _pdfTableCell(_crmExistsLabel(row));
      case 'crm_type':
        return _pdfTableCell(_crmTypeTableValue(row));
      case 'ead_bilan':
        return _pdfTableCell(
          _formatDisplayAmount(
              _convertRowAmount(_eadBilanAmountValue(row), row.currency)),
        );
      case 'ead_hb':
        return _pdfTableCell(
          _formatDisplayAmount(
              _convertRowAmount(_eadHbAmountValue(row), row.currency)),
        );
      case 'ead_hb_ccf':
        return _pdfTableCell(
          _formatDisplayAmount(
              _convertRowAmount(_eadHbCcfAmountValue(row), row.currency)),
        );
      case 'ead_total':
        return _pdfTableCell(
          _formatDisplayAmount(
              _convertRowAmount(_eadTotalAmountValue(row), row.currency)),
        );
      case 'rwa_eb':
        return _pdfTableCell(
          _formatDisplayAmount(
              _convertRowAmount(_rwaEbAmountValue(row), row.currency)),
        );
      case 'rwa_hb':
        return _pdfTableCell(
          _formatDisplayAmount(
              _convertRowAmount(_rwaHbAmountValue(row), row.currency)),
        );
      case 'rwa':
        return _pdfTableCell(
          _formatDisplayAmount(_convertRowAmount(row.rwa, row.currency)),
        );
      case 'capital':
        return _pdfTableCell(
          _formatDisplayAmount(_convertRowAmount(row.capital, row.currency)),
        );
      case 'statut':
        return _pdfTableCell(
          row.isImpayee && row.joursImpayes > 0
              ? '${row.statutPrudentielLabel} (${row.joursImpayes} j)'
              : row.statutPrudentielLabel,
          color: _pdfStatutColor(row.statutPrudentiel),
          fontWeight: pw.FontWeight.bold,
        );
      default:
        return _pdfTableCell('');
    }
  }

  Widget _buildEvolutionRemboursementsView(BuildContext context) {
    final now = DateTime.now();
    
    final List<DateTime> last12Months = List.generate(12, (index) {
      return DateTime(now.year, now.month - 11 + index);
    });

    // Data for Chart 1: Reimbursements received per month
    final Map<DateTime, double> reimbursementsPerMonth = {};
    for (final month in last12Months) {
      reimbursementsPerMonth[month] = 0.0;
    }
    
    for (final row in _visibleRows) {
      if (row.actualReimbursements.isNotEmpty) {
        // 1. Si les données réelles de la BD sont présentes, on les utilise directement
        for (final entry in row.actualReimbursements.entries) {
          final monthKey = DateTime(entry.key.year, entry.key.month, 1);
          if (reimbursementsPerMonth.containsKey(monthKey)) {
            reimbursementsPerMonth[monthKey] = reimbursementsPerMonth[monthKey]! + entry.value;
          }
        }
      }
    }
    final sortedReimbursementKeys = last12Months;
    
    // Data for Chart 2: Number of obligations per month over last 12 months
    final List<int> obligationsPerMonth = [];
    for (final month in last12Months) {
      final firstDayOfThisMonth = DateTime(month.year, month.month, 1);
      final firstDayOfNextMonth = DateTime(month.year, month.month + 1, 1);
      int count = 0;
      for (final row in _visibleRows) {
        final gDate = row.grantDate ?? DateTime(2000, 1, 1);
        final mDate = row.maturityDate ?? DateTime(2100, 1, 1);
        
        // Une exposition est "en vie" durant ce mois si :
        // 1. Elle a été octroyée AVANT le 1er du mois suivant (donc octroyée ce mois-ci ou avant)
        // 2. Elle n'est PAS arrivée à échéance AVANT le 1er de ce mois (donc elle expire ce mois-ci ou après)
        if (gDate.isBefore(firstDayOfNextMonth) && !mDate.isBefore(firstDayOfThisMonth)) {
          count++;
        }
      }
      obligationsPerMonth.add(count);
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF2F6FF) : const Color(0xFF13203A);
    final gridColor = isDark ? const Color(0xFF304764) : const Color(0xFFE2E8F0);

    final chartDropdown = Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101C32) : const Color(0xFFF6F9FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? const Color(0xFF304764) : const Color(0xFFDDE7F6)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedEvolutionChartIndex,
          icon: Icon(Icons.arrow_drop_down, color: textColor, size: 20),
          dropdownColor: isDark ? const Color(0xFF101C32) : Colors.white,
          style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
          isDense: true,
          items: const [
            DropdownMenuItem(
              value: 0,
              child: Text('Évolution des remboursements (XOF)'),
            ),
            DropdownMenuItem(
              value: 1,
              child: Text("Nombre d'expositions (12 derniers mois)"),
            ),
          ],
          onChanged: (value) {
            if (value != null && value != _selectedEvolutionChartIndex) {
              setState(() {
                _selectedEvolutionChartIndex = value;
              });
            }
          },
        ),
      ),
    );

    double maxReimbursement = 0;
    if (reimbursementsPerMonth.isNotEmpty) {
      maxReimbursement = reimbursementsPerMonth.values.reduce((a, b) => a > b ? a : b);
    }
    double maxObligations = 0;
    if (obligationsPerMonth.isNotEmpty) {
      maxObligations = obligationsPerMonth.reduce((a, b) => a > b ? a : b).toDouble();
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedEvolutionChartIndex == 0 
                      ? 'Évolution des remboursements (XOF)' 
                      : "Nombre d'expositions",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  if (_selectedEvolutionChartIndex != 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Sur les 12 derniers mois',
                        style: TextStyle(fontSize: 12, color: AppTheme.muted, fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
              chartDropdown,
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: _selectedEvolutionChartIndex == 0 
                  ? (sortedReimbursementKeys.isEmpty
                      ? Center(child: Text('Aucune donnée de remboursement', style: TextStyle(color: textColor)))
                      : Stack(
                          clipBehavior: Clip.none,
                          children: [
                            BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: maxReimbursement * 1.2,
                                barTouchData: const BarTouchData(enabled: false),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    axisNameWidget: Text('Mois', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                                    axisNameSize: 22,
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 1,
                                      reservedSize: 70,
                                      getTitlesWidget: (value, meta) {
                                        if (value % 1 != 0) return const SizedBox.shrink();
                                        if (value.toInt() >= 0 && value.toInt() < sortedReimbursementKeys.length) {
                                          final date = sortedReimbursementKeys[value.toInt()];
                                          String monthStr = DateFormat.MMMM('fr').format(date);
                                          monthStr = monthStr[0].toUpperCase() + monthStr.substring(1);
                                          return Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(width: 1, height: 4, color: textColor.withValues(alpha: 0.5)),
                                              const SizedBox(height: 20),
                                              Padding(
                                                padding: const EdgeInsets.only(right: 16.0),
                                                child: Transform.rotate(
                                                  angle: -0.5,
                                                  child: Text('$monthStr ${date.year}', style: TextStyle(fontSize: 10, color: textColor)),
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    axisNameWidget: Text('Montant remboursé', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                                    axisNameSize: 22,
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 55,
                                      getTitlesWidget: (value, meta) {
                                        String label = value.toInt().toString();
                                        if (value >= 1000000000) {
                                          label = '${(value / 1000000000).toStringAsFixed(1).replaceAll('.0', '')} Md';
                                        } else if (value >= 1000000) {
                                          label = '${(value / 1000000).toStringAsFixed(1).replaceAll('.0', '')} M';
                                        } else if (value >= 1000) {
                                          label = '${(value / 1000).toStringAsFixed(1).replaceAll('.0', '')} k';
                                        }
                                        return Text(label, style: TextStyle(fontSize: 10, color: textColor));
                                      },
                                    ),
                                  ),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: FlGridData(
                                  show: true, 
                                  drawVerticalLine: false,
                                  getDrawingHorizontalLine: (value) => FlLine(color: gridColor, strokeWidth: 0.5, dashArray: [5, 5]),
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border(
                                    bottom: BorderSide(color: textColor.withValues(alpha: 0.5), width: 1),
                                    left: BorderSide(color: textColor.withValues(alpha: 0.5), width: 1),
                                    right: BorderSide.none,
                                    top: BorderSide.none,
                                  ),
                                ),
                                barGroups: sortedReimbursementKeys.asMap().entries.map((e) {
                                  final date = e.value;
                                  final isCurrentMonth = date.year == DateTime.now().year && date.month == DateTime.now().month;
                                  return BarChartGroupData(
                                    x: e.key,
                                    barRods: [
                                      BarChartRodData(
                                        toY: reimbursementsPerMonth[e.value]!.toDouble(),
                                        color: isCurrentMonth ? Colors.amber : const Color(0xFF0D47A1),
                                        width: 40,
                                        borderRadius: BorderRadius.zero,
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                            LineChart(
                          LineChartData(
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                maxContentWidth: 200,
                                tooltipBorder: BorderSide(color: textColor.withValues(alpha: 0.2), width: 1),
                                tooltipBorderRadius: BorderRadius.circular(8),
                                fitInsideHorizontally: true,
                                fitInsideVertically: true,
                                getTooltipColor: (touchedSpot) => Theme.of(context).cardColor,
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((LineBarSpot touchedSpot) {
                                    final date = sortedReimbursementKeys[touchedSpot.x.toInt()];
                                    String monthStr = DateFormat.MMMM('fr').format(date);
                                    monthStr = monthStr[0].toUpperCase() + monthStr.substring(1);
                                    final valStr = touchedSpot.y.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '\u00A0');
                                    return LineTooltipItem(
                                      '$monthStr ${date.year}\n',
                                      TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
                                      children: [
                                        TextSpan(
                                          text: '$valStr\u00A0XOF',
                                          style: const TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                      ],
                                    );
                                  }).toList();
                                },
                              ),
                              getTouchLineEnd: (barData, spotIndex) => double.infinity,
                              getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                                return spotIndexes.map((index) {
                                  return TouchedSpotIndicatorData(
                                    FlLine(color: const Color(0xFF1E88E5).withValues(alpha: 0.5), strokeWidth: 1, dashArray: [4, 4]),
                                    FlDotData(
                                      show: true,
                                      getDotPainter: (spot, percent, barData, index) {
                                        return FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: const Color(0xFF1E88E5));
                                      },
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                            minX: -0.5,
                            maxX: sortedReimbursementKeys.length - 0.5,
                            minY: 0,
                            maxY: maxReimbursement * 1.2,
                            lineBarsData: [
                              LineChartBarData(
                                spots: sortedReimbursementKeys.asMap().entries.map((e) {
                                  return FlSpot(e.key.toDouble(), reimbursementsPerMonth[e.value]!.toDouble());
                                }).toList(),
                                isCurved: false,
                                color: const Color(0xFF1E88E5),
                                barWidth: 1.5,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, barData, index) {
                                    return FlDotCirclePainter(
                                      radius: 2.5,
                                      color: const Color(0xFF1E88E5),
                                      strokeWidth: 2,
                                      strokeColor: Colors.white,
                                    );
                                  },
                                ),
                              ),
                            ],
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                axisNameWidget: const SizedBox.shrink(),
                                axisNameSize: 22,
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  reservedSize: 70,
                                  getTitlesWidget: (value, meta) => const SizedBox.shrink(),
                                ),
                              ),
                              leftTitles: AxisTitles(
                                axisNameWidget: const SizedBox.shrink(),
                                axisNameSize: 22,
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 55,
                                  getTitlesWidget: (value, meta) => const SizedBox.shrink(),
                                ),
                              ),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                          ),
                        ),

                          ],
                        ))
                  : Stack(
                      clipBehavior: Clip.none,
                      children: [
                        BarChart(
                          BarChartData(
                            barTouchData: BarTouchData(
                              enabled: false,
                              touchTooltipData: BarTouchTooltipData(
                                tooltipBorder: const BorderSide(color: Colors.transparent, width: 0),
                                tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                tooltipMargin: 8,
                                getTooltipColor: (group) => Colors.transparent,
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final valStr = rod.toY.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
                                  return BarTooltipItem(
                                    valStr,
                                    const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold, fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            maxY: maxObligations * 1.2,
                            barGroups: last12Months.asMap().entries.map((e) {
                              final date = e.value;
                              final isCurrentMonth = date.year == DateTime.now().year && date.month == DateTime.now().month;
                              return BarChartGroupData(
                                x: e.key,
                                showingTooltipIndicators: const [],
                                barRods: [
                                  BarChartRodData(
                                    toY: obligationsPerMonth[e.key].toDouble(),
                                    color: isCurrentMonth ? Colors.amber : const Color(0xFF0D47A1),
                                    width: 16,
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ],
                              );
                            }).toList(),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                axisNameWidget: Text('Mois', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                                axisNameSize: 22,
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  reservedSize: 70,
                                  getTitlesWidget: (value, meta) {
                                    if (value % 1 != 0) return const SizedBox.shrink();
                                    if (value.toInt() >= 0 && value.toInt() < last12Months.length) {
                                      final date = last12Months[value.toInt()];
                                      String monthStr = DateFormat.MMMM('fr').format(date);
                                      monthStr = monthStr[0].toUpperCase() + monthStr.substring(1);
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(width: 1, height: 4, color: textColor.withValues(alpha: 0.5)),
                                          const SizedBox(height: 20),
                                          Padding(
                                            padding: const EdgeInsets.only(right: 16.0),
                                            child: Transform.rotate(
                                              angle: -0.5,
                                              child: Text('$monthStr ${date.year}', style: TextStyle(fontSize: 10, color: textColor)),
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                axisNameWidget: Text('Nombre d\'expositions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                                axisNameSize: 22,
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    String label = value.toInt().toString();
                                    if (value >= 1000000) {
                                      label = '${(value / 1000000).toStringAsFixed(1)} M';
                                    } else if (value >= 1000) {
                                      label = '${(value / 1000).toStringAsFixed(0)} k';
                                    }
                                    return Text(label, style: TextStyle(fontSize: 10, color: textColor));
                                  },
                                ),
                              ),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              show: true, 
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) => FlLine(color: gridColor, strokeWidth: 0.5, dashArray: [5, 5]),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border(
                                bottom: BorderSide(color: textColor.withValues(alpha: 0.5), width: 1),
                                left: BorderSide(color: textColor.withValues(alpha: 0.5), width: 1),
                                right: BorderSide.none,
                                top: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        BarChart(
                          BarChartData(
                            barTouchData: BarTouchData(
                              enabled: true,
                              handleBuiltInTouches: true,
                              touchTooltipData: BarTouchTooltipData(
                                tooltipBorder: BorderSide(color: textColor.withValues(alpha: 0.2), width: 1),
                                tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                tooltipMargin: 8,
                                getTooltipColor: (group) => Theme.of(context).cardColor,
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final date = last12Months[group.x];
                                  const months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
                                  final monthStr = months[date.month - 1];
                                  final valStr = rod.toY.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
                                  return BarTooltipItem(
                                    '$monthStr ${date.year}\n',
                                    TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
                                    children: [
                                      TextSpan(
                                        text: '$valStr expositions',
                                        style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            maxY: maxObligations * 1.2,
                            barGroups: last12Months.asMap().entries.map((e) {
                              return BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: obligationsPerMonth[e.key].toDouble(),
                                    color: Colors.transparent,
                                    width: 16,
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ],
                              );
                            }).toList(),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                axisNameWidget: const SizedBox.shrink(),
                                axisNameSize: 22,
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  reservedSize: 70,
                                  getTitlesWidget: (value, meta) => const SizedBox.shrink(),
                                ),
                              ),
                              leftTitles: AxisTitles(
                                axisNameWidget: const SizedBox.shrink(),
                                axisNameSize: 22,
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) => const SizedBox.shrink(),
                                ),
                              ),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 16, height: 16, color: Colors.amber),
              const SizedBox(width: 8),
              Text('Mois actuel', style: TextStyle(color: textColor, fontSize: 12)),
              const SizedBox(width: 24),
              Container(width: 16, height: 16, color: const Color(0xFF0D47A1)),
              const SizedBox(width: 8),
              Text('Mois précédents', style: TextStyle(color: textColor, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  PdfColor _pdfStatutColor(String statut) {
    switch (statut) {
      case 'douteuse':
        return const PdfColor.fromInt(0xFFB3261E);
      case 'impayee':
        return const PdfColor.fromInt(0xFF8A6100);
      default:
        return const PdfColor.fromInt(0xFF1B7A3D);
    }
  }

  PdfColor _pdfRowColor(int rowIndex) {
    return rowIndex.isEven
        ? const PdfColor.fromInt(0xFFFFFFFF)
        : const PdfColor.fromInt(0xFFF7FAFF);
  }

  PdfColor _pdfRwColor(double rwPercent) {
    if (rwPercent <= 50) {
      return const PdfColor.fromInt(0xFF18A957);
    }
    if (rwPercent <= 100) {
      return const PdfColor.fromInt(0xFFD68A00);
    }
    return const PdfColor.fromInt(0xFFE04F5F);
  }

  String _exportTimestamp() {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final now = DateTime.now();
    return '${now.year}${twoDigits(now.month)}${twoDigits(now.day)}_'
        '${twoDigits(now.hour)}${twoDigits(now.minute)}${twoDigits(now.second)}';
  }

}
