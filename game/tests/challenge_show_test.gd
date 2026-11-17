extends RefCounted
## THE COACHING CHALLENGE RESULT (ChallengeShow): the spec's REQUIRED TESTING (1-38).
##   godot --headless --path game -- --test challenge_show
##   godot --path game -- --test challenge_show_png <dir>

var r
var ce   # (the coaching events test: careers, players, events)
var pg   # (the postgame test's match box)

func run(runner) -> void:
	r = runner
	ce = load("res://tests/coaching_events_test.gd").new()
	ce.r = runner
	pg = load("res://tests/postgame_test.gd").new()
	ce.pg = pg
	print("coaching challenge results")
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	_triggers()
	_accuracy()
	_special_and_conditions()
	_waiting()
	await _screen()
	await _dev_preview()
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

func _frames(n: int = 3) -> void:
	for _i in n:
		await r.get_tree().process_frame

## A played game: `goals` (seven indexes), the rest in `extra` (assists, steals, blocks, saves).
func _game(c: Career, goals: Array, against: int, extra: Dictionary = {}) -> void:
	c.finish_my_game(pg._box(c, goals, against, extra))
	c.last_summary = {}

func _fresh(seed_value: int) -> Career:
	var c: Career = ce._career(seed_value)
	c.queue.clear()
	return c

func _choose(c: Career, id: String, p: PoloPlayer, i: int, extra: Dictionary = {}) -> void:
	CoachEvents.apply(c, ce._ev(c, id, p, extra), i)

func _idx(c: Career, p: PoloPlayer) -> int:
	return c.team().starters().find(p)

## A field starter with room to grow (seven index 2..6).
func _field(c: Career) -> PoloPlayer:
	var p: PoloPlayer = ce._dev(c)
	return p if p != null and _idx(c, p) > 0 else c.team().starters()[3]

# ------------------------------------------------------------------ 1-10
func _triggers() -> void:
	# 1: a made statistical challenge
	var c := _fresh(801)
	var p := _field(c)
	var i := _idx(c, p)
	_choose(c, "star_in_making", p, 1)
	_game(c, [i, i, 1, 1, 1, 1, 1, 1], 3, {"assists": [i, i]})
	var pops := CoachEvents.popups(c)
	r.check(pops.size() == 1 and String(pops[0].outcome) == "ok" and String(pops[0].event) == "star_in_making", "1: a made challenge: one result for the popup")
	# 2: a missed one
	c = _fresh(802)
	var k: PoloPlayer = c.team().starters()[0]
	_choose(c, "rough_night", k, 1)
	_game(c, [1, 2, 3], 9, {"saves": 5})
	pops = CoachEvents.popups(c)
	r.check(pops.size() == 1 and String(pops[0].outcome) == "fail", "2: a missed challenge: one result for the popup")
	# 3-9: never for these
	var none := {}
	c = _fresh(803)
	p = _field(c)
	_choose(c, "star_in_making", p, 0)            # an immediate XP choice (and a safe one)
	_game(c, [1, 2, 3, 4, 5, 6], 2)
	none["3/9: an immediate XP (safe) choice"] = c.coach_results.size() == 0 and CoachEvents.popups(c).is_empty()
	c = _fresh(804)
	c.credits = 100
	_choose(c, "recruiting_ripple", null, 1)      # a credits wager
	_game(c, [1, 2, 3, 4, 5, 6], 2)
	none["4: a coin wager"] = c.coach_results.size() == 1 and CoachEvents.popups(c).is_empty()
	c = _fresh(805)
	var lead := CoachEvents.leader(c)
	_choose(c, "big_rivalry", lead, 1)            # win-only
	_game(c, [1, 2, 3, 4, 5, 6], 2)
	none["5: the win-only BIG RIVALRY"] = c.coach_results.size() == 1 and CoachEvents.popups(c).is_empty()
	c = _fresh(806)
	_choose(c, "captains_speech", lead, 1)        # the team's win
	_game(c, [1, 2, 3, 4, 5, 6], 2)
	none["5: THE CAPTAIN'S SPEECH (team result)"] = CoachEvents.popups(c).is_empty()
	c = _fresh(807)
	var disc: Array = c.team().starters().filter(func(q): return not q.is_keeper() and CoachEvents.suspension_ok(c.team(), q) != null)
	_choose(c, "practice_discipline", disc[0], 1)  # a suspension
	_game(c, [1, 2, 3, 4, 5, 6], 2)
	none["6: a suspension"] = c.coach_results.size() == 1 and CoachEvents.popups(c).is_empty()
	c = _fresh(808)
	var t := c.team()
	var bench: Array = t.roster.filter(func(q): return not q in t.starters() and not CoachEvents.promotion(t, q).is_empty())
	_choose(c, "prove_me_wrong", bench[0], 1)     # PROVE ME WRONG
	_game(c, [1, 2, 3, 4, 5, 6], 2)
	none["7: PROVE ME WRONG"] = c.coach_results.size() == 1 and CoachEvents.popups(c).is_empty()
	c = _fresh(809)
	c.pending_event = ce._ev(c, "star_in_making", _field(c))   # offered, never answered
	none["8: an event offered but not answered"] = CoachEvents.popups(c).is_empty() and c.coach_pending.is_empty()
	var bad: Array = none.keys().filter(func(kk): return not none[kk])
	r.check(bad.is_empty(), "3-9: no popup for an immediate reward, a coin wager, a win-only wager, a team result, a suspension, PROVE ME WRONG or an unanswered event %s" % str(bad))
	# 10: a challenge just chosen can't settle before its game
	c = _fresh(810)
	p = _field(c)
	_choose(c, "star_in_making", p, 1)
	r.check(CoachEvents.popups(c).is_empty() and c.coach_pending.size() == 1, "10: a challenge just chosen waits for its game")

# ------------------------------------------------------------------ 11-19, 31-34, 37
func _accuracy() -> void:
	var c := _fresh(811)
	var p := _field(c)
	var i := _idx(c, p)
	_choose(c, "star_in_making", p, 1)
	_game(c, [i, i, 1, 1, 1, 1, 1, 1], 3, {"assists": [i, i]})
	var res: Dictionary = CoachEvents.popups(c)[0]
	r.check(int(res.pid) == p.id and String(res.title) == "A STAR IN THE MAKING", "11-13: his own id, the event's name")
	r.check(ChallengeShow.goal_text(res) == "3 GOALS + ASSISTS" and ChallengeShow.progress_text(res) == "4 / 3 G+A" and ChallengeShow.parts_text(res) == "2 GOALS + 2 ASSISTS" and ChallengeShow.fill(res) == 1.0,
		"14-16: GOAL 3 GOALS + ASSISTS, 4 / 3 G+A (2 goals + 2 assists), the bar full, not past it")
	var cq := ChallengeShow.consequence(res)
	var ap: Dictionary = res.applied
	r.check(cq[0] == "REWARD EARNED" and cq[1] == "2X GAME XP" and String(ap.kind) == "mult" and int(ap.xp) == roundi(int(ap.base) * 2.0) and String(cq[2]) == "%d -> %d XP   +%d%% HOT STAR PROGRESS FOR %s" % [int(ap.base), int(ap.xp), CoachEvents._pp(CoachEvents.HOT.loss), p.short_name().to_upper()],
		"18: REWARD EARNED: 2X GAME XP, as applied, and the HOT STAR PROGRESS it won (%s)" % cq[2])
	# a keeper's missed saves: the 0.5X
	c = _fresh(812)
	var k: PoloPlayer = c.team().starters()[0]
	_choose(c, "rough_night", k, 1)
	_game(c, [1, 2, 3], 9, {"saves": 5})
	res = CoachEvents.popups(c)[0]
	cq = ChallengeShow.consequence(res)
	r.check(ChallengeShow.title_of(res) == "CHALLENGE FAILED" and ChallengeShow.progress_text(res) == "5 / 8 SAVES" and is_equal_approx(ChallengeShow.fill(res), 0.625) and cq[0] == "PENALTY APPLIED" and cq[1] == "0.5X GAME XP",
		"2/15/19: CHALLENGE FAILED, 5 / 8 SAVES (62.5%% of the bar), PENALTY APPLIED: 0.5X GAME XP")
	# ...and made: the fixed +160
	c = _fresh(813)
	k = c.team().starters()[0]
	var x0: int = ce._xp_total(k)
	_choose(c, "rough_night", k, 1)
	_game(c, [1, 2, 3, 4, 5, 6], 2, {"saves": 10})
	res = CoachEvents.popups(c)[0]
	var gained: int = ce._xp_total(k) - x0
	r.check(ChallengeShow.title_of(res) == "CHALLENGE COMPLETE!" and ChallengeShow.consequence(res)[1] == "+%d XP" % CoachEvents.XP.rough_ok and ChallengeShow.progress_text(res) == "10 / 8 SAVES",
		"18: 10 / 8 SAVES: +160 XP")
	# 17: steals and blocks
	c = _fresh(814)
	p = _field(c)
	i = _idx(c, p)
	_choose(c, "defensive_masterclass", p, 1)
	_game(c, [1, 2, 3, 4, 5, 6], 2, {"steals": [i, i], "blocks": [i]})
	res = CoachEvents.popups(c)[0]
	r.check(ChallengeShow.progress_text(res) == "3 / 2 STL+BLK" and ChallengeShow.parts_text(res) == "2 STEALS + 1 BLOCK" and int(res.line.st) == 2 and int(res.line.bl) == 1, "17: 3 / 2 STL+BLK (2 steals + 1 block), from his line")
	# 31-34: once, and saved
	c = _fresh(815)
	k = c.team().starters()[0]
	_choose(c, "rough_night", k, 1)
	_game(c, [1, 2, 3, 4, 5, 6], 2, {"saves": 10})
	var xa: int = ce._xp_total(k)
	var re := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(CoachEvents.popups(re).size() == 1 and re.coach_pending.is_empty(), "34: not yet seen: it survives a save and reload, and the challenge isn't active again")
	(CoachEvents.popups(c)[0] as Dictionary)["shown"] = true
	re = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(CoachEvents.popups(re).is_empty() and ce._xp_total(re.team().find_id(k.id)) == xa, "31/33: dismissed: never again, the XP paid once (%d)" % xa)
	_game(c, [1, 2, 3, 4, 5, 6], 2, {"saves": 10})
	r.check(c.coach_results.filter(func(x): return String(x.event) == "rough_night").size() == 1, "32: settled once: the next game doesn't again")
	# 36: an older result (no line saved) is no popup, and loads
	var old := {"eid": 1, "event": "star_in_making", "title": "A STAR IN THE MAKING", "k": "chal", "pid": k.id, "outcome": "ok", "note": "", "label": "", "lines": [], "shown": false}
	r.check(not CoachEvents.is_stat_result(old), "36: an older save's result (no line) never pops up")
	# 37: a simulated game settles it the same way
	c = _fresh(816)
	k = c.team().starters()[0]
	_choose(c, "keeper_confidence", k, 1)
	c.sim_my_game()
	c.last_summary = {}
	var sim: Array = c.coach_results.filter(func(x): return String(x.event) == "keeper_confidence")
	r.check(sim.size() == 1 and (not CoachEvents.is_stat_result(sim[0]) or (int(sim[0].have) == int(sim[0].line.sv) and String(sim[0].outcome) == ("ok" if int(sim[0].have) >= 10 else "fail"))),
		"37: a simulated game: the same evaluation (%s)" % str(sim[0].get("have", "didn't play") if not sim.is_empty() else "?"))

# ------------------------------------------------------------------ 20, 21
func _special_and_conditions() -> void:
	var c := _fresh(821)
	var p := _field(c)
	var i := _idx(c, p)
	_choose(c, "star_in_making", p, 1, {"special": true})
	_game(c, [i, i, i, i, i, 1, 1], 2)
	var res: Dictionary = CoachEvents.popups(c)[0]
	var cq := ChallengeShow.consequence(res)
	r.check(ChallengeShow.look(res) == "legend" and ChallengeShow.title_of(res) == "LEGENDARY CHALLENGE COMPLETE!" and cq[0] == "SPECIAL CHALLENGE COMPLETE!" and cq[1] == "3X GAME XP" and ChallengeShow.progress_text(res) == "5 / 5 GOALS",
		"20/24: 5 / 5 GOALS: LEGENDARY CHALLENGE COMPLETE!, 3X GAME XP")
	# the LEGENDARY LEADER: a win, his target missed: no bonus, both conditions shown
	c = _fresh(822)
	var lead := CoachEvents.leader(c)
	var li := _idx(c, lead)
	_choose(c, "big_rivalry", lead, 1, {"special": true})
	var goals: Array = [1, 2, 3, 4, 5, 6].filter(func(x): return x != li)
	_game(c, goals + goals, 2)
	var pops := CoachEvents.popups(c)
	if li < 0:
		r.check(pops.is_empty(), "21: the leader didn't play: nothing to show")
	else:
		res = pops[0]
		var conds := ChallengeShow.conditions(res)
		r.check(String(res.outcome) == "even" and ChallengeShow.title_of(res) == "CHALLENGE FAILED" and conds.size() == 2 and conds[0][1] == true and conds[1][1] == false
			and ChallengeShow.consequence(res)[1] == "NORMAL GAME XP" and ChallengeShow.consequence(res)[0] == "NO BONUS", "21: won but his target missed: not complete, both conditions shown, NORMAL GAME XP")
	# THE LEARNING EXPERIENCE: lost, his target made
	c = _fresh(823)
	p = _field(c)
	i = _idx(c, p)
	_choose(c, "learning_experience", p, 1)
	_game(c, [i, i], 9, {"assists": [i]})
	res = CoachEvents.popups(c)[0]
	var cd := ChallengeShow.conditions(res)
	r.check(String(res.outcome) == "ok" and cd.size() == 2 and String(cd[0][0]) == "THE TEAM LOSES" and cd[0][1] and cd[1][1] and ChallengeShow.consequence(res)[1] == "2X GAME XP", "21: THE LEARNING EXPERIENCE: lost and made: both conditions, 2X")
	# won: no statistical attempt at stake, no popup
	c = _fresh(824)
	p = _field(c)
	_choose(c, "learning_experience", p, 1)
	_game(c, [1, 2, 3, 4, 5, 6], 2)
	r.check(CoachEvents.popups(c).is_empty() and String(c.coach_results.back().outcome) == "even", "21: THE LEARNING EXPERIENCE won: normal XP, no popup")

# ------------------------------------------------------------------ 35, 13
func _waiting() -> void:
	var c := _fresh(831)
	var t := c.team()
	var sub: PoloPlayer = t.roster.filter(func(q): return not q in t.starters())[0]
	_choose(c, "backup_breakout", sub, 1)
	_game(c, [1, 2, 3, 4, 5, 6], 2)
	r.check(c.coach_pending.size() == 1 and CoachEvents.popups(c).is_empty(), "35/Part 13: he didn't get in: still waiting, no FAILED")
	var guard := 0
	while not c.coach_pending.is_empty() and guard < 6:
		guard += 1
		while not c.has_game() and guard < 6:
			guard += 1
			c.end_week()
		if c.has_game():
			_game(c, [1, 2, 3, 4, 5, 6], 2)
	var res: Array = c.coach_results.filter(func(x): return String(x.event) == "backup_breakout")
	r.check(not res.is_empty() and String(res[0].outcome) == "fail" and not CoachEvents.is_stat_result(res[0]), "Part 13: expired without a game in the water: settled by the old rule, no popup")

# ------------------------------------------------------------------ 22-30
func _screen() -> void:
	var c := _fresh(841)
	var k: PoloPlayer = c.team().starters()[0]
	var p := _field(c)
	var i := _idx(c, p)
	_choose(c, "rough_night", k, 1)
	_choose(c, "star_in_making", p, 1)
	var xp0: Array = c.team().roster.map(func(q): return ce._xp_total(q))
	c.last_summary = c.finish_my_game(pg._box(c, [i, i, 1, 1, 1, 1, 1], 3, {"assists": [i], "saves": 9}))
	var xp1: Array = c.team().roster.map(func(q): return ce._xp_total(q))
	r.check(CoachEvents.popups(c).size() == 2, "28: two challenges, two results")
	# the real postgame order: the review, then the results
	Game.career = c
	Game.goto("player_development")
	await _frames()
	r.check(Game.current_name == "player_development", "29: PLAYER DEVELOPMENT, the postgame's last screen")
	Game.current_screen._continue()
	await _frames()
	var shows := Game.current_screen.find_children("*", "ChallengeShow", true, false)
	r.check(Game.current_name == "coach_event" and shows.size() == 1 and (shows[0] as ChallengeShow).recs.size() == 2, "28/29: then the CHALLENGE RESULT popups, one at a time, over the coaching screen")
	var w: ChallengeShow = shows[0]
	r.check(w.motion == Juice.enabled() and (ChallengeShow.play(Control.new(), c, [], Callable(), false).motion == false), "26: Reduce Motion (and tests): no motion, straight to the finished picture")
	r.check(int(w.rec().pid) == k.id and w.c.team().find_id(int(w.rec().pid)) == k, "11: his portrait, by his own id")
	r.check(w.cont != null and not w.cont.disabled, "27: CONTINUE, usable at once")
	w.motion = true
	w._start()
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	w._gui_input(ev)
	r.check(w.t >= w.done_at() and w.done_at() <= 1.8, "25: short (%.2f s), and a tap skips to the end" % w.done_at())
	w._next()
	await _frames(1)
	r.check(CoachEvents.popups(c).size() == 1 and w.i == 1 and is_instance_valid(w), "28/33: the first closed (saved as seen), the second up")
	w._next()
	await _frames(3)
	r.check(CoachEvents.popups(c).is_empty(), "33: both seen")
	var xp2: Array = c.team().roster.map(func(q): return ce._xp_total(q))
	r.check(xp2 == xp1, "31/32: showing them paid nothing more (XP as the game left it)")
	r.check(Game.current_name in ["hub", "coach_event"], "27: CONTINUE goes on with the postgame (%s)" % Game.current_name)
	# a reload while one is still unseen: the hub brings it back, once
	var c2 := _fresh(842)
	var k2: PoloPlayer = c2.team().starters()[0]
	_choose(c2, "rough_night", k2, 1)
	_game(c2, [1, 2, 3], 9, {"saves": 5})
	Game.career = Career.from_dict(JSON.parse_string(JSON.stringify(c2.to_dict())))
	Game.goto("hub")
	await _frames(4)
	var s2 := Game.current_screen.find_children("*", "ChallengeShow", true, false)
	r.check(Game.current_name == "coach_event" and s2.size() == 1, "34: reloaded before it was seen: it comes back")
	(s2[0] as ChallengeShow)._next()
	await _frames(4)
	r.check(CoachEvents.popups(Game.career).is_empty() and Game.current_name == "hub", "33: closed: back to the hub, never again")

# ------------------------------------------------------------------ Part 18
func _dev_preview() -> void:
	var c := _fresh(851)
	Game.career = c
	Game.settings.dev_mode = true
	var L = load("res://src/ui/screens/coach_lab.gd")
	var before := JSON.stringify(c.to_dict())
	var bad: Array = []
	for e in CoachEvents.EVENTS:
		var id := String(e.id)
		for sp in [false, true]:
			for ok in [true, false]:
				var want: bool = L.stat_challenge(id, sp) and (sp == false or CoachEvents.SPECIAL.has(id))
				var pr: Dictionary = L.preview_result(id, -1, ok, sp)
				if want and (pr.has("error") or not CoachEvents.is_stat_result(pr.res) or (String(pr.res.outcome) == "ok") != ok):
					bad.append("%s %s %s" % [id, sp, ok])
				if not L.stat_challenge(id, sp) and not pr.has("error"):
					bad.append("%s leaked" % id)
	r.check(bad.is_empty(), "Part 18: PREVIEW SUCCESS / FAILURE for every statistical challenge, 3X SUCCESS for the four; none for the others %s" % str(bad))
	r.check(JSON.stringify(c.to_dict()) == before, "Part 18: previews change nothing (no XP, penalty, attribute or challenge)")
	L.sel = "star_in_making"
	L.tab = "EVENTS"
	Game.goto("coach_lab")
	await _frames()
	var b = Game.current_screen.find_child("ResultLegend", true, false)
	r.check(b != null and Game.current_screen.find_child("ResultOk", true, false) != null, "Part 18: the buttons in the panel")
	b.emit_signal("pressed")
	await _frames()
	var sh := Game.current_screen.find_children("*", "ChallengeShow", true, false)
	r.check(sh.size() == 1 and (sh[0] as ChallengeShow).tag.begins_with("DEVELOPER PREVIEW") and ChallengeShow.look((sh[0] as ChallengeShow).rec()) == "legend", "Part 18: the real animation, marked as a preview")
	r.check(JSON.stringify(c.to_dict()) == before, "Part 18: and still nothing changed")
	Game.settings.dev_mode = false

static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	var t = load("res://tests/challenge_show_test.gd").new()
	t.r = runner
	t.ce = load("res://tests/coaching_events_test.gd").new()
	t.ce.r = runner
	t.pg = load("res://tests/postgame_test.gd").new()
	t.ce.pg = t.pg
	Store.reset_for_tests()
	var snap := func(name: String) -> void:
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(name))
	var cases := [["c1_ok", "star_in_making", false, true, false], ["c2_fail", "rough_night", true, false, false], ["c3_legend", "star_in_making", false, true, true],
		["c4_rough_ok", "rough_night", true, true, false], ["c5_rivalry", "big_rivalry", false, false, true]]
	for cs in cases:
		var c: Career = t._fresh(861)
		Game.career = c
		var p: PoloPlayer = c.team().starters()[0] if cs[2] else t._field(c)
		if cs[1] == "big_rivalry":
			p = CoachEvents.leader(c)
		var i: int = t._idx(c, p)
		t._choose(c, cs[1], p, 1, {"special": cs[4]})
		if cs[1] == "rough_night":
			t._game(c, [1, 2, 3, 4, 5, 6], 2, {"saves": 10 if cs[3] else 5})
		elif cs[1] == "big_rivalry":
			t._game(c, [i, i, 1, 2, 3], 2, {"assists": [i]})
		else:
			t._game(c, ([i, i, i, i, i, 1] if cs[4] else [i, i, 1, 1]) if cs[3] else [i, 1, 2], 2, {"assists": [i] if not cs[4] else []})
		Game.goto("hub")
		await tree.create_timer(0.6).timeout
		var w = Game.current_screen.find_children("*", "ChallengeShow", true, false)
		if not w.is_empty():
			w[0].motion = true
			w[0]._start()
			await tree.create_timer(0.7).timeout
			await snap.call(cs[0] + "_mid.png")
			await tree.create_timer(1.4).timeout
			await snap.call(cs[0] + ".png")
	print("  shots")
	Game.career = null
