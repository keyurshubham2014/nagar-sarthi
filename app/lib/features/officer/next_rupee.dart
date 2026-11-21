import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/flag_strings.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../map/map_data.dart';
import '../map/map_layers.dart';
import 'officer_data.dart';
import 'panel.dart';

const Color kFundedPin = Color(0xFF2E7D32);
const Color kUnfundedPin = Color(0xFF757575);
const Color kHospital = Color(0xFFD32F2F);
const Color kSchool = Color(0xFF1565C0);
const Color kHotspot = Color(0xFF00838F);

const nextRupeeLegend = [
  LegendEntry('Funded, by rank', kFundedPin),
  LegendEntry('Beyond the budget', kUnfundedPin),
  LegendEntry('Hospital', kHospital),
  LegendEntry('School', kSchool),
  LegendEntry('Flood hotspot', kHotspot),
];

/// Turns on the next-rupee pins for [ward] and shows its ranked list.
void showNextRupee(WidgetRef ref, String ward) {
  ref.read(nextRupeeWardProvider.notifier).set(ward);
  ref.read(visibleLayersProvider.notifier).set(nextRupeeLayerId, true);
  ref.read(panelProvider.notifier).push(PanelPage('Next rupee · Ward $ward', NextRupeeList(ward)));
}

void _openItem(WidgetRef ref, String ward, Json item) {
  final panel = ref.read(panelProvider.notifier);
  if (ref.read(panelProvider).isEmpty) panel.open(PanelPage('Next rupee · Ward $ward', NextRupeeList(ward)));
  panel.push(PanelPage('#${item['rank']} · ${item['issue']['category']}, ${item['issue']['locality']}', NextRupeeDetail(item)));
}

LatLng? _ll(Map m) =>
    m['lat'] is num && m['lon'] is num ? LatLng((m['lat'] as num).toDouble(), (m['lon'] as num).toDouble()) : null;

/// Map layer: numbered pins for the chosen ward, plus its hospitals, schools and flood hotspots.
class NextRupeeLayer extends ConsumerWidget {
  const NextRupeeLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ward = ref.watch(nextRupeeWardProvider);
    final nr = ward == null ? null : ref.watch(nextRupeeProvider(ward)).value;
    if (ward == null || nr == null) return const SizedBox.shrink();

    Marker place(Map m, IconData icon, Color color, String what) {
      return Marker(
        point: _ll(m)!,
        width: 22,
        height: 22,
        child: Tooltip(
          message: '$what: ${m['name']}',
          child: Container(
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: color, width: 1.5)),
            child: Icon(icon, size: 14, color: color, semanticLabel: '$what ${m['name']}'),
          ),
        ),
      );
    }

    final items = [for (final i in (nr['items'] as List? ?? const [])) i as Json];
    return MarkerLayer(
      markers: [
        for (final f in (nr['facilities'] as List? ?? const []))
          if (_ll(f) != null)
            f['type'] == 'Hospital'
                ? place(f, Icons.local_hospital, kHospital, 'Hospital')
                : place(f, Icons.school, kSchool, 'School'),
        for (final h in (nr['hotspots'] as List? ?? const []))
          if (_ll(h) != null) place(h, Icons.water_drop, kHotspot, 'Flood hotspot'),
        // Reverse so rank 1 paints on top.
        for (final item in items.reversed)
          if (_ll(item) != null)
            Marker(
              point: _ll(item)!,
              width: 34,
              height: 34,
              child: Semantics(
                button: true,
                label: 'Next rupee rank ${item['rank']}: ${item['issue']['category']}',
                child: GestureDetector(
                  onTap: () => _openItem(ref, ward, item),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: item['funded'] == true ? kFundedPin : kUnfundedPin,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [BoxShadow(blurRadius: 3, color: Color(0x55000000))],
                    ),
                    child: Text(
                      '${item['rank']}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// Funded items, then a "budget ends here" divider, then the rest.
class NextRupeeList extends ConsumerWidget {
  const NextRupeeList(this.ward, {super.key});
  final String ward;

  @override
  Widget build(BuildContext context, WidgetRef ref) => asyncPage(
    ref.watch(nextRupeeProvider(ward)),
    onRetry: () => ref.invalidate(nextRupeeProvider(ward)),
    data: (nr) {
      final c = SaartheeColors.of(context);
      final t = Theme.of(context).textTheme;
      final items = [for (final i in (nr['items'] as List? ?? const [])) i as Json];
      if (items.isEmpty) return const PanelMessage.empty('No open issues waiting for repair in this ward.');
      final funded = items.where((i) => i['funded'] == true).toList();
      final rest = items.where((i) => i['funded'] != true).toList();
      Widget row(Json i) => _ItemRow(item: i, onTap: () => _openItem(ref, ward, i));
      return PanelList(
        children: [
          Text('Budget left: ${formatInr(nr['remaining_budget'] as num? ?? 0)}', style: t.titleMedium),
          Text('Ranked by need: severity, nearby hospitals and schools, accidents, flooding and traffic.',
              style: t.bodySmall?.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpacing.s8),
          if (funded.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
              child: Text('No budget remains in this ward, so nothing below can be funded yet.',
                  style: t.bodyMedium?.copyWith(color: c.warning)),
            ),
          ...funded.map(row),
          if (rest.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
              child: Row(
                children: [
                  Expanded(child: Divider(color: c.error, thickness: 1.5)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                    child: Text(kBudgetEnds, style: t.labelLarge?.copyWith(color: c.error)),
                  ),
                  Expanded(child: Divider(color: c.error, thickness: 1.5)),
                ],
              ),
            ),
            ...rest.map(row),
          ],
        ],
      );
    },
  );
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.onTap});
  final Json item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final issue = item['issue'] as Map;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: item['funded'] == true ? kFundedPin : kUnfundedPin,
        child: Text('${item['rank']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      title: Text('${issue['category']} · ${issue['locality']}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Score ${item['score']} · ${formatInr(item['cost_to_ward_inr'] as num? ?? 0)} to ward'),
          if (item['claim_under_dlp'] == true)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Tag(kWarrantyClaimTag, bg: c.infoTint, fg: c.info, icon: Icons.verified_user_outlined),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

/// Why this item ranks where it does: the five score parts against their weights.
class NextRupeeDetail extends ConsumerWidget {
  const NextRupeeDetail(this.item, {super.key});
  final Json item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final weights = (ref.watch(mapDataProvider).value?.meta['weights'] as Map?) ??
        const {'severity': 30, 'access': 30, 'accidents': 20, 'flood': 10, 'traffic': 10};
    final parts = item['parts'] as Map? ?? const {};
    final issue = item['issue'] as Map;
    return PanelList(
      children: [
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s4,
          children: [
            Tag(item['funded'] == true ? 'Within budget' : 'Beyond the budget',
                bg: item['funded'] == true ? c.successTint : c.surfaceAlt,
                fg: item['funded'] == true ? c.success : c.textSecondary),
            if (item['claim_under_dlp'] == true)
              Tag(kWarrantyClaimTag, bg: c.infoTint, fg: c.info, icon: Icons.verified_user_outlined),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Text('Score ${item['score']} of 100', style: t.headlineSmall),
        Text('Complaints: ${(issue['complaint_ids'] as List? ?? const []).join(', ')} · ${issue['upvotes'] ?? 0} upvotes',
            style: t.bodySmall?.copyWith(color: c.textSecondary)),
        const SectionTitle('Score breakdown'),
        for (final e in scorePartLabels.entries)
          LabelledBar(
            label: e.value,
            value: parts[e.key] as num? ?? 0,
            max: weights[e.key] as num? ?? 0,
            trailing: '${parts[e.key] ?? 0} / ${weights[e.key] ?? 0}',
          ),
        const SectionTitle('Reasons'),
        for (final r in (item['reasons'] as List? ?? const []))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text('$r')),
              ],
            ),
          ),
        const SectionTitle('Recommended repair'),
        Text('${item['recommended_method']}', style: t.titleSmall),
        Text('Re-opens ${formatPercent(item['method_reopen_rate'] as num? ?? 0)} of the time in this season’s data',
            style: t.bodySmall),
        const SizedBox(height: AppSpacing.s8),
        Text('Estimated cost ${formatInr(item['est_cost_inr'] as num? ?? 0)}', style: t.bodyMedium),
        Text('Cost to ward ${formatInr(item['cost_to_ward_inr'] as num? ?? 0)}', style: t.bodyMedium),
      ],
    );
  }
}
