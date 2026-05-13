# Ticket 001 — App title + stale bodyweight after reset

**Issues:** #1, #7
**Estimate:** ~30 min
**Depends on:** nothing

---

## Acceptance criteria

### App title (#1)
- [ ] App launcher icon shows "BioLoop" on Android (not "bioloop")
- [ ] App launcher icon shows "BioLoop" on iOS (not "Bioloop")
- [ ] Window/task switcher title shows "BioLoop"
- [ ] Dashboard welcome text says "Welcome to BioLoop" (not "bioloop")

### Stale bodyweight after reset (#7)
- [ ] After data reset → complete onboarding → navigate to Bodyweight tab, the newly entered starting weight appears immediately (no app restart required)
- [ ] Dashboard goal weight card reflects the new bodyweight after onboarding

---

## Context from DISCOVERY.md

### App title — current state

| Location | File | Current | Target |
|----------|------|---------|--------|
| MaterialApp title | `lib/app.dart:57` | `'bioloop'` | `'BioLoop'` |
| Android manifest | `android/app/src/main/AndroidManifest.xml:4` | `android:label="bioloop"` | `android:label="BioLoop"` |
| iOS BundleDisplayName | `ios/Runner/Info.plist:12` | `Bioloop` | `BioLoop` |
| iOS BundleName | `ios/Runner/Info.plist:20` | `bioloop` | `BioLoop` |
| Dashboard welcome | `lib/features/dashboard/dashboard_screen.dart:188` | `'Welcome to bioloop'` | `'Welcome to BioLoop'` |

### Stale bodyweight — root cause trace

1. `resetAll()` truncates `bodyweight_entries` → `resetTriggerProvider` incremented → `bodyweightProvider` re-resolves → **empty list**
2. `_checkOnboarding()` → onboarding screen shown
3. User completes onboarding → `db.insertWeight()` called directly (not through provider) → new weight saved
4. `_onOnboardingComplete()` only calls `setState` — does NOT invalidate `bodyweightProvider`
5. Result: BodyweightScreen shows stale empty list until app restart

### Fix for #7

In `lib/app.dart`, add provider invalidation inside `_onOnboardingComplete()`:

```dart
void _onOnboardingComplete() {
  ref.invalidate(bodyweightProvider);
  ref.invalidate(todaysFoodProvider);
  ref.invalidate(userGoalsProvider);
  setState(() => _onboardingCompleted = true);
}
```

This matches the existing pattern in `bodyweight_screen.dart:118` and `145`.

---

## Testing

### Manual test — title
1. Build and install on device/emulator
2. Check launcher icon label: should show "BioLoop"
3. Check app bar title in task switcher

### Manual test — stale weight
1. Fresh install → complete onboarding with weight "75 kg"
2. Go to Bodyweight tab → verify "75 kg" appears
3. Go to Settings → Reset All Data
4. Complete onboarding again with weight "80 kg"
5. Immediately navigate to Bodyweight tab → verify "80 kg" appears (no restart needed)

### Automated test ideas
- Unit test: verify `_onOnboardingComplete` calls `ref.invalidate(bodyweightProvider)` — requires mocking `ProviderRef`
- Widget test: reset + onboard → bodyweight list is non-empty

---

## Files to modify

- `lib/app.dart` — MaterialApp title + `_onOnboardingComplete` invalidation
- `lib/features/dashboard/dashboard_screen.dart` — welcome text
- `android/app/src/main/AndroidManifest.xml` — `android:label`
- `ios/Runner/Info.plist` — `CFBundleDisplayName` + `CFBundleName`
