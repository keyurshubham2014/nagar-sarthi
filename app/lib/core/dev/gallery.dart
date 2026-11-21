import 'package:flutter/material.dart';

import '../format.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Hidden dev page (`/dev/gallery`): every token and component, light or
/// dark, for visual checks. Not linked from the app.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});
  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) => Theme(
    data: _dark ? AppTheme.dark() : AppTheme.light(),
    child: Builder(builder: (context) => _Gallery(dark: _dark, onDark: (v) => setState(() => _dark = v))),
  );
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.dark, required this.onDark});
  final bool dark;
  final ValueChanged<bool> onDark;
  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  String _filter = 'All';
  String _scope = 'ward';
  bool _loading = false;
  bool _switch = true;
  double _slider = 0.4;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    Widget h(String s) => Gutter(child: SectionHeading(s));
    const gap = SizedBox(height: AppSpacing.s12);

    final swatches = <(String, Color)>[
      ('background', c.background),
      ('surface', c.surface),
      ('surfaceAlt', c.surfaceAlt),
      ('surfacePressed', c.surfacePressed),
      ('border', c.border),
      ('borderStrong', c.borderStrong),
      ('textPrimary', c.textPrimary),
      ('textSecondary', c.textSecondary),
      ('textDisabled', c.textDisabled),
      ('primary', c.primary),
      ('primaryDark', c.primaryDark),
      ('primaryContainer', c.primaryContainer),
      ('success', c.success),
      ('successTint', c.successTint),
      ('warning', c.warning),
      ('warningTint', c.warningTint),
      ('error', c.error),
      ('errorTint', c.errorTint),
      ('info', c.info),
      ('infoTint', c.infoTint),
      ('review', c.review),
      ('reviewTint', c.reviewTint),
    ];

    return LargeTitleScaffold(
      title: 'Gallery',
      caption: 'Tokens and components · ${widget.dark ? 'dark' : 'light'}',
      detail: false,
      actions: [
        RoundIconButton(
          icon: widget.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          tooltip: 'Toggle dark',
          onPressed: () => widget.onDark(!widget.dark),
        ),
      ],
      children: [
        Gutter(
          child: SegmentedControl<bool>(
            segments: const [(false, 'Light'), (true, 'Dark')],
            value: widget.dark,
            onChanged: widget.onDark,
          ),
        ),
        const SectionBreak(),
        Gutter(child: Text('Do something', style: t.headline)),
        gap,
        Gutter(
          child: TileGrid(
            tiles: [
              Tile(label: 'Report a problem', pictogram: PictogramKind.report, size: TileSize.wide, onTap: () {}),
              Tile(label: 'Track a complaint', pictogram: PictogramKind.track, size: TileSize.wide, onTap: () {}),
              Tile(label: 'Ask about a complaint', pictogram: PictogramKind.chat, onTap: () {}),
              Tile(label: 'Report card', pictogram: PictogramKind.reportCard, onTap: () {}),
              Tile(label: 'Ask my ward', pictogram: PictogramKind.ask, onTap: () {}, badge: 3),
              Tile(label: 'Monsoon', pictogram: PictogramKind.monsoon, accent: c.info, onTap: () {}),
              Tile(label: 'Complaint trail', pictogram: PictogramKind.trail, onTap: () {}),
              Tile(label: 'About the data', pictogram: PictogramKind.about, onTap: () {}),
            ],
          ),
        ),
        const SectionBreak(),
        Gutter(
          child: HeroFigure(
            caption: 'Mumbai this monsoon',
            value: 412500000,
            format: formatInr,
            explanation: 'Billed on roads under warranty, to be claimed and verified',
            onTap: () {},
          ),
        ),
        gap,
        Gutter(
          child: HeroFigure(
            caption: 'Spend vs budget',
            value: 0.86,
            format: (v) => '${(v * 100).round()}%',
            action: const ProgressBar(value: 0.86, semanticLabel: 'Spend vs budget'),
          ),
        ),
        gap,
        Gutter(child: ProgressBar(value: 1.3, semanticLabel: 'Over budget')),
        gap,
        Gutter(
          child: StatRow(
            tiles: [
              StatTile.count(count: 42, label: 'Warranty claims'),
              StatTile.count(count: 7, label: 'Failed repairs', color: c.error, dot: c.error),
              const StatTile(value: '₹1.2 Cr', label: 'Next rupee'),
            ],
          ),
        ),
        h('Needs your attention'),
        ListRow(
          title: 'SV Road, Bandra',
          caption: 'WO-23-0412 · Shree Infra (synthetic)',
          icon: Icons.edit_road_outlined,
          chip: const StatusChip('Billed above rate', tone: StatusTone.review, more: 2),
          amount: '₹4.2 L',
          onTap: () {},
        ),
        ListRow(
          title: 'Mahim Causeway',
          caption: 'WO-23-0533 · Patel Roads',
          initials: 'PR',
          chip: const StatusChip('Failed repair', tone: StatusTone.error, dot: true),
          amount: '₹12.8 L',
          onTap: () {},
        ),
        ListRow(title: 'Plain row, no tap', caption: 'Caption line', divider: false),
        h('Chips and controls'),
        FilterChipRow(
          children: [
            for (final f in ['All', 'Above rate', 'Repeat job', 'Failed repair', 'Warranty', 'Slow'])
              FilterPill(label: f, selected: _filter == f, onTap: () => setState(() => _filter = f), count: f == 'All' ? 24 : null),
          ],
        ),
        gap,
        Gutter(
          child: Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              for (final tone in StatusTone.values) StatusChip(tone.name, tone: tone, dot: true),
            ],
          ),
        ),
        gap,
        Gutter(
          child: Wrap(
            spacing: AppSpacing.s8,
            children: [
              ChoiceChip(label: const Text('Material chip'), selected: false, onSelected: (_) {}),
              ChoiceChip(label: const Text('Selected'), selected: true, onSelected: (_) {}),
            ],
          ),
        ),
        gap,
        Gutter(
          child: SegmentedControl<String>(
            segments: const [('ward', 'Ward E'), ('all', 'All Mumbai')],
            value: _scope,
            onChanged: (v) => setState(() => _scope = v),
          ),
        ),
        gap,
        const Gutter(child: SearchField(hint: 'Search roads or contractors')),
        gap,
        const Gutter(child: TextField(decoration: InputDecoration(hintText: 'Material text field'))),
        gap,
        Gutter(
          child: Row(
            children: [
              Switch(value: _switch, onChanged: (v) => setState(() => _switch = v)),
              Expanded(child: Slider(value: _slider, onChanged: (v) => setState(() => _slider = v))),
            ],
          ),
        ),
        const Gutter(child: LinearProgressIndicator(value: 0.6)),
        h('Buttons'),
        Gutter(
          child: Column(
            children: [
              PrimaryButton(label: 'Open audit', onPressed: () => setState(() => _loading = !_loading)),
              gap,
              PrimaryButton(label: 'Filing…', loading: _loading, onPressed: () => setState(() => _loading = !_loading)),
              gap,
              const PrimaryButton(label: 'Disabled', onPressed: null),
              gap,
              SecondaryButton(label: 'File as new', icon: Icons.add, onPressed: () {}),
              gap,
              Row(
                children: [
                  FilledButton(onPressed: () {}, child: const Text('Filled')),
                  const SizedBox(width: AppSpacing.s8),
                  OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
                  const SizedBox(width: AppSpacing.s8),
                  TextButton(onPressed: () {}, child: const Text('Text')),
                ],
              ),
              gap,
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => showAppSheet<void>(
                      context,
                      title: 'Layers',
                      builder: (_) => Column(
                        children: [
                          for (final k in [PictogramKind.ward, PictogramKind.map, PictogramKind.monsoon])
                            ListRow(title: k.label, caption: 'Toggle row', leading: Pictogram(k), trailing: Switch(value: true, onChanged: (_) {})),
                        ],
                      ),
                    ),
                    child: const Text('Sheet'),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  OutlinedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard'))),
                    child: const Text('Snackbar'),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  OutlinedButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: const Text('Sign out?'),
                        content: const Text('You can sign in again any time.'),
                        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel'))],
                      ),
                    ),
                    child: const Text('Dialog'),
                  ),
                ],
              ),
            ],
          ),
        ),
        h('Timeline'),
        Gutter(
          child: Timeline(
            steps: [
              const TimelineStep(title: 'Complaint filed', meta: '12 Jun 2025 · Bandra West'),
              const TimelineStep(title: 'Linked to issue', meta: 'ISS-0091 · 6 reports'),
              TimelineStep(title: 'Work order', meta: 'WO-23-0412 · Shree Infra', amount: '₹4.2 L', chip: const StatusChip('Above rate', tone: StatusTone.review)),
              TimelineStep(title: 'Failed again', meta: '3 weeks later', state: TimelineNodeState.outcome, color: c.error),
              const TimelineStep(title: 'Warranty claim', meta: 'Not yet filed', state: TimelineNodeState.pending),
            ],
          ),
        ),
        h('Loading, empty, error'),
        Skeleton.rows(count: 2),
        gap,
        Gutter(child: Skeleton.tiles()),
        const EmptyState(message: 'No flags of this type in Ward E.', pictogram: PictogramKind.audit),
        ErrorState(message: 'Could not load this.', onRetry: () {}),
        h('Pictograms'),
        Gutter(
          child: Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              for (final k in PictogramKind.values)
                SizedBox(
                  width: 76,
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: AppRadii.tileRadius),
                        child: Pictogram(k, accent: k == PictogramKind.failedRepair ? c.error : null),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(k.name, style: t.caption.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
            ],
          ),
        ),
        h('Restyled legacy widgets'),
        Gutter(
          child: Column(
            children: [
              const ScorecardStatTile(value: '47%', label: 'Durability', barFraction: 0.47),
            ],
          ),
        ),
        h('Type'),
        Gutter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Display 34', style: t.display),
              Text('Headline 24', style: t.headline),
              Text('Title 18', style: t.title),
              Text('Body 16 — the default reading size.', style: t.body),
              Text('Body strong 16', style: t.bodyStrong),
              Text('Label 14', style: t.label),
              Text('Caption 13, secondary', style: t.caption),
              Text('₹41.25 Cr', style: t.figureXL),
              Text('₹4.2 L', style: t.figure),
              const SizedBox(height: AppSpacing.s8),
              Text('नमस्ते · वार्ड ई (Devanagari: no negative tracking in hi/mr)', style: t.headline),
            ],
          ),
        ),
        h('Colour'),
        Gutter(
          child: Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              for (final (name, color) in swatches)
                SizedBox(
                  width: 104,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 44,
                        decoration: BoxDecoration(color: color, borderRadius: AppRadii.controlRadius, border: Border.all(color: c.border)),
                      ),
                      Text(name, style: t.caption.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        h('Space and radii'),
        Gutter(
          child: Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              for (final s in AppSpacing.scale) Container(width: s, height: s, color: c.primary),
              for (final r in [AppRadii.control, AppRadii.tile, AppRadii.card, AppRadii.dialog, AppRadii.sheet])
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(r)),
                  child: Text('${r.round()}', style: t.caption),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
