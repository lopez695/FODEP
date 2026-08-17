// Ce fichier affiche une table de referentiel reutilisable.
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../shared/widgets/section_card.dart';

/// Carte qui encapsule un tableau de référentiel.
class ReferenceTableCard extends StatelessWidget {
  const ReferenceTableCard({
    super.key,
    required this.title,
    required this.columns,
    required this.rows,
  });

  final String title;
  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 18,
          horizontalMargin: 8,
          headingRowHeight: 38,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 44,
          dividerThickness: 0.4,
          headingTextStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
          dataTextStyle: Theme.of(context).textTheme.bodyMedium,
          columns: columns
              .map((item) => DataColumn(label: Text(item.tr(context))))
              .toList(),
          rows: rows
              .map(
                (row) => DataRow(
                  cells: row.map((cell) => DataCell(Text(cell))).toList(),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
