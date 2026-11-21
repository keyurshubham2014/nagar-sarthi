import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../app_router.dart';
import '../../core/flag_strings.dart';
import '../../core/prefs.dart';
import '../../core/format.dart';
import '../../core/map/civic_map.dart' show CivicMap, MapColors;
import '../../core/widgets/ui.dart';
import '../map/map_data.dart';
import '../map/map_layers.dart';
import 'officer_data.dart';
import 'panel.dart';

const nextRupeeLegend = [
  LegendEntry('Funded, by rank', MapColors.pin),
  LegendEntry('Beyond the budget', MapColors.pin, ring: true),
  LegendEntry('Hospital', MapColors.hospital),
  LegendEntry('School', MapColors.school),
  LegendEntry('Flood hotspot', MapColors.hotspot),
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
    ListView(
      primary: true,
      padding: const EdgeInsets.only(bottom: AppSpacing.s32),
      children: [const DetailTitle(), for (final i in items) _ItemRow(item: i, funded: i['funded'] == true, onTap: () => _openItem(ref, ward, i))],
    ),
  ));
}

LatLng? _ll(Map m) =>
    m['lat'] is num && m['lon'] is num ? LatLng((m['lat'] as num).toDouble(), (m['lon'] as num).toDouble()) : null;

/// Map pin: numbered black circle, filled when funded, outlined when beyond the
/// budget; [more] other items under it show as a "+n" badge.
class RankPin extends StatelessWidget {
  const RankPin({super.key, required this.rank, required this.funded, this.more = 0});
  final Object? rank;
  final bool funded;
  final int more;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: funded ? MapColors.pin : MapColors.label,
          shape: BoxShape.circle,
          border: Border.all(color: funded ? MapColors.label : MapColors.pin, width: 2),
          boxShadow: AppElevation.soft(SaartheeColors.light),
        ),
        child: Text(
          '$rank',
          style: context.type.label.copyWith(color: funded ? MapColors.onPin : MapColors.labelText, fontWeight: FontWeight.w700, height: 1),
        ),
      ),
      if (more > 0)
        PositionedDirectional(
          end: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: 1),
            decoration: const ShapeDecoration(color: MapColors.label, shape: StadiumBorder()),
            child: Text('+$more', style: context.type.label.copyWith(fontSize: 10, height: 1.2, color: MapColors.labelText, fontWeight: FontWeight.w700)),
          ),
        ),
    ],
  );
}

/// Map layer: numbered pins for the chosen ward, plus its hospitals, schools and flood hotspots.
class NextRupeeLayer extends ConsumerWidget {
  const NextRupeeLayer({super.key});

  /// Pins closer than this on screen merge into one (tap lists them); zooming in splits them.
  static const double _pinSize = 34;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pins for the ward selected on the map, else the one picked from a page, else the chosen ward.
    final String? selected = ref.watch(mapFocusProvider.select((s) => s.ward));
    final String ward = selected ?? ref.watch(nextRupeeWardProvider) ?? ref.watch(chosenWardProvider);
    final nr = ref.watch(nextRupeeProvider(ward)).value;
    if (nr == null) return const SizedBox.shrink();
    final camera = MapCamera.of(context);

    Marker place(Map m, IconData icon, Color color, String what) {
      return Marker(
        point: _ll(m)!,
        width: 22,
        height: 22,
        child: Tooltip(
          message: '$what: ${m['name']}',
          child: Container(
            decoration: BoxDecoration(color: MapColors.label, shape: BoxShape.circle, border: Border.all(color: color, width: 1.5)),
            child: Icon(icon, size: 14, color: color, semanticLabel: '$what ${m['name']}'),
          ),
        ),
      );
    }

    // Greedy clustering in rank order at the current zoom: an item joins the first spot
    // whose pin it would overlap on screen, so every pin stays tappable.
    final items = [for (final i in (nr['items'] as List? ?? const [])) if (_ll(i as Map) != null) i as Json]
      ..sort((a, b) => (a['rank'] as num).compareTo(b['rank'] as num));
    final spots = <(Offset, List<Json>)>[];
    for (final i in items) {
      final at = camera.projectAtZoom(_ll(i)!);
      final hit = spots.where((s) => (s.$1 - at).distance < _pinSize).firstOrNull;
      if (hit != null) {
        hit.$2.add(i);
      } else {
        spots.add((at, [i]));
      }
    }
    return MarkerLayer(
      markers: [
        for (final f in (nr['facilities'] as List? ?? const []))
          if (_ll(f) != null)
            f['type'] == 'Hospital'
                ? place(f, Icons.local_hospital, MapColors.hospital, 'Hospital')
                : place(f, Icons.school, MapColors.school, 'School'),
        for (final h in (nr['hotspots'] as List? ?? const []))
          if (_ll(h) != null) place(h, Icons.water_drop, MapColors.hotspot, 'Flood hotspot'),
        // Reverse so the best-ranked spot paints on top.
        for (final (_, group) in spots.reversed)
          Marker(
            point: _ll(group.first)!,
            width: _pinSize,
            height: _pinSize,
            child: Semantics(
              button: true,
              label: group.length == 1
                  ? 'Next rupee rank ${group.first['rank']}: ${group.first['issue']['category']}'
                  : '${group.length} next rupee items here, ranks ${group.map((i) => i['rank']).join(', ')}',
              child: GestureDetector(
                onTap: () => _openSpot(ref, ward, group),
                child: RankPin(rank: group.first['rank'], funded: group.any((i) => i['funded'] == true), more: group.length - 1),
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

  void _set(double v) {
    final next = v < 0 ? 0.0 : v;
    // Light haptic when the funding line crosses an item.
    if (fundedFor(widget.items, next).indexOf(false) != fundedFor(widget.items, _budget).indexOf(false)) lightHaptic();
    setState(() => _budget = next);
  }

  // Quick amounts: percentages of the budget left, or fixed steps when nothing is left.
  List<(String, double)> get _quick {
    final b = widget.base.toDouble();
    if (b <= 0) return [('Current ₹0', 0), ('+₹1 L', 1e5), ('+₹2.5 L', 2.5e5), ('+₹5 L', 5e5)];
    return [('−25%', b * 0.75), ('Now', b), ('+25%', b * 1.25), ('+50%', b * 1.5)];
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
    final t = context.type;
    final items = widget.items;
    final funded = fundedFor(items, _budget);
    final used = [for (final (k, i) in items.indexed) if (funded[k]) _cost(i)].fold<double>(0, (s, v) => s + v);
    final total = items.fold<double>(0, (s, i) => s + _cost(i));
    // Slider reaches twice the budget left or the whole list's cost, whichever is more, in whole lakh.
    final max = (([widget.base * 2, total, 1e5].reduce((a, b) => a > b ? a : b)) / 1e5).ceil() * 1e5;
    final cut = funded.indexOf(false); // first item below the funding line (-1: all funded)
    final changed = (_budget - widget.base).abs() >= 1;
    final counts = '${funded.where((f) => f).length} of ${items.length} items funded · ${formatInr(used)} used · ${formatInr(_budget - used)} left';
    final summary = _summary(funded);

    return Scaffold(
      backgroundColor: c.background,
      bottomNavigationBar: BottomActionBar(
        child: PrimaryButton(label: 'Show the pins on the map', icon: Icons.map_outlined, onPressed: () => showNextRupeeOnMap(ref, widget.ward)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContent),
          child: ListView(
            primary: true,
            padding: const EdgeInsets.only(bottom: AppSpacing.s32),
            children: [
              PageTitle(kNextRupeeAction, caption: 'Ward ${widget.ward} · ranked by need, safety first', detail: true),
              const SizedBox(height: AppSpacing.s16),
              Gutter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Budget to plan with', style: t.label.copyWith(color: c.textSecondary))),
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: AnimatedCount(value: _budget, format: formatInr, style: t.figureXL),
                    ),
                    Text('Budget left now: ${formatInr(widget.base)}', style: t.caption),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                child: Slider(
                  value: _budget.clamp(0, max).toDouble(),
                  max: max.toDouble(),
                  divisions: (max / 5000).round(),
                  label: formatInr(_budget),
                  semanticFormatterCallback: (v) => formatInr(v),
                  onChanged: (v) {
                    // A haptic tick at every lakh.
                    if ((v / 1e5).floor() != (_budget / 1e5).floor()) lightHaptic();
                    _typed.clear();
                    _set(v);
                  },
                ),
              ),
              FilterChipRow(
                children: [
                  for (final (label, v) in _quick)
                    FilterPill(
                      label: label,
                      selected: (_budget - v).abs() < 1,
                      onTap: () {
                        _typed.clear();
                        _set(v);
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Gutter(
                child: TextField(
                  controller: _typed,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(hintText: 'Type an amount, e.g. 7.5', suffixText: 'lakh ₹'),
                  onChanged: (s) {
                    final v = double.tryParse(s.trim());
                    if (v != null) _set(v * 1e5);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              Gutter(
                child: AnimatedSwitcher(
                  duration: AppMotion.of(context, AppMotion.quick),
                  layoutBuilder: (cur, prev) => Stack(alignment: AlignmentDirectional.topStart, children: [...prev, ?cur]),
                  child: Column(
                    key: ValueKey('$counts|$summary'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(counts, style: t.bodyStrong),
                      const SizedBox(height: AppSpacing.s4),
                      Text(summary, style: t.caption.copyWith(fontSize: 14, height: 20 / 14, color: changed ? c.textPrimary : c.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SectionBreak(space: AppSpacing.s32),
              Gutter(
                child: Text(
                  'Ranked by need: severity, nearby hospitals and schools, accidents, flooding and traffic. '
                  'The ranks never change with the budget; only the funding line moves. Tap an item for its score.',
                  style: t.caption,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              if (cut == 0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.s8),
                  child: InfoPanel(
                    icon: Icons.info_outline,
                    tone: StatusTone.warning,
                    text: 'At this budget nothing can be funded yet, except work under warranty.',
                  ),
                ),
              for (var k = 0; k < items.length; k++)
                Column(
                  key: ValueKey(items[k]['rank']),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The line collapses here and opens at its new place, so it slides between rows.
                    AnimatedSize(
                      duration: AppMotion.of(context, AppMotion.standard),
                      curve: AppMotion.standardCurve,
                      child: k == cut ? const _FundingLine() : const SizedBox(width: double.infinity),
                    ),
                    AnimatedOpacity(
                      opacity: funded[k] ? 1 : 0.5,
                      duration: AppMotion.of(context, AppMotion.standard),
                      child: StaggeredEntrance(
                        index: k,
                        child: _ItemRow(
                          item: items[k],
                          funded: funded[k],
                          onTap: () => _openItem(ref, widget.ward, {...items[k], 'funded': funded[k]}),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FundingLine extends StatelessWidget {
  const _FundingLine();
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.s8),
      child: Row(
        children: [
          Expanded(child: Divider(color: c.error, thickness: 2)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
            child: Text(kBudgetEnds, style: context.type.label.copyWith(color: c.error, fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Divider(color: c.error, thickness: 2)),
        ],
      ),
    );
  }
}

/// Factor chips from the item's reasons.
List<(String, IconData)> _factors(Json i) {
  final rs = [for (final r in (i['reasons'] as List? ?? const [])) '$r'];
  return [
    if (rs.any((r) => r.startsWith('Near hospital'))) ('Hospital', PictogramKind.hospital.icon),
    if (rs.any((r) => r.startsWith('Near school'))) ('School', PictogramKind.school.icon),
    if (rs.any((r) => r.startsWith('Flood hotspot'))) ('Flood spot', PictogramKind.flood.icon),
    if (((i['parts'] as Map?)?['traffic'] as num? ?? 0) >= 7) ('Heavy traffic', PictogramKind.traffic.icon),
  ];
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
    final factors = _factors(item);
    final warranty = item['claim_under_dlp'] == true;
    return Semantics(
      label: funded ? 'Funded' : 'Beyond the budget',
      child: ListRow(
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
          child: Text('${item['rank']}', style: context.type.label.copyWith(color: c.onPrimary, fontWeight: FontWeight.w700)),
        ),
        title: '${issue['category']} · ${issue['locality']}',
        caption: 'Score ${item['score']}',
        chip: factors.isEmpty && !warranty
            ? null
            : Wrap(
                spacing: AppSpacing.s4,
                runSpacing: AppSpacing.s4,
                children: [
                  if (warranty) Tag(kWarrantyClaimTag, bg: c.infoTint, fg: c.info, icon: Icons.verified_user_outlined),
                  for (final (label, icon) in factors) Tag(label, bg: c.surfaceAlt, fg: c.textPrimary, icon: icon),
                ],
              ),
        amount: formatInr(item['cost_to_ward_inr'] as num? ?? 0),
        onTap: onTap,
      ),
    );
  }
}

String _score(num v) {
  final r = (v * 100).round() / 100;
  return r == r.roundToDouble() ? '${r.round()}' : '$r';
}

/// Why this item ranks where it does: the five score parts against their weights,
/// the recommended repair, and the warranty note where it applies.
class NextRupeeDetail extends ConsumerWidget {
  const NextRupeeDetail(this.item, {super.key});
  final Json item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final weights = (ref.watch(mapDataProvider).value?.meta['weights'] as Map?) ??
        const {'severity': 30, 'access': 30, 'accidents': 20, 'flood': 10, 'traffic': 10};
    final parts = item['parts'] as Map? ?? const {};
    final issue = item['issue'] as Map;
    final funded = item['funded'] == true;
    return PanelList(
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: StatusChip(funded ? 'Within budget' : 'Beyond the budget', tone: funded ? StatusTone.success : StatusTone.neutral, dot: true),
        ),
        const SizedBox(height: AppSpacing.s16),
        HeroFigure(
          caption: 'Need score',
          value: item['score'] as num? ?? 0,
          format: (v) => '${_score(v)} of 100',
          explanation: 'Complaints: ${(issue['complaint_ids'] as List? ?? const []).join(', ')} · ${issue['upvotes'] ?? 0} upvotes',
        ),
        if (_ll(item) case final at?) ...[
          const SizedBox(height: AppSpacing.s16),
          ClipRRect(
            borderRadius: AppRadii.cardRadius,
            child: SizedBox(
              height: 180,
              child: IgnorePointer(
                child: CivicMap(
                  semanticLabel: 'Map of ${issue['locality']} with this item\'s pin',
                  center: at,
                  initialZoom: 15.5,
                  interactive: false,
                  layers: [
                    // Roads give the pin context even when map tiles do not load.
                    if (ref.watch(mapDataProvider).value case final data?)
                      PolylineLayer(
                        polylines: [
                          for (final r in data.roads)
                            Polyline(points: r.points, color: roadStatusColors[r.status] ?? MapColors.road, strokeWidth: 4),
                        ],
                      ),
                    MarkerLayer(
                      markers: [Marker(point: at, width: 34, height: 34, child: RankPin(rank: item['rank'], funded: funded))],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SectionTitle('Score breakdown'),
        for (final (i, e) in scorePartLabels.entries.indexed)
          StaggeredEntrance(
            index: i,
            child: LabelledBar(
              label: '${e.value} · weight ${weights[e.key] ?? 0}',
              value: parts[e.key] as num? ?? 0,
              max: weights[e.key] as num? ?? 0,
              trailing: '${_score(parts[e.key] as num? ?? 0)} / ${weights[e.key] ?? 0}',
            ),
          ),
        const SizedBox(height: AppSpacing.s24),
        InfoPanel(
          icon: Icons.handyman_outlined,
          title: 'Recommended repair',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.s4),
              Text('${item['recommended_method']}', style: t.body),
              Text('Re-opens ${formatPercent(item['method_reopen_rate'] as num? ?? 0)} of the time in this season’s data',
                  style: t.caption.copyWith(fontSize: 14, height: 20 / 14)),
              const SizedBox(height: AppSpacing.s8),
              EvidenceTable({
                'Estimated cost': formatInr(item['est_cost_inr'] as num? ?? 0),
                'Cost to ward': formatInr(item['cost_to_ward_inr'] as num? ?? 0),
              }),
            ],
          ),
        ),
        if (item['claim_under_dlp'] == true) ...[
          const SizedBox(height: AppSpacing.s12),
          const InfoPanel(icon: Icons.verified_user_outlined, tone: StatusTone.info, title: kUnderWarranty, text: kWarrantyClaimTag),
        ],
        const SectionTitle('Reasons'),
        for (final r in (item['reasons'] as List? ?? const []))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s8, right: AppSpacing.s12),
                  child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c.textPrimary, shape: BoxShape.circle)),
                ),
                Expanded(child: Text('$r', style: t.body)),
              ],
            ),
          ),
      ],
    );
  }
}
