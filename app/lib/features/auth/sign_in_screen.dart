import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/session.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/saarthee.dart';

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
    final t = Theme.of(context).textTheme;
    final c = SaartheeColors.of(context);
    return Scaffold(
      appBar: SaartheeAppBar(title: context.tr('Sign in')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.s24, AppSpacing.gutter, AppSpacing.s24),
            children: [
              Text(context.tr('Sign in with your mobile number'), style: t.titleLarge),
              const SizedBox(height: AppSpacing.s4),
              Text(
                context.tr(
                  'The map stays open to everyone. Sign in to file a complaint or draft a notice. '
                  'This demo uses a fixed code instead of an SMS.',
                ),
                style: t.bodyMedium?.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s16),
              TextField(
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: InputDecoration(
                  labelText: context.tr('Mobile number'),
                  hintText: context.tr('10 digits'),
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: const OutlineInputBorder(),
                  errorText: _fields['phone'] == null ? null : context.tr('${_fields['phone']}'),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              TextField(
                controller: _code,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                onSubmitted: (_) => _busy ? null : _submit(),
                decoration: InputDecoration(
                  labelText: context.tr('Code'),
                  prefixIcon: const Icon(Icons.password),
                  border: const OutlineInputBorder(),
                  errorText: _fields['code'] == null ? null : context.tr('${_fields['code']}'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(context.tr(_error!), style: t.bodyMedium?.copyWith(color: c.error)),
              ],
              const SizedBox(height: AppSpacing.s16),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.login),
                label: Text(context.tr(_busy ? 'Signing in…' : 'Sign in')),
              ),
              const SizedBox(height: AppSpacing.s24),
              Text(context.tr('Demo shortcuts (fill the fields)'), style: t.labelLarge),
              const SizedBox(height: AppSpacing.s8),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  for (final e in roleLabels.entries)
                    OutlinedButton(
                      onPressed: _busy ? null : () => _fillDemo(e.key),
                      child: Text('Demo: ${context.tr(e.value)}'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
