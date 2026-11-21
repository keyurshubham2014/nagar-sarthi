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

final roadFlagsProvider = FutureProvider.family<List<dynamic>, String>(
  retry: _noRetry,
  (ref, id) => ref.watch(apiClientProvider).flags(road: id),
);

final wardFlagsProvider = FutureProvider.family<List<dynamic>, ({String ward, String type})>(
  retry: _noRetry,
  (ref, q) => ref.watch(apiClientProvider).flags(ward: q.ward, type: q.type),
);

final nextRupeeProvider = FutureProvider.family<Json, String>(
  retry: _noRetry,
  (ref, ward) => ref.watch(apiClientProvider).nextRupee(ward),
);

/// Ward whose next-rupee pins are on the map (null: none chosen yet).
class NextRupeeWard extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? ward) => state = ward;
}

final nextRupeeWardProvider = NotifierProvider<NextRupeeWard, String?>(NextRupeeWard.new);
