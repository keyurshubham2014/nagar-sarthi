import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../app_router.dart';
import '../../core/i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/ui.dart';

import '../../core/flag_strings.dart';
import '../../core/format.dart';

/// One detail page: a title and a body that builds a `ListView(primary: true)` (use [PanelList]).
/// Pushed full screen above the tabs with [pushPanel].
class PanelPage {
  const PanelPage(this.title, this.body);
  final String title;
  final Widget body;
}

/// Opens [page] as a full-screen detail page (back arrow returns to the tab underneath).
void pushPanel(PanelPage page) => appRouter.push('/page', extra: page);

/// Full-screen detail page: [TopBar] (round back button, title fading in on
/// scroll) over [body], whose scroll view starts with a [DetailTitle] headline.
/// [heading] false: the body draws its own headline.
class DetailPage extends StatefulWidget {
  const DetailPage({super.key, required this.title, required this.body, this.subtitle, this.actions = const [], this.heading = true});
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final bool heading;
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final _sc = ScrollController();
  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = context.tr(widget.title);
    return Scaffold(
      backgroundColor: SaartheeColors.of(context).background,
      appBar: TopBar(title: title, controller: _sc, actions: widget.actions),
      body: PrimaryScrollController(
        controller: _sc,
        child: _DetailHeading(title: widget.heading ? title : null, subtitle: widget.subtitle, child: widget.body),
      ),
    );
  }
}

class _DetailHeading extends InheritedWidget {
  const _DetailHeading({required this.title, required this.subtitle, required super.child});
  final String? title;
  final String? subtitle;
  @override
  bool updateShouldNotify(_DetailHeading old) => old.title != title || old.subtitle != subtitle;
}

/// The detail page's headline (and caption), first item of a page body's
/// scroll view; nothing outside a [DetailPage] (e.g. on the My Ward tab).
class DetailTitle extends StatelessWidget {
  const DetailTitle({super.key});
  static bool shown(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_DetailHeading>()?.title != null;
  @override
  Widget build(BuildContext context) {
    final h = context.dependOnInheritedWidgetOfExactType<_DetailHeading>();
    if (h?.title == null) return const SizedBox.shrink();
    return PageTitle(h!.title!, caption: h.subtitle, detail: true);
  }
}

/// Scrollable page body, capped at the content width so wide screens do not
/// stretch it; starts with the page's [DetailTitle].
class PanelList extends StatelessWidget {
  const PanelList({super.key, required this.children, this.controller});
  final List<Widget> children;
  final ScrollController? controller;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final side = math.max(AppSpacing.gutter, (box.maxWidth - AppSpacing.maxContent) / 2 + AppSpacing.gutter);
      return ListView(
        controller: controller,
        primary: controller == null,
        padding: EdgeInsets.only(top: DetailTitle.shown(context) ? 0 : AppSpacing.s16, bottom: AppSpacing.s32),
        children: [
          Padding(padding: EdgeInsets.symmetric(horizontal: side - AppSpacing.gutter), child: const DetailTitle()),
          for (final c in children) Padding(padding: EdgeInsets.symmetric(horizontal: side), child: c),
        ],
      );
    },
  );
}

/// Loading (skeleton rows), error-with-retry and empty states, shaped as a page body.
class PanelMessage extends StatelessWidget {
  const PanelMessage.loading({super.key, this.text = 'Loading…'}) : icon = null, onRetry = null, isError = false;
  const PanelMessage.error(this.text, {super.key, required this.onRetry}) : icon = Icons.error_outline, isError = true;
  const PanelMessage.empty(this.text, {super.key, this.icon = Icons.inbox_outlined}) : onRetry = null, isError = false;

  final String text;
  final IconData? icon;
  final VoidCallback? onRetry;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    // The first line is a fixed sentence (translated); a second line is the error detail.
    final nl = text.indexOf('\n');
    final message = nl < 0 ? context.tr(text) : '${context.tr(text.substring(0, nl))}${text.substring(nl)}';
    return ListView(
      primary: true,
      padding: const EdgeInsets.only(bottom: AppSpacing.s32),
      children: [
        const DetailTitle(),
        const SizedBox(height: AppSpacing.s16),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxContent),
            child: isError
                ? ErrorState(message: message, onRetry: onRetry!)
                : icon == null
                ? Skeleton.rows(count: 6)
                : EmptyState(message: message),
          ),
        ),
      ],
    );
  }
}

/// Renders an [AsyncValue] as a page: loading, error with retry, or [data].
Widget asyncPage<T>(AsyncValue<T> v, {required VoidCallback onRetry, required Widget Function(T) data}) =>
    switch (v) {
      AsyncData(:final value) => data(value),
      AsyncError(:final error) => PanelMessage.error('Could not load this.\n$error', onRetry: onRetry),
      _ => const PanelMessage.loading(),
    };

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sectionTitleTop, bottom: AppSpacing.sectionTitleBottom),
    child: Semantics(header: true, child: Text(text, style: context.type.headline)),
  );
}

/// Small rounded label.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, required this.bg, required this.fg, this.icon});
  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: 3),
    decoration: ShapeDecoration(color: bg, shape: AppRadii.pill),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: AppSpacing.s4)],
        Flexible(child: Text(label, style: context.type.label.copyWith(fontSize: 12, height: 16 / 12, color: fg))),
      ],
    ),
  );
}

/// Labelled bar: [value] of [max], with the figure on the right.
class LabelledBar extends StatelessWidget {
  const LabelledBar({super.key, required this.label, required this.value, required this.max, required this.trailing, this.color});
  final String label;
  final num value;
  final num max;
  final String trailing;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(label, style: t.label)),
              const SizedBox(width: AppSpacing.s8),
              Text(trailing, style: t.label.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          ProgressBar(value: max <= 0 ? 0 : (value / max).clamp(0, 1).toDouble(), color: color, height: 8, semanticLabel: label),
        ],
      ),
    );
  }
}

/// The numbers behind one flag, as label/value rows.
class EvidenceTable extends StatelessWidget {
  const EvidenceTable(this.evidence, {super.key});
  final Map evidence;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = SaartheeColors.of(context);
    return Column(
      children: [
        for (final e in evidence.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
            child: () {
              final label = Text(
                context.tr(evidenceLabels[e.key] ?? '${e.key}'.replaceAll('_', ' ')),
                style: t.bodySmall?.copyWith(color: c.textSecondary),
              );
              // Fixed words (Yes, None, a repair method, a rate basis) translate; ids, dates and ₹ pass through.
              final value = context.tr(formatEvidence('${e.key}', e.value));
              final style = t.bodySmall?.copyWith(color: c.textPrimary, fontWeight: FontWeight.w500);
              // A long value (a list of ids) goes under its label at full width, so ids never split.
              if (value.length > 24) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [label, Text(value, style: style)]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: label),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(child: WordSafeText(value, style: style ?? context.type.caption, textAlign: TextAlign.end)),
                ],
              );
            }(),
          ),
      ],
    );
  }
}

String formatEvidence(String key, dynamic v) {
  if (v == null) return '—';
  if (v is List) return v.isEmpty ? 'None' : v.join(', ');
  if (v == 'Y') return 'Yes';
  if (v == 'N') return 'No';
  if (v is num) {
    if (key.endsWith('_inr')) return formatInr(v);
    if (key.endsWith('_rate')) return formatPercent(v);
    if (key == 'ratio' || key == 'threshold') return '$v×';
  }
  return '$v';
}

/// Tinted panel: a status icon and text (e.g. the warranty note), or a grey
/// panel without a [tone]. Radius 16, no border.
class InfoPanel extends StatelessWidget {
  const InfoPanel({super.key, this.title, this.text, this.child, this.icon, this.tone = StatusTone.neutral});
  final String? title;
  final String? text;
  final Widget? child;
  final IconData? icon;
  final StatusTone tone;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final (fg, bg) = StatusChip.colors(c, tone);
    final neutral = tone == StatusTone.neutral;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadii.tileRadius),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[Icon(icon, size: AppSpacing.iconSmall + 2, color: neutral ? c.textPrimary : fg), const SizedBox(width: AppSpacing.s12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) Text(title!, style: t.bodyStrong.copyWith(color: neutral ? c.textPrimary : fg)),
                if (text != null) Text(text!, style: t.caption.copyWith(fontSize: 14, height: 20 / 14, color: c.textPrimary)),
                ?child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
