import 'package:flutter/material.dart';

import '../config/app_config.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_text_styles.dart';

/// Central Material 3 theme — a single source of truth for the whole product.
///
/// Screens and future features consume colors via `ColorScheme`,
/// typography via `AppTypography`, and spacing/shape via `AppSpacing` /
/// `AppRadius`; no `Color`/`TextStyle` literals are hardcoded in widgets.
/// Brightness variants (light default, dark optional) share the same tokens.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primarySeed,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.primarySeed,
      onPrimary: AppColors.onPrimary,
      secondary: isDark ? AppColors.darkAccent : AppColors.accent,
      secondaryContainer: isDark
          ? const Color(0xFF3A3257)
          : AppColors.accentContainer,
      onSecondaryContainer: isDark
          ? AppColors.darkTextPrimary
          : AppColors.textPrimary,
      surface: isDark ? AppColors.darkSurface : AppColors.surfaceLight,
      surfaceContainerLowest:
          isDark ? AppColors.darkSurface : AppColors.surfaceLight,
      surfaceContainerLow:
          isDark ? AppColors.darkSurfaceVariant : AppColors.canvas,
      surfaceContainer:
          isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainer,
      surfaceContainerHigh:
          isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainer,
      surfaceContainerHighest:
          isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
      error: isDark ? AppColors.darkError : AppColors.error,
      errorContainer:
          isDark ? const Color(0xFF4A2E2B) : AppColors.errorContainer,
      onError: AppColors.onError,
      outline: isDark ? AppColors.darkOutline : AppColors.outline,
      outlineVariant: isDark ? AppColors.darkDivider : AppColors.divider,
    );

    final base = ThemeData(colorScheme: scheme);
    final typography =
        isDark ? AppTypography.dark(base.textTheme) : AppTypography.light(base.textTheme);

    final textTheme = base.textTheme.apply(
      fontFamily: AppConfig.fontFamilyArabic,
      bodyColor: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      displayColor: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
    );

    final fieldLabel = typography.labelSmall.copyWith(
      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
    );

    return base.copyWith(
      extensions: [typography],
      textTheme: textTheme,
      scaffoldBackgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surfaceLight,
        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: typography.sectionTitle,
        iconTheme: IconThemeData(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
        hintStyle: fieldLabel,
        labelStyle: fieldLabel,
        errorStyle: typography.labelSmall.copyWith(color: scheme.error),
        prefixIconColor:
            isDark ? AppColors.darkTextMuted : AppColors.textMuted,
        suffixIconColor:
            isDark ? AppColors.darkTextMuted : AppColors.textMuted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          padding: WidgetStatePropertyAll(
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.m,
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            typography.label.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onPrimary,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          padding: WidgetStatePropertyAll(
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.m,
            ),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
          textStyle: WidgetStatePropertyAll(
            typography.label.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          padding: WidgetStatePropertyAll(
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: AppSpacing.s,
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            typography.label.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surfaceLight,
        titleTextStyle: typography.sectionTitle,
        contentTextStyle: typography.body,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.canvas,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.outline),
        ),
        margin: EdgeInsets.zero,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.textPrimary,
        contentTextStyle: typography.body.copyWith(color: Colors.white),
        actionTextColor: scheme.secondaryContainer,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        side: BorderSide(color: AppColors.outline),
        backgroundColor:
            isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
        labelStyle: typography.labelSmall,
        selectedColor:
            isDark ? AppColors.darkAccent : AppColors.accentContainer,
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkDivider : AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: typography.tableHeader,
        dataTextStyle: typography.table,
        headingRowHeight: AppLayoutTokens.tableHeaderHeight,
        dataRowMaxHeight: AppLayoutTokens.tableRowHeight,
        dataRowMinHeight: AppLayoutTokens.tableRowHeight,
        headingRowColor: WidgetStatePropertyAll(
          isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainer,
        ),
        dataRowColor: WidgetStatePropertyAll(Colors.transparent),
        dividerThickness: 1,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surfaceLight,
        indicatorColor:
            isDark ? const Color(0xFF3A3257) : AppColors.accentContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        selectedLabelTextStyle: typography.label.copyWith(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        unselectedLabelTextStyle: typography.labelSmall,
        labelType: NavigationRailLabelType.all,
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surfaceLight,
        indicatorColor:
            isDark ? const Color(0xFF3A3257) : AppColors.accentContainer,
        labelTextStyle: WidgetStatePropertyAll(typography.label),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 350),
        textStyle: typography.labelSmall.copyWith(color: Colors.white),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceContainer : AppColors.textPrimary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStatePropertyAll(
          isDark ? AppColors.darkTextMuted : AppColors.textMuted.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}