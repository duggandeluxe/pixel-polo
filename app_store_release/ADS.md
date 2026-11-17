# Rewarded ads (Lucky Spin)

The wheel, its odds (8 × 5 PP, 2 × 10 PP, 1 × 15 PP, shown in the panel), 2 spins per 6 hours,
and its look are unchanged. Ads appear **only** when the player taps the spin button in the Polo
Points Shop: never in a match, never unprompted.

## How it behaves (`src/autoload/ads.gd`, `src/ads/backend_admob.gd`)

- One ad session at a time. The spin is paid **only** on AdMob's `on_user_earned_reward`, once per
  session, however often the callback repeats. Opening, failing or closing early pays nothing
  ("The ad was closed before the reward. No spin was used.") and doesn't use up a spin.
- No ad loaded: the wheel says no ad is available. Loading retries quietly every 30 s.
- The game's audio is muted while an ad plays and restored afterwards, whatever the outcome.
- **Debug builds always use Google's test unit** (`ca-app-pub-3940256099942544/1712485313`).
  Release builds use `Ads.PROD_UNITS.ios`. While that's empty, release builds show no ads at all.
- In the editor, "TEST AD & SPIN" simulates every outcome with its own wallet. It never exists in
  an exported game.

## Consent (required before any ad is requested)

Uses Google's User Messaging Platform through the plugin, as its docs specify:
`UserMessagingPlatform.consent_information.update(...)` at every launch, then the consent form if
the status is REQUIRED. Ads are requested only when the status is **NOT_REQUIRED** or **OBTAINED**.
Configure the messages in AdMob > Privacy & messaging (GDPR, US state regulations).

> This replaced an earlier version of the consent code that used class names the plugin doesn't
> have (`OnConsentInfoUpdateListener`, `request_consent_info_update`), which would have failed at
> runtime.

## Tracking (App Tracking Transparency): your decision

**Default in this build: no tracking.** No `NSUserTrackingUsageDescription` and no ATT prompt.
`privacy/tracking_enabled=false`. AdMob then can't read the IDFA and serves less-targeted ads
(lower revenue). This is the simplest path through review.

To use personalized ads instead:
1. AdMob > Privacy & messaging > create and publish an **IDFA explainer** message. The UMP form then
   shows Apple's ATT prompt after it.
2. Add to the iOS preset's `application/additional_plist_content`:
   `<key>NSUserTrackingUsageDescription</key><string>This identifier will be used to deliver personalized ads to you.</string>`
3. Link `AppTrackingTransparency.framework` in Xcode (per the plugin's IDFA guide).
4. Set `privacy/tracking_enabled=true` and fill in `privacy/tracking_domains`.
5. Update the privacy label ("Used to Track You") and the privacy policy.

## Setup steps

See IOS_BUILD.md step 3 and OUTSTANDING_SETUP.md items 8–10. Test on a real iPhone with the test
unit first. `backend_admob.gd` has not yet run against the real SDK.

## Not built: server-side verification

The reward is decided on the device. A changed system clock or a modified app could get extra
spins (they only give a few Polo Points). To make it authoritative, enable AdMob SSV and pay spins
from a small server (docs/SPEC.md §4b). The backend already passes the session id as SSV `custom_data`.
