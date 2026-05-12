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

## Testing

- **Widget — renders data**: insert 10 bodyweight entries over 30 days, chart renders with visible line and correct axis range
- **Widget — single point**: 1 data point renders as a dot (no line between points)
- **Widget — empty state**: no entries, chart area shows "Log your first weight" text
- **Widget — tooltip**: tap a data point, tooltip appears with date + weight value
- **Widget — responsive**: chart card fits within 200px height without overflow
- **Widget — real-time update**: log a new weight via bodyweight sheet, navigate back to dashboard, chart updates to include new point

Use `fl_chart`'s `LineChart` in the widget; test via `tester.tap(find.byType(LineChart))` for tooltip interaction. Override `bodyweightProvider` with known data.

## Human verification

- [ ] `flutter analyze` passes with zero errors
- [ ] Log 5+ weight entries over 30 days — chart renders with line connecting points, axis labels readable
- [ ] Tap a data point — tooltip shows date + weight
- [ ] Delete a weight entry — chart updates, line re-renders without the deleted point
- [ ] Empty state: no weights logged → chart area shows "Log your first weight" text (no broken chart)
- [ ] Single weight entry renders as a dot (no line renders with 1 point)
- [ ] Chart card fits in ~200px height, scrolls with rest of dashboard
- [ ] All widget tests pass
- [ ] Axis labels handle realistic weight ranges (e.g. 60–100kg) without overlapping

## Dependencies

T7 (bodyweight entries), T2 (dashboard placeholder)

Note: `fl_chart` must be added to `pubspec.yaml`.
