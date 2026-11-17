extends Node
## Ads: REWARDED ADS for LUCKY SPIN (the Polo Points Economy update), and nothing else. The game
## never shows an ad the player didn't ask for, and never in a match.
##
## Backends (picked at startup):
##   * AdMob on Android / iOS   - the Poing Studios "godot-admob-plugin" (Godot 4.5+), when it's
##                                installed AND this platform has a production unit id below.
##                                Debug builds always use Google's official test units.
##   * Test ads in the editor   - TEST AD & SPIN: no network, nothing real, the outcome chosen by
##                                Developer Mode (test_next). Never in an exported game.
##   * none                     - everywhere else: the wheel says ads aren't available.
##
## ONE SESSION AT A TIME. show_rewarded() opens a session with its own id. The reward is paid
## (reward_earned) only when the ad network reports the reward EARNED, once per session, whatever
## order the callbacks come in and however often they repeat. Starting, loading, opening, failing
## or closing early pays nothing, and LuckySpin only spends a spin on a paid reward.
##
## PRODUCTION SECURITY: the session id is made on the device. A real launch should turn on AdMob
## server-side verification (SSV) and pay spins from the server's callback (docs/SPEC.md, 4b).
## Until then `server_verified` is false and the claim is the device's word.

signal reward_earned(txn: String)          # a session's reward: spin now
signal ad_finished(ok: bool, message: String)   # every session ends with exactly one of these
signal availability_changed

## Google's own test units: safe to show any number of times, never pay anyone.
const TEST_UNITS := {"android": "ca-app-pub-3940256099942544/5224354917", "ios": "ca-app-pub-3940256099942544/1712485313"}
## The real rewarded units (AdMob console > Apps > Ad units). Empty: no real ads on that platform.
const PROD_UNITS := {"android": "", "ios": ""}

var backend_name := "none"                 # admob | test | none
var server_verified := false               # true only once rewards come from a server's SSV callback
var _backend = null
var _session := ""                         # the open session's id ("" none)
var _rewarded := {}                        # session id -> true: paid (never twice)
## TEST AD & SPIN (editor): what the next test ad does: "reward", "cancel" (closed early),
## "fail" (failed to show), "none" (no ad loaded).
var test_next := "reward"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var plat := "android" if OS.get_name() == "Android" else ("ios" if OS.get_name() == "iOS" else "")
	var unit := ""
	if plat != "":
		unit = String(TEST_UNITS[plat]) if OS.is_debug_build() else String(PROD_UNITS[plat])
	if plat != "" and unit != "" and _admob_installed():
		_backend = load("res://src/ads/backend_admob.gd").new(self, unit)
		backend_name = "admob"
	elif OS.has_feature("editor"):
		_backend = TestAds.new(self)
		backend_name = "test"
	if _backend != null:
		_backend.start()

static func _admob_installed() -> bool:
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == "RewardedAdLoader":
			return true
	return false

func is_test() -> bool:
	return backend_name == "test"

## Is an ad ready to show right now?
func ad_ready() -> bool:
	return _backend != null and _session == "" and _backend.loaded()

func busy() -> bool:
	return _session != ""

## Shows one rewarded ad. False (nothing happens) when one is already open or none is ready.
func show_rewarded() -> bool:
	if not ad_ready():
		return false
	_session = "ad-%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	_quiet(true)   # (the ad has the speaker; the game's music and sounds wait)
	_backend.show()
	return true

## The game's audio held back while an ad is on screen, and given back after (whatever the ending).
var _was_muted := false
var _quieted := false

func _quiet(on: bool) -> void:
	if on and not _quieted:
		_was_muted = AudioServer.is_bus_mute(0)
		AudioServer.set_bus_mute(0, true)
		_quieted = true
	elif not on and _quieted:
		AudioServer.set_bus_mute(0, _was_muted)
		_quieted = false

# ------------------------------------------------------------------ backend callbacks
## The network says the player earned the reward.
func _on_earned() -> void:
	if _session == "" or _rewarded.has(_session):
		return   # (a repeated callback, or one with no session: nothing)
	_rewarded[_session] = true
	reward_earned.emit(_session)

## The ad closed (watched or not).
func _on_closed() -> void:
	if _session == "":
		return
	var paid := _rewarded.has(_session)
	_session = ""
	_quiet(false)
	ad_finished.emit(paid, "" if paid else "The ad was closed before the reward. No spin was used.")
	availability_changed.emit()

## The ad couldn't be shown.
func _on_failed(message: String) -> void:
	if _session == "":
		return
	var paid := _rewarded.has(_session)
	_session = ""
	_quiet(false)
	ad_finished.emit(paid, "" if paid else (message if message != "" else "No ad is available right now. No spin was used."))
	availability_changed.emit()

func _on_availability() -> void:
	availability_changed.emit()

## The editor's test ads: the outcome is test_next, after a short wait. No network, nothing real.
class TestAds extends RefCounted:
	var ads: Node
	func _init(p: Node) -> void:
		ads = p
	func start() -> void:
		pass
	func loaded() -> bool:
		return ads.test_next != "none"
	func show() -> void:
		await ads.get_tree().create_timer(0.6).timeout
		match ads.test_next:
			"reward":
				ads._on_earned()
				ads._on_earned()   # (networks can repeat themselves: proves it pays once)
				ads._on_closed()
			"cancel":
				ads._on_closed()
			_:
				ads._on_failed("TEST: the ad failed to show.")
