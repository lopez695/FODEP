// Ce fichier affiche les paramètres globaux de l'application.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../shared/widgets/page_header.dart';

class ReferentielsScreen extends StatelessWidget {
  const ReferentielsScreen({
    super.key,
    required this.api,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.portfolioDisplayCurrency,
    required this.portfolioAmountUnit,
    required this.appLanguage,
    required this.fontFamily,
    required this.onFontFamilyChanged,
    required this.primaryColor,
    required this.onPrimaryColorChanged,
  });

  final RwaApiService api;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueNotifier<String> portfolioDisplayCurrency;
  final ValueNotifier<PortfolioAmountUnit> portfolioAmountUnit;
  final ValueNotifier<AppLanguage> appLanguage;
  final String fontFamily;
  final ValueChanged<String> onFontFamilyChanged;
  final Color primaryColor;
  final ValueChanged<Color> onPrimaryColorChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            title: 'Paramètres',
            subtitle: 'Préférences globales, devises et services essentiels.',
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SettingsOverview(
                      primary: primary,
                      themeMode: themeMode,
                      fontFamily: fontFamily,
                      portfolioDisplayCurrency: portfolioDisplayCurrency,
                      portfolioAmountUnit: portfolioAmountUnit,
                      appLanguage: appLanguage,
                    ),
                    const SizedBox(height: 3),
                    _SettingsGrid(
                      children: [
                        _SettingsPanel(
                          title: 'Langue',
                          subtitle: 'Langue utilisée dans l’interface.',
                          icon: CupertinoIcons.globe,
                          accent: const Color(0xFF2563EB),
                          child: ValueListenableBuilder<AppLanguage>(
                            valueListenable: appLanguage,
                            builder: (context, selectedLanguage, _) {
                              return _ChoiceGroup<AppLanguage>(
                                selected: selectedLanguage,
                                onChanged: (value) => appLanguage.value = value,
                                options: const [
                                  _ChoiceItem(
                                    value: AppLanguage.francais,
                                    title: 'Français',
                                    description: 'Interface en français.',
                                    icon: CupertinoIcons.flag_fill,
                                  ),
                                  _ChoiceItem(
                                    value: AppLanguage.anglais,
                                    title: 'English',
                                    description: 'Interface in English.',
                                    icon: CupertinoIcons.flag_fill,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        _SettingsPanel(
                          title: 'Thème Mode',
                          subtitle: 'Mode visuel appliqué à l’application.',
                          icon: CupertinoIcons.moon_stars_fill,
                          accent: const Color(0xFF7C3AED),
                          child: _ChoiceGroup<ThemeMode>(
                            selected: themeMode,
                            onChanged: onThemeModeChanged,
                            options: const [
                              _ChoiceItem(
                                value: ThemeMode.light,
                                title: 'Clair',
                                description:
                                    'Fond lumineux et lisibilité forte.',
                                icon: CupertinoIcons.sun_max_fill,
                              ),
                              _ChoiceItem(
                                value: ThemeMode.dark,
                                title: 'Sombre',
                                description: 'Interface sombre et contrastée.',
                                icon: CupertinoIcons.moon_fill,
                              ),
                              _ChoiceItem(
                                value: ThemeMode.system,
                                title: 'Système',
                                description: 'Suit le réglage de la machine.',
                                icon: CupertinoIcons.device_desktop,
                              ),
                            ],
                          ),
                        ),
                        _SettingsPanel(
                          title: 'Devises',
                          subtitle: 'Devise et unité d’affichage des montants.',
                          icon: CupertinoIcons.money_dollar_circle_fill,
                          accent: const Color(0xFF059669),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ValueListenableBuilder<String>(
                                valueListenable: portfolioDisplayCurrency,
                                builder: (context, selectedCurrency, _) {
                                  return _ChoiceGroup<String>(
                                    selected:
                                        normalizeCurrencyCode(selectedCurrency),
                                    onChanged: (value) =>
                                        portfolioDisplayCurrency.value =
                                            normalizeCurrencyCode(value),
                                    options: const [
                                      _ChoiceItem(
                                        value: 'XOF',
                                        title: 'XOF',
                                        description: 'FCFA BCEAO.',
                                        icon: CupertinoIcons.creditcard_fill,
                                      ),
                                      _ChoiceItem(
                                        value: 'EUR',
                                        title: 'EUR',
                                        description: 'Euro.',
                                        icon: CupertinoIcons.creditcard_fill,
                                      ),
                                      _ChoiceItem(
                                        value: 'USD',
                                        title: 'USD',
                                        description: 'Dollar américain.',
                                        icon: CupertinoIcons.creditcard_fill,
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 9),
                              ValueListenableBuilder<PortfolioAmountUnit>(
                                valueListenable: portfolioAmountUnit,
                                builder: (context, selectedUnit, _) {
                                  return _ChoiceGroup<PortfolioAmountUnit>(
                                    selected: selectedUnit,
                                    onChanged: (value) =>
                                        portfolioAmountUnit.value = value,
                                    options: const [
                                      _ChoiceItem(
                                        value: PortfolioAmountUnit.thousand,
                                        title: 'Mille',
                                        description: 'Affichage en k.',
                                        icon: CupertinoIcons.number,
                                      ),
                                      _ChoiceItem(
                                        value: PortfolioAmountUnit.million,
                                        title: 'Million',
                                        description: 'Affichage en M.',
                                        icon: CupertinoIcons.number,
                                      ),
                                      _ChoiceItem(
                                        value: PortfolioAmountUnit.billion,
                                        title: 'Milliard',
                                        description: 'Affichage en Md.',
                                        icon: CupertinoIcons.number,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        _SettingsPanel(
                          title: 'Font de police',
                          subtitle:
                              'Police principale utilisée par l’interface.',
                          icon: CupertinoIcons.textformat,
                          accent: const Color(0xFF0F766E),
                          child: _ChoiceGroup<String>(
                            selected: fontFamily,
                            onChanged: onFontFamilyChanged,
                            options: [
                              for (final family
                                  in AppTheme.supportedFontFamilies)
                                _ChoiceItem<String>(
                                  value: family,
                                  title: family,
                                  description: _fontDescription(family),
                                  icon: CupertinoIcons.textformat_alt,
                                ),
                            ],
                          ),
                        ),
                        _SettingsPanel(
                          title: 'Couleurs principales',
                          subtitle: 'Couleur de sélection et accents globaux.',
                          icon: CupertinoIcons.paintbrush_fill,
                          accent: primaryColor,
                          child: _ColorChoiceGroup(
                            selected: primaryColor,
                            onChanged: onPrimaryColorChanged,
                          ),
                        ),
                        const _SettingsPanel(
                          title: 'Services',
                          subtitle: 'Informations utiles et contacts produit.',
                          icon: CupertinoIcons.headphones,
                          accent: Color(0xFFEA580C),
                          child: _ServicesBlock(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsOverview extends StatelessWidget {
  const _SettingsOverview({
    required this.primary,
    required this.themeMode,
    required this.fontFamily,
    required this.portfolioDisplayCurrency,
    required this.portfolioAmountUnit,
    required this.appLanguage,
  });

  final Color primary;
  final ThemeMode themeMode;
  final String fontFamily;
  final ValueNotifier<String> portfolioDisplayCurrency;
  final ValueNotifier<PortfolioAmountUnit> portfolioAmountUnit;
  final ValueNotifier<AppLanguage> appLanguage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? const Color(0xFFF2F6FF) : AppTheme.text;
    final muted = isDark ? const Color(0xFF9FB0D0) : AppTheme.muted;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111C33) : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: isDark ? const Color(0xFF22304B) : const Color(0xFFE3E9F6),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Icon(
              CupertinoIcons.slider_horizontal_3,
              color: primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paramètres application',
                  style: TextStyle(
                    color: text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Les préférences modifient l’affichage global sans toucher aux données métier.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 3),
          Flexible(
            flex: 2,
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              alignment: WrapAlignment.end,
              children: [
                ValueListenableBuilder<AppLanguage>(
                  valueListenable: appLanguage,
                  builder: (context, value, _) => _OverviewPill(
                    label: 'Langue',
                    value: value.shortLabel,
                    color: primary,
                  ),
                ),
                _OverviewPill(
                  label: 'Thème',
                  value: _themeModeLabel(themeMode),
                  color: primary,
                ),
                ValueListenableBuilder<String>(
                  valueListenable: portfolioDisplayCurrency,
                  builder: (context, value, _) => _OverviewPill(
                    label: 'Devise',
                    value: normalizeCurrencyCode(value),
                    color: primary,
                  ),
                ),
                ValueListenableBuilder<PortfolioAmountUnit>(
                  valueListenable: portfolioAmountUnit,
                  builder: (context, value, _) => _OverviewPill(
                    label: 'Unité',
                    value: value.label,
                    color: primary,
                  ),
                ),
                _OverviewPill(
                  label: 'Police',
                  value: fontFamily,
                  color: primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewPill extends StatelessWidget {
  const _OverviewPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 31,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.09),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label : ',
            style: TextStyle(
              color: isDark ? const Color(0xFFB9C6E2) : AppTheme.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 10.4,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGrid extends StatelessWidget {
  const _SettingsGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 1040;
        final cardWidth =
            twoColumns ? (constraints.maxWidth - 10) / 2 : constraints.maxWidth;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final child in children)
              SizedBox(
                width: cardWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? const Color(0xFFF2F6FF) : AppTheme.text;
    final muted = isDark ? const Color(0xFF9FB0D0) : AppTheme.muted;

    return Container(
      constraints: const BoxConstraints(minHeight: 210),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF111C33).withValues(alpha: 0.92)
            : Colors.white,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: isDark ? const Color(0xFF22304B) : const Color(0xFFE3E9F6),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x22040A16) : const Color(0x080F172A),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        fontSize: 10.8,
                        fontWeight: FontWeight.w600,
                        height: 1.22,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          child,
        ],
      ),
    );
  }
}

class _ChoiceItem<T> {
  const _ChoiceItem({
    required this.value,
    required this.title,
    required this.description,
    required this.icon,
  });

  final T value;
  final String title;
  final String description;
  final IconData icon;
}

class _ChoiceGroup<T> extends StatelessWidget {
  const _ChoiceGroup({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<_ChoiceItem<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 520
            ? (constraints.maxWidth - 8) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              SizedBox(
                width: itemWidth,
                child: _ChoiceTile<T>(
                  option: option,
                  selected: option.value == selected,
                  onTap: () => onChanged(option.value),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ChoiceItem<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final text = isDark ? const Color(0xFFF2F6FF) : AppTheme.text;
    final muted = isDark ? const Color(0xFF9FB0D0) : AppTheme.muted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 66),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: isDark ? 0.18 : 0.09)
                : (isDark ? const Color(0xFF0F1B31) : const Color(0xFFF8FAFF)),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: selected
                  ? primary.withValues(alpha: 0.42)
                  : (isDark
                      ? const Color(0xFF22304B)
                      : const Color(0xFFE6EBF6)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? primary.withValues(alpha: 0.16)
                      : muted.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Icon(
                  option.icon,
                  color: selected ? primary : muted,
                  size: 15,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: TextStyle(
                        color: selected ? primary : text,
                        fontSize: 12.4,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      option.description,
                      style: TextStyle(
                        color: muted,
                        fontSize: 10.4,
                        fontWeight: FontWeight.w600,
                        height: 1.18,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.check_mark_circled_solid,
                  color: primary,
                  size: 15,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorChoiceGroup extends StatelessWidget {
  const _ColorChoiceGroup({
    required this.selected,
    required this.onChanged,
  });

  final Color selected;
  final ValueChanged<Color> onChanged;

  static const _colors = [
    _ColorChoice('Bleu finance', Color(0xFF2563EB)),
    _ColorChoice('Indigo', Color(0xFF4F46E5)),
    _ColorChoice('Émeraude', Color(0xFF059669)),
    _ColorChoice('Cyan', Color(0xFF0891B2)),
    _ColorChoice('Violet', Color(0xFF7C3AED)),
    _ColorChoice('Crimson', Color(0xFFE11D48)),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final choice in _colors)
          Builder(
            builder: (context) {
              final selectedColor =
                  selected.toARGB32() == choice.color.toARGB32();
              return InkWell(
                onTap: () => onChanged(choice.color),
                borderRadius: BorderRadius.circular(2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 146,
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    color: selectedColor
                        ? choice.color.withValues(alpha: isDark ? 0.18 : 0.10)
                        : (isDark
                            ? const Color(0xFF0F1B31)
                            : const Color(0xFFF8FAFF)),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: selectedColor
                          ? choice.color.withValues(alpha: 0.48)
                          : (isDark
                              ? const Color(0xFF22304B)
                              : const Color(0xFFE6EBF6)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: choice.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          choice.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selectedColor
                                ? choice.color
                                : (isDark
                                    ? const Color(0xFFF2F6FF)
                                    : AppTheme.text),
                            fontSize: 11.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _ColorChoice {
  const _ColorChoice(this.label, this.color);

  final String label;
  final Color color;
}

class _ServicesBlock extends StatelessWidget {
  const _ServicesBlock();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _ServiceTile(
          icon: CupertinoIcons.envelope_fill,
          title: 'Nous contacter',
          body:
              'Support produit, assistance fonctionnelle et remontées métier.',
          detail: 'support@heymanns.com',
        ),
        SizedBox(height: 8),
        _ServiceTile(
          icon: CupertinoIcons.info_circle_fill,
          title: 'À propos de nous',
          body: 'Solution de pilotage RWA, capital réglementaire et risques.',
          detail: 'Version 1.0.0',
        ),
        SizedBox(height: 8),
        _ServiceTile(
          icon: CupertinoIcons.lock_shield_fill,
          title: 'Sécurité & confidentialité',
          body: 'Contrôles d’accès, traçabilité et protection des données.',
          detail: 'Politique interne',
        ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String body;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final text = isDark ? const Color(0xFFF2F6FF) : AppTheme.text;
    final muted = isDark ? const Color(0xFF9FB0D0) : AppTheme.muted;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B31) : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: isDark ? const Color(0xFF22304B) : const Color(0xFFE6EBF6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Icon(icon, color: primary, size: 16),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: text,
                    fontSize: 12.4,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: TextStyle(
                    color: muted,
                    fontSize: 10.6,
                    fontWeight: FontWeight.w600,
                    height: 1.22,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: TextStyle(
                    color: primary,
                    fontSize: 10.6,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _themeModeLabel(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.light => 'Clair',
    ThemeMode.dark => 'Sombre',
    ThemeMode.system => 'Système',
  };
}

String _fontDescription(String family) {
  return switch (family) {
    'Roboto Flex' => 'Standard moderne.',
    'Aptos' => 'Bureautique premium.',
    'IBM Plex Sans' => 'Enterprise analytique.',
    'General Sans' => 'SaaS contemporain.',
    'Nunito Sans' => 'Lecture douce.',
    _ => 'Police disponible.',
  };
}
