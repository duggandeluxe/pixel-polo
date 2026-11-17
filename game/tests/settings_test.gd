extends RefCounted
## THE SETTINGS OVERHAUL & QUARTER LENGTH: the spec's REQUIRED TESTING (1-42).
##   godot --headless --path game -- --test settings
##   godot --path game -- --test settings_png <dir>

var r

func run(runner) -> void:
	r = runner
	print("settings overhaul & quarter length")
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	var kept: Dictionary = Game.settings.duplicate(true)
	Game.career = null
	await _layout()
	await _toggles()
	await _dev_access()
	await _quarter_button()
	_saves()
	_matches()
	await _match_start()
	Game.settings = kept
	Game.save_settings()
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

func _frames(n: int = 3) -> void:
	for _i in n:
		await r.get_tree().process_frame

func _find(name: String) -> Node:
	return Game.current_screen.find_child(name, true, false)

func _open() -> void:
	Game.goto("settings")
	await _frames()

## Inside the 480 x 270 page, nothing past its edges.
func _inside(n: Control) -> bool:
	var vr := Rect2(Vector2.ZERO, Vector2(480, 270))
	return vr.encloses(n.get_global_rect().grow(-0.5))

# ------------------------------------------------------------------ 1-9
func _layout() -> void:
	Game.settings.dev_mode = false
	await _open()
	var secs := ["Gameplay", "Audio"]
	r.check(secs.all(func(s): return _find(s) is PanelContainer), "1/2: two panels: GAMEPLAY, AUDIO & FEEDBACK")
	var heads: Array = secs.map(func(s): return (_find(s).find_child("Heading", true, false) as Label).text)
	r.check(heads == ["GAMEPLAY", "AUDIO & FEEDBACK"], "1: their headings %s" % str(heads))
	r.check(_find("Options") == null and _find("ResetRow") == null and _find("ResetGame") == null and _find("Toggle_dev_mode") == null and _find("DevTools") == null,
		"DEV: no GAME OPTIONS, DANGER ZONE, Developer Mode or tools on Settings")
	var g: Control = _find("Gameplay")
	var a: Control = _find("Audio")
	r.check(absf(g.global_position.y - a.global_position.y) < 1.0 and a.global_position.x > g.global_position.x + g.size.x, "2: GAMEPLAY and AUDIO side by side (two columns)")
	r.check(absf(g.size.y - a.size.y) < 0.5 and g.get_global_rect().end.y < 270.0 - 18.0,
		"layout: both panels one height, tops aligned, sized to their content (no stretching to the page's bottom: %.0f)" % g.get_global_rect().end.y)
	var snug := true
	for pn in ["DifficultyPlate", "QuarterPlate", "Row_sfx", "Row_music", "Row_haptics", "Row_reduce_motion"]:
		var pl := _find(pn) as Control
		if pl == null or pl.size.y > pl.get_combined_minimum_size().y + 0.5:
			snug = false
	var rows: Array = ["sfx", "music", "haptics", "reduce_motion"].map(func(k): return _find("Row_" + k))
	var gaps: Array = []
	for i in 3:
		gaps.append((rows[i + 1] as Control).global_position.y - (rows[i] as Control).get_global_rect().end.y)
	r.check(snug and gaps.all(func(x): return absf(x - gaps[0]) < 1.01), "layout: every inner box fits its content; the audio rows evenly spaced %s" % str(gaps))
	var db: Control = _find("DevButton")
	r.check(db is Button and (db as Button).text == "DEV" and db.global_position.x > 400 and db.global_position.y < 24 and _inside(db)
		and not db.get_global_rect().intersects(Game.current_screen.title_label.get_global_rect()), "DEV: a small DEV button at the top right, clear of the title")
	var all_in := true
	var bad: Array = []
	for n in Game.current_screen.find_children("*", "Control", true, false):
		if n is Control and (n as Control).is_visible_in_tree() and (n is Button or n is Label or n is PanelContainer) and not _inside(n):
			all_in = false
			bad.append(n.name)
	r.check(all_in, "6: everything inside the 480 x 270 screen, Developer Mode off %s" % str(bad.slice(0, 5)))
	var diffs: Array = Difficulty.MODES.map(func(m): return _find("Diff_" + m))
	r.check(diffs.all(func(b): return b != null) and diffs.all(func(b): return absf(b.size.y - diffs[0].size.y) < 0.5 and absf(b.global_position.y - diffs[0].global_position.y) < 0.5),
		"3: the four difficulties in one row, equal height")
	var toggles: Array = ["sfx", "music", "haptics", "reduce_motion"].map(func(k): return _find("Toggle_" + k))
	r.check(toggles.all(func(b): return b != null and absf(b.size.x - toggles[0].size.x) < 0.5 and absf(b.global_position.x - toggles[0].global_position.x) < 0.5),
		"3/11: the ON/OFF buttons one size, in one column")
	var lbls := Game.current_screen.find_children("*", "Label", true, false)
	r.check(lbls.all(func(l): return int((l as Label).get_theme_font_size("font_size")) >= 8), "4: no text under the game's 8 px")
	# selected: yellow
	var cur := Difficulty.mode(false)
	var off := String(Difficulty.MODES.filter(func(m): return m != cur)[0])
	r.check((_find("Diff_" + cur) as Button).get_theme_color("font_color") == Color(UI.BUTTON_STYLES.tab_on[4]) and (_find("Diff_" + off) as Button).get_theme_color("font_color") == UI.TEXT,
		"5: the picked difficulty in yellow, the others navy")
	Game.settings.dev_mode = true
	await _open()
	r.check(_find("DevTools") == null and _find("CoachLab") == null, "39: Developer Mode on: still no developer tools on Settings")
	await _open_dev()
	var tools := ["FormLab", "TempoLab", "AttrLab", "HotLab", "FxLab", "DefenseLab", "RecordLab", "CoachLab"]
	r.check(tools.all(func(t): return _find(t) is Button) and _find("DevTools") != null, "39: Developer Mode on: every developer tool, in its own panel on the DEV screen")
	Game.settings.dev_mode = false
	await _open()
	Game.current_screen.on_back()
	await _frames()
	r.check(Game.current_name == "title", "7: Back leaves Settings")
	await _open_dev()
	r.check(_find("DevTools") == null and _find("CoachLab") == null, "39: off: no developer tools")
	await _open()
	r.check(Game.current_screen.get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT, "9: drawn as ever (the 480 x 270 image scaled up, sharp pixels)")

## The DEV screen the way a player reaches it: Settings, DEV, the code.
func _open_dev() -> void:
	if Game.current_name != "settings":
		await _open()
	(_find("DevButton") as Button).pressed.emit()
	await _frames(1)
	var pad = _pad()
	for d in "8008":
		(pad.find_child("Key" + d, true, false) as Button).pressed.emit()
	(pad.find_child("Unlock", true, false) as Button).pressed.emit()
	await _frames()

func _pad() -> Node:
	return Game.overlay.get_node_or_null("DevPad")

func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

# ------------------------------------------------------------------ DEVELOPER ACCESS
func _dev_access() -> void:
	DevGate.lock()
	Game.goto("dev_settings")
	await _frames()
	r.check(Game.current_name == "settings", "DEV: straight to the DEV screen without the code: Settings instead")
	(_find("DevButton") as Button).pressed.emit()
	await _frames(1)
	var pad = _pad()
	r.check(pad != null and Game.current_name == "settings", "DEV: the DEV button opens the code popup, not the DEV screen")
	var plate := pad.find_child("TitlePlate", true, false) as Control
	r.check(plate != null and (plate.find_children("*", "Label", true, false)[0] as Label).text == "DEVELOPER ACCESS", "DEV: titled DEVELOPER ACCESS")
	var keys := ["Key0", "Key1", "Key2", "Key3", "Key4", "Key5", "Key6", "Key7", "Key8", "Key9", "Backspace", "Cancel", "Unlock"]
	r.check(keys.all(func(k): return pad.find_child(k, true, false) is Button), "DEV: 0-9, backspace, CANCEL and UNLOCK")
	var texts: Array = pad.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	for b in pad.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	r.check(not texts.any(func(t): return String(t).contains("8008")), "DEV: the code is never shown")
	for d in "123456":
		(pad.find_child("Key" + d, true, false) as Button).pressed.emit()
	r.check(pad.entered.length() == 4, "DEV: never more than four digits (%d)" % pad.entered.length())
	(pad.find_child("Backspace", true, false) as Button).pressed.emit()
	r.check(pad.entered == "123", "DEV: backspace takes one off")
	(pad.find_child("Key9", true, false) as Button).pressed.emit()
	(pad.find_child("Unlock", true, false) as Button).pressed.emit()
	await _frames(1)
	var st := pad.find_child("Status", true, false) as Label
	r.check(st.text == "INCORRECT CODE" and st.get_theme_color("font_color") == Color("ff5a5a") and pad.entered == "" and Game.current_name == "settings" and not DevGate.is_open(),
		"DEV: a wrong code: INCORRECT CODE in red, the digits cleared, no access")
	# the keyboard
	for k in [KEY_8, KEY_0, KEY_KP_0, KEY_9]:
		_key(k)
	r.check(pad.entered == "8009", "DEV: digits from the keyboard (and keypad) %s" % pad.entered)
	_key(KEY_BACKSPACE)
	r.check(pad.entered == "800", "DEV: Backspace from the keyboard")
	var was: Dictionary = Game.settings.duplicate(true)
	(pad.find_child("Cancel", true, false) as Button).pressed.emit()
	await _frames(1)
	r.check(_pad() == null and Game.current_name == "settings" and Game.settings == was and not DevGate.is_open(), "DEV: CANCEL closes it, nothing changed")
	r.check(not DevGate.try_unlock("800") and not DevGate.try_unlock("80080") and not DevGate.try_unlock("") and not DevGate.try_unlock("abcd"), "DEV: only the exact code")
	(_find("DevButton") as Button).pressed.emit()
	await _frames(1)
	pad = _pad()
	for k in [KEY_8, KEY_0, KEY_0, KEY_8]:
		_key(k)
	(pad.find_child("Unlock", true, false) as Button).pressed.emit()
	await _frames()
	r.check(Game.current_name == "dev_settings" and _pad() == null, "DEV: the right code opens the DEV screen at once")
	r.check(_find("Toggle_dev_mode") is Button and _find("ResetGame") is Button and _find("ResetRow") is PanelContainer and _find("ResetWarning") is Label,
		"DEV: Developer Mode and the DANGER ZONE (RESET EVERYTHING, its warning) on the DEV screen")
	var all_in := true
	for n in Game.current_screen.find_children("*", "Control", true, false):
		if n is Control and (n as Control).is_visible_in_tree() and (n is Button or n is PanelContainer) and not _inside(n):
			all_in = false
	r.check(all_in, "DEV: everything inside the screen")
	# a lab and back keeps the session; Back to Settings ends it
	Game.settings.dev_mode = true
	Game.current_screen._refresh()
	(_find("FormLab") as Button).pressed.emit()
	await _frames()
	Game.current_screen.on_back()
	await _frames()
	r.check(Game.current_name == "dev_settings", "DEV: a lab's Back returns to the DEV screen")
	Game.settings.dev_mode = false
	Game.current_screen.on_back()
	await _frames()
	r.check(Game.current_name == "settings" and not DevGate.is_open(), "DEV: Back returns to Settings and closes the session")
	Game.goto("dev_settings")
	await _frames()
	r.check(Game.current_name == "settings", "DEV: reopening it asks for the code again")
	DevGate.try_unlock("8008")
	Game.goto("title")
	await _frames()
	r.check(not DevGate.is_open(), "DEV: leaving for the menus closes the session")

# ------------------------------------------------------------------ 33-40
func _toggles() -> void:
	await _open()
	for k in ["sfx", "music", "haptics", "reduce_motion"]:
		var was: bool = Game.settings[k]
		(_find("Toggle_" + k) as Button).pressed.emit()
		await _frames(1)
		var now: bool = Game.settings[k]
		var b := _find("Toggle_" + k) as Button
		r.check(now == not was and b.text == ("ON" if now else "OFF"), "34-37: %s toggles (%s -> %s)" % [k, was, now])
		b.pressed.emit()
		await _frames(1)
	for m in Difficulty.MODES:
		(_find("Diff_" + m) as Button).pressed.emit()
		await _frames(1)
		r.check(Difficulty.mode(false) == m and (_find("DiffNote") as Label).text.begins_with(String(Game.current_screen.DIFF_NOTES[m]).substr(0, 20)), "33: %s picked, its note underneath" % m)
	Difficulty.set_mode("normal")
	await _open_dev()
	var dev: bool = Game.settings.dev_mode
	(_find("Toggle_dev_mode") as Button).pressed.emit()
	await _frames(1)
	r.check(Game.settings.dev_mode == not dev and (_find("DevTools") != null) == Game.settings.dev_mode, "39: DEVELOPER MODE switches, its tools with it")
	(_find("Toggle_dev_mode") as Button).pressed.emit()
	await _frames(1)
	(_find("ResetGame") as Button).pressed.emit()
	await _frames(1)
	var dialogs := Game.overlay.get_children().filter(func(l): return l is Control and l.mouse_filter == Control.MOUSE_FILTER_STOP)
	r.check(dialogs.size() == 1 and Game.current_name == "dev_settings", "40: RESET EVERYTHING asks first (nothing reset yet)")
	for l in dialogs:
		l.queue_free()
	await _frames(1)
	await _open()
	# Reduce Motion: no pop
	Game.test_mode = false
	Game.settings.reduce_motion = true
	(_find("QuarterLength") as Button).pressed.emit()
	await _frames(1)
	r.check((_find("QuarterLength") as Control).scale == Vector2.ONE, "10/16: Reduce Motion on: the button changes without its pop")
	Game.settings.reduce_motion = false
	(_find("QuarterLength") as Button).pressed.emit()   # (checked at once: the pop is 0.22 s)
	r.check((_find("QuarterLength") as Control).scale.x > 1.0, "16: ...off: a short pop as it changes")
	Game.test_mode = true
	for _i in 2:
		(_find("QuarterLength") as Button).pressed.emit()   # (back round to where it was)
	await _frames(1)
	Game.settings.quarter_min = 2

# ------------------------------------------------------------------ 11-16, 27-30
func _quarter_button() -> void:
	var c := Career.new_game("SJCU", "A", "B", 701)
	c.queue.clear()
	Game.career = c
	Game.settings.quarter_min = 5   # (the device's Quick Match length never leaks into a new career)
	r.check(c.quarter_min == 2, "11/29: a new dynasty: 2-minute quarters")
	await _open()
	var b := _find("QuarterLength") as Button
	r.check(b.text == "2 MIN" and (_find("QuarterScope") as Label).text.begins_with("YOUR DYNASTY"), "12: QUARTER LENGTH shows 2 MIN (your dynasty's)")
	var seen: Array = []
	for _i in 4:
		(_find("QuarterLength") as Button).pressed.emit()
		await _frames(1)
		seen.append((_find("QuarterLength") as Button).text)
	r.check(seen == ["3 MIN", "4 MIN", "5 MIN", "2 MIN"], "13-16: one click each: 3, 4, 5, then 2 again %s" % str(seen))
	r.check(_find("Gameplay").find_children("*", "OptionButton", true, false).is_empty() and _find("Gameplay").find_children("*", "Slider", true, false).is_empty(), "Part 4: one button (no dropdown, no slider)")
	for _i in 2:
		(_find("QuarterLength") as Button).pressed.emit()
	await _frames(1)
	r.check(c.quarter_min == 4 and int(Game.settings.quarter_min) == 5, "27: 4 MIN saved with the career (Quick Match's own untouched)")
	Game.goto("hub")
	await _frames()
	await _open()
	r.check((_find("QuarterLength") as Button).text == "4 MIN", "28: reopening Settings keeps 4 MIN")
	Game.career = null
	await _open()
	r.check((_find("QuarterLength") as Button).text == "5 MIN" and (_find("QuarterScope") as Label).text.begins_with("QUICK MATCH"), "Part 19: no career: Quick Match's own length")
	Game.settings.quarter_min = 2

func _saves() -> void:
	var c := Career.new_game("SJCU", "A", "B", 702)
	c.quarter_min = 4
	var re := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(re.quarter_min == 4, "27: saved and reloaded: 4 MIN")
	var old := c.to_dict()
	old.erase("quarter_min")
	r.check(Career.from_dict(JSON.parse_string(JSON.stringify(old))).quarter_min == 2, "30/41: an older save without it: 2 MIN, and it loads")
	old["quarter_min"] = 7
	r.check(Career.from_dict(old).quarter_min == 2 and MatchState.valid_quarter_min("x") == 2, "30: a bad value: 2 MIN")
	r.check(Career.new_game("SJCU", "C", "D", 703).quarter_min == 2, "29: every new career: 2 MIN")

# ------------------------------------------------------------------ 17-26, 32
## One whole match at `mins` a quarter (the test runner's autopilot): what the clocks did.
func _game(mins: float, seed_value: int) -> Dictionary:
	var teams := [League.make_team(1, 0), League.make_team(4, 0)]
	var f := MatchFlow.new(teams[0], teams[1], seed_value, mins)
	var out := {"starts": [f.state.clock_text()], "ends": [], "half": false, "shot_clocks": [], "excl": 0, "steps": 0}
	var steps := 0
	while f.phase != MatchFlow.Phase.FINAL and steps < 400000:
		steps += 1
		match f.phase:
			MatchFlow.Phase.SPRINT:
				f.sprint_done(f.rng.randf() < 0.5)
				if f.play != null:
					out.shot_clocks.append(f.play.shot_clock)
			MatchFlow.Phase.ATTACK:
				r._run_flow_attack(f)
				f.attack_done()
			MatchFlow.Phase.DEFENSE:
				f.auto_defense(0.5)
				f.defense_done()
			MatchFlow.Phase.SHOOTOUT_THEM:
				f.their_ball_done()
			MatchFlow.Phase.THEIR_SHOT:
				f.auto_duel(0.5)
				f.duel_done()
			MatchFlow.Phase.BREAK:
				out.ends.append([f.state.quarter, f.state.clock])
				if f.state.quarter == 2:
					out.half = f.at_halftime()
				f.break_done()
				out.starts.append(f.state.clock_text())
	out["flow"] = f
	out["final"] = f.phase == MatchFlow.Phase.FINAL
	return out

func _matches() -> void:
	var shots := {2: 0, 5: 0}
	var by := {}
	for mins in [2, 3, 4, 5]:
		var g := _game(float(mins), 900 + mins)
		by[mins] = g
		var f: MatchFlow = g.flow
		var want := "%d:00" % mins
		r.check(g.final and f.state.quarter == 4 and is_equal_approx(f.state.quarter_len, mins * 60.0), "17/21: %d MIN: four quarters of %d:00, regulation ends after the fourth" % [mins, mins])
		r.check((g.starts as Array).slice(0, 4).all(func(s): return s == want), "18: every quarter starts at %s on the scoreboard %s" % [want, str((g.starts as Array).slice(0, 4))])
		r.check((g.ends as Array).slice(0, 3).all(func(e): return int(e[1]) == 0) and (g.ends as Array).slice(0, 3).map(func(e): return int(e[0])) == [1, 2, 3], "19: quarters end at 0:00, one after another")
		r.check(g.half, "20: halftime after the second quarter")
		r.check(f.state.winner() != -1, "24: a winner (a tie still goes to the shootout, as before)")
	r.check(Play.SHOT_CLOCK == 30.0 and MatchState.CLOCK_SPEED == 1.25 and MatchState.TURNOVER_TIME == 10.0 and MatchState.QUARTERS == 4, "22/Part 6: the shot clock (30), clock speed and quarters as they were")
	var sc5: Array = by[5].shot_clocks
	r.check(not sc5.is_empty() and sc5.all(func(s): return float(s) <= Play.SHOT_CLOCK + 0.001), "22: 5 MIN: no shot clock past 30 s")
	for seed_off in 3:
		shots[2] += _total(_game(2.0, 950 + seed_off).flow)
		shots[5] += _total(_game(5.0, 950 + seed_off).flow)
	r.check(shots[5] > shots[2] * 1.8, "25: longer quarters, more of the game: shots + goals over three games, 2 MIN %d, 5 MIN %d" % [shots[2], shots[5]])
	var f5: MatchFlow = by[5].flow
	r.check(f5.state.exclusions[0] + f5.state.exclusions[1] >= 0 and f5.state.pf.size() >= 0, "23: exclusions counted as ever (%s)" % str(f5.state.exclusions))
	# XP: the same rules on a bigger line
	var t := League.make_team(1, 0)
	var p: PoloPlayer = t.starters()[2]
	var small := Development.game_xp(p, {"g": 2, "a": 1}, true)
	var big := Development.game_xp(p, {"g": 5, "a": 3}, true)
	r.check(big > small and small > 0, "26: game XP from the same table, more for more (%d vs %d)" % [small, big])
	# simulated games: unchanged
	var c := Career.new_game("SJCU", "A", "B", 704)
	c.queue.clear()
	c.quarter_min = 5
	var guard := 0
	while not c.has_game() and guard < 5:
		guard += 1
		c.end_week()
	var res: Dictionary = c.sim_my_game()
	r.check(not res.is_empty() and c.game_done_this_week(), "32: a simulated game plays as ever with a 5 MIN setting")

func _total(f: MatchFlow) -> int:
	return f.state.shots[0] + f.state.shots[1] + f.state.score[0] + f.state.score[1]

# ------------------------------------------------------------------ 17, 31: the real match screen
func _match_start() -> void:
	var c := Career.new_game("SJCU", "A", "B", 705)
	c.queue.clear()
	var guard := 0
	while not c.has_game() and guard < 5:
		guard += 1
		c.end_week()
	Game.career = c
	c.quarter_min = 3
	Game.goto("matchup")
	await _frames()
	if Game.current_name != "matchup":
		r.check(false, "17: the matchup screen opens (%s)" % Game.current_name)
		return
	Game.current_screen._play()
	await _frames(4)
	var ms = Game.current_screen
	r.check(Game.current_name == "match" and is_equal_approx(ms.flow.state.quarter_len, 180.0) and float(Game.match_cfg.minutes) == 3.0, "17: PLAY: the career game's quarters are 3:00")
	c.quarter_min = 5   # (Settings can't be reached mid-match; even so, the game under way keeps its clock)
	r.check(is_equal_approx(ms.flow.state.quarter_len, 180.0), "31: a change after kick-off never touches the game under way")
	Game.current_screen.queue_free()
	Game.current_screen = null
	Game.current_name = ""
	Game.career = null

const DevPad := preload("res://src/ui/dev_pad.gd")

static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var kept: Dictionary = Game.settings.duplicate(true)
	var snap := func(name: String) -> void:
		await tree.create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(name))
	Game.career = null
	Game.settings.dev_mode = false
	Game.settings.difficulty = "hard"
	Game.goto("settings")
	await snap.call("s1_settings.png")
	var c := Career.new_game("SJCU", "A", "B", 701)
	c.queue.clear()
	c.quarter_min = 4
	Game.career = c
	Game.settings.dev_mode = true
	Game.settings.difficulty = "dynamic"
	c.difficulty = "dynamic"
	Game.goto("settings")
	await snap.call("s2_career.png")
	var pad = DevPad.open()
	pad.add_digit("8")
	pad.add_digit("0")
	await snap.call("s3_dev_pad.png")
	pad.unlock()
	await snap.call("s4_dev_pad_wrong.png")
	pad.cancel()
	DevGate.try_unlock("8008")
	Game.goto("dev_settings")
	await snap.call("s5_dev_screen.png")
	Game.settings.dev_mode = false
	Game.current_screen._refresh()
	await snap.call("s6_dev_screen_off.png")
	Game.settings = kept
	Game.career = null
	print("  shots")
