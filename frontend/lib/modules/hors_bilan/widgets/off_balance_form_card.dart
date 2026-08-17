// Ce fichier affiche le formulaire du module hors bilan.
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/section_card.dart';
import '../models/hors_bilan_models.dart';

/// Formulaire de saisie des engagements hors bilan.
class OffBalanceFormCard extends StatefulWidget {
  const OffBalanceFormCard({
    super.key,
    required this.counterpartyOptions,
    required this.onSubmit,
  });

  final Map<String, String> counterpartyOptions;
  final Future<void> Function(OffBalanceDraft draft) onSubmit;

  @override
  State<OffBalanceFormCard> createState() => _OffBalanceFormCardState();
}

/// Etat interne du formulaire hors bilan.
class _OffBalanceFormCardState extends State<OffBalanceFormCard> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text: '5000000');
  final _commentController = TextEditingController();
  late String _counterpartyId;
  String _engagementType = 'Credit documentaire';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _counterpartyId = widget.counterpartyOptions.isEmpty
        ? ''
        : widget.counterpartyOptions.keys.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Ajouter Engagement Hors Bilan',
      child: widget.counterpartyOptions.isEmpty
          ? const Text(
              'Aucune contrepartie disponible pour la saisie hors bilan.')
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _counterpartyId,
                    isExpanded: true,
                    menuMaxHeight: 320,
                    decoration:
                        const InputDecoration(labelText: 'Contrepartie'),
                    items: widget.counterpartyOptions.entries
                        .map((entry) => DropdownMenuItem(
                            value: entry.key, child: Text(entry.value)))
                        .toList(),
                    onChanged: (value) => setState(
                        () => _counterpartyId = value ?? _counterpartyId),
                  ),
                  const SizedBox(height: AppTheme.spacing),
                  DropdownButtonFormField<String>(
                    initialValue: _engagementType,
                    isExpanded: true,
                    menuMaxHeight: 320,
                    decoration: const InputDecoration(
                        labelText: 'Nature d\'engagement'),
                    items: const [
                      'Credit documentaire',
                      'Lignes de credit',
                      'Instruments financiers',
                      'Garanties financieres',
                      'Engagement de garantie',
                    ]
                        .map((item) =>
                            DropdownMenuItem(value: item, child: Text(item)))
                        .toList(),
                    onChanged: (value) => setState(
                        () => _engagementType = value ?? _engagementType),
                  ),
                  const SizedBox(height: AppTheme.spacing),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Montant nominal'),
                    validator: (value) => double.tryParse(value ?? '') == null
                        ? 'Montant invalide'
                        : null,
                  ),
                  const SizedBox(height: AppTheme.spacing),
                  TextFormField(
                    controller: _commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Commentaire'),
                  ),
                  const SizedBox(height: AppTheme.spacing),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter Engagement HB'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        OffBalanceDraft(
          counterpartyId: _counterpartyId,
          engagementType: _engagementType,
          nominalAmount: double.parse(_amountController.text.trim()),
          comment: _commentController.text.trim(),
          analysisDate: DateTime.now(),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
