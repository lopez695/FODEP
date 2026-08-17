import 'package:flutter/widgets.dart';

import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/formatters.dart';

/// Formate un montant FCFA avec l'unité globale sélectionnée dans l'en-tête
/// (# / M / Md) - même écriture compacte que les onglets Dashboard, CRR3 et
/// Registre des pertes du module Risque Opérationnel.
String roAmount(BuildContext context, double value) {
  final unit = PortfolioAmountUnitScope.maybeOf(context);
  final sign = value < 0 ? '-' : '';
  final scaled = value.abs() / unit.divisor;
  return '$sign${AppFormatters.compactNumber(scaled)}${unit.label}';
}
