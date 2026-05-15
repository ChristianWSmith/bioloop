# Ticket 06 — Restrict history edit entry to quantity only

**Issues**: #12  
**Phase**: 2  
**Dependencies**: None  
**Estimate**: ~45 minutes

---

## Context

The `EditEntrySheet` (modal bottom sheet for editing logged food) currently
exposes editable fields for name, servings, calories, protein, carbs, fat,
and meal type. The issue says users should only be able to edit the quantity
(servings) — not individual macros.

The macro-scaling logic (`_onServingsChanged`) that recomputes total macros
when servings change should stay intact: changing quantity should scale the
totals proportionally.

---

## Acceptance Criteria

1. Entry name is displayed as read-only text, not a text field.
2. Calories, protein, carbs, fat are displayed as read-only text, not editable.
3. Servings/quantity remains editable and auto-scales macros (existing behavior).
4. Meal type dropdown stays editable.
5. The save button still works and updates the entry correctly.
6. The `_onServingsChanged` listener continues to scale macros when servings
   change.

---

## Implementation

**File**: `lib/features/history/widgets/edit_entry_sheet.dart`

### Change editable fields to read-only display

Replace `TextField` widgets for name, calories, protein, carbs, fat with
read-only `Text` widgets inside a `Padding` or `ListTile`.

```dart
// Before (name field, lines 153-158):
TextField(
  key: const Key('edit_name_field'),
  controller: _nameController,
  onChanged: (_) => setState(() {}),
  decoration: const InputDecoration(labelText: 'Name'),
),

// After:
Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    children: [
      const Text('Name: ', style: TextStyle(fontWeight: FontWeight.w600)),
      Text(_nameController.text),
    ],
  ),
),
```

Same pattern for calories, protein, carbs, fat — show as label + value.

### Keep editable
- Servings `TextField` (key: `edit_servings_field`)
- Meal type `DropdownButton`

### Simplify validation
Remove validation for name, calories, protein, carbs, fat (they can't be
edited). Only validate that servings is a positive number.

```dart
bool get _isValid {
  final servings = double.tryParse(_servingsController.text);
  return servings != null && servings > 0;
}
```

### Remove unused controllers and listeners
- Remove `_nameController`, `_caloriesController`, `_proteinController`,
  `_carbsController`, `_fatController`
- Only keep `_servingsController`
- The `_onServingsChanged` listener stays

---

## Testing

### Unit/widget tests (`test/features/history/history_screen_test.dart`)

- **Update**: "edit macro scaling — servings 1.0 -> 2.0 doubles macros" —
  should still pass since servings editing works the same way
- **Update**: "edit macro scaling — change servings back to 1 restores
  original" — should still pass
- **Remove or rewrite**: "edit save — change name" — name can no longer be
  edited. Replace with "edit save — name field is read-only"
- **Remove or rewrite**: the tap test that checks `edit_name_field` Key —
  replace with check for read-only name display

### Manual tests
- Go to History tab, tap an entry
- **Verify**: Name, Calories, Protein, Carbs, Fat are displayed as text
  (not text fields)
- **Verify**: Servings is an editable text field
- **Verify**: Meal type is a dropdown
- Change servings from 1.0 to 2.0
- **Verify**: displayed calories double, protein doubles, etc.
- Save
- **Verify**: the entry in the list shows updated values
- **Verify**: the name field in the sheet matches the original name exactly

---

## Files Changed

| File | Change |
|------|--------|
| `lib/features/history/widgets/edit_entry_sheet.dart` | Convert macro fields to read-only display, keep servings+meal type editable |

---

## Open Questions

- Should `servingLabel` also be displayed read-only alongside the name?
  Currently it's not shown at all in the edit sheet. Might be useful context
  for the user. Not required for this ticket.
