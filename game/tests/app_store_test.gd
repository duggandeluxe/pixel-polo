extends RefCounted
## App Store readiness: crash-safe saves and their fallback, saving when the app is backgrounded,
## release-build lockdown of the developer tools, rewarded-ad sessions, the OpenIAP purchase flow
## (against a stand-in plugin: success, duplicates, cancel, pending, failure, restore, PRO coins
## once), and the iOS project / export configuration.
##   godot --headless --path game -- --test app_store
## Native StoreKit / AdMob behaviour can only be proven on an iPhone (TestFlight): this checks the
## game's side of every callback.

var r
const DIR := "user://app_store_test/"

func run(runner) -> void:
	r = runner
	print("app store readiness")
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))
	_safe_file()
	await _career_saves()
	await _dev_gate()
	await _ads()
	await _iap()
	_config()

# ------------------------------------------------------------------ SafeFile
func _safe_file() -> void:
	var p := DIR + "thing.json"
	r.check(SafeFile.write_text(p, '{"a": 1}'), "SafeFile writes a file")
	r.check(not FileAccess.file_exists(p + SafeFile.TMP), "no .tmp is left behind")
	SafeFile.write_text(p, '{"a": 2}')
	r.check(FileAccess.get_file_as_string(p + SafeFile.PREV) == '{"a": 1}', "the replaced file is kept as .prev")
	# a torn write (what a crash in a non-atomic save would leave)
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string('{"a": ')
	f.close()
	var used: Array = []
	r.check(SafeFile.read_text(p, true, used) == '{"a": 1}' and not used.is_empty(), "a damaged file falls back to its previous copy")
	var cfg := DIR + "store_like.cfg"
	var cf := ConfigFile.new()
	cf.set_value("s", "vault", 120)
	SafeFile.save_config(cf, cfg)
	cf.set_value("s", "vault", 180)
	SafeFile.save_config(cf, cfg)
	var torn := FileAccess.open(cfg, FileAccess.WRITE)
	torn.store_string("[s]\nvault=")
	torn.close()
	var back := ConfigFile.new()
	r.check(SafeFile.load_config(back, cfg) == OK and int(back.get_value("s", "vault", -1)) == 120, "a damaged store.cfg-style file falls back to its previous copy")
	SafeFile.remove_all(p)
	r.check(not FileAccess.file_exists(p) and not FileAccess.file_exists(p + SafeFile.PREV), "remove_all removes the file and its .prev")

# ------------------------------------------------------------------ career saves
func _career_saves() -> void:
	var kept_dir := Game.save_dir
	var kept_test := Game.test_mode
	var kept_name := Game.current_name
	var kept_progress := Game.progress
	Game.save_dir = DIR
	Game.test_mode = false
	Game.progress = Progression.fresh()
	Game.career = Career.new_game("HURST", "A", "B", 77)
	Game.slot = 1
	Game.save_career()
	var path := Game.slot_path(1)
	r.check(FileAccess.file_exists(path), "a career saves")
	Game.career.quarter_min = 3
	Game.save_career()
	r.check(FileAccess.file_exists(path + SafeFile.PREV), "the earlier save is kept beside it")
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	# the newest save torn in half: the dynasty still loads, from the one before
	var text := FileAccess.get_file_as_string(path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text.substr(0, text.length() / 2))
	f.close()
	Game.career = null
	r.check(Game.load_career(1) and Game.career != null and Game.career.school == String(good.school), "a damaged save loads from its previous copy")
	r.check(JSON.parse_string(FileAccess.get_file_as_string(path)) is Dictionary, "...and the slot's file is whole again")
	r.check(not Game.slot_summary(1).get("damaged", false), "the slot list doesn't call it a save problem")
	# backgrounded: the dynasty in memory is written at once (not during a match)
	Game.current_name = "hub"
	Game.career.quarter_min = 5
	Game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	r.check(int(JSON.parse_string(FileAccess.get_file_as_string(path)).get("quarter_min", 0)) == 5, "going to the background saves the dynasty")
	Game.current_name = "match"
	Game.career.quarter_min = 2
	Game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	r.check(int(JSON.parse_string(FileAccess.get_file_as_string(path)).get("quarter_min", 0)) == 5, "...but never mid-match (the match pauses itself)")
	Game.delete_slot(1)
	r.check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path + SafeFile.PREV), "deleting a slot removes its previous copy too (a new dynasty can't fall back onto it)")
	Game.career = null
	Game.slot = 0
	Game.save_dir = kept_dir
	Game.test_mode = kept_test
	Game.current_name = kept_name
	Game.progress = kept_progress

# ------------------------------------------------------------------ developer tools
func _dev_gate() -> void:
	DevGate.simulate_release = true
	r.check(not DevGate.try_unlock("8008"), "release: the developer code opens nothing")
	for n in ["dev_settings", "dev_roster", "dev_test_lab", "attr_lab", "coin_lab", "elim_lab"]:
		r.check(DevGate.route(n) == "settings", "release: %s can't be opened" % n)
	r.check(DevGate.route("hub") == "hub" and DevGate.route("store") == "store", "release: normal screens open as before")
	r.check(not AppConfig.multiplayer_enabled(), "release: multiplayer is off for v1.0")
	Game.goto("multiplayer")
	await r.get_tree().process_frame
	r.check(Game.current_name == "title", "release: the multiplayer screen can't be opened")
	Game.goto("mp_match")
	await r.get_tree().process_frame
	r.check(Game.current_name == "title" and Net.t == null, "release: nor a multiplayer match, and no network link is opened")
	var kept: Dictionary = Game.settings.duplicate(true)
	Game.settings.dev_mode = true
	Game.load_settings()
	r.check(not bool(Game.settings.dev_mode), "release: Developer Mode is off whatever the settings file says")
	Game.settings = kept
	Game.goto("settings")
	await r.get_tree().process_frame
	await r.get_tree().process_frame
	r.check(Game.current_screen.find_child("DevButton", true, false) == null, "release: Settings has no DEV button")
	r.check((Game.current_screen.find_child("PrivacyButton", true, false) != null) == AppConfig.has_privacy_policy(), "release: PRIVACY shows only once its URL is set")
	DevGate.simulate_release = false
	Game.goto("settings")
	await r.get_tree().process_frame
	await r.get_tree().process_frame
	r.check(Game.current_screen.find_child("DevButton", true, false) != null, "development build: the DEV button is still there")
	r.check(AppConfig.multiplayer_enabled(), "development build: multiplayer still available for work on it")
	r.check(Game.current_screen.find_child("PrivacyButton", true, false) != null, "development build: PRIVACY is there (says when no URL is set)")
	DevGate.try_unlock("8008")
	r.check(DevGate.route("dev_settings") == "dev_settings", "development build: the right code still opens the DEV screen")
	DevGate.lock()

# ------------------------------------------------------------------ rewarded ads
func _ads() -> void:
	if Ads.backend_name != "test":
		print("  (skipped: the editor's test ads aren't active in this run)")
		return
	var earned := [0]
	var cb := func(_t): earned[0] += 1
	Ads.reward_earned.connect(cb)
	var muted_before := AudioServer.is_bus_mute(0)
	var kept_next := Ads.test_next
	# rewarded: paid exactly once even though the network repeats itself
	Ads.test_next = "reward"
	r.check(Ads.show_rewarded(), "an ad shows")
	r.check(AudioServer.is_bus_mute(0), "the game's audio is held while the ad plays")
	r.check(not Ads.show_rewarded(), "a second ad can't open on top")
	var res = await Ads.ad_finished
	r.check(bool(res[0]) and earned[0] == 1, "earned: one reward, once")
	r.check(AudioServer.is_bus_mute(0) == muted_before, "audio back after the ad")
	# closed early: nothing
	Ads.test_next = "cancel"
	Ads.show_rewarded()
	res = await Ads.ad_finished
	r.check(not bool(res[0]) and earned[0] == 1 and String(res[1]).contains("No spin"), "closed early: no reward, and says so")
	# failed to show: nothing
	Ads.test_next = "fail"
	Ads.show_rewarded()
	res = await Ads.ad_finished
	r.check(not bool(res[0]) and earned[0] == 1 and String(res[1]) != "", "failed: no reward, a message")
	Ads.test_next = "none"
	r.check(not Ads.ad_ready() and not Ads.show_rewarded(), "no ad loaded: nothing opens (the wheel says no ad is available)")
	r.check(AudioServer.is_bus_mute(0) == muted_before, "audio never left muted")
	Ads.test_next = kept_next
	Ads.reward_earned.disconnect(cb)
	r.check(Ads.PROD_UNITS.ios == "" or not OS.is_debug_build() or Ads.TEST_UNITS.ios.begins_with("ca-app-pub-3940256099942544/"), "debug builds use Google's test units")

# ------------------------------------------------------------------ in-app purchases (OpenIAP)
class FakeIap extends Node:
	signal purchase_updated(purchase: Dictionary)
	signal purchase_error(error: Dictionary)
	signal products_fetched(result: Dictionary)
	var requested: Array = []
	var finished: Array = []
	var available: Array = []
	func init_connection() -> bool:
		return true
	func fetch_products(_req) -> Array:
		return [{"id": "pro_unlock", "displayPrice": "7,99 €"}]
	func request_purchase(props) -> void:
		requested.append(props.request.apple.sku if props.request.apple != null else props.request.google.skus[0])
	func finish_transaction_dict(d: Dictionary, consumable: bool):
		finished.append([String(d.get("transactionId", "")), consumable])
		return null
	func restore_purchases():
		return null
	func get_available_purchases() -> Array:
		return available

class FakeTypes extends RefCounted:
	class ProductRequest extends RefCounted:
		var skus: Array = []
		var type := 0
	class RequestPurchaseIOSProps extends RefCounted:
		var sku := ""
	class RequestPurchaseAndroidProps extends RefCounted:
		var skus: Array = []
	class RequestPurchasePropsByPlatforms extends RefCounted:
		var apple = null
		var google = null
	class RequestPurchaseProps extends RefCounted:
		var type := 0
		var request = null

func _iap() -> void:
	var kept_backend = Store._backend
	var kept_name := Store.backend_name
	var kept_prices: Dictionary = Store._prices.duplicate()
	Store.reset_for_tests()
	var fake := FakeIap.new()
	r.add_child(fake)
	var b = load("res://src/store/backend_openiap.gd").new(Store, fake, FakeTypes)
	Store._backend = b
	Store.backend_name = "openiap"
	await b.start(Store.PRODUCTS.keys())
	r.check(Store.available(), "the store connects")
	r.check(Store.price("pro_unlock") == "7,99 €", "prices shown are the store's own (localized)")
	var results: Array = []
	var cb := func(id, ok, msg): results.append([id, ok, msg])
	Store.purchase_finished.connect(cb)
	var pp := func(): return Store.vault
	# a pack: credited once, however often StoreKit repeats it, then finished once
	Store.buy("blue_100")
	await r.get_tree().process_frame
	r.check(fake.requested.has("blue_100"), "BUY asks the store for that product")
	var t1 := {"productId": "blue_100", "transactionId": "t1", "purchaseState": "Purchased"}
	fake.purchase_updated.emit(t1)
	fake.purchase_updated.emit(t1)
	await r.get_tree().process_frame
	r.check(pp.call() == 60, "a pack pays its Polo Points once: %d" % pp.call())
	r.check(fake.finished.filter(func(x): return x[0] == "t1").size() == 1 and fake.finished[0][1] == true, "...and its transaction is finished once, as a consumable")
	r.check(results.any(func(x): return x[0] == "blue_100" and x[1]), "the shop hears it succeeded")
	# the next launch: StoreKit re-delivers t1 (already credited) and an unfinished t2
	fake.purchase_updated.emit(t1)
	fake.purchase_updated.emit({"productId": "blue_100", "transactionId": "t2", "purchaseState": "Purchased"})
	await r.get_tree().process_frame
	r.check(pp.call() == 120, "a re-delivered purchase pays nothing; an undelivered one pays once: %d" % pp.call())
	# canceled
	results.clear()
	Store.buy("blue_350")
	await r.get_tree().process_frame
	fake.purchase_error.emit({"code": "USER_CANCELED", "message": "cancelled"})
	r.check(pp.call() == 120 and results.any(func(x): return x[0] == "blue_350" and not x[1] and x[2] == ""), "canceled: nothing paid, no error message")
	r.check(Store._inflight == "", "...and the shop can buy again")
	# pending (Ask to Buy), approved later
	Store.buy("blue_650")
	await r.get_tree().process_frame
	fake.purchase_updated.emit({"productId": "blue_650", "transactionId": "t3", "purchaseState": "Pending"})
	r.check(pp.call() == 120 and "blue_650" in Store._pending, "pending: nothing paid yet")
	fake.purchase_updated.emit({"productId": "blue_650", "transactionId": "t3", "purchaseState": "Purchased"})
	await r.get_tree().process_frame
	r.check(pp.call() == 470, "approved later: paid once: %d" % pp.call())
	# failed
	results.clear()
	Store.buy("blue_1400")
	await r.get_tree().process_frame
	fake.purchase_error.emit({"code": "NETWORK_ERROR", "message": "The network is down."})
	r.check(pp.call() == 470 and results.any(func(x): return x[0] == "blue_1400" and not x[1] and x[2] == "The network is down."), "failed: nothing paid, the reason shown")
	# no valid transaction: nothing
	fake.purchase_updated.emit({"productId": "blue_1400", "purchaseState": "Purchased"})
	fake.purchase_updated.emit({"productId": "blue_1400", "transactionId": "t9", "purchaseState": "Unknown"})
	await r.get_tree().process_frame
	r.check(pp.call() == 470, "a purchase without a transaction id, or in an unknown state, pays nothing")
	# PIXEL POLO +: unlocked, its 200 Polo Points once
	Store.buy("pro_unlock")
	await r.get_tree().process_frame
	var tp := {"productId": "pro_unlock", "transactionId": "tp", "purchaseState": "Purchased"}
	fake.purchase_updated.emit(tp)
	fake.purchase_updated.emit(tp)
	await r.get_tree().process_frame
	r.check(Store.pro and pp.call() == 470 + Store.PRO_COINS, "PIXEL POLO + unlocks with its Polo Points once: %d" % pp.call())
	r.check(fake.finished.any(func(x): return x[0] == "tp" and x[1] == false), "...finished as a non-consumable")
	# a new device: RESTORE PURCHASES brings the unlocks back, never their coins, never packs
	Store.reset_for_tests()
	fake.available = [{"productId": "pro_unlock", "transactionId": "tp"}, {"productId": "all_teams_unlock", "transactionId": "ta"}]
	results.clear()
	Store.restore()
	for i in 3:
		await r.get_tree().process_frame
	r.check(Store.pro and Store.all_teams and Store.vault == 0, "RESTORE PURCHASES: both unlocks back, no coins")
	r.check(results.any(func(x): return x[0] == "restore" and x[1]), "...and the shop says what was restored")
	# refunded (StoreKit's refund notice / the revocation path)
	Store._on_revoked(Store.PRO_ID)
	r.check(not Store.pro, "a refunded PIXEL POLO + is taken back")
	Store.purchase_finished.disconnect(cb)
	fake.queue_free()
	Store.reset_for_tests()
	Store._backend = kept_backend
	Store.backend_name = kept_name
	Store._prices = kept_prices

# ------------------------------------------------------------------ project / export configuration
func _config() -> void:
	var proj := ConfigFile.new()
	r.check(proj.load("res://project.godot") == OK, "project.godot reads")
	r.check(int(proj.get_value("display", "window/handheld/orientation", -1)) == 4, "landscape (either way up) on phones")
	r.check(proj.get_value("display", "window/stretch/mode", "") == "viewport" and proj.get_value("display", "window/stretch/aspect", "") == "expand", "one 480x270 pixel image, never stretched, widened for wide phones")
	r.check(int(proj.get_value("rendering", "textures/canvas_textures/default_texture_filter", -1)) == 0, "nearest-neighbour pixel art")
	r.check(proj.get_value("application", "boot_splash/show_image", true) == false, "no Godot logo at launch")
	r.check(proj.get_value("application", "config/name.ios", "") == "Pixel Polo", "the iPhone home screen name is Pixel Polo")
	r.check(proj.get_value("application", "config/name", "") == "Retro Polo", "config/name unchanged (it names the desktop/web save folder)")
	var ex := ConfigFile.new()
	r.check(ex.load("res://export_presets.cfg") == OK, "export_presets.cfg reads")
	var ios := ""
	for sec in ex.get_sections():
		if ex.get_value(sec, "platform", "") == "iOS":
			ios = sec
	r.check(ios != "", "there is an iOS export preset")
	if ios == "":
		return
	var o := ios + ".options"
	var excl := String(ex.get_value(ios, "exclude_filter", ""))
	r.check(not Array(excl.split(",")).map(func(x): return x.strip_edges()).has("addons/*"), "iOS exports keep runtime plugins (addons/godot-iap, addons/admob)")
	r.check(int(ex.get_value(o, "application/targeted_device_family", -1)) == 0, "iPhone app")
	r.check(String(ex.get_value(o, "application/min_ios_version", "0")).to_float() >= 15.0, "iOS 15 or later (the IAP plugin's minimum)")
	r.check(String(ex.get_value(o, "application/bundle_identifier", "")) != "", "a bundle identifier is set")
	r.check(String(ex.get_value(o, "application/additional_plist_content", "")).contains("ITSAppUsesNonExemptEncryption"), "export compliance answered in Info.plist")
	for key in ["icons/icon_1024x1024", "icons/app_store_1024x1024"]:
		var path := String(ex.get_value(o, key, ""))
		var img := Image.load_from_file(ProjectSettings.globalize_path(path)) if path != "" else null
		r.check(img != null and img.get_width() == 1024 and img.get_height() == 1024 and img.detect_alpha() == Image.ALPHA_NONE and not img.get_format() in [Image.FORMAT_RGBA8, Image.FORMAT_LA8], "%s: 1024x1024 with no alpha channel" % key)
	r.check(not bool(ex.get_value(o, "privacy/tracking_enabled", false)), "no tracking declared (no ATT prompt) by default")
	var plist := String(ex.get_value(o, "application/additional_plist_content", ""))
	r.check(not plist.contains("NSLocalNetworkUsageDescription") and not bool(ex.get_value(o, "plugins/retropolo-ble", false)), "v1.0 asks for no Local Network or Bluetooth permission")
	r.check(not String(ex.get_value(o, "application/bundle_identifier", "")).contains("akikawasaki") and String(ex.get_value(o, "application/app_store_team_id", "")) != "7844HC9AYV", "the old project's bundle id and team are gone")
	# nothing secret in the shipped code
	var bad: Array = []
	_scan("res://src", bad)
	r.check(bad.is_empty(), "no private keys or secrets in the game's code %s" % str(bad))

func _scan(dir: String, bad: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			var t := FileAccess.get_file_as_string(dir + "/" + f)
			for pat in ["-----BEGIN", "PRIVATE KEY", "sk_live_", "AIza", "shared_secret"]:
				if t.contains(pat):
					bad.append("%s/%s: %s" % [dir, f, pat])
	for d in DirAccess.get_directories_at(dir):
		_scan(dir + "/" + d, bad)
