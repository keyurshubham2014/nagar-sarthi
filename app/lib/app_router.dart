import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/session.dart';
import 'core/dev/gallery.dart';
import 'features/about/about_screen.dart';
import 'features/audit/audit_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/citizen/ask_bot.dart';
import 'features/citizen/citizen_panels.dart';
import 'features/corporator/corporator_panels.dart';
import 'features/home/home_screen.dart';
import 'features/map/map_data.dart';
import 'features/map/map_screen.dart';
import 'features/officer/next_rupee.dart';
import 'features/officer/officer_panels.dart';
import 'features/officer/panel.dart';
import 'features/shell/shell_scaffold.dart';
import 'features/trail/trail_screen.dart';
import 'features/ward/my_ward_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

String? _q(GoRouterState s, String key) => s.uri.queryParameters[key];

/// Routes. Five tabs in a stateful shell (each keeps its state); detail pages
/// sit above the tabs on the root navigator, so back returns to the tab.
///   /  /map  /act (Report or Audit by role)  /contractors  /my-ward
///   /ward?code=  /road?id=&wo=  /contractor?id=&ward=  /complaint?id=  /track
///   /ask  /next-rupee?ward=  /trail?ward=  /issue?id=  /about  /sign-in  /page (any other detail page, passed as extra)
final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  routes: [
    StatefulShellRoute(
      builder: (context, state, shell) => ShellScaffold(shell: shell),
      navigatorContainerBuilder: ShellScaffold.branchContainer,
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/map', builder: (_, _) => const MapScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/act', builder: (_, _) => const _ActScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/contractors', builder: (_, _) => const ContractorsScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/my-ward', builder: (_, _) => const MyWardScreen())]),
      ],
    ),
    // Hidden dev page: every token and component (not linked from the app).
    GoRoute(path: '/dev/gallery', builder: (_, _) => const GalleryScreen()),
    GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
    GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
    GoRoute(
      path: '/ward',
      redirect: (_, s) => _q(s, 'code') == null ? '/' : null,
      builder: (_, s) => _WardPage(_q(s, 'code')!),
    ),
    GoRoute(
      path: '/road',
      redirect: (_, s) => _q(s, 'id') == null ? '/' : null,
      builder: (_, s) => _RoadPage(_q(s, 'id')!, wo: _q(s, 'wo')),
    ),
    GoRoute(
      path: '/contractor',
      redirect: (_, s) => _q(s, 'id') == null ? '/' : null,
      builder: (_, s) => ContractorPage(id: _q(s, 'id')!, ward: _q(s, 'ward')),
    ),
    GoRoute(
      path: '/complaint',
      redirect: (_, s) => _q(s, 'id') == null ? '/' : null,
      builder: (_, s) => ComplaintDetail(_q(s, 'id')!),
    ),
    GoRoute(path: '/ask', builder: (_, _) => const AskBotPage()),
    GoRoute(path: '/track', builder: (_, _) => const TrackPage()),
    GoRoute(
      path: '/next-rupee',
      redirect: (_, s) => _q(s, 'ward') == null ? '/' : null,
      builder: (_, s) => DetailPage(title: 'Next rupee · Ward ${_q(s, 'ward')}', body: NextRupeeList(_q(s, 'ward')!)),
    ),
    // Complaint trail: no ward opens on all Mumbai.
    GoRoute(
      path: '/trail',
      builder: (_, s) => TrailPage(ward: _q(s, 'ward')),
    ),
    GoRoute(
      path: '/issue',
      redirect: (_, s) => _q(s, 'id') == null ? '/' : null,
      builder: (_, s) => IssueDetail(_q(s, 'id')!),
    ),
    // Detail pages that only make sense mid-flow; after a web reload (no extra) they go Home.
    GoRoute(
      path: '/page',
      redirect: (_, s) => s.extra is PanelPage ? null : '/',
      builder: (_, s) {
        final p = s.extra! as PanelPage;
        return DetailPage(title: p.title, body: p.body);
      },
    ),
  ],
);

/// Centre tab: Audit for staff, Report for citizens and visitors.
class _ActScreen extends ConsumerWidget {
  const _ActScreen();
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      isStaff(ref.watch(sessionProvider.select((s) => s?.role))) ? const AuditScreen() : const ReportScreen();
}

class _WardPage extends ConsumerWidget {
  const _WardPage(this.code);
  final String code;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(mapDataProvider).value?.wardByCode[code]?.name;
    return DetailPage(title: 'Ward $code', subtitle: name, body: WardPanel(code));
  }
}

class _RoadPage extends ConsumerWidget {
  const _RoadPage(this.id, {this.wo});
  final String id;
  final String? wo;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final road = ref.watch(mapDataProvider).value?.roadById[id];
    return DetailPage(
      title: road?.name ?? id,
      subtitle: road == null ? null : 'Ward ${road.wardCode} · $id',
      body: RoadPanel(id, focusWo: wo),
    );
  }
}
