class_name PlayAI
## Where everybody swims. Attackers hold their spots in the formation and now and then one of
## them makes a release: a short drive off his spot (never more than RELEASE_MAX from it, one man
## at a time), then back to it. Defenders mark goal-side with a reaction lag, so a release opens
## up a passing lane for a moment. On a power play the five defenders zone up (ManDownZone: a lane
## each, the ball side stepping out) and one attacker is left free. Counters and the breakout swim free: the discipline is for the settled attack.
##
## Their attack (`defending`, OffenseAI's) also plays the water: a man left alone steps in
## towards the goal (the point never inside 6 m), a man with a defender in his passing lane
## slides to open it, drives go to the biggest gap, and the man with the ball can drive it in
## himself. In both attacks the centre's guard holds a side of him and the centre fights to keep
## him there (_center_guard_spot, _center_seal), and every few seconds the centre wins inside
## water for a moment (_center_battle).

const DRIVE_TIME := 2.4
## Formation discipline in the settled attack: a release (an off-ball drive, a give-and-go, a
## drive with the ball) goes at most RELEASE_MAX off his spot, and a man not releasing drifts at
## most SPOT_MAX off it (stepping into open water, opening a lane).
const RELEASE_MAX := 1.8
const SPOT_MAX := 1.0
const RELEASE_EVERY := Vector2(5.0, 8.0)   # your attack: an automatic release this often
## Their attack (see _open_spot, _gap_drive)
const OPEN_STEP_IN := 2.4      # nobody within this of him: he steps in towards the goal
const LANE_SLIDE := 0.8        # a defender in his passing lane: he slides this far to open it
const GAP_DRIVE_EVERY := Vector2(4.0, 6.5)
const GAP_DRIVE_MIN := 1.4     # the drive needs at least this much room (lane + half the space at the end)

static func update(p: Play, dt: float) -> void:
	if p.kind == Play.Kind.PENALTY:
		_keeper(p)
		return
	if p.breakout:
		_breakout(p, dt)
		_keeper(p)
		return
	_center_battle(p, dt)
	_attack(p, dt)
	_schedule_drive(p, dt)
	_defend(p, dt)
	_keeper(p)

# ------------------------------------------------------------------ attack
static func _attack(p: Play, dt: float) -> void:
	var loose_chaser := _loose_chaser(p) if p.ball.state == Ball.State.LOOSE else null
	if p.carry:
		ensure_lanes(p)
	for a in p.attackers:
		a.boost = 1.0
		if p.counter_t > 0.0 or p.carry:
			a.boost = PlaySetup.BREAK_SWIM
		if a == p.holder:
			_carry(p, a, dt)
			continue
		if p.ball.state == Ball.State.PASS and a == p.ball.receiver:
			a.target = run_onto(a, p.ball.to, true, (1.0 - p.ball.t) * p.ball.dur) if p.carry else p.ball.to
			a.boost = 1.2
			continue
		if a == loose_chaser:
			a.target = run_onto(a, p.ball.pos, false) if p.carry else p.ball.pos
			a.boost = 1.25
			continue
		if a.drive_t > 0.0:
			a.drive_t -= dt
			a.called = maxf(0.0, a.called - dt)
			a.target = a.drive_goal
			a.boost = 1.45 if a.called > 0.0 else 1.3
			if a.pos.distance_to(a.drive_goal) < 0.4:
				a.drive_t = minf(a.drive_t, 0.7)
			continue
		if p.carry:
			a.target = _break_spot(p, a)
			continue
		var wob := Vector2(sin(a.anim * 0.35 + a.home.y), cos(a.anim * 0.27 + a.home.x)) * 0.3
		var slide := DefenseFormation.slide_spot(p, a)
		if slide != Vector2.INF:
			a.target = slide + wob * 0.3   # 5 DROP: his man's gone, so in he slides
			continue
		if a.tag == "C" and p.man_up <= 0.0:
			a.target = _center_seal(p, a) + wob * 0.3
			continue
		a.target = (_open_spot(p, a) if p.defending else a.home) + wob
		if a.tag == "3" and p.man_up <= 0.0:
			a.target.x = minf(a.target.x, PlaySetup.POINT_MAX_X)   # the point stays outside 6 m

## On the break, a man without the ball: in the break, he races down his lane (break_lane) level
## with or just ahead of the ball, for the pass, all the way down to BREAK_DEEP; trailing, he goes
## to his spot to set up. The centre goes straight to 2 m. A man already ahead of the ball keeps
## swimming on (LANE_CREEP), never back to it, and he joins his lane on a slant (LANE_SLOPE), not
## straight across the pool.
const BREAK_DEEP := 26.6
const BREAK_LANE_W := 4.0      # (no lanes given out yet) either side of the carrier, this far across
const BREAK_WALL := Vector2(3.5, 16.5)
const BREAK_AHEAD := 1.5       # level with the ball, or this far ahead of it
const LANE_CREEP := 0.6        # ahead of that already: he still swims on (Swimmer.step: 3x this, m/s)
const LANE_SLOPE := 0.6        # at most this far across for every metre down the pool, getting into his lane

## With the ball in the air or loose, who's in the break is judged from where it was thrown, not
## where it's going (a ball thrown on ahead of everybody doesn't leave them all trailing), and
## nobody in it turns back: he keeps on down his lane.
static func _break_spot(p: Play, a: Swimmer) -> Vector2:
	var b := p.holder.pos if p.holder != null else (p.ball.to if p.ball.state == Ball.State.PASS else p.ball.pos)
	var from := p.holder.pos if p.holder != null else p.ball.from
	if a.tag == "C" or a.pos.x < from.x - Play.BREAK_TRAIL:
		return a.home
	var x := maxf(b.x + BREAK_AHEAD, a.pos.x + LANE_CREEP)
	if p.holder == null:
		x = maxf(x, a.pos.x + 1.0)
	x = minf(x, maxf(BREAK_DEEP, a.pos.x))
	var y := break_lane(p, a, b)
	var dx := maxf(x - a.pos.x, 0.5)
	y = a.pos.y + clampf(y - a.pos.y, -dx * LANE_SLOPE - 0.3, dx * LANE_SLOPE + 0.3)
	return Vector2(x, y)

## On the break a man going for a ball in front of him (a lead pass, or one gone loose) swims
## straight through it towards their goal, so he takes it in his stride instead of pulling up at
## it, and he never turns round for one thrown on past him. Level with where a pass is coming
## down, he swims on (it's caught within Play.CATCH_R). Only a ball behind him sends him back.
## `secs`: the time the pass has left in the air. If he'd get there before it at full speed he
## times his run instead, so he's just past where it lands (CATCH_AHEAD) as it lands, still
## swimming at the goal, rather than racing past it and having to come back.
const RUN_THROUGH := 2.0
const CATCH_AHEAD := 0.5
const RUN_TOP := 1.2           # (his boost going for a pass: PlayAI._attack)
const STEP_GAIN := 3.0         # Swimmer.step swims at up to 3x the distance to his target a second
static func run_onto(a: Swimmer, at: Vector2, in_air: bool, secs := INF) -> Vector2:
	var to := at - a.pos
	if to.x < -Play.CATCH_R or (to.x <= 0.0 and not in_air):
		return at
	if in_air and secs < INF:
		var v := (at + Vector2(CATCH_AHEAD, 0.0) - a.pos) / maxf(secs, 0.05)
		v.x = maxf(v.x, 0.0)   # never back for it
		if v.length() < a.top_speed * RUN_TOP:
			return a.pos + v / STEP_GAIN
	if to.x <= 0.0 or to.length() < 0.05:
		return Vector2(a.pos.x + RUN_THROUGH, at.y)
	return at + to.normalized() * RUN_THROUGH

## Who goes for a loose ball: the nearest man; on the break, the man it was thrown to while he's
## still running onto it (a ball in front of him, nearer him than RUN_ON_R).
const RUN_ON_R := 4.0
static func _loose_chaser(p: Play) -> Swimmer:
	var r := p.ball.receiver
	if p.carry and r != null and not r.out and p.attackers.has(r) and p.ball.pos.x >= r.pos.x \
			and r.pos.distance_to(p.ball.pos) < RUN_ON_R:
		return r
	return _nearest(p.attackers, p.ball.pos)

# ------------------------------------------------------------------ counter lanes
## The break runs in three lanes down the pool towards their goal: TOP (-1, up the screen), MIDDLE
## (0) and BOTTOM (+1). Each man in the break (the carrier too; not the centre, who goes to 2 m)
## gets one when the break starts (assign_lanes) and keeps it: three men take all three, in the
## order they're across the pool, so nobody crosses anybody; two take TOP and BOTTOM (the
## carrier swims the inside half of his, into the middle: lane_y); one goes straight in. Lanes
## are only handed out again when who's in the break changes, and then everyone who still can
## keeps his. The lanes are LANE_W_FAR apart up the pool, narrowing to LANE_W_NEAR at BREAK_DEEP
## (the posts). They guide the swim: nobody's held on a line (Play._move still shoves, and a pass
## or a loose ball takes a man off his lane).
const LANE_W_FAR := 5.0
const LANE_W_NEAR := 3.6
const LANE_FROM_X := 15.0
const LANE_CARRIER := 0.5      # the carrier in a two-man break: this share of his lane's width out
const LANE_CARRY_UNTIL := 23.0 # ...and he holds his lane only to here, then goes in for the goal

## The men in the break who get a lane: level with the ball or close behind it (Play.BREAK_TRAIL),
## not the centre, at most Play.BREAK_FRONT of them (the carrier first, then the furthest up).
static func lane_men(p: Play) -> Array[Swimmer]:
	var from := p.holder.pos if p.holder != null else p.ball.from
	var men: Array[Swimmer] = []
	for a in p.attackers:
		if a.out or (a.tag == "C" and a != p.holder):
			continue
		if a == p.holder or a.pos.x >= from.x - Play.BREAK_TRAIL:
			men.append(a)
	men.sort_custom(func(x: Swimmer, y: Swimmer):
		if x == p.holder or y == p.holder:
			return x == p.holder
		return x.pos.x > y.pos.x)
	return men.slice(0, Play.BREAK_FRONT)

static func _lane_key(men: Array[Swimmer]) -> String:
	var ids: Array[String] = []
	for m in men:
		ids.append(str(m.get_instance_id()))
	ids.sort()
	return ",".join(ids)

## Hands out lanes again if who's in the break has changed (PlayAI._attack, every frame on the break).
static func ensure_lanes(p: Play) -> void:
	if p.holder == null and p.ball.state != Ball.State.PASS:
		return   # (a loose ball: wait for somebody to have it before judging who's in the break)
	var men := lane_men(p)
	if _lane_key(men) != p.lane_key:
		assign_lanes(p, men)

static func assign_lanes(p: Play, men: Array[Swimmer] = []) -> void:
	if men.is_empty():
		men = lane_men(p)
	var free: Array[int] = [0]
	if men.size() >= 3:
		free = [-1, 0, 1]
	elif men.size() == 2:
		free = [-1, 1]
	var lanes := {}
	var rest: Array[Swimmer] = []
	for m in men:
		var had: int = p.lanes.get(m, 99)
		if had in free:
			lanes[m] = had
			free.erase(had)
		else:
			rest.append(m)
	rest.sort_custom(func(x: Swimmer, y: Swimmer): return x.pos.y < y.pos.y)
	for i in rest.size():
		lanes[rest[i]] = free[i]
	p.lanes = lanes
	p.lane_key = _lane_key(men)

## The y of `lane` at `x` down the pool. `carrier`: the man with the ball in a break of two or
## fewer swims the inside of his (LANE_CARRIER).
static func lane_y(lane: int, x: float, carrier := false, men := 3) -> float:
	var w := lerpf(LANE_W_FAR, LANE_W_NEAR, clampf((x - LANE_FROM_X) / (BREAK_DEEP - LANE_FROM_X), 0.0, 1.0))
	if carrier and men <= 2:
		w *= LANE_CARRIER
	return clampf(Geo.GOAL_Y + lane * w, BREAK_WALL.x, BREAK_WALL.y)

## The lane (y) for `a` on a break with the ball at `b`: his own (assign_lanes). Before lanes are
## given out, as it always was: the men with the carrier spread wide of him, one either side.
## A lane that would be in the wall goes to the other side.
static func break_lane(p: Play, a: Swimmer, b: Vector2) -> float:
	if p.lanes.has(a):
		return lane_y(int(p.lanes[a]), maxf(a.pos.x, b.x), a == p.holder, p.lanes.size())
	var mates: Array[Swimmer] = []
	for m in p.attackers:
		if m != p.holder and not m.out and m.tag != "C" and m.pos.x >= b.x - Play.BREAK_TRAIL:
			mates.append(m)
	mates.sort_custom(func(x: Swimmer, y: Swimmer): return x.pos.y < y.pos.y)
	var side := signf(a.pos.y - b.y)
	if mates.size() >= 2:
		side = -1.0 if mates.find(a) == 0 else 1.0
	if side == 0.0:
		side = 1.0 if b.y < Geo.GOAL_Y else -1.0
	var y := b.y + side * BREAK_LANE_W
	if y < BREAK_WALL.x or y > BREAK_WALL.y:
		y = b.y - side * BREAK_LANE_W
	return clampf(y, BREAK_WALL.x, BREAK_WALL.y)

## The man with the ball. Ball up to throw, he stops. On a counter he swims it in hard, down his
## lane (assign_lanes) and then in at the goal, right to COUNTER_STOP from it (he can let fly any
## time on the way: the AI only inside 6 m, Geo.in_shot_range); if he gets there without
## a shot the attack sets up and he takes it back out to his spot. Otherwise, ball down, he
## swims it to his spot; caught on a drive, nearer the goal than his spot, he stays where he is
## rather than swimming it back out.
static func _carry(p: Play, a: Swimmer, dt: float) -> void:
	a.facing = 1.0
	var goal := Geo.goal_center()
	if p.raised or p.kind == Play.Kind.PENALTY:
		a.target = a.pos
		return
	if p.carry:
		if a.pos.distance_to(goal) <= Play.COUNTER_STOP + 0.25:
			p.end_counter()
		else:
			var dir := Vector2(-Play.COUNTER_STOP, clampf(a.pos.y - Geo.GOAL_Y, -1.5, 1.5)).normalized()
			a.target = goal + dir * Play.COUNTER_STOP
			if p.lanes.has(a) and a.pos.x < LANE_CARRY_UNTIL:
				# down his lane first, then in at the goal (the further up the pool, the more lane)
				var k := clampf((LANE_CARRY_UNTIL - a.pos.x) / 6.0, 0.0, 1.0)
				a.target.y = lerpf(a.target.y, break_lane(p, a, a.pos), k)
			a.boost = PlaySetup.CARRY_SWIM
			return
	if p.defending and a.drive_t > 0.0:
		# their man driving the ball in (OffenseAI), or carrying on the drive he caught it on
		a.drive_t -= dt
		a.target = a.drive_goal
		a.boost = 1.0
		if a.pos.distance_to(a.drive_goal) < 0.3:
			a.drive_t = 0.0
		return
	if p.push_on == a:
		a.target = a.pos   # wrestling his man for the water (DefenseFormation.press): he isn't swimming
		return
	var attack := DefenseFormation.open_attack(p, a)
	if attack != Vector2.INF:
		a.target = attack   # 5 DROP: left open, he slides in at the cage
		a.boost = 1.0
		return
	if a == p.rotating:
		if a.pos.distance_to(a.home) < 0.4:
			p.rotating = null
		else:
			a.target = a.home
			a.boost = 0.9
			return
	var deeper := a.pos.distance_to(goal) < a.home.distance_to(goal) - 0.3
	if deeper or a.pos.distance_to(a.home) < 0.3:
		a.target = a.pos
		return
	a.target = a.home
	a.boost = 0.8

static func _schedule_drive(p: Play, dt: float) -> void:
	if p.ball.state != Ball.State.HELD or p.man_up > 0.0 or p.over or p.carry:
		return
	p.drive_timer -= dt
	if p.drive_timer > 0.0:
		return
	if p.defending:
		_gap_drive(p)
		return
	p.drive_timer = p.rng.randf_range(RELEASE_EVERY.x, RELEASE_EVERY.y)   # your DRIVE calls fill the gaps
	if releasing(p):
		return
	var options: Array[Swimmer] = []
	for a in p.attackers:
		if a != p.holder and a.tag != "C" and a.drive_t <= 0.0 and a.pos.distance_to(a.home) < 1.0:
			options.append(a)
	if options.is_empty():
		return
	var a: Swimmer = options[p.rng.randi() % options.size()]
	a.drive_t = DRIVE_TIME
	var lane_y := lerpf(a.home.y, Geo.GOAL_Y, 0.55) + p.rng.randf_range(-0.7, 0.7)
	a.drive_goal = release_to(a, Vector2(p.rng.randf_range(26.9, 27.8), lane_y))

## Is a man already on a release (off the ball)? Then nobody else goes: one at a time.
static func releasing(p: Play) -> bool:
	for a in p.attackers:
		if a != p.holder and a.drive_t > 0.0:
			return true
	return false

## A release by `a` towards `to`, cut short to RELEASE_MAX off his spot.
static func release_to(a: Swimmer, to: Vector2) -> Vector2:
	return Geo.clamp_in_pool(a.home + (to - a.home).limit_length(RELEASE_MAX))

## Their attack: where a man without the ball goes when he isn't driving. His spot, but left
## alone he steps in towards the goal (into the open water), with a defender in the lane from
## the ball he slides to open it. (The centre is _center_seal's.)
static func _open_spot(p: Play, a: Swimmer) -> Vector2:
	var spot := a.home
	var open := INF
	for d in p.defenders:
		if not d.out:
			open = minf(open, d.pos.distance_to(a.pos))
	if open > OPEN_STEP_IN:
		var inside := Vector2(minf(a.home.x + 1.6, 27.0), lerpf(a.home.y, Geo.GOAL_Y, 0.3))
		spot = a.home.lerp(inside, clampf((open - OPEN_STEP_IN) / 1.5, 0.0, 1.0))
	var h := p.holder
	if h != null and h != a:
		for d in p.defenders:
			if d.out:
				continue
			var c := Geometry2D.get_closest_point_to_segment(d.pos, h.pos, spot)
			if d.pos.distance_to(c) < 0.8 and c.distance_to(spot) > 1.0 and c.distance_to(h.pos) > 1.0:
				var perp := (spot - h.pos).orthogonal().normalized()
				var side := 1.0 if (spot - d.pos).dot(perp) >= 0.0 else -1.0
				spot += perp * side * LANE_SLIDE
				break
	return Geo.clamp_in_pool(a.home + (spot - a.home).limit_length(SPOT_MAX))

## Their attack's drives: more often, and by whoever has the biggest gap to drive into, the
## drive going for the middle of it.
static func _gap_drive(p: Play) -> void:
	p.drive_timer = p.rng.randf_range(GAP_DRIVE_EVERY.x, GAP_DRIVE_EVERY.y)
	if releasing(p):
		return
	var best: Swimmer = null
	var best_v := -INF
	var best_goal := Vector2.ZERO
	for a in p.attackers:
		if a == p.holder or a.tag == "C" or a.out or a.drive_t > 0.0 or a.pos.distance_to(a.home) > SPOT_MAX + 0.3:
			continue
		var goal_pt := release_to(a, Vector2(p.rng.randf_range(26.9, 27.6), lerpf(a.home.y, Geo.GOAL_Y, 0.55) + p.rng.randf_range(-0.6, 0.6)))
		var v := lane_space(p, a.pos, goal_pt) + 0.5 * _space_at(p, goal_pt) + p.rng.randf() * 0.4
		if v > best_v:
			best_v = v
			best = a
			best_goal = goal_pt
	if best == null or best_v < GAP_DRIVE_MIN:
		return
	best.drive_t = DRIVE_TIME
	best.drive_goal = best_goal

## How much room there is along a swim from `from` to `to`: metres from the path to the
## nearest defender in the water (but `skip`, the man he's already beaten).
static func lane_space(p: Play, from: Vector2, to: Vector2, skip: Swimmer = null) -> float:
	var best := INF
	for d in p.defenders:
		if not d.out and d != skip:
			best = minf(best, d.pos.distance_to(Geometry2D.get_closest_point_to_segment(d.pos, from, to)))
	return best

static func _space_at(p: Play, at: Vector2) -> float:
	var best := INF
	for d in p.defenders:
		if not d.out:
			best = minf(best, d.pos.distance_to(at))
	return best

# ------------------------------------------------------------------ the breakout
const BREAKOUT_AHEAD := 8.0     # each man swims for a point this far up the pool...
const BREAKOUT_LANE := 3.2      # ...the ones without the ball at least this far across from it

## The ball's just changed hands (Play._start_breakout). In this possession's frame the team
## that won it (`defenders`) now attacks the goal at x = 0, and the team that lost it
## (`attackers`) defends it: both swim down the pool. Winners go into lanes either side of the
## ball, the man with it straight up the middle; losers turn, then get back goal side.
static func _breakout(p: Play, dt: float) -> void:
	var b := p.holder.pos if p.holder != null else p.ball.pos
	for s in p.attackers + p.defenders:
		s.pace = 1.0   # (the turn: nobody's defending yet)
	for d in p.defenders:
		if d.out:
			d.target = Geo.REENTRY
			continue
		d.react -= dt
		d.facing = -1.0
		d.vel.x = minf(d.vel.x, 0.0)   # never back towards his own goal
		if d.react > 0.0:
			d.target = d.pos
			continue
		var to := Vector2(d.pos.x - BREAKOUT_AHEAD, d.pos.y)
		if d == p.holder:
			to.y = lerpf(d.pos.y, Geo.GOAL_Y, 0.25)
			d.boost = PlaySetup.CARRY_SWIM
		else:
			to.y = clampf(d.pos.y, 3.5, 16.5)
			if absf(to.y - b.y) < BREAKOUT_LANE:
				to.y = clampf(b.y + (BREAKOUT_LANE if d.pos.y >= b.y else -BREAKOUT_LANE), 3.5, 16.5)
			d.boost = PlaySetup.BREAK_SWIM
		d.target = Geo.clamp_in_pool(to)
	for a in p.attackers:
		if a.out:
			continue
		a.react -= dt
		if a.react > 0.0:
			a.target = a.pos   # (turning: his way on carries him a touch further, then he stops)
			continue
		a.facing = -1.0
		if a == p.breakout_guard:
			_center_trail(a, p.breakout_centre, b)   # on the back of the man he'll guard
			continue
		a.target = Geo.clamp_in_pool(Vector2(a.pos.x - BREAKOUT_AHEAD, lerpf(a.pos.y, Geo.GOAL_Y, 0.25)))
		a.boost = PlaySetup.RECOVER_SWIM

# ------------------------------------------------------------------ defence
## The defence's decisions are its AI level's (p.level, Difficulty): how sharply each man re-reads
## where he should be ("read"), how far he shades into the passing lane ("lane_deny"), how far the
## far side sags in to help ("help"), how far off his spot he reads it ("pos_err", rolled again
## every ERR_EVERY s), and the man beaten for inside water (CenterDefense). Never how fast he swims.
## In a settled PRESS nobody sags: a man off the ball is goal side of his own man, his hand in the
## lane at most PRESS_LANE towards the ball.
const ERR_EVERY := 2.5
const PRESS_LANE := 0.3
static var press_tight := true   # (off: the old PRESS, its far side sagging in: for measuring the difference)

static func _defend(p: Play, dt: float) -> void:
	var comm := p.comm()   # (their keeper's organising: every defender's effective Defense)
	var lv := p.level
	var read := Difficulty.value("read", lv)
	var lane := Difficulty.value("lane_deny", lv)
	var help := Difficulty.value("help", lv)
	_roll_errors(p, dt)
	DefenseFormation.update(p, dt)   # (the settled defence's formation: each man's duty, his man or his spot)
	var press := press_tight and p.formation == DefenseFormation.F.PRESS and DefenseFormation.active(p)
	var beaten := CenterDefense.responsible(p)
	ManDownZone.update(p, dt)   # (man-down: the zone's lanes and who steps out; it clears itself at 6 on 6)
	if p.carry and not p.over and p.man_up <= 0.0:
		p.marks_t += dt
		if p.marks_t >= COUNTER_REMARK or (p.holder != null and p.holder != p.marks_ball):
			counter_marks(p)
	var goal := Geo.goal_center()
	var short := p.carry and not p.over and p.is_break()   # (outnumbered on the break: counter_spot)
	var loose_chaser := _nearest(p.defenders, p.ball.pos) if p.ball.state == Ball.State.LOOSE else null
	for d in p.defenders:
		d.boost = 1.0
		d.pace = DefenseFormation.move_mult(d.player)   # (his Defense: how fast he gets anywhere)
		if d.out:
			d.target = Geo.REENTRY
			d.boost = 1.1
			continue
		if d == loose_chaser:
			d.target = p.ball.pos
			d.boost = 1.25
			continue
		if d == p.drop_fouler and p.holder != null:
			# the call's foul: he goes to the man with the ball, goal side of him
			d.target = p.holder.pos + (goal - p.holder.pos).normalized() * 0.7
			d.boost = 1.2
			continue
		var m := d.mark
		if d == beaten:
			var act := CenterDefense.think(p, d, dt)
			if act >= 0:
				d.target = CenterDefense.spot(p, d, act)
				continue
		if DefenseFormation.pressing(d):
			# a piston out on the ball (slowly: never a sprint) or swimming back to his spot
			d.target = d.fspot
			d.boost = 1.0
			if d.duty == DefenseFormation.Duty.PRESSURE:
				# he checks his swim at once (whatever he was doing) and goes out at the pressure's pace
				d.boost = DefenseFormation.press_share(d.player)
				d.vel = d.vel.move_toward(d.vel.limit_length(d.top_speed * d.pace * d.boost), d.accel * DefenseFormation.PRESS_BRAKE * dt)
			d.back_off = maxf(0.0, d.back_off - dt)
			continue
		if m != null and m.tag == "C" and center_swimming_in(p, m):
			_center_trail(d, m, p.ball.pos)
			continue
		var want := Vector2(27.2, Geo.GOAL_Y)
		if d.fspot != Vector2.INF:
			want = d.fspot + d.ai_err   # the formation's spot for him: splitting, dropped, behind the centre
		elif p.man_up > 0.0 and d.zlane >= 0:
			want = ManDownZone.spot(p, d) + d.ai_err * ManDownZone.ERR   # man-down: his lane, or out on the ball
		elif m != null and p.carry and p.man_up <= 0.0:
			want = counter_spot(p, d, m, short)
		elif m != null:
			var gap := 0.9 if m == p.holder else 1.1
			var wing := m == p.holder and DefenseFormation.wing_pressure(p, m)
			if m == p.holder and not p.raised and m.speed() > 0.5:
				gap = 1.6   # a man swimming the ball up gets a little room
			if wing:
				gap = DefenseFormation.WING_SWIM_GAP if not p.raised and m.speed() > 0.5 else DefenseFormation.WING_GAP
			if m.tag == "C":
				gap = 0.55
			if p.man_up > 0.0 and m != p.holder:
				gap = 1.5
			want = m.pos + (goal - m.pos).normalized() * gap
			if m.tag == "C" and m != p.holder and p.man_up <= 0.0 and not p.carry:
				want = _center_guard_spot(p, d, m, dt)
				if p.cfight == Fight.SPIN or p.cfight == Fight.ROUND:
					d.boost = 1.2   # going round him: a hard few strokes
			elif m != p.holder and press and m.tag != "C":
				# PRESS is man to man all over the pool: the far side stays on its men too, a hand
				# in the lane (PRESS_LANE at most), never sagging off into the hole (a drop's job)
				want += (p.ball.pos - want).normalized() * minf(lane, PRESS_LANE)
			elif m != p.holder:
				want += (p.ball.pos - want).normalized() * lane
				# the far side sags into the hole to help on the centre (not in PRESS: above)
				if m.tag != "C" and m.pos.distance_to(p.ball.pos) > 8.0:
					want = want.lerp(Vector2(26.8, Geo.GOAL_Y), help)
			if m.tag != "C":
				want += d.ai_err * (DefenseFormation.WING_ERR if wing else (0.5 if m == p.holder else 1.0))   # (a positioning mistake)
		if m != null and d.back_off > 0.0:
			d.back_off -= dt
			want = m.pos + (want - m.pos).normalized() * 1.9
		if p.man_up > 0.0:
			want.x = maxf(want.x, 25.6)
		var react := (3.0 + Attributes.eff_defense_legacy(d.player, comm) / 30.0) * read
		if m != null and m.called > 0.0:
			react *= 0.5   # a called drive catches his man a step slow
		d.target = d.target.lerp(want, clampf(dt * react, 0.0, 1.0))
		if d.pos.distance_to(want) > 1.4:
			d.boost = PlaySetup.RECOVER_SWIM if p.carry else 1.2
		if d.duty == DefenseFormation.Duty.CRASH:
			d.target = want   # (onto the centre: no lag, he's going)
			d.boost = DefenseFormation.CRASH_BOOST

# ------------------------------------------------------------------ the centre swimming in
## On a counter or the swim-in after the ball changes hands, the centre's man goes down the pool
## on his back: CENTER_TRAIL behind him the way he's swimming (towards the ball when he's
## stopped), in contact, not metres back. He aims where the centre will be (CENTER_TRAIL_LEAD
## ahead: Swimmer.step closes three times the gap a second) and swims at the centre's pace and a
## little more (CENTER_TRAIL_PACE), flat out at most CENTER_TRAIL_BOOST. Coming from the wrong side
## he goes round him, not through him. Once the centre's on his spot the 2 m battle takes over.
const CENTER_TRAIL := 0.55
const CENTER_TRAIL_LEAD := 0.33
const CENTER_TRAIL_PACE := 1.1
const CENTER_TRAIL_BOOST := 1.6

## Is the centre `c` still on his way in (a counter, or not on his spot yet), off the ball?
static func center_swimming_in(p: Play, c: Swimmer) -> bool:
	if c == p.holder or p.man_up > 0.0 or p.kind == Play.Kind.PENALTY or p.breakout:
		return false
	return p.carry or c.pos.distance_to(c.home) > Play.CENTER_SPOT_R

## Behind the centre `c`: back the way he's swimming, or (stopped) towards the ball at `b`.
static func trail_dir(c: Swimmer, b: Vector2) -> Vector2:
	if c.speed() > 0.5:
		return -c.vel.normalized()
	return (b - c.pos).normalized() if b.distance_to(c.pos) > 0.3 else Vector2.LEFT

static func _center_trail(d: Swimmer, c: Swimmer, b: Vector2) -> void:
	d.target = _round_to(c, d, trail_dir(c, b), CENTER_TRAIL, CENTER_SPIN_LEAD) + c.vel * CENTER_TRAIL_LEAD
	d.boost = clampf(c.top_speed * c.boost * CENTER_TRAIL_PACE / d.top_speed, 1.0, CENTER_TRAIL_BOOST)

# ------------------------------------------------------------------ the centre
## The centre's guard picks a side of him (-1 up the screen, +1 down it) and holds it: half in
## front of him on that side (CENTER_SIDE across, CENTER_UP towards the ball), so the entry
## from that side is his and the other side is open (Play.center_entry). When the ball goes
## round to the other side he doesn't follow it at once: he waits (CENTER_SWITCH_WAIT, quicker
## the better he defends), then swims round behind the centre to the new side (CENTER_SWITCH s,
## the first half of it behind him, where neither side is covered). Swing it and feed it from
## the side he's just left.
const CENTER_SIDE := 0.7
const CENTER_UP := 0.15
const CENTER_BEHIND := 0.75
const CENTER_MID := 1.5        # the ball within this (across) of the centre pulls neither way
const CENTER_SWITCH_WAIT := Vector2(2.0, 1.2)   # worst .. best defender
const CENTER_SWITCH := 1.0
const CENTER_SEAL := 0.3       # the centre leans off his guard, showing the passer the open side

static func _center_guard_spot(p: Play, d: Swimmer, c: Swimmer, dt: float) -> Vector2:
	var b := p.ball.to if p.ball.state == Ball.State.PASS else p.ball.pos
	var ball_side := Play.entry_side(b, c)
	if d.cside == 0:   # (to start with: the ball's side, or the side he's already on)
		d.cside = ball_side if ball_side != 0 else (-1 if d.pos.y < c.pos.y else 1)
	match p.cfight:
		Fight.SPIN, Fight.SEALED:
			# beaten: turned round behind him, and held there
			d.cside_t = 0.0
			d.cswitch = 0.0
			return _round_to(c, d, behind_dir(c, b), CENTER_BEHIND, CENTER_SPIN_LEAD)
		Fight.ROUND:
			# swimming round him to get back in front, on the ball's side
			d.cside = ball_side if ball_side != 0 else d.cside
			return _round_to(c, d, front_dir(c, b, d.cside), CENTER_FRONT, CENTER_ROUND_LEAD)
	if d.cswitch > 0.0:
		d.cswitch = maxf(0.0, d.cswitch - dt)
	elif ball_side != 0 and ball_side != d.cside:
		d.cside_t += dt
		if d.cside_t >= center_switch_wait(d, p.comm(), p.level):
			d.cside = ball_side
			d.cswitch = CENTER_SWITCH
			d.cside_t = 0.0
	else:
		d.cside_t = maxf(0.0, d.cside_t - dt)
	if d.cswitch > CENTER_SWITCH * 0.5:
		return c.pos + (Geo.goal_center() - c.pos).normalized() * CENTER_BEHIND
	if ball_side == -d.cside:
		# the ball's gone round and he hasn't (yet): still on his side, the entry from there is open
		return c.pos + Vector2(-CENTER_UP, float(d.cside) * CENTER_SIDE) + _sway(p, c, d) * 0.5
	# fronting him: in the lane from the ball, on the side he holds
	return c.pos + front_dir(c, b, d.cside) * CENTER_FRONT + _sway(p, c, d)

## How long the centre's guard waits before going round to the ball's new side: better defenders
## less (his effective Defense, his keeper's organising `comm` in it), and his Strength gets him
## round sooner too (Attributes.SWITCH_PER_POINT a point either side of 5). How soon he reads that
## he has to (`level`, Difficulty "switch") is his AI's.
static func center_switch_wait(d: Swimmer, comm: float = 0.0, level: float = Difficulty.MEDIUM) -> float:
	var w := lerpf(CENTER_SWITCH_WAIT.x, CENTER_SWITCH_WAIT.y, clampf(Attributes.eff_defense_legacy(d.player, comm) / 100.0, 0.0, 1.0))
	return w * clampf(1.0 - (Attributes.strength(d.player) - 5.0) * Attributes.SWITCH_PER_POINT, 0.7, 1.3) * Difficulty.value("switch", level)

## Every ERR_EVERY s: where each defender (and the keeper) misreads his spot by, for a while.
static func _roll_errors(p: Play, dt: float) -> void:
	p.err_t -= dt
	if p.err_t > 0.0:
		return
	p.err_t = ERR_EVERY
	var e := Difficulty.value("pos_err", p.level) * 0.7
	for d in p.defenders:
		d.ai_err = Vector2(p.ai_rng.randfn(0.0, e), p.ai_rng.randfn(0.0, e)).limit_length(e * 2.0)
	var g := Difficulty.value("gk_pos_err", p.level)
	p.keeper.ai_err = Vector2(0.0, clampf(p.ai_rng.randfn(0.0, g), -2.0 * g, 2.0 * g))

## The centre: on his spot, fighting to keep his guard where he is, leaning off him to show the
## passer the open side. With his guard on his way round behind him, he backs into him. With
## inside water won (SPIN, SEALED) he steps out into the lane towards the ball, his man on his back.
static func _center_seal(p: Play, c: Swimmer) -> Vector2:
	var spot := c.home
	var g := p.on_ball_guard(c)
	if g == null:
		return spot
	if p.cfight == Fight.SPIN or p.cfight == Fight.SEALED:
		var b := p.ball.to if p.ball.state == Ball.State.PASS else p.ball.pos
		return spot + (b - spot).normalized() * CENTER_STEP_OUT
	var held := Play.center_side_held(g, c)
	if held == 0:
		spot.x += 0.2
	else:
		spot.y -= float(held) * CENTER_SEAL
	return spot - _sway(p, c, g) * 0.4   # (shoving back against him)

# ------------------------------------------------------------------ the 2 m battle
## The centre and his guard wrestle for position all through a settled possession. Mostly his
## guard has it (HOLD): in front of him, in the lane from the ball, on the side he holds, the
## two of them shoving and shifting round each other, and an entry is his (Play.center_entry). Every
## CENTER_WIN s (a few seconds sooner the stronger the centre is than his man, a WRESTLER's edge
## too, never outside 5-10 s) the centre wins inside water: he turns and spins his man round
## behind him (SPIN) and seals him there for CENTER_OPEN s (SEALED): the entry is open from anywhere
## on the perimeter. Then his man swims round him back to the ball side (ROUND), and it starts
## again. Swinging the ball round still opens the other side for a beat (the side switch).
## All of it is just where the two of them are: the entry is decided by that, at the release.
enum Fight { HOLD, SPIN, SEALED, ROUND }
const CENTER_WIN := Vector2(5.0, 10.0)    # wrestling this long before the centre wins inside water...
const CENTER_OPEN := Vector2(2.2, 3.6)    # ...and he holds it this long once his man is behind him (open ~1 s more:
                                          # the spin and the swim back round; 3-5 s in all)
const CENTER_SPIN := 0.9       # at most this long turning his man round behind him
const CENTER_ROUND := 1.6      # ...and at most this long for his man to get back round in front
const CENTER_FRONT := 0.75     # fronting: this far out from the centre towards the ball...
const CENTER_NUDGE := 0.42     # ...the ball straight down from the point: this far (rad) round to his side
const CENTER_STEP_OUT := 0.3   # the centre with inside water steps this far into the lane
const CENTER_SPIN_LEAD := 1.2  # how far (rad) round him the spot leads a man going round
const CENTER_ROUND_LEAD := 0.9
const WRESTLE_SWAY := 0.05     # the shoving: this far (m) either way round him (never out of the lane)...
const WRESTLE_PUSH := 0.08     # ...and in and out, shoulder to shoulder
const WRESTLE_R := 1.3         # the two of them this close are locked up (the art)

static func _center_battle(p: Play, dt: float) -> void:
	var c: Swimmer = null
	for a in p.attackers:
		if a.tag == "C":
			c = a
	var g := p._center_guard(c) if c != null else null
	var on := c != null and g != null and p.man_up <= 0.0 and not p.carry and not p.over and not p.breakout \
		and p.kind != Play.Kind.PENALTY and c.pos.distance_to(c.home) <= Play.CENTER_SPOT_R
	for s in p.attackers + p.defenders:
		if s != c and s != g:
			s.grip = move_toward(s.grip, 0.0, dt * 4.0)
			s.hook = false
	if not on:
		p.cfight = Fight.HOLD
		p.cfight_t = -1.0
		for s in [c, g]:
			if s != null:
				s.grip = move_toward(s.grip, 0.0, dt * 4.0)
				s.hook = false
		return
	var locked := g.pos.distance_to(c.pos) < WRESTLE_R and c != p.holder
	for s in [c, g]:
		s.grip = move_toward(s.grip, 1.0 if locked else 0.0, dt * 4.0)
	if DefenseFormation.center_behind(p):
		# a drop formation: his man's on his back all the time and the dropper is in front, so
		# there's no fighting round him for the lane (the entry is the dropper's business)
		p.cfight = Fight.HOLD
		p.cfight_t = -1.0
		c.hook = false
		if locked:
			c.facing = -1.0
		return
	c.hook = locked and p.cfight in [Fight.SPIN, Fight.SEALED]
	if locked:
		c.facing = -1.0   # back to the goal, facing the ball
		if absf(c.pos.x - g.pos.x) > 0.15:
			g.facing = signf(c.pos.x - g.pos.x)   # on his man
	if p.cfight_t < 0.0:
		p.cfight = Fight.HOLD
		p.cfight_t = _win_time(p, c, g)
	# the clock stops while he has the ball, it's on its way in to him, or for a whistle
	if c == p.holder or (p.ball.state == Ball.State.PASS and p.ball.receiver == c) or p.freeze > 0.0:
		return
	var b := p.ball.to if p.ball.state == Ball.State.PASS else p.ball.pos
	p.cfight_t -= dt
	match p.cfight:
		Fight.HOLD:
			if p.cfight_t <= 0.0:
				p.cfight = Fight.SPIN
				p.cfight_t = CENTER_SPIN
				g.cswitch = 0.0
				g.cside_t = 0.0
		Fight.SPIN:
			if p.cfight_t <= 0.0 or is_behind(g, c, b):
				p.cfight = Fight.SEALED
				p.cfight_t = p.fight_rng.randf_range(CENTER_OPEN.x, CENTER_OPEN.y) * seal_mult(p, c, g)
		Fight.SEALED:
			if p.cfight_t <= 0.0:
				p.cfight = Fight.ROUND
				p.cfight_t = CENTER_ROUND
		Fight.ROUND:
			if p.cfight_t <= 0.0 or Play.in_entry_lane(g, b, c.pos):
				p.cfight = Fight.HOLD
				p.cfight_t = _win_time(p, c, g)

## How long the guard holds him off this time: CENTER_WIN, a stronger centre (or a WRESTLER)
## winning it sooner, a stronger guard (Strength: holding him) and a better one (Defense: where he
## sets up, his keeper's organising in it) later. Attributes.CENTER_WIN_PER_POINT s a point.
static func _win_time(p: Play, c: Swimmer, g: Swimmer) -> float:
	return clampf(p.fight_rng.randf_range(CENTER_WIN.x, CENTER_WIN.y) - win_edge(p, c, g), CENTER_WIN.x, CENTER_WIN.y)

## The centre's edge in the 2 m battle, in seconds sooner he wins inside water: his Strength over
## his guard's, less half of the guard's effective Defense over 5, and a WRESTLER either side.
static func win_edge(p: Play, c: Swimmer, g: Swimmer) -> float:
	var pts := Attributes.strength(c.player) - Attributes.strength(g.player) \
		- 0.5 * (Attributes.eff_defense(g.player, p.comm()) - 5.0)
	var edge := pts * Attributes.CENTER_WIN_PER_POINT
	if Traits.has(c.player, "wrestler"):
		edge += 0.6
	if Traits.has(g.player, "wrestler"):
		edge -= 0.6
	return edge

## How long the centre holds his man behind him once he's sealed him, as a share of CENTER_OPEN:
## a guard stronger (and better) than the centre fights back round sooner.
static func seal_mult(p: Play, c: Swimmer, g: Swimmer) -> float:
	var guard := 0.5 * (Attributes.strength(g.player) + Attributes.eff_defense(g.player, p.comm()))
	return clampf(1.0 - (guard - Attributes.strength(c.player)) * Attributes.SEAL_PER_POINT, 0.7, 1.3)

## Out from the centre `c` towards the ball at `b`; straight down from the point (no side to
## the ball), turned CENTER_NUDGE round to `side`, the side his guard holds (still in the lane).
static func front_dir(c: Swimmer, b: Vector2, side: int) -> Vector2:
	var dir := (b - c.pos).normalized() if b.distance_to(c.pos) > 0.3 else Vector2.LEFT
	if Play.entry_side(b, c) == 0 and side != 0:
		var r := dir.rotated(CENTER_NUDGE)
		dir = r if signf(r.y - dir.y) == float(side) else dir.rotated(-CENTER_NUDGE)
	return dir

## Behind the centre `c`, as the ball at `b` sees him: goal side, and away from the ball.
static func behind_dir(c: Swimmer, b: Vector2) -> Vector2:
	var away := (c.pos - b).normalized() if b.distance_to(c.pos) > 0.3 else Vector2.RIGHT
	return ((Geo.goal_center() - c.pos).normalized() + away).normalized()

## Is `g` behind the centre `c` as a ball from `b` comes: past him, the far side from the ball?
static func is_behind(g: Swimmer, c: Swimmer, b: Vector2) -> bool:
	return (g.pos - c.pos).dot(b - c.pos) < 0.0

## A spot on the circle of radius `r` round `c` that leads `g` round him towards `dir`, at most
## `lead` radians ahead of where he is: he swims round the centre, not through him.
static func _round_to(c: Swimmer, g: Swimmer, dir: Vector2, r: float, lead: float) -> Vector2:
	var cur := g.pos - c.pos
	if cur.length() < 0.05:
		cur = dir
	var diff := wrapf(dir.angle() - cur.angle(), -PI, PI)
	return c.pos + Vector2.from_angle(cur.angle() + clampf(diff, -lead, lead)) * r

## The shoving: an uneven push and give, in and out (and a little way round), the same for both
## of them so they move together.
static func _sway(p: Play, c: Swimmer, g: Swimmer) -> Vector2:
	var t := p.elapsed + float(c.player.number) * 1.7
	var k := sin(t * 1.9) * 0.6 + sin(t * 3.3 + 1.0) * 0.4
	var out := (g.pos - c.pos).normalized() if g.pos.distance_to(c.pos) > 0.05 else Vector2.LEFT
	return out.orthogonal() * k * WRESTLE_SWAY + out * sin(t * 2.6 + k) * WRESTLE_PUSH

## Getting back on a counter: the most dangerous man first (the ball, then whoever's nearest
## the goal, a man trailing the break counting THREAT_TRAIL m further off), each picked up by the
## free defender who can get goal side of him quickest. A defender still behind his man has to
## swim past him first, so he's a poor pick: the break is only covered by the men who are back.
## The centre's own man, on his back (CENTER_STICK_R), stays on him. A defender keeps the man he
## had unless somebody else is clearly better placed (MARK_STICK), so nobody switches back and
## forth, and it's only looked at again when the ball changes hands or every COUNTER_REMARK s. A
## defender left over (a man short of attackers: an exclusion) isn't sent after a man already
## taken: he drops into the hole in front of the goal. (The same MARK_STICK keeps a man who's
## already covered ahead of one who isn't in the pecking order, so the two free men in a 3 on 2
## don't swap places in it every time they're looked at.)
const CENTER_STICK_R := 1.5
const COUNTER_REMARK := 1.2
const MARK_STICK := 2.0
const THREAT_TRAIL := 3.0
const BEHIND_COST := 4.0

static func counter_marks(p: Play) -> void:
	p.marks_t = 0.0
	p.marks_ball = p.holder
	var goal := Geo.goal_center()
	var bx := p.holder.pos.x if p.holder != null else p.ball.pos.x
	var danger := func(a: Swimmer) -> float:
		var v := a.pos.distance_to(goal) + (THREAT_TRAIL if a.pos.x < bx - Play.BREAK_TRAIL else 0.0)
		for d in p.defenders:
			if d.mark == a and not d.out and d.pos.x >= a.pos.x - 0.5:
				return v - MARK_STICK   # (he's covered already: he stays ahead of a man nobody's on)
		return v
	var threats := p.attackers.filter(func(a: Swimmer): return not a.out)
	threats.sort_custom(func(x: Swimmer, y: Swimmer):
		if x == p.holder or y == p.holder:
			return x == p.holder
		return danger.call(x) < danger.call(y))
	var free: Array[Swimmer] = []
	for d in p.defenders:
		if not d.out:
			free.append(d)
	# the centre's own man, on his back as he swims in: he's the centre's (unless the centre has it:
	# then the ball comes first, as ever)
	var c := _tagged(p, "C")
	var stick := center_pair(p)
	if c == null or c == p.holder or stick == null or stick.out or stick.pos.distance_to(c.pos) > CENTER_STICK_R:
		stick = null
	for a: Swimmer in threats:
		if free.is_empty():
			break
		if stick != null and a == c and stick in free:
			stick.mark = c
			free.erase(stick)
			continue
		var spot := a.pos + (goal - a.pos).normalized() * 1.0
		var best: Swimmer = null
		var best_cost := INF
		for d in free:
			if d == stick and a != p.holder:
				continue
			var cost := d.pos.distance_to(spot) + (BEHIND_COST if d.pos.x < a.pos.x - 0.5 else 0.0) \
				- (MARK_STICK if d.mark == a else 0.0)
			if cost < best_cost:
				best_cost = cost
				best = d
		if best == null:
			continue
		best.mark = a
		free.erase(best)
	for d in free:
		d.mark = null   # (nobody left to take: the hole, _defend)

## Where a defender on the break wants to be against his man `m`: goal side of where he's going
## (COUNTER_LEAD s on), so he meets the swim rather than chasing it, closer on the ball. Back
## already, he never swims up the pool to meet him: he holds, then gives ground in front of him
## (COUNTER_CUSHION up the pool, tight by 6 m), never deeper than COUNTER_HOLE. Short of
## men (`short`: the attack has more in the break than are back), the man on the ball shades
## towards the free man (COUNTER_SPLIT) so the pass across isn't a walk-in, and the others sag into
## the middle in front of the goal (COUNTER_SAG). Still behind his man, he goes round beside him,
## not through him. Only where he aims: how fast he gets there is his speed (and his Defense how
## sharply he reads it, _defend's react), so a man who's beaten him stays beaten.
const COUNTER_LEAD := 0.4
const COUNTER_GAP := 1.2
const COUNTER_GAP_BALL := 1.0
const COUNTER_SPLIT := 0.35
const COUNTER_SAG := 0.3
const COUNTER_HOLE := Vector2(26.5, Geo.GOAL_Y)
const COUNTER_ROUND := 0.9
const COUNTER_CUSHION := 3.0
const CUSHION_FROM_X := 18.0

static func counter_spot(p: Play, d: Swimmer, m: Swimmer, short: bool) -> Vector2:
	var goal := Geo.goal_center()
	var lead := Geo.clamp_in_pool(m.pos + m.vel * COUNTER_LEAD)
	var want := lead + (goal - lead).normalized() * (COUNTER_GAP_BALL if m == p.holder else COUNTER_GAP)
	if short:
		if m == p.holder:
			var free := _free_threat(p)
			if free != null:
				var other := free.pos + (goal - free.pos).normalized() * COUNTER_GAP
				want = want.lerp(other, COUNTER_SPLIT)
		else:
			want = want.lerp(COUNTER_HOLE, COUNTER_SAG)
	if d.pos.x > m.pos.x - 0.3:
		# goal side already: he doesn't come up the pool at him, he holds and gives ground, keeping
		# COUNTER_CUSHION in the open water and closing it to the gap by 6 m
		var t := clampf((m.pos.x - CUSHION_FROM_X) / (Geo.SIX_M - CUSHION_FROM_X), 0.0, 1.0)
		var cushion := m.pos.x + lerpf(COUNTER_CUSHION, want.x - m.pos.x, t)
		want.x = maxf(want.x, minf(maxf(d.pos.x, cushion), COUNTER_HOLE.x))
	if d.pos.x < m.pos.x - 0.3 and absf(d.pos.y - m.pos.y) < COUNTER_ROUND:
		var side := signf(d.pos.y - m.pos.y)
		want.y = m.pos.y + (side if side != 0.0 else 1.0) * COUNTER_ROUND
	return Geo.clamp_in_pool(want)

## The break's most dangerous man nobody's back on (nearest the goal, in the break, not the ball).
static func _free_threat(p: Play) -> Swimmer:
	var bx := p.holder.pos.x if p.holder != null else p.ball.pos.x
	var best: Swimmer = null
	var bd := INF
	for a in p.attackers:
		if a.out or a == p.holder or a.pos.x < bx - Play.BREAK_TRAIL:
			continue
		var marked := false
		for d in p.defenders:
			if d.mark == a and not d.out and d.pos.x >= a.pos.x - 0.5:
				marked = true   # (by a man who's back: one still chasing from behind doesn't count)
		var dd := a.pos.distance_to(Geo.goal_center())
		if not marked and dd < bd:
			bd = dd
			best = a
	return best

## The centre's own man: the one restore_marks pairs with him (their best wrestler: PlaySetup.build).
static func center_pair(p: Play) -> Swimmer:
	var c := _tagged(p, "C")
	var i := p.attackers.find(c)
	return p.defenders[i] if c != null and i < p.defenders.size() else null   # (a drill has no defenders)

static func _tagged(p: Play, tag: String) -> Swimmer:
	for a in p.attackers:
		if a.tag == tag:
			return a
	return null

static func restore_marks(p: Play) -> void:
	for i in p.defenders.size():
		p.defenders[i].mark = p.attackers[i]

# ------------------------------------------------------------------ keeper
const KEEPER_SET := 0.06       # he doesn't shuffle for less than this
## WHERE HE SETS: on the line that halves the angle between the two posts as the ball sees them
## (keeper_angle_y): so the wider the ball, the more of the near post he covers and the less far
## corner it can see. He goes KEEPER_ANGLE of the way there (worst, best), a free shooter gets a
## little more of it (KEEPER_FREE) and a pressed one a little less, and KEEPER_POST_GAP
## is the nearest he comes to the post, so the far corner stays inside a dive that way
## (KeeperDive). Wide, he also comes up off his line by up to KEEPER_STEP_OUT. All of it is his
## target: he swims there (Swimmer.step), so it's never a jump.
const KEEPER_ANGLE := Vector2(0.3, 0.55)
const KEEPER_FREE := 0.1
const KEEPER_FREE_R := 2.0     # nobody this close to the shooter: he's free
const KEEPER_PRESSED_R := 1.1  # somebody this close: he's pressed
const KEEPER_POST_GAP := 0.6
const KEEPER_STEP_OUT := 0.2

## Before the shot: square to the ball on his line, shading towards the near post the wider
## the angle, the better he is the truer he sets, give or take his AI's misreading of it
## (Difficulty "gk_pos_err"). A shot is Play's (its dive is the one ShotModel decided it with);
## once the play's over he drifts back to the middle. His state (KeeperAI.state_of): READY,
## ANTICIPATING while a shot's being wound up in range, committed while he dives, RECOVERING.
## Your keeper (`defending`) is never the AI's: he only moves when you move him or dive
## (MatchFlow: a little ball tracking, and your dives).
static func _keeper(p: Play) -> void:
	var k := p.keeper
	if p.keeper_rush and not p.over:
		_keeper_out(p, k)
		return
	if p.defending:
		return
	var in_range := p.holder != null and p.ball.state == Ball.State.HELD and Geo.in_shot_range(p.holder.pos)
	_keeper_read(p, k, in_range)
	p.gk_state = KeeperAI.state_of(k.pose, p.raised and in_range, in_range and p.gk_read != KeeperAI.NO_READ and p.gk_read != KeeperDive.CENTRE)
	var skill := clampf(k.player.live("keeping") / 100.0, 0.0, 1.0)
	k.boost = lerpf(1.3, 1.6, skill) / Attributes.lunge_mult(k.player)   # (LUNGE SPEED: quicker across)
	if p.ball.state == Ball.State.SHOT:
		return
	if p.over:
		if p.holder != k:
			k.target = Vector2(Geo.KEEPER_X, Geo.GOAL_Y)
			k.boost = 0.8
		return
	if p.ball.state == Ball.State.LOOSE and p.ball.pos.x > 27.2 and absf(p.ball.pos.y - Geo.GOAL_Y) < 3.0:
		k.target = p.ball.pos
		return
	var b := p.ball.pos
	if p.ball.state == Ball.State.PASS:
		b = p.ball.to   # he moves with the pass, not after it
	var y := keeper_set_y(b, skill, ball_pressure(p)) + k.ai_err.y
	if not is_nan(p.keeper_spot):
		y = p.keeper_spot   # (the shooting drill sets him)
	if in_range and p.gk_read != KeeperAI.NO_READ and p.keeper_dive == Play.NO_DIVE:
		# he's read it (KeeperAI): he shades that way, more the longer it's held. A lean, not a dive.
		p.gk_lean_y = y
		y += float(p.gk_read) * KeeperAI.lean(p.gk_hold())
	var x := keeper_set_x(b)
	if absf(y - k.target.y) > KEEPER_SET or absf(k.target.x - x) > 0.04:
		k.target = Vector2(x, y)

## Their keeper reads the man with the ball once he's had it in range READ_AT (KeeperAI: from what
## he can see, never the aim), on the defence's own dice. One read a man: it's the read his shot
## gets (Play._shoot), and the lean you see.
static func _keeper_read(p: Play, k: Swimmer, in_range: bool) -> void:
	if not in_range or p.gk_read != KeeperAI.NO_READ or p.gk_hold() < KeeperAI.READ_AT or p.kind == Play.Kind.PENALTY:
		return
	var nearest := INF
	for d in p.defenders:
		if not d.out:
			nearest = minf(nearest, d.pos.distance_to(p.holder.pos))
	var info := {"from": p.holder.pos, "keeper_y": k.pos.y, "pressure": nearest, "penalty": false,
		"close": p.close_chance(p.holder), "memory": p.gk_memory}
	p.gk_read = KeeperAI.choose(KeeperAI.read(info, p.level), p.level, p.ai_rng)

## How pressed the man with the ball is: 1 free, 0 even, -1 somebody right on him.
static func ball_pressure(p: Play) -> float:
	if p.holder == null or p.ball.state != Ball.State.HELD:
		return 0.0
	var near := INF
	for d in p.defenders:
		if not d.out:
			near = minf(near, d.pos.distance_to(p.holder.pos))
	if near >= KEEPER_FREE_R:
		return 1.0
	return -1.0 if near <= KEEPER_PRESSED_R else 0.0

## Where on his line the angle between the posts, as the ball at `b` sees them, is halved.
static func keeper_angle_y(b: Vector2) -> float:
	var from := Vector2(minf(b.x, Geo.KEEPER_X - 0.3), b.y)
	var near := (Vector2(Geo.GOAL_X, Geo.GOAL_Y - Geo.GOAL_HALF) - from).normalized()
	var far := (Vector2(Geo.GOAL_X, Geo.GOAL_Y + Geo.GOAL_HALF) - from).normalized()
	var half := near + far
	return from.y + half.y / maxf(0.001, half.x) * (Geo.KEEPER_X - from.x)

## Where a keeper sets across his goal for the ball at `b`: towards the angle's middle by `skill`
## (0..1) and how free the shooter is (ball_pressure), never closer to the post than KEEPER_POST_GAP.
## The same for both goals: Play always attacks x = 30.
static func keeper_set_y(b: Vector2, skill: float, free := 0.0) -> float:
	var share := lerpf(KEEPER_ANGLE.x, KEEPER_ANGLE.y, skill) + KEEPER_FREE * free
	var lim := Geo.GOAL_HALF - KEEPER_POST_GAP
	return Geo.GOAL_Y + clampf((keeper_angle_y(b) - Geo.GOAL_Y) * share, -lim, lim)

## ...and up the pool from his line: a step out at a wide ball, on the line for one straight on.
static func keeper_set_x(b: Vector2) -> float:
	var wide := absf(sin(atan2(b.y - Geo.GOAL_Y, maxf(Geo.GOAL_X - b.x, 0.5))))
	return Geo.KEEPER_X - KEEPER_STEP_OUT * wide

## Out for a ball thrown past the centre (Play._keeper_reads), either keeper, yours too: a beat to
## read it (Play.KEEPER_READ), then flat out at where it comes down, arm going up for it.
static func _keeper_out(p: Play, k: Swimmer) -> void:
	var flown := p.ball.t * p.ball.dur if p.ball.state == Ball.State.PASS else INF
	if flown < Play.KEEPER_READ:
		return
	k.target = p.ball.to if p.ball.state == Ball.State.PASS else p.ball.pos
	k.boost = Play.KEEPER_RUSH
	k.arm = maxf(k.arm, 0.6)

static func _nearest(list: Array[Swimmer], at: Vector2) -> Swimmer:
	var best: Swimmer = null
	var bd := INF
	for s in list:
		if s.out:
			continue
		var dd := s.pos.distance_to(at)
		if dd < bd:
			bd = dd
			best = s
	return best
