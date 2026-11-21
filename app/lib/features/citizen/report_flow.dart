import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/session.dart';
import '../../core/flag_strings.dart';
import '../../core/i18n.dart';
import '../../core/widgets/ui.dart';
import '../map/map_data.dart';
import '../officer/officer_data.dart';
import 'ask_bot.dart';
import 'citizen_panels.dart' hide TimelineStep;

// Report tab (design brief 7.6–7.9): describe → confirm → matches → filed. Same API calls and
// rules as before; one question per step, the step's action pinned at the bottom.

/// Report tab (citizens and visitors).
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});
  @override
  Widget build(BuildContext context) => const IntakePage();
}

/// Category tiles on step 1 (category, pictogram).
const _pickTiles = [
  ('Pothole', PictogramKind.pothole),
  ('Waterlogging', PictogramKind.waterlogging),
  ('Open or broken manhole', PictogramKind.manhole),
  ('Choked drain / nullah overflow', PictogramKind.drain),
  ('Road cave-in', PictogramKind.failedRepair),
];

class IntakePage extends ConsumerStatefulWidget {
  const IntakePage({super.key});
  @override
  ConsumerState<IntakePage> createState() => _IntakePageState();
}

class _IntakePageState extends ConsumerState<IntakePage> {
  final _text = TextEditingController();
  final _scroll = [for (var i = 0; i < 4; i++) ScrollController()];
  int _step = 0; // 0 describe, 1 confirm, 2 matches (3 = filed)
  bool _busy = false; // analysing or submitting
  bool? _filingVoice; // which filing button is busy
  String? _error;
  Map<String, String> _fields = const {};
  Json? _result;
  String? _analysed; // the text [_result] was made from
  String? _category, _locality, _language, _picked;
  bool _matchesLoading = false;
  Json? _filed;
  VoidCallback? _retryFile; // set when filing failed (e.g. 503), so the error panel can retry it

  @override
  void dispose() {
    _text.dispose();
    for (final s in _scroll) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _understand() async {
    final text = _text.text.trim();
    if (_result != null && _analysed == text) return setState(() => _step = 1);
    setState(() {
      _busy = true;
      _error = null;
      _fields = const {};
      _result = null;
      _filed = null;
    });
    try {
      final r = await ref.read(apiClientProvider).intake(text);
      if (!mounted) return;
      final picked = _picked;
      setState(() {
        _result = r;
        _analysed = text;
        _category = picked ?? r['category'] as String?;
        _locality = r['locality'] as String?;
        _language = r['language'] as String?;
        _step = 1;
      });
      if (picked != null && picked != r['category']) _rematch();
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

  /// Signed out: a sheet at the moment of filing, then the sign-in page. [ensureRole] stays the gate.
  Future<bool> _signIn(String why) async {
    if (ref.read(sessionProvider) != null) return true;
    final go = await showAppSheet<bool>(
      context,
      title: context.tr('Please sign in'),
      builder: (s) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(why, style: s.type.body),
            const SizedBox(height: AppSpacing.s24),
            PrimaryButton(label: s.tr('Sign in'), onPressed: () => Navigator.pop(s, true)),
            const SizedBox(height: AppSpacing.s8),
            TextButton(onPressed: () => Navigator.pop(s, false), child: Text(s.tr('Not now'))),
          ],
        ),
      ),
    );
    if (go != true || !mounted) return false;
    await context.push('/sign-in');
    return ref.read(sessionProvider) != null;
  }

  Future<void> _file({String? matchedId}) async {
    final why = context.tr('Sign in with your mobile number to file a complaint, so you can track it later.');
    if (!await _signIn(why) || !mounted) return;
    if (!await ensureRole(context, why: why)) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _filingVoice = matchedId != null;
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
      if (mounted) {
        rememberComplaint(ref, r['id'] as String);
        setState(() {
          _filed = r;
          _step = 3;
        });
      }
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

  void _reset() => setState(() {
    _text.clear();
    _step = 0;
    _result = _analysed = _filed = _error = _picked = _retryFile = null;
    _fields = const {};
  });

  void _back() => setState(() {
    _step = math.max(0, _step - 1);
    _error = null;
    _retryFile = null;
  });

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final step = r == null && _step < 3 ? 0 : _step;
    final page = switch (step) {
      1 => _confirm(context, r!),
      2 => _matches(context, r!),
      3 => _done(context, _filed!),
      _ => _describe(context),
    };
    // Back steps back through the flow; the floating tab bar stays put while an action is pinned.
    return PopScope(
      canPop: step == 0 || step == 3,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: NotificationListener<UserScrollNotification>(
        onNotification: (_) => true,
        child: AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.standard),
          switchInCurve: AppMotion.standardCurve,
          switchOutCurve: AppMotion.standardCurve,
          child: KeyedSubtree(key: ValueKey(step), child: page),
        ),
      ),
    );
  }

  /// The page frame of every step: progress bar, large title, content, pinned action.
  Widget _frame(
    BuildContext context, {
    required int step,
    required String title,
    String? caption,
    Widget? chip,
    required List<Widget> children,
    required Widget action,
  }) => LargeTitleScaffold(
    title: title,
    caption: caption,
    controller: _scroll[step],
    showBack: step == 1 || step == 2,
    detail: false,
    actions: [
      RoundIconButton(icon: Icons.chat_bubble_outline, tooltip: context.tr(kAskBot), onPressed: openAskBot),
      RoundIconButton(icon: Icons.manage_search, tooltip: context.tr(kTrackComplaint), onPressed: () => appRouter.push('/track')),
    ],
    header: Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.s4, AppSpacing.gutter, AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step < 3) _StepBar(step: step),
          if (chip != null) ...[const SizedBox(height: AppSpacing.s16), chip],
        ],
      ),
    ),
    bottomBar: BottomActionBar(child: action),
    children: [...children, if (_error != null) _errorPanel(context)],
  );

  Widget _errorPanel(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final r = _result;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.s16, AppSpacing.gutter, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s8, AppSpacing.s12),
        decoration: BoxDecoration(color: c.errorTint, borderRadius: AppRadii.tileRadius),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: c.error),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr(_error!), style: t.body.copyWith(color: c.error)),
                  for (final f in _fields.values) Text(context.tr(f), style: t.caption.copyWith(color: c.error)),
                ],
              ),
            ),
            TextButton(
              onPressed: _busy ? null : (r == null ? _understand : _retryFile ?? () => setState(() => _error = null)),
              child: Text(context.tr(r == null || _retryFile != null ? 'Retry' : 'Dismiss')),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- step 1

  Widget _describe(BuildContext context) {
    final t = context.type;
    final text = _text.text.trim();
    return _frame(
      context,
      step: 0,
      title: context.tr('What is the problem?'),
      caption: context.tr('In your own words. See if neighbours already raised it.'),
      action: PrimaryButton(label: context.tr('Continue'), loading: _busy, onPressed: text.length < 10 ? null : _understand),
      children: [
        Gutter(
          child: Semantics(
            label: context.tr('Your complaint'),
            child: TextField(
              controller: _text,
              minLines: 5,
              maxLines: 10,
              maxLength: 1000,
              enabled: !_busy,
              style: t.body,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: context.tr(kIntakeHint),
                hintMaxLines: 3,
                border: const OutlineInputBorder(borderRadius: AppRadii.cardRadius, borderSide: BorderSide.none),
                enabledBorder: const OutlineInputBorder(borderRadius: AppRadii.cardRadius, borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadii.cardRadius,
                  borderSide: BorderSide(color: SaartheeColors.of(context).primary, width: AppSpacing.focusWidth),
                ),
                contentPadding: const EdgeInsets.all(AppSpacing.s16),
                errorText: _fields['description'],
                // Intake and filing both need 10 characters (server checks too).
                helperText: text.isNotEmpty && text.length < 10 ? context.tr('At least 10 characters, please.') : null,
              ),
            ),
          ),
        ),
        Gutter(child: Text(context.tr('Try an example'), style: t.caption)),
        FilterChipRow(
          children: [
            for (final (label, example) in intakeExamples)
              FilterPill(
                label: label,
                selected: _text.text == example,
                onTap: _busy
                    ? null
                    : () => setState(() {
                        _text.text = example;
                        _result = null;
                        _filed = null;
                      }),
              ),
          ],
        ),
        Gutter(child: SectionHeading(context.tr('Or pick one'))),
        Gutter(
          child: _ChoiceGrid(
            children: [
              for (final (cat, kind) in _pickTiles)
                _ChoiceTile(
                  label: context.tr(cat),
                  pictogram: kind,
                  selected: _picked == cat,
                  onTap: () => setState(() => _picked = _picked == cat ? null : cat),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- step 2

  Widget _confirm(BuildContext context, Json r) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final live = r['source'] == 'live';
    final locs = ref.watch(localitiesProvider).value ?? const [];
    final ward =
        [
          for (final l in locs)
            if (l['locality'] == _locality) l['ward_code'],
        ].firstOrNull ??
        (_locality == r['locality'] ? r['ward_code'] : null);
    final wardName = ward == null ? null : ref.watch(mapDataProvider).value?.wardByCode[ward]?.name;
    final cands = (r['locality_candidates'] as List?) ?? const [];
    final kind =
        [
          for (final (cat, k) in _pickTiles)
            if (cat == _category) k,
        ].firstOrNull ??
        PictogramKind.report;
    return _frame(
      context,
      step: 1,
      title: context.tr('What we understood'),
      chip: StatusChip(
        context.tr(live ? kUnderstoodLive : 'Keyword rules, no AI'),
        tone: live ? StatusTone.success : StatusTone.neutral,
        dot: true,
      ),
      action: PrimaryButton(
        label: context.tr('Looks right'),
        onPressed: _category == null || _locality == null ? null : () => setState(() => _step = 2),
      ),
      children: [
        ListRow(
          icon: kind.icon,
          title: _category == null ? context.tr('Pick one') : context.tr(_category!),
          caption: context.tr('Problem'),
          onTap: _pickCategory,
        ),
        ListRow(
          icon: Icons.place_outlined,
          title: _locality ?? context.tr('Pick your locality'),
          caption: [context.tr('Place'), if (r['place_text'] case final String p when p.isNotEmpty) '“$p”'].join(' · '),
          onTap: _pickLocality,
        ),
        ListRow(
          icon: PictogramKind.ward.icon,
          title: ward == null
              ? '—'
              : [
                  context.tr('Ward {w}', {'w': ward}),
                  ?wardName,
                ].join(' · '),
          caption: context.tr('Ward'),
          onTap: _pickLocality,
        ),
        ListRow(
          icon: Icons.translate,
          title: complaintLanguages[_language] ?? '—',
          caption: context.tr('Language'),
          onTap: _pickLanguage,
          divider: false,
        ),
        if (_locality == null)
          Gutter(
            child: Text(
              context.tr('We could not find the place in your text. Please pick your locality.'),
              style: t.body.copyWith(color: c.warning),
            ),
          ),
        if (r['ambiguous'] == true && cands.length > 1) ...[
          Gutter(child: SectionHeading(context.tr('Is it {a} or {b}?', {'a': cands[0], 'b': cands[1]}))),
          Gutter(
            child: _ChoiceGrid(
              columns: 2,
              children: [
                for (final l in cands.take(2))
                  _ChoiceTile(
                    label: '$l',
                    pictogram: PictogramKind.ward,
                    selected: _locality == l,
                    onTap: () {
                      setState(() => _locality = '$l');
                      _rematch();
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickCategory() async {
    final v = await showAppSheet<String>(
      context,
      title: context.tr('Category'),
      builder: (s) => Column(
        children: [
          for (final k in complaintCategories)
            ListRow(
              title: s.tr(k),
              trailing: k == _category ? const Icon(Icons.check) : null,
              chevron: false,
              onTap: () => Navigator.pop(s, k),
            ),
        ],
      ),
    );
    if (v == null || v == _category || !mounted) return;
    setState(() => _category = v);
    _rematch();
  }

  Future<void> _pickLanguage() async {
    final v = await showAppSheet<String>(
      context,
      title: context.tr('Language'),
      builder: (s) => Column(
        children: [
          for (final e in complaintLanguages.entries)
            ListRow(
              title: e.value,
              trailing: e.key == _language ? const Icon(Icons.check) : null,
              chevron: false,
              onTap: () => Navigator.pop(s, e.key),
            ),
        ],
      ),
    );
    if (v != null && mounted) setState(() => _language = v);
  }

  Future<void> _pickLocality() async {
    final v = await showAppSheet<String>(
      context,
      title: context.tr('Place'),
      builder: (_) => _LocalitySheet(selected: _locality),
    );
    if (v == null || v == _locality || !mounted) return;
    setState(() => _locality = v);
    _rematch();
  }

  // ------------------------------------------------------------- step 3

  Widget _matches(BuildContext context, Json r) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final matches = (r['matches'] as List?) ?? const [];
    final n = r['match_count'] as int? ?? matches.length;
    final canFile = !_busy && _locality != null && _category != null;
    // Join the newest dataset complaint (it carries the repair trail); else the newest app one.
    VoidCallback? voice() => matches.isEmpty || !canFile
        ? null
        : () => _file(matchedId: (matches.firstWhere((m) => m['source'] == 'dataset', orElse: () => matches.first))['id'] as String);
    return _frame(
      context,
      step: 2,
      title: context.tr(n == 0 ? 'Not reported here yet' : 'Others reported this'),
      caption: n == 0 ? null : context.tr(alreadyReported(n), {'n': n}),
      action: matches.isEmpty || _matchesLoading
          ? PrimaryButton(label: context.tr(kFileAsNew), loading: _busy, onPressed: canFile && !_matchesLoading ? () => _file() : null)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(label: context.tr(kAddMyVoice), loading: _busy && _filingVoice == true, onPressed: voice()),
                const SizedBox(height: AppSpacing.s8),
                SecondaryButton(
                  label: context.tr(kFileAsNew),
                  loading: _busy && _filingVoice == false,
                  onPressed: canFile ? () => _file() : null,
                ),
              ],
            ),
      children: [
        if (_matchesLoading)
          Gutter(
            child: Skeleton(child: Column(children: [for (var i = 0; i < 3; i++) const _CardSkeleton()])),
          )
        else if (matches.isEmpty)
          EmptyState(
            message: context.tr('No one has reported this in {loc} in the last 14 days of the data.', {'loc': _locality}),
            pictogram: PictogramKind.report,
          )
        else ...[
          for (final (i, m) in matches.indexed)
            Gutter(
              child: StaggeredEntrance(index: i, child: ComplaintCard(m as Json)),
            ),
          if (n > matches.length)
            Gutter(child: Text(context.tr('Showing the latest {shown} of {n}.', {'shown': matches.length, 'n': n}), style: t.caption)),
          if (r['app_matches_unavailable'] == true)
            Gutter(
              child: Text(
                context.tr('Complaints filed in this app could not be checked right now.'),
                style: t.caption.copyWith(color: c.warning),
              ),
            ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------- filed

  Widget _done(BuildContext context, Json filed) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final id = filed['id'] as String;
    return _frame(
      context,
      step: 3,
      title: context.tr('Reported'),
      caption: filed['matched_complaint_id'] == null
          ? context.tr('A new complaint in {loc}.', {'loc': filed['locality']})
          : context.tr('Your voice is added to {id}.', {'id': filed['matched_complaint_id']}),
      chip: const _DrawnCheck(),
      action: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(label: context.tr('Track it'), onPressed: () => pushComplaint(context, id)),
          TextButton(onPressed: _reset, child: Text(context.tr('Done'))),
        ],
      ),
      children: [
        const SizedBox(height: AppSpacing.s16),
        Gutter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s16, AppSpacing.s8, AppSpacing.s16),
            decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: AppRadii.cardRadius),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('Complaint id'), style: t.caption),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(id, style: t.figure),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Copy'),
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: id));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Copied'))));
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        Gutter(
          child: Text(context.tr('We’ll show what happens to it here.'), style: t.body.copyWith(color: c.textSecondary)),
        ),
      ],
    );
  }
}

/// Thin three-segment progress bar for the report steps.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Semantics(
      label: context.tr('Step {n} of 3', {'n': step + 1}),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.s4),
            Expanded(
              child: AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.standard),
                curve: AppMotion.standardCurve,
                height: 4,
                decoration: BoxDecoration(color: i <= step ? c.primary : c.surfaceAlt, borderRadius: AppRadii.pillRadius),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rows of equal tiles ([columns] per row; default 3, 5 on wide screens).
class _ChoiceGrid extends StatelessWidget {
  const _ChoiceGrid({required this.children, this.columns});
  final List<Widget> children;
  final int? columns;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final cols = columns ?? (box.maxWidth >= 560 ? 5 : 3);
      return Column(
        children: [
          for (var i = 0; i < children.length; i += cols) ...[
            if (i > 0) const SizedBox(height: AppSpacing.tileGap),
            StaggeredEntrance(
              index: i ~/ cols,
              child: Row(
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) const SizedBox(width: AppSpacing.tileGap),
                    Expanded(child: i + j < children.length ? children[i + j] : const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// Square grey tile that can be selected (black when selected).
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.label, required this.pictogram, required this.selected, required this.onTap});
  final String label;
  final PictogramKind pictogram;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final fg = selected ? c.onPrimary : c.textPrimary;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      color: selected ? c.primary : c.surfaceAlt,
      pressedColor: selected ? c.primaryDark : c.surfacePressed,
      borderRadius: AppRadii.tileRadius,
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.quick),
        height: AppSpacing.tileSquare + math.max(0, scale - 1) * 48,
        padding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Pictogram(pictogram, color: fg),
            ),
            Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.label.copyWith(fontSize: 13, height: 17 / 13, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Searchable locality list for the Place row.
class _LocalitySheet extends ConsumerStatefulWidget {
  const _LocalitySheet({required this.selected});
  final String? selected;
  @override
  ConsumerState<_LocalitySheet> createState() => _LocalitySheetState();
}

class _LocalitySheetState extends ConsumerState<_LocalitySheet> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    return Column(
      children: [
        Gutter(
          child: SearchField(
            hint: context.tr('Locality (type to search)'),
            autofocus: true,
            onChanged: (v) => setState(() => _q = v.trim()),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        switch (ref.watch(localitiesProvider)) {
          AsyncData(:final value) => Column(
            children: [
              for (final l in value)
                if (q.isEmpty || '${l['locality']}'.toLowerCase().contains(q) || '${l['ward_code']}'.toLowerCase() == q)
                  ListRow(
                    title: '${l['locality']}',
                    caption: context.tr('Ward {w}', {'w': l['ward_code']}),
                    trailing: l['locality'] == widget.selected ? const Icon(Icons.check) : null,
                    chevron: false,
                    onTap: () => Navigator.pop(context, l['locality'] as String),
                  ),
            ],
          ),
          AsyncError() => ErrorState(message: context.tr('Could not load localities.'), onRetry: () => ref.invalidate(localitiesProvider)),
          _ => Skeleton.rows(count: 6),
        },
      ],
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: AppSpacing.cardGap),
    child: SkeletonBox(height: 104, radius: AppRadii.card),
  );
}

/// Black circle with a check mark that draws itself (400 ms; instant with reduced motion).
class _DrawnCheck extends StatelessWidget {
  const _DrawnCheck();
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Semantics(
      label: context.tr('Reported'),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.of(context, const Duration(milliseconds: 400)),
        curve: Curves.easeOutCubic,
        builder: (_, k, _) => SizedBox.square(dimension: 72, child: CustomPaint(painter: _CheckPainter(k, c.primary, c.onPrimary))),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.k, this.fill, this.stroke);
  final double k;
  final Color fill, stroke;
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawCircle(Offset(s / 2, s / 2), s / 2 * (0.85 + 0.15 * k), Paint()..color = fill);
    final path = Path()
      ..moveTo(s * 0.28, s * 0.52)
      ..lineTo(s * 0.44, s * 0.67)
      ..lineTo(s * 0.73, s * 0.37);
    final m = path.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * k),
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.k != k || old.fill != fill || old.stroke != stroke;
}
