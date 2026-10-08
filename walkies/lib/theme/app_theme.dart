import 'package:flutter/material.dart';

/// Walkies design system: warm cream surfaces, forest green as the primary
/// colour, terracotta for energy (streaks, progress), Fraunces for headings
/// and Inter for everything else.
class AppPalette {
  static const forest = Color(0xFF2D5A4A);
  static const forestDeep = Color(0xFF1E3D33);
  static const forestSoft = Color(0xFF3F7361);
  static const sage = Color(0xFFDDEEE6);
  static const sageDeep = Color(0xFFC4E0D2);
  static const cream = Color(0xFFFBF6EF);
  static const sand = Color(0xFFF3ECE1);
  static const white = Color(0xFFFFFFFF);
  static const line = Color(0xFFEAE1D4);
  static const terracotta = Color(0xFFD4773D);
  static const terracottaSoft = Color(0xFFFBE6D6);
  static const ink = Color(0xFF1F2E29);
  static const body = Color(0xFF3E534C);
  static const muted = Color(0xFF66796F);
  static const danger = Color(0xFFB3261E);
  static const dangerSoft = Color(0xFFFBE4E1);
  static const warn = Color(0xFF9A5B12);
  static const warnSoft = Color(0xFFFCEFD9);
}

class AppSpacing {
  static const page = EdgeInsets.fromLTRB(20, 8, 20, 32);
  static const gap = 16.0;
  static const radius = 20.0;
  static const radiusSmall = 14.0;
}

class AppTheme {
  static const _sans = 'Inter';
  static const _serif = 'Fraunces';

  static TextTheme _textTheme() {
    const ink = AppPalette.ink;
    TextStyle serif(double size, {FontWeight weight = FontWeight.w600, double height = 1.15}) =>
        TextStyle(
          fontFamily: _serif,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: ink,
          letterSpacing: -0.2,
        );
    TextStyle sans(double size, FontWeight weight, {double height = 1.4, Color color = ink, double spacing = 0}) =>
        TextStyle(
          fontFamily: _sans,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: color,
          letterSpacing: spacing,
        );

    return TextTheme(
      displayLarge: serif(48, height: 1.05),
      displayMedium: serif(40, height: 1.05),
      displaySmall: serif(34, height: 1.1),
      headlineLarge: serif(30),
      headlineMedium: serif(27),
      headlineSmall: serif(23),
      titleLarge: serif(20, height: 1.25),
      titleMedium: sans(16, FontWeight.w600, height: 1.35),
      titleSmall: sans(14, FontWeight.w600, height: 1.35),
      bodyLarge: sans(16, FontWeight.w400, height: 1.55, color: AppPalette.body),
      bodyMedium: sans(14.5, FontWeight.w400, height: 1.5, color: AppPalette.body),
      bodySmall: sans(13, FontWeight.w400, height: 1.45, color: AppPalette.muted),
      labelLarge: sans(15, FontWeight.w600, height: 1.2),
      labelMedium: sans(13, FontWeight.w600, height: 1.2),
      labelSmall: sans(11.5, FontWeight.w700, height: 1.2, color: AppPalette.muted, spacing: 0.9),
    );
  }

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppPalette.forest,
      onPrimary: AppPalette.white,
      primaryContainer: AppPalette.sage,
      onPrimaryContainer: AppPalette.forestDeep,
      secondary: AppPalette.terracotta,
      onSecondary: AppPalette.white,
      secondaryContainer: AppPalette.terracottaSoft,
      onSecondaryContainer: Color(0xFF6B3410),
      tertiary: AppPalette.forestSoft,
      onTertiary: AppPalette.white,
      error: AppPalette.danger,
      onError: AppPalette.white,
      errorContainer: AppPalette.dangerSoft,
      onErrorContainer: Color(0xFF5C1410),
      surface: AppPalette.cream,
      onSurface: AppPalette.ink,
      onSurfaceVariant: AppPalette.muted,
      surfaceContainerLowest: AppPalette.white,
      surfaceContainerLow: AppPalette.white,
      surfaceContainer: AppPalette.sand,
      surfaceContainerHigh: AppPalette.sand,
      surfaceContainerHighest: Color(0xFFEDE4D6),
      outline: Color(0xFFD9CDBC),
      outlineVariant: AppPalette.line,
      shadow: Color(0xFF1E3D33),
      inverseSurface: AppPalette.forestDeep,
      onInverseSurface: AppPalette.white,
      surfaceTint: Colors.transparent,
    );
    final text = _textTheme();
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _sans,
      textTheme: text,
      scaffoldBackgroundColor: AppPalette.cream,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: const DividerThemeData(color: AppPalette.line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: AppPalette.cream,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        foregroundColor: AppPalette.ink,
        titleTextStyle: text.titleLarge!.copyWith(fontSize: 22),
        iconTheme: const IconThemeData(color: AppPalette.ink),
      ),
      cardTheme: CardThemeData(
        color: AppPalette.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          side: const BorderSide(color: AppPalette.line),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppPalette.sage,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontFamily: _sans,
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? AppPalette.forestDeep
                  : AppPalette.muted,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 24,
              color: states.contains(WidgetState.selected)
                  ? AppPalette.forestDeep
                  : AppPalette.muted,
            )),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.forest,
          foregroundColor: AppPalette.white,
          disabledBackgroundColor: const Color(0xFFE3DACB),
          disabledForegroundColor: AppPalette.muted,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: rounded,
          textStyle: text.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.forest,
          foregroundColor: AppPalette.white,
          elevation: 0,
          minimumSize: const Size(64, 48),
          shape: rounded,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.forestDeep,
          backgroundColor: AppPalette.white,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: const BorderSide(color: Color(0xFFD9CDBC)),
          shape: rounded,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.forest,
          textStyle: text.labelLarge,
          shape: rounded,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppPalette.forest,
        foregroundColor: AppPalette.white,
        elevation: 2,
        highlightElevation: 4,
        extendedTextStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: text.bodyMedium!.copyWith(color: AppPalette.muted),
        floatingLabelStyle: text.labelMedium!.copyWith(color: AppPalette.forest),
        hintStyle: text.bodyMedium!.copyWith(color: AppPalette.muted),
        helperStyle: text.bodySmall,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          borderSide: const BorderSide(color: AppPalette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          borderSide: const BorderSide(color: Color(0xFFDDD2C2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          borderSide: const BorderSide(color: AppPalette.forest, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.white,
        selectedColor: AppPalette.forest,
        disabledColor: AppPalette.sand,
        side: const BorderSide(color: AppPalette.line),
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelStyle: const TextStyle(
          fontFamily: _sans,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppPalette.body,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: _sans,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppPalette.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppPalette.white : const Color(0xFFB4A897)),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppPalette.forest : AppPalette.sand),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppPalette.forest : const Color(0xFFD9CDBC)),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: Color(0xFFB9AC99), width: 1.6),
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppPalette.forest : Colors.transparent),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        iconColor: AppPalette.forest,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppPalette.forest,
        linearTrackColor: AppPalette.sand,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.forestDeep,
        contentTextStyle: text.bodyMedium!.copyWith(color: AppPalette.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppPalette.cream,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppPalette.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: text.bodyMedium!.copyWith(color: AppPalette.ink),
      ),
    );
  }
}
