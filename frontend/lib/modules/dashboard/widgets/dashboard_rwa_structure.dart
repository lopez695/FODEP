import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/formatters.dart';
import 'dashboard_design.dart';

/// Décomposition des RWA et Méthodologie.
class DashboardRwaStructure extends StatelessWidget {
  const DashboardRwaStructure({super.key, this.currency = 'XOF'});

  final String currency;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context);
    final scale = 1000000000 / amountUnit.divisor;

    final rwaTotal = 3180.0 * scale;

    final parts = <_RwaPart>[
      _RwaPart('Crédit (Approche Standard)', 2450 * scale, 77, c.ramp[0]),
      _RwaPart('Marché (Modèles Internes)', 320 * scale, 10, c.ramp[2]),
      _RwaPart('Opérationnel (Indicateur de Base)', 410 * scale, 13, c.ramp[4]),
    ];

    return DashPanel(
      title: 'STRUCTURE DES RWA'.tr(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête RWA Total & Capital Minimum
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total RWA'.tr(context), style: DashText.caption(c, color: c.muted)),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(AppFormatters.integer(rwaTotal), style: DashText.hero(c, size: 24).copyWith(color: c.navy)),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('${amountUnit.label} ($currency)', style: DashText.caption(c, color: c.muted)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Détails des parts
          Column(
            children: [
              for (var i = 0; i < parts.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                _buildPartRow(context, parts[i], c, currency, amountUnit.label),
              ]
            ],
          ),
          
          const SizedBox(height: 24),
          Text(
            'Contribution aux exigences minimales (9%)'.tr(context),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink),
          ),
          const SizedBox(height: 12),
          for (var p in parts) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(p.label.split(' ').first.tr(context), style: TextStyle(fontSize: 13, color: c.muted)),
                  Text(
                    '${AppFormatters.integer(p.amount * 0.09)} ${amountUnit.label}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPartRow(BuildContext context, _RwaPart p, DashColors c, String currency, String unitLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: p.color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(p.label.tr(context), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
              ],
            ),
            Text('${AppFormatters.integer(p.amount)}$unitLabel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: p.percent / 100,
            backgroundColor: c.divider,
            valueColor: AlwaysStoppedAnimation<Color>(p.color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _RwaPart {
  const _RwaPart(this.label, this.amount, this.percent, this.color);
  final String label;
  final double amount;
  final double percent;
  final Color color;
}
