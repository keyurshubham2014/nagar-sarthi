import 'package:flutter/material.dart';

/// Semantic colour tokens. The only colour source in the app: screens read
/// them with `SaartheeColors.of(context)`. Values follow
/// docs/design/design-overhaul.md §1 (black on white, grey tiles; colour only
/// for status). Field names are kept from the earlier design system.
@immutable
class SaartheeColors extends ThemeExtension<SaartheeColors> {
  const SaartheeColors({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.primaryDark,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.onPrimarySubtle,
    required this.sunrise,
    required this.onSunrise,
    required this.sunrisePressed,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.success,
    required this.successTint,
    required this.warning,
    required this.warningTint,
    required this.error,
    required this.errorTint,
    required this.info,
    required this.infoTint,
    required this.focusRing,
    required this.focusInner,
    required this.shadow,
    required this.onToast,
    required this.offline,
    required this.offlineTint,
    required this.surfacePressed,
    required this.review,
    required this.reviewTint,
  });

  final Brightness brightness;
  final Color primary;
  final Color onPrimary;
  final Color primaryDark;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color onPrimarySubtle;

  /// Report actions only, at most once per screen (DS §2 rule).
  final Color sunrise;
  final Color onSunrise;
  final Color sunrisePressed;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color success;
  final Color successTint;
  final Color warning;
  final Color warningTint;
  final Color error;
  final Color errorTint;
  final Color info;
  final Color infoTint;
  final Color focusRing;
  final Color focusInner;
  final Color shadow;

  /// Text on the `primaryDark` toast.
  final Color onToast;

  /// Slate offline banner (DS §5 banners).
  final Color offline;
  final Color offlineTint;

  /// Pressed tile, chip and row (design overhaul §1).
  final Color surfacePressed;

  /// Billed above rate, repeat job.
  final Color review;
  final Color reviewTint;

  bool get isDark => brightness == Brightness.dark;

  static const SaartheeColors light = SaartheeColors(
    brightness: Brightness.light,
    primary: Color(0xFF0A0A0A),
    onPrimary: Color(0xFFFFFFFF),
    primaryDark: Color(0xFF000000),
    primaryContainer: Color(0xFFF3F3F3),
    onPrimaryContainer: Color(0xFF0A0A0A),
    onPrimarySubtle: Color(0xFFC9C9C9),
    sunrise: Color(0xFF0A0A0A),
    onSunrise: Color(0xFFFFFFFF),
    sunrisePressed: Color(0xFF000000),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF3F3F3),
    border: Color(0xFFEEEEEE),
    borderStrong: Color(0xFFD0D0D0),
    textPrimary: Color(0xFF0A0A0A),
    textSecondary: Color(0xFF5E5E5E),
    textDisabled: Color(0xFFA6A6A6),
    success: Color(0xFF0C7A40), // spec #0E8345, darkened to 4.5:1 on successTint
    successTint: Color(0xFFE6F4EC),
    warning: Color(0xFFA85800), // spec #B25E00, darkened to 4.5:1 on warningTint
    warningTint: Color(0xFFFFF2DC),
    error: Color(0xFFC8102E),
    errorTint: Color(0xFFFDECEE),
    info: Color(0xFF1F5FD0),
    infoTint: Color(0xFFE9F0FD),
    focusRing: Color(0xFF0A0A0A),
    focusInner: Color(0xFFFFFFFF),
    shadow: Color(0xFF000000),
    onToast: Color(0xFFFFFFFF),
    offline: Color(0xFF5E5E5E),
    offlineTint: Color(0xFFF3F3F3),
    surfacePressed: Color(0xFFE8E8E8),
    review: Color(0xFF6B3FD4),
    reviewTint: Color(0xFFF0EBFC),
  );

  // Dark: the light structure inverted. `primaryDark` stays a dark pill
  // (toasts, the map's monsoon pill, Home's band) with `onToast` text on it.
  static const SaartheeColors dark = SaartheeColors(
    brightness: Brightness.dark,
    primary: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF000000),
    primaryDark: Color(0xFF262626),
    primaryContainer: Color(0xFF1C1C1C),
    onPrimaryContainer: Color(0xFFFFFFFF),
    onPrimarySubtle: Color(0xFF5E5E5E),
    sunrise: Color(0xFFFFFFFF),
    onSunrise: Color(0xFF000000),
    sunrisePressed: Color(0xFFD9D9D9),
    background: Color(0xFF000000),
    surface: Color(0xFF121212),
    surfaceAlt: Color(0xFF1C1C1C),
    border: Color(0xFF2A2A2A),
    borderStrong: Color(0xFF444444),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA6A6A6),
    textDisabled: Color(0xFF6B6B6B),
    success: Color(0xFF4CC38A),
    successTint: Color(0xFF0F2A1C),
    warning: Color(0xFFF0A848),
    warningTint: Color(0xFF33240C),
    error: Color(0xFFFF7A8A),
    errorTint: Color(0xFF3A1218),
    info: Color(0xFF86AEF7),
    infoTint: Color(0xFF14213A),
    focusRing: Color(0xFFFFFFFF),
    focusInner: Color(0xFF000000),
    shadow: Color(0xFF000000),
    onToast: Color(0xFFFFFFFF),
    offline: Color(0xFFA6A6A6),
    offlineTint: Color(0xFF1C1C1C),
    surfacePressed: Color(0xFF2A2A2A),
    review: Color(0xFFB49BFF),
    reviewTint: Color(0xFF261A40),
  );

  /// Tokens of the current theme (light when no extension is registered).
  static SaartheeColors of(BuildContext context) =>
      Theme.of(context).extension<SaartheeColors>() ?? light;

  @override
  SaartheeColors copyWith({Color? primary, Color? sunrise}) => SaartheeColors(
    brightness: brightness,
    primary: primary ?? this.primary,
    onPrimary: onPrimary,
    primaryDark: primaryDark,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    onPrimarySubtle: onPrimarySubtle,
    sunrise: sunrise ?? this.sunrise,
    onSunrise: onSunrise,
    sunrisePressed: sunrisePressed,
    background: background,
    surface: surface,
    surfaceAlt: surfaceAlt,
    border: border,
    borderStrong: borderStrong,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    textDisabled: textDisabled,
    success: success,
    successTint: successTint,
    warning: warning,
    warningTint: warningTint,
    error: error,
    errorTint: errorTint,
    info: info,
    infoTint: infoTint,
    focusRing: focusRing,
    focusInner: focusInner,
    shadow: shadow,
    onToast: onToast,
    offline: offline,
    offlineTint: offlineTint,
    surfacePressed: surfacePressed,
    review: review,
    reviewTint: reviewTint,
  );

  @override
  SaartheeColors lerp(SaartheeColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return SaartheeColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primaryDark: l(primaryDark, other.primaryDark),
      primaryContainer: l(primaryContainer, other.primaryContainer),
      onPrimaryContainer: l(onPrimaryContainer, other.onPrimaryContainer),
      onPrimarySubtle: l(onPrimarySubtle, other.onPrimarySubtle),
      sunrise: l(sunrise, other.sunrise),
      onSunrise: l(onSunrise, other.onSunrise),
      sunrisePressed: l(sunrisePressed, other.sunrisePressed),
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textDisabled: l(textDisabled, other.textDisabled),
      success: l(success, other.success),
      successTint: l(successTint, other.successTint),
      warning: l(warning, other.warning),
      warningTint: l(warningTint, other.warningTint),
      error: l(error, other.error),
      errorTint: l(errorTint, other.errorTint),
      info: l(info, other.info),
      infoTint: l(infoTint, other.infoTint),
      focusRing: l(focusRing, other.focusRing),
      focusInner: l(focusInner, other.focusInner),
      shadow: l(shadow, other.shadow),
      onToast: l(onToast, other.onToast),
      offline: l(offline, other.offline),
      offlineTint: l(offlineTint, other.offlineTint),
      surfacePressed: l(surfacePressed, other.surfacePressed),
      review: l(review, other.review),
      reviewTint: l(reviewTint, other.reviewTint),
    );
  }
}

/// Fixed white and transparent, for the few places a fixed value is needed.
class NeemFixed {
  const NeemFixed._();

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);

  /// Scrim behind sheets and full-screen photos (40% black).
  static const Color scrim = Color(0x66000000);

  /// Round buttons on a dark band: white at 14%.
  static const Color headerButton = Color(0x24FFFFFF);
}

/// 4 dp spacing scale and layout constants (design overhaul §1).
class AppSpacing {
  const AppSpacing._();

  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s56 = 56;

  static const List<double> scale = [4, 8, 12, 16, 20, 24, 32, 40, 56];

  /// Page gutter.
  static const double gutter = 20;
  static const double sectionGap = 32;
  static const double tileGap = 12;
  static const double cardGap = 12;
  static const double sectionTitleTop = 32;
  static const double sectionTitleBottom = 12;

  /// Section break: full-bleed grey band between major sections.
  static const double sectionBreak = 8;

  /// Content column on wide screens: lists and reading pages.
  static const double maxContent = 720;

  /// Content column on wide screens: tile grids.
  static const double maxGrid = 1040;
  static const double staffMaxContent = 1200;
  static const double touchTarget = 48;
  static const double buttonHeight = 56;
  static const double pinnedButtonHeight = 56;
  static const double listRow = 64;
  static const double topBar = 56;
  static const double searchHeight = 52;
  static const double reportCardMinHeight = 56;
  static const double categoryBadge = 40;

  /// Round grey header and back buttons.
  static const double headerButton = 40;
  static const double emptyIcon = 56;
  static const double timelineDot = 12;
  static const double iconSize = 24;
  static const double iconSmall = 18;
  static const double pictogram = 28;
  static const double borderWidth = 1;
  static const double outlineWidth = 1.5;
  static const double focusWidth = 2;

  /// Tiles: wide spans 2 columns of a 4-column grid, square spans 1.
  static const double tileWide = 104;
  static const double tileSquare = 96;

  /// Floating tab bar: pill height, gap above the safe bottom edge, max width.
  static const double tabBarHeight = 64;
  static const double tabBarGap = 16;
  static const double tabBarMaxWidth = 420;

  /// Width at which the tab bar becomes a left rail.
  static const double railBreakpoint = 900;
}

/// Corner radii (design overhaul §1).
class AppRadii {
  const AppRadii._();

  /// Inputs (and legacy controls).
  static const double control = 14;
  static const double tile = 16;
  static const double card = 20;
  static const double dialog = 24;
  static const double mapCard = 24;
  static const double sheet = 28;

  /// Brand mark corner radius as a fraction of its size.
  static const double markFraction = 0.28;

  static const BorderRadius controlRadius = BorderRadius.all(Radius.circular(control));
  static const BorderRadius tileRadius = BorderRadius.all(Radius.circular(tile));
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius dialogRadius = BorderRadius.all(Radius.circular(dialog));
  static const BorderRadius sheetTop = BorderRadius.vertical(top: Radius.circular(sheet));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(999));
  static const StadiumBorder pill = StadiumBorder();
}

/// Elevation: none on the page. Shadows only on floating elements (tab bar,
/// map controls and preview card, sheets, snackbar).
class AppElevation {
  const AppElevation._();

  /// Material elevation for sheets and dialogs (the shadow comes from [floating]).
  static const double overlay = 0;

  /// Cards on the page: no shadow.
  static List<BoxShadow> card(SaartheeColors c) => const [];

  /// Kept for old callers; the report action no longer glows.
  static List<BoxShadow> reportGlow(SaartheeColors c) => floating(c);

  /// Floating elements: y 8, blur 24, 12% black.
  static List<BoxShadow> floating(SaartheeColors c) => [
    BoxShadow(color: c.shadow.withValues(alpha: c.isDark ? 0.5 : 0.12), offset: const Offset(0, 8), blurRadius: 24),
  ];

  /// Small floating controls (map buttons): 8%.
  static List<BoxShadow> soft(SaartheeColors c) => [
    BoxShadow(color: c.shadow.withValues(alpha: c.isDark ? 0.4 : 0.08), offset: const Offset(0, 4), blurRadius: 12),
  ];

  /// A card on the page: grey fill, radius 20, no border, no shadow.
  static BoxDecoration cardDecoration(SaartheeColors c) =>
      BoxDecoration(color: c.surfaceAlt, borderRadius: AppRadii.cardRadius);
}

/// Motion tokens (design overhaul §1 "Motion"). Read durations through
/// [AppMotion.of] so "reduce motion" turns them to zero.
class AppMotion {
  const AppMotion._();

  static const Duration pressIn = Duration(milliseconds: 90);
  static const Duration pressOut = Duration(milliseconds: 160);
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 260);
  static const Duration pageIn = Duration(milliseconds: 320);
  static const Duration pageOut = Duration(milliseconds: 220);
  static const Duration sheet = Duration(milliseconds: 360);
  static const Duration staggerStep = Duration(milliseconds: 40);
  static const int staggerMax = 6;
  static const Duration count = Duration(milliseconds: 600);
  static const Duration shimmer = Duration(milliseconds: 1200);

  static const Curve pressCurve = Curves.easeOut;
  static const Curve quickCurve = Curves.easeOutCubic;
  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve pageInCurve = Curves.easeOutQuart;
  static const Curve pageOutCurve = Curves.easeIn;
  static const Curve sheetCurve = _SoftBack(0.6);
  static const Curve countCurve = Curves.easeOutCubic;

  static const double pressScale = 0.97;
  static const double pageSlide = 24;
  static const double staggerRise = 12;

  /// True when the platform asks for reduced motion.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], or zero under reduced motion.
  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}

/// easeOutBack with a small overshoot ([s] = 0.6 overshoots about 2%).
class _SoftBack extends Curve {
  const _SoftBack(this.s);
  final double s;
  @override
  double transformInternal(double t) {
    final u = t - 1;
    return 1 + (s + 1) * u * u * u + s * u * u;
  }
}
