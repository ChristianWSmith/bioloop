# Ticket 004 — Bodyweight imperial support + authoritative unit + 2dp rounding

**Issues:** #6, #10, #2 (display portion)
**Estimate:** ~2 hr
**Depends on:** Ticket 003 (global unit provider)

---

## Acceptance criteria

### Bodyweight imperial (#6)
- [ ] "Log weight" sheet shows unit suffix based on preference: `lb` or `kg`
- [ ] Entering weight in lb is correctly converted to kg for storage
- [ ] Editing an existing weight shows the value in user's preferred unit
- [ ] Bodyweight list displays weights in user's preferred unit
- [ ] Delete confirmation dialog shows weight in user's preferred unit
- [ ] Bodyweight CSV export has a `unit` column indicating `lb` or `kg`

### Authoritative unit (#10)
- [ ] Decision documented: approach chosen (see open questions below)
- [ ] Implemented approach prevents display drift beyond 0.1 unit

### Rounding (#2)
- [ ] All measurement displays round to 2 decimal places
- [ ] Internal storage preserves full precision

---

## Context from DISCOVERY.md

### Current bodyweight gap

`AddWeightSheet` (`lib/features/bodyweight/widgets/add_weight_sheet.dart`):
```dart
suffixText: 'kg',   // line 142 — hardcoded
```

Bodyweight list (`bodyweight_screen.dart`):
```dart
title: Text('${entry.weightKg} kg'),   // line 104 — hardcoded
```

The sheet has no access to `useImperial`. The list has no access to `useImperial`.

### Rounding audit — current precisions

| Site | Current | Target |
|------|---------|--------|
| Goal weight card | `toStringAsFixed(0)` | `toStringAsFixed(2)` |
| Sparkline tooltip | `toStringAsFixed(1)` | `toStringAsFixed(2)` |
| Sparkline Y-axis | `value >= 100 ? 0 : 1` | `2` (or adaptive: show 0 if integer) |
| Bodyweight list item | raw `$weightKg` | `toStringAsFixed(2)` |
| Goals/onboarding conversions | `toStringAsFixed(1)` | `toStringAsFixed(2)` |
| Onboarding unit toggle | `toStringAsFixed(1)` | `toStringAsFixed(2)` |

### Authoritative unit — decision needed

Three approaches identified in DISCOVERY.md:

- **A**: Store raw user-entered value + unit in separate columns. Full precision, no drift. Requires schema change.
- **B**: Store only kg, accept <0.1lb rounding drift (invisible at 0dp, potentially visible at 2dp). Simplest, no schema change.
  - Example: 100 lb → 45.3592 kg → 100 × 2.20462 = 100.0 — no drift
  - Edge: 165.4 lb → 75.052 kg → 75.052 × 2.20462 = 165.41 — 0.01lb drift
- **C**: Store kg + raw value + unit. Precise but redundant.

**Recommended:** Approach B with display rounding to 0dp for goal weight card and 2dp for detailed views. The sub-0.1lb drift is negligible for this use case.

---

## Testing

### Manual test — bodyweight imperial
1. Complete onboarding in imperial mode
2. Go to Bodyweight tab → tap "Log weight"
3. Verify suffix shows "lb"
4. Enter "150" and save
5. Verify list shows "150.00 lb" (not "68.04 kg")
6. Tap to edit → verify field shows "150.00"
7. Go to Dashboard → verify goal weight card shows consistent values

### Manual test — rounding
1. Log bodyweight of 75.1234 kg in metric mode
2. Verify display shows "75.12 kg" (not "75.1234 kg")
3. Switch to imperial → verify display shows "165.57 lb"
4. Switch back to metric → verify field returns to "75.12" (no cumulative drift beyond 0.01)

### Automated test ideas
- Unit test: create bodyweight entry at 75.1234 kg, display in metric → check "75.12 kg"
- Unit test: verify display weight in lb uses correct conversion and 2dp
- Widget test: `AddWeightSheet` shows correct suffix based on unit preference
- Widget test: bodyweight list shows converted values

---

## Files to modify

- `lib/features/bodyweight/widgets/add_weight_sheet.dart`
- `lib/features/bodyweight/bodyweight_screen.dart`
- `lib/features/dashboard/dashboard_screen.dart`
- `lib/features/dashboard/widgets/bodyweight_sparkline.dart`
- `lib/features/goals/goals_screen.dart` (rounding only)
- `lib/features/onboarding/onboarding_screen.dart` (rounding only)
- `lib/features/history/export.dart` (CSV unit column)
