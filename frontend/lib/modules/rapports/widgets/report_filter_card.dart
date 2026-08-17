// Ce fichier affiche le panneau de generation des rapports.
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/section_card.dart';
import '../models/report_models.dart';

/// Formulaire de filtres pour générer un rapport.
class ReportFilterCard extends StatefulWidget {
  const ReportFilterCard({
    super.key,
    required this.onGenerate,
  });

  final Future<void> Function(ReportDraft draft) onGenerate;

  @override
  State<ReportFilterCard> createState() => _ReportFilterCardState();
}

/// Etat interne du formulaire de filtres de rapport.
class _ReportFilterCardState extends State<ReportFilterCard> {
  String _period = 'Mars 2026';
  String _reportType = 'Synthese';
  String _currency = 'EUR';
  String _scope = 'Toutes';
  bool _includeCategoryChart = true;
  bool _includeRatingChart = true;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Parametres du Rapport',
      child: Column(
        children: [
          Wrap(
            spacing: AppTheme.spacing,
            runSpacing: AppTheme.spacing,
            children: [
              _buildDropdown(
                label: 'Periode',
                value: _period,
                values: const ['Mars 2026', 'Avril 2026', 'T1 2026'],
                onChanged: (value) => setState(() => _period = value),
              ),
              _buildDropdown(
                label: 'Type de Rapport',
                value: _reportType,
                values: const ['Synthese', 'Detaille'],
                onChanged: (value) => setState(() => _reportType = value),
              ),
              _buildDropdown(
                label: 'Monnaie',
                value: _currency,
                values: const ['EUR', 'USD', 'XOF'],
                onChanged: (value) => setState(() => _currency = value),
              ),
              _buildDropdown(
                label: 'Expositions',
                value: _scope,
                values: const [
                  'Toutes',
                  'Entreprises',
                  'Banques',
                  'Souverains'
                ],
                onChanged: (value) => setState(() => _scope = value),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing),
          CheckboxListTile(
            dense: true,
            value: _includeCategoryChart,
            onChanged: (value) => setState(
                () => _includeCategoryChart = value ?? _includeCategoryChart),
            title: const Text('Inclure graphique de repartition par categorie'),
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            dense: true,
            value: _includeRatingChart,
            onChanged: (value) => setState(
                () => _includeRatingChart = value ?? _includeRatingChart),
            title: const Text('Inclure graphique de repartition par notation'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('Generer Rapport'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: values
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (newValue) {
          if (newValue != null) {
            onChanged(newValue);
          }
        },
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await widget.onGenerate(
        ReportDraft(
          period: _period,
          reportType: _reportType,
          currency: _currency,
          exposureScope: _scope,
          includeCategoryChart: _includeCategoryChart,
          includeRatingChart: _includeRatingChart,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
