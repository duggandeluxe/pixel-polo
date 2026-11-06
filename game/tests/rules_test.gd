extends RefCounted
## The centre entry, the exclusion the fed centre draws before he shoots (never on or after a
## shot), penalties on the shot, and the counter's carrier swimming it in. Staged plays, then big samples for the rates.
##   godot --headless --path game -- --test rules

const DT := 1.0 / 60.0

var r   # the test runner (check, check_between)

func run(runner) -> void:
	r = runner
	_entry()
	_center_shot()
	_penalties()
	_counter()
	_transition()
	_keeper_out()

# ------------------------------------------------------------------ helpers
## A set half court (test_runner._center_play), the centre's man on him at `g_off` from him and
## holding side `side` (0: behind him, on his way round, so he stays there a moment), the ball
## with `from_tag`. Nobody else is in the way.
func _setup(seed_value: int, defending: bool, from_tag: String, g_off: Vector2, side: int) -> Play:
	var p: Play = r._center_play(seed_value, defending)
	var c := PlaySetup._by_tag(p, "C")
	for a in p.attackers:
		a.player.trait_id = ""
	for d in p.defenders:
		d.player.trait_id = ""
	var g := p._center_guard(c)
	g.cside = side if side != 0 else 1
	g.cswitch = PlayAI.CENTER_SWITCH if side == 0 else 0.0
	g.pos = c.pos + g_off
	g.target = g.pos
	p.give_ball(PlaySetup._by_tag(p, from_tag))
	return p

## Feeds the centre and plays the pass out. "steal", "catch", or what else became of it.
func _feed(p: Play) -> String:
	var c := PlaySetup._by_tag(p, "C")
	p._pass(p.lead_point(c), c)
	var t := 0.0
	while p.ball.state == Ball.State.PASS and t < 2.0:
		p.step(DT)
		t += DT
	if p.over:
		return String(p.result.outcome)
	return "catch" if p.holder == c else "other"

## Steps until the shot in the air is decided (or 3 s).
func _fly(p: Play) -> void:
	var t := 0.0
	while p.ball.state == Ball.State.SHOT and not p.over and t < 3.0:
		p.step(DT)
		t += DT

func _count(p: Play, k: String) -> int:
	return p.events.filter(func(e): return String(e.k) == k).size()

const BESIDE_TOP := Vector2(-PlayAI.CENTER_UP, -PlayAI.CENTER_SIDE)   # holding the top side (-1)
const BEHIND := Vector2(0.55, 0.0)                                   # goal side of him

# ------------------------------------------------------------------ 1. the centre entry
func _entry() -> void:
	print("rules: the centre entry")
	for defending in [false, true]:
		var who := "theirs" if defending else "yours"
		# between the ball and the centre, in the lane: every pass is his, from wherever he's in it
		var stolen := 0
		var n := 0
		for sd in 120:
			var from_tag: String = ["4", "5", "3", "2", "1"][sd % 5]
			var p := _setup(3000 + sd, defending, from_tag, BEHIND, 0)
			var c := PlaySetup._by_tag(p, "C")
			var g := p._center_guard(c)
			# put him right in the lane, 0.7 m out from the centre towards the ball
			g.pos = c.pos + (p.holder.pos - c.pos).normalized() * 0.7
			g.target = g.pos
			if p.center_entry(p.holder.pos, c) != "fronted":
				continue
			n += 1
			var got := _feed(p)
			if got == "steal" or (got == "other" and p.ball.state == Ball.State.LOOSE):
				stolen += 1   # (his hands on it: picked off, or knocked loose: DefenseFormation.FRONT_LOOSE)
		r.check(n == 120 and stolen == n, "%s: his man in the passing lane, between the ball and the centre: never the centre's (%d/%d)" % [who, stolen, n])
		# behind the centre (goal side): the centre has inside position, the entry goes in
		var caught := 0
		n = 0
		for sd in 120:
			var p := _setup(3200 + sd, defending, ["4", "5", "3", "2", "1"][sd % 5], BEHIND, 0)
			var c := PlaySetup._by_tag(p, "C")
			if p.center_entry(p.holder.pos, c) == "fronted":
				continue
			n += 1
			if _feed(p) == "catch" and p.center_fed == c:
				caught += 1
		r.check(n == 120 and caught == n, "%s: his man behind the centre: the entry is caught every time (%d/%d)" % [who, caught, n])
		# beside him, not in the lane: no automatic steal. Near the centre isn't enough.
		var p2 := _setup(3400, defending, "2", BESIDE_TOP, -1)
		var c2 := PlaySetup._by_tag(p2, "C")
		var g2 := p2._center_guard(c2)
		r.check(g2.pos.distance_to(c2.pos) < 0.8 and p2.center_entry(p2.holder.pos, c2) != "fronted",
			"%s: his man right next to the centre but off the lane (the other side): not fronted" % who)
		var picked := 0
		for sd in 120:
			var p := _setup(3500 + sd, defending, "2", BESIDE_TOP, -1)
			if _feed(p) == "steal":
				picked += 1
		r.check(picked == 0, "%s: ...so the pass from there is never picked off by him (%d/120)" % [who, picked])
		# the swing: from his side it's his; round to the other side, it goes in
		var p3 := _setup(3600, defending, "4", BESIDE_TOP, -1)
		var c3 := PlaySetup._by_tag(p3, "C")
		var top := PlaySetup._by_tag(p3, "4")
		var bottom := PlaySetup._by_tag(p3, "2")
		r.check(p3.center_entry(top.pos, c3) == "fronted" and p3.center_entry(bottom.pos, c3) == "open",
			"%s: his man holding the top: the entry from the top is shut, swung to the bottom it's open" % who)
		var swung := 0
		var shut := 0
		for sd in 60:
			var pa := _setup(3700 + sd, defending, "4", BESIDE_TOP, -1)
			var got := _feed(pa)
			if got == "steal" or (got == "other" and pa.ball.state == Ball.State.LOOSE):
				shut += 1
			var pb := _setup(3700 + sd, defending, "2", BESIDE_TOP, -1)
			if _feed(pb) == "catch":
				swung += 1
		r.check(shut == 60 and swung == 60, "%s: ...fed from the top, his %d/60; swung round first, in %d/60" % [who, shut, swung])
		# off to one side of the lane, a metre off it: no automatic pick, nor from a man further out
		var p4 := _setup(3800, defending, "3", BEHIND, 0)
		var c4 := PlaySetup._by_tag(p4, "C")
		var g4 := p4._center_guard(c4)
		g4.pos = c4.pos + Vector2(-1.0, 1.0)
		r.check(not Play.in_entry_lane(g4, p4.holder.pos, c4.pos) and p4.center_entry(p4.holder.pos, c4) != "fronted",
			"%s: a metre off the line from the point: not in the lane" % who)
	# the line itself: on it, on the ball side, he's in it; past the centre (behind him) he isn't
	var probe := Swimmer.new(League.make_team(0, 0).starters()[1], Swimmer.Side.THEM)
	var from := Vector2(24.5, 5.7)
	var to := Vector2(28.0, 10.0)
	probe.pos = to.lerp(from, 0.2)
	var on_line := Play.in_entry_lane(probe, from, to)
	probe.pos = to + (to - from).normalized() * 0.5
	var past := Play.in_entry_lane(probe, from, to)
	probe.pos = to.lerp(from, 0.2) + (to - from).orthogonal().normalized() * (Play.ENTRY_LANE_R + 0.2)
	var wide := Play.in_entry_lane(probe, from, to)
	r.check(on_line and not past and not wide, "in the lane: on the line ball side (yes), behind the centre (no), %.1f m off it (no)" % (Play.ENTRY_LANE_R + 0.2))

# ------------------------------------------------------------------ 2. the fed centre's exclusion
## Holds the ball down for `secs` (or until the play stops).
func _hold(p: Play, secs: float) -> void:
	_steps(p, secs, func(): p.raise_ball(false))

func _center_shot() -> void:
	print("rules: the fed centre's exclusion comes before the shot, never after it")
	# held, ball down: his beaten man is whistled CENTER_FOUL_T after the catch, CENTER_EXCL of the time
	var held := 0
	var drawn := 0
	var early := 0
	var drawn_ok := true
	for sd in 2000:
		var p := _setup(5000 + sd, sd % 2 == 1, ["2", "1"][sd % 2], BEHIND, 0)
		var c := PlaySetup._by_tag(p, "C")
		if _feed(p) != "catch" or p.center_fed != c:
			continue
		var g := p._center_guard(c)
		_hold(p, Play.CENTER_FOUL_T - 0.1)
		if p.man_up > 0.0 or _count(p, "exclusion") > 0:
			early += 1
			continue
		_hold(p, 0.3)
		if p.over or _count(p, "foul") > 0:
			continue
		held += 1
		if _count(p, "exclusion") > 0:
			drawn += 1
			drawn_ok = drawn_ok and _count(p, "shot") == 0 and p.man_up > 0.0 and g.out and p.excluded == g \
				and p.holder == c and p.shot_clock >= 20.0
	var rate := float(drawn) / maxf(1.0, held)
	print("  %d fed centres held it: exclusion drawn %d (%.1f%%), whistled too soon %d" % [held, drawn, 100.0 * rate, early])
	r.check(held > 1500, "the fed centre holds it (%d)" % held)
	r.check(early == 0, "no whistle in the first %.1f s after the catch (%d)" % [Play.CENTER_FOUL_T, early])
	r.check_between(rate, 0.77, 0.83, "fed centre holding it: exclusion rate")
	r.check(drawn_ok, "...before any shot: his man's out, his team has it 6 on 5, 20 s on the clock")
	# he shoots straight away (before the whistle): the shot is just a shot, whatever it does
	var shots := 0
	var outcomes := {}
	var excl_after := 0
	for sd in 2000:
		var p := _setup(15000 + sd, sd % 2 == 1, ["2", "1"][sd % 2], BEHIND, 0)
		var c := PlaySetup._by_tag(p, "C")
		if _feed(p) != "catch" or p.center_fed != c:
			continue
		# the far post, straight at the keeper, or just wide: so all the outcomes come up
		var aim_y: float = [Geo.GOAL_Y + (1.1 if p.keeper.pos.y < Geo.GOAL_Y else -1.1), p.keeper.pos.y, Geo.GOAL_Y + 1.95][sd % 3]
		p.shoot_at(Vector2(Geo.GOAL_X + 0.4, aim_y), 0.8)
		if p.ball.state != Ball.State.SHOT:
			continue
		shots += 1
		_fly(p)
		_hold(p, 1.0)   # (whatever comes of it: a rebound, the keeper's ball)
		var o := String(p.result.get("outcome", "")) if p.over else "live"
		outcomes[o] = int(outcomes.get(o, 0)) + 1
		if _count(p, "exclusion") > 0 or p.man_up > 0.0:
			excl_after += 1
	print("  %d fed centres shot at once: %s, an exclusion after it %d" % [shots, str(outcomes), excl_after])
	r.check(shots > 1500, "the fed centre gets his shot away before the whistle (%d)" % shots)
	r.check(excl_after == 0, "nothing on or after a shot is an exclusion: no 6 on 5 off a shot")
	r.check(outcomes.get("goal", 0) > 0 and outcomes.get("save", 0) > 0 and outcomes.get("miss", 0) > 0,
		"...it's a goal, the keeper's ball, or a miss, as normal")
	# going up before the whistle: no exclusion (a foul as he shoots is never one), and he shoots
	var up_excl := 0
	var up := 0
	for sd in 300:
		var p := _setup(17000 + sd, sd % 2 == 1, "2", BEHIND, 0)
		var c := PlaySetup._by_tag(p, "C")
		if _feed(p) != "catch" or p.center_fed != c:
			continue
		up += 1
		_steps(p, 1.0, func(): p.raise_ball(true))
		if _count(p, "exclusion") > 0:
			up_excl += 1
	r.check(up > 200 and up_excl == 0, "up to shoot before the whistle: no exclusion (%d of %d)" % [up_excl, up])
	# only a real entry: a centre who didn't catch an entry, a perimeter man, a power play
	var none := 0
	for sd in 300:
		var p := _setup(7000 + sd, false, "2", BEHIND, 0)
		var c := PlaySetup._by_tag(p, "C")
		match sd % 3:
			0:
				p.give_ball(c)   # (handed it, not fed it)
			1:
				p.give_ball(PlaySetup._by_tag(p, "2"))
				p.holder.pos = Vector2(26.0, 13.0)
			2:
				_feed(p)
				if p.holder == c:
					p._exclusion(p.defenders[4], null)
					p.freeze = 0.0
		if p.holder == null or p.over:
			continue
		p.events.clear()
		_hold(p, 1.0)
		if _count(p, "exclusion") > 0:
			none += 1
	r.check(none == 0, "no centre exclusion without a real entry: handed the ball, a perimeter man, a power play (%d)" % none)

# ------------------------------------------------------------------ 3. penalties
## The man with the ball at `at`, his man (defender 0) at `d_at`, everybody else out of it.
func _pen_play(at: Vector2, d_at: Vector2, seed_value: int, defending := false) -> Play:
	var p: Play = r._staged(at, d_at, seed_value, defending)
	r._mark_holder(p, p.defenders[0])
	return p

## {penalty, exclusion, shot} counts over `n` shots from `at` with his man at `d_at`.
func _pen_rate(at: Vector2, d_at: Vector2, n: int, seed0: int) -> Dictionary:
	var out := {"penalty": 0, "exclusion": 0, "shot": 0, "pen_shot": 0}
	for sd in n:
		var p := _pen_play(at, d_at, seed0 + sd, sd % 2 == 1)
		_wind_up(p)
		if p.over or p.holder == null:
			continue
		p.shoot_at(Vector2(Geo.GOAL_X + 0.4, 9.0), 0.8)
		var pen := p.over and String(p.result.outcome) == "penalty"
		if pen:
			out.penalty += 1
			if p.ball.state == Ball.State.SHOT or _count(p, "shot") > 0:
				out.pen_shot += 1   # (should never: the whistle stops the shot)
		if p.ball.state == Ball.State.SHOT:
			out.shot += 1
		_fly(p)
		if _count(p, "exclusion") > 0:
			out.exclusion += 1
	return out

## Ball up and held READ_T before the shot, so his man has had time to see what's happening and
## decide (CenterDefense: a penalty is his choice, never the position alone).
const READ_T := 0.5
func _wind_up(p: Play) -> void:
	p.raise_ball(true)
	var t := 0.0
	while t < READ_T and not p.over and p.ball.state == Ball.State.HELD:
		p.step(DT)
		t += DT

func _penalties() -> void:
	print("rules: penalties on the shot")
	var at := Vector2(27.0, 10.0)
	var inside := _pen_rate(at, at + Vector2(-0.8, 0.1), 1000, 9000)
	var front := _pen_rate(at, at + Vector2(0.75, 0.05), 400, 9100)
	var beside := _pen_rate(at, at + Vector2(0.0, 0.8), 400, 9200)
	var outside := _pen_rate(Vector2(23.2, 10.0), Vector2(22.4, 10.1), 400, 9300)
	var gone := _pen_rate(at, at + Vector2(-2.5, 0.0), 400, 9400)
	print("  inside water in the box %s; his man in front %s; beside %s; outside the box %s; his man 2.5 m back %s" % [
		str(inside), str(front), str(beside), str(outside), str(gone)])
	r.check(inside.penalty > 0, "inside water, in the goalie box, going up, pulled back: a penalty")
	r.check_between(float(inside.penalty) / 1000.0, 0.05, 0.6, "...when his beaten man chooses to pull him: this share of those shots")
	r.check(inside.pen_shot == 0, "...and the whistle stops the shot")
	r.check(inside.penalty + inside.shot <= 1000 and inside.shot > 300, "...not pulled, the shot goes as normal (%d)" % inside.shot)
	r.check(front.penalty == 0, "his man ball side, goal side of him: no penalty")
	r.check(beside.penalty == 0, "his man beside him: no penalty")
	r.check(outside.penalty == 0, "inside water outside the goalie box: no penalty")
	r.check(gone.penalty == 0, "nobody close enough to foul him: no penalty")
	# just being in the box isn't enough: holding it there, never going up, nobody gives a penalty
	var held_pens := 0
	for sd in 100:
		var p := _pen_play(at, at + Vector2(-0.8, 0.1), 9500 + sd)
		var t := 0.0
		while t < 2.0 and not p.over:
			p.step(DT)
			t += DT
		if p.over and String(p.result.outcome) == "penalty":
			held_pens += 1
	r.check(held_pens == 0, "in the box with inside water but not shooting: no penalty (%d)" % held_pens)
	# a fed centre who has got inside water: going up at once it can be a penalty, never an
	# exclusion; holding it, it's the exclusion and never a penalty. One play never gets both.
	var pens := 0
	var shot_excls := 0
	var both := 0
	var n := 0
	var held_n := 0
	var held_excls := 0
	for sd in 600:
		var p := _setup(9600 + sd, sd % 2 == 1, "1", BEHIND, 0)
		var c := PlaySetup._by_tag(p, "C")
		if _feed(p) != "catch" or p.center_fed != c:
			continue
		var g := p._center_guard(c)
		g.pos = c.pos + Vector2(-0.8, 0.05)   # he's got in front of his man: inside water
		g.target = g.pos
		p.events.clear()
		if sd % 2 == 0:
			_wind_up(p)
			if p.over or p.holder != c:
				continue
			n += 1
			p.shoot_at(Vector2(Geo.GOAL_X + 0.4, 9.0), 0.8)
			var pen := p.over and String(p.result.outcome) == "penalty"
			_fly(p)
			var ex := _count(p, "exclusion") > 0
			pens += int(pen)
			shot_excls += int(ex)
			both += int(pen and ex)
		else:
			_hold(p, Play.CENTER_FOUL_T + 0.3)
			if _count(p, "foul") > 0:
				continue
			held_n += 1
			held_excls += int(_count(p, "exclusion") > 0)
			both += int(_count(p, "exclusion") > 0 and _count(p, "penalty") > 0)
	print("  fed centre with inside water: went up %d (penalties %d, exclusions %d); held it %d (exclusions %d); both %d" % [n, pens, shot_excls, held_n, held_excls, both])
	r.check(n > 100 and pens > 0 and shot_excls == 0, "going up with inside water: a penalty or the shot, never an exclusion")
	r.check(both == 0, "one play never gets a penalty and an exclusion")
	r.check_between(float(held_excls) / maxf(1.0, held_n), 0.74, 0.86, "holding it: the exclusion rate")
	# the existing penalty: the 5 m formation in the quarters (the shootout keeps its own: test_penalties)
	var teams: Array = r._teams()
	var f: MatchFlow = null
	for sd in 40:
		f = MatchFlow.new(teams[0], teams[1], 9900 + sd, MatchState.QUARTER_MIN)
		f._start_attack(Play.Kind.HALF_COURT)
		var p := f.play
		var d := p.defenders[0]
		r._mark_holder(p, d)
		p.holder.pos = at
		d.pos = at + Vector2(-0.8, 0.1)
		_wind_up(p)
		if p.over or p.holder == null:
			f = null
			continue
		p.shoot_at(Vector2(Geo.GOAL_X + 0.4, 9.0), 0.8)
		if p.over and String(p.result.outcome) == "penalty":
			break
		f = null
	r.check(f != null, "a penalty called on the shot in a match")
	if f != null:
		f.tick_attack(1.0 / 30.0)
		f.attack_done()
		var pp := f.play
		r.check(pp.kind == Play.Kind.PENALTY and not pp.shootout and pp.taker != null \
			and is_equal_approx(pp.taker.pos.x, Geo.FIVE_M) and pp.bodies().size() == 13,
			"...it's taken from the 5 m line in the usual formation, everybody in the water")

# ------------------------------------------------------------------ 4. the counter
func _counter_play(seed_value: int, defending: bool) -> Play:
	var teams: Array = r._teams()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var p := Play.new(teams[0], teams[1], Play.Kind.COUNTER, rng)
	p.defending = defending
	return p if p.carry else null

func _counter() -> void:
	print("rules: the counter's carrier")
	# no input: he swims it in, all the way, every counter
	var counters := 0
	var stalls := 0
	var slowest := INF
	var gained := 0.0
	for sd in 300:
		var p := _counter_play(11000 + sd, sd % 2 == 1)
		if p == null:
			continue
		counters += 1
		var slow := 0.0
		var t := 0.0
		var h := p.holder
		var x0 := h.pos.x
		while not p.over and p.carry and p.holder == h and t < 12.0:
			p.step(DT)
			t += DT
			if t < 0.5 or not p.carry or p.holder != h:
				continue
			slowest = minf(slowest, h.vel.x)
			if h.speed() < 0.6 and h.pos.distance_to(Geo.goal_center()) > Play.COUNTER_STOP + 0.6:
				slow += DT
				if slow > 0.25:
					stalls += 1
					break
			else:
				slow = 0.0
		gained += h.pos.x - x0
	print("  %d counters with nobody touching the screen: %d stalls, slowest forward speed %.2f m/s, %.1f m gained on average" % [counters, stalls, slowest, gained / maxf(1.0, counters)])
	r.check(counters > 100 and stalls == 0, "on the break the carrier swims at the goal without being told, never stopping")
	r.check(slowest > 0.5, "...always forwards")
	# pull back to shoot: he stops; let go of it: he swims on. A drag that isn't a pull back doesn't stop him.
	var stops := 0
	var resumes := 0
	var still := 0
	var drags := 0
	var n := 0
	for sd in 200:
		var p := _counter_play(12000 + sd, false)
		if p == null:
			continue
		var h := p.holder
		_steps(p, 0.4, func(): p.raise_ball(false))
		if not p.carry or p.over or p.holder != h or h.pos.distance_to(Geo.goal_center()) < 7.0:
			continue
		p.events.clear()
		var back := h.pos + Vector2(-3.0, 0.5)   # dragged the wrong way: that aims behind him
		var x0 := h.pos.x
		_steps(p, 0.4, func(): p.raise_ball(p.can_throw() and p.shooting_pull(back)))
		var dragged := not p.raised and h.pos.x - x0 > 0.5
		var goal := Vector2(Geo.GOAL_X + 0.4, Geo.GOAL_Y)
		_steps(p, 0.8, func(): p.raise_ball(p.can_throw() and p.shooting_pull(goal)))
		var stopped := p.raised and h.speed() < 0.2
		var x1 := h.pos.x
		_steps(p, 0.8, func(): p.raise_ball(false))   # (eased off, never let go of a shot)
		var resumed := not p.raised and h.pos.x - x1 > 0.6 and h.vel.x > 1.0
		if _count(p, "foul") > 0 or p.over or p.holder != h:
			continue   # (a whistle on the way: nobody throws while it's blown, so the ball's down anyway)
		n += 1
		drags += int(dragged)
		stops += int(stopped)
		if p.carry:
			# (still a break: the defence didn't get back while he waited; once it has, he's in the set
			# attack and a man in contact with him holds him there: DefenseFormation.press)
			still += 1
			resumes += int(resumed)
	print("  %d breaks: pulled back, stopped %d; eased off, still a break, swam on %d of %d; a drag the wrong way, kept swimming %d" % [n, stops, resumes, still, drags])
	r.check(n > 60 and stops == n, "pulling back to shoot stops him and the ball goes up")
	r.check(still > 10 and resumes == still, "...ease off without shooting and (still on the break) he swims at the goal again")
	r.check(drags == n, "a drag that isn't a pull back at the goal doesn't stop him")
	# the shooting controls are as they were: a pull that lands in the goal shoots, a tap passes
	var p2: Play = null
	for sd in 50:
		p2 = _counter_play(13000 + sd, false)
		if p2 != null:
			break
	var mate: Swimmer = null
	for a in p2.attackers:
		if a != p2.holder and not a.out and a.pos.x >= p2.holder.pos.x - Play.BREAK_TRAIL and a.tag != "C":
			mate = a
	r.check(mate != null and p2.pass_at(p2.lead_point(mate)), "on the break, a tap still passes")
	var t2 := 0.0
	while p2.ball.state == Ball.State.PASS and t2 < 2.0:
		p2.step(DT)
		t2 += DT
	r.check(p2.holder == mate and p2.carry, "...he catches it and it's still a break")
	_steps(p2, 0.6, func(): p2.raise_ball(false))
	r.check(not p2.carry or mate.vel.x > 1.0, "...and he carries it on at the goal (%.1f m/s)" % mate.vel.x)
	var p3: Play = null
	for sd in 50:
		p3 = _counter_play(13100 + sd, false)
		if p3 != null:
			break
	r.check(p3.shoot_at(Vector2(Geo.GOAL_X + 0.4, 9.0), 0.8) == "shot", "...and a pull into the goal still shoots")
	# the defence gets back in numbers: the break is over and the attack sets up
	var ended := 0
	var n4 := 0
	for sd in 100:
		var p := _counter_play(14000 + sd, sd % 2 == 1)
		if p == null:
			continue
		n4 += 1
		var bx := p.holder.pos.x
		for d in p.defenders:
			d.pos = Vector2(minf(bx + 2.5, 27.0), d.pos.y)
			d.target = d.pos
		p.events.clear()
		_steps(p, Play.BREAK_CHECK + 0.1, func(): pass)
		if not p.carry and _count(p, "settle") == 1:
			ended += 1
	r.check(n4 > 30 and ended == n4, "the defence back in numbers: the counter ends and the attack sets up (%d/%d)" % [ended, n4])

# ------------------------------------------------------------------ 5. the centre swimming in
## Seconds of play, ball held by whoever has it, recording the gap from the centre to his man
## while he's still on his way in: [average, most].
func _trail_gap(p: Play, secs: float) -> Vector2:
	var c := PlaySetup._by_tag(p, "C")
	var sum := 0.0
	var most := 0.0
	var k := 0
	var t := 0.0
	while t < secs and not p.over and p.holder != null:
		p.raise_ball(false)
		p.step(DT)
		t += DT
		if not PlayAI.center_swimming_in(p, c) or t < 0.3:
			continue
		var g := PlayAI.center_pair(p)
		var gap := g.pos.distance_to(c.pos)
		sum += gap
		most = maxf(most, gap)
		k += 1
	return Vector2(sum / maxf(1, k), most) if k > 0 else Vector2(-1, -1)

func _transition() -> void:
	print("rules: the centre's man on his back as he swims in")
	var teams: Array = r._teams()
	# the swim-in (after the ball changes hands with no break, or a goal): his man on his back
	var avg := 0.0
	var most := 0.0
	var n := 0
	for sd in 100:
		var rng := RandomNumberGenerator.new()
		rng.seed = 21000 + sd
		var p := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, rng)
		p.defending = sd % 2 == 1
		var gm := _trail_gap(p, 3.0)
		if gm.x < 0.0:
			continue
		n += 1
		avg += gm.x
		most = maxf(most, gm.y)
	print("  swim-in: %d, his man %.2f m off him on average, %.2f m at most" % [n, avg / maxf(1, n), most])
	r.check(n > 80 and avg / n < 0.8 and most < 1.3, "swimming in to 2 m, his man stays on his back, in contact")
	# a counter: he goes down the pool with him, not metres behind
	avg = 0.0
	most = 0.0
	n = 0
	for sd in 200:
		var p := _counter_play(22000 + sd, sd % 2 == 1)
		if p == null or p.holder.tag == "C":
			continue
		var c := PlaySetup._by_tag(p, "C")
		var g := PlayAI.center_pair(p)
		if g.pos.distance_to(c.pos) > PlayAI.CENTER_STICK_R:
			continue   # (he wasn't with him when the ball changed hands: he got back instead)
		var gm := _trail_gap(p, 4.0)
		if gm.x < 0.0:
			continue
		n += 1
		avg += gm.x
		most = maxf(most, gm.y)
	print("  counters: %d, his man %.2f m off him on average, %.2f m at most" % [n, avg / maxf(1, n), most])
	r.check(n > 60 and avg / n < 0.8 and most < 1.5, "on a counter his man swims down the pool on his back")
	# the breakout (the banner): the man who'll guard their centre turns with him and goes with him
	var bo := 0
	var bo_most := 0.0
	for sd in 100:
		var p := _center_play_both(23000 + sd)
		var c_player: PoloPlayer = p.them.starters()[1]
		var g_player: PoloPlayer = PlaySetup.wrestlers(p.us.starters())[0]
		var cs: Swimmer = p.defenders.filter(func(d): return d.player == c_player)[0]
		var gs: Swimmer = p.attackers.filter(func(a): return a.player == g_player)[0]
		if gs == p.holder:
			p.give_ball(p.attackers.filter(func(a): return a != gs)[0])
		var stealer: Swimmer = p.defenders.filter(func(d): return d != cs)[sd % 5]
		gs.pos = cs.pos + Vector2(0.6, 0.3)   # (they were wrestling)
		p._turnover(stealer, "PICKED OFF!", "steal")
		if p.breakout_guard != gs or p.breakout_centre != cs:
			continue
		bo += 1
		for i in 120:
			p.step(DT)
			if i > 40:
				bo_most = maxf(bo_most, p.breakout_guard.pos.distance_to(p.breakout_centre.pos))
	print("  breakouts with the pair together: %d, his man %.2f m off him at most" % [bo, bo_most])
	r.check(bo > 50 and bo_most < 1.3, "while the banner's up, he turns with the man he'll guard and doesn't fall behind")
	# trying to get away: he matches the centre's pace. Even the quickest centre there is (a JET)
	# against the slowest man can't shake him on the way in...
	var gap := 0.0
	for sd in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = 24000 + sd
		var p := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, rng)
		var c := PlaySetup._by_tag(p, "C")
		var g := PlayAI.center_pair(p)
		c.pos = Vector2(14.0, 10.0)
		g.pos = c.pos + Vector2(-PlayAI.CENTER_TRAIL, 0.0)
		p.carry = true   # (a counter: he races in to 2 m, as fast as he goes)
		c.top_speed = lerpf(1.7, 2.5, 1.0) + Sprint.JET_BONUS
		g.top_speed = 1.7
		var t := 0.0
		while t < 4.0 and not p.over and p.carry:
			p.raise_ball(false)
			p.step(DT)
			t += DT
			gap = maxf(gap, g.pos.distance_to(c.pos))
	print("  racing in: the quickest centre against the slowest man, %.2f m off him at most" % gap)
	r.check(gap < 1.0, "the centre racing in can't shake his man by speed alone")
	# ...he wins inside water the way he always has: on his spot, in the 2 m battle
	var sealed := 0
	var plays := 0
	for sd in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = 24500 + sd
		var p := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, rng)
		p.drive_timer = 99.0
		var t := 0.0
		var won := false
		while t < 15.0 and not p.over and p.holder != null:
			p.raise_ball(false)
			p.step(DT)
			t += DT
			won = won or p.cfight == PlayAI.Fight.SEALED
		if p.over or p.holder == null:
			continue
		plays += 1
		sealed += int(won)
	print("  swum in and set: inside water won in %d of %d possessions (15 s)" % [sealed, plays])
	r.check(plays > 30 and sealed > plays * 0.6, "...once set, the centre still wins inside water")
	# a ball in to him as he swims in: with his man on his back, contested; with a step on him, his
	var picked := 0
	var thrown := 0
	var free_picked := 0
	var free_thrown := 0
	for sd in 400:
		var rng := RandomNumberGenerator.new()
		rng.seed = 25000 + sd
		var p := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, rng)
		p.defending = sd % 2 == 1
		var c := PlaySetup._by_tag(p, "C")
		var free := sd % 4 == 3
		_steps(p, 0.4, func(): p.raise_ball(false))
		if p.over or p.holder == null or c.pos.distance_to(c.home) < Play.CENTER_SPOT_R + 0.5:
			continue
		var g := PlayAI.center_pair(p)
		if free:
			g.pos = c.pos + Vector2(-1.6, 0.0)   # a step on him
		var e := p.center_entry(p.holder.pos, c)
		if free != (e == ""):
			continue
		if not free and e != "trailed":
			continue
		p.pass_to(c)
		var t := 0.0
		while p.ball.state == Ball.State.PASS and t < 2.0:
			p.step(DT)
			t += DT
		var stolen := p.over and p.holder == g
		if free:
			free_thrown += 1
			free_picked += int(stolen)
		else:
			thrown += 1
			picked += int(stolen)
	print("  into the centre swimming in: his man on his back took %d of %d; a step on him %d of %d" % [picked, thrown, free_picked, free_thrown])
	r.check(thrown > 150 and float(picked) / thrown > 0.3 and float(picked) / thrown < 0.7, "his man on his back gets a hand to it often, not always")
	r.check(free_thrown > 40 and float(free_picked) / free_thrown < 0.1, "...a step clear of him, only the usual pick-offs (%d)" % free_picked)

## A set half court (test_runner._center_play) with both teams' rosters (for the breakout pair).
func _center_play_both(seed_value: int) -> Play:
	var p: Play = r._center_play(seed_value, false)
	p.give_ball(PlaySetup._by_tag(p, "3"))
	return p

# ------------------------------------------------------------------ 6. the keeper comes out
## An open entry from `from_tag` thrown `past` m past where the centre would take it (-1: right
## to him). {rush, claim, centre, moved, step}
func _overpass(seed_value: int, defending: bool, past: float) -> Dictionary:
	var p: Play = r._center_play(seed_value, defending)
	var c := PlaySetup._by_tag(p, "C")
	var g := p._center_guard(c)
	g.pos = c.pos + Vector2(0.55, 0.0)   # behind him: the entry's open
	g.target = g.pos
	var from := PlaySetup._by_tag(p, ["2", "4"][seed_value % 2])
	p.give_ball(from)
	var lead := p.lead_point(c)
	var to: Vector2 = lead if past < 0.0 else Geo.clamp_in_pool(lead + (lead - from.pos).normalized() * (Play.CATCH_R + past))
	var k0 := p.keeper.pos
	p._pass(to, c)
	var out := {"rush": p.keeper_rush, "claim": false, "centre": false, "moved": 0.0, "step": 0.0}
	var last := p.keeper.pos
	var t := 0.0
	while not p.over and p.holder == null and t < 3.0:
		p.step(DT)
		t += DT
		out.step = maxf(out.step, p.keeper.pos.distance_to(last))
		last = p.keeper.pos
	out.claim = p.over and p.holder == p.keeper
	out.centre = p.holder == c
	out.moved = p.keeper.pos.distance_to(k0)
	return out

func _keeper_out() -> void:
	print("rules: the keeper comes out for a ball thrown past the centre")
	for defending in [false, true]:
		var who := "theirs" if defending else "yours"   # (whose attack: defending, it's your keeper)
		var right := 0
		var right_rush := 0
		var rates: Array[float] = []
		var claim_ok := true
		var moved := INF
		var step := 0.0
		for past in [-1.0, 1.5, 2.5, 3.5]:
			var rush := 0
			var k := 0
			for sd in 150:
				var o := _overpass(26000 + sd, defending, past)
				k += 1
				rush += int(o.rush)
				if past < 0.0:
					right += int(o.centre)
					right_rush += int(o.rush)
				elif o.rush:
					claim_ok = claim_ok and o.claim
					moved = minf(moved, o.moved)
					step = maxf(step, o.step)
			if past >= 0.0:
				rates.append(float(rush) / k)
		print("  %s: right to him, caught %d/150 (keeper out %d); %.1f / %.1f / %.1f m past him, keeper out %s; claimed every time %s, swam %.2f m at least, %.3f m a frame at most" % [
			who, right, right_rush, 1.5, 2.5, 3.5, str(rates), claim_ok, moved, step])
		r.check(right == 150 and right_rush == 0, "%s: an accurate entry reaches the centre, and the keeper stays home" % who)
		r.check(rates[0] > 0.0 and rates[0] < rates[1] and rates[1] <= rates[2] and rates[2] > 0.6,
			"%s: the further past the centre it's thrown, the likelier the keeper comes for it" % who)
		r.check(claim_ok, "%s: out for it, he gets it: their ball at once" % who)
		r.check(moved > 0.3 and step < 0.12, "%s: he swims out to it (%.2f m), he isn't teleported (%.3f m a frame)" % [who, moved, step])
	# in a match, your keeper (their attack): he comes off his line, and the flow lets him
	var teams: Array = r._teams()
	var f := MatchFlow.new(teams[0], teams[1], 27000, MatchState.QUARTER_MIN)
	f._start_defense(Play.Kind.HALF_COURT)
	var p := f.play
	var c := PlaySetup._by_tag(p, "C")
	for a in p.attackers:
		a.pos = a.home
		a.target = a.home
	c.pos = c.home
	var g := p._center_guard(c) if p._center_guard(c) != null else PlayAI.center_pair(p)
	g.pos = c.pos + Vector2(0.55, 0.0)
	var tries := 0
	var got := false
	while tries < 30 and not got:
		tries += 1
		p.give_ball(PlaySetup._by_tag(p, ["2", "4"][tries % 2]))
		var lead := p.lead_point(c)
		var to: Vector2 = lead + (lead - p.holder.pos).normalized() * (Play.CATCH_R + 3.5)
		p._pass(Geo.clamp_in_pool(to), c)
		if not p.keeper_rush:
			continue
		var k0 := p.keeper.pos
		var t := 0.0
		while not p.over and t < 3.0:
			f.tick_defense(DT)
			t += DT
		got = p.over and p.holder == p.keeper and p.keeper.pos.distance_to(k0) > 0.3
	r.check(got, "in a match your keeper swims off his line for it and takes it")

## Steps `p` for `secs`, calling `each` before every frame (the screen's input).
func _steps(p: Play, secs: float, each: Callable) -> void:
	var t := 0.0
	while t < secs - 0.001 and not p.over:
		each.call()
		p.step(DT)
		t += DT
