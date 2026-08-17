// Ce fichier affiche le tableau CRM avant et apres mitigation.
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/state/portfolio_currency_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../models/crm_models.dart';

/// Tableau de consultation des garanties CRM.
class CrmTable extends StatelessWidget {
  const CrmTable({
    super.key,
    required this.rows,
  });

  final List<CrmRecord> rows;

  @override
  Widget build(BuildContext context) {
    final displayCurrency = PortfolioCurrencyScope.maybeOf(context);
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = [
          DataColumn(label: Text(context.tr('ID'))),
          DataColumn(label: Text(context.tr('Emprunteur'))),
          DataColumn(label: Text(context.tr('Garant'))),
          DataColumn(label: Text(context.tr('Couverture'))),
          DataColumn(label: Text(context.tr('RW Avant'))),
          DataColumn(label: Text(context.tr('RW Final'))),
          DataColumn(label: Text(context.tr('RWA Avant'))),
          DataColumn(label: Text(context.tr('RWA Apres'))),
          DataColumn(label: Text(context.tr('Economie Capital'))),
        ];

        final dataRows = rows.map((row) {
          return DataRow(
            cells: [
              DataCell(Text(row.id)),
              DataCell(Text(row.borrowerName)),
              DataCell(Text(row.guarantorName)),
              DataCell(Text(formatCurrencyInDisplayUnit(
                row.coverageAmount,
                toCurrency: displayCurrency,
                amountUnit: amountUnit,
              ))),
              DataCell(Text(AppFormatters.percent(row.borrowerRw))),
              DataCell(Text(AppFormatters.percent(row.finalRw))),
              DataCell(Text(formatCurrencyInDisplayUnit(
                row.rwaBefore,
                toCurrency: displayCurrency,
                amountUnit: amountUnit,
              ))),
              DataCell(Text(formatCurrencyInDisplayUnit(
                row.rwaAfter,
                toCurrency: displayCurrency,
                amountUnit: amountUnit,
              ))),
              DataCell(Text(formatCurrencyInDisplayUnit(
                row.capitalSaving,
                toCurrency: displayCurrency,
                amountUnit: amountUnit,
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
