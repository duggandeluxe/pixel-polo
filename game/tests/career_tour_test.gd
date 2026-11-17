extends RefCounted
## THE FIRST CAREER TOUR (CareerTour): only the first-ever career starts it, once, for good (the
## global flag, never a save); the whole walk through the real screens (home, Dynasty Hub, Roster,
## Training, Coaching, Recruiting) with NEXT and the real buttons; BACK; SKIP; a dialog hiding it;
## TUTORIAL PAUSED and RESUME; the box clear of what it highlights; nothing in the career changed.
##   godot --headless --path game -- --test career_tour
##   godot --path game --resolution 1440x810 -- --test career_tour_png <dir>   (every step, PNGs)

var r
var tree: SceneTree

func run(runner) -> void:
	r = runner
	tree = r.get_tree()
	print("career tour")
	var kept: Dictionary = Game.settings.duplicate(true)
	var kept_career = Game.career
	CareerTour.force_in_tests = true
	_flag_rules()
	await _walkthrough(null)
	await _back_and_skip()
	await _dialog_and_pause()
	await _pin_section()
	await _replay_from_settings()
	await _ends_quietly()
	CareerTour.force_in_tests = false
	_end_tour()
	Game.settings = kept
	Game.career = kept_career
	Game.history.clear()
	Game.goto("title", {}, false)
	await tree.process_frame

## Every step as a PNG (a window run), for judging the look at a resolution.
func run_png(runner, dir: String) -> void:
	r = runner
	tree = r.get_tree()
	var kept: Dictionary = Game.settings.duplicate(true)
	CareerTour.force_in_tests = true
	DirAccess.make_dir_recursive_absolute(dir)
	await _walkthrough(dir)
	CareerTour.force_in_tests = false
	_end_tour()
	Game.settings = kept


# ------------------------------------------------------------------ helpers
func _career(seed_value: int) -> Career:
	var c := Career.new_setup(seed_value).begin("CULA", "Sam", "Rivera")
	c.queue.clear()   # (the welcome dialog: tested on its own in _dialog_and_pause)
	return c

func _frames(n: int = 3) -> void:
	for _i in n:
		await tree.process_frame

func _tour() -> CareerTour:
	return CareerTour.current()

func _end_tour() -> void:
	var t := _tour()
	if t != null:
		t.get_parent().remove_child(t)
		t.free()

func _press(n: Node) -> void:
	if n is BaseButton:
		(n as BaseButton).pressed.emit()

func _tour_button(nm: String) -> Node:
	var t := _tour()
	return null if t == null else t.find_child(nm, true, false)

## A fresh first career on its home screen, the flag as a new player has it.
func _fresh_hub(seed_value: int) -> Career:
	_end_tour()
	Game.settings.career_tour = ""
	Game.settings.career_tour_uid = ""
	var c := _career(seed_value)
	Game.career = c
	CareerTour.note_new_career(c, false)
	Game.history.clear()
	Game.goto("hub", {}, false)
	await _frames(4)
	return c

# ------------------------------------------------------------------ the flag
func _flag_rules() -> void:
	_end_tour()
	var c1 := _career(11)
	var c2 := _career(12)
	# the first-ever career: pending, for that career
	Game.settings.career_tour = ""
	Game.settings.career_tour_uid = ""
	CareerTour.note_new_career(c1, false)
	r.check(Game.settings.career_tour == CareerTour.PENDING and Game.settings.career_tour_uid == c1.uid, "T1: the first-ever career is given the tour")
	# a second career (created while the first's tour is still to come): not given it
	CareerTour.note_new_career(c2, true)
	r.check(Game.settings.career_tour_uid == c1.uid, "T2: a second career never takes the tour")
	Game.career = c2
	r.check(CareerTour.maybe_start() == null, "T3: the second career's home screen doesn't start it")
	# the first career opened: it starts, and is marked seen at once
	Game.career = c1
	var t := CareerTour.maybe_start()
	r.check(t != null and Game.settings.career_tour == CareerTour.SEEN, "T4: the first career starts it, marked seen as it launches")
	_end_tour()
	r.check(CareerTour.maybe_start() == null, "T5: reopened (or left early): it never starts again by itself")
	# a career made when a save already existed (a player from before the tour): never
	Game.settings.career_tour = ""
	Game.settings.career_tour_uid = ""
	CareerTour.note_new_career(c2, true)
	Game.career = c2
	r.check(Game.settings.career_tour == CareerTour.SEEN and CareerTour.maybe_start() == null, "T6: a career made when another existed: no tour")
	# third career, flag already seen: unchanged
	CareerTour.note_new_career(_career(13), false)
	r.check(Game.settings.career_tour == CareerTour.SEEN, "T7: once seen, every later career is left alone")
	r.check(Game.settings.has("career_tour") and not c1.to_dict().has("career_tour"), "T8: the flag is a global setting, never in a career save")

# ------------------------------------------------------------------ the whole walk
## Every step in order, as a player does it: NEXT, or the real button the step highlights.
func _walkthrough(dir) -> void:
	var c := await _fresh_hub(21)
	var before := JSON.stringify(c.to_dict())
	var t := _tour()
	r.check(t != null, "W1: the tour starts on the first career's home screen")
	if t == null:
		return
	var seen_screens := {}
	var guard := 0
	var all_clear := true
	var all_holes := true
	var all_inside := true
	while t != null and is_instance_valid(t) and guard < 80:
		guard += 1
		await _frames(3)
		var s: Dictionary = CareerTour.STEPS[t.step]
		seen_screens[Game.current_name] = true
		r.check(Game.current_name == String(s.screen), "W2: step %d is shown on its screen (%s, on %s)" % [t.step, s.screen, Game.current_name])
		if dir != null:
			await _frames(6)
			tree.root.get_viewport().get_texture().get_image().save_png("%s/tour_%02d.png" % [dir, t.step])
		if String(s.mode) == "final":
			var go := _tour_button("StartDynasty")
			r.check(go != null and (go as Control).is_visible_in_tree(), "W3: the last step is YOU'RE READY, COACH! with START MY DYNASTY!")
			_press(go)
			await _frames(2)
			break
		var vs := t.get_viewport_rect().size
		r.check(t.box != null and t.box.is_visible_in_tree(), "W4: step %d's box is up" % t.step)
		if String(s.target) != "":
			if not t.has_hole:
				all_holes = false
				print("    no hole: step %d (%s)" % [t.step, s.target])
			elif t.box_side != "over" and t.box.get_global_rect().intersects(t.hole):
				all_clear = false
				print("    box over its hole: step %d" % t.step)
			var br := t.box.get_global_rect()
			if br.position.x < 0 or br.position.y < 0 or br.end.x > vs.x + 0.5 or br.end.y > vs.y + 0.5:
				all_inside = false
				print("    box off screen: step %d %s" % [t.step, br])
		if String(s.mode) == "click":
			r.check(t.box.find_child("TourNext", true, false) == null, "W5: a tap step has no NEXT (step %d)" % t.step)
			var target := _click_target(String(s.target))
			r.check(target != null, "W6: step %d's button is there to tap (%s)" % [t.step, s.target])
			if target == null:
				break
			# the hole lets this tap through: nothing of the tour covers the button's middle
			r.check(not t.lid.visible, "W7: a tap step's highlight takes taps (step %d)" % t.step)
			_press(target)
			await _frames(6)
		else:
			_press(t.box.find_child("TourNext", true, false))
		t = _tour()
	r.check(all_holes, "W8: every step with a target highlights it")
	r.check(all_clear, "W9: the box never covers what it highlights (where there's room)")
	r.check(all_inside, "W10: the box stays on the screen")
	for scr in ["hub", "more", "roster", "training", "coaching", "recruiting", "player"]:
		r.check(seen_screens.has(scr), "W11: the tour visits %s" % scr)
	r.check(_tour() == null and Game.current_name == "hub", "W12: START MY DYNASTY! closes the tour, back on the home screen")
	var after := JSON.stringify(c.to_dict())
	r.check(c.wallet() == Career.from_dict(JSON.parse_string(before)).wallet() and c.incoming.is_empty() and c.refreshes == 0, "W13: no recruiting resources spent, nobody signed")
	r.check(c.training == Career.from_dict(JSON.parse_string(before)).training and c.gameplan == Career.from_dict(JSON.parse_string(before)).gameplan, "W14: training and the gameplan left as they were")
	if before != after:
		print("    (career dict changed during the tour: hub_seen etc. are the screens' own)")

## The real button a tap step highlights.
func _click_target(target: String) -> Node:
	var scr := Game.current_screen
	match target:
		"hub_door":
			return scr.find_child("HubEntry", true, false)
		"nav_roster", "nav_training", "nav_coaching":
			return scr.find_child("Nav_" + target.trim_prefix("nav_"), true, false)
		"c_open":
			return scr.find_child("OpenRecruiting", true, false)
		"rc_first":
			var grid := scr.find_child("Cards", true, false)
			return null if grid == null or grid.get_child_count() == 0 else grid.get_child(0)
		"back":
			for ch in scr.header_left.get_children():
				if ch is BaseButton:
					return ch
	return null

# ------------------------------------------------------------------ BACK and SKIP
func _back_and_skip() -> void:
	await _fresh_hub(31)
	var t := _tour()
	r.check(t.box.find_child("TourBack", true, false) == null, "B1: no BACK on the first step")
	_press(t.box.find_child("TourNext", true, false))
	await _frames(3)
	_press(t.box.find_child("TourNext", true, false))
	await _frames(3)
	r.check(t.step == 2, "B2: NEXT moves on a step")
	_press(t.box.find_child("TourBack", true, false))
	await _frames(3)
	r.check(t.step == 1, "B3: BACK revisits the explanation before")
	_press(t.box.find_child("TourSkip", true, false))
	await _frames(3)
	r.check(_tour() == null and Game.settings.career_tour == CareerTour.SEEN, "B4: SKIP TUTORIAL ends it, for good")
	r.check(CareerTour.maybe_start() == null, "B5: skipped: it never starts again")

# ------------------------------------------------------------------ a dialog, TUTORIAL PAUSED
func _dialog_and_pause() -> void:
	_end_tour()
	Game.settings.career_tour = ""
	Game.settings.career_tour_uid = ""
	var c := Career.new_setup(41).begin("CULA", "Sam", "Rivera")   # (with its WELCOME dialog queued)
	Game.career = c
	CareerTour.note_new_career(c, false)
	Game.goto("hub", {}, false)
	await _frames(4)
	var t := _tour()
	r.check(t != null, "D1: the tour starts under the welcome dialog")
	if t == null:
		return
	r.check(t.box == null or not t.box.visible, "D2: ...hidden while the dialog is up")
	# close every dialog the new career queued
	for _i in 6:
		var layer: Node = null
		for ch in Game.overlay.get_children():
			if ch != t and ch is Control and (ch as Control).mouse_filter == Control.MOUSE_FILTER_STOP and not ch.is_queued_for_deletion():
				layer = ch
		if layer == null:
			break
		var btns := layer.find_children("*", "Button", true, false)
		if btns.is_empty():
			break
		_press(btns[0])
		await _frames(4)
	await _frames(3)
	t = _tour()
	r.check(t != null and t.box != null and t.box.visible and t.step == 0, "D3: the welcome closed: the tour's first step shows")
	# somewhere the step isn't about: TUTORIAL PAUSED, then RESUME TOUR
	Game.goto("settings")
	await _frames(4)
	r.check(t.pill != null and t.pill.visible and (t.box == null or not t.box.visible), "D4: on another screen: TUTORIAL PAUSED")
	_press(t.pill.find_child("TourResume", true, false))
	await _frames(5)
	r.check(Game.current_name == "hub" and t.box != null and t.box.visible and t.step == 0, "D5: RESUME TOUR goes back to the step")

# ------------------------------------------------------------------ pinning a recruit
## The pin steps: a recruit's profile opens, PIN is highlighted (and works through the hole),
## BACK returns to the market (still going back to Coaching after); an empty market skips them.
func _pin_section() -> void:
	var c := await _fresh_hub(61)
	var t := _tour()
	var open_i := -1
	for i in CareerTour.STEPS.size():
		if String(CareerTour.STEPS[i].target) == "rc_first":
			open_i = i
	r.check(open_i > 0 and String(CareerTour.STEPS[open_i + 1].target) == "p_pin", "P1: the tour has a PIN RECRUITS section after the market")
	Game.goto("recruiting", {"from": "coaching"})
	await _frames(4)
	t._go(open_i)
	await _frames(4)
	r.check(t.has_hole and t.box != null and t.box.visible, "P2: the market's first recruit is highlighted to open")
	_press(_click_target("rc_first"))
	await _frames(6)
	r.check(Game.current_name == "player" and t.step == open_i + 1, "P3: tapping him opens his profile, on to the PIN step")
	await _frames(3)
	var pin := Game.current_screen.find_child("Pin", true, false)
	r.check(pin != null and t.has_hole and t.hole.encloses((pin as Control).get_global_rect().grow(-1)), "P4: PIN is highlighted on his profile")
	r.check(not t.lid.visible, "P5: ...and can be tapped through the highlight")
	var was := Recruiting.pinned(c).size()
	_press(pin)
	await _frames(3)
	r.check(Recruiting.pinned(c).size() == was + 1 and t.step == open_i + 1, "P6: PIN pins him, the tour waits on its step")
	_press(t.box.find_child("TourNext", true, false))
	await _frames(3)
	_press(_click_target("back"))
	await _frames(6)
	r.check(Game.current_name == "recruiting" and t.step == open_i + 3, "P7: BACK returns to the market, on to NEW RECRUITS")
	var rs = Game.current_screen
	r.check(rs.get("from") == "coaching", "P8: the market still goes back to Coaching after a recruit's profile")
	# paused on the profile: RESUME goes back to the market's step that opens one
	t._go(open_i + 1)
	Game.goto("settings")
	await _frames(5)
	_press(t.pill.find_child("TourResume", true, false))
	await _frames(6)
	r.check(Game.current_name == "recruiting" and t.step == open_i, "P9: RESUME from a profile step returns to the market's step")
	# an empty market: the section is skipped
	c.market.clear()
	t._go(open_i)
	await _frames(4)
	r.check(t.step == open_i + 3, "P10: an empty market skips the pin steps")
	_end_tour()

# ------------------------------------------------------------------ Settings: TUTORIALS
func _replay_from_settings() -> void:
	_end_tour()
	var c := _career(71)
	Game.career = c
	Game.settings.career_tour = CareerTour.SEEN
	Game.history.clear()
	Game.goto("settings", {}, false)
	await _frames(4)
	var tour_b := Game.current_screen.find_child("PlayTour", true, false)
	var drill_b := Game.current_screen.find_child("PlayDrills", true, false)
	r.check(tour_b != null and drill_b != null and not (tour_b as Button).disabled, "S1: Settings has CAREER TOUR and GAMEPLAY TUTORIAL")
	_press(tour_b)
	await _frames(6)
	var t := _tour()
	r.check(Game.current_name == "hub" and t != null and t.step == 0 and t.box != null and t.box.visible, "S2: CAREER TOUR replays the tour from its first step, a career already seen")
	_end_tour()
	Game.goto("settings", {}, false)
	await _frames(4)
	_press(Game.current_screen.find_child("PlayDrills", true, false))
	await _frames(6)
	r.check(Game.current_name == "drill" and Game.current_screen.get("part") == 0 and not Game.current_screen.get("in_career"), "S3: GAMEPLAY TUTORIAL opens the drills from part 1")
	Game.current_screen.call("_to_menu")
	await _frames(6)
	r.check(Game.current_name == "settings", "S4: the tutorial's way out comes back to Settings")

func _ends_quietly() -> void:
	await _fresh_hub(51)
	r.check(_tour() != null, "E1: tour up")
	Game.goto("title", {}, false)
	await _frames(3)
	r.check(_tour() == null, "E2: back at the title screen: the tour ends (and stays seen)")
