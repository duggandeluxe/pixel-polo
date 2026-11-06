extends RefCounted
## RESET GAME (Settings): every save, the Road to Glory, the settings and every purchase gone,
## after two confirmations; one-time unlocks come back only through RESTORE PURCHASES.
##   godot --headless --path game -- --test reset

var r   # the test runner
const DIR := "user://reset_test/"

func run(runner) -> void:
	r = runner
	print("reset game")
	var kept_settings: Dictionary = Game.settings.duplicate(true)
	var kept_dir := Game.save_dir
	var kept_store := FileAccess.get_file_as_string(Store.SAVE_PATH) if FileAccess.file_exists(Store.SAVE_PATH) else ""
	DirAccess.make_dir_recursive_absolute(DIR)
	Game.save_dir = DIR
	var was_test := Game.test_mode
	Game.test_mode = false
	# a played-in device: two careers, unlocks, settings changed, purchases owned
	Game.progress = Progression.fresh()
	Game.progress.award(["five_wins"])
	Game.save_progress()
	for n in [1, 3]:
		Game.career = Career.new_game("HURST", "A", "B", 50 + n)
		Game.slot = n
		Game.save_career()
	Game.settings.difficulty = "hard"
	Game.settings.music = false
	Game.settings.tutorials_done = ["shooting"]
	Store.pro = true
	Store.all_teams = true
	Store.vault = 900
	Store.caps_owned = ["gold"]
	var before := DirAccess.get_files_at(DIR)
	r.check(before.size() >= 3, "a device with saves on it %s" % str(before))
	# the button and its two confirmations
	Game.goto("settings")
	await r.get_tree().process_frame
	await r.get_tree().process_frame
	var scr = Game.current_screen
	var b: Button = scr.find_child("ResetGame", true, false)
	r.check(b != null and b.text == "RESET EVERYTHING", "Settings has RESET EVERYTHING")
	b.pressed.emit()
	await r.get_tree().process_frame
	r.check(DirAccess.get_files_at(DIR).size() == before.size() and Store.pro, "the first dialog deletes nothing")
	scr._confirm_reset_again()
	await r.get_tree().process_frame
	r.check(DirAccess.get_files_at(DIR).size() == before.size(), "nor the second, until it's confirmed")
	for layer in Game.overlay.get_children():
		if layer is Control and layer.mouse_filter == Control.MOUSE_FILTER_STOP:
			layer.queue_free()   # (the dialogs; never the screen fade)
	scr._reset()
	await r.get_tree().create_timer(0.5).timeout   # (outside test mode the screens fade)
	var left := Array(DirAccess.get_files_at(DIR)).filter(func(f): return f.ends_with(".json") or f == Game.SLOTS_CFG)
	r.check(left.is_empty(), "every career, backup, slot list and the Road to Glory profile deleted %s" % str(left))
	r.check(Game.career == null and Game.slot == 0 and Game.setup == null and Game.progression().unlocked.size() == 5, "a fresh profile: the bottom five open")
	r.check(Game.settings.difficulty == "normal" and Game.settings.music == true and (Game.settings.tutorials_done as Array).is_empty() and float(Game.settings.dyn_ai) == Difficulty.DYN_START, "settings back to their defaults")
	r.check(not Store.pro and not Store.all_teams and Store.caps_owned.is_empty() and Store.hold_owned, "PRO, ALL 30 TEAMS and caps gone")
	r.check(Store.vault == 900, "purchased coins stay (the Universal Coin Wallet update): %d" % Store.vault)
	Store._on_owned(Store.TEAMS_ID)
	Store._on_purchased(Store.PRO_ID)
	r.check(not Store.all_teams and not Store.pro, "the store's startup sync doesn't bring them back")
	r.check(Game.current_name == "title", "back to the title screen")
	Store.restore()
	Store._on_owned(Store.TEAMS_ID)
	r.check(Store.all_teams and not Store.hold_owned, "RESTORE PURCHASES does")
	# put the test machine back (its own settings and editor test store as they were)
	Store.reset_for_tests()
	if kept_store != "":
		var f := FileAccess.open(Store.SAVE_PATH, FileAccess.WRITE)
		f.store_string(kept_store)
		f.close()
	Store._load()
	Game.test_mode = was_test
	Game.save_dir = kept_dir
	Game.settings = kept_settings
	Game.save_settings()
	Game.progress = null
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))
