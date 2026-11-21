import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/widgets/ui.dart';
import '../map/map_data.dart';
import '../officer/officer_data.dart';
import '../officer/panel.dart';
import '../ward/ward_picker.dart';

/// Ward report card: a portrait card rendered to PNG, shared on Android,
/// downloaded on web. The share button is pinned at the bottom.
class ReportCardPage extends ConsumerStatefulWidget {
  const ReportCardPage({super.key, this.ward});
  final String? ward;
  @override
  ConsumerState<ReportCardPage> createState() => _ReportCardPageState();
}

class _ReportCardPageState extends ConsumerState<ReportCardPage> {
  late String? _ward = widget.ward;
  final _boundary = GlobalKey();
  bool _sharing = false;
  String? _shareError;

  Future<void> _share(String code) async {
    setState(() {
      _sharing = true;
      _shareError = null;
    });
    try {
      final ro = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await ro.toImage(pixelRatio: 3);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final name = 'ward-${code.replaceAll('/', '-')}-report-card.png';
      final file = XFile.fromData(png, mimeType: 'image/png', name: name);
      if (kIsWeb) {
        await file.saveTo(name); // web: triggers a PNG download
      } else {
        await SharePlus.instance.share(
          ShareParams(files: [file], fileNameOverrides: [name], text: 'Ward $code road repairs: report card from Nagar Sarthi'),
        );
      }
    } catch (e) {
      debugPrint('[report-card] share failed: $e');
      if (mounted) setState(() => _shareError = 'Could not create the image. Please try again.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final ward = _ward;
    final name = ward == null ? null : ref.watch(mapDataProvider).value?.wardByCode[ward]?.name;
    final ready = ward != null && ref.watch(wardDetailProvider(ward)).hasValue && ref.watch(nextRupeeProvider(ward)).hasValue;
    return Scaffold(
      backgroundColor: c.background,
      bottomNavigationBar: ward == null
          ? null
          : BottomActionBar(
              child: PrimaryButton(
                label: context.tr(kIsWeb ? 'Download image' : 'Share image'),
                icon: kIsWeb ? Icons.download : Icons.ios_share,
                loading: _sharing,
                onPressed: ready && !_sharing ? () => _share(ward) : null,
              ),
            ),
      body: PanelList(
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: WardPillButton(
              label: ward == null ? context.tr('Choose your ward') : '${context.tr('Ward {w}', {'w': ward})}${name == null ? '' : ' · $name'}',
              onTap: () async {
                final code = await chooseWard(context, current: ward);
                if (code != null && mounted) setState(() => _ward = code);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          if (ward == null)
            EmptyState(message: context.tr('Pick a ward to see its report card.'), pictogram: PictogramKind.reportCard)
          else
            _CardLoader(ward, boundary: _boundary, key: ValueKey(ward)),
          if (_shareError != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(_shareError!, style: context.type.body.copyWith(color: c.error)),
          ],
        ],
      ),
    );
  }
}

class _CardLoader extends ConsumerWidget {
  const _CardLoader(this.code, {required this.boundary, super.key});
  final String code;
  final GlobalKey boundary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(wardDetailProvider(code));
    final nr = ref.watch(nextRupeeProvider(code));
    final map = ref.watch(mapDataProvider).value;
    final (wd, nd) = (w.value, nr.value);
    if (wd != null && nd != null) {
      return RepaintBoundary(
        key: boundary,
        child: WardReportCard(ward: wd, nextRupee: nd, disclaimer: map?.disclaimer ?? kDefaultDisclaimer, shape: map?.wardByCode[code]),
      );
    }
    if (w.hasError || nr.hasError) {
      return ErrorState(
        message: context.tr('Could not load the report card.'),
        onRetry: () {
          ref.invalidate(wardDetailProvider(code));
          ref.invalidate(nextRupeeProvider(code));
        },
      );
    }
    return const Skeleton(child: SkeletonBox(height: 520, radius: AppRadii.mapCard));
  }
}

/// The card itself: always the light palette, so the shared image looks the same in any theme.
class WardReportCard extends StatelessWidget {
  const WardReportCard({super.key, required this.ward, required this.nextRupee, required this.disclaimer, this.shape});
  final Json ward;
  final Json nextRupee;
  final String disclaimer;

  /// The ward's boundary for the mini map (none: no map).
  final Ward? shape;

  @override
  Widget build(BuildContext context) {
    const c = SaartheeColors.light;
    final t = AppTypography.scale(c, devanagari: context.lang != 'en');
    final budget = ward['budget'] as num? ?? 0;
    final spend = ward['spend'] as num? ?? 0;
    final bft = (ward['by_flag_type'] as Map?) ?? const {};
    final jobs = ((ward['by_method'] as List?) ?? const []).fold<num>(0, (s, m) => s + (m['jobs'] as num));
    final failed = (bft['fix_failed'] as Map?)?['count'] as num? ?? 0;
    final neverFixed = (ward['never_fixed'] as List?)?.length ?? 0;
    final items = [...(nextRupee['items'] as List? ?? const [])]..sort((a, b) => (a['rank'] as num).compareTo(b['rank'] as num));
    final top = items.firstOrNull as Map?;
    final over = spend > budget;

    Widget figure(String value, String text, {Color? color, Widget? extra}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: t.figureXL.copyWith(color: color ?? c.textPrimary)),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(text.replaceAll('\n', ' '), style: t.caption.copyWith(color: c.textSecondary)),
          ?extra,
        ],
      ),
    );
    final line = Divider(height: 1, thickness: 1, color: c.border);

    return Theme(
      data: Theme.of(context).copyWith(extensions: [c, t]),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s24),
        decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: AppRadii.dialogRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('WARD REPORT CARD · ROAD REPAIRS 2025'), style: t.label.copyWith(fontSize: 12, height: 16 / 12, color: c.textSecondary)),
                      const SizedBox(height: AppSpacing.s8),
                      Text(context.tr('Ward {w}', {'w': ward['code']}), style: t.display.copyWith(color: c.textPrimary)),
                      Text('${ward['name']}', style: t.body.copyWith(color: c.textSecondary)),
                    ],
                  ),
                ),
                if (shape != null) ...[
                  const SizedBox(width: AppSpacing.s12),
                  ExcludeSemantics(
                    child: SizedBox.square(dimension: 84, child: CustomPaint(painter: _WardShape(shape!, c.textPrimary))),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            figure(
              budget <= 0 ? formatInr(spend) : formatPercent(spend / budget),
              context.tr('Spent {spend} of {budget} budget', {'spend': formatInr(spend), 'budget': formatInr(budget)}),
              color: over ? c.error : null,
              extra: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProgressBar(value: budget <= 0 ? 1 : spend / budget, height: 8, trackColor: c.surface),
                    if (over) ...[
                      const SizedBox(height: AppSpacing.s4),
                      Text(context.tr('{amount} over budget', {'amount': formatInr(spend - budget)}), style: t.caption.copyWith(color: c.error)),
                    ],
                  ],
                ),
              ),
            ),
            line,
            figure(formatInr(ward['flagged_inr'] as num? ?? 0), context.tr('to be reviewed')),
            line,
            figure(jobs == 0 ? '—' : formatPercent(failed / jobs), context.tr('of repairs failed\nwithin 30 days'), color: c.error),
            line,
            const SizedBox(height: AppSpacing.s16),
            Row(
              children: [
                Text('$neverFixed', style: t.figure.copyWith(color: c.textPrimary)),
                const SizedBox(width: AppSpacing.s8),
                Expanded(child: Text(context.tr('open issues\nnever fixed').replaceAll('\n', ' '), style: t.caption.copyWith(color: c.textSecondary))),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(context.tr('Next rupee should go to'), style: t.caption.copyWith(color: c.textSecondary)),
            Text(
              top == null
                  ? context.tr('No items listed')
                  : '${top['issue']['category']}, ${top['issue']['locality']} · ${formatInr(top['est_cost_inr'] as num? ?? 0)}',
              style: t.bodyStrong.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: AppSpacing.s24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: Text(context.tr(disclaimer), style: t.caption.copyWith(fontSize: 12, height: 16 / 12, color: c.textSecondary))),
                const SizedBox(width: AppSpacing.s12),
                Text('Nagar Sarthi', style: t.title.copyWith(color: c.textPrimary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The ward's outline as a filled silhouette, fitted to the box.
class _WardShape extends CustomPainter {
  _WardShape(this.ward, this.color);
  final Ward ward;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final b = ward.bounds;
    final k = math.cos(b.center.latitude * math.pi / 180); // shrink longitude to keep the shape true
    final w = (b.east - b.west) * k, h = b.north - b.south;
    if (w <= 0 || h <= 0) return;
    final s = math.min(size.width / w, size.height / h);
    final dx = (size.width - w * s) / 2, dy = (size.height - h * s) / 2;
    Offset p(LatLng l) => Offset(dx + (l.longitude - b.west) * k * s, dy + (b.north - l.latitude) * s);
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final part in ward.parts) {
      for (final ring in part) {
        if (ring.isEmpty) continue;
        path.addPolygon([for (final l in ring) p(l)], true);
      }
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_WardShape old) => old.ward != ward || old.color != color;
}
