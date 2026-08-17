// Ce fichier affiche le tableau des engagements hors bilan.
import 'package:flutter/material.dart';

import '../../../core/state/portfolio_currency_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../models/hors_bilan_models.dart';

/// Tableau d'affichage des engagements hors bilan.
class OffBalanceTable extends StatelessWidget {
  const OffBalanceTable({
    super.key,
    required this.rows,
  });

  final List<OffBalanceRecord> rows;

  @override
  Widget build(BuildContext context) {
    final displayCurrency = PortfolioCurrencyScope.maybeOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Contrepartie')),
          DataColumn(label: Text('Nature d\'engagement')),
          DataColumn(label: Text('Nominal')),
          DataColumn(label: Text('CCF')),
          DataColumn(label: Text('EAD')),
          DataColumn(label: Text('RW')),
          DataColumn(label: Text('RWA')),
          DataColumn(label: Text('Capital')),
        ];

        final dataRows = rows.map((row) {
          return DataRow(
            cells: [
              DataCell(Text(row.id)),
              DataCell(Text(row.counterpartyName)),
              DataCell(Text(row.engagementType)),
              DataCell(Text(formatCurrencyForDisplay(
                row.nominalAmount,
                toCurrency: displayCurrency,
              ))),
              DataCell(Text(AppFormatters.percent(row.ccf))),
              DataCell(Text(formatCurrencyForDisplay(
                row.ead,
                toCurrency: displayCurrency,
              ))),
              DataCell(Text(AppFormatters.percent(row.riskWeight))),
              DataCell(Text(formatCurrencyForDisplay(
                row.rwa,
                toCurrency: displayCurrency,
              ))),
              DataCell(Text(formatCurrencyForDisplay(
                row.capital,
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
