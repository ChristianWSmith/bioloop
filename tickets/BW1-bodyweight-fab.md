# BW1: Move bodyweight log button to FloatingActionButton

**Category**: Bodyweight
**Priority**: Low
**Estimated effort**: Medium (1 file, layout restructuring)
**Discovery**: `DISCOVERY.md` → BW1

## Problem

The bodyweight screen uses an inline `FilledButton.icon` in a custom header row, inconsistent with the `FloatingActionButton` pattern used by the Recipe List and Combined Log screens.

## Current Layout

**`bodyweight_screen.dart:19-97`**:
```dart
return SafeArea(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text('Bodyweight', ...),           // title
            const Spacer(),
            FilledButton.icon(                 // ← "+ Log weight" button
              key: const Key('log_weight_button'),
              onPressed: () => _showSheet(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Log weight'),
            ),
            PopupMenuButton<String>(...),      // CSV export menu
          ],
        ),
      ),
      const Divider(height: 1),
      Expanded(child: ListView...),            // body
    ],
  ),
);
```

### Reference pattern (Recipe List, Combined Log)

```dart
return Scaffold(
  appBar: AppBar(
    title: Text('...'),
    actions: [PopupMenuButton(...)],
  ),
  floatingActionButton: FloatingActionButton(
    onPressed: ...,
    tooltip: '...',
    child: const Icon(Icons.add),
  ),
  body: ...,
);
```

## Proposed Fix

1. Replace `SafeArea` + `Column` with `Scaffold` + `AppBar` + `body`
2. Move "Bodyweight" title to `AppBar.title`
3. Move CSV export `PopupMenuButton` to `AppBar.actions`
4. Replace `FilledButton.icon` with `FloatingActionButton(child: Icon(Icons.add))`
5. Keep all existing `_showSheet()` and `_confirmDelete()` logic unchanged
6. Remove the `Divider` (AppBar provides visual separation)
7. Wrap body in `SafeArea` if needed (Scaffold handles this for the body by default)

### Implementation sketch

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final weightsAsync = ref.watch(bodyweightProvider);
  final prefs = ref.watch(unitPreferencesProvider);

  return Scaffold(
    appBar: AppBar(
      title: const Text('Bodyweight'),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) async {
            // ... existing CSV export logic unchanged ...
          },
          itemBuilder: (_) => [
            // ... existing menu items unchanged ...
          ],
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      key: const Key('log_weight_button'),
      onPressed: () => _showSheet(context, ref),
      tooltip: 'Log weight',
      child: const Icon(Icons.add),
    ),
    body: weightsAsync.when(
      data: (weights) => weights.isEmpty
          ? const Center(child: Text('No entries yet'))
          : ListView.builder(
              itemCount: weights.length,
              itemBuilder: (ctx, i) =>
                  _buildEntry(context, ref, prefs, weights[i]),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    ),
  );
}
```

## Acceptance Criteria

- [ ] FAB appears in bottom-right corner with `Icons.add`
- [ ] Tapping FAB opens the add-weight bottom sheet
- [ ] CSV export `PopupMenuButton` appears in AppBar actions (top-right)
- [ ] CSV export functionality works unchanged (Share CSV, Save to device)
- [ ] Entry tap-to-edit opens `AddWeightSheet` with pre-filled data
- [ ] Entry long-press shows delete confirmation dialog
- [ ] Screen renders correctly on small and large screens
- [ ] `flutter analyze` passes with zero issues

## Testing

### Manual testing
1. Navigate to Bodyweight tab → verify FAB is visible in bottom-right
2. Tap FAB → verify add-weight sheet opens
3. Log a weight → verify it appears in the list
4. Tap an entry → verify edit sheet opens with pre-filled values
5. Long-press an entry → verify delete confirmation dialog appears
6. Tap the `more_vert` icon in AppBar → verify CSV export menu appears
7. Test CSV export (Share CSV / Save to device)

### Edge cases
- Empty state (no entries) → "No entries yet" centered, FAB still visible
- Many entries → list scrolls correctly, FAB stays fixed at bottom-right
- Keyboard open in sheet → FAB behavior is unaffected (sheet is modal)

## Files to change

| File | Lines | Change |
|---|---|---|
| `lib/features/bodyweight/bodyweight_screen.dart` | 15-97 | Restructure from SafeArea+Column to Scaffold+AppBar+FAB |

## References

- `lib/features/recipes/recipe_list_screen.dart` — reference Scaffold+FAB pattern
- `lib/features/logging/combined_log_screen.dart` — reference Scaffold+FAB pattern
- `lib/features/bodyweight/widgets/add_weight_sheet.dart` — sheet widget (unchanged)
