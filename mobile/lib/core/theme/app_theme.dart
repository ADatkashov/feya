import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildFeyaTheme() {
  const scheme = ColorScheme.dark(
    primary: FeyaColors.primary,
    onPrimary: Colors.white,
    secondary: FeyaColors.secondary,
    onSecondary: Colors.white,
    surface: FeyaColors.surface,
    onSurface: FeyaColors.text,
    error: FeyaColors.error,
    onError: Colors.black,
    outline: FeyaColors.border,
    surfaceContainerHighest: FeyaColors.surface2,
  );

  const base = TextStyle(
    fontFamily: 'Inter',
    color: FeyaColors.text,
    letterSpacing: 0,
  );
  final textTheme = TextTheme(
    displaySmall: base.copyWith(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.15,
    ),
    headlineMedium: base.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    headlineSmall: base.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.25,
    ),
    titleLarge: base.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    titleMedium: base.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    titleSmall: base.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    bodyLarge: base.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodyMedium: base.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
    bodySmall: base.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: FeyaColors.textSecondary,
    ),
    labelLarge: base.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
    labelMedium: base.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
    labelSmall: base.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: FeyaColors.textSecondary,
    ),
  );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(FeyaRadius.md),
    borderSide: BorderSide(color: c, width: w),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: FeyaColors.bg,
    canvasColor: FeyaColors.bg,
    fontFamily: 'Inter',
    textTheme: textTheme,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: FeyaColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge,
      iconTheme: const IconThemeData(color: FeyaColors.text),
    ),
    cardTheme: CardThemeData(
      color: FeyaColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: FeyaRadius.card,
        side: const BorderSide(color: FeyaColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: FeyaColors.border,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FeyaColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(FeyaColors.border),
      enabledBorder: border(FeyaColors.border),
      focusedBorder: border(FeyaColors.primary, 1.5),
      errorBorder: border(FeyaColors.error),
      focusedErrorBorder: border(FeyaColors.error, 1.5),
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: FeyaColors.textSecondary,
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: FeyaColors.textSecondary,
      ),
      errorStyle: textTheme.bodySmall?.copyWith(color: FeyaColors.error),
      prefixIconColor: FeyaColors.textSecondary,
      suffixIconColor: FeyaColors.textSecondary,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: FeyaColors.surface,
      selectedColor: FeyaColors.primary.withValues(alpha: 0.18),
      side: const BorderSide(color: FeyaColors.border),
      shape: const StadiumBorder(),
      labelStyle: textTheme.labelMedium,
      padding: const EdgeInsets.symmetric(horizontal: 6),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Colors.white
            : FeyaColors.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? FeyaColors.primary
            : FeyaColors.surface2,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: FeyaColors.surface2,
      contentTextStyle: textTheme.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FeyaRadius.sm),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: FeyaColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(FeyaRadius.lg),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: FeyaColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FeyaRadius.lg),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: FeyaColors.primary,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: FeyaColors.primary,
      selectionHandleColor: FeyaColors.primary,
    ),
  );
}
