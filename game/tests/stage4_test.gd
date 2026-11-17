extends RefCounted
## Broadcast Presentation, Victory Celebrations and Pregame Presentation (the Premium Visual
## Upgrades update, Stage 4). The win presentation is gone: a win goes straight to the full-time panel.
##   godot --headless --path game -- --test stage4
## Screenshots (needs a window): --test stage4_png <dir>

var r

func run(runner) -> void:
	r = runner
	print("broadcast, victory, pregame")
	Store.reset_for_tests()
	_broadcast()
	_victory()
	_pregame()
	await _in_a_match()
	await _lab()
	Store.reset_for_tests()
	Game.career = null

func _frames(n: int = 2) -> void:
	for i in n:
		await r.get_tree().process_frame

func _broadcast() -> void:
	var t := League.make_team(2, 1)
	var p: PoloPlayer = t.starters()[1]
	r.check(BroadcastFx.stat_line(5, 7) == "5 GOALS | 7 SHOTS | 71% SHOOTING", "the spec's line, worked out: %s" % BroadcastFx.stat_line(5, 7))
	r.check(BroadcastFx.stat_line(1, 1) == "1 GOAL | 1 SHOT | 100% SHOOTING", "singular, and never over 100%")
	r.check(BroadcastFx.stat_line(2, 1).contains("2 SHOTS"), "a goal is always at least a shot")
	var one := BroadcastFx.new(1)
	one.goal(p, t, 1, 1, "1-0")
	one.save(p, t, 1)
	r.check(one.msg.is_empty(), "Level 1: the existing presentation, no new graphics")
	var two := BroadcastFx.new(2)
	two.save(p, t, 1)
	r.check(two.msg.is_empty(), "Level 2: no save graphics yet")
	two.goal(p, t, 1, 1, "1-0")
	r.check(String(two.msg.kind) == "goal", "Level 2: the scoring strip")
	var three := BroadcastFx.new(3)
	three.save(p, t, 4)
	r.check(String(three.msg.kind) == "save" and int(three.msg.saves) == 4, "Level 3: the save graphic")
	three.step(BroadcastFx.HOLD + 0.1)
	r.check(three.msg.is_empty(), "graphics leave by themselves")
	r.check(BroadcastFx.new(4).level == 3, "no Level 4 any more")

func _victory() -> void:
	var old := VisualUpgrades.from_dict({"unlocked": {"victory": 4, "crowd": 3}, "equipped": {"victory": 3, "crowd": 2}})
	r.check(not old.unlocked.has("victory") and not old.equipped.has("victory") and old.level("crowd") == 2 and old.worn("crowd") == 2,
		"an old save's Victory levels are dropped, everything else kept")
	r.check(VisualUpgrades.cat("victory").is_empty() and not VisualUpgrades.BUILT.has("victory"), "Victory Presentation isn't sold")

func _pregame() -> void:
	var a := League.make_team(2, 1)
	var b := League.make_team(3, 1)
	var one := PregameIntro.new(a, b, true)
	one.calm = false
	one.set_level(1)
	r.check(is_zero_approx(one.lead()) and is_equal_approx(one.length(), PregameIntro.TOTAL), "Level 1: the plain glass doors, the same timeline")
	r.check(not bool(one._look().logos) and not bool(one._look().sign) and is_zero_approx(float(one._look().spill)), "Level 1: no logos, no sign, no light spilling in")
	var two := PregameIntro.new(a, b, true)
	two.calm = false
	two.set_level(2)
	r.check(is_zero_approx(two.lead()) and is_equal_approx(two.length(), PregameIntro.TOTAL), "Level 2: the old Level 1's entrance, as long")
	r.check(two._look() == PregameIntro.LOOK_GAMEDAY and bool(two._look().logos) and two._look().wall == PregameIntro.WALL, "Level 2: the old Level 1's hall and logo doors, exactly")
	var three := PregameIntro.new(a, b, true)
	three.calm = false
	three.set_level(3)
	r.check(is_equal_approx(three.lead(), PregameIntro.HALL_TIME) and is_equal_approx(three.length(), PregameIntro.HALL_TIME + PregameIntro.TOTAL), "Level 3: the corridor first, then the doors")
	three.t = 0.5
	r.check(three.stage() == "HALLWAY" and three.dolly() < 1.0 and is_zero_approx(three.open_amount()), "Level 3: walking the dark corridor, the doors still shut")
	r.check(three._look().glass == two._look().glass and bool(three._look().logos), "Level 3: Level 2's own doors at its end")
	three.t = three.lead() + PregameIntro.DOLLY_END
	r.check(three.bloom() > 0.0 and three.through(), "Level 3: the bright pool's flash coming through")
	var four := PregameIntro.new(a, b, true)
	four.calm = false
	four.set_level(4)
	r.check(four.level == 3 and is_equal_approx(four.length(), PregameIntro.HALL_TIME + PregameIntro.TOTAL), "the old Level 4 (Starting 7, removed) plays Level 3's entrance")
	four.t = four.length() - 0.5
	r.check(four.matchup() > 0.0 and four.stage() == "MATCHUP", "Level 3 ends on the matchup")

func _cfg(extra: Dictionary) -> Dictionary:
	var d := {"us": League.make_team(2, 1), "them": League.make_team(3, 1), "seed": 77, "minutes": 2.0, "autoplay": true, "intro": false}
	d.merge(extra, true)
	return d

func _finish(ms) -> void:
	var guard := 0
	while ms.flow.phase != MatchFlow.Phase.FINAL and guard < 200000:
		guard += 1
		ms._process(1.0 / 30.0)
		if ms.flow.phase == MatchFlow.Phase.BREAK and not ms.flow.state.is_last_quarter():
			ms.flow.break_done()   # (the break waits for a tap)
	ms._process(1.0 / 30.0)

func _in_a_match() -> void:
	# a seed your side wins, so the victory path really runs
	var want: Array = []
	var seed_won := -1
	for sd in range(77, 97):
		Game.match_cfg = _cfg({"seed": sd})
		Game.goto("match", Game.match_cfg)
		await _frames(2)
		var plain = Game.current_screen
		_finish(plain)
		if plain.flow.state.winner() == 0:
			want = plain.flow.state.score.duplicate()
			seed_won = sd
			break
	r.check(seed_won >= 0, "found a seed your side wins")
	Store.looks.unlocked = {"broadcast": 3, "pregame": 3}
	Store.looks.equipped = {"broadcast": 3, "pregame": 3}
	Game.match_cfg = _cfg({"victory": true, "title": "nat", "seed": seed_won})   # (old keys: ignored now)
	Game.goto("match", Game.match_cfg)
	await _frames(2)
	var ms = Game.current_screen
	r.check(ms.broadcast.level == 3, "the worn broadcast level reaches the match")
	var said := false
	var guard := 0
	while ms.flow.phase != MatchFlow.Phase.FINAL and guard < 200000:
		guard += 1
		ms._process(1.0 / 30.0)
		if ms.flow.phase == MatchFlow.Phase.BREAK and not ms.flow.state.is_last_quarter():
			ms.flow.break_done()
		if ms.broadcast.msg.get("kind", "") == "goal":
			said = true
			var who: PoloPlayer = ms.broadcast.msg.who
			r.check(int(ms.broadcast.msg.goals) >= 1 and who != null, "a goal's graphic names the real scorer")
			ms.broadcast.msg = {}
	ms._process(1.0 / 30.0)
	r.check(said, "goals bring the broadcast graphic")
	r.check(ms.flow.phase == MatchFlow.Phase.FINAL, "the match reaches the final whistle")
	r.check(ms.flow.state.score == want, "a full presentation ends exactly the same: %s" % str(ms.flow.state.score))
	r.check(ms.flow.state.winner() == 0 and ms.results != null and not "victory" in ms, "a win: straight to the full-time panel, no presentation")
	r.check(not ResourceLoader.exists("res://src/match/victory_show.gd"), "the victory presentation is gone")
	Store.reset_for_tests()
	var total := 0
	for c in VisualUpgrades.CATS:
		total += VisualUpgrades.category_cost(String(c.id))
	Store.bank.credit(total, "T-S4")
	var all := true
	for c in VisualUpgrades.CATS:
		if String(c.id) == "goal":
			for n in range(VisualUpgrades.CONFETTI, VisualUpgrades.FIREWORKS + 1):
				all = all and Store.buy_celeb(n) == ""   # (Goal Celebrations: each on its own)
			continue
		for i in VisualUpgrades.top(String(c.id)) - 1:
			all = all and Store.buy_tier(String(c.id)) == ""
	r.check(total == 1725 and all and Store.vault == 0, "every category can be bought in full: %d Polo Points (no Instant Replay or Starting 7)" % total)
	Store.reset_for_tests()
	Game.goto("title")
	await _frames(1)

func _lab() -> void:
	Game.settings.dev_mode = true
	Game.goto("visual_lab")
	await _frames(3)
	var lab = Game.current_screen
	lab.cat_i = VisualUpgrades.CATS.map(func(cd): return String(cd.id)).find("pregame")
	lab._labels()
	lab.lv = 3
	lab.game_i = 3
	r.check(lab.preview() and lab.cine is PregameIntro and lab.cine.level == 3, "PREGAME preview at Level 3, the top")
	lab.test_skip()
	r.check(lab.cine == null, "skip")
	lab.preview()
	r.check(lab.compare() and lab.queue == [2, 3], "COMPARE LEVELS: Pregame's three")
	lab.reset_preview()
	lab.cat_i = VisualUpgrades.CATS.map(func(cd): return String(cd.id)).find("broadcast")
	lab._labels()
	lab.lv = 3
	r.check(lab.preview() and lab.goal_run, "BROADCAST preview: a real goal")
	r.check(Store.looks.level("broadcast") == 1, "...and owns nothing")
	r.check(Store.looks.level("broadcast") == 1 and Store.looks.level("pregame") == 1, "previews own nothing")
	Game.settings.dev_mode = false
	Game.goto("title")
	await _frames(1)
