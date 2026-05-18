# Ticket 05: Add empty-result retry to OpenFoodFactsClient

**Category:** OpenFoodFacts API
**Status:** Pending
**Depends on:** None
**Blocks:** Ticket 06

## Problem

`OpenFoodFactsClient.search()` in `lib/core/api/open_food_facts_client.dart:21-73` has a retry loop for network errors (HTTP 429, 5xx, SocketException, HttpException, TimeoutException — up to 3 attempts with 500ms × attempt backoff). However, when the API returns HTTP 200 with an empty `products` array, it returns `[]` immediately with no retry.

Users report intermittent "no results" responses that are odd because the API call succeeds (HTTP 200) but returns no products. This may be a transient OFF server issue. We should retry with a backoff strategy before giving up.

## Context

- `lib/core/api/open_food_facts_client.dart:40-50` — current empty products handling (no retry)
- `lib/core/api/open_food_facts_client.dart:33-38` — existing retry logic for 429/5xx
- Issue #5 from `issues.txt`: "If the former is true, we ought to do retries on requests that are successful but return no results. We should use good API etiquette and not spam, so maybe some kind of back off strategy works there."

## Changes Required

In `OpenFoodFactsClient.search()`, after successfully parsing the response with `products.isEmpty`:

1. Retry up to 2 additional times (3 total attempts including the initial)
2. Use exponential backoff: 1 second, then 2 seconds
3. If all retries return empty, return `[]` (same as current behavior)

The backoff should be longer than the network error backoff (500ms) to be respectful of the API and because empty results are less likely to be transient.

## Acceptance Criteria

- [ ] Empty products result triggers up to 2 retries with 1s and 2s backoff
- [ ] If a retry returns non-empty products, those results are returned immediately
- [ ] If all 3 attempts return empty, `[]` is returned
- [ ] Existing retry logic for network errors (429, 5xx, etc.) is unchanged
- [ ] `flutter analyze` passes with zero issues

## Testing

New tests in `test/api/open_food_facts_client_test.dart`:

- Test: mock returns 200 with empty products twice, then returns results → client returns results after 3 HTTP calls
- Test: mock always returns empty products → client returns `[]` after exactly 3 attempts
- Test: verify backoff timing — first retry after ~1s, second retry after ~2s (use `FakeAsync`)
- Test: existing "search returns empty on empty products" test still passes (now takes longer due to retries)

## Files Affected

- `lib/core/api/open_food_facts_client.dart` — add empty-result retry logic
- `test/api/open_food_facts_client_test.dart` — add retry tests
