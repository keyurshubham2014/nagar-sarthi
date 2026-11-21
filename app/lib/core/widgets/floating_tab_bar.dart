import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'motion.dart';

/// One tab: outlined icon at rest, filled when active.
class TabBarItem {
  const TabBarItem({required this.icon, required this.selectedIcon, required this.label});
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// White floating pill tab bar: 64 high, 16 above the safe bottom edge, max
/// width 420, shadow. The active item sits in a grey pill that slides between
/// items; its icon swaps outline to filled. Light haptic on change.
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({super.key, required this.items, required this.selectedIndex, required this.onSelected});
  final List<TabBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final n = items.length;
    final quick = AppMotion.of(context, AppMotion.quick);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s12, 0, AppSpacing.s12, AppSpacing.tabBarGap),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.tabBarMaxWidth),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.2,
              child: Container(
                height: AppSpacing.tabBarHeight,
                padding: const EdgeInsets.all(6),
                decoration: ShapeDecoration(
                  color: c.isDark ? c.surfaceAlt : c.surface,
                  shape: AppRadii.pill,
                  shadows: AppElevation.floating(c),
                ),
                child: Stack(
                  children: [
                    AnimatedAlign(
                      duration: quick,
                      curve: AppMotion.quickCurve,
                      alignment: AlignmentDirectional(n == 1 ? 0 : -1 + 2 * selectedIndex / (n - 1), 0),
                      child: FractionallySizedBox(
                        widthFactor: 1 / n,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: c.isDark ? c.surfacePressed : c.primaryContainer,
                            shape: AppRadii.pill,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final (i, item) in items.indexed)
                          Expanded(
                            child: _TabItem(
                              key: Key('nav.$i'),
                              item: item,
                              selected: i == selectedIndex,
                              onTap: () {
                                if (i != selectedIndex) lightHaptic();
                                onSelected(i);
                              },
                            ),
                          ),
                      ],
                    ),
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

class _TabItem extends StatelessWidget {
  const _TabItem({super.key, required this.item, required this.selected, required this.onTap});
  final TabBarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    final color = selected ? c.textPrimary : c.textSecondary;
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: item.label,
      pressedColor: NeemFixed.transparent,
      borderRadius: AppRadii.pillRadius,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.quick),
            child: Icon(selected ? item.selectedIcon : item.icon, key: ValueKey(selected), size: 24, color: color),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.label,
                maxLines: 1,
                style: t.label.copyWith(
                  fontSize: 12,
                  height: 16 / 12,
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Provided by the app shell above the tabs. [shown] runs 0 (hidden) to 1
/// (visible); screens can force the bar with [setVisible].
class TabBarScope extends InheritedWidget {
  const TabBarScope({super.key, required this.shown, required this.setVisible, required super.child});

  final Animation<double> shown;
  final ValueChanged<bool> setVisible;

  static TabBarScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<TabBarScope>();

  @override
  bool updateShouldNotify(TabBarScope old) => old.shown != shown || old.setVisible != setVisible;
}

/// Per-tab registry for [ExtendUnderTabBar] (provided by the shell for each
/// branch).
class TabBranchInset extends InheritedWidget {
  const TabBranchInset({super.key, required this.extended, required super.child});

  /// Number of live [ExtendUnderTabBar]s in this tab.
  final ValueNotifier<int> extended;

  @override
  bool updateShouldNotify(TabBranchInset old) => old.extended != extended;
}

/// Opt-in for redesigned tab screens: the tab's content runs under the
/// floating tab bar (no reserved strip) and `MediaQuery.paddingOf(context)
/// .bottom` below this widget is the bar's height plus the safe area, so pad
/// the end of your scrollable by it. Screens that do not opt in get a
/// reserved strip instead. No-op outside a tab. [LargeTitleScaffold] does
/// this for you.
class ExtendUnderTabBar extends StatefulWidget {
  const ExtendUnderTabBar({super.key, required this.child});
  final Widget child;
  @override
  State<ExtendUnderTabBar> createState() => _ExtendUnderTabBarState();
}

class _ExtendUnderTabBarState extends State<ExtendUnderTabBar> {
  ValueNotifier<int>? _extended;

  @override
  void initState() {
    super.initState();
    // After the frame: the shell rebuilds above us.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _extended = context.getInheritedWidgetOfExactType<TabBranchInset>()?.extended;
      _extended?.value++;
    });
  }

  @override
  void dispose() {
    final e = _extended;
    if (e != null) WidgetsBinding.instance.addPostFrameCallback((_) => e.value--);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
