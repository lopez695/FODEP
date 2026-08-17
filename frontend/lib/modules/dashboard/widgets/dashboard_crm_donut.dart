import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/localization/app_localization.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'dashboard_design.dart';

class DashboardCrmDonut extends StatefulWidget {
  const DashboardCrmDonut({super.key, required this.entries, required this.portfolioOverview});

  final List<DistributionEntry> entries;
  final List<PortfolioRow> portfolioOverview;

  @override
  State<DashboardCrmDonut> createState() => _DashboardCrmDonutState();
}

class _DashboardCrmDonutState extends State<DashboardCrmDonut> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    // Map the CRM entries to sector data
    // Usually there are up to 3 entries: 'CRM financée', 'CRM non financée', 'Aucune'
    final colors = [
      c.navy,
      c.conforme,
      const Color(0xFF3B82F6), // Bleu clair
    ];

    List<_SectorData> sectors = [];

    // Safety check, handle up to 4 just in case
    final safeColors = [...colors, Colors.purple, Colors.orange];

    for (int i = 0; i < widget.entries.length; i++) {
      final entry = widget.entries[i];
      final percent = entry.percentage * 100;
      sectors.add(
        _SectorData(
          entry.label,
          entry.amount,
          percent,
          safeColors[i % safeColors.length],
          entry.count ?? 0,
        ),
      );
    }

    // Find the dominant sector for the central text
    _SectorData? dominantSector;
    if (sectors.isNotEmpty) {
      dominantSector = sectors.reduce((a, b) => a.percentage > b.percentage ? a : b);
    }

    return DashPanel(
      title: 'Répartition totale par type de CRM'.tr(context),
      trailing: TextButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => _CrmDetailsDialog(
              portfolioOverview: widget.portfolioOverview,
            ),
          );
        },
        style: TextButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'Voir plus',
          maxLines: 1,
          softWrap: false,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      height: 360,
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: SizedBox(
              width: double.infinity,
              child: Stack(
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
                      sectionsSpace: 4,
                      centerSpaceRadius: 45,
                      sections: sectors.asMap().entries.map((entry) {
                        final i = entry.key;
                        final s = entry.value;
                        final isTouched = i == touchedIndex;
                        final radius = isTouched ? 22.0 : 16.0;
                        
                        return PieChartSectionData(
                          color: s.color,
                          value: s.percentage,
                          title: '',
                          radius: radius,
                          badgeWidget: isTouched
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: c.surface,
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: c.ink.withValues(alpha: 0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  child: Text(
                                    '${AppFormatters.decimalNumber(s.percentage, maxDecimals: 1)}%',
                                    style: DashText.caption(c, color: s.color).copyWith(fontWeight: FontWeight.w700),
                                  ),
                                )
                              : null,
                          badgePositionPercentageOffset: 1.2,
                        );
                      }).toList(),
                    ),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutQuint,
                  ),
                  if (dominantSector != null && touchedIndex == -1)
                    Center(
                      child: SizedBox(
                        width: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${AppFormatters.decimalNumber(dominantSector.percentage, maxDecimals: 1)}%',
                                style: DashText.hero(c, size: 18),
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                dominantSector.label.tr(context),
                                style: DashText.caption(c, color: c.muted).copyWith(fontSize: 10),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: sectors.asMap().entries.map((entry) {
                  final isLast = entry.key == sectors.length - 1;
                  return Column(
                    children: [
                      _LegendItem(sector: entry.value),
                      if (!isLast) ...[
                        const SizedBox(height: 4),
                        Divider(color: c.border, thickness: Dash.hairline, height: 1),
                        const SizedBox(height: 4),
                      ]
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectorData {
  const _SectorData(this.label, this.amount, this.percentage, this.color, this.count);
  final String label;
  final double amount;
  final double percentage;
  final Color color;
  final int count;
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.sector});

  final _SectorData sector;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final countText = context.tr('{{count}} expositions', args: {'count': sector.count});

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: sector.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sector.label.tr(context),
                  style: DashText.caption(c, color: c.muted).copyWith(fontWeight: FontWeight.w700, fontSize: 9),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  countText,
                  style: DashText.caption(c, color: c.ink).copyWith(fontSize: 10, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${AppFormatters.decimalNumber(sector.percentage, maxDecimals: 1)}%',
              style: DashText.hero(c, size: 14).copyWith(
                color: Colors.indigo.shade900,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Range un type de CRM dans l'un des trois onglets du détail.
///
/// Un libellé vide ou non reconnu tombe dans « aucune garantie » : le classer
/// parmi les CRM non financées affirmerait l'existence d'une sûreté que rien
/// n'établit, et gonflerait la couverture apparente du portefeuille.
String crmBucketLabel(String crmType) {
  final normalized = crmType.toLowerCase();
  if (normalized.contains('aucune') || normalized.contains('sans crm')) {
    return 'AUCUNE';
  }
  if (normalized.contains('non') && normalized.contains('financ')) {
    return 'NON FINANCÉE';
  }
  if (normalized.contains('cash') || normalized.contains('financ')) {
    return 'FINANCÉE';
  }
  return 'AUCUNE';
}

/// Colonne du détail CRM : largeur fixe, valeur affichée, tri et total.
///
/// Les colonnes sont déclarées par onglet : une sûreté financée et une
/// garantie personnelle ne se décrivent pas avec les mêmes grandeurs, et
/// afficher des colonnes vides laisserait croire à une information absente.
class _CrmColumn {
  const _CrmColumn({
    required this.label,
    required this.width,
    required this.cell,
    this.numeric = false,
    this.comparator,
    this.total,
    this.color,
    this.tooltip,
  });

  final String label;
  final double width;
  final String Function(PortfolioRow row) cell;
  final bool numeric;
  final int Function(PortfolioRow a, PortfolioRow b)? comparator;
  final String Function(List<PortfolioRow> rows)? total;
  final Color? Function(PortfolioRow row, DashColors c)? color;
  final String Function(PortfolioRow row)? tooltip;

  _CrmColumn scaled(double factor) => _CrmColumn(
        label: label,
        width: width * factor,
        cell: cell,
        numeric: numeric,
        comparator: comparator,
        total: total,
        color: color,
        tooltip: tooltip,
      );
}

int Function(PortfolioRow, PortfolioRow) _byText(
  String Function(PortfolioRow row) value,
) {
  return (a, b) => value(a).toLowerCase().compareTo(value(b).toLowerCase());
}

int Function(PortfolioRow, PortfolioRow) _byNumber(
  double Function(PortfolioRow row) value,
) {
  return (a, b) => value(a).compareTo(value(b));
}

/// Échelons servis par le backend, de la meilleure qualité à la plus faible.
/// « Non noté » ferme la marche : l'absence de notation n'est pas une note.
const List<String> _echelonsDeNotation = [
  'AAA à AA-',
  'A+ à A-',
  'BBB+ à BBB-',
  'BB+ à B-',
  'Inférieur à B-',
  'Non noté',
];

/// Trie sur la qualité de crédit, pas sur l'alphabet : classer « B+ » avant
/// « BBB- » parce que B précède BBB inverserait la lecture du risque.
int Function(PortfolioRow, PortfolioRow) _byRating(
  String Function(PortfolioRow row) band,
  String Function(PortfolioRow row) rating,
) {
  int rank(PortfolioRow row) {
    final index = _echelonsDeNotation.indexOf(band(row));
    return index < 0 ? _echelonsDeNotation.length : index;
  }

  return (a, b) {
    final byBand = rank(a).compareTo(rank(b));
    if (byBand != 0) return byBand;
    return rating(a).toLowerCase().compareTo(rating(b).toLowerCase());
  };
}

String _echelonTooltip(String band) {
  if (band.isEmpty) return '';
  return 'Échelon prudentiel : $band.\nC\'est lui qui désigne la ligne de '
      'grille, donc la pondération appliquée.';
}

double _sum(List<PortfolioRow> rows, double Function(PortfolioRow row) value) {
  return rows.fold<double>(0, (total, row) => total + value(row));
}

/// Moyenne pondérée par l'EAD : la moyenne arithmétique d'un taux de
/// couverture donnerait le même poids à une ligne de 1 M et à une de 10 Md.
double _weightedByEad(
  List<PortfolioRow> rows,
  double Function(PortfolioRow row) value,
) {
  final totalEad = _sum(rows, (row) => row.ead);
  if (totalEad <= 0) return 0;
  return _sum(rows, (row) => value(row) * row.ead) / totalEad;
}

String _amount(double value) => AppFormatters.compactAmount(value);

String _ratio(double value, {int decimals = 1}) =>
    AppFormatters.percent(value, decimalDigits: decimals);

String _exactAmount(double value) => '${AppFormatters.integer(value)} XOF';

/// Variation de RWA imputable à la CRM, signée dans le sens du RWA : négative
/// quand la garantie allège l'exigence, nulle quand elle n'apporte rien. Le
/// moteur ne retient jamais une atténuation qui alourdirait l'exigence, mais
/// la colonne reste signée : une valeur positive servie par un backend plus
/// ancien doit rester lisible plutôt que d'être présentée comme un gain.
double _rwaDelta(PortfolioRow row) => row.rwa - row.rwaBeforeCrm;

String _formatDelta(double delta) {
  if (delta.abs() < 1) return '-';
  return delta > 0 ? '+${_amount(delta)}' : _amount(delta);
}

Color? _deltaColor(double delta, DashColors c) {
  if (delta.abs() < 1) return c.muted;
  return delta < 0 ? c.conforme : c.sousMinimum;
}

/// Garantie déclarée dont l'exigence ne bouge pas : le garant est pondéré au
/// moins aussi lourdement que le débiteur, la substitution n'est donc pas
/// retenue. La ligne compte dans la couverture affichée sans rien alléger —
/// c'est ce décalage qu'il faut montrer.
bool _isCrmWithoutEffect(PortfolioRow row) =>
    row.crmCoveragePercent > 0 && _rwaDelta(row).abs() < 1;

class _CrmDetailsDialog extends StatefulWidget {
  const _CrmDetailsDialog({required this.portfolioOverview});

  final List<PortfolioRow> portfolioOverview;

  @override
  State<_CrmDetailsDialog> createState() => _CrmDetailsDialogState();
}

class _CrmDetailsDialogState extends State<_CrmDetailsDialog> {
  static const double _rowHeight = 40;
  static const double _headerHeight = 42;

  final ScrollController _horizontal = ScrollController();
  final LinkedScrollControllerGroup _verticalGroup = LinkedScrollControllerGroup();
  late final ScrollController _vertical1 = _verticalGroup.addAndGet();
  late final ScrollController _vertical2 = _verticalGroup.addAndGet();
  late final ScrollController _vertical3 = _verticalGroup.addAndGet();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  String _selectedType = 'FINANCÉE';
  String? _selectedRowId;
  int _sortColumn = 0;
  bool _sortAscending = true;
  String _query = '';

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical1.dispose();
    _vertical2.dispose();
    _vertical3.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _selectType(String type) {
    setState(() {
      _selectedType = type;
      // Les colonnes diffèrent d'un onglet à l'autre : conserver l'index de
      // tri trierait sur une grandeur sans rapport.
      _sortColumn = 0;
      _sortAscending = true;
      _selectedRowId = null;
    });
  }

  List<PortfolioRow> _bucketRows() {
    return widget.portfolioOverview
        .where((row) => crmBucketLabel(row.crmType) == _selectedType)
        .toList();
  }

  List<PortfolioRow> _visibleRows(List<_CrmColumn> columns) {
    final query = _query.trim().toLowerCase();
    final rows = _bucketRows()
        .where((row) => query.isEmpty || _matchesQuery(row, query))
        .toList();
    final comparator =
        columns[_sortColumn.clamp(0, columns.length - 1)].comparator;
    if (comparator != null) {
      rows.sort((a, b) => _sortAscending ? comparator(a, b) : comparator(b, a));
    }
    return rows;
  }

  bool _matchesQuery(PortfolioRow row, String query) {
    return row.id.toLowerCase().contains(query) ||
        row.counterparty.toLowerCase().contains(query) ||
        row.category.toLowerCase().contains(query) ||
        row.guarantorName.toLowerCase().contains(query) ||
        row.collateralType.toLowerCase().contains(query);
  }

  List<_CrmColumn> _columnsFor(String type) {
    final columns = <_CrmColumn>[
      _CrmColumn(
        label: 'ID',
        width: 140,
        cell: (row) => row.id,
        comparator: _byText((row) => row.id),
      ),
      _CrmColumn(
        label: 'Contrepartie',
        width: 360,
        cell: (row) => row.counterparty,
        comparator: _byText((row) => row.counterparty),
        tooltip: (row) => row.counterparty,
      ),
      _CrmColumn(
        label: 'Catégorie',
        width: 280,
        cell: (row) => row.category,
        comparator: _byText((row) => row.category),
        tooltip: (row) => row.category,
      ),
      // La note du débiteur cède la place au bloc « garant » sur l'onglet des
      // garanties personnelles : la pondération avant/après y dit déjà ce que
      // la notation du débiteur apporte.
      if (type != 'NON FINANCÉE')
        _CrmColumn(
          label: 'Note',
          width: 90,
          cell: (row) => row.rating,
          comparator: _byRating((row) => row.ratingBand, (row) => row.rating),
          tooltip: (row) => _echelonTooltip(row.ratingBand),
        ),
      _CrmColumn(
        label: 'Encours brut',
        width: 140,
        numeric: true,
        cell: (row) => _amount(row.grossAmount),
        comparator: _byNumber((row) => row.grossAmount),
        total: (rows) => _amount(_sum(rows, (row) => row.grossAmount)),
        tooltip: (row) => _exactAmount(row.grossAmount),
      ),
      _CrmColumn(
        label: 'EAD',
        width: 140,
        numeric: true,
        cell: (row) => _amount(row.ead),
        comparator: _byNumber((row) => row.ead),
        total: (rows) => _amount(_sum(rows, (row) => row.ead)),
        tooltip: (row) => _exactAmount(row.ead),
      ),
    ];

    if (type == 'FINANCÉE') {
      columns.addAll([
        _CrmColumn(
          label: 'Sûreté',
          width: 300,
          cell: (row) => row.collateralType.isNotEmpty
              ? row.collateralType
              : (row.crmLabel.isNotEmpty ? row.crmLabel : '-'),
          comparator: _byText((row) => row.collateralType),
          color: (row, c) => row.crmEligible ? null : c.sousMinimum,
          tooltip: (row) => row.crmEligible
              ? '${row.crmLabel} - ${row.collateralType}'
              : 'Sûreté non éligible : ${row.crmIneligibilityReason.isEmpty ? "motif non renseigné" : row.crmIneligibilityReason}',
        ),
        _CrmColumn(
          label: 'Valeur sûreté',
          width: 140,
          numeric: true,
          cell: (row) => _amount(row.collateralValue),
          comparator: _byNumber((row) => row.collateralValue),
          total: (rows) => _amount(_sum(rows, (row) => row.collateralValue)),
          tooltip: (row) => _exactAmount(row.collateralValue),
        ),
        _CrmColumn(
          label: 'Décote',
          width: 80,
          numeric: true,
          cell: (row) => _ratio(row.collateralHaircut),
          comparator: _byNumber((row) => row.collateralHaircut),
          total: (rows) =>
              _ratio(_weightedByEad(rows, (row) => row.collateralHaircut)),
        ),
        _CrmColumn(
          label: 'Sûreté retenue',
          width: 140,
          numeric: true,
          cell: (row) => _amount(row.collateralValueAfterHaircut),
          comparator: _byNumber((row) => row.collateralValueAfterHaircut),
          total: (rows) =>
              _amount(_sum(rows, (row) => row.collateralValueAfterHaircut)),
          tooltip: (row) => _exactAmount(row.collateralValueAfterHaircut),
        ),
      ]);
    } else if (type == 'NON FINANCÉE') {
      columns.addAll([
        _CrmColumn(
          label: 'Garant',
          width: 400,
          cell: (row) => row.guarantorName.isEmpty ? '-' : row.guarantorName,
          comparator: _byText((row) => row.guarantorName),
          tooltip: (row) => row.guarantorName,
        ),
        _CrmColumn(
          label: 'Catégorie garant',
          width: 360,
          cell: (row) =>
              row.guarantorCategory.isEmpty ? '-' : row.guarantorCategory,
          comparator: _byText((row) => row.guarantorCategory),
          tooltip: (row) => row.guarantorCategory,
        ),
        _CrmColumn(
          label: 'Note',
          width: 90,
          cell: (row) =>
              row.guarantorRating.isEmpty ? '-' : row.guarantorRating,
          comparator:
              _byRating((row) => row.guarantorRatingBand, (row) => row.guarantorRating),
          tooltip: (row) => _echelonTooltip(row.guarantorRatingBand),
        ),
        _CrmColumn(
          label: 'Couverture',
          width: 100,
          numeric: true,
          cell: (row) => _ratio(row.crmCoveragePercent),
          comparator: _byNumber((row) => row.crmCoveragePercent),
          total: (rows) =>
              _ratio(_weightedByEad(rows, (row) => row.crmCoveragePercent)),
        ),
        // Les deux poids qui se disputent la part couverte sont adjacents :
        // c'est leur comparaison, pas leur valeur isolée, qui dit si la
        // garantie sert à quelque chose.
        _CrmColumn(
          label: 'Pond. contrepartie',
          width: 140,
          numeric: true,
          cell: (row) => _ratio(row.originalRiskWeight, decimals: 0),
          comparator: _byNumber((row) => row.originalRiskWeight),
          total: (rows) {
            final ead = _sum(rows, (row) => row.ead);
            if (ead <= 0) return '-';
            return _ratio(
              _sum(rows, (row) => row.ead * row.originalRiskWeight) / ead,
              decimals: 0,
            );
          },
          tooltip: (row) => 'Pondération du débiteur, avant toute garantie.',
        ),
        _CrmColumn(
          label: 'Pond. garant',
          width: 100,
          numeric: true,
          cell: (row) => _ratio(row.guarantorRiskWeight, decimals: 0),
          comparator: _byNumber((row) => row.guarantorRiskWeight),
          color: (row, c) => row.guarantorRiskWeight >= row.originalRiskWeight
              ? c.sousCible
              : null,
          tooltip: (row) => row.guarantorRiskWeight >= row.originalRiskWeight
              ? 'Le garant est pondéré au moins aussi lourdement que le '
                  'débiteur : la substitution n\'est pas retenue, la ligne '
                  'reste pondérée au poids du débiteur.'
              : 'Pondération substituée sur la part couverte.',
        ),
      ]);
    }

    if (type == 'NON FINANCÉE') {
      columns.add(
        _CrmColumn(
          label: 'Pond. retenue',
          width: 120,
          numeric: true,
          cell: (row) => _ratio(row.finalRiskWeight),
          comparator: _byNumber((row) => row.finalRiskWeight),
          total: (rows) {
            final ead = _sum(rows, (row) => row.ead);
            if (ead <= 0) return '-';
            return _ratio(_sum(rows, (row) => row.rwa) / ead);
          },
          color: (row, c) =>
              row.finalRiskWeight < row.originalRiskWeight ? c.conforme : null,
          tooltip: (row) => row.finalRiskWeight < row.originalRiskWeight
              ? 'Moyenne des deux poids : part couverte au poids du garant, '
                  'solde au poids du débiteur.'
              : 'Substitution non retenue : la ligne garde la pondération du '
                  'débiteur.',
        ),
      );
    } else {
      // Hors garantie personnelle, la pondération retenue est celle de la
      // contrepartie : une sûreté financée réduit l'assiette, pas le poids.
      columns.add(
        _CrmColumn(
          label: 'Pond. contrepartie',
          width: 140,
          numeric: true,
          cell: (row) => _ratio(row.finalRiskWeight),
          comparator: _byNumber((row) => row.finalRiskWeight),
          total: (rows) {
            final ead = _sum(rows, (row) => row.ead);
            if (ead <= 0) return '-';
            return _ratio(_sum(rows, (row) => row.rwa) / ead);
          },
        ),
      );
    }

    columns.add(
      _CrmColumn(
        label: 'RWA',
        width: 140,
        numeric: true,
        cell: (row) => _amount(row.rwa),
        comparator: _byNumber((row) => row.rwa),
        total: (rows) => _amount(_sum(rows, (row) => row.rwa)),
        tooltip: (row) => _exactAmount(row.rwa),
      ),
    );

    if (type == 'AUCUNE') {
      columns.add(
        _CrmColumn(
          label: 'Fonds propres',
          width: 140,
          numeric: true,
          cell: (row) => _amount(row.capital),
          comparator: _byNumber((row) => row.capital),
          total: (rows) => _amount(_sum(rows, (row) => row.capital)),
          tooltip: (row) => _exactAmount(row.capital),
        ),
      );
    } else {
      columns.add(
        _CrmColumn(
          label: 'Effet sur RWA',
          width: 140,
          numeric: true,
          cell: (row) => _formatDelta(_rwaDelta(row)),
          comparator: _byNumber(_rwaDelta),
          total: (rows) => _formatDelta(_sum(rows, _rwaDelta)),
          color: (row, c) => _deltaColor(_rwaDelta(row), c),
          tooltip: (row) => 'RWA sans CRM : ${_exactAmount(row.rwaBeforeCrm)}',
        ),
      );
    }

    return columns;
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final columns = _columnsFor(_selectedType);
    final bucketRows = _bucketRows();
    final rows = _visibleRows(columns);
    final media = MediaQuery.sizeOf(context);
    final tableWidth =
        columns.fold<double>(0, (total, col) => total + col.width);

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dash.radius)),
      child: SizedBox(
        width: math.min(media.width * 0.94, 1500),
        height: math.min(media.height * 0.92, 720),
        // Une seule définition d'infobulle pour toute la modale : la note de
        // lecture et les montants exacts des cellules parlent du même ton.
        child: TooltipTheme(
          data: _tooltipTheme(c),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(c),
                const SizedBox(height: 16),
                _buildToolbar(c, bucketRows.length, rows.length),
                const SizedBox(height: 16),
                _buildSummary(c, bucketRows),
                const SizedBox(height: 16),
                Expanded(
                  key: const ValueKey('crm_table'),
                  child: _buildTable(c, columns, rows, tableWidth),
                ),
                _buildAlert(c, bucketRows),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Infobulle sobre : fond papier, encre navy, filet fin et ombre courte.
  /// Étroite par construction pour rester lisible d'un seul regard.
  TooltipThemeData _tooltipTheme(DashColors c) {
    return TooltipThemeData(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      verticalOffset: 14,
      waitDuration: const Duration(milliseconds: 300),
      showDuration: const Duration(seconds: 15),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.border, width: Dash.hairline),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      textStyle: TextStyle(
        color: c.navy,
        fontSize: 11.5,
        height: 1.5,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildHeader(DashColors c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Détail des expositions par CRM',
                style: DashText.hero(c, size: 18)),
            const SizedBox(width: 8),
            TooltipTheme(
              data: _tooltipTheme(c).copyWith(
                constraints: const BoxConstraints(maxWidth: 600),
              ),
              child: Tooltip(
                message: _noteDeLecture(),
                child: Icon(Icons.info_outline, size: 15, color: c.faint),
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Fermer',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  String _noteDeLecture() {
    switch (_selectedType) {
      case 'FINANCÉE':
        return '❶ Encours brut : Bilan + Hors bilan (avant facteur de conversion CCF).\n'
            '❷ EAD : Exposition réduite de la valeur de la sûreté retenue après décote.\n'
            '❸ Tous les montants sont exprimés en XOF.';
      case 'NON FINANCÉE':
        return '❶ Encours brut : Bilan + Hors bilan (avant facteur de conversion CCF).\n'
            '❷ EAD : Exposition ajustée selon le principe de substitution du garant.\n'
            '❸ Tous les montants sont exprimés en XOF.';
      default:
        return '❶ Encours brut : Bilan + Hors bilan (avant facteur de conversion CCF).\n'
            '❷ EAD : Exposition après application du facteur de conversion (CCF).\n'
            '❸ Tous les montants sont exprimés en XOF.';
    }
  }

  Widget _buildToolbar(DashColors c, int bucketCount, int visibleCount) {
    return Row(
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'FINANCÉE', label: Text('Financée')),
            ButtonSegment(value: 'NON FINANCÉE', label: Text('Non financée')),
            ButtonSegment(value: 'AUCUNE', label: Text('Aucune garantie')),
          ],
          selected: {_selectedType},
          onSelectionChanged: (selection) => _selectType(selection.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(1)),
            ),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected) ? c.navy : null;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? Colors.white
                  : c.navy;
            }),
            iconColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? Colors.white
                  : c.navy;
            }),
          ),
        ),
        const SizedBox(width: 16),
        // Le champ cède de la largeur avant que la barre ne déborde : sur un
        // écran étroit, le compteur de lignes reste lisible.
        Flexible(
          child: SizedBox(
            width: 260,
            height: 34,
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 13, color: c.ink),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Rechercher un ID, une contrepartie, un garant',
                hintStyle: TextStyle(fontSize: 12, color: c.faint),
                prefixIcon: Icon(Icons.search, size: 16, color: c.muted),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(1),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(1),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(1),
                  borderSide: BorderSide(color: c.navy),
                ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: c.navy.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(1),
            border: Border.all(color: c.navy.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.layers_outlined, size: 16, color: c.navy),
              const SizedBox(width: 8),
              Text(
                visibleCount == bucketCount
                    ? '$bucketCount ${_bucketNoun(bucketCount)}'
                    : '$visibleCount / $bucketCount ${_bucketNoun(bucketCount)}',
                style: TextStyle(
                  color: c.navy,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _bucketNoun(int count) {
    final plural = count > 1 ? 's' : '';
    switch (_selectedType) {
      case 'FINANCÉE':
        return 'exposition$plural sous sûreté financée';
      case 'NON FINANCÉE':
        return 'exposition$plural sous garantie personnelle';
      default:
        return 'exposition$plural sans garantie';
    }
  }

  Widget _buildSummary(DashColors c, List<PortfolioRow> rows) {
    final tiles = <Widget>[
      _SummaryTile(
        label: 'Encours brut',
        value: _amount(_sum(rows, (row) => row.grossAmount)),
      ),
      _SummaryTile(label: 'EAD', value: _amount(_sum(rows, (row) => row.ead))),
      _SummaryTile(label: 'RWA', value: _amount(_sum(rows, (row) => row.rwa))),
    ];

    if (_selectedType == 'FINANCÉE') {
      tiles.add(_SummaryTile(
        label: 'Sûretés retenues',
        value: _amount(_sum(rows, (row) => row.collateralValueAfterHaircut)),
        caption: 'après décote',
      ));
    } else if (_selectedType == 'NON FINANCÉE') {
      tiles.add(_SummaryTile(
        label: 'Couverture moyenne',
        value: _ratio(_weightedByEad(rows, (row) => row.crmCoveragePercent)),
        caption: 'pondérée par l\'EAD',
      ));
    } else {
      tiles.add(_SummaryTile(
        label: 'Fonds propres',
        value: _amount(_sum(rows, (row) => row.capital)),
        caption: 'exigence à 9 %',
      ));
    }

    if (_selectedType != 'AUCUNE') {
      final delta = _sum(rows, _rwaDelta);
      tiles.add(_SummaryTile(
        label: 'Effet sur RWA',
        value: _formatDelta(delta),
        color: _deltaColor(delta, c),
        caption:
            'RWA sans CRM : ${_amount(_sum(rows, (row) => row.rwaBeforeCrm))}',
      ));
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < tiles.length; index++) ...[
            if (index > 0) const SizedBox(width: 12),
            Expanded(child: tiles[index]),
          ],
        ],
      ),
    );
  }

  /// Signale les garanties qui n'atténuent rien : elles gonflent le taux de
  /// couverture affiché sans alléger d'un franc l'exigence de fonds propres.
  Widget _buildAlert(DashColors c, List<PortfolioRow> rows) {
    String? message;
    if (_selectedType == 'NON FINANCÉE') {
      final sansEffet = rows.where(_isCrmWithoutEffect).toList();
      if (sansEffet.isNotEmpty) {
        final encours = _sum(sansEffet, (row) => row.grossAmount);
        message =
            '${sansEffet.length} garantie${sansEffet.length > 1 ? 's' : ''} sur '
            '${rows.length} (${_amount(encours)}) n\'apporte${sansEffet.length > 1 ? 'nt' : ''} aucun allègement : '
            'le garant n\'est pas mieux pondéré que le débiteur.';
      }
    } else if (_selectedType == 'FINANCÉE') {
      final ineligible = rows.where((row) => !row.crmEligible).toList();
      if (ineligible.isNotEmpty) {
        message =
            '${ineligible.length} sûreté${ineligible.length > 1 ? 's' : ''} '
            'non éligible${ineligible.length > 1 ? 's' : ''} '
            '(sans effet sur l\'exposition).';
      }
    }

    if (message == null) return const SizedBox.shrink();

    // Registre « vigilance », pas « manquement » : le calcul est conforme, le
    // point d'attention porte sur la qualité des garanties déclarées.
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.sousCible.withValues(alpha: 0.06),
          border: Border.all(color: c.sousCible.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: c.sousCible),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 12, color: c.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(
    DashColors c,
    List<_CrmColumn> declaredColumns,
    List<PortfolioRow> rows,
    double tableWidth,
  ) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(border: Border.all(color: c.navy, width: 1.0)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // En-tête, lignes et total vivent dans le MÊME défilement horizontal :
          // aucun décalage possible entre le titre d'une colonne et ses valeurs.
          final available = constraints.maxWidth - 1;
          final scrolls = tableWidth > available;
          // Quand l'onglet tient dans la modale, les colonnes s'étirent pour
          // occuper la largeur : pas de bande morte à droite du tableau.
          final columns = scrolls
              ? declaredColumns
              : [
                  for (final column in declaredColumns)
                    column.scaled(available / tableWidth),
                ];
          final width = math.max(tableWidth, available);
          
          final fixedColumn = columns.first;
          final rightFixedColumns = columns.sublist(columns.length - 2);
          final scrollableColumns = columns.sublist(1, columns.length - 2);
          
          final leftFixedWidth = fixedColumn.width;
          final rightFixedWidth = rightFixedColumns.fold<double>(0, (sum, col) => sum + col.width);
          final scrollableWidth = width - leftFixedWidth - rightFixedWidth;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colonne fixe à gauche (ID)
              SizedBox(
                width: leftFixedWidth,
                child: Column(
                  children: [
                    _buildHeaderRow(c, [fixedColumn]),
                    Expanded(
                      child: rows.isEmpty
                          ? const SizedBox.shrink()
                          : ListView.builder(
                              controller: _vertical1,
                              itemExtent: _rowHeight,
                              itemCount: rows.length,
                              itemBuilder: (context, index) => _buildBodyRow(
                                  c, [fixedColumn], rows[index], index),
                            ),
                    ),
                    if (rows.isNotEmpty)
                      _buildTotalRow(c, [fixedColumn], rows,
                          label: 'TOTAL · ${rows.length}'),
                  ],
                ),
              ),
              // Colonnes défilables au centre
              Expanded(
                child: Scrollbar(
                  controller: _horizontal,
                  thumbVisibility: scrolls,
                  child: SingleChildScrollView(
                    controller: _horizontal,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: scrollableWidth,
                      child: Column(
                        children: [
                          _buildHeaderRow(c, scrollableColumns),
                          Expanded(
                            child: rows.isEmpty
                                ? Center(
                                    child: Text(
                                      'Aucune exposition ne correspond à ce filtre.',
                                      style: DashText.caption(c, color: c.muted),
                                    ),
                                  )
                                : ListView.builder(
                                    controller: _vertical2,
                                    itemExtent: _rowHeight,
                                    itemCount: rows.length,
                                    itemBuilder: (context, index) => _buildBodyRow(
                                        c, scrollableColumns, rows[index], index),
                                  ),
                          ),
                          if (rows.isNotEmpty) _buildTotalRow(c, scrollableColumns, rows),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Colonnes fixes à droite
              SizedBox(
                width: rightFixedWidth,
                child: Column(
                  children: [
                    _buildHeaderRow(c, rightFixedColumns),
                    Expanded(
                      child: rows.isEmpty
                          ? const SizedBox.shrink()
                          : Scrollbar(
                              controller: _vertical3,
                              thumbVisibility: true,
                              child: ListView.builder(
                                controller: _vertical3,
                                itemExtent: _rowHeight,
                                itemCount: rows.length,
                                itemBuilder: (context, index) => _buildBodyRow(
                                    c, rightFixedColumns, rows[index], index),
                              ),
                            ),
                    ),
                    if (rows.isNotEmpty) _buildTotalRow(c, rightFixedColumns, rows),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderRow(DashColors c, List<_CrmColumn> columns) {
    return Container(
      height: _headerHeight,
      color: c.navy,
      child: Row(
        children: [
          for (var index = 0; index < columns.length; index++)
            _buildHeaderCell(c, columns[index], index),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(DashColors c, _CrmColumn column, int index) {
    final isSorted = index == _sortColumn && column.comparator != null;
    return SizedBox(
      width: column.width,
      child: InkWell(
        onTap: column.comparator == null
            ? null
            : () => setState(() {
                  if (_sortColumn == index) {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortColumn = index;
                    _sortAscending = !column.numeric;
                  }
                }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: column.numeric
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (isSorted && column.numeric) _sortIcon(),
              Flexible(
                child: Text(
                  column.label,
                  textAlign: column.numeric ? TextAlign.right : TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ),
              if (isSorted && !column.numeric) _sortIcon(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortIcon() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Icon(
        _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
        size: 12,
        color: Colors.white,
      ),
    );
  }

  Widget _buildBodyRow(
    DashColors c,
    List<_CrmColumn> columns,
    PortfolioRow row,
    int index,
  ) {
    final isSelected = _selectedRowId == row.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedRowId = row.id),
      child: Container(
        height: _rowHeight,
        decoration: BoxDecoration(
          color: isSelected
              ? c.navy.withValues(alpha: 0.1)
              : (index.isEven ? Colors.transparent : c.surfaceAlt),
          border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            for (final column in columns)
              _buildCell(
                c,
                column,
                column.cell(row),
                color: column.color?.call(row, c),
                tooltip: column.tooltip?.call(row),
              ),
          ],
        ),
      ),
    );
  }

  /// [label] n'est posé que sur le bloc figé de gauche : le tableau est
  /// découpé en trois blocs, l'écrire dans chacun le répéterait à l'écran.
  Widget _buildTotalRow(
    DashColors c,
    List<_CrmColumn> columns,
    List<PortfolioRow> rows, {
    String? label,
  }) {
    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        color: c.navy.withValues(alpha: 0.06),
        border: Border(top: BorderSide(color: c.navy, width: 0.8)),
      ),
      child: Row(
        children: [
          for (var index = 0; index < columns.length; index++)
            _buildCell(
              c,
              columns[index],
              index == 0 && label != null
                  ? label
                  : (columns[index].total?.call(rows) ?? ''),
              weight: FontWeight.w700,
            ),
        ],
      ),
    );
  }

  Widget _buildCell(
    DashColors c,
    _CrmColumn column,
    String text, {
    Color? color,
    String? tooltip,
    FontWeight weight = FontWeight.w500,
  }) {
    final label = Text(
      text,
      textAlign: column.numeric ? TextAlign.right : TextAlign.left,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color ?? c.ink,
        fontSize: 11.5,
        fontWeight: weight,
        fontFeatures: column.numeric ? Dash.tabular : null,
      ),
    );
    return SizedBox(
      width: column.width,
      child: Align(
        alignment:
            column.numeric ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: tooltip == null || tooltip.isEmpty
              ? label
              : Tooltip(
                  message: tooltip,
                  constraints: const BoxConstraints(maxWidth: 280),
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
                        color: Colors.black45,
                        offset: Offset(0, 4),
                        blurRadius: 12,
                        spreadRadius: -2,
                      )
                    ],
                  ),
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                  child: label,
                ),
        ),
      ),
    );
  }
}

/// Tuile de synthèse du bandeau : libellé sobre, chiffre tabulaire.
class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    this.caption,
    this.color,
  });

  final String label;
  final String value;
  final String? caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashText.eyebrow(c).copyWith(fontSize: 9.0, color: c.accent),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: DashText.hero(c, size: 16, color: color)),
          ),
          if (caption != null) ...[
            const SizedBox(height: 1),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DashText.caption(c, color: c.muted).copyWith(fontSize: 9.0),
            ),
          ],
        ],
      ),
    );
  }
}

