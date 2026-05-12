# T14 — Dashboard: full integration

Polish the dashboard into the final layout with all components.

## Files to modify

- `lib/features/dashboard/dashboard_screen.dart` — final layout
- `lib/features/dashboard/widgets/maintenance_card.dart` — maintenance display card

## Layout (top to bottom)

1. **Greeting + date header** — "Today, May 11"
2. **Calorie ring** — large, center of screen (from T11)
3. **Macro rings row** — protein, fat, carbs (from T11)
4. **Rate card** — "On track to lose ~1 lb/week" (reads from goals)
5. **Maintenance card** — computed maintenance or onboarding prompt (from T13)
6. **Bodyweight sparkline** — compact line chart (from T12)

## Maintenance card states

| State | Display |
|-------|---------|
| Loading | Skeleton shimmer |
| Insufficient data | Card: "Log 14+ days of food + weight to calculate your maintenance" with progress indicator (X/14) |
| Data ready | "Your maintenance: **2,450 kcal** (±180)" + data points count |
| Error | "Unable to calculate — inconsistent data" |

## Rate card

- Reads `goalType` and `calorieAdjustment` from goals provider
- Computes `rateLbsPerWeek`
- Display: *"~1 lb/week loss"* or *"~0.6 lb/week gain"* or *"Maintenance"*
- Color: green (cut/on track), red (over), gray (maintain)

## Acceptance criteria

- All sections render together without layout overflow or scroll issues
- Maintenance card transitions between states as data accumulates
- Rate card updates when goals change
- Empty state (no food, no weight) shows a helpful onboarding message
- Scrollable if content exceeds viewport

## Dependencies

T11 (macro rings), T12 (weight sparkline), T13 (maintenance), T9 (goals)
