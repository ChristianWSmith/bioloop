# Ticket 005 — Serving units: schema migration + API parsing

**Issues:** #4 (infrastructure)
**Estimate:** ~2 hr
**Depends on:** nothing

---

## Acceptance criteria

### Schema migration
- [ ] `Foods` table gains `servingUnit` text column and `servingQuantity` real column
- [ ] `schemaVersion` bumped from 1 to 2 in `database.dart`
- [ ] Migration strategy defined and tested for existing data
- [ ] `dart run build_runner build` generates updated drift code successfully

### API serving-size parsing
- [ ] `FoodResult._parseServingGrams()` replaced with `_parseServingInfo()` that extracts quantity, unit, and gram-equivalent
- [ ] Common labels handled correctly: `"100g"`, `"1 cup (240ml)"`, `"1 slice"`, `"1 bar (40g)"`, `"1 oz (28g)"`, `"1/2 cup (120ml)"`, `"1 packet"`
- [ ] Falls back to defaults for unparseable labels

### Data model updates
- [ ] `Food`, `FoodResult`, `FoodSearchItem` include new `servingUnit` and `servingQuantity` fields
- [ ] `FoodsCompanion` includes new fields for inserts/updates

---

## Context from DISCOVERY.md

### Current schema gap

```dart
// lib/core/database/tables/foods.dart
class Foods extends Table {
  // ...
  TextColumn get servingLabel => text()();           // "100g", "1 cup", "1 slice"
  RealColumn get servingSizeGrams => real().nullable();  // grams per serving, nullable
}
```

Missing: dedicated `servingUnit` + `servingQuantity` columns to store parsed components.

### New column design

| Column | Type | Example values |
|--------|------|---------------|
| `servingLabel` (existing) | text | "1 cup", "100g", "1 slice" |
| `servingSizeGrams` (existing) | real? | 240, 100, null |
| `servingQuantity` (new) | real | 1.0, 100.0, 1.0 |
| `servingUnit` (new) | text | "cup", "g", "slice", "bar", "oz", "packet" |

### Parsing logic

Replace `_parseServingGrams()` with `_parseServingInfo()`:

```dart
static ({double quantity, String unit, double? gramEquivalent})? _parseServingInfo(String label) {
  // Pattern: "1 cup (240ml)" or "1 bar (40g)" → extract qty, unit, gram-equivalent
  final fullMatch = RegExp(r'^([\d./]+)\s+(\w+)(?:\s*\((\d+)\s*g(?:ram)?\))?$').firstMatch(label);
  if (fullMatch != null) {
    final qty = _parseFraction(fullMatch.group(1)!);
    final unit = fullMatch.group(2)!;
    final gramEq = fullMatch.group(3) != null ? double.parse(fullMatch.group(3)!) : null;
    return (quantity: qty, unit: unit, gramEquivalent: gramEq);
  }

  // Pattern: "100g" → qty=100, unit=g
  final simpleGrams = RegExp(r'^(\d+(?:\.\d+)?)\s*g$').firstMatch(label);
  if (simpleGrams != null) {
    return (quantity: double.parse(simpleGrams.group(1)!), unit: 'g', gramEquivalent: double.parse(simpleGrams.group(1)!));
  }

  return null; // fallback
}

static double _parseFraction(String s) {
  if (s.contains('/')) {
    final parts = s.split('/');
    return double.parse(parts[0]) / double.parse(parts[1]);
  }
  return double.parse(s);
}
```

### Data migration (schema v1 → v2)

For existing rows in `foods`:
- `servingSizeGrams != null` → `servingUnit = 'g'`, `servingQuantity = servingSizeGrams`
- `servingLabel` contains `/cup/` → `servingUnit = 'cup'`, `servingQuantity = 1`
- `servingLabel` contains `/slice/` → `servingUnit = 'slice'`, `servingQuantity = 1`
- Fallback: `servingUnit = 'serving'`, `servingQuantity = 1`

Drift migration:
```dart
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(foods, foods.servingUnit);
        await m.addColumn(foods, foods.servingQuantity);
        // Populate from existing data
        await customStatement('''
          UPDATE foods
          SET serving_unit = CASE
            WHEN serving_size_grams IS NOT NULL THEN 'g'
            WHEN serving_label LIKE '%cup%' THEN 'cup'
            WHEN serving_label LIKE '%slice%' THEN 'slice'
            WHEN serving_label LIKE '%bar%' THEN 'bar'
            WHEN serving_label LIKE '%oz%' THEN 'oz'
            ELSE 'serving'
          END,
          serving_quantity = CASE
            WHEN serving_size_grams IS NOT NULL THEN serving_size_grams
            ELSE 1
          END
        ''');
      }
    },
  );
}
```

---

## Testing

### Manual test — migration
1. Install existing app, log several foods with various serving labels
2. Upgrade to version with migration
3. Verify all foods have correct `servingUnit` and `servingQuantity` values
4. Search and log new foods — verify API results are parsed correctly

### Automated test ideas
- Unit test `_parseServingInfo()` with: `"100g"`, `"1 cup (240ml)"`, `"1 slice"`, `"1 bar (40g)"`, `"1/2 cup (120ml)"`, `"1 oz (28g)"`, `"1 packet"`, `"unknown format"`
- Unit test migration SQL on an in-memory DB with seed data
- Verify `FoodResult.fromJson` correctly populates new fields
- `flutter test` must pass

---

## Files to create/modify

- **Modify:** `lib/core/database/tables/foods.dart` — add `servingUnit`, `servingQuantity`
- **Modify:** `lib/core/database/database.dart` — bump schema version + migration
- **Modify:** `lib/core/api/models/food_result.dart` — new parsing logic
- **Modify:** `lib/providers/food_search_provider.dart` — update `FoodSearchItem`
- **Regenerate:** `database.g.dart` via `dart run build_runner build`
