# App Store submission checklist

## Accounts
- [ ] Apple Developer Program active. Paid Apps agreement, tax and banking done.
- [ ] Bundle ID registered (Certificates, Identifiers & Profiles) with the In-App Purchase capability.
- [ ] AdMob account, iOS app, Rewarded unit, consent messages published, app-ads.txt live.

## Code / config (in this repo)
- [ ] `export_presets.cfg` iOS: your bundle id and Team ID. `short_version` (e.g. 1.0.0) and `version` (build number) bumped for each upload.
- [ ] `Ads.PROD_UNITS.ios` set. AdMob App ID set in the plugin's project settings.
- [ ] `AppConfig.PRIVACY_POLICY_URL` (and `SUPPORT_URL`) set to the published pages.
- [ ] godot-iap and AdMob plugins installed and enabled. `addons/` is in the iOS export.
- [ ] Bundle id and Team ID placeholders replaced (`com.CHANGEME.pixelpolo`, empty team).
- [ ] `--test app_store` passes on the Mac.

## App Store Connect
- [ ] New app: name "Pixel Polo: Water Polo Dynasty", primary language English (U.S.), the bundle id, SKU.
- [ ] Pricing: Free (with in-app purchases). Availability: the countries you choose.
- [ ] In-App Purchases: all 8 products (IN_APP_PURCHASES.md), each with a review screenshot, all
      "Ready to Submit", and attached to the version.
- [ ] App Privacy: privacy policy URL, plus the data types from PRIVACY_AND_COMPLIANCE.md.
- [ ] Age rating questionnaire.
- [ ] Version page: screenshots (6.9"), description, keywords, support URL, promotional text, copyright.
- [ ] App Review Information: contact details, and notes such as: "No login required. Polo Points Shop
      is under the gold coin chip. Lucky Spin uses rewarded ads (consent shown first in regulated
      regions). Restore Purchases is at the bottom of the shop."
- [ ] Export compliance: no non-exempt encryption (Info.plist answers it).

## Build
- [ ] `tools/build_ios_release.sh`, then Xcode Archive, then upload (Xcode 26+).
- [ ] TestFlight: internal testing passes TESTFLIGHT_CHECKLIST.md.
- [ ] RELEASE_VERIFICATION.md all ticked.
- [ ] Select the build on the version and Submit for Review. Choose manual or automatic release.
