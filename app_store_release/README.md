# Pixel Polo: Water Polo Dynasty — App Store release kit

Everything needed to take the game from this repository to the App Store. Read it in this order:

| # | File | What it's for |
|---|------|---------------|
| 1 | [OUTSTANDING_SETUP.md](OUTSTANDING_SETUP.md) | **What only you can do** (accounts, ids, URLs, signing). Start here. |
| 2 | [IOS_BUILD.md](IOS_BUILD.md) | Installing the two plugins, exporting from Godot, archiving in Xcode |
| 3 | [IN_APP_PURCHASES.md](IN_APP_PURCHASES.md) | The products to create in App Store Connect, and how the game handles them |
| 4 | [ADS.md](ADS.md) | AdMob rewarded ads for the Lucky Spin, consent, App Tracking Transparency |
| 5 | [PRIVACY_AND_COMPLIANCE.md](PRIVACY_AND_COMPLIANCE.md) | Data audit, privacy "nutrition label" answers, manifests, review-guideline risks |
| 6 | [PRIVACY_POLICY_DRAFT.md](PRIVACY_POLICY_DRAFT.md) | A draft policy that matches the code. Not published anywhere yet. |
| 7 | [STORE_LISTING.md](STORE_LISTING.md) | Name, subtitle, description, keywords, screenshot requirements |
| 8 | [TESTFLIGHT_CHECKLIST.md](TESTFLIGHT_CHECKLIST.md) | What to test on a real iPhone |
| 9 | [SUBMISSION_CHECKLIST.md](SUBMISSION_CHECKLIST.md) | App Store Connect, step by step |
| 10 | [RELEASE_VERIFICATION.md](RELEASE_VERIFICATION.md) | The final pass before pressing Submit |

## Status (2026-11-16)

**Built and checked on Windows** (headless Godot 4.7.2, `--test app_store`: 74 checks, 0 failed):
crash-safe saves with fallback, saving on backgrounding, release lockdown of developer tools, the
purchase flow against a stand-in plugin, the rewarded-ad session rules, and the iOS export config.

**Not done, because it can't be done on Windows:** no iOS build has been made. Nothing has run on an
iPhone. Neither plugin (godot-iap, AdMob) is installed in the project, so the StoreKit and AdMob
code paths have never talked to the real SDKs. Treat both integrations as **written to the plugins'
published APIs, but unproven** until TestFlight.
