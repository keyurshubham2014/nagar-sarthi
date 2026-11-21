import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../api/api_client.dart';
import 'ui.dart';

/// Asks the server's Claude [feature] for a draft and shows it editable on a
/// full-screen draft page, with Copy, Share and regenerate. The server builds
/// the prompt from [body]; send ids, not figures. Reusable for any drafting
/// feature (notice, brief, question...).
Future<void> showClaudeDraftSheet(
  BuildContext context, {
  required String title,
  required String feature,
  required Map<String, dynamic> body,
  Map<String, String>? languages,
  String textLabel = 'Draft letter (editable)',
}) => Navigator.of(context, rootNavigator: true).push<void>(
  MaterialPageRoute(
    builder: (_) => _DraftPage(title: title, feature: feature, body: body, languages: languages, textLabel: textLabel),
  ),
);

/// Short segment labels for the language switch; unknown codes keep their given label.
const Map<String, String> _shortLang = {'en': 'EN', 'hi': 'हिं', 'mr': 'मरा'};

class _DraftPage extends ConsumerStatefulWidget {
  const _DraftPage({
    required this.title,
    required this.feature,
    required this.body,
    this.languages,
    required this.textLabel,
  });
  final String title;
  final String feature;
  final Map<String, dynamic> body;

  /// Code -> label. Adds a language switch that redrafts with `body['language']`.
  final Map<String, String>? languages;
  final String textLabel;
  @override
  ConsumerState<_DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends ConsumerState<_DraftPage> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  bool _copied = false;

  /// True while a fresh draft's paragraphs fade in; then the editable field takes over.
  bool _revealing = false;
  String? _source;
  String? _error;
  Timer? _copiedTimer;
  Timer? _revealTimer;
  late String? _lang = widget.languages == null ? null : (widget.body['language'] as String? ?? widget.languages!.keys.first);

  @override
  void initState() {
    super.initState();
    _draft();
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _revealTimer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _draft() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = {...widget.body, 'language': ?_lang};
      final reply = await ref.read(apiClientProvider).claude(widget.feature, body);
      if (!mounted) return;
      _text.text = reply.text;
      final reveal = !AppMotion.reduced(context);
      setState(() {
        _source = reply.source;
        _revealing = reveal;
      });
      _revealTimer?.cancel();
      if (reveal) {
        _revealTimer = Timer(AppMotion.staggerStep * AppMotion.staggerMax + AppMotion.standard, () {
          if (mounted) setState(() => _revealing = false);
        });
      }
    } on ApiException catch (e) {
      debugPrint('[draft] ${widget.feature} failed: ${e.status ?? ''} ${e.message}');
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text.text));
    if (!mounted) return;
    setState(() => _copied = true);
    SemanticsService.sendAnnouncement(View.of(context), 'Copied to clipboard', TextDirection.ltr);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _share() async {
    try {
      await SharePlus.instance.share(ShareParams(text: _text.text, subject: widget.title));
    } catch (e) {
      // Some browsers have no share sheet: copy instead so the action still does something.
      debugPrint('[draft] share failed: $e');
      await _copy();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    final hasText = !_busy && _error == null && _source != null;
    final letter = t.body.copyWith(height: 26 / 16);
    final langs = widget.languages;

    final Widget panel;
    if (_busy) {
      panel = Skeleton(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final w in const [0.5, 1.0, 0.95, 1.0, 0.7, 0.0, 1.0, 0.9, 0.98, 0.6]) ...[
              if (w == 0) const SizedBox(height: 12) else SkeletonBox(height: 12, widthFactor: w, radius: 6),
              const SizedBox(height: AppSpacing.s14),
            ],
          ],
        ),
      );
    } else if (_error != null) {
      panel = ErrorState(message: 'Could not draft this.\n$_error', onRetry: _draft);
    } else if (_revealing) {
      final lines = _text.text.split('\n');
      panel = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final (i, l) in lines.indexed) StaggeredEntrance(index: i, child: Text(l, style: letter))],
      );
    } else {
      panel = TextField(
        controller: _text,
        maxLines: null,
        style: letter,
        decoration: InputDecoration(
          hintText: widget.textLabel,
          filled: false,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: TopBar(
        title: widget.title,
        controller: _scroll,
        actions: [
          RoundIconButton(icon: Icons.refresh, tooltip: _error != null ? 'Retry' : 'Redraft', onPressed: _busy ? null : _draft),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: _copied ? 'Copied' : 'Copy',
                icon: _copied ? Icons.check : Icons.copy,
                onPressed: hasText ? _copy : null,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(child: PrimaryButton(label: 'Share', icon: Icons.ios_share, onPressed: hasText ? _share : null)),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxContent),
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.s8, AppSpacing.gutter, AppSpacing.s32),
              children: [
                Semantics(header: true, child: Text(widget.title, style: t.headline)),
                const SizedBox(height: AppSpacing.s12),
                Row(
                  children: [
                    AnimatedSwitcher(
                      duration: AppMotion.of(context, AppMotion.quick),
                      child: hasText
                          ? StatusChip(
                              _source == 'live' ? 'Live' : 'Saved',
                              key: ValueKey(_source),
                              tone: _source == 'live' ? StatusTone.success : StatusTone.neutral,
                              dot: true,
                            )
                          : const SizedBox(height: AppSpacing.s24),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        _busy ? 'Drafting…' : (_source == 'live' ? 'Drafted live by Claude' : (hasText ? 'Saved draft' : '')),
                        style: t.caption,
                      ),
                    ),
                  ],
                ),
                if (langs != null) ...[
                  const SizedBox(height: AppSpacing.s16),
                  IgnorePointer(
                    ignoring: _busy,
                    child: SegmentedControl<String>(
                      segments: [for (final e in langs.entries) (e.key, _shortLang[e.key] ?? e.value)],
                      value: _lang!,
                      onChanged: (v) {
                        setState(() => _lang = v);
                        _draft();
                      },
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.s16),
                if (hasText) ...[
                  Text(widget.textLabel, style: t.caption),
                  const SizedBox(height: AppSpacing.s8),
                ],
                AnimatedSwitcher(
                  duration: AppMotion.of(context, AppMotion.standard),
                  child: KeyedSubtree(
                    key: ValueKey('$_busy$_error'),
                    // Skeleton lines are grey themselves, so they sit on the page, not the grey panel.
                    child: _error != null || _busy
                        ? Padding(padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8), child: panel)
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.s20),
                            decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: AppRadii.tileRadius),
                            child: panel,
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                Text(
                  _busy ? 'Claude is writing from the audit rows on the server.' : 'Draft made from synthetic data. Review before sending.',
                  style: t.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
