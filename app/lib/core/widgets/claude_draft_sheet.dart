import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../theme/tokens.dart';
import 'saarthee.dart';

/// Asks the server's Claude [feature] for a draft and shows it editable on a
/// full-screen page, with Copy and Redraft. The server builds the prompt from
/// [body]; send ids, not figures. Reusable for any drafting feature (notice, brief...).
Future<void> showClaudeDraftSheet(
  BuildContext context, {
  required String title,
  required String feature,
  required Map<String, dynamic> body,
  Map<String, String>? languages,
  String textLabel = 'Draft letter (editable)',
}) => Navigator.of(context, rootNavigator: true).push<void>(
  MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: SaartheeAppBar(title: title),
      body: SafeArea(
        child: ContentWidth(
          padded: false,
          child: _DraftSheet(title: title, feature: feature, body: body, languages: languages, textLabel: textLabel),
        ),
      ),
    ),
  ),
);

class _DraftSheet extends ConsumerStatefulWidget {
  const _DraftSheet({
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
  ConsumerState<_DraftSheet> createState() => _DraftSheetState();
}

class _DraftSheetState extends ConsumerState<_DraftSheet> {
  final _text = TextEditingController();
  bool _busy = false;
  bool _copied = false;
  String? _source;
  String? _error;
  Timer? _copiedTimer;
  late String? _lang = widget.languages == null ? null : (widget.body['language'] as String? ?? widget.languages!.keys.first);

  @override
  void initState() {
    super.initState();
    _draft();
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _text.dispose();
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
      setState(() => _source = reply.source);
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

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final hasText = !_busy && _error == null && _source != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.s12,
        AppSpacing.gutter,
        AppSpacing.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasText)
            Align(
              alignment: Alignment.centerLeft,
              child: _Badge(
                _source == 'live' ? 'Drafted live by Claude' : 'Saved draft',
                _source == 'live' ? c.successTint : c.warningTint,
                _source == 'live' ? c.success : c.warning,
              ),
            ),
          if (widget.languages case final langs?) ...[
            const SizedBox(height: AppSpacing.s8),
            SegmentedButton<String>(
              segments: [for (final e in langs.entries) ButtonSegment(value: e.key, label: Text(e.value))],
              selected: {_lang!},
              showSelectedIcon: false,
              onSelectionChanged: _busy
                  ? null
                  : (s) {
                      setState(() => _lang = s.first);
                      _draft();
                    },
            ),
          ],
          const SizedBox(height: AppSpacing.s8),
          Expanded(
            child: _busy
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const LinearProgressIndicator(),
                      const SizedBox(height: AppSpacing.s12),
                      Text('Drafting…', style: t.bodyLarge),
                      Text('Claude is writing from the audit rows on the server.', style: t.bodySmall),
                    ],
                  )
                : _error != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: c.error, size: 36),
                      const SizedBox(height: AppSpacing.s8),
                      Text('Could not draft this.\n$_error', textAlign: TextAlign.center),
                    ],
                  )
                : TextField(
                    controller: _text,
                    expands: true,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    style: t.bodyMedium,
                    decoration: InputDecoration(
                      labelText: widget.textLabel,
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _draft,
                icon: const Icon(Icons.refresh),
                label: Text(_error != null ? 'Retry' : 'Redraft'),
              ),
              const SizedBox(width: AppSpacing.s8),
              FilledButton.icon(
                onPressed: hasText ? _copy : null,
                icon: Icon(_copied ? Icons.check : Icons.copy),
                label: Text(_copied ? 'Copied to clipboard' : 'Copy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: AppRadii.controlRadius),
    child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
  );
}
