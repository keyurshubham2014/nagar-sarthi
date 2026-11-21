import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../../core/prefs.dart';
import '../../core/widgets/ui.dart';
import '../map/map_data.dart';
import '../officer/officer_panels.dart';
import 'ward_picker.dart';

/// My Ward tab: the chosen ward's page under a large "Ward E" title with a
/// change-ward pill; the title moves into the top bar as the page scrolls.
class MyWardScreen extends ConsumerStatefulWidget {
  const MyWardScreen({super.key});
  @override
  ConsumerState<MyWardScreen> createState() => _MyWardScreenState();
}

class _MyWardScreenState extends ConsumerState<MyWardScreen> {
  final _sc = ScrollController();

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final code = ref.watch(chosenWardProvider);
    final name = ref.watch(mapDataProvider).value?.wardByCode[code]?.name;
    final title = context.tr('Ward {w}', {'w': code});
    return Scaffold(
      backgroundColor: c.background,
      appBar: TopBar(
        title: title,
        controller: _sc,
        showBack: false,
        actions: [RoundIconButton(icon: Icons.swap_horiz, tooltip: context.tr('Change ward'), onPressed: () => pickWard(context, ref))],
      ),
      body: ExtendUnderTabBar(
        // WardPanel's list is `primary`: it scrolls with this controller, which drives the bar title.
        child: PrimaryScrollController(
          controller: _sc,
          child: WardPanel(
            code,
            key: ValueKey(code),
            header: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.s24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text(title, style: t.display)),
                  if (name != null) ...[
                    const SizedBox(height: AppSpacing.s4),
                    Text(name, style: t.caption.copyWith(fontSize: 15, height: 22 / 15)),
                  ],
                  const SizedBox(height: AppSpacing.s12),
                  WardPillButton(label: context.tr('Change ward'), onTap: () => pickWard(context, ref)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
