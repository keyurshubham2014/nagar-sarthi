import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/prefs.dart';
import '../../core/theme/tokens.dart';
import '../map/map_data.dart';

/// Bottom sheet listing the 24 wards with a search box; sets the chosen ward.
Future<void> pickWard(BuildContext context, WidgetRef ref) async {
  final code = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _WardSheet(),
  );
  if (code != null) ref.read(chosenWardProvider.notifier).set(code);
}

class _WardSheet extends ConsumerStatefulWidget {
  const _WardSheet();
  @override
  ConsumerState<_WardSheet> createState() => _WardSheetState();
}

class _WardSheetState extends ConsumerState<_WardSheet> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final chosen = ref.watch(chosenWardProvider);
    final async = ref.watch(mapDataProvider);
    final q = _q.toLowerCase();
    final wards = [
      for (final w in async.value?.wards ?? const <Ward>[])
        if (q.isEmpty || w.code.toLowerCase().contains(q) || w.name.toLowerCase().contains(q)) w,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, sc) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.tr('Choose your ward'), style: t.titleLarge),
                const SizedBox(height: AppSpacing.s8),
                TextField(
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: context.tr('Ward or area name')),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (async) {
              AsyncError(:final error) => Center(
                child: TextButton(onPressed: () => ref.invalidate(mapDataProvider), child: Text('Could not load wards. $error\nRetry')),
              ),
              AsyncData() => ListView(
                controller: sc,
                children: [
                  for (final w in wards)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: w.code == chosen ? c.primary : c.primaryContainer,
                        child: Text(
                          w.code,
                          style: t.labelMedium?.copyWith(color: w.code == chosen ? c.onPrimary : c.onPrimaryContainer),
                        ),
                      ),
                      title: Text(w.name),
                      subtitle: Text('${formatInr(w.flaggedInr)} ${context.tr('to review')}'),
                      trailing: w.code == chosen ? Icon(Icons.check, color: c.primary) : null,
                      onTap: () => Navigator.pop(context, w.code),
                    ),
                ],
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}
