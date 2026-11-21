import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'typography.dart';

/// Material 3 `ThemeData` built only from the tokens (design overhaul §1),
/// so Material widgets across the app inherit the look without per-screen work.
class AppTheme {
  const AppTheme._();

  static ThemeData light({bool devanagari = false}) => build(SaartheeColors.light, devanagari: devanagari);
  static ThemeData dark({bool devanagari = false}) => build(SaartheeColors.dark, devanagari: devanagari);

  /// Hindi and Marathi use Devanagari: no negative tracking, +2 px line height.
  static bool isDevanagari(String lang) => lang == 'hi' || lang == 'mr';

  static ThemeData build(SaartheeColors c, {bool devanagari = false}) {
    final text = AppTypography.textTheme(c, devanagari: devanagari);
    final type = AppTypography.scale(c, devanagari: devanagari);
    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.primary,
      onSecondary: c.onPrimary,
      secondaryContainer: c.surfaceAlt,
      onSecondaryContainer: c.textPrimary,
      tertiary: c.info,
      onTertiary: c.onPrimary,
      error: c.error,
      onError: c.surface,
      errorContainer: c.errorTint,
      onErrorContainer: c.error,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceAlt,
      surfaceContainerHighest: c.surfaceAlt,
      outline: c.borderStrong,
      outlineVariant: c.border,
      shadow: c.shadow,
      scrim: NeemFixed.scrim,
      inverseSurface: c.primaryDark,
      onInverseSurface: c.onToast,
      inversePrimary: c.primaryContainer,
      surfaceTint: NeemFixed.transparent,
    );

    // No ripple: a subtle grey highlight while pressed, a lighter one on hover.
    final pressed = c.textPrimary.withValues(alpha: 0.08);
    final hover = c.textPrimary.withValues(alpha: 0.04);
    WidgetStateProperty<Color?> overlay([Color? onColor]) => WidgetStateProperty.resolveWith((s) {
      final base = onColor ?? c.textPrimary;
      if (s.contains(WidgetState.pressed)) return base.withValues(alpha: onColor == null ? 0.08 : 0.16);
      if (s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)) return base.withValues(alpha: 0.06);
      return null;
    });
    final focusSide = BorderSide(color: c.focusRing, width: AppSpacing.focusWidth);
    WidgetStateProperty<BorderSide?> focusOnly([BorderSide? rest]) =>
        WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.focused) ? focusSide : rest);

    final buttonText = text.labelLarge!;
    const pillShape = StadiumBorder();
    const buttonSize = Size(AppSpacing.touchTarget, AppSpacing.buttonHeight);
    const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpacing.s24, vertical: AppSpacing.s12);
    OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: AppRadii.controlRadius,
      borderSide: BorderSide(color: color, width: width),
    );
    final noBorder = OutlineInputBorder(borderRadius: AppRadii.controlRadius, borderSide: BorderSide.none);
    final statusBar = c.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      extensions: [c, type],
      textTheme: text,
      fontFamily: AppTypography.body,
      fontFamilyFallback: AppTypography.fallback,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      dividerColor: c.border,
      focusColor: hover,
      hoverColor: hover,
      highlightColor: pressed,
      splashColor: NeemFixed.transparent,
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: c.textPrimary, size: AppSpacing.iconSize),
      appBarTheme: AppBarTheme(
        backgroundColor: NeemFixed.transparent,
        foregroundColor: c.textPrimary,
        surfaceTintColor: NeemFixed.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.gutter,
        titleTextStyle: type.title,
        iconTheme: IconThemeData(color: c.textPrimary),
        actionsIconTheme: IconThemeData(color: c.textPrimary),
        systemOverlayStyle: statusBar.copyWith(statusBarColor: NeemFixed.transparent),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.surfacePressed,
          disabledForegroundColor: c.textDisabled,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: pillShape,
          textStyle: buttonText,
          elevation: 0,
          animationDuration: AppMotion.quick,
        ).copyWith(overlayColor: overlay(c.onPrimary), side: focusOnly()),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.surfaceAlt,
          foregroundColor: c.textPrimary,
          disabledBackgroundColor: c.surfaceAlt,
          disabledForegroundColor: c.textDisabled,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: pillShape,
          textStyle: buttonText,
          elevation: 0,
        ).copyWith(overlayColor: overlay(), side: focusOnly()),
      ),
      // Tonal and outlined buttons are grey pills (SecondaryButton).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: c.surfaceAlt,
          foregroundColor: c.textPrimary,
          disabledBackgroundColor: c.surfaceAlt,
          disabledForegroundColor: c.textDisabled,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: pillShape,
          textStyle: buttonText,
          animationDuration: AppMotion.quick,
        ).copyWith(overlayColor: overlay(), side: focusOnly(BorderSide.none)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.textPrimary,
          disabledForegroundColor: c.textDisabled,
          minimumSize: const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
          shape: pillShape,
          textStyle: text.labelMedium!.copyWith(fontWeight: FontWeight.w700),
        ).copyWith(
          overlayColor: overlay(),
          side: focusOnly(),
          // Underlined while pressed.
          textStyle: WidgetStateProperty.resolveWith(
            (s) => text.labelMedium!.copyWith(
              fontWeight: FontWeight.w700,
              decoration: s.contains(WidgetState.pressed) ? TextDecoration.underline : null,
            ),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
        ).copyWith(overlayColor: overlay()),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: c.surfaceAlt,
          foregroundColor: c.textSecondary,
          selectedBackgroundColor: c.primary,
          selectedForegroundColor: c.onPrimary,
          side: BorderSide.none,
          shape: pillShape,
          textStyle: text.labelMedium,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: pillShape,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: c.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s16),
        border: noBorder,
        enabledBorder: noBorder,
        focusedBorder: inputBorder(c.primary, AppSpacing.focusWidth),
        errorBorder: inputBorder(c.error),
        focusedErrorBorder: inputBorder(c.error, AppSpacing.focusWidth),
        disabledBorder: noBorder,
        hintStyle: text.bodyLarge!.copyWith(color: c.textSecondary),
        labelStyle: text.bodyLarge!.copyWith(color: c.textSecondary),
        floatingLabelStyle: text.labelMedium!.copyWith(color: c.textPrimary),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall!.copyWith(color: c.error),
        prefixIconColor: c.textSecondary,
        suffixIconColor: c.textSecondary,
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      chipTheme: ChipThemeData(
        shape: AppRadii.pill,
        side: BorderSide.none,
        backgroundColor: c.surfaceAlt,
        selectedColor: c.primary,
        disabledColor: c.surfaceAlt,
        secondarySelectedColor: c.primary,
        labelStyle: text.labelMedium!.copyWith(color: c.textPrimary),
        secondaryLabelStyle: text.labelMedium!.copyWith(color: c.onPrimary),
        checkmarkColor: c.onPrimary,
        iconTheme: IconThemeData(color: c.textPrimary, size: AppSpacing.iconSmall),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
        color: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return c.primary;
          if (s.contains(WidgetState.pressed)) return c.surfacePressed;
          return c.surfaceAlt;
        }),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
      ),
      cardTheme: CardThemeData(
        color: c.surfaceAlt,
        surfaceTintColor: NeemFixed.transparent,
        elevation: 0,
        shadowColor: NeemFixed.transparent,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        surfaceTintColor: NeemFixed.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        dragHandleSize: const Size(36, 4),
        modalBarrierColor: NeemFixed.scrim,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: NeemFixed.transparent,
        elevation: 0,
        barrierColor: NeemFixed.scrim,
        titleTextStyle: type.title,
        contentTextStyle: type.body,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.dialogRadius),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.primaryDark,
        contentTextStyle: text.bodyMedium!.copyWith(color: c.onToast, fontWeight: FontWeight.w500),
        actionTextColor: c.onToast,
        closeIconColor: c.onToast,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.s12),
        shape: AppRadii.pill,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: NeemFixed.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: c.primaryContainer,
        indicatorShape: AppRadii.pill,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelSmall!.copyWith(
            color: s.contains(WidgetState.selected) ? c.textPrimary : c.textSecondary,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: AppSpacing.iconSize,
            color: s.contains(WidgetState.selected) ? c.textPrimary : c.textSecondary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.background,
        indicatorColor: c.primaryContainer,
        indicatorShape: AppRadii.pill,
        selectedIconTheme: IconThemeData(color: c.textPrimary),
        unselectedIconTheme: IconThemeData(color: c.textSecondary),
        selectedLabelTextStyle: text.labelSmall!.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: text.labelSmall!.copyWith(color: c.textSecondary),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textPrimary,
        textColor: c.textPrimary,
        minVerticalPadding: AppSpacing.s8,
        minTileHeight: AppSpacing.touchTarget,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        titleTextStyle: type.bodyStrong,
        subtitleTextStyle: type.caption,
        leadingAndTrailingTextStyle: type.bodyStrong,
        selectedColor: c.textPrimary,
        selectedTileColor: c.surfaceAlt,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: c.textPrimary,
        collapsedIconColor: c.textSecondary,
        textColor: c.textPrimary,
        collapsedTextColor: c.textPrimary,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.borderStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(NeemFixed.transparent),
        overlayColor: overlay(),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : null),
        checkColor: WidgetStatePropertyAll(c.onPrimary),
        side: BorderSide(color: c.borderStrong, width: AppSpacing.outlineWidth),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.borderStrong,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        inactiveTrackColor: c.surfacePressed,
        thumbColor: c.primary,
        overlayColor: c.primary.withValues(alpha: 0.08),
        activeTickMarkColor: c.onPrimary,
        inactiveTickMarkColor: c.borderStrong,
        valueIndicatorColor: c.primaryDark,
        valueIndicatorTextStyle: text.labelMedium!.copyWith(color: c.onToast),
        trackHeight: 4,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceAlt,
        circularTrackColor: NeemFixed.transparent,
        linearMinHeight: 4,
        borderRadius: AppRadii.pillRadius,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.primaryDark, borderRadius: AppRadii.pillRadius),
        textStyle: text.labelSmall!.copyWith(color: c.onToast),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: NeemFixed.transparent,
        elevation: 4,
        shadowColor: c.shadow.withValues(alpha: 0.2),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.tileRadius),
        textStyle: type.body,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primary,
        selectionColor: c.textPrimary.withValues(alpha: 0.18),
        selectionHandleColor: c.primary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SlideFadePageTransitionsBuilder(),
          TargetPlatform.fuchsia: SlideFadePageTransitionsBuilder(),
          TargetPlatform.linux: SlideFadePageTransitionsBuilder(),
          TargetPlatform.macOS: SlideFadePageTransitionsBuilder(),
          TargetPlatform.windows: SlideFadePageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// The spec's "page" motion: the new page slides 24 px in from the right and
/// fades in (320 ms easeOutQuart); going back reverses it in 220 ms easeIn.
/// Reduced motion: no movement, no fade.
class SlideFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const SlideFadePageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.pageIn;

  @override
  Duration get reverseTransitionDuration => AppMotion.pageOut;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) return child;
    final a = CurvedAnimation(parent: animation, curve: AppMotion.pageInCurve, reverseCurve: AppMotion.pageOutCurve);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        child: child,
        builder: (context, child) {
          final dx = (1 - a.value) * AppMotion.pageSlide;
          return Transform.translate(offset: Offset(rtl ? -dx : dx, 0), child: child);
        },
      ),
    );
  }
}
