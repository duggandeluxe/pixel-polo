extends RefCounted
## Piston pressure, the one-arm block, the penalty from behind and Developer Mode's labs:
##   godot --headless --path game -- --test piston
## Tests A-AE of the "piston drop, one-arm blocking, penalty enforcement & BAR-IN! developer mode"
## update. Staged plays with fixed seeds, played by the game's own systems.

const DT := 1.0 / 60.0
const F := DefenseFormation.F
const P := DefenseFormation.Press
const D := DefenseFormation.Duty

var r   # the test runner (check, check_between)

func run(runner) -> void:
	r = runner
	print("piston: one-arm blocking")
	_one_arm()
	for f in [F.FOUR_FIVE, F.THREE_FOUR]:
		print("piston: %s" % DefenseFormation.NAMES[f])
		_pressure(f)
	print("piston: the guaranteed block and the red X")
	_guaranteed(F.FOUR_FIVE)
	_guaranteed(F.THREE_FOUR)
	print("piston: penalties from behind")
	_penalties()
	print("piston: Developer Mode, SPECIAL GOAL EFFECTS")
	await _fx_lab()
	print("piston: Developer Mode, DEFENSIVE TESTING")
	await _defense_lab()

# ------------------------------------------------------------------ helpers
## The pistons: [the one who goes out (his man gets the ball), the other].
static func _tags(f: int) -> Array:
	return ["5", "4"] if f == F.FOUR_FIVE else ["4", "3"]

func _settled(seed_value: int, f: int, tag: String = "3", defending := true) -> Play:
	var p: Play = r._center_play(seed_value, defending)
	for s in p.attackers + p.defenders:
		s.player.trait_id = ""
	p.give_ball(PlaySetup._by_tag(p, tag))
	p.select_formation(f)
	return p

func _a(p: Play, tag: String) -> Swimmer:
	return DefenseFormation.by_tag(p.attackers, tag)

func _d(p: Play, tag: String) -> Swimmer:
	return DefenseFormation.by_tag(p.defenders, tag, true)

func _steps(p: Play, secs: float, each: Callable = Callable()) -> void:
	var t := 0.0
	while t < secs - 0.0001 and not p.over:
		p.step(DT)
		t += DT
		if each.is_valid():
			each.call()

## Runs until `cond` (or `secs`); true if it came.
func _until(p: Play, cond: Callable, secs: float) -> bool:
	var t := 0.0
	while t < secs and not p.over:
		if cond.call():
			return true
		p.step(DT)
		t += DT
	return not p.over and cond.call()

## `f` set up for 2 s with the point holding it, then the ball to the piston's man (his man stays
## where he is: nobody drives). [play, the man, his piston]. `dfn` >= 0: the piston's Defense.
func _out(seed_value: int, f: int, dfn: float = -1.0) -> Array:
	var p := _settled(seed_value, f, "2")
	var tag: String = _tags(f)[0]
	var s := _d(p, tag)
	if dfn >= 0.0:
		s.player = AttrBench.player({"dfn": dfn}, false, {}, PoloPlayer.Pos.UTILITY)
		s.top_speed = 2.1
	_steps(p, 2.0)
	p.freeze = 0.0
	p.events.clear()
	var m := _a(p, tag)
	m.vel = Vector2.ZERO
	p.give_ball(m)
	p.free_throw = false   # (a whistle while it set up: this is a new ball, not a free throw)
	p._end_restart()   # (nor a restart: Play.restart)
	return [p, m, s]

## A recorder for PoolArt's arm drawing: how many arms are up (rects at least 5 px tall).
static func _arms_up(draw: Callable) -> int:
	var acc := {"n": 0}
	var px := func(_dx: int, _dy: int, _w: int, h: int, _c: Color) -> void:
		if h >= 5:
			acc.n += 1
	draw.call(px)
	return int(acc.n)

# ------------------------------------------------------------------ A-D: one arm, always
func _one_arm() -> void:
	var skin := Color.TAN
	var s := Swimmer.new(AttrBench.player({}, false, {}, PoloPlayer.Pos.UTILITY), Swimmer.Side.THEM)
	# B: every field block, whatever way and however far he reaches (every formation draws these)
	var worst := 0
	var least := 9
	for i in range(-20, 21):
		s.dive = i / 20.0
		if absf(s.dive) < 0.2:
			continue
		var n := _arms_up(func(px): PoolArt._block_arms(px, s, skin))
		worst = maxi(worst, n)
		least = mini(least, n)
	r.check(worst == 1 and least == 1, "TEST B: a field player's block is one arm up, every reach, both ways (%d..%d)" % [least, worst])
	# A: the piston's arm, at every stage of going up
	var a_worst := 0
	for i in range(1, 21):
		a_worst = maxi(a_worst, _arms_up(func(px): PoolArt._raised_arm(px, i / 20.0, skin)))
	r.check(a_worst == 1, "TEST A: the piston's block: one arm, the other down (most up at once: %d)" % a_worst)
	# C: the keeper's untouched: set, both hands up; a lunge, his arm out and the other up
	var k := Swimmer.new(AttrBench.player({}, false, {}, PoloPlayer.Pos.GK), Swimmer.Side.THEM, true)
	k.dive = 0.0
	var set_arms := _arms_up(func(px): PoolArt._keeper_arms(px, k, skin))
	k.dive = 0.8
	var lunge := _arms_up(func(px): PoolArt._keeper_arms(px, k, skin))
	r.check(set_arms == 2 and lunge == 2, "TEST C: goalkeepers keep their own arms (set: %d up, lunging: %d)" % [set_arms, lunge])
	# B in play: PRESS, M-DROP and 5 DROP possessions with shots; every block drawn is one arm,
	# and nobody outside the pistons ever has the piston's arm up
	var bad := {"two": 0, "piston_arm": 0, "blocks": 0, "frames": 0}
	for f in [F.PRESS, F.M_DROP, F.FIVE_DROP]:
		for i in 6:
			var p := _settled(5100 + f * 10 + i, f)
			var rng := RandomNumberGenerator.new()
			rng.seed = 77 + i
			var think := 0.0
			var t := 0.0
			while not p.over and t < 30.0:
				think -= DT
				if think <= 0.0:
					think = PlayBot.THINK_EVERY
					var d := PlayBot.think(p, rng)
					if not d.is_empty():
						p.throw(d.target, d.power)
				p.step(DT)
				t += DT
				for dd in p.defenders:
					if dd.block_arm > 0.0 or dd.press != P.HOLD:
						bad.piston_arm += 1
					if absf(dd.dive) >= 0.2:
						bad.frames += 1
						if _arms_up(func(px): PoolArt._block_arms(px, dd, skin)) != 1:
							bad.two += 1
				for e in p.events:
					if String(e.k) == "block":
						bad.blocks += 1
				p.events.clear()
	r.check(bad.frames > 0 and bad.two == 0, "TEST B: PRESS, M-DROP, 5 DROP in play: %d block frames drawn, all one arm (%d blocks)" % [bad.frames, bad.blocks])
	r.check(bad.piston_arm == 0, "...and the piston's arm (pressure) never comes up outside the pistons")

# ------------------------------------------------------------------ D, I-Q: the pressure
func _pressure(f: int) -> void:
	var name: String = DefenseFormation.NAMES[f]
	var tags := _tags(f)
	var o := _out(6100 + f, f)
	var p: Play = o[0]
	var m: Swimmer = o[1]
	var s: Swimmer = o[2]
	var full := s.top_speed * s.pace
	var w := {"max_v": 0.0, "arm_early": false, "zone_early": false, "t": 0.0, "set_off": -1.0, "raise_at": -1.0,
		"block_at": -1.0, "states": [], "stalled": 0, "after_block_d": [], "fouls": 0, "foul_at": -1.0,
		"teleport": 0.0, "last": s.pos, "pistons_out": 0, "foul_dist": -1.0}
	var each := func():
		w.t += DT
		if s.press in [P.APPROACH, P.RAISE, P.BLOCK]:
			if w.set_off < 0.0:
				w.set_off = w.t
			if w.t - w.set_off > 0.15:
				w.max_v = maxf(w.max_v, s.speed())
			if s.press == P.APPROACH and s.block_arm > 0.0:
				w.arm_early = true
			if s.press != P.BLOCK and not DefenseFormation.arm_zone(s).is_empty() and float(DefenseFormation.arm_zone(s).ready) <= 0.0:
				w.zone_early = true
		if s.press == P.RAISE and w.raise_at < 0.0:
			w.raise_at = w.t
		if s.press == P.BLOCK:
			if w.block_at < 0.0:
				w.block_at = w.t
			(w.after_block_d as Array).append(s.pos.distance_to(m.pos))
			if s.speed() < 0.15:
				w.stalled += 1
		if (w.states as Array).is_empty() or (w.states as Array).back() != s.press:
			(w.states as Array).append(s.press)
		var n := 0
		for dd in p.defenders:
			if dd.press in [P.APPROACH, P.RAISE, P.BLOCK]:
				n += 1
		w.pistons_out = maxi(int(w.pistons_out), n)
		for e in p.events:
			if String(e.k) == "piston_foul":
				w.fouls += 1
				w.foul_at = w.t
				w.foul_dist = s.pos.distance_to(m.pos)
		p.events.clear()
	var got := _until(p, func() -> bool:
		each.call()
		return int(w.fouls) > 0, 12.0)
	r.check(got, "%s: D%s goes out to A%s, gets to him and fouls him" % [name, tags[0], tags[0]])
	var ratio := float(w.max_v) / maxf(full, 0.01)
	r.check_between(ratio, 0.15, 0.45, "TEST I %s: his swim out, share of his full speed" % name)
	r.check(float(w.set_off) >= 0.0 and float(w.raise_at) > float(w.set_off), "TEST D %s: his arm starts up only after his reaction" % name)
	var delay := float(w.raise_at) - float(w.set_off)
	r.check_between(delay, DefenseFormation.ARM_DELAY_RANGE.x - 0.04, DefenseFormation.ARM_DELAY_RANGE.y + 0.04, "TEST D %s: reaction before the arm, s" % name)
	r.check_between(float(w.block_at) - float(w.raise_at), DefenseFormation.ARM_RAISE - 0.04, DefenseFormation.ARM_RAISE + 0.04,
		"TEST D %s: the arm's time going up, s" % name)
	r.check(not w.arm_early and not w.zone_early, "TEST D %s: no arm in the approach, no active block before it's fully up" % name)
	var ds: Array = w.after_block_d
	r.check(ds.size() > 10 and float(ds.back()) < float(ds.front()) - 0.2 and int(w.stalled) <= 3,
		"TEST K %s: still coming with his arm up (%.2f m -> %.2f m, %d stalled frames)" % [name, float(ds.front()) if ds.size() > 0 else 0.0, float(ds.back()) if ds.size() > 0 else 0.0, int(w.stalled)])
	r.check(int(w.fouls) == 1 and float(w.foul_dist) <= DefenseFormation.FOUL_AT + 0.01 and p.freeze > 0.0 and not p.over,
		"TEST L %s: at FOUL_AT in front of him: one ordinary foul (%.2f m)" % [name, float(w.foul_dist)])
	r.check(int(w.pistons_out) == 1, "%s: only the one piston goes out (most at once: %d)" % [name, int(w.pistons_out)])
	r.check((w.states as Array).slice(0, 4) == [P.HOLD, P.APPROACH, P.RAISE, P.BLOCK] or (w.states as Array).slice(0, 3) == [P.APPROACH, P.RAISE, P.BLOCK],
		"%s: HOLD > APPROACH > RAISE > BLOCK (%s)" % [name, _names(w.states)])
	# M, N: all the way back, swimming, before anything else; the man still has the ball
	var home_d := {"min": INF, "re": false, "fouls": 0, "teleport": 0.0, "last": s.pos, "back": -1.0, "t": 0.0,
		"arm": 1.0, "zone": false}
	var watch := func():
		home_d.t += DT
		var hd := s.pos.distance_to(DefenseFormation.piston_home(p, s, m))
		home_d.teleport = maxf(float(home_d.teleport), (s.pos - (home_d.last as Vector2)).length())
		home_d.last = s.pos
		if s.press == P.RETURN:
			home_d.min = minf(float(home_d.min), hd)
			home_d.arm = s.block_arm
			home_d.zone = home_d.zone or not DefenseFormation.arm_zone(s).is_empty()
		elif s.press in [P.APPROACH, P.RAISE, P.BLOCK] and float(home_d.back) < 0.0:
			home_d.re = true
		if s.press == P.HOLD and float(home_d.back) < 0.0:
			home_d.back = home_d.t
			home_d.at_home = hd
		for e in p.events:
			if String(e.k) == "piston_foul":
				home_d.fouls += 1
		p.events.clear()
	var start_d := s.pos.distance_to(DefenseFormation.piston_home(p, s, m))
	_until(p, func() -> bool:
		watch.call()
		return float(home_d.back) >= 0.0, 12.0)
	r.check(float(home_d.back) > 0.5 and float(home_d.get("at_home", 9.0)) <= DefenseFormation.RETURN_TOL + 0.01,
		"TEST M %s: swims all the way back to his spot (%.1f m in %.2f s, ended %.2f m off it)" % [name, start_d, float(home_d.back), float(home_d.get("at_home", 9.0))])
	r.check(float(home_d.teleport) <= s.top_speed * 1.3 * DT + 0.12, "TEST M %s: no teleport (%.3f m in a frame at most)" % [name, float(home_d.teleport)])
	r.check(not home_d.re and int(home_d.fouls) == 0 and not home_d.zone,
		"TEST N %s: on the way back: no new approach, no block, no second foul (the man still has it: %s)" % [name, str(p.holder == m)])
	# ...and once he's back, with the man still on the ball, he can go again
	var again := _until(p, func() -> bool: return s.press == P.APPROACH, 2.0)
	r.check(again and p.holder == m, "TEST N %s: back on his spot, he goes again" % name)
	# J: elite and poor Defense: both slow, the better one a bit quicker and sooner with the arm
	var meas := {}
	for dv in [10.0, 1.0]:
		var q: Array = _out(6200 + f, f, dv)
		var qp: Play = q[0]
		var qs: Swimmer = q[2]
		var mm := {"v": 0.0, "t": 0.0, "raise": -1.0, "off": -1.0}
		_until(qp, func() -> bool:
			mm.t += DT
			if qs.press in [P.APPROACH, P.RAISE, P.BLOCK]:
				if float(mm.off) < 0.0:
					mm.off = mm.t
				if mm.t - float(mm.off) > 0.15:
					mm.v = maxf(float(mm.v), qs.speed())
			if qs.press == P.RAISE and float(mm.raise) < 0.0:
				mm.raise = mm.t
			return qs.press == P.BLOCK and mm.t - float(mm.off) > 1.5, 8.0)
		meas[dv] = {"share": float(mm.v) / (qs.top_speed * qs.pace), "delay": float(mm.raise) - float(mm.off)}
	r.check(float(meas[10.0].share) <= DefenseFormation.PRESS_SHARE_RANGE.y + 0.05 and float(meas[10.0].share) > float(meas[1.0].share),
		"TEST J %s: Defense 10 still swims out slowly (%.0f%% of full; Defense 1 %.0f%%)" % [name, 100.0 * float(meas[10.0].share), 100.0 * float(meas[1.0].share)])
	r.check(float(meas[10.0].delay) < float(meas[1.0].delay) and float(meas[10.0].delay) >= DefenseFormation.ARM_DELAY_RANGE.x - 0.02,
		"TEST J %s: ...his arm a little sooner (%.2f s vs %.2f s), never at once" % [name, float(meas[10.0].delay), float(meas[1.0].delay)])
	# O: a pass away before he's there: he lets it go, the arm comes down, the next man's piston goes
	var o2 := _out(6300 + f, f)
	var op: Play = o2[0]
	var om: Swimmer = o2[1]
	var os: Swimmer = o2[2]
	_until(op, func() -> bool: return os.press == P.RAISE, 3.0)
	var was := os.press
	op.freeze = 0.0
	var other := _a(op, tags[1])
	op._pass(op.lead_point(other), other)
	op.step(DT)
	var cancelled := os.press == P.HOLD and DefenseFormation.arm_zone(os).is_empty()
	_steps(op, DefenseFormation.ARM_DROP + 0.1)
	var arm_down := os.block_arm <= 0.001
	var od := _d(op, tags[1])
	var next := _until(op, func() -> bool: return od.press == P.APPROACH and op.holder == other, 2.5)
	r.check(was == P.RAISE and cancelled and arm_down, "TEST O %s: a pass away: he lets it go at once, his arm down, no block left" % name)
	r.check(next, "TEST O %s: ...and the other piston goes out to A%s (the formation's next man)" % [name, tags[1]])
	r.check(op.holder != om, "...(the first man hasn't got it)")
	print("  %s: out at %.0f%% of full speed, arm after %.2f s, fouled at %.2f m, back in %.2f s" % [name, 100.0 * ratio, delay,
		float(w.foul_dist), float(home_d.back)])

static func _names(states: Array) -> String:
	var out: PackedStringArray = []
	for x in states:
		out.append(DefenseFormation.PRESS_NAMES[int(x)])
	return " > ".join(out)

# ------------------------------------------------------------------ E-H: the guaranteed block, the red X
## The piston's arm fully up: [play, man, piston], or [] if it never came.
func _blocking(seed_value: int, f: int, extra := 0.0) -> Array:
	var o := _out(seed_value, f)
	var p: Play = o[0]
	var s: Swimmer = o[2]
	var m: Swimmer = o[1]
	if not _until(p, func() -> bool: return s.press == P.BLOCK and not is_nan(p.blocked_aim(0.7)) \
			and s.pos.distance_to(m.pos) > DefenseFormation.FOUL_AT + 0.25, 14.0):
		return []
	_steps(p, extra)
	return o if s.press == P.BLOCK and not p.over else []

## A pull aimed to cross the goal line at `cy` from the man with the ball: the target past the line.
static func _at_line(p: Play, cy: float) -> Vector2:
	var h := p.holder
	return Vector2(Geo.GOAL_X + 0.5, cy + (cy - h.pos.y) * 0.5 / maxf(Geo.GOAL_X - h.pos.x, 0.5))

## A pull aimed through `point` from the man with the ball: the target past the goal line.
static func _through(p: Play, point: Vector2) -> Vector2:
	var h := p.holder
	var dir := point - h.pos
	return h.pos + dir * ((Geo.GOAL_X + 0.6 - h.pos.x) / dir.x)

## Shoots at `target` (exactly: shoot_at) and plays it out. The shot's result.
func _fire(p: Play, target: Vector2, power: float) -> Dictionary:
	p.shoot_at(target, power)
	var sh := p.ball.shot
	_until(p, func() -> bool: return p.ball.state != Ball.State.SHOT, 3.0)
	return sh

func _guaranteed(f: int) -> void:
	var name: String = DefenseFormation.NAMES[f]
	var power := 0.7
	# E: through the hand, every time (fresh possessions, every seed its own dice)
	var e := {"n": 0, "blocked": 0, "by_him": 0, "xs": 0}
	var f2 := {"n": 0, "arm": 0, "xs": 0}
	var g := {"n": 0, "agree": 0}
	for i in 24:
		var o := _blocking(6400 + f * 50 + i, f)
		if o.is_empty():
			continue
		var p: Play = o[0]
		var s: Swimmer = o[2]
		var target := _at_line(p, p.blocked_aim(power))
		var info := p.aim_info(target)
		if String(info.mode) != "shot":
			continue
		var x := p.arm_block(float(info.cross_y), power)
		e.xs += 1 if not x.is_empty() else 0
		var sh := _fire(p, target, power)
		e.n += 1
		if String(sh.outcome) == "block":
			e.blocked += 1
		if bool(sh.get("arm", false)) and int(sh.blocker) == p.defenders.find(s):
			e.by_him += 1
	r.check(int(e.n) >= 16 and int(e.blocked) == int(e.n) and int(e.by_him) == int(e.n) and int(e.xs) == int(e.n),
		"TEST E %s: through his raised arm: blocked %d / %d, by him, the red X up every time (%d)" % [name, int(e.blocked), int(e.n), int(e.xs)])
	# F: around it (the far side of the goal from the hand): never the arm, no red X
	for i in 24:
		var o := _blocking(6500 + f * 50 + i, f)
		if o.is_empty():
			continue
		var p: Play = o[0]
		var s: Swimmer = o[2]
		var hand: Vector2 = DefenseFormation.arm_zone(s).hand
		var h := p.holder
		var side := signf(hand.y - h.pos.y)
		var cy := Geo.GOAL_Y - side * (Geo.GOAL_HALF - 0.3)
		var target := Vector2(Geo.GOAL_X + 0.5, cy + (cy - h.pos.y) * 0.5 / maxf(Geo.GOAL_X - h.pos.x, 0.5))
		var info := p.aim_info(target)
		if String(info.mode) != "shot":
			continue
		f2.xs += 0 if p.arm_block(float(info.cross_y), power).is_empty() else 1
		var sh := _fire(p, target, power)
		f2.n += 1
		f2.arm += 1 if bool(sh.get("arm", false)) else 0
	r.check(int(f2.n) >= 16 and int(f2.arm) == 0 and int(f2.xs) == 0,
		"TEST F %s: aimed round his arm: no guaranteed block (%d / %d), no red X (%d)" % [name, int(f2.arm), int(f2.n), int(f2.xs)])
	# G: a sweep across the whole goal mouth from one spot: the red X exactly where the arm blocks
	var lo := Geo.GOAL_Y - Geo.GOAL_HALF + 0.05
	for k in 21:
		var o := _blocking(6600 + f, f)
		if o.is_empty():
			continue
		var p: Play = o[0]
		var h := p.holder
		var cy := lerpf(lo, Geo.GOAL_Y + Geo.GOAL_HALF - 0.05, k / 20.0)
		var target := Vector2(Geo.GOAL_X + 0.5, cy + (cy - h.pos.y) * 0.5 / maxf(Geo.GOAL_X - h.pos.x, 0.5))
		var info := p.aim_info(target)
		if String(info.mode) != "shot":
			continue
		var x := not p.arm_block(float(info.cross_y), power).is_empty()
		var sh := _fire(p, target, power)
		g.n += 1
		g.agree += 1 if _agrees(x, sh) else 0
		g[str(x)] = int(g.get(str(x), 0)) + 1
	r.check(int(g.n) >= 18 and int(g.agree) == int(g.n) and int(g.get("true", 0)) > 0 and int(g.get("false", 0)) > 0,
		"TEST G %s: across the goal: red X <-> blocked on %d / %d aims (%d with an X, %d without)" % [name, int(g.agree), int(g.n),
			int(g.get("true", 0)), int(g.get("false", 0))])
	# H: as he comes in, the same aim: the preview moves with him and still matches the shot
	var hm := {"n": 0, "agree": 0, "at": []}
	var fixed := Vector2.INF
	for extra in [0.0, 0.3, 0.6, 0.9]:
		var o := _blocking(6700 + f, f, extra)
		if o.is_empty():
			continue
		var p: Play = o[0]
		var s: Swimmer = o[2]
		if fixed == Vector2.INF:
			fixed = _at_line(p, p.blocked_aim(power))
		var info := p.aim_info(fixed)
		var x := p.arm_block(float(info.cross_y), power)
		if not x.is_empty():
			(hm.at as Array).append(x.at)

		var sh := _fire(p, fixed, power)
		hm.n += 1
		hm.agree += 1 if _agrees(not x.is_empty(), sh) else 0
	var moved := (hm.at as Array).size() >= 2 and ((hm.at as Array).front() as Vector2).distance_to((hm.at as Array).back()) > 0.05
	r.check(int(hm.n) == 4 and int(hm.agree) == 4 and (moved or (hm.at as Array).size() < 4),
		"TEST H %s: the defender moving in: preview = shot on %d / %d, the X moving with him (%d frames with one)" % [name, int(hm.agree), int(hm.n), (hm.at as Array).size()])
	# D: the arm on its way up: a ball that gets there first goes through (no X either), one that
	# gets there after it's up doesn't
	var o3 := _out(6800 + f, f)
	var p3: Play = o3[0]
	var s3: Swimmer = o3[2]
	_until(p3, func() -> bool: return s3.press == P.RAISE, 4.0)
	var z3 := DefenseFormation.arm_zone(s3)
	var from: Vector2 = p3.holder.pos
	var dir: Vector2 = _through(p3, z3.hand) - from
	var arrive_slow := float(z3.ready) * 2.0 + 0.05
	var along := (z3.hand as Vector2).distance_to(from)
	var fast := ShotModel.arm_contact(from, dir, along / maxf(float(z3.ready) * 0.5, 0.001), z3)
	var slow := ShotModel.arm_contact(from, dir, along / arrive_slow, z3)
	r.check(s3.press == P.RAISE and float(z3.ready) > 0.0 and fast.is_empty() and not slow.is_empty(),
		"TEST D %s: arm going up (%.2f s to go): a ball there before it's through, one after it's up is blocked" % [name, float(z3.ready)])
	# ShotModel itself: a thousand shots through a fully raised arm, the bots' spread switched off
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var arm := {"i": 4, "hand": Vector2(26.0, 10.2), "r": DefenseFormation.ARM_R, "ready": 0.0}
	var all := 0
	for i in 1000:
		var res := ShotModel.resolve(Vector2(24.8, 10.2), 10.2 + rng.randf_range(-0.05, 0.05), rng.randf_range(0.3, 1.0), rng.randf_range(20, 95),
			1.0, [], Geo.GOAL_Y, 60.0, rng, false, {}, {"exact": true, "arms": [arm]})
		all += 1 if String(res.outcome) == "block" and int(res.blocker) == 4 and bool(res.get("arm", false)) else 0
	if f == F.FOUR_FIVE:
		r.check(all == 1000, "TEST E: ShotModel, 1000 shots through a raised arm: %d blocked (no dice)" % all)

## The red X (`x`) and the shot that was thrown agree: an X is a block, every time; no X, his arm
## never blocked it.
static func _agrees(x: bool, sh: Dictionary) -> bool:
	var ok := String(sh.get("outcome", "")) == "block" if x else not bool(sh.get("arm", false))
	if not ok:
		print("    mismatch: X %s, outcome %s, arm %s, blocker %d" % [str(x), sh.get("outcome", "none"), str(sh.get("arm", false)), int(sh.get("blocker", -1))])
	return ok

# ------------------------------------------------------------------ R-X: from behind
## The man with the ball (`tag`) at `at`, `d` (his marker) put `off` from him; everybody else out of
## the way unless `crowd`. The whistle (Play._ordinary_foul): "penalty" or "foul".
func _whistle(seed_value: int, at: Vector2, off: Vector2, tag := "2", defending := true, kind := Play.Kind.HALF_COURT,
		crowd: Vector2 = Vector2.INF) -> String:
	var p: Play = r._center_play(seed_value, defending)
	if kind == Play.Kind.COUNTER:
		p.kind = kind
		p.carry = true
	var a := _a(p, tag)
	a.pos = at
	p.give_ball(a)
	var d: Swimmer = p._marker(a)
	d.pos = at + off
	for e in p.defenders:
		if e != d:
			e.pos = Vector2(12.0, 2.0 + p.defenders.find(e))
	if crowd != Vector2.INF:
		p.defenders[(p.defenders.find(d) + 1) % 6].pos = crowd
	for o in p.attackers:
		if o != a:
			o.pos = Vector2(13.0, 3.0 + p.attackers.find(o))
	p._ordinary_foul(a, d)
	if p.over and String(p.result.outcome) == "penalty":
		return "penalty"
	return "foul" if p.freeze > 0.0 else "?"

func _penalties() -> void:
	var goal := Geo.goal_center()
	# R: a counter, beaten, fouled on his back in the box: a penalty, every time, from anywhere in it
	var rr := {"n": 0, "pen": 0}
	for i in 40:
		var y := Geo.GOAL_Y + (i % 9 - 4) * 0.35
		var x := 25.4 + (i % 5) * 0.55
		var at := Vector2(x, y)
		var back := (at - goal).normalized() * (0.7 + (i % 3) * 0.25)
		rr.n += 1
		rr.pen += 1 if _whistle(7000 + i, at, back, "2", i % 2 == 0, Play.Kind.COUNTER) == "penalty" else 0
	r.check(int(rr.pen) == int(rr.n), "TEST R: counterattack, fouled from behind with a clear chance: penalty %d / %d" % [int(rr.pen), int(rr.n)])
	# ...including where the old rule gave a free throw: a real chance (not a probable goal), the way open
	var p0: Play = r._center_play(7050, true)
	var a0 := _a(p0, "2")
	a0.pos = Vector2(25.6, Geo.GOAL_Y + 0.5)
	p0._marker(a0).pos = a0.pos + Vector2(-0.9, -0.1)
	r.check(not CenterDefense.probable(p0, a0) and p0.close_chance(a0) > 0.0
		and _whistle(7051, a0.pos, Vector2(-0.9, -0.1)) == "penalty",
		"TEST R: a real chance in the box that isn't a 'probable goal', open, fouled from behind: penalty (was a free throw)")
	# S: the centre with it at 2 m, his man on his back
	r.check(_whistle(7100, Vector2(28.0, Geo.GOAL_Y), Vector2(-0.8, 0.0), "C") == "penalty", "TEST S: the centre with it at 2 m, fouled from behind: penalty")
	r.check(_whistle(7101, Vector2(27.6, Geo.GOAL_Y + 0.8), Vector2(-0.7, 0.3), "C", false) == "penalty", "TEST S: ...turned a little, your centre: penalty")
	# T: in front of him (goal side), beside him: an ordinary foul
	r.check(_whistle(7200, Vector2(26.4, Geo.GOAL_Y), Vector2(0.85, 0.0)) == "foul", "TEST T: in front of him: an ordinary foul")
	r.check(_whistle(7201, Vector2(26.4, Geo.GOAL_Y), Vector2(-0.1, 0.85)) == "foul", "TEST T: beside him: an ordinary foul")
	r.check(_whistle(7202, Vector2(26.4, Geo.GOAL_Y), Vector2(-0.1, 0.0)) == "foul", "TEST T: a few cm off behind isn't behind: an ordinary foul")
	r.check(_whistle(7203, Vector2(25.6, Geo.GOAL_Y + 0.5), Vector2(-0.9, -0.1), "2", true, Play.Kind.HALF_COURT, Vector2(27.4, Geo.GOAL_Y + 0.3)) == "foul",
		"TEST T: from behind, but a defender between him and the goal and no probable goal: no clear chance, a free throw")
	# U: from behind far out: ordinary, as always
	r.check(_whistle(7300, Vector2(18.0, Geo.GOAL_Y), Vector2(-0.9, 0.0)) == "foul", "TEST U: midfield, from behind: an ordinary foul")
	r.check(_whistle(7301, Vector2(23.0, Geo.GOAL_Y + 1.0), Vector2(-0.9, 0.0)) == "foul", "TEST U: outside the box (7 m), from behind: an ordinary foul")
	# V: whichever way he's attacking: the geometry turns with the goal
	var gl := Vector2(0.0, Geo.GOAL_Y)
	var gr := Vector2(Geo.GOAL_X, Geo.GOAL_Y)
	r.check(Play.behind(Vector2(4.0, 10.0), Vector2(4.9, 10.0), gl) and not Play.behind(Vector2(4.0, 10.0), Vector2(3.1, 10.0), gl)
		and Play.behind(Vector2(26.0, 10.0), Vector2(25.1, 10.0), gr) and not Play.behind(Vector2(26.0, 10.0), Vector2(26.9, 10.0), gr),
		"TEST V: behind him is away from the goal he's attacking, at either end")
	r.check(Play.behind(Vector2(4.0, 12.0), Vector2(4.7, 12.6), gl) == Play.behind(Vector2(26.0, 8.0), Vector2(25.3, 7.4), gr)
		and Play.behind(Vector2(4.0, 12.0), Vector2(4.0, 12.9), gl) == Play.behind(Vector2(26.0, 8.0), Vector2(26.0, 7.1), gr),
		"TEST V: ...the same calls mirrored end to end")
	# W: your defence and theirs (the AI plays both): the same whistle for the same water
	var same := true
	for c in [[Vector2(26.0, 10.4), Vector2(-0.8, 0.1)], [Vector2(26.0, 10.4), Vector2(0.8, 0.1)], [Vector2(19.0, 9.0), Vector2(-0.8, 0.0)]]:
		same = same and _whistle(7400, c[0], c[1], "2", true) == _whistle(7400, c[0], c[1], "2", false)
	r.check(same, "TEST W: their attack (your defenders) and yours (theirs): identical calls")
	# X: a piston who's got round behind the man in the box: his contact is a penalty
	var p := _settled(7500, F.FOUR_FIVE)
	_steps(p, 2.0)
	p.freeze = 0.0
	var m := _a(p, "5")
	m.pos = Vector2(26.6, Geo.GOAL_Y - 1.4)
	m.vel = Vector2.ZERO
	var s := _d(p, "5")
	s.pos = m.pos + (m.pos - goal).normalized() * 0.85
	s.vel = Vector2.ZERO
	for e in p.defenders:
		if e != s and e.pos.distance_to(m.pos + (goal - m.pos) * 0.5) < 1.5:
			e.pos += Vector2(-2.0, 0.0)
	p.f_in = _d(p, "4")
	p.f_want_in = p.f_in
	p.give_ball(m)
	var pen := {"piston": false}
	# the formation's own frame (he goes: HOLD -> APPROACH) and its contact check, nobody moved in
	# between (in play, the inside-water battle shoves the two apart in a frame or two)
	PlayAI.update(p, DT)
	DefenseFormation.piston_contact(p)
	for ev in p.events:
		if String(ev.k) == "piston_foul":
			pen.piston = true
	r.check(pen.piston and p.over and String(p.result.get("outcome", "")) == "penalty",
		"TEST X: a piston fouling from behind on a clear chance: penalty, not his ordinary foul (%s)" % String(p.result.get("outcome", "foul")))
	# the computer's read: a pull from behind on a clear chance is costed as the penalty it is
	var q: Play = r._center_play(7600, true)
	var qa := _a(q, "2")
	qa.pos = Vector2(25.6, Geo.GOAL_Y + 0.5)
	q.give_ball(qa)
	var qd: Swimmer = q._marker(qa)
	qd.pos = qa.pos + Vector2(-0.9, -0.1)
	for e in q.defenders:
		if e != qd:
			e.pos = Vector2(12.0, 2.0 + q.defenders.find(e))
	var v := CenterDefense.values(q, qd, qa)
	var conv := CenterDefense.CONVERT * q.close_chance(qa)
	var pt := CenterDefense.through_chance(qd, qa)
	r.check(not CenterDefense.probable(q, qa) and v.has(CenterDefense.Act.DESPERATE) and absf(float(v[CenterDefense.Act.DESPERATE]) - (pt * conv + (1.0 - pt) * CenterDefense.PEN_XG)) < 0.001,
		"the AI defender reads a pull from behind on a clear chance as a penalty")

# ------------------------------------------------------------------ Y-AE: Developer Mode
func _fx_lab() -> void:
	var career_before = Game.career
	var stats_before := str(Game.career.to_dict()) if Game.career != null and Game.career.has_method("to_dict") else ""
	var dev_was: bool = Game.settings.get("dev_mode", false)
	Game.settings.dev_mode = true
	Game.goto("fx_lab")
	await r.get_tree().process_frame
	await r.get_tree().process_frame
	var lab = Game.current_screen
	r.check(lab != null and lab.has_method("run"), "SPECIAL GOAL EFFECTS opens (Settings > Developer Mode)")
	if lab == null or not lab.has_method("run"):
		Game.settings.dev_mode = dev_was
		return
	var cases := [["left", false, BarHit.Kind.LEFT_POST, "BAR-IN!", "Y"], ["right", false, BarHit.Kind.RIGHT_POST, "BAR-IN!", "Z"],
		["bar", false, BarHit.Kind.CROSSBAR, "BAR-DOWN!", "AA"], ["ul", false, BarHit.Kind.LEFT_POST, "BAR-IN!", "AB"],
		["ul", true, BarHit.Kind.CROSSBAR, "BAR-DOWN!", "AB"], ["ur", false, BarHit.Kind.RIGHT_POST, "BAR-IN!", "AB"],
		["ur", true, BarHit.Kind.CROSSBAR, "BAR-DOWN!", "AB"]]
	var shows := 0
	for c: Array in cases:
		lab.corner_bar = bool(c[1])
		var seen := await _watch_lab(lab, String(c[0]))
		shows += 1
		var phases: Array = seen.phases
		var full := phases.has(BarHit.Phase.HIT_STOP) and phases.has(BarHit.Phase.RICOCHET) and phases.has(BarHit.Phase.NET_IMPACT) \
			and phases.has(BarHit.Phase.COMPLETE)
		r.check(int(seen.kind) == int(c[2]) and String(seen.text) == String(c[3]) and full and seen.net and seen.goal_show and seen.settled,
			"TEST %s: %s%s: %s off the %s, hit-stop, ricochet, net, GOAL!, settled (kind %d, '%s', %d phases)" % [c[4], String(c[0]).to_upper(),
				(" (corner: bar)" if c[1] else ""), c[3], ["", "left post", "right post", "bar"][int(c[2])], int(seen.kind), seen.text, phases.size()])
		if String(c[0]) == "left":
			var side_ok := float(seen.net_y) > Geo.GOAL_Y
			r.check(side_ok, "TEST Y: ...across into the right side netting (%.2f)" % float(seen.net_y))
		elif String(c[0]) == "right":
			r.check(float(seen.net_y) < Geo.GOAL_Y, "TEST Z: ...across into the left side netting (%.2f)" % float(seen.net_y))
	# AC: every press, the effect: no die (the natural chance this tight is ~37 %)
	var on := 0
	for i in 12:
		lab.corner_bar = false
		lab.run(["left", "right", "bar"][i % 3])
		on += 1 if lab.play.ball.bar_on() else 0
	r.check(on == 12, "TEST AC: the tests bypass the die: %d / 12 shown off the frame" % on)
	r.check(BarHit.chance(BarHit.DEMO_GAP) < 0.5, "...where the normal chance would be %.0f %%" % (100.0 * BarHit.chance(BarHit.DEMO_GAP)))
	# REPLAY LAST: the last test again
	lab.last = "bar"
	var rep := await _watch_lab(lab, "")
	r.check(int(rep.kind) == BarHit.Kind.CROSSBAR, "REPLAY LAST plays the last test again (the crossbar)")
	shows += 1
	# AE: nothing counted, one show per preview
	r.check(lab.scratch.score == [0, 0] and (lab.scratch.goal_by[0] as Array).is_empty() and int(lab.goals_shown) >= shows,
		"TEST AE: %d previews, %d GOAL! shows, nothing on the scratch board (%s)" % [shows, int(lab.goals_shown), str(lab.scratch.score)])
	var after := str(Game.career.to_dict()) if Game.career != null and Game.career.has_method("to_dict") else ""
	r.check(Game.career == career_before and after == stats_before, "TEST AE: no career, statistic, standing or save touched")
	# the match probability override: ALWAYS / NEVER for real goals, still only tight to the frame
	var rng := RandomNumberGenerator.new()
	var tight := {"outcome": "goal", "cross_y": Geo.GOAL_Y - 1.36, "height": 0.45}
	var middle := {"outcome": "goal", "cross_y": Geo.GOAL_Y + 0.1, "height": 0.4}
	var counts := {"always": 0, "never": 0, "middle": 0, "normal": 0}
	var teams: Array = r._teams()
	for i in 40:
		rng.seed = 900 + i
		for mode in [BarHit.Override.ALWAYS, BarHit.Override.NEVER, BarHit.Override.NORMAL]:
			for res: Dictionary in [tight, middle]:
				var p := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, rng)
				p.bar_fx = true
				p.bar_mode = mode
				p.give_ball(_a(p, "3"))
				p.holder.pos = Vector2(24.6, Geo.GOAL_Y + i * 0.03)
				var shot := res.duplicate()
				shot["end"] = Vector2(Geo.GOAL_X, float(shot.cross_y))
				shot["speed"] = 14.0
				shot["flight"] = 0.4
				p._launch(p.holder, shot, 0.7)
				var shown := p.ball.bar_on()
				if res == middle:
					counts.middle += 1 if shown else 0
				elif mode == BarHit.Override.ALWAYS:
					counts.always += 1 if shown else 0
				elif mode == BarHit.Override.NEVER:
					counts.never += 1 if shown else 0
				else:
					counts.normal += 1 if shown else 0
	r.check(int(counts.always) == 40 and int(counts.never) == 0 and int(counts.middle) == 0,
		"PROBABILITY: ALWAYS %d / 40 tight goals, NEVER %d, a goal in the middle never (%d)" % [int(counts.always), int(counts.never), int(counts.middle)])
	r.check(int(counts.normal) > 0 and int(counts.normal) < 40, "PROBABILITY: NORMAL is the normal die (%d / 40)" % int(counts.normal))
	# AD: Developer Mode off: no override reaches a match, and none is ever saved
	BarHit.override = BarHit.Override.ALWAYS
	r.check(BarHit.mode_for(false) == BarHit.Override.NORMAL and BarHit.mode_for(true) == BarHit.Override.ALWAYS,
		"TEST AD: Developer Mode off: the match plays NORMAL whatever the lab was set to")
	Game.settings.dev_mode = false
	Game.match_cfg = {"us": League.make_team(2, 1), "them": League.make_team(3, 1), "seed": 9, "minutes": 2.0}
	Game.goto("match", Game.match_cfg)
	await r.get_tree().process_frame
	var ms = Game.current_screen
	ms.flow._start_attack(Play.Kind.HALF_COURT)
	ms._process(DT)
	r.check(ms.flow.play.bar_fx and ms.flow.play.bar_mode == BarHit.Override.NORMAL, "TEST AD: ...a real match with it off: BAR-IN! on, the normal die")
	r.check(not Game.settings.has("bar_override") and not str(Game.settings).contains("ALWAYS"), "TEST AD: the override is never saved with the settings")
	BarHit.override = BarHit.Override.NORMAL
	r.check(Play.new(League.make_team(2, 1), League.make_team(3, 1), Play.Kind.HALF_COURT, rng).bar_mode == BarHit.Override.NORMAL,
		"TEST AD: a possession's die is the normal one unless the screen says otherwise")
	Game.settings.dev_mode = dev_was
	Game.goto("title")
	await r.get_tree().process_frame

## Runs lab test `key` ("" REPLAY LAST) frame by frame to the end and the lab settling: what was seen.
func _watch_lab(lab, key: String) -> Dictionary:
	if key == "":
		lab.run(lab.last)
	else:
		lab.run(key)
	var p: Play = lab.play
	var seen := {"kind": int(p.ball.bar.get("kind", 0)), "text": String(p.ball.bar.get("text", "")), "phases": [], "net": false,
		"net_y": 0.0, "goal_show": false, "settled": false}
	var n := 0
	while n < 900:
		lab._process(DT)
		n += 1
		var b: BarHit = lab.bar_show
		if b.phase != BarHit.Phase.NONE and not (seen.phases as Array).has(b.phase):
			seen.phases.append(b.phase)
		if p.ball.net_t >= 0.0 and not seen.net:
			seen.net = true
			seen.net_y = p.ball.pos.y
		if lab.goal_show.active() and lab.goal_show.stage >= GoalShow.Stage.IMPACT:
			seen.goal_show = true
		if lab.play != p:
			seen.settled = lab.paused
			break
	return seen

func _defense_lab() -> void:
	var dev_was: bool = Game.settings.get("dev_mode", false)
	Game.settings.dev_mode = true
	Game.goto("defense_lab")
	await r.get_tree().process_frame
	await r.get_tree().process_frame
	var lab = Game.current_screen
	r.check(lab != null and lab.has_method("run"), "DEFENSIVE TESTING opens (Settings > Developer Mode)")
	if lab == null or not lab.has_method("run"):
		Game.settings.dev_mode = dev_was
		return
	for key in ["45", "34"]:
		var ok: bool = lab.run(key)
		var p: Play = lab.play
		r.check(ok and p.formation == (F.FOUR_FIVE if key == "45" else F.THREE_FOUR) and lab.presser != null,
			"TEST %s PISTON PRESSURE: set up, the ball to the piston's man" % ("4-5" if key == "45" else "3-4"))
		var seen := {"states": {}}
		for i in 360:
			lab._process(DT)
			seen.states[lab.presser.press] = true
		r.check(seen.states.has(P.APPROACH) and seen.states.has(P.BLOCK), "...he goes out and gets his arm up (live, in the lab)")
	r.check(lab.run("arm") and lab.presser.press == P.BLOCK and lab.paused and lab.presser.block_arm >= 1.0,
		"TEST ACTIVE ONE-ARM BLOCK: held still with his arm fully up")
	r.check(lab.run("aim") and lab.aim.active, "TEST GUARANTEED BLOCK INDICATOR: an aim set through his hand")
	var p2: Play = lab.play
	var info: Dictionary = p2.aim_info(lab.aim.target(p2.holder))
	var x: Dictionary = p2.arm_block(float(info.cross_y), lab.aim.power(p2.holder))
	r.check(String(info.mode) == "shot" and not x.is_empty(), "...the line stops on his hand: the red X")
	lab.shoot_aimed()
	var res: Dictionary = p2.ball.shot
	for i in 120:
		lab._process(DT)
	r.check(String(res.get("outcome", "")) == "block" and bool(res.get("arm", false)), "...and SHOOT is blocked by his arm")
	lab.run("pen")
	r.check(lab.play.over and String(lab.play.result.get("outcome", "")) == "penalty" and String(lab.verdict).ends_with("PENALTY"),
		"TEST COUNTERATTACK PENALTY: from behind on the break: PENALTY! (%s)" % lab.verdict)
	Game.settings.dev_mode = dev_was
	Game.goto("title")
	await r.get_tree().process_frame

# ------------------------------------------------------------------ screenshots
## godot --path game -- --test piston_png <outdir>: the labs at their moments (needs a window).
static func shots(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var save := func(name: String) -> void:
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	Game.settings.dev_mode = true
	Game.goto("defense_lab")
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	var lab = Game.current_screen
	lab.run("45")
	for i in 40:
		await runner.get_tree().process_frame
	await save.call("piston_approach")
	lab.run("arm")
	await runner.get_tree().process_frame
	await save.call("piston_block")
	lab.run("aim")
	await runner.get_tree().process_frame
	await save.call("piston_red_x")
	lab.run("pen")
	for i in 12:
		await runner.get_tree().process_frame
	await save.call("counter_penalty")
	Game.goto("fx_lab")
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	var fx = Game.current_screen
	for c in [["left", false], ["bar", false], ["ul", true]]:
		fx.corner_bar = c[1]
		fx.run(c[0])
		var n := 0
		var shot := {"hit": false, "word": false}
		while n < 300 and not shot.word:
			await runner.get_tree().process_frame
			n += 1
			var b: BarHit = fx.bar_show
			if b.phase == BarHit.Phase.HIT_STOP and not shot.hit:
				shot.hit = true
				await save.call("fx_%s_contact" % c[0])
			elif b.active() and b.t > 0.25 and not shot.word:
				shot.word = true
				await save.call("fx_%s_word" % c[0])
	Game.goto("settings")
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	await save.call("settings_dev")
	Game.goto("title")
