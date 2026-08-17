// Ce fichier affiche le module hors bilan.
import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';
import '../models/hors_bilan_models.dart';
import '../widgets/off_balance_form_card.dart';
import '../widgets/off_balance_table.dart';

/// Ecran de pilotage des engagements hors bilan.
class HorsBilanScreen extends StatefulWidget {
  const HorsBilanScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<HorsBilanScreen> createState() => _HorsBilanScreenState();
}

/// Etat interne de l'écran hors bilan et de ses filtres.
class _HorsBilanScreenState extends State<HorsBilanScreen> {
  late Future<OffBalanceModuleData> _future;
  final TextEditingController _searchController = TextEditingController();
  String _selectedType = 'Tous';

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchHorsBilanModule();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OffBalanceModuleData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final data = snapshot.data!;
        final items = data.items.where((item) {
          final matchesSearch = _searchController.text.isEmpty ||
              item.id
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase()) ||
              item.counterpartyName
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase());
          final matchesType =
              _selectedType == 'Tous' || item.engagementType == _selectedType;
          return matchesSearch && matchesType;
        }).toList();
        final options = {
          for (final item in data.items)
            item.counterpartyId: item.counterpartyName,
        };

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'Hors Bilan',
                subtitle:
                    'Gestion des engagements hors bilan avec application des CCF et calcul des RWA.',
              ),
              const SizedBox(height: AppTheme.pageGap),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1120;
                  final form = SizedBox(
                    width: isWide ? 320 : double.infinity,
                    child: OffBalanceFormCard(
                      counterpartyOptions: options,
                      onSubmit: _handleCreate,
                    ),
                  );
                  final tableSection = Column(
                    children: [
                      SectionCard(
                        title: 'Portefeuille hors bilan',
                        child: Column(
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                SizedBox(
                                  width: 260,
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.search),
                                      hintText: 'Rechercher...',
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 180,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedType,
                                    isExpanded: true,
                                    menuMaxHeight: 320,
                                    items: [
                                      'Tous',
                                      ...data.items
                                          .map((item) => item.engagementType)
                                          .toSet()
                                    ]
                                        .map((item) => DropdownMenuItem(
                                            value: item, child: Text(item)))
                                        .toList(),
                                    onChanged: (value) => setState(
                                        () => _selectedType = value ?? 'Tous'),
                                    decoration: const InputDecoration(
                                        labelText: 'Type'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.pageGap),
                            OffBalanceTable(rows: items),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing),
                      LayoutBuilder(
                        builder: (context, inner) {
                          final width = inner.maxWidth >= 960
                              ? 190.0
                              : inner.maxWidth >= 620
                                  ? ((inner.maxWidth - AppTheme.spacing) / 2)
                                      .clamp(0.0, 190.0)
                                      .toDouble()
                                  : inner.maxWidth;
                          return Wrap(
                            spacing: AppTheme.spacing,
                            runSpacing: AppTheme.spacing,
                            children: [
                              SizedBox(
                                width: width,
                                child: MetricCard(
                                  label: 'Total Engagements HB',
                                  value: data.summary.totalEngagements,
                                  variation: 'Nominal consolide',
                                  color: AppTheme.sidebarLight,
                                  icon: Icons.account_balance_wallet_outlined,
                                  trend: const [32, 38, 40, 44, 50],
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: MetricCard(
                                  label: 'Total EAD HB',
                                  value: data.summary.totalEad,
                                  variation: 'Apres CCF',
                                  color: AppTheme.warning,
                                  icon: Icons.track_changes_outlined,
                                  trend: const [18, 21, 24, 27, 30],
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: MetricCard(
                                  label: 'Capital HB',
                                  value: data.summary.totalCapital,
                                  variation: 'Ratio 9%',
                                  color: AppTheme.success,
                                  icon: Icons.account_balance_outlined,
                                  trend: const [0.42, 0.56, 0.61, 0.72, 0.83],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  );

                  return isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            form,
                            const SizedBox(width: AppTheme.spacing),
                            Expanded(child: tableSection),
                          ],
                        )
                      : Column(
                          children: [
                            form,
                            const SizedBox(height: AppTheme.spacing),
                            SizedBox(
                                width: double.infinity, child: tableSection),
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

  Future<void> _handleCreate(OffBalanceDraft draft) async {
    try {
      await widget.api.createOffBalance(draft);
      if (!mounted) {
        return;
      }
      setState(() => _future = widget.api.fetchHorsBilanModule());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Engagement hors bilan ajoute.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('Échec de l\'enregistrement : $error'),
        ),
      );
    }
  }
}
