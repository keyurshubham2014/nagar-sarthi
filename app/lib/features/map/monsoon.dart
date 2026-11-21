import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_client.dart';
import '../../core/flag_strings.dart';
import '../../core/theme/tokens.dart';
import '../officer/panel.dart';
import 'map_data.dart';
import 'map_layers.dart';

// Monsoon mode colours.
const Color kMonsoonGrey = Color(0xFFA0A0A0);
const Color kMonsoonGlow = Color(0xFFFFB300);
const Color kMonsoonRed = Color(0xFFD32F2F);
const Color kMonsoonDot = Color(0xFF1E88E5);
const Color kRainWash = Color(0xFF64B5F6);
const Duration kMonsoonStep = Duration(milliseconds: 80); // 153 days ≈ 12 s

const Map<String, Color> alertColors = {
  'Green': Color(0xFF2E7D32),
  'Yellow': Color(0xFFF9A825),
  'Orange': Color(0xFFEF6C00),
  'Red': Color(0xFFC62828),
};

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _date(String iso) {
  final p = iso.split('-');
  return '${int.parse(p[2])} ${_months[int.parse(p[1]) - 1]} ${p[0]}';
}

String _count(int n) => n < 1000 ? '$n' : '${n ~/ 1000},${'${n % 1000}'.padLeft(3, '0')}';

/// The season, indexed by day once at load so a slider tick is a lookup.
class Season {
  Season(List<dynamic> rows, MapData map) : roads = map.roads {
    var complaints = 0, repairs = 0, failed = 0;
    final failedRoads = <String>{};
    for (var i = 0; i < rows.length; i++) {
      final d = rows[i] as Map<String, dynamic>;
      days.add(d);
      complaints += d['n'] as int;
      for (final id in d['r'] as List) {
        repairs++;
        // Repaired after an earlier day's failed fix: paid for more than once.
        if (failedRoads.contains(id)) firstPaidAgain.putIfAbsent(id as String, () => i);
        repairDays.putIfAbsent(id as String, () => []).add(i);
      }
      for (final id in d['x'] as List) {
        failed++;
        failedFrom.putIfAbsent(id as String, () => i);
        failedRoads.add(id);
      }
      complaintsSoFar.add(complaints);
      repairsSoFar.add(repairs);
      failedSoFar.add(failed);
      paidAgainSoFar.add(firstPaidAgain.values.where((v) => v <= i).length);
    }
  }

  final List<Road> roads;
  final List<Map<String, dynamic>> days = [];
  final List<int> complaintsSoFar = [], repairsSoFar = [], failedSoFar = [], paidAgainSoFar = [];
  final Map<String, List<int>> repairDays = {};
  final Map<String, int> failedFrom = {};
  final Map<String, int> firstPaidAgain = {};

  int get last => days.length - 1;
  String dateLabel(int i) => _date(days[i]['d'] as String);
  String? alert(int i) => days[i]['alert'] as String?;
  bool heavy(int i) => const {'Orange', 'Red'}.contains(alert(i));

  late final List<List<Polyline>?> _lines = List.filled(days.length, null);
  late final List<List<CircleMarker>?> _dots = List.filled(days.length, null);

  /// One polyline list per day, sorted grey, glow, red, pulse so the layer batches its paths.
  List<Polyline> lines(int i) => _lines[i] ??= _buildLines(i);
  List<CircleMarker> dots(int i) => _dots[i] ??= _buildDots(i);

  List<Polyline> _buildLines(int i) {
    final grey = <Polyline>[], glow = <Polyline>[], red = <Polyline>[], pulse = <Polyline>[];
    for (final r in roads) {
      final rd = repairDays[r.id] ?? const [];
      final recent = rd.any((d) => d <= i && d > i - 7);
      final isRed = (failedFrom[r.id] ?? 1 << 20) <= i;
      // Repaired again after a failed fix: pulse for the repair day and two after.
      final pulsing = isRed && rd.any((d) => d <= i && d > i - 3 && d > failedFrom[r.id]!);
      if (pulsing) {
        pulse.add(Polyline(points: r.points, color: kMonsoonGlow, strokeWidth: 9, borderColor: kMonsoonRed, borderStrokeWidth: 2));
      } else if (isRed) {
        red.add(Polyline(points: r.points, color: kMonsoonRed, strokeWidth: 4.5));
      } else if (recent) {
        glow.add(Polyline(points: r.points, color: kMonsoonGlow, strokeWidth: 6, borderColor: Colors.white, borderStrokeWidth: 1));
      } else {
        grey.add(Polyline(points: r.points, color: kMonsoonGrey, strokeWidth: 2.5));
      }
    }
    return [...grey, ...glow, ...red, ...pulse];
  }

  late final Map<String, LatLng> _mid = {for (final r in roads) r.id: r.points[r.points.length ~/ 2]};

  List<CircleMarker> _buildDots(int i) => [
    for (var a = 4; a >= 0; a--)
      if (i - a >= 0)
        for (final p in days[i - a]['c'] as List)
          CircleMarker(
            point: LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
            radius: 3.5,
            color: kMonsoonDot.withValues(alpha: 0.85 * (1 - a / 5)),
          ),
    // "Paid again" marker at the road's midpoint, kept once it appears.
    for (final e in firstPaidAgain.entries)
      if (e.value <= i && _mid[e.key] != null)
        CircleMarker(point: _mid[e.key]!, radius: 2.5, color: Colors.white, borderColor: const Color(0xFF7F0000), borderStrokeWidth: 1.2),
  ];
}

/// Timeline loaded once, joined to the road geometry.
final seasonProvider = FutureProvider<Season>(retry: (_, _) => null, (ref) async {
  final api = ref.watch(apiClientProvider);
  final results = await Future.wait([api.timeline(), ref.watch(mapDataProvider.future)]);
  return Season(results[0] as List, results[1] as MapData);
});

typedef MonsoonState = ({int day, bool playing});

/// Slider state, in its own notifier so only the monsoon layers rebuild per tick. null = monsoon mode off.
class MonsoonController extends Notifier<MonsoonState?> {
  Timer? _timer;

  @override
  MonsoonState? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void play(int last) {
    _timer?.cancel();
    final s = state;
    state = (day: s == null || s.day >= last ? 0 : s.day, playing: true);
    _timer = Timer.periodic(kMonsoonStep, (_) {
      final next = state!.day + 1;
      if (next >= last) _timer?.cancel();
      state = (day: next.clamp(0, last), playing: next < last);
    });
  }

  void pause() {
    _timer?.cancel();
    if (state != null) state = (day: state!.day, playing: false);
  }

  void seek(int day) {
    _timer?.cancel();
    state = (day: day, playing: false);
  }

  void exit() {
    _timer?.cancel();
    state = null;
  }
}

final monsoonProvider = NotifierProvider<MonsoonController, MonsoonState?>(MonsoonController.new);

/// Legend shown in monsoon mode in place of the road status legend.
final MapLayerDef monsoonLegend = MapLayerDef(
  id: 'monsoon',
  label: 'Monsoon',
  legendTitle: 'Monsoon 2025',
  build: (_) => const SizedBox.shrink(),
  legend: [
    const LegendEntry(kMonsoonNotYet, kMonsoonGrey, line: true),
    const LegendEntry(kMonsoonRecent, kMonsoonGlow, line: true),
    LegendEntry(flagLabels['fix_failed']!, kMonsoonRed, line: true),
    const LegendEntry('$kRepairedAgain (white ring)', kMonsoonRed),
    const LegendEntry(kMonsoonDots, kMonsoonDot),
    const LegendEntry(kMonsoonRainTint, kRainWash),
  ],
);

int? _day(WidgetRef ref) => ref.watch(monsoonProvider.select((s) => s?.day));

/// Light blue wash over the tiles on Orange and Red alert days.
class MonsoonRainWash extends ConsumerWidget {
  const MonsoonRainWash({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = _day(ref);
    final season = ref.watch(seasonProvider).value;
    final heavy = day != null && season != null && season.heavy(day);
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        color: kRainWash.withValues(alpha: heavy ? (season.alert(day) == 'Red' ? 0.38 : 0.26) : 0),
      ),
    );
  }
}

/// All roads for the day as ONE polyline layer.
class MonsoonRoadLayer extends ConsumerWidget {
  const MonsoonRoadLayer({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = _day(ref);
    final season = ref.watch(seasonProvider).value;
    if (day == null || season == null) return const SizedBox.shrink();
    return PolylineLayer(polylines: season.lines(day));
  }
}

/// The day's complaints (fading) and "paid again" rings as ONE circle layer.
class MonsoonDotLayer extends ConsumerWidget {
  const MonsoonDotLayer({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = _day(ref);
    final season = ref.watch(seasonProvider).value;
    if (day == null || season == null) return const SizedBox.shrink();
    return CircleLayer(circles: season.dots(day));
  }
}

/// Bottom bar: play/pause/replay, slider, date, rain and running counters.
class MonsoonBar extends ConsumerWidget {
  const MonsoonBar({super.key, required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!wide && ref.watch(panelProvider.select((p) => p.isNotEmpty))) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final async = ref.watch(seasonProvider);
    final s = ref.watch(monsoonProvider);
    final ctl = ref.read(monsoonProvider.notifier);
    final season = async.value;

    if (season == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
          child: async.hasError
              ? Row(
                  children: [
                    const Expanded(child: Text('Could not load the monsoon timeline')),
                    TextButton(onPressed: () => ref.invalidate(seasonProvider), child: const Text('Retry')),
                  ],
                )
              : const Row(
                  children: [
                    SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: AppSpacing.s8),
                    Text('Loading the monsoon timeline…'),
                  ],
                ),
        ),
      );
    }

    final day = s?.day ?? 0;
    final rain = season.days[day]['rain'] as num?;
    final alert = season.alert(day);
    final atEnd = s != null && !s.playing && day >= season.last;
    final rainText = rain == null ? kMonsoonNoRain : '${rain.toStringAsFixed(rain < 10 ? 1 : 0)} mm rain';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s4, AppSpacing.s12, AppSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton.filled(
                  tooltip: s?.playing == true ? 'Pause' : (atEnd ? 'Replay the season' : kMonsoonPlay),
                  icon: Icon(s?.playing == true ? Icons.pause : (atEnd ? Icons.replay : Icons.play_arrow)),
                  onPressed: () => s?.playing == true ? ctl.pause() : ctl.play(season.last),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.s8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(s == null ? kMonsoonPlay : season.dateLabel(day), style: t.titleSmall),
                      if (s != null) ...[
                        Text(rainText, style: t.bodySmall),
                        if (alert != null) _AlertChip(alert),
                      ],
                    ],
                  ),
                ),
                if (s != null) TextButton(onPressed: ctl.exit, child: const Text(kMonsoonExit)),
              ],
            ),
            Semantics(
              label: 'Day of the 2025 monsoon',
              value: season.dateLabel(day),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(trackHeight: 3),
                child: Slider(
                  value: day.toDouble(),
                  max: season.last.toDouble(),
                  divisions: season.last,
                  onChanged: (v) => ctl.seek(v.round()),
                ),
              ),
            ),
            if (s != null)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s8),
                child: Wrap(
                  spacing: AppSpacing.s12,
                  runSpacing: 2,
                  children: [
                    _Counter(season.complaintsSoFar[day], kMonsoonComplaints, kMonsoonDot),
                    _Counter(season.repairsSoFar[day], kMonsoonRepairs, const Color(0xFFB27C00)),
                    _Counter(season.failedSoFar[day], kMonsoonFailed, kMonsoonRed),
                    _Counter(season.paidAgainSoFar[day], kMonsoonPaidAgain, kMonsoonRed),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter(this.n, this.label, this.color);
  final int n;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: _count(n), style: t.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w800)),
          TextSpan(text: ' $label', style: t.bodySmall),
        ],
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  const _AlertChip(this.alert);
  final String alert;
  @override
  Widget build(BuildContext context) {
    final bg = alertColors[alert] ?? kMonsoonGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        '$alert alert',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: alert == 'Yellow' ? Colors.black : Colors.white),
      ),
    );
  }
}
