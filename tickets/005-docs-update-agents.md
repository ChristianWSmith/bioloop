# Ticket #5: [DOCS] Update AGENTS.md with recipe and maintenance behavior

**Priority:** 🟢 Low  
**Effort:** Small (1-2 hours)  
**Status:** Pending  
**Assignee:** Unassigned  
**Created:** May 16, 2026  
**Tags:** `documentation`, `agents`, `maintenance`

---

## Problem Statement

After implementing tickets #1-4, AGENTS.md needs to be updated to document:
1. Recipe edit flow (two modes clarified)
2. Recipe bug fix (ingredient re-insert on edit)
3. Maintenance forward-fill behavior (pre-weight assumption)
4. Unit filtering for imported foods
5. Recipe discoverability improvements

**User Impact:** Future developers and AI agents will have accurate documentation for maintaining and extending these features.

---

## Scope

### Sections to Add/Update

1. **Design Rules** section:
   - Recipe management modes (management vs. picker)
   - Unit filtering for OpenFoodFacts imports

2. **Important Notes** section:
   - Maintenance forward-fill algorithm behavior
   - Recipe edit flow and ingredient persistence

3. **Architecture** section (if needed):
   - Clarify `ServingSizePicker` source parameter
   - Clarify `MaintenanceCalculator` forward-fill logic

---

## Acceptance Criteria

### Content Requirements
- [ ] Recipe section clarifies management vs. picker mode
- [ ] Recipe section documents edit → save → ingredient re-insert behavior
- [ ] Recipe section documents long-press delete with haptic feedback
- [ ] Maintenance section documents forward-fill algorithm (pre-weight assumption)
- [ ] Design rules section documents unit filtering for imported foods
- [ ] All file paths and line numbers are accurate (verified against final code)

### Quality Requirements
- [ ] No typos or grammatical errors
- [ ] Consistent formatting with existing AGENTS.md style
- [ ] Code examples match final implementation
- [ ] Cross-references to other sections work correctly

### Verification
- [ ] All documented behaviors match implemented code
- [ ] File paths verified (files exist at documented locations)
- [ ] Line numbers verified (within ±5 lines of documented location)

---

## Technical Implementation

### Files to Modify

1. **`AGENTS.md`**
   - Update "Design rules" section
   - Update "Important notes" section
   - Add new subsections if needed

### Documentation Changes

#### Change 1: Recipe Management Modes

**Location:** After "Design rules" section (around line 99-115)

**Add new subsection:**
```markdown
### Recipe management

- **Two modes**: `RecipeListScreen` has `pickerMode` parameter
  - Management mode (`pickerMode: false`): Recipes tab — tap to edit, long-press to delete
  - Picker mode (`pickerMode: true`): Log screen — tap to log recipe only
- **Edit flow**: Edit → modify ingredients → save → ingredients re-inserted (bug fix #1)
- **Delete flow**: Long-press with haptic feedback → confirmation dialog → cascade delete (ingredients first, then recipe)
- **Duplicate flow**: Duplicate → navigate to edit form → user can modify before saving
- Files: `lib/features/recipes/recipe_list_screen.dart`, `lib/features/recipes/recipe_form_screen.dart`
```

#### Change 2: Maintenance Forward-Fill

**Location:** "Important notes" section (around line 117-133)

**Add new note:**
```markdown
- **Maintenance forward-fill**: `MaintenanceCalculator.calculate()` assumes the oldest logged weight for all dates before the first weight entry. This ensures new users with sparse early data can get maintenance estimates. Example: If you onboard at 190 lbs on May 16, the algorithm assumes you were 190 lbs for all dates in the 30-day window before May 16. If you delete the May 16 weight, the assumption shifts to the new oldest weight. File: `lib/core/algorithms/maintenance_calculator.dart:57-78`
```

#### Change 3: Unit Filtering

**Location:** "Design rules" section (after recipe management subsection)

**Add new subsection:**
```markdown
### Unit filtering for imported foods

- **OpenFoodFacts imports**: `ServingSizePicker` filters unit dropdown to `[parsedUnit, 'Custom…']` when `source == 'open_food_facts'`. This prevents users from selecting nonsensical units (e.g., "cups" for a food defined per 100g).
- **Manual foods**: Show all 11 common units (`g`, `ml`, `fl oz`, `oz`, `cups`, `tbsp`, `tsp`, `slices`, `pieces`, `bars`, `servings`) plus custom option.
- **Rationale**: Imported foods have macros defined per a specific unit from the API. Allowing arbitrary unit changes without conversion would confuse users about serving sizes.
- File: `lib/features/logging/widgets/serving_size_picker.dart:56-63`
```

#### Change 4: Recipe Edit Bug Fix

**Location:** "Important notes" section (after maintenance forward-fill note)

**Add new note:**
```markdown
- **Recipe edit bug fix**: When editing a recipe, the save logic re-inserts ingredients after deleting them. Previously, ingredients were deleted but not re-inserted, causing zero macros. File: `lib/features/recipes/recipe_form_screen.dart:204-217`
```

---

## Review Checklist

### Content Accuracy
- [ ] Recipe modes documented correctly (management vs. picker)
- [ ] Recipe edit flow documented (ingredient re-insert)
- [ ] Maintenance forward-fill documented (pre-weight assumption)
- [ ] Unit filtering documented (OpenFoodFacts vs. manual)
- [ ] All file paths exist and are correct
- [ ] All line numbers are within ±5 of actual location

### Formatting
- [ ] Markdown syntax correct (no broken links or formatting)
- [ ] Consistent with existing AGENTS.md style
- [ ] Code blocks use correct language hints
- [ ] Tables align properly

### Completeness
- [ ] All tickets #1-4 documented
- [ ] No implementation details omitted that would confuse future developers
- [ ] Edge cases documented where relevant
- [ ] Cross-references to other sections added where helpful

---

## Definition of Done

- [ ] AGENTS.md updated with all four sections
- [ ] File paths verified (files exist)
- [ ] Line numbers verified (within ±5 lines)
- [ ] No typos or grammatical errors
- [ ] Formatting consistent with existing style
- [ ] Reviewed against implemented code (tickets #1-4)
- [ ] `flutter analyze` still passes (no code changes, docs only)

---

## Dependencies

- Tickets #1-4 must be complete (documenting implemented behavior)

---

## References

- Discovery report: `DISCOVERY.md`
- Tickets:
  - `tickets/001-bug-recipe-macros-zeroes.md`
  - `tickets/002-feature-maintenance-preweight-assumption.md`
  - `tickets/003-ux-filter-units-openfoodfacts.md`
  - `tickets/004-ux-recipe-discoverability.md`
- Related files:
  - `AGENTS.md`
  - `lib/features/recipes/recipe_list_screen.dart`
  - `lib/features/recipes/recipe_form_screen.dart`
  - `lib/core/algorithms/maintenance_calculator.dart`
  - `lib/features/logging/widgets/serving_size_picker.dart`

---

## Notes

**AGENTS.md Purpose:**
This file is used by both human developers and AI agents (like opencode) to understand the codebase structure, conventions, and important behaviors. Accuracy is critical — incorrect documentation will propagate to future AI-assisted development.

**Update Strategy:**
- Make incremental changes (one section at a time)
- Verify each change against implemented code
- Don't restructure existing sections (only add/modify content)
- Keep line number references up-to-date (they drift as code changes)

**Post-Update:**
After completing this ticket, run `flutter analyze` to ensure no accidental code changes were introduced (should be docs-only).
