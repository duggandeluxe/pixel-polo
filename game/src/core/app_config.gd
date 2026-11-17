class_name AppConfig
extends RefCounted
## Release configuration that comes from outside the game: public URLs only. NEVER put secrets
## here (no API keys, no App Store Connect keys, no shared secrets): everything in this file ships
## inside the app and can be read by anyone.
##
## Fill these in once the pages are actually published (see app_store_release/OUTSTANDING_SETUP.md).
## The AdMob ad-unit ids live in Ads.PROD_UNITS; the In-App Purchase product ids in Store.PRODUCTS.

## The published privacy policy (the same URL goes in App Store Connect > App Privacy).
## Empty: the Settings PRIVACY button is hidden in release builds.
const PRIVACY_POLICY_URL := ""
## The support page / contact URL (App Store Connect requires a Support URL).
const SUPPORT_URL := ""

## MULTIPLAYER (Wi-Fi, Bluetooth, online): hidden in release builds for v1.0. Its screens can't be
## opened (Game.goto sends them to the title) and no networking ever starts, so the app asks for
## no Local Network or Bluetooth permission. Development builds keep it, for work on it. To ship it
## later: deploy the relay (NetConfig.RELAY_URL), build/test the BLE plugin, put a menu entry back,
## re-enable plugins/retropolo-ble and NSLocalNetworkUsageDescription in the iOS preset, update the
## privacy label/policy, and set this true.
const MULTIPLAYER_IN_RELEASE := false
const MULTIPLAYER_SCREENS := ["multiplayer", "mp_match"]

static func multiplayer_enabled() -> bool:
	return MULTIPLAYER_IN_RELEASE or DevGate.allowed()

static func has_privacy_policy() -> bool:
	return PRIVACY_POLICY_URL.begins_with("https://")
