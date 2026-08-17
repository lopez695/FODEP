import 'package:flutter/widgets.dart';

import '../utils/currency_conversion.dart';

class PortfolioCurrencyScope extends InheritedNotifier<ValueNotifier<String>> {
  const PortfolioCurrencyScope({
    super.key,
    required ValueNotifier<String> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ValueNotifier<String> listenableOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<PortfolioCurrencyScope>();
    assert(scope != null,
        'PortfolioCurrencyScope introuvable dans le widget tree.');
    return scope!.notifier!;
  }

  static String of(BuildContext context) {
    return normalizeCurrencyCode(listenableOf(context).value);
  }

  static String maybeOf(BuildContext context, {String fallback = 'XOF'}) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<PortfolioCurrencyScope>();
    return normalizeCurrencyCode(scope?.notifier?.value ?? fallback);
  }
}
