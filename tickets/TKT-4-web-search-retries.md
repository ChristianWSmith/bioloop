# TKT-4: Web search retries and error differentiation

**Risk**: Medium | **Files**: 4 | **Est**: 2-3hr

---

## Context

The OpenFoodFacts API search intermittently fails. Currently, all failures (network errors, rate limiting, bad responses, timeouts) are silently swallowed by `OpenFoodFactsClient.search()` which returns `[]`. Some paths (`TimeoutException`) aren't caught at all and propagate as raw errors in the UI.

The `_WebSearchContent` widget cannot distinguish between "search succeeded, no results" and "search failed entirely" because both result in an empty list being passed to the `FutureBuilder`.

## Findings

### API client (`open_food_facts_client.dart`)

The `search()` method (lines 20-48):
- Catches `SocketException`, `HttpException`, `FormatException` → returns `[]`
- Returns `[]` for 429, non-200, null body/products
- `TimeoutException` from `.timeout(10s)` is **uncaught** — propagates to UI
- **No retry logic**

### Service layer (`food_search_provider.dart:82`)

`FoodSearchService.searchWeb()` has no way to signal failure vs empty results.

### UI (`food_search_delegate.dart:307`)

- `.hasError`: shows raw `'Error: ${snapshot.error}'` text (reached on uncaught exceptions)
- `items.isEmpty`: shows `'No results found'` (reached for both "no results" AND "silent failure")

## Acceptance Criteria

- Intermittent API failures (network blips, 429, 5xx) are silently retried up to 2 times with backoff
- User sees `"No results found"` only when the API actually returned zero results
- User sees `"Search failed. Tap to retry."` when all retries are exhausted
- `TimeoutException` is handled gracefully (caught, retried, never shown raw)
- User never sees raw error messages from the search
- Retries are completely transparent — no loading spinners, no toasts, no logs

## Implementation

### 1. `lib/core/api/open_food_facts_client.dart`

Refactor `search()` to add retry:

```dart
Future<List<FoodResult>> search(String query) async {
  int attempts = 0;
  while (true) {
    attempts++;
    try {
      final uri = Uri.parse(...);
      final response = await _client
          .get(uri, headers: {'User-Agent': userAgent})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 429 || response.statusCode >= 500) {
        if (attempts < 3) {
          await Future.delayed(Duration(milliseconds: 500 * attempts));
          continue;
        }
        return [];
      }
      if (response.statusCode != 200) return [];

      // ... parse body, return results
    } on SocketException {
      if (attempts < 3) {
        await Future.delayed(Duration(milliseconds: 500 * attempts));
        continue;
      }
      return [];
    } on HttpException {
      if (attempts < 3) {
        await Future.delayed(Duration(milliseconds: 500 * attempts));
        continue;
      }
      return [];
    } on TimeoutException {
      if (attempts < 3) {
        await Future.delayed(Duration(milliseconds: 500 * attempts));
        continue;
      }
      return [];
    } on FormatException {
      return [];  // malformed JSON — no point retrying
    }
  }
}
```

Note: The while-loop/continue pattern can alternatively be a for-loop with early returns. The key behaviors are:
- Max 3 attempts (1 initial + 2 retries)
- 500ms × attempt_number exponential backoff
- Retry on: network errors, timeout, 429, 5xx
- No retry on: 4xx (except 429), FormatException

### 2. `lib/providers/food_search_provider.dart`

Add a result type to distinguish success from failure:

```dart
sealed class WebSearchResult {}
class WebSearchSuccess extends WebSearchResult {
  final List<FoodSearchItem> items;
  WebSearchSuccess(this.items);
}
class WebSearchFailure extends WebSearchResult {
  final String message;
  WebSearchFailure(this.message);
}
```

Update `searchWeb()`:

```dart
Future<WebSearchResult> searchWeb(String query) async {
  if (query.trim().isEmpty) return WebSearchSuccess([]);
  final results = await apiClient.search(query);
  if (results.isEmpty) {
    // Can't distinguish at this level without more info from the client
    // For now: client returns [] for both failure and empty success.
    // After retry addition: failure returns empty, success returns empty or data.
  }
  return WebSearchSuccess(
    results.map(FoodSearchItem.fromFoodResult).toList(),
  );
}
```

Actually, since the client already swallows all errors, we need the client itself (or the service) to report whether the request succeeded. The simplest approach:

**Option A**: Have the service layer catch the final failure and re-throw as a typed exception.

**Option B**: Add an `isFailed` flag or exception field to the client response.

**Simplest approach (recommended)**: Since after the retry changes, the client will have exhausted all retries but can't distinguish, add a `searchWeb` wrapper in the service that catches the remaining error:

```dart
Future<WebSearchResult> searchWeb(String query) async {
  if (query.trim().isEmpty) return WebSearchSuccess([]);
  try {
    final results = await apiClient.search(query);
    return WebSearchSuccess(
      results.map(FoodSearchItem.fromFoodResult).toList(),
    );
  } catch (e) {
    return WebSearchFailure('Search failed');
  }
}
```

Also need to catch final `TimeoutException` in the client — the loop above handles this.

### 3. `lib/features/logging/widgets/food_search_delegate.dart`

Update `_WebSearchContent` FutureBuilder:

```dart
future: widget.searchService.searchWeb(_debouncedQuery),
builder: (context, snapshot) {
  if (snapshot.connectionState == ConnectionState.waiting) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  final result = snapshot.data;
  if (result is WebSearchFailure) {
    return GestureDetector(
      onTap: () {
        setState(() => _debouncedQuery = widget.query);
        // triggers re-search
      },
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Search failed. Tap to retry.'),
      ),
    );
  }

  final items = (result as WebSearchSuccess?)?.items ?? [];
  if (items.isEmpty) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text('No results found'),
    );
  }

  return ListView(/* ... items ... */);
},
```

Also update the error path: since `WebSearchResult` is now used, `snapshot.hasError` would indicate a genuinely unhandled exception (shouldn't happen after client fixes). Remove or simplify the raw error text display.

The tap-to-retry works by re-setting `_debouncedQuery` to the current query, which triggers the `FutureBuilder`'s `key: ValueKey(_debouncedQuery)` rebuild.

Actually, re-setting `_debouncedQuery` to the same value won't necessarily retrigger the future. Better approach: add a `_retryTrigger` int counter and use it in the key or future:

```dart
int _retryTrigger = 0;

// In build:
future: widget.searchService.searchWeb('$_debouncedQuery-$_retryTrigger') // no, this changes the query
```

Simpler: use a late field or a `_search()` method that's called both from debounce and retry:

```dart
// Add a _retryTrigger counter
int _retryTrigger = 0;

// In build:
return FutureBuilder<WebSearchResult>(
  key: ValueKey('$_debouncedQuery-$_retryTrigger'),
  future: widget.searchService.searchWeb(_debouncedQuery),
  ...
);

// On retry tap:
setState(() => _retryTrigger++);
```

## Testing

### Unit tests (`test/api/open_food_facts_client_test.dart`)
- **Happy path with retry**: First call throws `SocketException` → retry succeeds → returns results
- **All retries exhausted**: All 3 attempts fail → returns `[]`
- **Non-retryable error**: `FormatException` on first call → returns `[]` immediately (no retry)
- **Timeout retry**: First call times out → retry succeeds

### Widget/scenario tests
- Mock search service returns `WebSearchSuccess([])` → screen shows "No results found"
- Mock search service returns `WebSearchFailure(...)` → screen shows "Search failed. Tap to retry."
- Tapping the failure message triggers a re-search

### Regression
- Run `flutter analyze` — zero issues
- Run `flutter test` — all existing tests pass (new result type is backward-compatible via sealed class pattern in Dart 3; existing callers that expect `List<FoodSearchItem>` need updating)
