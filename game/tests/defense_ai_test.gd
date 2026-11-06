extends RefCounted
## The Intelligent Defensive AI & Goalie Leg Fatigue update: the computer's one drop a half
## (DropCall: scouted, kept or changed at halftime), PRESS first and the drop only once the centre
## has position (sooner for a bigger edge or a 2MD in foul trouble), PRESS as real man to man, and
## the keeper's legs in a drop (KeeperLegs). The spec's scenarios A-N, F2-F7.
##   godot --headless --path game -- --test defense_ai
## Fixed seeds throughout.

const DT := 1.0 / 60.0
const F := DefenseFormation.F
const D := DefenseFormation.Duty
const C_POS := PoloPlayer.Pos.CENTER
const G_POS := PoloPlayer.Pos.DEFENDER

var r

func run(runner) -> void:
	r = runner
	print("defensive AI: scouting the drop")
	_scouting()
	print("defensive AI: the call (A-D)")
	_reaction_table()
	_scenario_a()
	_scenario_bcd()
	print("defensive AI: PRESS is man to man (E)")
	_scenario_e()
	print("defensive AI: halftime (F2-F5, F7)")
	_halftime_decisions()
	_halftime_flow()
	print("defensive AI: whole matches (F, F6)")
	_matches()
	print("keeper legs (G-N)")
	_legs()
	_reach()

# ------------------------------------------------------------------ helpers
func _lab(vals: Dictionary, pos: int = PoloPlayer.Pos.UTILITY) -> PoloPlayer:
	return AttrBench.player(vals, false, {}, pos)

func _keeper(leg: float) -> PoloPlayer:
	return AttrBench.player({"leg": leg}, true)

## A matchup made by hand: the centre and the 2MD, the perimeter by attacker tag, their guards by tag.
func _m(c: Dictionary, g: Dictionary, perim: Dictionary = {}, guards: Dictionary = {}) -> Dictionary:
	var att := {"C": _lab(c, C_POS)}
	var def := {"C": _lab(g, G_POS)}
	for t in ["1", "2", "3", "4", "5"]:
		att[t] = _lab(perim.get(t, {}))
		def[t] = _lab(guards.get(t, {}))
	return {"att": att, "def": def}

func _a(p: Play, tag: String) -> Swimmer:
	return DefenseFormation.by_tag(p.attackers, tag)

func _d(p: Play, tag: String) -> Swimmer:
	return DefenseFormation.by_tag(p.defenders, tag, true)

## A settled possession against the computer's defence (Play.ai_drop `drop`), the point with the ball.
func _cpu(seed_value: int, drop: int = F.M_DROP, holder := "3") -> Play:
	var p: Play = r._center_play(seed_value, false)
	for s in p.attackers + p.defenders:
		s.player.trait_id = ""
	p.give_ball(_a(p, holder))
	p.ai_drop = drop
	p.pf = {}
	return p

## Everybody set up on his spot (as r._center_play does), the point with the ball.
func _settle(p: Play) -> void:
	for a in p.attackers:
		a.pos = a.home
		a.target = a.home
		a.vel = Vector2.ZERO
	for d in p.defenders:
		d.pos = d.mark.pos + (Geo.goal_center() - d.mark.pos).normalized() * (0.55 if d.mark.tag == "C" else 1.0)
		d.target = d.pos
	p.carry = false
	p.counter_t = 0.0
	p.drive_timer = 99.0
	p.give_ball(_a(p, "3"))

## The centre and his 2MD with these attributes.
func _matchup(p: Play, c: Dictionary, g: Dictionary) -> void:
	_a(p, "C").player = _lab(c, C_POS)
	_d(p, "C").player = _lab(g, G_POS)

## The centre wins inside water now (the 2 m battle turns his man).
func _centre_wins(p: Play) -> void:
	p.cfight = PlayAI.Fight.SPIN
	p.cfight_t = PlayAI.CENTER_SPIN

## The centre fronted: his man in the lane between him and the ball, and the battle held up.
func _centre_fronted(p: Play) -> void:
	p.cfight = PlayAI.Fight.HOLD
	p.cfight_t = 60.0
	var c := _a(p, "C")
	var g := _d(p, "C")
	g.pos = c.pos + (DefenseFormation.ball_focus(p) - c.pos).normalized() * PlayAI.CENTER_FRONT
	g.target = g.pos
	g.vel = Vector2.ZERO

## Live seconds (Play.elapsed) until the computer's in its drop, at most `limit`; INF if never.
func _time_to_drop(p: Play, limit: float = 6.0) -> float:
	var t0 := p.elapsed
	var steps := 0
	while p.elapsed - t0 < limit and not p.over and steps < 2000:
		steps += 1
		p.step(DT)
		if p.formation == p.ai_drop:
			return p.elapsed - t0
	return INF

# ------------------------------------------------------------------ 1. scouting
func _scouting() -> void:
	# a dominant centre on a weak 2MD, poor shooters outside: the drop with the most help in front of him
	var big := _m({"str": 9.5, "sho": 8.0}, {"str": 3.5, "dfn": 4.0},
		{"1": {"sho": 3.0}, "2": {"sho": 3.0}, "3": {"sho": 3.0}, "4": {"sho": 3.0}, "5": {"sho": 3.0}})
	var s_big := DropCall.score(big, true, DropCall.center_edge(big.att.C, big.def.C))
	r.check(DropCall.best(s_big) == F.M_DROP, "1: a dominant centre, weak shooters outside: M-DROP (the most centre support) %s" % str(s_big))
	# the same centre, but great shooters at the point and the flats M-DROP leaves (the computer's
	# spots 2, 3, 4 are your tags 4, 3, 2: slot)
	var guns := _m({"str": 9.5, "sho": 8.0}, {"str": 3.5, "dfn": 4.0},
		{"2": {"sho": 9.5, "pas": 8.0}, "3": {"sho": 9.5, "pas": 8.0}, "4": {"sho": 9.5, "pas": 8.0}, "1": {"sho": 3.0}, "5": {"sho": 3.0}})
	var s_guns := DropCall.score(guns, true, DropCall.center_edge(guns.att.C, guns.def.C))
	r.check(DropCall.best(s_guns) != F.M_DROP, "1: ...with great shooters where M-DROP leaves men open: not M-DROP (%s)" % DefenseFormation.NAMES[DropCall.best(s_guns)])
	# a poor shooter at the computer's spot 5 (your tag 1): 5 DROP leaves him the shot
	var weak5 := _m({"str": 6.5, "sho": 6.0}, {"str": 6.0, "dfn": 6.0},
		{"1": {"sho": 1.5, "pas": 3.0}, "2": {"sho": 8.0}, "3": {"sho": 8.0}, "4": {"sho": 8.0}, "5": {"sho": 8.0}})
	var s_w5 := DropCall.score(weak5, true, DropCall.center_edge(weak5.att.C, weak5.def.C))
	r.check(DropCall.best(s_w5) == F.FIVE_DROP, "1: a poor shooter at its spot 5, good ones elsewhere: 5 DROP (%s)" % str(s_w5))
	# a 2MD who has the centre handled, shooters outside: the least help, the most perimeter cover
	var held := _m({"str": 4.0, "sho": 4.0}, {"str": 9.0, "dfn": 9.0}, {"2": {"sho": 7.0}, "3": {"sho": 7.0}, "4": {"sho": 7.0}})
	var s_held := DropCall.score(held, true, DropCall.center_edge(held.att.C, held.def.C))
	r.check(float(DropCall.SUPPORT[DropCall.best(s_held)]) < float(DropCall.SUPPORT[F.M_DROP]),
		"1: a 2MD who has the centre handled: a drop with more perimeter cover than M-DROP (%s)" % DefenseFormation.NAMES[DropCall.best(s_held)])
	# real teams: it reads the rosters (the same two, the same pick), and different opponents get different picks
	var picks := {}
	var same := true
	for i in 30:
		var a := League.make_team(i % 6, 1 + i)
		var b := League.make_team((i + 2) % 6, 40 + i)
		var f := DropCall.scout(b, a)
		same = same and f == DropCall.scout(b, a) and DefenseFormation.is_drop(f)
		picks[f] = int(picks.get(f, 0)) + 1
	print("    picks over 30 matchups: %s" % str(picks))
	r.check(same, "1: the scouting is the rosters', no dice: the same matchup, the same drop (one of the four)")
	r.check(picks.size() >= 2, "1: different opponents, different drops (%d of the four used)" % picks.size())
	var flow := MatchFlow.new(League.make_team(1, 3), League.make_team(4, 5), 77, MatchState.QUARTER_MIN)
	r.check(flow.their_drop == DropCall.scout(flow.them, flow.us) and flow.their_first_drop == flow.their_drop,
		"1: a match starts with their scouted drop as the game plan")

# ------------------------------------------------------------------ 2. the call
func _reaction_table() -> void:
	var even_c := _lab({"str": 6.0, "sho": 6.0}, C_POS)
	var even_g := _lab({"str": 6.0, "dfn": 6.0}, G_POS)
	var big_c := _lab({"str": 9.0, "sho": 8.0}, C_POS)
	var weak_g := _lab({"str": 4.0, "dfn": 5.0}, G_POS)
	var good_g := _lab({"str": 9.0, "dfn": 9.0}, G_POS)
	# (a centre with position gets fed fast: every call within two seconds, no fouls needed)
	var rows := [
		["defender's advantage, 0 fouls", DropCall.reaction(even_c, good_g, 0), 1.5, 2.0],
		["even, 0 fouls", DropCall.reaction(even_c, even_g, 0), 1.0, 1.4],
		["centre's big edge, 0 fouls", DropCall.reaction(big_c, weak_g, 0), 0.5, 0.8],
		["even, 1 foul", DropCall.reaction(even_c, even_g, 1), 0.75, 1.1],
		["centre's big edge, 1 foul", DropCall.reaction(big_c, weak_g, 1), 0.3, 0.6],
		["even, 2 fouls", DropCall.reaction(even_c, even_g, 2), 0.3, 0.7],
		["defender's advantage, 2 fouls", DropCall.reaction(even_c, good_g, 2), 0.3, 0.7],
		["centre's big edge, 2 fouls", DropCall.reaction(big_c, weak_g, 2), 0.3, 0.7]]
	for row in rows:
		r.check(float(row[1]) >= float(row[2]) - 0.001 and float(row[1]) <= float(row[3]) + 0.001,
			"13: %s: %.2f s (%.2f-%.2f)" % [row[0], row[1], row[2], row[3]])
	r.check(DropCall.reaction(even_c, even_g, 0) > DropCall.reaction(even_c, even_g, 1) and DropCall.reaction(even_c, even_g, 1) > DropCall.reaction(even_c, even_g, 2),
		"12: the more fouls on the 2MD, the quicker the call")
	r.check(DropCall.reaction(even_c, good_g, 0) > DropCall.reaction(even_c, even_g, 0) and DropCall.reaction(even_c, even_g, 0) > DropCall.reaction(big_c, weak_g, 0),
		"11: the bigger the centre's edge, the quicker the call")

## A: fronted, he never has position: PRESS all possession, everybody on his man.
func _scenario_a() -> void:
	var p := _cpu(3100, F.M_DROP)
	_matchup(p, {"str": 9.0, "sho": 8.0}, {"str": 4.0, "dfn": 5.0})   # (even a big edge: no position, no call)
	p.pf[_d(p, "C").player.id] = 2                                       # (and two fouls: still no call)
	_centre_fronted(p)
	var far := 0.0
	var t := 0.0
	var start_press := p.formation == F.PRESS
	var calls := 0
	while t < 5.0 and not p.over:
		p.step(DT)
		t += DT
		calls += p.events.filter(func(e): return String(e.k) == "formation").size()
		p.events.clear()
		if t > 1.0:
			for tag in ["1", "2", "4", "5"]:
				far = maxf(far, _d(p, tag).pos.distance_to(_a(p, tag).pos))
	r.check(start_press and p.formation == F.PRESS and calls == 0, "A: the centre fronted all possession: PRESS throughout (no call, even with a big edge and two fouls)")
	r.check(far < 1.7, "A: ...and every perimeter defender stays on his man (furthest %.2f m)" % far)

## B, C, D: he wins position; the call comes after a reaction set by the matchup and the fouls.
func _scenario_bcd() -> void:
	# B: a strong centre on a weak 2MD
	var b := _cpu(3200, F.M_DROP)
	_matchup(b, {"str": 9.0, "sho": 8.0}, {"str": 4.0, "dfn": 5.0})
	r.check(b.formation == F.PRESS, "B: the possession starts in PRESS")
	_centre_wins(b)
	var tb := _time_to_drop(b)
	r.check(tb <= 0.9, "B: strong centre, weak 2MD: the drop's called quickly (%.2f s)" % tb)
	var dropper_ok := false
	for i in 60:
		b.step(DT)
		dropper_ok = dropper_ok or (b.f_dropper == _d(b, "3") and _d(b, "3").duty in [D.DROP, D.RECOVER, D.CRASH])
	r.check(b.formation == F.M_DROP and dropper_ok, "B: ...its own drop (M-DROP): D3 goes in front of the centre")
	# C: an even matchup: moderate
	var c := _cpu(3300, F.FOUR_FIVE)
	_matchup(c, {"str": 6.0, "sho": 6.0}, {"str": 6.0, "dfn": 6.0})
	_centre_wins(c)
	var tc := _time_to_drop(c)
	r.check(tc >= 1.0 and tc <= 1.5 and tc > tb, "C: even matchup, no fouls: still called, within a second or two (%.2f s, slower than B)" % tc)
	r.check(c.formation == F.FOUR_FIVE, "C: ...into its drop, 4-5 DROP")
	# D: the same even matchup, the 2MD on two fouls: urgent
	var d := _cpu(3300, F.FOUR_FIVE)
	_matchup(d, {"str": 6.0, "sho": 6.0}, {"str": 6.0, "dfn": 6.0})
	d.pf[_d(d, "C").player.id] = 2
	_centre_wins(d)
	var td := _time_to_drop(d)
	r.check(td <= 0.8 and td < tc, "D: the 2MD on two fouls: urgent (%.2f s against %.2f)" % [td, tc])
	# the centre loses it before they call it: the call's off
	var lost := _cpu(3400, F.M_DROP)
	_matchup(lost, {"str": 5.0, "sho": 5.0}, {"str": 7.0, "dfn": 7.0})   # (a slow call: ~3 s)
	_centre_wins(lost)
	for i in 30:
		lost.step(DT)
	_centre_fronted(lost)   # (his man's back in front of him)
	var cancelled := false
	for i in 300:
		lost.step(DT)
		cancelled = cancelled or lost.dc_wait < 0.0
	r.check(lost.formation == F.PRESS and cancelled, "13: the centre loses his position before the call: it's cancelled, still PRESS")
	# once in, no flicker: it stays in while he's on his spot
	var stay := _cpu(3500, F.FIVE_DROP)
	_matchup(stay, {"str": 9.0, "sho": 8.0}, {"str": 4.0, "dfn": 5.0})
	_centre_wins(stay)
	_time_to_drop(stay)
	stay.events.clear()   # (the call itself)
	var flips := 0
	for i in 360:
		stay.step(DT)
		flips += stay.events.filter(func(e): return String(e.k) == "formation").size()
		stay.events.clear()
	r.check(stay.formation == F.FIVE_DROP and flips == 0, "13: in the drop it stays (6 s, no flicking back to PRESS)")
	# ...and back to PRESS when the threat's over: the centre's left his spot
	var c_man := _a(stay, "C")
	var away := c_man.home + Vector2(-6.0, 0.0)   # (he goes out to the perimeter and stays there)
	var back := false
	for i in 240:
		c_man.pos = away
		c_man.target = away
		stay.step(DT)
		back = back or stay.formation == F.PRESS
	r.check(back, "13: the centre's off his spot for a while: back to PRESS")
	# never a drop it didn't plan: the call is always its own
	var own := true
	for f in DefenseFormation.DROPS:
		var q := _cpu(3600 + f, f)
		_matchup(q, {"str": 9.0, "sho": 8.0}, {"str": 4.0, "dfn": 5.0})
		_centre_wins(q)
		_time_to_drop(q)
		own = own and q.formation == f
	r.check(own, "F: whichever drop it planned is the one it calls")

## E: PRESS is man to man on the far side too.
func _scenario_e() -> void:
	for defending in [false, true]:
		for level in [0.5, 1.0]:
			var p: Play = r._center_play(3700, defending)
			for s in p.attackers + p.defenders:
				s.player.trait_id = ""
			p.set_level(level)
			p.give_ball(_a(p, "1"))   # (the right wing)
			var weak := DefenseFormation.slot(p, "5")
			var weak_tag := "5"   # (the far wing from tag 1, whichever way the defence sees it)
			var far := 0.0
			var worst := 0.0
			var sag := false
			var t := 0.0
			while t < 4.0 and not p.over:
				p.step(DT)
				t += DT
				if t > 1.0 and p.holder == _a(p, "1"):
					var wd := _d(p, weak_tag)
					far = maxf(far, wd.pos.distance_to(_a(p, weak_tag).pos))
					sag = sag or wd.duty != D.MARK or wd.fspot != Vector2.INF
					for tag in ["2", "3", "4", "5"]:
						worst = maxf(worst, _d(p, tag).pos.distance_to(_a(p, tag).pos))
			var who := "your AI defenders" if defending else "the computer's"
			r.check(p.formation == F.PRESS and far < 1.8 and not sag,
				"E %s (AI %.1f): ball on the right wing, the far wing's defender stays on him (%.2f m), no drop duty" % [who, level, far])
			r.check(worst < 1.8, "E %s (AI %.1f): every man off the ball in PRESS stays close (furthest %.2f m)" % [who, level, worst])
			r.check(weak != "", "E (orientation read: %s)" % weak)

# ------------------------------------------------------------------ 3. halftime
func _log(poss: int, extra: Dictionary = {}) -> Dictionary:
	var lg := DropCall.new_log()
	lg.poss = poss
	lg.press_poss = poss / 2
	lg.drop_poss = poss - lg.press_poss
	for k in extra:
		lg[k] = extra[k]
	return lg

func _by(goals: Dictionary, saves: Dictionary = {}, tired: Dictionary = {}) -> Dictionary:
	var by := {}
	for t in ["C", "1", "2", "3", "4", "5"]:
		by[t] = {"g": int(goals.get(t, 0)), "sv": int(saves.get(t, 0)), "sh": int(goals.get(t, 0)) + int(saves.get(t, 0)) + 1,
			"tired": int(tired.get(t, 0))}
	return by

func _halftime_decisions() -> void:
	var avg := _m({"str": 6.5, "sho": 6.0}, {"str": 6.0, "dfn": 6.0})
	# F2: M-DROP (scouted against a big centre) and a quiet half: kept
	var m_side := _m({"str": 8.5, "sho": 7.5}, {"str": 5.0, "dfn": 5.0})
	var quiet := _log(14, {"goals": 2, "saves": 3, "drop_goals": 1, "press_goals": 1, "c_threats": 2, "by": _by({"3": 1, "1": 1}, {"5": 2, "C": 1})})
	r.check(DropCall.best(DropCall.score(m_side, true, DropCall.center_edge(m_side.att.C, m_side.def.C))) == F.M_DROP, "F2: (the scouting's M-DROP)")
	var f2 := DropCall.halftime(F.M_DROP, m_side, quiet, 0, true)
	r.check(f2.keep and int(f2.drop) == F.M_DROP, "F2: M-DROP limited them: kept (%s, gain %.2f < margin %.2f)" % [f2.reason, f2.gain, f2.margin])
	# Example A: 4-5 DROP (scouted where it fits: shooters away from its spots 4, 5) working: kept
	var f45_side := _m({"str": 6.0, "sho": 5.0}, {"str": 7.0, "dfn": 7.0}, {"1": {"sho": 3.0}, "2": {"sho": 3.5}, "3": {"sho": 7.5}, "4": {"sho": 7.5}, "5": {"sho": 7.5}})
	var s45 := DropCall.best(DropCall.score(f45_side, true, DropCall.center_edge(f45_side.att.C, f45_side.def.C)))
	r.check(s45 == F.FOUR_FIVE, "6 Example A: (the scouting's 4-5 DROP: %s)" % DefenseFormation.NAMES[s45])
	var a45 := DropCall.halftime(F.FOUR_FIVE, f45_side, quiet, 0, true)
	r.check(a45.keep and int(a45.drop) == F.FOUR_FIVE, "6 Example A: 4-5 DROP working: kept (gain %.2f < margin %.2f)" % [a45.gain, a45.margin])
	# F3 / Example B: 5 DROP, the centre dominating, the 2MD on two fouls: more centre support
	var c_log := _log(14, {"goals": 7, "saves": 2, "drop_goals": 4, "press_goals": 3, "c_threats": 9, "c_excl": 4, "drop_entries": 3,
		"by": _by({"C": 5, "2": 1, "4": 1}, {"C": 2})})
	var big := _m({"str": 8.5, "sho": 7.5}, {"str": 5.0, "dfn": 5.0})
	var f3 := DropCall.halftime(F.FIVE_DROP, big, c_log, 2, true)
	r.check(not f3.keep and float(DropCall.SUPPORT[int(f3.drop)]) > float(DropCall.SUPPORT[F.FIVE_DROP]),
		"F3: the centre dominating 5 DROP, the 2MD on two fouls: a drop with more centre support (%s, %s)" % [DefenseFormation.NAMES[int(f3.drop)], f3.reason])
	r.check(int(f3.drop) == DropCall.best(f3.scores), "F3: ...the best-scoring of the four")
	var f3_clean := DropCall.halftime(F.FIVE_DROP, big, c_log, 0, true)
	r.check(float(f3.edge) > float(f3_clean.edge), "D: the 2MD's fouls count in it (edge %.2f with two, %.2f with none)" % [f3.edge, f3_clean.edge])
	# F4 / Example C: M-DROP, the perimeter it leaves (its spots 2, 3, 4: your tags 4, 3, 2) shooting it
	# up, high goals off tired legs, the centre held: better perimeter cover
	var p_log := _log(14, {"goals": 7, "saves": 4, "drop_goals": 6, "press_goals": 1, "high_tired": 4, "c_threats": 1,
		"by": _by({"2": 2, "3": 3, "4": 2}, {"2": 1, "3": 2, "4": 1}, {"3": 2, "2": 1, "4": 1})})
	var f4 := DropCall.halftime(F.M_DROP, avg, p_log, 0, true)
	r.check(not f4.keep and int(f4.drop) != F.M_DROP and String(f4.reason) == "the perimeter",
		"F4: shooters exploiting M-DROP's open men: a drop with more perimeter cover (%s)" % DefenseFormation.NAMES[int(f4.drop)])
	# F5 / Example D: another drop only a little better: kept
	var flat := _log(14, {"goals": 4, "saves": 3, "drop_goals": 2, "press_goals": 2, "by": _by({"1": 1, "3": 1, "5": 1, "C": 1})})
	var f5 := DropCall.halftime(F.THREE_FOUR, avg, flat, 0, true)
	var near := 0.0
	for f in DefenseFormation.DROPS:
		if f != F.THREE_FOUR:
			near = maxf(near, float(f5.scores[f]) - float(f5.scores[F.THREE_FOUR]))
	r.check(f5.keep and int(f5.drop) == F.THREE_FOUR, "F5: 3-4 DROP, the rest within the margin (best by %.2f, margin %.2f): kept" % [near, f5.margin])
	# goals aren't all of it: a half of saves the keeper had to make counts as a busy half
	var saved := _log(14, {"goals": 1, "saves": 8, "by": _by({}, {"2": 3, "3": 3, "4": 2})})
	var hidden := DropCall.halftime(F.M_DROP, avg, saved, 0, true)
	r.check(float(hidden.margin) < float(f2.margin), "4A: a keeper saving them hides nothing: a busier half lowers the bar for a change (%.2f < %.2f)" % [hidden.margin, f2.margin])
	# deterministic: no dice in it
	r.check(DropCall.halftime(F.M_DROP, avg, p_log, 0, true).drop == f4.drop, "5: the same half, the same decision (no dice)")

func _halftime_flow() -> void:
	# F6: a change at halftime is the second half's only drop
	var f := MatchFlow.new(League.make_team(1, 3), League.make_team(4, 5), 99, MatchState.QUARTER_MIN)
	f.their_drop = F.M_DROP
	f.their_first_drop = F.M_DROP
	f.their_log = _log(14, {"goals": 9, "saves": 4, "drop_goals": 8, "press_goals": 1, "high_tired": 5, "c_threats": 0,
		"by": _by({"2": 3, "3": 3, "4": 3}, {"2": 1, "3": 2, "4": 1}, {"2": 2, "3": 2, "4": 1})})
	f.state.quarter = 2
	f._quarter_end()
	var second := f.their_drop
	r.check(not f.their_half.is_empty() and second != F.M_DROP and f.at_halftime(),
		"F6: at halftime they change M-DROP for %s (%s)" % [DefenseFormation.NAMES[second], f.their_half.get("reason", "")])
	f._their_halftime()
	r.check(f.their_drop == second, "F6: one decision a match: halftime's, and only once")
	f.break_done()
	f.sprint_done(true)
	var p := f.play
	r.check(p.ai_drop == second and p.formation == F.PRESS and not p.formation_locked, "F6: Q3: PRESS to start, and the new drop is the one it has")
	for s in p.attackers + p.defenders:
		s.player.trait_id = ""
	_settle(p)
	_centre_wins(p)
	var ok := false
	var only := true
	for i in 400:
		f.tick_attack(DT)
		if p.over:
			break
		only = only and p.formation in [F.PRESS, second]
		ok = ok or p.formation == second
	r.check(only and (ok or p.over), "F6: second half: only PRESS or %s, and it calls that one" % DefenseFormation.NAMES[second])
	# F7: your halftime controls are yours: their decision doesn't touch them, yours doesn't touch theirs
	var g := MatchFlow.new(League.make_team(2, 7), League.make_team(3, 8), 101, MatchState.QUARTER_MIN)
	g.set_gameplan(F.FIVE_DROP)
	g.state.quarter = 2
	g._quarter_end()
	var theirs := g.their_drop
	r.check(g.can_adjust() and g.user_formations() == [F.PRESS, F.FIVE_DROP], "F7: at halftime you can still adjust, your bar unchanged")
	r.check(g.adjust_drop(F.THREE_FOUR) and g.user_formations() == [F.PRESS, F.THREE_FOUR] and g.their_drop == theirs,
		"F7: your adjustment is yours: their drop stays %s" % DefenseFormation.NAMES[theirs])

# ------------------------------------------------------------------ 4. whole matches
func _matches() -> void:
	var halves_ok := true
	var start_press := true
	var calls := 0
	var possessions := 0
	var dropped := 0
	var decided := 0
	for i in 3:
		var f := MatchFlow.new(League.make_team(i, 20 + i), League.make_team(i + 3, 30 + i), 5100 + i, MatchState.QUARTER_MIN)
		var seen := [{}, {}]
		var steps := 0
		while f.phase != MatchFlow.Phase.FINAL and steps < 200000:
			steps += 1
			match f.phase:
				MatchFlow.Phase.SPRINT:
					f.sprint_done(f.rng.randf() < 0.5)
				MatchFlow.Phase.ATTACK:
					var p := f.play
					var half := 0 if f.state.quarter <= 2 else 1
					if p.kind != Play.Kind.PENALTY and not f.state.in_shootout:
						possessions += 1
						start_press = start_press and p.formation == F.PRESS and p.ai_drop == f.their_drop
					var think := 0.0
					var t := 0.0
					var was_drop := false
					while not p.over and t < 90.0:
						think -= DT
						if think <= 0.0:
							think = PlayBot.THINK_EVERY
							var d := PlayBot.think(p, f.rng)
							if not d.is_empty():
								p.throw(d.target, d.power)
						f.tick_attack(DT)
						t += DT
						seen[half][p.formation] = true
						if p.formation != F.PRESS and not was_drop:
							was_drop = true
							calls += 1
					dropped += 1 if was_drop else 0
					f.events.clear()
					f.attack_done()
				MatchFlow.Phase.DEFENSE:
					f.auto_keeper = 0.5
					var t := 0.0
					while not f.play.over and t < 90.0:
						f.tick_defense(DT)
						t += DT
					f.events.clear()
					f.defense_done()
				MatchFlow.Phase.SHOOTOUT_THEM:
					f.their_ball_done()
				MatchFlow.Phase.THEIR_SHOT:
					f.auto_duel(0.5)
					f.duel_done()
				MatchFlow.Phase.BREAK:
					f.break_done()
		decided += 0 if f.their_half.is_empty() else 1
		for k in seen[0]:
			halves_ok = halves_ok and int(k) in [F.PRESS, f.their_first_drop]
		for k in seen[1]:
			halves_ok = halves_ok and int(k) in [F.PRESS, f.their_drop]
		print("    match %d: %s then %s (%s); formations seen %s / %s" % [i, DefenseFormation.NAMES[f.their_first_drop],
			DefenseFormation.NAMES[f.their_drop], f.their_half.get("reason", "?"), str(seen[0].keys()), str(seen[1].keys())])
	print("    %d of %d possessions saw the drop called" % [dropped, possessions])
	r.check(start_press, "9: every one of their %d defensive possessions began in PRESS, with their planned drop" % possessions)
	r.check(halves_ok, "F: each half, only PRESS and that half's one drop")
	r.check(decided == 3, "3: every match, a halftime decision")
	r.check(calls > 0 and dropped < possessions, "10: the drop gets called in real play, and not every possession (%d of %d)" % [dropped, possessions])

# ------------------------------------------------------------------ 5. the keeper's legs
## A possession with their keeper's legs `leg`, in formation `f` (picked: no call), the point with the ball.
func _legs_play(seed_value: int, f: int, leg: float, defending := false) -> Play:
	var p: Play = r._center_play(seed_value, defending)
	for s in p.attackers + p.defenders:
		s.player.trait_id = ""
	p.keeper.player = _keeper(leg)
	p.give_ball(_a(p, "5"))   # (the computer's spot 1: no piston or dropper of any of the four on him)
	p.drive_timer = 99.0
	if f != F.PRESS:
		p.select_formation(f)
	return p

## Live seconds of play, nobody shooting (the shot clock wound up) and no whistle for holding.
func _hold(p: Play, secs: float) -> void:
	var t := 0.0
	while t < secs and not p.over:
		p.shot_clock = Play.SHOT_CLOCK
		p.foul_t = 0.0
		p.step(DT)
		t += DT

func _legs() -> void:
	# G: PRESS: nothing
	var g := _legs_play(4100, F.PRESS, 5.0)
	_hold(g, 10.0)
	r.check(g.gk_strain == 0.0 and KeeperLegs.loss(g) == 0.0, "G: ten seconds of PRESS: his legs as fresh as they were")
	# H: two seconds of drop: next to nothing
	var h := _legs_play(4200, F.M_DROP, 5.0)
	_hold(h, 2.0)
	var h_loss := KeeperLegs.loss(h)
	r.check(h_loss < 0.1 * KeeperLegs.cap(h.keeper.player), "H: two seconds in a drop: hardly anything (%.3f of his top reach)" % h_loss)
	# I: an extended drop: it builds, gradually, to a cap
	var i := _legs_play(4300, F.FIVE_DROP, 5.0)
	var marks := []
	for s in 5:
		_hold(i, 2.5)
		marks.append(KeeperLegs.loss(i))
	var rising := true
	for k in range(1, marks.size()):
		rising = rising and float(marks[k]) >= float(marks[k - 1])
	r.check(rising and float(marks[0]) < 0.3 * float(marks[4]) and float(marks[4]) <= KeeperLegs.cap(i.keeper.player) + 0.0001,
		"I: 12.5 s in a drop: it builds gradually to his cap (%s)" % str(marks.map(func(x): return snappedf(x, 0.001))))
	r.check(float(marks[2]) > 0.25 * KeeperLegs.cap(i.keeper.player), "I: ...and by 7.5 s it's noticeable (%.3f)" % marks[2])
	# J / K: legs 9 against legs 3, the same six seconds
	var strong := _legs_play(4400, F.FOUR_FIVE, 9.0)
	var weak := _legs_play(4400, F.FOUR_FIVE, 3.0)
	_hold(strong, 6.0)
	_hold(weak, 6.0)
	r.check(KeeperLegs.loss(strong) < KeeperLegs.loss(weak) * 0.6 and strong.gk_strain < weak.gk_strain,
		"J/K: Leg Strength 9 holds up far better than 3 after 6 s (%.3f against %.3f)" % [KeeperLegs.loss(strong), KeeperLegs.loss(weak)])
	r.check(KeeperLegs.cap(strong.keeper.player) < KeeperLegs.cap(weak.keeper.player), "J/K: ...and loses less at worst")
	# L: your keeper and theirs, the same rules
	var mine := _legs_play(4500, F.THREE_FOUR, 6.0, true)
	var theirs := _legs_play(4500, F.THREE_FOUR, 6.0, false)
	_hold(mine, 6.0)
	_hold(theirs, 6.0)
	r.check(absf(mine.gk_strain - theirs.gk_strain) < 0.05 and mine.gk_strain > 0.0, "L: your keeper and theirs tire alike in the same drop (%.2f / %.2f)" % [mine.gk_strain, theirs.gk_strain])
	var duel := KeeperDuel.new().setup_given(_keeper(6.0), Vector2(24, Geo.GOAL_Y), Geo.GOAL_Y + 1.1, 0.4, Geo.GOAL_X, Geo.GOAL_Y, 0.5, 1.0, true, 0.15)
	var fresh := KeeperDuel.new().setup_given(_keeper(6.0), Vector2(24, Geo.GOAL_Y), Geo.GOAL_Y + 1.1, 0.4, Geo.GOAL_X, Geo.GOAL_Y, 0.5, 1.0, true, 0.0)
	r.check(is_equal_approx(duel.height_k(), fresh.height_k() * ShotModel.legs_mult(1.0, 0.15)) and duel.height_k() < fresh.height_k(),
		"L: your keeper's dive takes the same loss off his reach (KeeperDuel.height_k by ShotModel.legs_mult)")
	# M: back to PRESS: he gets them back, but not at once (no switching it away)
	var m := _legs_play(4600, F.M_DROP, 5.0)
	_hold(m, 5.0)
	var tired := m.gk_strain
	m.formation = F.PRESS
	m.f_active = false
	_hold(m, 1.0)
	r.check(not m.over and m.gk_strain < tired and m.gk_strain > tired - 1.0, "M: a second back in PRESS: some of it back, most of it still there (%.2f -> %.2f)" % [tired, m.gk_strain])
	var toggle := _legs_play(4650, F.M_DROP, 5.0)
	for k in 8:
		toggle.formation = F.M_DROP if k % 2 == 0 else F.PRESS
		toggle.f_active = false
		_hold(toggle, 1.0)
	r.check(toggle.gk_strain > 1.5, "M: flicking in and out of the drop never wipes it (%.2f s still in his legs)" % toggle.gk_strain)
	# N: a foul's restart (the shot clock stopped) and a whistle's freeze don't count, nor reset it
	var n := _legs_play(4700, F.M_DROP, 5.0)
	_hold(n, 4.0)
	var before := n.gk_strain
	n.restart = true
	_hold(n, 1.0)
	var during := n.gk_strain
	n.restart = false
	n.freeze = 1.0
	_hold(n, 1.0)
	r.check(is_equal_approx(during, before) and is_equal_approx(n.gk_strain, before), "N: a restart and a whistle neither count nor reset it (%.2f)" % n.gk_strain)
	_hold(n, 1.0)
	r.check(n.gk_strain > before, "N: ...the same possession carries on: it builds again")
	var next := _legs_play(4700, F.M_DROP, 5.0)
	r.check(next.gk_strain == 0.0 and next.drop_t == 0.0, "N: a new possession: fresh legs")

## The reach itself: high shots only, through the real dive.
func _reach() -> void:
	r.check(is_equal_approx(ShotModel.height_reach(0.3, 0.5, 0.2), ShotModel.height_reach(0.3, 0.5, 0.0))
		and is_equal_approx(ShotModel.height_reach(ShotModel.HEIGHT_PEAK, 0.5, 0.2), ShotModel.height_reach(ShotModel.HEIGHT_PEAK, 0.5, 0.0)),
		"22: low shots and shoulder height: not touched")
	r.check(ShotModel.height_reach(1.0, 0.5, 0.2) < ShotModel.height_reach(1.0, 0.5, 0.0) * 0.81, "22: the top of the goal: the whole loss")
	# the same shots, the same dice: fresh legs against tired ones (right way, so it's only his reach)
	var keeper := _keeper(5.0)
	var shooter := _lab({"sho": 6.0})
	var out := {}
	for key in ["fresh", "tired"]:
		for h in [0.95, 0.3]:
			var rng := RandomNumberGenerator.new()
			rng.seed = 4800
			var ctx := AttrBench.shot_ctx(shooter, null, keeper, INF)
			ctx["height"] = h
			ctx["strain"] = 0.0 if key == "fresh" else KeeperLegs.cap(keeper)
			var goals := 0
			var reach := 0.0
			var n := 400
			for k in n:
				ctx["dive_side"] = KeeperDive.RIGHT if k % 2 == 0 else KeeperDive.LEFT
				var aim := Geo.GOAL_Y + (1.15 if k % 2 == 0 else -1.15)
				var res := ShotModel.resolve(Vector2(23.0, Geo.GOAL_Y), aim, 0.8, float(shooter.shoot), 9.0, [],
					Geo.GOAL_Y, float(keeper.keeping), rng, false, {}, ctx)
				goals += 1 if String(res.outcome) == "goal" else 0
				reach += float(res.get("dive", {}).get("reach_k", 0.0))
			out["%s_%s" % [key, h]] = [float(goals) / n, reach / n]
	print("    goals / reach_k, top corner fresh %s tired %s; low fresh %s tired %s" % [str(out["fresh_0.95"]), str(out["tired_0.95"]),
		str(out["fresh_0.3"]), str(out["tired_0.3"])])
	r.check(float(out["tired_0.95"][0]) > float(out["fresh_0.95"][0]) + 0.03,
		"22/24: after a long drop, top-corner shots go in more often (%.2f against %.2f)" % [out["tired_0.95"][0], out["fresh_0.95"][0]])
	r.check(float(out["tired_0.95"][0]) < 0.95, "24: ...never a sure thing (%.2f)" % out["tired_0.95"][0])
	r.check(is_equal_approx(float(out["tired_0.3"][0]), float(out["fresh_0.3"][0])), "22: low shots: exactly the same")
	r.check(float(out["tired_0.95"][1]) < float(out["fresh_0.95"][1]), "23: it's his dive's reach (what the art draws: KeeperDive.reach_k) that's shorter")
