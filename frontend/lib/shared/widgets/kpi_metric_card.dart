import 'package:flutter/material.dart';

import '../../core/localization/app_localization.dart';
import '../../core/theme/app_theme.dart';

class KpiMetricCard extends StatefulWidget {
  const KpiMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.color,
    this.trend = const <double>[],
    this.fullValue,
    this.height = 46,
    this.borderRadius = AppTheme.radius,
    this.onTap,
  });

  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color color;
  final List<double> trend;
  final String? fullValue;
  final double height;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  State<KpiMetricCard> createState() => _KpiMetricCardState();
}

class _KpiMetricCardState extends State<KpiMetricCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        isDark ? Colors.white.withValues(alpha: 0.04) : AppTheme.card;
    final borderColor = widget.color.withValues(
      alpha: _hovered ? (isDark ? 0.40 : 0.45) : (isDark ? 0.18 : 0.0),
    );
    final titleColor = isDark ? AppTheme.darkText : AppTheme.text;
    final mutedColor = isDark ? AppTheme.darkMuted : AppTheme.muted;
    final indicatorInfo = _KpiIndicatorInfo.resolve(
      label: widget.label,
      helper: widget.helper,
    );
    final label = widget.label.tr(context).toUpperCase();
    final value = widget.value;

    // Calcul du trend (variation entre avant-dernier et dernier point)
    String? trendStr;
    Color? trendColor;
    if (widget.trend.length >= 2) {
      final last = widget.trend.last;
      final prev = widget.trend[widget.trend.length - 2];
      if (prev != 0) {
        final pct = ((last - prev) / prev) * 100;
        trendStr = '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';
        trendColor = pct >= 0 ? AppTheme.success : AppTheme.danger;
      }
    }

    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hovered = true);
      }),
      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hovered = false);
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: widget.height,
          transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
          padding: const EdgeInsets.fromLTRB(3, 8, 3, 8),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.18)
                    : const Color(0xFF4318FF)
                        .withValues(alpha: _hovered ? 0.10 : 0.05),
                blurRadius: _hovered ? 18 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _IndicatorTooltip(
                info: indicatorInfo,
                accent: widget.color,
                isDark: isDark,
                borderRadius: widget.borderRadius,
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: isDark ? 0.18 : 0.10),
                    borderRadius:
                        BorderRadius.circular(widget.borderRadius * 0.7),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.color,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mutedColor,
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          maxLines: 1,
                          style: TextStyle(
                            color: titleColor,
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    if (trendStr != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            trendColor == AppTheme.success
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 9,
                            color: trendColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            trendStr,
                            style: TextStyle(
                              color: trendColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IndicatorTooltip extends StatelessWidget {
  const _IndicatorTooltip({
    required this.info,
    required this.accent,
    required this.isDark,
    required this.borderRadius,
    required this.child,
  });

  final _KpiIndicatorInfo info;
  final Color accent;
  final bool isDark;
  final double borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final background =
        isDark ? const Color(0xFF101B2E) : const Color(0xFF0F172A);
    const bodyColor = Color(0xFFEAF1FF);
    const mutedColor = Color(0xFFAFC0DA);

    return Tooltip(
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: info.title.tr(context),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.4,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          TextSpan(
            text: '\n${info.summary.tr(context)}',
            style: const TextStyle(
              color: bodyColor,
              fontSize: 10.4,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          TextSpan(
            text: '\n\nCalcul',
            style: TextStyle(
              color: accent,
              fontSize: 10.4,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          TextSpan(
            text: '\n${info.formula.tr(context)}',
            style: const TextStyle(
              color: bodyColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          TextSpan(
            text: '\n\nRéférences',
            style: TextStyle(
              color: accent,
              fontSize: 10.4,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          TextSpan(
            text: '\n${info.references.tr(context)}',
            style: const TextStyle(
              color: mutedColor,
              fontSize: 9.6,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          TextSpan(
            text: '\n\nLecture',
            style: TextStyle(
              color: accent,
              fontSize: 10.4,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          TextSpan(
            text: '\n${info.reading.tr(context)}',
            style: const TextStyle(
              color: mutedColor,
              fontSize: 9.6,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      ),
      constraints: const BoxConstraints(
        minWidth: 260,
        maxWidth: 340,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      margin: const EdgeInsets.all(3),
      preferBelow: false,
      verticalOffset: 15,
      waitDuration: const Duration(milliseconds: 220),
      showDuration: const Duration(seconds: 9),
      textAlign: TextAlign.left,
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: accent.withValues(alpha: 0.44)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _KpiIndicatorInfo {
  const _KpiIndicatorInfo({
    required this.title,
    required this.summary,
    required this.formula,
    required this.references,
    required this.reading,
  });

  final String title;
  final String summary;
  final String formula;
  final String references;
  final String reading;

  static _KpiIndicatorInfo resolve({
    required String label,
    required String helper,
  }) {
    final text = '$label $helper'.toLowerCase();

    if (text.contains('solv') || text.contains('cet1')) {
      return const _KpiIndicatorInfo(
        title: 'Ratio de solvabilité',
        summary:
            'Mesure la capacité de la banque à couvrir ses risques pondérés par ses fonds propres éligibles.',
        formula:
            'Ratio = fonds propres réglementaires éligibles / RWA total. Le CET1 retient le noyau dur des fonds propres.',
        references:
            'Repères Bâle III et dispositif prudentiel BCEAO/UMOA : fonds propres, exigences minimales et coussins prudentiels.',
        reading:
            'Un ratio élevé indique une marge de solvabilité plus confortable ; une baisse signale une pression sur le capital.',
      );
    }

    if (text.contains('npl') ||
        text.contains('defaut') ||
        text.contains('défaut') ||
        text.contains('pd')) {
      return const _KpiIndicatorInfo(
        title: 'Qualité du portefeuille',
        summary:
            'Suit le poids des défauts, retards ou probabilités de défaut dans le portefeuille analysé.',
        formula:
            'NPL = encours non performants / exposition brute. PD = moyenne pondérée des probabilités de défaut disponibles.',
        references:
            'Dispositif prudentiel BCEAO/UMOA : créances en souffrance et défaut prudentiel, avec repère interne aux paragraphes 152 à 160.',
        reading:
            'Une hausse détériore la qualité crédit, augmente la surveillance et peut peser sur les pondérations ou provisions.',
      );
    }

    if (text.contains('ead') || text.contains('exposition')) {
      return const _KpiIndicatorInfo(
        title: 'Exposition au défaut',
        summary:
            'Représente le montant exposé au risque après prise en compte du bilan, du hors-bilan et des conversions applicables.',
        formula:
            'EAD = exposition bilan + exposition hors-bilan convertie par CCF, avant ou après filtres selon le module.',
        references:
            'Approche standard BCEAO/UMOA : traitement des expositions, engagements hors bilan et facteurs de conversion CCF.',
        reading:
            'Plus l’EAD est élevée, plus le portefeuille alimente fortement le RWA et le capital minimum requis.',
      );
    }

    if (text.contains('capital')) {
      return const _KpiIndicatorInfo(
        title: 'Capital minimum requis',
        summary:
            'Estime le montant de fonds propres réglementaires à immobiliser pour couvrir les actifs pondérés.',
        formula:
            'Capital minimum = RWA total x taux réglementaire cible. Le taux standard utilisé dans l’outil est 9 %.',
        references:
            'Cadre Bâle III et dispositif prudentiel BCEAO/UMOA : exigence de fonds propres et pilotage des coussins.',
        reading:
            'Une hausse traduit une consommation de capital plus importante et réduit les marges disponibles.',
      );
    }

    if (text.contains('var')) {
      return const _KpiIndicatorInfo(
        title: 'VaR globale',
        summary:
            'Mesure une perte potentielle maximale sur un horizon donné, pour un niveau de confiance défini.',
        formula:
            'VaR = quantile de perte du portefeuille selon l’horizon, la volatilité et les corrélations retenues.',
        references:
            'Référentiel de risque de marché : exigences internes de mesure, backtesting et limites de marché.',
        reading:
            'Une VaR élevée signale une exposition de marché plus sensible aux mouvements défavorables.',
      );
    }

    if (text.contains('incident') || text.contains('operationnel')) {
      return const _KpiIndicatorInfo(
        title: 'Incidents critiques',
        summary:
            'Synthétise les événements opérationnels majeurs nécessitant un suivi renforcé ou une action corrective.',
        formula:
            'Indicateur = nombre d’incidents classés critiques selon la gravité, l’impact financier et le statut de traitement.',
        references:
            'Cadre de risque opérationnel : collecte des pertes, suivi KRI, contrôle interne et plans d’actions.',
        reading:
            'Un niveau élevé appelle une priorisation des contrôles, des plans correctifs et de l’escalade managériale.',
      );
    }

    if (text.contains('expected loss') || text.contains('perte attendue')) {
      return const _KpiIndicatorInfo(
        title: 'Expected Loss',
        summary:
            'Estime la perte moyenne attendue du portefeuille sur la base des paramètres de risque disponibles.',
        formula:
            'EL = EAD x PD x LGD. Lorsque les paramètres sont absents, l’indicateur reste à zéro ou non disponible.',
        references:
            'Référentiel crédit : paramètres EAD, PD, LGD, défaut et suivi des pertes attendues.',
        reading:
            'Une EL élevée indique une perte statistique attendue plus importante et peut guider le provisionnement.',
      );
    }

    if (text.contains('couverture') || text.contains('crm')) {
      return const _KpiIndicatorInfo(
        title: 'Couverture CRM',
        summary:
            'Mesure la part du risque couverte par des techniques éligibles de réduction du risque de crédit.',
        formula:
            'Couverture = montant couvert éligible / exposition concernée, après règles d’éligibilité et décotes applicables.',
        references:
            'Approche standard BCEAO/UMOA : garanties, sûretés, CRM éligible, décotes et traitement des garants.',
        reading:
            'Une bonne couverture peut réduire le risque résiduel, le RWA et le besoin de capital.',
      );
    }

    if (text.contains('risque residuel') || text.contains('résiduel')) {
      return const _KpiIndicatorInfo(
        title: 'Risque résiduel',
        summary:
            'Montant de risque restant après prise en compte des garanties et mécanismes de mitigation.',
        formula:
            'Risque résiduel = exposition brute - protections reconnues, selon les règles CRM appliquées.',
        references:
            'Référentiel CRM et garanties : éligibilité, valorisation, décotes et reconnaissance prudentielle.',
        reading:
            'Un risque résiduel élevé montre que la protection économique ou prudentielle reste insuffisante.',
      );
    }

    return const _KpiIndicatorInfo(
      title: 'RWA - Actifs pondérés aux risques',
      summary:
          'Indicateur prudentiel central qui transforme les expositions en risque pondéré selon leur catégorie et leur qualité.',
      formula:
          'RWA = somme des EAD x pondération prudentielle, après CCF hors bilan et CRM éligible lorsque applicable.',
      references:
          'Approche standard du dispositif prudentiel BCEAO/UMOA : catégories prudentielles, notations, CCF, défauts et CRM.',
      reading:
          'Plus le RWA est élevé, plus la consommation de capital réglementaire augmente.',
    );
  }
}
