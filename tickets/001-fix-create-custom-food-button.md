# Ticket 1: Fix "Create custom food" button not opening the form

**Issue:** #7  
**Priority:** High  
**Effort:** 1 line  
**File:** `lib/features/logging/widgets/food_search_delegate.dart`

## Context

The "Create custom food" ListTile in `_LocalSearchContent` calls `onCreateCustomFood()` but never closes the search delegate. The user sees no visual feedback — the search screen stays open. They must manually press back, and only then does `ManualFoodForm` appear.

The barcode scanner handler (same file, lines 43-45) demonstrates the correct pattern — it sets the flag **and** pops the delegate in the same gesture.

Tracking the flow:
1. `_LocalSearchContent` `onTap` → `onCreateCustomFood()` sets `_pendingCreateCustom = true` in `CombinedLogScreen`
2. Delegate stays open — user must press back manually
3. `CombinedLogScreen._onSearch()` checks `_pendingCreateCustom` after the pop and opens `ManualFoodForm`

The fix is to pop the delegate synchronously after setting the flag, just like the barcode path does.

## Acceptance criteria

- [ ] Tapping "Create custom food" from My Foods results immediately closes the search delegate
- [ ] `ManualFoodForm` opens on the next frame after delegate closes
- [ ] Saving a food from the form logs it (via `_showQuickLogSheet`) and returns to the log screen
- [ ] Canceling the form returns to the log screen with no side effects
- [ ] Barcode scanner → "Enter manually" still works correctly (regression check)

## Testing

### Manual testing
1. Open log screen → tap FAB → tap "Create custom food"
2. Verify the search delegate closes immediately
3. Fill in food details → save → verify quick-log sheet opens
4. Open search again → tap "Create custom food" → press back on form → verify you're back on log screen
5. Test barcode scanner → scan fails → "Enter manually" → verify same flow works

### Automated testing notes
- The fix is in the `_LocalSearchContent.build()` ListTile `onTap` handler
- No new widget needed — the delegate handles the pop internally
- Existing tests for `FoodSearchDelegate` that call `onCreateCustomFood` should verify the delegate pops

## Implementation

```dart
// lib/features/logging/widgets/food_search_delegate.dart ~line 188
onTap: () {
  onCreateCustomFood();
  Navigator.of(context).pop<FoodSearchItem?>(null);  // add this line
},
```
