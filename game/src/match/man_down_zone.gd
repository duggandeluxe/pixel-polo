class_name ManDownZone
## THE MAN-DOWN ZONE (6 on 5): the five defenders left after an exclusion play the 4-2 the way the
## coaching sketch draws it, a lane each between two attackers, not man to man.
##
##        5                     the attack's 4-2 (PlaySetup.HOME_4_2), its goal on the right:
##        ^ TOP_FLAT              "5" "4" "C" "1" down the 2 m line, "3" and "2" out at 5 m
##   3 <TOP_POINT> 4
##        ^ MID                 each defender lives on the line between his two men (goal side
##   2 <BOT_POINT> C            of it, SAG), shades along it as the ball goes round, and the one
##        ^ BOT_FLAT            whose man has the ball steps out to him (STEP_GAP goal side of him).
##        1
##
## The arrows are the water each man works in, not a loop he swims. Who steps out is decided on the
## catch (or as the pass is thrown: they read it), the defender of the lanes the ball's man is on who
## is nearest him, and he stays the one until the ball moves on. The man he leaves is covered
## (COVER_SHADE) by the lanes next to his; the others on the ball's man's lanes shade onto him
## (ADJ_SHADE); everybody else leans to the ball's end of his lane (BALL_SHADE). So a pass round
## the perimeter moves the whole zone: the old ball side recovers, the new one steps up.
##
## Nothing here changes how fast anybody swims or reads: PlayAI._defend eases each man's target
## onto his spot at his own reaction and he swims there at his own pace. What's exaggerated is
## what you see (all art, never read by the play): the stepped-out man's arm going up in the lane
## (zreach, PoolArt._raised_arm, never a block), the defenders facing the ball, their eggbeater
## churning harder as they shift (ANIM_EXTRA) and leaning into it with a wake behind them (PoolArt).

enum Lane { TOP_FLAT, TOP_POINT, MID, BOT_POINT, BOT_FLAT }
const LANES := [["5", "4"], ["3", "4"], ["4", "C"], ["2", "C"], ["1", "C"]]   # [a, b] by attacker tag
const REST := [0.5, 0.5, 0.5, 0.5, 0.5]   # where along a..b he sits with the ball elsewhere (0 at a)
## Short-handed (a rolled man nobody can replace): the lanes are filled in this order.
const FILL := [Lane.MID, Lane.TOP_POINT, Lane.BOT_POINT, Lane.TOP_FLAT, Lane.BOT_FLAT]
const SAG := 0.55          # m goal side of his lane
const STEP_GAP := 0.8      # stepped out: this far goal side of the man with the ball
const ADJ_SHADE := 0.25    # his lane's on the ball's man (not the one out on him): this far along it to him
const COVER_SHADE := 0.25  # his lane's on the man the stepper left: this far along it to him
const BALL_SHADE := 0.12   # anybody else: this far along it to the end nearer the ball
const W_RANGE := Vector2(0.15, 0.85)   # never right on top of either man
const ERR := 0.5           # his positioning mistake (Swimmer.ai_err) counts this much: a zone's spots are tight
## The art (nothing in the play reads these)
const ARM_UP := 0.8        # the stepped-out man's arm: up to here (PoolArt._raised_arm; < 1: no block's open hand)
const ARM_RISE := 3.5      # ...per second going up...
const ARM_FALL := 4.0      # ...and coming down
const ARM_NEAR := 1.2      # ...going up once he's within this of his spot out on the man
const ANIM_EXTRA := 2.5    # his eggbeater churns this much more per m/s while he shifts

## One frame, before anybody moves (PlayAI._defend): sets the lanes up on an exclusion, decides who
## steps out on a catch, keeps each zone man's mark and the art. Out of man-down it clears itself.
static func update(p: Play, dt: float) -> void:
	if p.man_up <= 0.0 or p.over or p.kind == Play.Kind.PENALTY:
		if p.zone_set:
			p.zone_set = false
			p.zone_ball = null
			p.zone_primary = null
			for d in p.defenders:
				d.zlane = -1
		for d in p.defenders:
			_arm(d, null, dt)
		return
	if not p.zone_set:
		assign(p)
		p.zone_set = true
		p.zone_ball = null
		p.zone_primary = null
	var h := ball_man(p)
	if h != p.zone_ball:
		p.zone_ball = h
		p.zone_primary = _primary(p, h)
	var b := DefenseFormation.ball_focus(p)
	for d in p.defenders:
		if d.out or d.zlane < 0:
			_arm(d, null, dt)
			continue
		d.mark = _mark(p, d, b)
		var out_on := h if d == p.zone_primary and h != null and d.pos.distance_to(spot(p, d)) <= ARM_NEAR else null
		_arm(d, out_on, dt)
		if absf(d.vel.x) < 0.25 and absf(b.x - d.pos.x) > 0.2:
			d.facing = signf(b.x - d.pos.x)   # (eyes on the ball: step turns him only when he swims)
		d.anim += dt * d.speed() * ANIM_EXTRA

## The man the zone is playing as having it: the man with the ball, or the man a pass is going to
## (they read it in the air), or nobody (loose, a shot).
static func ball_man(p: Play) -> Swimmer:
	if p.ball.state == Ball.State.HELD and p.holder != null and p.attackers.has(p.holder):
		return p.holder
	if p.ball.state == Ball.State.PASS and p.ball.receiver != null and p.attackers.has(p.ball.receiver):
		return p.ball.receiver
	return null

## Each defender in the water to a lane, once per exclusion: whoever's nearest each lane's spot in
## the 4-2 (the fewest metres between them all), so nobody swims across the zone to get to his.
static func assign(p: Play) -> void:
	var ds: Array[Swimmer] = []
	for d in p.defenders:
		d.zlane = -1
		if not d.out:
			ds.append(d)
	var lanes: Array = FILL.slice(0, mini(ds.size(), FILL.size()))
	var cost := []
	for d in ds:
		var row: Array[float] = []
		for l in lanes:
			row.append(d.pos.distance_to(_home_spot(p, l)))
		cost.append(row)
	var best := {"c": INF, "pick": []}
	_search(cost, lanes.size(), 0, [], 0.0, best)
	var pick: Array = best.pick
	for i in pick.size():
		ds[pick[i]].zlane = lanes[i]

## The cheapest way to give lane i, i+1.. a defender each (none twice), into best.
static func _search(cost: Array, n: int, i: int, used: Array, c: float, best: Dictionary) -> void:
	if c >= best.c:
		return
	if i == n:
		best.c = c
		best.pick = used.duplicate()
		return
	for di in cost.size():
		if not used.has(di):
			used.append(di)
			_search(cost, n, i + 1, used, c + float(cost[di][i]), best)
			used.pop_back()

## Lane `l`'s spot with the attack on its 4-2 spots (for handing the lanes out).
static func _home_spot(p: Play, l: int) -> Vector2:
	var a := _man(p, LANES[l][0])
	var b := _man(p, LANES[l][1])
	var pa := a.home if a != null else (b.home if b != null else Geo.goal_center())
	var pb := b.home if b != null else pa
	return _sag(pa.lerp(pb, REST[l]))

## Of the zone men whose lanes `h` is on, the one nearest him; anybody in the zone if none is.
static func _primary(p: Play, h: Swimmer) -> Swimmer:
	if h == null:
		return null
	var best: Swimmer = null
	var any: Swimmer = null
	for d in p.defenders:
		if d.out or d.zlane < 0:
			continue
		if any == null or d.pos.distance_to(h.pos) < any.pos.distance_to(h.pos):
			any = d
		if h.tag in LANES[d.zlane] and (best == null or d.pos.distance_to(h.pos) < best.pos.distance_to(h.pos)):
			best = d
	return best if best != null else any

## The man the stepper has left: the other end of his lane from the ball (null: nobody's out, or
## the ball's man isn't on his lane).
static func left_open(p: Play) -> Swimmer:
	var s := p.zone_primary
	var h := p.zone_ball
	if s == null or h == null or s.zlane < 0 or not (h.tag in LANES[s.zlane]):
		return null
	var pair: Array = LANES[s.zlane]
	return _man(p, pair[1] if h.tag == pair[0] else pair[0])

## Where zone man `d` wants to be: out on the ball's man, or on his lane, shaded.
static func spot(p: Play, d: Swimmer) -> Vector2:
	var goal := Geo.goal_center()
	var h := p.zone_ball
	if h != null and d == p.zone_primary:
		return Geo.clamp_in_pool(h.pos + (goal - h.pos).normalized() * STEP_GAP)
	var a := _man(p, LANES[d.zlane][0])
	var b := _man(p, LANES[d.zlane][1])
	if a == null and b == null:
		return _sag(goal + Vector2(-2.5, 0.0))
	if a == null:
		a = b
	if b == null:
		b = a
	var w: float = REST[d.zlane]
	var open := left_open(p)
	if h != null and (h == a or h == b) and a != b:
		w += ADJ_SHADE * (-1.0 if h == a else 1.0)
	elif open != null and (open == a or open == b) and a != b:
		w += COVER_SHADE * (-1.0 if open == a else 1.0)
	else:
		var f := DefenseFormation.ball_focus(p)
		w += BALL_SHADE * (1.0 if b.pos.distance_to(f) < a.pos.distance_to(f) else -1.0)
	return _sag(a.pos.lerp(b.pos, clampf(w, W_RANGE.x, W_RANGE.y)))

static func _sag(at: Vector2) -> Vector2:
	return Geo.clamp_in_pool(at + (Geo.goal_center() - at).normalized() * SAG)

## Who he's on (fouls, contact, the attack's reads): the ball's man if he's the one out on him, else
## the end of his lane nearer the ball.
static func _mark(p: Play, d: Swimmer, b: Vector2) -> Swimmer:
	if d == p.zone_primary and p.zone_ball != null:
		return p.zone_ball
	var a := _man(p, LANES[d.zlane][0])
	var c := _man(p, LANES[d.zlane][1])
	if a == null or c == null:
		return a if a != null else c
	return c if c.pos.distance_to(b) < a.pos.distance_to(b) else a

static func _man(p: Play, tag: String) -> Swimmer:
	for a in p.attackers:
		if a.tag == tag and not a.out:
			return a
	return null

## The art's arm: up (on `on`, the side his line to the goal passes him) or coming down.
static func _arm(d: Swimmer, on: Swimmer, dt: float) -> void:
	if on != null:
		d.zreach_on = on
		d.zside = DefenseFormation.arm_side(d, on.pos)
		d.zreach = move_toward(d.zreach, ARM_UP, dt * ARM_RISE)
	else:
		d.zreach = move_toward(d.zreach, 0.0, dt * ARM_FALL)
		if d.zreach <= 0.0:
			d.zreach_on = null
