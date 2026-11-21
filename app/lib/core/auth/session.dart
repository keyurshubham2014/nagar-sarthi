import 'dart:convert';

import 'package:flutter/material.dart';
import '../i18n.dart';
import '../prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../api/api_client.dart';

/// Signed-in user. Saved in shared preferences, so it survives an app restart; a 401 clears it.
typedef Session = ({String token, String role, String phone, String? ward});

const Map<String, String> roleLabels = {'citizen': 'Citizen', 'corporator': 'Corporator', 'officer': 'Ward officer'};

/// For snackbars shown outside any screen's context (session expired).
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

class SessionNotifier extends Notifier<Session?> {
  @override
  Session? build() {
    final raw = ref.read(prefsProvider).getString('session');
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return (token: m['token'] as String, role: m['role'] as String, phone: m['phone'] as String, ward: m['ward'] as String?);
    } catch (_) {
      return null; // unreadable: treat as signed out
    }
  }

  void _save(Session? s) {
    state = s;
    final prefs = ref.read(prefsProvider);
    if (s == null) {
      prefs.remove('session');
    } else {
      prefs.setString('session', jsonEncode({'token': s.token, 'role': s.role, 'phone': s.phone, 'ward': s.ward}));
    }
  }

  Future<Session> signIn(String phone, String code) async {
    final r = await ref.read(apiClientProvider).login(phone, code);
    final s = (token: r['token'] as String, role: r['role'] as String, phone: r['phone'] as String, ward: r['ward_code'] as String?);
    _save(s);
    // Staff work on their own ward: make it the chosen ward.
    if (s.ward != null && s.role != 'citizen') ref.read(chosenWardProvider.notifier).set(s.ward!);
    return s;
  }

  /// Demo shortcut: the code comes from the server's config, never from the app.
  Future<Session> signInAsDemo(String role) async {
    final demo = await ref.read(apiClientProvider).demoLogin();
    return signIn((demo['users'] as Map)[role] as String, demo['code'] as String);
  }

  void signOut() => _save(null);

  /// The server rejected the token: clear it and offer sign-in.
  void expired() {
    if (state == null) return;
    _save(null);
    rootMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(translate('Your session has ended. Sign in again to continue.', ref.read(langProvider))),
        action: SnackBarAction(label: translate('Sign in', ref.read(langProvider)), onPressed: () => appRouter.push('/sign-in')),
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
      content: Text(c.tr(why)),
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
