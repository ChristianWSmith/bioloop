import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/bodyweight/bodyweight_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/goals/goals_screen.dart';
import 'features/logging/combined_log_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'providers/bodyweight_provider.dart';
import 'providers/data_trigger_provider.dart';
import 'providers/database_provider.dart';
import 'providers/food_log_provider.dart';
import 'providers/goals_provider.dart';
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
    ref.invalidate(bodyweightProvider);
    ref.invalidate(todaysFoodProvider);
    ref.invalidate(userGoalsProvider);
    ref.read(dataTriggerProvider.notifier).state++;
    setState(() => _onboardingCompleted = true);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(resetTriggerProvider, (_, _) {
      _checkOnboarding();
    });

    final goalsAsync = ref.watch(userGoalsProvider);
    final seedColor = goalsAsync.when(
      data: (goals) => goals?.accentColorSeed != null
          ? Color(goals!.accentColorSeed!)
          : null,
      loading: () => null,
      error: (_, _) => null,
    );

    return MaterialApp(
      title: 'BioLoop',
      themeMode: ThemeMode.system,
      theme: AppTheme.light(seedColor),
      darkTheme: AppTheme.dark(seedColor),
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
  int _currentIndex = 1;

  static const _screens = <Widget>[
    DashboardScreen(),
    CombinedLogScreen(),
    BodyweightScreen(),
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
            icon: Icon(Icons.track_changes),
            label: 'Goals',
          ),
        ],
      ),
    );
  }
}
