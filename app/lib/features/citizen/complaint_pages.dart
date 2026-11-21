import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_router.dart';
import '../../core/api/api_client.dart';
import '../../core/flag_strings.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/widgets/ui.dart';
import '../officer/officer_data.dart';
import '../officer/officer_panels.dart';
import '../trail/trail_screen.dart';
import 'citizen_panels.dart';

// Track a complaint and Complaint detail (design brief 7.10, 7.11).

/// One status chip for a complaint row: the repair outcome when there is a work order, else what
/// happened to it (same wording as before the redesign).
Widget complaintChip(BuildContext context, Map m) {
  final wo = m['work_order_id'] ?? (m['work_order'] as Map?)?['id'];
  final reopened = m['reopened'] == true || (m['work_order'] as Map?)?['reopened'] == true;
  if (wo != null) {
    return reopened
        ? StatusChip(context.tr(kFixFailed30), tone: StatusTone.error, dot: true)
        : StatusChip(context.tr('Fixed and held'), tone: StatusTone.success, dot: true);
  }
  if (m['source'] == 'app') return StatusChip(context.tr('Filed in this app'), tone: StatusTone.info);
  final outcome = noWorkOrderOutcome(m['status']);
  return StatusChip(context.tr(outcome), tone: outcome == kNotYetFixed ? StatusTone.warning : StatusTone.neutral);
}

/// Grey card for one complaint (report-flow matches): id and date, status chip, what happened.
class ComplaintCard extends StatelessWidget {
  const ComplaintCard(this.m, {super.key});
  final Json m;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final wo = m['work_order_id'];
    final outcome = wo == null
        ? null
        : '${plainName(m['contractor_name'])} · ${formatInr(m['cost_inr'] as num? ?? 0)} · '
              '${context.tr(m['sla_met'] == true ? 'on time' : 'late')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      child: Pressable(
        onTap: () => pushComplaint(context, m['id'] as String),
        color: c.surfaceAlt,
        borderRadius: AppRadii.cardRadius,
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${m['id']}', style: t.bodyStrong),
                  Text(
                    [
                      context.tr('Received {d}', {'d': complaintDay(m['received_at'])}),
                      ?wo,
                    ].join(' · '),
                    style: t.caption,
                  ),
                  if (outcome != null) Text(outcome, style: t.caption),
                  const SizedBox(height: AppSpacing.s8),
                  complaintChip(context, m),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.textSecondary),
          ],
        ),
      ),
    );
  }
}

bool _looksLikeId(String q) => RegExp(r'^(BMC|NS)\d*-?\d+$', caseSensitive: false).hasMatch(q.replaceAll(' ', ''));

// ----------------------------------------------------------------- track

class TrackPage extends ConsumerStatefulWidget {
  const TrackPage({super.key});
  @override
  ConsumerState<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends ConsumerState<TrackPage> {
  final _q = TextEditingController();
  String? _locality;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _open(String id) {
    rememberComplaint(ref, id);
    pushComplaint(context, id);
  }

  void _submit(String q) {
    q = q.trim();
    if (_looksLikeId(q)) _open(q.toUpperCase().replaceAll(' ', ''));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final q = _q.text.trim();
    final loc = _locality;
    final recent = recentComplaints(ref);
    return LargeTitleScaffold(
      title: context.tr(kTrackComplaint),
      children: [
        Gutter(
          child: SearchField(
            controller: _q,
            hint: context.tr('Complaint id or locality'),
            onChanged: (_) => setState(() {}),
            onSubmitted: _submit,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        if (q.isEmpty) ...[
          FilterChipRow(
            children: [
              // Before anything is tracked on this device, a known demo complaint.
              for (final id in recent.isEmpty ? const ['BMC25-006359'] : recent)
                FilterPill(label: id, selected: false, icon: Icons.history, onTap: () => _open(id)),
            ],
          ),
          Gutter(child: Text(context.tr('Dataset ids look like BMC25-000123; app ids like NS-000001.'), style: t.caption)),
          if (loc != null) ..._results(context, loc),
        ] else if (_looksLikeId(q))
          ListRow(icon: Icons.search, title: context.tr('Track {id}', {'id': q.toUpperCase().replaceAll(' ', '')}), onTap: () => _submit(q))
        else
          ..._localities(context, q),
      ],
    );
  }

  /// Localities matching the typed text (name or alias).
  List<Widget> _localities(BuildContext context, String q) {
    final locs = ref.watch(localitiesProvider);
    return switch (locs) {
      AsyncData(:final value) => () {
        final ql = q.toLowerCase();
        final hits = [
          for (final l in value)
            if ('${l['locality']}'.toLowerCase().contains(ql) ||
                ((l['aliases'] as List?) ?? const []).any((a) => '$a'.toLowerCase().contains(ql)))
              l,
        ];
        if (hits.isEmpty) {
          return [
            EmptyState(message: context.tr('No locality or complaint id matches “{q}”.', {'q': q}), pictogram: PictogramKind.track),
          ];
        }
        return [
          for (final (i, l) in hits.take(12).indexed)
            StaggeredEntrance(
              index: i,
              child: ListRow(
                icon: Icons.place_outlined,
                title: '${l['locality']}',
                caption: context.tr('Ward {w}', {'w': l['ward_code']}),
                onTap: () => setState(() {
                  _locality = l['locality'] as String;
                  _q.clear();
                  FocusScope.of(context).unfocus();
                }),
              ),
            ),
        ];
      }(),
      AsyncError() => [ErrorState(message: context.tr('Could not load localities.'), onRetry: () => ref.invalidate(localitiesProvider))],
      _ => [Skeleton.rows(count: 4)],
    };
  }

  List<Widget> _results(BuildContext context, String loc) => [
    Gutter(
      child: SectionHeading(
        loc,
        trailing: TextButton(onPressed: () => setState(() => _locality = null), child: Text(context.tr('Clear'))),
      ),
    ),
    ...switch (ref.watch(complaintsAtProvider(loc))) {
      AsyncData(:final value) when (value['total'] as int) == 0 => [
        EmptyState(message: context.tr('No complaints recorded in {loc}.', {'loc': loc}), pictogram: PictogramKind.track),
      ],
      AsyncData(:final value) => [
        Gutter(
          child: Text(
            '${context.tr('{n} complaints in {loc}, newest first', {'n': value['total'], 'loc': loc})}'
            '${(value['total'] as int) > 50 ? context.tr(' (latest 50 shown)') : ''}',
            style: context.type.caption,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        for (final (i, m) in (value['rows'] as List).indexed)
          StaggeredEntrance(
            index: i,
            child: ListRow(
              icon: Icons.inbox_outlined,
              title: '${m['id']}',
              caption: '${context.tr('${m['category']}')} · ${complaintDay(m['received_at'])}',
              chip: complaintChip(context, m as Map),
              onTap: () => _open(m['id'] as String),
            ),
          ),
      ],
      AsyncError() => [
        ErrorState(message: context.tr('Could not load complaints.'), onRetry: () => ref.invalidate(complaintsAtProvider(loc))),
      ],
      _ => [Skeleton.rows(count: 5)],
    },
  ];
}

// ------------------------------------------------------------ detail page

class ComplaintDetail extends ConsumerWidget {
  const ComplaintDetail(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(complaintProvider(id));
    final d = v.value;
    return LargeTitleScaffold(
      title: id,
      caption: d == null
          ? null
          : '${context.tr('${d['category']}')} · ${d['locality']} · ${context.tr('Ward {w}', {'w': d['ward_code']})} · '
                '${context.tr('Received {d}', {'d': complaintDay(d['received_at'])})}',
      header: d == null
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.s8, AppSpacing.gutter, AppSpacing.s4),
              child: Align(alignment: AlignmentDirectional.centerStart, child: complaintChip(context, d)),
            ),
      children: switch (v) {
        AsyncData(:final value) => _body(context, value),
        AsyncError(:final error) when error is ApiException && error.status == 404 => [
          EmptyState(
            message: context.tr('No complaint with id {id}. Dataset ids look like BMC25-000123; app ids like NS-000001.', {'id': id}),
            pictogram: PictogramKind.track,
            actionLabel: context.tr(kTrackComplaint),
            onAction: () => appRouter.pushReplacement('/track'),
          ),
        ],
        AsyncError() => [ErrorState(message: context.tr('Could not load this.'), onRetry: () => ref.invalidate(complaintProvider(id)))],
        _ => [
          const SizedBox(height: AppSpacing.s16),
          Gutter(
            child: Skeleton(child: Column(children: [for (var i = 0; i < 4; i++) const _SkeletonStep()])),
          ),
        ],
      },
    );
  }

  List<Widget> _body(BuildContext context, Json d) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final wo = d['work_order'] as Map?;
    final open = noWorkOrderOutcome(d['status']) == kNotYetFixed;
    final matched = d['matched_complaint_id'] as String?;
    final issue = d['issue_id'] as String?;
    final steps = <TimelineStep>[
      TimelineStep(title: context.tr('Received'), meta: complaintDay(d['received_at'])),
      if (issue != null)
        TimelineStep(
          title: context.tr('Part of issue {id}', {'id': issue}),
          meta: context.tr(
            d['link'] == 'inferred'
                ? 'Grouped with reports of the same problem. Its work order is our best match (inferred link), not BMC’s record.'
                : 'Grouped with other reports of the same problem.',
          ),
          chip: d['link'] == 'inferred' ? StatusChip(context.tr(kInferredLink), tone: StatusTone.info) : null,
        ),
      if (wo == null) ...[
        if (matched != null)
          TimelineStep(
            title: context.tr('Added to complaint {id}', {'id': matched}),
            meta: context.tr('Follow that complaint for the repair.'),
            child: SecondaryButton(label: context.tr('Track it'), expand: false, onPressed: () => pushComplaint(context, matched)),
          ),
        TimelineStep(
          title: context.tr(noWorkOrderOutcome(d['status'])),
          meta: context.tr(open ? 'No repair has been ordered for this complaint yet.' : 'No work order linked'),
          state: open ? TimelineNodeState.pending : TimelineNodeState.outcome,
          color: c.textSecondary,
        ),
      ] else ...[
        TimelineStep(
          title: context.tr('Linked to work order {id}', {'id': wo['id']}),
          meta:
              '${context.tr('Assigned {d}', {'d': complaintDay(wo['assigned_at'])})} · ${wo['method']}\n${plainName(wo['contractor_name'])}',
          amount: formatInr(wo['cost_inr'] as num? ?? 0),
        ),
        TimelineStep(
          title: context.tr('Completed {d}', {'d': complaintDay(wo['completed_at'])}),
          meta: context.tr(wo['sla_met'] == true ? 'On time against the SLA' : 'Late against the SLA'),
        ),
        TimelineStep(
          title: context.tr(wo['reopened'] == true ? kFixFailed30 : kFixHeld),
          meta: context.tr(
            wo['reopened'] == true ? '$kNeedsReview: the same spot was reported again.' : 'No repeat complaint within 30 days.',
          ),
          state: TimelineNodeState.outcome,
          color: wo['reopened'] == true ? c.error : c.success,
        ),
      ],
    ];
    return [
      if (d['category_corrected'] == true)
        Gutter(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusChip(
              context.tr('Reported as {a} → corrected to {b}', {
                'a': context.tr('${d['category']}'),
                'b': context.tr('${d['category_clean']}'),
              }),
              tone: StatusTone.info,
            ),
          ),
        ),
      const SizedBox(height: AppSpacing.s12),
      Gutter(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: AppRadii.tileRadius),
          child: Text('“${d['description']}”', style: t.body.copyWith(fontStyle: FontStyle.italic)),
        ),
      ),
      Gutter(child: SectionHeading(context.tr('What happened'))),
      Gutter(child: Timeline(steps: steps)),
      if (wo != null || issue != null) ...[
        const SectionBreak(),
        if (wo != null) ...[
          ListRow(
            icon: Icons.alt_route,
            title: '${wo['road_name']}',
            caption: context.tr('Road'),
            onTap: () => openRoad(wo['road_id'] as String, wo: wo['id'] as String?),
          ),
          ListRow(icon: Icons.engineering_outlined, title: plainName(wo['contractor_name']), caption: context.tr('Contractor')),
          ListRow(
            icon: Icons.currency_rupee,
            title: formatInr(wo['cost_inr'] as num? ?? 0),
            caption: '${context.tr('Cost')} · ${wo['method']}',
          ),
        ],
        if (issue != null)
          ListRow(
            icon: Icons.route_outlined,
            title: context.tr('See the full trail'),
            caption: context.tr('Issue {id}', {'id': issue}),
            onTap: () => openIssue(issue),
            divider: false,
          ),
      ],
    ];
  }
}

class _SkeletonStep extends StatelessWidget {
  const _SkeletonStep();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: AppSpacing.s20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: 12, height: 12, circle: true),
        SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 16, widthFactor: 0.6),
              SizedBox(height: AppSpacing.s8),
              SkeletonBox(height: 12, widthFactor: 0.4),
            ],
          ),
        ),
      ],
    ),
  );
}
