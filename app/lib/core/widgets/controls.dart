import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'motion.dart';

/// Scales its child to 0.97 while a pointer is down (for Material buttons,
/// which keep their own semantics, focus and disabled handling).
class _PressScale extends StatefulWidget {
  const _PressScale({required this.enabled, required this.child});
  final bool enabled;
  final Widget child;
  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return widget.child;
    return Listener(
      onPointerDown: widget.enabled ? (_) => _set(true) : null,
      onPointerUp: (_) => Future.delayed(AppMotion.pressIn, () => _set(false)),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? AppMotion.pressScale : 1,
        duration: _down ? AppMotion.pressIn : AppMotion.pressOut,
        curve: AppMotion.pressCurve,
        child: widget.child,
      ),
    );
  }
}

/// Black pill, 56 high, label 16/700, full width by default. [loading]
/// swaps the label for a 3-dot pulse and keeps the width; it ignores taps
/// while loading. Disabled (null [onPressed]) is light grey with grey text.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.loading = false, this.expand = true});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) => _Button(
    label: label,
    onPressed: onPressed,
    icon: icon,
    loading: loading,
    expand: expand,
    primary: true,
  );
}

/// Grey pill twin of [PrimaryButton].
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon, this.loading = false, this.expand = true});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) => _Button(
    label: label,
    onPressed: onPressed,
    icon: icon,
    loading: loading,
    expand: expand,
    primary: false,
  );
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.onPressed,
    required this.icon,
    required this.loading,
    required this.expand,
    required this.primary,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final fg = primary ? c.onPrimary : c.textPrimary;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: AppSpacing.s8)],
        Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
      ],
    );
    final child = loading
        ? Stack(
            alignment: Alignment.center,
            children: [
              Opacity(opacity: 0, child: content),
              _DotPulse(color: fg),
            ],
          )
        : content;
    final tap = loading || onPressed == null
        ? (onPressed == null ? null : () {})
        : () {
            if (primary) lightHaptic();
            onPressed!();
          };
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(expand ? double.infinity : AppSpacing.touchTarget, AppSpacing.buttonHeight)),
    );
    final button = primary
        ? FilledButton(onPressed: tap, style: style, child: child)
        : OutlinedButton(onPressed: tap, style: style, child: child);
    return Semantics(
      label: loading ? '$label, loading' : null,
      child: _PressScale(enabled: tap != null && !loading, child: button),
    );
  }
}

/// Three pulsing dots (chat typing state); secondary text colour by default.
class DotPulse extends StatelessWidget {
  const DotPulse({super.key, this.color});
  final Color? color;
  @override
  Widget build(BuildContext context) => _DotPulse(color: color ?? SaartheeColors.of(context).textSecondary);
}

/// Three dots pulsing in turn (loading state of buttons and chat).
class _DotPulse extends StatefulWidget {
  const _DotPulse({required this.color});
  final Color color;
  @override
  State<_DotPulse> createState() => _DotPulseState();
}

class _DotPulseState extends State<_DotPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _c.value = 0.5;
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Opacity(
            // Each dot peaks a third of a cycle after the previous one.
            opacity: 0.3 + 0.7 * (1 - (((_c.value - i / 3) % 1) * 2 - 1).abs()),
            child: Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
          ),
        ],
      ],
    ),
  );
}

/// Filter pill: grey; selected = black with white text. Light haptic on tap.
/// 36 visual height inside a 48 target. Use inside [FilterChipRow].
class FilterPill extends StatefulWidget {
  const FilterPill({super.key, required this.label, required this.selected, required this.onTap, this.icon, this.count});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Leading icon (e.g. for a pill that opens a picker sheet).
  final IconData? icon;
  final int? count;

  @override
  State<FilterPill> createState() => _FilterPillState();
}

class _FilterPillState extends State<FilterPill> {
  @override
  void initState() {
    super.initState();
    if (widget.selected) _reveal(Duration.zero);
  }

  @override
  void didUpdateWidget(FilterPill old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) _reveal(AppMotion.of(context, AppMotion.standard));
  }

  /// Scrolls the chip row (only that row, not the page) just enough that the
  /// selected pill is fully in view; a pill already in view does not move it.
  void _reveal(Duration d) => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final s = Scrollable.maybeOf(context);
    final box = context.findRenderObject();
    if (s == null || box == null || s.position.axis != Axis.horizontal) return;
    for (final policy in [ScrollPositionAlignmentPolicy.keepVisibleAtEnd, ScrollPositionAlignmentPolicy.keepVisibleAtStart]) {
      s.position.ensureVisible(box, alignmentPolicy: policy, duration: d, curve: AppMotion.standardCurve);
    }
  });

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final selected = widget.selected;
    final onTap = widget.onTap;
    final icon = widget.icon;
    final count = widget.count;
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    final fg = selected ? c.onPrimary : c.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Pressable(
        onTap: onTap,
        haptic: true,
        selected: selected,
        semanticLabel: count == null ? label : '$label, $count',
        borderRadius: AppRadii.pillRadius,
        color: selected ? c.primary : c.surfaceAlt,
        pressedColor: selected ? c.primaryDark : c.surfacePressed,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14),
        child: SizedBox(
          height: 36,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 6)],
              Text(label, style: t.label.copyWith(color: fg)),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text('$count', style: t.label.copyWith(color: selected ? c.onPrimarySubtle : c.textSecondary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal scroller of [FilterPill]s with the 20 gutter and faded edges.
/// Full bleed: owns its gutter.
class FilterChipRow extends StatelessWidget {
  const FilterChipRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (rect) {
      final f = rect.width == 0 ? 0.0 : (AppSpacing.gutter / rect.width).clamp(0.0, 0.5);
      return LinearGradient(
        colors: const [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
        stops: [0, f, 1 - f, 1],
      ).createShader(rect);
    },
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Row(
        children: [
          for (final (i, w) in children.indexed) ...[if (i > 0) const SizedBox(width: AppSpacing.s8), w],
        ],
      ),
    ),
  );
}

/// Grey pill search field, 52 high, leading search icon, clear button; a
/// 2 px outline and a little more width on focus.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    this.controller,
    this.hint = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.keyboardType,
  });
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputType? keyboardType;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _text = widget.controller ?? TextEditingController();
  late final FocusNode _focus = widget.focusNode ?? FocusNode();

  @override
  void initState() {
    super.initState();
    _text.addListener(_changed);
    _focus.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _text.removeListener(_changed);
    _focus.removeListener(_changed);
    if (widget.controller == null) _text.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    final focused = _focus.hasFocus;
    const pill = OutlineInputBorder(borderRadius: AppRadii.pillRadius, borderSide: BorderSide.none);
    return AnimatedPadding(
      duration: AppMotion.of(context, AppMotion.quick),
      curve: AppMotion.quickCurve,
      padding: EdgeInsets.symmetric(horizontal: focused ? 0 : AppSpacing.s4),
      child: SizedBox(
        height: AppSpacing.searchHeight,
        child: TextField(
          controller: _text,
          focusNode: _focus,
          autofocus: widget.autofocus,
          keyboardType: widget.keyboardType,
          textInputAction: TextInputAction.search,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          style: t.body,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: widget.hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s14),
            prefixIcon: Icon(Icons.search, color: c.textPrimary),
            suffixIcon: _text.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.cancel, size: 20),
                    color: c.textSecondary,
                    onPressed: () {
                      _text.clear();
                      widget.onChanged?.call('');
                    },
                  ),
            border: pill,
            enabledBorder: pill,
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadii.pillRadius,
              borderSide: BorderSide(color: c.primary, width: AppSpacing.focusWidth),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grey segmented control with a sliding white thumb (two or three
/// segments). Selection change is a quick slide.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({super.key, required this.segments, required this.value, required this.onChanged});

  /// (value, label) pairs.
  final List<(T, String)> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    final n = segments.length;
    final i = segments.indexWhere((s) => s.$1 == value);
    return Container(
      height: AppSpacing.touchTarget,
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: ShapeDecoration(color: c.surfaceAlt, shape: AppRadii.pill),
      child: Stack(
        children: [
          if (i >= 0)
            AnimatedAlign(
              duration: AppMotion.of(context, AppMotion.quick),
              curve: AppMotion.quickCurve,
              alignment: Alignment(n == 1 ? 0 : -1 + 2 * i / (n - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: c.isDark ? c.surfacePressed : c.surface,
                    shape: AppRadii.pill,
                    shadows: AppElevation.soft(c),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final (j, s) in segments.indexed)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: j == i,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (j != i) {
                          lightHaptic();
                          onChanged(s.$1);
                        }
                      },
                      child: Center(
                        child: Text(
                          s.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.label.copyWith(
                            color: j == i ? c.textPrimary : c.textSecondary,
                            fontWeight: j == i ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
