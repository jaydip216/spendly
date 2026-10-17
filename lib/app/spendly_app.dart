import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/providers.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/backup/backup_screen.dart';
import '../features/categories/category_management_screen.dart';
import '../features/home/home_screen.dart';
import '../features/manual_entry/manual_entry_screen.dart';
import '../features/merchant/merchant_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/sms_review_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/spends/spends_screen.dart';
import 'theme/spendly_theme.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/spends',
              builder: (context, state) => const SpendsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/insights',
              builder: (context, state) => const AnalyticsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/sms-review',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SmsReviewScreen(),
    ),
    GoRoute(
      path: '/manual-entry',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ManualEntryScreen(),
    ),
    GoRoute(
      path: '/backup',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BackupScreen(),
    ),
    GoRoute(
      path: '/categories',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CategoryManagementScreen(),
    ),
    GoRoute(
      path: '/merchant',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          MerchantScreen(merchant: state.extra as String? ?? ''),
    ),
  ],
);

class SpendlyApp extends ConsumerWidget {
  const SpendlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Spendly',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: buildSpendlyTheme(Brightness.light),
      darkTheme: buildSpendlyTheme(Brightness.dark),
      routerConfig: _router,
    );
  }
}
