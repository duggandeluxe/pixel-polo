# Outstanding setup (only you can do these)

Nothing below has been done. None of it can be done from the code.

## Blockers: the app can't be submitted without these

1. **Apple Developer Program** membership ($99/year), plus the **Paid Apps agreement**, tax and
   banking in App Store Connect (Business). In-app purchases don't work in TestFlight or
   production until the agreement is active.
2. **Your own bundle identifier and Team ID.** The old project's values were removed. The presets
   now hold placeholders, which won't build until you replace them:
   - iOS preset: `application/bundle_identifier="com.CHANGEME.pixelpolo"`. Use your own reverse-DNS
     id, for example `com.<yourname>.pixelpolo`. It can't be changed after the first upload.
   - iOS preset: `application/app_store_team_id=""`. Enter your 10-character Team ID
     (developer.apple.com > Account > Membership details).
   - Android preset: `package/unique_name="com.CHANGEME.pixelpolo"` (only if you ship Android).
   `tools/ios_add_pack_phase.py` reads the bundle id from the preset, so there's nothing else to change.
3. **A Mac with Xcode 26 or later.** Since 28 April 2026 App Store Connect only accepts builds made
   with the iOS 26 SDK. Also Godot 4.7.2 for macOS, with the 4.7.2 iOS export templates.
4. **Install the two plugins** (IOS_BUILD.md, steps 2–3). Without them the shop says "The store
   isn't available right now" and the Lucky Spin says no ad is available. That's honest, but a
   reviewer will reject a shop that can't sell anything.
5. **Create the in-app purchase products** in App Store Connect with the exact ids in
   IN_APP_PURCHASES.md, and attach them to the first version you submit.
6. **Publish a privacy policy** (start from PRIVACY_POLICY_DRAFT.md, have it reviewed). Then put
   its URL in `game/src/core/app_config.gd` (`PRIVACY_POLICY_URL`) and in App Store Connect. The
   Settings PRIVACY button stays hidden in release builds until the URL is set.
7. **A Support URL** (App Store Connect requires one). Optionally also set `AppConfig.SUPPORT_URL`.

## Needed for ads (the Lucky Spin) to work

8. A **Google AdMob account**, an iOS app in it, and one **Rewarded** ad unit. Put the unit id in
   `Ads.PROD_UNITS.ios` (`game/src/autoload/ads.gd`). Put the **App ID** (the one with a `~`) in the
   plugin's project settings (ADS.md).
9. In AdMob > Privacy & messaging: publish the **GDPR** and **US state regulations** messages. Add
   the **IDFA explainer** only if you choose personalized ads (ADS.md, "Tracking").
10. An **app-ads.txt** file on the developer website you list in App Store Connect.

## Decisions for you

- **Personalized ads (tracking) or not.** The default here is *no tracking*: no App Tracking
  Transparency prompt, and AdMob serves ads without the IDFA. Choosing tracking changes the
  privacy label, Info.plist and the export preset (ADS.md).
- **Multiplayer: hidden for v1.0 (decided).** Release builds can't open the multiplayer screens
  and never start networking. The iOS build carries no Bluetooth plugin and no Local Network
  permission. Development builds keep it. Steps to ship it later are in
  `game/src/core/app_config.gd` (`MULTIPLAYER_IN_RELEASE`).
- **Languages to list.** The game has 50 machine-translated catalogs (written by Claude subagents,
  not reviewed by native speakers). App Store Connect lists only the localizations you add there.
  To avoid advertising unreviewed languages, add metadata only for the ones you trust (English
  for v1.0). In-game, the phone's language is still picked automatically.
- **Age rating questionnaire:** answer it honestly (it asks about in-app purchases, ads and
  randomized rewards; the Lucky Spin is ad-funded, not bought).
- **Name check:** search the App Store and trademarks for "Pixel Polo" before submitting.

## Device testing only you can do

TestFlight on at least one small iPhone (SE / mini class) and one Dynamic Island model:
TESTFLIGHT_CHECKLIST.md.
