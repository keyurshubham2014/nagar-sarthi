import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/session.dart';
import '../../core/flag_strings.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/claude_draft_sheet.dart';
import '../map/map_data.dart';
import '../officer/officer_data.dart';
import '../officer/officer_panels.dart';
import '../officer/panel.dart';
import 'report_card.dart';

// Citizen flow (TASK-06): raise, track, share, ask. Pages live in the shared panel host.

Duration? _noRetry(int _, Object _) => null;

final localitiesProvider = FutureProvider<List<dynamic>>(retry: _noRetry, (ref) => ref.watch(apiClientProvider).localities());
final complaintProvider = FutureProvider.family<Json, String>(
  retry: _noRetry,
  (ref, id) => ref.watch(apiClientProvider).complaint(id),
);
final complaintsAtProvider = FutureProvider.family<Json, String>(
  retry: _noRetry,
  (ref, loc) => ref.watch(apiClientProvider).complaintsAt(loc),
);

PanelStack _panel(BuildContext context) => ProviderScope.containerOf(context, listen: false).read(panelProvider.notifier);

void openCitizenHub(BuildContext context) => _panel(context).open(const PanelPage(kCitizenHubTitle, CitizenHub()));
void _push(BuildContext context, String title, Widget body) => _panel(context).push(PanelPage(title, body));
void pushComplaint(BuildContext context, String id) => _push(context, 'Complaint $id', ComplaintDetail(id));

String _day(dynamic s) => s == null ? '—' : '$s'.substring(0, '$s'.length >= 10 ? 10 : '$s'.length);
String _plain(dynamic name) => '${name ?? '—'}'.replaceAll(' (synthetic)', '');

// ------------------------------------------------------------------- hub

class CitizenHub extends StatelessWidget {
  const CitizenHub({super.key});
  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String title, String sub, VoidCallback onTap) => Card(
      child: ListTile(leading: Icon(icon), title: Text(context.tr(title)), subtitle: Text(context.tr(sub)), trailing: const Icon(Icons.chevron_right), onTap: onTap),
    );
    return PanelList(
      children: [
        tile(Icons.edit_note, kReportProblem, 'In your own words. See if neighbours already raised it.',
            () => _push(context, kReportProblem, const IntakePage())),
        tile(Icons.timeline, kTrackComplaint, 'By complaint id or by locality.', () => _push(context, kTrackComplaint, const TrackPage())),
        tile(Icons.ios_share, kReportCard, 'A shareable card of your ward’s road repairs.',
            () => _push(context, kReportCard, const ReportCardPage())),
        tile(Icons.question_answer_outlined, kAskWard, 'A polite question to the ward office, with the figures.',
            () => _push(context, kAskWard, const AskWardPage())),
      ],
    );
  }
}

// ---------------------------------------------------------------- intake

class IntakePage extends ConsumerStatefulWidget {
  const IntakePage({super.key});
  @override
  ConsumerState<IntakePage> createState() => _IntakePageState();
}

class _IntakePageState extends ConsumerState<IntakePage> {
  final _text = TextEditingController();
  bool _busy = false; // analysing or submitting
  String? _error;
  Map<String, String> _fields = const {};
  Json? _result;
  String? _category, _locality, _language;
  bool _matchesLoading = false;
  Json? _filed;
  VoidCallback? _retryFile; // set when filing failed (e.g. 503), so the error card can retry it

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _understand() async {
    setState(() {
      _busy = true;
      _error = null;
      _fields = const {};
      _result = null;
      _filed = null;
    });
    try {
      final r = await ref.read(apiClientProvider).intake(_text.text.trim());
      if (!mounted) return;
      setState(() {
        _result = r;
        _category = r['category'] as String?;
        _locality = r['locality'] as String?;
        _language = r['language'] as String?;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.fields['text'] as String? ?? e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // After a correction: matches for the new category and locality.
  Future<void> _rematch() async {
    final cat = _category, loc = _locality;
    if (cat == null || loc == null) return;
    setState(() => _matchesLoading = true);
    try {
      final m = await ref.read(apiClientProvider).complaintMatches(cat, loc);
      if (mounted) setState(() => _result = {..._result!, ...m});
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _matchesLoading = false);
    }
  }

  Future<void> _file({String? matchedId}) async {
    if (!await ensureRole(context, why: context.tr('Sign in with your mobile number to file a complaint, so you can track it later.'))) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _fields = const {};
      _retryFile = null;
    });
    try {
      final r = await ref.read(apiClientProvider).fileComplaint({
        'category': _category,
        'locality': _locality,
        'description': _text.text.trim(),
        'language': _language,
        'matched_complaint_id': ?matchedId,
      });
      if (mounted) setState(() => _filed = r);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _fields = {for (final f in e.fields.entries) f.key: '${f.value}'};
          if (e.fields.isEmpty) _retryFile = () => _file(matchedId: matchedId);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = SaartheeColors.of(context);
    final r = _result;
    return PanelList(
      children: [
        TextField(
          controller: _text,
          minLines: 4,
          maxLines: 8,
          maxLength: 1000,
          enabled: !_busy,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: context.tr('Your complaint'),
            hintText: context.tr(kIntakeHint),
            hintMaxLines: 3,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            border: const OutlineInputBorder(),
            errorText: _fields['description'],
          ),
        ),
        Text(context.tr('Try an example'), style: t.labelMedium),
        const SizedBox(height: AppSpacing.s4),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s4,
          children: [
            for (final (label, text) in intakeExamples)
              ActionChip(
                label: Text(label),
                tooltip: text,
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _text.text = text;
                        _result = null;
                        _filed = null;
                      }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        FilledButton.icon(
          onPressed: _busy || _text.text.trim().length < 5 ? null : _understand,
          icon: _busy && r == null
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: Text(context.tr(_busy && r == null ? 'Understanding…' : kUnderstand)),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.s8),
          Card(
            color: c.errorTint,
            child: ListTile(
              leading: Icon(Icons.error_outline, color: c.error),
              title: Text(context.tr(_error!)),
              trailing: TextButton(
                onPressed: _busy ? null : (r == null ? _understand : _retryFile ?? () => setState(() => _error = null)),
                child: Text(context.tr(r == null || _retryFile != null ? 'Retry' : 'Dismiss')),
              ),
            ),
          ),
        ],
        if (r != null) ..._resultCard(context, r),
      ],
    );
  }

  List<Widget> _resultCard(BuildContext context, Json r) {
    final t = Theme.of(context).textTheme;
    final c = SaartheeColors.of(context);
    final live = r['source'] == 'live';
    final matches = (r['matches'] as List?) ?? const [];
    final n = r['match_count'] as int? ?? matches.length;
    final locs = ref.watch(localitiesProvider).value ?? const [];
    final ward = [for (final l in locs) if (l['locality'] == _locality) l['ward_code']].firstOrNull;
    final wardName = ward == null ? null : ref.watch(mapDataProvider).value?.wardByCode[ward]?.name;
    final filed = _filed;

    return [
      SectionTitle(context.tr('What we understood')),
      Align(
        alignment: Alignment.centerLeft,
        child: Tag(context.tr(live ? kUnderstoodLive : kUnderstoodRules),
            bg: live ? c.successTint : c.warningTint, fg: live ? c.success : c.warning, icon: live ? Icons.auto_awesome : Icons.rule),
      ),
      const SizedBox(height: AppSpacing.s12),
      DropdownMenu<String>(
        label: Text(context.tr('Language')),
        expandedInsets: EdgeInsets.zero,
        initialSelection: _language,
        dropdownMenuEntries: [for (final e in complaintLanguages.entries) DropdownMenuEntry(value: e.key, label: e.value)],
        onSelected: (v) => setState(() => _language = v),
      ),
      const SizedBox(height: AppSpacing.s12),
      DropdownMenu<String>(
        label: Text(context.tr('Category')),
        expandedInsets: EdgeInsets.zero,
        initialSelection: _category,
        errorText: _fields['category'],
        dropdownMenuEntries: [for (final k in complaintCategories) DropdownMenuEntry(value: k, label: context.tr(k))],
        onSelected: (v) {
          setState(() => _category = v);
          _rematch();
        },
      ),
      const SizedBox(height: AppSpacing.s12),
      if (_locality == null)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s4),
          child: Text(context.tr('We could not find the place in your text. Please pick your locality.'), style: t.bodyMedium?.copyWith(color: c.warning)),
        ),
      DropdownMenu<String>(
        // Rebuilt once the gazetteer loads, so the resolved locality shows as selected.
        key: ValueKey('loc-${locs.length}'),
        label: Text(context.tr('Locality (type to search)')),
        expandedInsets: EdgeInsets.zero,
        enableFilter: true,
        requestFocusOnTap: true,
        menuHeight: 320,
        initialSelection: _locality,
        errorText: _fields['locality'],
        helperText: ward == null ? null : 'Ward $ward${wardName == null ? '' : ' · $wardName'}',
        dropdownMenuEntries: [
          for (final l in locs) DropdownMenuEntry(value: l['locality'] as String, label: '${l['locality']} · Ward ${l['ward_code']}'),
        ],
        onSelected: (v) {
          setState(() => _locality = v);
          _rematch();
        },
      ),
      if (_locality != null) ...[
        SectionTitle(context.tr(n == 0 ? 'Not reported here yet' : alreadyReported(n), {'n': n})),
        if (_matchesLoading)
          const LinearProgressIndicator()
        else if (matches.isEmpty)
          Text(context.tr('No one has reported this in {loc} in the last 14 days of the data.', {'loc': _locality}), style: t.bodyMedium)
        else ...[
          for (final m in matches) _MatchCard(m as Json),
          if (n > matches.length) Text(context.tr('Showing the latest {shown} of {n}.', {'shown': matches.length, 'n': n}), style: t.bodySmall),
          if (r['app_matches_unavailable'] == true)
            Text(context.tr('Complaints filed in this app could not be checked right now.'), style: t.bodySmall?.copyWith(color: c.warning)),
        ],
      ],
      const SizedBox(height: AppSpacing.s16),
      if (filed != null)
        Card(
          color: c.successTint,
          child: ListTile(
            leading: Icon(Icons.check_circle, color: c.success),
            title: Text(context.tr('Filed as {id}', {'id': filed['id']})),
            subtitle: Text(filed['matched_complaint_id'] == null
                ? context.tr('A new complaint in {loc}.', {'loc': filed['locality']})
                : context.tr('Your voice is added to {id}.', {'id': filed['matched_complaint_id']})),
            trailing: FilledButton(onPressed: () => pushComplaint(context, filed['id'] as String), child: Text(context.tr('Track'))),
          ),
        )
      else
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          alignment: WrapAlignment.end,
          children: [
            if (matches.isNotEmpty)
              FilledButton.icon(
                // Join the newest dataset complaint (it carries the repair trail); else the newest app one.
                onPressed: _busy || _locality == null
                    ? null
                    : () => _file(
                        matchedId: (matches.firstWhere((m) => m['source'] == 'dataset', orElse: () => matches.first))['id'] as String,
                      ),
                icon: const Icon(Icons.group_add_outlined),
                label: Text(context.tr(kAddMyVoice)),
              ),
            OutlinedButton.icon(
              onPressed: _busy || _locality == null || _category == null ? null : () => _file(),
              icon: const Icon(Icons.add),
              label: Text(context.tr(kFileAsNew)),
            ),
            if (_busy) const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            if (_retryFile != null)
              Row(
                children: [
                  Expanded(child: Text(_error ?? '', style: t.bodySmall?.copyWith(color: c.error))),
                  TextButton(onPressed: _busy ? null : _retryFile, child: Text(context.tr('Retry'))),
                ],
              ),
          ],
        ),
    ];
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard(this.m);
  final Json m;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = SaartheeColors.of(context);
    final wo = m['work_order_id'];
    final outcome = wo == null
        ? context.tr(m['source'] == 'app' ? 'Filed in this app' : kNotYetFixed)
        : '${_plain(m['contractor_name'])} · ${formatInr(m['cost_inr'] as num? ?? 0)} · '
              '${context.tr(m['sla_met'] == true ? 'on time' : 'late')} · ${context.tr(m['reopened'] == true ? kFixFailed30.toLowerCase() : 'held')}';
    return Card(
      child: ListTile(
        dense: true,
        title: Text('${m['id']} · ${m['status']}'),
        subtitle: Text('${context.tr('Received {d}', {'d': _day(m['received_at'])})}${wo == null ? '' : ' · $wo'}\n$outcome',
            style: t.bodySmall?.copyWith(color: m['reopened'] == true ? c.error : null)),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => pushComplaint(context, m['id'] as String),
      ),
    );
  }
}

// ----------------------------------------------------------------- track

class TrackPage extends ConsumerStatefulWidget {
  const TrackPage({super.key});
  @override
  ConsumerState<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends ConsumerState<TrackPage> {
  final _id = TextEditingController();
  String? _locality;

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  void _go() {
    final id = _id.text.trim().toUpperCase();
    if (id.isNotEmpty) pushComplaint(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final locs = ref.watch(localitiesProvider);
    final loc = _locality;
    return PanelList(
      children: [
        SectionTitle(context.tr('By complaint id')),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _id,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _go(),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: context.tr('Complaint id'),
                  hintText: 'BMC25-000123 or NS-000001',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            FilledButton(onPressed: _id.text.trim().isEmpty ? null : _go, child: Text(context.tr('Track'))),
          ],
        ),
        SectionTitle(context.tr('By locality')),
        switch (locs) {
          AsyncData(:final value) => DropdownMenu<String>(
            label: Text(context.tr('Locality (type to search)')),
            expandedInsets: EdgeInsets.zero,
            enableFilter: true,
            requestFocusOnTap: true,
            menuHeight: 320,
            dropdownMenuEntries: [
              for (final l in value) DropdownMenuEntry(value: l['locality'] as String, label: '${l['locality']} · Ward ${l['ward_code']}'),
            ],
            onSelected: (v) => setState(() => _locality = v),
          ),
          AsyncError(:final error) => ListTile(
            title: Text('Could not load localities. $error'),
            trailing: TextButton(onPressed: () => ref.invalidate(localitiesProvider), child: const Text('Retry')),
          ),
          _ => const LinearProgressIndicator(),
        },
        if (loc != null)
          switch (ref.watch(complaintsAtProvider(loc))) {
            AsyncData(:final value) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.s8),
                Text(
                  (value['total'] as int) == 0
                      ? context.tr('No complaints recorded in {loc}.', {'loc': loc})
                      : '${context.tr('{n} complaints in {loc}, newest first', {'n': value['total'], 'loc': loc})}${(value['total'] as int) > 50 ? context.tr(' (latest 50 shown)') : ''}',
                  style: t.bodyMedium,
                ),
                for (final m in value['rows'] as List) _MatchCard(m as Json),
              ],
            ),
            AsyncError(:final error) => ListTile(
              title: Text('Could not load complaints. $error'),
              trailing: TextButton(onPressed: () => ref.invalidate(complaintsAtProvider(loc)), child: const Text('Retry')),
            ),
            _ => const Padding(padding: EdgeInsets.only(top: AppSpacing.s12), child: LinearProgressIndicator()),
          },
      ],
    );
  }
}

class ComplaintDetail extends ConsumerWidget {
  const ComplaintDetail(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(complaintProvider(id));
    if (v case AsyncError(:final error) when error is ApiException && error.status == 404) {
      return PanelMessage.empty('No complaint with id $id.\nDataset ids look like BMC25-000123; app ids like NS-000001.',
          icon: Icons.search_off);
    }
    return asyncPage(v, onRetry: () => ref.invalidate(complaintProvider(id)), data: (c) => _body(context, c));
  }

  Widget _body(BuildContext context, Json d) {
    final t = Theme.of(context).textTheme;
    final c = SaartheeColors.of(context);
    final wo = d['work_order'] as Map?;
    final open = const {'Open', 'In Progress', 'open'}.contains(d['status']);
    final matched = d['matched_complaint_id'] as String?;
    return PanelList(
      children: [
        Text('${d['category']} · ${d['locality']} · Ward ${d['ward_code']}', style: t.titleSmall),
        const SizedBox(height: AppSpacing.s4),
        Text('“${d['description']}”', style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
        const SizedBox(height: AppSpacing.s4),
        Align(alignment: Alignment.centerLeft, child: Tag(context.tr('Status: {s}', {'s': d['status']}), bg: c.infoTint, fg: c.info)),
        SectionTitle(context.tr('What happened')),
        _Step(icon: Icons.inbox_outlined, color: c.info, title: context.tr('Received'), sub: _day(d['received_at'])),
        if (wo == null) ...[
          if (matched != null)
            _Step(
              icon: Icons.group_add_outlined,
              color: c.info,
              title: context.tr('Added to complaint {id}', {'id': matched}),
              sub: context.tr('Follow that complaint for the repair.'),
              action: TextButton(onPressed: () => pushComplaint(context, matched), child: Text(context.tr('Track it'))),
            ),
          _Step(
            icon: Icons.hourglass_empty,
            color: c.warning,
            title: context.tr(open ? kNotYetFixed : 'No work order linked'),
            sub: open ? context.tr('No repair has been ordered for this complaint yet.') : context.tr('Closed as: {s}', {'s': d['status']}),
            last: true,
          ),
        ] else ...[
          _Step(
            icon: Icons.assignment_outlined,
            color: c.info,
            title: context.tr('Linked to work order {id}', {'id': wo['id']}),
            sub: '${context.tr('Assigned {d}', {'d': _day(wo['assigned_at'])})} · ${wo['method']}\n'
                '${_plain(wo['contractor_name'])} · ${formatInr(wo['cost_inr'] as num? ?? 0)}',
          ),
          _Step(
            icon: wo['sla_met'] == true ? Icons.check_circle_outline : Icons.schedule,
            color: wo['sla_met'] == true ? c.success : c.warning,
            title: context.tr('Completed {d}', {'d': _day(wo['completed_at'])}),
            sub: context.tr(wo['sla_met'] == true ? 'On time against the SLA' : 'Late against the SLA'),
          ),
          _Step(
            icon: wo['reopened'] == true ? Icons.report_problem_outlined : Icons.verified_outlined,
            color: wo['reopened'] == true ? c.error : c.success,
            title: context.tr(wo['reopened'] == true ? kFixFailed30 : kFixHeld),
            sub: context.tr(wo['reopened'] == true ? '$kNeedsReview: the same spot was reported again.' : 'No repeat complaint within 30 days.'),
            last: true,
          ),
          const SizedBox(height: AppSpacing.s8),
          OutlinedButton.icon(
            onPressed: () => _push(context, '${wo['road_name']}', RoadPanel(wo['road_id'] as String)),
            icon: const Icon(Icons.alt_route),
            label: Text(context.tr('Open road: {r}', {'r': wo['road_name']})),
          ),
        ],
      ],
    );
  }
}

/// One step of the vertical timeline: dot, connector line, title and detail.
class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.color, required this.title, required this.sub, this.last = false, this.action});
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final bool last;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Icon(icon, color: color, size: 22),
              if (!last) Expanded(child: Container(width: 2, color: color.withValues(alpha: 0.4))),
            ],
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleSmall?.copyWith(color: color)),
                  Text(sub, style: t.bodySmall),
                  ?action,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ ask the ward

/// Ward chooser from the money map's ward list.
class WardPicker extends ConsumerWidget {
  const WardPicker({super.key, required this.selected, required this.onSelected});
  final String? selected;
  final ValueChanged<String?> onSelected;
  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(mapDataProvider)) {
    AsyncData(:final value) => DropdownMenu<String>(
      label: Text(context.tr('Ward (type to search)')),
      expandedInsets: EdgeInsets.zero,
      enableFilter: true,
      requestFocusOnTap: true,
      menuHeight: 320,
      initialSelection: selected,
      dropdownMenuEntries: [for (final w in value.wards) DropdownMenuEntry(value: w.code, label: 'Ward ${w.code} · ${w.name}')],
      onSelected: onSelected,
    ),
    AsyncError(:final error) => ListTile(
      title: Text('Could not load wards. $error'),
      trailing: TextButton(onPressed: () => ref.invalidate(mapDataProvider), child: const Text('Retry')),
    ),
    _ => const LinearProgressIndicator(),
  };
}

class AskWardPage extends StatefulWidget {
  const AskWardPage({super.key, this.ward});
  final String? ward;
  @override
  State<AskWardPage> createState() => _AskWardPageState();
}

class _AskWardPageState extends State<AskWardPage> {
  late String? _ward = widget.ward;
  @override
  Widget build(BuildContext context) {
    final ward = _ward;
    return PanelList(
      children: [
        WardPicker(selected: ward, onSelected: (v) => setState(() => _ward = v)),
        SectionTitle(context.tr('What would you like to ask about?')),
        if (ward == null) Text(context.tr('Pick your ward first.')),
        for (final e in questionTopics.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: OutlinedButton(
              onPressed: ward == null
                  ? null
                  : () => showClaudeDraftSheet(
                      context,
                      title: context.tr('Question to Ward {w}', {'w': ward}),
                      feature: 'question',
                      // Drafted in the app's language; the sheet can still switch.
                      body: {'ward_code': ward, 'topic': e.key, 'language': context.lang},
                      languages: briefLanguages,
                      textLabel: context.tr('Your question (editable)'),
                    ),
              child: Text(context.tr(e.value)),
            ),
          ),
      ],
    );
  }
}
