// Ce fichier affiche le tableau des rapports generes.
import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../models/report_models.dart';

/// Tableau de consultation des rapports générés.
class ReportTable extends StatelessWidget {
  const ReportTable({
    super.key,
    required this.reports,
  });

  final List<ReportRecord> reports;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Periode')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Monnaie')),
          DataColumn(label: Text('Portee')),
          DataColumn(label: Text('Export PDF')),
          DataColumn(label: Text('Export Excel')),
        ];

        final dataRows = reports.map((report) {
          return DataRow(
            cells: [
              DataCell(Text(report.id)),
              DataCell(Text(AppFormatters.shortDate(report.createdAt))),
              DataCell(Text(report.period)),
              DataCell(Text(report.reportType)),
              DataCell(Text(report.currency)),
              DataCell(Text(report.exposureScope)),
              DataCell(Text(report.exports['pdf'] ?? '-')),
              DataCell(Text(report.exports['excel'] ?? '-')),
            ],
          );
        }).toList();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                    width: 1.0,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              child: DataTable(
                columnSpacing: 18,
                horizontalMargin: 8,
                headingRowHeight: 40,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 48,
                dividerThickness: 0.35,
                headingTextStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                columns: [columns.first],
                rows: dataRows.map((r) => DataRow(cells: [r.cells.first])).toList(),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 18,
                  horizontalMargin: 8,
                  headingRowHeight: 40,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 48,
                  dividerThickness: 0.35,
                  headingTextStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                  columns: columns.sublist(1),
                  rows: dataRows.map((r) => DataRow(cells: r.cells.sublist(1))).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
