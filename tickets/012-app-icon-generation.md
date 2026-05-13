# 012 — Generate and apply custom app icon

- **Phase**: 4 — Polish
- **Priority**: Medium

## Overview

The app icon is configured in `pubspec.yaml` via `flutter_launcher_icons`, but the package is not installed as a dev dependency. The existing mipmap `ic_launcher.png` files are default Flutter placeholders (442–1443 bytes), not the custom icon. The source icon exists at `assets/icon/app_icon.png` (278 KB). Modern Android adaptive icons are also missing.

## Context from Discovery

- `pubspec.yaml` lines 24–28:
  ```yaml
  flutter_launcher_icons:
    android: true
    ios: true
    image_path: "assets/icon/app_icon.png"
    min_sdk_android: 21
  ```
- `flutter_launcher_icons` is NOT listed in `dev_dependencies`.
- Android manifest (`AndroidManifest.xml:6`): `android:icon="@mipmap/ic_launcher"` — correctly references mipmap.
- Existing mipmap files are 8-bit colormap PNGs, 48–192px, clearly default Flutter icons (442–1443 bytes).
- No `mipmap-anydpi-v26/` directory exists (required for adaptive icons on Android 8+).
- Asset exists at `assets/icon/app_icon.png` (278 KB, presumably the real custom icon).

## Steps

1. Add `flutter_launcher_icons: ^0.14.3` to `dev_dependencies` in `pubspec.yaml`.
2. Run `dart run flutter_launcher_icons` to generate:
   - All density-specific `ic_launcher.png` files from the source asset
   - Adaptive icon files in `mipmap-anydpi-v26/` (`ic_launcher.xml`, `ic_launcher_foreground.png`, background)

## Files to Modify

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `flutter_launcher_icons: ^0.14.3` to `dev_dependencies` |

Additionally, running the generator will modify/create files under `android/app/src/main/res/`.

## Acceptance Criteria

- [ ] `flutter_launcher_icons` is in `dev_dependencies`
- [ ] Running `dart run flutter_launcher_icons` completes without error
- [ ] All mipmap `ic_launcher.png` files are replaced with generated versions of the source icon
- [ ] `mipmap-anydpi-v26/` directory exists with adaptive icon files (`ic_launcher.xml`, foreground, background)
- [ ] Building and installing the APK shows the custom icon in the app launcher
- [ ] `flutter analyze` passes with zero errors
- [ ] Existing tests pass
