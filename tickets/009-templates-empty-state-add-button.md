# 009 — Add "create template" button to empty templates sheet

- **Phase**: 3 — Bug Fixes
- **Priority**: Medium

## Overview

The meal templates sheet shows "No templates yet" with no way to create one. Templates can only be created indirectly after selecting a food in the Log screen and tapping the bookmark icon. Add a way to create a template directly from the templates sheet's empty state.

## Context from Discovery

- `MealTemplatesSheet` (`lib/features/logging/widgets/meal_templates.dart`): a `DraggableScrollableSheet` modal bottom sheet.
- Empty state shows icon + text but no action button.
- The only path to create a template: Log screen → search food → select it → bookmark icon appears → tap → enter name → saved.
- `saveCurrentFoodsAsTemplate()` function exists (line 169) and can be called programmatically.

## Options

1. **Empty state FilledButton**: In the empty state, show a button "Create your first template" that opens a dialog for name + manual food entry, or navigates to the log screen.
2. **Warning**: Templates require at least one food entry to exist. The create action in the empty state could prompt the user to log a food first, then save as template.

Since templates inherently store food snapshots, an empty templates sheet with no foods logged yet could: guide the user to log a food first, and provide a short explanation.

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/logging/widgets/meal_templates.dart` | Add action button to empty state that either opens a mini-form to create a template from scratch, or navigates the user to the log screen to log food first |

## Acceptance Criteria

- [ ] Empty state of templates sheet shows a button/action to create a template
- [ ] Tapping the action either creates a blank template or guides the user to log food first
- [ ] If a template is created, it appears in the list immediately
- [ ] `flutter analyze` passes with zero errors
- [ ] Existing tests pass

## Testing

- Widget test: empty state includes an action widget (button)
- Widget test: tapping the action closes the sheet or navigates appropriately
- Widget test: after creating a template via this path, the template appears in the list
