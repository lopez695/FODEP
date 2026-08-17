// Ce fichier centralise le theme visuel de l'application.
import 'package:flutter/material.dart';

/// Définit les couleurs, espacements et thèmes partagés de l'interface.
class AppTheme {
  static const String defaultFontFamily = 'Roboto Flex';
  static String fontFamily = defaultFontFamily;
  static String get dataFontFamily => fontFamily;
  static String get titleFontFamily => fontFamily;
  static const List<String> supportedFontFamilies = [
    'Roboto Flex',
    'Aptos',
    'IBM Plex Sans',
    'General Sans',
    'Nunito Sans',
  ];
  static const double radius = 8;
  static const double spacing = 4;
  static const double pagePadding = 4;
  static const double pageGap = 4;
  static const Color sidebar = Color(0xFF11047A);
  static const Color sidebarLight = Color(0xFF190793);
  static const Color accent = Color(0xFF4318FF);
  static const Color success = Color(0xFF05CD99);
  static const Color warning = Color(0xFFFFB547);
  static const Color danger = Color(0xFFEE5D50);
  static const Color background = Color(0xFFF4F7FE);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE9EDF7);
  static const Color text = Color(0xFF1B2559);
  static const Color muted = Color(0xFF707EAE);
  static const Color darkBackground = Color(0xFF081028);
  static const Color darkCard = Color(0xFF111827);
  static const Color darkBorder = Color(0xFF1F2937);
  static const Color darkText = Color(0xFFF8FAFC);
  static const Color darkMuted = Color(0xFF94A3B8);

  static ThemeData buildTheme({
    String fontFamily = defaultFontFamily,
    Color accentColor = accent,
  }) =>
      _buildTheme(
        brightness: Brightness.light,
        scaffoldBackground: background,
        surfaceColor: card,
        borderColor: border,
        textColor: text,
        mutedColor: muted,
        inputFillColor: const Color(0xFFFBFCFF),
        fontFamily: fontFamily,
        accentColor: accentColor,
      );

  static ThemeData buildDarkTheme({
    String fontFamily = defaultFontFamily,
    Color accentColor = accent,
  }) =>
      _buildTheme(
        brightness: Brightness.dark,
        scaffoldBackground: darkBackground,
        surfaceColor: darkCard,
        borderColor: darkBorder,
        textColor: darkText,
        mutedColor: darkMuted,
        inputFillColor: const Color(0xFF111827),
        fontFamily: fontFamily,
        accentColor: accentColor,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color scaffoldBackground,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color mutedColor,
    required Color inputFillColor,
    required String fontFamily,
    required Color accentColor,
  }) {
    AppTheme.fontFamily = fontFamily;
    final baseTextTheme = ThemeData(
      brightness: brightness,
      fontFamily: fontFamily,
    ).textTheme.apply(
          bodyColor: textColor,
          displayColor: textColor,
        );
    final textTheme = _buildTextTheme(baseTextTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      colorScheme: ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: accentColor,
        primary: accentColor,
        surface: surfaceColor,
        onSurface: textColor,
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: brightness == Brightness.light ? 1 : 0,
        shadowColor: const Color(0xFF4318FF).withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(radius)),
          side: brightness == Brightness.dark
              ? BorderSide(color: borderColor, width: 0.5)
              : BorderSide.none,
        ),
      ),
      appBarTheme: AppBarTheme(
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
        toolbarTextStyle: textTheme.titleMedium,
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: textTheme.labelMedium?.copyWith(
          color: textColor,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
        ),
        dataTextStyle: textTheme.bodyMedium?.copyWith(
          color: textColor,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: textTheme.labelLarge?.copyWith(color: textColor),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: mutedColor),
      ),
      popupMenuTheme: PopupMenuThemeData(
        textStyle: textTheme.labelMedium?.copyWith(color: textColor),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: mutedColor,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: mutedColor,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius / 2),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius / 2),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius / 2),
          borderSide: BorderSide(color: accentColor, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius / 2),
          borderSide: const BorderSide(color: danger, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius / 2),
          borderSide: const BorderSide(color: danger),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      scrollbarTheme: const ScrollbarThemeData(
        radius: Radius.circular(999),
        minThumbLength: 36.0,
        thumbColor: WidgetStatePropertyAll<Color?>(Color(0xCC234A84)),
        trackColor: WidgetStatePropertyAll<Color?>(Colors.transparent),
        trackBorderColor: WidgetStatePropertyAll<Color?>(Colors.transparent),
        thickness: WidgetStatePropertyAll<double?>(3.0),
        crossAxisMargin: 2.0,
        mainAxisMargin: 6.0,
      ),
      dividerColor: borderColor,
      iconTheme: IconThemeData(color: textColor),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: _font(base.displayLarge, fontFamily, FontWeight.w600),
      displayMedium: _font(base.displayMedium, fontFamily, FontWeight.w600),
      displaySmall: _font(base.displaySmall, fontFamily, FontWeight.w600),
      headlineLarge: _font(base.headlineLarge, fontFamily, FontWeight.w600),
      headlineMedium: _font(base.headlineMedium, fontFamily, FontWeight.w600),
      headlineSmall: _font(base.headlineSmall, fontFamily, FontWeight.w600),
      titleLarge: _font(base.titleLarge, fontFamily, FontWeight.w600),
      titleMedium: _font(base.titleMedium, fontFamily, FontWeight.w600),
      titleSmall: _font(base.titleSmall, fontFamily, FontWeight.w600),
      labelLarge: _font(base.labelLarge, fontFamily, FontWeight.w600),
      labelMedium: _font(base.labelMedium, fontFamily, FontWeight.w600),
      labelSmall: _font(base.labelSmall, fontFamily, FontWeight.w500),
      bodyLarge: _font(base.bodyLarge, fontFamily, FontWeight.w400),
      bodyMedium: _font(base.bodyMedium, fontFamily, FontWeight.w400),
      bodySmall: _font(base.bodySmall, fontFamily, FontWeight.w400),
    );
  }

  static TextStyle? _font(
    TextStyle? style,
    String fontFamily,
    FontWeight fontWeight,
  ) {
    return style?.copyWith(
      fontFamily: fontFamily,
      fontWeight: fontWeight,
    );
  }
}
