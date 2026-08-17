import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'dashboard_design.dart';

class DashboardGrandsRisquesSummary extends StatelessWidget {
  const DashboardGrandsRisquesSummary({
    super.key,
    required this.exposures,
    required this.currency,
  });

  final List<TopExposure> exposures;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    // Calculs de synthèse
    final totalRisques = exposures.length;
    final totalNet = exposures.fold<double>(0.0, (sum, e) => sum + e.netExposure);
    // Classification par statut
    final alertes = exposures.where((e) => e.status == 'Dépassement').length;
    final conformes = exposures.where((e) => e.status == 'Dans la norme').length;
    // Indicateurs de concentration (fpRatio exprimé en % des fonds propres)
    final maxRatio = exposures.fold<double>(0.0, (max, e) => e.fpRatio > max ? e.fpRatio : max);
    final avgRatio = totalRisques == 0 ? 0.0 : exposures.fold<double>(0.0, (sum, e) => sum + e.fpRatio) / totalRisques;
    final tauxConformite = totalRisques == 0 ? null : conformes / totalRisques * 100;

    return DashPanel(
      title: 'SYNTHÈSE DES GRANDS RISQUES'.tr(context),
      subtitle: 'Expositions individuelles rapportées aux fonds propres effectifs'.tr(context),
      height: 500,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gros indicateurs
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _KpiTile(
                  label: 'Total grands risques'.tr(context),
                  value: totalRisques.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: _KpiTile(
                  label: 'Risque Net Total'.tr(context),
                  value: AppFormatters.formatAmountValue(totalNet),
                  suffix: AppFormatters.formatAmountSuffix(totalNet),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionLabel('CLASSIFICATION PRUDENTIELLE'.tr(context)),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatusCard(
                    count: conformes,
                    label: 'Dans la norme'.tr(context),
                    threshold: '< 25 % des FP'.tr(context),
                    color: c.conforme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatusCard(
                    count: alertes,
                    label: 'Dépassement'.tr(context),
                    threshold: '> 25 % des FP'.tr(context),
                    color: c.sousMinimum,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionLabel('INDICATEURS DE SUIVI'.tr(context)),
          const SizedBox(height: 4),
          _IndicatorRow(
            label: 'Concentration maximale'.tr(context),
            value: totalRisques == 0 ? '-' : '${maxRatio.toStringAsFixed(1)} %',
            valueColor: maxRatio > 25
                ? c.sousMinimum
                : maxRatio >= 20
                    ? c.sousCible
                    : c.ink,
          ),
          _IndicatorRow(
            label: 'Concentration moyenne'.tr(context),
            value: totalRisques == 0 ? '-' : '${avgRatio.toStringAsFixed(1)} %',
          ),
          _IndicatorRow(
            label: 'Taux de conformité'.tr(context),
            value: tauxConformite == null ? '-' : '${tauxConformite.toStringAsFixed(0)} %',
            valueColor: tauxConformite == null
                ? null
                : tauxConformite >= 100
                    ? c.conforme
                    : c.sousMinimum,
            last: true,
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: Dash.hairline, color: c.divider),
          const SizedBox(height: 10),
          Text(
            'Limite individuelle : 25 % des fonds propres effectifs'.tr(context),
            style: DashText.caption(c),
          ),
        ],
      ),
    );
  }
}

/// Tuile KPI plate : filet fin, fond alterné, chiffre-héros tabulaire.
class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    this.suffix,
  });

  final String label;
  final String value;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Dash.radius),
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: DashText.caption(c, color: c.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value, style: DashText.hero(c, size: 24)),
                if (suffix != null)
                  TextSpan(
                    text: suffix,
                    style: DashText.caption(c, color: c.muted),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Carte de statut prudentiel : filet supérieur coloré, compte centré.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.count,
    required this.label,
    required this.threshold,
    required this.color,
  });

  final int count;
  final String label;
  final String threshold;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Dash.radius),
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 2, color: color),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$count', style: DashText.hero(c, size: 28, color: color)),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(threshold, style: DashText.caption(c)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sur-titre de section interne au panneau.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Text(
      text,
      style: DashText.eyebrow(c, color: c.navy).copyWith(fontSize: 10),
    );
  }
}

/// Ligne label / valeur de la table d'indicateurs, séparée par un filet fin.
class _IndicatorRow extends StatelessWidget {
  const _IndicatorRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.last = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(color: c.divider, width: Dash.hairline),
              ),
            ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: c.muted),
          ),
          Text(value, style: DashText.value(c, color: valueColor, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}
