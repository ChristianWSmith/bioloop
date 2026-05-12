# T12 — Dashboard: bodyweight chart

Line chart showing recent bodyweight data on the dashboard.

## Files to create

- `lib/features/dashboard/widgets/bodyweight_sparkline.dart`

## Specification

- Line chart using `fl_chart` (`LineChart`)
- X-axis: last 30 days
- Y-axis: weight in kg
- Plot logged data points; connect with lines
- Touch tooltip shows date + weight
- Compact size (fits in ~200px height card)
- Shows as a card on the dashboard below macro rings

## Acceptance criteria

- Chart renders with real bodyweight data
- Multiple data points connected correctly
- Empty state when no weight data logged (show "Log your first weight" prompt)
- Tapping a point shows tooltip

## Dependencies

T7 (bodyweight entries), T2 (dashboard placeholder)

Note: `fl_chart` must be added to `pubspec.yaml`.
