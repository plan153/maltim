import 'package:go_router/go_router.dart';
import 'package:pronunciation_engine/pronunciation_engine.dart';

import '../screens/admin_screen.dart';
import '../screens/home_screen.dart';
import '../screens/practice_screen.dart';
import '../screens/progress_screen.dart';

/// 앱 라우팅 정의.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
        path: '/practice',
        builder: (context, state) => PracticeScreen(
              initialLevel: state.extra is PracticeLevel
                  ? state.extra as PracticeLevel
                  : null,
            )),
    GoRoute(
        path: '/progress', builder: (context, state) => const ProgressScreen()),
    GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
  ],
);
