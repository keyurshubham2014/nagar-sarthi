import 'dart:ui' as ui;
import '../../core/i18n.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../map/map_data.dart';
import '../officer/officer_data.dart';
import '../officer/panel.dart';
import 'citizen_panels.dart';

/// Ward report card: a clean card rendered to PNG, shared on Android, downloaded on web.
class ReportCardPage extends StatefulWidget {
  const ReportCardPage({super.key, this.ward});
  final String? ward;
  @override
  State<ReportCardPage> createState() => _ReportCardPageState();
}

class _ReportCardPageState extends State<ReportCardPage> {
  late String? _ward = widget.ward;
  @override
  Widget build(BuildContext context) {
    final ward = _ward;
    return PanelList(
      children: [
        WardPicker(selected: ward, onSelected: (v) => setState(() => _ward = v)),
        const SizedBox(height: AppSpacing.s12),
        if (ward == null) Text(context.tr('Pick a ward to see its report card.')) else _CardLoader(ward, key: ValueKey(ward)),
      ],
    );
  }
}

class _CardLoader extends ConsumerStatefulWidget {
  const _CardLoader(this.code, {super.key});
  final String code;
  @override
  ConsumerState<_CardLoader> createState() => _CardLoaderState();
}

class _CardLoaderState extends ConsumerState<_CardLoader> {
  final _boundary = GlobalKey();
  bool _sharing = false;
  String? _shareError;

  Future<void> _share() async {
    setState(() {
      _sharing = true;
      _shareError = null;
    });
    try {
      final ro = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await ro.toImage(pixelRatio: 3);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final name = 'ward-${widget.code.replaceAll('/', '-')}-report-card.png';
      final file = XFile.fromData(png, mimeType: 'image/png', name: name);
      if (kIsWeb) {
        await file.saveTo(name); // web: triggers a PNG download
      } else {
        await SharePlus.instance.share(
          ShareParams(files: [file], fileNameOverrides: [name], text: 'Ward ${widget.code} road repairs: report card from Nagar Sarthi'),
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
    final code = widget.code;
    final w = ref.watch(wardDetailProvider(code));
    final nr = ref.watch(nextRupeeProvider(code));
    final disclaimer = ref.watch(mapDataProvider).value?.disclaimer ?? kDefaultDisclaimer;
    if (w.hasError || nr.hasError) {
      return ListTile(
        title: Text('Could not load the report card. ${w.error ?? nr.error}'),
        trailing: TextButton(
          onPressed: () {
            ref.invalidate(wardDetailProvider(code));
            ref.invalidate(nextRupeeProvider(code));
          },
          child: Text(context.tr('Retry')),
        ),
      );
    }
    final (wd, nd) = (w.value, nr.value);
    if (wd == null || nd == null) return const LinearProgressIndicator();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(key: _boundary, child: WardReportCard(ward: wd, nextRupee: nd, disclaimer: disclaimer)),
        const SizedBox(height: AppSpacing.s12),
        FilledButton.icon(
          onPressed: _sharing ? null : _share,
          icon: _sharing
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(kIsWeb ? Icons.download : Icons.share),
          label: Text(context.tr(kIsWeb ? 'Download image' : 'Share image')),
        ),
        if (_shareError != null) Text(_shareError!, style: TextStyle(color: SaartheeColors.of(context).error)),
      ],
    );
  }
}

/// The card itself: fixed light colours so the shared image looks the same in any theme.
class WardReportCard extends StatelessWidget {
  const WardReportCard({super.key, required this.ward, required this.nextRupee, required this.disclaimer});
  final Json ward;
  final Json nextRupee;
  final String disclaimer;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1A1A1A), soft = Color(0xFF5F6368), accent = Color(0xFF0B6E4F), warn = Color(0xFFB3261E);
    final budget = ward['budget'] as num? ?? 0;
    final spend = ward['spend'] as num? ?? 0;
    final bft = (ward['by_flag_type'] as Map?) ?? const {};
    final jobs = ((ward['by_method'] as List?) ?? const []).fold<num>(0, (s, m) => s + (m['jobs'] as num));
    final failed = (bft['fix_failed'] as Map?)?['count'] as num? ?? 0;
    final neverFixed = (ward['never_fixed'] as List?)?.length ?? 0;
    final items = [...(nextRupee['items'] as List? ?? const [])]..sort((a, b) => (a['rank'] as num).compareTo(b['rank'] as num));
    final top = items.firstOrNull as Map?;
    const label = TextStyle(color: soft, fontSize: 12);
    const big = TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w700);

    Widget stat(String value, String text, {Color color = ink}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(value, style: big.copyWith(color: color)), Text(text, style: label)],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDADCE0)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: ink, fontSize: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('WARD REPORT CARD · ROAD REPAIRS 2025'), style: const TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(context.tr('Ward {w}', {'w': ward['code']}), style: big.copyWith(fontSize: 26)),
            Text('${ward['name']}', style: label.copyWith(fontSize: 14)),
            const SizedBox(height: 16),
            Text(context.tr('Spent {spend} of {budget} budget', {'spend': formatInr(spend), 'budget': formatInr(budget)}), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: budget <= 0 ? 1 : (spend / budget).clamp(0, 1).toDouble(),
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
              color: spend > budget ? warn : accent,
              backgroundColor: const Color(0xFFE8EAED),
            ),
            if (spend > budget) Text(context.tr('{amount} over budget', {'amount': formatInr(spend - budget)}), style: label.copyWith(color: warn)),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stat(formatInr(ward['flagged_inr'] as num? ?? 0), context.tr('to be reviewed')),
                stat(jobs == 0 ? '—' : formatPercent(failed / jobs), context.tr('of repairs failed\nwithin 30 days'), color: warn),
                stat('$neverFixed', context.tr('open issues\nnever fixed')),
              ],
            ),
            const SizedBox(height: 16),
            Text(context.tr('Next rupee should go to'), style: label),
            Text(
              top == null
                  ? context.tr('No items listed')
                  : '${top['issue']['category']}, ${top['issue']['locality']} · ${formatInr(top['est_cost_inr'] as num? ?? 0)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(child: Text(context.tr(disclaimer), style: label.copyWith(fontSize: 10))),
                const SizedBox(width: 8),
                const Text('Nagar Sarthi', style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
