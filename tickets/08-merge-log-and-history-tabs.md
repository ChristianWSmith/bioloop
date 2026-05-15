# Ticket 08 — Merge Log and History tabs

**Issues**: #15 (main), #3 (subsumed)  
**Phase**: 3  
**Dependencies**: Ticket 06 (edit sheet), Ticket 07 (search rework)  
**Estimate**: ~4-6 hours

---

## Context

The current app has 5 bottom-nav tabs: Dashboard, **Log** (today's entries),
Bodyweight, **History** (paginated all-time view), Goals. These two middle
tabs should merge into a single **"Log"** tab that shows food history one
day at a time with day navigation and a "Log new food" button.

This is the largest structural change in the project. It removes two screens
and introduces a new combined screen, a day-navigation widget, and a date-keyed
provider.

---

## Acceptance Criteria

### Navigation
1. Bottom nav has 4 destinations: Dashboard, Log, Bodyweight, Goals.
2. The Log tab defaults to today's date.
3. Left/right arrows on the Log screen navigate to prev/next day.
4. The date label shows "Today", "Yesterday", or a formatted date (Mon DD, YYYY)
   matching the current history formatting.

### Entry display
5. Entries are grouped by meal order: breakfast → lunch → dinner → snack.
6. Each entry shows: name, serving label (including quantity/unit), macros
   (cal/p/c/f), time, meal-type badge.
7. Empty day shows a friendly message ("No entries for this date").

### Entry interaction
8. Tap an entry → opens `EditEntrySheet` (quantity-only, per Ticket 06).
9. Swipe-to-delete or trash icon → confirmation dialog → removes entry.
10. Edit → invalidates the date's entries; delete → invalidates.
11. CSV export available in overflow menu (moved from current History screen).

### Food logging
12. "Log new food" button (FAB or pinned bottom button) → opens existing
    `FoodSearchDelegate` or recipe picker.
13. After logging, the current date's entries refresh.

### Data architecture
14. New `dateFoodProvider(DateTime)` — `FutureProvider.family` watching
    `resetTriggerProvider` + `dataTriggerProvider`, calling `getEntriesForDate()`.
15. Old `todaysFoodProvider` is removed or aliased to `dateFoodProvider(today)`.

---

## Implementation

### 8a. New date-keyed provider
**File**: `lib/providers/food_log_provider.dart` (or new `date_food_provider.dart`)

```dart
final dateFoodProvider = FutureProvider.family<List<FoodEntry>, DateTime>((ref, date) async {
  ref.watch(resetTriggerProvider);
  ref.watch(dataTriggerProvider);
  final logService = ref.read(foodLogProvider);
  final day = DateTime(date.year, date.month, date.day);
  return await logService.getEntriesForDate(day);
});
```

Can replace `todaysFoodProvider` with a simple alias:
```dart
final todaysFoodProvider = FutureProvider<List<FoodEntry>>((ref) async {
  final now = DateTime.now();
  return await ref.read(dateFoodProvider(DateTime(now.year, now.month, now.day)).future);
});
```

Or just remove `todaysFoodProvider` and update call sites. The combined
screen doesn't need it — it uses `dateFoodProvider(currentDate)`.

### 8b. Day navigator widget
**File**: `lib/features/logging/widgets/day_navigator.dart`

```dart
class DayNavigator extends StatelessWidget {
  final DateTime currentDate;
  final ValueChanged<DateTime> onDateChanged;

  const DayNavigator({
    super.key,
    required this.currentDate,
    required this.onDateChanged,
  });

  String _formatDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(currentDate).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    return '${_monthNames[currentDate.month - 1]} ${currentDate.day}, ${currentDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onDateChanged(currentDate.subtract(const Duration(days: 1))),
        ),
        Text(_formatDate(), style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onDateChanged(currentDate.add(const Duration(days: 1))),
        ),
      ],
    );
  }
}
```

### 8c. Combined Log screen
**File**: `lib/features/logging/combined_log_screen.dart`

```dart
class CombinedLogScreen extends ConsumerStatefulWidget {
  const CombinedLogScreen({super.key});

  @override
  ConsumerState<CombinedLogScreen> createState() => _CombinedLogScreenState();
}

class _CombinedLogScreenState extends ConsumerState<CombinedLogScreen> {
  late DateTime _currentDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentDate = DateTime(now.year, now.month, now.day);
  }

  void _goToDate(DateTime date) {
    setState(() => _currentDate = DateTime(date.year, date.month, date.day));
  }

  // ... build method with:
  //   - DayNavigator at top
  //   - Expanded ListView with entries grouped by meal type
  //   - Each entry: name, servingLabel, macros, time, meal badge, edit/delete actions
  //   - CSV export in overflow menu
  //   - "Log new food" FAB at bottom
}
```

### 8d. Update app shell
**File**: `lib/app.dart`

```dart
class _AppShellState extends State<_AppShellState> {
  int _currentIndex = 0;

  static const _screens = <Widget>[
    DashboardScreen(),
    CombinedLogScreen(),    // replaces LogFoodScreen
    BodyweightScreen(),
    GoalsScreen(),           // HistoryScreen removed
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Log'),
          NavigationDestination(icon: Icon(Icons.monitor_weight), label: 'Bodyweight'),
          NavigationDestination(icon: Icon(Icons.track_changes), label: 'Goals'),
        ],
      ),
    );
  }
}
```

### 8e. Remove old files
- `lib/features/logging/log_food_screen.dart` — delete (all functionality
  absorbed by combined screen + existing widgets)
- `lib/features/history/history_screen.dart` — delete

---

## Testing

### Widget tests
- New `test/features/logging/combined_log_screen_test.dart`:
  - Empty day shows "No entries for this date"
  - Day with entries shows them grouped by meal order
  - Tap left/right arrows changes the displayed day
  - "Today" label for current date, "Yesterday" for previous
  - Tapping entry opens edit sheet
  - Swipe-to-delete shows confirmation
  - FAB is visible and opens search
  - "Log new food" flow works end-to-end

### Regression tests
- Update `test/widget_test.dart` — verify 4-tab nav structure
- Remove or repurpose `test/features/history/history_screen_test.dart` tests
- Remove or repurpose `test/features/logging/log_food_screen_test.dart` tests
  (the food-logging widget tests for manual form, barcode etc. stay)

### Manual tests
- Open app → verify 4 tabs, Log is 2nd
- Tap Log → shows today's entries grouped by meal
- Tap ← arrow → shows yesterday's entries
- Tap → arrow → back to today
- Navigate to a day with no entries → "No entries for this date"
- Tap FAB → search opens (My Foods mode per Ticket 07)
- Select food → save → entry appears
- Tap entry → edit sheet opens with read-only macros
- Change quantity → save → entry updated
- Swipe entry → delete confirmation → entry removed
- Check CSV export in overflow menu
- Re-open app → today's entries still there

---

## Files Changed / Created

| File | Change |
|------|--------|
| `lib/features/logging/combined_log_screen.dart` | **NEW** — combined screen |
| `lib/features/logging/widgets/day_navigator.dart` | **NEW** — day navigation widget |
| `lib/providers/food_log_provider.dart` | Add `dateFoodProvider` family, remove or alias `todaysFoodProvider` |
| `lib/app.dart` | 4-tab nav, reference `CombinedLogScreen` |
| `lib/features/logging/log_food_screen.dart` | DELETE |
| `lib/features/history/history_screen.dart` | DELETE |
| Various providers | Remove imports of deleted files |
| `test/features/logging/combined_log_screen_test.dart` | **NEW** |
| `test/features/history/history_screen_test.dart` | DELETE or gut |
| `test/features/logging/log_food_screen_test.dart` | DELETE or gut |
| `test/widget_test.dart` | Update nav structure test |

---

## Open Questions

- Should we keep `todaysFoodProvider` as an alias for backward compat, or
  update all its consumers? The only consumer outside the old `LogFoodScreen`
  is `app.dart:_onOnboardingComplete()`. Update that one call site and remove
  the provider.
- Should the CSV export include bodyweight as well, or just food entries?
  Current behavior is just food entries — keep as-is.
- Day navigator "Tomorrow" label — is it useful? It matches the logic and
  could appear if the user navigates to a future date (no entries there).
  Harmless to include.
