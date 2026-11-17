# iOS build

Godot 4.7.2 · Compatibility renderer (`gl_compatibility`, also on mobile) · arm64 · iOS 15.6+ ·
iPhone only (`application/targeted_device_family=0`) · landscape either way up.

## What's already configured (iOS preset in `game/export_presets.cfg`, and `project.godot`)

| Setting | Value |
|---|---|
| Home-screen name | `Pixel Polo` (`application/config/name.ios`). The store name is set in App Store Connect. `config/name` stays "Retro Polo" because it names the desktop/web save folder. |
| Orientation | `display/window/handheld/orientation=4` (landscape, sensor) |
| Pixel art | `stretch/mode=viewport`, `aspect=expand`, nearest filtering, 2D pixel snapping |
| Launch | No Godot splash image; launch storyboard in the game's navy (`#0f1830`) |
| Icon | `assets/icon/ios_1024_opaque.png`: the existing icon, same pixels, alpha channel removed (App Store Connect rejects icons that have one) |
| Info.plist extras | `ITSAppUsesNonExemptEncryption=false`. No Local Network or Bluetooth permission: multiplayer is hidden for v1.0, and the BLE plugin is off in the iOS preset. |
| Bundle ID / Team ID | **Placeholders**: `com.CHANGEME.pixelpolo` and an empty Team ID. Replace them with yours (OUTSTANDING_SETUP.md item 2). |
| Exported files | Excludes `tests/*`, the editor-only BLE exporter, and the root screenshots. **Keeps `addons/`**, which the IAP and AdMob plugins need. |
| Required-reason APIs | Godot's defaults for file timestamp, boot time, disk space and user defaults. Godot writes `PrivacyInfo.xcprivacy`. |
| Tracking | Off (`privacy/tracking_enabled=false`) |

The Android and Web presets were not changed.

## 1. On the Mac

- Xcode 26 or later (required for uploads since 28 April 2026).
- Godot 4.7.2 (macOS), with the **4.7.2 export templates** (Editor > Manage Export Templates).
- Clone the repo and open `game/` in Godot once, so it imports.

## 2. Install the In-App Purchase plugin (godot-iap)

The maintained OpenIAP plugin: <https://github.com/hyochan/godot-iap>. That repo was archived on
26 April 2026; development continues in <https://github.com/hyodotdev/openiap> (`libraries/godot-iap`).
Use the newest release there.

1. Download the release zip and copy `addons/godot-iap/` into `game/addons/`.
2. Project > Project Settings > Plugins: enable **GodotIap**. This adds the `GodotIapPlugin` autoload,
   which is what the game looks for.
3. Check that `game/addons/godot-iap/types.gd` exists. `backend_openiap.gd` loads it from that path.
   If a newer release moved it, update `TYPES_PATH` there.
4. In Xcode (step 6) add the **In-App Purchase** capability.

The game picks this backend automatically on iOS (`Store._ready`, `backend_name == "openiap"`).

## 3. Install the AdMob plugin (Poing Studios)

<https://github.com/poingstudios/godot-admob-plugin>, docs at
<https://poingstudios.github.io/godot-admob-plugin/latest> (Godot 4.5+).

1. Install it from the Asset Library / Asset Store ("AdMob" by Poing Studios), then enable it in
   Project Settings > Plugins. The iOS libraries download automatically. If they don't, use
   Project > Tools > AdMob Manager > iOS > Download & Install.
2. Project Settings > General > **Admob > General**: tick **iOS Enabled** and enter your **App ID**
   (`ca-app-pub-…~…`).
3. Put your Rewarded **ad unit id** (`ca-app-pub-…/…`) in `Ads.PROD_UNITS.ios`. Debug builds always
   use Google's test unit instead.

## 4. Signing values

In Project > Export > iOS, replace the placeholders: **App Store Team ID** (empty) and **Bundle
Identifier** (`com.CHANGEME.pixelpolo`). Set Export Method (Release) = App Store Connect. The
export fails until both are real.

## 5. Export

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/build_ios_release.sh   # App Store / TestFlight
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/build_ios.sh           # day-to-day debug Run on a cable
```

`build_ios_release.sh` uses `--export-release`. That is the build with no developer tools (`DevGate`),
real AdMob units, and the real App Store.

## 6. Xcode

1. Signing & Capabilities: your team; automatic signing. Add **In-App Purchase**.
2. Open the exported `Info.plist` and confirm the name, the orientations
   (`UIInterfaceOrientationLandscapeLeft/Right` only), `GADApplicationIdentifier` (from the AdMob
   plugin) and `SKAdNetworkItems`. If the AdMob plugin didn't add `SKAdNetworkItems`, add Google's
   list from the AdMob iOS quick-start.
3. Product > Archive, then Distribute App > App Store Connect > Upload.
4. In Organizer, check the privacy report (Archive > Generate Privacy Report). It should show
   Godot's manifest plus Google Mobile Ads / UMP's own.

## Known limits

- The iOS **Simulator can't run it**: Godot 4.7.2's iOS template only ships an x86_64 simulator
  library. Use a real iPhone.
- The Compatibility renderer runs on OpenGL ES on iOS, which Apple has deprecated but still ships.
  Watch for rendering issues on device. Switching to the Mobile renderer (Metal) would need a
  separate visual check of every screen.
