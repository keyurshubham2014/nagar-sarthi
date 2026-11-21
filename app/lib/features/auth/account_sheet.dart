import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/session.dart';
import '../../core/i18n.dart';
import '../../core/widgets/ui.dart';

/// Account sheet from Home's account button: who is signed in, the three
/// "Demo:" switches, sign in / switch account, language, About this data, sign out.
Future<void> showAccountSheet(BuildContext context) => showAppSheet<void>(context, builder: (_) => const _AccountSheet());

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final c = SaartheeColors.of(context);
    final t = context.type;
    final notifier = ref.read(sessionProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    void go(String path) {
      Navigator.pop(context);
      appRouter.push(path);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gutter(
          child: Row(
            children: [
              Container(
                width: AppSpacing.s56,
                height: AppSpacing.s56,
                decoration: BoxDecoration(color: s == null ? c.surfaceAlt : c.primary, shape: BoxShape.circle),
                child: Icon(s == null ? Icons.person_outline : Icons.person, color: s == null ? c.textPrimary : c.onPrimary, size: 28),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s == null ? context.tr('Not signed in') : s.phone, style: t.title),
                    const SizedBox(height: AppSpacing.s4),
                    if (s == null)
                      Text(
                        context.tr('The map and ward figures are open to everyone. Sign in to file a complaint or draft a notice.'),
                        style: t.caption,
                      )
                    else
                      StatusChip(
                        '${context.tr(roleLabels[s.role] ?? s.role)}${s.ward == null ? '' : ' · ${context.tr('Ward {w}', {'w': s.ward})}'}',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SectionBreak(space: AppSpacing.s20),
        Gutter(child: Text(context.tr('Demo: switch role in one tap'), style: t.label.copyWith(color: c.textSecondary))),
        const SizedBox(height: AppSpacing.s8),
        FilterChipRow(
          children: [
            for (final e in roleLabels.entries)
              FilterPill(
                label: context.tr(e.value),
                selected: s?.role == e.key,
                onTap: s?.role == e.key
                    ? null
                    : () async {
                        Navigator.pop(context);
                        try {
                          await notifier.signInAsDemo(e.key);
                        } on ApiException catch (err) {
                          messenger.showSnackBar(SnackBar(content: Text('Could not sign in: ${err.message}')));
                        }
                      },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        ListRow(
          title: context.tr(s == null ? 'Sign in with a number…' : 'Switch account…'),
          icon: Icons.login,
          onTap: () => go('/sign-in'),
        ),
        ListRow(
          title: context.tr('Language'),
          icon: Icons.translate,
          chevron: false,
          // Under the title, so the label keeps its full width at large text sizes.
          chip: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s4),
            child: SizedBox(
              width: 200,
              child: SegmentedControl<String>(
                segments: const [('en', 'EN'), ('hi', 'हिं'), ('mr', 'मरा')],
                value: context.lang,
                onChanged: (l) => ref.read(langProvider.notifier).set(l),
              ),
            ),
          ),
        ),
        ListRow(
          title: context.tr('About this data'),
          caption: context.tr('Synthetic data, how flags work, credits'),
          icon: Icons.info_outline,
          divider: s != null,
          onTap: () => go('/about'),
        ),
        if (s != null)
          Pressable(
            onTap: () {
              Navigator.pop(context);
              notifier.signOut();
            },
            scale: false,
            semanticLabel: context.tr('Sign out'),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSpacing.listRow),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                child: Row(
                  children: [
                    SizedBox(width: 40, child: Icon(Icons.logout, color: c.error, size: 20)),
                    const SizedBox(width: AppSpacing.s16),
                    Text(context.tr('Sign out'), style: t.bodyStrong.copyWith(color: c.error)),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.s8),
      ],
    );
  }
}
