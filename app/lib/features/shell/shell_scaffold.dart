import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session.dart';
import '../../core/i18n.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/floating_tab_bar.dart';
import '../../core/widgets/motion.dart';

/// Wide web: a navigation rail on the left instead of the floating tab bar.
const double kRailBreakpoint = AppSpacing.railBreakpoint;

/// Staff (ward officer, corporator) get Audit in the centre; citizens and visitors get Report.
bool isStaff(String? role) => role == 'officer' || role == 'corporator';

const int _mapTab = 1;

/// Five-tab shell: Home, Map, Report/Audit, Contractors, My Ward, on a
/// floating pill tab bar (left rail when wide). Each tab keeps its state;
/// tab changes fade through. The bar hides while scrolling down a long list
/// and returns on scroll up; it always shows on Map. Back on a tab other
/// than Home goes Home; back on Home leaves the app.
class ShellScaffold extends ConsumerStatefulWidget {
  const ShellScaffold({super.key, required this.shell});
  final StatefulNavigationShell shell;

  /// `StatefulShellRoute.navigatorContainerBuilder`: the tabs, fading through.
  static Widget branchContainer(BuildContext context, StatefulNavigationShell shell, List<Widget> children) =>
      _FadeThroughBranches(index: shell.currentIndex, children: children);

  @override
  ConsumerState<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<ShellScaffold> with SingleTickerProviderStateMixin {
  late final AnimationController _shown = AnimationController(vsync: this, duration: AppMotion.standard, value: 1);
  late final Animation<double> _curve = CurvedAnimation(parent: _shown, curve: AppMotion.standardCurve);

  void _setVisible(bool v) {
    _shown.duration = AppMotion.of(context, AppMotion.standard);
    if (v) {
      _shown.forward();
    } else {
      _shown.reverse();
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (widget.shell.currentIndex == _mapTab) return false;
    if (n is UserScrollNotification) {
      // Short pages keep the bar.
      if (n.metrics.maxScrollExtent < 160) return false;
      if (n.direction == ScrollDirection.reverse) _setVisible(false);
      if (n.direction == ScrollDirection.forward) _setVisible(true);
    } else if (n is ScrollEndNotification && n.metrics.pixels <= n.metrics.minScrollExtent) {
      _setVisible(true);
    }
    return false;
  }

  @override
  void didUpdateWidget(ShellScaffold old) {
    super.didUpdateWidget(old);
    if (old.shell.currentIndex != widget.shell.currentIndex) {
      _setVisible(true);
      // A search field focused on the tab we left must not keep the keyboard up here.
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  void dispose() {
    _shown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    final staff = isStaff(ref.watch(sessionProvider.select((s) => s?.role)));
    final items = [
      TabBarItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: context.tr('Home')),
      TabBarItem(icon: Icons.map_outlined, selectedIcon: Icons.map, label: context.tr('Map')),
      staff
          ? TabBarItem(icon: Icons.fact_check_outlined, selectedIcon: Icons.fact_check, label: context.tr('Audit'))
          : TabBarItem(icon: Icons.add_circle_outline, selectedIcon: Icons.add_circle, label: context.tr('Report')),
      TabBarItem(icon: Icons.engineering_outlined, selectedIcon: Icons.engineering, label: context.tr('Contractors')),
      TabBarItem(icon: Icons.location_city_outlined, selectedIcon: Icons.location_city, label: context.tr('My Ward')),
    ];
    // Re-tapping the current tab returns it to its first screen.
    void go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);
    final wide = MediaQuery.sizeOf(context).width >= kRailBreakpoint;
    final c = SaartheeColors.of(context);
    final body = TabBarScope(
      shown: _curve,
      setVisible: _setVisible,
      child: NotificationListener<ScrollNotification>(onNotification: _onScroll, child: shell),
    );

    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.goBranch(0);
      },
      child: wide
          ? Scaffold(
              body: Row(
                children: [
                  SafeArea(
                    right: false,
                    child: NavigationRail(
                      selectedIndex: shell.currentIndex,
                      onDestinationSelected: (i) {
                        if (i != shell.currentIndex) lightHaptic();
                        go(i);
                      },
                      labelType: NavigationRailLabelType.all,
                      minWidth: 88,
                      groupAlignment: -0.9,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
                        child: Text('Nagar\nSarthi', textAlign: TextAlign.center, style: AppTypeScale.of(context).title),
                      ),
                      destinations: [
                        for (final d in items)
                          NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label)),
                      ],
                    ),
                  ),
                  VerticalDivider(width: 1, color: c.border),
                  Expanded(child: body),
                ],
              ),
            )
          : Scaffold(
              extendBody: true,
              body: body,
              bottomNavigationBar: AnimatedBuilder(
                animation: _curve,
                child: FloatingTabBar(items: items, selectedIndex: shell.currentIndex, onSelected: go),
                builder: (context, bar) => IgnorePointer(
                  ignoring: _curve.value < 0.5,
                  child: Transform.translate(
                    offset: Offset(0, (1 - _curve.value) * (AppSpacing.tabBarHeight + AppSpacing.tabBarGap + 40)),
                    child: bar,
                  ),
                ),
              ),
            ),
    );
  }
}

/// The tab navigators, all kept alive (like IndexedStack). On a tab change
/// the old one fades out, then the new one fades in (160 ms fade-through).
class _FadeThroughBranches extends StatefulWidget {
  const _FadeThroughBranches({required this.index, required this.children});
  final int index;
  final List<Widget> children;
  @override
  State<_FadeThroughBranches> createState() => _FadeThroughBranchesState();
}

class _FadeThroughBranchesState extends State<_FadeThroughBranches> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.quick, value: 1);
  late final Animation<double> _in = CurvedAnimation(parent: _c, curve: const Interval(0.35, 1, curve: Curves.easeOut));
  late final Animation<double> _out = ReverseAnimation(
    CurvedAnimation(parent: _c, curve: const Interval(0, 0.35, curve: Curves.easeIn)),
  );
  int? _prev;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && _prev != null) setState(() => _prev = null);
    });
  }

  @override
  void didUpdateWidget(_FadeThroughBranches old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      if (AppMotion.reduced(context)) {
        _prev = null;
        _c.value = 1;
      } else {
        _prev = old.index;
        _c.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (final (i, child) in widget.children.indexed)
        Offstage(
          offstage: i != widget.index && i != _prev,
          child: TickerMode(
            enabled: i == widget.index,
            child: FadeTransition(
              opacity: i == widget.index ? _in : _out,
              child: IgnorePointer(ignoring: i != widget.index, child: _Branch(child: child)),
            ),
          ),
        ),
    ],
  );
}

/// One tab. Unless its screen opts in with [ExtendUnderTabBar], the tab
/// keeps a strip clear for the floating bar (shrinking as the bar hides), so
/// screens built before the redesign are never covered.
class _Branch extends StatefulWidget {
  const _Branch({required this.child});
  final Widget child;
  @override
  State<_Branch> createState() => _BranchState();
}

class _BranchState extends State<_Branch> {
  // Not disposed: ExtendUnderTabBar may decrement it after this tab is gone.
  final _extended = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    final scope = TabBarScope.maybeOf(context);
    final mq = MediaQuery.of(context);
    // With Scaffold.extendBody this is the floating bar's slot (bar + gap + safe area).
    final slot = mq.padding.bottom;
    final shown = scope?.shown ?? const AlwaysStoppedAnimation<double>(1);
    return TabBranchInset(
      extended: _extended,
      child: ValueListenableBuilder<int>(
        valueListenable: _extended,
        child: widget.child,
        builder: (context, n, child) => AnimatedBuilder(
          animation: shown,
          child: child,
          builder: (context, child) => Padding(
            padding: EdgeInsets.only(bottom: n > 0 ? 0 : slot * shown.value),
            child: MediaQuery(
              data: mq.copyWith(padding: mq.padding.copyWith(bottom: n > 0 ? slot : 0)),
              child: child!,
            ),
          ),
        ),
      ),
    );
  }
}
