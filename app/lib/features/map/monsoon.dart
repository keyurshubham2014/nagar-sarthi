import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/flag_strings.dart';
import '../../core/i18n.dart';
import '../../core/map/civic_map.dart';
import '../../core/widgets/ui.dart';
import 'map_data.dart';
import 'map_layers.dart';

// Monsoon mode colours (map tokens).
const Color kMonsoonGrey = MapColors.monsoonIdle;
const Color kMonsoonGlow = MapColors.monsoonRecent;
const Color kMonsoonRed = MapColors.monsoonFailed;
const Color kMonsoonDot = MapColors.complaintDot;
const Color kRainWash = MapColors.rainWash;
const Duration kMonsoonStep = Duration(milliseconds: 80); // 153 days ≈ 12 s at 1×
const List<int> kMonsoonSpeeds = [1, 2, 4];

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
        // Repaired strictly after an earlier day's failed fix.
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
        pulse.add(
          Polyline(
            points: r.points,
            color: kMonsoonGlow,
            strokeWidth: 9,
            borderColor: kMonsoonRed,
            borderStrokeWidth: 2,
          ),
        );
      } else if (isRed) {
        red.add(Polyline(points: r.points, color: kMonsoonRed, strokeWidth: 4.5));
      } else if (recent) {
        glow.add(
          Polyline(
            points: r.points,
            color: kMonsoonGlow,
            strokeWidth: 6,
            borderColor: MapColors.roadCasing,
            borderStrokeWidth: 1,
          ),
        );
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
            // Pops in: small on its first day, overshoots, then settles while it fades.
            radius: const [2.5, 4.5, 3.5, 3.5, 3.5][a],
            color: kMonsoonDot.withValues(alpha: 0.85 * (1 - a / 5)),
          ),
    // "Paid again" marker at the road's midpoint, kept once it appears.
    for (final e in firstPaidAgain.entries)
      if (e.value <= i && _mid[e.key] != null)
        CircleMarker(
          point: _mid[e.key]!,
          radius: 2.5,
          color: MapColors.label,
          borderColor: kMonsoonRed,
          borderStrokeWidth: 1.2,
        ),
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

  /// Playback speed, one of [kMonsoonSpeeds].
  int speed = 1;

  @override
  MonsoonState? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void play(int last) {
    _timer?.cancel();
    final s = state;
    state = (day: s == null || s.day >= last ? 0 : s.day, playing: true);
    _timer = Timer.periodic(kMonsoonStep ~/ speed, (_) {
      final next = state!.day + 1;
      if (next >= last) _timer?.cancel();
      state = (day: next.clamp(0, last), playing: next < last);
    });
  }

  /// Next speed; a playing replay keeps going at the new pace.
  void cycleSpeed(int last) {
    speed = kMonsoonSpeeds[(kMonsoonSpeeds.indexOf(speed) + 1) % kMonsoonSpeeds.length];
    if (state?.playing == true) play(last);
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
        color: kRainWash.withValues(alpha: heavy ? (season.alert(day) == 'Red' ? 0.22 : 0.14) : 0),
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

/// Bottom panel: date, rain, play/pause, scrubber with weekly ticks, speed, running counts, Exit.
class MonsoonBar extends ConsumerWidget {
  const MonsoonBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final async = ref.watch(seasonProvider);
    final s = ref.watch(monsoonProvider);
    final ctl = ref.read(monsoonProvider.notifier);
    final season = async.value;

    Widget panel(Widget child) => Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s16, AppSpacing.s12, AppSpacing.s16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.mapCard),
        boxShadow: AppElevation.floating(c),
      ),
      child: child,
    );

    if (season == null) {
      return panel(
        async.hasError
            ? Row(
                children: [
                  Expanded(child: Text(context.tr('Could not load the monsoon timeline'), style: t.body)),
                  TextButton(onPressed: () => ref.invalidate(seasonProvider), child: Text(context.tr('Retry'))),
                  TextButton(onPressed: ctl.exit, child: Text(context.tr(kMonsoonExit))),
                ],
              )
            : Semantics(
                label: 'Loading the monsoon timeline',
                child: const Skeleton(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 160, height: 28),
                      SizedBox(height: AppSpacing.s16),
                      Row(
                        children: [
                          SkeletonBox(width: 56, height: 56, circle: true),
                          SizedBox(width: AppSpacing.s12),
                          Expanded(child: SkeletonBox(height: 8)),
                        ],
                      ),
                      SizedBox(height: AppSpacing.s16),
                      SkeletonBox(width: 200, height: 24),
                    ],
                  ),
                ),
              ),
      );
    }

    final day = s?.day ?? 0;
    final rain = season.days[day]['rain'] as num?;
    final alert = season.alert(day);
    final playing = s?.playing == true;
    final atEnd = s != null && !playing && day >= season.last;
    final rainText = rain == null ? kMonsoonNoRain : 'Rain ${rain.toStringAsFixed(rain < 10 ? 1 : 0)} mm';
    final playLabel = playing ? 'Pause' : (atEnd ? 'Replay the season' : kMonsoonPlay);

    return panel(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(season.dateLabel(day), style: t.headline),
                    const SizedBox(height: AppSpacing.s8),
                    Wrap(
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s4,
                      children: [
                        StatusChip(rainText, tone: StatusTone.info),
                        if (alert != null) _AlertChip(alert),
                      ],
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: ctl.exit, child: Text(context.tr(kMonsoonExit))),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              Tooltip(
                message: playLabel,
                excludeFromSemantics: true,
                child: Pressable(
                  onTap: () => playing ? ctl.pause() : ctl.play(season.last),
                  semanticLabel: playLabel,
                  circle: true,
                  color: c.primary,
                  pressedColor: c.primaryDark,
                  haptic: true,
                  child: SizedBox.square(
                    dimension: AppSpacing.buttonHeight,
                    child: Icon(playing ? Icons.pause : (atEnd ? Icons.replay : Icons.play_arrow), color: c.onPrimary),
                  ),
                ),
              ),
              Expanded(
                child: _Scrubber(season: season, day: day, onSeek: ctl.seek),
              ),
              _SpeedChip(onTap: () => ctl.cycleSpeed(season.last)),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: _count(season.repairsSoFar[day]), style: t.figure),
                TextSpan(text: '  $kMonsoonRepairs so far', style: t.caption),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Wrap(
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s4,
            children: [
              _Counter(season.complaintsSoFar[day], kMonsoonComplaints, kMonsoonDot),
              _Counter(season.failedSoFar[day], kMonsoonFailed, kMonsoonRed),
              _Counter(season.paidAgainSoFar[day], kMonsoonPaidAgain, kMonsoonRed),
            ],
          ),
        ],
      ),
    );
  }
}

/// Black-on-grey slider over a row of weekly ticks with month initials.
class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.season, required this.day, required this.onSeek});
  final Season season;
  final int day;
  final ValueChanged<int> onSeek;

  // The slider's track is inset by its overlay radius; the ticks use the same inset.
  static const double _inset = 16;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Day of the 2025 monsoon',
          value: season.dateLabel(day),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: c.primary,
              inactiveTrackColor: c.surfaceAlt,
              thumbColor: c.primary,
              overlayColor: c.primary.withValues(alpha: 0.08),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: _inset),
              trackShape: const RoundedRectSliderTrackShape(),
              tickMarkShape: SliderTickMarkShape.noTickMark,
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              value: day.toDouble(),
              max: season.last.toDouble(),
              divisions: season.last,
              onChanged: (v) => onSeek(v.round()),
            ),
          ),
        ),
        ExcludeSemantics(
          child: SizedBox(
            height: 18,
            child: CustomPaint(
              size: Size.infinite,
              painter: _TicksPainter(
                days: [for (final d in season.days) d['d'] as String],
                tick: c.borderStrong,
                text: context.type.caption.copyWith(fontSize: 10, color: c.textSecondary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TicksPainter extends CustomPainter {
  _TicksPainter({required this.days, required this.tick, required this.text});
  final List<String> days;
  final Color tick;
  final TextStyle text;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = _Scrubber._inset;
    final w = size.width - 2 * inset;
    final last = days.length - 1;
    if (last <= 0 || w <= 0) return;
    final p = Paint()
      ..color = tick
      ..strokeWidth = 1;
    double x(int i) => inset + w * i / last;
    for (var i = 0; i <= last; i += 7) {
      canvas.drawLine(Offset(x(i), 0), Offset(x(i), 4), p);
    }
    for (var i = 0; i <= last; i++) {
      if (!days[i].endsWith('-01')) continue;
      final tp = TextPainter(
        text: TextSpan(text: _months[int.parse(days[i].split('-')[1]) - 1], style: text),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((x(i) - tp.width / 2).clamp(0, size.width - tp.width), 5));
    }
  }

  @override
  bool shouldRepaint(_TicksPainter old) => old.days != days || old.tick != tick;
}

/// "1×" / "2×" / "4×": cycles the replay speed.
class _SpeedChip extends ConsumerStatefulWidget {
  const _SpeedChip({required this.onTap});
  final VoidCallback onTap;
  @override
  ConsumerState<_SpeedChip> createState() => _SpeedChipState();
}

class _SpeedChipState extends ConsumerState<_SpeedChip> {
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final speed = ref.read(monsoonProvider.notifier).speed;
    return SizedBox(
      height: AppSpacing.touchTarget,
      child: Center(
        child: Pressable(
          onTap: () => setState(widget.onTap),
          semanticLabel: 'Replay speed $speed times. Tap to change.',
          color: c.surfaceAlt,
          borderRadius: AppRadii.pillRadius,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
          child: Text('$speed×', style: context.type.label),
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
    final t = context.type;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.s4),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: _count(n),
                  style: t.caption.copyWith(color: t.body.color, fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' $label'),
              ],
            ),
            style: t.caption,
          ),
        ),
      ],
    );
  }
}

class _AlertChip extends StatelessWidget {
  const _AlertChip(this.alert);
  final String alert;
  @override
  Widget build(BuildContext context) {
    final bg = MapColors.alert[alert] ?? kMonsoonGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: 3),
      decoration: ShapeDecoration(color: bg, shape: AppRadii.pill),
      child: Text(
        '$alert alert',
        style: context.type.label.copyWith(
          fontSize: 12,
          height: 16 / 12,
          color: alert == 'Yellow' ? MapColors.labelText : MapColors.onPin,
        ),
      ),
    );
  }
}
