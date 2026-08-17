import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'dashboard_design.dart';

/// Structure des fonds propres réglementaires - décomposition par tier.
///
/// Design premium : barre de composition visuelle globale, suivie d'une
/// liste épurée avec des indicateurs colorés pour une lecture instantanée.
class DashboardFondsPropres extends StatelessWidget {
  const DashboardFondsPropres({
    super.key,
    this.currency = 'XOF',
    required this.data,
    this.onEdit,
  });

  final String currency;
  final DashboardSnapshot data;
  final VoidCallback? onEdit;

  // Jusqu'à 3 décimales utiles, sans zéros de remplissage - même précision
  // que les tooltips du graphique « Exigences de fonds propres » pour que le
  // même montant se lise à l'identique partout.
  String _formatAmount(double value, PortfolioAmountUnit unit) {
    return AppFormatters.decimalNumber(value / unit.divisor, maxDecimals: 3);
  }

  String _formatTotalAmount(double value, PortfolioAmountUnit unit) {
    return AppFormatters.decimalNumber(value / unit.divisor, maxDecimals: 3);
  }

  String _formatTotalUnit(double value, PortfolioAmountUnit unit) {
    return AppFormatters.formatAmountSuffix(value, unit.label);
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context);

    final fp = data.fondsPropres;
    final totalFP = fp?.totalFp ?? 0.0;
    final cet1 = fp?.cet1 ?? 0.0;
    final at1 = fp?.at1 ?? 0.0;
    final tier2 = fp?.tier2 ?? 0.0;

    return DashPanel(
      title: 'Fonds propres réglementaires'.tr(context),
      trailing: onEdit != null
          ? ElevatedButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text('Mettre à jour'.tr(context)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                elevation: 0,
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: onEdit,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero total
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTotalAmount(totalFP, amountUnit),
                style: DashText.hero(c, size: 24).copyWith(color: c.navy),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _formatTotalUnit(totalFP, amountUnit),
                  style: DashText.caption(c, color: c.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Treemap Layout (3-column)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border.all(color: c.divider.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildTreemapCol(
                      context,
                      title: 'CET1',
                      subtitle: 'Common Equity Tier 1',
                      amount: cet1,
                      color: c.navy,
                      textColor: c.ramp[0],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          _buildCompactRow(
                              context,
                              'Capital ordinaire',
                              fp?.capitalOrdinaire ?? 0.0,
                              const Color(0xFF1E40AF),
                              amountUnit),
                          _buildCompactRow(context, 'Réserves', fp?.reserves ?? 0.0,
                              const Color(0xFF2563EB), amountUnit),
                          _buildCompactRow(
                              context,
                              'Résultats en report',
                              fp?.resultatsReport ?? 0.0,
                              const Color(0xFF3B82F6),
                              amountUnit),
                          _buildCompactRow(
                              context,
                              'Résultat éligible',
                              fp?.resultatEligible ?? 0.0,
                              const Color(0xFF93C5FD),
                              amountUnit),
                          _buildCompactRow(
                              context,
                              'Réduction prud.',
                              -(fp?.deductionsPrudCet1 ?? 0.0),
                              const Color(0xFFEF4444),
                              amountUnit),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 1,
                    color: c.divider.withValues(alpha: 0.8),
                  ),
                  Expanded(
                    flex: 4,
                    child: _buildTreemapCol(
                      context,
                      title: 'AT1',
                      subtitle: 'Additional Tier 1',
                      amount: at1,
                      color: c.ramp[2],
                      textColor: c.ramp[0],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          _buildCompactRow(context, 'Instruments add.',
                              fp?.instrumentsAt1 ?? 0.0, c.ramp[1], amountUnit),
                          _buildCompactRow(
                              context,
                              'Primes d\'émission',
                              fp?.primesEmissionAt1 ?? 0.0,
                              c.ramp[2],
                              amountUnit),
                          _buildCompactRow(
                              context,
                              'Réduction prud.',
                              -(fp?.deductionsPrudAt1 ?? 0.0),
                              const Color(0xFFEF4444),
                              amountUnit),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 1,
                    color: c.divider.withValues(alpha: 0.8),
                  ),
                  Expanded(
                    flex: 3,
                    child: _buildTreemapCol(
                      context,
                      title: 'Tier 2',
                      subtitle: 'Capital Complémentaire',
                      amount: tier2,
                      color: c.ramp[4],
                      textColor: c.ramp[0],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          _buildCompactRow(
                              context,
                              'Dettes subordonnées',
                              fp?.dettesSubordonneesT2 ?? 0.0,
                              c.ramp[3],
                              amountUnit),
                          _buildCompactRow(
                              context,
                              'Provisions générales',
                              fp?.provisionsGeneralesT2 ?? 0.0,
                              c.ramp[4],
                              amountUnit),
                          _buildCompactRow(
                              context,
                              'Réduction prud.',
                              -(fp?.deductionsPrudT2 ?? 0.0),
                              const Color(0xFFEF4444),
                              amountUnit),
                        ],
                      ),
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

  Widget _buildTreemapCol(
    BuildContext context, {
    required String title,
    required String subtitle,
    required double amount,
    required Color color,
    required Color textColor,
    required Widget child,
  }) {
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      color: color.withValues(alpha: 0.03),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title.tr(context),
                  style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900)),
              Text(_formatAmountWithUnit(amount, amountUnit),
                  style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle.tr(context),
              style: TextStyle(
                color: textColor.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
          Divider(
              height: 16, thickness: 0.5, color: color.withValues(alpha: 0.3)),
          Expanded(child: child),
        ],
      ),
    );
  }

  String _formatAmountWithUnit(double value, PortfolioAmountUnit unit) {
    // Les déductions sont passées négativées ; quand elles valent zéro le
    // double -0.0 s'afficherait « -0 ». On normalise vers le zéro positif.
    final normalized = value == 0.0 ? 0.0 : value;
    final amountVal = _formatAmount(normalized, unit);
    final amountSuffix = AppFormatters.formatAmountSuffix(normalized, unit.label);
    return '$amountVal $amountSuffix'.trim();
  }

  Widget _buildCompactRow(BuildContext context, String label, double amount, Color color,
      PortfolioAmountUnit amountUnit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 1,
              offset: const Offset(0, 1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label.tr(context),
                style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
                softWrap: true,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatAmountWithUnit(amount, amountUnit),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111827)),
            ),
          ],
        ),
      ),
    );
  }
}
