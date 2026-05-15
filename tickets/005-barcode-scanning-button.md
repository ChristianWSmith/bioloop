# 005 — Add barcode scanning button to food search

**Issues**: #2
**Files**:
- `lib/features/logging/widgets/food_search_delegate.dart`
- `lib/features/logging/combined_log_screen.dart`

**Effort**: Medium

---

## Context

The barcode scanner screen (`BarcodeScannerScreen`) exists in the codebase at `lib/features/logging/widgets/barcode_scanner.dart` but has no entry point in the UI. It was lost during a previous refactor of the logging screen.

The scanner uses `mobile_scanner` to detect barcodes, then looks up the food via `OpenFoodFactsClient.getByBarcode()`. On success, it returns a `FoodResult`; on not-found, it offers "Enter manually" (returns `'manual'`) or "Scan again".

We need to add a barcode scan button to the food search screen so users can log foods by scanning the barcode.

---

## Acceptance criteria

1. A barcode scan icon button (`Icons.qr_code_scanner`) appears in the `FoodSearchDelegate`'s AppBar area (e.g. in `buildActions`)
2. Tapping the button opens `BarcodeScannerScreen` as a full-screen route
3. When a food is found via barcode:
   - A `FoodSearchItem` is created from the `FoodResult`
   - The quick-log flow (`QuickFoodLogSheet`) is opened to let the user log it
   - After logging, the search delegate closes and returns to the log screen
4. When the barcode is not found:
   - The user can enter the food manually (leads to `ManualFoodForm`)
   - Or scan again
5. When the user cancels the scanner (pops without result), they return to the search delegate
6. No regressions to existing search functionality

---

## Implementation notes

### Getting the API client to the delegate

`FoodSearchDelegate` currently holds a `FoodSearchService` but doesn't have direct access to `OpenFoodFactsClient`. Two approaches:

**Approach A**: Have the delegate read `openFoodFactsClientProvider` directly (requires making `FoodSearchDelegate` a `ConsumerWidget` or accepting a `WidgetRef`).

**Approach B**: Pass the `OpenFoodFactsClient` through the delegate's constructor:
```dart
class FoodSearchDelegate extends SearchDelegate<FoodSearchItem?> {
  final FoodSearchService searchService;
  final OpenFoodFactsClient apiClient;  // add this
  ...
}
```

Approach B is simpler. In `CombinedLogScreen._onSearch()`:
```dart
final apiClient = ref.read(openFoodFactsClientProvider);
final result = await showSearch<FoodSearchItem?>(
  context: context,
  delegate: FoodSearchDelegate(
    searchService: searchService,
    apiClient: apiClient,
    ...
  ),
);
```

### Integrating with quick-log

When the scanner returns a `FoodResult`, convert it to `FoodSearchItem` via `FoodSearchItem.fromFoodResult()`, then pass it to `onQuickLog` to open the sheet. After the sheet closes, close the search delegate (same pattern as Ticket 004 fix for #9).

```dart
// In buildActions:
IconButton(
  icon: const Icon(Icons.qr_code_scanner),
  onPressed: () async {
    final result = await Navigator.of(context).push<FoodResult>(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(apiClient: apiClient),
      ),
    );
    if (result != null && result is FoodResult) {
      final item = FoodSearchItem.fromFoodResult(result);
      if (onQuickLog != null) {
        await onQuickLog!(item);  // opens sheet
        close(context, null);     // closes search
      }
    }
  },
),
```

---

## Testing

1. Tap the barcode icon in the search delegate → verify `BarcodeScannerScreen` opens
2. Cancel the scanner → verify return to search delegate
3. (If possible with a test barcode) Scan a known barcode → verify food is found and quick-log sheet opens
4. (If possible) Scan an unknown barcode → verify "not found" UI with manual entry option
5. Tap "Enter manually" from the not-found screen → verify `ManualFoodForm` opens
6. After logging a scanned food → verify the search delegate closes
7. Run `flutter analyze` — zero issues
