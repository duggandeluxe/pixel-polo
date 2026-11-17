extends RefCounted
## INSIDE WATER PENALTIES: a man with the ball who has inside water on his defender (between him and
## the goal, Play.behind), on a clear chance in the box, fouled by that beaten defender, is given a
## PENALTY, never an ordinary foul: in PRESS or any drop, and however late the drop was called.
## "Beaten" is one test (Play.behind) for both inside water and a foul from behind, from the real
## positions: before it, a guard between 45 and 50 degrees off straight behind gave the man inside
## water yet fouled him for a free throw (a late drop's foul on the ball, _drop_step, among them).
##   godot --headless --path game -- --test inside_water_penalty

const F := DefenseFormation.F
const ALL := [F.PRESS, F.M_DROP, F.FOUR_FIVE, F.FIVE_DROP, F.THREE_FOUR]

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("inside water penalties")
	var was := Play.instant_drops
	Play.instant_drops = false   # (a drop called in play waits for its foul on the ball: Play.begin_drop)
	_run()
	Play.instant_drops = was

func _run() -> void:
	var goal := Geo.goal_center()
	var spots := [Vector2(27.6, 10.4), Vector2(27.6, 9.6)]   # the centre at 2 m, either side of the cage
	var angles := [0.0, 30.0, 47.0, -47.0]                     # 47: the band the old 45 degree test missed

	# A: a late drop. The centre has inside water, the drop's called, the ball's his: the beaten
	# guard's foul is a penalty, and the drop's own foul on the ball never whistles him for a free throw.
	var a := {"n": 0, "pen": 0, "no_drop_foul": 0, "iw": 0}
	for f in DefenseFormation.DROPS:
		for defending in [true, false]:
			for at in spots:
				for ang in angles:
					var p := _scene(5100 + a.n, defending, "C", at, _back(at, ang))
					var c := p.holder
					var g := p._marker(c)
					a.n += 1
					a.iw += 1 if p.has_inside_water(c) else 0
					r.check(p.select_formation(f) and p.drop_pending == f, "(the drop is called late: pending, %s)" % DefenseFormation.NAMES[f])
					p._drop_step()
					if not p.events.any(func(e): return String(e.k) in ["drop_foul", "foul"]):
						a.no_drop_foul += 1
					p._ordinary_foul(c, g)
					a.pen += 1 if _outcome(p) == "penalty" else 0
	r.check(a.iw == a.n, "A: the centre has inside water on his guard every time: %d / %d" % [a.iw, a.n])
	r.check(a.no_drop_foul == a.n, "A: a late drop's foul on the ball doesn't whistle a beaten guard for a free throw: %d / %d" % [a.no_drop_foul, a.n])
	r.check(a.pen == a.n, "A: late drop, the beaten guard fouls from behind: PENALTY %d / %d" % [a.pen, a.n])

	# ...and the drop formed but the dropper not there yet (just swimming over): still a penalty
	var late := {"n": 0, "pen": 0}
	for f in DefenseFormation.DROPS:
		for at in spots:
			var p := _scene(5300 + late.n, true, "C", at, _back(at, 47.0))
			p.instant_drop(f)
			var dr := _dropper_of(p)
			dr.pos = at + (at - goal).normalized().orthogonal() * 1.3 + (at - goal).normalized() * 0.6   # beside him, coming
			late.n += 1
			p._ordinary_foul(p.holder, p._marker(p.holder))
			late.pen += 1 if _outcome(p) == "penalty" else 0
	r.check(late.pen == late.n, "A: a drop that's formed but not there in time doesn't save the beaten guard: PENALTY %d / %d" % [late.pen, late.n])

	# B: normal PRESS, the same water: penalty
	var b := {"n": 0, "pen": 0}
	for defending in [true, false]:
		for at in spots:
			for ang in angles:
				var p := _scene(5500 + b.n, defending, "C", at, _back(at, ang))
				b.n += 1
				p._ordinary_foul(p.holder, p._marker(p.holder))
				b.pen += 1 if _outcome(p) == "penalty" else 0
	r.check(b.pen == b.n, "B: press, inside water, fouled from behind on a clear chance: PENALTY %d / %d" % [b.pen, b.n])

	# C: the drop got there. The guard recovered goal side, the dropper set in front of the centre
	# (between him and the ball): fouled by either, an ordinary foul
	var cc := {"n": 0, "foul": 0}
	for f in ALL:
		for at in spots:
			var p := _scene(5700 + cc.n, true, "C", at, (goal - at).normalized() * 0.8)   # the guard goal side
			var c := p.holder
			cc.n += 1
			r.check(not p.has_inside_water(c), "(C: no inside water with his man goal side of him)")
			p._ordinary_foul(c, p._marker(c))
			cc.foul += 1 if _outcome(p) == "foul" else 0
			if f != F.PRESS:
				var q := _scene(5800 + cc.n, true, "C", at, (goal - at).normalized() * 0.8)
				q.instant_drop(f)
				var dr := _dropper_of(q)
				dr.pos = DefenseFormation.drop_spot(q, q.holder)
				cc.n += 1
				q._ordinary_foul(q.holder, dr)
				cc.foul += 1 if _outcome(q) == "foul" else 0
	r.check(cc.foul == cc.n, "C: the defence recovered (goal side, the dropper set): an ordinary foul %d / %d" % [cc.foul, cc.n])

	# D: no clear chance: outside the box, beside him, a few cm off behind, a second defender in
	# his way: the ordinary foul as ever
	var d := {"n": 0, "foul": 0}
	var cases := [
		[Vector2(22.5, 10.0), Vector2(-0.9, 0.0), Vector2.INF],          # 7.5 m out, from behind
		[Vector2(27.6, 10.4), Vector2(-0.1, 0.9), Vector2.INF],          # beside him
		[Vector2(27.6, 10.4), Vector2(-0.1, 0.0), Vector2.INF],          # not really behind
		[Vector2(25.6, 10.5), Vector2(-0.9, -0.1), Vector2(27.4, 10.3)], # a man between him and the goal
	]
	for defending in [true, false]:
		for k in cases:
			var p := _scene(5900 + d.n, defending, "2", k[0], k[1], k[2])
			d.n += 1
			p._ordinary_foul(p.holder, p._marker(p.holder))
			d.foul += 1 if _outcome(p) == "foul" else 0
	r.check(d.foul == d.n, "D: no clear chance (or not beaten): an ordinary foul %d / %d" % [d.foul, d.n])

	# E: both attacking directions. The play's frame always attacks x = 30 (your attack and theirs);
	# the geometry itself, end to end, gives the same call for the same water
	var gl := Vector2(0.0, Geo.GOAL_Y)
	var same := true
	for ang in angles + [55.0, 120.0, 180.0]:
		for dist in [0.3, 0.85, 1.2]:
			var at_r := Vector2(27.6, 10.4)
			var at_l := Vector2(Geo.GOAL_X - at_r.x, at_r.y)
			var off_r: Vector2 = _back(at_r, ang) * (dist / 0.85)
			same = same and Play.behind(at_r, at_r + off_r, goal) == Play.behind(at_l, at_l + Vector2(-off_r.x, off_r.y), gl)
	r.check(same, "E: attacking left to right or right to left: identical calls")
	var both := true
	for at in spots:
		for ang in angles:
			both = both and _call(6100, true, "C", at, _back(at, ang)) == _call(6100, false, "C", at, _back(at, ang))
	r.check(both, "E: your defence and theirs: identical calls")

	# F: a driver with inside water, fouled from behind on a clear chance, a late drop called: penalty
	var fd := {"n": 0, "pen": 0}
	for f in ALL:
		for at in [Vector2(26.2, 11.4), Vector2(26.2, 8.6)]:
			for ang in [0.0, 47.0, -47.0]:
				var p := _scene(6300 + fd.n, fd.n % 2 == 0, "2", at, _back(at, ang))
				if f != F.PRESS:
					p.select_formation(f)
					p._drop_step()
				fd.n += 1
				p._ordinary_foul(p.holder, p._marker(p.holder))
				fd.pen += 1 if _outcome(p) == "penalty" else 0
	r.check(fd.pen == fd.n, "F: a driver with inside water, fouled from behind: PENALTY %d / %d" % [fd.pen, fd.n])

	# never downgraded: whatever path the whistle took, the beaten man's penalty foul is one
	var p2 := _scene(6500, true, "C", spots[0], _back(spots[0], 47.0))
	r.check(p2.has_inside_water(p2.holder) == p2.fouled_from_behind(p2.holder, p2._marker(p2.holder)),
		"inside water and a foul from behind are the same test")

## A centre-play scene: `tag` with the ball at `at`, his own man at `at + off`, everybody else well
## out of it (and `crowd`, if given, one more defender there).
func _scene(sd: int, defending: bool, tag: String, at: Vector2, off: Vector2, crowd := Vector2.INF) -> Play:
	var p: Play = r._center_play(sd, defending)
	var a: Swimmer = null
	for s in p.attackers:
		if s.tag == tag:
			a = s
	a.pos = at
	a.target = at
	p.give_ball(a)
	var g: Swimmer = p._marker(a)
	g.pos = at + off
	g.target = g.pos
	for e in p.defenders:
		if e != g:
			e.pos = Vector2(12.0, 2.0 + p.defenders.find(e))
			e.target = e.pos
	if crowd != Vector2.INF:
		p.defenders[(p.defenders.find(g) + 1) % 6].pos = crowd
	for o in p.attackers:
		if o != a:
			o.pos = Vector2(13.0, 3.0 + p.attackers.find(o))
	p.freeze = 0.0
	p.restart = false
	p.catch_t = 1.0   # (he's had it long enough for the drop's foul on the ball: Play.DROP_CATCH_WAIT)
	return p

func _call(sd: int, defending: bool, tag: String, at: Vector2, off: Vector2) -> String:
	var p := _scene(sd, defending, tag, at, off)
	p._ordinary_foul(p.holder, p._marker(p.holder))
	return _outcome(p)

func _outcome(p: Play) -> String:
	if p.over and String(p.result.get("outcome", "")) == "penalty":
		return "penalty"
	return "foul" if p.freeze > 0.0 and not p.over else "?"

## 0.85 m behind the man at `at`, `ang` degrees off straight behind (away from the goal).
func _back(at: Vector2, ang: float) -> Vector2:
	return (at - Geo.goal_center()).normalized().rotated(deg_to_rad(ang)) * 0.85

## The formation's dropper (formed now), or failing that a defender to play him.
func _dropper_of(p: Play) -> Swimmer:
	PlayAI.update(p, 0.0)
	if p.f_dropper != null:
		return p.f_dropper
	return p.defenders[3] if p.defenders[3] != p._marker(p.holder) else p.defenders[4]
