// Ce fichier affiche le tableau des expositions.
import 'package:flutter/material.dart';

import '../../../core/state/portfolio_currency_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../models/exposition_models.dart';

/// Tableau qui affiche les expositions filtrées.
class ExposureTable extends StatelessWidget {
  const ExposureTable({
    super.key,
    required this.rows,
  });

  final List<ExposureRecord> rows;

  @override
  Widget build(BuildContext context) {
    final displayCurrency = PortfolioCurrencyScope.maybeOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Contrepartie')),
          DataColumn(label: Text('Categorie')),
          DataColumn(label: Text('Notation')),
          DataColumn(label: Text('Pays')),
          DataColumn(label: Text('Montant Brut')),
          DataColumn(label: Text('CRM')),
          DataColumn(label: Text('RW Final')),
          DataColumn(label: Text('RWA')),
          DataColumn(label: Text('Capital')),
        ];
        
        final dataRows = rows.map((row) {
          return DataRow(
            cells: [
              DataCell(Text(row.id)),
              DataCell(Text(row.counterparty.name)),
              DataCell(Text(row.categoryLabel)),
              DataCell(Text(row.counterparty.rating)),
              DataCell(Text(row.counterparty.country)),
              DataCell(Text(formatCurrencyForDisplay(
                row.grossAmount,
                fromCurrency: row.currency,
                toCurrency: displayCurrency,
              ))),
              DataCell(Text(
                  '${(row.crmCoveragePercent * 100).toStringAsFixed(0)} %')),
              DataCell(Text('${(row.finalRw * 100).toStringAsFixed(0)} %')),
              DataCell(Text(formatCurrencyForDisplay(
                row.rwa,
                fromCurrency: row.currency,
                toCurrency: displayCurrency,
              ))),
              DataCell(Text(formatCurrencyForDisplay(
                row.capital,
                fromCurrency: row.currency,
                toCurrency: displayCurrency,
              ))),
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
