import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

// No auto-retry: failures show the panel's error state with its Retry button at once.
Duration? _noRetry(int _, Object _) => null;

typedef Json = Map<String, dynamic>;

final wardDetailProvider = FutureProvider.family<Json, String>(
  retry: _noRetry,
  (ref, code) => ref.watch(apiClientProvider).ward(code),
);

final roadDetailProvider = FutureProvider.family<Json, String>(
  retry: _noRetry,
  (ref, id) => ref.watch(apiClientProvider).road(id),
);

// A road has far fewer than 100 flag rows, so one page holds them all.
final roadFlagsProvider = FutureProvider.family<List<dynamic>, String>(
  retry: _noRetry,
  (ref, id) async => (await ref.watch(apiClientProvider).flags(road: id, limit: 100))['items'] as List,
);

/// Money flags only (no timing-only sla_missed), biggest first: Home's "Needs your attention".
final topFlagsProvider = FutureProvider.family<List<dynamic>, String>(
  retry: _noRetry,
  (ref, ward) async =>
      (await ref.watch(apiClientProvider).flags(ward: ward, type: 'dlp_paid,fix_failed,over_rate,double_billing', limit: 5))['items']
          as List,
);

final nextRupeeProvider = FutureProvider.family<Json, String>(
  retry: _noRetry,
  (ref, ward) => ref.watch(apiClientProvider).nextRupee(ward),
);

/// Ward whose next-rupee pins are on the map (null: the ward selected on the map, else the chosen ward).
class NextRupeeWard extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? ward) => state = ward;
}

final nextRupeeWardProvider = NotifierProvider<NextRupeeWard, String?>(NextRupeeWard.new);
