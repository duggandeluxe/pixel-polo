class_name PlaySetup
## Formations and starting positions for each kind of possession.

## 6 on 6 "umbrella": the centre on 2 m, five spread round the arc (4-5 m between them, so
## there's a lane to swing it through). "1" is the right side of the attack (bottom of the
## screen), where a lefty shoots from. "3", the point, is just outside 6 m (Geo.SIX_M), never
## inside it in the set-up (POINT_MAX_X).
const HOME_6V6 := {
	"C": Vector2(28.0, 10.0), "1": Vector2(27.2, 16.4), "2": Vector2(24.5, 14.3),
	"3": Vector2(23.4, 10.0), "4": Vector2(24.5, 5.7), "5": Vector2(27.2, 3.6),
}
const POINT_MAX_X := Geo.SIX_M - 0.3
## 6 on 5 power play "4-2": four on the 2 m line, two at 5 m.
const HOME_4_2 := {
	"C": Vector2(28.1, 11.4), "1": Vector2(28.0, 14.4), "2": Vector2(25.0, 12.5),
	"3": Vector2(25.0, 7.5), "4": Vector2(28.1, 8.6), "5": Vector2(28.0, 5.6),
}
const TAGS := ["C", "1", "2", "3", "4", "5"]
## Counterattacks (see _counter): the break picks up with the ball about COUNTER_PICKUP m up the
## pool. When the ball changes hands the new attackers are already facing the right way and
## react in ATTACK_REACT s; the team that lost it has to turn round first (DEFENCE_TURN s, and
## the man who lost it LOSER_TURN more) but then swims back flat out.
const COUNTER_PICKUP := 13.0
const ATTACK_REACT := Vector2(0.1, 0.5)
const DEFENCE_TURN := Vector2(0.2, 0.8)
const LOSER_TURN := 1.6
const OUTLET_TIME := 0.6      # the keeper has it: the outlet pass takes this long
const BREAK_SWIM := 1.15      # counter speeds (Swimmer.boost): the attack...
const CARRY_SWIM := 1.05      # ...the man with the ball...
const RECOVER_SWIM := 1.2     # ...and the defence getting back

static func build(p: Play, snap: Dictionary = {}) -> void:
	var ours := seven(p.us)
	var theirs := seven(p.them)
	# the seven come in their places (PoloTeam.starters: LINEUP_SPOTS order, TAGS' order), a
	# lefty already on the right side, "1" or "2"
	var order: Array = ours.slice(1)
	for i in 6:
		var a := Swimmer.new(order[i], Swimmer.Side.US)
		a.tag = TAGS[i]
		p.attackers.append(a)
	# their best wrestler guards our centre; a lefty the right of our attack, their own left
	var dfield := marking(theirs)
	for i in 6:
		var d := Swimmer.new(dfield[i], Swimmer.Side.THEM)
		d.mark = p.attackers[i]
		d.dtag = p.attackers[i].tag
		p.defenders.append(d)
	p.keeper = Swimmer.new(theirs[0], Swimmer.Side.THEM, true)
	mark_gone(p)
	p.keeper.pos = Vector2(Geo.KEEPER_X, Geo.GOAL_Y)
	apply_formation(p, false)
	match p.kind:
		Play.Kind.COUNTER:
			_counter(p, snap)
		Play.Kind.PENALTY:
			_penalty(p, bool(snap.get("shootout", false)))
		_:
			_half_court(p)
	for s in p.bodies():
		s.target = s.pos

## A defending team's field players (from its `starters`), best wrestler first: the first guards
## the centre.
## A team's seven for a possession (PoloTeam.starters). With so many ROLLED that it can't make
## seven (four in one game, from a ten-man roster), the places left over are taken by rolled men
## who stay out of the water (mark_gone): the team plays short, nobody comes back.
static func seven(t: PoloTeam) -> Array:
	var out: Array = t.starters()
	for q in t.roster:
		if out.size() >= PoloTeam.STARTERS:
			break
		if not out.has(q):
			out.append(q)
	return out

## Keeps every ROLLED stand-in (seven) out of the water for the possession.
static func mark_gone(p: Play) -> void:
	for s in p.attackers + p.defenders:
		if s.player.rolled:
			s.out = true

## Who marks whom (defender i on attacker TAGS[i]): the best wrestler (never a lefty, while
## there's anyone else) on the centre, the lefties on "1" and "2", the right of the attack, the
## defence's own left side of the goal, at either end and in every drop and the press (they're
## all by these tags); everybody else in wrestling order.
static func marking(starters: Array) -> Array:
	var field := wrestlers(starters)
	var lefties: Array = field.filter(func(q: PoloPlayer): return q.is_lefty())
	if lefties.is_empty():
		return field
	var rest: Array = field.filter(func(q: PoloPlayer): return not q.is_lefty())
	var out: Array = [rest.pop_front() if not rest.is_empty() else lefties.pop_front()]
	for _k in 2:
		if not lefties.is_empty():
			out.append(lefties.pop_front())
		elif not rest.is_empty():
			out.append(rest.pop_front())
	return out + rest + lefties

static func wrestlers(starters: Array) -> Array:
	var field := starters.slice(1)
	field.sort_custom(func(x: PoloPlayer, y: PoloPlayer): return x.strength + x.defense > y.strength + y.defense)
	return field

static func apply_formation(p: Play, man_up: bool) -> void:
	var homes: Dictionary = HOME_4_2 if man_up else HOME_6V6
	for a in p.attackers:
		a.home = homes[a.tag]

## After a goal against or a turnover: the team swims into the arc, point has the ball.
static func _half_court(p: Play) -> void:
	for a in p.attackers:
		a.pos = a.home + Vector2(p.rng.randf_range(-4.5, -3.0), p.rng.randf_range(-0.8, 0.8))
	for d in p.defenders:
		d.pos = d.mark.pos + Vector2(p.rng.randf_range(0.8, 2.0), p.rng.randf_range(-0.6, 0.6))
	# the centre's man came down the pool with him: on his back, between him and the ball
	var c := _by_tag(p, "C")
	PlayAI.center_pair(p).pos = c.pos + Vector2(-PlayAI.CENTER_TRAIL, 0.0)
	p.give_ball(_by_tag(p, "3"))

## After a steal or a keeper save: the break grows out of where everybody was when the ball
## changed hands (`snap`, from Play.snapshot; made up if there's none). Nobody is placed on a
## spot: each man swims from where he was, the attack reacting first and the defence turning
## round, and the play picks up a few seconds in, when the ball is about COUNTER_PICKUP m up.
##
## Where the ball was won decides what it starts (steal_line):
##  - on the bottom line (their 2 m line: the wings, the centre) there's no break. Everybody's
##    down by the goal, so the team that won it just sets up (a normal possession).
##  - out on the top line (the perimeter) it's a break: usually 3 on 2, often 2 on 1, now and
##    then a man clean away (BREAK_ODDS, leaned on by where everybody was: _break_odds). Who's
##    in it comes from where they were too: the men nearest the ball and furthest up lead it,
##    the men of theirs who were furthest back (the perimeter) are the ones getting back.
##  - anything else (a save, a steal in open water) is just where everybody was: whoever's
##    ahead is in the break, whoever was caught is trailing; numbers from 1 on 1 to 3 on 0.
static func _counter(p: Play, snap: Dictionary) -> void:
	if snap.is_empty():
		snap = _made_up_turnover(p)
	var spots: Dictionary = snap.get("pos", {})
	for s in p.attackers + p.defenders:
		s.pos = spots.get(s.player, s.home + Vector2(-12.0, 0.0))
	var holder: Swimmer = null
	for a in p.attackers:
		if a.player == snap.get("holder"):
			holder = a
	var outlet := holder == null   # the keeper's ball (a save, a claimed pass): he throws it out
	if outlet:
		holder = p.attackers[0]
		for a in p.attackers:
			if a.pos.x > holder.pos.x:
				holder = a
	p.steal_line = "" if outlet else steal_line(snap)
	if p.steal_line == "bottom":
		_no_break(p, holder)
		return
	var shape := {}
	if p.steal_line == "top":
		shape = _shape_break(p, holder, snap)
	var ball_x := holder.pos.x
	var t := clampf((COUNTER_PICKUP - ball_x) / (holder.top_speed * CARRY_SWIM), 0.8, 5.0)
	for a in p.attackers:
		var lag := OUTLET_TIME if outlet else 0.0
		if a != holder:
			lag += p.rng.randf_range(ATTACK_REACT.x, ATTACK_REACT.y)
		var boost := CARRY_SWIM if a == holder else BREAK_SWIM
		var swim := maxf(0.0, t - lag) * a.top_speed * boost
		a.pos.x = minf(a.pos.x + swim, 26.0 if a != holder else COUNTER_PICKUP + 1.0)
		# fanning out into lanes, away from the ball
		a.pos.y = lerpf(a.pos.y, clampf(a.pos.y, 3.5, 16.5), 0.5)
		a.vel = Vector2(a.top_speed * boost, 0.0) if swim > 0.0 else Vector2.ZERO
	for d in p.defenders:
		var turn := p.rng.randf_range(DEFENCE_TURN.x, DEFENCE_TURN.y)
		if d.player == snap.get("lost_by"):
			turn += LOSER_TURN
		var swim := maxf(0.0, t - turn) * d.top_speed * RECOVER_SWIM
		d.pos.x = minf(d.pos.x + swim, 27.0)
		d.pos.y = lerpf(d.pos.y, Geo.GOAL_Y, clampf(swim / 30.0, 0.0, 0.3))
		d.vel = Vector2(d.top_speed * RECOVER_SWIM, 0.0) if swim > 0.0 else Vector2.ZERO
	p.give_ball(holder)
	if not shape.is_empty():
		_settle_break(p, holder, shape)
	_trail_center(p, snap)
	p.carry = true
	p._hold_ball()
	p.break_n = p.break_numbers()
	if not p.is_break():
		# level numbers: no counter, just the ball. They play it as a normal possession from
		# where they are (MatchFlow sets up a fresh half court instead).
		_no_break(p, holder)
		return
	PlayAI.counter_marks(p)

static func _no_break(p: Play, holder: Swimmer) -> void:
	if p.holder == null:
		p.give_ball(holder)
	p.kind = Play.Kind.HALF_COURT
	p.carry = false
	p.counter_t = 0.0

## Where in their attack the ball was won (`snap`, in the frame of the team that won it): "top"
## (out on the perimeter, TOP_LINE_X..BOTTOM_LINE_X from the goal they were attacking),
## "bottom" (deeper: the 2 m line), or "" (not won off a man in their set attack: a save, a shot
## wide, the shot clock, a ball won out in open water).
const BOTTOM_LINE_X := 26.6
const TOP_LINE_X := 19.0
static func steal_line(snap: Dictionary) -> String:
	if not String(snap.get("why", "")) in ["steal", "turnover"] or snap.get("holder") == null:
		return ""
	var at: Variant = snap.get("at")
	if at == null:
		return ""
	var x := Geo.LENGTH - (at as Vector2).x   # (back in their frame: they were attacking x = 30)
	if x >= BOTTOM_LINE_X:
		return "bottom"
	return "top" if x >= TOP_LINE_X else ""

## A top-line steal: the numbers on the break (3 on 2, 2 on 1, 1 on 0: BREAK_ODDS), and who.
## The odds lean on where everybody was: clean away needs nobody of theirs near him
## (CLEAR_AWAY: it takes a pass picked off out in the lane), and is less likely with one on him; three in the break needs two more of his
## close enough to go with him (BREAK_MATES_R). In the break: the man with the ball and the men
## of his nearest it and furthest up, with a little luck, so it's not the same three every time.
## Back: the men of theirs furthest back (nearest their own goal), the man who lost it least.
const BREAK_ODDS := [[3, 2, 0.55], [2, 1, 0.35], [1, 0, 0.10]]
const CLEAR_AWAY := 2.0
const BREAK_MATES_R := 9.0
const BREAK_LUCK := 3.0       # metres of luck in who goes and who gets back

static func _shape_break(p: Play, holder: Swimmer, snap: Dictionary) -> Dictionary:
	var nearest := INF
	for d in p.defenders:
		nearest = minf(nearest, d.pos.distance_to(holder.pos))
	var mates := 0
	for a in p.attackers:
		if a != holder and a.pos.distance_to(holder.pos) <= BREAK_MATES_R:
			mates += 1
	var weights: Array[float] = []
	var total := 0.0
	for o: Array in BREAK_ODDS:
		var w := float(o[2])
		if int(o[0]) == 1:
			w *= 2.2 if nearest >= CLEAR_AWAY else 0.8
		elif int(o[0]) - 1 > mates:
			w *= 0.3
		weights.append(w)
		total += w
	var r := p.rng.randf() * total
	var pick: Array = BREAK_ODDS[BREAK_ODDS.size() - 1]
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			pick = BREAK_ODDS[i]
			break
	var with := p.attackers.filter(func(a: Swimmer): return a != holder and not a.out)
	var score := {}
	for a: Swimmer in with:
		score[a] = a.pos.x * 0.5 - a.pos.distance_to(holder.pos) * 0.5 + p.rng.randf() * BREAK_LUCK
	with.sort_custom(func(x: Swimmer, y: Swimmer): return score[x] > score[y])
	var back := p.defenders.filter(func(d: Swimmer): return not d.out)
	for d: Swimmer in back:
		score[d] = d.pos.x + p.rng.randf() * BREAK_LUCK - (3.0 if d.player == snap.get("lost_by") else 0.0)
	back.sort_custom(func(x: Swimmer, y: Swimmer): return score[x] > score[y])
	return {"with": with.slice(0, int(pick[0]) - 1), "back": back.slice(0, int(pick[1]))}

## The break picked up (_counter): the men in it level with the ball or just behind it, in their
## lanes; the rest of his team a few strides behind, coming; the men of theirs who got back goal
## side of the ball, swimming; the ones who were caught turning behind it, chasing.
static func _settle_break(p: Play, holder: Swimmer, shape: Dictionary) -> void:
	var bx := holder.pos.x
	for a in p.attackers:
		if a == holder or a.out:
			continue
		if a in shape.with:
			a.pos.x = clampf(a.pos.x, bx - Play.BREAK_TRAIL + 0.5, minf(26.0, bx + 1.2))   # (never past his lane: _break_spot)
			a.vel = Vector2(a.top_speed * BREAK_SWIM, 0.0)
		else:
			a.pos.x = minf(a.pos.x, bx - Play.BREAK_TRAIL - p.rng.randf_range(0.8, 4.0))
	PlayAI.assign_lanes(p)
	for a in shape.with:
		a.pos.y = PlayAI.break_lane(p, a, holder.pos)
	for d in p.defenders:
		if d.out:
			continue
		if d in shape.back:
			d.pos.x = clampf(maxf(d.pos.x, bx + p.rng.randf_range(0.5, 4.0)), bx - Play.BREAK_BACK + 0.5, 27.0)
		else:
			d.pos.x = minf(d.pos.x, bx - Play.BREAK_BACK - p.rng.randf_range(0.6, 3.5))
		d.vel = Vector2(d.top_speed * RECOVER_SWIM, 0.0)

## The centre's own man swam down the pool with him, on his back (PlayAI.CENTER_TRAIL behind him,
## at his pace), if he was with him when the ball changed hands (CENTER_WITH_R): he doesn't fall
## metres behind on the way. Not one who got back goal side of the ball (he's stopping the break,
## and counts in it: Play.break_numbers), and never off the centre with the ball.
const CENTER_WITH_R := 3.0

static func _trail_center(p: Play, snap: Dictionary) -> void:
	var c := _by_tag(p, "C")
	var g := PlayAI.center_pair(p)
	if c == p.holder or c.out or g == null or g.out or g.pos.x >= p.holder.pos.x - Play.BREAK_BACK:
		return
	var spots: Dictionary = snap.get("pos", {})
	if not spots.has(c.player) or not spots.has(g.player) \
			or (spots[c.player] as Vector2).distance_to(spots[g.player]) > CENTER_WITH_R:
		return
	g.pos = c.pos + Vector2(-PlayAI.CENTER_TRAIL, 0.0)
	g.vel = c.vel
	g.mark = c

## No last possession to pick up from (a test, the title demo, multiplayer): their attack was
## set up in the umbrella with us marking it, and one of us took it off his man. Usually it's at
## the top of their arc, sometimes a wing or the centre, once in a while a pass picked off with
## their attack caught deep.
static func _made_up_turnover(p: Play) -> Dictionary:
	var pos := {}
	var vel := {}
	var lost: Swimmer = p.defenders[0]
	var stealer: Swimmer = p.attackers[0]
	var r := p.rng.randf()
	var at: String = "3" if r < 0.45 else (["2", "4"][p.rng.randi() % 2] if r < 0.75 else (["1", "5"][p.rng.randi() % 2] if r < 0.9 else "C"))
	var caught_deep := p.rng.randf() < 0.15   # their attack crashed the goal: we're away
	for i in p.defenders.size():
		var d := p.defenders[i]
		var a := p.attackers[i]   # we were marking the man we now play alongside
		var home: Vector2 = HOME_6V6[TAGS[i]]
		# their man, in our frame: turned round to attack the other way
		var them_at := Vector2(Geo.LENGTH - home.x, home.y) + Vector2(p.rng.randf_range(-0.5, 0.5), p.rng.randf_range(-0.6, 0.6))
		if caught_deep:
			them_at.x -= p.rng.randf_range(0.5, 2.5)
		pos[d.player] = them_at
		# we were goal side of him: further from the goal we now attack
		pos[a.player] = them_at + Vector2(-p.rng.randf_range(0.6, 1.2), p.rng.randf_range(-0.3, 0.3))
		if TAGS[i] == at:
			lost = d
			stealer = a
	return {"pos": pos, "vel": vel, "holder": stealer.player, "lost_by": lost.player, "why": "steal",
		"at": pos[stealer.player]}

## Penalties. Two separate set-ups, never mixed: a 5 m penalty in the four quarters (_penalty)
## and a shootout kick after them (_shootout). Either way the shooter is on the 5 m line
## (Geo.FIVE_M) square to the goal, the keeper in the middle of his, and nobody moves until the
## shot: PlayAI only runs the keeper on a penalty.
##
## In the quarters: one defender either side of the shooter, a little back off the line and
## well wide of him (clear of his arm and the shot), and everybody else at half pool, staggered,
## just on the goal side of halfway (PEN_HALF_X): the match camera, framed on the shooter and
## the goal, catches only the edge of them.
const PEN_BESIDE := [-2.2, 2.2]              # the two defenders, across from the shooter (m)...
const PEN_BESIDE_BACK := 0.4                 # ...and this far back off the 5 m line
const PEN_HALF_X := Vector2(16.15, 16.5)     # the half-pool line-up: staggered between these...
const PEN_HALF_ROW := Vector2(3.0, 17.0)     # ...wall to wall...
const PEN_HALF_DEF := [1, 4, 7]              # ...with the spare defenders in these slots

static func _penalty(p: Play, shootout: bool = false) -> void:
	if shootout:
		_shootout(p)
		return
	var shooter := _pen_shooter(p)
	var beside: Array[Swimmer] = []
	var rest: Array[Swimmer] = []
	for d in p.defenders:
		if beside.size() < PEN_BESIDE.size():
			beside.append(d)
		else:
			rest.append(d)
	for i in beside.size():
		beside[i].pos = Vector2(Geo.FIVE_M - PEN_BESIDE_BACK, Geo.GOAL_Y + PEN_BESIDE[i])
	# half pool: the other five attackers and the spare defenders, evenly spaced, staggered
	var others := p.attackers.filter(func(a): return a != shooter)
	var row: Array[Swimmer] = []
	var slots := others.size() + rest.size()
	for i in slots:
		if i in PEN_HALF_DEF and not rest.is_empty():
			row.append(rest.pop_front())
		elif not others.is_empty():
			row.append(others.pop_front())
		else:
			row.append(rest.pop_front())
	for i in row.size():
		var y := lerpf(PEN_HALF_ROW.x, PEN_HALF_ROW.y, i / maxf(1.0, row.size() - 1.0))
		row[i].pos = Vector2(PEN_HALF_X.y if i % 2 == 0 else PEN_HALF_X.x, y)
	_pen_settle(p, shooter)

## A shootout kick: just the shooter and their keeper (Play.bodies). Nobody else is in the
## water: bodies() leaves the rest out of drawing, moving, catching and the snapshot, and they're
## parked at the far end of the pool, nowhere near the shot or the camera, all the same.
const SHOOTOUT_PARK_X := 3.0

static func _shootout(p: Play) -> void:
	var shooter := _pen_shooter(p)
	p.shootout = true
	var parked := (p.attackers + p.defenders).filter(func(s): return s != shooter)
	for i in parked.size():
		parked[i].pos = Vector2(SHOOTOUT_PARK_X, lerpf(PEN_HALF_ROW.x, PEN_HALF_ROW.y, i / maxf(1.0, parked.size() - 1.0)))
	_pen_settle(p, shooter)

static func _pen_shooter(p: Play) -> Swimmer:
	var shooter := p.attackers[0]
	for a in p.attackers:
		if a.player.shoot > shooter.player.shoot:
			shooter = a
	shooter.pos = Vector2(Geo.FIVE_M, Geo.GOAL_Y)
	p.taker = shooter
	return shooter

static func _pen_settle(p: Play, shooter: Swimmer) -> void:
	for s in p.attackers + p.defenders:
		s.vel = Vector2.ZERO
		s.facing = 1.0   # everybody watching the goal
	p.keeper.pos = Vector2(Geo.KEEPER_X, Geo.GOAL_Y)
	p.shot_clock = 5.0
	p.give_ball(shooter)

static func _by_tag(p: Play, t: String) -> Swimmer:
	for a in p.attackers:
		if a.tag == t:
			return a
	return p.attackers[0]
