import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'blocks.dart';
import 'layout.dart';
import 'motion.dart';

// The original shared widgets, restyled in place for the design overhaul
// (docs/design/design-overhaul.md): same constructors, new look.

/// 36 dp circle button inside a 48 dp target (Home header, app bar).
class HeaderCircleButton extends StatelessWidget {
  const HeaderCircleButton({super.key, required this.tooltip, required this.onPressed, required this.child, this.onDark = false});
  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: SizedBox.square(
        dimension: AppSpacing.touchTarget,
        child: Center(
          child: Pressable(
            onTap: onPressed,
            semanticLabel: tooltip,
            circle: true,
            color: onDark ? NeemFixed.headerButton : c.surfaceAlt,
            pressedColor: onDark ? NeemFixed.white.withValues(alpha: 0.24) : c.surfacePressed,
            child: SizedBox.square(
              dimension: AppSpacing.headerButton,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// EN / हि / म: shows the current language's glyph; tap picks another.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key, this.onDark = false});
  final bool onDark;

  static const Map<String, String> glyphs = {'en': 'EN', 'hi': 'हि', 'mr': 'म'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    final c = SaartheeColors.of(context);
    return HeaderCircleButton(
      tooltip: context.tr('Language'),
      onDark: onDark,
      onPressed: () => showAppSheet<void>(
        context,
        title: context.tr('Language'),
        builder: (sheet) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, e) in appLanguages.entries.indexed)
              ListRow(
                title: e.value,
                chevron: false,
                divider: i < appLanguages.length - 1,
                trailing: e.key == lang ? Icon(Icons.check, color: c.primary) : null,
                onTap: () {
                  ref.read(langProvider.notifier).set(e.key);
                  Navigator.pop(sheet);
                },
              ),
            const SizedBox(height: AppSpacing.s8),
          ],
        ),
      ),
      child: Text(
        glyphs[lang] ?? 'EN',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: onDark ? NeemFixed.white : c.textPrimary),
      ),
    );
  }
}

/// Stat tile: grey, radius 16, figure (24/700 tabular) on top, caption
/// below, optional status [dot]. [StatTile.count] counts a number up once.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.color, this.dot, this.onTap})
    : count = null,
      format = null;

  /// A figure that counts up from zero on first appearance.
  const StatTile.count({super.key, required num this.count, this.format, required this.label, this.color, this.dot, this.onTap})
    : value = '';

  final String value;
  final num? count;
  final String Function(num v)? format;
  final String label;

  /// Status colour for the figure.
  final Color? color;

  /// Tiny status dot after the caption.
  final Color? dot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    final style = t.figure.copyWith(color: color);
    final shown = count == null ? value : (format ?? (num v) => v.round().toString())(count!);
    return Semantics(
      container: true,
      button: onTap != null,
      label: '$label: $shown',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        color: c.surfaceAlt,
        borderRadius: AppRadii.tileRadius,
        padding: const EdgeInsets.all(AppSpacing.s14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: count == null ? Text(value, style: style) : AnimatedCount(value: count!, format: format, style: style),
            ),
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                Flexible(
                  child: switch (_StatTileWidth.maybeOf(context)) {
                    // Tile width less its padding (and the dot), so a long word shrinks instead of breaking.
                    final w? => WordSafeText(label, style: t.caption, maxWidth: w - 2 * AppSpacing.s14 - (dot == null ? 0 : 12)),
                    null => Text(label, style: t.caption),
                  },
                ),
                if (dot != null) ...[
                  const SizedBox(width: 6),
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Three stat tiles in a row, equal height.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.tiles});
  final List<Widget> tiles;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => _StatTileWidth(
      width: (box.maxWidth - AppSpacing.tileGap * (tiles.length - 1)) / math.max(1, tiles.length),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.tileGap),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Width of each tile in a [StatRow] (labels measure against it; no LayoutBuilder under IntrinsicHeight).
class _StatTileWidth extends InheritedWidget {
  const _StatTileWidth({required this.width, required super.child});
  final double width;
  static double? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_StatTileWidth>()?.width;
  @override
  bool updateShouldNotify(_StatTileWidth old) => old.width != width;
}

/// Bold section heading (headline 24/700), 32 above and 12 below, optional
/// trailing widget (e.g. a "See all" text button).
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sectionTitleTop, bottom: AppSpacing.sectionTitleBottom),
    child: Row(
      children: [
        Expanded(
          child: Semantics(header: true, child: Text(text, style: AppTypeScale.of(context).headline)),
        ),
        ?trailing,
      ],
    ),
  );
}

