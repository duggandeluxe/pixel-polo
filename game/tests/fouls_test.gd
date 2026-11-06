extends RefCounted
## THE FOULS & GAMEPLAY MECHANICS UPDATE: wing pressure against PRESS and M-DROP, the keeper's
## dive at any shot, the shot clock stopped from the whistle to the free throw's release (and
## its taker protected), and a pass owed after a foul inside 6 m. The numbered checks follow the
## spec's REQUIRED TESTING list.
##   godot --headless --path game -- --test fouls

const DT := 1.0 / 30.0

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("fouls & gameplay mechanics")
	_wings()
	_keeper()
	_clock()
	_six_meter()
	_penalty()

func _play(seed_value: int, formation: int = DefenseFormation.F.PRESS) -> Play:
	var teams: Array = r._teams()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var p := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, rng)
	p.formation = formation
	return p

func _a(p: Play, tag: String) -> Swimmer:
	for s in p.attackers:
		if s.tag == tag:
			return s
	return null

func _own(p: Play, a: Swimmer) -> Swimmer:
	for d in p.defenders:
		if d.mark == a:
			return d
	return p.defenders[0]

func _count(p: Play, k: String) -> int:
	return p.events.filter(func(e): return String(e.get("k", "")) == k).size()

## A wing holds the ball for `secs`: fouls, exclusions and penalties seen, over `n` possessions.
func _wing_trial(formation: int, boost: bool, n: int, secs: float = 4.0) -> Dictionary:
	DefenseFormation.wing_boost = boost
	var out := {"foul": 0, "exclusion": 0, "penalty": 0, "possessions": n}
	for i in n:
		var p := _play(4000 + i, formation)
		var w := _a(p, "1" if i % 2 == 0 else "5")
		p.give_ball(w)
		p.catch_t = 0.0
		var t := 0.0
		while t < secs and not p.over:
			p.step(DT)
			t += DT
			if _count(p, "foul") > 0:
				break
		for k in ["foul", "exclusion", "penalty"]:
			out[k] += 1 if _count(p, k) > 0 else 0
	DefenseFormation.wing_boost = true
	return out

# ------------------------------------------------------------------ T33, T34
func _wings() -> void:
	var n := 40
	for f in [DefenseFormation.F.PRESS, DefenseFormation.F.M_DROP]:
		var name: String = "PRESS" if f == DefenseFormation.F.PRESS else "M-DROP"
		var before := _wing_trial(f, false, n)
		var after := _wing_trial(f, true, n)
		var short0 := _wing_trial(f, false, n, 2.0)
		var short1 := _wing_trial(f, true, n, 2.0)
		print("    %s wing holding 4 s: fouls %d -> %d of %d (2 s: %d -> %d), exclusions %d -> %d, penalties %d -> %d" % [name, before.foul, after.foul, n, short0.foul, short1.foul, before.exclusion, after.exclusion, before.penalty, after.penalty])
		r.check(int(short1.foul) < n * 0.6, "T2: not every wing possession: a quick wing still plays (%d of %d fouled in 2 s)" % [short1.foul, n])
		r.check(int(after.foul) < n * 0.9, "T2: not every possession even held 4 s (%d of %d)" % [after.foul, n])
		r.check(int(after.foul) > int(before.foul) * 1.3 and int(after.foul) >= n / 4, "T%d: a closely guarded wing is fouled more against %s (%d -> %d of %d)" % [33 if f == DefenseFormation.F.PRESS else 34, name, before.foul, after.foul, n])
		r.check(int(after.exclusion) <= int(before.exclusion) + 2 and int(after.penalty) <= int(before.penalty) + 2, "T5: ...ordinary fouls: no more exclusions or penalties (%s)" % name)
	# other formations and the point aren't touched
	var p := _play(77, DefenseFormation.F.FIVE_DROP)
	r.check(not DefenseFormation.wing_pressure(p, _a(p, "1")), "T28: 5 DROP's wings play as before")
	var q := _play(78, DefenseFormation.F.PRESS)
	r.check(DefenseFormation.wing_pressure(q, _a(q, "5")) and not DefenseFormation.wing_pressure(q, _a(q, "3")) and not DefenseFormation.wing_pressure(q, _a(q, "C")), "T2: only the wings")
	# a wing with room plays on: no contact, no foul, however long
	var o := _play(79, DefenseFormation.F.PRESS)
	var w := _a(o, "1")
	o.give_ball(w)
	var d := _own(o, w)
	d.pos = w.pos + (w.pos - Geo.goal_center()).normalized() * -2.5
	var fouled := false
	for i in 120:
		o._pressure(DT)
		fouled = fouled or _count(o, "foul") > 0
	r.check(DefenseFormation.contact_defender(o, w) == null and not fouled, "T33: a wing with separation is never whistled")
	# M-DROP: the dropper stays on the centre while the wing is pressed
	var m := _play(80, DefenseFormation.F.M_DROP)
	m.give_ball(_a(m, "5"))
	for i in 90:
		m.step(DT)
	var c := _a(m, "C")
	r.check(m.f_dropper != null and m.f_dropper.pos.distance_to(c.pos) < 3.0, "T34: the M-DROP dropper is still on the centre (%.1f m)" % (m.f_dropper.pos.distance_to(c.pos) if m.f_dropper != null else -1.0))
	# the same rule for both sides
	var mine := _play(81, DefenseFormation.F.PRESS)
	mine.defending = true
	r.check(DefenseFormation.wing_pressure(mine, _a(mine, "1")), "T43: the wing pressure applies when you defend too")

# ------------------------------------------------------------------ T35, T36
func _keeper() -> void:
	var p := _play(90)
	p.defending = true
	p.remote_keeper = true
	var s := _a(p, "3")
	p.give_ball(s)
	s.pos = Vector2(22.0, Geo.GOAL_Y)
	var miss := {"outcome": "miss", "cross_y": Geo.GOAL_Y + Geo.GOAL_HALF + 0.6, "speed": 14.0, "end": Vector2(31.3, Geo.GOAL_Y + 2.0), "flight": 0.65}
	p._pend_for_keeper(s, miss)
	r.check(String(miss.outcome) == "pending" and String(miss.auto) == "miss" and miss.has("line_flight"), "T36: a shot going wide still waits for your keeper's dive")
	var post := {"outcome": "post", "cross_y": Geo.GOAL_Y + Geo.GOAL_HALF, "speed": 14.0, "end": Vector2(30, Geo.GOAL_Y), "flight": 0.6}
	var p2 := _play(91)
	p2.remote_keeper = true
	p2._pend_for_keeper(_a(p2, "3"), post)
	r.check(String(post.outcome) == "pending" and String(post.auto) == "post", "T35: so does one at the post")
	# whatever the dive says, the miss stands (no ball to touch): no automatic save
	p.give_ball(s)
	p._launch(s, miss, 0.7)
	p.set_verdict("save", p.shot_n)
	r.check(p.verdict == "miss", "T10: the dive can't turn a miss into a save (%s)" % p.verdict)
	var ev: Array = p.events.filter(func(e): return String(e.get("k", "")) == "duel")
	r.check(not ev.is_empty() and not bool(ev.back().get("on_target", true)), "T35: your duel opens, marked off target")
	# the duel itself: dive all you like, it's wide or the post
	var gk: PoloPlayer = (r._teams()[0] as PoloTeam).keeper()
	var duel := KeeperDuel.new().setup_given(gk, Vector2(22, Geo.GOAL_Y), Geo.GOAL_Y + Geo.GOAL_HALF + 0.05, 0.5, Geo.GOAL_X, Geo.GOAL_Y, 0.5, 0.5, false)
	duel.dive(KeeperDive.RIGHT)
	for i in 60:
		duel.step(DT)
	r.check(duel.done() and duel.outcome in ["post", "wide"], "T35: off target, the duel ends at the post or wide (%s)" % duel.outcome)
	# the AI keeper dives at a wide shot too, and it stays wide
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var res := ShotModel.resolve(Vector2(23, Geo.GOAL_Y), Geo.GOAL_Y + Geo.GOAL_HALF + 0.7, 0.8, 70.0, 5.0, [], Geo.GOAL_Y, 60.0, rng, false, {}, {})
	r.check(String(res.outcome) == "miss" and res.has("dive"), "T12: their keeper goes for a wide one too, and it's still wide")

# ------------------------------------------------------------------ T37, T38, T39
func _clock() -> void:
	var p := _play(100)
	var s := _a(p, "3")
	p.give_ball(s)
	s.pos = Vector2(20.0, Geo.GOAL_Y)
	p.start_shot_clock(15.0)
	var d := _own(p, s)
	p._ordinary_foul(s, d)
	r.check(p.restart and not p.pass_first, "T37: an ordinary foul outside 6 m: a restart, a direct shot allowed")
	for i in 90:   # the whistle's freeze and two more seconds
		p.step(DT)
	r.check(is_equal_approx(p.shot_clock, 15.0) and p.restart, "T37: the shot clock stays at 15 while he gets ready (%.2f)" % p.shot_clock)
	# a defender right on him all the while: no second whistle
	var fouls := _count(p, "foul")
	d.back_off = 0.0
	for i in 60:
		d.pos = s.pos + (Geo.goal_center() - s.pos).normalized() * 0.5
		p.step(DT)
	r.check(_count(p, "foul") == fouls and _count(p, "exclusion") == 0 and not p.over, "T39: no foul loop while he takes it")
	var mate := _a(p, "2")
	p._pass(mate.pos, mate)
	r.check(not p.restart, "T37: the pass is released: the restart's over")
	var c0 := p.shot_clock
	for i in 30:
		p.step(DT)
	r.check(p.shot_clock < c0 - 0.5, "T37: and the clock runs again from where it stopped (%.2f -> %.2f)" % [c0, p.shot_clock])
	# an exclusion: its reset to 20 s stands, frozen until the restart pass
	var e := _play(101)
	var h := _a(e, "2")
	e.give_ball(h)
	h.pos = Vector2(21.0, Geo.GOAL_Y - 3.0)
	e.start_shot_clock(9.0)
	e._exclusion(_own(e, h), h)
	for i in 80:
		e.step(DT)
	r.check(e.restart and is_equal_approx(e.shot_clock, 20.0), "T38: an exclusion: reset to 20 s and held there (%.2f)" % e.shot_clock)
	var to := _a(e, "4")
	e._pass(to.pos, to)
	for i in 30:
		e.step(DT)
	r.check(not e.restart and e.shot_clock < 20.0, "T38: the restart pass, then it runs")
	# a held free throw can't stall the clock for ever
	var z := _play(102)
	var zh := _a(z, "3")
	z.give_ball(zh)
	zh.pos = Vector2(20.0, Geo.GOAL_Y)
	z._ordinary_foul(zh, _own(z, zh))
	for i in int((Play.RESTART_DELAY + 1.5) * 30.0):
		z.step(DT)
	r.check(not z.restart, "T18: held past %.0f s, the restart lapses and the clock runs" % Play.RESTART_DELAY)

# ------------------------------------------------------------------ T40, T41
func _six_meter() -> void:
	var p := _play(110)
	var s := _a(p, "3")
	p.give_ball(s)
	p.carry = true   # a counterattack
	s.pos = Vector2(24.6, Geo.GOAL_Y + 0.5)   # inside 6 m (outside the goalie box: no penalty question)
	var sd := _own(p, s)
	sd.pos = s.pos + (Geo.goal_center() - s.pos).normalized() * 0.6   # in front of him: an ordinary foul
	p._ordinary_foul(s, sd)
	r.check(p.pass_first and p.shot_barred(), "T40/T41: fouled inside 6 m on the break: a pass first")
	for i in 30:
		p.step(DT)
	s.pos = Vector2(22.5, Geo.GOAL_Y)   # swims back out past 6 m
	r.check(p.shot_barred(), "T22: swimming somewhere else doesn't clear it")
	var info := p.aim_info(Geo.goal_center())
	r.check(String(info.mode) == "no_shot" and p.shoot_at(Geo.goal_center(), 0.8) == "no_shot" and p.throw(Geo.goal_center(), 0.8) != "shot",
		"T41: the shooting stick (and any throw at goal) gets no shot")
	r.check(p.ball.state == Ball.State.HELD and p.holder == s, "T41: he still has it")
	var ai := OffenseAI.new()
	r.check(not ai._can_shoot(p), "T40: the CPU can't shoot either")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var guard := 0
	while p.restart_t < OffenseAI.RESTART_MOVE and guard < 200:
		guard += 1
		p.step(DT)
	s.pos = Vector2(22.5, Geo.GOAL_Y)
	# (he thinks again and again in a match; a look can be "sit on it", never a shot)
	var plans: Array = []
	for k in 12:
		var plan := ai.think(p, rng, false, 20.0)
		if not plan.is_empty():
			plans.append(String(p.aim_info(plan.target).mode))
	r.check(not plans.is_empty() and not "shot" in plans and "pass" in plans, "T40/T24: the CPU passes, never tries the barred shot (%s)" % str(plans))
	var mate := _a(p, "2")
	p._pass(mate.pos, mate)
	r.check(not p.pass_first and not p.restart, "T40/T41: the pass clears it")
	p.give_ball(mate)
	mate.pos = Vector2(26.0, Geo.GOAL_Y - 0.5)
	r.check(not p.shot_barred() and String(p.aim_info(Geo.goal_center()).mode) == "shot", "T41: then shooting is back")
	# a foul outside 6 m: a direct shot is legal
	var q := _play(111)
	var qs := _a(q, "3")
	q.give_ball(qs)
	qs.pos = Vector2(21.0, Geo.GOAL_Y)
	q._ordinary_foul(qs, _own(q, qs))
	r.check(not q.shot_barred(), "T26: fouled outside 6 m, he may shoot straight away")
	# both sides: the same rule when the CPU attacks you
	var m := _play(112)
	m.defending = true
	var ms := _a(m, "3")
	m.give_ball(ms)
	ms.pos = Vector2(24.5, Geo.GOAL_Y)
	var md := _own(m, ms)
	md.pos = ms.pos + (Geo.goal_center() - ms.pos).normalized() * 0.6
	m._ordinary_foul(ms, md)
	r.check(m.shot_barred() and m.restart, "T43: the same when they attack")

# ------------------------------------------------------------------ T42
func _penalty() -> void:
	var teams: Array = r._teams()
	var rng := RandomNumberGenerator.new()
	rng.seed = 120
	var p := Play.new(teams[0], teams[1], Play.Kind.PENALTY, rng)
	p.pass_first = true   # (even with a stale flag, a penalty is never barred)
	r.check(not p.shot_barred(), "T42: a penalty shot is never barred")
