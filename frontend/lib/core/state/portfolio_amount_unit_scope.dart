import 'package:flutter/widgets.dart';

import '../utils/currency_conversion.dart';

class PortfolioAmountUnitScope
    extends InheritedNotifier<ValueNotifier<PortfolioAmountUnit>> {
  const PortfolioAmountUnitScope({
    super.key,
    required ValueNotifier<PortfolioAmountUnit> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ValueNotifier<PortfolioAmountUnit> listenableOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<PortfolioAmountUnitScope>();
    assert(scope != null,
        'PortfolioAmountUnitScope introuvable dans le widget tree.');
    return scope!.notifier!;
  }

  static PortfolioAmountUnit of(BuildContext context) {
    return listenableOf(context).value;
  }

  static PortfolioAmountUnit maybeOf(
    BuildContext context, {
    PortfolioAmountUnit fallback = PortfolioAmountUnit.billion,
  }) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<PortfolioAmountUnitScope>();
    return scope?.notifier?.value ?? fallback;
  }
}
