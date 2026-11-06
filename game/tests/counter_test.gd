extends RefCounted
## The AI's 6 m rule (Geo.in_shot_range: OffenseAI, PlayBot) and the break: lanes
## (PlayAI.assign_lanes), timed runs onto lead passes (PlayAI.run_onto), the defence getting goal
## side and sorting out who takes whom (PlayAI.counter_marks, counter_spot), and the break ending
## in the settled attack. Staged by hand, so every scenario is the same every run; each one is
## played as your attack and as theirs (`defending`), and mirrored top to bottom.
##   godot --headless --path game -- --test counter

const DT := 1.0 / 60.0

var r   # the test runner (check, check_between)

func run(runner) -> void:
	r = runner
	print("counter")
	_ai_range()
	_ai_deadline()
	_bot_range()
	_lanes()
	_lead_pass()
	_goal_side()
	_two_on_one()
	_marks_stable()
	_even_settles()
	_breakaway()
	_speeds()

func _teams() -> Array:
	return [League.make_team(2, 1), League.make_team(3, 1)]

# ------------------------------------------------------------------ staging
## A half-court possession with the ball at `at`, the rest of the attack on its spots, and the
## defence well up the pool; `cover`: every other man of ours has his man goal side of him.
func _set_play(at: Vector2, seed_value: int, defending: bool, cover := false) -> Play:
	var t := _teams()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var p := Play.new(t[0], t[1], Play.Kind.HALF_COURT, rng)
	p.defending = defending
	for a in p.attackers:
		a.pos = a.home
	p.holder.pos = at
	for i in p.defenders.size():
		p.defenders[i].pos = Vector2(4.0 + i, 2.0 + 3.0 * i)
		var m := p.defenders[i].mark
		if cover and m != p.holder:
			p.defenders[i].pos = m.pos + (Geo.goal_center() - m.pos).normalized() * 0.8   # (his man's covered)
	p.keeper.pos = Vector2(Geo.KEEPER_X, Geo.GOAL_Y)
	for s in p.bodies():
		s.target = s.pos
		s.vel = Vector2.ZERO
	return p

## A break: `att` of ours up the pool (the ball in the middle one, "3"; "2" and "4" with him),
## `back` of theirs goal side of it, everybody else (the centre and his man too) well behind.
## `flip` mirrors it top to bottom.
func _break(att: int, back: int, defending: bool, flip := false, seed_value := 3) -> Play:
	var t := _teams()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var p := Play.new(t[0], t[1], Play.Kind.HALF_COURT, rng)
	p.defending = defending
	var fy := func(y: float) -> float: return 2.0 * Geo.GOAL_Y - y if flip else y
	var spots := {"3": Vector2(14.0, 9.0), "4": Vector2(13.6, 4.8), "2": Vector2(13.4, 14.6)}
	var order := ["3", "4", "2"]
	if att == 2:
		spots = {"3": Vector2(14.0, 8.5), "4": Vector2(13.6, 13.5)}
	var holder: Swimmer = null
	var parked := 0
	for a in p.attackers:
		var i := order.find(a.tag)
		if i >= 0 and i < att:
			a.pos = spots[a.tag]
			a.pos.y = fy.call(a.pos.y)
			a.vel = Vector2(a.top_speed * PlaySetup.BREAK_SWIM, 0.0)
			if a.tag == "3":
				holder = a
		else:
			a.pos = Vector2(3.0 + parked, fy.call(3.0 + 3.0 * parked))
			a.vel = Vector2.ZERO
			parked += 1
	var backs := [Vector2(20.5, 9.5), Vector2(21.0, 13.0), Vector2(19.5, 6.0)]
	var n := 0
	for d in p.defenders:
		if n < back and d != PlayAI.center_pair(p):
			d.pos = backs[n]
			d.pos.y = fy.call(d.pos.y)
			d.vel = Vector2(1.5, 0.0)
			n += 1
		else:
			d.pos = Vector2(2.0 + parked * 0.7, fy.call(2.0 + 2.5 * parked))
			d.vel = Vector2.ZERO
			parked += 1
	p.keeper.pos = Vector2(Geo.KEEPER_X, Geo.GOAL_Y)
	for s in p.bodies():
		s.target = s.pos
	p.give_ball(holder)
	p.kind = Play.Kind.COUNTER
	p.carry = true
	p.counter_t = 5.0
	p.break_n = p.break_numbers()
	PlayAI.counter_marks(p)
	PlayAI.assign_lanes(p)
	return p

func _variants() -> Array:
	return [[false, false], [true, false], [false, true], [true, true]]   # [defending, flip]

func _name(v: Array) -> String:
	return ("theirs" if v[0] else "yours") + (", flipped" if v[1] else "")

func _men(p: Play) -> Array:
	return p.lanes.keys()

## The defenders who started back (goal side of the ball).
func _backs(p: Play) -> Array:
	return p.defenders.filter(func(d: Swimmer): return d.pos.x > p.holder.pos.x)

func _step(p: Play, secs: float, each := Callable()) -> void:
	var t := 0.0
	while t < secs - 0.0001 and not p.over:
		p.step(DT)
		t += DT
		if each.is_valid():
			each.call()

# ------------------------------------------------------------------ the AI's 6 m rule
func _is_shot(p: Play, d: Dictionary) -> bool:
	return not d.is_empty() and String(p.aim_info(d.target).mode) == "shot"

## Outside 6 m OffenseAI never shoots, whatever the clock, pressed or not; it passes or swims it
## in. Inside, it still shoots (and straight off a catch).
func _ai_range() -> void:
	var far_shots := 0
	var far_looks := 0
	var moved := 0
	var quick := 0
	for defending in [true, false]:
		for x in [17.0, 20.0, 22.5, 23.4, 23.95]:
			for y in [5.0, 10.0, 15.0]:
				for clock in [25.0, 9.0, 3.0, 0.5]:
					for pressed in [false, true]:
						var p := _set_play(Vector2(x, y), int(x * 10 + y + clock), defending)
						var ai := OffenseAI.new()
						var rng := RandomNumberGenerator.new()
						rng.seed = int(x * 7 + y)
						var d := ai.think(p, rng, pressed, clock)
						far_looks += 1
						if _is_shot(p, d):
							far_shots += 1
						elif not d.is_empty() or p.holder.drive_t > 0.0:
							moved += 1
						p.catch_t = 0.0
						if ai.quick_shot(p):
							quick += 1
	r.check(far_shots == 0, "counter: OffenseAI never shoots from outside 6 m (%d of %d looks)" % [far_shots, far_looks])
	r.check(quick == 0, "counter: ...nor straight off the catch out there")
	r.check(moved >= far_looks * 0.5, "counter: outside 6 m it passes or swims it in (%d of %d)" % [moved, far_looks])
	var near_shots := {9.0: 0, 3.0: 0}
	var near_looks := 0
	for defending in [true, false]:
		for at in [Vector2(24.0, 10.0), Vector2(25.0, 12.0), Vector2(26.5, 8.0), Vector2(27.5, 10.0)]:
			near_looks += 1
			for clock in [9.0, 3.0]:
				var p := _set_play(at, int(at.x * 13 + clock), defending, true)
				p.shot_clock = clock
				var ai := OffenseAI.new()
				var rng := RandomNumberGenerator.new()
				rng.seed = 5
				PlaySetup._by_tag(p, "C").out = true   # (no centre to feed: it's his look or a swing)
				if _is_shot(p, ai.think(p, rng, false, clock)):
					near_shots[clock] += 1
	# (with time left an open man inside 6 m may still find a better pass: his shot selection is as it was)
	r.check(near_shots[3.0] == near_looks, "counter: inside 6 m with the clock going, it shoots (%d of %d)" % [near_shots[3.0], near_looks])
	r.check(near_shots[9.0] > 0, "counter: ...and open inside 6 m with time left it can shoot (%d of %d)" % [near_shots[9.0], near_looks])
	r.check(Geo.in_shot_range(Vector2(Geo.SIX_M, 3.0)) and not Geo.in_shot_range(Vector2(Geo.SIX_M - 0.05, 10.0)),
		"counter: the 6 m line itself is in range, just outside it isn't")

## The shot clock running out outside 6 m: still no shot. It passes to a man inside if it can (and
## he can shoot it), otherwise it keeps it and the shot clock goes.
func _ai_deadline() -> void:
	var in_range_pass := 0
	var n := 0
	for seed_value in 12:
		var p := _set_play(Vector2(22.0, 10.0), 40 + seed_value, true)
		var ai := OffenseAI.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var d := ai.think(p, rng, false, 1.0)
		r.check(not _is_shot(p, d), "counter: 1 s on the clock at 8 m, no shot (seed %d)" % seed_value)
		if not d.is_empty():
			n += 1
			var info := p.aim_info(d.target)
			if info.receiver != null and Geo.in_shot_range(info.point):
				in_range_pass += 1
	r.check(n > 0 and in_range_pass == n, "counter: ...it gives it to a man inside 6 m (%d of %d)" % [in_range_pass, n])
	# nobody to give it to: it holds it and the shot clock goes
	var p := _set_play(Vector2(22.0, 10.0), 77, true)
	for a in p.attackers:
		if a != p.holder:
			a.out = true
	p.start_shot_clock(1.5)
	var ai := OffenseAI.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var shots := 0
	var t := 0.0
	while not p.over and t < 4.0:
		p.raise_ball(false)
		var d := ai.think(p, rng, false, p.shot_clock)
		if not d.is_empty():
			if p.throw(d.target, d.power) == "shot":
				shots += 1
		p.step(DT)
		t += DT
	r.check(shots == 0 and p.over and String(p.result.outcome) == "shotclock",
		"counter: alone outside 6 m as the clock goes, it's a shot clock violation, not a shot (%s)" % str(p.result.get("outcome", "")))

## PlayBot (the bot that plays your attack in the demo and the tests) keeps to it too.
func _bot_range() -> void:
	var far := 0
	var near := 0
	for seed_value in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var p := _set_play(Vector2(21.0 + (seed_value % 6) * 0.5, 6.0 + (seed_value % 5) * 2.0), seed_value, false)
		p.shot_clock = [20.0, 4.0, 2.0, 0.5][seed_value % 4]
		if _is_shot(p, PlayBot.think(p, rng, seed_value % 2 == 0)):
			far += 1
		var q := _set_play(Vector2(26.0, 9.0 + (seed_value % 3)), seed_value, false)
		q.shot_clock = [20.0, 4.0, 2.0, 0.5][seed_value % 4]
		if _is_shot(q, PlayBot.think(q, rng)):
			near += 1
	r.check(far == 0, "counter: PlayBot never shoots from outside 6 m (%d)" % far)
	r.check(near > 10, "counter: ...and still does inside it (%d of 40)" % near)

# ------------------------------------------------------------------ lanes
## Three in the break take the three lanes and stay in them (spread across the pool, nobody on
## top of anybody), two take top and bottom, and everybody in the break keeps swimming at the goal.
func _lanes() -> void:
	for v in _variants():
		for att in [3, 2]:
			var p := _break(att, att - 1, v[0], v[1])
			var lanes := p.lanes.duplicate()
			var want := [-1, 0, 1] if att == 3 else [-1, 1]
			var got := lanes.values()
			got.sort()
			r.check(got == want, "counter: %d in the break take lanes %s (%s): %s" % [att, str(want), _name(v), str(got)])
			var men := _men(p)
			var w := {"closest": INF, "slowest": INF, "switched": false, "t": 0.0}   # (a lambda can't assign the locals round it)
			_step(p, 2.0, func():
				w.t += DT
				if p.carry:
					w.switched = w.switched or p.lanes != lanes
					for a: Swimmer in men:
						w.slowest = minf(w.slowest, a.vel.x)
					if w.t > 0.5:
						for i in men.size():
							for j in range(i + 1, men.size()):
								w.closest = minf(w.closest, men[i].pos.distance_to(men[j].pos)))
			var closest: float = w.closest
			var slowest: float = w.slowest
			var switched: bool = w.switched
			var ys: Array = men.map(func(a: Swimmer): return a.pos.y)
			ys.sort()
			var gap := INF
			for i in range(1, ys.size()):
				gap = minf(gap, ys[i] - ys[i - 1])
			r.check(not switched, "counter: %d in the break, nobody changes lanes (%s)" % [att, _name(v)])
			r.check(gap >= (2.5 if att == 3 else 3.0), "counter: %d in the break spread across the pool (%.1f m between lanes, %s)" % [att, gap, _name(v)])
			r.check(closest >= 1.5, "counter: %d in the break, nobody on top of a teammate (%.1f m, %s)" % [att, closest, _name(v)])
			r.check(slowest >= 0.0, "counter: %d in the break, all of them keep swimming at the goal (slowest %.2f m/s, %s)" % [att, slowest, _name(v)])
			# lanes follow who's in the break, keeping who they can in theirs
			if att == 3:
				var keep := p.lanes.duplicate()
				PlayAI.assign_lanes(p)
				r.check(p.lanes == keep, "counter: handing lanes out again keeps everybody in his (%s)" % _name(v))

# ------------------------------------------------------------------ lead passes
## A ball led to a man in his lane: he runs onto it and takes it, never turning back. Thrown long
## across the pool (so he'd be there before it), he times his run instead of overshooting it.
func _lead_pass() -> void:
	for v in _variants():
		for lead in [3.0, 1.0]:
			var p := _break(3, 2, v[0], v[1])
			_step(p, 0.5)
			var men: Array = _men(p).filter(func(a: Swimmer): return a != p.holder)
			men.sort_custom(func(a: Swimmer, b: Swimmer): return absf(a.pos.y - p.holder.pos.y) > absf(b.pos.y - p.holder.pos.y))
			var mate: Swimmer = men[0]
			var spot := mate.pos + Vector2(lead, 0.0)
			if lead == 1.0:
				p.holder.pos.y = 2.0 * Geo.GOAL_Y - mate.pos.y + (3.0 if mate.pos.y < Geo.GOAL_Y else -3.0)   # (from right across the pool)
			p.pass_at(spot)
			var slowest := INF
			var t := 0.0
			while t < 3.0 and not p.over and p.holder == null:
				p.step(DT)
				t += DT
				slowest = minf(slowest, mate.vel.x)
			r.check(p.holder == mate, "counter: a ball led %.0f m in front of him is caught (%s)" % [lead, _name(v)])
			r.check(slowest >= 0.0, "counter: ...and he never swims back for it (%.2f m/s, %s)" % [slowest, _name(v)])
			_step(p, 0.4)
			r.check(p.holder == mate and mate.vel.x > 1.0, "counter: ...and carries on at the goal with it (%s)" % _name(v))
	# straight through a ball in front (the run itself), back for one behind
	var p := _break(3, 2, false)
	var a: Swimmer = p.holder
	r.check(PlayAI.run_onto(a, a.pos + Vector2(3.0, 0.0), true, 0.2).x > a.pos.x + 3.0,
		"counter: a pass he can only just reach, he runs through it")
	var timed := PlayAI.run_onto(a, a.pos + Vector2(1.0, 0.0), true, 2.0)
	r.check(timed.x > a.pos.x and timed.x < a.pos.x + 1.0, "counter: one he'd be early for, he times it, still going forward")

# ------------------------------------------------------------------ the defence
## The men who are back stay goal side of the men they've got, go back with the break as it comes
## (not chase it), and a 3 on 2 has the ball and another man covered by the two of them.
func _goal_side() -> void:
	for v in _variants():
		var p := _break(3, 2, v[0], v[1])
		var backs := _backs(p)
		var x0: Array = backs.map(func(d: Swimmer): return d.pos.x)
		var w := {"goal_side": true, "stepped_up": false, "t": 0.0}
		_step(p, 2.5, func():
			w.t += DT
			for i in backs.size():
				w.stepped_up = w.stepped_up or backs[i].pos.x < x0[i] - 0.3
			if p.carry and w.t > 0.4:
				for d: Swimmer in backs:
					if d.mark != null and d.pos.x < d.mark.pos.x - 0.3:
						w.goal_side = false)
		var goal_side: bool = w.goal_side
		var stepped_up: bool = w.stepped_up
		var marked: Array = backs.map(func(d: Swimmer): return d.mark)
		var retreated := true
		for i in backs.size():
			var m: Swimmer = backs[i].mark
			retreated = retreated and backs[i].pos.x > x0[i] and m != null and backs[i].pos.x > m.pos.x + 1.0
		r.check(goal_side, "counter: the men back stay goal side of their men (%s)" % _name(v))
		r.check(retreated and not stepped_up, "counter: ...and give ground as the break comes (a metre or more in front of their men), never swimming up the pool at it (%s)" % _name(v))
		r.check(marked.size() == 2 and marked[0] != marked[1] and marked.has(p.holder if p.holder != null else marked[0]),
			"counter: 3 on 2, the two back take the ball and one other, not the same man (%s)" % _name(v))

## 2 on 1: the man back takes the ball, goal side, shading towards the other man (the pass
## across isn't a walk-in, and he's not off chasing either of them); the pass across goes, he
## picks up the new man with the ball. The attack still has its man over.
func _two_on_one() -> void:
	for v in _variants():
		var p := _break(2, 1, v[0], v[1])
		var d: Swimmer = _backs(p)[0]
		var mate: Swimmer = _men(p).filter(func(a: Swimmer): return a != p.holder)[0]
		_step(p, 1.2)
		var h := p.holder
		r.check(d.mark == h, "counter: 2 on 1, the man back takes the ball (%s)" % _name(v))
		var between := (d.pos.y - h.pos.y) * (mate.pos.y - h.pos.y) > 0.0 and absf(d.pos.y - h.pos.y) < absf(mate.pos.y - h.pos.y)
		r.check(between and d.pos.x > h.pos.x, "counter: ...goal side, shading towards the other man (%s)" % _name(v))
		r.check(p.is_break(), "counter: ...and it's still a man over (%s)" % _name(v))
		p.pass_to(mate)
		var t := 0.0
		while t < 2.0 and p.holder == null and not p.over:
			p.step(DT)
			t += DT
		p.step(DT)
		r.check(p.holder == mate and d.mark == mate, "counter: the pass across, and he picks up the new man with the ball (%s)" % _name(v))

## Nobody switches men while nothing changes (no pass): the marks are looked at again, but kept.
func _marks_stable() -> void:
	for v in _variants():
		var p := _break(3, 2, v[0], v[1])
		var backs := _backs(p)
		var marks: Array = backs.map(func(d: Swimmer): return d.mark)
		var changes := [0]
		_step(p, 3.0, func():
			for i in backs.size():
				if backs[i].mark != marks[i]:
					changes[0] += 1
					marks[i] = backs[i].mark)
		r.check(changes[0] == 0, "counter: the men back don't keep switching who they've got (%d switches, %s)" % [changes[0], _name(v)])

## Level numbers (2 on 2, 3 on 3) are no break: it settles into the set attack straight away, the
## ball and the shot clock carry on, nobody jumps, and the men go to their spots.
func _even_settles() -> void:
	for v in _variants():
		for n in [2, 3]:
			var p := _break(n, n, v[0], v[1])
			r.check(not p.is_break(), "counter: %d on %d is level (%s)" % [n, n, _name(v)])
			var h := p.holder
			var clock := p.shot_clock
			var last := {}
			for s in p.bodies():
				last[s] = s.pos
			var jump := [0.0]
			_step(p, 2.5, func():
				for s in p.bodies():
					jump[0] = maxf(jump[0], s.pos.distance_to(last[s]))
					last[s] = s.pos)
			r.check(not p.carry and p.holder == h, "counter: %d on %d settles, same man on the ball (%s)" % [n, n, _name(v)])
			r.check(p.shot_clock < clock and p.shot_clock > clock - 2.5 * MatchState.CLOCK_SPEED - 0.1, "counter: ...the shot clock runs on, not reset (%s)" % _name(v))
			r.check(jump[0] < 0.35, "counter: ...and nobody jumps (%.2f m in a frame, %s)" % [jump[0], _name(v)])
	# an outnumbered defence catching up ends it too (the numbers are looked at as it goes)
	var p := _break(2, 1, false)
	for d in p.defenders:
		if d.pos.x < p.holder.pos.x:
			d.pos = Vector2(p.holder.pos.x + 2.0, 12.0)
			break
	_step(p, 0.6)
	r.check(not p.carry, "counter: the defence getting a man back makes it level, and it settles")

## Clean away (1 on 0, everybody behind him): nobody's put in front of him, he swims it in, the
## keeper's still there to beat.
func _breakaway() -> void:
	for v in _variants():
		var p := _break(1, 0, v[0], v[1])
		var h := p.holder
		var w := {"ahead": false, "close": INF}
		_step(p, 6.0, func():
			if p.holder == h:
				w.close = minf(w.close, h.pos.distance_to(Geo.goal_center()))
				for d in p.defenders:
					if not d.out and d.pos.x > h.pos.x:
						w.ahead = true)
		var ahead: bool = w.ahead
		var close: float = w.close
		r.check(not ahead, "counter: clean away, no defender gets in front of him (%s)" % _name(v))
		r.check(close <= Play.COUNTER_STOP + 0.3, "counter: ...he gets all the way in (%.1f m, %s)" % [close, _name(v)])
		r.check(p.keeper_in and p.keeper.pos.distance_to(Vector2(Geo.KEEPER_X, Geo.GOAL_Y)) < 2.0, "counter: ...the keeper's there to beat (%s)" % _name(v))

## Defenders get back at their own speed: nobody swims faster than his top speed and the
## hardest boost a defender has (PlayAI.CENTER_TRAIL_BOOST), and the break isn't caught by magic.
func _speeds() -> void:
	var w := {"fastest": 0.0}
	for v in _variants():
		var p := _break(3, 2, v[0], v[1])
		_step(p, 3.0, func():
			for d in p.defenders:
				w.fastest = maxf(w.fastest, d.vel.length() / (d.top_speed * PlayAI.CENTER_TRAIL_BOOST)))
	var fastest: float = w.fastest
	r.check(fastest <= 1.001, "counter: no defender swims faster than he can (%.2f of his best)" % fastest)
