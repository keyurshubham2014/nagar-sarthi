import 'package:flutter/material.dart';
import '../i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../api/api_client.dart';

/// Signed-in user. Held in memory only: survives navigation, not an app restart.
typedef Session = ({String token, String role, String phone, String? ward});

const Map<String, String> roleLabels = {'citizen': 'Citizen', 'corporator': 'Corporator', 'officer': 'Ward officer'};

/// For snackbars shown outside any screen's context (session expired).
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

class SessionNotifier extends Notifier<Session?> {
  @override
  Session? build() => null;

  Future<Session> signIn(String phone, String code) async {
    final r = await ref.read(apiClientProvider).login(phone, code);
    final s = (token: r['token'] as String, role: r['role'] as String, phone: r['phone'] as String, ward: r['ward_code'] as String?);
    state = s;
    return s;
  }

  /// Demo shortcut: the code comes from the server's config, never from the app.
  Future<Session> signInAsDemo(String role) async {
    final demo = await ref.read(apiClientProvider).demoLogin();
    return signIn((demo['users'] as Map)[role] as String, demo['code'] as String);
  }

  void signOut() => state = null;

  /// The server rejected the token: clear it and offer sign-in.
  void expired() {
    if (state == null) return;
    state = null;
    rootMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Text('Your session has ended. Sign in again to continue.'),
        action: SnackBarAction(label: 'Sign in', onPressed: () => appRouter.push('/sign-in')),
      ),
    );
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);

/// True when signed in with one of [roles] (any role when null). Otherwise explains [why]
/// and offers sign-in; returns true if the user then signs in with a fitting role.
Future<bool> ensureRole(BuildContext context, {Set<String>? roles, required String why}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  bool ok() {
    final r = container.read(sessionProvider)?.role;
    return r != null && (roles == null || roles.contains(r));
  }

  if (ok()) return true;
  final signedIn = container.read(sessionProvider) != null;
  final go = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.lock_outline),
      title: Text(c.tr(signedIn ? 'Not available for your role' : 'Please sign in')),
      content: Text(why),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.tr('Not now'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(c.tr(signedIn ? 'Switch account' : 'Sign in'))),
      ],
    ),
  );
  if (go != true || !context.mounted) return false;
  await context.push('/sign-in');
  return ok();
}
