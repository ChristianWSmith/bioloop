# TICKET-004: Tighten date-navigation arrows around date text

**Priority:** Low (visual polish)
**File:** `lib/features/logging/combined_log_screen.dart`
**Estimate:** ~20min

---

## Context

The log screen's `AppBar` currently places the date-chevron buttons at the far left and right:
- `leading`: `IconButton(chevron_left)` — pinned to far left edge
- `title`: `Text(date)` — centered via `centerTitle: true`
- `actions[0]`: `IconButton(chevron_right)` — starts the actions list, right-aligned

This leaves a wide gap between the date text and the chevron buttons, especially on larger screens. The user wants the chevrons to be directly adjacent to the date text (tight left/right), while keeping the date text screen-centered and the remaining actions (recipe-log, CSV menu) on the far right.

---

## Acceptance criteria

1. **Date text stays screen-centered** — the "Today"/"Yesterday"/"Mar 15, 2026" text is horizontally centered in the AppBar.
2. **Chevrons are tight to the date text** — the left chevron is directly to the left of the date, the right chevron directly to the right, with no extra spacing beyond standard `IconButton` padding.
3. **Other actions remain on the far right** — the recipe-log (`menu_book`) icon and CSV menu (`more_vert`) stay on the right edge of the AppBar.
4. **No functional regression** — tapping left/right chevrons changes the date correctly, "Today"/"Yesterday"/formatted dates display correctly.
5. **DayNavigator.format()** is unchanged.

---

## Implementation plan

Restructure the AppBar so both chevrons live inside the `title` widget as a tightly-packed `Row`:

```dart
AppBar(
  title: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: const Icon(Icons.chevron_left),
        onPressed: () => _goToDate(_currentDate.subtract(const Duration(days: 1))),
      ),
      Text(
        _formatDateText(),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      IconButton(
        icon: const Icon(Icons.chevron_right),
        onPressed: () => _goToDate(_currentDate.add(const Duration(days: 1))),
      ),
    ],
  ),
  centerTitle: true,
  // Remove leading entirely — omit the property or set to const SizedBox.shrink()
  // Remove the two chevrons from actions — keep only menu_book and PopupMenuButton
  actions: [
    IconButton(
      icon: const Icon(Icons.menu_book),
      tooltip: 'Log recipe',
      onPressed: _onLogRecipe,
    ),
    PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        if (value == 'share_food') {
          await _shareCsv();
        } else if (value == 'save_food') {
          await _saveCsv();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'share_food',
          child: ListTile(
            leading: Icon(Icons.share),
            title: Text('Share CSV'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'save_food',
          child: ListTile(
            leading: Icon(Icons.save_alt),
            title: Text('Save to device'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ),
  ],
)
```

The `centerTitle: true` applies to the custom `Row` title, centering the entire group (chevron-text-chevron) in the AppBar. The remaining action icons (`menu_book`, `more_vert`) stay right-aligned as `actions` entries.

---

## Testing

### Manual verification

1. Open the log screen — verify "Today" is displayed with chevrons tight around it
2. Tap right chevron — date changes to "Tomorrow", text stays centered, chevrons stay tight
3. Tap left chevron twice — date changes to "Yesterday" and then back to "Today"
4. Tap the chevrons repeatedly — no layout shifts, text remains centered
5. Verify recipe-log and CSV menu buttons are on the far right and functional

### Regression verification

- Run `flutter test > test.log 2>&1` — all existing tests must pass
  - The widget test at `test/widget_test.dart` verifies log tab shows "Today" (`find.text('Today'), findsOneWidget`) — this should still pass since `_formatDateText()` and `DayNavigator.format()` are unchanged
- Run `flutter analyze > analyze.log 2>&1` — zero issues
