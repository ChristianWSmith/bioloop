# T8 — Food history screen

Paginated list of all logged food entries grouped by date.

## Files to modify

- `lib/features/history/history_screen.dart` — full implementation

## Behavior

- Group entries by date, sorted newest first
- Each date section shows date header + entries with: name, macros summary, meal type badge, time
- Swipe left on an entry → confirmation dialog → delete
- Tap entry → show detail popup/edit bottomsheet (read-only for now, edit in future)
- Pull-to-refresh
- Infinite scroll / pagination (load 20 at a time)

## DAO methods needed

- `Future<List<FoodEntry>> getEntriesPaginated({int offset, int limit})`

## Acceptance criteria

- Shows all logged entries grouped by date
- Swipe-to-delete works with confirmation
- Deleting updates totals on dashboard (since provider reacts to DB changes)
- Pull-to-refresh reloads data

## Dependencies

T6 (food_entries DAO)
