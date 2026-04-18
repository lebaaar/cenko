import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const primary = Color(0xFF006760);
  static const primaryDim = Color(0xFF005A54);
  static const accent = Color(0xFF2E8D84);

  static const surface = Color(0xFFF5F6F7);
  static const surfaceLow = Color(0xFFEFF1F2);
  static const surfaceLowest = Color(0xFFFFFFFF);
  static const surfaceContainer = Color(0xFFE8EBEC);
  static const surfaceHigh = Color(0xFFE0E3E4);
  static const surfaceHighest = Color(0xFFD7DBDC);
  static const surfaceBright = Color(0xFFFBFCFD);
  static const surfaceDim = Color(0xFFE1E4E5);

  static const onSurface = Color(0xFF2C2F30);
  static const onSurfaceVariant = Color(0xFF595C5D);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF9BEFE4);
  static const onPrimaryContainer = Color(0xFF00201D);
  static const secondary = Color(0xFF46635F);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFC8E9E3);
  static const onSecondaryContainer = Color(0xFF00201D);
  static const tertiary = Color(0xFF296B73);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFFB3ECF5);
  static const onTertiaryContainer = Color(0xFF001F24);

  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF410002);

  static const outline = Color(0xFF747877);
  static const outlineVariant = Color(0xFFABADAE);
  static const outlineVariantDim = Color(0x66ABADAE);
  static const inverseSurface = Color(0xFF313334);
  static const onInverseSurface = Color(0xFFF2F1F1);
  static const inversePrimary = Color(0xFF7CD0C6);
  static const shadow = Color(0x26006760);
  static const scrim = Color(0x33000000);

  static const darkSurface = Color(0xFF131718);
  static const darkSurfaceBright = Color(0xFF353A3B);
  static const darkSurfaceDim = Color(0xFF0F1314);
  static const darkSurfaceLowest = Color(0xFF0A0D0E);
  static const darkSurfaceLow = Color(0xFF1A1F20);
  static const darkSurfaceContainer = Color(0xFF1F2426);
  static const darkSurfaceHigh = Color(0xFF24292B);
  static const darkSurfaceHighest = Color(0xFF2E3435);

  static const darkOnSurface = Color(0xFFE4E8E8);
  static const darkOnSurfaceVariant = Color(0xFFC0C5C5);
  static const darkOnPrimary = Color(0xFF003733);
  static const darkPrimaryContainer = Color(0xFF005049);
  static const darkOnPrimaryContainer = Color(0xFF9BEFE4);
  static const darkSecondary = Color(0xFFACCFC9);
  static const darkOnSecondary = Color(0xFF163733);
  static const darkSecondaryContainer = Color(0xFF2E4B47);
  static const darkOnSecondaryContainer = Color(0xFFC8E9E3);
  static const darkTertiary = Color(0xFF95D0D9);
  static const darkOnTertiary = Color(0xFF00363D);
  static const darkTertiaryContainer = Color(0xFF114D55);
  static const darkOnTertiaryContainer = Color(0xFFB3ECF5);

  static const darkError = Color(0xFFFFB4AB);
  static const darkOnError = Color(0xFF690005);
  static const darkErrorContainer = Color(0xFF93000A);
  static const darkOnErrorContainer = Color(0xFFFFDAD6);

  static const darkOutline = Color(0xFF8A9291);
  static const darkOutlineVariant = Color(0xFF737A7A);
  static const darkOutlineVariantDim = Color(0x66737A7A);
  static const darkInverseSurface = Color(0xFFE4E8E8);
  static const darkOnInverseSurface = Color(0xFF2A2F30);
  static const darkInversePrimary = Color(0xFF006760);
  static const darkShadow = Color(0x33000000);
  static const darkScrim = Color(0x66000000);
}

abstract final class AppTheme {
  static ThemeData light() {
    return _buildTheme(isDark: false);
  }

  static ThemeData dark() {
    return _buildTheme(isDark: true);
  }

  static ThemeData _buildTheme({required bool isDark}) {
    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
    final colorScheme = _colorScheme(isDark: isDark);
    final textTheme = _textTheme(base.textTheme, onSurface: colorScheme.onSurface, onSurfaceVariant: colorScheme.onSurfaceVariant);

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      appBarTheme: _appBarTheme(colorScheme: colorScheme),
      inputDecorationTheme: _inputDecorationTheme(colorScheme: colorScheme),
      cardTheme: CardThemeData(color: colorScheme.surfaceContainerLow, elevation: 0, margin: EdgeInsets.zero),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant.withValues(alpha: 0.15), thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary.withValues(alpha: 0.35);
          return colorScheme.surfaceContainerHighest;
        }),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          textStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    );
  }

  static ColorScheme _colorScheme({required bool isDark}) {
    final seed = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: isDark ? Brightness.dark : Brightness.light);
    if (isDark) {
      return seed.copyWith(
        primary: AppColors.primary,
        onPrimary: AppColors.darkOnPrimary,
        primaryContainer: AppColors.darkPrimaryContainer,
        onPrimaryContainer: AppColors.darkOnPrimaryContainer,
        secondary: AppColors.darkSecondary,
        onSecondary: AppColors.darkOnSecondary,
        secondaryContainer: AppColors.darkSecondaryContainer,
        onSecondaryContainer: AppColors.darkOnSecondaryContainer,
        tertiary: AppColors.darkTertiary,
        onTertiary: AppColors.darkOnTertiary,
        tertiaryContainer: AppColors.darkTertiaryContainer,
        onTertiaryContainer: AppColors.darkOnTertiaryContainer,
        error: AppColors.darkError,
        onError: AppColors.darkOnError,
        errorContainer: AppColors.darkErrorContainer,
        onErrorContainer: AppColors.darkOnErrorContainer,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkOnSurface,
        surfaceContainerLowest: AppColors.darkSurfaceLowest,
        surfaceContainerLow: AppColors.darkSurfaceLow,
        surfaceContainer: AppColors.darkSurfaceContainer,
        surfaceContainerHigh: AppColors.darkSurfaceHigh,
        surfaceContainerHighest: AppColors.darkSurfaceHighest,
        surfaceDim: AppColors.darkSurfaceDim,
        surfaceBright: AppColors.darkSurfaceBright,
        onSurfaceVariant: AppColors.darkOnSurfaceVariant,
        outline: AppColors.darkOutline,
        outlineVariant: AppColors.darkOutlineVariant,
        shadow: AppColors.darkShadow,
        scrim: AppColors.darkScrim,
        inverseSurface: AppColors.darkInverseSurface,
        onInverseSurface: AppColors.darkOnInverseSurface,
        inversePrimary: AppColors.darkInversePrimary,
        surfaceTint: AppColors.primary,
      );
    }

    return seed.copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      surfaceContainerLowest: AppColors.surfaceLowest,
      surfaceContainerLow: AppColors.surfaceLow,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceHigh,
      surfaceContainerHighest: AppColors.surfaceHighest,
      surfaceDim: AppColors.surfaceDim,
      surfaceBright: AppColors.surfaceBright,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      shadow: AppColors.shadow,
      scrim: AppColors.scrim,
      inverseSurface: AppColors.inverseSurface,
      onInverseSurface: AppColors.onInverseSurface,
      inversePrimary: AppColors.inversePrimary,
      surfaceTint: AppColors.primary,
    );
  }

  static TextTheme _textTheme(TextTheme base, {required Color onSurface, required Color onSurfaceVariant}) {
    TextStyle style({required double size, required FontWeight weight, required Color color, required double height, double letterSpacing = 0}) {
      return GoogleFonts.manrope(fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: letterSpacing);
    }

    return GoogleFonts.manropeTextTheme(base).copyWith(
      displayLarge: style(size: 57, weight: FontWeight.w800, color: onSurface, height: 1.12, letterSpacing: -0.8),
      displayMedium: style(size: 45, weight: FontWeight.w800, color: onSurface, height: 1.16, letterSpacing: -0.4),
      displaySmall: style(size: 36, weight: FontWeight.w700, color: onSurface, height: 1.22, letterSpacing: -0.2),
      headlineLarge: style(size: 32, weight: FontWeight.w700, color: onSurface, height: 1.25),
      headlineMedium: style(size: 28, weight: FontWeight.w700, color: onSurface, height: 1.29),
      headlineSmall: style(size: 24, weight: FontWeight.w700, color: onSurface, height: 1.33),
      titleLarge: style(size: 22, weight: FontWeight.w600, color: onSurface, height: 1.27),
      titleMedium: style(size: 16, weight: FontWeight.w600, color: onSurface, height: 1.38),
      titleSmall: style(size: 14, weight: FontWeight.w600, color: onSurface, height: 1.43),
      bodyLarge: style(size: 16, weight: FontWeight.w400, color: onSurface, height: 1.50),
      bodyMedium: style(size: 14, weight: FontWeight.w400, color: onSurfaceVariant, height: 1.43),
      bodySmall: style(size: 12, weight: FontWeight.w400, color: onSurfaceVariant, height: 1.33),
      labelLarge: style(size: 14, weight: FontWeight.w600, color: onSurface, height: 1.43, letterSpacing: 0.1),
      labelMedium: style(size: 12, weight: FontWeight.w600, color: onSurfaceVariant, height: 1.33, letterSpacing: 0.4),
      labelSmall: style(size: 11, weight: FontWeight.w600, color: onSurfaceVariant, height: 1.27, letterSpacing: 0.4),
    );
  }

  static InputDecorationTheme _inputDecorationTheme({required ColorScheme colorScheme}) {
    return InputDecorationTheme(
      filled: false,
      labelStyle: GoogleFonts.manrope(color: colorScheme.onSurfaceVariant, fontSize: 14),
      floatingLabelStyle: GoogleFonts.manrope(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w500),
      border: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.45))),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.45))),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.primary, width: 2)),
      errorBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.error.withValues(alpha: 0.8))),
      focusedErrorBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.error, width: 2)),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
    );
  }

  static AppBarTheme _appBarTheme({required ColorScheme colorScheme}) {
    return AppBarTheme(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    );
  }
}
