import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_router.dart';
import 'core/auth/session.dart';
import 'core/i18n.dart';
import 'core/prefs.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Session, chosen ward and language are read before the first frame.
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const NagarSarthiApp()));
}

class NagarSarthiApp extends StatelessWidget {
  const NagarSarthiApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Nagar Sarthi',
    debugShowCheckedModeBanner: false,
    scaffoldMessengerKey: rootMessengerKey,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    routerConfig: appRouter,
    builder: (context, child) => Consumer(builder: (_, ref, _) => LangScope(lang: ref.watch(langProvider), child: child!)),
  );
}
