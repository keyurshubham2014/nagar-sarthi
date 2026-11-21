import 'package:go_router/go_router.dart';

import 'features/auth/sign_in_screen.dart';
import 'features/map/map_home_screen.dart';

/// Routes. The money map is home (REQ-F-016); later tasks add routes here.
final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const MapHomeScreen()),
    GoRoute(path: '/sign-in', builder: (context, state) => const SignInScreen()),
  ],
);
