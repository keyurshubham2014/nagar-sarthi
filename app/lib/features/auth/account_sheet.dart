import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/session.dart';
import '../../core/i18n.dart';
import '../../core/theme/tokens.dart';

/// Account sheet from Home's account button: who is signed in, the three
/// "Demo:" switches, sign in / switch account, sign out, and About this data.
Future<void> showAccountSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => const _AccountSheet(),
);

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final notifier = ref.read(sessionProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: c.primaryContainer,
                  child: Icon(s == null ? Icons.person_outline : Icons.person, color: c.onPrimaryContainer),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s == null ? context.tr('Not signed in') : context.tr(roleLabels[s.role] ?? s.role), style: t.titleLarge),
                      Text(
                        s == null
                            ? context.tr('The map and audit are open to everyone. Sign in to file a complaint or draft a notice.')
                            : '${s.phone}${s.ward == null ? '' : ' · ${context.tr('Ward {w}', {'w': s.ward})}'}',
                        style: t.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(context.tr('Demo: switch role in one tap'), style: t.labelLarge),
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                for (final e in roleLabels.entries)
                  if (s?.role != e.key)
                    OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          await notifier.signInAsDemo(e.key);
                        } on ApiException catch (err) {
                          messenger.showSnackBar(SnackBar(content: Text('Could not sign in: ${err.message}')));
                        }
                      },
                      child: Text('Demo: ${context.tr(e.value)}'),
                    ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.login),
              title: Text(context.tr(s == null ? 'Sign in with a number…' : 'Switch account…')),
              onTap: () {
                Navigator.pop(context);
                appRouter.push('/sign-in');
              },
            ),
            if (s != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout),
                title: Text(context.tr('Sign out')),
                onTap: () {
                  Navigator.pop(context);
                  notifier.signOut();
                },
              ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: Text(context.tr('About this data')),
              subtitle: Text(context.tr('Synthetic data, how flags work, credits')),
              onTap: () {
                Navigator.pop(context);
                appRouter.push('/about');
              },
            ),
          ],
        ),
      ),
    );
  }
}
