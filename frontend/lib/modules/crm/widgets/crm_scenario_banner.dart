// Ce fichier affiche le scenario CRM mis en avant.
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/section_card.dart';
import '../models/crm_models.dart';

/// Bandeau visuel qui illustre le scénario CRM avant/après.
class CrmScenarioBanner extends StatelessWidget {
  const CrmScenarioBanner({
    super.key,
    required this.highlight,
  });

  final CrmHighlight? highlight;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Scenario',
      child: highlight == null
          ? Text('Aucun scenario CRM disponible.'.tr(context))
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 920;
                final resultCard = Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing, vertical: AppTheme.spacing),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    color: const Color(0xFFE7F7EF),
                  ),
                  child: Column(
                    children: [
                      Text(
                        highlight!.label.tr(context),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF0F766E),
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr(
                          'RW final {{value}}',
                          args: {
                            'value': AppFormatters.percent(highlight!.finalRw),
                          },
                        ),
                      ),
                    ],
                  ),
                );

                if (isWide) {
                  return Row(
                    children: [
                      _ScenarioNode(
                        title: 'Emprunteur',
                        name: highlight!.borrowerName,
                        rw: AppFormatters.percent(highlight!.borrowerRw),
                        icon: Icons.business_outlined,
                      ),
                      const Expanded(
                        child: Center(
                          child:
                              Icon(Icons.arrow_forward, color: Colors.blueGrey),
                        ),
                      ),
                      _ScenarioNode(
                        title: 'Garant',
                        name: highlight!.guarantorName,
                        rw: AppFormatters.percent(highlight!.guarantorRw),
                        icon: Icons.shield_outlined,
                      ),
                      const Expanded(
                        child: Center(
                          child: Icon(Icons.equalizer_rounded,
                              color: Colors.blueGrey),
                        ),
                      ),
                      resultCard,
                    ],
                  );
                }

                return Column(
                  children: [
                    _ScenarioNode(
                      title: 'Emprunteur',
                      name: highlight!.borrowerName,
                      rw: AppFormatters.percent(highlight!.borrowerRw),
                      icon: Icons.business_outlined,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppTheme.spacing),
                      child: Icon(Icons.arrow_downward, color: Colors.blueGrey),
                    ),
                    _ScenarioNode(
                      title: 'Garant',
                      name: highlight!.guarantorName,
                      rw: AppFormatters.percent(highlight!.guarantorRw),
                      icon: Icons.shield_outlined,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppTheme.spacing),
                      child:
                          Icon(Icons.equalizer_rounded, color: Colors.blueGrey),
                    ),
                    resultCard,
                  ],
                );
              },
            ),
    );
  }
}

/// Élément visuel interne utilisé dans le schéma CRM.
class _ScenarioNode extends StatelessWidget {
  const _ScenarioNode({
    required this.title,
    required this.name,
    required this.rw,
    required this.icon,
  });

  final String title;
  final String name;
  final String rw;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: const Color(0xFFDCE3F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2563EB)),
          const SizedBox(height: 8),
          Text(title.tr(context),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(context.tr('RW = {{value}}', args: {'value': rw})),
        ],
      ),
    );
  }
}
