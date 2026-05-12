# T8 — Food history screen

Paginated list of all logged food entries grouped by date.

## Files to modify

- `lib/features/history/history_screen.dart` — full implementation

## Behavior

- Group entries by date, sorted newest first
- Each date section shows date header + entries with: name, macros summary, meal type badge, time
- Swipe left on an entry → confirmation dialog → delete
- Tap entry → edit bottomsheet with all fields editable:
  - Name, servings, meal type, macros (calories, protein, carbs, fat)
  - Changing servings rescales macros proportionally
  - Save updates the `food_entries` row in-place
- Pull-to-refresh
- Infinite scroll / pagination (load 20 at a time)

## DAO methods needed

- `Future<List<FoodEntry>> getEntriesPaginated({int offset, int limit})`
- `Future<void> updateEntry(FoodEntry entry)` — updates name, servings, macros, meal_type by id

## Acceptance criteria

- Shows all logged entries grouped by date
- Swipe-to-delete works with confirmation
- Deleting updates totals on dashboard (since provider reacts to DB changes)
- Pull-to-refresh reloads data

## Testing

- **Widget — date grouping**: entries from 3 different dates render as 3 sections with correct date headers
- **Widget — swipe-to-delete**: swipe an entry, confirmation dialog appears, confirm removes it from the list and DB
- **Widget — cancel delete**: swipe, tap cancel, entry remains
- **Widget — tap-to-edit**: tap an entry, edit bottomsheet opens with current name, servings, meal type, and macros pre-filled
- **Widget — edit save**: change name and servings in edit mode, save, entry reflects new values in list, no new row created
- **Widget — edit macro scaling**: change servings from 1.0 to 2.0, all four macro fields update to 2× original values; change back to 1.0, macros return to original
- **Widget — pull-to-refresh**: pull down triggers a reload (verify via spy on provider)
- **Widget — pagination**: insert 25 entries, verify only first 20 render on initial load, scroll to bottom loads next 5
- **Widget — empty state**: with no entries, shows "No food logged yet" message
- **Widget — entry details**: tap an entry opens a detail popup showing name, macros, meal type, date/time
- **Unit — pagination DAO**: `getEntriesPaginated(offset: 0, limit: 20)` returns 20, `getEntriesPaginated(offset: 20, limit: 20)` returns remaining

## Human verification

- [ ] `flutter analyze` passes with zero errors
- [ ] Log 3+ entries across different dates, navigate to History — entries grouped by date with headers
- [ ] Swipe an entry left — confirmation dialog appears
- [ ] Confirm delete — entry removed from list and DB; dashboard totals reflect the change (if navigating back)
- [ ] Cancel delete — entry remains
- [ ] Pull-to-refresh works
- [ ] Load 30+ entries — pagination loads 20 initially, scroll loads next batch
- [ ] Tap an entry — edit bottomsheet opens with name, servings, meal type, and macro fields pre-filled
- [ ] Change servings from 1 to 2 — macro fields update to 2× live before saving
- [ ] Save edit — entry updates in list, no duplicate created
- [ ] Empty state shows "No food logged yet"
- [ ] All widget + unit tests pass
- [ ] Date formatting is correct for locale (ISO format or friendly like "Today", "Yesterday", "May 11")

## Dependencies

T6 (food_entries DAO)

## Agent instructions (app state tracking)

After completing the work in this ticket, append a row to the `## App State` table in `AGENTS.md`:

| T8 — Food history screen | ✅ Complete | YYYY-MM-DD | AI |

See `AGENTS.md` for the current state table.
