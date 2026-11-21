import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_router.dart';
import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/prefs.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/saarthee.dart';
import '../officer/officer_panels.dart';
import '../officer/panel.dart';
import '../trail/trail_screen.dart';
import 'citizen_panels.dart';

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
    if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  });

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final chips = ['BMC25-006359', context.tr('Why is my road still broken?'), context.tr('How much was spent on my road?')];
    return SafeArea(
      top: false,
      child: ContentWidth(
        padded: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.s16, AppSpacing.gutter, AppSpacing.s16),
                children: [
                  _Bubble(
                    mine: false,
                    child: Text(context.tr('Namaste! Send your complaint id (like BMC25-001234 or NS-000012) or ask a question, and I will tell you what happened to it.'), style: t.bodyMedium),
                  ),
                  for (final m in _msgs) _message(context, m),
                  if (_busy)
                    _Bubble(
                      mine: false,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: AppSpacing.s8),
                          Flexible(child: Text(context.tr('Looking it up…'), style: t.bodyMedium)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.s8, AppSpacing.s8, AppSpacing.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final q in chips)
                            Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.s8),
                              child: ActionChip(label: Text(q), onPressed: _busy ? null : () => _send(q)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _text,
                            enabled: !_busy,
                            maxLength: 500,
                            minLines: 1,
                            maxLines: 3,
                            textInputAction: TextInputAction.send,
                            onSubmitted: _send,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(hintText: context.tr('Type a complaint id or a question'), counterText: '', border: const OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        IconButton.filled(tooltip: context.tr('Send'), onPressed: _busy || _text.text.trim().isEmpty ? null : () => _send(_text.text), icon: const Icon(Icons.send)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(BuildContext context, _Msg m) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    if (m.mine) return _Bubble(mine: true, child: Text(m.text, style: t.bodyMedium));
    if (m.error) {
      return _Bubble(
        mine: false,
        child: Text(context.tr('Could not get an answer. {e}', {'e': m.text}), style: t.bodyMedium?.copyWith(color: c.error)),
      );
    }
    final r = m.reply ?? const {};
    final live = r['source'] == 'live';
    return _Bubble(
      mine: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.text, style: t.bodyMedium),
          const SizedBox(height: AppSpacing.s8),
          Tag(
            context.tr(live ? 'Answered live by Claude' : 'Saved answer'),
            bg: live ? c.successTint : c.warningTint,
            fg: live ? c.success : c.warning,
            icon: live ? Icons.auto_awesome : Icons.description_outlined,
          ),
          ..._facts(context, r),
        ],
      ),
    );
  }

  /// The facts behind the answer as small tappable cards.
  List<Widget> _facts(BuildContext context, Map<String, dynamic> r) {
    final cards = <Widget>[
      if (r['complaint_id'] case final String id when r['kind'] == 'complaint')
        _FactCard(icon: Icons.inbox_outlined, title: context.tr('Complaint {id}', {'id': id}), onTap: () => pushComplaint(context, id)),
      if (r['matched_complaint_id'] case final String id) _FactCard(icon: Icons.group_add_outlined, title: context.tr('Complaint {id}', {'id': id}), onTap: () => pushComplaint(context, id)),
      if (r['work_order_id'] case final String wo)
        _FactCard(
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
        _FactCard(icon: Icons.account_tree_outlined, title: context.tr('Issue {id}', {'id': issue}), sub: context.tr(outcomeLabels[r['outcome']] ?? ''), onTap: () => openIssue(issue)),
      if (r['kind'] == 'ward' && r['ward_code'] is String)
        _FactCard(icon: Icons.account_tree_outlined, title: context.tr('Complaint trail · Ward {w}', {'w': r['ward_code']}), onTap: () => openTrail(r['ward_code'] as String)),
      if (r['kind'] == 'not_found') _FactCard(icon: Icons.timeline, title: context.tr('Track a complaint'), onTap: () => appRouter.push('/track')),
    ];
    return [if (cards.isNotEmpty) const SizedBox(height: AppSpacing.s8), ...cards];
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.mine, required this.child});
  final bool mine;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mine ? 280 : 520),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.s12),
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: mine ? c.primaryContainer : c.surface,
            border: mine ? null : Border.all(color: c.border),
            borderRadius: AppRadii.cardRadius,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _FactCard extends StatelessWidget {
  const _FactCard({required this.icon, required this.title, this.sub, this.onTap});
  final IconData icon;
  final String title;
  final String? sub;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s4),
      child: Material(
        color: c.surfaceAlt,
        borderRadius: AppRadii.controlRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: c.primary),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: t.labelLarge),
                        if (sub != null && sub!.isNotEmpty) Text(sub!, style: t.bodySmall?.copyWith(color: c.textSecondary)),
                      ],
                    ),
                  ),
                  if (onTap != null) Icon(Icons.chevron_right, color: c.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
