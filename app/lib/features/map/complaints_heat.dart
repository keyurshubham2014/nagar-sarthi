import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/flag_strings.dart';
import '../../core/i18n.dart';
import '../../core/map/civic_map.dart';
import '../../core/widgets/ui.dart';

// Cluster shade by complaint count: under 5, under 20, 20+.
const List<int> heatSteps = [5, 20];
const List<Color> heatColors = MapColors.heat;

Color heatColor(int count) => heatColors[heatSteps.where((s) => count >= s).length];

/// Open and repeat complaints clustered on the server (`/api/complaints/heat`).
final heatProvider = FutureProvider<List<dynamic>>(
  retry: (_, _) => null,
  (ref) => ref.watch(apiClientProvider).complaintsHeat(),
);

class ComplaintsHeatLayer extends ConsumerStatefulWidget {
  const ComplaintsHeatLayer({super.key});
  @override
  ConsumerState<ComplaintsHeatLayer> createState() => _ComplaintsHeatLayerState();
}

class _ComplaintsHeatLayerState extends ConsumerState<ComplaintsHeatLayer> {
  final LayerHitNotifier<Map> _hit = ValueNotifier(null);

  @override
  void dispose() {
    _hit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(heatProvider);
    final clusters = async.value;
    if (clusters == null) {
      return _Status(
        text: async.hasError ? '${context.tr('Could not load complaints.')} ${async.error}' : context.tr('Loading complaints…'),
        onRetry: async.hasError ? () => ref.invalidate(heatProvider) : null,
      );
    }
    if (clusters.isEmpty) return _Status(text: context.tr('No open or repeat complaints here'));
    return GestureDetector(
      onTap: () {
        final c = _hit.value?.hitValues.firstOrNull;
        if (c != null) showHeatSheet(context, c);
      },
      child: CircleLayer<Map>(
        hitNotifier: _hit,
        circles: [
          for (final c in clusters.cast<Map>())
            CircleMarker<Map>(
              point: LatLng((c['lat'] as num).toDouble(), (c['lon'] as num).toDouble()),
              radius: math.min(20, 4 + 1.8 * math.sqrt(c['count'] as num)),
              color: heatColor(c['count'] as int).withValues(alpha: 0.75),
              borderColor: MapColors.label,
              borderStrokeWidth: 1.5,
              hitValue: c,
            ),
        ],
      ),
    );
  }
}

/// Floating status pill over the map (loading, error with retry, empty).
class _Status extends StatelessWidget {
  const _Status({required this.text, this.onRetry});
  final String text;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.gutter),
        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s4, AppSpacing.s4, AppSpacing.s4),
        constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
        decoration: ShapeDecoration(color: c.surface, shape: AppRadii.pill, shadows: AppElevation.soft(c)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(text, style: context.type.label)),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: Text(context.tr('Retry')))
            else
              const SizedBox(width: AppSpacing.s12),
          ],
        ),
      ),
    );
  }
}

void showHeatSheet(BuildContext context, Map cluster) {
  final sample = (cluster['sample'] as List).cast<Map>();
  final count = cluster['count'] as int;
  showAppSheet<void>(
    context,
    title: context.tr('{n} complaints here · {open} open', {'n': count, 'open': cluster['open']}),
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gutter(child: Text(context.tr('Showing {n} of {total} (newest first)', {'n': sample.length, 'total': count}), style: context.type.caption)),
        const SizedBox(height: AppSpacing.s8),
        for (final (i, c) in sample.indexed)
          ListRow(
            icon: Icons.report_outlined,
            title: '${context.tr('${c['category']}')} · ${c['locality']}',
            caption:
                '${context.tr('${c['status']}')}${c['repeat'] == true ? ' · ${context.tr(kRepairReopened)}' : ''} · ${(c['received_at'] as String).split(' ').first}',
            chevron: false,
            divider: i < sample.length - 1,
          ),
        const SizedBox(height: AppSpacing.s16),
      ],
    ),
  );
}
