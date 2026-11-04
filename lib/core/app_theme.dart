import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const bgTop = Color(0xFF080B18);
  static const bgBottom = Color(0xFF121A35);
  static const bgGlow = Color(0xFF3B2B72);
  static const surface = Color(0xFF172136);
  static const surfaceLight = Color(0xFF25345A);
  static const surfaceElevated = Color(0xFF2E4068);
  static const cyan = Color(0xFF38BDF8);
  static const purple = Color(0xFF9B7BFF);
  static const green = Color(0xFF34D399);
  static const red = Color(0xFFF87171);
  static const white = Color(0xFFFFFFFF);
  static const amber = Color(0xFFFBBF24);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF9DABC5);
  static const glassBorder = Color(0x26FFFFFF);
  static const glassHighlight = Color(0x14FFFFFF);
  static const divider = Color(0x1FFFFFFF);
}

class AppRadii {
  const AppRadii._();

  static const small = 12.0;
  static const control = 16.0;
  static const card = 22.0;
  static const sheet = 28.0;
  static const pill = 999.0;
}

class AppSpacing {
  const AppSpacing._();

  static const page = 10.0;
  static const screenTop = 14.0;
  static const screenBottom = 28.0;
  static const headerTop = 8.0;
  static const section = 22.0;
  static const card = 16.0;
  static const item = 12.0;
  static const dense = 8.0;
}

class AppTextStyles {
  const AppTextStyles._();

  static TextStyle display({Color color = AppColors.textPrimary}) => TextStyle(
    color: color,
    fontSize: 25,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
  );

  static TextStyle pageTitle({Color color = AppColors.textPrimary}) =>
      TextStyle(
        color: color,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      );

  static TextStyle screenTitle({Color color = AppColors.textPrimary}) =>
      TextStyle(
        color: color,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      );

  static TextStyle sectionTitle({Color color = AppColors.textPrimary}) =>
      TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700);

  static TextStyle body({
    Color color = AppColors.textPrimary,
    FontWeight fontWeight = FontWeight.w400,
  }) => TextStyle(color: color, fontSize: 14, fontWeight: fontWeight);

  static TextStyle secondary({
    Color color = AppColors.textSecondary,
    FontWeight fontWeight = FontWeight.w400,
    double fontSize = 12,
  }) => TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight);

  static TextStyle metric({Color color = AppColors.textPrimary}) =>
      TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700);

  static TextStyle caption({
    Color color = AppColors.textSecondary,
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w400,
  }) => TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight);

  static TextStyle button({Color color = Colors.white}) =>
      TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final colorScheme = const ColorScheme.dark(
      primary: AppColors.cyan,
      secondary: AppColors.purple,
      surface: AppColors.surface,
      error: AppColors.red,
      onPrimary: AppColors.textPrimary,
      onSurface: AppColors.textPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
    );

    return base.copyWith(
      textTheme: base.textTheme
          .apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          )
          .copyWith(
            headlineSmall: AppTextStyles.display(),
            titleLarge: AppTextStyles.pageTitle(),
            titleMedium: AppTextStyles.screenTitle(),
            bodyLarge: AppTextStyles.body(),
            bodyMedium: AppTextStyles.body(),
            labelLarge: AppTextStyles.button(),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
        trackOutlineWidth: WidgetStatePropertyAll(0),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.cyan;
          }
          return AppColors.surfaceLight;
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.error)) {
            return AppColors.red.withValues(alpha: .12);
          }
          return states.contains(WidgetState.focused)
              ? AppColors.surfaceLight
              : AppColors.surface;
        }),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide.none,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.textSecondary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide.none,
          backgroundColor: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide.none,
        selectedColor: AppColors.surfaceLight,
        backgroundColor: AppColors.surface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.cyan,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          textStyle: AppTextStyles.button(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.cyan,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        titleTextStyle: AppTextStyles.screenTitle(),
        contentTextStyle: AppTextStyles.body(color: AppColors.textSecondary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        modalBarrierColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        textStyle: AppTextStyles.body(),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.cyan,
        linearTrackColor: AppColors.glassBorder,
        circularTrackColor: AppColors.glassBorder,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.cyan.withValues(alpha: 0.14),
        selectedIconTheme: const IconThemeData(color: AppColors.cyan),
        unselectedIconTheme: const IconThemeData(
          color: AppColors.textSecondary,
        ),
        selectedLabelTextStyle: const TextStyle(
          color: AppColors.cyan,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
    );
  }
}
