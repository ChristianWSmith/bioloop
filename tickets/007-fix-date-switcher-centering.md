# Ticket 7: Fix date switcher "Today" text not screen-centered

**Issue:** #2  
**Priority:** Low  
**Effort:** ~20 lines  
**Files:** `lib/features/logging/widgets/day_navigator.dart`, `lib/features/logging/combined_log_screen.dart`

## Context

The date label ("Today", "Yesterday", "Tomorrow", or a formatted date) is visually left of screen center in the app bar. This is because the `DayNavigator` widget (a `Row` of left chevron + text + right chevron) is centered as a whole, and the right-side action buttons (`menu_book`, `more_vert`) eat into the right side of the app bar.

The `AppBar` has `centerTitle: true`, which centers the **entire title widget** in the space available (accounting for `leading` width). The title widget is the full `DayNavigator` Row. The actions on the right overlay this space, but Flutter's `centerTitle` doesn't account for action widths — it centers in the total app bar width.

### Visual explanation

```
[  <  Today  >  ] [📖] [⋮]
^--centered--^
```

The brackets show what gets centered (the entire DayNavigator). But the action buttons sit to the right of this centered block, making the text appear offset.

### Fix

Restructure the AppBar so only the text is centered, and the chevrons are placed in the `leading` and `actions` slots:

1. `leading`: left chevron (only when DayNavigator would show it)
2. `title`: just the date `Text` widget
3. `actions`: right chevron + existing `menu_book` + `more_vert`

This lets `centerTitle: true` center just the text on screen.

## Acceptance criteria

- [ ] On "Today" → text is visually centered on screen
- [ ] On "Yesterday" / "Tomorrow" → text is centered
- [ ] On longer date strings ("Jan 15, 2026") → text is centered and doesn't overflow
- [ ] Left chevron navigates to previous day
- [ ] Right chevron navigates to next day
- [ ] `menu_book` button still opens recipe list
- [ ] `more_vert` menu still shows CSV options
- [ ] No layout regressions on narrow screens (small phones)
- [ ] No regressions on wide screens (tablets)

## Testing

### Manual testing
1. Open log screen → verify "Today" is screen-centered
2. Tap left chevron → "Yesterday" is centered
3. Tap right chevron → back to "Today"
4. Tap right chevron multiple times → check date strings like "May 17, 2026" are centered
5. Verify all action buttons still work (recipe list, CSV export)
6. Test on narrow screen width (use Flutter device preview or resize window)
7. Test on wide screen width

### Regression checks
- `DayNavigator` is only used in `CombinedLogScreen` (one consumer). No other screens affected.
- The date navigation logic is unchanged — only the layout/positioning changes.
- The `_formatDate()` method returns the same strings.
- IconButton callbacks are unchanged.

## Implementation

```dart
// lib/features/logging/combined_log_screen.dart
// Restructure AppBar:

appBar: AppBar(
  centerTitle: true,
  title: Text(
    _formatDateText(),  // extract date formatting to CombinedLogScreen
    style: Theme.of(context).textTheme.titleMedium,
  ),
  leading: IconButton(
    icon: const Icon(Icons.chevron_left),
    onPressed: () => _goToDate(_currentDate.subtract(const Duration(days: 1))),
  ),
  actions: [
    IconButton(
      icon: const Icon(Icons.chevron_right),
      onPressed: () => _goToDate(_currentDate.add(const Duration(days: 1))),
    ),
    IconButton(
      icon: const Icon(Icons.menu_book),
      tooltip: 'Log recipe',
      onPressed: _onLogRecipe,
    ),
    PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      // ... existing menu items ...
    ),
  ],
),
```

Alternatively, keep `DayNavigator` as a lightweight widget that returns just the formatted date text, or modify it to accept a build context for AppBar integration:

```dart
// Option: Simplify DayNavigator to a stateless text formatter
class DayNavigator {
  static String format(DateTime currentDate) {
    // existing _formatDate() logic
  }
}
```

Then use it in `CombinedLogScreen` as a simple string getter.
```
