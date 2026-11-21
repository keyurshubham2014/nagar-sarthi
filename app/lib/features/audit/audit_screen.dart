import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/flag_strings.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/prefs.dart';
import '../../core/widgets/ui.dart';
import '../map/map_data.dart';
import '../officer/officer_panels.dart';
import '../ward/ward_picker.dart';

final _contractorsProvider = FutureProvider<List<dynamic>>(retry: (_, _) => null, (ref) => ref.watch(apiClientProvider).contractors());

/// Audit tab (ward officer and corporator): every flag for the chosen ward or all Mumbai.
class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ward = ref.watch(chosenWardProvider);
    final name = ref.watch(mapDataProvider).value?.wardByCode[ward]?.name;
    // A new chosen ward starts a fresh list.
    return AuditList(key: ValueKey(ward), ward: ward, wardName: name, title: context.tr('Audit'));
  }
}

/// Flag rows with filter chips, contractor filter, search, totals and paging.
/// Also the body of "one flag type in a ward" pages ([type] preset).
/// With a [title] it is a root tab page (large title, change-ward button).
class AuditList extends ConsumerStatefulWidget {
  const AuditList({super.key, required this.ward, this.wardName, this.type, this.allowAllMumbai = true, this.title});
  final String ward;
  final String? wardName;
  final String? type;
  final bool allowAllMumbai;
  final String? title;
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
  bool _loaded = false;
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
        _loaded = true;
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

  String get _caption {
    final n = _total == 1 ? '1 flag' : '$_total flags';
    if (_type == 'sla_missed') return n;
    return '$n · ${formatInr(_totalInr)} ${_type == 'dlp_paid' ? 'to be claimed and verified' : 'to review'}';
  }

  bool get _filtered => _contractor != null || _search.text.trim().isNotEmpty || _type != widget.type;

  String get _emptyText {
    final q = _search.text.trim();
    if (q.isNotEmpty) return 'No work order or road matches "$q".';
    final where = _allMumbai ? 'in Mumbai' : 'in Ward ${widget.ward}';
    final who = _contractor == null ? '' : ' for this contractor';
    if (_type != null) return 'No work orders $where$who are flagged "${flagShortLabels[_type] ?? _type}".';
    return 'No work orders $where$who need review.';
  }

  Future<void> _pickContractor() async {
    final contractors = ref.read(_contractorsProvider).value;
    final picked = await showAppSheet<String>(
      context,
      title: 'Contractor',
      builder: (sheet) => contractors == null
          ? Skeleton.rows(count: 4)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListRow(
                  title: 'All contractors',
                  chevron: false,
                  trailing: _contractor == null ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(sheet, ''),
                ),
                for (final k in contractors)
                  ListRow(
                    title: '${k['name']}',
                    chevron: false,
                    trailing: _contractor == k['id'] ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(sheet, k['id'] as String),
                  ),
              ],
            ),
    );
    if (picked == null || !mounted) return;
    _set(() => _contractor = picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final contractors = ref.watch(_contractorsProvider).value ?? const [];
    final contractorName = contractors.cast<Map?>().firstWhere((k) => k?['id'] == _contractor, orElse: () => null)?['name'];
    final root = widget.title != null;

    // One row per work order: its first (largest) flag, other flags as "+n".
    final byWo = <Object?, List<Map<String, dynamic>>>{};
    for (final f in _items) {
      (byWo[f['work_order_id']] ??= []).add(f as Map<String, dynamic>);
    }
    final rows = byWo.values.toList();
    final more = _items.length < _total;

    Widget footer() {
      if (_error != null) {
        return ErrorState(message: 'Could not load flags. $_error', onRetry: () => _load(reset: _items.isEmpty));
      }
      if (_loading || (more && _items.isNotEmpty)) {
        // Reached the end: fetch the next page.
        if (!_loading) WidgetsBinding.instance.addPostFrameCallback((_) => mounted && !_loading ? _load(reset: false) : null);
        return Skeleton.rows(count: _items.isEmpty ? 6 : 3);
      }
      if (_items.isEmpty) {
        return EmptyState(
          message: _emptyText,
          pictogram: PictogramKind.audit,
          actionLabel: _filtered ? 'Clear filters' : null,
          onAction: () => _set(() {
            _contractor = null;
            _type = widget.type;
            _search.clear();
          }),
        );
      }
      return const SizedBox(height: AppSpacing.s16);
    }

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.gutter, root ? 0 : AppSpacing.s16, AppSpacing.gutter, AppSpacing.s16),
          child: AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.standard),
            layoutBuilder: (cur, prev) => Stack(alignment: AlignmentDirectional.topStart, children: [...prev, ?cur]),
            child: Text(
              _loaded ? _caption : ' ',
              key: ValueKey(_loaded ? _caption : ''),
              style: t.caption.copyWith(fontSize: 15, height: 22 / 15),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.allowAllMumbai) ...[
              Gutter(
                child: SegmentedControl<bool>(
                  segments: [(false, 'Ward ${widget.ward}'), (true, 'All Mumbai')],
                  value: _allMumbai,
                  onChanged: (v) => _set(() => _allMumbai = v),
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
            ],
            FilterChipRow(
              children: [
                FilterPill(
                  label: contractorName == null ? 'Contractor' : '$contractorName',
                  icon: Icons.engineering_outlined,
                  selected: _contractor != null,
                  onTap: _pickContractor,
                ),
                for (final k in [null, ...flagOrder])
                  FilterPill(
                    label: k == null ? 'All' : flagShortLabels[k] ?? k,
                    selected: _type == k,
                    onTap: () => _set(() => _type = k),
                  ),
              ],
            ),
          ],
        ),
      ),
      SliverPersistentHeader(
        pinned: true,
        delegate: _PinnedSearch(
          ColoredBox(
            color: c.background,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.s8),
              child: SearchField(
                controller: _search,
                hint: 'Work order or road',
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), () => _load(reset: true));
                },
                onSubmitted: (_) => _load(reset: true),
              ),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.s4, AppSpacing.gutter, AppSpacing.s4),
          child: Text(
            _type == 'sla_missed' ? kSlaNoMoney : 'Biggest amounts first. Each work order counted once in the total.',
            style: t.caption,
          ),
        ),
      ),
      SliverList.builder(
        itemCount: rows.length + 1,
        itemBuilder: (context, i) {
          if (i == rows.length) return footer();
          final r = rows[i];
          return StaggeredEntrance(
            key: ValueKey(r.first['work_order_id']),
            index: i,
            child: FlagRow(r.first, more: r.length - 1, showWard: _allMumbai, divider: i < rows.length - 1 || more),
          );
        },
      ),
    ];

    if (root) {
      return LargeTitleScaffold(
        title: widget.title!,
        actions: [RoundIconButton(icon: Icons.location_on_outlined, tooltip: 'Change ward (Ward ${widget.ward})', onPressed: () => pickWard(context, ref))],
        onRefresh: () => _load(reset: true),
        slivers: slivers,
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContent),
        child: CustomScrollView(
          primary: true,
          slivers: [...slivers, const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.s32))],
        ),
      ),
    );
  }
}

class _PinnedSearch extends SliverPersistentHeaderDelegate {
  _PinnedSearch(this.child);
  final Widget child;
  static const double _height = AppSpacing.searchHeight + AppSpacing.s16;
  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox.expand(child: child);
  @override
  bool shouldRebuild(_PinnedSearch old) => true;
}

/// One flagged work order: road, id and contractor, one status chip (other flags as "+n"),
/// amount and the one-line reason. Opens the road page on that work order.
class FlagRow extends StatelessWidget {
  const FlagRow(this.f, {super.key, this.more = 0, this.showWard = true, this.divider = true});
  final Map<String, dynamic> f;

  /// Other flags on the same work order.
  final int more;
  final bool showWard;
  final bool divider;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final type = f['type'] as String;
    return ListRow(
      title: '${f['road_name'] ?? f['road_id']}',
      caption: '${f['work_order_id']} · ${f['contractor_name']}${showWard ? ' · Ward ${f['ward_code']}' : ''}',
      chip: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusChip(flagShortLabels[type] ?? type, tone: flagTone(type), more: more),
          const SizedBox(height: AppSpacing.s4),
          Text(flagReason(f), style: t.caption.copyWith(color: c.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
      amount: formatInr(f['cost_inr'] as num? ?? 0),
      divider: divider,
      onTap: () => openRoad(f['road_id'] as String, wo: f['work_order_id'] as String),
    );
  }
}
