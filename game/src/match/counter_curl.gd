class_name CounterCurl
## THE COUNTERATTACK ROTATION: how a counterattack the game has ALREADY started is swum, as a
## chain reaction of arrivals. It never decides whether there's a counter: that's
## PlaySetup._counter's (the numbers on the break, Play.is_break), untouched. It starts only once a
## possession is a confirmed counter (Play.kind COUNTER with the break on, Play.carry), and it draws
## no dice (none of the game's rngs).
##
## THE SPOTS are the umbrella's (PlaySetup.HOME_6V6), each owned by the man whose spot it is. Each
## side of the pool is a chain of them from the 2 m line out (CHAINS): the attack's left (the top of
## the screen) 2 m -> 5 -> 4 -> 3, its right (the bottom) 2 m -> 1 -> 2 -> 3. The centre's spot is
## the 2 m one; the point (3) is the end of both chains.
##
## ARRIVING: a man swims down the pool for the deepest spot on his side's chain that's still waiting
## for its owner (who's further from it than he is), or his own if there's none (_choose). An early
## man takes a teammate's spot for him and holds it.
##
## THE CORE RULE: when an incoming man gets within ARRIVE_R of a spot somebody else is holding, the
## man holding it starts rotating to his next spot (_displace): one step further out along his
## chain, again the deepest still waiting for its owner, or his own. He leaves before they meet; the
## incoming man takes it. If that next spot's held too, his own arrival moves its man on in turn: the
## chain reaction. Every move takes a man further out towards his own spot, never back, so it always
## ends, with each man on his own spot: one centre on 2 m and five on the perimeter. Nobody moves on
## a clock: a man holding a spot leaves it only for a teammate coming in, or when the man it's being
## held for has stopped coming (he's on the ball, driving: _release).
##
## Only one man is ever heading for a spot that isn't his (`reserved`); its owner can always come for
## it, and a man still on his way to it peels off for his next one when the owner gets close first.
## The ball always comes first (PlayAI._attack): the man with it, a pass to him, a loose ball, a
## drive take him out of the rotation (drop); when he's free again he swims for his own spot (rejoin).
## The men in the break's lanes run them as before while the break is on (PlayAI._break_spot), and
## come in when it's over. An exclusion, the ball changing hands, the end of the possession: it's off.

const ARRIVE_R := 3.0                  # m from a held spot: an incoming man this close moves its man on
const APPROACH_R := 4.0                # m: "approaching" his spot
const SETTLE_R := 1.5                  # m from his own spot: "settling"
const HOLD_R := 0.6                    # m: he's on it
const LOOK := 1.1                      # m along his route he swims at
const LOST_R := 3.5                    # shoved this far off his route: it's laid out again
const MAX_X := Geo.TWO_M - 0.15        # nobody's route goes inside 2 m without the ball (the 2 m spot is on the line)
const SPRINT_STEP := 1.5               # m down the pool between a sprint's waypoints...
const LANE_SLOPE := 0.6                # ...at most this far across for each (PlayAI.LANE_SLOPE)
const BULGE := 1.8                     # how far out a rotation swings...
const BACK := 1.0                      # ...and how far goal side of his next spot it comes round from
const SAMPLES := 14
const MAX_AGE := 18.0                  # s: a man still not in after this long is left to the set attack
const CLOSER := 1.0                    # m: he takes a spot for its owner only this much nearer it than him
const CHAINS := {-1: ["C", "5", "4", "3"], 1: ["C", "1", "2", "3"]}
const NAMES := {"C": "2M", "1": "POSITION 1", "2": "POSITION 2", "3": "POSITION 3", "4": "POSITION 4", "5": "POSITION 5"}

enum Mode { OFF, LIVE, SETTLING, FINISHED }

## Tests only: false, and no counter is swum this way (the old way instead).
static var enabled := true

## A swim laid out as a polyline: `pts`, the distance along it to each (`cum`), how far he's got (`s`).
class Route:
	var pts := PackedVector2Array()
	var cum := PackedFloat32Array()
	var s := 0.0
	var k := 0
	var rotation := false

	func length() -> float:
		return cum[cum.size() - 1]

	func end() -> Vector2:
		return pts[pts.size() - 1]

	func at(d: float) -> Vector2:
		d = clampf(d, 0.0, length())
		var i := k
		while i > 0 and cum[i] > d:
			i -= 1
		while i < pts.size() - 2 and cum[i + 1] < d:
			i += 1
		var seg := cum[i + 1] - cum[i]
		return pts[i].lerp(pts[i + 1], 0.0 if seg <= 0.0001 else (d - cum[i]) / seg)

	func finish() -> void:
		cum.resize(pts.size())
		cum[0] = 0.0
		for i in range(1, pts.size()):
			cum[i] = cum[i - 1] + pts[i - 1].distance_to(pts[i])

## One man in the rotation.
class Agent:
	var who: Swimmer
	var own := ""            # his own spot (his tag)
	var side := 0.0          # his chain: -1 the top (the attack's left), +1 the bottom; 0 the centre
	var goal := ""           # the spot he's swimming for ("" while he holds one)
	var at := ""             # the spot he's holding for its owner ("" none)
	var rotating := false    # moved on by a teammate coming in (or peeling off)
	var route: Route = null
	var reason := ""
	var by: Swimmer = null   # who moved him on
	var age := 0.0

## The rotation's whole state (Play.rot).
class Rotation:
	var agents := {}         # Swimmer -> Agent: the men in it
	var spots := {}          # spot -> Vector2
	var owner := {}          # spot -> the Swimmer whose spot it is
	var occupant := {}       # spot -> the Swimmer on it (holding it for its owner, or its owner, set)
	var reserved := {}       # spot -> the one man not its owner heading for it
	var done := {}           # Swimmer -> "SET" (on his own spot) | why he's out of it
	var interrupted := {}    # Swimmer -> true: out of it for the ball; back in when he's free
	var joined := {}         # Swimmer -> true: he's been in it (a man joins once; then only rejoins)
	var notes := {}          # Swimmer -> his last reason (Developer Mode, after he's out of it)
	var log: Array = []      # what happened: {t, k, who, by, from, to, d, gap}
	var t := 0.0

# ------------------------------------------------------------------ the counter's lifecycle
## Every frame of the attack (PlayAI._attack, after the break's lanes are sorted out; and the
## breakout, to call it off).
static func update(p: Play, dt: float) -> void:
	if not enabled or p.curl_mode == Mode.FINISHED:
		return
	if p.curl_mode == Mode.OFF:
		# only a counter the game has already started (PlaySetup._counter: kind COUNTER, the break on)
		if p.kind != Play.Kind.COUNTER or not p.carry or p.over or p.breakout or p.man_up > 0.0:
			return
		p.curl_mode = Mode.LIVE
		p.rot = _start(p)
	if p.over or p.breakout or p.man_up > 0.0 or p.kind == Play.Kind.PENALTY:
		cancel_all(p)
		return
	var R: Rotation = p.rot
	R.t += dt
	for a: Swimmer in R.agents.keys():
		var ag: Agent = R.agents[a]
		ag.age += dt
		if a.out or a == p.holder:
			drop(p, a, "ON THE BALL" if a == p.holder else "OUT")
		elif ag.age > MAX_AGE:
			_leave(p, ag, "TOO LONG")
	if p.curl_mode == Mode.LIVE and not p.carry:
		p.curl_mode = Mode.SETTLING   # the break's over: the men from its lanes come in too
	_join_all(p)
	_triggers(p)
	_release(p)
	for a: Swimmer in R.agents.keys():
		_arrive(p, R.agents[a])
	if p.curl_mode == Mode.SETTLING and R.agents.is_empty():
		p.curl_mode = Mode.FINISHED

static func _start(p: Play) -> Rotation:
	var R := Rotation.new()
	for a in p.attackers:
		R.spots[a.tag] = a.home
		R.owner[a.tag] = a
	return R

## Everybody who can come in, does: the men furthest down the pool first (they get the deepest
## spots). Not the man on the ball, a man busy with it, or (while the break's on) its lanes.
static func _join_all(p: Play) -> void:
	var R: Rotation = p.rot
	var busy := p.ball.state == Ball.State.LOOSE
	var men: Array[Swimmer] = []
	for a in p.attackers:
		if a.out or a == p.holder or R.agents.has(a) or R.done.get(a, "") == "SET":
			continue
		if p.carry and p.lanes.has(a) and a.tag != "C":
			continue   # (in the break: his lane, as it always was)
		if a.drive_t > 0.0 or (p.ball.state == Ball.State.PASS and p.ball.receiver == a):
			continue
		if R.interrupted.has(a) and busy:
			continue
		if not p.carry and DefenseFormation.slide_spot(p, a) != Vector2.INF:
			continue   # (5 DROP: he's sliding in, the set attack's job)
		men.append(a)
	men.sort_custom(func(x: Swimmer, y: Swimmer): return x.pos.x > y.pos.x)
	for a in men:   # (all of them in first: a spot's owner coming in with them counts as coming)
		var ag := Agent.new()
		ag.who = a
		ag.own = a.tag
		ag.side = _side(p, a)
		R.agents[a] = ag
	for a in men:
		var ag: Agent = R.agents[a]
		if R.interrupted.has(a) or R.joined.has(a):
			R.interrupted.erase(a)
			_assign(p, ag, a.tag, "BACK IN - TO %s" % NAMES[a.tag])   # (the rotations still needed: his own spot)
		else:
			R.joined[a] = true
			var to := _choose(p, ag, 0)
			_assign(p, ag, to, ("SPRINTING TO %s" % NAMES[to]) if to == a.tag else ("SPRINTING TO %s (HOLDING IT FOR PLAYER %s)" % [NAMES[to], to]))
		_log(p, "join", a, null, "", ag.goal)

## His chain: the side of the pool his spot is on; the point's is the side he's on.
static func _side(p: Play, a: Swimmer) -> float:
	if a.tag == "C":
		return 0.0
	var sy := signf(a.home.y - Geo.GOAL_Y)
	if sy != 0.0:
		return sy
	var dy := a.pos.y - Geo.GOAL_Y
	if absf(dy) > 0.3:
		return signf(dy)
	var b := p.holder.pos if p.holder != null else p.ball.pos
	return -1.0 if b.y >= Geo.GOAL_Y else 1.0

## Where `ag` swims next, looking from `from_i` along his chain out to his own spot: the deepest
## spot still waiting for its owner (he's on his way, further off it than this man) that nobody else
## is heading for; his own if there's none. The centre: always his own.
static func _choose(p: Play, ag: Agent, from_i: int) -> String:
	if ag.side == 0.0:
		return ag.own
	var R: Rotation = p.rot
	var chain: Array = CHAINS[int(ag.side)]
	var mine := chain.find(ag.own)
	for i in range(maxi(from_i, 0), mine + 1):
		var k: String = chain[i]
		if k == ag.own:
			return k
		var o: Swimmer = R.owner.get(k)
		if o == null or not R.agents.has(o):
			continue   # (its owner's set, or not coming: nobody to hold it for)
		if R.reserved.has(k) and R.reserved[k] != ag.who:
			continue
		var spot: Vector2 = R.spots[k]
		if ag.who.pos.distance_to(spot) + CLOSER > o.pos.distance_to(spot):
			continue   # (its owner will be there first)
		return k
	return ag.own

## Sends `ag` for spot `k`, his route laid out from where he is.
static func _assign(p: Play, ag: Agent, k: String, reason: String) -> void:
	var R: Rotation = p.rot
	if ag.goal != "" and R.reserved.get(ag.goal) == ag.who:
		R.reserved.erase(ag.goal)
	ag.goal = k
	if k != ag.own:
		R.reserved[k] = ag.who
	ag.route = _route(ag, R.spots[k])
	ag.reason = reason
	R.notes[ag.who] = reason

## THE CORE RULE. A man coming in for a spot (within ARRIVE_R of it): whoever's holding it for its
## owner moves on. And the owner coming in for his own: a man still on his way to it peels off.
## The man on the ball taking it back out to his spot (Play.rotating) counts as coming in for it.
static func _triggers(p: Play) -> void:
	var R: Rotation = p.rot
	var incoming: Array = []
	for a: Swimmer in R.agents.keys():
		var ag: Agent = R.agents[a]
		if ag.goal != "":
			incoming.append([a, ag.goal])
	if p.rotating != null and p.rotating == p.holder and R.spots.has(p.rotating.tag):
		incoming.append([p.rotating, p.rotating.tag])
	for pair in incoming:
		var a: Swimmer = pair[0]
		var k: String = pair[1]
		var d := a.pos.distance_to(R.spots[k])
		if d > ARRIVE_R:
			continue
		var occ: Swimmer = R.occupant.get(k)
		if occ != null and occ != a and R.agents.has(occ) and (R.agents[occ] as Agent).at == k:
			_displace(p, R.agents[occ], a, d)
		var res: Swimmer = R.reserved.get(k)
		if k == a.tag and res != null and res != a and R.agents.has(res) and (R.agents[res] as Agent).goal == k:
			_peel(p, R.agents[res], a)
		if R.agents.has(a) and occ != a:
			var ag: Agent = R.agents[a]
			if ag.goal == k and not ag.reason.begins_with("TAKING"):
				ag.reason = "TAKING %s" % NAMES[k]
				R.notes[a] = ag.reason

## The man holding spot `k` for its owner, moved on by `by` coming in: one step further out.
static func _displace(p: Play, h: Agent, by: Swimmer, d: float) -> void:
	var R: Rotation = p.rot
	var k := h.at
	h.at = ""
	if R.occupant.get(k) == h.who:
		R.occupant.erase(k)
	var chain: Array = CHAINS[int(h.side)]
	var nxt := _choose(p, h, chain.find(k) + 1)
	h.rotating = true
	h.by = by
	_assign(p, h, nxt, "ROTATING TO %s - PLAYER %s APPROACHING" % [NAMES[nxt], by.tag])
	_log(p, "rotate", h.who, by, k, nxt, d, by.pos.distance_to(h.who.pos))

## A man still on his way to spot `k` for its owner, and the owner's got there first: he peels off for his next.
static func _peel(p: Play, r: Agent, by: Swimmer) -> void:
	var k := r.goal
	var chain: Array = CHAINS[int(r.side)]
	var nxt := _choose(p, r, chain.find(k) + 1)
	r.rotating = true
	r.by = by
	_assign(p, r, nxt, "PEELING OFF TO %s - PLAYER %s TAKING %s" % [NAMES[nxt], by.tag, NAMES[k]])
	_log(p, "peel", r.who, by, k, nxt, by.pos.distance_to((p.rot as Rotation).spots[k]), by.pos.distance_to(r.who.pos))

## A man holding a spot for an owner who's stopped coming (on the ball, out, driving): nobody to wait for.
static func _release(p: Play) -> void:
	var R: Rotation = p.rot
	for a: Swimmer in R.agents.keys():
		var ag: Agent = R.agents[a]
		if ag.at == "" or ag.at == ag.own:
			continue
		var o: Swimmer = R.owner.get(ag.at)
		if o != null and (R.agents.has(o) or (o == p.rotating and o == p.holder)):
			continue
		var k := ag.at
		ag.at = ""
		R.occupant.erase(k)
		var chain: Array = CHAINS[int(ag.side)]
		var nxt := _choose(p, ag, chain.find(k) + 1)
		ag.rotating = true
		ag.by = null
		_assign(p, ag, nxt, "MOVING ON TO %s - PLAYER %s NOT COMING" % [NAMES[nxt], k])
		_log(p, "release", a, null, k, nxt)

## On the spot he was swimming for: his own (set: out of the rotation, the set attack's), or held for its owner.
static func _arrive(p: Play, ag: Agent) -> void:
	if ag.goal == "" or ag.route == null:
		return
	var R: Rotation = p.rot
	var spot: Vector2 = R.spots[ag.goal]
	if ag.who.pos.distance_to(spot) > HOLD_R or ag.route.length() - ag.route.s > HOLD_R + 0.4:
		return
	var k := ag.goal
	if R.reserved.get(k) == ag.who:
		R.reserved.erase(k)
	_face_ball(p, ag.who)
	if k == ag.own:
		R.occupant[k] = ag.who
		R.done[ag.who] = "SET"
		R.notes[ag.who] = "FORMATION READY AT %s" % NAMES[k]
		R.agents.erase(ag.who)
		_log(p, "set", ag.who, null, "", k)
		return
	ag.goal = ""
	ag.at = k
	ag.rotating = false
	ag.route = null
	R.occupant[k] = ag.who
	ag.reason = "HOLDING %s FOR PLAYER %s" % [NAMES[k], k]
	R.notes[ag.who] = ag.reason
	_log(p, "hold", ag.who, null, "", k)

static func _face_ball(p: Play, a: Swimmer) -> void:
	var b := p.holder.pos if p.holder != null else p.ball.pos
	if absf(b.x - a.pos.x) > 0.3:
		a.facing = signf(b.x - a.pos.x)   # (turned to the ball: Swimmer.step keeps it while he's still)

## Out of it for good (too long: the set attack takes him from here).
static func _leave(p: Play, ag: Agent, why: String) -> void:
	var R: Rotation = p.rot
	_unhold(R, ag)
	R.agents.erase(ag.who)
	R.done[ag.who] = why

static func _unhold(R: Rotation, ag: Agent) -> void:
	if ag.goal != "" and R.reserved.get(ag.goal) == ag.who:
		R.reserved.erase(ag.goal)
	if ag.at != "" and R.occupant.get(ag.at) == ag.who:
		R.occupant.erase(ag.at)

## Out of it for now: the ball (he's got it, it's coming to him, it's loose and he's going for it, a
## drive). Back in (for his own spot) when he's free again.
static func drop(p: Play, a: Swimmer, why := "INTERRUPTED") -> void:
	if p.rot == null:
		return
	var R: Rotation = p.rot
	if not R.agents.has(a):
		return
	_unhold(R, R.agents[a])
	R.agents.erase(a)
	R.interrupted[a] = true
	R.notes[a] = why
	_log(p, "interrupt", a, null, "", "")

## Everybody out of it (the counter's been overtaken: an exclusion, the ball changing hands, the end).
static func cancel_all(p: Play) -> void:
	if p.rot != null:
		var R: Rotation = p.rot
		for a: Swimmer in R.agents.keys():
			R.done[a] = "CANCELLED"
		R.agents.clear()
		R.reserved.clear()
	p.curl_mode = Mode.FINISHED

## Where `a` swims this frame (Vector2.INF: he isn't in the rotation): the spot he's holding, or on
## along his route.
static func target(p: Play, a: Swimmer) -> Vector2:
	if p.rot == null or not (p.rot as Rotation).agents.has(a):
		return Vector2.INF
	var R: Rotation = p.rot
	var ag: Agent = R.agents[a]
	if ag.at != "":
		return R.spots[ag.at]
	var rt := ag.route
	if _advance(rt, a.pos) > LOST_R:
		ag.route = _route(ag, R.spots[ag.goal])   # (shoved well off it: laid out again from here)
		rt = ag.route
	return rt.at(rt.s + LOOK)

## On his own spot after the rotation: he holds it (PlayAI._attack, while the break plays out).
static func settled(p: Play, a: Swimmer) -> bool:
	return p.rot != null and (p.rot as Rotation).done.get(a, "") == "SET"

static func _advance(rt: Route, pos: Vector2) -> float:
	var best := INF
	var best_s := rt.s
	var n := rt.pts.size()
	for i in range(rt.k, mini(rt.k + 4, n - 1)):
		var a := rt.pts[i]
		var b := rt.pts[i + 1]
		var c := Geometry2D.get_closest_point_to_segment(pos, a, b)
		var d := pos.distance_to(c)
		if d < best:
			best = d
			best_s = rt.cum[i] + a.distance_to(c)
	rt.s = maxf(rt.s, best_s)
	while rt.k < n - 2 and rt.cum[rt.k + 1] <= rt.s:
		rt.k += 1
	return best

# ------------------------------------------------------------------ the routes
## From where `ag` is to `to`. Coming in from up the pool: a sprint down his lane (joining it on a
## slant), then in to the spot. Rotating (or close already): a curve out to his side and back round
## into the spot from goal side of it, so he rounds the turn rather than cutting back.
static func _route(ag: Agent, to: Vector2) -> Route:
	var a := ag.who
	var rt := Route.new()
	rt.rotation = ag.rotating
	rt.pts.append(a.pos)
	if not ag.rotating and a.pos.x < to.x - 3.0:
		var at := a.pos
		var until := to.x - 1.5
		while at.x < until - 0.01:
			var dx := minf(SPRINT_STEP, until - at.x)
			var lim := dx * LANE_SLOPE + 0.3
			at = Vector2(at.x + dx, at.y + clampf(to.y - at.y, -lim, lim))
			rt.pts.append(at)
		_cubic(rt, at, at + Vector2(0.6, 0.0), to - Vector2(0.6, 0.0), to)
	else:
		var d0 := a.vel.normalized() if a.speed() > 0.4 else (to - a.pos).normalized()
		var side := ag.side
		if side == 0.0:
			side = signf(to.y - a.pos.y) if absf(to.y - a.pos.y) > 0.3 else 1.0
		var out := swing(a.pos, to, side)
		var p1: Vector2
		var p2: Vector2
		if ag.rotating:
			p1 = a.pos + d0 * 0.6 + out * BULGE
			p2 = to + Vector2(BACK, 0.0) + out * BULGE * 0.5
		else:
			var dist := a.pos.distance_to(to)
			p1 = a.pos + d0 * dist * 0.35
			p2 = to - (to - a.pos).normalized() * dist * 0.3
		_cubic(rt, a.pos, _keep(p1), _keep(p2), to)
	rt.finish()
	return rt

## The way a rotation from `from` to `to` bows: off the straight line between them, towards his side
## of the pool (up for the top, down for the bottom), and back up the pool where that's ambiguous
## (straight across from the 2 m spot to a wing: never in at the goal, inside 2 m). The tests judge
## the swim by the same line.
static func bow(from: Vector2, to: Vector2, side: float) -> Vector2:
	var n := (to - from).orthogonal().normalized()
	if absf(n.y) < 0.3:
		return n if n.x < 0.0 else -n   # (back up the pool)
	return n if signf(n.y) == signf(side) else -n

static func swing(from: Vector2, to: Vector2, side: float) -> Vector2:
	return (bow(from, to, side) + Vector2(0.0, side)).normalized()

static func _keep(q: Vector2) -> Vector2:
	q = Geo.clamp_in_pool(q)
	q.x = minf(q.x, MAX_X)
	return q

static func _cubic(rt: Route, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> void:
	for i in range(1, SAMPLES + 1):
		var t := float(i) / SAMPLES
		var u := 1.0 - t
		var q := p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t
		if i < SAMPLES:
			q = _keep(q)
		rt.pts.append(q)

static func _log(p: Play, k: String, who: Swimmer, by: Swimmer, from: String, to: String, d := -1.0, gap := -1.0) -> void:
	var R: Rotation = p.rot
	R.log.append({"t": R.t, "k": k, "who": who, "by": by, "from": from, "to": to, "d": d, "gap": gap})

# ------------------------------------------------------------------ Developer Mode
## What `a` is doing on the counter right now (SHOW PLAYER STATES, the tests).
static func state_of(p: Play, a: Swimmer) -> String:
	if a.out:
		return "OUT"
	if a == p.holder:
		return "ON THE BALL"
	var R: Rotation = p.rot
	if R == null:
		return "-"
	if R.agents.has(a):
		var ag: Agent = R.agents[a]
		if ag.at != "":
			var res: Swimmer = R.reserved.get(ag.at)
			var own: Swimmer = R.owner.get(ag.at)
			for c in [res, own]:
				if c != null and c != a and R.agents.has(c) and (R.agents[c] as Agent).goal == ag.at \
						and c.pos.distance_to(R.spots[ag.at]) < ARRIVE_R * 2.0:
					return "INCOMING TEAMMATE"
			return "HOLDING POSITION"
		var d := a.pos.distance_to(R.spots[ag.goal])
		if ag.goal == ag.own and d < SETTLE_R:
			return "SETTLING"
		if ag.rotating:
			return "ROTATING"
		return "SPRINTING" if d > APPROACH_R else "APPROACHING POSITION"
	if R.done.get(a, "") == "SET":
		return "FORMATION READY"
	if p.carry and p.lanes.has(a):
		return "BREAK LANE"
	if R.interrupted.has(a):
		return "ON THE PLAY"
	return "SET ATTACK"

## Why (the lab shows it as "PLAYER 3: ROTATING TO POSITION 4 - PLAYER 5 APPROACHING", "PLAYER 5: TAKING POSITION 3").
static func reason_of(p: Play, a: Swimmer) -> String:
	if p.rot == null:
		return ""
	var R: Rotation = p.rot
	if R.agents.has(a):
		return (R.agents[a] as Agent).reason
	return String(R.notes.get(a, ""))

## Who's on each spot now: {spot: [the man, held for its owner (true) or his own (false)]}.
static func owners(p: Play) -> Dictionary:
	var out := {}
	if p.rot == null:
		return out
	var R: Rotation = p.rot
	for k: String in R.occupant.keys():
		var s: Swimmer = R.occupant[k]
		out[k] = [s, s.tag != k]
	return out

## Where a man holding a spot would go if he were moved on now (SHOW PATHS' pending rotations).
static func next_for(p: Play, a: Swimmer) -> String:
	if p.rot == null or not (p.rot as Rotation).agents.has(a):
		return ""
	var ag: Agent = (p.rot as Rotation).agents[a]
	if ag.at == "":
		return ""
	return _choose(p, ag, (CHAINS[int(ag.side)] as Array).find(ag.at) + 1)

## Short labels for the overlay.
const SHORT := {"SPRINTING": "SPRINT", "APPROACHING POSITION": "APPROACH", "HOLDING POSITION": "HOLD",
	"INCOMING TEAMMATE": "INCOMING!", "ROTATING": "ROTATE", "SETTLING": "SETTLE", "FORMATION READY": "READY",
	"BREAK LANE": "LANE", "ON THE BALL": "BALL", "ON THE PLAY": "PLAY", "SET ATTACK": "SET", "OUT": "OUT", "-": "-"}
