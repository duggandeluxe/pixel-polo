extends RefCounted
## COACHING EVENTS: DECISIONS & CONSEQUENCES (CoachEvents): the spec's REQUIRED TESTING, numbered
## by its parts (37 presentation, 38 instant rewards, 39 conditional XP, 40 suspensions, 41 PROVE
## ME WRONG, 42 the event system). Played games go through finish_my_game (a match's box),
## simulated ones through sim_my_game: both settle through Career._award_game_xp.
##   godot --headless --path game -- --test coaching_events

var r
var pg   # (the postgame test's match-box helper)

func run(runner) -> void:
	r = runner
	pg = load("res://tests/postgame_test.gd").new()
	print("coaching events: decisions & consequences")
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	_instant()
	_credits()
	_challenge()
	_result_bonus()
	_no_stacking()
	_pmw(true)
	_pmw(false)
	_pmw_sim_and_save()
	_suspension()
	_distribution()
	await _screen()
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

func _frames(n: int = 2) -> void:
	for _i in n:
		await r.get_tree().process_frame

func _career(seed_value: int) -> Career:
	var c := Career.new_game("SJCU", "A", "B", seed_value)
	c.queue.clear()
	var guard := 0
	while not c.has_game() and guard < 5:
		guard += 1
		c.end_week()
	Game.career = c
	return c

func _xp_total(p: PoloPlayer) -> int:
	var t := p.xp
	for n in Development.level_index(p):
		t += Development.xp_required(n)
	return t

## A developing starter (room to grow), field player unless `gk`.
func _dev(c: Career, gk := false) -> PoloPlayer:
	for p in c.team().starters():
		if p.is_keeper() == gk and Development.boxes_left(p) >= 4 and p.tokens == 0:
			return p
	for p in c.team().starters():
		if p.is_keeper() == gk:
			for k in p.key_ratings():
				p.attr_pot[k] = minf(10.0, p.attrs[k] + 3.0)
			p.tokens = 0
			return p
	return null

func _ev(c: Career, id: String, p: PoloPlayer, extra: Dictionary = {}) -> Dictionary:
	var ev := {"id": id, "pid": p.id if p != null else -1, "story": 0, "vars": {"name": p.short_name().to_upper() if p != null else ""},
		"pids": c.team().starters().map(func(q): return q.id), "field": [], "year": c.year, "week": c.week}
	ev.merge(extra, true)
	return ev

## A played game: `win` 8-2 (a goal each to the seven's field players, more to `who`), else 1-9.
func _play(c: Career, win: bool, goals_for: Array = []) -> Dictionary:
	var seven := c.team().starters()
	var us: Array = goals_for if not goals_for.is_empty() else ([1, 1, 2, 3, 4, 5, 6, 6] if win else [1])
	var box: Dictionary = pg._box(c, us, 2 if win else 9, {"saves": 8})
	return c.finish_my_game(box)

# ------------------------------------------------------------------ 38
func _instant() -> void:
	var c := _career(301)
	var p := _dev(c)
	var x0 := _xp_total(p)
	var bar0: float = PlayerForm.momentum(p).bar
	var out := CoachEvents.apply(c, _ev(c, "star_in_making", p), 0)
	r.check(_xp_total(p) - x0 == CoachEvents.XP.star_praise, "38: PRAISE HIM: +%d XP through the development system (%d)" % [CoachEvents.XP.star_praise, _xp_total(p) - x0])
	r.check(is_equal_approx(float(PlayerForm.momentum(p).bar) - bar0, 0.2) and p.heat_bonus < 1.0, "38: +20%% HOT STAR PROGRESS (bar %.2f -> %.2f)" % [bar0, PlayerForm.momentum(p).bar])
	for i in 5:
		CoachEvents.apply(c, _ev(c, "keeper_confidence", p), 0)
	r.check(p.heat_bonus <= 1.0 and p.heat == 0, "38: HOT progress stays inside the system's limits: one GOOD grade's worth at most, never HOT on its own (%.2f)" % p.heat_bonus)
	p.form = [1, 0, 0]
	p.heat_bonus = 1.0
	PlayerForm.push_grade(p, 0)
	r.check(p.heat == 0, "38: one GOOD game and the boost: not HOT (HOT still takes a real run)")
	p.form = [1, 1, 0]
	p.heat_bonus = 1.0
	PlayerForm.push_grade(p, 0)
	r.check(p.heat == 1 and p.heat_bonus == 0.0, "38: two GOOD games and the boost: HOT, and the boost is spent")
	p.form = [0, -1, 1, -1]
	var lines := CoachEvents.apply(c, _ev(c, "rough_night", p), 0)
	r.check(p.form == [0, 0, 1, 0], "38: DOUBLE COLD recovery: his two most recent BAD grades forgiven, nothing else (%s)" % str(p.form))
	r.check(lines.any(func(l): return "FORGIVEN" in String(l[0])), "38: and it says so")
	var attrs := [p.attrs.duplicate(), p.attr_pot.duplicate(), p.stars, p.pot_stars]
	r.check([p.attrs, p.attr_pot, p.stars, p.pot_stars] == attrs, "38: no attribute, potential or star changed by an event")

func _credits() -> void:
	var c := _career(302)
	c.credits = 40
	var w0 := c.wallet()
	CoachEvents.apply(c, _ev(c, "recruiting_ripple", null), 0)
	r.check(c.wallet() == w0 + CoachEvents.COINS.ripple_now, "38: CAPITALIZE: +%d credits on the existing balance" % CoachEvents.COINS.ripple_now)
	c.credits = 10
	var w1 := c.wallet()
	r.check(CoachEvents.blocked(c, _ev(c, "recruiting_ripple", null), 1) != "", "38: INVEST is disabled when it can't be afforded")
	r.check(CoachEvents.apply(c, _ev(c, "recruiting_ripple", null), 1).is_empty() and c.wallet() == w1 and c.coach_pending.is_empty(), "38: ...and applying it anyway does nothing (no negative balance)")
	c.credits = 30
	CoachEvents.apply(c, _ev(c, "recruiting_ripple", null), 1)
	r.check(c.wallet() == 30 - CoachEvents.COINS.ripple_cost + Store.vault and c.coach_pending.size() == 1, "38: INVEST: -%d now, the win bet pending" % CoachEvents.COINS.ripple_cost)
	var before := c.wallet()
	var sm := _play(c, true)
	var credits_from_game := CreditRewards.total(sm.get("credits", []))
	r.check(c.wallet() - before - credits_from_game == CoachEvents.COINS.ripple_win and c.coach_pending.is_empty(), "39: won: +%d credits, once (%d)" % [CoachEvents.COINS.ripple_win, c.wallet() - before - credits_from_game])
	var res: Dictionary = c.coach_results.back()
	r.check(res.k == "invest" and res.outcome == "ok" and not res.shown, "42: the result saved, to be shown once")

# ------------------------------------------------------------------ 39
func _challenge() -> void:
	# made: 3 goals and assists next game -> 2x his game XP
	var c := _career(303)
	var p := _dev(c)
	var i := c.team().starters().find(p)
	CoachEvents.apply(c, _ev(c, "star_in_making", p), 1)
	var e: Dictionary = c.coach_pending[0]
	r.check(e.k == "chal" and e.stat == ("sv" if p.is_keeper() else "ga") and int(e.n) == 3, "39: CHALLENGE HIM: 3 goals + assists next game, pending")
	var sm := _play(c, true, [i, i, i, 1, 2, 3, 4, 5])
	var got: Dictionary = sm.xp[p.id]
	r.check(got.has("mult") and float(got.mult) == 2.0 and int(got.xp) == int(got.base) * 2, "39: made it: 2X his positive game XP (%d -> %d)" % [int(got.get("base", 0)), int(got.xp)])
	r.check(sm.xp.keys().all(func(id): return int(id) == p.id or not sm.xp[id].has("mult")), "39: nobody else's game XP is touched")
	r.check(c.coach_results.back().outcome == "ok" and c.coach_pending.is_empty(), "39: settled once")
	# missed: the same challenge, a game where he scores none
	var c2 := _career(304)
	var q := _dev(c2)
	CoachEvents.apply(c2, _ev(c2, "star_in_making", q), 1)
	var other := 1 if c2.team().starters()[1] != q else 2
	var sm2 := _play(c2, true, [other, other, other])
	r.check(float(sm2.xp[q.id].get("mult", 1.0)) == 0.75, "39: missed it: no bonus, 0.75X his game XP (the failure penalty)")
	r.check(c2.coach_results.back().outcome == "fail" and "0 OF 3" in String(c2.coach_results.back().note), "39: CHALLENGE FAILED, with his real numbers (%s)" % c2.coach_results.back().note)
	# an XP-reward challenge (rough night): made -> the event XP, separate from the game's
	var c3 := _career(305)
	var s := _dev(c3)
	var j := c3.team().starters().find(s)
	CoachEvents.apply(c3, _ev(c3, "rough_night", s), 1)
	var x0 := _xp_total(s)
	var sm3 := _play(c3, true, [j, j, 1, 2, 3])
	r.check(_xp_total(s) - x0 == int(sm3.xp[s.id].xp) + CoachEvents.XP.rough_ok, "39: DEMAND A RESPONSE made: +%d event XP on top of normal game XP" % CoachEvents.XP.rough_ok)

func _result_bonus() -> void:
	var c := _career(306)
	var p := _dev(c)
	var li := c.team().starters().find(p)
	CoachEvents.apply(c, _ev(c, "learning_experience", p), 1)
	var sm := _play(c, false, [li, li])
	r.check(sm.xp.has(p.id) and float(sm.xp[p.id].get("mult", 1.0)) == 2.0, "39: LEARN THROUGH ADVERSITY: lost, his 2 goals made it: 2X game XP after the result was recorded")
	var c2 := _career(307)
	var q := _dev(c2)
	CoachEvents.apply(c2, _ev(c2, "learning_experience", q), 1)
	var sm2 := _play(c2, true)
	r.check(float(sm2.xp[q.id].get("mult", 1.0)) == 1.0 and c2.coach_results.back().outcome == "even", "39: ...won instead: normal XP, no bonus, no penalty")
	var c3 := _career(308)
	var w := _dev(c3)
	CoachEvents.apply(c3, _ev(c3, "big_rivalry", w), 1)
	var sm3 := _play(c3, true)
	r.check(float(sm3.xp[w.id].get("mult", 1.0)) == 2.0, "39: RAISE THE STAKES: won, the leader's 2X")

func _no_stacking() -> void:
	var c := _career(309)
	var p := _dev(c)
	var i := c.team().starters().find(p)
	CoachEvents.apply(c, _ev(c, "star_in_making", p), 1)
	CoachEvents.apply(c, _ev(c, "big_rivalry", p), 1)
	var sm := _play(c, true, [i, i, i, 1, 2, 3, 4, 5])
	r.check(float(sm.xp[p.id].mult) == 2.0 and int(sm.xp[p.id].xp) == int(sm.xp[p.id].base) * 2, "39: two 2X bonuses for one man: 2X, never 4X")

# ------------------------------------------------------------------ 41
## A bench player who can legally start, and the event for him.
func _backup(c: Career) -> Dictionary:
	var rv := {"team": {"g": [5, 6]}, "players": []}
	return CoachEvents._when_pmw(c, rv)

func _pmw(win: bool) -> void:
	var c := _career(310 if win else 311)
	var ctx := _backup(c)
	r.check(not ctx.is_empty(), "41: a real backup who can legally start")
	if ctx.is_empty():
		return
	var t := c.team()
	var b := t.find_id(int(ctx.pid))
	r.check(not b in t.starters() and not b.is_suspended(), "41: he's really on the bench")
	for k in b.key_ratings():
		b.attr_pot[k] = minf(10.0, b.attrs[k] + 3.0)
	b.tokens = 0
	var ev := _ev(c, "prove_me_wrong", b, {"place": ctx.place, "displaced": ctx.displaced})
	var was := t.lineup.duplicate()
	CoachEvents.apply(c, ev, 1)
	var seven := t.starters()
	r.check(b in seven and seven.find(b) == int(ctx.place) and PoloTeam.legal(seven), "41: GIVE HIM THE START: he's in the seven, in a legal place (%s)" % PoloTeam.SLOT_NAMES[PoloTeam.SLOTS[int(ctx.place)]])
	r.check(not t.find_id(int(ctx.displaced)) in seven, "41: the displaced starter to the bench")
	r.check(CoachEvents.locked(c) == b.id, "41: locked in: the roster can't move him before the game")
	b.xp = Development.xp_needed(b) / 2
	var bar0 := b.xp
	var lv0 := b.xp_level
	var tk0 := b.tokens
	var at0 := [b.attrs.duplicate(), b.attr_pot.duplicate()]
	var mate: PoloPlayer = seven[1] if seven[1] != b else seven[2]
	var mate_x0 := _xp_total(mate)
	var sm := _play(c, win)
	var xp: Dictionary = sm.xp
	r.check(xp.has(b.id), "41: he played")
	var res: Dictionary = c.coach_results.back()
	if win:
		r.check(float(xp[b.id].mult) == 2.0 and int(xp[b.id].xp) == int(xp[b.id].base) * 2, "41: won: the backup 2X total (%d -> %d), not 3X" % [int(xp[b.id].base), int(xp[b.id].xp)])
		r.check(xp.keys().filter(func(id): return int(id) != b.id).all(func(id): return float(xp[id].mult) == 1.5 and int(xp[id].xp) == roundi(int(xp[id].base) * 1.5)),
			"41: won: every other player who played 1.5X")
		r.check(res.k == "pmw" and res.outcome == "ok" and int(res.team_xp[1]) > int(res.team_xp[0]), "41: HE PROVED YOU RIGHT, the real totals saved (%s)" % str(res.team_xp))
		r.check(b.xp >= bar0, "41: won: his bar is never reset")
	else:
		r.check(xp.keys().all(func(id): return float(xp[id].mult) == 0.75 and int(xp[id].xp) == roundi(int(xp[id].base) * 0.75)), "41: lost: everyone who played 0.75X")
		r.check(b.xp == 0 and int(res.lost) > 0, "41: lost: his XP bar reset to 0 (%d lost)" % int(res.get("lost", 0)))
		r.check(b.xp_level >= lv0 and b.tokens >= tk0 and [b.attrs, b.attr_pot] == at0, "41: his levels, upgrades, attributes and potential untouched")
		r.check(_xp_total(mate) == mate_x0 + int(xp[mate.id].xp), "41: nobody else's bar is reset")
		r.check(res.outcome == "fail" and res.lines.any(func(l): return "XP BAR RESET" in String(l[0])), "41: THE GAMBLE BACKFIRED, its numbers saved")
	r.check(c.coach_pending.is_empty() and CoachEvents.locked(c) == -1, "41: settled once, the lock gone")
	r.check(not b in t.starters() or t.lineup == was, "41: the lineup put back after the wager game")

func _pmw_sim_and_save() -> void:
	var c := _career(312)
	var ctx := _backup(c)
	if ctx.is_empty():
		r.check(false, "41: a backup for the sim test")
		return
	var b := c.team().find_id(int(ctx.pid))
	CoachEvents.apply(c, _ev(c, "prove_me_wrong", b, {"place": ctx.place, "displaced": ctx.displaced}), 1)
	var d := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(d.coach_pending.size() == 1 and String(d.coach_pending[0].k) == "pmw" and CoachEvents.locked(d) == b.id, "41: the wager survives a save")
	r.check(d.team().starters().any(func(q): return q.id == b.id), "41: ...and he still starts")
	Game.career = d
	var sm := d.sim_my_game()
	var res: Dictionary = d.coach_results.back()
	r.check(res.k == "pmw" and res.outcome != "void" and sm.xp.has(b.id), "41: a simmed game settles it the same way (%s)" % res.outcome)
	var mults: Array = sm.xp.keys().map(func(id): return float(sm.xp[id].get("mult", 1.0)))
	r.check(mults.all(func(m): return m in ([2.0, 1.5] if sm.won else [0.75])), "41: the sim's multipliers are the wager's (%s)" % str(mults))
	var n := d.coach_results.size()
	var d2 := Career.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	r.check(d2.coach_pending.is_empty() and d2.coach_results.size() == n, "41: reloaded after the game: settled, nothing to settle again")

# ------------------------------------------------------------------ 40
func _suspension() -> void:
	var c := _career(313)
	var t := c.team()
	var ctx := CoachEvents._when_discipline(c, {"team": {"g": [5, 6]}, "players": []})
	r.check(not ctx.is_empty(), "40: a starter who can be suspended with a legal seven left")
	var p := t.find_id(int(ctx.pid))
	r.check(not p.is_keeper(), "40: never the keeper")
	var rep := CoachEvents.suspension_ok(t, p)
	CoachEvents.apply(c, _ev(c, "practice_discipline", p), 1)
	var seven := t.starters()
	r.check(p.susp == 1 and not p in seven and not p.is_available(), "40: SUSPENDED: out of the seven, unavailable")
	r.check(rep in seven and PoloTeam.legal(seven) and seven[0].is_keeper(), "40: the lineup's best legal man takes his place (%s)" % rep.short_name())
	var d := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(d.team().find_id(p.id).susp == 1, "40: the suspension survives a save")
	var sm := c.sim_my_game()
	r.check(not sm.xp.has(p.id), "40: he didn't play the simulated game")
	r.check(p.susp == 0 and p.is_available(), "40: one game served, he's back")
	var res: Dictionary = c.coach_results.back()
	r.check(res.k == "susp" and (res.outcome == "ok") == sm.xp.has(rep.id), "40: the replacement's 2X chance settled from whether he played")
	if sm.xp.has(rep.id):
		r.check(float(sm.xp[rep.id].mult) == 2.0, "40: ...2X game XP for him")
	# never an impossible lineup: with only one keeper, the keeper is never the subject
	var only_gk := t.roster.filter(func(q: PoloPlayer): return q.is_keeper()).size() == 1
	r.check(not only_gk or CoachEvents.suspension_ok(t, t.keeper()) == null or t.starters()[0].is_keeper(), "40: suspending the only keeper is refused")

# ------------------------------------------------------------------ 42 + rarity
## Many rolls on a game where most events fit: the categories near their targets, discipline and
## PROVE ME WRONG rare.
func _distribution() -> void:
	var c := _career(314)
	var seven := c.team().starters()
	var players: Array = []
	for p: PoloPlayer in seven:
		var gk := p.is_keeper()
		players.append({"pid": p.id, "name": p.short_name(), "last": p.last, "pos": p.pos, "year": p.year, "gk": gk,
			"g": 3 if p == seven[1] else 0, "a": 2 if p == seven[1] else 0, "sh": 5, "st": 3 if p == seven[2] else 0, "bl": 1,
			"ed": 0, "sv": 14 if gk else 0, "ga": 6 if gk else 0})
	var rv := {"team": {"g": [7, 6]}, "players": players, "won": true, "streak": 3}
	var counts := {}
	var n := 0
	for i in 3000:
		c.event_log = []
		var ev := CoachEvents.roll(c, rv)
		if ev.is_empty():
			continue
		n += 1
		var cat := String(CoachEvents.scenario(String(ev.id)).cat)
		counts[cat] = int(counts.get(cat, 0)) + 1
		counts[String(ev.id)] = int(counts.get(String(ev.id), 0)) + 1
	var share := func(k: String) -> float: return float(counts.get(k, 0)) / maxf(1.0, n)
	print("    categories: dev %.2f challenge %.2f money %.2f discipline %.2f  pmw %.3f" % [share.call("dev"), share.call("challenge"), share.call("money"), share.call("discipline"), share.call("prove_me_wrong")])
	r.check(share.call("discipline") > 0.02 and share.call("discipline") < 0.09, "40: discipline events rare: ~5%% (%.3f)" % share.call("discipline"))
	r.check(share.call("dev") > share.call("challenge") and share.call("challenge") > share.call("money") and share.call("money") > share.call("discipline"),
		"24: positive development most common, discipline least")
	r.check(share.call("prove_me_wrong") < share.call("rough_night"), "23: PROVE ME WRONG less common than the ordinary challenges (%.3f)" % share.call("prove_me_wrong"))
	var rate := float(n) / 3000.0
	r.check(rate > 0.55 and rate < 0.65, "42: ~60%% of games still bring an event (%.2f)" % rate)

# ------------------------------------------------------------------ 37
func _screen() -> void:
	var c := _career(315)
	var p := _dev(c)
	c.pending_event = _ev(c, "star_in_making", p, {"vars": {"name": p.short_name().to_upper(), "line": "2 goals and 4 assists", "cls": "freshman"}})
	Game.goto("coach_event")
	await _frames(3)
	var scr = Game.current_screen
	var face: Control = scr.find_child("Portrait", true, false)
	r.check(face != null and int(face.get_meta("pid", -1)) == p.id, "37: his own portrait on a player event")
	var desc: Label = scr.find_child("Description", true, false)
	r.check(desc != null and desc.text.count(".") + desc.text.count("?") >= 3, "37: a story of several sentences")
	r.check(scr.find_child("Choice0", true, false) != null and scr.find_child("Choice1", true, false) != null and scr.find_child("Confirm", true, false) != null, "37: two decision panels and CONFIRM")
	r.check(scr.find_child("Recorded", true, false) != null, "37: his recorded line")
	c.credits = 0
	Store.vault = 0
	c.pending_event = _ev(c, "recruiting_ripple", null, {"vars": {"feat": "3 straight wins."}})
	Game.goto("coach_event")
	await _frames(3)
	scr = Game.current_screen
	r.check(scr.find_child("Logo", true, false) != null and scr.find_child("Portrait", true, false) == null, "37: a team event shows the logo")
	var b1: Control = scr.find_child("Choice1", true, false)
	r.check(b1 != null and String(b1.get_meta("blocked", "")) != "", "37: an unaffordable choice says why and can't be picked")
	scr.pick = 0
	scr._confirm()
	await _frames(1)
	r.check(scr.find_child("Result", true, false) != null and c.pending_event.is_empty(), "37: confirmed: applied once, the result shown")
	scr._leave()
	await _frames(2)
	# a settled consequence comes first in the next postgame, shown once
	c.coach_results.append({"eid": 99, "event": "prove_me_wrong", "title": "PROVE ME WRONG", "k": "pmw", "pid": p.id, "outcome": "fail", "note": "LOST",
		"label": "X STARTS", "lines": [["TEAM PENALTY: 0.75X GAME XP (100 -> 75)", "bad"]], "shown": false, "year": c.year, "week": c.week})
	Game.goto("coach_event")
	await _frames(3)
	scr = Game.current_screen
	var verdict: Label = scr.find_child("Verdict", true, false)
	r.check(verdict != null and verdict.text == "THE GAMBLE BACKFIRED", "41: the loss gets its own result: THE GAMBLE BACKFIRED")
	scr._leave()
	await _frames(2)
	r.check(CoachEvents.unshown(c).is_empty(), "42: shown once")
	Game.goto("title")
	await _frames(1)

# ------------------------------------------------------------------ shots
##   godot --path game -- --test coaching_events_png <dir>
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	var t := new()
	t.r = runner
	var c := t._career(320)
	c.credits = 60
	var p: PoloPlayer = c.team().starters()[3]
	var snap := func(name: String) -> void:
		await tree.create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
		print("  shot ", name)
	c.pending_event = t._ev(c, "star_in_making", p, {"vars": {"name": p.short_name().to_upper(), "line": "2 goals and 4 assists", "cls": "freshman"}})
	Game.goto("coach_event")
	await snap.call("e1_star")
	Game.current_screen.pick = 1
	Game.current_screen._render()
	await snap.call("e2_star_picked")
	var ctx := CoachEvents._when_pmw(c, {"team": {"g": [5, 6]}, "players": []})
	var b := c.team().find_id(int(ctx.pid))
	c.pending_event = t._ev(c, "prove_me_wrong", b, {"place": ctx.place, "displaced": ctx.displaced, "vars": ctx.vars})
	Game.goto("coach_event")
	await snap.call("e3_pmw")
	c.pending_event = t._ev(c, "recruiting_ripple", null, {"vars": {"feat": "3 straight wins, the latest 9-7."}})
	Game.goto("coach_event")
	await snap.call("e4_ripple")
	CoachEvents.apply(c, t._ev(c, "prove_me_wrong", b, {"place": ctx.place, "displaced": ctx.displaced}), 1)
	var dctx := CoachEvents._when_discipline(c, {"team": {"g": [5, 6]}, "players": []})
	if not dctx.is_empty():
		CoachEvents.apply(c, t._ev(c, "practice_discipline", c.team().find_id(int(dctx.pid))), 1)
	c.pending_event = {}
	Game.goto("matchup")
	await snap.call("e5_pregame")
	Game.goto("roster")
	await snap.call("e6_roster")
	c.coach_results.append({"eid": 98, "event": "prove_me_wrong", "title": "PROVE ME WRONG", "k": "pmw", "pid": b.id, "outcome": "fail", "note": "LOST",
		"label": "%s STARTS" % b.short_name().to_upper(), "lines": [["TEAM PENALTY: 0.75X GAME XP (212 -> 159)", "bad"], ["%s: 0.75X GAME XP (40 -> 30)" % b.short_name().to_upper(), "bad"],
		["%s'S XP BAR RESET: 245 XP LOST (0 / 467)" % b.short_name().to_upper(), "bad"]], "shown": false, "year": c.year, "week": c.week})
	c.coach_results.append({"eid": 97, "event": "star_in_making", "title": "A STAR IN THE MAKING", "k": "chal", "pid": p.id, "outcome": "ok", "note": "%s: 4 OF 3" % p.short_name().to_upper(),
		"label": "%s 3 GOALS + ASSISTS" % p.short_name().to_upper(), "lines": [["2X GAME XP ACTIVATED: %s 62 -> 124 XP" % p.short_name().to_upper(), "good"]], "shown": false, "year": c.year, "week": c.week})
	Game.goto("coach_event", {"review": false})
	await snap.call("e7_results")
	Game.career = null
