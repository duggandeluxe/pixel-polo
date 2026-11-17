# Privacy and App Review compliance

## What the game itself collects

Audited from the code (`game/src`). There are **no analytics, crash reporters, accounts, logins,
sign-in, email, contacts, location, camera, microphone or photos**.

| Data | Where | Leaves the phone? |
|---|---|---|
| Dynasties, settings, Road to Glory profile | `user://` (app sandbox) | No |
| Polo Points, unlocks, purchase receipts (product id, transaction id, time) | `user://store.cfg` | No. Apple processes the payment; the game never sees payment details. |
| Multiplayer | **Hidden in v1.0 release builds**: no networking starts | No |
| Ad interactions, device data | **Google Mobile Ads SDK** (when installed) | Yes, to Google |

## App Store privacy label (App Store Connect > App Privacy)

**If AdMob is included, without tracking (this build's default):**
- Data collected by third-party partners counts as yours. Using Google's own guidance
  ("Prepare for Apple's App Store data disclosure requirements", AdMob help), typically declare:
  **Identifiers: Device ID** (IDFV), **Usage Data: Product Interaction, Advertising Data**,
  **Diagnostics: Crash Data, Performance Data**, **Location: Coarse Location** (IP-derived). Purposes:
  Third-Party Advertising, Analytics. **Not used to track you** (no IDFA).
  Re-check Google's current list for the SDK version you install.
- If you turn on tracking (ADS.md), Device ID and Advertising Data become "Used to Track You".

**Without AdMob:** "Data Not Collected". (Multiplayer is hidden in v1.0. If you ship the online
relay later, add **User Content: Gameplay Content** and the nickname.)

## Manifests and required-reason APIs

- Godot generates the app's `PrivacyInfo.xcprivacy` from the iOS preset's `privacy/*` options.
  The required-reason entries for file timestamps, system boot time, disk space and user defaults
  are Godot's defaults for its engine code.
- The game's own code collects nothing, so `privacy/collected_data/*` stays empty. The label
  above lives in App Store Connect.
- Google Mobile Ads and UMP ship their own privacy manifests in current versions. Confirm them in
  Xcode's privacy report after archiving (IOS_BUILD.md §6).
- v1.0 requests **no permissions at all**. The Bluetooth plugin is off in the iOS preset, there's
  no Local Network usage string, and camera, microphone and photos are empty. (The ATT prompt
  appears only if you choose tracking: ADS.md.)

## Export compliance

`ITSAppUsesNonExemptEncryption=false` is in Info.plist. The game uses only standard HTTPS/TLS
(AdMob, StoreKit and the optional relay over `wss://`), which is exempt. Confirm this answer
yourself in App Store Connect.

## App Review Guidelines: things checked and risks

| Guideline | Status |
|---|---|
| 3.1.1 IAP for digital goods | All real-money items go through StoreKit. No external payment links. |
| 3.1.1 Restore | RESTORE PURCHASES button in the Polo Points Shop. |
| 3.1.1 Randomized rewards | The Lucky Spin isn't sold. It's ad-funded, and its odds are shown on the wheel panel. |
| 5.1.1 Privacy policy | Settings > PRIVACY opens it **once `AppConfig.PRIVACY_POLICY_URL` is set**. It's also required in App Store Connect. |
| 5.1.2 / ATT | No tracking by default. If you enable it, ATT comes through UMP. |
| 2.1 Completeness | Multiplayer is hidden in release builds. **Remaining risk:** the shop is unavailable until the IAP plugin is installed and the products exist. |
| 2.3 Accurate metadata | Product descriptions must state the current Polo Points amounts (IN_APP_PURCHASES.md). Screenshots must be real gameplay. |
| 2.5.2 / debug features | Developer tools, labs, test store, test ads and the `--test` harness are unreachable in release builds (`DevGate.allowed()`, tested). |
| 4.1 Copycats / naming | All schools and players are fictional. Do a trademark check on "Pixel Polo". |
| 5.1.1(v) Account deletion | Not applicable (no accounts). |

## Secrets

No API keys, private keys or credentials are in the code (scanned by `--test app_store`). AdMob
unit and app ids and IAP product ids are public identifiers, not secrets. Never commit
`.p8`/`.p12`/provisioning profiles; `.gitignore` already excludes them.

## Release logging

Release builds keep Godot's default logging. The game prints almost nothing: one result line in
multiplayer and engine warnings. No personal data is logged.
