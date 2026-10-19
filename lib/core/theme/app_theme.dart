import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.textOnAccent,
    secondary: AppColors.accentStrong,
    onSecondary: AppColors.textPrimary,
    surface: AppColors.surfacePrimary,
    onSurface: AppColors.textPrimary,
    error: AppColors.error,
    onError: AppColors.navy,
    outline: AppColors.borderSoft,
  );
  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark, colorScheme: scheme, fontFamily: 'Montserrat');
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bgPrimary,
    textTheme: base.textTheme.apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary),
    splashFactory: InkSparkle.splashFactory,
    focusColor: AppColors.lightBlue.withValues(alpha: 0.18),
    hoverColor: AppColors.lightBlue.withValues(alpha: 0.06),
    dividerTheme: const DividerThemeData(color: AppColors.borderSoft, thickness: 1, space: 1),
    iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.navy : AppColors.textMuted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.accent : AppColors.surfaceElevated),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.accent,
      inactiveTrackColor: AppColors.surfaceElevated,
      thumbColor: AppColors.offWhite,
      overlayColor: Color(0x22B3CFE5),
      trackHeight: 4,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceSecondary,
      contentTextStyle: AppText.bodyMedium.primary,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: const BorderSide(color: AppColors.borderStrong),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceSecondary,
      modalBackgroundColor: AppColors.surfaceSecondary,
      showDragHandle: true,
      dragHandleColor: AppColors.textMuted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xl),
        side: const BorderSide(color: AppColors.borderSoft),
      ),
      titleTextStyle: AppText.h2.primary,
      contentTextStyle: AppText.secondary.secondaryColor,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      hintStyle: TextStyle(color: AppColors.textMuted),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: Color(0x55B3CFE5),
      selectionHandleColor: AppColors.accent,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}
