# T15 — Barcode scanning

Camera-based barcode scanning that looks up foods via OpenFoodFacts.

## Files to create

- `lib/features/logging/widgets/barcode_scanner.dart` — camera view + scanner overlay

## Dependencies to add

- `camera` — for camera access
- `mobile_scanner` (wraps MLKit barcode scanning) — simpler than manual MLKit integration

## Flow

1. User taps barcode icon in log screen search bar
2. Camera opens with a viewfinder overlay
3. Detected barcode auto-fires lookup via `OpenFoodFactsClient.getByBarcode()`
4. If found: show the food result, proceed to serving adjustment + log flow
5. If not found: show "Unknown barcode" with option to enter manually
6. On successful log, cache the result in `foods` table for future searches

## Platform setup

- Android: add `<uses-permission android:name="android.permission.CAMERA" />` to `AndroidManifest.xml`
- iOS: add `NSCameraUsageDescription` to `Info.plist`
- Web: show unsupported message

## Acceptance criteria

- Camera opens with permission prompt
- Scanning a known barcode (e.g. Nutella 3017620422003) returns the product
- Result proceeds through the standard log flow
- Unknown barcode shows "Not found" with manual entry fallback
- Permission denied shows helpful message

## Dependencies

T3 (API client), T6 (log flow)
