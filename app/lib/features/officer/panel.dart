import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../app_router.dart';
import '../../core/i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/saarthee.dart';

import '../../core/flag_strings.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';

/// One detail page: a title and a body that builds a `ListView(primary: true)` (use [PanelList]).
/// Pushed full screen above the tabs with [pushPanel].
class PanelPage {
  const PanelPage(this.title, this.body);
  final String title;
  final Widget body;
}

/// Opens [page] as a full-screen detail page (back arrow returns to the tab underneath).
void pushPanel(PanelPage page) => appRouter.push('/page', extra: page);

/// Full-screen page for a [PanelPage]: Saarthee app bar with back arrow, body below.
class DetailPage extends StatelessWidget {
  const DetailPage({super.key, required this.title, required this.body, this.subtitle, this.actions = const []});
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SaartheeAppBar(title: context.tr(title), subtitle: subtitle, actions: actions),
    body: body,
  );
}

/// Scrollable page body, capped at the content width so wide screens do not stretch it.
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
        padding: EdgeInsets.fromLTRB(side, AppSpacing.s16, side, AppSpacing.s32),
        children: children,
      );
    },
  );
}

/// Loading, error-with-retry and empty states, shaped as a page body.
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
    final c = SaartheeColors.of(context);
    return PanelList(
      children: [
        const SizedBox(height: AppSpacing.s32),
        Center(
          child: icon == null
              ? const SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Icon(icon, size: 40, color: isError ? c.error : c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s12),
        Text(text, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.s12),
          Center(
            child: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ),
        ],
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
    padding: const EdgeInsets.only(top: AppSpacing.s20, bottom: AppSpacing.s8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
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
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: AppRadii.controlRadius),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
        Flexible(child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg))),
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
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: t.bodyMedium, overflow: TextOverflow.ellipsis)),
              Text(trailing, style: t.labelLarge),
            ],
          ),
          const SizedBox(height: 2),
          LinearProgressIndicator(
            value: max <= 0 ? 0 : (value / max).clamp(0, 1).toDouble(),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            color: color,
          ),
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
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(evidenceLabels[e.key] ?? '${e.key}'.replaceAll('_', ' '),
                      style: t.bodySmall?.copyWith(color: c.textSecondary)),
                ),
                const SizedBox(width: AppSpacing.s8),
                Flexible(child: Text(formatEvidence('${e.key}', e.value), style: t.bodySmall, textAlign: TextAlign.end)),
              ],
            ),
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
