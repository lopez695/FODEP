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
import '../widgets/garantie_form_dialog.dart';

class GarantiesScreen extends StatefulWidget {
  const GarantiesScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<GarantiesScreen> createState() => _GarantiesScreenState();
}

class _GarantiesScreenState extends State<GarantiesScreen> {
  late final CreditRiskSubmodulesService _service;
  late Future<GuaranteesModuleData> _future;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<int>? _portfolioSubscription;

  String _selectedStatus = 'Tous';
  String _selectedType = 'Tous';

  @override
  void initState() {
    super.initState();
    _service = CreditRiskSubmodulesService(widget.api);
    _future = _service.fetchGuaranteesModule();
    _portfolioSubscription = widget.api.portfolioRefreshStream.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() => _future = _service.fetchGuaranteesModule());
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
    return FutureBuilder<GuaranteesModuleData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final data = snapshot.data!;
        final typeOptions = [
          'Tous',
          ...data.guarantees.map((item) => item.type).toSet(),
        ];
        final statusOptions = [
          'Tous',
          ...data.guarantees.map((item) => item.status).toSet(),
        ];

        final filtered = data.guarantees.where((item) {
          final query = _searchController.text.trim().toLowerCase();
          final matchesSearch = query.isEmpty ||
              item.id.toLowerCase().contains(query) ||
              item.exposureLabel.toLowerCase().contains(query) ||
              item.counterpartyName.toLowerCase().contains(query) ||
              item.type.toLowerCase().contains(query);
          final matchesStatus =
              _selectedStatus == 'Tous' || item.status == _selectedStatus;
          final matchesType =
              _selectedType == 'Tous' || item.type == _selectedType;
          return matchesSearch && matchesStatus && matchesType;
        }).toList(growable: false);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'Garanties',
                subtitle:
                    'Pilotage opérationnel des garanties liées aux expositions, sans recréer la logique CRM/RWA déjà utilisée dans Expositions.',
              ),
              const SizedBox(height: AppTheme.pageGap),
              _buildStatGrid(data),
              const SizedBox(height: AppTheme.pageGap),
              CreditDataTableCard(
                title: 'Registre des garanties',
                toolbar: CreditModuleToolbar(
                  searchController: _searchController,
                  searchHint:
                      'Rechercher une garantie, une exposition ou une contrepartie',
                  onSearchChanged: (_) => setState(() {}),
                  filters: [
                    _buildDropdown(
                      label: 'Statut',
                      value: _selectedStatus,
                      values: statusOptions,
                      onChanged: (value) =>
                          setState(() => _selectedStatus = value),
                    ),
                    _buildDropdown(
                      label: 'Type',
                      value: _selectedType,
                      values: typeOptions,
                      onChanged: (value) =>
                          setState(() => _selectedType = value),
                    ),
                  ],
                  actions: [
                    FilledButton.icon(
                      onPressed: data.exposureOptions.isEmpty
                          ? null
                          : () => _openGuaranteeDialog(data),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nouvelle garantie'),
                    ),
                  ],
                ),
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Exposition')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Valeur')),
                  DataColumn(label: Text('Couverture')),
                  DataColumn(label: Text('Expiration')),
                  DataColumn(label: Text('Statut')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: filtered
                    .map(
                      (item) => DataRow(
                        cells: [
                          DataCell(Text(item.id)),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.exposureLabel,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  item.counterpartyName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppTheme.muted),
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text(item.type)),
                          DataCell(Text(formatCurrencyForDisplay(
                            item.value,
                            toCurrency: 'XOF',
                          ))),
                          DataCell(
                            Text(AppFormatters.percent(item.coverageRatio)),
                          ),
                          DataCell(Text(
                              AppFormatters.shortDate(item.expirationDate))),
                          DataCell(_StatusBadge(label: item.status)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Modifier',
                                  onPressed: () => _openGuaranteeDialog(
                                    data,
                                    initial: item,
                                  ),
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 18),
                                ),
                                IconButton(
                                  tooltip: 'Supprimer',
                                  onPressed: () => _deleteGuarantee(item),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: AppTheme.danger,
                                  ),
                                ),
                              ],
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

  Widget _buildStatGrid(GuaranteesModuleData data) {
    final stats = [
      CreditStatCard(
        label: 'Garanties suivies',
        value: data.summary.totalGuarantees.toString(),
        helper: 'Registre consolidé',
        icon: Icons.inventory_2_outlined,
        color: AppTheme.sidebarLight,
        lottieAsset: 'assets/lotties/rwa_dashboard.json',
      ),
      CreditStatCard(
        label: 'Valeur active',
        value: formatCurrencyForDisplay(
          data.summary.activeValue,
          toCurrency: 'XOF',
        ),
        helper: 'Garanties non expirées',
        icon: Icons.verified_user_outlined,
        color: AppTheme.success,
      ),
      CreditStatCard(
        label: 'Couverture moyenne',
        value: AppFormatters.percent(data.summary.averageCoverage),
        helper: 'Couverture CRM observée',
        icon: Icons.shield_outlined,
        color: AppTheme.accent,
      ),
      CreditStatCard(
        label: 'À renouveler',
        value: data.summary.expiringSoonCount.toString(),
        helper: 'Échéance sous 90 jours',
        icon: Icons.event_busy_outlined,
        color: AppTheme.warning,
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
      width: 190,
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

  Future<void> _openGuaranteeDialog(
    GuaranteesModuleData data, {
    CreditGuaranteeRecord? initial,
  }) async {
    final draft = await showDialog<CreditGuaranteeDraft>(
      context: context,
      builder: (_) => GarantieFormDialog(
        exposureOptions: data.exposureOptions,
        initialValue: initial,
      ),
    );
    if (draft == null) {
      return;
    }

    try {
      await _service.upsertGuarantee(draft);
      if (!mounted) {
        return;
      }
      setState(() => _future = _service.fetchGuaranteesModule());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.success,
          content: Text(
            initial == null
                ? 'Garantie ajoutée avec succès.'
                : 'Garantie mise à jour avec succès.',
          ),
        ),
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

  Future<void> _deleteGuarantee(CreditGuaranteeRecord record) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Supprimer la garantie'),
            content: Text(
              'Confirmer la suppression de la garantie ${record.id} liée à ${record.counterpartyName} ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    try {
      await _service.deleteGuarantee(record.id);
      if (!mounted) {
        return;
      }
      setState(() => _future = _service.fetchGuaranteesModule());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.success,
          content: Text('Garantie supprimée.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('Échec de la suppression : $error'),
        ),
      );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'Active' => AppTheme.success,
      'A renouveler' => AppTheme.warning,
      'Expiree' => AppTheme.danger,
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
