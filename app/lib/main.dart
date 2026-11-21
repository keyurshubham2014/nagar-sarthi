import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'core/auth/session.dart';
import 'core/theme/app_theme.dart';

void main() => runApp(const ProviderScope(child: NagarSarthiApp()));

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
  );
}
