import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../../core/prefs.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/saarthee.dart';
import '../map/map_data.dart';
import '../officer/officer_panels.dart';
import 'ward_picker.dart';

/// My Ward tab: the chosen ward as a page, with a change-ward card on top.
class MyWardScreen extends ConsumerWidget {
  const MyWardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final code = ref.watch(chosenWardProvider);
    final name = ref.watch(mapDataProvider).value?.wardByCode[code]?.name;
    return Scaffold(
      appBar: SaartheeAppBar(title: context.tr('My Ward'), subtitle: name, showBack: false),
      body: WardPanel(
        code,
        key: ValueKey(code),
        header: Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s8, AppSpacing.s8),
          decoration: AppElevation.cardDecoration(c),
          child: Row(
            children: [
              Icon(Icons.location_city, color: c.primary),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  '${context.tr('Ward {w}', {'w': code})}${name == null ? '' : ' · $name'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(onPressed: () => pickWard(context, ref), child: Text(context.tr('Change'))),
            ],
          ),
        ),
      ),
    );
  }
}
