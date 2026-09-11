import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_semantic_colors.dart';
import 'app_text_styles.dart';

/// مصدر الثيم الموحد للتطبيق.
///
/// يوفر:
/// - [light]: ThemeData كامل للوضع الفاتح
/// - [dark]:  ThemeData كامل للوضع الداكن
/// - الـ ColorScheme، الـ TextTheme، الـ Semantic Colors
/// - Themes لكل المكونات (أزرار، حقول، بطاقات، جداول، تنقل، حوارات...)
abstract final class AppTheme {
  static const fontFamily = 'Cairo';

  // ============================================================
  // LIGHT
  // ============================================================
  static ThemeData light() {
    final scheme = _lightScheme();
    final textTheme = AppTextStyles.textTheme(
      onSurface: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
    );
    return _theme(
      brightness: Brightness.light,
      scheme: scheme,
      textTheme: textTheme,
      semantic: AppSemanticColors.light,
    );
  }

  // ============================================================
  // DARK
  // ============================================================
  static ThemeData dark() {
    final scheme = _darkScheme();
    final textTheme = AppTextStyles.textTheme(
      onSurface: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
    );
    return _theme(
      brightness: Brightness.dark,
      scheme: scheme,
      textTheme: textTheme,
      semantic: AppSemanticColors.dark,
    );
  }

  static ColorScheme _lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDCE8FF),
      onPrimaryContainer: Color(0xFF0B2E78),
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE2E8F0),
      onSecondaryContainer: Color(0xFF1E293B),
      tertiary: AppColors.tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFD7F0FA),
      onTertiaryContainer: Color(0xFF073B4C),
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF7F1D1D),
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: AppColors.background,
      surfaceContainer: AppColors.surfaceMuted,
      surfaceContainerHigh: Color(0xFFE9EEF5),
      surfaceContainerHighest: Color(0xFFE2E8F0),
      onSurfaceVariant: AppColors.textSecondary,
      outline: Color(0xFF94A3B8),
      outlineVariant: AppColors.border,
      inverseSurface: AppColors.textPrimary,
      onInverseSurface: Colors.white,
      inversePrimary: Color(0xFFB5C8FF),
      shadow: Colors.black,
      scrim: Colors.black,
    );
  }

  static ColorScheme _darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColorsDark.primary,
      onPrimary: Color(0xFF0B2A66),
      primaryContainer: Color(0xFF1B3E8C),
      onPrimaryContainer: Color(0xFFD8E6FF),
      secondary: AppColorsDark.secondary,
      onSecondary: Color(0xFF25313F),
      secondaryContainer: Color(0xFF3A4757),
      onSecondaryContainer: Color(0xFFDAE4EE),
      tertiary: AppColorsDark.tertiary,
      onTertiary: Color(0xFF063546),
      tertiaryContainer: Color(0xFF0E4A5F),
      onTertiaryContainer: Color(0xFFC7EAF9),
      error: AppColorsDark.error,
      onError: Color(0xFF420E0E),
      errorContainer: Color(0xFF5F1A1A),
      onErrorContainer: Color(0xFFFECACA),
      surface: AppColorsDark.surface,
      onSurface: AppColorsDark.textPrimary,
      surfaceContainerLowest: AppColorsDark.background,
      surfaceContainerLow: Color(0xFF0F1729),
      surfaceContainer: AppColorsDark.surfaceMuted,
      surfaceContainerHigh: Color(0xFF1B2944),
      surfaceContainerHighest: Color(0xFF223350),
      onSurfaceVariant: AppColorsDark.textSecondary,
      outline: Color(0xFF3B4C68),
      outlineVariant: AppColorsDark.border,
      inverseSurface: AppColorsDark.textPrimary,
      onInverseSurface: AppColorsDark.background,
      inversePrimary: AppColors.primary,
      shadow: Colors.black,
      scrim: Colors.black,
    );
  }

  // ============================================================
  // BUILD COMMON THEME
  // ============================================================
  static ThemeData _theme({
    required Brightness brightness,
    required ColorScheme scheme,
    required TextTheme textTheme,
    required AppSemanticColors semantic,
  }) {
    final isDark = brightness == Brightness.dark;
    final inputFill = isDark ? scheme.surfaceContainer : scheme.surface;
    final cardRadius = AppRadius.card;
    final controlRadius = AppRadius.medium;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      extensions: [semantic],

      // ===== AppBar =====
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontFamily: fontFamily,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),

      // ===== Cards =====
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      // ===== Inputs =====
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        helperStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.error)
                ? scheme.error
                : scheme.primary,
          ),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.25),
        selectionHandleColor: scheme.primary,
      ),

      // ===== Buttons =====
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor:
              scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor:
              scheme.onSurface.withValues(alpha: 0.38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor:
              scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor:
              scheme.onSurface.withValues(alpha: 0.38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          backgroundColor: Colors.transparent,
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppSizes.buttonHeightSmall),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size.square(AppSizes.iconButton),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),

      // ===== Lists =====
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
      ),

      // ===== Dividers =====
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: AppSizes.dividerThickness,
        space: AppSizes.dividerThickness,
      ),

      // ===== Chips =====
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainer,
        checkmarkColor: scheme.onPrimaryContainer,
        secondarySelectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurface,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),

      // ===== Dialogs / Sheets =====
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? scheme.surfaceContainerHigh : scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? scheme.surfaceContainerHigh : scheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor:
            isDark ? scheme.surfaceContainerHigh : scheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.large),
          ),
        ),
      ),

      // ===== SnackBar / Tooltip =====
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      bannerTheme: MaterialBannerThemeData(
        backgroundColor:
            isDark ? scheme.surfaceContainerHighest : scheme.surface,
      ),

      // ===== Progress =====
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        circularTrackColor: scheme.surfaceContainerHighest,
        linearTrackColor: scheme.surfaceContainerHighest,
        linearMinHeight: 4,
      ),

      // ===== Navigation =====
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isDark ? scheme.surfaceContainerHigh : scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 2,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        width: 300,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            right: Radius.circular(AppRadius.card),
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        labelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: textTheme.labelLarge,
        dividerColor: scheme.outlineVariant,
      ),

      // ===== Selection controls =====
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: 0.45)
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStatePropertyAll(scheme.outline),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        side: BorderSide(color: scheme.onSurfaceVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small - 4),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),

      // ===== Tables =====
      dataTableTheme: DataTableThemeData(
        headingTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
        ),
        headingRowColor: WidgetStatePropertyAll(
          scheme.surfaceContainer,
        ),
        dataRowColor: WidgetStatePropertyAll(Colors.transparent),
        dividerThickness: AppSizes.dividerThickness,
        dataRowMaxHeight: 52,
        dataRowMinHeight: 44,
        headingRowHeight: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
      ),

      // ===== Menus =====
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
        elevation: 4,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.error,
        textColor: scheme.onError,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            isDark ? scheme.surfaceContainerHigh : scheme.surface,
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
          ),
        ),
      ),
    );
  }
}