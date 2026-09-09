// Ce fichier construit la navigation laterale reutilisable.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_module.dart';
import '../../core/localization/app_localization.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'desktop_asset_image.dart';
import 'rwa_tool_logo.dart';

const Color _sidebarDeepBlue = Color(0xFF234A84);
const double _sidebarPanelRadius = 1;

/// Couleur de l'état sélectionné = navy institutionnel (accord avec le
/// dashboard). En mode sombre, navy éclairci pour rester lisible sur le fond.
Color _selectedNavColor(bool isDark) =>
    isDark ? const Color(0xFF2E4E86) : AppColors.sidebar;

const String settingsSectionLanguageId = 'language';
const String settingsSectionCurrenciesId = 'currencies';
const String settingsSectionThemeId = 'theme';
const String settingsSectionFontId = 'font';
const String settingsSectionColorsId = 'colors';
const String settingsSectionServicesId = 'services';

class SettingsSectionSelection {
  const SettingsSectionSelection({
    required this.sectionId,
    required this.anchorRect,
  });

  final String sectionId;
  final Rect anchorRect;
}

/// Barre latérale qui gère la navigation entre les modules.
class SidebarNavigation extends StatelessWidget {
  const SidebarNavigation({
    super.key,
    required this.selectedModule,
    required this.onSelectModule,
    this.compact = false,
    this.showBrand = true,
    this.contentTopInset = 0,
    this.headerTrailing,
    this.onSelectSettingsSection,
    this.selectedSettingsSectionId,
  });

  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelectModule;
  final bool compact;
  final bool showBrand;
  final double contentTopInset;
  final Widget? headerTrailing;
  final ValueChanged<SettingsSectionSelection>? onSelectSettingsSection;
  final String? selectedSettingsSectionId;

  @override
  Widget build(BuildContext context) {
    // Le menu est le même pour tous : chaque compte importe dans son propre
    // espace, sans jamais toucher aux données d'un autre. Masquer l'import à
    // certains les empêcherait de travailler sur leurs propres chiffres.
    const items = _sidebarItems;

    final sidebar = compact
        ? _CompactSidebar(
            items: items,
            selectedModule: selectedModule,
            onSelectModule: onSelectModule,
            onSelectSettingsSection: onSelectSettingsSection,
            selectedSettingsSectionId: selectedSettingsSectionId,
            contentTopInset: contentTopInset,
            headerTrailing: headerTrailing,
          )
        : _ExpandedSidebar(
            items: items,
            selectedModule: selectedModule,
            onSelectModule: onSelectModule,
            onSelectSettingsSection: onSelectSettingsSection,
            selectedSettingsSectionId: selectedSettingsSectionId,
            showBrand: showBrand,
            contentTopInset: contentTopInset,
            headerTrailing: headerTrailing,
          );

    return sidebar;
  }
}

/// Structure interne qui décrit une entrée du menu latéral.
class _MenuEntry {
  const _MenuEntry.leaf({
    required this.module,
    required this.icon,
    required this.label,
    this.selectable = true,
    this.settingsSectionId,
    this.disabled = false,
  }) : children = const [];

  const _MenuEntry.group({
    required this.icon,
    required this.label,
    required this.children,
  })  : module = null,
        selectable = false,
        settingsSectionId = null,
        disabled = false;

  final AppModule? module;
  final IconData icon;
  final String label;
  final List<_MenuEntry> children;
  final bool selectable;
  final String? settingsSectionId;
  /// Quand true, l'entrée est grisée et non cliquable (temporairement
  /// désactivée) - elle reste visible dans le menu mais n'a aucun effet.
  final bool disabled;

  bool get hasChildren => children.isNotEmpty;

  IconData iconFor(bool selected) => selected ? _filledIconFor(icon) : icon;

  static IconData _filledIconFor(IconData icon) {
    return switch (icon) {
      Icons.autorenew_rounded => Icons.autorenew_rounded,
      Icons.file_download_outlined => Icons.file_download_rounded,
      Icons.compare_arrows_rounded => Icons.compare_arrows_rounded,
      Icons.open_in_new_rounded => Icons.open_in_new_rounded,
      Icons.notifications_none_rounded => Icons.notifications_rounded,
      Icons.business_center_outlined => Icons.business_center_rounded,
      Icons.bar_chart_rounded => Icons.insert_chart_rounded,
      Icons.analytics_outlined => Icons.analytics_rounded,
      Icons.pie_chart_outline_rounded => Icons.pie_chart_rounded,
      Icons.verified_outlined => Icons.verified_rounded,
      Icons.verified_user_outlined => Icons.verified_user_rounded,
      Icons.schedule_rounded => Icons.schedule_rounded,
      Icons.credit_card_outlined => Icons.credit_card_rounded,
      Icons.summarize_outlined => Icons.summarize_rounded,
      Icons.assignment_turned_in_outlined => Icons.assignment_turned_in_rounded,
      Icons.file_copy_outlined => Icons.file_copy_rounded,
      Icons.description_outlined => Icons.description_rounded,
      Icons.water_drop_outlined => Icons.water_drop_rounded,
      Icons.report_gmailerrorred_rounded => Icons.report_rounded,
      Icons.warning_amber_rounded => Icons.warning_rounded,
      Icons.local_fire_department_outlined =>
        Icons.local_fire_department_rounded,
      Icons.settings_outlined => Icons.settings_rounded,
      Icons.show_chart_rounded => Icons.show_chart_rounded,
      Icons.favorite_border_rounded => Icons.favorite_rounded,
      Icons.home_work_outlined => Icons.home_work_rounded,
      Icons.science_outlined => Icons.science_rounded,
      Icons.admin_panel_settings_outlined => Icons.admin_panel_settings_rounded,
      Icons.map_outlined => Icons.map_rounded,
      Icons.monetization_on_outlined => Icons.monetization_on_rounded,
      Icons.palette_outlined => Icons.palette_rounded,
      Icons.groups_2_outlined => Icons.groups_2_rounded,
      Icons.layers_outlined => Icons.layers_rounded,
      Icons.shield_outlined => Icons.shield_rounded,
      Icons.dashboard_outlined => Icons.dashboard_rounded,
      Icons.inventory_2_outlined => Icons.inventory_2_rounded,
      Icons.view_in_ar_outlined => Icons.view_in_ar_rounded,
      Icons.table_chart_outlined => Icons.table_chart_rounded,
      Icons.multiline_chart_rounded => Icons.multiline_chart_rounded,
      _ => icon,
    };
  }

  bool matches(AppModule selectedModule) {
    if (selectable && module == selectedModule) {
      return true;
    }
    return children.any((child) => child.matches(selectedModule));
  }

  AppModule resolveTarget(AppModule selectedModule) {
    if (module != null) {
      return module!;
    }

    for (final child in children) {
      if (child.matches(selectedModule)) {
        return child.resolveTarget(selectedModule);
      }
    }

    final fallbackModule = children.first.module;
    if (fallbackModule == null) {
      throw StateError('Le sous-menu ne contient aucun module navigable.');
    }
    return fallbackModule;
  }
}

bool _entrySelected(
  _MenuEntry entry,
  AppModule selectedModule,
  String? selectedSettingsSectionId,
) {
  final settingsSectionId = entry.settingsSectionId;
  if (settingsSectionId != null) {
    return settingsSectionId == selectedSettingsSectionId;
  }
  if (entry.selectable && entry.module == selectedModule) {
    return true;
  }
  return entry.children.any(
    (child) => _entrySelected(
      child,
      selectedModule,
      selectedSettingsSectionId,
    ),
  );
}

Rect _anchorRectFrom(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.attached) {
    return Rect.zero;
  }
  final topLeft = renderObject.localToGlobal(Offset.zero);
  return topLeft & renderObject.size;
}

const List<_MenuEntry> _riskCreditChildren = [
  _MenuEntry.leaf(
    module: AppModule.dashboardCredit,
    icon: Icons.dashboard_outlined,
    label: 'Dashboard Crédit',
  ),
  _MenuEntry.leaf(
    module: AppModule.expositions,
    icon: Icons.credit_card_outlined,
    label: 'Expositions',
  ),
  _MenuEntry.leaf(
    module: AppModule.concentrationCredit,
    icon: Icons.pie_chart_outline_rounded,
    label: 'Portefeuille',
  ),
  _MenuEntry.leaf(
    module: AppModule.derives,
    icon: Icons.swap_horiz_rounded,
    label: 'Dérivés',
  ),
  _MenuEntry.leaf(
    module: AppModule.rwaEngine,
    icon: Icons.functions_rounded,
    label: 'Pilotage RWA Crédit',
  ),
];

// "Import données" et "Simulation de crise" ont été déplacés à l'intérieur
// du hub "CCR3 / Dispositif UEMOA" (onglets supplémentaires) - ils ne sont
// plus des entrées séparées de ce sous-menu.
const List<_MenuEntry> _operationalRiskChildren = [
  _MenuEntry.leaf(
    module: AppModule.risqueOperationnel,
    icon: Icons.dashboard_outlined,
    label: 'Dashboard Opérationnel',
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueOperationnelUemoiCcr3,
    icon: Icons.policy_outlined,
    label: 'CCR3 / Dispositif UEMOA',
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueOperationnelPertes,
    icon: Icons.monetization_on_outlined,
    label: 'Pertes opérationnelles',
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueOperationnelHistorique,
    icon: Icons.schedule_rounded,
    label: 'Historique événements',
  ),
];

const List<_MenuEntry> _stressChildren = [
  _MenuEntry.leaf(
    module: AppModule.stressTest,
    icon: Icons.credit_card_outlined,
    label: 'Stress crédit',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.stressTest,
    icon: Icons.science_outlined,
    label: 'Stress marché',
    selectable: false,
  ),
  _MenuEntry.leaf(
    module: AppModule.stressTest,
    icon: Icons.engineering_outlined,
    label: 'Stress opérationnel',
    selectable: false,
  ),
];

// Les sept composantes du PIEAFP, dans l'ordre ou elles se construisent.
// Celles qui restent grisees attendent leur ecran : les afficher des
// maintenant dit ou va le module, plutot que de laisser croire que l'ICAAP se
// resume au socle reglementaire.
const List<_MenuEntry> _icaapChildren = [
  _MenuEntry.leaf(
    module: AppModule.icapCapitalReglementaire,
    icon: Icons.account_balance_outlined,
    label: 'Capital reglementaire',
  ),
  _MenuEntry.leaf(
    module: AppModule.icapAppetenceRisque,
    icon: Icons.tune_outlined,
    label: 'Appetence au risque',
    disabled: true,
  ),
  _MenuEntry.leaf(
    module: AppModule.icapCapitalEconomique,
    icon: Icons.calculate_outlined,
    label: 'Capital economique',
    disabled: true,
  ),
  _MenuEntry.leaf(
    module: AppModule.icapBuffersPrudentiels,
    icon: Icons.layers_outlined,
    label: 'Coussins prudentiels',
    disabled: true,
  ),
  _MenuEntry.leaf(
    module: AppModule.icapAnalyseSolvabilite,
    icon: Icons.balance_outlined,
    label: 'Analyse de solvabilite',
    disabled: true,
  ),
  _MenuEntry.leaf(
    module: AppModule.icapProjectionCapital,
    icon: Icons.trending_up_outlined,
    label: 'Projection du capital',
    disabled: true,
  ),
  _MenuEntry.leaf(
    module: AppModule.icapPlansCapital,
    icon: Icons.assignment_outlined,
    label: 'Plan de fonds propres',
    disabled: true,
  ),
  _MenuEntry.leaf(
    module: AppModule.icapReportingIcaap,
    icon: Icons.summarize_outlined,
    label: 'Rapport PIEAFP',
    disabled: true,
  ),
];

const List<_MenuEntry> _capitalPlanningChildren = [
  _MenuEntry.leaf(
    module: AppModule.capitalPlaning,
    icon: Icons.construction_outlined,
    label: 'En cours de construction',
  ),
];

const List<_MenuEntry> _settingsChildren = [
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: CupertinoIcons.globe,
    label: 'Langue',
    settingsSectionId: settingsSectionLanguageId,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: CupertinoIcons.creditcard,
    label: 'Devises',
    settingsSectionId: settingsSectionCurrenciesId,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: CupertinoIcons.circle_lefthalf_fill,
    label: 'Thème Mode',
    settingsSectionId: settingsSectionThemeId,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: CupertinoIcons.textformat_size,
    label: 'Font de police',
    settingsSectionId: settingsSectionFontId,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: CupertinoIcons.paintbrush,
    label: 'Couleurs principales',
    settingsSectionId: settingsSectionColorsId,
  ),
  _MenuEntry.leaf(
    module: AppModule.referentiels,
    icon: CupertinoIcons.info_circle,
    label: 'Services',
    settingsSectionId: settingsSectionServicesId,
  ),
];

const List<_MenuEntry> _sidebarItems = [
  _MenuEntry.leaf(
    module: AppModule.importations,
    icon: Icons.cloud_upload_outlined,
    label: 'Importations',
  ),
  _MenuEntry.leaf(
    module: AppModule.vueEnsemble,
    icon: Icons.pie_chart_outline_rounded,
    label: 'Vue d\'ensemble',
  ),
  _MenuEntry.group(
    icon: Icons.monetization_on_outlined,
    label: 'Risque Crédit',
    children: _riskCreditChildren,
  ),
  _MenuEntry.group(
    icon: Icons.show_chart_rounded,
    label: 'Risque de Marché',
    children: [
      _MenuEntry.leaf(
        module: AppModule.risqueMarche,
        icon: Icons.dashboard_outlined,
        label: 'Tableau de Bord',
      ),
      _MenuEntry.leaf(
        module: AppModule.risqueMarcheCalculPrudentiel,
        icon: Icons.calculate_rounded,
        label: 'Calcul Prudentiel',
      ),
      _MenuEntry.leaf(
        module: AppModule.risqueMarchePilotage,
        icon: Icons.speed_rounded,
        label: 'Pilotage des risques',
      ),
    ],
  ),
  _MenuEntry.group(
    icon: Icons.shield_outlined,
    label: 'Risque Opérationnel',
    children: _operationalRiskChildren,
  ),
  _MenuEntry.group(
    icon: Icons.science_outlined,
    label: 'Stress Test',
    children: _stressChildren,
  ),
  _MenuEntry.group(
    icon: Icons.business_center_outlined,
    label: 'ICAAP',
    children: _icaapChildren,
  ),
  _MenuEntry.group(
    icon: Icons.bar_chart_rounded,
    label: 'Capital Planning',
    children: _capitalPlanningChildren,
  ),
  _MenuEntry.leaf(
    module: AppModule.risqueOperationnelReporting,
    icon: Icons.summarize_outlined,
    label: 'Reporting global',
  ),
  _MenuEntry.group(
    icon: Icons.settings_outlined,
    label: 'Paramètres',
    children: _settingsChildren,
  ),
];

/// Variante compacte de la sidebar affichant surtout les icônes.
class _CompactSidebar extends StatelessWidget {
  const _CompactSidebar({
    required this.items,
    required this.selectedModule,
    required this.onSelectModule,
    required this.contentTopInset,
    this.onSelectSettingsSection,
    this.selectedSettingsSectionId,
    this.headerTrailing,
  });

  final List<_MenuEntry> items;
  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelectModule;
  final double contentTopInset;
  final ValueChanged<SettingsSectionSelection>? onSelectSettingsSection;
  final String? selectedSettingsSectionId;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 54,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F1B31).withValues(alpha: 0.96)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(_sidebarPanelRadius),
        border: Border.all(
          color: isDark ? const Color(0xFF22304B) : const Color(0xFFE5E8F5),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33040A16) : const Color(0x120F172A),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 0),
          if (contentTopInset > 0) SizedBox(height: contentTopInset),
          if (headerTrailing != null) ...[
            Align(
              alignment: Alignment.center,
              child: headerTrailing!,
            ),
            const SizedBox(height: 6),
          ],
          Expanded(
            child: ListView.separated(addSemanticIndexes: false,
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final entry = items[index];
                if (entry.hasChildren) {
                  return _CompactNavGroup(
                    entry: entry,
                    selectedModule: selectedModule,
                    onSelectModule: onSelectModule,
                    onSelectSettingsSection: onSelectSettingsSection,
                    selectedSettingsSectionId: selectedSettingsSectionId,
                  );
                }

                return _CompactNavButton(
                  entry: entry,
                  selected: _entrySelected(
                    entry,
                    selectedModule,
                    selectedSettingsSectionId,
                  ),
                  onTap: () => onSelectModule(
                    entry.resolveTarget(selectedModule),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 2),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? const Color(0xFF22304B) : const Color(0xFFE5ECFA),
          ),
          const SizedBox(height: 2),
          const _CompactSidebarLogo(),
        ],
      ),
    );
  }
}

/// Bloc logo affiché en haut de la sidebar compacte.
class _CompactSidebarLogo extends StatelessWidget {
  const _CompactSidebarLogo();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 50,
      height: 40,
      child: DesktopAssetImage(
        'assets/images/heymanns_logo.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        color: isDark ? const Color(0xFFEAF1FF) : null,
        colorBlendMode: isDark ? BlendMode.srcIn : null,
        opacity: isDark
            ? const AlwaysStoppedAnimation<double>(0.82)
            : const AlwaysStoppedAnimation<double>(1),
      ),
    );
  }
}

/// Ouvre un menu popup imbriqué pour un groupe de navigation.
/// Retourne l'entrée feuille sélectionnée, ou `null` si le menu est fermé.
/// Si un enfant est lui-même un groupe, un sous-menu s'ouvre récursivement.
Future<_MenuEntry?> _showNestedMenuForEntry(
  BuildContext context,
  _MenuEntry menuEntry,
  AppModule currentModule,
  String? selectedSettingsSectionId, {
  Offset popupOffset = const Offset(205, -4),
}) async {
  final renderBox = context.findRenderObject() as RenderBox?;
  if (renderBox == null || !renderBox.attached) return null;
  final topLeft = renderBox.localToGlobal(Offset.zero);
  final anchorRect = topLeft + popupOffset & const Size(1, 1);
  final mediaQuerySize = MediaQuery.of(context).size;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final popupBackground = isDark ? const Color(0xFF0F1B31) : Colors.white;
  final borderColor =
      isDark ? const Color(0xFF263856) : const Color(0xFFDDE6F4);

  final selection = await showMenu<_MenuEntry>(
    context: context,
    position: RelativeRect.fromRect(anchorRect, Offset.zero & mediaQuerySize),
    color: popupBackground,
    elevation: 10,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      side: BorderSide(color: borderColor),
    ),
    constraints: const BoxConstraints(minWidth: 194, maxWidth: 220),
    items: [
      for (final child in menuEntry.children)
        PopupMenuItem<_MenuEntry>(
          value: child,
          enabled: !child.disabled,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          child: _CompactFloatingMenuItem(
            entry: child,
            selected:
                _entrySelected(child, currentModule, selectedSettingsSectionId),
          ),
        ),
    ],
  );

  if (selection == null) return null;
  if (!context.mounted) return null;
  if (selection.hasChildren) {
    return _showNestedMenuForEntry(
        context, selection, currentModule, selectedSettingsSectionId,
        popupOffset: popupOffset);
  }
  return selection;
}

/// Groupe de navigation compact affiché dans une carte flottante.
class _CompactNavGroup extends StatelessWidget {
  const _CompactNavGroup({
    required this.entry,
    required this.selectedModule,
    required this.onSelectModule,
    this.onSelectSettingsSection,
    this.selectedSettingsSectionId,
  });

  final _MenuEntry entry;
  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelectModule;
  final ValueChanged<SettingsSectionSelection>? onSelectSettingsSection;
  final String? selectedSettingsSectionId;

  @override
  Widget build(BuildContext context) {
    final groupSelected =
        _entrySelected(entry, selectedModule, selectedSettingsSectionId);

    return GestureDetector(
      onTap: () async {
        final selection = await _showNestedMenuForEntry(
          context,
          entry,
          selectedModule,
          selectedSettingsSectionId,
          popupOffset: const Offset(48, -4),
        );
        if (selection == null) return;
        if (!context.mounted) return;
        final settingsSectionId = selection.settingsSectionId;
        if (settingsSectionId != null && onSelectSettingsSection != null) {
          final anchorRect = _anchorRectFrom(context);
          onSelectSettingsSection!(
            SettingsSectionSelection(
              sectionId: settingsSectionId,
              anchorRect: anchorRect,
            ),
          );
          return;
        }
        onSelectModule(selection.resolveTarget(selectedModule));
      },
      child: _CompactNavButtonSurface(
        entry: entry,
        selected: groupSelected,
      ),
    );
  }
}

class _CompactFloatingMenuItem extends StatelessWidget {
  const _CompactFloatingMenuItem({
    required this.entry,
    required this.selected,
  });

  final _MenuEntry entry;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBlue = _selectedNavColor(isDark);
    final disabled = entry.disabled;
    final mutedColor = isDark ? const Color(0xFF465577) : const Color(0xFFC2CBDA);
    final iconColor = disabled
        ? mutedColor
        : (selected ? Colors.white : const Color(0xFF71829F));
    final textColor = disabled
        ? mutedColor
        : selected
            ? Colors.white
            : (isDark ? const Color(0xFFB8C8E8) : const Color(0xFF60708B));

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: selected && !disabled ? selectedBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: [
          Icon(
            entry.iconFor(selected && !disabled),
            size: 16,
            color: disabled
                ? mutedColor
                : (selected ? Colors.white : (isDark ? const Color(0xFF9FB2D6) : iconColor)),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              entry.label.tr(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 10.4,
                fontWeight: selected && !disabled ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
          if (disabled) ...[
            const SizedBox(width: 6),
            Icon(Icons.lock_outline, size: 13, color: mutedColor),
          ] else if (selected) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.check_rounded,
              size: 14,
              color: Colors.white,
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactNavButtonSurface extends StatelessWidget {
  const _CompactNavButtonSurface({
    required this.entry,
    required this.selected,
  });

  final _MenuEntry entry;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = selected
        ? Colors.white
        : (isDark ? const Color(0xFFB8C8E8) : _sidebarDeepBlue);
    const buttonSize = 36.0;
    const iconSize = 16.0;
    final selectedColor = _selectedNavColor(isDark);

    return Container(
      width: buttonSize,
      height: buttonSize,
      decoration: BoxDecoration(
        color: selected ? selectedColor : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: selected ? selectedColor : Colors.transparent,
        ),
      ),
      child: Center(
        child: Icon(entry.iconFor(selected), size: iconSize, color: iconColor),
      ),
    );
  }
}

/// Bouton de navigation individuel pour la sidebar compacte.
class _CompactNavButton extends StatelessWidget {
  const _CompactNavButton({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final _MenuEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: _CompactNavButtonSurface(
          entry: entry,
          selected: selected,
        ),
      ),
    );
  }
}

/// Variante ouverte de la sidebar avec icônes et libellés.
class _ExpandedSidebar extends StatelessWidget {
  const _ExpandedSidebar({
    required this.items,
    required this.selectedModule,
    required this.onSelectModule,
    required this.showBrand,
    required this.contentTopInset,
    this.onSelectSettingsSection,
    this.selectedSettingsSectionId,
    this.headerTrailing,
  });

  final List<_MenuEntry> items;
  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelectModule;
  final bool showBrand;
  final double contentTopInset;
  final ValueChanged<SettingsSectionSelection>? onSelectSettingsSection;
  final String? selectedSettingsSectionId;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCondensed = constraints.maxWidth < 118;
        final panelPadding = isCondensed ? 8.0 : AppTheme.spacing;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(panelPadding),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F1B31).withValues(alpha: 0.97)
                : Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(_sidebarPanelRadius),
            border: Border.all(
              color: isDark ? const Color(0xFF22304B) : const Color(0xFFE5E8F5),
            ),
            boxShadow: [
              BoxShadow(
                color:
                    isDark ? const Color(0x33040A16) : const Color(0x120F172A),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contentTopInset > 0) SizedBox(height: contentTopInset),
              if (showBrand && !isCondensed) ...[
                const _BrandHeader(),
                const SizedBox(height: 3),
              ],
              if (!isCondensed) ...[
                Row(
                  children: [
                    Expanded(
                      child: _SidebarSectionTitle(context.tr('Navigation')),
                    ),
                    if (headerTrailing != null) ...[
                      const SizedBox(width: 8),
                      headerTrailing!,
                    ],
                  ],
                ),
                const SizedBox(height: 3),
              ],
              Expanded(
                child: ListView.separated(addSemanticIndexes: false,
                  padding: EdgeInsets.zero,
                  physics: const ClampingScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final entry = items[index];
                    if (entry.hasChildren) {
                      return _ExpandedNavGroup(
                        entry: entry,
                        selectedModule: selectedModule,
                        onSelectModule: onSelectModule,
                        onSelectSettingsSection: onSelectSettingsSection,
                        selectedSettingsSectionId: selectedSettingsSectionId,
                        showLabel: !isCondensed,
                      );
                    }

                    return _ExpandedNavTile(
                      entry: entry,
                      selected: _entrySelected(
                        entry,
                        selectedModule,
                        selectedSettingsSectionId,
                      ),
                      showLabel: !isCondensed,
                      onTap: () => onSelectModule(
                        entry.resolveTarget(selectedModule),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 2),
              Divider(
                height: 1,
                thickness: 1,
                color:
                    isDark ? const Color(0xFF22304B) : const Color(0xFFE5ECFA),
              ),
              const SizedBox(height: 3),
              if (isCondensed) ...[
                const Center(child: _CompactSidebarLogo()),
              ] else ...[
                _SidebarSectionTitle(context.tr('Service')),
                const SizedBox(height: 8),
                const _SidebarServiceCard(),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Groupe de navigation ouvert affichant ses sous-sections en popup.
class _ExpandedNavGroup extends StatelessWidget {
  const _ExpandedNavGroup({
    required this.entry,
    required this.selectedModule,
    required this.onSelectModule,
    required this.showLabel,
    this.onSelectSettingsSection,
    this.selectedSettingsSectionId,
  });

  final _MenuEntry entry;
  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelectModule;
  final bool showLabel;
  final ValueChanged<SettingsSectionSelection>? onSelectSettingsSection;
  final String? selectedSettingsSectionId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupSelected =
        _entrySelected(entry, selectedModule, selectedSettingsSectionId);

    return _ExpandedNavTile(
      entry: entry,
      selected: groupSelected,
      showLabel: showLabel,
      trailing: showLabel
          ? Icon(
              Icons.chevron_right_rounded,
              size: 12,
              color: groupSelected
                  ? Colors.white.withValues(alpha: 0.95)
                  : (isDark
                      ? const Color(0xFFD7E3FA)
                      : const Color(0xFF5270A7)),
            )
          : null,
      onTap: () => _openPopupMenu(context),
    );
  }

  Future<void> _openPopupMenu(BuildContext context) async {
    final selection = await _showNestedMenuForEntry(
      context,
      entry,
      selectedModule,
      selectedSettingsSectionId,
    );
    if (selection == null) return;
    if (!context.mounted) return;
    final settingsSectionId = selection.settingsSectionId;
    if (settingsSectionId != null && onSelectSettingsSection != null) {
      final anchorRect = _anchorRectFrom(context);
      onSelectSettingsSection!(
        SettingsSectionSelection(
          sectionId: settingsSectionId,
          anchorRect: anchorRect,
        ),
      );
      return;
    }
    onSelectModule(selection.resolveTarget(selectedModule));
  }
}

/// Titre de section utilisé dans la sidebar étendue.
class _SidebarSectionTitle extends StatelessWidget {
  const _SidebarSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Text(
      label,
      style: TextStyle(
        color: isDark ? const Color(0xFF9CB2D4) : _sidebarDeepBlue,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

/// Carte d'information affichée en bas de la sidebar.
class _SidebarServiceCard extends StatelessWidget {
  const _SidebarServiceCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 90,
            child: DesktopAssetImage(
              'assets/images/heymanns_logo.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              color: isDark ? const Color(0xFFEAF1FF) : null,
              colorBlendMode: isDark ? BlendMode.srcIn : null,
              opacity: isDark
                  ? const AlwaysStoppedAnimation<double>(0.84)
                  : const AlwaysStoppedAnimation<double>(1),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.tr(
              "LEADER DE L'ALM ET DU RISK MANAGEMENT EN AFRIQUE SUBSAHARIENNE",
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark
                  ? const Color(0xFF8FA6CB)
                  : const Color.fromARGB(255, 13, 33, 64),
              fontSize: 7,
              fontWeight: FontWeight.w500,
              height: 1.2,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 7),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? const Color(0xFF22304B) : const Color(0xFFD9E4F6),
          ),
          const SizedBox(height: 6),
          Text(
            'Version : 1.0.0'.tr(context),
            style: TextStyle(
              color: isDark
                  ? const Color(0xFFD7E3FA)
                  : const Color.fromARGB(255, 6, 24, 57),
              fontSize: 8,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// En-tête de marque affiché dans la sidebar ouverte.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14233D) : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: isDark ? const Color(0xFF2A3C5E) : const Color(0xFFD9E4F6),
            ),
          ),
          child: const RwaToolLogo(size: 34),
        ),
        const SizedBox(width: AppTheme.spacing),
        Expanded(
          child: Text(
            context.tr('FODEP'),
            style: TextStyle(
              color: isDark
                  ? const Color(0xFFD7E3FA)
                  : const Color.fromARGB(255, 16, 42, 94),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tuile de navigation complète pour la sidebar étendue.
class _ExpandedNavTile extends StatelessWidget {
  const _ExpandedNavTile({
    required this.entry,
    required this.selected,
    required this.showLabel,
    required this.onTap,
    this.trailing,
  });

  final _MenuEntry entry;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBlue = _selectedNavColor(isDark);
    final iconColor = selected
        ? Colors.white
        : (isDark ? const Color(0xFFB8C8E8) : _sidebarDeepBlue);
    final textColor = selected
        ? Colors.white
        : (isDark ? const Color(0xFFB8C8E8) : _sidebarDeepBlue);
    final tileColor = selected
        ? selectedBlue
        : (isDark
            ? const Color(0xFF16304F).withValues(alpha: 0.46)
            : const Color(0xFFF4F8FF));
    final tileBorderColor = selected ? selectedBlue : Colors.transparent;
    final tileBorderWidth = selected ? 1.0 : 0.0;
    final tileShadow = selected
        ? const <BoxShadow>[]
        : [
            BoxShadow(
              color: isDark ? const Color(0x0A040A16) : const Color(0x040F172A),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ];
    const tileRadius = 3.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tileRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(tileRadius),
            border: Border.all(
              color: tileBorderColor,
              width: tileBorderWidth,
            ),
            boxShadow: tileShadow,
          ),
          child: !showLabel
              ? Center(
                  child: Icon(
                    entry.iconFor(selected),
                    size: 17,
                    color: iconColor,
                  ),
                )
              : Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.16)
                            : (isDark
                                ? const Color(0xFF14233D)
                                : const Color(0xFFF7FAFF)),
                        borderRadius: BorderRadius.circular(3.0),
                      ),
                      child: Icon(
                        entry.iconFor(selected),
                        size: 15,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        entry.label.tr(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 10.4,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                          height: 1.0,
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 6),
                      trailing!,
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
