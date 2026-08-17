import 'package:flutter/material.dart';

import '../../../shared/widgets/kpi_metric_card.dart';

class CreditStatCard extends StatelessWidget {
  const CreditStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.color,
    this.lottieAsset,
  });

  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color color;
  final String? lottieAsset;

  @override
  Widget build(BuildContext context) {
    return KpiMetricCard(
      label: label,
      value: value,
      helper: helper,
      icon: icon,
      color: color,
      fullValue: value,
    );
  }
}
