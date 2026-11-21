import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_router.dart';
import '../../core/api/api_client.dart';
import '../../core/flag_strings.dart';
import '../../core/prefs.dart';
import '../../core/widgets/ui.dart';
import '../ward/ward_picker.dart';
import '../../core/widgets/claude_draft_sheet.dart';
import '../map/map_data.dart';
import '../officer/officer_data.dart';
import '../officer/panel.dart';

export 'complaint_pages.dart';
export 'report_flow.dart';

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

void pushComplaint(BuildContext context, String id) => appRouter.push(Uri(path: '/complaint', queryParameters: {'id': id}).toString());

/// Complaint ids this device tracked or filed, newest first (chips on Track a complaint).
List<String> recentComplaints(WidgetRef ref) => ref.read(prefsProvider).getStringList('recent_complaints') ?? const [];
void rememberComplaint(WidgetRef ref, String id) => ref
    .read(prefsProvider)
    .setStringList('recent_complaints', [id, ...recentComplaints(ref).where((x) => x != id)].take(5).toList());

String complaintDay(dynamic s) => s == null ? '—' : '$s'.substring(0, '$s'.length >= 10 ? 10 : '$s'.length);
String plainName(dynamic name) => '${name ?? '—'}'.replaceAll(' (synthetic)', '');

// ------------------------------------------------------------ ask the ward

class AskWardPage extends ConsumerStatefulWidget {
  const AskWardPage({super.key, this.ward});
  final String? ward;
  @override
  ConsumerState<AskWardPage> createState() => _AskWardPageState();
}

class _AskWardPageState extends ConsumerState<AskWardPage> {
  late String? _ward = widget.ward;
  @override
  Widget build(BuildContext context) {
    final ward = _ward;
    final name = ward == null ? null : ref.watch(mapDataProvider).value?.wardByCode[ward]?.name;
    return ListView(
      primary: true,
      padding: const EdgeInsets.only(bottom: AppSpacing.s32),
      children: [
        const DetailTitle(),
        const SizedBox(height: AppSpacing.s8),
        Gutter(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: WardPillButton(
              label: ward == null ? context.tr('Choose your ward') : '${context.tr('Ward {w}', {'w': ward})}${name == null ? '' : ' · $name'}',
              onTap: () async {
                final code = await chooseWard(context, current: ward);
                if (code != null && mounted) setState(() => _ward = code);
              },
            ),
          ),
        ),
        Gutter(child: SectionTitle(context.tr('What would you like to ask about?'))),
        if (ward == null) Gutter(child: Text(context.tr('Pick your ward first.'), style: context.type.caption)),
        for (final (i, e) in questionTopics.entries.indexed)
          ListRow(
            icon: Icons.help_outline,
            title: context.tr(e.value),
            divider: i < questionTopics.length - 1,
            onTap: ward == null
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
          ),
      ],
    );
  }
}
