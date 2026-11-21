import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../i18n.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'controls.dart';
import 'motion.dart';
import 'pictogram.dart';

/// Page gutter (20) on both sides. Wrap non-full-bleed content in it.
class Gutter extends StatelessWidget {
  const Gutter({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter), child: child);
}

/// The 8 px full-bleed grey band between major sections, with [space] above
/// and below.
class SectionBreak extends StatelessWidget {
  const SectionBreak({super.key, this.space = AppSpacing.s24});
  final double space;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: space),
    child: ExcludeSemantics(
      child: SizedBox(
        height: AppSpacing.sectionBreak,
        width: double.infinity,
        child: ColoredBox(color: SaartheeColors.of(context).surfaceAlt),
      ),
    ),
  );
}

enum TileSize { wide, square }

/// Grey rounded tile: label bottom-left (max 2 lines), pictogram top-right,
/// optional badge count top-left. Press: scale 0.97 + darker grey.
/// Lay several out with [TileGrid].
class Tile extends StatelessWidget {
  const Tile({
    super.key,
    required this.label,
    this.pictogram,
    this.art,
    this.accent,
    this.onTap,
    this.size = TileSize.square,
    this.badge,
    this.semanticLabel,
  });

  final String label;
  final PictogramKind? pictogram;

  /// Custom art in the 40 px top-right area (instead of [pictogram]).
  final Widget? art;

  /// Accent dot on the pictogram (one status colour at most).
  final Color? accent;
  final VoidCallback? onTap;
  final TileSize size;

  /// Count shown top-left in a small black pill (null or 0 = none).
  final int? badge;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final base = size == TileSize.wide ? AppSpacing.tileWide : AppSpacing.tileSquare;
    final height = base + math.max(0, scale - 1) * 48;
    final square = size == TileSize.square;
    return Pressable(
      onTap: onTap,
      color: c.surfaceAlt,
      borderRadius: AppRadii.tileRadius,
      semanticLabel: semanticLabel ?? (badge == null || badge == 0 ? label : '$label, $badge'),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.all(square ? 10 : AppSpacing.s14),
          child: Stack(
            children: [
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: SizedBox.square(
                  dimension: 40,
                  child: Center(child: art ?? (pictogram == null ? null : Pictogram(pictogram!, accent: accent))),
                ),
              ),
              if (badge != null && badge! > 0)
                Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: ShapeDecoration(color: c.primary, shape: AppRadii.pill),
                    child: Text('$badge', style: t.label.copyWith(color: c.onPrimary, fontSize: 12, height: 16 / 12)),
                  ),
                ),
              Align(
                alignment: AlignmentDirectional.bottomStart,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(end: square ? 0 : 44),
                  child: WordSafeText(
                    label,
                    style: square ? t.label.copyWith(fontSize: 13, height: 17 / 13) : t.label.copyWith(fontSize: 15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiles in the reference layout: wide tiles two per row, then square tiles
/// in rows of [squareColumns] (null = 4 when each tile gets at least 84 dp,
/// else 3). Rows stagger in on first paint. No outer padding: wrap in [Gutter].
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.tiles, this.squareColumns, this.stagger = true});
  final List<Tile> tiles;
  final int? squareColumns;
  final bool stagger;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = AppSpacing.tileGap;
      final wide = tiles.where((t) => t.size == TileSize.wide).toList();
      // Two wide tiles always share one row; more reflow to 4 per row when wide.
      final wideCols = box.maxWidth >= 640 && wide.length > 2 ? 4 : 2;
      // Large text: fewer, wider square tiles, so two-line labels still fit (min 96 dp at 100%).
      final minSquare = 96 * MediaQuery.textScalerOf(context).scale(14) / 14;
      var squareCols = squareColumns ?? _squareCols(box.maxWidth);
      while (squareCols > 2 && (box.maxWidth - gap * (squareCols - 1)) / squareCols < minSquare) {
        squareCols--;
      }
      final rows = <Widget>[];
      void addRow(List<Tile> items, int cols) {
        for (var i = 0; i < items.length; i += cols) {
          final row = items.sublist(i, math.min(i + cols, items.length));
          rows.add(
            Row(
              children: [
                for (var j = 0; j < cols; j++) ...[
                  if (j > 0) const SizedBox(width: gap),
                  Expanded(child: j < row.length ? row[j] : const SizedBox.shrink()),
                ],
              ],
            ),
          );
        }
      }

      addRow(wide, wideCols);
      addRow(tiles.where((t) => t.size == TileSize.square).toList(), squareCols);
      return Column(
        children: [
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: gap),
            stagger ? StaggeredEntrance(index: i, child: r) : r,
          ],
        ],
      );
    },
  );

  static int _squareCols(double width) {
    for (final n in [8, 6, 4]) {
      if ((width - AppSpacing.tileGap * (n - 1)) / n >= (n == 4 ? 84 : 110)) return n;
    }
    return 3;
  }
}

/// Hero figure, plain on white: caption, big tabular figure that counts up
/// once, a one-line explanation, optional chevron (tappable) and [action].
class HeroFigure extends StatelessWidget {
  const HeroFigure({
    super.key,
    required this.caption,
    required this.value,
    this.format,
    this.explanation,
    this.color,
    this.onTap,
    this.action,
  });

  final String caption;
  final num value;

  /// e.g. `formatInr`.
  final String Function(num v)? format;
  final String? explanation;

  /// A status colour for the figure (default text colour).
  final Color? color;
  final VoidCallback? onTap;

  /// Optional widget below (e.g. a `PrimaryButton` or `ProgressBar`).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(caption, style: t.label.copyWith(color: c.textSecondary)),
        const SizedBox(height: AppSpacing.s4),
        Row(
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: AnimatedCount(value: value, format: format, style: t.figureXL.copyWith(color: color)),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.s4),
              Icon(Icons.chevron_right, color: c.textSecondary, size: 28),
            ],
          ],
        ),
        if (explanation != null) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(explanation!, style: t.caption.copyWith(fontSize: 14, height: 20 / 14)),
        ],
        if (action != null) ...[const SizedBox(height: AppSpacing.s16), action!],
      ],
    );
    if (onTap == null) return content;
    return Pressable(onTap: onTap, borderRadius: AppRadii.tileRadius, child: content);
  }
}

/// List row: 64 min height, 40 px grey leading well (icon or initials),
/// title + caption, optional chip, trailing amount (tabular) and chevron;
/// hairline divider inset 76. Full-bleed grey on press. Owns the page gutter.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.caption,
    this.icon,
    this.initials,
    this.leading,
    this.chip,
    this.amount,
    this.amountColor,
    this.trailing,
    this.onTap,
    this.chevron,
    this.divider = true,
    this.titleMaxLines = 2,
  });

  final String title;
  final String? caption;
  final IconData? icon;
  final String? initials;

  /// Custom 40 px leading (instead of [icon] / [initials]).
  final Widget? leading;

  /// One status chip under the caption.
  final Widget? chip;
  final String? amount;
  final Color? amountColor;

  /// Replaces amount and chevron.
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Default: shown when [onTap] is set.
  final bool? chevron;
  final bool divider;
  final int titleMaxLines;

  static const double dividerInset = AppSpacing.gutter + 40 + AppSpacing.s16;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    final hasWell = leading != null || icon != null || initials != null;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpacing.listRow),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.s12),
        child: Row(
          children: [
            if (hasWell) ...[
              leading ??
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                    child: icon != null
                        ? Icon(icon, size: 20, color: c.textPrimary)
                        : Text(initials!, style: t.label.copyWith(fontWeight: FontWeight.w700)),
                  ),
              const SizedBox(width: AppSpacing.s16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  WordSafeText(title, style: t.bodyStrong, maxLines: titleMaxLines, overflow: TextOverflow.ellipsis),
                  if (caption != null) Text(caption!, style: t.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (chip != null) ...[const SizedBox(height: AppSpacing.s4), chip!],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.s12),
              trailing!,
            ] else ...[
              if (amount != null) ...[
                const SizedBox(width: AppSpacing.s12),
                Text(
                  amount!,
                  style: t.bodyStrong.copyWith(
                    color: amountColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              if (chevron ?? onTap != null) ...[
                const SizedBox(width: AppSpacing.s4),
                Icon(Icons.chevron_right, color: c.textSecondary, size: 22),
              ],
            ],
          ],
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Pressable(onTap: onTap, scale: false, child: row),
        if (divider)
          Padding(
            padding: EdgeInsetsDirectional.only(start: hasWell ? dividerInset : AppSpacing.gutter),
            child: Divider(height: 1, thickness: 1, color: c.border),
          ),
      ],
    );
  }
}

enum StatusTone { neutral, success, warning, error, info, review }

/// Status pill: tint background, status text 12/500, optional 6 px dot.
/// One per row; pass [more] to collapse extra flags into "+N".
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = StatusTone.neutral, this.dot = false, this.more = 0});
  final String label;
  final StatusTone tone;
  final bool dot;
  final int more;

  /// (text, tint) for [tone].
  static (Color, Color) colors(SaartheeColors c, StatusTone tone) => switch (tone) {
    StatusTone.neutral => (c.textSecondary, c.surfaceAlt),
    StatusTone.success => (c.success, c.successTint),
    StatusTone.warning => (c.warning, c.warningTint),
    StatusTone.error => (c.error, c.errorTint),
    StatusTone.info => (c.info, c.infoTint),
    StatusTone.review => (c.review, c.reviewTint),
  };

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    final (fg, bg) = colors(c, tone);
    final style = t.label.copyWith(fontSize: 12, height: 16 / 12, color: fg);
    Widget pill(Color bg, List<Widget> children) => Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: 3),
      decoration: ShapeDecoration(color: bg, shape: AppRadii.pill),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
    return Wrap(
      spacing: AppSpacing.s4,
      runSpacing: AppSpacing.s4,
      children: [
        pill(bg, [
          if (dot) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          Flexible(child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        if (more > 0) pill(c.surfaceAlt, [Text('+$more', style: style.copyWith(color: c.textSecondary))]),
      ],
    );
  }
}

/// Slim progress bar: black fill on grey; above 1.0 the overshoot is red.
/// Grows from zero on first paint (standard motion).
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.color, this.height = 6, this.semanticLabel, this.trackColor});

  /// Unfilled part (default grey; pass `surface` when the bar sits on a grey tile).
  final Color? trackColor;

  /// 0..n (1 = 100%).
  final double value;
  final Color? color;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final v = value.isFinite ? math.max(0.0, value) : 0.0;
    final over = v > 1;
    return Semantics(
      label: semanticLabel,
      value: '${(v * 100).round()}%',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.of(context, AppMotion.standard),
        curve: AppMotion.standardCurve,
        builder: (_, k, _) => ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: Container(
            height: height,
            color: over ? c.error : trackColor ?? c.surfaceAlt,
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: (over ? 1 / v : v) * k,
              heightFactor: 1,
              child: ColoredBox(color: color ?? c.primary),
            ),
          ),
        ),
      ),
    );
  }
}

/// One step of a [Timeline].
class TimelineStep {
  const TimelineStep({
    required this.title,
    this.meta,
    this.state = TimelineNodeState.done,
    this.color,
    this.chip,
    this.amount,
    this.child,
  });
  final String title;
  final String? meta;
  final TimelineNodeState state;

  /// Status colour for an outcome node.
  final Color? color;
  final Widget? chip;
  final String? amount;

  /// Extra content under the step (evidence rows, a button).
  final Widget? child;
}

enum TimelineNodeState { done, pending, outcome }

/// Vertical timeline: 2 px grey rail, 12 px nodes (filled = done, ring =
/// pending, status colour = outcome); each step a title, meta, chip, amount.
class Timeline extends StatelessWidget {
  const Timeline({super.key, required this.steps});
  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, s) in steps.indexed)
          // Rail drawn as a positioned fill (no IntrinsicHeight: it over-measured Devanagari text).
          Stack(
            children: [
              // Rail: from this node down to the next; the last step only draws in to its node.
              if (steps.length > 1)
                PositionedDirectional(
                  start: 11,
                  top: i == 0 ? 12 : 0,
                  bottom: i == steps.length - 1 ? null : 0,
                  height: i == steps.length - 1 ? 12 : null,
                  width: 2,
                  child: ColoredBox(color: c.border),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Center(
                        child: Container(
                          width: AppSpacing.timelineDot,
                          height: AppSpacing.timelineDot,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: switch (s.state) {
                              TimelineNodeState.done => c.primary,
                              TimelineNodeState.pending => c.surface,
                              TimelineNodeState.outcome => s.color ?? c.primary,
                            },
                            border: s.state == TimelineNodeState.pending ? Border.all(color: c.borderStrong, width: 2) : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : AppSpacing.s20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Text(s.title, style: t.bodyStrong)),
                              if (s.amount != null) ...[
                                const SizedBox(width: AppSpacing.s8),
                                Text(s.amount!, style: t.bodyStrong.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                              ],
                            ],
                          ),
                          if (s.meta != null) Text(s.meta!, style: t.caption),
                          if (s.chip != null) ...[const SizedBox(height: AppSpacing.s4), s.chip!],
                          if (s.child != null) ...[const SizedBox(height: AppSpacing.s8), s.child!],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

/// Empty block: pictogram, one sentence, optional button.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.pictogram = PictogramKind.about, this.actionLabel, this.onAction});
  final String message;
  final PictogramKind pictogram;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => _StateBlock(
    art: Pictogram(pictogram, size: 32),
    message: message,
    action: actionLabel == null || onAction == null ? null : SecondaryButton(label: actionLabel!, onPressed: onAction, expand: false),
  );
}

/// Error block: pictogram with a red dot, one sentence, Retry.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry, this.retryLabel});
  final String message;
  final VoidCallback onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) => _StateBlock(
    art: Pictogram(PictogramKind.about, size: 32, accent: SaartheeColors.of(context).error),
    message: message,
    action: SecondaryButton(label: retryLabel ?? context.tr('Retry'), icon: Icons.refresh, onPressed: onRetry, expand: false),
  );
}

class _StateBlock extends StatelessWidget {
  const _StateBlock({required this.art, required this.message, this.action});
  final Widget art;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.s32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
            child: art,
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(message, textAlign: TextAlign.center, style: AppTypeScale.of(context).body.copyWith(color: c.textSecondary)),
          if (action != null) ...[const SizedBox(height: AppSpacing.s16), action!],
        ],
      ),
    );
  }
}

/// Grey rounded info panel with a tappable header (icon, title, chevron)
/// that expands to show [child] (standard motion). For notes such as "How
/// this is kept fair" or "How we link".
class CollapsiblePanel extends StatefulWidget {
  const CollapsiblePanel({super.key, required this.title, required this.child, this.icon = Icons.info_outline, this.initiallyOpen = false});
  final String title;
  final Widget child;
  final IconData icon;
  final bool initiallyOpen;

  @override
  State<CollapsiblePanel> createState() => _CollapsiblePanelState();
}

class _CollapsiblePanelState extends State<CollapsiblePanel> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    final d = AppMotion.of(context, AppMotion.standard);
    return ClipRRect(
      borderRadius: AppRadii.tileRadius,
      child: ColoredBox(
        color: c.surfaceAlt,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              expanded: _open,
              child: Pressable(
                onTap: () => setState(() => _open = !_open),
                scale: false,
                pressedColor: c.surfacePressed,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget - AppSpacing.s24),
                  child: Row(
                    children: [
                      Icon(widget.icon, size: AppSpacing.iconSmall + 2, color: c.textPrimary),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(child: Text(widget.title, style: t.bodyStrong)),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: d,
                        curve: AppMotion.standardCurve,
                        child: Icon(Icons.expand_more, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: d,
              curve: AppMotion.standardCurve,
              alignment: Alignment.topCenter,
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, 0, AppSpacing.s16, AppSpacing.s16),
                      child: DefaultTextStyle.merge(style: t.caption.copyWith(color: c.textPrimary, fontSize: 14, height: 20 / 14), child: widget.child),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text that never breaks inside a word. When its widest word does not fit the
/// line (large text scale on a narrow phone) it scales itself down just enough,
/// to no less than 75%, instead. Measures against [maxWidth], or the incoming
/// constraints (a LayoutBuilder, so not inside IntrinsicHeight) without it.
class WordSafeText extends StatelessWidget {
  const WordSafeText(this.text, {super.key, required this.style, this.maxLines, this.overflow, this.maxWidth, this.textAlign});
  final String text;
  final TextAlign? textAlign;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final double? maxWidth;

  Widget _text(BuildContext context, double width) {
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final w in text.split(RegExp(r'\s+'))) {
      if (w.isEmpty) continue;
      final tp = TextPainter(text: TextSpan(text: w, style: style), textDirection: Directionality.of(context), textScaler: scaler)
        ..layout();
      widest = math.max(widest, tp.width);
      tp.dispose();
    }
    final k = widest > width && width > 0 ? math.max(0.75, width / widest) : 1.0;
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      textScaler: k == 1 ? null : TextScaler.linear(scaler.scale(style.fontSize ?? 14) / (style.fontSize ?? 14) * k),
    );
  }

  @override
  Widget build(BuildContext context) => maxWidth != null
      ? _text(context, maxWidth!)
      : LayoutBuilder(builder: (context, box) => _text(context, box.maxWidth.isFinite ? box.maxWidth : double.infinity));
}
