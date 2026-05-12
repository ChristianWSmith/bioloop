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

## Testing

- **Widget — all sections render**: full dashboard scrolls without overflow; calorie ring, macro rings, rate card, maintenance card, sparkline all present
- **Widget — maintenance states**:
  - Loading: shimmer/skeleton visible
  - Null: "Log 14+ days" prompt with X/14 progress
  - Value: "Your maintenance: **2,450 kcal** (±180)"
  - Error: "Unable to calculate — inconsistent data"
- **Widget — rate card**: "~1 lb/week loss" displayed with green text for deficit; "~0.6 lb/week gain" in orange; "Maintenance" in gray
- **Widget — onboarding**: empty state (no food, no weight, no goals) shows "Log your first meal" or setup prompt
- **Widget — data accumulation progression**: add 1 day of food+weight → X/14 increments; at 14+ days → maintenance value appears
- **Golden file — dashboard layout**: capture `DashboardScreen` with known data as a golden image, compare on subsequent runs (requires `flutter test --update-goldens` to regenerate)
- **Integration — full CRUD cycle**: log food → dashboard totals update. Log weight → sparkline updates. Change goals → rate card updates. Full round-trip through DB.

## Human verification

- [ ] `flutter analyze` passes with zero errors
- [ ] Full dashboard renders on real device: all sections visible, scrollable without overflow
- [ ] Maintenance card states:
  - Fresh install: "Log 14+ days" with 0/14 progress
  - After 7 days of data: "7/14" progress
  - After 14+ days: "Your maintenance: 2,450 kcal (±180)"
- [ ] Rate card shows correct text + color for cut/maintain/bulk
- [ ] Empty state (no data at all) shows onboarding message, no broken widgets
- [ ] Log food → dashboard updates immediately (totals, rings)
- [ ] Log weight → sparkline updates
- [ ] Change goals → rate card + macro targets update
- [ ] Golden file test passes (or baseline created with `--update-goldens`)
- [ ] Scroll performance is smooth (no jank from unnecessary rebuilds)
- [ ] Pull-to-refresh on dashboard reloads all data sources

## Dependencies

T11 (macro rings), T12 (weight sparkline), T13 (maintenance), T9 (goals)
