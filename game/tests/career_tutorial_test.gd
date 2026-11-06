extends RefCounted
## NEW CAREER -> TUTORIAL -> CAREER: the tutorial opening every new career, its pop-ups, SKIP,
## TRAINING COMPLETE, that a loaded career never meets it, that it leaves the career as it found
## it, and that the Coaching Tips are gone (the spec's testing list, by number).
##   godot --headless --path game -- --test career_tutorial

const DT := 1.0 / 30.0
const DIR := "user://career_tutorial_test/"

var r
var tree: SceneTree

func run(runner) -> void:
	r = runner
	tree = r.get_tree()
	print("career tutorial")
	Store.reset_for_tests()
	var kept: Dictionary = Game.settings.duplicate(true)
	var kept_dir := Game.save_dir
	var kept_slot := Game.slot
	var kept_career = Game.career
	var kept_progress = Game.progress
	DirAccess.make_dir_recursive_absolute(DIR)
	_clear()
	Game.save_dir = DIR
	Game.progress = Progression.fresh()
	await _launch()
	await _popups()
	await _skip_everywhere()
	await _completes()
	await _loading()
	await _no_tips()
	_layout()
	_clear()
	Game.save_dir = kept_dir
	Game.slot = kept_slot
	Game.career = kept_career
	Game.progress = kept_progress
	Game.settings = kept
	Game.save_settings()
	Game.history.clear()
	Game.goto("title", {}, false)
	await tree.process_frame

func _clear() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)

# ------------------------------------------------------------------ helpers
## A new career the way a player makes one: the NEW CAREER screen's START.
func _new_career():
	_clear()
	Game.career = null
	Game.slot = 1
	Game.goto("new_career")
	for _i in 3:
		await tree.process_frame
	var scr = Game.current_screen
	scr.first = "Sam"
	scr.last = "Rivera"
	await _for_real(func(): scr._start())
	return Game.current_screen

## `act` out of test mode, so what it saves is really written (Game.save_career), its screen
## change fading in as it does for a player.
func _for_real(act: Callable) -> void:
	Game.test_mode = false
	act.call()
	await tree.create_timer(0.4).timeout
	Game.test_mode = true

func _touch(ms, pos: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = pos
	e.pressed = down
	e.index = 0
	ms._input(e)

func _tap(ms, pos: Vector2) -> void:
	_touch(ms, pos, true)
	_touch(ms, pos, false)

func _labels(ms) -> Array:
	return ms.buttons_now(ms.get_viewport_rect().size).map(func(b): return b[1])

func _press(ms, label: String) -> bool:
	for b in ms.buttons_now(ms.get_viewport_rect().size):
		if b[1] == label:
			_tap(ms, (b[0] as Rect2).get_center())
			return true
	return false

func _steps(ms, secs: float) -> void:
	var t := 0.0
	while t < secs:
		ms._process(DT)
		t += DT

func _until(ms, cond: Callable, limit: float = 10.0) -> bool:
	var t := 0.0
	while t < limit:
		if cond.call():
			return true
		ms._process(DT)
		t += DT
	return cond.call()

## The career as a save holds it, its tutorial state aside.
func _state(c: Career) -> String:
	var d := c.to_dict()
	d.erase("tutorial")
	return JSON.stringify(d)

func _saved_tutorial(n: int = 1) -> String:
	var d = JSON.parse_string(FileAccess.get_file_as_string(Game.slot_path(n)))
	return String(d.get("tutorial", "<none>"))

# ------------------------------------------------------------------ 1: it launches
func _launch() -> void:
	var ms = await _new_career()
	r.check(Game.current_name == "drill" and ms.in_career, "1: a new career opens the tutorial (%s)" % Game.current_name)
	r.check(Game.career != null and Game.career.tutorial == Career.TUTORIAL_PENDING and _saved_tutorial() == Career.TUTORIAL_PENDING, "1: the career is already made and saved, the tutorial pending")
	r.check(Game.slot_exists(1), "1: in its slot")
	r.check(ms.part == 0 and ms.drill_id == "frontcourt", "1: from part 1")
	# a second career gets it too, whatever the practice run had kept as done
	Game.settings["tutorials_done"] = Drill.ORDER.duplicate()
	ms = await _new_career()
	r.check(Game.current_name == "drill" and ms.part == 0, "1: every new career, from part 1, whatever's been practised")
	r.check((Game.settings.tutorials_done as Array).size() == Drill.ORDER.size(), "1: the practice run's progress left alone")
	Game.settings["tutorials_done"] = []

# ------------------------------------------------------------------ 2, 3: the pop-ups
func _popups() -> void:
	var ms = await _new_career()
	for i in Drill.ORDER.size():
		var id: String = Drill.ORDER[i]
		var drill_ := ms.drill as Drill
		r.check(ms.drill_id == id, "2: part %d is %s" % [i + 1, id])
		r.check(String(ms.popup.title) == String(Drill.TITLES[id]) and ms.popup.lines == Drill.BRIEFS[id], "2: %s opens on its pop-up" % id)
		r.check(_labels(ms).has("GOT IT") and _labels(ms).has("SKIP TUTORIAL"), "2: %s: GOT IT, and SKIP TUTORIAL still there %s" % [id, str(_labels(ms))])
		# held: time passes, nothing moves, and a touch on the water plays nothing
		_steps(ms, 0.6)
		var p: Play = ms.flow.play
		r.check(p.elapsed == 0.0, "3: %s: the play waits for GOT IT" % id)
		var size: Vector2 = ms.get_viewport_rect().size
		_tap(ms, Vector2(size.x * 0.75, size.y * 0.8))
		_tap(ms, Vector2(size.x * 0.15, size.y * 0.8))
		r.check(p.ball.state != Ball.State.PASS and not ms.popup.is_empty() and ms.flow.duel == null, "3: %s: a touch off the button does nothing" % id)
		r.check(_press(ms, "GOT IT") and ms.popup.is_empty(), "3: %s: GOT IT closes it" % id)
		_steps(ms, 0.2)
		r.check(ms.flow.play.elapsed > 0.0 and ms.drill == drill_, "3: %s: and the part begins at once" % id)
		_steps(ms, 0.8)
		r.check(ms.popup.is_empty(), "3: %s: no message during the part" % id)
		if i + 1 < Drill.ORDER.size():
			ms.drill.complete = true
			r.check(_until(ms, func(): return ms.drill_id != id, 6.0), "3: %s: done, on to the next" % id)
	# the keyboard's way
	ms._start_part(0, false)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_ENTER
	ms._input(key)
	r.check(ms.popup.is_empty(), "3: Enter is GOT IT on a keyboard")
	# RESTART goes straight back in: you've read it
	_steps(ms, 0.3)
	r.check(_press(ms, "RESTART") and ms.popup.is_empty() and ms.part == 0, "4: RESTART: this part again, no pop-up")
	# nothing can stop the clock under a pop-up, or stack a pause on one
	ms._start_part(1, false)
	ms._pause()
	r.check(not ms.paused, "3: no pause menu over a pop-up")
	ms._close_popup()
	ms._pause()
	r.check(ms.paused, "5: the pause menu in play")
	var dlg: Control = Game.overlay.get_child(Game.overlay.get_child_count() - 1)
	var words: Array = []
	_button_texts(dlg, words)
	r.check(words.has("SKIP TUTORIAL") and not words.has("MAIN MENU") and not words.has("START OVER"), "5: ...has SKIP TUTORIAL, no way round the career %s" % str(words))
	dlg.queue_free()
	ms.paused = false

func _button_texts(n: Node, out: Array) -> void:
	if n is Button:
		out.append((n as Button).text)
	for ch in n.get_children():
		_button_texts(ch, out)

# ------------------------------------------------------------------ 5, 6, 12: skipping
func _skip_everywhere() -> void:
	for i in Drill.ORDER.size():
		for stage in ["popup", "play", "segue"]:
			if stage == "segue" and i + 1 >= Drill.ORDER.size():
				continue
			var ms = await _new_career()
			var c: Career = Game.career
			var before := _state(c)
			var done_before: Array = (Game.settings.tutorials_done as Array).duplicate()
			var where := "part %d %s" % [i + 1, stage]
			ms._start_part(i, false)
			if stage != "popup":
				ms._close_popup()
				_steps(ms, 0.4)
			if stage == "segue":
				ms.drill.complete = true
				_until(ms, func(): return ms.segue_t >= 0.0, 6.0)
			var under: Dictionary = ms.popup
			r.check(_press(ms, "SKIP TUTORIAL"), "5: %s: SKIP TUTORIAL is there" % where)
			r.check(String(ms.popup.title) == "SKIP TUTORIAL?" and _labels(ms) == ["CANCEL", "SKIP"], "5: %s: asks first, CANCEL and SKIP only" % where)
			var t0: float = ms.flow.play.elapsed
			var seg: float = ms.segue_t
			_steps(ms, 0.5)
			r.check(ms.flow.play.elapsed == t0 and ms.segue_t == seg, "5: %s: everything waits on the question" % where)
			_press(ms, "CANCEL")
			r.check(Game.current_name == "drill" and ms.popup == under and c.tutorial == Career.TUTORIAL_PENDING, "5: %s: CANCEL puts it back" % where)
			_press(ms, "SKIP TUTORIAL")
			await _for_real(func(): _press(ms, "SKIP"))
			r.check(Game.current_name == "hub" and Game.history.is_empty(), "5: %s: SKIP goes straight to the career" % where)
			r.check(Game.career == c and _state(c) == before, "6/12: %s: the career exactly as it was made" % where)
			r.check(c.tutorial == Career.TUTORIAL_SKIPPED and _saved_tutorial() == Career.TUTORIAL_SKIPPED, "5: %s: marked skipped, and saved" % where)
			r.check(Game.settings.tutorials_done == done_before, "12: %s: no tutorial progress given" % where)

# ------------------------------------------------------------------ 4, 7, 12: all the way through
func _completes() -> void:
	var ms = await _new_career()
	var c: Career = Game.career
	var before := _state(c)
	var settings_done: Array = (Game.settings.tutorials_done as Array).duplicate()
	for i in Drill.ORDER.size():
		r.check(ms.part == i and not ms.popup.is_empty(), "7: part %d behind its pop-up" % (i + 1))
		_press(ms, "GOT IT")
		_steps(ms, 0.3)
		ms.drill.complete = true
		if i + 1 < Drill.ORDER.size():
			r.check(_until(ms, func(): return ms.part == i + 1, 6.0), "7: part %d hands on" % (i + 1))
	r.check(_until(ms, func(): return ms.card_on, 6.0), "7: the last part done, the card")
	r.check(String(ms.popup.title) == "TRAINING COMPLETE!" and ms.popup.lines == ["You're ready to start your career."], "7: TRAINING COMPLETE!")
	r.check(_labels(ms) == ["START CAREER"], "7: START CAREER and nothing else %s" % str(_labels(ms)))
	r.check(c.tutorial == Career.TUTORIAL_PENDING, "7: not marked until it's left")
	await _for_real(func():
		_press(ms, "START CAREER")
		_press(ms, "START CAREER"))   # (a second tap in the fade)
	r.check(Game.current_name == "hub" and Game.career == c, "7: START CAREER goes into the career")
	r.check(c.tutorial == Career.TUTORIAL_COMPLETED and _saved_tutorial() == Career.TUTORIAL_COMPLETED, "7: marked completed, and saved")
	r.check(_state(c) == before, "12: nothing in the career changed: stats, standings, development, injuries, season")
	r.check(Game.settings.tutorials_done == settings_done, "12: no tutorial progress written")
	r.check(c.phase == "season", "7: the season's ready to play")

# ------------------------------------------------------------------ 8: a loaded career
func _loading() -> void:
	# every way a career comes back, in every state it can be saved in, even left half way through
	for state in [Career.TUTORIAL_PENDING, Career.TUTORIAL_SKIPPED, Career.TUTORIAL_COMPLETED, ""]:
		await _new_career()
		Game.career.tutorial = state
		await _for_real(func(): Game.save_career())
		Game.career = null
		Game.goto("careers", {}, false)
		await tree.process_frame
		Game.current_screen._pick(1, Game.slot_summary(1))
		await tree.process_frame
		r.check(Game.current_name == "hub" and Game.career != null and Game.career.tutorial == state, "8: loading a career (tutorial '%s') opens the hub" % state)
		Game.career = null
		Game.goto("title", {}, false)
		await tree.process_frame
		Game.current_screen._continue()
		await tree.process_frame
		r.check(Game.current_name != "drill" and Game.career != null, "8: and CONTINUE (tutorial '%s') too" % state)
	# a save from before the tutorial joined the career
	var old: Dictionary = Game.career.to_dict()
	old.erase("tutorial")
	r.check(Career.from_dict(old).tutorial == "", "8: an older save has no tutorial to do")
	# nothing launches it but NEW CAREER (and the guide's practice run)
	var launchers: Array = []
	_scan("res://src", func(path: String, text: String):
		if text.contains("goto(\"drill\""):
			launchers.append(path.get_file()))
	launchers.sort()
	r.check(launchers == ["howto.gd", "new_career.gd"], "8: only NEW CAREER and the GAME GUIDE open it %s" % str(launchers))
	# the practice run from the guide: pop-ups, no career, BACK as ever
	await _new_career()
	var c: Career = Game.career
	var before := JSON.stringify(c.to_dict())
	Game.goto("drill")
	await tree.process_frame
	var ms = Game.current_screen
	r.check(not ms.in_career and not ms.popup.is_empty() and _labels(ms).has("BACK") and not _labels(ms).has("SKIP TUTORIAL"), "the guide's practice run: its pop-ups, BACK, no SKIP")
	ms._close_popup()
	r.check(JSON.stringify(c.to_dict()) == before, "the guide's practice run leaves the career alone")
	# the title's menu: the tutorial belongs to the career now
	Game.goto("title", {}, false)
	await tree.process_frame
	var words: Array = []
	_button_texts(Game.current_screen, words)
	r.check(words.has("NEW CAREER") and not words.has("TUTORIAL"), "the title has no separate TUTORIAL")

# ------------------------------------------------------------------ 9: no Coaching Tips
func _no_tips() -> void:
	var left: Array = []
	_scan("res://src", func(path: String, text: String):
		for word in ["Tips.", "MatchTips", "tips_seen", "_show_tip", "_close_tip", "COACHING TIPS", "ShowTips", "Hud.hint", "DefenseView.hint", "DIVE_HINT", "hint_left"]:
			if text.contains(word):
				left.append("%s: %s" % [path.get_file(), word]))
	r.check(left.is_empty(), "9: nothing of the tips left in the game %s" % str(left))
	r.check(not ResourceLoader.exists("res://src/ui/tips.gd") and not ResourceLoader.exists("res://src/match/match_tips.gd"), "9: their scripts are gone")
	r.check(not Game.settings.has("tips_seen"), "9: no setting for them")
	Game.goto("settings")
	await tree.process_frame
	r.check(Game.current_screen.find_child("ShowTips", true, false) == null, "9: no row in Settings")
	# a first game: nothing stops the play, no coach on the screen, however new you are
	Game.goto("match", {"us": League.make_team(3), "them": League.make_team(0), "seed": 12, "minutes": 2.0, "level": 0.5})
	await tree.process_frame
	var ms = Game.current_screen
	ms.flow.sprint_done(true)
	UI.drawn_log = []
	for _i in 12:
		await tree.process_frame
	var e0: float = ms.flow.play.elapsed
	for _i in 12:
		await tree.process_frame
	r.check(ms.flow.play.elapsed > e0, "9: the first attack plays straight away")
	ms.flow._start_defense(Play.Kind.HALF_COURT)
	for _i in 6:
		await tree.process_frame
	var dp: Play = ms.flow.play
	var d0: float = dp.elapsed
	for _i in 12:
		await tree.process_frame
	r.check(dp.elapsed > d0, "9: so does their first attack")
	var log: Array = UI.drawn_log
	UI.drawn_log = null
	r.check(not log.any(func(s): return "COACH" in String(s) or "TAP THE" in String(s) or "TO GO ON" in String(s) or "YOU'RE THE KEEPER" in String(s)), "9: no tip or hint drawn in play")
	# the real coaching stays: the gameplan and the drop bar in the match, the screens
	r.check(ms.flow.phase == MatchFlow.Phase.DEFENSE and FormationBar.shown(ms.flow), "10: the formation bar is still the match's")
	Game.goto("title", {}, false)
	await tree.process_frame

func _scan(dir: String, visit: Callable) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			visit.call(dir + "/" + f, FileAccess.get_file_as_string(dir + "/" + f))
	for d in DirAccess.get_directories_at(dir):
		_scan(dir + "/" + d, visit)

# ------------------------------------------------------------------ 11: phone screens
func _layout() -> void:
	var ms = load("res://src/tutorial/drill_screen.gd").new()
	ms.setup({})
	ms.in_career = true
	# the narrowest screen there is (480 wide) and a wide phone, with its notch insets
	for size in [Vector2(480, 270), Vector2(585, 270)]:
		var strip: Array = ms._strip_buttons(size)
		r.check(UI.text_width("SKIP TUTORIAL", 8, "caps") <= (strip[0][0] as Rect2).size.x - 2, "11: SKIP TUTORIAL fits its button")
		r.check(UI.text_width("RESTART", 8, "caps") <= (strip[1][0] as Rect2).size.x - 2, "11: RESTART fits its button")
		var mid: float = (strip[1][0] as Rect2).position.x - 4 - ((strip[0][0] as Rect2).end.x + 4)
		for id in Drill.ORDER:
			var d := Drill.make(id)
			r.check(UI.text_width(d.instruction(), 8, "body") <= mid, "11: %s's instruction fits the strip (%d in %d)" % [id, UI.text_width(d.instruction(), 8, "body"), mid])
			if d is ShootingDrill:
				(d as ShootingDrill).cross = ShootingDrill.GOALS
				r.check(UI.text_width(d.instruction(), 8, "body") <= mid, "11: and its second (%d in %d)" % [UI.text_width(d.instruction(), 8, "body"), mid])
			ms.drill = d
			ms.part = Drill.ORDER.find(id)
			r.check(UI.text_width(ms.part_line(), 8, "caps") <= mid, "11: %s's progress fits the strip (%d in %d)" % [id, UI.text_width(ms.part_line(), 8, "caps"), mid])
			for line in Drill.BRIEFS[id]:
				r.check(UI.text_width(String(line), 16, "body") <= ms.POP_W - 8, "11: %s's pop-up line fits (%d)" % [id, UI.text_width(String(line), 16, "body")])
			r.check(UI.text_width(String(Drill.TITLES[id]), 16, "big") <= ms.POP_W - 8, "11: %s's title fits" % id)
		for line in ["You're ready to start your career.", "You can skip training and jump", "straight into your career."]:
			r.check(UI.text_width(line, 16, "body") <= ms.POP_W - 8, "11: '%s' fits (%d)" % [line, UI.text_width(line, 16, "body")])
		r.check(UI.text_width("START CAREER", 16, "caps") <= ms.POP_BTN.x - 4, "11: START CAREER fits its button")
		var pop: Rect2 = ms._popup_rect(size)
		r.check(pop.position.x >= 16 and pop.end.x <= size.x - 16 and pop.position.y >= ms.BAR_H and pop.end.y <= size.y, "11: the pop-up is on the screen, under the strip")
		r.check(absf(pop.get_center().x - size.x / 2.0) <= 1.0 and absf(pop.get_center().y - size.y / 2.0) <= 1.0, "11: and centred")
		ms.popup = {"title": "X", "lines": [], "buttons": [["CANCEL", Callable(), false], ["SKIP", Callable(), true]]}
		for b in ms._popup_buttons(size):
			var br: Rect2 = b[0]
			r.check(pop.encloses(br) and br.size.y >= 30.0, "11: %s: inside it, and big enough for a thumb" % b[1])
	ms.free()
