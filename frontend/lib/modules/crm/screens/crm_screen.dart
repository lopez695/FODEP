// Ce fichier affiche le module CRM.
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';
import '../models/crm_models.dart';
import '../widgets/crm_scenario_banner.dart';
import '../widgets/crm_table.dart';

/// Ecran de gestion des techniques de réduction du risque.
class CrmScreen extends StatefulWidget {
  const CrmScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

/// Etat interne de l'écran CRM et de ses sélections.
class _CrmScreenState extends State<CrmScreen> {
  late Future<CrmModuleData> _future;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchCrmModule();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CrmModuleData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              context.tr('Erreur: {{error}}', args: {'error': snapshot.error}),
            ),
          );
        }

        final data = snapshot.data!;
        final rows = data.items.where((item) {
          final query = _searchController.text.toLowerCase();
          return query.isEmpty ||
              item.borrowerName.toLowerCase().contains(query) ||
              item.guarantorName.toLowerCase().contains(query);
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'Analyse & Risques',
                subtitle:
                    'Analyse des garanties, du risque et recalcul automatique des RW et RWA.',
              ),
              const SizedBox(height: AppTheme.pageGap),
              CrmScenarioBanner(highlight: data.highlight),
              const SizedBox(height: AppTheme.pageGap),
              SectionCard(
                title: 'Portefeuille CRM',
                child: Column(
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: context.tr('Rechercher...'),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing),
                    CrmTable(rows: rows),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.pageGap),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth >= 960
                      ? 190.0
                      : constraints.maxWidth >= 620
                          ? ((constraints.maxWidth - AppTheme.spacing) / 2)
                              .clamp(0.0, 190.0)
                              .toDouble()
                          : constraints.maxWidth;
                  return Wrap(
                    spacing: AppTheme.spacing,
                    runSpacing: AppTheme.spacing,
                    children: [
                      SizedBox(
                        width: width,
                        child: MetricCard(
                          label: 'RWA Avant',
                          value: data.summary.totalRwaBefore,
                          variation: 'Avant mitigation',
                          color: AppTheme.danger,
                          icon: Icons.warning_amber_rounded,
                          trend: const [82, 79, 76, 74, 72],
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: MetricCard(
                          label: 'RWA Apres',
                          value: data.summary.totalRwaAfter,
                          variation: 'Apres mitigation',
                          color: AppTheme.success,
                          icon: Icons.shield_outlined,
                          trend: const [72, 68, 66, 63, 60],
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: MetricCard(
                          label: 'Couverture CRM',
                          value: data.summary.averageCoverage,
                          variation: 'Moyenne portefeuille',
                          color: AppTheme.accent,
                          icon: Icons.verified_user_outlined,
                          trend: const [0.12, 0.16, 0.19, 0.23, 0.27],
                          isPercent: true,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
