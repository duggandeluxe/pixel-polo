extends RefCounted
## Goal Celebrations and Crowd Atmosphere (the Premium Visual Upgrades update, Stage 3): GoalFx adds
## to the goal show inside its own time, CrowdArt dresses the stands; attendance comes from the
## game, never what you own; neither reaches the match.
##   godot --headless --path game -- --test goal_crowd
## Screenshots (needs a window): --test goal_crowd_png <dir>

var r

func run(runner) -> void:
	r = runner
	print("goal celebrations & crowd")
	Store.reset_for_tests()
	_levels()
	_crowd()
	await _in_a_match()
	await _lab()
	Store.reset_for_tests()
	Game.career = null

func _frames(n: int = 2) -> void:
	for i in n:
		await r.get_tree().process_frame

func _fx(lv: int, calm := false, kind := "") -> GoalFx:
	var s := GoalShow.new()
	s.kind = kind
	var f := GoalFx.new()
	f.start(lv, s, Color.RED, Color.WHITE, calm)
	return f

func _levels() -> void:
	var p1 := _fx(1).parts()
	var p2 := _fx(2).parts()
	var p3 := _fx(3).parts()
	var p4 := _fx(4).parts()
	r.check(int(p1.confetti) == 0 and int(p1.fireworks) == 0 and not bool(p1.lights) and not bool(p1.shake), "Level 1 adds nothing: the classic show")
	r.check(int(p2.confetti) > 0 and int(p2.drops) > 0 and bool(p2.shake) and not bool(p2.lights) and int(p2.fireworks) == 0, "Level 2: confetti, splashes, a shake")
	r.check(int(p3.confetti) > int(p2.confetti) and bool(p3.lights) and bool(p3.spot) and int(p3.lasers) == 0, "Level 3: lights, the scorer's spotlight, more confetti")
	r.check(int(p4.confetti) > int(p3.confetti) and int(p4.fireworks) > 0 and int(p4.lasers) > 0 and bool(p4.flash), "Level 4: fireworks, lasers, flashes")
	r.check(int(_fx(4, false, "winner").parts().fireworks) > int(p4.fireworks), "Level 4: more for a game winner")
	var c := _fx(4, true).parts()
	r.check(not bool(c.flash) and not bool(c.shake) and int(c.confetti) < int(p4.confetti) and int(c.fireworks) > 0, "Reduce Motion: no flashes or shake, less confetti, the celebration still there")
	var words := []
	for lv in [1, 2, 3, 4]:
		words.append(_fx(lv).show.word_base())
	r.check(words[0] == GoalShow.WORD and words[1] < words[2] and words[2] < words[3], "GOAL! grows with the level: %s" % str(words))
	r.check(GoalShow.word_size("GOAL!", words[3], 1.2, 300.0) <= words[3] * 1.2, "a massive GOAL! still fits the width")

func _crowd() -> void:
	var a := League.make_team(2, 1)
	var b := League.make_team(3, 1)
	r.check(CrowdArt.style(1, a, b, false, 0.9, false).is_empty(), "Level 1: the plain crowd")
	r.check(is_equal_approx(CrowdArt.attendance(0.4, 0), 0.4) and is_equal_approx(CrowdArt.attendance(0.4, 1), 0.55) and is_equal_approx(CrowdArt.attendance(0.4, 2), 0.75), "attendance follows the game's importance")
	r.check(CrowdArt.attendance(0.9, 2) <= 1.0, "...up to full")
	var quiet := CrowdArt.style(4, a, b, false, 0.45, false)
	var full := CrowdArt.style(4, a, b, false, 0.9, false)
	r.check(not CrowdArt.sold_out(quiet) and CrowdArt.sold_out(full), "owning Level 4 doesn't fill a quiet game: SOLD OUT! needs a full pool")
	r.check(not CrowdArt.sold_out(CrowdArt.style(3, a, b, false, 0.95, false)), "...and Level 4")
	var v := PoolView.new()
	var st := CrowdArt.style(2, a, b, false, 0.9, false)
	var ok := false
	var plain := Color("123456")
	for sd in 40:
		var cc := CrowdArt.fan_colour(st, plain, sd, 3, 0, 0, v)
		ok = ok or (cc != plain and cc.is_equal_approx(a.c1.darkened(0.05)))
	r.check(ok, "Level 2: fans in the home school's real colour")
	var ctr := CrowdArt._centre(v)
	var s3 := CrowdArt.style(3, a, b, false, 0.9, false)
	r.check(CrowdArt.in_section(s3, ctr, v) and not CrowdArt.in_section(s3, ctr + 40, v) and not CrowdArt.in_section(st, ctr, v), "Level 3: a student section in the middle")
	r.check(CrowdArt._team(CrowdArt.style(3, a, b, true, 0.9, false), 25) == b and CrowdArt._team(CrowdArt.style(3, a, b, true, 0.9, false), 5) == a, "a neutral site: both schools in the stands")
	r.check(CrowdArt.fan_jump(CrowdArt.style(4, a, b, false, 0.9, true), 1.0, ctr, v) == 0.0, "Reduce Motion: no bouncing or wave")
	var rules := ""
	for f in ["res://src/match/play.gd", "res://src/core/shot_model.gd", "res://src/core/game_sim.gd", "res://src/match/keeper_duel.gd", "res://src/match/match_flow.gd"]:
		rules += FileAccess.get_file_as_string(f)
	r.check(not rules.contains("CrowdArt") and not rules.contains("GoalFx") and not rules.contains(".crowd"), "no home-pool edge: the game's rules never read the crowd or the celebration")

func _cfg(extra: Dictionary) -> Dictionary:
	var d := {"us": League.make_team(2, 1), "them": League.make_team(3, 1), "seed": 77, "minutes": 2.0, "autoplay": true, "intro": false, "replay": false}
	d.merge(extra, true)
	return d

func _play(ms) -> void:
	var guard := 0
	while ms.flow.phase != MatchFlow.Phase.FINAL and guard < 200000:
		guard += 1
		ms._process(1.0 / 30.0)
		if ms.flow.phase == MatchFlow.Phase.BREAK and not ms.flow.state.is_last_quarter():
			ms.flow.break_done()   # (the break waits for a tap)

func _in_a_match() -> void:
	Game.match_cfg = _cfg({})
	Game.goto("match", Game.match_cfg)
	await _frames(2)
	var plain = Game.current_screen
	_play(plain)
	r.check(plain.flow.phase == MatchFlow.Phase.FINAL, "the Level 1 match reaches the final whistle")
	var want: Array = plain.flow.state.score.duplicate()
	var shots: Array = plain.flow.state.shots.duplicate()
	Store.looks.unlocked = {"goal": 4, "crowd": 4}
	Store.looks.equipped = {"goal": 4, "crowd": 4}
	Game.match_cfg = _cfg({})
	Game.goto("match", Game.match_cfg)
	await _frames(2)
	var ms = Game.current_screen
	r.check(ms.stand_style.get("lv", 0) == 4, "the worn crowd level reaches the match")
	var seen := false
	var guard := 0
	while ms.flow.phase != MatchFlow.Phase.FINAL and guard < 200000:
		guard += 1
		ms._process(1.0 / 30.0)
		if ms.flow.phase == MatchFlow.Phase.BREAK and not ms.flow.state.is_last_quarter():
			ms.flow.break_done()
		seen = seen or (ms.goal_fx.active() and ms.goal_fx.level == 4)
	r.check(seen, "a goal uses the worn level, for either team")
	r.check(ms.flow.phase == MatchFlow.Phase.FINAL, "the Level 4 match reaches the final whistle")
	r.check(ms.flow.state.score == want and ms.flow.state.shots == shots, "a Level 4 match ends exactly like a Level 1 match: %s" % str(ms.flow.state.score))
	Store.looks = VisualUpgrades.new()
	Store.bank.credit(375, "T-GC")
	r.check(Store.buy_tier("goal") == "" and Store.buy_tier("crowd") == "", "Goal and Crowd tiers are on sale")
	Store.reset_for_tests()
	Game.goto("title")
	await _frames(1)

func _lab() -> void:
	Game.settings.dev_mode = true
	Game.goto("visual_lab")
	await _frames(3)
	var lab = Game.current_screen
	lab.cat_i = 0
	lab._labels()
	lab.lv = 4
	r.check(lab.preview() and lab.goal_run and lab.lab_goal_level() == 4, "PREVIEW: a real goal at the picked level")
	var guard := 0
	while lab.goal_fx.show == null and guard < 600:
		guard += 1
		lab._process(1.0 / 30.0)
	r.check(lab.goal_fx.level == 4 and lab.goal_show.active(), "the goal show runs with Level 4 over it")
	lab.reset_preview()
	lab.cat_i = 2
	lab._labels()
	lab.lv = 4
	r.check(lab.preview() and CrowdArt.sold_out(lab.lab_style()), "Crowd: Level 4 with a full pool")
	lab.crowd_full = false
	r.check(not CrowdArt.sold_out(lab.lab_style()), "...and with a quiet one")
	r.check(Store.looks.level("goal") == 1 and Store.looks.level("crowd") == 1, "previews own nothing")
	Game.settings.dev_mode = false
	Game.goto("title")
	await _frames(1)
