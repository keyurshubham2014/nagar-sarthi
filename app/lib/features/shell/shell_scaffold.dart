import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session.dart';
import '../../core/i18n.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/saarthee.dart';

/// Wide web: a navigation rail on the left instead of the bottom bar.
const double kRailBreakpoint = 900;

/// Staff (ward officer, corporator) get Audit in the centre; citizens and visitors get Report.
bool isStaff(String? role) => role == 'officer' || role == 'corporator';

/// Five-tab shell: Home, Map, Report/Audit, Contractors, My Ward. Each tab keeps
/// its state (StatefulShellRoute). Back on a tab other than Home goes Home;
/// back on Home leaves the app.
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = isStaff(ref.watch(sessionProvider.select((s) => s?.role)));
    final destinations = [
      (Icons.home_outlined, Icons.home, context.tr('Home')),
      (Icons.map_outlined, Icons.map, context.tr('Map')),
      staff
          ? (Icons.fact_check_outlined, Icons.fact_check, context.tr('Audit'))
          : (Icons.add_circle_outline, Icons.add_circle, context.tr('Report')),
      (Icons.engineering_outlined, Icons.engineering, context.tr('Contractors')),
      (Icons.location_city_outlined, Icons.location_city, context.tr('My Ward')),
    ];
    // Re-tapping the current tab returns it to its first screen.
    void go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);
    final wide = MediaQuery.sizeOf(context).width >= kRailBreakpoint;
    final c = SaartheeColors.of(context);

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
                      onDestinationSelected: go,
                      labelType: NavigationRailLabelType.all,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
                        child: Text('Nagar\nSarthi', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: c.primary)),
                      ),
                      destinations: [
                        for (final (i, d) in destinations.indexed)
                          NavigationRailDestination(
                            icon: Icon(i == 2 ? d.$2 : d.$1, color: i == 2 ? c.sunrise : null),
                            selectedIcon: Icon(d.$2, color: i == 2 ? c.sunrise : c.onPrimaryContainer),
                            label: Text(d.$3),
                          ),
                      ],
                    ),
                  ),
                  VerticalDivider(width: 1, color: c.border),
                  Expanded(child: shell),
                ],
              ),
            )
          : Scaffold(
              body: shell,
              bottomNavigationBar: SaartheeNavigationBar(selectedIndex: shell.currentIndex, onSelected: go, destinations: destinations),
            ),
    );
  }
}
