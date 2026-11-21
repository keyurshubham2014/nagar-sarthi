import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_router.dart';
import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/prefs.dart';
import '../../core/widgets/ui.dart';
import '../officer/officer_panels.dart';
import '../trail/trail_screen.dart';
import 'citizen_panels.dart' hide TimelineStep;

const String kAskBot = 'Ask about a complaint';
void openAskBot() => appRouter.push('/ask');

/// One line of the conversation: the citizen's question, or an answer with its facts.
class _Msg {
  _Msg.user(this.text) : mine = true, reply = null, error = false;
  _Msg.bot(this.text, {this.reply, this.error = false}) : mine = false;
  final bool mine;
  final String text;
  final Map<String, dynamic>? reply;
  final bool error;
}

/// "What happened to my complaint?" The server finds the complaint, issue and work order; Claude
/// (or the saved template) words the answer. The conversation stays in memory on this page only.
class AskBotPage extends ConsumerStatefulWidget {
  const AskBotPage({super.key});
  @override
  ConsumerState<AskBotPage> createState() => _AskBotPageState();
}

class _AskBotPageState extends ConsumerState<AskBotPage> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _msgs = <_Msg>[];
  bool _busy = false; // one question at a time

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String q) async {
    q = q.trim();
    if (q.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _msgs.add(_Msg.user(q));
      _text.clear();
    });
    _toEnd();
    try {
      final r = await ref.read(apiClientProvider).answer(q, language: context.lang, ward: ref.read(chosenWardProvider));
      if (mounted) setState(() => _msgs.add(_Msg.bot(r['text'] as String? ?? '', reply: r)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _msgs.add(_Msg.bot(e.message, error: true)));
    } finally {
      if (mounted) setState(() => _busy = false);
      _toEnd();
    }
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: AppMotion.of(context, AppMotion.standard), curve: AppMotion.standardCurve);
    }
  });

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final chips = ['BMC25-006359', context.tr('Why is my road still broken?'), context.tr('How much was spent on my road?')];
    final canSend = !_busy && _text.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: c.background,
      appBar: TopBar(title: context.tr(kAskBot)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxContent),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.s16, AppSpacing.gutter, AppSpacing.s16),
                    children: [
                      _Answer(child: Text(context.tr('Namaste! Send your complaint id (like BMC25-001234 or NS-000012) or ask a question, and I will tell you what happened to it.'), style: t.body)),
                      for (final (i, m) in _msgs.indexed)
                        StaggeredEntrance(key: ValueKey(i), index: 0, child: _message(context, m)),
                      if (_busy)
                        _Answer(
                          child: Semantics(
                            label: context.tr('Looking it up…'),
                            child: const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.s8), child: Align(alignment: AlignmentDirectional.centerStart, child: DotPulse())),
                          ),
                        ),
                    ],
                  ),
                ),
                FilterChipRow(
                  children: [for (final q in chips) FilterPill(label: q, selected: false, onTap: _busy ? null : () => _send(q))],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.s4, AppSpacing.gutter, AppSpacing.s12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _text,
                          enabled: !_busy,
                          maxLength: 500,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: _send,
                          onChanged: (_) => setState(() {}),
                          style: t.body,
                          decoration: InputDecoration(
                            hintText: context.tr('Type a complaint id or a question'),
                            counterText: '',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s14),
                            border: const OutlineInputBorder(borderRadius: AppRadii.pillRadius, borderSide: BorderSide.none),
                            enabledBorder: const OutlineInputBorder(borderRadius: AppRadii.pillRadius, borderSide: BorderSide.none),
                            disabledBorder: const OutlineInputBorder(borderRadius: AppRadii.pillRadius, borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: AppRadii.pillRadius,
                              borderSide: BorderSide(color: c.primary, width: AppSpacing.focusWidth),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Pressable(
                        onTap: canSend ? () => _send(_text.text) : null,
                        circle: true,
                        haptic: true,
                        semanticLabel: context.tr('Send'),
                        color: canSend ? c.primary : c.surfacePressed,
                        pressedColor: c.primaryDark,
                        child: SizedBox.square(
                          dimension: AppSpacing.touchTarget,
                          child: Icon(Icons.arrow_upward, color: canSend ? c.onPrimary : c.textDisabled),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(BuildContext context, _Msg m) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    if (m.mine) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.s16, left: AppSpacing.s40),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
            decoration: BoxDecoration(color: c.primary, borderRadius: AppRadii.cardRadius),
            child: Text(m.text, style: t.body.copyWith(color: c.onPrimary)),
          ),
        ),
      );
    }
    if (m.error) {
      return _Answer(child: Text(context.tr('Could not get an answer. {e}', {'e': m.text}), style: t.body.copyWith(color: c.error)));
    }
    final r = m.reply ?? const {};
    final live = r['source'] == 'live';
    final facts = _facts(context, r);
    return _Answer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.text, style: t.body),
          const SizedBox(height: AppSpacing.s8),
          StatusChip(context.tr(live ? 'Answered live by Claude' : 'Saved answer'), tone: live ? StatusTone.success : StatusTone.neutral, dot: true),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            ClipRRect(
              borderRadius: AppRadii.tileRadius,
              child: ColoredBox(
                color: c.surfaceAlt,
                child: Column(
                  children: [
                    for (final (i, f) in facts.indexed) ...[
                      if (i > 0) Divider(height: 1, thickness: 1, indent: AppSpacing.s16, color: c.background),
                      f,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The facts behind the answer as compact tappable rows.
  List<Widget> _facts(BuildContext context, Map<String, dynamic> r) => [
    if (r['complaint_id'] case final String id when r['kind'] == 'complaint')
      _Fact(icon: Icons.inbox_outlined, title: context.tr('Complaint {id}', {'id': id}), onTap: () => pushComplaint(context, id)),
    if (r['matched_complaint_id'] case final String id)
      _Fact(icon: Icons.group_add_outlined, title: context.tr('Complaint {id}', {'id': id}), onTap: () => pushComplaint(context, id)),
    if (r['work_order_id'] case final String wo)
      _Fact(
        icon: Icons.assignment_outlined,
        title: context.tr('Work order {id}', {'id': wo}),
        sub: [
          if (r['cost_inr'] is num) formatInr(r['cost_inr'] as num),
          if (r['road_name'] != null) '${r['road_name']}',
          if (r['link'] == 'inferred') context.tr(kInferredLink),
          if (r['under_warranty'] == true) context.tr('Under warranty'),
        ].join(' · '),
        onTap: r['road_id'] == null ? null : () => openRoad(r['road_id'] as String, wo: wo),
      ),
    if (r['issue_id'] case final String issue)
      _Fact(icon: Icons.account_tree_outlined, title: context.tr('Issue {id}', {'id': issue}), sub: context.tr(outcomeLabels[r['outcome']] ?? ''), onTap: () => openIssue(issue)),
    if (r['kind'] == 'ward' && r['ward_code'] is String)
      _Fact(icon: Icons.route_outlined, title: context.tr('Complaint trail · Ward {w}', {'w': r['ward_code']}), onTap: () => openTrail(r['ward_code'] as String)),
    if (r['kind'] == 'not_found') _Fact(icon: Icons.manage_search, title: context.tr('Track a complaint'), onTap: () => appRouter.push('/track')),
  ];
}

/// An answer: plain text on white, left, after a small round "N" mark.
class _Answer extends StatelessWidget {
  const _Answer({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s20, right: AppSpacing.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
              child: Text('N', style: t.label.copyWith(color: c.onPrimary, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// One compact fact row inside the grey group under an answer.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.title, this.sub, this.onTap});
  final IconData icon;
  final String title;
  final String? sub;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    return Pressable(
      onTap: onTap,
      scale: false,
      pressedColor: c.surfacePressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget + AppSpacing.s8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
          child: Row(
            children: [
              Icon(icon, size: AppSpacing.iconSmall, color: c.textPrimary),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: t.label),
                    if (sub != null && sub!.isNotEmpty) Text(sub!, style: t.caption),
                  ],
                ),
              ),
              if (onTap != null) Icon(Icons.chevron_right, color: c.textSecondary, size: AppSpacing.iconSize),
            ],
          ),
        ),
      ),
    );
  }
}
