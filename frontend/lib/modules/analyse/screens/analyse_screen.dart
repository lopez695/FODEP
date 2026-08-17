// Tableau de bord analytique reglementaire.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../shared/widgets/page_header.dart';
import '../models/analyse_models.dart';
import '../services/analyse_service.dart';

class AnalyseScreen extends StatefulWidget {
  const AnalyseScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<AnalyseScreen> createState() => _AnalyseScreenState();
}

class _AnalyseScreenState extends State<AnalyseScreen> {
  late final AnalyseService _service;
  late Future<AnalyseData> _future;
  StreamSubscription<int>? _portfolioSubscription;

  @override
  void initState() {
    super.initState();
    _service = AnalyseService(widget.api);
    _future = _service.fetchAnalyseData();
    _portfolioSubscription = widget.api.portfolioRefreshStream.listen((_) {
      if (!mounted) return;
      setState(() => _future = _service.fetchAnalyseData());
    });
  }

  @override
  void dispose() {
    _portfolioSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AnalyseData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        final data = snapshot.data!;
        final report = data.regulatoryReport;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return SingleChildScrollView(
          padding: AppSpacing.pageInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Tableau de Bord Analytique',
                subtitle:
                    'Diagnostic reglementaire, causes et plan d action ICAAP.',
                trailing: _StatusPill(status: report.status),
              ),
              AppSpacing.gapLg,
              _ComplianceSummary(report: report),
              AppSpacing.gapLg,
              _ResponsiveGrid(
                minTileWidth: 255,
                children: report.analysisCards
                    .map((card) => _RegulatoryCard(card: card))
                    .toList(),
              ),
              AppSpacing.gapLg,
              _TwoColumn(
                left: _GapChart(report: report),
                right: _DiagnosticList(report: report),
              ),
              AppSpacing.gapLg,
              _TwoColumn(
                left: _AlertTimeline(events: report.alertTimeline),
                right: _RecommendationNarrative(report: report),
              ),
              AppSpacing.gapLg,
              _JsonPreview(report: report, isDark: isDark),
            ],
          ),
        );
      },
    );
  }
}

class _ComplianceSummary extends StatelessWidget {
  const _ComplianceSummary({required this.report});

  final RegulatoryAnalysisReport report;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _statusColor(report.status);
    return Container(
      padding: AppSpacing.cardInsets,
      decoration: _cardDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TrafficLight(status: report.status),
          AppSpacing.hGapLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conformite globale ${report.status.label}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.darkText : AppTheme.text,
                  ),
                ),
                AppSpacing.gapSm,
                Text(
                  report.consultantNarrative,
                  style: TextStyle(
                    height: 1.45,
                    color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.hGapMd,
          _MetricBlock(
            label: 'Gap capital',
            value: formatCurrencyCompact(report.capitalGap),
            color: statusColor,
          ),
        ],
      ),
    );
  }
}

class _RegulatoryCard extends StatelessWidget {
  const _RegulatoryCard({required this.card});

  final RegulatoryAnalysisCard card;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _statusColor(card.status);
    return Container(
      padding: AppSpacing.cardInsets,
      decoration: _cardDecoration(context).copyWith(
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(card.icon, color: color, size: 20),
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(
                  card.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.darkText : AppTheme.text,
                  ),
                ),
              ),
              _StatusDot(status: card.status),
            ],
          ),
          AppSpacing.gapMd,
          Text(
            card.keyValue,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.darkText : AppTheme.text,
            ),
          ),
          Text(
            card.keyLabel,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkMuted : AppTheme.muted,
            ),
          ),
          AppSpacing.gapMd,
          _LabeledText(label: 'Ou sommes-nous ?', value: card.diagnostic),
          AppSpacing.gapSm,
          _LabeledText(label: 'Pourquoi ?', value: card.cause),
          AppSpacing.gapSm,
          _LabeledText(label: 'Que faire ?', value: card.recommendation),
          AppSpacing.gapMd,
          Text(
            card.ruleReference,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _GapChart extends StatelessWidget {
  const _GapChart({required this.report});

  final RegulatoryAnalysisReport report;

  @override
  Widget build(BuildContext context) {
    final maxValue = [
      report.availableCapital,
      report.requiredCapital,
      report.economicCapital,
    ].reduce(math.max);
    return _Panel(
      title: 'Graphique Gap',
      child: Column(
        children: [
          _BarLine(
            label: 'Capital disponible',
            value: report.availableCapital,
            maxValue: maxValue,
            color: AppColors.success,
          ),
          _BarLine(
            label: 'Capital requis',
            value: report.requiredCapital,
            maxValue: maxValue,
            color: AppColors.warning,
          ),
          _BarLine(
            label: 'Capital economique',
            value: report.economicCapital,
            maxValue: maxValue,
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _DiagnosticList extends StatelessWidget {
  const _DiagnosticList({required this.report});

  final RegulatoryAnalysisReport report;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Diagnostics du moteur',
      child: Column(
        children: report.diagnostics.take(6).map((item) {
          final color = AppColors.severityColor(item.severity);
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.rule_rounded, color: color, size: 18),
                AppSpacing.hGapSm,
                Expanded(
                  child: Text(
                    item.message,
                    style: const TextStyle(height: 1.35, fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AlertTimeline extends StatelessWidget {
  const _AlertTimeline({required this.events});

  final List<RegulatoryAlertEvent> events;

  @override
  Widget build(BuildContext context) {
    final list = events.isEmpty
        ? [
            RegulatoryAlertEvent(
              date: DateTime.now(),
              title: 'Aucune non-conformite majeure',
              detail:
                  'Les seuils critiques sont respectes sur les donnees chargees.',
              status: RegulatoryStatus.green,
            ),
          ]
        : events;
    return _Panel(
      title: 'Chronologie des alertes',
      child: Column(
        children: list.map((event) {
          final color = _statusColor(event.status);
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    Container(
                      width: 1,
                      height: 34,
                      color: color.withValues(alpha: 0.3),
                    ),
                  ],
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${event.date.day.toString().padLeft(2, '0')}/${event.date.month.toString().padLeft(2, '0')} - ${event.title}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      AppSpacing.gapXs,
                      Text(event.detail, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RecommendationNarrative extends StatelessWidget {
  const _RecommendationNarrative({required this.report});

  final RegulatoryAnalysisReport report;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Que faire ?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(report.consultantNarrative, style: const TextStyle(height: 1.5)),
          AppSpacing.gapMd,
          ...report.recommendations.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${action.priority}.',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  AppSpacing.hGapSm,
                  Expanded(child: Text(action.action)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JsonPreview extends StatelessWidget {
  const _JsonPreview({required this.report, required this.isDark});

  final RegulatoryAnalysisReport report;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final json = report.toJson();
    return _Panel(
      title: 'Objet JSON genere',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.22)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '{ analysis_id: ${json['analysis_id']}, status: ${json['status']}, diagnostics: ${report.diagnostics.length}, recommendations: ${report.recommendations.length} }',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: isDark ? AppTheme.darkMuted : AppTheme.muted,
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: AppSpacing.cardInsets,
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.darkText : AppTheme.text,
            ),
          ),
          AppSpacing.gapMd,
          child,
        ],
      ),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({
    required this.children,
    required this.minTileWidth,
  });

  final List<Widget> children;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(1, constraints.maxWidth ~/ minTileWidth);
        final width =
            (constraints.maxWidth - ((columns - 1) * AppSpacing.md)) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: children
              .map((child) => SizedBox(width: width.toDouble(), child: child))
              .toList(),
        );
      },
    );
  }
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 850) {
          return Column(children: [left, AppSpacing.gapMd, right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            AppSpacing.hGapMd,
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _BarLine extends StatelessWidget {
  const _BarLine({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final String label;
  final double value;
  final double maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final factor = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 13))),
              Text(
                formatCurrencyCompact(value),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          AppSpacing.gapSm,
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: factor.toDouble(),
              minHeight: 16,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrafficLight extends StatelessWidget {
  const _TrafficLight({required this.status});

  final RegulatoryStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Light(
              color: AppColors.success,
              active: status == RegulatoryStatus.green),
          AppSpacing.gapSm,
          _Light(
              color: AppColors.warning,
              active: status == RegulatoryStatus.warning),
          AppSpacing.gapSm,
          _Light(
              color: AppColors.danger,
              active: status == RegulatoryStatus.critical),
        ],
      ),
    );
  }
}

class _Light extends StatelessWidget {
  const _Light({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: active ? color : color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final RegulatoryStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final RegulatoryStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _statusColor(status),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 185),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          AppSpacing.gapXs,
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledText extends StatelessWidget {
  const _LabeledText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 13,
          height: 1.35,
          color: isDark ? AppTheme.darkMuted : AppTheme.muted,
        ),
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(
              color: isDark ? AppTheme.darkText : AppTheme.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark ? AppColors.surfaceDark : Colors.white,
    borderRadius: BorderRadius.circular(6),
    border: Border.all(
      color: isDark ? AppColors.borderDark : AppColors.borderLight,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.035),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

Color _statusColor(RegulatoryStatus status) {
  switch (status) {
    case RegulatoryStatus.green:
      return AppColors.success;
    case RegulatoryStatus.warning:
      return AppColors.warning;
    case RegulatoryStatus.critical:
      return AppColors.danger;
  }
}
