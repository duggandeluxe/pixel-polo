extends RefCounted
## AdMob rewarded ads through the Poing Studios godot-admob-plugin (Godot 4.5+;
## https://github.com/poingstudios/godot-admob-plugin). Ads loads this only when the plugin's
## classes exist, so this file reaches them by name (_cls) and still parses without the plugin.
##
## Order: the consent check (Google's User Messaging Platform) -> MobileAds.initialize() -> load one
## rewarded ad -> show it when asked -> after it closes, destroy it and load the next.
## UNTESTED ON A DEVICE (the plugin isn't installed in this project yet). Every plugin API used
## here is from the plugin's published docs (ad_formats/rewarded, privacy/user_messaging_tools,
## reference/classes/ConsentInformation), checked 2026-11-16 against the "latest" docs (Godot 4.5+).

var ads: Node
var unit := ""
var _ad = null              # the loaded RewardedAd
var _loading := false
var _started := false

func _init(p_ads: Node, p_unit: String) -> void:
	ads = p_ads
	unit = p_unit

## A plugin class by name (null when missing).
static func _cls(name: String):
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == name:
			return load(String(c.path))
	return null

## Consent first, then ads. Google's User Messaging Platform (UMP) through the plugin, exactly as
## its docs give it (privacy/user_messaging_tools/get_started and reference/classes/ConsentInformation):
##   UserMessagingPlatform.consent_information.update(params, on_success, on_failure)
##   consent_information.get_is_consent_form_available() / get_consent_status()
##   UserMessagingPlatform.load_consent_form(on_loaded(form), on_failure) -> form.show(on_dismissed)
## Ads are requested only when the status is NOT_REQUIRED or OBTAINED. Without a decision (UNKNOWN,
## REQUIRED and dismissed, or the update failing) no ad is requested: the wheel says no ad is
## available, and the next app start asks again.
## If the IDFA explainer message is published in AdMob (Privacy & messaging) and
## NSUserTrackingUsageDescription is in Info.plist, the UMP form also shows Apple's App Tracking
## Transparency prompt (privacy/user_messaging_tools/idfa_support). Without them there is no ATT
## prompt and AdMob serves ads without the IDFA.
const STATUS_NOT_REQUIRED := 1   # ConsentInformation.ConsentStatus (plugin docs: UNKNOWN 0,
const STATUS_OBTAINED := 3       # NOT_REQUIRED 1, REQUIRED 2, OBTAINED 3)
const STATUS_REQUIRED := 2

func _ump():
	var u = _cls("UserMessagingPlatform")
	return u

func start() -> void:
	var ump = _ump()
	var params_cls = _cls("ConsentRequestParameters")
	if ump == null or params_cls == null:
		# a plugin without UMP: ads can't be shown without a consent decision in regions that need
		# one, so none are requested
		push_warning("Ads: the AdMob plugin's User Messaging Platform wasn't found; no ads requested.")
		return
	var params = params_cls.new()
	params.tag_for_under_age_of_consent = false
	ump.consent_information.update(params, _on_consent_info, func(_err): _after_consent())

func _on_consent_info() -> void:
	var ump = _ump()
	var ci = ump.consent_information
	if ci.get_is_consent_form_available() and int(ci.get_consent_status()) == STATUS_REQUIRED:
		ump.load_consent_form(func(form):
			form.show(func(_err): _after_consent()),
			func(_err): _after_consent())
		return
	_after_consent()

func _consent_ok() -> bool:
	var ump = _ump()
	if ump == null:
		return false
	var st := int(ump.consent_information.get_consent_status())
	return st == STATUS_NOT_REQUIRED or st == STATUS_OBTAINED

func _after_consent() -> void:
	if not _consent_ok():
		return   # (no consent decision allowing ads: the wheel says ads aren't available)
	_init_ads()

func _init_ads() -> void:
	if not _started:
		_started = true
		_cls("MobileAds").initialize()
	_load()

func loaded() -> bool:
	return _ad != null

func _load() -> void:
	if _loading or _ad != null:
		return
	_loading = true
	var cb = _cls("RewardedAdLoadCallback").new()
	cb.on_ad_failed_to_load = func(_err):
		_loading = false
		ads._on_availability()
		ads.get_tree().create_timer(30.0).timeout.connect(_load)   # (try again later, quietly)
	cb.on_ad_loaded = func(ad):
		_loading = false
		_ad = ad
		ads._on_availability()
	_cls("RewardedAdLoader").new().load(unit, _cls("AdRequest").new(), cb)

func show() -> void:
	if _ad == null:
		ads._on_failed("")
		return
	var fs = _cls("FullScreenContentCallback").new()
	fs.on_ad_dismissed_full_screen_content = func():
		ads._on_closed()
		_drop()
	fs.on_ad_failed_to_show_full_screen_content = func(_err):
		ads._on_failed("")
		_drop()
	_ad.full_screen_content_callback = fs
	# SSV: the session id rides along to the server's callback, so a backend can pay it (once)
	var ssv_cls = _cls("ServerSideVerificationOptions")
	if ssv_cls != null and _ad.has_method("set_server_side_verification_options"):
		var o = ssv_cls.new()
		o.custom_data = ads._session
		_ad.set_server_side_verification_options(o)
	var earned = _cls("OnUserEarnedRewardListener").new()
	earned.on_user_earned_reward = func(_item): ads._on_earned()
	_ad.show(earned)

func _drop() -> void:
	if _ad != null and _ad.has_method("destroy"):
		_ad.destroy()
	_ad = null
	_load()
