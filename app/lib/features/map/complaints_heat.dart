import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_client.dart';
import '../../core/flag_strings.dart';
import '../../core/theme/tokens.dart';

// Cluster shade by complaint count: under 5, under 20, 20+.
const List<int> heatSteps = [5, 20];
const List<Color> heatColors = [Color(0xFF9FA8DA), Color(0xFF5C6BC0), Color(0xFF283593)];

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
        text: async.hasError ? 'Could not load complaints: ${async.error}' : 'Loading complaints…',
        onRetry: async.hasError ? () => ref.invalidate(heatProvider) : null,
      );
    }
    if (clusters.isEmpty) return const _Status(text: 'No open or repeat complaints here');
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
              borderColor: Colors.white,
              borderStrokeWidth: 1.5,
              hitValue: c,
            ),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.text, this.onRetry});
  final String text;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.center,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onRetry == null && text.startsWith('Loading')) ...const [
              SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: AppSpacing.s8),
            ],
            Flexible(child: Text(text)),
            if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    ),
  );
}

void showHeatSheet(BuildContext context, Map cluster) {
  final sample = (cluster['sample'] as List).cast<Map>();
  final count = cluster['count'] as int;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final t = Theme.of(context).textTheme;
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, 0, AppSpacing.s16, AppSpacing.s16),
          children: [
            Text('$count complaints here · ${cluster['open']} $kHeatOpen', style: t.titleMedium),
            Text(
              count > sample.length ? 'Latest ${sample.length} of $count' : 'All $count',
              style: t.bodySmall,
            ),
            for (final c in sample)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${c['category']} · ${c['locality']}'),
                subtitle: Text(
                  '${c['status']}${c['repeat'] == true ? ' · $kRepairReopened' : ''} · ${(c['received_at'] as String).split(' ').first}',
                ),
              ),
          ],
        ),
      );
    },
  );
}
