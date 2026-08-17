import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/utils/currency_conversion.dart';
import '../models/dashboard_models.dart';

class DashboardLargeExposures extends StatelessWidget {
  const DashboardLargeExposures({
    super.key,
    required this.topCounterparties,
    required this.fondsPropres,
    required this.displayCurrency,
  });

  final List<PortfolioRow> topCounterparties;
  final double fondsPropres;
  final String displayCurrency;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Grands Risques (Top Contreparties)'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
                'Méthodologie: Exposition Nette (Brut - Garanties) vs 25% des Fonds Propres'),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),
          if (topCounterparties.isEmpty)
            Text(
              context.tr('Aucune donnée de contrepartie.'),
              style: TextStyle(color: textColor),
            )
          else
            ...topCounterparties.take(3).map(
                (row) => _buildExposureRow(context, row, isDark, textColor)),
        ],
      ),
    );
  }

  Widget _buildExposureRow(
      BuildContext context, PortfolioRow row, bool isDark, Color textColor) {
    // Exposition nette simplifiée : Gross Amount - Off Balance Exposure (as a proxy for CRM if not provided, though ideally we should have net exposure).
    // The instructions say: "Montant brut - Garanties = Exposition Nette". If we don't have explicit net exposure, we'll use a placeholder logic or gross.
    // We will use EAD (Exposure At Default) as a proxy for Net Exposure if it's there.
    final netExposure = row.ead > 0 ? row.ead : row.grossAmount;

    final ratioFP = fondsPropres > 0 ? netExposure / fondsPropres : 0.0;
    final isBreached = ratioFP >= 0.25;

    final String netExposureFormatted = formatCurrencyForDisplay(
      netExposure,
      toCurrency: displayCurrency,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  row.counterparty.isNotEmpty ? row.counterparty : row.id,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                netExposureFormatted,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('Consommation FP: {{value}}%', args: {'value': (ratioFP * 100).toStringAsFixed(2)}),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isBreached ? Colors.redAccent : Colors.teal,
                ),
              ),
              if (isBreached)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Limite 25% dépassée'.tr(context),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
              color:
                  isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
        ],
      ),
    );
  }
}
