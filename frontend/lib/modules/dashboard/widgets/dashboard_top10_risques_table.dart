import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'dashboard_design.dart';
import 'dashboard_all_grands_risques_dialog.dart';

class DashboardTop10RisquesTable extends StatelessWidget {
  const DashboardTop10RisquesTable({
    super.key,
    required this.exposures,
    required this.currency,
    this.allExposures = const [],
  });

  final List<TopExposure> exposures;
  final String currency;
  final List<TopExposure> allExposures;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context);
    final scale = 1000000000 / amountUnit.divisor;

    final data = List<TopExposure>.from(exposures)
      ..sort((a, b) => b.netExposure.compareTo(a.netExposure));

    // Couleurs du tableau
    const headerBg = Color(0xFF172B4D);      // Navy profond
    const rowEvenBg = Color(0xFFFFFFFF);      // Blanc pur
    const rowOddBg = Color(0xFFF7F8FB);       // Gris très léger (zébré)
    const borderColor = Color(0xFFE3E7EE);    // Bordure douce

    final totalGrossScaled = data.fold<double>(0.0, (sum, e) => sum + e.exposureAmount) / 1000000000 * scale;
    final totalNetScaled = data.fold<double>(0.0, (sum, e) => sum + e.netExposure) / 1000000000 * scale;
    final totalRatioFP = data.isEmpty ? 0.0 : data.fold<double>(0.0, (sum, e) => sum + e.fpRatio) / data.length;

    Widget vDiv() => Container(width: 0.3, height: 34, color: borderColor);
    Widget vDivHeader() => Container(width: 0.3, height: 30, color: Colors.white24);
    Widget vDivTotal() => Container(width: 0.3, height: 38, color: borderColor);

    return DashPanel(
      title: 'TOP 10 DES GRANDS RISQUES'.tr(context),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (allExposures.isNotEmpty) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => DashboardAllGrandsRisquesDialog(
                      exposures: allExposures,
                      currency: currency,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                hoverColor: c.navy.withValues(alpha: 0.08),
                splashColor: c.navy.withValues(alpha: 0.12),
                highlightColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Voir tous'.tr(context),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.navy,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 12, color: c.navy),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 0.8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  // ── En-tête ──
                  Container(
                    color: headerBg,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    child: Row(
                      children: [
                        const _HeaderCell(label: '#', width: 32, align: TextAlign.center),
                        vDivHeader(),
                        const _HeaderCell(label: 'Contrepartie / Groupe lié', flex: 3),
                        vDivHeader(),
                        const _HeaderCell(label: 'Pays de risque', flex: 2),
                        vDivHeader(),
                        const _HeaderCell(label: 'Risque Brut', flex: 2, align: TextAlign.right),
                        vDivHeader(),
                        const _HeaderCell(label: 'Risque Net', flex: 2, align: TextAlign.right),
                        vDivHeader(),
                        const _HeaderCell(label: 'Ratio RN/FP (%)', flex: 2, align: TextAlign.right),
                        vDivHeader(),
                        const _HeaderCell(label: 'Statut', flex: 2, align: TextAlign.center),
                      ],
                    ),
                  ),
                  // ── Lignes de données ──
                  Column(
                    children: List.generate(
                      data.length < 10 ? 10 : data.length,
                      (index) {
                        final isEven = index.isEven;
                        
                        if (index >= data.length) {
                          return Container(
                            color: isEven ? rowEvenBg : rowOddBg,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            child: Container(
                              decoration: const BoxDecoration(),
                              padding: const EdgeInsets.symmetric(vertical: 0),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 32,
                                    child: Text(
                                      '${index + 1}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFC1C7D0),
                                        fontFeatures: Dash.tabular,
                                      ),
                                    ),
                                  ),
                                  vDiv(),
                                  const Expanded(flex: 3, child: SizedBox.shrink()),
                                  vDiv(),
                                  const Expanded(flex: 2, child: SizedBox.shrink()),
                                  vDiv(),
                                  const Expanded(flex: 2, child: SizedBox.shrink()),
                                  vDiv(),
                                  const Expanded(flex: 2, child: SizedBox.shrink()),
                                  vDiv(),
                                  const Expanded(flex: 2, child: SizedBox.shrink()),
                                  vDiv(),
                                  const Expanded(flex: 2, child: SizedBox.shrink()),
                                ],
                              ),
                            ),
                          );
                        }

                        final e = data[index];
                        final expScaled = e.exposureAmount;
                        final netScaled = e.netExposure;

                        return Container(
                          color: isEven ? rowEvenBg : rowOddBg,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          child: Container(
                            decoration: const BoxDecoration(),
                            padding: const EdgeInsets.symmetric(vertical: 0),
                            child: Row(
                              children: [
                                // Rang
                                SizedBox(
                                  width: 32,
                                  child: Text(
                                    '${index + 1}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: c.navy,
                                      fontFeatures: Dash.tabular,
                                    ),
                                  ),
                                ),
                                vDiv(),
                                // Contrepartie
                                Expanded(
                                  flex: 3,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      e.counterparty,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: c.navy,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                vDiv(),
                                // Pays de risque
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      e.country,
                                      style: TextStyle(fontSize: 11, color: c.ink),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                vDiv(),
                                // Risque Brut
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      '${AppFormatters.formatAmountValue(expScaled)}${AppFormatters.formatAmountSuffix(expScaled)}'.trim(),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: c.ink,
                                        fontFeatures: Dash.tabular,
                                      ),
                                    ),
                                  ),
                                ),
                                vDiv(),
                                // Risque Net
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      '${AppFormatters.formatAmountValue(netScaled)}${AppFormatters.formatAmountSuffix(netScaled)}'.trim(),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: c.ink,
                                        fontFeatures: Dash.tabular,
                                      ),
                                    ),
                                  ),
                                ),
                                vDiv(),
                                // Ratio RN/FP (%)
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      '${e.fpRatio.toStringAsFixed(1)} %',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: e.fpRatio > 25 ? c.sousMinimum : e.fpRatio >= 20 ? c.sousCible : c.ink,
                                        fontFeatures: Dash.tabular,
                                      ),
                                    ),
                                  ),
                                ),
                                vDiv(),
                                // Statut
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: _StatutBadge(status: e.status, colors: c),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // ── Ligne des Totaux ──
                  if (data.isNotEmpty)
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0F4F8),
                        border: Border(top: BorderSide(color: borderColor, width: 1.5)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      child: Row(
                        children: [
                          const SizedBox(width: 32),
                          vDivTotal(),
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'Total'.tr(context),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: headerBg,
                                ),
                              ),
                            ),
                          ),
                          vDivTotal(),
                          const Expanded(flex: 2, child: SizedBox.shrink()),
                          vDivTotal(),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${AppFormatters.formatAmountValue(totalGrossScaled)}${amountUnit.label}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: headerBg,
                                  fontFeatures: Dash.tabular,
                                ),
                              ),
                            ),
                          ),
                          vDivTotal(),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${AppFormatters.formatAmountValue(totalNetScaled)}${amountUnit.label}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: headerBg,
                                  fontFeatures: Dash.tabular,
                                ),
                              ),
                            ),
                          ),
                          vDivTotal(),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${totalRatioFP.toStringAsFixed(1)} %',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: totalRatioFP > 25 ? c.sousMinimum : headerBg,
                                  fontFeatures: Dash.tabular,
                                ),
                              ),
                            ),
                          ),
                          vDivTotal(),
                          const Expanded(flex: 2, child: SizedBox.shrink()),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cellule d'en-tête du tableau.
class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    this.flex,
    this.width,
    this.align = TextAlign.left,
  });

  final String label;
  final int? flex;
  final double? width;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label.tr(context),
        textAlign: align,
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 10.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: child);
    }
    return Expanded(flex: flex ?? 1, child: child);
  }
}

/// Badge de statut avec pastille colorée.
class _StatutBadge extends StatelessWidget {
  const _StatutBadge({required this.status, required this.colors});

  final String status;
  final DashColors colors;

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color bgColor;

    switch (status) {
      case 'Dépassement':
        textColor = colors.sousMinimum;
        bgColor = const Color(0xFFFEF2F2);
        break;

      default: // Dans la norme
        textColor = colors.conforme;
        bgColor = const Color(0xFFF0FDF4);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          status.tr(context),
          maxLines: 1,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
