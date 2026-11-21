import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/flag_strings.dart';
import '../../core/format.dart';
import '../../core/prefs.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/saarthee.dart';
import '../map/map_data.dart';
import '../officer/officer_panels.dart';
import '../officer/panel.dart';
import '../ward/ward_picker.dart';

final _contractorsProvider = FutureProvider<List<dynamic>>(retry: (_, _) => null, (ref) => ref.watch(apiClientProvider).contractors());

/// Audit tab (ward officer and corporator): every flag for the chosen ward or all Mumbai.
class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ward = ref.watch(chosenWardProvider);
    final name = ref.watch(mapDataProvider).value?.wardByCode[ward]?.name;
    return Scaffold(
      appBar: SaartheeAppBar(
        title: 'Audit',
        subtitle: 'Work orders that need review',
        showBack: false,
        actions: [
          TextButton.icon(
            onPressed: () => pickWard(context, ref),
            icon: const Icon(Icons.location_on_outlined),
            label: Text('Ward $ward'),
          ),
        ],
      ),
      // A new chosen ward starts a fresh list.
      body: AuditList(key: ValueKey(ward), ward: ward, wardName: name),
    );
  }
}

/// Flag rows with filter chips, contractor filter, search, totals and paging.
/// Also the body of "one flag type in a ward" pages ([type] preset).
class AuditList extends ConsumerStatefulWidget {
  const AuditList({super.key, required this.ward, this.wardName, this.type, this.allowAllMumbai = true});
  final String ward;
  final String? wardName;
  final String? type;
  final bool allowAllMumbai;
  @override
  ConsumerState<AuditList> createState() => _AuditListState();
}

class _AuditListState extends ConsumerState<AuditList> {
  static const int _page = 30;
  late bool _allMumbai = false;
  late String? _type = widget.type;
  String? _contractor;
  final _search = TextEditingController();
  Timer? _debounce;

  List<dynamic> _items = const [];
  int _total = 0;
  num _totalInr = 0;
  bool _loading = false;
  String? _error;
  int _request = 0; // newer requests win

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final id = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _items = const [];
    });
    try {
      final r = await ref.read(apiClientProvider).flags(
        ward: _allMumbai ? null : widget.ward,
        type: _type,
        contractor: _contractor,
        q: _search.text.trim().isEmpty ? null : _search.text.trim(),
        offset: reset ? 0 : _items.length,
        limit: _page,
      );
      if (!mounted || id != _request) return;
      setState(() {
        _items = [..._items, ...(r['items'] as List)];
        _total = r['total'] as int? ?? 0;
        _totalInr = r['total_inr'] as num? ?? 0;
      });
    } on ApiException catch (e) {
      if (mounted && id == _request) setState(() => _error = e.message);
    } finally {
      if (mounted && id == _request) setState(() => _loading = false);
    }
  }

  void _set(VoidCallback f) {
    setState(f);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final contractors = ref.watch(_contractorsProvider).value ?? const [];
    final header = <Widget>[
      if (widget.allowAllMumbai)
        Wrap(
          spacing: AppSpacing.s8,
          children: [
            ChoiceChip(
              label: Text('Ward ${widget.ward}${widget.wardName == null ? '' : ' · ${widget.wardName!.split(',').first}'}'),
              selected: !_allMumbai,
              onSelected: (_) => _set(() => _allMumbai = false),
            ),
            ChoiceChip(label: const Text('All Mumbai'), selected: _allMumbai, onSelected: (_) => _set(() => _allMumbai = true)),
          ],
        ),
      const SizedBox(height: AppSpacing.s8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final k in [null, ...flagOrder])
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.s8),
                child: ChoiceChip(
                  avatar: k == null ? null : CircleAvatar(backgroundColor: flagColor(k), radius: 5),
                  label: Text(k == null ? 'All flags' : flagLabel(k)),
                  selected: _type == k,
                  onSelected: (_) => _set(() => _type = k),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.s12),
      TextField(
        controller: _search,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: 'Work order id or road name',
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close),
                  onPressed: () => _set(_search.clear),
                ),
        ),
        onChanged: (_) {
          setState(() {});
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 350), () => _load(reset: true));
        },
        onSubmitted: (_) => _load(reset: true),
      ),
      const SizedBox(height: AppSpacing.s8),
      DropdownMenu<String?>(
        key: ValueKey('contractors-${contractors.length}'),
        label: const Text('Contractor'),
        expandedInsets: EdgeInsets.zero,
        initialSelection: _contractor,
        leadingIcon: const Icon(Icons.engineering_outlined),
        dropdownMenuEntries: [
          const DropdownMenuEntry<String?>(value: null, label: 'All contractors'),
          for (final k in contractors) DropdownMenuEntry<String?>(value: k['id'] as String, label: '${k['name']}'),
        ],
        onSelected: (v) => _set(() => _contractor = v),
      ),
      const SizedBox(height: AppSpacing.s16),
      Text.rich(
        TextSpan(
          children: [
            TextSpan(text: _total == 1 ? '1 flag' : '$_total flags', style: t.titleMedium),
            if (_type != 'sla_missed')
              TextSpan(text: ' · ${formatInr(_totalInr)} ${_type == 'dlp_paid' ? 'to be claimed and verified' : 'to review'}', style: t.bodyMedium),
          ],
        ),
      ),
      Text(
        _type == 'sla_missed' ? kSlaNoMoney : 'Biggest amounts first. Each work order counted once in the total.',
        style: t.bodySmall,
      ),
      const SizedBox(height: AppSpacing.s8),
    ];

    final footer = <Widget>[
      if (_error != null)
        Card(
          color: c.errorTint,
          child: ListTile(
            leading: Icon(Icons.error_outline, color: c.error),
            title: Text('Could not load flags. $_error'),
            trailing: TextButton(onPressed: () => _load(reset: _items.isEmpty), child: const Text('Retry')),
          ),
        )
      else if (_loading)
        const Padding(padding: EdgeInsets.all(AppSpacing.s16), child: Center(child: CircularProgressIndicator()))
      else if (_items.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s32),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 40, color: c.textSecondary),
              const SizedBox(height: AppSpacing.s8),
              const Text('No work orders match these filters.', textAlign: TextAlign.center),
            ],
          ),
        )
      else if (_items.length < _total)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
          child: OutlinedButton(
            onPressed: () => _load(reset: false),
            child: Text('Load more (${_items.length} of $_total shown)'),
          ),
        ),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        final side = math.max(AppSpacing.gutter, (box.maxWidth - AppSpacing.maxContent) / 2 + AppSpacing.gutter);
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(side, AppSpacing.s16, side, AppSpacing.s32),
          itemCount: header.length + _items.length + footer.length,
          itemBuilder: (context, i) {
            if (i < header.length) return header[i];
            i -= header.length;
            if (i < _items.length) return FlagRow(_items[i] as Map<String, dynamic>);
            return footer[i - _items.length];
          },
        );
      },
    );
  }
}

/// One flag: work order, road, contractor, amount and the one-line reason. Opens the road page on that work order.
class FlagRow extends StatelessWidget {
  const FlagRow(this.f, {super.key});
  final Map<String, dynamic> f;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final type = f['type'] as String;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius, side: BorderSide(color: c.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openRoad(f['road_id'] as String, wo: f['work_order_id'] as String),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${f['work_order_id']} · ${f['road_name'] ?? f['road_id']}', style: t.titleMedium)),
                    const SizedBox(width: AppSpacing.s8),
                    Text(formatInr(f['cost_inr'] as num? ?? 0), style: t.titleMedium),
                  ],
                ),
                Text('${f['contractor_name']} · Ward ${f['ward_code']}', style: t.bodySmall),
                const SizedBox(height: AppSpacing.s8),
                Tag(flagLabel(type), bg: flagColor(type).withValues(alpha: 0.12), fg: flagColor(type)),
                const SizedBox(height: AppSpacing.s4),
                Text(flagReason(f), style: t.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
