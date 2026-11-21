import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_router.dart';
import 'core/auth/session.dart';
import 'core/i18n.dart';
import 'core/prefs.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/scroll_behavior.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Session, chosen ward and language are read before the first frame.
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const NagarSarthiApp()));
}

class NagarSarthiApp extends StatelessWidget {
  const NagarSarthiApp({super.key});

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (_, ref, _) {
      final lang = ref.watch(langProvider);
      // Devanagari text gets no negative tracking and a little more line height.
      final devanagari = AppTheme.isDevanagari(lang);
      return MaterialApp.router(
        title: 'Nagar Sarthi',
        debugShowCheckedModeBanner: false,
        scrollBehavior: const AppScrollBehavior(),
        scaffoldMessengerKey: rootMessengerKey,
        theme: AppTheme.light(devanagari: devanagari),
        darkTheme: AppTheme.dark(devanagari: devanagari),
        routerConfig: appRouter,
        builder: (context, child) => LangScope(lang: lang, child: child!),
      );
    },
  );
}
