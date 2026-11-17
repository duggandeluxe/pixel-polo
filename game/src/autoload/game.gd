extends Node
## Global state: settings, the match being set up, screen navigation, dialogs.

const SETTINGS_PATH := "user://settings.cfg"
const SLOTS := 5
const SLOT_PATH := "career_slot%d.json"
const BACKUP_PATH := "career_slot%d_backup.json"   # the original of a save converted on load or realigned
const SLOTS_CFG := "slots.cfg"                     # the last slot played, each slot's summary
const LEGACY_SAVE_PATH := "career.json"            # the one save from before slots
const LEGACY_KEPT_PATH := "career_premigration.json"
const PROGRESS_PATH := "progression.json"          # the Road to Glory: schools open to a new career (Progression)
const SETUP_PATH := "setup.json"                    # the dynasty setup being picked from: its seed (dynasty_setup)
## Screens that don't live in res://src/ui/screens/.
const SCREEN_PATHS := {"match": "res://src/match/match_screen.gd", "mp_match": "res://src/match/mp_match_screen.gd",
	"drill": "res://src/tutorial/drill_screen.gd"}

## Every setting needs a default here: only these keys are loaded back from disk.
var settings := {
	"sfx": true, "music": true, "haptics": true,
	"difficulty": "normal",    # see Difficulty: MEDIUM ("normal") for a new player; a saved pick is kept
	"dyn_level": -0.4,         # (before the AI overhaul: Quick Match's dynamic level, -1..+1; read once into dyn_ai)
	"dyn_ai": -1.0,            # Quick Match's DYNAMIC level, 0..1 (a career keeps its own); -1: not yet set
	"dyn_hist": [],            # ...and the recent games it's judged on
	"tutorials_done": [],      # tutorial parts finished (Drill.ORDER ids): the tutorial picks up after them
	"career_tour": "",         # the first career's guided tour (CareerTour): "", "pending" or "seen"; global, never in a save
	"career_tour_uid": "",     # ...the career it's pending for
	"career_tutorial_seen": false,   # the gameplay tutorial a new career opens with: only the first-ever dynasty gets it
	"hub_hint_uid": "",        # the one dynasty that gets the home screen's CLICK HERE TO VIEW YOUR DYNASTY HUB! hint (the first-ever one); "-": none left
	"reduce_motion": false,
	"no_reminders": false,      # DISABLE COACHING REMINDERS: no injury / new recruits / Dynasty Hub callouts on the home screen
	"quarter_min": 2,          # QUARTER LENGTH for Quick Match (a career keeps its own: Career.quarter_min)    # no fades, pops or count-ups in the menus (see Juice)
	"dev_mode": false,         # Developer Mode: the form lab and the roster's DEV panel (StarFx)
	"mp_name": "", "mp_link": "online", "mp_club": 3,
	"language": "",            # LANGUAGE (Loc): an App Store locale id the player picked; "": the phone's own
}

## What the next match screen plays: {"us": PoloTeam, "them": PoloTeam, "seed": int}
var match_cfg: Dictionary = {}
var career: Career = null
var progress: Progression = null   # the player's profile, every career's (progression(): loaded on first use)
var setup: Career = null       # the dynasty setup on the PICK YOUR SCHOOL screen (dynasty_setup)
var setup_seed := 0
var slot := 0          # the career slot (1-5) Game.career lives in; 0 = none yet
var save_dir := "user://"   # where the career files live (the slot tests use a folder of their own)
var main: Node = null
var screen_root: Control = null
var overlay: CanvasLayer = null
var current_screen: Control = null
var current_name := ""
var history: Array = []
var test_mode := false
var _fade: ColorRect
var _changing := 0        # screen changes under way (goto between its first line and the new screen in)
var warmup: Node = null   # ScreenWarmup: every screen compiled ahead of its first visit
const ScreenWarmup := preload("res://src/ui/screen_warmup.gd")

var _default_settings := {}   # `settings` as a first install has them (RESET GAME)

## The game's name (the Pixel Polo rebrand): PIXEL POLO, WATER POLO DYNASTY under it, the two
## together where a full title is wanted (the window, the browser tab). The project's own
## config/name stays "Retro Polo": it names the save folder (user://, on the web too:
## /userfs/godot/app_userdata/Retro Polo), so every career saved before the rename still loads.
const TITLE := "Pixel Polo"
const SUBTITLE := "Water Polo Dynasty"
const FULL_TITLE := "Pixel Polo: Water Polo Dynasty"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# the window's and, on the web, the page's title: once the engine has set its own (config/name)
	DisplayServer.window_set_title.call_deferred(FULL_TITLE)
	_default_settings = settings.duplicate(true)
	load_settings()

## Going to the background (home button, a phone call, the app switcher) or being closed: iOS and
## Android may end a backgrounded app without any further notice, so whatever the dynasty has in
## memory is written now. Not in a match (its result is applied when it ends; the career on disk is
## already the pre-match one, and the match pauses itself) and not mid screen change.
const NO_FLUSH_SCREENS := ["match", "mp_match", "drill"]

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush_saves()

func flush_saves() -> void:
	if test_mode:
		return
	if career != null and slot >= 1 and _changing == 0 and not current_name in NO_FLUSH_SCREENS:
		save_career()
	if progress != null:
		save_progress()

func register_main(m: Node, root: Control, ov: CanvasLayer) -> void:
	main = m
	screen_root = root
	overlay = ov
	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.05, 0.1, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(_fade)
	warmup = ScreenWarmup.new()
	warmup.name = "ScreenWarmup"
	m.add_child(warmup)

## Starts compiling every screen in the background (main.gd, once the title is up). Not in tests.
func start_warmup() -> void:
	if warmup != null and not test_mode:
		warmup.start()
		prepare_setup()

## Is a screen change under way (its fade, or the new screen being built)?
func is_changing_screen() -> bool:
	return _changing > 0

# ------------------------------------------------------------------ navigation
func goto(name: String, params: Dictionary = {}, push: bool = true) -> void:
	# no career game starts while an upgrade is unspent, however it was reached: the first
	# player with one opens instead (open_upgrades)
	if (name == "matchup" or (name == "match" and bool(params.get("career", false)))) and upgrade_target() != {}:
		params = upgrade_target()
		name = "player"
	# the DEV screen only behind its code, however it's reached (a button, Back, a lab): DevGate
	name = DevGate.route(name)
	if name in AppConfig.MULTIPLAYER_SCREENS and not AppConfig.multiplayer_enabled():
		name = "title"   # (v1.0: multiplayer is hidden in release builds)
	if push and current_name != "" and current_name != name:
		history.append(current_name)
		if history.size() > 12:
			history.pop_front()
	_changing += 1
	var script_path: String = SCREEN_PATHS.get(name, "res://src/ui/screens/%s.gd" % name)
	var scr: Script = load(script_path)
	var node: Control = scr.new()
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.theme = UI.theme
	if node.has_method("setup"):
		node.setup(params)
	if current_screen != null and not test_mode:
		var tw := create_tween()
		_fade.color.a = 0.0
		tw.tween_property(_fade, "color:a", 1.0, 0.12)
		await tw.finished
	if current_screen != null:
		current_screen.queue_free()
	current_screen = node
	current_name = name
	set_detail(node.get("detail") == true or Loc.hires())   # (LANGUAGE: scripts the pixel fonts lack, at full resolution)
	screen_root.add_child(node)
	_changing -= 1
	if not test_mode:
		var tw2 := create_tween()
		tw2.tween_property(_fade, "color:a", 0.0, 0.15)

## DETAIL MODE (the screen resolution framework): a screen whose `detail` is true is drawn at the
## window's own pixels (Window.content_scale_mode CANVAS_ITEMS) on the same 480 x 270 layout, so
## its art can be drawn in half pixels (2x the detail); every other screen, and every match, keeps
## the one 480 x 270 image scaled up (VIEWPORT), exactly as before. Text is never oversampled
## (Window.oversampling off), so the pixel fonts look the same in both.
func set_detail(on: bool) -> void:
	var win := get_window()
	if win == null:
		return
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if on else Window.CONTENT_SCALE_MODE_VIEWPORT
	win.oversampling = not on or Loc.hires()   # (LANGUAGE: system-font scripts drawn sharp at the display's size)

## The mandatory upgrades' next page ({id, mandatory}), or {} when nothing is left to spend.
func upgrade_target() -> Dictionary:
	if career == null:
		return {}
	var due: Array = career.upgrades_due()
	return {} if due.is_empty() else {"id": (due[0] as PoloPlayer).id, "mandatory": true}

## Opens the next player's upgrades (after the postgame, training, a reload). False if none.
func open_upgrades() -> bool:
	var to := upgrade_target()
	if to.is_empty():
		return false
	goto("player", to, false)
	return true

func back(default: String = "title") -> void:
	var target := default
	if history.size() > 0:
		target = history.pop_back()
	# (a DEV screen left behind in the history, its session closed: skipped, never a detour to
	# Settings, nor back to the screen already open behind it)
	if target == DevGate.SCREEN and not DevGate.is_open():
		while (target == DevGate.SCREEN or target == current_name) and history.size() > 0:
			target = history.pop_back()
		if target == DevGate.SCREEN or target == current_name:
			target = default
	goto(target, {}, false)

# ------------------------------------------------------------------ dialogs
## buttons: Array of [label, Callable, style]. kind: the popup's colour (UI.POPUP_KINDS: info,
## reward, danger, warn, good); left empty, a dialog with a danger button is danger, one whose title
## warns is warn, the rest info.
## The layer's children: [dim, centre]; the centre holds the panel, the panel the column:
## [title plate, body, button row] (screens add rows to that column: hub, player).
func dialog(title: String, body: String, buttons: Array, kind: String = "") -> Control:
	if kind == "":
		kind = dialog_kind(title, buttons)
	var k := UI.popup_kind(kind)
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.theme = UI.theme
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var p := PanelContainer.new()
	p.name = "Popup"
	p.add_theme_stylebox_override("panel", UI.popup_box(kind))
	# never wider than the screen (a phone in portrait is the narrowest): the body wraps to fit
	var vw := get_viewport().get_visible_rect().size.x if is_inside_tree() else 480.0
	var pw := minf(280.0, vw - 16.0)
	p.custom_minimum_size = Vector2(pw, 0)
	center.add_child(p)
	var v := UI.vbox(5)
	p.add_child(v)
	# (an amount's coin, CreditCoin.TAG, is drawn as the coin itself: number first)
	var plate := PanelContainer.new()
	plate.name = "TitlePlate"
	plate.add_theme_stylebox_override("panel", UI.popup_plate(kind))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(CreditCoin.rich(title, 16, k.title, "big", pw - 2.0 * UI.POPUP_PAD_H - 10.0, 20))
	v.add_child(plate)
	v.add_child(CreditCoin.rich(body, 8, UI.TEXT, "body", pw - 2.0 * UI.POPUP_PAD_H - 2.0))
	var bh := UI.hbox(4)
	bh.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(bh)
	for bd in buttons:
		var cb: Callable = bd[1]
		var style: String = bd[2] if bd.size() > 2 else "normal"
		var btn := UI.button(String(bd[0]), func():
			layer.queue_free()
			if cb.is_valid():
				cb.call(), style, 60, 20)
		bh.add_child(CreditCoin.set_button(btn, String(bd[0])))
	overlay.add_child(layer)
	Sfx.play("card")
	if Juice.enabled():
		p.pivot_offset = Vector2(p.custom_minimum_size.x / 2.0, 40)
		p.scale = Vector2(0.9, 0.9)
		create_tween().tween_property(p, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return layer

## A dialog's colour when the caller doesn't name one: red when one of its buttons is a danger
## button, orange when its title warns, gold when it pays out, otherwise the plain info popup.
func dialog_kind(title: String, buttons: Array) -> String:
	for bd in buttons:
		if bd.size() > 2 and String(bd[2]) == "danger":
			return "danger"
	var t := title.to_upper()
	for w in ["WARNING", "DEADLINE", "PROBLEM", "NOT ENOUGH", "FORFEIT"]:
		if t.contains(w):
			return "warn"
	for w in ["EARNED", "BONUS", "ACHIEVEMENT"]:
		if t.contains(w):
			return "reward"
	return "info"

## The Road to Glory's notification (a queued "achievement": {id, title, count}): the unlock show
## (TeamUnlock: the new tier's schools break out of their padlocks one by one). `done` runs when
## it's closed with OK.
func achievement_dialog(q: Dictionary, done: Callable) -> Control:
	return TeamUnlock.play(overlay, q, done)

func toast(text: String, color: Color = UI.GOLD) -> void:
	if overlay == null:
		return
	# a small notification: the popup's frame (its edge in the message's colour), no title; the
	# message between two pixel diamonds, with a 1 px ink drop shadow. It carries UI.theme itself
	# (the overlay is a CanvasLayer, which passes no theme down): without it the body font falls
	# back to its imported, smoothed settings and the text comes out blotchy.
	var p := PanelContainer.new()
	p.name = "Toast"
	p.theme = UI.theme
	p.add_theme_stylebox_override("panel", UI.toast_box(color))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UI.hbox(5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var msg := CreditCoin.rich(text, 8, color)
	msg.add_theme_color_override("font_shadow_color", UI.INK)
	msg.add_theme_constant_override("shadow_offset_x", 1)
	msg.add_theme_constant_override("shadow_offset_y", 1)
	for i in 3:
		if i == 1:
			row.add_child(msg)
			continue
		var pip := TextureRect.new()
		pip.texture = UI.toast_pip(color)
		pip.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		pip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pip)
	overlay.add_child(p)
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	var vs := get_viewport().get_visible_rect().size
	p.position = Vector2(roundf((vs.x - p.size.x) / 2.0), -p.size.y - 6.0)
	var tw := create_tween()
	tw.tween_property(p, "position:y", 6.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.6)
	tw.tween_property(p, "position:y", 2.0, 0.25).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(p, "modulate:a", 0.0, 0.25)
	tw.tween_callback(p.queue_free)

func vibrate(ms: int) -> void:
	if settings.haptics and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

# ------------------------------------------------------------------ persistence
func load_settings() -> void:
	var cf := ConfigFile.new()
	if SafeFile.load_config(cf, SETTINGS_PATH) == OK:
		for k in settings.keys():
			settings[k] = cf.get_value("s", k, settings[k])
		# from before the first career tour: a player who already has a career has had their first
		if not cf.has_section_key("s", "career_tour") and _any_career_file():
			settings.career_tour = CareerTour.SEEN
		# from before the hint went global: a player who already has a career has had their first
		if not cf.has_section_key("s", "hub_hint_uid") and _any_career_file():
			settings.hub_hint_uid = "-"
	if not DevGate.allowed():
		settings.dev_mode = false   # (release build: Developer Mode can't be switched on from a settings file)
	if float(settings.dyn_ai) < 0.0:
		# first run after the AI overhaul: an old dynamic level that had moved comes across; otherwise MEDIUM
		var old := float(settings.dyn_level)
		settings.dyn_ai = Difficulty.from_legacy(old) if not is_equal_approx(old, -0.4) else Difficulty.DYN_START

func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings.keys():
		cf.set_value("s", k, settings[k])
	SafeFile.save_config(cf, SETTINGS_PATH)
	Sfx.set_sfx_on(settings.sfx)
	Sfx.set_music_on(settings.music)

## Is there any career save on disk (a slot, or the old single save)? Read straight from the
## folder: no migration, no loading.
func _any_career_file() -> bool:
	if FileAccess.file_exists(save_dir + LEGACY_SAVE_PATH):
		return true
	for n in range(1, SLOTS + 1):
		if FileAccess.file_exists(slot_path(n)):
			return true
	return false

# ------------------------------------------------------------------ RESET GAME
## Settings' RESET GAME: the game as it was first installed. Every career slot and its backups,
## the Road to Glory profile, the dynasty setup, the settings (difficulty, sound,
## tutorial progress, Developer Mode), the unlocks (Store.reset_all; RESTORE PURCHASES brings
## them back), the purchased Polo Points and the visual upgrades are all gone (the store's record
## is written again at once); the title screen comes up fresh. Returns the files it removed.
func reset_everything() -> Array:
	var gone: Array = []
	DevGate.lock()   # (the DEV screen asks for its code again)
	career = null
	setup = null
	setup_seed = 0
	progress = null
	slot = 0
	history.clear()
	match_cfg = {}
	var dir := DirAccess.open(save_dir)
	if dir != null:
		for f in dir.get_files():
			# (the game's own files: the slots, their backups, slots.cfg, the profile, the setup,
			# the old single save, settings and the store's record; Godot's logs and caches stay)
			var base := f.trim_suffix(SafeFile.TMP).trim_suffix(SafeFile.PREV)
			if base.ends_with(".json") or base in [SLOTS_CFG, "settings.cfg", "store.cfg"]:
				if dir.remove(f) == OK:
					gone.append(f)
	settings = _default_settings.duplicate(true)
	settings.dyn_ai = Difficulty.DYN_START
	save_settings()
	Store.reset_all()
	BarHit.override = BarHit.Override.NORMAL
	Scoreboard.override = 0
	return gone

# ------------------------------------------------------------------ career saves (five slots)
## Each slot is its own file holding a whole Career (team, roster, schedule, recruiting,
## staff, records ...). slots.cfg remembers which one was played last and a small summary of
## each for the SELECT CAREER screen.
func slot_path(n: int) -> String:
	return save_dir + SLOT_PATH % n

func slot_exists(n: int) -> bool:
	_migrate_legacy_save()
	return n >= 1 and n <= SLOTS and FileAccess.file_exists(slot_path(n))

## Any career at all (CONTINUE needs one).
func has_save() -> bool:
	return last_slot() > 0

## The slot played most recently, or 0 when there's no career.
func last_slot() -> int:
	_migrate_legacy_save()
	var cf := _slots_cfg()
	var last := int(cf.get_value("slots", "last", 0))
	if slot_exists(last):
		return last
	# no record (or that one was deleted): the newest file
	var best := 0
	var best_t := -1
	for n in range(1, SLOTS + 1):
		if slot_exists(n):
			var t := int(cf.get_value("slots", "played_%d" % n, FileAccess.get_modified_time(slot_path(n))))
			if t > best_t:
				best = n
				best_t = t
	return best

func first_free_slot() -> int:
	for n in range(1, SLOTS + 1):
		if not slot_exists(n):
			return n
	return 0

## {"team", "season", "record"} for a slot's career, or {} when it's empty or unreadable.
func slot_summary(n: int) -> Dictionary:
	if not slot_exists(n):
		return {}
	var cf := _slots_cfg()
	var mtime := FileAccess.get_modified_time(slot_path(n))
	var cached = cf.get_value("slots", "sum_%d" % n, {})
	# the school's id is kept with the summary so a renamed team shows its new name; summaries
	# cached before that are read again
	if cached is Dictionary and int(cached.get("mtime", -1)) == mtime and cached.has("school"):
		var s := Colleges.school(String(cached.school))
		if s.is_empty():
			return {"team": "SAVE PROBLEM", "season": 0, "record": "", "damaged": true}
		cached.team = s.name
		return cached
	var c := _read_slot(n)
	if c == null:
		return {"team": "SAVE PROBLEM", "season": 0, "record": "", "damaged": true}
	var sm := _summary_of(c)
	sm.mtime = mtime
	if not test_mode:
		cf.set_value("slots", "sum_%d" % n, sm)
		SafeFile.save_config(cf, save_dir + SLOTS_CFG)
	return sm

static func _summary_of(c: Career) -> Dictionary:
	return {"team": c.team().name, "school": c.school, "season": c.year - Career.START_YEAR + 1, "record": c.record_text()}

func save_career() -> void:
	if career == null or test_mode:
		return
	if slot < 1:
		slot = maxi(first_free_slot(), 1)
	var path := slot_path(slot)
	if career.realigned and FileAccess.file_exists(path):
		# an old save just moved onto the current conferences: keep its last old file beside it
		var backup := _free_path(save_dir + BACKUP_PATH % slot)
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup)) != OK:
			push_error("Can't back up the career save before the realignment; keeping the old file.")
			return
	career.realigned = false
	# write, read back, then rename (SafeFile): a crash, a full disk or iOS ending the app mid-save
	# never leaves a half-written career, and the save it replaces is kept as .prev
	if not SafeFile.write_text(path, JSON.stringify(career.to_dict())):
		return
	Store.commit_career(career.uid)   # (what it bought with purchased coins is in the save now: final)
	var sm := _summary_of(career)
	sm.mtime = FileAccess.get_modified_time(path)
	_mark_played(slot, sm)

## Loads slot n (default: the current slot) into Game.career and makes it the current slot.
func load_career(n: int = -1) -> bool:
	if n < 0:
		n = slot
	if not slot_exists(n):
		return false
	var used_prev: Array = []
	var text := SafeFile.read_text(slot_path(n), true, used_prev)   # (damaged: its previous good copy)
	if text == "":
		return false
	var d = JSON.parse_string(text)
	if not _playable(d):
		push_error("The career save in slot %d is damaged or at a school no longer in the game, and can't be loaded." % n)
		return false
	career = Career.from_dict(d)
	slot = n
	if not used_prev.is_empty():
		toast("Your last save couldn't be read, so the one before it was loaded.", UI.WARN)
		save_career()   # (the good copy becomes the slot's file again)
	# purchased coins it spent on something this save never got (the game stopped before saving)
	# come back: never charged without the thing bought (CoinVault.reconcile)
	var back := Store.reconcile_career(career.uid)
	if back > 0:
		toast("%s returned to your purchased Polo Points: an unfinished purchase" % CreditCoin.tag(back, true), UI.GOLD)
	# (a save behind the exchange's ledger: coins already exchanged don't come back)
	if Wallet.reconcile_exchanges(career) > 0:
		save_career()
	if not test_mode:
		_mark_played(n)
	# what this career has already done counts on the Road to Glory (a save from before it)
	if not progression().reconstruct_career(career, n).is_empty():
		save_progress()
	if career.trimmed or career.upgraded or career.rated:
		# an older save, now converted (18-man programs and the recruiting year, the locked
		# OFF/DEF ratings and the poll): keep the original untouched beside it, then save
		var backup := _free_path(save_dir + BACKUP_PATH % n)
		var bf := FileAccess.open(backup, FileAccess.WRITE)
		if bf == null:
			push_error("Can't back up the career save before converting it: %s" % error_string(FileAccess.get_open_error()))
			return true   # play on with the converted roster in memory, but leave the old file alone
		bf.store_string(text)
		bf.close()
		save_career()
	return true

## A new career at `school_id`, in the current slot. Refused (false, nothing saved or deleted)
## when the school is still locked on the Road to Glory: the picker's NEXT isn't the only check.
## A new career at `school_id`. With no seed (the New Career screen): from the dynasty setup the
## picker showed, its players exactly as they were rated there, never made again; the setup is
## then used up, so the next new dynasty gets new rosters. With a seed: a setup made from it.
func start_career(school_id: String, coach_first: String, coach_last: String, seed_value: int = -1) -> bool:
	if Colleges.school(school_id).is_empty() or not progression().is_unlocked(school_id):
		return false
	var from := dynasty_setup() if seed_value < 0 else Career.new_setup(seed_value)
	var had_career := _any_career_file()   # (the first career tour: only the first-ever career gets it)
	delete_save()
	career = from.begin(school_id, coach_first, coach_last)
	# the gameplay tutorial: the first dynasty ever made only (a player with a career already saved,
	# from before this setting, has played; the GAME GUIDE's PLAY THE TUTORIAL is always there)
	if not bool(settings.get("career_tutorial_seen", false)) and not had_career:
		career.tutorial = Career.TUTORIAL_PENDING
	if not bool(settings.get("career_tutorial_seen", false)):
		settings["career_tutorial_seen"] = true
		save_settings()
	if seed_value < 0:
		clear_setup()
	save_career()
	CareerTour.note_new_career(career, had_career)
	progression().note(career, slot)   # (the season line starts again at 0 wins)
	save_progress()
	return true

## Deletes the current slot's career (a new career is about to take the slot).
func delete_save() -> void:
	if slot >= 1:
		delete_slot(slot)
	career = null

## Deletes slot n's career for good. Backups made by save conversions are left alone.
func delete_slot(n: int) -> void:
	if n == slot:
		career = null
	if slot_exists(n):
		# its dynasty coins go with it; purchased coins it took without saving come back first
		var d = JSON.parse_string(FileAccess.get_file_as_string(slot_path(n)))
		if d is Dictionary:
			Store.reconcile_career(String(d.get("uid", "")))
		SafeFile.remove_all(slot_path(n))   # (and its .tmp / .prev: a new career never falls back onto it)
	var cf := _slots_cfg()
	for k in ["played_%d" % n, "sum_%d" % n]:
		if cf.has_section_key("slots", k):
			cf.erase_section_key("slots", k)
	SafeFile.save_config(cf, save_dir + SLOTS_CFG)

func _read_slot(n: int) -> Career:
	var text := SafeFile.read_text(slot_path(n))
	if text == "":
		return null
	var d = JSON.parse_string(text)
	if not _playable(d):
		return null
	return Career.from_dict(d)

## A save that can be opened: whole, and at one of the schools. (A career from the first 32-school
## world isn't: those schools are gone. Its file stays where it is, and the slot shows SAVE PROBLEM.)
static func _playable(d: Variant) -> bool:
	return d is Dictionary and d.has("teams") and not Colleges.school(String(d.get("school", ""))).is_empty()

func _slots_cfg() -> ConfigFile:
	var cf := ConfigFile.new()
	SafeFile.load_config(cf, save_dir + SLOTS_CFG)
	return cf

func _mark_played(n: int, summary: Dictionary = {}) -> void:
	var cf := _slots_cfg()
	cf.set_value("slots", "last", n)
	cf.set_value("slots", "played_%d" % n, int(Time.get_unix_time_from_system()))
	if not summary.is_empty():
		cf.set_value("slots", "sum_%d" % n, summary)
	SafeFile.save_config(cf, save_dir + SLOTS_CFG)

## path, or path_2, path_3 ... so an earlier file is never overwritten.
func _free_path(path: String) -> String:
	var p := path
	var n := 2
	while FileAccess.file_exists(p):
		p = path.replace(".json", "_%d.json" % n)
		n += 1
	return p

## The old single save (user://career.json) moves into the first free slot. It's copied and
## checked first; the original is then kept, renamed, never deleted.
var _migrated := false

func _migrate_legacy_save() -> void:
	if _migrated or test_mode:
		return
	_migrated = true
	var legacy := save_dir + LEGACY_SAVE_PATH
	if not FileAccess.file_exists(legacy):
		return
	var n := first_free_slot()
	if n == 0:
		push_warning("All five career slots are full: the old career save stays in %s." % legacy)
		return
	var text := FileAccess.get_file_as_string(legacy)
	if text == "":
		return
	var tmp := slot_path(n) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Can't move the old career save into slot %d: %s" % [n, error_string(FileAccess.get_open_error())])
		return
	f.store_string(text)
	f.close()
	if FileAccess.get_file_as_string(tmp) != text:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		push_error("The old career save didn't copy cleanly; it stays where it is.")
		return
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(slot_path(n)))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(legacy), ProjectSettings.globalize_path(_free_path(save_dir + LEGACY_KEPT_PATH)))
	_mark_played(n)

# ------------------------------------------------------------------ the dynasty setup
## THE DYNASTY SETUP: all 30 schools' rosters, made before you pick a school so the picker's
## ratings are the players you'll get (Career.new_setup). Made once and kept until a career
## starts from it: leaving the screen, going back or closing the game brings back the same
## players (the seed is saved, and the same seed always makes the same players), so rosters
## can't be rerolled by reopening the picker.
func dynasty_setup() -> Career:
	if setup == null and _setup_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_setup_task)
		_setup_task = -1
		setup = _setup_made
		_setup_made = null
	if setup == null:
		var seed_value := _read_setup_seed()
		if seed_value < 0:
			seed_value = randi()
			_write_setup_seed(seed_value)
		setup_seed = seed_value
		setup = Career.new_setup(seed_value)
	return setup

## The setup's used up (a career started from it): the next new dynasty gets new rosters.
## Makes the next dynasty setup on a worker thread (~0.3 s of roster generation), so PICK YOUR
## SCHOOL opens without making it; dynasty_setup() takes it (waiting, if it's not quite done).
## Career.new_setup reads only its own dice and constants. Not without threads (the web build):
## there it's made on the screen's first visit, as before.
var _setup_task := -1
var _setup_made: Career = null

func prepare_setup() -> void:
	if setup != null or _setup_task >= 0 or test_mode or not ScreenWarmup.threads_ok():
		return
	var seed_value := _read_setup_seed()
	if seed_value < 0:
		seed_value = randi()
		_write_setup_seed(seed_value)
	setup_seed = seed_value
	_setup_task = WorkerThreadPool.add_task(func(): _setup_made = Career.new_setup(seed_value), false, "dynasty setup")

func clear_setup() -> void:
	setup = null
	setup_seed = 0
	if not test_mode and FileAccess.file_exists(save_dir + SETUP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_dir + SETUP_PATH))

func _read_setup_seed() -> int:
	if test_mode or not FileAccess.file_exists(save_dir + SETUP_PATH):
		return -1
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_dir + SETUP_PATH))
	return int(d.seed) if d is Dictionary and d.has("seed") else -1

func _write_setup_seed(seed_value: int) -> void:
	if test_mode:
		return
	var f := FileAccess.open(save_dir + SETUP_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"version": 1, "seed": seed_value}))
		f.close()

# ------------------------------------------------------------------ the Road to Glory profile
## The player's progression profile (see Progression), loaded the first time it's needed. With
## no profile yet, a new one starts from the tiers, then whatever the careers already saved
## prove is counted (Progression.reconstruct) and it's saved.
func progression() -> Progression:
	if progress == null:
		load_progress()
	return progress

func progress_path() -> String:
	return save_dir + PROGRESS_PATH

func load_progress() -> void:
	if test_mode:
		progress = Progression.fresh()   # (tests never read or write the player's own profile)
		return
	var path := progress_path()
	if FileAccess.file_exists(path):
		var d = JSON.parse_string(SafeFile.read_text(path))
		if d is Dictionary and d.has("tiers"):
			progress = Progression.from_dict(d)
			return
		# unreadable: keep it beside the new one, never over it
		push_error("The progression profile is damaged; starting a new one from the saved careers.")
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(_free_path(path.replace(".json", "_damaged.json"))))
	progress = Progression.fresh()
	var last := last_slot()
	for n in range(1, SLOTS + 1):
		if not FileAccess.file_exists(slot_path(n)):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(slot_path(n)))
		if d is Dictionary and d.has("teams"):
			progress.reconstruct_save(d, n, n == last)
	save_progress()

## Write-then-rename, like a career save: a crash mid-write never loses what was earned.
func save_progress() -> void:
	if progress == null or test_mode:
		return
	SafeFile.write_text(progress_path(), JSON.stringify(progress.to_dict()))
