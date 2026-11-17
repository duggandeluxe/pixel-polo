extends RefCounted
## Goal Celebrations and Crowd Atmosphere: the equipped celebration (GoalFx) plays at the goal
## inside the goal show's own time, CrowdArt dresses the stands; attendance comes from the
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
	var p0 := _fx(VisualUpgrades.CLASSIC).parts()
	var p1 := _fx(VisualUpgrades.CONFETTI).parts()
	var p2 := _fx(VisualUpgrades.WATER).parts()
	var p3 := _fx(VisualUpgrades.FIREWORKS).parts()
	var total := func(p: Dictionary) -> int: return int(p.confetti) + int(p.drops) + int(p.sparks) + int(p.rockets) + int(p.poppers) + int(p.ripples)
	r.check(total.call(p0) == 0 and not bool(p0.shake) and not _fx(VisualUpgrades.CLASSIC).active(), "Level 0 CLASSIC adds nothing: the GOAL! show alone")
	r.check(int(p1.poppers) == 2 and int(p1.confetti) > 0 and int(p1.drops) + int(p1.rockets) + int(p1.sparks) == 0, "Level 1: two poppers of confetti, nothing else")
	r.check(int(p2.cannons) == 2 and int(p2.drops) > int(p1.confetti) and int(p2.ripples) > 0 and bool(p2.shake) and int(p2.confetti) + int(p2.rockets) == 0, "Level 2: a water cannon on each back post (more than the confetti), ripples, a jolt; nothing else")
	r.check(int(p3.rockets) == 2 and int(p3.shells) > 0 and int(p3.sparks) > int(p2.drops) and int(p3.confetti) + int(p3.drops) + int(p3.cannons) == 0, "Level 3: two big rockets, smaller ones after, the most sparks of all; nothing else")
	r.check(int(p3.sparks) >= 4 * 108, "Level 3: about four times the sparks it had (108): %d" % int(p3.sparks))
	# the water cannons: symmetrical, fanning apart, inside their 1.5 s; the fireworks inside 2 s
	var vw := PoolView.new()
	vw.width = 480
	vw.height = 270
	vw.snap_to(Vector2(Geo.GOAL_X, Geo.GOAL_Y))
	var gw := GoalFx.points(vw, Vector2(Geo.GOAL_X, Geo.GOAL_Y))
	var l0 := GoalFx._jet_landing(gw, 0)
	var l1 := GoalFx._jet_landing(gw, 1)
	r.check(absf((l0.x - (gw.far_w as Vector2).x) - (l1.x - (gw.near_w as Vector2).x)) < 0.01 and is_equal_approx((gw.far_w as Vector2).y - l0.y, l1.y - (gw.near_w as Vector2).y),
		"Level 2: the two jets mirror each other")
	r.check(l0.y < (gw.far_w as Vector2).y and l1.y > (gw.near_w as Vector2).y and signf(l0.x - (gw.far_w as Vector2).x) == float(gw.out), "Level 2: they arc apart (not into the goal's middle) and out over the pool")
	r.check(GoalFx.JET_LIFE <= 1.5 and GoalFx.jet_power(0.05) > GoalFx.jet_power(0.3), "Level 2: 1.5 s, a strong first burst")
	r.check(GoalFx.rocket_burst(1) <= 0.35 and GoalFx.shell_burst(GoalFx.SHELL_AT.size() - 1) < 1.2 and GoalFx.FW_LIFE <= 2.0, "Level 3: big bursts by 0.35 s, the smaller ones by 1.2 s, all gone by 2 s")
	var c := _fx(VisualUpgrades.WATER, true).parts()
	r.check(not bool(c.shake) and int(c.drops) < int(p2.drops) and int(c.drops) > 0, "Reduce Motion: no jolt, less spray, the celebration still there")
	var words := []
	for lv in 4:
		words.append(_fx(lv).show.word_base())
	r.check(words.count(GoalShow.WORD) == 4, "the GOAL! announcement is the classic one, whatever's equipped: %s" % str(words))
	# the emitters: the goal it went into, at either end, mirrored or not
	var v := PoolView.new()
	v.width = 480
	v.height = 270
	for gx in [Geo.GOAL_X, 0.0]:
		for mir in [false, true]:
			v.mirror = mir
			v.snap_to(Vector2(gx, Geo.GOAL_Y))
			var g := GoalFx.points(v, Vector2(gx, Geo.GOAL_Y))
			var line := v.to_screen(Vector2(gx, Geo.GOAL_Y))
			var post_far := v.to_screen(Vector2(gx, Geo.GOAL_Y - Geo.GOAL_HALF))
			var back_sign := signf((g.far as Vector2).x - line.x)
			r.check(back_sign == -float(g.out) and absf((g.far as Vector2).x - line.x) > 10.0 and (g.far as Vector2).x == (g.near as Vector2).x,
				"x=%d%s: both emitters on the back posts, behind the goal line (away from the pool)" % [gx, " mirrored" if mir else ""])
			r.check((g.far as Vector2).y < post_far.y and (g.near as Vector2).y > (g.far as Vector2).y and float(g.water) > (g.near as Vector2).y,
				"x=%d%s: the posts' tops, far above near, over the water" % [gx, " mirrored" if mir else ""])
	# the save: the old tiers become celebrations, Classic always owned, the equipped one kept
	var old := VisualUpgrades.from_dict({"unlocked": {"goal": 4, "crowd": 3}, "equipped": {"goal": 3, "crowd": 2}})
	r.check(old.celebs == [1, 2, 3] and old.worn_celeb() == VisualUpgrades.WATER and old.level("crowd") == 2 and old.worn("crowd") == 2 and not old.unlocked.has("goal"),
		"an old LEGENDARY save: all three owned, its worn tier's place equipped, the crowd kept (old 3 -> new 2)")
	var none := VisualUpgrades.from_dict({"unlocked": {"crowd": 2}})
	r.check(none.celebs.is_empty() and none.worn_celeb() == VisualUpgrades.CLASSIC and none.owns_celeb(VisualUpgrades.CLASSIC), "an old save with no celebration: CLASSIC owned and equipped")
	var bad := VisualUpgrades.from_dict({"celebs": [2, 9, 2], "celeb": 3, "celeb_v": VisualUpgrades.CELEB_V})
	r.check(bad.celebs == [2] and bad.worn_celeb() == VisualUpgrades.CLASSIC, "a celebration equipped but not owned falls back to CLASSIC")
	var back := VisualUpgrades.from_dict(old.to_dict())
	r.check(back.celebs == [1, 2, 3] and back.worn_celeb() == VisualUpgrades.WATER, "owned and equipped celebrations save and load")
	# bought one by one: any first, none needing another, one equipped
	var car := Career.new_game("GWU", "E", "C", 701)
	car.credits = 160
	var lk := VisualUpgrades.new()
	var vault := CoinVault.new()
	r.check(lk.buy_celeb(VisualUpgrades.FIREWORKS, car, vault) == "" and car.credits == 10, "GOALPOST FIREWORKS first, straight from CLASSIC: 150")
	r.check(lk.owns_celeb(VisualUpgrades.FIREWORKS) and not lk.owns_celeb(VisualUpgrades.CONFETTI) and not lk.owns_celeb(VisualUpgrades.WATER), "...and nothing below it comes with it")
	r.check(lk.worn_celeb() == VisualUpgrades.FIREWORKS, "buying equips it")
	r.check(lk.celeb_block(VisualUpgrades.CONFETTI, car, vault) == "NOT ENOUGH POLO POINTS" and lk.celeb_block(VisualUpgrades.FIREWORKS, car, vault) == "ALREADY OWNED", "short of coins says so; owned can't be bought twice")
	r.check(not lk.equip_celeb(VisualUpgrades.CONFETTI) and lk.worn_celeb() == VisualUpgrades.FIREWORKS, "one not owned can't be equipped")
	r.check(lk.equip_celeb(VisualUpgrades.CLASSIC) and lk.worn_celeb() == VisualUpgrades.CLASSIC and lk.equip_celeb(VisualUpgrades.FIREWORKS), "switching between owned ones is free")
	car.credits = 50
	r.check(lk.buy_celeb(VisualUpgrades.CONFETTI, car, vault) == "" and car.credits == 0 and lk.celebs == [1, 3], "then CONFETTI POPPERS on its own: 50")
	r.check(lk.buy_tier("goal", car, vault) != "", "no tier ladder sells them")

func _crowd() -> void:
	var a := League.make_team(2, 1)
	var b := League.make_team(3, 1)
	r.check(VisualUpgrades.top("crowd") == 3 and CrowdArt.TOP == 3, "Crowd Atmosphere: exactly three levels")
	r.check(is_equal_approx(CrowdArt.attendance(0.4, 0), 0.4) and is_equal_approx(CrowdArt.attendance(0.4, 1), 0.55) and is_equal_approx(CrowdArt.attendance(0.4, 2), 0.75), "the plain crowd's attendance follows the game's importance")
	r.check(CrowdArt.attendance(0.9, 2) <= 1.0, "...up to full")
	var v := PoolView.new()
	var plain := Color("123456")
	# Level 1 SPARSE CROWD: 20-30% of seats, casual clothes only, whatever the game
	var s1 := CrowdArt.style(1, a, b, false, 0.95, false, 2, 11)
	var lo := 1.0
	var hi := 0.0
	for sd in 12:
		var f := CrowdArt.fill_of(CrowdArt.style(1, a, b, false, 0.9, false, 0, sd * 977 + 3))
		lo = minf(lo, f)
		hi = maxf(hi, f)
	r.check(lo >= 0.17 and hi <= 0.33, "Level 1: about a quarter of the seats taken (%.2f .. %.2f)" % [lo, hi])
	var groups := 0
	var empty_rows := 0
	for row in 6:
		var run := 0
		for i in 400:
			if CrowdArt.seated(s1, i, row):
				run += 1
			else:
				if run >= 2 and run <= 4:
					groups += 1
				run = 0
		for blk in 40:   # a section's row with nobody in it
			var anyone := false
			for i in range(blk * 10, blk * 10 + 10):
				anyone = anyone or CrowdArt.seated(s1, i, row)
			if not anyone:
				empty_rows += 1
	r.check(groups >= 20 and empty_rows >= 40, "Level 1: little groups of 2-4 (%d) and empty sections and rows (%d)" % [groups, empty_rows])
	var casual_only := true
	for i in 200:
		var cc := CrowdArt.fan_colour(s1, plain, i * 3, i, i % 5, 0, v)
		var any_casual := false
		for k in CrowdArt.CASUAL:
			any_casual = any_casual or cc.is_equal_approx(Color(k).darkened(0.1))
		casual_only = casual_only and any_casual
	r.check(casual_only, "Level 1: every fan in casual clothes")
	# Level 2 FULL CROWD: 95-100% of seats, half in the home colours, half casual, mixed
	var s2 := CrowdArt.style(2, a, b, false, 0.3, false, 0, 11)
	var f2 := CrowdArt.fill_of(s2)
	r.check(f2 >= 0.95 and f2 <= 1.0, "Level 2: nearly every seat taken (%.3f), whatever the game" % f2)
	var home := 0
	var team_col := 0
	var n := 0
	var left_home := 0
	for row in 6:
		for i in 400:
			n += 1
			var cc := CrowdArt.fan_colour(s2, plain, i, i, row, 0, v)
			if CrowdArt.home_fan(s2, i, row):
				home += 1
				if i < 200:
					left_home += 1
				if cc.is_equal_approx(a.c1.darkened(0.05)) or cc.is_equal_approx(a.c2.darkened(0.05)):
					team_col += 1
	r.check(absf(home / float(n) - 0.5) < 0.05, "Level 2: half the fans are home fans (%.2f)" % (home / float(n)))
	r.check(team_col == home, "Level 2: every home fan in the school's real colours (%d/%d)" % [team_col, home])
	r.check(absf(left_home / float(home) - 0.5) < 0.06, "Level 2: home fans mixed through the stands, not in a block")
	var other := CrowdArt.style(2, b, a, false, 0.3, false, 0, 11)
	var b_col := false
	for i in 40:
		if CrowdArt.home_fan(other, i, 0):
			var cc := CrowdArt.fan_colour(other, plain, i, i, 0, 0, v)
			b_col = b_col or cc.is_equal_approx(b.c1.darkened(0.05)) or cc.is_equal_approx(b.c2.darkened(0.05))
	r.check(b_col, "Level 2: a different home school, its own colours")
	# the seating is fixed for the match: the same seats and clothes every frame
	var same := true
	for i in 100:
		same = same and CrowdArt.seated(s1, i, 2) == CrowdArt.seated(CrowdArt.style(1, a, b, false, 0.1, false, 0, 11), i, 2)
		same = same and CrowdArt.fan_colour(s2, plain, i, i, 1, 0, v) == CrowdArt.fan_colour(s2, plain, i, i, 1, 0, v)
	r.check(same, "the stands don't regenerate: the same seed, the same seats")
	# Level 3 MAXIMUM ATMOSPHERE: the former SOLD OUT!, full stands
	var s3 := CrowdArt.style(3, a, b, false, 0.3, false, 0, 11)
	r.check(CrowdArt.fill_of(s3) >= 0.95 and CrowdArt.sold_out(s3), "Level 3: full stands, the wave and the giant flags")
	r.check(not CrowdArt.sold_out(s2), "...never at Level 2")
	var ok := false
	for sd in 40:
		var cc := CrowdArt.fan_colour(s3, plain, sd, 3, 0, 0, v)
		ok = ok or (cc != plain and cc.is_equal_approx(a.c1.darkened(0.05)))
	r.check(ok and CrowdArt.fan_colour(s3, plain, 56, 3, 0, 0, v) == plain, "Level 3: the former Level 4's school colours and plain crowd")
	var ctr := CrowdArt._centre(v)
	r.check(CrowdArt.in_section(s3, ctr, v) and not CrowdArt.in_section(s3, ctr + 40, v) and not CrowdArt.in_section(s2, ctr, v), "Level 3: a student section in the middle")
	r.check(CrowdArt._team(CrowdArt.style(3, a, b, true, 0.9, false), 25) == b and CrowdArt._team(CrowdArt.style(3, a, b, true, 0.9, false), 5) == a, "a neutral site: both schools in the stands")
	r.check(CrowdArt.fan_jump(CrowdArt.style(3, a, b, false, 0.9, true), 1.0, ctr, v) == 0.0, "Reduce Motion: no bouncing or wave")
	# the cheering: Level 1 the least, Level 2 more
	var up := [0, 0, 0]
	for lvl in [1, 2]:
		var st := s1 if lvl == 1 else s2
		for k in 60:
			for i in 50:
				if CrowdArt.fan_jump(st, k * 0.37, i, v, 1, i, 0.0) < 0.0:
					up[lvl] += 1
	r.check(up[1] > 0 and up[2] > up[1] * 3, "between goals: the odd cheer at Level 1 (%d), many more at Level 2 (%d)" % [up[1], up[2]])
	var g1 := 0
	var g2 := 0
	for i in 200:
		g1 += 1 if CrowdArt.fan_jump(s1, 0.11, i, v, 1, i, 1.0) <= -1.0 else 0
		g2 += 1 if CrowdArt.fan_jump(s2, 0.11, i, v, 1, i, 1.0) <= -1.0 else 0
	r.check(g2 > g1 * 2 and not CrowdArt.arms(s1) and CrowdArt.arms(s2), "a goal: a few at Level 1, most at Level 2 with their arms up (%d, %d)" % [g1, g2])
	# the old saves
	var o4 := VisualUpgrades.from_dict({"unlocked": {"crowd": 4, "broadcast": 3}, "equipped": {"crowd": 4}})
	var o3 := VisualUpgrades.from_dict({"unlocked": {"crowd": 3}, "equipped": {"crowd": 1}})
	var o2 := VisualUpgrades.from_dict({"unlocked": {"crowd": 4}, "equipped": {"crowd": 3}})
	r.check(o4.level("crowd") == 3 and o4.worn("crowd") == 3 and o4.level("broadcast") == 3, "an old Level 4 owner owns and wears the new Level 3; the rest untouched")
	r.check(o3.level("crowd") == 2 and o3.worn("crowd") == 1, "an old Level 3 owner keeps Level 2")
	r.check(o2.level("crowd") == 3 and o2.worn("crowd") == 2, "an old Level 3 worn: the new Level 2")
	r.check(VisualUpgrades.from_dict({}).level("crowd") == 1 and VisualUpgrades.from_dict({}).worn("crowd") == 1, "Level 1: everybody's")
	var again := VisualUpgrades.from_dict(o4.to_dict())
	r.check(again.level("crowd") == 3 and VisualUpgrades.from_dict(o3.to_dict()).level("crowd") == 2, "a converted save converts once")
	var rules := ""
	for f in ["res://src/match/play.gd", "res://src/core/shot_model.gd", "res://src/core/game_sim.gd", "res://src/match/keeper_duel.gd", "res://src/match/match_flow.gd"]:
		rules += FileAccess.get_file_as_string(f)
	r.check(not rules.contains("CrowdArt") and not rules.contains("GoalFx") and not rules.contains(".crowd"), "no home-pool edge: the game's rules never read the crowd or the celebration")

func _cfg(extra: Dictionary) -> Dictionary:
	var d := {"us": League.make_team(2, 1), "them": League.make_team(3, 1), "seed": 77, "minutes": 2.0, "autoplay": true, "intro": false}
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
	Store.looks.unlocked = {"crowd": 3}
	Store.looks.equipped = {"crowd": 3}
	Store.looks.celebs = [VisualUpgrades.FIREWORKS]
	Store.looks.celeb = VisualUpgrades.FIREWORKS
	Game.match_cfg = _cfg({})
	Game.goto("match", Game.match_cfg)
	await _frames(2)
	var ms = Game.current_screen
	r.check(ms.stand_style.get("lv", 0) == 3, "the worn crowd level reaches the match")
	var seats: Array = []
	for i in 60:
		seats.append(CrowdArt.seated(ms.stand_style, i, 1))
	Game.settings.dev_mode = true
	ms.cycle_crowd()
	r.check(int(ms.stand_style.lv) == 1 and Store.looks.worn("crowd") == 3 and Store.looks.level("crowd") == 3, "Developer Mode: CROWD switches the match's stands, owning nothing")
	ms.cycle_crowd()
	ms.cycle_crowd()
	var kept := true
	for i in 60:
		kept = kept and CrowdArt.seated(ms.stand_style, i, 1) == seats[i]
	r.check(int(ms.stand_style.lv) == 3 and kept, "...round to Level 3, the same seats")
	CrowdArt.override = 0
	Game.settings.dev_mode = false
	var seen := false
	var guard := 0
	while ms.flow.phase != MatchFlow.Phase.FINAL and guard < 200000:
		guard += 1
		ms._process(1.0 / 30.0)
		if ms.flow.phase == MatchFlow.Phase.BREAK and not ms.flow.state.is_last_quarter():
			ms.flow.break_done()
		seen = seen or (ms.goal_fx.active() and ms.goal_fx.level == VisualUpgrades.FIREWORKS)
	r.check(seen, "a goal plays the equipped celebration, for either team")
	r.check(ms.flow.phase == MatchFlow.Phase.FINAL, "the Level 3 match reaches the final whistle")
	r.check(ms.flow.state.score == want and ms.flow.state.shots == shots, "a Level 3 match ends exactly like a Level 1 match: %s" % str(ms.flow.state.score))
	Store.looks = VisualUpgrades.new()
	Store.bank.credit(375, "T-GC")
	r.check(Store.buy_celeb(VisualUpgrades.WATER) == "" and Store.buy_tier("crowd") == "", "a Goal Celebration and a Crowd tier are on sale")
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
	r.check(lab.preview() and lab.goal_run and lab.lab_goal_level() == VisualUpgrades.FIREWORKS, "PREVIEW: a real goal with the picked celebration (button 4: LEVEL 3)")
	var guard := 0
	while lab.goal_fx.show == null and guard < 600:
		guard += 1
		lab._process(1.0 / 30.0)
	r.check(lab.goal_fx.level == VisualUpgrades.FIREWORKS and lab.goal_show.active(), "the goal show runs with GOALPOST FIREWORKS over it")
	lab.reset_preview()
	lab.cat_i = 1   # (CROWD ATMOSPHERE)
	lab._labels()
	lab.lv = 3
	r.check(lab.preview() and CrowdArt.sold_out(lab.lab_style()) and lab.status.contains("MAXIMUM ATMOSPHERE"), "Crowd: Level 3, MAXIMUM ATMOSPHERE")
	lab.lv = 1
	lab.preview()
	r.check(lab.status.contains("SPARSE CROWD") and lab.status.contains("% FULL"), "Crowd: Level 1 says how full it is (%s)" % lab.status)
	var was: Color = lab.us.c1
	lab.crowd_btn.pressed.emit()
	r.check(lab.us.c1 != was, "HOME: the next school's colours")
	r.check(Store.looks.celebs.is_empty() and Store.looks.level("crowd") == 1, "previews own nothing")
	await _celeb_lab()
	Game.settings.dev_mode = false
	Game.goto("title")
	await _frames(1)

## GOAL CELEBRATION PREVIEW (Developer Mode): each one, at both goals, nothing owned or saved.
func _celeb_lab() -> void:
	Game.goto("celeb_lab")
	await _frames(3)
	var lab = Game.current_screen
	var saved := Store.looks.to_dict()
	for n in 4:
		for e in 3:
			lab.sel = n
			lab.end_i = e
			lab.preview()
			lab._process(0.5)
			var ok: bool = lab.goal_show.active() and lab.goal_fx.level == n and lab.goal_fx.active() == (n != VisualUpgrades.CLASSIC)
			ok = ok and is_equal_approx(lab.goal_show.mouth.x, 0.0 if e == 1 else Geo.GOAL_X) and lab.view.mirror == (e == 2)
			r.check(ok, "PREVIEW %s at the %s goal, no goal scored" % [lab.NAMES[n], lab.ENDS[e]])
	var guard := 0
	while lab.goal_show.active() and guard < 400:
		guard += 1
		lab._process(1.0 / 30.0)
	r.check(not lab.goal_show.active() and not lab.goal_fx.active(), "...and it all clears away when the show's done")
	lab.sel = VisualUpgrades.WATER
	lab.toggle_equip()
	r.check(GoalFx.equipped() == VisualUpgrades.WATER and Store.looks.worn_celeb() == VisualUpgrades.CLASSIC, "TEMP EQUIP: a match plays it, the real equipped one untouched")
	lab.toggle_equip()
	r.check(GoalFx.dev_equip == -1 and GoalFx.equipped() == Store.looks.worn_celeb(), "...and off again")
	r.check(Store.looks.to_dict() == saved and Store.looks.celebs.is_empty(), "previews buy, equip and save nothing")
	GoalFx.dev_equip = -1
