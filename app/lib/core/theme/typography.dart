import 'package:flutter/material.dart';

import 'tokens.dart';

/// Type scale (design overhaul §1 "Type"). One family: the platform default
/// already used by the app (no bundled font files). Weights 400 / 500 / 700.
///
/// Devanagari (Hindi, Marathi): the theme is built with `devanagari: true`,
/// which adds 2 px of line height and drops every negative tracking. Screens
/// never set tracking themselves; they read styles from the theme.
class AppTypography {
  const AppTypography._();

  static const String? heading = null; // platform default (Roboto)
  static const String? body = null;
  static const List<String> fallback = [];

  /// No text below this size.
  static const double minSize = 12;
  static const double balooMinSize = 16;

  static TextStyle _style(
    double size,
    FontWeight weight,
    double lineHeight,
    Color color, {
    double tracking = 0,
    bool devanagari = false,
    bool tabular = false,
  }) => TextStyle(
    fontFamily: body,
    fontFamilyFallback: fallback,
    fontSize: size,
    fontWeight: weight,
    height: (lineHeight + (devanagari ? 2 : 0)) / size,
    letterSpacing: devanagari ? 0 : tracking,
    color: color,
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The nine spec styles for [c], tuned for Latin or Devanagari script.
  static AppTypeScale scale(SaartheeColors c, {bool devanagari = false}) {
    final p = c.textPrimary;
    TextStyle s(double size, FontWeight w, double lh, {double tr = 0, Color? color, bool tab = false}) =>
        _style(size, w, lh, color ?? p, tracking: tr, devanagari: devanagari, tabular: tab);
    return AppTypeScale(
      display: s(34, FontWeight.w700, 40, tr: -0.6),
      headline: s(24, FontWeight.w700, 30, tr: -0.3),
      title: s(18, FontWeight.w700, 24, tr: -0.1),
      body: s(16, FontWeight.w400, 24),
      bodyStrong: s(16, FontWeight.w500, 24),
      label: s(14, FontWeight.w500, 20),
      caption: s(13, FontWeight.w400, 18, color: c.textSecondary),
      // Figures are digits and ₹: they keep their tight tracking in every language.
      figureXL: _style(40, FontWeight.w700, 44, p, tracking: -1.0, tabular: true),
      figure: _style(24, FontWeight.w700, 28, p, tracking: -0.4, tabular: true),
    );
  }

  /// The spec styles mapped onto Material roles, so Material widgets and
  /// existing screens inherit them.
  static TextTheme textTheme(SaartheeColors c, {bool devanagari = false}) {
    final t = scale(c, devanagari: devanagari);
    final bodyM = _style(14, FontWeight.w400, 20, c.textPrimary, devanagari: devanagari);
    final button = _style(16, FontWeight.w700, 20, c.textPrimary, devanagari: devanagari);
    final small = _style(12, FontWeight.w500, 16, c.textPrimary, devanagari: devanagari);
    return TextTheme(
      displayLarge: t.display,
      displayMedium: t.display,
      displaySmall: t.display,
      headlineLarge: t.headline,
      headlineMedium: t.headline,
      headlineSmall: t.headline,
      titleLarge: t.title,
      titleMedium: t.bodyStrong,
      titleSmall: t.label,
      bodyLarge: t.body,
      bodyMedium: bodyM,
      bodySmall: t.caption,
      labelLarge: button,
      labelMedium: t.label,
      labelSmall: small,
    );
  }

  /// Stat figures (24/700, tabular).
  static TextStyle numeric(SaartheeColors c) => scale(c).figure;

  /// Hero figures (40/700, tabular).
  static TextStyle displayNumber(SaartheeColors c) => scale(c).figureXL;

  /// Wordmark at [size].
  static TextStyle wordmark(Color color, double size) => _style(size, FontWeight.w700, size * 1.3, color);
}

/// The spec type scale, registered on the theme. Read it with
/// `AppTypeScale.of(context)` (or `context.type`).
@immutable
class AppTypeScale extends ThemeExtension<AppTypeScale> {
  const AppTypeScale({
    required this.display,
    required this.headline,
    required this.title,
    required this.body,
    required this.bodyStrong,
    required this.label,
    required this.caption,
    required this.figureXL,
    required this.figure,
  });

  /// 34/40 700: page title on root tabs.
  final TextStyle display;

  /// 24/30 700: section heading, page title on detail pages.
  final TextStyle headline;

  /// 18/24 700: card title.
  final TextStyle title;

  /// 16/24 400: default.
  final TextStyle body;

  /// 16/24 500: list row title.
  final TextStyle bodyStrong;

  /// 14/20 500: tile label, chip, small button.
  final TextStyle label;

  /// 13/18 400 secondary colour: secondary line.
  final TextStyle caption;

  /// 40/44 700 tabular: hero rupee figure.
  final TextStyle figureXL;

  /// 24/28 700 tabular: stat tile.
  final TextStyle figure;

  static AppTypeScale of(BuildContext context) =>
      Theme.of(context).extension<AppTypeScale>() ?? AppTypography.scale(SaartheeColors.of(context));

  @override
  AppTypeScale copyWith() => this;

  @override
  AppTypeScale lerp(AppTypeScale? other, double t) {
    if (other == null) return this;
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return AppTypeScale(
      display: l(display, other.display),
      headline: l(headline, other.headline),
      title: l(title, other.title),
      body: l(body, other.body),
      bodyStrong: l(bodyStrong, other.bodyStrong),
      label: l(label, other.label),
      caption: l(caption, other.caption),
      figureXL: l(figureXL, other.figureXL),
      figure: l(figure, other.figure),
    );
  }
}

extension AppTypeContext on BuildContext {
  /// The spec type scale for this context's theme and language.
  AppTypeScale get type => AppTypeScale.of(this);
}
