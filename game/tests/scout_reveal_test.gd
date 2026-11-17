extends RefCounted
## SCOUT OPPONENT's garage door (ScoutReveal): the team you play next on the door, the Scout
## screen loaded under it, the roll up, skipping, one door at a time, Reduce motion, and nothing
## about the team, the gameplan or the wallet changed.
##   godot --headless --path game -- --test scout_reveal
##   godot --path game --resolution 1440x810 -- --test scout_reveal_png <outdir>

const DT := 1.0 / 60.0

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("scout opponent garage door")
	Store.reset_for_tests()
	await _plays_through()
	await _skips()
	await _reduce_motion()
	await _dev_preview()
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

func _frames(n: int = 2) -> void:
	for i in n:
		await r.get_tree().process_frame

func _career(seed_value: int = 41) -> Career:
	var c := Career.new_game("GWU", "A", "B", seed_value)
	c.queue.clear()
	Game.career = c
	return c

func _doors() -> Array:
	return Game.overlay.get_children().filter(func(n): return n is ScoutReveal and not n.is_queued_for_deletion())

func _step(s: ScoutReveal, until: float) -> void:
	while is_instance_valid(s) and not s.done and s.t < until:
		s._process(DT)

func _key() -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = KEY_SPACE
	k.pressed = true
	return k

func _plays_through() -> void:
	var c := _career(43)
	var opp: PoloTeam = c.teams[c.next_game().opp]
	var before := JSON.stringify(opp.to_dict())
	var plan := c.gameplan
	var cr := c.wallet()
	Game.goto("coaching")
	await _frames(2)
	# in tests the button goes straight to the page, as before
	(Game.current_screen.find_child("ScoutOpponent", true, false) as BaseButton).pressed.emit()
	await _frames(2)
	r.check(Game.current_name == "scout" and _doors().is_empty(), "tests: SCOUT OPPONENT straight to the page, no door")
	Game.goto("coaching")
	await _frames(2)
	ScoutReveal.scout(true)
	var ds := _doors()
	r.check(ds.size() == 1, "the door goes up over Coaching")
	if ds.is_empty():
		return
	var s: ScoutReveal = ds[0]
	s.set_process(false)
	r.check(Game.current_name == "coaching", "the page isn't loaded till the door is down")
	r.check(s.team == opp, "the door shows the team you play next (%s)" % opp.name)
	r.check(s.ovr == opp.overall_display(), "its OVR, the game's own (%d)" % s.ovr)
	var want := [opp.offense_display(), opp.defense_display(), opp.goalkeeping_display()]
	var same := s.rows.size() == 3
	for i in mini(3, s.rows.size()):
		same = same and is_equal_approx(float(s.rows[i][1]), PoloTeam.rating_stars(float(want[i])))
	r.check(same and String(s.rows[2][0]) == "GOALKEEPING", "OFFENSE / DEFENSE / GOALKEEPING stars, the team's own (%s)" % str(s.rows))
	r.check(s.title == Colleges.display_name(opp.name).to_upper(), "its full name (%s)" % s.title)
	r.check(s.logo_tex != null and s.logo_k >= 2, "its logo, big, whole-pixel scaled (x%d)" % s.logo_k)
	var area := s.door_rect().get_area() / (s.size.x * s.size.y)
	r.check(area >= 0.88 and area <= 0.96, "the door covers about 90%% of the screen (%.0f%%)" % (area * 100.0))
	ScoutReveal.scout(true)
	r.check(_doors().size() == 1, "a second press while it's up: still one door")
	# the press that opened it can't skip it
	s._input(_key())
	r.check(not s.done, "a press before it's down doesn't skip")
	_step(s, ScoutReveal.T_LAND + DT)
	await _frames(2)
	r.check(Game.current_name == "scout" and Game.current_screen.get("scout_team") == opp, "down: the Scout page loads under it, the right team")
	r.check(s.lift() == 0.0 and s.clip.size.y == s.opening().size.y, "down: the door fills its opening")
	var hold_from := s.t
	_step(s, s._hold_end() - DT)
	r.check(s.lift() == 0.0 and s._hold_end() - hold_from >= ScoutReveal.HOLD, "the showcase holds %.1f s before it opens" % (s._hold_end() - hold_from))
	_step(s, s._hold_end() + ScoutReveal.ROLL * 0.5)
	var half_h := s.clip.size.y
	var half_y := s.face.position.y
	r.check(s.lift() > 0.2 and s.lift() < 0.8 and half_h < s.opening().size.y and half_y < 0.0,
		"rolling: the door's going up into the housing, everything on it with it (%.2f)" % s.lift())
	r.check(s.clip.position.y + half_h < s.size.y * 0.8, "rolling: the page shows under the door's edge")
	r.check(half_y == roundf(half_y) and half_h == roundf(half_h), "rolling: whole pixels")
	_step(s, s._hold_end() + ScoutReveal.ROLL + ScoutReveal.RETRACT + 0.1)
	await _frames(2)
	r.check(_doors().is_empty() and Game.current_name == "scout", "up: the overlay's gone, the Scout page as always")
	r.check(JSON.stringify(opp.to_dict()) == before and c.gameplan == plan and c.wallet() == cr, "nothing changed: his team, your gameplan, your wallet")

func _skips() -> void:
	_career(44)
	Game.goto("coaching")
	await _frames(2)
	ScoutReveal.scout(true)
	var s: ScoutReveal = _doors()[0]
	s.set_process(false)
	_step(s, ScoutReveal.T_LAND + 0.3)
	s._input(_key())
	await _frames(2)
	r.check(s == null or not is_instance_valid(s) or s.done, "a key skips it")
	r.check(_doors().is_empty() and Game.current_name == "scout", "skipped: straight to the Scout page")
	# a tap skips it too, and a door can go up again after
	Game.goto("coaching")
	await _frames(2)
	ScoutReveal.scout(true)
	var s2: ScoutReveal = _doors()[0]
	s2.set_process(false)
	_step(s2, 1.0)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	s2._input(tap)
	await _frames(2)
	r.check(_doors().is_empty() and Game.current_name == "scout", "a click skips it, every time")

func _reduce_motion() -> void:
	_career(45)
	Game.goto("coaching")
	await _frames(2)
	ScoutReveal.scout(false)
	var s: ScoutReveal = _doors()[0]
	s.set_process(false)
	await _frames(2)
	r.check(Game.current_name == "scout", "Reduce motion: the page loads at once, under the door")
	var moved := false
	while is_instance_valid(s) and not s.done:
		s._process(DT)
		moved = moved or s.lift() != 0.0 or s.shake() != Vector2.ZERO
	r.check(not moved, "Reduce motion: no drop, shake or roll")
	await _frames(2)
	r.check(_doors().is_empty(), "Reduce motion: it lifts away after the hold")

## Developer Mode's PREVIEW SCOUT GARAGE ANIMATION: the same door, over the DEV screen, which it
## never leaves; no scouting, nothing changed; skippable and replayable.
func _dev_preview() -> void:
	var c := _career(46)
	var opp: PoloTeam = c.teams[c.next_game().opp]
	var before := JSON.stringify(opp.to_dict())
	var plan := c.gameplan
	var cr := c.wallet()
	var had_dev: bool = Game.settings.get("dev_mode", false)
	Game.settings.dev_mode = true
	DevGate.try_unlock("8008")
	Game.goto("dev_settings", {}, false)
	await _frames(2)
	var b := Game.current_screen.find_child("PreviewScoutGarage", true, false) as BaseButton
	r.check(b != null, "DEV: a PREVIEW SCOUT GARAGE ANIMATION button")
	if b == null:
		Game.settings.dev_mode = had_dev
		return
	b.pressed.emit()
	var ds := _doors()
	r.check(ds.size() == 1 and ds[0].team == opp and not ds[0].go_screen, "DEV: the real door, your next opponent (%s), no page to load" % opp.name)
	if ds.is_empty():
		Game.settings.dev_mode = had_dev
		return
	var s: ScoutReveal = ds[0]
	s.set_process(false)
	r.check(s.ovr == opp.overall_display() and s.logo_tex != null, "DEV: its logo and OVR")
	_step(s, s._hold_end() + ScoutReveal.ROLL * 0.5)
	await _frames(2)
	r.check(Game.current_name == "dev_settings" and s.lift() > 0.2, "DEV: rolling up over the DEV screen, still there")
	_step(s, s._hold_end() + ScoutReveal.ROLL + ScoutReveal.RETRACT + 0.1)
	await _frames(2)
	r.check(_doors().is_empty() and Game.current_name == "dev_settings", "DEV: up, the overlay's gone, still on the DEV screen")
	# again, and skipped
	b = Game.current_screen.find_child("PreviewScoutGarage", true, false) as BaseButton
	b.pressed.emit()
	var s2: ScoutReveal = _doors()[0]
	s2.set_process(false)
	_step(s2, ScoutReveal.T_LAND + 0.3)
	s2._input(_key())
	await _frames(2)
	r.check(_doors().is_empty() and Game.current_name == "dev_settings", "DEV: replayed and skipped, still on the DEV screen")
	r.check(JSON.stringify(opp.to_dict()) == before and c.gameplan == plan and c.wallet() == cr, "DEV: nothing changed")
	# no career: a sample club, still no page
	Game.career = null
	var s3 := ScoutReveal.preview(true)
	r.check(s3 != null and s3.team != null, "DEV: no career, a sample club on the door")
	if s3 != null:
		s3.skip()
	await _frames(2)
	r.check(Game.current_name == "dev_settings", "DEV: no career, still on the DEV screen")
	Game.settings.dev_mode = had_dev
	DevGate.lock()

## Frames of the door at 1440 x 810: dropping, down and full, rolling, almost up.
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var c := Career.new_game("GWU", "Sam", "Rivera", 31)
	c.queue.clear()
	Game.career = c
	Game.goto("coaching")
	await tree.create_timer(0.4).timeout
	ScoutReveal.scout(true)
	var s: ScoutReveal = Game.overlay.get_node("ScoutReveal")
	s.set_process(false)
	var times := [["sr_1_drop", 0.16], ["sr_2_shake", ScoutReveal.T_LAND + 0.05], ["sr_3_logo", ScoutReveal.T_NAME],
		["sr_4_full", s._hold_end() - 0.5], ["sr_5_roll25", s._hold_end() + 0.35], ["sr_6_roll60", s._hold_end() + 0.55],
		["sr_7_roll90", s._hold_end() + 0.8]]
	for shot in times:
		while s.t < float(shot[1]):
			s._process(1.0 / 60.0)
		await tree.create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(String(shot[0]) + ".png"))
		print("  shot ", shot[0])
	s.skip()
	Game.career = null
	Game.goto("title")
