import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/prefs.dart';
import '../../core/widgets/ui.dart';
import '../map/map_data.dart';

/// Ward picker sheet that sets the chosen ward (Home, Audit, My Ward).
Future<void> pickWard(BuildContext context, WidgetRef ref) async {
  final code = await chooseWard(context, current: ref.read(chosenWardProvider));
  if (code != null) ref.read(chosenWardProvider.notifier).set(code);
}

/// Ward picker sheet: search and the 24 wards; returns the tapped code (null if dismissed).
Future<String?> chooseWard(BuildContext context, {String? current}) => showModalBottomSheet<String>(
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
  builder: (_) => _WardSheet(current: current),
);

/// Grey pill "Ward E · Byculla ▾" that opens a ward picker (48 dp target).
class WardPillButton extends StatelessWidget {
  const WardPillButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
      child: Center(
        widthFactor: 1,
        child: Pressable(
          onTap: onTap,
          color: c.surfaceAlt,
          borderRadius: AppRadii.pillRadius,
          semanticLabel: '$label. ${context.tr('Change ward')}',
          padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.s12, AppSpacing.s8, AppSpacing.s8, AppSpacing.s8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_outlined, size: AppSpacing.iconSmall, color: c.textPrimary),
              const SizedBox(width: AppSpacing.s4),
              Flexible(child: Text(label, style: context.type.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
              Icon(Icons.expand_more, size: AppSpacing.iconSmall + 2, color: c.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

class _WardSheet extends ConsumerStatefulWidget {
  const _WardSheet({this.current});
  final String? current;
  @override
  ConsumerState<_WardSheet> createState() => _WardSheetState();
}

class _WardSheetState extends ConsumerState<_WardSheet> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final async = ref.watch(mapDataProvider);
    final q = _q.trim().toLowerCase();
    final wards = [
      for (final w in async.value?.wards ?? const <Ward>[])
        if (q.isEmpty || w.code.toLowerCase().contains(q) || w.name.toLowerCase().contains(q)) w,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 1,
      builder: (context, sc) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(header: true, child: Text(context.tr('Choose your ward'), style: t.headline)),
                const SizedBox(height: AppSpacing.s12),
                SearchField(hint: context.tr('Ward or area name'), onChanged: (v) => setState(() => _q = v)),
              ],
            ),
          ),
          Expanded(
            child: switch (async) {
              AsyncData() when wards.isEmpty => ListView(
                controller: sc,
                children: [EmptyState(message: context.tr('No ward matches.'), pictogram: PictogramKind.ward)],
              ),
              AsyncData() => ListView.builder(
                controller: sc,
                itemCount: wards.length,
                itemBuilder: (_, i) {
                  final w = wards[i];
                  final chosen = w.code == widget.current;
                  return ListRow(
                    title: w.name,
                    caption: '${formatInr(w.flaggedInr)} ${context.tr('to review')} · ${formatPercent(w.flaggedShare)}',
                    leading: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: chosen ? c.primary : c.surfaceAlt, shape: BoxShape.circle),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.s4),
                          child: Text(w.code, style: t.label.copyWith(fontWeight: FontWeight.w700, color: chosen ? c.onPrimary : c.textPrimary)),
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 48, child: ProgressBar(value: w.flaggedShare, height: 4, color: c.error)),
                        const SizedBox(width: AppSpacing.s8),
                        SizedBox.square(
                          dimension: AppSpacing.iconSize,
                          child: chosen ? Icon(Icons.check, color: c.textPrimary, semanticLabel: context.tr('Chosen')) : null,
                        ),
                      ],
                    ),
                    divider: i < wards.length - 1,
                    onTap: () => Navigator.pop(context, w.code),
                  );
                },
              ),
              AsyncError() => ListView(
                controller: sc,
                children: [ErrorState(message: context.tr('Could not load wards.'), onRetry: () => ref.invalidate(mapDataProvider))],
              ),
              _ => ListView(controller: sc, children: [Skeleton.rows(count: 8)]),
            },
          ),
        ],
      ),
    );
  }
}
