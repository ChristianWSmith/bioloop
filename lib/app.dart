import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/bodyweight/bodyweight_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/goals/goals_screen.dart';
import 'features/history/history_screen.dart';
import 'features/logging/log_food_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'providers/database_provider.dart';
import 'providers/reset_provider.dart';
import 'theme/theme.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  bool? _onboardingCompleted;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    try {
      final db = ref.read(databaseProvider);
      final goals = await db.getGoals();
      if (mounted) {
        setState(() {
          _onboardingCompleted = goals?.onboardingCompleted == 1;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _onboardingCompleted = false);
      }
    }
  }

  void _onOnboardingComplete() {
    setState(() => _onboardingCompleted = true);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(resetTriggerProvider, (_, _) {
      _checkOnboarding();
    });

    return MaterialApp(
      title: 'bioloop',
      themeMode: ThemeMode.system,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_onboardingCompleted == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_onboardingCompleted!) {
      return OnboardingScreen(onComplete: _onOnboardingComplete);
    }
    return const _AppShell();
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _currentIndex = 0;

  static const _screens = <Widget>[
    DashboardScreen(),
    LogFoodScreen(),
    BodyweightScreen(),
    HistoryScreen(),
    GoalsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            label: 'Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_weight),
            label: 'Bodyweight',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.track_changes),
            label: 'Goals',
          ),
        ],
      ),
    );
  }
}
