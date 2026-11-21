import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/session.dart';
import '../../core/i18n.dart';
import '../../core/widgets/ui.dart';

/// Phone + demo code sign-in. Pops `true` on success.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, dynamic> _fields = const {};

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
      _fields = const {};
    });
    try {
      await ref.read(sessionProvider.notifier).signIn(_phone.text.trim(), _code.text.trim());
      if (mounted) context.pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _fields = e.fields;
          _error = e.fields.isEmpty ? e.message : null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Fills both fields for a demo role; the code comes from the server.
  Future<void> _fillDemo(String role) async {
    setState(() => _error = null);
    try {
      final demo = await ref.read(apiClientProvider).demoLogin();
      if (!mounted) return;
      setState(() {
        _phone.text = (demo['users'] as Map)[role] as String;
        _code.text = demo['code'] as String;
        _fields = const {};
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.status == 404 ? 'Demo shortcuts are turned off on this server.' : e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    const roleIcons = {'citizen': Icons.person_outline, 'corporator': Icons.account_balance_outlined, 'officer': Icons.badge_outlined};
    return LargeTitleScaffold(
      title: context.tr('Sign in'),
      caption: context.tr(
        'The map stays open to everyone. Sign in to file a complaint or draft a notice. '
        'This demo uses a fixed code instead of an SMS.',
      ),
      maxWidth: 480,
      bottomBar: BottomActionBar(
        child: PrimaryButton(label: context.tr('Sign in'), loading: _busy, onPressed: _busy ? null : _submit),
      ),
      children: [
        Gutter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.s16),
              Text(context.tr('Mobile number'), style: t.label),
              const SizedBox(height: AppSpacing.s8),
              TextField(
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                autofillHints: const [AutofillHints.telephoneNumber],
                style: t.figure,
                decoration: InputDecoration(
                  hintText: context.tr('10 digits'),
                  // A prefix icon, not prefixText, so "+91" shows before anything is typed.
                  prefixIcon: Padding(
                    padding: const EdgeInsetsDirectional.only(start: AppSpacing.s16, end: AppSpacing.s12),
                    child: Text('+91', style: t.figure.copyWith(color: c.textSecondary)),
                  ),
                  prefixIconConstraints: const BoxConstraints(),
                  errorText: _fields['phone'] == null ? null : context.tr('${_fields['phone']}'),
                ),
              ),
              const SizedBox(height: AppSpacing.s20),
              Text(context.tr('Code'), style: t.label),
              const SizedBox(height: AppSpacing.s8),
              _CodeBoxes(
                controller: _code,
                enabled: !_busy,
                label: context.tr('Code'),
                error: _fields['code'] == null ? null : context.tr('${_fields['code']}'),
                onSubmitted: () => _busy ? null : _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.s12),
                Text(context.tr(_error!), style: t.body.copyWith(color: c.error)),
              ],
            ],
          ),
        ),
        const SectionBreak(space: AppSpacing.s32),
        Gutter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: Semantics(header: true, child: Text(context.tr('Demo shortcuts (fill the fields)'), style: t.title)),
          ),
        ),
        Gutter(
          child: TileGrid(
            squareColumns: 3,
            tiles: [
              for (final e in roleLabels.entries)
                Tile(
                  label: context.tr(e.value),
                  art: Icon(roleIcons[e.key], size: AppSpacing.pictogram, color: c.textPrimary),
                  semanticLabel: 'Demo: ${context.tr(e.value)}',
                  onTap: _busy ? null : () => _fillDemo(e.key),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Code entry shown as boxes (six, more if the code is longer), backed by one
/// invisible text field so paste, autofill and the keyboard work as usual.
class _CodeBoxes extends StatefulWidget {
  const _CodeBoxes({required this.controller, required this.enabled, required this.label, required this.onSubmitted, this.error});
  final TextEditingController controller;
  final bool enabled;
  final String label;
  final String? error;
  final VoidCallback onSubmitted;

  @override
  State<_CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<_CodeBoxes> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, _focus]),
      builder: (context, _) {
        final text = widget.controller.text;
        final n = math.max(6, text.length);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ExcludeSemantics(
                  child: Row(
                    children: [
                      for (var i = 0; i < n; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: AnimatedContainer(
                            duration: AppMotion.of(context, AppMotion.quick),
                            height: AppSpacing.buttonHeight,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c.surfaceAlt,
                              borderRadius: AppRadii.controlRadius,
                              border: Border.all(
                                width: AppSpacing.focusWidth,
                                color: widget.error != null
                                    ? c.error
                                    : _focus.hasFocus && i == math.min(text.length, n - 1)
                                    ? c.primary
                                    : c.surfaceAlt,
                              ),
                            ),
                            child: Text(i < text.length ? text[i] : '', style: t.figure),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    alwaysIncludeSemantics: true,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                      onSubmitted: (_) => widget.onSubmitted(),
                      showCursor: false,
                      enableInteractiveSelection: false,
                      decoration: InputDecoration.collapsed(hintText: widget.label),
                    ),
                  ),
                ),
              ],
            ),
            if (widget.error != null) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(widget.error!, style: t.caption.copyWith(color: c.error)),
            ],
          ],
        );
      },
    );
  }
}
