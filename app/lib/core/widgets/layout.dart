import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'floating_tab_bar.dart';
import 'saarthee.dart';

/// 40 px round grey icon button in a 48 target (back, close, account...).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.onDark = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool onDark;

  @override
  Widget build(BuildContext context) => HeaderCircleButton(
    tooltip: tooltip,
    onPressed: onPressed,
    onDark: onDark,
    child: Icon(icon, size: 20, color: onDark ? NeemFixed.white : SaartheeColors.of(context).textPrimary),
  );
}

/// Round grey back button that pops the current route.
class BackCircleButton extends StatelessWidget {
  const BackCircleButton({super.key, this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => RoundIconButton(
    icon: Icons.arrow_back,
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
  );
}

/// The 56 px bar row shared by [TopBar] and [LargeTitleScaffold]: back
/// button, a centred 18/700 title at [titleOpacity], trailing actions, and a
/// hairline at [lineOpacity].
class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.title,
    required this.titleOpacity,
    required this.lineOpacity,
    required this.showBack,
    required this.actions,
    this.onBack,
    this.leading,
  });
  final String? title;
  final double titleOpacity;
  final double lineOpacity;
  final bool showBack;
  final List<Widget> actions;
  final VoidCallback? onBack;

  /// Shown instead of the back button; the collapsed title is then hidden (no room).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(bottom: BorderSide(color: c.border.withValues(alpha: lineOpacity))),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: AppSpacing.topBar,
          child: NavigationToolbar(
            leading: showBack
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(start: AppSpacing.s8),
                    child: BackCircleButton(onPressed: onBack),
                  )
                : leading == null
                ? null
                : Padding(padding: const EdgeInsetsDirectional.only(start: AppSpacing.gutter), child: leading),
            middle: title == null || (leading != null && !showBack)
                ? null
                : Opacity(
                    opacity: titleOpacity,
                    child: Semantics(
                      header: titleOpacity > 0.5,
                      child: Text(title!, style: t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
            trailing: actions.isEmpty
                ? null
                : Padding(
                    padding: const EdgeInsetsDirectional.only(end: AppSpacing.s8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                  ),
            middleSpacing: AppSpacing.s8,
          ),
        ),
      ),
    );
  }
}

SystemUiOverlayStyle _statusBar(SaartheeColors c) =>
    (c.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: NeemFixed.transparent);

/// Detail-page top bar: 56 px, round grey back button, title that fades in
/// once [controller] has scrolled past 48 px (always shown without one),
/// optional trailing [actions]. Use as `Scaffold.appBar`.
class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({super.key, this.title, this.controller, this.actions = const [], this.showBack, this.onBack});
  final String? title;
  final ScrollController? controller;
  final List<Widget> actions;

  /// Default: when the route can pop.
  final bool? showBack;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(AppSpacing.topBar);

  @override
  Widget build(BuildContext context) {
    final back = showBack ?? Navigator.of(context).canPop();
    final c = SaartheeColors.of(context);
    Widget row(double k) =>
        _BarRow(title: title, titleOpacity: k, lineOpacity: k, showBack: back, actions: actions, onBack: onBack);
    final sc = controller;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _statusBar(c),
      child: sc == null
          ? row(1)
          : ListenableBuilder(
              listenable: sc,
              builder: (context, _) {
                final off = sc.hasClients && sc.positions.length == 1 ? sc.offset : 0.0;
                return row(((off - 24) / 24).clamp(0.0, 1.0));
              },
            ),
    );
  }
}

/// Large page title: display (root tabs) or headline (detail) style, left
/// aligned in the 20 gutter, optional caption, 8 below.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.caption, this.detail = false, this.trailing});
  final String title;
  final String? caption;
  final bool detail;

  /// Widget at the end of the title line (e.g. an avatar).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = AppTypeScale.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.s4, AppSpacing.gutter, AppSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: detail ? t.headline : t.display)),
                if (caption != null) ...[const SizedBox(height: AppSpacing.s4), Text(caption!, style: t.caption.copyWith(fontSize: 15, height: 22 / 15))],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Page with the large-title behaviour: a big left-aligned [title] that
/// scrolls away while an 18/700 centred title fades into a pinned 56 px bar.
/// Give it [children] (a plain list) or [slivers]. On a tab it extends under
/// the floating tab bar and pads its end so nothing is covered.
class LargeTitleScaffold extends StatefulWidget {
  const LargeTitleScaffold({
    super.key,
    required this.title,
    this.caption,
    this.children,
    this.slivers,
    this.header,
    this.actions = const [],
    this.titleTrailing,
    this.bottomBar,
    this.onRefresh,
    this.controller,
    this.showBack,
    this.detail,
    this.maxWidth = AppSpacing.maxContent,
    this.leading,
  }) : assert((children == null) != (slivers == null), 'Pass children or slivers');

  final String title;
  final String? caption;
  final List<Widget>? children;
  final List<Widget>? slivers;

  /// Above the large title, scrolls with the page (e.g. the ward pill row).
  final Widget? header;

  /// Round buttons on the right of the pinned bar.
  final List<Widget> actions;

  /// Widget at the end of the large title line.
  final Widget? titleTrailing;

  /// Pinned bottom (a [BottomActionBar]).
  final Widget? bottomBar;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;

  /// Default: when the route can pop.
  final bool? showBack;

  /// Headline-size title (detail pages). Default: when the route can pop.
  final bool? detail;
  final double maxWidth;

  /// Pinned bar's start slot when there is no back button (e.g. Home's ward
  /// pill); the collapsed title is then not shown.
  final Widget? leading;

  @override
  State<LargeTitleScaffold> createState() => _LargeTitleScaffoldState();
}

class _LargeTitleScaffoldState extends State<LargeTitleScaffold> {
  final _progress = ValueNotifier<double>(0);

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
      _progress.value = ((n.metrics.pixels - 8) / 32).clamp(0.0, 1.0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final canPop = Navigator.of(context).canPop();
    final back = widget.showBack ?? canPop;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final slivers = [
      SliverPersistentHeader(
        pinned: true,
        delegate: _PinnedBar(
          height: top + AppSpacing.topBar,
          child: ValueListenableBuilder<double>(
            valueListenable: _progress,
            builder: (_, k, _) => _BarRow(
              title: widget.title,
              titleOpacity: k,
              lineOpacity: k,
              showBack: back,
              actions: widget.actions,
              leading: widget.leading,
            ),
          ),
        ),
      ),
      if (widget.header != null) SliverToBoxAdapter(child: widget.header),
      SliverToBoxAdapter(
        child: PageTitle(widget.title, caption: widget.caption, detail: widget.detail ?? canPop, trailing: widget.titleTrailing),
      ),
      ...?widget.slivers,
      if (widget.children != null) SliverList(delegate: SliverChildListDelegate(widget.children!)),
      SliverPadding(padding: EdgeInsets.only(bottom: bottom + AppSpacing.s32)),
    ];
    Widget scroll = CustomScrollView(controller: widget.controller, primary: widget.controller == null, slivers: slivers);
    if (widget.onRefresh != null) {
      scroll = RefreshIndicator(
        onRefresh: widget.onRefresh!,
        edgeOffset: top + AppSpacing.topBar,
        color: c.primary,
        backgroundColor: c.surface,
        child: scroll,
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _statusBar(c),
      child: Scaffold(
        backgroundColor: c.background,
        bottomNavigationBar: widget.bottomBar,
        body: ExtendUnderTabBar(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.maxWidth),
                child: scroll,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinnedBar extends SliverPersistentHeaderDelegate {
  _PinnedBar({required this.height, required this.child});
  final double height;
  final Widget child;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox.expand(child: child);
  @override
  bool shouldRebuild(_PinnedBar old) => old.height != height || old.child != child;
}

/// Pinned bottom bar for the screen's one primary action: background colour,
/// hairline top, 16 padding plus the safe area; rises with the keyboard.
/// Use as `Scaffold.bottomNavigationBar` (or [LargeTitleScaffold.bottomBar]).
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});

  /// Usually a [PrimaryButton], or a Row of two buttons.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final mq = MediaQuery.of(context);
    return AnimatedPadding(
      duration: AppMotion.of(context, AppMotion.quick),
      curve: AppMotion.quickCurve,
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(color: c.background, border: Border(top: BorderSide(color: c.border))),
        child: Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, AppSpacing.s16 + mq.padding.bottom),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: AppSpacing.maxContent), child: child),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet in the app's style: radius 28 top, 36x4 grabber, drag to
/// dismiss, 40% scrim, sheet motion; optional headline [title]. Opens on the
/// root navigator (above the tab bar). Content scrolls if tall.
Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder, String? title}) =>
    showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      sheetAnimationStyle: AnimationStyle(
        duration: AppMotion.of(context, AppMotion.sheet),
        reverseDuration: AppMotion.of(context, AppMotion.pageOut),
        curve: AppMotion.sheetCurve,
        reverseCurve: AppMotion.pageOutCurve,
      ),
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.s12),
                  child: Semantics(header: true, child: Text(title, style: AppTypeScale.of(sheet).headline)),
                ),
              Flexible(child: SingleChildScrollView(child: builder(sheet))),
            ],
          ),
        ),
      ),
    );
