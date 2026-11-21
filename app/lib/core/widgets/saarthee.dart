import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

// Adapted from Saarthee core/widgets (navigation_bar, app_bar, home_header,
// report_card, cards, page_layout). Saarthee's l10n, motion and haptics are
// dropped; strings come from core/i18n.dart.

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
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox.square(
          dimension: AppSpacing.touchTarget,
          child: Material(
            type: MaterialType.transparency,
            child: InkResponse(
              onTap: onPressed,
              radius: AppSpacing.touchTarget / 2,
              child: Center(
                child: Container(
                  width: AppSpacing.headerButton,
                  height: AppSpacing.headerButton,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: onDark ? NeemFixed.headerButton : c.surfaceAlt),
                  child: ExcludeSemantics(child: child),
                ),
              ),
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
        builder: (sheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(sheet.tr('Language'), style: Theme.of(sheet).textTheme.titleLarge),
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

  @override
  Size get preferredSize => Size.fromHeight((subtitle == null ? 64 : 72) + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final canPop = showBack && Navigator.of(context).canPop();
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: subtitle == null ? 64 : 72,
      leading: canPop
          ? IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop())
          : null,
      titleSpacing: canPop ? 0 : AppSpacing.gutter,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              // Long titles drop to the smaller title size and wrap to a second line.
              style: title.length > 22 ? t.titleLarge : t.headlineSmall,
              maxLines: subtitle == null ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (subtitle != null) Text(subtitle!, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
      actions: [...actions, const SizedBox(width: AppSpacing.s8)],
      shape: Border(bottom: BorderSide(color: c.border)),
      bottom: bottom,
    );
  }
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

/// The `sunrise` action card: ≥ 56 dp, "+" in a circle, title + hint, arrow, glow.
/// The only `sunrise` element on its screen (Report actions only).
class SunriseActionCard extends StatelessWidget {
  const SunriseActionCard({super.key, required this.title, required this.hint, required this.onPressed, this.icon = Icons.add});
  final String title;
  final String hint;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final fg = c.onSunrise;
    return Semantics(
      button: true,
      label: '$title. $hint',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: AppRadii.controlRadius, boxShadow: AppElevation.reportGlow(c)),
        child: Material(
          color: c.sunrise,
          borderRadius: AppRadii.controlRadius,
          child: InkWell(
            borderRadius: AppRadii.controlRadius,
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSpacing.reportCardMinHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: fg.withValues(alpha: 0.2)),
                      child: Icon(icon, color: fg, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: t.titleMedium?.copyWith(color: fg)),
                          Text(hint, style: t.bodySmall?.copyWith(color: fg)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward, color: fg),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White card on the header band for staff (same shape as the sunrise card, no sunrise).
class HeaderActionCard extends StatelessWidget {
  const HeaderActionCard({super.key, required this.title, required this.hint, required this.onPressed, required this.icon});
  final String title;
  final String hint;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    return Material(
      color: c.surface,
      borderRadius: AppRadii.controlRadius,
      elevation: 2,
      shadowColor: c.shadow.withValues(alpha: 0.2),
      child: InkWell(
        borderRadius: AppRadii.controlRadius,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.reportCardMinHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c.primaryContainer),
                  child: Icon(icon, color: c.onPrimaryContainer, size: 20),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.titleMedium),
                      Text(hint, style: t.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, color: c.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stat tile (DS §5): `surfaceAlt`, radius 14, figure and a small label.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.color});
  final String value;
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: AppRadii.controlRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: AppTypography.numeric(c).copyWith(color: color)),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
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
          if (i > 0) const SizedBox(width: AppSpacing.s8),
          Expanded(child: tiles[i]),
        ],
      ],
    ),
  );
}

/// Section heading (DS §4: 24 above, 12 below, titleLarge).
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sectionTitleTop, bottom: AppSpacing.s8),
    child: Row(
      children: [
        Expanded(
          child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Rounded white card with a leading icon badge, title, subtitle and chevron; whole card tappable.
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
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius, side: BorderSide(color: c.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: subtitle == null ? 56 : 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
              child: Row(
                children: [
                  Container(
                    width: AppSpacing.categoryBadge,
                    height: AppSpacing.categoryBadge,
                    decoration: BoxDecoration(color: c.primaryContainer, borderRadius: AppRadii.controlRadius),
                    child: Icon(icon, color: c.onPrimaryContainer, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: t.titleMedium),
                        if (subtitle != null) Text(subtitle!, style: t.bodySmall),
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
      ),
    );
  }
}
