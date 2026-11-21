import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/flag_strings.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';

/// Below this width panels are a draggable bottom sheet; at or above, a side panel.
const double kSidePanelBreakpoint = 900;

/// One page in the officer panel. [body] builds a `ListView(primary: true)`
/// (use [PanelList]) so the host can drive its scrolling.
class PanelPage {
  const PanelPage(this.title, this.body, {this.ward});
  final String title;
  final Widget body;

  /// Ward this page belongs to, if any. Next-rupee pins stay only while a page for their ward is open.
  final String? ward;
}

/// The officer panel is a stack of pages: [open] replaces it, [push] drills in,
/// the header's back button pops. The map stays live underneath.
class PanelStack extends Notifier<List<PanelPage>> {
  @override
  List<PanelPage> build() => const [];
  void open(PanelPage p) => state = [p];
  void push(PanelPage p) => state = [...state, p];
  void pop() => state = state.sublist(0, state.length - 1);
  void close() => state = const [];
}

final panelProvider = NotifierProvider<PanelStack, List<PanelPage>>(PanelStack.new);

/// Lives in the map home's Stack; shows the top page of [panelProvider].
class PanelHost extends ConsumerStatefulWidget {
  const PanelHost({super.key});
  @override
  ConsumerState<PanelHost> createState() => _PanelHostState();
}

class _PanelHostState extends ConsumerState<PanelHost> {
  final _sideScroll = ScrollController();

  @override
  void dispose() {
    _sideScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stack = ref.watch(panelProvider);
    if (stack.isEmpty) return const SizedBox.shrink();
    final page = stack.last;
    final c = SaartheeColors.of(context);

    Widget content(ScrollController sc) => Material(
      color: c.surface,
      elevation: 6,
      borderRadius: MediaQuery.sizeOf(context).width >= kSidePanelBreakpoint
          ? AppRadii.cardRadius
          : AppRadii.sheetTop,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _Header(page: page, canPop: stack.length > 1),
          const Divider(height: 1),
          Expanded(
            child: PrimaryScrollController(
              controller: sc,
              // Key per page so each page starts at the top.
              child: KeyedSubtree(key: ObjectKey(page), child: page.body),
            ),
          ),
        ],
      ),
    );

    if (MediaQuery.sizeOf(context).width >= kSidePanelBreakpoint) {
      return Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 56, AppSpacing.s8, AppSpacing.s8),
          child: SizedBox(width: 420, child: content(_sideScroll)),
        ),
      );
    }
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.15,
      maxChildSize: 0.95,
      snap: true,
      builder: (context, sc) => content(sc),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.page, required this.canPop});
  final PanelPage page;
  final bool canPop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(panelProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s4, AppSpacing.s4, AppSpacing.s4),
      child: Row(
        children: [
          if (canPop)
            IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: n.pop)
          else
            const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              context.tr(page.title),
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(tooltip: 'Close panel', icon: const Icon(Icons.close), onPressed: n.close),
        ],
      ),
    );
  }
}

/// Scrollable page body driven by the host's scroll controller.
class PanelList extends StatelessWidget {
  const PanelList({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
    primary: true,
    padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.s8, AppSpacing.gutter, AppSpacing.s32),
    children: children,
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
