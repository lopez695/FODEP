// Ce fichier structure le layout principal de l'application.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_module.dart';
import '../../core/auth/session_scope.dart';
import '../../modules/auth/widgets/equipe_dialog.dart';
import '../../core/localization/app_language.dart';
import '../../core/localization/app_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_conversion.dart';
import 'desktop_asset_image.dart';
import 'sidebar_navigation.dart';

const double _sidebarToggleButtonWidth = 28;
const double _sidebarToggleButtonHeight = 28;
const double _sidebarToggleHitArea = 42;
const double _sidebarToggleButtonRadius = 6;
const double _desktopPanelGap = 2.0;
const double _desktopRailWidth = 54;
const double _desktopOverlayWidth = 220;
const double _workspaceTopBarControlHeight = 24;
const double _workspaceTopBarControlRadius = 2;
const Duration _desktopSidebarOpenDuration = Duration(milliseconds: 60);
const Duration _desktopSidebarCloseDuration = Duration(milliseconds: 60);

class AppShellNotification {
  const AppShellNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.detail,
    required this.severity,
    required this.source,
    required this.date,
    required this.targetModule,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final String detail;
  final String severity;
  final String source;
  final DateTime date;
  final AppModule targetModule;
  final bool isRead;

  AppShellNotification copyWith({bool? isRead}) {
    return AppShellNotification(
      id: id,
      title: title,
      body: body,
      detail: detail,
      severity: severity,
      source: source,
      date: date,
      targetModule: targetModule,
      isRead: isRead ?? this.isRead,
    );
  }
}

/// Coquille principale de l'application avec top bar, sidebar et contenu.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.selectedModule,
    required this.onSelectModule,
    required this.onReturnToWelcome,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.portfolioDisplayCurrency,
    required this.portfolioAmountUnit,
    required this.appLanguage,
    required this.fontFamily,
    required this.onFontFamilyChanged,
    required this.primaryColor,
    required this.onPrimaryColorChanged,
    required this.child,
  });

  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelectModule;
  final VoidCallback onReturnToWelcome;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueNotifier<String> portfolioDisplayCurrency;
  final ValueNotifier<PortfolioAmountUnit> portfolioAmountUnit;
  final ValueNotifier<AppLanguage> appLanguage;
  final String fontFamily;
  final ValueChanged<String> onFontFamilyChanged;
  final Color primaryColor;
  final ValueChanged<Color> onPrimaryColorChanged;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

/// Etat interne qui pilote la sidebar et la top bar.
class _AppShellState extends State<AppShell> {
  static const double _screenSpacing = 0.0;
  bool _isSidebarOverlayOpen = true;
  String? _activeSettingsSectionId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1120;

        if (isDesktop) {
          return _buildDesktopShell();
        }

        return _buildMobileShell();
      },
    );
  }

  Widget _buildDesktopShell() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF091224) : AppTheme.background,
      body: Stack(
        children: [
          // Ce fond reste fixe derrière tout l'espace de travail.
          _DecorativeBackdrop(dark: isDark),
          SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _screenSpacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // La top bar concentre la marque et les actions globales.
                  _WorkspaceTopBar(
                    selectedModule: widget.selectedModule,
                    onReturnToWelcome: widget.onReturnToWelcome,
                    portfolioDisplayCurrency: widget.portfolioDisplayCurrency,
                    portfolioAmountUnit: widget.portfolioAmountUnit,
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            end: _isSidebarOverlayOpen ? 1 : 0,
                          ),
                          duration: _isSidebarOverlayOpen
                              ? _desktopSidebarOpenDuration
                              : _desktopSidebarCloseDuration,
                          curve: _isSidebarOverlayOpen
                              ? Curves.easeOutQuart
                              : Curves.easeInQuart,
                          builder: (context, progress, _) {
                            final sidebarWidth = _desktopRailWidth +
                                (_desktopOverlayWidth - _desktopRailWidth) *
                                    progress;
                            final showCompact =
                                !_isSidebarOverlayOpen && progress <= 0.001;
                            return SizedBox(
                              width: sidebarWidth,
                              child: RepaintBoundary(
                                child: ClipRect(
                                  child: showCompact
                                      ? _DesktopSidebarFrame(
                                          compact: true,
                                          width: _desktopRailWidth,
                                          selectedModule: widget.selectedModule,
                                          onSelectModule:
                                              _handleDesktopModuleSelection,
                                          onSelectSettingsSection:
                                              _openSettingsSectionOverlay,
                                          selectedSettingsSectionId:
                                              _activeSettingsSectionId,
                                          showBrand: false,
                                          showToggleButton: true,
                                          onToggleSidebar:
                                              _toggleDesktopSidebarOverlay,
                                        )
                                      : IgnorePointer(
                                          ignoring: progress < 0.98,
                                          child: OverflowBox(
                                            alignment: Alignment.centerLeft,
                                            minWidth: _desktopOverlayWidth,
                                            maxWidth: _desktopOverlayWidth,
                                            child: SizedBox(
                                              width: _desktopOverlayWidth,
                                              child: _DesktopSidebarFrame(
                                                compact: false,
                                                width: _desktopOverlayWidth,
                                                selectedModule:
                                                    widget.selectedModule,
                                                onSelectModule:
                                                    _handleDesktopModuleSelection,
                                                onSelectSettingsSection:
                                                    _openSettingsSectionOverlay,
                                                selectedSettingsSectionId:
                                                    _activeSettingsSectionId,
                                                showBrand: false,
                                                showToggleButton: true,
                                                onToggleSidebar:
                                                    _toggleDesktopSidebarOverlay,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: _desktopPanelGap),
                        Expanded(
                          child: RepaintBoundary(
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0F1B31)
                                        .withValues(alpha: 0.92)
                                    : Colors.white.withValues(alpha: 0.80),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius,
                                ),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF22304B)
                                      : const Color(0xFFE5E8F5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? const Color(0x33040A16)
                                        : const Color(0x120F172A),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius,
                                ),
                                child: widget.child,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleDesktopSidebarOverlay() {
    setState(() => _isSidebarOverlayOpen = !_isSidebarOverlayOpen);
  }

  void _handleDesktopModuleSelection(AppModule module) {
    if (module == AppModule.referentiels) {
      _openSettingsSectionOverlay(
        const SettingsSectionSelection(
          sectionId: settingsSectionLanguageId,
          anchorRect: Rect.zero,
        ),
      );
      return;
    }
    if (module == AppModule.risqueMarcheImport) {
      widget.onSelectModule(module);
      return;
    }
    if (module == widget.selectedModule) {
      return;
    }
    widget.onSelectModule(module);
  }

  Widget _buildMobileShell() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF091224) : AppTheme.background,
      // Sur mobile, la navigation passe dans un drawer pour conserver de l'espace utile.
      drawer: Drawer(
        child: SidebarNavigation(
          selectedModule: widget.selectedModule,
          onSelectModule: (module) {
            Navigator.of(context).pop();
            if (module == AppModule.referentiels) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _openSettingsSectionOverlay(
                    const SettingsSectionSelection(
                      sectionId: settingsSectionLanguageId,
                      anchorRect: Rect.zero,
                    ),
                  );
                }
              });
              return;
            }
            widget.onSelectModule(module);
          },
          onSelectSettingsSection: (selection) {
            Navigator.of(context).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _openSettingsSectionOverlay(selection);
              }
            });
          },
          selectedSettingsSectionId: _activeSettingsSectionId,
          compact: false,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _screenSpacing),
          child: Column(
            children: [
              // La barre mobile garde seulement le contexte courant et l'accès au menu.
              _TopBar(
                selectedModule: widget.selectedModule,
                showMenuButton: true,
                onReturnToWelcome: widget.onReturnToWelcome,
              ),
              const SizedBox(height: AppTheme.pageGap),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F1B31) : Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(
                      color: isDark ? const Color(0xFF22304B) : AppTheme.border,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: widget.child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSettingsSectionOverlay(
    SettingsSectionSelection selection,
  ) async {
    if (!mounted) return;
    final sectionId = selection.sectionId;
    final initialSection = _settingsSectionFromId(sectionId);
    final media = MediaQuery.of(context);
    final isDesktop = media.size.width >= 1120;
    final sidebarWidth =
        _isSidebarOverlayOpen ? _desktopOverlayWidth : _desktopRailWidth;
    final fallbackLeft = _screenSpacing + sidebarWidth + _desktopPanelGap + 2;
    final sideLeft = _settingsOverlayLeft(selection.anchorRect, fallbackLeft);
    final sideTop = _settingsOverlayTop(
      media,
      selection.anchorRect,
      initialSection,
    );

    setState(() => _activeSettingsSectionId = sectionId);
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Fermer les paramètres',
        barrierColor: Colors.black.withValues(alpha: 0.14),
        transitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (context, _, __) {
          return _SettingsTopOverlay(
            initialSection: initialSection,
            sideAligned: isDesktop,
            cascade: isDesktop,
            sideLeft: sideLeft,
            sideTop: sideTop,
            themeMode: widget.themeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
            portfolioDisplayCurrency: widget.portfolioDisplayCurrency,
            portfolioAmountUnit: widget.portfolioAmountUnit,
            appLanguage: widget.appLanguage,
            fontFamily: widget.fontFamily,
            onFontFamilyChanged: widget.onFontFamilyChanged,
            primaryColor: widget.primaryColor,
            onPrimaryColorChanged: widget.onPrimaryColorChanged,
          );
        },
        transitionBuilder: (context, animation, _, child) {
          final curved = Curves.easeOutCubic.transform(animation.value);
          return Opacity(
            opacity: curved,
            child: Transform.translate(
              offset: isDesktop
                  ? Offset(-18 * (1 - curved), 0)
                  : Offset(0, -22 * (1 - curved)),
              child: child,
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _activeSettingsSectionId = null);
      }
    }
  }

  double _settingsOverlayLeft(Rect anchorRect, double fallbackLeft) {
    if (anchorRect == Rect.zero) {
      return fallbackLeft;
    }
    return anchorRect.right + 10;
  }

  double _settingsOverlayTop(
    MediaQueryData media,
    Rect anchorRect,
    _SettingsOverlaySection initialSection,
  ) {
    if (anchorRect == Rect.zero) {
      return _screenSpacing + 82;
    }

    const menuPaddingTop = 7.0;
    const menuItemOuterHeight = 38.0;
    final menuHeight = menuPaddingTop * 2 +
        _settingsContentSections.length * menuItemOuterHeight;
    const bottomMargin = 12.0;
    final sectionIndex = _settingsContentSections.indexOf(initialSection);
    final activeIndex = sectionIndex < 0 ? 0 : sectionIndex;
    final preferredTop =
        anchorRect.top - menuPaddingTop - activeIndex * menuItemOuterHeight;
    final maxTop = media.size.height - menuHeight - bottomMargin;
    if (maxTop <= _screenSpacing) {
      return _screenSpacing;
    }
    return preferredTop.clamp(_screenSpacing, maxTop).toDouble();
  }
}

/// Fond analytique discret affiché derrière l'espace de travail.
class _DecorativeBackdrop extends StatelessWidget {
  const _DecorativeBackdrop({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final colors = dark
        ? const [Color(0xFF091224), Color(0xFF0B1630), Color(0xFF0F1B31)]
        : const [Color(0xFFF8FAFC), Color(0xFFF1F5F9), Color(0xFFF8FAFC)];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: _WorkspaceBackdropPainter(dark: dark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WorkspaceBackdropPainter extends CustomPainter {
  const _WorkspaceBackdropPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = dark ? const Color(0x142C4166) : const Color(0x1A9BA8BD)
      ..strokeWidth = 1;
    const gridStep = 48.0;
    for (var x = 0.0; x <= size.width; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final bandPaint = Paint()
      ..color = dark ? const Color(0x102563EB) : const Color(0x102563EB)
      ..style = PaintingStyle.fill;
    final bandPath = Path()
      ..moveTo(size.width * 0.52, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.82, size.height)
      ..close();
    canvas.drawPath(bandPath, bandPaint);

    final baselinePaint = Paint()
      ..color = dark ? const Color(0x242563EB) : const Color(0x24365F9A)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(0, size.height * 0.18),
      Offset(size.width, size.height * 0.18),
      baselinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WorkspaceBackdropPainter oldDelegate) {
    return oldDelegate.dark != dark;
  }
}

enum _SettingsOverlaySection {
  menu,
  language,
  currencies,
  theme,
  font,
  colors,
  services,
}

_SettingsOverlaySection _settingsSectionFromId(String sectionId) {
  return switch (sectionId) {
    settingsSectionLanguageId => _SettingsOverlaySection.language,
    settingsSectionCurrenciesId => _SettingsOverlaySection.currencies,
    settingsSectionThemeId => _SettingsOverlaySection.theme,
    settingsSectionFontId => _SettingsOverlaySection.font,
    settingsSectionColorsId => _SettingsOverlaySection.colors,
    settingsSectionServicesId => _SettingsOverlaySection.services,
    _ => _SettingsOverlaySection.menu,
  };
}

class _SettingsTopOverlay extends StatefulWidget {
  const _SettingsTopOverlay({
    this.initialSection = _SettingsOverlaySection.menu,
    this.sideAligned = false,
    this.cascade = false,
    this.sideLeft = 0,
    this.sideTop = 14,
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

  final _SettingsOverlaySection initialSection;
  final bool sideAligned;
  final bool cascade;
  final double sideLeft;
  final double sideTop;
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
  State<_SettingsTopOverlay> createState() => _SettingsTopOverlayState();
}

class _SettingsTopOverlayState extends State<_SettingsTopOverlay> {
  late _SettingsOverlaySection _section;
  _SettingsOverlaySection? _activeMenuSection;
  late ThemeMode _themeMode = widget.themeMode;
  late String _fontFamily = widget.fontFamily;
  late Color _primaryColor = widget.primaryColor;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    if (_section != _SettingsOverlaySection.menu) {
      _activeMenuSection = _section;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isMenu = _section == _SettingsOverlaySection.menu;
    if (widget.cascade && widget.sideAligned) {
      return _buildCascadeLayout(media);
    }

    final maxWidth = media.size.width - 24;
    final targetWidth = isMenu ? 340.0 : 540.0;
    final width = targetWidth > maxWidth ? maxWidth : targetWidth;

    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment:
              widget.sideAligned ? Alignment.topLeft : Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(
              left: widget.sideAligned ? widget.sideLeft : 0,
              top: widget.sideAligned ? widget.sideTop : 14,
            ),
            child: SizedBox(
              width: width,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 170),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.04),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: isMenu ? _buildMenuPanel() : _buildSectionPanel(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCascadeLayout(MediaQueryData media) {
    const menuWidth = 220.0;
    const gap = 8.0;
    const margin = 12.0;
    final hasContentPanel = _section != _SettingsOverlaySection.menu;
    final menuTop = _settingsMenuTop(media);
    final availableWidth = media.size.width - widget.sideLeft - 12;
    final contentWidth = _settingsPanelWidth(availableWidth - menuWidth - gap);
    final contentTop =
        hasContentPanel ? _cascadePanelTop(media, menuTop) : menuTop;
    final availablePanelHeight = media.size.height - contentTop - margin;
    final maxBodyHeight = hasContentPanel
        ? (availablePanelHeight - 72).clamp(90.0, 460.0).toDouble()
        : null;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            left: widget.sideLeft,
            top: menuTop,
            width: menuWidth,
            child: _SettingsCascadeMenu(
              activeSection: _section,
              onSelected: _showSection,
            ),
          ),
          if (hasContentPanel)
            Positioned(
              left: widget.sideLeft + menuWidth + gap,
              top: contentTop,
              width: contentWidth,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.025, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _buildSectionPanel(
                  showBack: false,
                  maxBodyHeight: maxBodyHeight,
                  onClose: _closeCascadeSection,
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _settingsMenuTop(MediaQueryData media) {
    const margin = 12.0;
    final menuHeight = _settingsCascadeMenuHeight();
    final maxTop = media.size.height - menuHeight - margin;
    if (maxTop <= margin) {
      return margin;
    }
    return widget.sideTop.clamp(margin, maxTop).toDouble();
  }

  double _cascadePanelTop(MediaQueryData media, double menuTop) {
    const margin = 12.0;
    final activeRowTop = menuTop + _settingsSectionRowTop(_section);
    final estimatedHeight = _settingsPanelEstimatedHeight(_section)
        .clamp(180.0, media.size.height - margin * 2)
        .toDouble();
    final maxTop = media.size.height - estimatedHeight - margin;
    if (maxTop <= margin) {
      return margin;
    }
    return activeRowTop.clamp(margin, maxTop).toDouble();
  }

  double _settingsSectionRowTop(_SettingsOverlaySection section) {
    const menuPaddingTop = 7.0;
    const menuItemOuterHeight = 38.0;
    final sectionIndex = _settingsContentSections.indexOf(section);
    if (sectionIndex <= 0) {
      return menuPaddingTop;
    }
    return menuPaddingTop + sectionIndex * menuItemOuterHeight;
  }

  double _settingsCascadeMenuHeight() {
    const menuPaddingTop = 7.0;
    const menuItemOuterHeight = 38.0;
    return menuPaddingTop * 2 +
        _settingsContentSections.length * menuItemOuterHeight;
  }

  double _settingsPanelEstimatedHeight(_SettingsOverlaySection section) {
    return switch (section) {
      _SettingsOverlaySection.language => 190,
      _SettingsOverlaySection.currencies => 320,
      _SettingsOverlaySection.theme => 230,
      _SettingsOverlaySection.font => 315,
      _SettingsOverlaySection.colors => 250,
      _SettingsOverlaySection.services => 330,
      _SettingsOverlaySection.menu => 220,
    };
  }

  double _settingsPanelWidth(double availableWidth) {
    return switch (_section) {
      _SettingsOverlaySection.currencies =>
        availableWidth.clamp(236.0, 260.0).toDouble(),
      _SettingsOverlaySection.font =>
        availableWidth.clamp(250.0, 270.0).toDouble(),
      _SettingsOverlaySection.services =>
        availableWidth.clamp(250.0, 270.0).toDouble(),
      _ => availableWidth.clamp(236.0, 260.0).toDouble(),
    };
  }

  Widget _buildMenuPanel() {
    final primary = Theme.of(context).colorScheme.primary;
    return _SettingsOverlayCard(
      key: const ValueKey<String>('settings-menu'),
      title: 'Paramètres',
      subtitle: 'Choisir une rubrique',
      icon: CupertinoIcons.slider_horizontal_3,
      onClose: () => Navigator.of(context).maybePop(),
      child: Column(
        children: [
          _SettingsMenuButton(
            title: 'Langue',
            icon: CupertinoIcons.globe,
            color: primary,
            selected: _activeMenuSection == _SettingsOverlaySection.language,
            onTap: () => _showSection(_SettingsOverlaySection.language),
          ),
          _SettingsMenuButton(
            title: 'Devises',
            icon: CupertinoIcons.creditcard_fill,
            color: primary,
            selected: _activeMenuSection == _SettingsOverlaySection.currencies,
            onTap: () => _showSection(_SettingsOverlaySection.currencies),
          ),
          _SettingsMenuButton(
            title: 'Thème Mode',
            icon: CupertinoIcons.circle_lefthalf_fill,
            color: primary,
            selected: _activeMenuSection == _SettingsOverlaySection.theme,
            onTap: () => _showSection(_SettingsOverlaySection.theme),
          ),
          _SettingsMenuButton(
            title: 'Font de police',
            icon: CupertinoIcons.textformat_size,
            color: primary,
            selected: _activeMenuSection == _SettingsOverlaySection.font,
            onTap: () => _showSection(_SettingsOverlaySection.font),
          ),
          _SettingsMenuButton(
            title: 'Couleurs principales',
            icon: CupertinoIcons.paintbrush_fill,
            color: primary,
            selected: _activeMenuSection == _SettingsOverlaySection.colors,
            onTap: () => _showSection(_SettingsOverlaySection.colors),
          ),
          _SettingsMenuButton(
            title: 'Services',
            icon: CupertinoIcons.info_circle_fill,
            color: primary,
            selected: _activeMenuSection == _SettingsOverlaySection.services,
            onTap: () => _showSection(_SettingsOverlaySection.services),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionPanel({
    bool showBack = true,
    double? maxBodyHeight,
    VoidCallback? onClose,
  }) {
    return _SettingsOverlayCard(
      key: ValueKey<_SettingsOverlaySection>(_section),
      title: _sectionTitle(_section),
      subtitle: _sectionSubtitle(_section),
      icon: _sectionIcon(_section),
      onBack:
          showBack ? () => _showSection(_SettingsOverlaySection.menu) : null,
      onClose: onClose ?? () => Navigator.of(context).maybePop(),
      maxBodyHeight: maxBodyHeight,
      child: _sectionContent(),
    );
  }

  Widget _sectionContent() {
    return switch (_section) {
      _SettingsOverlaySection.language => _buildLanguageSection(),
      _SettingsOverlaySection.currencies => _buildCurrenciesSection(),
      _SettingsOverlaySection.theme => _buildThemeSection(),
      _SettingsOverlaySection.font => _buildFontSection(),
      _SettingsOverlaySection.colors => _buildColorsSection(),
      _SettingsOverlaySection.services => _buildServicesSection(),
      _SettingsOverlaySection.menu => const SizedBox.shrink(),
    };
  }

  Widget _buildLanguageSection() {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: widget.appLanguage,
      builder: (context, selectedLanguage, _) {
        return _SettingsOptionGrid<AppLanguage>(
          selected: selectedLanguage,
          onChanged: (value) => widget.appLanguage.value = value,
          options: const [
            _SettingsOption(
              value: AppLanguage.francais,
              title: 'Français',
              description: 'Interface, libellés et formats en français.',
              icon: CupertinoIcons.flag_fill,
              flag: 'FR',
            ),
            _SettingsOption(
              value: AppLanguage.anglais,
              title: 'English',
              description: 'Interface labels and formats in English.',
              icon: CupertinoIcons.flag_fill,
              flag: 'GB',
            ),
          ],
        );
      },
    );
  }

  Widget _buildCurrenciesSection() {
    return ValueListenableBuilder<String>(
      valueListenable: widget.portfolioDisplayCurrency,
      builder: (context, selectedCurrency, _) {
        return _SettingsCurrencyOptionList(
          selectedCurrency: normalizeCurrencyCode(selectedCurrency),
          onChanged: (value) {
            widget.portfolioDisplayCurrency.value =
                normalizeCurrencyCode(value);
          },
        );
      },
    );
  }

  Widget _buildThemeSection() {
    return _SettingsOptionGrid<ThemeMode>(
      selected: _themeMode,
      onChanged: (value) {
        setState(() => _themeMode = value);
        widget.onThemeModeChanged(value);
      },
      options: const [
        _SettingsOption(
          value: ThemeMode.light,
          title: 'Clair',
          description: 'Interface lumineuse.',
          icon: CupertinoIcons.sun_max_fill,
        ),
        _SettingsOption(
          value: ThemeMode.dark,
          title: 'Sombre',
          description: 'Interface sombre.',
          icon: CupertinoIcons.moon_fill,
        ),
        _SettingsOption(
          value: ThemeMode.system,
          title: 'Système',
          description: 'Suit la machine.',
          icon: CupertinoIcons.device_desktop,
        ),
      ],
    );
  }

  Widget _buildFontSection() {
    return _SettingsOptionGrid<String>(
      selected: _fontFamily,
      onChanged: (value) {
        setState(() => _fontFamily = value);
        widget.onFontFamilyChanged(value);
      },
      options: [
        for (final family in AppTheme.supportedFontFamilies)
          _SettingsOption<String>(
            value: family,
            title: family,
            description: _fontDescription(family),
            icon: CupertinoIcons.textformat_alt,
          ),
      ],
    );
  }

  Widget _buildColorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final choice in _settingsAccentColors)
          _SettingsColorTile(
            label: choice.label,
            color: choice.color,
            selected: _primaryColor.toARGB32() == choice.color.toARGB32(),
            onTap: () {
              setState(() => _primaryColor = choice.color);
              widget.onPrimaryColorChanged(choice.color);
            },
          ),
      ],
    );
  }

  Widget _buildServicesSection() {
    return const Column(
      children: [
        _SettingsServiceTile(
          icon: CupertinoIcons.envelope_fill,
          title: 'Nous contacter',
        ),
        _SettingsServiceTile(
          icon: CupertinoIcons.info_circle_fill,
          title: 'À propos de nous',
        ),
        _SettingsServiceTile(
          icon: CupertinoIcons.lock_shield_fill,
          title: 'Sécurité & confidentialité',
        ),
      ],
    );
  }

  void _showSection(_SettingsOverlaySection section) {
    setState(() {
      _section = section;
      if (section != _SettingsOverlaySection.menu) {
        _activeMenuSection = section;
      }
    });
  }

  void _closeCascadeSection() {
    setState(() => _section = _SettingsOverlaySection.menu);
  }
}

const List<_SettingsOverlaySection> _settingsContentSections = [
  _SettingsOverlaySection.language,
  _SettingsOverlaySection.currencies,
  _SettingsOverlaySection.theme,
  _SettingsOverlaySection.font,
  _SettingsOverlaySection.colors,
  _SettingsOverlaySection.services,
];

class _SettingsCascadeMenu extends StatelessWidget {
  const _SettingsCascadeMenu({
    required this.activeSection,
    required this.onSelected,
  });

  final _SettingsOverlaySection activeSection;
  final ValueChanged<_SettingsOverlaySection> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF263856) : const Color(0xFFDDE6F4);

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B31) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.14),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final section in _settingsContentSections)
            _SettingsCascadeMenuItem(
              section: section,
              selected: section == activeSection,
              onTap: () => onSelected(section),
            ),
        ],
      ),
    );
  }
}

class _SettingsCascadeMenuItem extends StatelessWidget {
  const _SettingsCascadeMenuItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _SettingsOverlaySection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final muted = isDark ? const Color(0xFF9FB2D6) : const Color(0xFF71829F);
    final textColor = selected
        ? Colors.white
        : (isDark ? const Color(0xFFB8C8E8) : const Color(0xFF60708B));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOutCubic,
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? primary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Row(
              children: [
                Icon(
                  _sectionIcon(section),
                  size: 16,
                  color: selected ? Colors.white : muted,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    _sectionTitle(section),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 10.4,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    CupertinoIcons.check_mark,
                    size: 13,
                    color: Colors.white,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsOverlayCard extends StatelessWidget {
  const _SettingsOverlayCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.onBack,
    required this.onClose,
    this.maxBodyHeight,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback onClose;
  final double? maxBodyHeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final text = isDark ? const Color(0xFFF2F6FF) : AppTheme.text;
    final muted = isDark ? const Color(0xFF9FB0D0) : AppTheme.muted;
    final body = maxBodyHeight == null
        ? child
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxBodyHeight!),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: child,
            ),
          );

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B31) : Colors.white,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: isDark ? const Color(0xFF22304B) : const Color(0xFFDDE6F4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                _SettingsIconButton(
                  icon: CupertinoIcons.chevron_left,
                  onTap: onBack!,
                ),
                const SizedBox(width: 6),
              ],
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Icon(icon, color: primary, size: 17),
              ),
              const SizedBox(width: 9),
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
                        fontSize: 14.2,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        fontSize: 10.2,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SettingsIconButton(
                icon: CupertinoIcons.xmark,
                onTap: onClose,
              ),
            ],
          ),
          const SizedBox(height: 3),
          body,
        ],
      ),
    );
  }
}

class _SettingsIconButton extends StatelessWidget {
  const _SettingsIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14233D) : const Color(0xFFF7F8FD),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: isDark ? const Color(0xFF22304B) : const Color(0xFFE7EAF5),
            ),
          ),
          child: Icon(
            icon,
            color: isDark ? const Color(0xFFE2E8F0) : AppTheme.muted,
            size: 13,
          ),
        ),
      ),
    );
  }
}

class _SettingsMenuButton extends StatelessWidget {
  const _SettingsMenuButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF2F6FF) : AppTheme.text;
    final mutedColor = isDark ? const Color(0xFF9FB0D0) : AppTheme.muted;
    final bgColor = selected
        ? color
        : (isDark ? const Color(0xFF14233D) : const Color(0xFFF8FAFF));
    final bdColor = selected
        ? color
        : (isDark ? const Color(0xFF253653) : const Color(0xFFE4EAF6));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: bdColor),
              boxShadow: [
                if (selected)
                  BoxShadow(
                    color: color.withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.16)
                        : color.withValues(alpha: isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? Colors.white : color,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : textColor,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 120),
                  child: Icon(
                    selected
                        ? CupertinoIcons.check_mark
                        : CupertinoIcons.chevron_right,
                    key: ValueKey<bool>(selected),
                    color: selected ? Colors.white : mutedColor,
                    size: selected ? 15 : 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsOption<T> {
  const _SettingsOption({
    required this.value,
    required this.title,
    required this.description,
    required this.icon,
    this.flag,
    this.currencySymbol,
  });

  final T value;
  final String title;
  final String description;
  final IconData icon;
  final String? flag;
  final String? currencySymbol;
}

class _SettingsOptionGrid<T> extends StatelessWidget {
  const _SettingsOptionGrid({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<_SettingsOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in options)
          _SettingsOptionTile<T>(
            option: option,
            selected: option.value == selected,
            onTap: () => onChanged(option.value),
          ),
      ],
    );
  }
}

class _SettingsOptionTile<T> extends StatelessWidget {
  const _SettingsOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _SettingsOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final text = isDark ? const Color(0xFFF2F6FF) : AppTheme.text;
    final selectedBg =
        isDark ? const Color(0xFF16233A) : const Color(0xFFF4F6FA);
    final flag = option.flag;
    final currencySymbol = option.currencySymbol;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: flag != null ? Colors.transparent : primary,
                  shape: flag != null ? BoxShape.rectangle : BoxShape.circle,
                ),
                child: flag != null
                    ? _SettingsCountryFlag(code: flag)
                    : currencySymbol != null
                        ? _SettingsCurrencySymbol(
                            symbol: currencySymbol,
                            selected: selected,
                          )
                        : Icon(
                            option.icon,
                            color: Colors.white,
                            size: 13,
                          ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  option.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 12.8,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCountryFlag extends StatelessWidget {
  const _SettingsCountryFlag({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 24,
      height: 18,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3A58) : const Color(0xFFD5DCEA),
          width: 0.7,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(1.4),
        child: CustomPaint(
          painter: _SettingsCountryFlagPainter(code),
        ),
      ),
    );
  }
}

class _SettingsCurrencySymbol extends StatelessWidget {
  const _SettingsCurrencySymbol({
    required this.symbol,
    required this.selected,
  });

  final String symbol;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = selected
        ? primary
        : (isDark ? const Color(0xFF9FB0D0) : const Color(0xFF64748B));

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        symbol,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: symbol.length > 1 ? 9.2 : 14,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _SettingsCurrencyOptionList extends StatelessWidget {
  const _SettingsCurrencyOptionList({
    required this.selectedCurrency,
    required this.onChanged,
  });

  final String selectedCurrency;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsCurrencyOptionRow(
          code: 'XOF',
          label: 'XOF - FCFA BCEAO',
          symbol: 'CFA',
          color: const Color(0xFF12BBD2),
          selected: true,
          onTap: () => onChanged('XOF'),
        ),
        const _SettingsCurrencyOptionRow(
          code: 'EUR',
          label: 'EUR - Euro (Indisponible)',
          symbol: '€',
          color: Color(0xFF2563EB),
          selected: false,
          onTap: null,
        ),
        const _SettingsCurrencyOptionRow(
          code: 'USD',
          label: 'USD - Dollar américain (Indisponible)',
          symbol: r'$',
          color: Color(0xFF10B981),
          selected: false,
          onTap: null,
        ),
      ],
    );
  }
}

class _SettingsCurrencyOptionRow extends StatelessWidget {
  const _SettingsCurrencyOptionRow({
    required this.code,
    required this.label,
    required this.symbol,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String label;
  final String symbol;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = onTap == null;
    final text = isDark
        ? const Color(0xFFF2F6FF).withValues(alpha: disabled ? 0.35 : 1.0)
        : AppTheme.text.withValues(alpha: disabled ? 0.35 : 1.0);
    final selectedBg =
        isDark ? const Color(0xFF16233A) : const Color(0xFFF4F6FA);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: disabled ? color.withValues(alpha: 0.3) : color,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  symbol,
                  maxLines: 1,
                  style: TextStyle(
                    color: disabled ? Colors.white.withValues(alpha: 0.5) : Colors.white,
                    fontSize: symbol.length > 1 ? 7.9 : 12,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 12.8,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCountryFlagPainter extends CustomPainter {
  const _SettingsCountryFlagPainter(this.code);

  final String code;

  @override
  void paint(Canvas canvas, Size size) {
    final normalized = code.toUpperCase();
    if (normalized == 'GB') {
      _paintUnitedKingdom(canvas, size);
      return;
    }
    _paintFrance(canvas, size);
  }

  void _paintFrance(Canvas canvas, Size size) {
    final third = size.width / 3;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, third, size.height),
      Paint()..color = const Color(0xFF1F4E9D),
    );
    canvas.drawRect(
      Rect.fromLTWH(third, 0, third, size.height),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      Rect.fromLTWH(third * 2, 0, third, size.height),
      Paint()..color = const Color(0xFFE23A45),
    );
  }

  void _paintUnitedKingdom(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF1E3D7A));

    final whiteDiagonal = Paint()
      ..color = Colors.white
      ..strokeWidth = size.height * 0.34
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
        Offset.zero, Offset(size.width, size.height), whiteDiagonal);
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(0, size.height),
      whiteDiagonal,
    );

    final redDiagonal = Paint()
      ..color = const Color(0xFFE43D4B)
      ..strokeWidth = size.height * 0.16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), redDiagonal);
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(0, size.height),
      redDiagonal,
    );

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width,
        height: size.height * 0.40,
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.28,
        height: size.height,
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width,
        height: size.height * 0.20,
      ),
      Paint()..color = const Color(0xFFE43D4B),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.14,
        height: size.height,
      ),
      Paint()..color = const Color(0xFFE43D4B),
    );
  }

  @override
  bool shouldRepaint(covariant _SettingsCountryFlagPainter oldDelegate) {
    return oldDelegate.code != code;
  }
}

class _SettingsAccentChoice {
  const _SettingsAccentChoice(this.label, this.color);

  final String label;
  final Color color;
}

const List<_SettingsAccentChoice> _settingsAccentColors = [
  _SettingsAccentChoice('Bleu finance', Color(0xFF2563EB)),
  _SettingsAccentChoice('Indigo', Color(0xFF4F46E5)),
  _SettingsAccentChoice('Émeraude', Color(0xFF059669)),
  _SettingsAccentChoice('Cyan', Color(0xFF0891B2)),
  _SettingsAccentChoice('Violet', Color(0xFF7C3AED)),
  _SettingsAccentChoice('Crimson', Color(0xFFE11D48)),
];

class _SettingsColorTile extends StatelessWidget {
  const _SettingsColorTile({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? const Color(0xFFF2F6FF) : AppTheme.text;
    final selectedBg =
        isDark ? const Color(0xFF16233A) : const Color(0xFFF4F6FA);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 12.8,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsServiceTile extends StatelessWidget {
  const _SettingsServiceTile({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final text = isDark ? const Color(0xFFF2F6FF) : AppTheme.text;

    return Material(
      color: Colors.transparent,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(2)),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 13),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: text,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _sectionTitle(_SettingsOverlaySection section) {
  return switch (section) {
    _SettingsOverlaySection.language => 'Langue',
    _SettingsOverlaySection.currencies => 'Devises',
    _SettingsOverlaySection.theme => 'Thème Mode',
    _SettingsOverlaySection.font => 'Font de police',
    _SettingsOverlaySection.colors => 'Couleurs principales',
    _SettingsOverlaySection.services => 'Services',
    _SettingsOverlaySection.menu => 'Paramètres',
  };
}

String _sectionSubtitle(_SettingsOverlaySection section) {
  return switch (section) {
    _SettingsOverlaySection.language => 'Choisir la langue de travail',
    _SettingsOverlaySection.currencies => 'Devise d’affichage',
    _SettingsOverlaySection.theme => 'Choisir le mode visuel',
    _SettingsOverlaySection.font => 'Choisir la police de l’interface',
    _SettingsOverlaySection.colors => 'Couleur de sélection et accents',
    _SettingsOverlaySection.services => 'Informations essentielles',
    _SettingsOverlaySection.menu => 'Choisir une rubrique',
  };
}

IconData _sectionIcon(_SettingsOverlaySection section) {
  return switch (section) {
    _SettingsOverlaySection.language => CupertinoIcons.globe,
    _SettingsOverlaySection.currencies => CupertinoIcons.creditcard,
    _SettingsOverlaySection.theme => CupertinoIcons.circle_lefthalf_fill,
    _SettingsOverlaySection.font => CupertinoIcons.textformat_size,
    _SettingsOverlaySection.colors => CupertinoIcons.paintbrush,
    _SettingsOverlaySection.services => CupertinoIcons.info_circle,
    _SettingsOverlaySection.menu => CupertinoIcons.slider_horizontal_3,
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

IconData _iconForModule(AppModule module) {
  return module.icon;
}

/// Barre supérieure de l'espace de travail.
class _WorkspaceTopBar extends StatelessWidget {
  const _WorkspaceTopBar({
    required this.selectedModule,
    required this.onReturnToWelcome,
    required this.portfolioDisplayCurrency,
    required this.portfolioAmountUnit,
  });

  final AppModule selectedModule;
  final VoidCallback onReturnToWelcome;
  final ValueNotifier<String> portfolioDisplayCurrency;
  final ValueNotifier<PortfolioAmountUnit> portfolioAmountUnit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 66,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F1B31).withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: isDark ? const Color(0xFF22304B) : const Color(0xFFE7EAF5),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x26040A16) : const Color(0x0D0F172A),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Ces seuils permettent de simplifier progressivement la barre sur des largeurs réduites.
          final showActionButtons = constraints.maxWidth >= 1380;
          final showHeaderStatus = constraints.maxWidth >= 1080;

          return Row(
            children: [
              // La marque reste à gauche pour ancrer la lecture de l'application.
              const _ShellBrand(),
              const Spacer(),
              // Identité de session et gestion d'équipe. L'application a DEUX
              // barres d'en-tête — celle-ci pour le poste de travail, _TopBar
              // pour les écrans étroits. Les deux doivent porter la zone
              // compte, sinon la gestion d'équipe n'apparaît que sur l'une
              // des deux : c'est ce qui la rendait visible au téléphone et
              // introuvable sur ordinateur.
              const _ZoneCompte(),
              _HeaderIconButton(
                icon: CupertinoIcons.circle_grid_3x3_fill,
                accent: Theme.of(context).colorScheme.primary,
                onPressed: onReturnToWelcome,
              ),
              const SizedBox(width: 6),
              if (showHeaderStatus) ...[
                const SizedBox(width: 6),
              ],
              _PortfolioAmountUnitPicker(
                  amountUnitListenable: portfolioAmountUnit),
              const SizedBox(width: 6),
              _PortfolioCurrencyPicker(
                selectedCurrencyListenable: portfolioDisplayCurrency,
              ),
              if (showActionButtons) ...[
                // Les actions secondaires et primaires ne s'affichent que sur les écrans larges.
                const SizedBox(width: 8),
                _HeaderGhostButton(
                  label: context.tr('Exporter'),
                  icon: CupertinoIcons.arrow_down_doc_fill,
                ),
                const SizedBox(width: 6),
                _HeaderPrimaryButton(
                  label: context.tr('Nouvelle analyse'),
                  icon: CupertinoIcons.plus,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Bloc de marque affiché dans la barre supérieure.
class _ShellBrand extends StatelessWidget {
  const _ShellBrand();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF14233D)
                : Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(AppTheme.radius),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.14)
                    : const Color(0xFF234A84).withValues(alpha: 0.055),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const DesktopAssetImage(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(width: 3),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Risk management'),
              style: TextStyle(
                color:
                    isDark ? const Color(0xFFC9D6FF) : const Color(0xFF123A73),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 0.1),
            Text(
              context.tr('Outil de pilotage des fonds propres'),
              style: TextStyle(
                color:
                    isDark ? const Color(0xFF8FA0BC) : const Color(0xFF365F9A),
                fontSize: 10.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Cadre qui positionne la sidebar sur desktop.
class _DesktopSidebarFrame extends StatelessWidget {
  const _DesktopSidebarFrame({
    required this.compact,
    required this.width,
    required this.selectedModule,
    required this.onSelectModule,
    this.onSelectSettingsSection,
    this.selectedSettingsSectionId,
    this.showBrand = false,
    this.showToggleButton = false,
    this.onToggleSidebar,
  });

  final bool compact;
  final double width;
  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelectModule;
  final ValueChanged<SettingsSectionSelection>? onSelectSettingsSection;
  final String? selectedSettingsSectionId;
  final bool showBrand;
  final bool showToggleButton;
  final VoidCallback? onToggleSidebar;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: width,
        child: ClipRect(
          child: SidebarNavigation(
            selectedModule: selectedModule,
            onSelectModule: onSelectModule,
            onSelectSettingsSection: onSelectSettingsSection,
            selectedSettingsSectionId: selectedSettingsSectionId,
            compact: compact,
            showBrand: showBrand,
            contentTopInset: 0,
            headerTrailing: showToggleButton && onToggleSidebar != null
                ? _SidebarToggleButton(
                    compact: compact,
                    onTap: onToggleSidebar!,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Bouton qui replie ou déplie la sidebar.
class _SidebarToggleButton extends StatelessWidget {
  const _SidebarToggleButton({required this.compact, required this.onTap});

  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TooltipVisibility(
      visible: compact,
      child: SizedBox(
        width: _sidebarToggleHitArea,
        height: _sidebarToggleHitArea,
        child: Tooltip(
          message: 'Ouvrir le menu',
          waitDuration: const Duration(milliseconds: 160),
          showDuration: const Duration(milliseconds: 1500),
          preferBelow: false,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7.0),
          decoration: BoxDecoration(
            color: const Color(0xFF102A55),
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: const Color(0xFF2F5D9F)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2A0F172A),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.05,
          ),
          child: Center(
            child: Material(
              color: isDark ? const Color(0xFF14233D) : Colors.white,
              borderRadius: BorderRadius.circular(_sidebarToggleButtonRadius),
              elevation: 3,
              shadowColor:
                  isDark ? const Color(0x33040A16) : const Color(0x150F172A),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(
                  _sidebarToggleButtonRadius,
                ),
                child: Container(
                  width: _sidebarToggleButtonWidth,
                  height: _sidebarToggleButtonHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      _sidebarToggleButtonRadius,
                    ),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2A3C5E)
                          : const Color(0xFFD9E4F6),
                    ),
                  ),
                  child: Icon(
                    compact
                        ? CupertinoIcons.chevron_right
                        : CupertinoIcons.chevron_left,
                    color: isDark
                        ? const Color(0xFFD7E3FA)
                        : const Color(0xFF47619C),
                    size: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PortfolioAmountUnitPicker extends StatelessWidget {
  const _PortfolioAmountUnitPicker({required this.amountUnitListenable});

  final ValueNotifier<PortfolioAmountUnit> amountUnitListenable;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<PortfolioAmountUnit>(
      valueListenable: amountUnitListenable,
      builder: (context, selectedUnit, _) {
        return PopupMenuButton<PortfolioAmountUnit>(
          tooltip: '',
          padding: EdgeInsets.zero,
          onSelected: (value) {
            if (value == selectedUnit) return;
            amountUnitListenable.value = value;
          },
          offset: const Offset(0, _workspaceTopBarControlHeight + 8),
          color: isDark ? const Color(0xFF14233D) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_workspaceTopBarControlRadius),
            side: BorderSide(
              color: isDark ? const Color(0xFF22304B) : const Color(0xFFE7EAF5),
            ),
          ),
          itemBuilder: (context) => [
            _buildAmountUnitMenuItem(
              unit: PortfolioAmountUnit.thousand,
              title: 'Mille',
              detail: 'k',
              selected: selectedUnit == PortfolioAmountUnit.thousand,
              isDark: isDark,
              accentColor: Theme.of(context).colorScheme.primary,
            ),
            _buildAmountUnitMenuItem(
              unit: PortfolioAmountUnit.million,
              title: 'Million',
              detail: 'M',
              selected: selectedUnit == PortfolioAmountUnit.million,
              isDark: isDark,
              accentColor: Theme.of(context).colorScheme.primary,
            ),
            _buildAmountUnitMenuItem(
              unit: PortfolioAmountUnit.billion,
              title: 'Milliard',
              detail: 'Md',
              selected: selectedUnit == PortfolioAmountUnit.billion,
              isDark: isDark,
              accentColor: Theme.of(context).colorScheme.primary,
            ),
          ],
          child: Container(
            height: _workspaceTopBarControlHeight,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14233D) : const Color(0xFFF7F8FD),
              borderRadius:
                  BorderRadius.circular(_workspaceTopBarControlRadius),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF22304B) : const Color(0xFFE7EAF5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 15,
                  height: 15,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius:
                        BorderRadius.circular(_workspaceTopBarControlRadius),
                  ),
                  child: const Icon(
                    CupertinoIcons.number,
                    size: 9,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  selectedUnit.label,
                  style: TextStyle(
                    color: isDark ? const Color(0xFFF2F6FF) : AppTheme.text,
                    fontSize: 9.8,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 12,
                  color: isDark ? const Color(0xFFD7E3FA) : AppTheme.muted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PopupMenuItem<PortfolioAmountUnit> _buildAmountUnitMenuItem({
    required PortfolioAmountUnit unit,
    required String title,
    required String detail,
    required bool selected,
    required bool isDark,
    required Color accentColor,
  }) {
    final accent = selected ? accentColor : AppTheme.muted;
    return PopupMenuItem<PortfolioAmountUnit>(
      value: unit,
      height: 38,
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: selected ? 0.14 : 0.08),
              borderRadius:
                  BorderRadius.circular(_workspaceTopBarControlRadius),
            ),
            child: Text(
              detail,
              style: TextStyle(
                color: accent,
                fontSize: detail.length > 1 ? 8.6 : 9.6,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? const Color(0xFFF2F6FF) : AppTheme.text,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sélecteur de devise compact affiché dans la top bar.
class _PortfolioCurrencyPicker extends StatelessWidget {
  const _PortfolioCurrencyPicker({required this.selectedCurrencyListenable});

  final ValueNotifier<String> selectedCurrencyListenable;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: selectedCurrencyListenable,
      builder: (context, selectedCurrency, _) {
        return PopupMenuButton<String>(
          enabled: false,
          tooltip: 'FCFA (XOF) uniquement pour l\'instant',
          padding: EdgeInsets.zero,
          onSelected: (value) {},
          offset: const Offset(0, _workspaceTopBarControlHeight + 8),
          color: isDark ? const Color(0xFF14233D) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_workspaceTopBarControlRadius),
            side: BorderSide(
              color: isDark ? const Color(0xFF22304B) : const Color(0xFFE7EAF5),
            ),
          ),
          itemBuilder: (context) => [],
          child: Container(
            height: _workspaceTopBarControlHeight,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14233D) : const Color(0xFFF7F8FD),
              borderRadius:
                  BorderRadius.circular(_workspaceTopBarControlRadius),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF22304B) : const Color(0xFFE7EAF5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _CurrencyBadge(
                  currencyCode: 'XOF',
                  size: 15,
                ),
                const SizedBox(width: 5),
                Text(
                  'XOF',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFF2F6FF).withValues(alpha: 0.5)
                        : AppTheme.text.withValues(alpha: 0.5),
                    fontSize: 9.8,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.lock_outline,
                  size: 10,
                  color: isDark
                      ? const Color(0xFFD7E3FA).withValues(alpha: 0.4)
                      : AppTheme.muted.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CurrencyBadge extends StatelessWidget {
  const _CurrencyBadge({
    required this.currencyCode,
    this.size = 16,
  });

  final String currencyCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeCurrencyCode(currencyCode);
    final symbol = switch (normalized) {
      'XOF' => 'CFA',
      'EUR' => '€',
      'USD' => r'$',
      _ => normalized.length <= 3 ? normalized : normalized.substring(0, 3),
    };
    final color = switch (normalized) {
      'XOF' => const Color(0xFF06B6D4),
      'EUR' => const Color(0xFF2563EB),
      'USD' => const Color(0xFF10B981),
      _ => AppTheme.muted,
    };

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        symbol,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: symbol.length > 1 ? size * 0.34 : size * 0.62,
          fontWeight: FontWeight.w500,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.accent,
    this.onPressed,
  });

  final IconData icon;
  final Color accent;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(_workspaceTopBarControlRadius),
        child: Container(
          width: _workspaceTopBarControlHeight,
          height: _workspaceTopBarControlHeight,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14233D) : const Color(0xFFF7F8FD),
            borderRadius: BorderRadius.circular(_workspaceTopBarControlRadius),
            border: Border.all(
              color: isDark ? const Color(0xFF22304B) : const Color(0xFFE7EAF5),
            ),
          ),
          child: Icon(icon, size: 13, color: accent),
        ),
      ),
    );
  }
}

/// Bouton secondaire au style discret pour la top bar.
class _HeaderGhostButton extends StatelessWidget {
  const _HeaderGhostButton({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14233D) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: isDark ? const Color(0xFF22304B) : const Color(0xFFE7EAF5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? const Color(0xFF8FA0BC) : AppTheme.muted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isDark ? const Color(0xFFD7E0F3) : const Color(0xFF4B556B),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton principal de la top bar pour l'action mise en avant.
class _HeaderPrimaryButton extends StatelessWidget {
  const _HeaderPrimaryButton({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x222563EB),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Structure globale de la barre supérieure.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.selectedModule,
    required this.showMenuButton,
    required this.onReturnToWelcome,
  });

  final AppModule selectedModule;
  final bool showMenuButton;
  final VoidCallback onReturnToWelcome;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B31) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: isDark ? const Color(0xFF22304B) : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          if (showMenuButton)
            Builder(
              builder: (context) => IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
          Icon(
            _iconForModule(selectedModule),
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppTheme.spacing),
          // Le titre cède la place avant que la barre ne déborde : sur un
          // téléphone, « Risque Opérationnel » et les commandes de compte ne
          // tiennent pas ensemble, et ce sont les commandes qui comptent.
          Flexible(
            child: Text(
              selectedModule.title.tr(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFFF2F6FF)
                        : const Color(0xFF1E2337),
                  ),
            ),
          ),
          const Spacer(),
          const _ZoneCompte(),
          _HeaderIconButton(
            icon: CupertinoIcons.circle_grid_3x3_fill,
            accent: Theme.of(context).colorScheme.primary,
            onPressed: onReturnToWelcome,
          ),
        ],
      ),
    );
  }
}

/// Identité de la session et sortie, dans l'en-tête.
///
/// N'apparaît que lorsque le backend impose une authentification : sur un
/// poste de travail local, il n'y a ni compte ni déconnexion possible.
class _ZoneCompte extends StatelessWidget {
  const _ZoneCompte();

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.maybeOf(context);
    if (session == null || !session.authentificationRequise) {
      return const SizedBox.shrink();
    }
    final profil = session.profil;
    if (profil == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    // Sur écran étroit, seules les commandes subsistent : le nom du compte et
    // le badge de rôle poussaient la barre au-delà de sa largeur. Perdre le
    // nom est sans gravité — l'utilisateur sait qui il est ; perdre l'accès à
    // l'équipe ne l'est pas.
    final etroit = MediaQuery.sizeOf(context).width < 700;
    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.spacing),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!etroit) ...
          [
            const BandeauConsultation(),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                profil.nomComplet?.trim().isNotEmpty == true
                    ? profil.nomComplet!
                    : profil.identifiant,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          // La gestion d'équipe n'apparaît qu'aux comptes qui éditent : le
          // serveur refuse la liste aux autres, inutile de la leur proposer.
          if (profil.peutGererEquipe)
            IconButton(
              iconSize: 18,
              tooltip: 'Gérer l\'équipe',
              icon: const Icon(Icons.group_outlined),
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => EquipeDialog(session: session),
              ),
            ),
          IconButton(
            iconSize: 18,
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout_outlined),
            color: theme.colorScheme.onSurfaceVariant,
            onPressed: session.deconnecter,
          ),
        ],
      ),
    );
  }
}
