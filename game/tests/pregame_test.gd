extends RefCounted
## The Pregame Aquatic Center Cinematic: PregameIntro before a match you play, the match held
## (no clock, no shot clock, no possession) until it hands over once, skip at any moment, the
## right logos on the right doors, the designation, Reduce Motion, PREGAME CINEMATIC TESTING.
##   godot --headless --path game -- --test pregame
## Screenshots (needs a window): --test pregame_png <dir>

var r

func run(runner) -> void:
	r = runner
	print("pregame cinematic")
	Store.reset_for_tests()
	_timeline()
	await _in_a_match()
	await _skip()
	await _lab()
	_sources()
	Game.career = null

func _frames(n: int = 2) -> void:
	for i in n:
		await r.get_tree().process_frame

func _teams() -> Array:
	var c := Career.new_setup(778)
	var ts: Array = c.teams.values()
	return [ts[0], ts[1], c]

func _timeline() -> void:
	var tt := _teams()
	var a: PoloTeam = tt[0]
	var b: PoloTeam = tt[1]
	var it := PregameIntro.new(a, b, true, "REGULAR SEASON")
	it.calm = false
	r.check(it.home == a and it.away == b and it.left == a and it.right == b, "14: home game: ours (home) on the left door")
	var it2 := PregameIntro.new(a, b, false, "")
	r.check(it2.home == b and it2.away == a and it2.left == a and it2.right == b, "13/16: away game: still ours on the left door, theirs (home) on the right")
	var seen := []
	var last_z := 0.0
	var mono := true
	for i in 46:
		it.t = i * 0.1
		var z := it.dolly()
		mono = mono and z >= last_z - 0.0001
		last_z = z
		if seen.is_empty() or seen[seen.size() - 1] != it.stage():
			seen.append(it.stage())
	r.check(seen == ["CLOSED", "OPENING", "DOORWAY", "REVEAL", "MATCHUP"], "1/6/7/8: closed doors, opening, the doorway, the reveal, the matchup (%s)" % str(seen))
	r.check(mono and is_equal_approx(last_z, PregameIntro.DOLLY_ZOOM), "7: the walk only goes forward, through the doorway")
	it.t = 0.3
	r.check(is_zero_approx(it.open_amount()) and is_equal_approx(it.dolly(), 1.0) and is_zero_approx(it.reveal()), "2: at first the doors are shut and we stand still")
	it.t = 1.15
	r.check(it.open_amount() > 0.3 and it.open_amount() < 0.8, "6: half-open at 1.15 s")
	it.t = 4.2
	r.check(is_equal_approx(it.reveal(), 1.0) and it.matchup() > 0.9, "9/12: the reveal ends on the game's camera; the matchup up")
	r.check(PregameIntro.TOTAL >= 4.0 and PregameIntro.TOTAL <= 5.0, "about 4-5 s (%.1f)" % PregameIntro.TOTAL)
	var cm := PregameIntro.new(a, b, true)
	cm.calm = true
	var calm_stages := []
	for i in 27:
		cm.t = i * 0.1
		if calm_stages.is_empty() or calm_stages[calm_stages.size() - 1] != cm.stage():
			calm_stages.append(cm.stage())
	r.check(cm.length() < it.length() and calm_stages == ["DOORS", "OPEN", "MATCHUP"], "32: Reduce Motion: doors, open, the matchup; no walk or pan (%s)" % str(calm_stages))
	cm.t = 1.5
	r.check(is_equal_approx(cm.reveal(), 1.0) and is_equal_approx(cm.dolly(), 1.0), "32: the pool already at the game's camera")
	r.check(PregameIntro.label_for({"kind": "reg"}) == "REGULAR SEASON" and PregameIntro.label_for({"kind": "conf_semi"}) == "CONFERENCE TOURNAMENT"
		and PregameIntro.label_for({"kind": "nat_final"}) == "NCSA CHAMPIONSHIP", "39/40: the designations")
	r.check(it.matchup_text().contains(Colleges.display_name(a.name).to_upper()) and it.matchup_text().contains(Colleges.display_name(b.name).to_upper()), "10: the real names")
	# every school's own logo art
	var c: Career = tt[2]
	var all_art := true
	for id in c.teams:
		all_art = all_art and (TeamLogo.art_within(c.teams[id], Vector2i(48, 48)) != null or TeamLogo.texture(c.teams[id]) != null)
	r.check(all_art and c.teams.size() == 30, "13/17: all 30 schools' own logos for the doors")

func _match_cfg(extra: Dictionary) -> Dictionary:
	var tt := _teams()
	var d := {"us": tt[0], "them": tt[1], "seed": 9, "minutes": 2.0, "home": true, "stage": "REGULAR SEASON"}
	d.merge(extra, true)
	return d

func _in_a_match() -> void:
	Game.match_cfg = _match_cfg({})
	Game.goto("match", Game.match_cfg)
	await _frames(3)
	r.check(Game.current_screen.intro == null, "26: tests and bots get no intro unless asked (the default)")
	Game.match_cfg = _match_cfg({"autoplay": true, "intro": false})
	Game.goto("match", Game.match_cfg)
	await _frames(2)
	r.check(Game.current_screen.intro == null, "26: an autoplayed match has none")
	Game.match_cfg = _match_cfg({"intro": true})
	Game.goto("match", Game.match_cfg)
	await _frames(2)
	var ms = Game.current_screen
	r.check(ms.intro != null, "1: a match you play opens with the entrance")
	var clock: float = ms.flow.state.clock
	for i in 20:
		ms._process(0.1)
	r.check(ms.intro != null and ms.flow.state.clock == clock and ms.sprint == null and ms.flow.play == null and ms.last_phase == -1 and ms.flow.events.is_empty(),
		"19-21: 2 s in: the clock, shot clock and play haven't started")
	r.check(ms.flow.state.score == [0, 0] and ms.flow.state.shots == [0, 0], "27: no statistics")
	for i in 40:
		ms._process(0.1)
	r.check(ms.intro == null and ms.intros_done == 1, "1/12: it ends and hands the match over")
	ms._process(0.016)
	r.check(ms.sprint != null and ms.flow.phase == MatchFlow.Phase.SPRINT, "24/25: the match starts as before: the sprint, the game's camera")
	for i in 30:
		ms._process(0.05)
	r.check(ms.intros_done == 1, "23: once")

func _skip() -> void:
	Game.match_cfg = _match_cfg({"intro": true})
	Game.goto("match", Game.match_cfg)
	await _frames(2)
	var ms = Game.current_screen
	ms._process(0.3)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ms._input(ev)
	r.check(ms.intro == null and ms.intros_done == 1, "11/22: a click skips it at once")
	ms._input(ev)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	ms._input(key)
	r.check(ms.intros_done == 1, "23: skipping can't start the match twice")
	ms._process(0.016)
	r.check(ms.sprint != null, "22: the match starts")
	Game.goto("title")
	await _frames(1)

func _lab() -> void:
	var c := Career.new_game("GWU", "C", "L", 990)
	c.queue.clear()
	Game.career = c
	var before := JSON.stringify(c.to_dict())
	Game.settings.dev_mode = true
	DevGate.try_unlock("8008")   # (the developer tools: the DEV screen, behind its code)
	Game.goto("dev_settings")
	await _frames(3)
	r.check(Game.current_screen.find_child("CinemaLab", true, false) != null and Game.current_screen.find_child("HotStarLab", true, false) != null
		and Game.current_screen.find_child("CoinLab", true, false) != null, "36: PREGAME CINEMATIC TESTING with every other tool")
	Game.goto("cinema_lab")
	await _frames(3)
	var lab = Game.current_screen
	r.check(lab.teams.size() == 30 and lab.home() == c.team(), "37: all 30 schools, yours at home first")
	lab._pick(false, 3)
	lab._pick(true, 1)
	r.check(lab.home() != lab.away(), "37: home and away picked (never the same)")
	for i in 3:
		lab.type_i = i
		lab.still(4.2, "FINAL")
		r.check(lab.intro.label == PregameIntro.label_for({"kind": ["reg", "conf_qf", "nat_sf"][i]}) or lab.intro.label == lab.TYPES[i], "38-40: %s" % lab.TYPES[i])
	lab.play(0.4, 1.7)
	for i in 30:
		lab._process(0.1)
	r.check(lab.intro.hold >= 0.0 and is_equal_approx(lab.intro.t, 1.7) and lab.intro.open_amount() > 0.99, "41: DOORS plays the opening and holds")
	lab.play(2.4, 3.9)
	for i in 20:
		lab._process(0.1)
	r.check(is_equal_approx(lab.intro.reveal(), 1.0), "42: REVEAL")
	lab.test_skip()
	lab._do_skip()
	r.check(lab.handovers == 1 and lab.intro.skipped, "43: TEST SKIP: one hand-over")
	for st in lab.STILLS:
		lab.still(lab.at(float(st[1])), String(st[0]))
	r.check(lab.intro.stage() == "MATCHUP", "20: the stage stills")
	Game.settings.dev_mode = false
	Game.goto("title")
	await _frames(1)
	r.check(JSON.stringify(c.to_dict()) == before, "44: the career untouched")
	Game.career = null

func _sources() -> void:
	var m := FileAccess.get_file_as_string("res://src/ui/screens/matchup.gd")
	r.check(m.contains("\"stage\": PregameIntro.label_for(c.cur())"), "12: a career game carries its designation")
	var sim := FileAccess.get_file_as_string("res://src/core/career.gd") + FileAccess.get_file_as_string("res://src/core/game_sim.gd")
	r.check(not sim.contains("PregameIntro"), "26: simulated games never touch it")
	var drill := FileAccess.get_file_as_string("res://src/tutorial/drill_screen.gd")
	r.check(not drill.contains("super.setup"), "the tutorial has its own setup (no entrance)")
