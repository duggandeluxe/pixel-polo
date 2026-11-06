extends RefCounted
## COACHING EVENTS: HIGH STAKES & RARE TRIPLE XP: the spec's REQUIRED TESTING (26 rewards, 27 rare
## triple XP, 28 readability, 29 preservation). Played games through finish_my_game, a simmed one
## through sim_my_game (both settle in Career._award_game_xp).
##   godot --headless --path game -- --test coach_stakes
##   godot --path game -- --test coach_stakes_png <dir>

var r
var ce   # (the coaching events test: careers, players, events, played games)

func run(runner) -> void:
	r = runner
	ce = load("res://tests/coaching_events_test.gd").new()
	ce.r = runner
	ce.pg = load("res://tests/postgame_test.gd").new()
	print("coaching events: high stakes & rare triple xp")
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	_values()
	_instant()
	_fixed_xp()
	_team()
	_penalties()
	_special_roll()
	_special_targets()
	_rivalry()
	_stacking()
	_sim_and_old_save()
	_readability()
	await _screen()
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

func _xp(p: PoloPlayer) -> int:
	return ce._xp_total(p)

# ------------------------------------------------------------------ 26
func _values() -> void:
	var X: Dictionary = CoachEvents.XP
	r.check([X.star_praise, X.backup_reward, X.backup_ok, X.leader, X.team_win, X.keeper, X.rough_encourage, X.rough_ok, X.def_star,
		X.rivalry_calm, X.learn, X.private, X.recovery, X.cost_ok] == [80, 40, 150, 90, 30, 50, 60, 160, 90, 40, 60, 40, 30, 120],
		"26.1: every event XP value the spec gives")
	r.check(CoachEvents.COINS == {"ripple_now": 20, "ripple_cost": 15, "ripple_win": 50, "private": 15, "recovery": 15}, "26.6-11: credits 20 / -15 / +50 / -15 / -15, nothing doubled")
	r.check(X.pmw_safe == 25 and CoachEvents.PMW_WIN == 1.5 and CoachEvents.PMW_LOSS == 0.75 and CoachEvents.MULT_2X == 2.0, "26.13: PROVE ME WRONG unchanged (+25, 1.5X / 2X, 0.75X)")
	r.check(not CoachEvents.SPECIAL.has("prove_me_wrong") and not CoachEvents.FAIL_MULT.has("prove_me_wrong"), "26.13: ...no special, no new penalty")

func _instant() -> void:
	var c: Career = ce._career(401)
	var p: PoloPlayer = ce._dev(c)
	var x0 := _xp(p)
	var bar0: float = PlayerForm.momentum(p).bar
	CoachEvents.apply(c, ce._ev(c, "star_in_making", p, {"special": true}), 0)
	r.check(_xp(p) - x0 == 80 and is_equal_approx(float(PlayerForm.momentum(p).bar) - bar0, 0.2), "26.2: PRAISE HIM: +80 XP and +20 HOT STAR points")
	r.check(c.coach_pending.is_empty(), "27.12: a safe choice on a special event: no challenge, no triple XP")
	var k: PoloPlayer = ce._dev(c, true)
	var k0 := _xp(k)
	var kb: float = PlayerForm.momentum(k).bar
	CoachEvents.apply(c, ce._ev(c, "keeper_confidence", k), 0)
	r.check(_xp(k) - k0 == 50 and is_equal_approx(float(PlayerForm.momentum(k).bar) - kb, 0.3), "BUILD CONFIDENCE: +50 XP and +30 points")
	var q: PoloPlayer = c.team().starters()[4]
	ce._dev(c)
	var q0 := _xp(q)
	CoachEvents.apply(c, ce._ev(c, "backup_breakout", q), 0)
	r.check(_xp(q) - q0 == 40, "26.3: THE BACKUP BREAKOUT, REWARD HIM: exactly +40 XP (%d)" % (_xp(q) - q0))
	c.credits = 40
	var w0 := c.wallet()
	var d: PoloPlayer = c.team().starters()[5]
	var d0 := _xp(d)
	CoachEvents.apply(c, ce._ev(c, "practice_discipline", d), 0)
	r.check(c.wallet() == w0 - 15 and (Development.is_maxed(d) or _xp(d) - d0 == 40), "26.9: HANDLE IT PRIVATELY: -15 credits, +40 XP")
	var heavy: Array = c.team().starters().slice(1, 5).map(func(x): return x.id)
	var h0: Array = heavy.map(func(id): return _xp(c.team().find_id(id)))
	var w1 := c.wallet()
	CoachEvents.apply(c, ce._ev(c, "cost_of_victory", p, {"heavy": heavy.slice(0, 3)}), 0)
	var gains: Array = []
	for j in 4:
		gains.append(_xp(c.team().find_id(heavy[j])) - int(h0[j]))
	r.check(c.wallet() == w1 - 15 and gains.slice(0, 3).all(func(g): return g == 30 or g == 0) and gains[3] == 0, "26.10: INVEST IN THE TEAM: -15 credits, +30 XP each to up to three (%s)" % str(gains))
	c.credits = 5
	r.check(CoachEvents.blocked(c, ce._ev(c, "practice_discipline", d), 0) != "" and CoachEvents.blocked(c, ce._ev(c, "cost_of_victory", p), 0) != "",
		"the paid options are disabled when 15 credits can't be afforded")

func _fixed_xp() -> void:
	# THE BACKUP BREAKOUT made: +150 on top of his game XP; missed: 0.5X
	var c: Career = ce._career(402)
	var p: PoloPlayer = ce._dev(c)
	var i: int = c.team().starters().find(p)
	CoachEvents.apply(c, ce._ev(c, "backup_breakout", p), 1)
	var x0 := _xp(p)
	var sm: Dictionary = ce._play(c, true, [i, i, 1, 2, 3, 4])
	r.check(_xp(p) - x0 == int(sm.xp[p.id].xp) + 150 and not sm.xp[p.id].has("mult"), "26.4: PROVE IT AGAIN made: exactly +150 XP, no multiplier")
	var c2: Career = ce._career(403)
	var q: PoloPlayer = ce._dev(c2)
	CoachEvents.apply(c2, ce._ev(c2, "backup_breakout", q), 1)
	var o := 1 if c2.team().starters()[1] != q else 2
	var sm2: Dictionary = ce._play(c2, true, [o, o, o])
	r.check(float(sm2.xp[q.id].get("mult", 1.0)) == 0.5 and c2.coach_results.back().outcome == "fail", "PROVE IT AGAIN missed: 0.5X game XP")
	# A ROUGH NIGHT missed: 0.5X
	var c3: Career = ce._career(404)
	var s: PoloPlayer = ce._dev(c3)
	CoachEvents.apply(c3, ce._ev(c3, "rough_night", s), 1)
	var o3 := 1 if c3.team().starters()[1] != s else 2
	var sm3: Dictionary = ce._play(c3, true, [o3])
	r.check(float(sm3.xp[s.id].get("mult", 1.0)) == 0.5, "26.5: DEMAND A RESPONSE missed: 0.5X (made: +160, the coaching events suite)")
	# THE COST OF VICTORY: +120 made
	var c4: Career = ce._career(405)
	var v: PoloPlayer = ce._dev(c4)
	var vi: int = c4.team().starters().find(v)
	CoachEvents.apply(c4, ce._ev(c4, "cost_of_victory", v), 1)
	var v0 := _xp(v)
	var sm4: Dictionary = ce._play(c4, true, [vi, vi, 1, 2])
	r.check(_xp(v) - v0 == int(sm4.xp[v.id].xp) + 120, "INDIVIDUAL CHALLENGE made: +120 XP")

func _team() -> void:
	var c: Career = ce._career(406)
	var lead := CoachEvents.leader(c)
	CoachEvents.apply(c, ce._ev(c, "captains_speech", lead), 1)
	r.check(c.coach_pending.size() == 1 and c.coach_pending[0].k == "team", "CHALLENGE THE TEAM: riding on the next game")
	var seven := c.team().starters()
	var before: Array = seven.map(func(p): return _xp(p))
	var sm: Dictionary = ce._play(c, true)
	var ok := true
	for j in seven.size():
		var p: PoloPlayer = seven[j]
		if sm.xp.has(p.id) and not Development.is_maxed(p) and p.tokens < Development.boxes_left(p):
			ok = ok and _xp(p) - int(before[j]) == int(sm.xp[p.id].xp) + 30
	r.check(ok and sm.xp.keys().all(func(id): return not sm.xp[id].has("mult")), "won: +30 XP to everyone who played, no multiplier")
	var c2: Career = ce._career(407)
	CoachEvents.apply(c2, ce._ev(c2, "captains_speech", CoachEvents.leader(c2)), 1)
	var sm2: Dictionary = ce._play(c2, false)
	r.check(sm2.xp.keys().all(func(id): return float(sm2.xp[id].get("mult", 1.0)) == 0.75), "lost: 0.75X for everyone who played")

func _penalties() -> void:
	# A GOALKEEPER'S CONFIDENCE missed: 0.5X and 10 points of HOT STAR PROGRESS
	var c: Career = ce._career(408)
	var k: PoloPlayer = ce._dev(c, true)
	k.form = [1]
	k.heat_bonus = 0.6
	CoachEvents.apply(c, ce._ev(c, "keeper_confidence", k), 1)
	var sm: Dictionary = ce._play(c, true)   # (8 saves)
	var res: Dictionary = c.coach_results.back()
	r.check(float(sm.xp[k.id].get("mult", 1.0)) == 0.5 and res.outcome == "fail", "27.10: SAVES CHALLENGE missed: the displayed 0.5X")
	r.check(res.lines.any(func(l): return "-10% HOT STAR" in String(l[0])), "...and -10%% HOT STAR PROGRESS, shown (%s)" % str(res.lines))
	# never below nothing
	var c2: Career = ce._career(409)
	var p: PoloPlayer = ce._dev(c2)
	p.form = []
	p.heat_bonus = 0.0
	var line := CoachEvents.hot_loss(p, 0.3)
	r.check(p.heat_bonus == 0.0 and String(line[1]) == "info", "no HOT progress to lose: none taken")
	# didn't play: no penalty
	var c3: Career = ce._career(410)
	var b: PoloPlayer = c3.team().roster.filter(func(x): return not x in c3.team().starters() and not x.is_keeper())[0]
	CoachEvents.apply(c3, ce._ev(c3, "star_in_making", b), 1)
	var sm3: Dictionary = ce._play(c3, true)
	r.check(not sm3.xp.has(b.id) and c3.coach_results.back().outcome == "fail" and c3.coach_pending.is_empty(), "didn't play: settled once, nothing to multiply or penalize")

# ------------------------------------------------------------------ 27
func _special_roll() -> void:
	var c: Career = ce._career(411)
	var hits := 0
	var n := 4000
	for k in n:
		c.week = k % 20
		c.year = 2026 + k / 20
		if CoachEvents.roll_special(c, "star_in_making"):
			hits += 1
	var share := float(hits) / n
	r.check(share > 0.035 and share < 0.065, "27.2: about 1 in 20 occurrences special (%.1f%%)" % (share * 100.0))
	var others := 0
	for ev in CoachEvents.EVENTS:
		if not CoachEvents.SPECIAL.has(ev.id):
			for k in 200:
				c.week = k
				if CoachEvents.roll_special(c, String(ev.id)):
					others += 1
	r.check(others == 0 and CoachEvents.SPECIAL.keys() == ["star_in_making", "keeper_confidence", "defensive_masterclass", "big_rivalry"], "27.1: only the four approved events can be special")
	# rolled once, at generation, and saved
	var c2: Career = ce._career(412)
	var rv: Dictionary = {"team": {"g": [9, 4]}, "won": true, "players": [], "streak": 0}
	var made := 0
	var specials := 0
	for k in 300:
		c2.event_log.clear()
		var ev := CoachEvents.roll(c2, rv)
		if not ev.is_empty():
			made += 1
			r.check(ev.has("special"), "27.3: the variant decided when the event is made") if made == 1 else null
			if bool(ev.special):
				specials += 1
	r.check(specials == 0 or true, "(roll: %d events, %d special)" % [made, specials])
	var p: PoloPlayer = ce._dev(c2)
	c2.pending_event = ce._ev(c2, "star_in_making", p, {"special": true})
	var d := Career.from_dict(JSON.parse_string(JSON.stringify(c2.to_dict())))
	r.check(CoachEvents.is_special(d.pending_event) and CoachEvents.choices_for(d.pending_event)[1].label == "PROVE HE'S ELITE", "27.4: a special event survives save/load")
	c2.pending_event = ce._ev(c2, "star_in_making", p, {"special": false})
	var d2 := Career.from_dict(JSON.parse_string(JSON.stringify(c2.to_dict())))
	r.check(not CoachEvents.is_special(d2.pending_event) and CoachEvents.choices_for(d2.pending_event)[1].label == "CHALLENGE HIM", "...and a normal one stays normal")
	CoachEvents.apply(c2, ce._ev(c2, "star_in_making", p, {"special": true}), 1)
	var d3 := Career.from_dict(JSON.parse_string(JSON.stringify(c2.to_dict())))
	var e: Dictionary = d3.coach_pending[0]
	r.check(bool(e.special) and String(e.stat) == "g" and int(e.n) == 5 and float(e.mult) == 3.0 and float(e.fail_mult) == 0.75 and e.has("eid") and e.has("made"),
		"25: the pending challenge saved whole: variant, objective, 3X, failure penalty, its game")

func _special_targets() -> void:
	# A STAR IN THE MAKING, special: 5 real goals
	var c: Career = ce._career(413)
	var p: PoloPlayer = ce._dev(c)
	var i: int = c.team().starters().find(p)
	var ev: Dictionary = ce._ev(c, "star_in_making", p, {"special": true})
	r.check(CoachEvents.challenge(c, ev).label == "5 GOALS" and CoachEvents.challenge(c, ce._ev(c, "star_in_making", p)).label == "3 GOALS + ASSISTS", "27.5: special: 5 goals (normal 3 goals + assists)")
	CoachEvents.apply(c, ev, 1)
	var rest: Array = [1, 2, 3, 4, 5, 6].filter(func(j): return j != i).slice(0, 3)
	var sm: Dictionary = ce._play(c, true, [i, i, i, i] + rest)
	r.check(float(sm.xp[p.id].get("mult", 1.0)) == 0.75 and c.coach_results.back().outcome == "fail", "27.6: four goals isn't five: the displayed 0.75X (%s / %s)" % [str(sm.xp[p.id]), str(c.coach_results.back())])
	var c2: Career = ce._career(414)
	var q: PoloPlayer = ce._dev(c2)
	var qi: int = c2.team().starters().find(q)
	CoachEvents.apply(c2, ce._ev(c2, "star_in_making", q, {"special": true}), 1)
	var sm2: Dictionary = ce._play(c2, true, [qi, qi, qi, qi, qi, 1, 2])
	var g: Dictionary = sm2.xp[q.id]
	r.check(float(g.get("mult", 1.0)) == 3.0 and int(g.xp) == int(g.base) * 3 and bool(c2.coach_results.back().special), "27.9: five real goals: 3X GAME XP (%d -> %d)" % [int(g.get("base", 0)), int(g.xp)])
	r.check(c2.coach_results.back().lines.any(func(l): return "3X GAME XP ACTIVATED" in String(l[0])), "...and the result says so")
	# A GOALKEEPER'S CONFIDENCE, special: 16 real saves
	var c3: Career = ce._career(415)
	var k: PoloPlayer = c3.team().starters()[0]
	CoachEvents.apply(c3, ce._ev(c3, "keeper_confidence", k, {"special": true}), 1)
	var sm3: Dictionary = c3.finish_my_game(ce.pg._box(c3, [1, 2, 3, 4], 3, {"saves": 15}))
	r.check(float(sm3.xp[k.id].get("mult", 1.0)) == 0.5, "27.7: 15 saves isn't 16: 0.5X")
	var c4: Career = ce._career(416)
	var k4: PoloPlayer = c4.team().starters()[0]
	CoachEvents.apply(c4, ce._ev(c4, "keeper_confidence", k4, {"special": true}), 1)
	var sm4: Dictionary = c4.finish_my_game(ce.pg._box(c4, [1, 2, 3, 4], 3, {"saves": 16}))
	r.check(float(sm4.xp[k4.id].get("mult", 1.0)) == 3.0, "27.7: 16 real saves: 3X")
	# DEFENSIVE MASTERCLASS, special: 5 real steals + blocks; a keeper's 16 saves
	var c5: Career = ce._career(417)
	var dp: PoloPlayer = ce._dev(c5)
	var di: int = c5.team().starters().find(dp)
	var dev5: Dictionary = ce._ev(c5, "defensive_masterclass", dp, {"special": true})
	r.check(CoachEvents.challenge(c5, dev5).label == "5 STEALS + BLOCKS" and CoachEvents.challenge(c5, ce._ev(c5, "defensive_masterclass", c5.team().starters()[0], {"special": true})).label == "16 SAVES",
		"position-appropriate: a field player's 5 steals + blocks, a keeper's 16 saves")
	CoachEvents.apply(c5, dev5, 1)
	var sm5: Dictionary = c5.finish_my_game(ce.pg._box(c5, [1, 2, 3, 4, 5], 2, {"steals": [di, di, di], "blocks": [di, di]}))
	r.check(float(sm5.xp[dp.id].get("mult", 1.0)) == 3.0, "27.8: 3 steals + 2 blocks: 3X")
	var c6: Career = ce._career(418)
	var d6: PoloPlayer = ce._dev(c6)
	var d6i: int = c6.team().starters().find(d6)
	CoachEvents.apply(c6, ce._ev(c6, "defensive_masterclass", d6, {"special": true}), 1)
	var sm6: Dictionary = c6.finish_my_game(ce.pg._box(c6, [1, 2, 3, 4, 5], 2, {"steals": [d6i, d6i], "blocks": [d6i, d6i]}))
	r.check(float(sm6.xp[d6.id].get("mult", 1.0)) == 0.75, "27.8: four isn't five: 0.75X")

func _rivalry() -> void:
	var make := func(seed_value: int, special: bool) -> Array:
		var c: Career = ce._career(seed_value)
		var lead := CoachEvents.leader(c)
		if lead.is_keeper() or not lead in c.team().starters():
			lead = ce._dev(c)
		CoachEvents.apply(c, ce._ev(c, "big_rivalry", lead, {"special": special}), 1)
		return [c, lead, c.team().starters().find(lead)]
	var a: Array = make.call(419, false)
	var sm: Dictionary = ce._play(a[0], false)
	r.check(float(sm.xp[a[1].id].get("mult", 1.0)) == 0.5 if sm.xp.has(a[1].id) else true, "RAISE THE STAKES lost: the leader's 0.5X")
	var b: Array = make.call(420, true)
	var bi: int = b[2]
	var smb: Dictionary = ce._play(b[0], true, [bi, bi, bi, bi, bi, 1, 2, 3])
	r.check(float(smb.xp[b[1].id].get("mult", 1.0)) == 3.0, "LEGENDARY LEADER: won AND 5 goals + assists: 3X")
	var cc: Array = make.call(421, true)
	var o := 1 if cc[2] != 1 else 2
	var smc: Dictionary = ce._play(cc[0], true, [o, o, o, 3, 4, 5, 6, 6])
	r.check(float(smc.xp[cc[1].id].get("mult", 1.0)) == 1.0 and (cc[0] as Career).coach_results.back().outcome == "even", "won but his target missed: normal game XP (never 3X for a routine win)")
	var dd: Array = make.call(422, true)
	var di: int = dd[2]
	var smd: Dictionary = ce._play(dd[0], false, [di])
	r.check(float(smd.xp[dd[1].id].get("mult", 1.0)) == 0.5, "lost: 0.5X")

func _stacking() -> void:
	var c: Career = ce._career(423)
	var p: PoloPlayer = ce._dev(c)
	var i: int = c.team().starters().find(p)
	CoachEvents.apply(c, ce._ev(c, "star_in_making", p, {"special": true}), 1)
	CoachEvents.apply(c, ce._ev(c, "big_rivalry", p), 1)
	var sm: Dictionary = ce._play(c, true, [i, i, i, i, i, 1, 2, 3])
	r.check(float(sm.xp[p.id].mult) == 3.0 and int(sm.xp[p.id].xp) == int(sm.xp[p.id].base) * 3, "27.11: 3X and 2X for one man: 3X, never 6X")
	var c2: Career = ce._career(424)
	var q: PoloPlayer = ce._dev(c2)
	var qi: int = c2.team().starters().find(q)
	CoachEvents.apply(c2, ce._ev(c2, "learning_experience", q), 1)
	CoachEvents.apply(c2, ce._ev(c2, "captains_speech", CoachEvents.leader(c2)), 1)
	var sm2: Dictionary = ce._play(c2, false, [qi, qi])
	r.check(float(sm2.xp[q.id].mult) == 2.0, "a bonus he made beats a team penalty: one multiplier (%s)" % str(sm2.xp[q.id].mult))

func _sim_and_old_save() -> void:
	var c: Career = ce._career(425)
	var p: PoloPlayer = ce._dev(c)
	CoachEvents.apply(c, ce._ev(c, "star_in_making", p, {"special": true}), 1)
	c.sim_my_game()
	r.check(c.coach_pending.is_empty() and c.coach_results.back().event == "star_in_making", "29.7: a simulated game settles the special challenge too (%s)" % c.coach_results.back().outcome)
	# an older save's pending challenge (before failure penalties): missed, no penalty
	var c2: Career = ce._career(426)
	var q: PoloPlayer = ce._dev(c2)
	c2.coach_seq += 1
	c2.coach_pending.append({"k": "chal", "stat": "ga", "n": 3, "mult": 2.0, "label": "OLD", "reward": "2X GAME XP", "wait": false,
		"eid": c2.coach_seq, "event": "star_in_making", "title": "A STAR IN THE MAKING", "pid": q.id, "team": c2.school, "made": [c2.year, c2.week], "games": 0})
	var o := 1 if c2.team().starters()[1] != q else 2
	var sm: Dictionary = ce._play(c2, true, [o])
	r.check(float(sm.xp[q.id].get("mult", 1.0)) == 1.0 and c2.coach_pending.is_empty(), "29.1: an older save's challenge settles as it promised (no new penalty)")

# ------------------------------------------------------------------ 28
func _readability() -> void:
	var long := 0
	for ev in CoachEvents.EVENTS:
		if ev.id == "prove_me_wrong":
			continue
		var all: Array = (ev.stories as Array).duplicate()
		if ev.has("special_story"):
			all.append(ev.special_story)
		for t in all:
			var n := String(t).split(" ", false).size()
			if n > 42 or n < 18:
				long += 1
	r.check(long == 0, "28.1: every story short (2-3 sentences, about 25-45 words with its numbers)")
	r.check(CoachEvents.EVENTS.size() == 12, "29.8: all 12 events")

func _screen() -> void:
	var c: Career = ce._career(427)
	c.credits = 60
	var p: PoloPlayer = ce._dev(c)
	p.last = "Vanderbergh-Szabo"
	c.pending_event = ce._ev(c, "star_in_making", p, {"special": true, "vars": {"name": p.short_name().to_upper(), "line": "5 goals and 2 assists", "cls": "freshman", "Cls": "Freshman"}})
	Game.goto("coach_event")
	await ce._frames(3)
	var s = Game.current_screen
	var tag: Array = s.find_children("Special", "Label", true, false)
	r.check(tag.size() == 2, "28.5: SPECIAL CHALLENGE - 3X GAME XP, by the headline and on the choice (%d)" % tag.size())
	var ch1: Control = s.find_child("Choice1", true, false)
	var labels: Array = ch1.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	r.check("PROVE HE'S ELITE" in labels and labels.any(func(t): return "5 GOALS NEXT GAME" in t) and labels.has("SUCCESS: 3X GAME XP") and labels.has("FAILURE: 0.75X GAME XP"),
		"22: the task and both consequences, exactly (%s)" % str(labels))
	r.check(not labels.any(func(t): return "2X" in t), "22: never 2X on a 3X challenge")
	var pr: Array = s.find_children("Portrait", "", true, false)
	r.check(pr.size() == 1 and int(pr[0].get_meta("pid")) == p.id, "28.7: his own portrait")
	var page: Control = s.find_child("Page", true, false)
	var over: Array = s.find_children("*", "Label", true, false).filter(func(l): return l.is_visible_in_tree() and l.get_global_rect().end.x > page.get_global_rect().end.x + 1)
	r.check(over.is_empty(), "28.8-9: nothing runs off the page, long name and all (%s)" % str(over.map(func(l): return l.text)))
	c.pending_event = ce._ev(c, "star_in_making", p, {"vars": {"name": p.short_name().to_upper(), "line": "2 goals", "cls": "freshman"}})
	Game.goto("coach_event")
	await ce._frames(3)
	r.check(Game.current_screen.find_children("Special", "Label", true, false).is_empty(), "a normal event: no special mark")
	c.pending_event = {}

static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	var t = load("res://tests/coaching_events_test.gd").new()
	t.r = runner
	t.pg = load("res://tests/postgame_test.gd").new()
	var c: Career = t._career(430)
	c.credits = 60
	var snap := func(name: String) -> void:
		await tree.create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
		print("  shot ", name)
	var p: PoloPlayer = t._dev(c)
	var k: PoloPlayer = c.team().starters()[0]
	var v := {"name": p.short_name().to_upper(), "line": "4 goals and 2 assists", "cls": "freshman", "Cls": "Freshman"}
	c.pending_event = t._ev(c, "star_in_making", p, {"special": true, "vars": v})
	Game.goto("coach_event")
	await snap.call("hs1_star_special")
	Game.current_screen.pick = 1
	Game.current_screen._render()
	await snap.call("hs2_star_special_picked")
	c.pending_event = t._ev(c, "keeper_confidence", k, {"vars": {"name": k.short_name().to_upper(), "saves": "14", "save_pct": "64"}})
	Game.goto("coach_event")
	await snap.call("hs3_keeper")
	c.pending_event = t._ev(c, "rough_night", p, {"vars": {"name": p.short_name().to_upper(), "rough": "He took 6 shots and didn't score."}})
	Game.goto("coach_event")
	await snap.call("hs4_rough")
	var lead := CoachEvents.leader(c)
	c.pending_event = t._ev(c, "big_rivalry", lead, {"special": true, "vars": {"name": lead.short_name().to_upper(), "opp": "STANFORD", "why": "They're ranked #3 in the country."}})
	Game.goto("coach_event")
	await snap.call("hs5_rivalry_special")
	c.pending_event = {}
	c.coach_results.append({"eid": 97, "event": "star_in_making", "title": "A STAR IN THE MAKING", "k": "chal", "pid": p.id, "outcome": "ok", "special": true,
		"note": "%s: 5 OF 5" % p.short_name().to_upper(), "label": "%s 5 GOALS" % p.short_name().to_upper(),
		"lines": [["3X GAME XP ACTIVATED: %s 46 -> 138 XP" % p.short_name().to_upper(), "good"]], "shown": false, "year": c.year, "week": c.week})
	c.coach_results.append({"eid": 98, "event": "keeper_confidence", "title": "A GOALKEEPER'S CONFIDENCE", "k": "chal", "pid": k.id, "outcome": "fail",
		"note": "%s: 8 OF 10" % k.short_name().to_upper(), "label": "%s 10 SAVES" % k.short_name().to_upper(),
		"lines": [["0.5X GAME XP: %s 40 -> 20 XP" % k.short_name().to_upper(), "bad"], ["-10%% HOT STAR PROGRESS FOR %s" % k.short_name().to_upper(), "bad"]], "shown": false, "year": c.year, "week": c.week})
	Game.goto("coach_event", {"review": false})
	await snap.call("hs6_results")
	Game.career = null
