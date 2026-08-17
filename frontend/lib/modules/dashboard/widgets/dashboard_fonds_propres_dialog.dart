import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/state/portfolio_currency_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../../dashboard/models/dashboard_models.dart';
import 'dashboard_design.dart';

/// Modal d'edition des fonds propres reglementaires.
class DashboardFondsPropresDialog extends StatefulWidget {
  const DashboardFondsPropresDialog({
    super.key,
    required this.api,
    required this.fondsPropres,
    required this.amountUnit,
    required this.currency,
  });

  final RwaApiService api;
  final FondsPropresDetail? fondsPropres;
  final PortfolioAmountUnit amountUnit;
  final String currency;

  /// Ouvre la modale et retourne `true` si une sauvegarde a ete effectuee.
  static Future<bool> show(
    BuildContext context,
    RwaApiService api,
    FondsPropresDetail? fondsPropres,
  ) async {
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context);
    final currency = PortfolioCurrencyScope.maybeOf(context);
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer'.tr(context),
      pageBuilder: (context, _, __) {
        return Align(
          alignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            child: DashboardFondsPropresDialog(
              api: api,
              fondsPropres: fondsPropres,
              amountUnit: amountUnit,
              currency: currency,
            ),
          ),
        );
      },
    );
    return result == true;
  }

  @override
  State<DashboardFondsPropresDialog> createState() =>
      _DashboardFondsPropresDialogState();
}

class _DashboardFondsPropresDialogState
    extends State<DashboardFondsPropresDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _capOrdinaireCtrl;
  late TextEditingController _reservesCtrl;
  late TextEditingController _reportCtrl;
  late TextEditingController _eligibleCtrl;
  late TextEditingController _deducCet1Ctrl;

  late TextEditingController _instAt1Ctrl;
  late TextEditingController _primesAt1Ctrl;
  late TextEditingController _deducAt1Ctrl;

  late TextEditingController _subordT2Ctrl;
  late TextEditingController _provGenT2Ctrl;
  late TextEditingController _deducT2Ctrl;

  bool _isLoading = false;
  late String _selectedCurrency;

  bool _initialized = false;
  @override
  void initState() {
    super.initState();
    _selectedCurrency = 'XOF';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final fp = widget.fondsPropres;

      _capOrdinaireCtrl = _ctrl(fp?.capitalOrdinaire);
      _reservesCtrl = _ctrl(fp?.reserves);
      _reportCtrl = _ctrl(fp?.resultatsReport);
      _eligibleCtrl = _ctrl(fp?.resultatEligible);
      _deducCet1Ctrl = _ctrl(fp?.deductionsPrudCet1);

      _instAt1Ctrl = _ctrl(fp?.instrumentsAt1);
      _primesAt1Ctrl = _ctrl(fp?.primesEmissionAt1);
      _deducAt1Ctrl = _ctrl(fp?.deductionsPrudAt1);

      _subordT2Ctrl = _ctrl(fp?.dettesSubordonneesT2);
      _provGenT2Ctrl = _ctrl(fp?.provisionsGeneralesT2);
      _deducT2Ctrl = _ctrl(fp?.deductionsPrudT2);

      // Listeners for live computations
      final controllers = [
        _capOrdinaireCtrl,
        _reservesCtrl,
        _reportCtrl,
        _eligibleCtrl,
        _deducCet1Ctrl,
        _instAt1Ctrl,
        _primesAt1Ctrl,
        _deducAt1Ctrl,
        _subordT2Ctrl,
        _provGenT2Ctrl,
        _deducT2Ctrl
      ];
      for (final ctrl in controllers) {
        ctrl.addListener(_onFieldChanged);
      }
      _initialized = true;
    }
  }

  void _onFieldChanged() {
    setState(() {});
  }

  double get cet1Val {
    final cap = _parse(_capOrdinaireCtrl.text);
    final res = _parse(_reservesCtrl.text);
    final rep = _parse(_reportCtrl.text);
    final elig = _parse(_eligibleCtrl.text);
    final ded = _parse(_deducCet1Ctrl.text);
    final val = cap + res + rep + elig - ded;
    return val < 0.0 ? 0.0 : val;
  }

  double get at1Val {
    final inst = _parse(_instAt1Ctrl.text);
    final pri = _parse(_primesAt1Ctrl.text);
    final ded = _parse(_deducAt1Ctrl.text);
    final val = inst + pri - ded;
    return val < 0.0 ? 0.0 : val;
  }

  double get tier2Val {
    final sub = _parse(_subordT2Ctrl.text);
    final prov = _parse(_provGenT2Ctrl.text);
    final ded = _parse(_deducT2Ctrl.text);
    final val = sub + prov - ded;
    return val < 0.0 ? 0.0 : val;
  }

  double get totalFpVal => cet1Val + at1Val + tier2Val;

  TextEditingController _ctrl(double? val) {
    if (val == null || val == 0.0) return TextEditingController(text: '');
    final formatted = _formatWithThousandSeparators(val);
    return TextEditingController(text: formatted);
  }

  String _formatWithThousandSeparators(double val) {
    String text = val.toStringAsFixed(3);
    while (text.contains('.') && (text.endsWith('0') || text.endsWith('.'))) {
      text = text.substring(0, text.length - 1);
    }

    final parts = text.split('.');
    String integerPart = parts[0];
    String? decimalPart = parts.length > 1 ? parts[1] : null;

    final buffer = StringBuffer();
    int count = 0;
    for (int i = integerPart.length - 1; i >= 0; i--) {
      buffer.write(integerPart[i]);
      count++;
      if (count == 3 && i > 0) {
        buffer.write(' ');
        count = 0;
      }
    }
    final reversedInteger = buffer.toString().split('').reversed.join('');

    if (decimalPart != null) {
      return '$reversedInteger,$decimalPart';
    }
    return reversedInteger;
  }

  double _parse(String text) {
    final cleaned = text.replaceAll(',', '.').replaceAll(RegExp(r'\s+'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  @override
  void dispose() {
    _capOrdinaireCtrl.dispose();
    _reservesCtrl.dispose();
    _reportCtrl.dispose();
    _eligibleCtrl.dispose();
    _deducCet1Ctrl.dispose();

    _instAt1Ctrl.dispose();
    _primesAt1Ctrl.dispose();
    _deducAt1Ctrl.dispose();

    _subordT2Ctrl.dispose();
    _provGenT2Ctrl.dispose();
    _deducT2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final update = FondsPropresUpdate(
        capitalOrdinaire: _parse(_capOrdinaireCtrl.text),
        reserves: _parse(_reservesCtrl.text),
        resultatsReport: _parse(_reportCtrl.text),
        resultatEligible: _parse(_eligibleCtrl.text),
        deductionsPrudCet1: _parse(_deducCet1Ctrl.text),
        instrumentsAt1: _parse(_instAt1Ctrl.text),
        primesEmissionAt1: _parse(_primesAt1Ctrl.text),
        deductionsPrudAt1: _parse(_deducAt1Ctrl.text),
        dettesSubordonneesT2: _parse(_subordT2Ctrl.text),
        provisionsGeneralesT2: _parse(_provGenT2Ctrl.text),
        deductionsPrudT2: _parse(_deducT2Ctrl.text),
      );

      await widget.api.updateFondsPropres(update);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Erreur lors de la sauvegarde : {{error}}', args: {'error': e})),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 1200
        ? 1080.0
        : (screenWidth > 1000
            ? 960.0
            : (screenWidth > 800 ? 780.0 : screenWidth * 0.95));

    return Container(
      width: dialogWidth,
      constraints: const BoxConstraints(maxHeight: 800),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Modifier les Fonds Propres'.tr(context),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(false),
                color: c.muted,
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Devise de saisie :'.tr(context),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.muted,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'FCFA (XOF)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildColumn(
                        c,
                        isDark,
                        'CET1',
                        'Fonds propres de base de catégorie 1',
                        const Color(0xFF1E40AF),
                        [
                          _buildField(
                              'Capital ordinaire', _capOrdinaireCtrl, isDark),
                          _buildField('Réserves', _reservesCtrl, isDark),
                          _buildField(
                              'Résultats en report', _reportCtrl, isDark),
                          _buildField(
                              'Résultat éligible', _eligibleCtrl, isDark),
                          _buildField(
                              'Réduction prudentielle', _deducCet1Ctrl, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildColumn(
                        c,
                        isDark,
                        'AT1',
                        'Fonds propres additionnels de catégorie 1',
                        const Color(0xFF1E3A8A),
                        [
                          _buildField(
                              'Instruments additionnels', _instAt1Ctrl, isDark),
                          _buildField(
                              'Primes d\'émission', _primesAt1Ctrl, isDark),
                          _buildField(
                              'Réduction prudentielle', _deducAt1Ctrl, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildColumn(
                        c,
                        isDark,
                        'Tier 2',
                        'Fonds propres complémentaires',
                        const Color(0xFF475569),
                        [
                          _buildField(
                              'Dettes subordonnées', _subordT2Ctrl, isDark),
                          _buildField(
                              'Provisions générales', _provGenT2Ctrl, isDark),
                          _buildField(
                              'Réduction prudentielle', _deducT2Ctrl, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Dynamic calculation summary banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem('Total CET1', cet1Val, widget.amountUnit,
                    _selectedCurrency, const Color(0xFF1E40AF), isDark),
                _buildSummaryItem('Total AT1', at1Val, widget.amountUnit,
                    _selectedCurrency, const Color(0xFF1E3A8A), isDark),
                _buildSummaryItem('Total Tier 2', tier2Val, widget.amountUnit,
                    _selectedCurrency, const Color(0xFF475569), isDark),
                Container(width: 1, height: 28, color: c.divider),
                _buildSummaryItem(
                  'Fonds Propres Globaux',
                  totalFpVal,
                  widget.amountUnit,
                  _selectedCurrency,
                  const Color(0xFF10B981),
                  isDark,
                  isTotal: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed:
                    _isLoading ? null : () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: c.ink,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                child: Text('Annuler'.tr(context)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sidebar,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Enregistrer'.tr(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double val, PortfolioAmountUnit unit,
      String currency, Color color, bool isDark,
      {bool isTotal = false}) {
    final textVal = AppFormatters.usefulDecimalNumber(val / unit.divisor);
    final suffixStr = AppFormatters.formatAmountSuffix(val, unit.label);
    final valueColor = isTotal
        ? color
        : (isDark ? const Color(0xFFF2F6FF) : const Color(0xFF1E293B));
    final labelColor = isTotal
        ? color
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.tr(context).toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              textVal.isEmpty ? '0' : textVal,
              style: TextStyle(
                fontSize: isTotal ? 15 : 13,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              suffixStr,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColumn(DashColors c, bool isDark, String title, String subtitle,
      Color borderC, List<Widget> fields) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            color: borderC,
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.tr(context),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle.tr(context),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              thickness: 0.5,
              color:
                  isDark ? const Color(0x1F94A3B8) : const Color(0x1F64748B)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: fields,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x1F94A3B8) : const Color(0x1F64748B),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 6,
            child: Text(
              label.tr(context),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 7,
            child: SizedBox(
              height: 32,
              child: TextFormField(
                controller: ctrl,
                textAlign: TextAlign.right,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
                ],
                style: TextStyle(
                  fontSize: 12.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  hintText: '0',
                  suffixText: ' FCFA',
                  suffixStyle: TextStyle(
                    color: isDark
                        ? const Color(0xFF475569)
                        : const Color(0xFF94A3B8),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                  hintStyle: TextStyle(
                    color: isDark
                        ? const Color(0xFF475569)
                        : const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:
                        const BorderSide(color: AppColors.sidebar, width: 1.2),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
