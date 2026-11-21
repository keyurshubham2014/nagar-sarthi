import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'motion.dart';

// The original shared widgets, restyled in place for the design overhaul
// (docs/design/design-overhaul.md): same constructors, new look. New screens
// use the components in ui.dart; these stay until every screen is redesigned.

/// Five labelled tabs with a sliding `primaryContainer` pill behind the active
/// icon; the centre action is always in `sunrise` (Saarthee DS §5).
class SaartheeNavigationBar extends StatelessWidget {
  const SaartheeNavigationBar({super.key, required this.selectedIndex, required this.onSelected, required this.destinations});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// (outlined icon, filled icon, label).
  final List<(IconData, IconData, String)> destinations;

  static const int centreIndex = 2;
  static const double pillWidth = 64;
  static const double pillHeight = 32;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: NavPill(index: selectedIndex, count: destinations.length, color: c.primaryContainer),
              ),
            ),
          ),
          NavigationBar(
            backgroundColor: NeemFixed.transparent,
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            destinations: [
              for (var i = 0; i < destinations.length; i++)
                NavigationDestination(
                  key: Key('nav.$i'),
                  icon: Icon(i == centreIndex ? destinations[i].$2 : destinations[i].$1, color: i == centreIndex ? c.sunrise : null),
                  selectedIcon: Icon(destinations[i].$2, color: i == centreIndex ? c.sunrise : c.onPrimaryContainer),
                  label: destinations[i].$3,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The sliding, stretching pill (transform only).
class NavPill extends StatefulWidget {
  const NavPill({super.key, required this.index, required this.count, required this.color});
  final int index;
  final int count;
  final Color color;
  @override
  State<NavPill> createState() => _NavPillState();
}

class _NavPillState extends State<NavPill> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, value: 1, duration: const Duration(milliseconds: 220));
  late double _from = widget.index.toDouble();

  double get _position => _from + (widget.index - _from) * Curves.easeOutCubic.transform(_c.value);

  @override
  void didUpdateWidget(NavPill old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _from = _position;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final slot = box.maxWidth / widget.count;
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final x = slot * _position + (slot - SaartheeNavigationBar.pillWidth) / 2;
          final stretch = 1 + 0.4 * (1 - (2 * _c.value - 1).abs()) * (_c.isAnimating ? 1 : 0);
          return Stack(
            children: [
              Positioned(
                left: 0,
                top: 12,
                child: Transform.translate(
                  offset: Offset(x, 0),
                  child: Transform.scale(
                    scaleX: stretch,
                    child: Container(
                      width: SaartheeNavigationBar.pillWidth,
                      height: SaartheeNavigationBar.pillHeight,
                      decoration: ShapeDecoration(color: widget.color, shape: const StadiumBorder()),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

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
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true, // above the floating tab bar
        builder: (sheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                child: Align(alignment: Alignment.centerLeft, child: Text(sheet.tr('Language'), style: Theme.of(sheet).textTheme.titleLarge)),
              ),
              const SizedBox(height: AppSpacing.s8),
              for (final e in appLanguages.entries)
                ListTile(
                  title: Text(e.value),
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
      ),
      child: Text(
        glyphs[lang] ?? 'EN',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: onDark ? NeemFixed.white : c.textPrimary),
      ),
    );
  }
}

/// App bar for every non-Home screen: white surface, left-aligned title (up to
/// two lines, so long titles never cut off on a 360 dp phone), optional
/// subtitle, back arrow when the route can pop.
class SaartheeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SaartheeAppBar({super.key, required this.title, this.subtitle, this.actions = const [], this.showBack = true, this.bottom});

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final PreferredSizeWidget? bottom;

  /// Long titles use the smaller title size and may wrap to two lines.
  bool get _long => title.length > 22;
  double get _toolbar => subtitle == null ? (_long ? 72 : 64) : (_long ? 92 : 80);

  @override
  Size get preferredSize => Size.fromHeight(_toolbar + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final t = AppTypeScale.of(context);
    final canPop = showBack && Navigator.of(context).canPop();
    // Root tabs get the large display title; detail pages a headline beside the round back button.
    final style = _long ? t.title : (canPop ? t.headline : t.display.copyWith(fontSize: 30, height: 36 / 30));
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: _toolbar,
      leadingWidth: AppSpacing.touchTarget + AppSpacing.s12,
      leading: canPop
          ? const Padding(padding: EdgeInsetsDirectional.only(start: AppSpacing.s8), child: _BackButton())
          : null,
      titleSpacing: canPop ? AppSpacing.s4 : AppSpacing.gutter,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: style, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          if (subtitle != null) Text(subtitle!, style: t.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
      actions: [...actions, const SizedBox(width: AppSpacing.s8)],
      bottom: bottom,
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();
  @override
  Widget build(BuildContext context) => HeaderCircleButton(
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    onPressed: () => Navigator.of(context).maybePop(),
    child: Icon(Icons.arrow_back, size: 20, color: SaartheeColors.of(context).textPrimary),
  );
}

/// Centers content at max 600 dp wide (DS §4); keeps wide web from stretching.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.padded = true});
  final Widget child;
  final bool padded;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSpacing.maxContent),
      child: padded ? Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter), child: child) : child,
    ),
  );
}

/// The report action: a white search-style card with a black "+" circle,
/// title + hint and an arrow; floats with a soft shadow (works on the dark
/// Home band and on white).
class SunriseActionCard extends StatelessWidget {
  const SunriseActionCard({super.key, required this.title, required this.hint, required this.onPressed, this.icon = Icons.add});
  final String title;
  final String hint;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => _ActionCard(
    title: title,
    hint: hint,
    onPressed: onPressed,
    icon: icon,
    iconFilled: true,
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.title, required this.hint, required this.onPressed, required this.icon, required this.iconFilled});
  final String title;
  final String hint;
  final VoidCallback onPressed;
  final IconData icon;
  final bool iconFilled;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: AppRadii.cardRadius, boxShadow: AppElevation.floating(c)),
      child: Pressable(
        onTap: onPressed,
        semanticLabel: '$title. $hint',
        color: c.isDark ? c.surfaceAlt : c.surface,
        pressedColor: c.isDark ? c.surfacePressed : c.surfaceAlt,
        borderRadius: AppRadii.cardRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.reportCardMinHeight + 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: iconFilled ? c.primary : c.surfaceAlt),
                  child: Icon(icon, color: iconFilled ? c.onPrimary : c.textPrimary, size: 22),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.bodyStrong.copyWith(fontWeight: FontWeight.w700)),
                      Text(hint, style: t.caption),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, color: c.textPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Staff twin of [SunriseActionCard]: same white floating card, grey icon well.
class HeaderActionCard extends StatelessWidget {
  const HeaderActionCard({super.key, required this.title, required this.hint, required this.onPressed, required this.icon});
  final String title;
  final String hint;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => _ActionCard(
    title: title,
    hint: hint,
    onPressed: onPressed,
    icon: icon,
    iconFilled: false,
  );
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
                Flexible(child: Text(label, style: t.caption)),
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
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.tileGap),
          Expanded(child: tiles[i]),
        ],
      ],
    ),
  );
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

/// Grey rounded row: white icon well, title, subtitle and chevron; the whole
/// row is tappable (press: scale + darker grey).
class NavCard extends StatelessWidget {
  const NavCard({super.key, required this.icon, required this.title, this.subtitle, required this.onTap, this.trailing});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Pressable(
        onTap: onTap,
        color: c.surfaceAlt,
        borderRadius: AppRadii.tileRadius,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: subtitle == null ? 56 : AppSpacing.listRow + 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
            child: Row(
              children: [
                Container(
                  width: AppSpacing.categoryBadge,
                  height: AppSpacing.categoryBadge,
                  decoration: BoxDecoration(color: c.isDark ? c.surfacePressed : c.surface, shape: BoxShape.circle),
                  child: Icon(icon, color: c.textPrimary, size: 20),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: t.bodyStrong),
                      if (subtitle != null) Text(subtitle!, style: t.caption),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                trailing ?? Icon(Icons.chevron_right, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
