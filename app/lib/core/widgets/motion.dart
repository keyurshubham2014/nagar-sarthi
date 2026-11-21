import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Light haptic for the moments the spec names (primary button, tab change,
/// filter chip, funding-line cross). No-op where unsupported (web).
void lightHaptic() => unawaited(HapticFeedback.lightImpact());

/// Tap target with the spec's press feedback: scales to 0.97 and swaps
/// [color] for [pressedColor] (90 ms in, 160 ms out), optional light haptic,
/// keyboard activation and a 2 px focus ring. No ripple.
///
/// With [semanticLabel] the children's own semantics are replaced by it.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.color,
    this.pressedColor,
    this.borderRadius,
    this.circle = false,
    this.padding,
    this.scale = true,
    this.haptic = false,
    this.semanticLabel,
    this.selected,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Resting fill; null = transparent.
  final Color? color;

  /// Fill while pressed; defaults to `surfacePressed` when [color] is set,
  /// otherwise `surfaceAlt` (full-bleed rows).
  final Color? pressedColor;
  final BorderRadius? borderRadius;
  final bool circle;
  final EdgeInsetsGeometry? padding;

  /// Scale to 0.97 while pressed (rows turn this off).
  final bool scale;
  final bool haptic;
  final String? semanticLabel;
  final bool? selected;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _focus = false;
  Timer? _release;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _press(bool v) {
    _release?.cancel();
    if (_down != v && mounted) setState(() => _down = v);
  }

  // A quick tap still shows the press for one "press in" beat.
  void _up() {
    _release?.cancel();
    _release = Timer(AppMotion.pressIn, () => _press(false));
  }

  void _tap() {
    if (widget.haptic) lightHaptic();
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _release?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final reduced = AppMotion.reduced(context);
    final d = reduced ? Duration.zero : (_down ? AppMotion.pressIn : AppMotion.pressOut);
    final rest = widget.color ?? NeemFixed.transparent;
    final pressed = widget.pressedColor ?? (widget.color == null ? c.surfaceAlt : c.surfacePressed);
    final shape = widget.circle ? BoxShape.circle : BoxShape.rectangle;
    final radius = widget.circle ? null : widget.borderRadius;

    Widget body = AnimatedContainer(
      duration: d,
      curve: AppMotion.pressCurve,
      padding: widget.padding,
      decoration: BoxDecoration(color: _down && _enabled ? pressed : rest, shape: shape, borderRadius: radius),
      foregroundDecoration: _focus
          ? BoxDecoration(
              shape: shape,
              borderRadius: radius,
              border: Border.all(color: c.focusRing, width: AppSpacing.focusWidth),
            )
          : null,
      child: widget.child,
    );
    if (widget.scale && !reduced) {
      body = AnimatedScale(
        scale: _down && _enabled ? AppMotion.pressScale : 1,
        duration: d,
        curve: AppMotion.pressCurve,
        child: body,
      );
    }
    return Semantics(
      button: _enabled,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _tap())},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: false,
          onTapDown: _enabled ? (_) => _press(true) : null,
          onTapUp: _enabled ? (_) => _up() : null,
          onTapCancel: _enabled ? () => _press(false) : null,
          onTap: widget.onTap == null ? null : _tap,
          onLongPress: widget.onLongPress,
          child: body,
        ),
      ),
    );
  }
}

/// First-paint entrance for tiles and list rows: fade + 12 px rise, 40 ms
/// apart by [index]. Items at index 6 and beyond appear at once. Plays once per
/// element; reduced motion shows the child immediately.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.standard);
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: AppMotion.standardCurve);
  Timer? _start;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context) || widget.index >= AppMotion.staggerMax) {
      _c.value = 1;
    } else {
      _start = Timer(AppMotion.staggerStep * widget.index, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _a,
    child: AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (_, child) =>
          Transform.translate(offset: Offset(0, (1 - _a.value) * AppMotion.staggerRise), child: child),
    ),
  );
}

/// A number that counts up from zero the first time it appears (600 ms
/// easeOutCubic); later changes jump. Screen readers get the final text.
class AnimatedCount extends StatefulWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.format,
    this.style,
    this.textAlign,
    this.animate = true,
  });

  final num value;

  /// Formats the running value (e.g. `formatInr`); default rounds to an integer.
  final String Function(num v)? format;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool animate;

  @override
  State<AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<AnimatedCount> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.count);
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: AppMotion.countCurve);
  bool _started = false;

  String _fmt(num v) => (widget.format ?? (num v) => v.round().toString())(v);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate || AppMotion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finalText = _fmt(widget.value);
    return Semantics(
      label: finalText,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _a,
        builder: (_, _) {
          final done = _a.value >= 1;
          final v = widget.value is int && !done ? (widget.value * _a.value).round() : widget.value * _a.value;
          return Text(done ? finalText : _fmt(v), style: widget.style, textAlign: widget.textAlign, maxLines: 1);
        },
      ),
    );
  }
}

/// Loading placeholder: wrap grey [SkeletonBox] blocks shaped like the final
/// layout; a highlight sweeps across them every 1200 ms (static under reduced
/// motion). Use instead of spinners on a screen's first load.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child});
  final Widget child;

  /// [count] list-row placeholders: 40 px well (or, without [well], an amount
  /// on the right, as on Audit rows) and two lines.
  static Widget rows({int count = 4, bool well = true}) => Skeleton(
    child: Column(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.s12),
            child: Row(
              children: [
                if (well) ...[const SkeletonBox(width: 40, height: 40, circle: true), const SizedBox(width: AppSpacing.s16)],
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(height: 14, widthFactor: 0.7),
                      SizedBox(height: AppSpacing.s8),
                      SkeletonBox(height: 12, widthFactor: 0.45),
                    ],
                  ),
                ),
                if (!well) ...[const SizedBox(width: AppSpacing.s16), const SkeletonBox(width: 56, height: 14)],
              ],
            ),
          ),
      ],
    ),
  );

  /// A row of [count] stat-tile placeholders.
  static Widget tiles({int count = 3, double height = 88}) => Skeleton(
    child: Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.tileGap),
          Expanded(child: SkeletonBox(height: height, radius: AppRadii.tile)),
        ],
      ],
    ),
  );

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.shimmer);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Semantics(
      label: 'Loading',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final x = -1.5 + 3 * _c.value;
            return LinearGradient(
              begin: Alignment(x - 0.6, 0),
              end: Alignment(x + 0.6, 0),
              colors: [c.surfaceAlt, c.surfacePressed, c.surfaceAlt],
            ).createShader(rect);
          },
          child: child,
        ),
      ),
    );
  }
}

/// One grey block inside a [Skeleton].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.widthFactor, this.radius = 8, this.circle = false});
  final double? width;
  final double height;

  /// Fraction of the available width (when [width] is null).
  final double? widthFactor;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: SaartheeColors.of(context).surfaceAlt,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
    if (width != null || widthFactor == null) return box;
    return FractionallySizedBox(alignment: AlignmentDirectional.centerStart, widthFactor: math.min(1, widthFactor!), child: box);
  }
}
