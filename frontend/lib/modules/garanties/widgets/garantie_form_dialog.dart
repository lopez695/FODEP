import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../risque_credit_shared/models/credit_risk_models.dart';

class GarantieFormDialog extends StatefulWidget {
  const GarantieFormDialog({
    super.key,
    required this.exposureOptions,
    this.initialValue,
  });

  final List<CreditExposureOption> exposureOptions;
  final CreditGuaranteeRecord? initialValue;

  @override
  State<GarantieFormDialog> createState() => _GarantieFormDialogState();
}

class _GarantieFormDialogState extends State<GarantieFormDialog> {
  static const List<String> _guaranteeTypes = [
    'Garantie bancaire',
    'Garantie etatique',
    'Assurance credit',
    'Cash collateral',
    'Nantissement titres',
    'Hypotheque',
  ];

  static const List<String> _statuses = [
    'Active',
    'A renouveler',
    'Expiree',
    'Liberee',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _valueController;
  late final TextEditingController _coverageController;
  late String _selectedExposureId;
  late String _selectedType;
  late String _selectedStatus;
  late DateTime _expirationDate;

  bool get _isEditing => widget.initialValue != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    _selectedExposureId = initial?.exposureId ??
        (widget.exposureOptions.isEmpty ? '' : widget.exposureOptions.first.id);
    _selectedType = initial?.type ?? _guaranteeTypes.first;
    _selectedStatus = initial?.status ?? _statuses.first;
    _expirationDate = initial?.expirationDate ??
        DateTime.now().add(const Duration(days: 365));
    _valueController = TextEditingController(
      text: initial == null ? '' : initial.value.toStringAsFixed(0),
    );
    _coverageController = TextEditingController(
      text: initial == null
          ? '50'
          : (initial.coverageRatio * 100).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    _coverageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Modifier une garantie' : 'Nouvelle garantie'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue:
                      _selectedExposureId.isEmpty ? null : _selectedExposureId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Exposition liee',
                  ),
                  items: widget.exposureOptions
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(item.label),
                        ),
                      )
                      .toList(growable: false),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Champ requis' : null,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _selectedExposureId = value);
                  },
                ),
                const SizedBox(height: AppTheme.spacing),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: _guaranteeTypes
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: AppTheme.spacing),
                TextFormField(
                  controller: _valueController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valeur',
                    prefixText: 'FCFA ',
                  ),
                  validator: (value) {
                    final parsed = double.tryParse((value ?? '').trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Valeur invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacing),
                TextFormField(
                  controller: _coverageController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Couverture (%)',
                    suffixText: '%',
                  ),
                  validator: (value) {
                    final parsed = double.tryParse((value ?? '').trim());
                    if (parsed == null || parsed < 0 || parsed > 100) {
                      return 'Pourcentage invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacing),
                InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  onTap: _pickExpirationDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date d expiration',
                      suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                    ),
                    child: Text(
                      '${_expirationDate.day.toString().padLeft(2, '0')}/${_expirationDate.month.toString().padLeft(2, '0')}/${_expirationDate.year}',
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(labelText: 'Statut'),
                  items: _statuses
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedStatus = value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: Icon(_isEditing ? Icons.save_outlined : Icons.add_rounded),
          label: Text(_isEditing ? 'Enregistrer' : 'Ajouter'),
        ),
      ],
    );
  }

  Future<void> _pickExpirationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2045),
    );
    if (picked != null) {
      setState(() => _expirationDate = picked);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(
      CreditGuaranteeDraft(
        id: widget.initialValue?.id,
        exposureId: _selectedExposureId,
        type: _selectedType,
        value: double.parse(_valueController.text.trim()),
        currency: 'XOF',
        coverageRatio: double.parse(_coverageController.text.trim()) / 100,
        expirationDate: _expirationDate,
        status: _selectedStatus,
      ),
    );
  }
}
