import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_router.dart';
import '../../core/api/api_client.dart';
import '../../core/flag_strings.dart';
import '../../core/prefs.dart';
import '../../core/theme/tokens.dart';
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

/// One step of the vertical timeline: dot, connector line, title and detail.
class TimelineStep extends StatelessWidget {
  const TimelineStep({super.key, required this.icon, required this.color, required this.title, required this.sub, this.last = false, this.action});
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final bool last;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Icon(icon, color: color, size: 22),
              if (!last) Expanded(child: Container(width: 2, color: color.withValues(alpha: 0.4))),
            ],
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleSmall?.copyWith(color: color)),
                  Text(sub, style: t.bodySmall),
                  ?action,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ ask the ward

/// Ward chooser from the money map's ward list.
class WardPicker extends ConsumerWidget {
  const WardPicker({super.key, required this.selected, required this.onSelected});
  final String? selected;
  final ValueChanged<String?> onSelected;
  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(mapDataProvider)) {
    AsyncData(:final value) => DropdownMenu<String>(
      label: Text(context.tr('Ward (type to search)')),
      expandedInsets: EdgeInsets.zero,
      enableFilter: true,
      requestFocusOnTap: true,
      menuHeight: 320,
      initialSelection: selected,
      dropdownMenuEntries: [for (final w in value.wards) DropdownMenuEntry(value: w.code, label: 'Ward ${w.code} · ${w.name}')],
      onSelected: onSelected,
    ),
    AsyncError(:final error) => ListTile(
      title: Text('Could not load wards. $error'),
      trailing: TextButton(onPressed: () => ref.invalidate(mapDataProvider), child: const Text('Retry')),
    ),
    _ => const LinearProgressIndicator(),
  };
}

class AskWardPage extends StatefulWidget {
  const AskWardPage({super.key, this.ward});
  final String? ward;
  @override
  State<AskWardPage> createState() => _AskWardPageState();
}

class _AskWardPageState extends State<AskWardPage> {
  late String? _ward = widget.ward;
  @override
  Widget build(BuildContext context) {
    final ward = _ward;
    return PanelList(
      children: [
        WardPicker(selected: ward, onSelected: (v) => setState(() => _ward = v)),
        SectionTitle(context.tr('What would you like to ask about?')),
        if (ward == null) Text(context.tr('Pick your ward first.')),
        for (final e in questionTopics.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: OutlinedButton(
              onPressed: ward == null
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
              child: Text(context.tr(e.value)),
            ),
          ),
      ],
    );
  }
}
