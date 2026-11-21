import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../app_router.dart';
import '../../core/flag_strings.dart';
import '../../core/prefs.dart';
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

/// Opens the ward's ranked next-rupee list and points the map's pins at that ward.
void showNextRupee(WidgetRef ref, String ward) {
  ref.read(nextRupeeWardProvider.notifier).set(ward);
  appRouter.push(Uri(path: '/next-rupee', queryParameters: {'ward': ward}).toString());
}

/// Turns the pins on for [ward] and shows the Map tab.
void showNextRupeeOnMap(WidgetRef ref, String ward) {
  ref.read(nextRupeeWardProvider.notifier).set(ward);
  ref.read(visibleLayersProvider.notifier).set(nextRupeeLayerId, true);
  ref.read(mapFocusProvider.notifier).focusWard(ward);
  appRouter.go('/map');
}

void _openItem(WidgetRef ref, String ward, Json item) => pushPanel(PanelPage(
  '#${item['rank']} · ${item['issue']['category']}, ${item['issue']['locality']}',
  NextRupeeDetail(item),
));

/// Several items at one spot: one pin, tap opens a chooser listing them.
void _openSpot(WidgetRef ref, String ward, List<Json> items) {
  if (items.length == 1) return _openItem(ref, ward, items.single);
  pushPanel(PanelPage(
    '${items.length} items at this spot · Ward $ward',
    PanelList(children: [for (final i in items) _ItemRow(item: i, funded: i['funded'] == true, onTap: () => _openItem(ref, ward, i))]),
  ));
}

LatLng? _ll(Map m) =>
    m['lat'] is num && m['lon'] is num ? LatLng((m['lat'] as num).toDouble(), (m['lon'] as num).toDouble()) : null;

/// Map layer: numbered pins for the chosen ward, plus its hospitals, schools and flood hotspots.
class NextRupeeLayer extends ConsumerWidget {
  const NextRupeeLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pins for the ward selected on the map, else the one picked from a page, else the chosen ward.
    final String? selected = ref.watch(mapFocusProvider.select((s) => s.ward));
    final String ward = selected ?? ref.watch(nextRupeeWardProvider) ?? ref.watch(chosenWardProvider);
    final nr = ref.watch(nextRupeeProvider(ward)).value;
    if (nr == null) return const SizedBox.shrink();

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

    // Group items that share a point (rank order kept), so stacked pins become one tappable pin.
    final spots = <String, List<Json>>{};
    for (final i in (nr['items'] as List? ?? const [])) {
      final p = _ll(i as Map);
      if (p != null) (spots['${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}'] ??= []).add(i as Json);
    }
    return MarkerLayer(
      markers: [
        for (final f in (nr['facilities'] as List? ?? const []))
          if (_ll(f) != null)
            f['type'] == 'Hospital'
                ? place(f, Icons.local_hospital, kHospital, 'Hospital')
                : place(f, Icons.school, kSchool, 'School'),
        for (final h in (nr['hotspots'] as List? ?? const []))
          if (_ll(h) != null) place(h, Icons.water_drop, kHotspot, 'Flood hotspot'),
        // Reverse so the best-ranked spot paints on top.
        for (final group in spots.values.toList().reversed)
          Marker(
            point: _ll(group.first)!,
            width: 34,
            height: 34,
            child: Semantics(
              button: true,
              label: group.length == 1
                  ? 'Next rupee rank ${group.first['rank']}: ${group.first['issue']['category']}'
                  : '${group.length} next rupee items here, ranks ${group.map((i) => i['rank']).join(', ')}',
              child: GestureDetector(
                onTap: () => _openSpot(ref, ward, group),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: group.any((i) => i['funded'] == true) ? kFundedPin : kUnfundedPin,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [BoxShadow(blurRadius: 3, color: Color(0x55000000))],
                      ),
                      child: Text(
                        '${group.first['rank']}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    if (group.length > 1)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                          child: Text('+${group.length - 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ranked list with a budget what-if: change the budget, and the funding line moves live.
class NextRupeeList extends ConsumerWidget {
  const NextRupeeList(this.ward, {super.key});
  final String ward;

  @override
  Widget build(BuildContext context, WidgetRef ref) => asyncPage(
    ref.watch(nextRupeeProvider(ward)),
    onRetry: () => ref.invalidate(nextRupeeProvider(ward)),
    data: (nr) {
      final items = [for (final i in (nr['items'] as List? ?? const [])) i as Json]
        ..sort((a, b) => (a['rank'] as num).compareTo(b['rank'] as num));
      if (items.isEmpty) return const PanelMessage.empty('No open issues waiting for repair in this ward.');
      return _Planner(ward: ward, items: items, base: nr['remaining_budget'] as num? ?? 0);
    },
  );
}

double _cost(Json i) => (i['cost_to_ward_inr'] as num? ?? 0).toDouble();
bool _warranty(Json i) => i['claim_under_dlp'] == true;

/// The engine's rule (engine/audit.py): walk the items by rank, adding each one's cost to the ward;
/// the list stops at the first item that busts the budget. Warranty items cost the ward ₹0 and are always funded.
List<bool> fundedFor(List<Json> items, num budget) {
  var spent = 0.0;
  var over = false;
  return [
    for (final i in items)
      () {
        spent += _cost(i);
        over = over || spent > budget + 0.005;
        return _warranty(i) || !over;
      }(),
  ];
}

class _Planner extends ConsumerStatefulWidget {
  const _Planner({required this.ward, required this.items, required this.base});
  final String ward;
  final List<Json> items;
  final num base;
  @override
  ConsumerState<_Planner> createState() => _PlannerState();
}

class _PlannerState extends ConsumerState<_Planner> {
  late double _budget = widget.base.toDouble();
  final _typed = TextEditingController();
  late final List<bool> _baseFunded = fundedFor(widget.items, widget.base);

  @override
  void initState() {
    super.initState();
    // Self-check: at the current budget the client rule must match the engine's own funded flags.
    assert(() {
      for (final (k, i) in widget.items.indexed) {
        if (_baseFunded[k] != (i['funded'] == true)) throw StateError('next-rupee rule differs from the engine at rank ${i['rank']}');
      }
      return true;
    }());
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _set(double v) => setState(() => _budget = v < 0 ? 0 : v);

  // Quick amounts: percentages of the budget left, or fixed steps when nothing is left.
  List<(String, double)> get _quick {
    final b = widget.base.toDouble();
    if (b <= 0) return [('Current ₹0', 0), ('+₹1 L', 1e5), ('+₹2.5 L', 2.5e5), ('+₹5 L', 5e5)];
    return [('−25%', b * 0.75), ('Current', b), ('+25%', b * 1.25), ('+50%', b * 1.5)];
  }

  String _near(Iterable<Json> xs) {
    final h = xs.where((i) => (i['reasons'] as List? ?? const []).any((r) => '$r'.startsWith('Near hospital'))).length;
    final s = xs.where((i) => (i['reasons'] as List? ?? const []).any((r) => '$r'.startsWith('Near school'))).length;
    final parts = [if (h > 0) '$h near a hospital', if (s > 0) '$s near a school'];
    return parts.isEmpty ? '' : ', including ${parts.join(' and ')}';
  }

  /// One line: what the change from the current budget buys or drops.
  String _summary(List<bool> funded) {
    final items = widget.items;
    final delta = _budget - widget.base;
    if (delta.abs() < 1) return 'This is the budget left now.';
    final added = [for (final (k, i) in items.indexed) if (funded[k] && !_baseFunded[k]) i];
    final dropped = [for (final (k, i) in items.indexed) if (!funded[k] && _baseFunded[k]) i];
    final d = '${delta > 0 ? '+' : '−'}${formatInr(delta.abs())}';
    if (added.isNotEmpty) return '$d funds ${added.length} more ${added.length == 1 ? 'item' : 'items'}${_near(added)}.';
    if (dropped.isNotEmpty) return '$d drops ${dropped.length} ${dropped.length == 1 ? 'item' : 'items'}${_near(dropped)}.';
    final next = funded.indexOf(false);
    if (next < 0) return '$d changes nothing: every item is already funded.';
    final needed = items.take(next + 1).fold<double>(0, (s, i) => s + _cost(i)) - _budget;
    return '$d funds no more items: the next one needs ${formatInr(needed)} more.';
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final items = widget.items;
    final funded = fundedFor(items, _budget);
    final used = [for (final (k, i) in items.indexed) if (funded[k]) _cost(i)].fold<double>(0, (s, v) => s + v);
    final total = items.fold<double>(0, (s, i) => s + _cost(i));
    // Slider reaches twice the budget left or the whole list's cost, whichever is more, in whole lakh.
    final max = (([widget.base * 2, total, 1e5].reduce((a, b) => a > b ? a : b)) / 1e5).ceil() * 1e5;
    final cut = funded.indexOf(false); // first item below the funding line (-1: all funded)
    final changed = (_budget - widget.base).abs() >= 1;
    Widget row(int k) => _ItemRow(
      item: items[k],
      funded: funded[k],
      onTap: () => _openItem(ref, widget.ward, {...items[k], 'funded': funded[k]}),
    );

    return PanelList(
      children: [
        Text('Budget left now: ${formatInr(widget.base)}', style: t.titleMedium),
        const SizedBox(height: AppSpacing.s8),
        OutlinedButton.icon(
          onPressed: () => showNextRupeeOnMap(ref, widget.ward),
          icon: const Icon(Icons.map_outlined),
          label: const Text('Show the pins on the map'),
        ),
        const SectionTitle('What if the budget changes?'),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: AppElevation.cardDecoration(c),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(formatInr(_budget), style: t.headlineSmall)),
                  if (changed)
                    TextButton.icon(
                      onPressed: () {
                        _typed.clear();
                        _set(widget.base.toDouble());
                      },
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset'),
                    ),
                ],
              ),
              Slider(
                value: _budget.clamp(0, max).toDouble(),
                max: max.toDouble(),
                divisions: (max / 5000).round(),
                label: formatInr(_budget),
                semanticFormatterCallback: (v) => formatInr(v),
                onChanged: (v) {
                  _typed.clear();
                  _set(v);
                },
              ),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s4,
                children: [
                  for (final (label, v) in _quick)
                    ChoiceChip(
                      label: Text(label),
                      selected: (_budget - v).abs() < 1,
                      onSelected: (_) {
                        _typed.clear();
                        _set(v);
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              TextField(
                controller: _typed,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Type an amount', suffixText: 'lakh ₹', hintText: 'e.g. 7.5'),
                onChanged: (s) {
                  final v = double.tryParse(s.trim());
                  if (v != null) _set(v * 1e5);
                },
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                '${funded.where((f) => f).length} of ${items.length} items funded · ${formatInr(used)} used · ${formatInr(_budget - used)} left',
                style: t.titleSmall,
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(_summary(funded), style: t.bodyMedium?.copyWith(color: changed ? c.primary : c.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text('Ranked by need: severity, nearby hospitals and schools, accidents, flooding and traffic. '
            'The ranks never change with the budget; only the funding line moves. Tap an item for its score.',
            style: t.bodySmall?.copyWith(color: c.textSecondary)),
        const SizedBox(height: AppSpacing.s8),
        if (cut == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
            child: Text('At this budget nothing can be funded yet, except work under warranty.', style: t.bodyMedium?.copyWith(color: c.warning)),
          ),
        for (var k = 0; k < items.length; k++) ...[
          if (k == cut)
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
          row(k),
        ],
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.onTap, required this.funded});
  final Json item;
  final VoidCallback onTap;
  final bool funded;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final issue = item['issue'] as Map;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: funded ? kFundedPin : kUnfundedPin,
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
