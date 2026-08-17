import 'dart:async';
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/utils/file_save.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';
import '../../risque_credit_shared/models/credit_risk_models.dart';
import '../../risque_credit_shared/services/credit_risk_submodules_service.dart';
import '../../risque_credit_shared/widgets/credit_data_table_card.dart';
import '../../risque_credit_shared/widgets/credit_module_toolbar.dart';
import '../../risque_credit_shared/widgets/credit_stat_card.dart';

class ReportingCreditScreen extends StatefulWidget {
  const ReportingCreditScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<ReportingCreditScreen> createState() => _ReportingCreditScreenState();
}

class _ReportingCreditScreenState extends State<ReportingCreditScreen> {
  late final CreditRiskSubmodulesService _service;
  late Future<CreditReportingModuleData> _future;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<int>? _portfolioSubscription;

  CreditReportFamily _selectedFamily = CreditReportFamily.portfolio;
  String _selectedPeriod = 'T2 2026';
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _service = CreditRiskSubmodulesService(widget.api);
    _future = _service.fetchReportingModule();
    _portfolioSubscription = widget.api.portfolioRefreshStream.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() => _future = _service.fetchReportingModule());
    });
  }

  @override
  void dispose() {
    _portfolioSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CreditReportingModuleData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final data = snapshot.data!;
        final filteredHistory = data.history.where((item) {
          final query = _searchController.text.trim().toLowerCase();
          if (query.isEmpty) {
            return true;
          }
          return item.id.toLowerCase().contains(query) ||
              item.fileName.toLowerCase().contains(query) ||
              item.family.label.toLowerCase().contains(query);
        }).toList(growable: false);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'Reporting',
                subtitle:
                    'Exports Excel/PDF et préparation de rapports de portefeuille, garanties et défauts à partir des données déjà disponibles.',
              ),
              const SizedBox(height: AppTheme.pageGap),
              _buildTopStats(data),
              const SizedBox(height: AppTheme.pageGap),
              _buildFamilyOverview(data),
              const SizedBox(height: AppTheme.pageGap),
              SectionCard(
                title: 'Génération d un rapport',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppTheme.spacing,
                      runSpacing: AppTheme.spacing,
                      children: [
                        _buildFamilyDropdown(),
                        _buildPeriodDropdown(),
                        FilledButton.icon(
                          onPressed: _exporting
                              ? null
                              : () => _exportReport(CreditExportFormat.excel),
                          icon: const Icon(Icons.table_chart_rounded),
                          label: Text(
                              _exporting ? 'Export...' : 'Exporter en Excel'),
                        ),
                        FilledButton.icon(
                          onPressed: _exporting
                              ? null
                              : () => _exportReport(CreditExportFormat.pdf),
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFB45309),
                          ),
                          label: Text(
                              _exporting ? 'Export...' : 'Exporter en PDF'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing),
                    Text(
                      _selectedFamily.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.muted,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.pageGap),
              CreditDataTableCard(
                title: 'Historique des exports',
                toolbar: CreditModuleToolbar(
                  searchController: _searchController,
                  searchHint:
                      'Rechercher un export, un fichier ou un sous-module',
                  onSearchChanged: (_) => setState(() {}),
                ),
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Famille')),
                  DataColumn(label: Text('Format')),
                  DataColumn(label: Text('Expositions')),
                  DataColumn(label: Text('Montant couvert')),
                  DataColumn(label: Text('Fichier')),
                ],
                rows: filteredHistory
                    .map(
                      (item) => DataRow(
                        cells: [
                          DataCell(Text(item.id)),
                          DataCell(
                              Text(AppFormatters.shortDate(item.createdAt))),
                          DataCell(Text(item.family.label)),
                          DataCell(Text(item.format.label)),
                          DataCell(Text(item.lineCount.toString())),
                          DataCell(Text(formatCurrencyForDisplay(
                            item.totalAmount,
                            toCurrency: 'XOF',
                          ))),
                          DataCell(Text(item.fileName)),
                        ],
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopStats(CreditReportingModuleData data) {
    final stats = [
      CreditStatCard(
        label: 'Exports générés',
        value: data.summary.generatedReports.toString(),
        helper: 'Historique de reporting crédit',
        icon: Icons.description_outlined,
        color: AppTheme.sidebarLight,
        lottieAsset: 'assets/lotties/rwa_dashboard.json',
      ),
      CreditStatCard(
        label: 'Exports Excel',
        value: data.summary.excelExports.toString(),
        helper: 'Classeur(s) prêts au partage',
        icon: Icons.table_chart_rounded,
        color: AppTheme.success,
      ),
      CreditStatCard(
        label: 'Exports PDF',
        value: data.summary.pdfExports.toString(),
        helper: 'Pack(s) de diffusion',
        icon: Icons.picture_as_pdf_rounded,
        color: AppTheme.warning,
      ),
      CreditStatCard(
        label: 'Périmètres couverts',
        value: data.familySnapshots.length.toString(),
        helper: 'Portefeuille, garanties, défauts',
        icon: Icons.layers_outlined,
        color: AppTheme.accent,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 960
            ? 190.0
            : constraints.maxWidth >= 620
                ? ((constraints.maxWidth - AppTheme.spacing) / 2)
                    .clamp(0.0, 190.0)
                    .toDouble()
                : constraints.maxWidth;

        return Wrap(
          spacing: AppTheme.spacing,
          runSpacing: AppTheme.spacing,
          children: [
            for (final stat in stats)
              SizedBox(
                width: width,
                child: stat,
              ),
          ],
        );
      },
    );
  }

  Widget _buildFamilyOverview(CreditReportingModuleData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 1120
            ? (constraints.maxWidth - (AppTheme.spacing * 2)) / 3
            : constraints.maxWidth;

        return Wrap(
          spacing: AppTheme.spacing,
          runSpacing: AppTheme.spacing,
          children: [
            for (final snapshot in data.familySnapshots)
              SizedBox(
                width: width,
                child: _FamilySnapshotCard(
                  snapshot: snapshot,
                  selected: snapshot.family == _selectedFamily,
                  onTap: () =>
                      setState(() => _selectedFamily = snapshot.family),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFamilyDropdown() {
    return SizedBox(
      width: 240,
      child: DropdownButtonFormField<CreditReportFamily>(
        initialValue: _selectedFamily,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Famille de rapport'),
        items: CreditReportFamily.values
            .map(
              (item) => DropdownMenuItem<CreditReportFamily>(
                value: item,
                child: Text(
                  item.label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(growable: false),
        selectedItemBuilder: (context) => CreditReportFamily.values
            .map(
              (item) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(growable: false),
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedFamily = value);
          }
        },
      ),
    );
  }

  Widget _buildPeriodDropdown() {
    const periods = ['Mensuel', 'T2 2026', 'Semestriel', 'Annuel'];
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        initialValue: _selectedPeriod,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Période'),
        items: periods
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(growable: false),
        selectedItemBuilder: (context) => periods
            .map(
              (item) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(growable: false),
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedPeriod = value);
          }
        },
      ),
    );
  }

  Future<void> _exportReport(CreditExportFormat format) async {
    setState(() => _exporting = true);
    try {
      final dataset = await _service.buildExportDataset(_selectedFamily);
      final bytes = format == CreditExportFormat.excel
          ? _buildExcelBytes(dataset)
          : await _buildPdfBytes(dataset);
      final suggestedName =
          '${_selectedFamily.label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${_timestamp()}${format.fileExtension}';
      final location = await getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: [
          XTypeGroup(
            label: format.label,
            extensions: [format.fileExtension.replaceFirst('.', '')],
          ),
        ],
      );
      if (!mounted || location == null) {
        return;
      }

      final savedFile = await saveBytesAtLocation(
        location,
        bytes,
        requiredExtension: format.fileExtension,
      );
      await _service.registerExport(
        family: _selectedFamily,
        format: format,
        fileName: _extractFileName(savedFile.path),
        lineCount: dataset.rows.length,
        totalAmount: dataset.totalAmount,
      );
      if (!mounted) {
        return;
      }
      setState(() => _future = _service.fetchReportingModule());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.success,
          content: Text(
            'Export ${format.label} enregistré: ${_extractFileName(savedFile.path)}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('Export impossible: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Uint8List _buildExcelBytes(CreditExportDataset dataset) {
    final workbook = Excel.createExcel();
    final defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != dataset.sheetName) {
      workbook.rename(defaultSheet, dataset.sheetName);
    }
    final sheet = workbook[dataset.sheetName];

    sheet.appendRow(
      dataset.headers
          .map((value) => TextCellValue(value))
          .toList(growable: false),
    );
    for (final row in dataset.rows) {
      sheet.appendRow(
        row.map((value) => TextCellValue(value)).toList(growable: false),
      );
    }

    final bytes = workbook.save();
    if (bytes == null) {
      throw StateError('Impossible de générer le fichier Excel.');
    }
    return Uint8List.fromList(bytes);
  }

  Future<Uint8List> _buildPdfBytes(CreditExportDataset dataset) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(5),
        build: (_) => [
          pw.Text(
            'Reporting ${_selectedFamily.label} - $_selectedPeriod',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.TableHelper.fromTextArray(
            headers: dataset.headers,
            data: dataset.rows,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF234A84),
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(
              color: const PdfColor.fromInt(0xFFD8E1F2),
              width: 0.4,
            ),
          ),
        ],
      ),
    );
    return document.save();
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  String _extractFileName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }
}

class _FamilySnapshotCard extends StatelessWidget {
  const _FamilySnapshotCard({
    required this.snapshot,
    required this.selected,
    required this.onTap,
  });

  final CreditReportingFamilySnapshot snapshot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (snapshot.family) {
      CreditReportFamily.portfolio => AppTheme.sidebarLight,
      CreditReportFamily.guarantees => AppTheme.success,
      CreditReportFamily.defaults => AppTheme.warning,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.10)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: selected ? color : Theme.of(context).dividerColor,
            width: selected ? 0.9 : 0.4,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x050F172A),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              snapshot.family.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              snapshot.family.subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
                  ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _SnapshotPill(
                    label: 'Expositions',
                    value: snapshot.itemCount.toString(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SnapshotPill(
                    label: 'Montant',
                    value: formatCurrencyForDisplay(
                      snapshot.totalAmount,
                      toCurrency: 'XOF',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotPill extends StatelessWidget {
  const _SnapshotPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
