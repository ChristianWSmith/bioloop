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

## Testing

- **Unit — scan → API lookup**: a detected barcode "3017620422003" calls `OpenFoodFactsClient.getByBarcode("3017620422003")`
- **Unit — unknown barcode**: API returns null → shows "Unknown barcode" UI with manual entry button
- **Widget — permission denied**: camera permission denied → shows "Camera access required" message with settings button
- **Widget — successful scan → log flow**: after scan returns a product, user can adjust servings and log it (same flow as T6)
- **Widget — scanner overlay**: viewfinder rectangle renders with correct aspect ratio
- **Note**: camera-based tests require a device/emulator — skip in CI with `test.skip = true` guard for platform test mode

## Human verification

- [ ] `flutter analyze` passes with zero errors
- [ ] Build and install on Android/iOS device, tap the barcode icon — camera permission prompt appears
- [ ] Grant permission — camera opens with viewfinder overlay
- [ ] Scan a known barcode (find one on a packaged food) — product resolves, serving adjustment screen appears
- [ ] Result proceeds through the standard log flow (meal type, save)
- [ ] Unknown barcode: try scanning something without a food entry — shows "Not found" with "Enter manually" button
- [ ] Deny permission — shows "Camera access required" with a button to settings
- [ ] Web platform: shows unsupported message gracefully (no crash)
- [ ] Cached result: first scan hits API, second scan of same barcode uses local cache (fast)
- [ ] All unit tests pass

## Dependencies

T3 (API client), T6 (log flow)
