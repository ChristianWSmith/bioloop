# Ticket 2: Add editable brand field to ManualFoodForm

## Status
- [ ] Not started

## Scope
`lib/features/logging/widgets/manual_food_form.dart`

## Context
Users can create custom foods manually but have no way to record the brand. The `brand` column exists in the `foods` table and `FoodsCompanion` already supports it. The `ManualFoodForm` is used for both creating new foods and editing existing ones.

## Requirements
- Add an optional "Brand" TextFormField to the form
- Position: after the Name field, before the Quantity/Unit row
- Label: "Brand (optional)"
- No validator — empty is valid
- When editing an existing food, pre-fill the field from `widget.existingFood!.brand`
- On save, include brand in both insert and update paths:
  - If the field is empty or whitespace-only, save `null`
  - Otherwise, save the trimmed text
- The `Food` object returned via `Navigator.pop()` must include the brand value

## Acceptance Criteria
- [ ] Brand field appears in the form between Name and Quantity/Unit
- [ ] Brand field pre-fills when editing an existing food with a brand
- [ ] Brand field is empty when creating a new food
- [ ] Saving with brand text stores it in the database
- [ ] Saving with empty brand stores `null` in the database
- [ ] The returned `Food` object includes the brand value
- [ ] `flutter analyze` passes with zero issues

## Testing
- **Widget test** (`test/features/logging/manual_food_form_test.dart`):
  - Create new food with brand → verify brand is saved in DB
  - Create new food without brand → verify brand is null in DB
  - Edit existing food with brand → verify brand pre-fills and is preserved on save
  - Edit existing food, clear brand → verify brand becomes null on save

## Files to Modify
- `lib/features/logging/widgets/manual_food_form.dart`

## Notes
- `FoodsCompanion.insert()` and `FoodsCompanion()` already accept `brand: Value(String?)`
- The `brand` column is nullable in the schema, so `Value(null)` is valid
- This ticket is independent of Ticket 1 but both touch the brand field
