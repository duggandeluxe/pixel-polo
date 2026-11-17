extends RefCounted
## Defensive formations, physical pressing and the defensive AI (DefenseFormation):
##   godot --headless --path game -- --test formations          (the checks, and scenarios A-G)
##   godot --headless --path game -- --test formation_balance [n] (their attack against each of your formations)
## Staged plays with fixed seeds; the big samples are possessions played out by the game's own AI.

const DT := 1.0 / 60.0
const F := DefenseFormation.F
const D := DefenseFormation.Duty

var r   # the test runner (check, check_between)

func run(runner) -> void:
	r = runner
	print("formations: picking and locking")
	_selection()
	_ai_selection()
	print("formations: defensive movement")
	_movement()
	print("formations: physical pressing")
	_pressing()
	print("formations: M-DROP")
	_m_drop()
	print("formations: 5 DROP")
	_five_drop()
	print("formations: the pistons")
	_piston(F.FOUR_FIVE, "4", "5")
	_piston(F.THREE_FOUR, "3", "4")
	print("formations: ordinary fouls")
	_fouls()
	print("formations: centre entries and the dropper")
	_entries()
	print("formations: passing lanes and loose balls")
	_passing()
	print("formations: the screen")
	await _bar()
	print("formations: their attack against each formation")
	_counterplay(120)

# ------------------------------------------------------------------ helpers
## A set half court (everybody on his spot, his man goal side of him), the ball with `tag`,
## `f` picked (-1: left on PRESS, unpicked). Nobody drives.
func _settled(seed_value: int, f: int = -1, tag: String = "3", defending := true) -> Play:
	var p: Play = r._center_play(seed_value, defending)
	for s in p.attackers + p.defenders:
		s.player.trait_id = ""
	p.give_ball(PlaySetup._by_tag(p, tag))
	if f >= 0:
		p.select_formation(f)
	return p

func _a(p: Play, tag: String) -> Swimmer:
	return DefenseFormation.by_tag(p.attackers, tag)

func _d(p: Play, tag: String) -> Swimmer:
	return DefenseFormation.by_tag(p.defenders, tag, true)

## `secs` of play; `each` (optional) runs every frame after the step.
func _steps(p: Play, secs: float, each: Callable = Callable()) -> void:
	var t := 0.0
	while t < secs - 0.0001 and not p.over:
		p.step(DT)
		t += DT
		if each.is_valid():
			each.call()

## Passes to `m` and plays it until he has it (or 2 s). True if he caught it.
func _feed(p: Play, m: Swimmer) -> bool:
	p.freeze = 0.0
	p._pass(p.lead_point(m), m)
	var t := 0.0
	while p.ball.state == Ball.State.PASS and t < 2.0 and not p.over:
		p.step(DT)
		t += DT
	return p.holder == m and not p.over

## A lab player with these attributes (AttrBench: exactly these numbers, not a pro's).
func _lab(vals: Dictionary, pos: int = PoloPlayer.Pos.UTILITY) -> PoloPlayer:
	return AttrBench.player(vals, false, {}, pos)

# ------------------------------------------------------------------ 1. picking and locking
func _selection() -> void:
	var p := _settled(100)
	r.check(p.formation == F.PRESS and not p.formation_locked, "a possession starts on PRESS, not locked")
	var all_ok := true
	for f in DefenseFormation.COUNT:
		var q := _settled(101 + f)
		all_ok = all_ok and q.select_formation(f) and q.formation == f and q.formation_locked
	r.check(all_ok, "every one of the five can be picked: %s" % " | ".join(DefenseFormation.NAMES))
	var q := _settled(110)
	q.select_formation(F.M_DROP)
	r.check(not q.select_formation(F.FIVE_DROP) and q.formation == F.M_DROP, "one pick a possession: a second is refused")
	# the lock through everything that isn't the ball changing hands, in a match
	var teams: Array = r._teams()
	var f := MatchFlow.new(teams[0], teams[1], 120, MatchState.QUARTER_MIN)
	f.auto_keeper = 0.5
	f.set_gameplan(F.FOUR_FIVE)   # (your bar: PRESS and Coaching's drop)
	f._start_defense(Play.Kind.HALF_COURT)
	var dp := f.play
	r.check(not f.play.formation_locked and f.play.formation == F.PRESS, "your defence: PRESS until you pick")
	r.check(f.select_formation(F.FOUR_FIVE), "you pick 4-5 DROP on their attack")
	r.check(not f.select_formation(F.PRESS), "...and that's it for this possession")
	dp._ordinary_foul(dp.holder, dp.defenders[3])
	_steps(dp, 1.0)
	var kept := dp.formation == F.FOUR_FIVE and dp.formation_locked
	dp.freeze = 0.0
	dp.holder = null
	dp._go_loose(Vector2(-1.0, 0.5))
	kept = kept and dp.formation == F.FOUR_FIVE
	# a rebound (off the post: loose, and their man gets it back)
	var back := dp.attackers[2]
	dp.ball.pos = back.pos
	_steps(dp, 0.3)
	r.check(f.play == dp and dp.holder == back and kept and dp.formation == F.FOUR_FIVE and dp.formation_locked,
		"the lock holds through an ordinary foul, a loose ball and their rebound (the same possession)")
	dp.shot_clock = 20.0   # (a reset with the ball still theirs)
	r.check(dp.formation_locked and f.play == dp, "...and a shot clock reset")
	r.check(not f.select_formation(F.PRESS), "still one pick: nothing to re-pick after the restart")
	# a real change of possession
	dp._turnover(dp.defenders[2], "STOLEN!", "steal")
	f.defense_done()
	r.check(f.phase == MatchFlow.Phase.ATTACK and not f.select_formation(F.PRESS), "on your attack there's nothing to pick")
	f.play._turnover(f.play.defenders[1], "STOLEN!", "steal")
	f.attack_done()
	r.check(f.phase == MatchFlow.Phase.DEFENSE and f.play != dp and f.play.formation == F.PRESS and not f.play.formation_locked,
		"the ball changed hands and came back: a new possession, PRESS, unlocked")
	r.check(f.select_formation(F.FOUR_FIVE), "...and a new pick")

## The computer's defence (DropCall; the whole of it: --test defense_ai): every possession starts
## on PRESS, unlocked, with the one drop it game-planned for the match; it reads the matchup.
func _ai_selection() -> void:
	var teams: Array = r._teams()
	var start_ok := true
	for i in 40:
		var f := MatchFlow.new(teams[0], teams[1], 2000 + i, MatchState.QUARTER_MIN)
		f._start_attack(Play.Kind.HALF_COURT)
		var p := f.play
		start_ok = start_ok and p.formation == F.PRESS and not p.formation_locked and p.ai_drop == f.their_drop \
			and DefenseFormation.is_drop(f.their_drop) and f.their_drop == DropCall.scout(teams[1], teams[0])
	r.check(start_ok, "the computer starts every possession on PRESS (unlocked) with its scouted drop, the same each time")
	# what it weighs: a dominant centre makes the drops with more help likelier, a weak A5 the 5 DROP
	var p := _settled(2400, -1, "3", false)
	var m := DropCall.matchup(p.them, p.us)
	var edge := func() -> float: return DropCall.center_edge(m.att.C, m.def.C)
	var base := DropCall.score(m, true, edge.call())
	m.att["C"] = _lab({"str": 9.5, "sho": 9.0}, PoloPlayer.Pos.CENTER)
	m.def["C"] = _lab({"str": 3.0, "dfn": 3.0}, PoloPlayer.Pos.DEFENDER)
	var big := DropCall.score(m, true, edge.call())
	r.check(big[F.M_DROP] - big[F.FOUR_FIVE] > base[F.M_DROP] - base[F.FOUR_FIVE], "a dominant centre against a weak guard: the drops with more help score better")
	m.att[DefenseFormation.TURNED["5"]] = _lab({"sho": 1.0})   # (the computer's own spot 5: DefenseFormation.slot)
	var weak5 := DropCall.score(m, true, edge.call())
	r.check(weak5[F.FIVE_DROP] - weak5[F.M_DROP] > big[F.FIVE_DROP] - big[F.M_DROP], "a poor shooter at A5: 5 DROP scores better (leave him the shot)")

# ------------------------------------------------------------------ 2. movement
func _movement() -> void:
	var mults := [2.0, 5.0, 8.0, 10.0].map(func(v): return DefenseFormation.move_mult(_lab({"dfn": v})))
	r.check(is_equal_approx(mults[0], 0.91) and is_equal_approx(mults[1], 1.0) and is_equal_approx(mults[2], 1.09) \
		and is_equal_approx(mults[3], 1.15), "movement multiplier 0.85 + 0.03 x Defense: %s" % str(mults))
	r.check(Attributes.FIELD == ["pas", "sho", "str", "dfn"] and not ("swi" in Attributes.NAMES) and not ("swimming" in Attributes.NAMES),
		"no Swimming attribute: the field player's four are still Passing, Shooting, Strength, Defense")
	# recovery: the same swimmer, a 9 against a 2 in Defense, swimming back 5 m to his man
	var times := []
	for dv in [9.0, 2.0]:
		var p := _settled(300, F.PRESS, "4")
		var d := _d(p, "1")
		var m := _a(p, "1")
		d.player = _lab({"dfn": dv})
		d.top_speed = 2.1
		d.pos = m.pos + Vector2(-5.0, -2.0)
		d.target = d.pos
		var t := 0.0
		var from := d.pos
		while t < 6.0 and d.pos.distance_to(from) < 4.0:
			p.step(DT)
			t += DT
		times.append(t)
	print("  the first 4 m back to his man: Defense 9 %.2f s, Defense 2 %.2f s" % times)
	r.check(times[0] < times[1] * 0.93, "higher Defense recovers faster (%.2f vs %.2f s)" % times)
	r.check(times[0] > times[1] * 0.75, "...but not unrealistically (no more than the multiplier's 26%)")
	# the attack swims as it always did, and nobody is ever moved further in a frame than he swims
	var acc := {"att_pace": true, "worst": 0.0, "who": ""}   # (a lambda can't assign to the locals it sees)
	for f in DefenseFormation.COUNT:
		for sd in 4:
			var p := _settled(320 + sd * 7 + f, f, ["2", "4", "5", "3"][sd])
			var last := {}
			for s in p.bodies():
				last[s] = s.pos
			var mates: Array = ["1", "2", "3", "4", "5", "C"]
			var k := 0
			var each := func():
				k += 1
				if k % 50 == 0 and p.can_throw():
					var m := _a(p, mates[(k / 50 + sd) % 6])
					if m != p.holder:
						p._pass(p.lead_point(m), m)
				for s in p.bodies():
					if s.keeper:
						continue
					var step: float = (s.pos - last[s]).length()
					var cap := s.top_speed * s.pace * 1.6 * DT + 0.06   # (the flat-out boost, and the shove apart)
					if step > cap and step - cap > acc.worst:
						acc.worst = step - cap
						acc.who = "%s %s" % [DefenseFormation.NAMES[f], s.tag if s.side == Swimmer.Side.US else "D" + s.dtag]
					last[s] = s.pos
				for a in p.attackers:
					acc.att_pace = acc.att_pace and a.pace == 1.0
				acc["frames"] = int(acc.get("frames", 0)) + 1
			_steps(p, 6.0, each)
	r.check(acc.att_pace and int(acc.get("frames", 0)) > 1000, "attackers always swim at their own speed (pace 1): offensive movement unchanged")
	r.check(acc.worst <= 0.0, "nobody teleports: every frame within his own swimming (%d frames, worst over by %.3f m %s)" % [int(acc.get("frames", 0)), acc.worst, acc.who])
	# picking a formation: they swim into it, they don't appear in it
	var p := _settled(340, -1, "2")
	_steps(p, 1.0)
	var d3 := _d(p, "3")
	var from := d3.pos
	p.select_formation(F.M_DROP)
	p.step(DT)
	var c := _a(p, "C")
	r.check(d3.pos.distance_to(from) < 0.1 and d3.pos.distance_to(c.pos) > 2.0, "M-DROP picked: D3 doesn't snap onto the centre")
	var reached := -1.0
	var t := 0.0
	while t < 5.0:
		p.step(DT)
		t += DT
		if reached < 0.0 and d3.duty == D.DROP:
			reached = t
	r.check(reached > 0.6, "...he swims there (%.2f s to get set in front of him)" % reached)

# ------------------------------------------------------------------ 3. pressing
## A3 with the ball at his spot, D3 in contact goal side of him, these two players; `secs` of the
## press alone (DefenseFormation.press each frame, nothing else moving), at `dt`. Returns how
## far A3 went away from the goal, and the largest single step.
func _push_run(strength: float, def: float, secs: float, dt: float = DT, gap: float = 0.85) -> Vector2:
	var p := _settled(400, F.PRESS, "3")
	var a := _a(p, "3")
	var d := _d(p, "3")
	a.player = _lab({"str": strength})
	d.player = _lab({"dfn": def})
	var goal := Geo.goal_center()
	a.pos = Vector2(23.4, 10.0)
	d.pos = a.pos + (goal - a.pos).normalized() * gap
	var start := a.pos.distance_to(goal)
	var biggest := 0.0
	var t := 0.0
	while t < secs - 0.0001:
		var was := a.pos
		DefenseFormation.press(p, dt)
		biggest = maxf(biggest, a.pos.distance_to(was))
		t += dt
	return Vector2(a.pos.distance_to(goal) - start, biggest)

func _pressing() -> void:
	var p := _settled(410)
	_steps(p, 1.5)
	var right := p.defenders.all(func(d: Swimmer): return d.mark != null and d.mark.tag == d.dtag and d.duty in [D.MARK, D.CLOSE])
	r.check(right, "PRESS: D1-D5 on A1-A5, D6 on the centre, every one of them man to man")
	r.check(not p.defenders.any(func(d: Swimmer): return d.duty in [D.DROP, D.SPLIT, D.CRASH]), "...nobody drops onto the centre")
	var none := _push_run(3.0, 9.0, 2.0, DT, 2.0)
	r.check(absf(none.x) < 1e-4, "no contact (2 m off him), no push")
	var weak := _push_run(3.0, 9.0, 2.0)
	var strong := _push_run(10.0, 2.0, 2.0)
	var even := _push_run(7.0, 7.0, 2.0)
	var slight := _push_run(5.0, 6.0, 2.0)
	print("  2 s of contact: Str 3 v Def 9 %+.2f m, Def 6 v Str 5 %+.2f m, 7 v 7 %+.2f m, Str 10 v Def 2 %+.2f m" % [weak.x, slight.x, even.x, strong.x])
	r.check_between(weak.x, 0.6, 0.8, "Scenario A: Strength 3 against Defense 9 is pushed away from the cage (m in 2 s)")
	r.check(weak.y <= DefenseFormation.push_speed(6.0) * DT + 1e-4, "...gradually: never more than %.3f m a frame" % (DefenseFormation.push_speed(6.0) * DT))
	r.check(strong.x <= 0.0, "Scenario B: Strength 10 against Defense 2 holds (or gains) his water (%+.2f m)" % strong.x)
	r.check(absf(even.x) < 1e-4 and slight.x > 0.0 and slight.x < weak.x, "level, he holds his ground; +1 a little; +6 a lot")
	# frame rate: the same push over a second at 30, 60 and 144 fps
	var fps := [1.0 / 30.0, DT, 1.0 / 144.0].map(func(dt): return _push_run(3.0, 9.0, 1.0, dt).x)
	r.check(absf(fps[0] - fps[2]) < 0.02 and absf(fps[1] - fps[2]) < 0.02, "the push doesn't depend on the frame rate (%s)" % str(fps))
	# limits: held on and on, he's never pushed past PUSH_MAX, and stays in the pool
	var long := _push_run(1.0, 10.0, 15.0)
	r.check(long.x <= DefenseFormation.PUSH_MAX + 1e-3, "pushed for 15 s: never more than %.1f m (%.2f m)" % [DefenseFormation.PUSH_MAX, long.x])
	var q := _settled(420, F.PRESS, "1")
	var a1 := _a(q, "1")
	var d1 := _d(q, "1")
	a1.player = _lab({"str": 0.0})
	d1.player = _lab({"dfn": 10.0})
	a1.pos = Vector2(27.0, 19.3)
	d1.pos = a1.pos + (Geo.goal_center() - a1.pos).normalized() * 0.8
	for i in 600:
		DefenseFormation.press(q, DT)
	r.check(Geo.in_pool(a1.pos) and a1.pos.y <= Geo.WIDTH - 0.5, "...pushed towards the wall, he stops at it")
	# contact ends, the push ends; a whistle ends it; one defender, one man
	var e := _settled(430, F.PRESS, "3")
	var a3 := _a(e, "3")
	var d3 := _d(e, "3")
	a3.player = _lab({"str": 2.0})
	d3.player = _lab({"dfn": 9.0})
	d3.pos = a3.pos + (Geo.goal_center() - a3.pos).normalized() * 0.85
	for i in 30:
		DefenseFormation.press(e, DT)
	var on := e.push_by == d3 and e.push_on == a3
	d3.pos += Vector2(3.0, 0.0)
	var held := a3.pos
	for i in 30:
		DefenseFormation.press(e, DT)
	r.check(on and e.push_by == null and a3.pos == held, "contact broken: the push stops at once")
	d3.pos = a3.pos + (Geo.goal_center() - a3.pos).normalized() * 0.85
	DefenseFormation.press(e, DT)
	e._ordinary_foul(a3, d3)
	held = a3.pos
	var pushed_in_freeze := false
	for i in 30:
		e.step(DT)
		pushed_in_freeze = pushed_in_freeze or e.push_by != null
	r.check(not pushed_in_freeze, "an ordinary foul: no pushing through the whistle or the restart")
	r.check(not e.defenders.any(func(x: Swimmer): return x != e.push_by and e.push_by != null), "only one pair at a time")
	# the shooting consequence: pushed back, he's further out (the shot's harder from there; his Shooting is untouched)
	var s := _settled(440, F.PRESS, "2")
	var a2 := _a(s, "2")
	var sho := Attributes.value(a2.player, "sho")
	var before := s.close_chance(a2, Vector2(25.5, 13.0))
	var after := s.close_chance(a2, Vector2(24.6, 13.6))
	r.check(Attributes.value(a2.player, "sho") == sho and OffenseAI.spot_quality(Vector2(24.6, 13.6)) < OffenseAI.spot_quality(Vector2(25.5, 13.0)) \
		and after <= before, "pushed back a metre, his look from there is worse (and his Shooting is the same)")
	# in a live possession: Scenario A, end to end
	var g := _settled(450, F.PRESS, "3")
	var ga := _a(g, "3")
	var gd := _d(g, "3")
	ga.player = _lab({"str": 3.0, "pas": 5.0})
	gd.player = _lab({"dfn": 9.0})
	var d0 := ga.pos.distance_to(Geo.goal_center())
	var pushed_at := -1.0
	var tt := 0.0
	while tt < 3.0 and g.freeze <= 0.0 and not g.over:
		g.step(DT)
		tt += DT
		if pushed_at < 0.0 and g.push_on == ga:
			pushed_at = tt
	var moved := ga.pos.distance_to(Geo.goal_center()) - d0
	print("  live: D3 (Def 9) gets to A3 (Str 3) in %.2f s and moves him %.2f m back by %.2f s" % [pushed_at, moved, tt])
	r.check(pushed_at >= 0.0 and moved > 0.15, "Scenario A live: D3 closes, makes contact, and A3 gives ground")

# ------------------------------------------------------------------ 4. M-DROP
func _m_drop() -> void:
	var p := _settled(500, F.M_DROP, "2")
	_steps(p, 3.0)
	var c := _a(p, "C")
	var b := p.ball.pos
	var d3 := _d(p, "3")
	var d6 := _d(p, "C")
	r.check(d3.duty in [D.DROP, D.CRASH] and (d3.pos - c.pos).dot(b - c.pos) > 0.0 and d3.pos.distance_to(c.pos) < 1.8,
		"D3 is in front of the centre, on the ball's side (%.2f m off him)" % d3.pos.distance_to(c.pos))
	r.check(d6.duty == D.BEHIND and (d6.pos - c.pos).dot(b - c.pos) < 0.0, "D6 is behind the centre: a sandwich")
	var d4 := _d(p, "4")
	var s4 := DefenseFormation.split_spot(p, _a(p, "4"), _a(p, "3"))
	r.check(d4.duty == D.SPLIT and d4.pos.distance_to(s4) < 1.0, "D4 splits A3-A4 (%.2f m off his spot)" % d4.pos.distance_to(s4))
	var mid4 := _a(p, "4").pos.lerp(_a(p, "3").pos, 0.5)
	r.check(d4.pos.distance_to(mid4) < 1.6, "...about halfway between them, goal side")
	# the ball at A4: D2 splits A2-A3
	var q := _settled(501, F.M_DROP, "4")
	_steps(q, 3.0)
	var d2 := _d(q, "2")
	r.check(d2.duty == D.SPLIT and d2.pos.distance_to(DefenseFormation.split_spot(q, _a(q, "2"), _a(q, "3"))) < 1.0, "D2 splits A2-A3")
	# Scenario C: A3 gets it. One splitter goes, the nearer one; the other covers; D3 stays
	var one := 0
	var right := 0
	var stayed := 0
	var n := 0
	for sd in 40:
		var e := _settled(510 + sd, F.M_DROP, "2" if sd % 2 == 0 else "4")
		_steps(e, 2.0)
		var a3 := _a(e, "3")
		var cand := [_d(e, "2"), _d(e, "4")]
		var quick: Swimmer = cand[0] if DefenseFormation.closeout_time(cand[0], a3) <= DefenseFormation.closeout_time(cand[1], a3) else cand[1]
		e.freeze = 0.0
		if not _feed(e, a3):
			continue
		n += 1
		var w := {"both": 0, "stay": true}
		_steps(e, 1.0, func():
			var closing := cand.filter(func(s: Swimmer): return s.duty == D.CLOSE).size()
			w.both = maxi(w.both, closing)
			w.stay = w.stay and (_d(e, "3").duty in [D.DROP, D.RECOVER, D.CRASH]))
		var ok_stay: bool = w.stay
		if w.both == 1:
			one += 1
		if e.f_closer == quick:
			right += 1
		if ok_stay:
			stayed += 1
	r.check(n >= 30 and one == n, "Scenario C: A3 has it, exactly one splitter closes out (%d/%d)" % [one, n])
	r.check(right == n, "...the one who can get there first (%d/%d)" % [right, n])
	r.check(stayed == n, "...and D3 never leaves the centre for A3 (%d/%d)" % [stayed, n])
	# the closer has to swim there: A3 isn't pressed the moment he catches it
	var k := _settled(560, F.M_DROP, "2")
	_steps(k, 2.0)
	var a3k := _a(k, "3")
	_feed(k, a3k)
	k.step(DT)   # (the defence reads the catch on its next look)
	var closer := k.f_closer
	var d_at_catch := closer.pos.distance_to(a3k.pos) if closer != null else 0.0
	var contact_t := -1.0
	var tk := 0.0
	while tk < 3.0 and not k.over:
		k.step(DT)
		tk += DT
		if contact_t < 0.0 and DefenseFormation.contact_defender(k, a3k) != null:
			contact_t = tk
	r.check(d_at_catch > 1.5 and contact_t > 0.4, "the splitter is %.1f m off at the catch and in contact %.2f s later" % [d_at_catch, contact_t])
	# when it's moved on, the closer goes back to splitting
	var mate := _a(k, "1")
	k.freeze = 0.0
	if k.holder == a3k and _feed(k, mate):
		_steps(k, 2.0)
		r.check(closer.duty in [D.SPLIT, D.MARK], "the ball moved on: the closer recovers to his split")

# ------------------------------------------------------------------ 5. 5 DROP
func _five_drop() -> void:
	var p := _settled(600, F.FIVE_DROP, "3")
	var c := _a(p, "C")
	var d5 := _d(p, "5")
	var a5 := _a(p, "5")
	var far := 0.0
	_steps(p, 2.5)
	# Scenario D: A5 has it: he attacks on the diagonal, one man helps, his own man is left
	p.freeze = 0.0
	var start5 := a5.pos
	_feed(p, a5)
	var g0 := a5.pos.distance_to(Geo.goal_center())
	var ang0 := absf(rad_to_deg(atan2(a5.pos.y - Geo.GOAL_Y, Geo.GOAL_X - a5.pos.x)))
	var w := {"far": 0.0, "max": 0, "helper": null}
	_steps(p, 1.6, func():
		w.far = maxf(w.far, d5.pos.distance_to(c.pos))
		var hs := p.defenders.filter(func(s: Swimmer): return s.duty == D.HELP)
		w.max = maxi(w.max, hs.size())
		if not hs.is_empty():
			w.helper = hs[0]
		p.raise_ball(false))
	far = w.far
	var helpers_max: int = w.max
	var helper: Swimmer = w.helper
	var helper_own: Swimmer = null
	var g1 := a5.pos.distance_to(Geo.goal_center())
	var ang1 := absf(rad_to_deg(atan2(a5.pos.y - Geo.GOAL_Y, Geo.GOAL_X - a5.pos.x)))
	print("  A5 attacks: %.1f m at %.0f deg -> %.1f m at %.0f deg; helper %s" % [g0, ang0, g1, ang1, ("D" + helper.dtag) if helper != null else "none"])
	r.check(g1 < a5.home.distance_to(Geo.goal_center()) - 1.5 and absf(ang1 - ang0) < 4.0, "A5 slides straight in at the cage: closer than his spot, on the same line (%.1f m)" % g1)
	r.check(far < 2.2, "D5 stays in front of the centre, never chasing A5 (%.1f m at most)" % far)
	r.check(helpers_max == 1 and helper != null and helper.dtag in ["1", "2", "3", "4"], "exactly one perimeter defender helps")
	if helper == null:
		return
	helper_own = _a(p, helper.dtag)
	r.check(helper.mark == a5 and helper.pos.distance_to(helper_own.pos) > 2.0, "...leaving his own man open (%.1f m off him)" % helper.pos.distance_to(helper_own.pos))
	# A5 passes to the man left open: he has the water while his man swims back
	p.freeze = 0.0
	var open_at := 0.0
	if _feed(p, helper_own):
		open_at = p.openness(helper_own)
		var dist0 := helper.pos.distance_to(helper_own.pos)
		r.check(helper.duty == D.RECOVER and dist0 > 1.5, "Scenario D: A5 to A%s: his man is %.1f m off at the catch, recovering" % [helper_own.tag, dist0])
		r.check(open_at > 1.4, "...A%s has a moment of open water (%.1f m)" % [helper_own.tag, open_at])
		var back_t := -1.0
		var tt := 0.0
		while tt < 4.0 and not p.over:
			p.step(DT)
			tt += DT
			if back_t < 0.0 and helper.pos.distance_to(helper_own.pos) < 1.4:
				back_t = tt
		r.check(back_t > 0.3, "...and his man has to swim back (%.2f s)" % back_t)
	# A5 with a defender right on him doesn't drive through him
	var q := _settled(610, F.FIVE_DROP, "5")
	var qa := _a(q, "5")
	var qd := _d(q, "4")
	qd.pos = qa.pos + (Geo.goal_center() - qa.pos).normalized() * 0.8
	r.check(DefenseFormation.open_attack(q, qa) == Vector2.INF, "A5 with a man on him: no automatic drive")
	var u := _settled(612, F.FIVE_DROP, "5")
	u.raise_ball(true)
	r.check(DefenseFormation.open_attack(u, _a(u, "5")) == Vector2.INF, "your pull back (ball up) comes first: he stops to shoot")

# ------------------------------------------------------------------ 6. the pistons
## `f` with pistons `t1` (out by default) and `t2` (dropped by default).
func _piston(f: int, t1: String, t2: String) -> void:
	var name: String = DefenseFormation.NAMES[f]
	var p := _settled(700 + f, f, "2")
	_steps(p, 2.5)
	var a1 := _a(p, t1)
	var a2 := _a(p, t2)
	var d1 := _d(p, t1)
	var d2 := _d(p, t2)
	var c := _a(p, "C")
	p.freeze = 0.0
	_feed(p, a1)
	var from1 := d1.pos.distance_to(a1.pos)
	_steps(p, 1.5)
	# (out to him at the pressure's pace, not a sprint: DefenseFormation.Press, tests/piston_test.gd)
	var pressing := d1.press != DefenseFormation.Press.HOLD or d1.pos.distance_to(a1.pos) < 1.6
	r.check(d1.mark == a1 and pressing and (d1.pos.distance_to(a1.pos) < from1 or d1.press == DefenseFormation.Press.RETURN)
		and d2.duty in [D.DROP, D.CRASH] and d2.pos.distance_to(c.pos) < 2.0,
		"%s: A%s has it: D%s going out to him, D%s dropped on the centre" % [name, t1, t1, t2])
	# quick ball across: D2 goes out, D1 swims back in. Nobody snaps; the centre's open a while.
	p.freeze = 0.0
	var gap := -1.0
	var swapped_at := -1.0
	if _feed(p, a2):
		var t := 0.0
		var d1_from := d1.pos
		var d2_from := d2.pos.distance_to(a2.pos)
		var went := false
		while t < 4.0 and not p.over:
			p.step(DT)
			t += DT
			if swapped_at < 0.0 and p.f_in == d1:
				swapped_at = t
			if gap < 0.0 and d1.duty == D.DROP:
				gap = t
			went = went or d2.press != DefenseFormation.Press.HOLD
		# (at the pressure's pace: a man swimming the ball away from him keeps his distance a while)
		r.check(d2.mark == a2 and went, "%s: A%s has it: D%s goes out to him (%.1f m -> %.1f m)" % [name, t2, t2, d2_from, d2.pos.distance_to(a2.pos)])
		r.check(d1_from.distance_to(c.pos) > 2.0 and gap > 0.5, "...D%s swims back in to the centre (%.2f s to get set: the centre's open till then)" % [t1, gap])
	# Defense: a better pair closes the gap sooner (the ball moved on quickly, before the one going
	# out to A1 has gone far: it's their swim back that's being raced)
	var gaps := []
	for dv in [9.0, 2.0]:
		var q := _settled(720 + f, f, "2")
		for t in [t1, t2]:
			var dd := _d(q, t)
			dd.player = _lab({"dfn": dv})
			dd.top_speed = 2.1
		_steps(q, 2.5)
		q.freeze = 0.0
		_feed(q, _a(q, t1))
		_steps(q, 0.4)
		# (both from the same spot, out on A1, as a piston who'd got there: it's the swim back that's raced)
		var qa1 := _a(q, t1)
		var qd1 := _d(q, t1)
		qd1.pos = qa1.pos + (Geo.goal_center() - qa1.pos).normalized() * 1.1
		qd1.vel = Vector2.ZERO
		q.freeze = 0.0
		var g := 6.0
		if _feed(q, _a(q, t2)):
			var t := 0.0
			while t < 6.0 and not q.over:
				q.step(DT)
				t += DT
				if _d(q, t1).duty == D.DROP:
					g = t
					break
		gaps.append(g)
	r.check(gaps[0] < gaps[1], "%s: the gap closes sooner with Defense 9 pistons than 2 (%.2f vs %.2f s)" % [name, gaps[0], gaps[1]])
	# no flip-flopping: rapid passes back and forth never change the drop faster than PISTON_COMMIT
	var j := _settled(740 + f, f, t1)
	_steps(j, 2.0)
	var changes: Array[float] = []
	var w := {"last": j.f_in, "t": 0.0}
	var watch := func():
		w.t += DT
		if j.f_in != w.last:
			changes.append(w.t)
			w.last = j.f_in
	for i in 6:
		j.freeze = 0.0
		var to := _a(j, t2 if j.holder == _a(j, t1) else t1)
		if j.holder == null:
			break
		j._pass(j.lead_point(to), to)
		var tf := 0.0
		while j.ball.state == Ball.State.PASS and tf < 2.0:
			j.step(DT)
			watch.call()
			tf += DT
		if j.holder != to:
			break
		for k in 12:
			j.step(DT)
			watch.call()
	var min_gap := INF
	for i in range(1, changes.size()):
		min_gap = minf(min_gap, changes[i] - changes[i - 1])
	r.check(changes.size() >= 2 and min_gap >= DefenseFormation.PISTON_COMMIT - 0.02,
		"%s: quick passing, the pistons change at most every %.2f s (%d changes, closest %.2f s)" % [name, DefenseFormation.PISTON_COMMIT, changes.size(), min_gap])

# ------------------------------------------------------------------ 7. fouls
func _fouls() -> void:
	# a man in contact from the catch: never whistled on the catch, never before FOUL_SETTLE
	var early := 0
	var firsts: Array[float] = []
	for sd in 300:
		var p := _settled(800 + sd, F.PRESS, "2")
		var a2 := _a(p, "2")
		var d2 := _d(p, "2")
		d2.pos = a2.pos + (Geo.goal_center() - a2.pos).normalized() * 0.85
		d2.target = d2.pos
		p.give_ball(a2)
		var t := 0.0
		while t < 6.0 and not p.over:
			p.step(DT)
			t += DT
			if p.events.any(func(e): return String(e.k) == "foul"):
				break
			p.events.clear()
		if p.events.any(func(e): return String(e.k) == "foul"):
			if t < DefenseFormation.FOUL_SETTLE:
				early += 1
			firsts.append(t)
	firsts.sort()
	var med: float = firsts[firsts.size() / 2] if not firsts.is_empty() else INF
	print("  pressed from the catch: fouled %d/300, median %.2f s after the catch" % [firsts.size(), med])
	r.check(early == 0, "no ordinary foul on the catch, nor before %.1f s of contact (%d)" % [DefenseFormation.FOUL_SETTLE, early])
	r.check_between(med, 1.4, 2.8, "a defender already pressing: typical seconds to the foul")
	# nobody in contact: no foul at all
	var q := _settled(1200, F.PRESS, "2")
	var qd := _d(q, "2")
	var qa := _a(q, "2")
	qd.pos = qa.pos + Vector2(-1.8, 0.0)
	var fouls := 0
	for i in 600:
		q._pressure(DT)
		if q.freeze > 0.0:
			fouls += 1
			q.freeze = 0.0
	r.check(fouls == 0, "his man 1.8 m off him: no ordinary foul in 10 s (%d)" % fouls)
	# the further the defender has to come, the later the foul
	var by_gap := []
	for gap in [0.85, 3.0, 5.0]:
		var ts: Array[float] = []
		for sd in 120:
			var p := _settled(1300 + sd, F.PRESS, "2")
			var a2 := _a(p, "2")
			var d2 := _d(p, "2")
			d2.pos = a2.pos + (Geo.goal_center() - a2.pos).normalized() * 0.85 + Vector2(-gap + 0.85, 0.0) * (1.0 if gap > 1.0 else 0.0)
			d2.target = d2.pos
			p.give_ball(a2)
			var t := 0.0
			while t < 8.0 and p.freeze <= 0.0 and not p.over:
				p.step(DT)
				t += DT
			if p.freeze > 0.0:
				ts.append(t)
		ts.sort()
		by_gap.append(ts[ts.size() / 2] if not ts.is_empty() else 9.0)
	print("  median seconds to the foul, his man starting 0.85 / 3 / 5 m off: %.2f / %.2f / %.2f" % by_gap)
	r.check(by_gap[0] < by_gap[1] and by_gap[1] < by_gap[2], "the further he has to close out, the later he can foul")
	# a foul stops the press; the centre fouled can't shoot it
	var e := _settled(1500, F.PRESS, "C")
	var c := _a(e, "C")
	e._ordinary_foul(c, _d(e, "C"))
	r.check(e.push_by == null and e.free_throw, "fouled: the press stops and it's a free throw")
	e.freeze = 0.0
	r.check(e.aim_info(Vector2(Geo.GOAL_X + 0.4, 10.6)).mode == "no_shot" and e.shoot_at(Vector2(Geo.GOAL_X + 0.4, 10.6), 0.8) != "shot",
		"the centre fouled can't shoot it: he has to pass")
	var ai := OffenseAI.new()
	r.check(not ai._can_shoot(e), "...and their AI knows it")
	r.check(e.man_up <= 0.0, "...an ordinary foul on the centre isn't an exclusion")

# ------------------------------------------------------------------ 8. centre entries
func _entries() -> void:
	# PRESS, his guard behind him (an open, excellent ball): an exclusion can come of it
	var ex := 0
	var n := 0
	for sd in 200:
		var p := _settled(1600 + sd, F.PRESS, "2")
		var c := _a(p, "C")
		var g := p._center_guard(c)
		g.pos = c.pos + Vector2(0.55, 0.0)
		g.target = g.pos
		if p.center_entry(p.holder.pos, c) != "open":
			continue
		if not _feed(p, c):
			continue
		n += 1
		_steps(p, 0.4, func(): p.raise_ball(false))
		if p.man_up > 0.0:
			ex += 1
	r.check(n > 150 and ex > n * 0.6, "an excellent entry, his man beaten and nobody to help: an exclusion (%d/%d)" % [ex, n])
	# a poor ball (in beside his man): caught, sometimes an ordinary foul, never an exclusion
	var poor := 0
	var poor_ex := 0
	var poor_n := 0
	for sd in 200:
		var p := _settled(1900 + sd, F.PRESS, "3")
		var c := _a(p, "C")
		var g := p._center_guard(c)
		g.pos = c.pos + Vector2(-PlayAI.CENTER_UP, PlayAI.CENTER_SIDE)
		g.target = g.pos
		p.holder.pos = Vector2(23.6, c.pos.y)
		if p.center_entry(p.holder.pos, c) != "straight":
			continue
		if not _feed(p, c):
			continue
		poor_n += 1
		_steps(p, 0.4, func(): p.raise_ball(false))
		if p.events.any(func(e): return String(e.k) == "foul"):
			poor += 1
		if p.man_up > 0.0:
			poor_ex += 1
	print("  poor balls (straight in beside his man): %d caught, %d fouled, %d exclusions" % [poor_n, poor, poor_ex])
	r.check(poor_n > 100 and poor > poor_n * 0.3 and poor_ex == 0, "a poor entry: the centre catches it, his man fouls him (ordinary), no exclusion")
	# a terrible ball (right into his man): never the centre's
	var bad_caught := 0
	var bad_loose := 0
	var bad_n := 0
	for sd in 200:
		var p := _settled(2200 + sd, F.PRESS, "4")
		var c := _a(p, "C")
		var g := p._center_guard(c)
		g.pos = c.pos + (p.holder.pos - c.pos).normalized() * 0.7
		g.target = g.pos
		if p.center_entry(p.holder.pos, c) != "fronted":
			continue
		bad_n += 1
		p._pass(p.lead_point(c), c)
		var t := 0.0
		while p.ball.state == Ball.State.PASS and t < 2.0:
			p.step(DT)
			t += DT
		if p.holder == c:
			bad_caught += 1
		if p.ball.state == Ball.State.LOOSE:
			bad_loose += 1
	r.check(bad_n > 150 and bad_caught == 0 and bad_loose > 0, "a terrible entry, into his man: picked off or knocked loose, never caught (%d loose of %d)" % [bad_loose, bad_n])
	# M-DROP: the dropper in the lane gets hands to entries through him; out of the lane, none
	var tips := 0
	var thrown := 0
	var tips_off := 0
	for sd in 300:
		var p := _settled(2500 + sd, F.M_DROP, "2")
		_steps(p, 2.0)
		var c := _a(p, "C")
		if p.holder == null or p.freeze > 0.0:
			p.freeze = 0.0
		if p.holder != _a(p, "2"):
			continue
		var dr := _d(p, "3")
		if dr.duty != D.DROP:
			continue
		thrown += 1
		p._pass(p.lead_point(c), c)
		var t := 0.0
		while p.ball.state == Ball.State.PASS and t < 2.0:
			p.step(DT)
			t += DT
		if p.ball.checked.has(dr) and (p.over or p.ball.state == Ball.State.LOOSE):
			tips += 1
		# the same, but the dropper shoved out of the lane first
		var q := _settled(2500 + sd, F.M_DROP, "2")
		_steps(q, 2.0)
		q.freeze = 0.0
		var qd := _d(q, "3")
		var qc := _a(q, "C")
		if q.holder != _a(q, "2"):
			continue
		qd.pos = qc.pos + Vector2(-2.0, -2.5)
		q._pass(q.lead_point(qc), qc)
		var u := 0.0
		while q.ball.state == Ball.State.PASS and u < 2.0:
			q.step(DT)
			u += DT
		if q.ball.checked.has(qd):
			tips_off += 1
	print("  entries through a set dropper: %d of %d got a hand on (%.0f pct); with him out of the lane %d" % [tips, thrown, 100.0 * tips / maxf(1.0, thrown), tips_off])
	r.check(thrown > 200 and float(tips) / thrown > 0.2 and float(tips) / thrown < 0.75, "the dropper in the lane interferes with entries, not every one")
	r.check(tips_off == 0, "...out of the lane he can't get to it")
	# Scenario F: the centre catches before the dropper's there: time to act; he shoots, it's a shot
	var shot_ok := 0
	var stolen := 0
	var held_n := 0
	var held_stolen := 0
	var held_lost := 0
	var times: Array[float] = []
	for sd in 120:
		var p := _settled(2900 + sd, F.FIVE_DROP, "2")
		_steps(p, 2.0)
		p.freeze = 0.0
		var c := _a(p, "C")
		var dr := _d(p, "5")
		if p.holder == null:
			continue
		dr.pos = c.pos + (p.holder.pos - c.pos).normalized() * 2.0 + Vector2(-0.5, 0.0)
		var on := sd % 2 == 0
		p.free_throw = false
		p._end_restart()   # (nor a restart: Play.restart)
		p.give_ball(c)
		p.entry = "open"
		p.step(DT)
		times.append(DefenseFormation.center_time(p, c))
		if on:
			p.shoot_at(Vector2(Geo.GOAL_X + 0.4, 10.9), 0.8)
			if p.ball.state == Ball.State.SHOT:
				shot_ok += 1
				_steps(p, 1.5)
				if p.over and String(p.result.outcome) == "steal" and p.result.get("by") == dr.player:
					stolen += 1
		else:
			held_n += 1
			_steps(p, 4.0, func(): p.raise_ball(false))
			if p.over and String(p.result.outcome) == "steal":
				held_lost += 1   # (his man behind him can get there first: CenterDefense's challenge)
				if p.result.get("by") == dr.player:
					held_stolen += 1
	times.sort()
	print("  Scenario F: the centre has %.2f s (median) before the dropper; shot at once %d (stolen after %d); held on: dropper's ball %d/%d" \
		% [times[times.size() / 2], shot_ok, stolen, held_stolen, held_n])
	r.check(times[0] > 0.2, "the centre catches before the dropper gets there: he has time (at least %.2f s)" % times[0])
	r.check(shot_ok > 50 and stolen == 0, "a shot released before the dropper's on him stands")
	r.check(held_n > 50 and held_lost == held_n and held_stolen >= held_n * 0.9,
		"held on until the dropper's on him: a turnover every time, the dropper's %d of %d" % [held_stolen, held_n])
	# no exclusion with a dropper there to help; with him far off (a piston swimming back), there can be
	var near_ex := 0
	var far_ex := 0
	for sd in 200:
		var p := _settled(3200 + sd, F.FOUR_FIVE, "2")
		_steps(p, 2.0)
		p.freeze = 0.0
		var c := _a(p, "C")
		var dr := p.f_dropper
		if p.holder == null or dr == null:
			continue
		var far := sd % 2 == 1
		if far:
			dr.pos = c.pos + Vector2(-4.5, -3.0)
		p._center_guard(c).pos = c.pos + Vector2(0.55, 0.0)
		if not _feed(p, c):
			continue
		_steps(p, 0.3, func(): p.raise_ball(false))
		if p.man_up > 0.0 or p.events.any(func(e): return String(e.k) == "exclusion"):
			if far:
				far_ex += 1
			else:
				near_ex += 1
	r.check(near_ex == 0 and far_ex > 0, "a dropper there: no exclusion (%d); the dropper caught out of position: there can be (%d)" % [near_ex, far_ex])

# ------------------------------------------------------------------ 9. passes and loose balls
func _passing() -> void:
	var table := [2.0, 4.0, 6.0, 8.0, 10.0].map(func(v): return snappedf(DefenseFormation.tip_chance(_lab({"dfn": v}), _lab({"pas": 5.0})), 0.0001))
	r.check(table == [0.05, 0.08, 0.11, 0.14, 0.17], "tip chance 2 pct + 1.5 x Defense - 1 x (Passing - 5): %s" % str(table))
	r.check(DefenseFormation.tip_chance(_lab({"dfn": 10.0}), _lab({"pas": 0.0})) <= DefenseFormation.TIP_RANGE.y \
		and DefenseFormation.tip_chance(_lab({"dfn": 0.0}), _lab({"pas": 10.0})) >= DefenseFormation.TIP_RANGE.x, "...clamped")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var out := [0, 0, 0]
	for i in 20000:
		out[DefenseFormation.tip_outcome(rng)] += 1
	r.check(absf(out[0] / 20000.0 - 0.75) < 0.02 and absf(out[1] / 20000.0 - 0.2) < 0.02 and absf(out[2] / 20000.0 - 0.05) < 0.01,
		"a tip that comes off: 75 pct minor, 20 major, 5 clean (%s)" % str(out))
	# Scenario G: a pass straight through a splitter; and the same pass with nobody near its line
	var hits := 0
	var tries := 0
	var off_line := 0
	var worst_jump := 0.0
	var once := true
	for sd in 1500:
		var p := _settled(4000 + sd, F.M_DROP, "2", false)   # (their defence: no YOUR_DEFENCE_STEALS edge)
		for s in p.defenders:
			s.pos = Vector2(4.0, 2.0 + float(p.defenders.find(s)))   # (everybody else well out of it)
			s.target = s.pos
		var a2 := _a(p, "2")
		var a3 := _a(p, "3")
		var sp := _d(p, "2")
		sp.player = _lab({"dfn": 5.0})
		a2.player = _lab({"pas": 5.0})
		var through := sd % 3 != 0
		var mid := a2.pos.lerp(a3.pos, 0.3)   # (a 4 m pass loops over a man in the middle of it: Play.PASS_PEAK_MAX)
		sp.pos = mid if through else mid + (a3.pos - a2.pos).orthogonal().normalized() * 2.0
		sp.target = sp.pos
		p._pass(a3.pos, a3)
		var counted := false
		var t := 0.0
		var ends := 0
		var last := p.ball.pos
		while t < 2.5 and not p.over:
			p.step(DT)
			t += DT
			if p.ball.state == Ball.State.LOOSE:
				# (on the water it drifts; the frame it comes off his hand it's put where it met him,
				# at most one frame of the pass back along its line)
				worst_jump = maxf(worst_jump, p.ball.pos.distance_to(last) - Play.PASS_SPEED * 1.3 * DT)
			last = p.ball.pos
			ends += p.events.filter(func(e): return String(e.k) == "end").size()
			p.events.clear()
			if through and p.ball.checked.has(sp) and not counted:
				counted = true
				# (it came off his hand: picked off, or knocked loose; else the pass carried on)
				if p.over or p.ball.state == Ball.State.LOOSE:
					hits += 1
		once = once and ends <= 1
		if through:
			tries += 1
		elif p.ball.checked.has(sp):
			off_line += 1
	var rate := float(hits) / maxf(1.0, tries)
	print("  Scenario G: passes through a Defense 5 splitter, Passing 5: %d/%d got a hand on (%.1f pct); 2 m off the line: %d" % [hits, tries, 100.0 * rate, off_line])
	r.check(off_line == 0, "a defender away from the pass's path never gets a go at it")
	r.check_between(rate, 0.06, 0.14, "right through him: about the 9.5 pct tip chance")
	r.check(worst_jump <= 0.05, "a deflected ball moves on the water, it doesn't jump (%.3f m)" % worst_jump)
	r.check(once, "every possession ends once (one change of possession)")
	# a deflection, staged: knocked off line, loose; both sides go for it; the first there has it
	var won := {"us": 0, "them": 0}
	var redirected := 0
	var ok_once := true
	for sd in 200:
		var p := _settled(6000 + sd, F.M_DROP, "2")
		var a3 := _a(p, "3")
		var sp := _d(p, "2")
		p._pass(a3.pos, a3)
		p.step(DT)
		p.step(DT)
		var dir := (p.ball.to - p.ball.from).normalized()
		p.ball.pos = p.ball.from.lerp(p.ball.to, 0.5)
		p._deflect(sp, sd % 2 == 0)
		if absf(rad_to_deg(p.ball.drift.angle_to(dir))) >= DefenseFormation.MINOR_TURN.x - 0.5:
			redirected += 1
		var seen_ends := 0
		var t := 0.0
		var chasers_ok := false
		while t < 6.0 and not p.over and p.ball.state == Ball.State.LOOSE:
			p.step(DT)
			t += DT
			if t > 0.1 and t < 0.2:
				chasers_ok = p.attackers.any(func(a: Swimmer): return a.target.distance_to(p.ball.pos) < 2.5) \
					and p.defenders.any(func(s: Swimmer): return s.target.distance_to(p.ball.pos) < 2.5)
		seen_ends = p.events.filter(func(e): return String(e.k) == "end").size()
		ok_once = ok_once and seen_ends <= 1 and chasers_ok
		if p.over:
			won["them"] += 1
		elif p.holder != null:
			won["us"] += 1
	print("  200 deflections: recovered by the attack %d, by the defence %d" % [won.us, won.them])
	r.check(redirected == 200, "a deflection visibly turns the ball off its line")
	r.check(ok_once, "loose: players from both sides swim for it, and it's settled once")
	r.check(won.us > 10 and won.them > 10, "whoever gets there first has it: sometimes the attack, sometimes the defence")

# ------------------------------------------------------------------ 10. the bar
func _bar() -> void:
	var teams: Array = r._teams()
	Game.match_cfg = {"us": teams[0], "them": teams[1], "seed": 77, "minutes": 2.0, "drop": F.FIVE_DROP}
	Game.goto("match", Game.match_cfg)
	await r.get_tree().process_frame
	var screen = Game.current_screen
	var flow: MatchFlow = screen.flow
	flow._start_defense(Play.Kind.HALF_COURT)
	screen._process(DT)
	var size: Vector2 = screen.get_viewport_rect().size
	screen.fbar.layout(size, Vector2.ZERO, 3.0 + Hud.tag_parts(flow.play.keeper.player).size.x + 4.0)   # (as the screen lays it out)
	var rects: Array[Rect2] = screen.fbar.rects
	r.check(rects.size() == 1 and Rect2(Vector2.ZERO, size).encloses(rects[0]) and rects[0].size.x > 96.0, "one button, CALL DROP, on screen, bigger than the old ones (%.0f px)" % rects[0].size.x)
	r.check(rects[0].end.y >= size.y - 5.0 and rects[0].size.y >= FormationBar.H_MIN, "along the bottom, big (%.0f px tall)" % rects[0].size.y)
	r.check(FormationBar.shown(flow), "shown while you defend")
	var tag_w: float = Hud.tag_parts(flow.play.keeper.player).size.x + 3.0
	r.check(rects[0].position.x > tag_w, "clear of your keeper's tag, bottom left (%.0f px vs %.0f)" % [rects[0].position.x, tag_w])
	var dh: Swimmer = flow.play.holder
	r.check(dh != null and dh != flow.play.keeper and flow.play.attackers.has(dh) and screen._tag_holder(flow.play) == dh.player
		and flow.them.roster.has(dh.player), "the bottom-left tag is their man on the ball (from their roster), not your keeper")
	var room: float = screen._tag_room
	r.check(rects[0].position.x > 3.0 + room, "CALL DROP clear of any of their tags (%.0f px)" % room)
	r.check(flow.play.formation == F.PRESS and not FormationBar.called(flow.play), "the possession starts in the normal defence, the button up")
	# a tap on CALL DROP (a real touch, the mouse's too: emulate_touch_from_mouse) calls your drop, 5 DROP
	Play.instant_drops = true
	_touch(screen, rects[0].get_center())
	r.check(flow.play.formation == F.FIVE_DROP and flow.play.formation_locked, "a tap on CALL DROP calls 5 DROP")
	_touch(screen, rects[0].get_center())
	r.check(flow.play.formation == F.FIVE_DROP and flow.play.formation_locked, "...a second tap doesn't cancel it")
	Play.instant_drops = false
	r.check(flow.keeper_anim == null, "a tap on the bar never dives your keeper")
	# their shot wound up: a tap on the bar is your dive, not a call
	var q := flow.play
	flow.opp_plan = {"target": Vector2(Geo.GOAL_X + 0.4, 10.5), "power": 0.8, "shot": true, "t": 0.3}
	r.check(flow.can_dive() and not screen.fbar.press(rects[0].get_center(), flow), "their shot coming: the bar doesn't take the tap...")
	_touch(screen, rects[0].get_center())
	r.check(flow.keeper_anim != null and q.formation == F.FIVE_DROP, "...it's your dive")
	flow.opp_plan = {}
	# your attack: no bar; their defence's formation is shown under the shot clock
	flow.play._turnover(flow.play.defenders[1], "STOLEN!", "steal")
	flow.defense_done()
	screen._process(DT)
	r.check(not FormationBar.shown(flow) and flow.play.ai_drop >= 0, "not on your attack (their defence calls its own: PRESS or its drop, shown under the shot clock)")
	Game.goto("title")
	await r.get_tree().process_frame

func _touch(screen, at: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = at
	ev.index = 0
	screen._input(ev)
	var up := InputEventScreenTouch.new()
	up.position = at
	up.index = 0
	screen._input(up)

# ------------------------------------------------------------------ 11. their attack against each formation
## Their AI attack (OffenseAI) against each of your formations, `n` possessions each: how it
## scores, where its shots come from, the passes it makes. Every formation has to leave it
## something, and it has to find what that is.
func _measure(n: int, seed0: int = 9000, shooters := false, only: Array = []) -> Array:
	var teams: Array = r._teams()
	var res := []
	for f in DefenseFormation.COUNT:
		if not only.is_empty() and not (f in only):
			res.append({"poss": 0, "goals": 0, "shots": 1})
			continue
		var m := {"poss": 0, "goals": 0, "shots": 0, "sh_C": 0, "sh_5": 0, "sh_open": 0, "entries": 0, "passes": 0,
			"piston_pass": 0, "p45": 0, "p34": 0, "excl": 0, "steals": 0, "tips": 0, "fouls": 0,
			"frames": 0, "near": 0, "set": 0}
		for i in n:
			var flow := MatchFlow.new(teams[0], teams[1], seed0 + i, MatchState.QUARTER_MIN)
			flow.auto_keeper = 0.5
			flow._start_defense(Play.Kind.HALF_COURT)
			var p := flow.play
			p.select_formation(f)
			if shooters:
				_sharpshooters(p)
			var t := 0.0
			var pair := DefenseFormation.pistons(f)
			var last_state := p.ball.state
			while not p.over and t < 60.0:
				flow.tick_defense(1.0 / 30.0)
				t += 1.0 / 30.0
				if p.ball.state == Ball.State.PASS and last_state != Ball.State.PASS and p.ball.passer != null and p.ball.receiver != null:
					m.passes += 1
					if p.ball.receiver.tag == "C":
						m.entries += 1
					if p.ball.passer.tag in pair and p.ball.receiver.tag in pair:
						m.piston_pass += 1
					var two := [p.ball.passer.tag, p.ball.receiver.tag]
					if "4" in two and "5" in two:
						m.p45 += 1
					if "3" in two and "4" in two:
						m.p34 += 1
				last_state = p.ball.state
				if DefenseFormation.active(p) and DefenseFormation.drops(f):
					m.frames += 1
					var cc := _a(p, "C")
					if DefenseFormation.dropper_near(p, cc):
						m.near += 1
					if DefenseFormation.dropper_set(p, cc):
						m.set += 1
				for e in flow.events:
					match String(e.k):
						"shot":
							m.shots += 1
							for a in p.attackers:
								if a.player == e.by:
									if a.tag == "C":
										m.sh_C += 1
									if a.tag == "5":
										m.sh_5 += 1
									if DefenseFormation.left_open(p, a):
										m.sh_open += 1
						"exclusion":
							m.excl += 1
						"tip":
							m.tips += 1
						"foul":
							m.fouls += 1
				flow.events.clear()
			m.poss += 1
			var o := String(p.result.get("outcome", ""))
			if o == "goal":
				m.goals += 1
			if o == "steal":
				m.steals += 1
		res.append(m)
	return res

## Their attack made of outside shooters (A2, A3, A4 Shooting 9.5), and an ordinary centre.
func _sharpshooters(p: Play) -> void:
	for t in ["2", "3", "4"]:
		var a := _a(p, t)
		a.player = _lab({"sho": 9.5, "pas": 7.0, "str": 5.0, "dfn": 4.0})
	_a(p, "C").player = _lab({"sho": 4.0, "str": 4.0, "pas": 5.0, "dfn": 4.0}, PoloPlayer.Pos.CENTER)

func _report(res: Array) -> void:
	for f in res.size():
		var m: Dictionary = res[f]
		var poss := maxf(1.0, m.poss)
		var shots := maxf(1.0, m.shots)
		print("  %-9s goals/poss %.2f  shots/poss %.2f  centre %2.0f%%  A5 %2.0f%%  left-open %2.0f%%  entries/poss %.2f  piston passes/poss %.2f  excl/poss %.2f  steals %.2f  tips %.2f  fouls %.2f  dropper near %2.0f%% set %2.0f%%" \
			% [DefenseFormation.NAMES[f], m.goals / poss, m.shots / poss, 100.0 * m.sh_C / shots, 100.0 * m.sh_5 / shots,
			100.0 * m.sh_open / shots, m.entries / poss, m.piston_pass / poss, m.excl / poss, m.steals / poss, m.tips / poss, m.fouls / poss,
			100.0 * m.near / maxf(1.0, m.frames), 100.0 * m.set / maxf(1.0, m.frames)])

func _counterplay(n: int) -> void:
	var res := _measure(n)
	_report(res)
	var g := func(f: int, k: String) -> float: return float(res[f][k]) / maxf(1.0, float(res[f].poss))
	var sh := func(f: int, k: String) -> float: return float(res[f][k]) / maxf(1.0, float(res[f].shots))
	r.check(sh.call(F.FIVE_DROP, "sh_5") > sh.call(F.PRESS, "sh_5") * 1.2, "against 5 DROP their A5 shoots more (%.0f vs %.0f pct of shots)" % [100.0 * sh.call(F.FIVE_DROP, "sh_5"), 100.0 * sh.call(F.PRESS, "sh_5")])
	r.check(g.call(F.M_DROP, "entries") < g.call(F.PRESS, "entries") * 0.75 and sh.call(F.M_DROP, "sh_C") < sh.call(F.PRESS, "sh_C"),
		"against M-DROP they feed the centre less and shoot from outside instead")
	for f in [F.FOUR_FIVE, F.THREE_FOUR]:
		var pair := DefenseFormation.pistons(f)
		var k := "p" + "".join(pair)
		r.check(g.call(f, k) > g.call(F.PRESS, k) * 1.15,
			"against %s they move it A%s-A%s more (%.2f a possession, against PRESS %.2f)" % [DefenseFormation.NAMES[f], pair[0], pair[1], g.call(f, k), g.call(F.PRESS, k)])
	r.check(sh.call(F.FIVE_DROP, "sh_open") > sh.call(F.PRESS, "sh_open"), "they find the man a help leaves open")
	# nobody's the answer to everything, and every one of them leaves something
	var goals: Array = range(DefenseFormation.COUNT).map(func(f): return g.call(f, "goals"))
	r.check(goals.max() - goals.min() < 0.2, "no formation is a lock: their goals a possession %s" % str(goals.map(func(x): return snappedf(x, 0.01))))
	r.check(goals.min() > 0.2, "...they still score against all of them")
	r.check(sh.call(F.PRESS, "sh_C") > sh.call(F.M_DROP, "sh_C") and sh.call(F.PRESS, "sh_C") > sh.call(F.FIVE_DROP, "sh_C"),
		"PRESS leaves the centre alone with his man: more of their shots from there than against a drop")

## The balance mode: their attack against each of your formations, `n` possessions each, and your
## attack (the bot) against each of theirs.
static func balance(runner, n: int) -> void:
	var t: RefCounted = load("res://tests/formation_test.gd").new()
	t.r = runner
	print("their attack (OffenseAI) against each of your formations, %d possessions each" % n)
	t._report(t._measure(n, 12000))
	print("...an attack of outside shooters (A2-A4 Shooting 9.5) and a poor centre")
	t._report(t._measure(n, 12000, true))

## (Developer: one formation's possessions traced, a line every time the ball changes hands.)
static func trace(runner, f: int, n: int) -> void:
	var teams: Array = runner._teams()
	for i in n:
		var flow := MatchFlow.new(teams[0], teams[1], 12000 + i, MatchState.QUARTER_MIN)
		flow.auto_keeper = 0.5
		flow._start_defense(Play.Kind.HALF_COURT)
		var p := flow.play
		p.select_formation(f)
		var t := 0.0
		var last := ""
		print("-- possession %d" % i)
		while not p.over and t < 40.0:
			flow.tick_defense(1.0 / 30.0)
			t += 1.0 / 30.0
			for e in flow.events:
				if String(e.k) == "shot":
					var sh: Swimmer = null
					for x in p.attackers:
						if x.player == e.by:
							sh = x
					print("    SHOT by %s from %.1f m (%.1f, %.1f), nearest D %.1f m, why %s q %.2f" % [sh.tag, Geo.range_to_goal(sh.pos), sh.pos.x, sh.pos.y, p.openness(sh), flow.opp_ai.why, flow.opp_ai.why_q])
				elif String(e.k) in ["tip", "foul", "exclusion", "drive_ball"]:
					print("    %s" % String(e.k))
			flow.events.clear()
			var c := DefenseFormation.by_tag(p.attackers, "C")
			var dr := p.f_dropper
			var who: String = str(Ball.State.keys()[p.ball.state])
			if p.holder != null:
				who = p.holder.tag
			elif p.ball.state == Ball.State.PASS and p.ball.receiver != null:
				who = "pass>" + p.ball.receiver.tag
			var line := "%s in=%s" % [who, ("D" + dr.dtag) if dr != null else "-"]
			if line != last and p.holder != null and p.attackers.has(p.holder) and not line.begins_with(last.get_slice(" ", 0) + " "):
				var nd: Swimmer = p._nearest_defender(p.holder.pos)
				print("    caught by %s at %.1f m: nearest D%s %.1f m (%s), left open %s" % [p.holder.tag, Geo.range_to_goal(p.holder.pos), nd.dtag,
					p.openness(p.holder), DefenseFormation.DUTY_NAMES[nd.duty], DefenseFormation.left_open(p, p.holder)])
			if line != last:
				last = line
				print("  %5.2f %-10s dropper %s %s %.1f m off C, active %s, covered %s" % [t, who, ("D" + dr.dtag) if dr != null else "-",
					DefenseFormation.DUTY_NAMES[dr.duty] if dr != null else "", dr.pos.distance_to(c.pos) if dr != null else 0.0,
					DefenseFormation.active(p), DefenseFormation.entry_covered(p, c)])
		print("  => %s" % str(p.result.get("outcome", "")))

## Screenshots (needs a window): the bar on their attack, unpicked and picked, each formation set
## up in the pool, your attack with their call shown, at 16:9 and a wide phone.
##   godot --path game -- --test formation_png <dir>
static func shots(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	for shape in [[Vector2i(1440, 810), "169"], [Vector2i(1752, 810), "phone"]]:
		DisplayServer.window_set_size(shape[0])
		await tree.create_timer(0.3).timeout
		var teams: Array = runner._teams()
		Game.match_cfg = {"us": teams[0], "them": teams[1], "seed": 31, "minutes": 3.0}
		Game.goto("match", Game.match_cfg)
		await tree.create_timer(0.3).timeout
		var ms = Game.current_screen
		for f in [-1] + range(DefenseFormation.COUNT):
			ms.flow._start_defense(Play.Kind.HALF_COURT)
			ms.flow.auto_keeper = 0.5
			var p: Play = ms.flow.play
			p.drive_timer = 99.0
			if f >= 0:
				ms.flow.select_formation(f)
			# a few seconds of their set attack, frozen before anybody shoots
			for i in 150:
				if p.over or not ms.flow.opp_plan.is_empty() and bool(ms.flow.opp_plan.get("shot", false)):
					break
				ms._process(1.0 / 60.0)
			ms.paused = true
			await tree.process_frame
			await tree.process_frame
			var name := "unpicked" if f < 0 else String(DefenseFormation.NAMES[f]).to_lower().replace(" ", "").replace("-", "")
			runner.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [shape[1], name]))
			ms.paused = false
		ms.flow._start_attack(Play.Kind.HALF_COURT)
		for i in 30:
			ms._process(1.0 / 60.0)
		ms.paused = true
		await tree.process_frame
		await tree.process_frame
		runner.get_viewport().get_texture().get_image().save_png(out.path_join("%s_your_attack.png" % shape[1]))
		ms.paused = false
	Game.goto("title")
