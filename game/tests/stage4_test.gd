extends RefCounted
## Broadcast Presentation, Victory Celebrations and Pregame Presentation (the Premium Visual
## Upgrades update, Stage 4), and the free trophy ceremony.
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
	var t := League.make_team(2, 1)
	for lv in [1, 2, 3, 4]:
		r.check(VictoryShow.new(t, lv, "nat").trophy() != null and bool(VictoryShow.new(t, lv, "nat").parts().trophy), "Level %d: the NCSA trophy ceremony (free at Level 1)" % lv)
		r.check(bool(VictoryShow.new(t, lv, "conf").parts().trophy), "Level %d: the conference trophy" % lv)
	r.check(not bool(VictoryShow.new(t, 3).parts().trophy) and not bool(VictoryShow.new(t, 4).parts().title), "no title, no real trophy")
	r.check(VictoryShow.new(t, 1).headline() == "VICTORY!" and VictoryShow.new(t, 1, "", true).headline() == "BIG WIN!"
		and VictoryShow.new(t, 1, "conf").headline() == "CONFERENCE CHAMPIONS!" and VictoryShow.new(t, 1, "nat").headline() == "NATIONAL CHAMPIONS!", "the moment follows the game")
	var a := VictoryShow.new(t, 3).parts()
	var b := VictoryShow.new(t, 4).parts()
	r.check(int(VictoryShow.new(t, 1).parts().confetti) == 0 and int(a.confetti) == 0 and int(b.confetti) > 0, "confetti at Level 4")
	r.check(int(VictoryShow.new(t, 1).parts().fireworks) == 0 and int(VictoryShow.new(t, 2).parts().fireworks) > 0 and int(a.fireworks) > 0 and int(b.fireworks) > 0, "fireworks from Level 2")
	r.check(int(VictoryShow.new(t, 4, "nat").parts().fireworks) > int(VictoryShow.new(t, 4, "conf").parts().fireworks) and int(VictoryShow.new(t, 4, "conf").parts().fireworks) > int(b.fireworks), "the NCSA title gets the most")
	r.check(VictoryShow.new(t, 4, "nat").length() == VictoryShow.new(t, 4, "nat").celebration(), "Level 4 is its own ceremony: nothing after it")
	r.check(VictoryShow.new(t, 3).length() < 7.0 and VictoryShow.new(t, 4).length() < 7.0, "short")
	var c := VictoryShow.new(t, 1, "nat")
	r.check(not c.ceremony(), "the celebration first")
	while not c.done:
		c.step(1.0 / 30.0)
		if c.t > c.celebration() + 0.1 and c.t < c.celebration() + 0.2:
			r.check(c.ceremony(), "then the ceremony")
	r.check(c.length() < 7.0, "short (%.1f s)" % c.length())
	var s := VictoryShow.new(t, 4)
	s.skip()
	s.skip()
	r.check(s.done and s.skipped, "skip")

func _pregame() -> void:
	var a := League.make_team(2, 1)
	var b := League.make_team(3, 1)
	var one := PregameIntro.new(a, b, true)
	one.calm = false
	one.set_level(1)
	r.check(one.lineup.is_empty() and is_equal_approx(one.length(), PregameIntro.TOTAL), "Level 1: the entrance as it was")
	var two := PregameIntro.new(a, b, true)
	two.calm = false
	two.set_level(2)
	r.check(two.lineup.is_empty() and is_equal_approx(two.length(), PregameIntro.TOTAL), "Level 2: no longer, just richer")
	var three := PregameIntro.new(a, b, true)
	three.calm = false
	three.set_level(3)
	r.check(three.lineup.size() == 7 and three.lineup[0][1] == a, "Level 3: your starting seven")
	var seven := a.starters()
	r.check(three.lineup.all(func(e): return seven.has(e[0])), "real starters, none invented")
	var four := PregameIntro.new(a, b, true)
	four.calm = false
	four.set_level(4)
	r.check(four.lineup.is_empty() and four.sevens.size() == 2 and four.length() < 10.0, "Level 4: both sevens, no one-by-one cards, still under 10 s (%.1f)" % four.length())
	four.t = PregameIntro.LINEUP_AT + 0.05
	r.check(four.in_showcase() and four.seven_index() == 0 and four.stage() == "HOME SEVEN", "the graphics start in the reveal")
	var k0 := four.reveal()
	four.t = PregameIntro.LINEUP_AT + four.extra() - 0.05
	r.check(is_equal_approx(four.reveal(), k0) and four.seven_index() == 1, "the camera holds while they're up")
	four.t = four.length() - 0.5
	r.check(not four.in_showcase() and four.matchup() > 0.0, "then the matchup")
	four.calm = true
	r.check(four.length() < 7.0, "Reduce Motion keeps it short")

func _cfg(extra: Dictionary) -> Dictionary:
	var d := {"us": League.make_team(2, 1), "them": League.make_team(3, 1), "seed": 77, "minutes": 2.0, "autoplay": true, "intro": false, "replay": false}
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
		r.check(plain.victory == null, "no presentation unless the match has it")
		if plain.flow.state.winner() == 0:
			want = plain.flow.state.score.duplicate()
			seed_won = sd
			break
	r.check(seed_won >= 0, "found a seed your side wins")
	Store.looks.unlocked = {"broadcast": 3, "victory": 4, "pregame": 4}
	Store.looks.equipped = {"broadcast": 3, "victory": 4, "pregame": 4}
	Game.match_cfg = _cfg({"victory": true, "title": "nat", "seed": seed_won})
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
	r.check(ms.victory != null and ms.victory.title == "nat" and ms.flow.state.winner() == 0, "a win: the presentation, before the panel")
	ms._process(0.5)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ms._input(ev)
	ms._input(ev)
	r.check(ms.victory == null and ms.victories_done == 1 and ms.results != null, "a tap skips to the full-time panel, once")
	# a loss has none
	var lost := MatchState.new()
	lost.score = [1, 3]
	r.check(lost.winner() != 0, "(a loss)")
	var src := FileAccess.get_file_as_string("res://src/match/match_screen.gd")
	r.check(src.contains("if won and victory_on:"), "the victory show is only for a win")
	Store.reset_for_tests()
	Store.bank.credit(4375, "T-S4")
	var all := true
	for c in VisualUpgrades.CATS:
		for i in VisualUpgrades.top(String(c.id)) - 1:
			all = all and Store.buy_tier(String(c.id)) == ""
	r.check(all and Store.vault == 0, "all six categories can be bought in full: 4,375 Yellow Coins")
	Store.reset_for_tests()
	Game.goto("title")
	await _frames(1)

func _lab() -> void:
	Game.settings.dev_mode = true
	Game.goto("visual_lab")
	await _frames(3)
	var lab = Game.current_screen
	lab.cat_i = 4
	lab._labels()
	lab.lv = 2
	lab.game_i = 3
	r.check(lab.preview() and lab.cine is VictoryShow and lab.cine.title == "nat", "VICTORY preview, the NCSA title")
	lab.test_skip()
	r.check(lab.cine == null, "skip")
	lab.cat_i = 5
	lab._labels()
	lab.lv = 4
	r.check(lab.preview() and lab.cine is PregameIntro and lab.cine.sevens.size() == 2, "PREGAME preview at Level 4")
	r.check(lab.compare() and lab.queue == [2, 3, 4], "COMPARE LEVELS")
	lab.reset_preview()
	lab.cat_i = 3
	lab._labels()
	lab.lv = 3
	r.check(lab.preview() and lab.goal_run, "BROADCAST preview: a real goal")
	r.check(Store.looks.level("broadcast") == 1, "...and owns nothing")
	r.check(Store.looks.level("broadcast") == 1 and Store.looks.level("victory") == 1, "previews own nothing")
	Game.settings.dev_mode = false
	Game.goto("title")
	await _frames(1)
