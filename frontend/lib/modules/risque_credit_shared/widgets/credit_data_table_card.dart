import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/section_card.dart';

class CreditDataTableCard extends StatelessWidget {
  const CreditDataTableCard({
    super.key,
    required this.title,
    required this.columns,
    required this.rows,
    this.toolbar,
    this.trailing,
    this.emptyMessage = 'Portefeuille vide',
    this.headingRowColor,
    this.headingTextStyle,
  });

  final String title;
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final Widget? toolbar;
  final Widget? trailing;
  final String emptyMessage;
  // Permet aux écrans qui le souhaitent (ex. Registre des pertes
  // opérationnelles) de reprendre le style d'en-tête du tableau du module
  // Expositions (fond marine, texte blanc) sans changer l'apparence par
  // défaut des autres tableaux qui utilisent cette carte.
  final WidgetStateProperty<Color?>? headingRowColor;
  final TextStyle? headingTextStyle;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      trailing: trailing,
      child: Column(
        children: [
          if (toolbar != null) ...[
            toolbar!,
            const SizedBox(height: AppTheme.spacing),
          ],
          if (rows.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (columns.isNotEmpty)
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
                          headingRowColor: headingRowColor,
                          headingTextStyle: headingTextStyle ??
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                          dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                          columns: [columns.first],
                          rows: rows.map((r) {
                            return DataRow(
                              key: r.key,
                              selected: r.selected,
                              onSelectChanged: r.onSelectChanged,
                              color: r.color,
                              cells: [r.cells.first],
                            );
                          }).toList(),
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
                          headingRowColor: headingRowColor,
                          headingTextStyle: headingTextStyle ??
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                          dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                          columns: columns.length > 1 ? columns.sublist(1) : [],
                          rows: rows.map((r) {
                            return DataRow(
                              key: r.key,
                              selected: r.selected,
                              onSelectChanged: r.onSelectChanged,
                              color: r.color,
                              cells: r.cells.length > 1 ? r.cells.sublist(1) : [],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
