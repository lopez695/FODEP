import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/page_header.dart';
import '../../risque_credit_shared/models/credit_risk_models.dart';
import '../../risque_credit_shared/services/credit_risk_submodules_service.dart';
import '../../risque_credit_shared/widgets/credit_data_table_card.dart';
import '../../risque_credit_shared/widgets/credit_module_toolbar.dart';
import '../../risque_credit_shared/widgets/credit_stat_card.dart';

class DefautsImpayesScreen extends StatefulWidget {
  const DefautsImpayesScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<DefautsImpayesScreen> createState() => _DefautsImpayesScreenState();
}

class _DefautsImpayesScreenState extends State<DefautsImpayesScreen> {
  late final CreditRiskSubmodulesService _service;
  late Future<DefaultsModuleData> _future;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<int>? _portfolioSubscription;

  String _selectedStatus = 'Tous';
  String _selectedSector = 'Tous';

  @override
  void initState() {
    super.initState();
    _service = CreditRiskSubmodulesService(widget.api);
    _future = _service.fetchDefaultsModule();
    _portfolioSubscription = widget.api.portfolioRefreshStream.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() => _future = _service.fetchDefaultsModule());
    });
  }

  @override
  void dispose() {
    _portfolioSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DefaultsModuleData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final data = snapshot.data!;
        final sectors = [
          'Tous',
          ...data.items.map((item) => item.sector).toSet(),
        ];
        final statuses = [
          'Tous',
          ...data.items.map((item) => item.prudentialStatus).toSet(),
        ];

        final filtered = data.items.where((item) {
          final query = _searchController.text.trim().toLowerCase();
          final matchesSearch = query.isEmpty ||
              item.exposureId.toLowerCase().contains(query) ||
              item.counterpartyName.toLowerCase().contains(query) ||
              item.country.toLowerCase().contains(query);
          final matchesStatus = _selectedStatus == 'Tous' ||
              item.prudentialStatus == _selectedStatus;
          final matchesSector =
              _selectedSector == 'Tous' || item.sector == _selectedSector;
          return matchesSearch && matchesStatus && matchesSector;
        }).toList(growable: false);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'Défauts / Impayés',
                subtitle:
                    'Surveillance des retards, défauts prudentiels et provisions estimées à partir du portefeuille existant.',
              ),
              const SizedBox(height: AppTheme.pageGap),
              _buildStatGrid(data),
              const SizedBox(height: AppTheme.pageGap),
              CreditDataTableCard(
                title: 'Expositions en surveillance',
                toolbar: CreditModuleToolbar(
                  searchController: _searchController,
                  searchHint:
                      'Rechercher une exposition, une contrepartie ou un pays',
                  onSearchChanged: (_) => setState(() {}),
                  filters: [
                    _buildDropdown(
                      label: 'Statut prudentiel',
                      value: _selectedStatus,
                      values: statuses,
                      onChanged: (value) =>
                          setState(() => _selectedStatus = value),
                    ),
                    _buildDropdown(
                      label: 'Secteur',
                      value: _selectedSector,
                      values: sectors,
                      onChanged: (value) =>
                          setState(() => _selectedSector = value),
                    ),
                  ],
                ),
                columns: const [
                  DataColumn(label: Text('Exposition')),
                  DataColumn(label: Text('Contrepartie')),
                  DataColumn(label: Text('Retard')),
                  DataColumn(label: Text('Statut prudentiel')),
                  DataColumn(label: Text('Provision estimée')),
                  DataColumn(label: Text('Incidents')),
                ],
                rows: filtered
                    .map(
                      (item) => DataRow(
                        cells: [
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.exposureId),
                                Text(
                                  item.sector,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppTheme.muted),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.counterpartyName),
                                Text(
                                  '${item.country} • ${item.rating}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppTheme.muted),
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text('${item.daysPastDue} j')),
                          DataCell(
                              _PrudentialBadge(label: item.prudentialStatus)),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(formatCurrencyForDisplay(
                                  item.estimatedProvision,
                                  toCurrency: 'XOF',
                                )),
                                Text(
                                  AppFormatters.percent(item.provisionRate),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppTheme.muted),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            TextButton.icon(
                              onPressed: () => _showIncidentHistory(item),
                              icon: const Icon(Icons.history_rounded, size: 16),
                              label:
                                  Text('${item.incidents.length} évènement(s)'),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatGrid(DefaultsModuleData data) {
    final stats = [
      CreditStatCard(
        label: 'Expositions suivies',
        value: data.summary.totalDefaults.toString(),
        helper: 'Portefeuille en défaut ou retard',
        icon: Icons.warning_amber_rounded,
        color: AppTheme.warning,
        lottieAsset: 'assets/lotties/rwa_dashboard.json',
      ),
      CreditStatCard(
        label: 'Encours surveillé',
        value: formatCurrencyForDisplay(
          data.summary.totalDefaultGross,
          toCurrency: 'XOF',
        ),
        helper: 'Montant brut exposé',
        icon: Icons.account_balance_wallet_outlined,
        color: AppTheme.sidebarLight,
      ),
      CreditStatCard(
        label: 'Provision estimée',
        value: formatCurrencyForDisplay(
          data.summary.totalProvision,
          toCurrency: 'XOF',
        ),
        helper: 'Lecture prudentielle',
        icon: Icons.savings_outlined,
        color: AppTheme.danger,
      ),
      CreditStatCard(
        label: 'Retard moyen',
        value: '${data.summary.averageDaysPastDue.toStringAsFixed(0)} j',
        helper: 'Délai moyen observé',
        icon: Icons.schedule_rounded,
        color: AppTheme.accent,
      ),
    ];

    return LayoutBuilder(
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
            for (final stat in stats)
              SizedBox(
                width: width,
                child: stat,
              ),
          ],
        );
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: values
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(growable: false),
        selectedItemBuilder: (context) => values
            .map(
              (item) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(growable: false),
        onChanged: (newValue) {
          if (newValue != null) {
            onChanged(newValue);
          }
        },
      ),
    );
  }

  Future<void> _showIncidentHistory(CreditDefaultRecord record) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Historique des incidents - ${record.exposureId}'),
        content: SizedBox(
          width: 540,
          child: ListView.separated(addSemanticIndexes: false,
            shrinkWrap: true,
            itemCount: record.incidents.length,
            separatorBuilder: (_, __) => const Divider(height: 20),
            itemBuilder: (context, index) {
              final incident = record.incidents[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    incident.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppFormatters.shortDate(incident.date),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(incident.description),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

class _PrudentialBadge extends StatelessWidget {
  const _PrudentialBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'Defaut prudentiel' => AppTheme.danger,
      'Sous surveillance renforcee' => AppTheme.warning,
      'Surveillance' => AppTheme.accent,
      _ => AppTheme.muted,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}
