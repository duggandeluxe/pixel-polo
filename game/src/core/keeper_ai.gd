class_name KeeperAI
extends RefCounted
## The AI keeper's mind (their keeper on your shots, any keeper the bots shoot at). Two stages:
##
## ANTICIPATION, before the ball leaves the hand. He never knows where it's going: he reads what
## he can see (read(): the room either side of him, the angle, how close and central the shooter
## is, a shooter under pressure, where this team's shots went earlier: `memory`) and picks a way,
## LEFT, UP or RIGHT (choose()). Never the aim, the ball, or the line it'll fly on. How much that
## pick matters is how long the shooter has had it (anticipation()): a quick release gives him
## nothing to read and he almost never goes early; the longer it's held, the likelier he sets off
## as the arm comes through, and the earlier. Right, and he's already on his way; wrong, and
## he's committed to the wrong side. (Play also shows the read: he leans that way, LEAN_MAX.)
##
## REACTION, once it's away. After he's seen it (recognize_time: LUNGE SPEED, later for a quick
## release, a catch and shoot, a ball across his body) he knows its line and goes for it
## (react_side): the way it's going, timed for when it'll get to him. No dice in which way: a
## shot to his left is a dive to his left. Seeing it is not saving it: his dive (KeeperDive, his
## attributes) still has to get a hand there before it crosses (ShotModel).
##
## If he'd already gone the wrong way (ShotModel): barely started (KeeperDive.Commit.MINIMAL), a
## quick correction, a new dive after MINOR_FIX; further, the PANIC (KeeperDive.turn): a limited
## claw back, never a second dive, never across the goal once he'd fully committed.
##
## Difficulty (Difficulty.value: gk_read, gk_temp, gk_memory, mistake) is how well he reads before
## the shot and how loosely he picks: his body (reach, speed, hands, how quickly he sees it) is his
## attributes', the same at every level.
##
## Sides are the keeper's own, facing the play (KeeperDive): LEFT (-1) up the screen (lower pool
## y), RIGHT (+1) down it, UP (CENTRE, 0) a block straight up out of the water.

## His state (state_of), for the screen and the tests. COMMITTED_*: he set off before he saw it
## (anticipation); REACTING: he's going for the ball he saw; LEANING: he's read it and shades that
## way; PANIC_RECOVERY: clawing back from the wrong way; BLOCKING: the ball's on him.
enum State { READY, ANTICIPATING, COMMITTED_LEFT, COMMITTED_RIGHT, COMMITTED_UP, RECOVERING,
	LEANING, REACTING, PANIC_RECOVERY, BLOCKING }
const STATE_NAMES := ["READY", "ANTICIPATING", "COMMITTED_LEFT", "COMMITTED_RIGHT", "COMMITTED_UP", "RECOVERING",
	"LEANING", "REACTING", "PANIC_RECOVERY", "BLOCKING"]
const NO_READ := -99

## Anticipation (anticipation()): how long the shooter's had it, in shooting range (Play.hold_t).
## Under HOLD.x he's barely had a look; from HOLD.y he's had all he'll get.
const HOLD := Vector2(0.3, 1.6)
const READ_AT := 0.25          # he's read it (Play shows his lean) once it's been held this long
const COMMIT_P := Vector2(0.05, 0.45)   # the chance he sets off before he's seen it: a snap shot .. a long hold
const COMMIT_LEAD := Vector2(0.02, 0.14) # ...and how early, at most (s before the release)
## ...and close in he knows he won't see it in time: from COMMIT_NEAR.x m out (to the middle of the
## goal) to COMMIT_NEAR.y he's likelier and likelier to go early whatever the hold, up to COMMIT_NEAR_P.
const COMMIT_NEAR := Vector2(6.5, 3.5)
const COMMIT_NEAR_P := 0.75
const LEAN_MAX := 0.12         # m he shades towards his read on a long hold (Play)
## Reaction: he sees where it's going this long after the release (worst .. best LUNGE SPEED,
## times Attributes.lunge_mult). Then the push off and the rise are his dive's (KeeperDive).
const RECOGNIZE := Vector2(0.36, 0.20)   # (tuned with RISE: the average keeper saves what he did before, --test keeper_measure)
const RECOGNIZE_SD := 0.22     # ...give or take this share, shot to shot (a delayed reaction, never a wrong one)
## His dive in live play (ShotModel): across the goal in real time, so the rise to full stretch takes
## RISE times KeeperDive.EXTEND (0.30 s; your keeper's, on screen time in his slow-motion duel, stays
## 0.12). An ease-out: the first half of his reach comes quickly, a far corner takes the lot.
const RISE := 2.5
const MINOR_FIX := 0.05        # a lean the wrong way (Commit.MINIMAL) costs him this much to undo
const LEAN_FIX := 0.04         # ...and a shade the wrong way (LEAN_MAX in full) this much

## The sharp read
const OPEN_POW := 1.6          # shooters go for the open net: the room either side of him, to this power
const FAR_POST := 0.32         # from off to one side, this much more on the far post (cross-cage)...
const FAR_FULL := 2.0          # ...in full this far (m) across from the middle of the goal
const UP_BASE := 0.12          # a shot he should block straight up...
const UP_CLOSE := 0.3          # ...more the closer and more central the shooter
const UP_PRESSED := 0.12       # ...and a shooter with a man in his face puts it less in the corner
const PRESSED_R := 1.2
const UP_PENALTY := 0.2
const MEMORY_FULL := 4.0       # shots seen before his memory counts in full
## The naive read (EASY's end of gk_read): he goes to the shooter's side, the near post. Easy to
## see, easy to beat across the cage.
const NAIVE_NEAR := 0.52
const NAIVE_UP := 0.3
const NAIVE_CENTRAL := 0.8     # a shooter this close to the middle has no near post: even
## Timing (the same for every level: his body's). A dive he's forced into (a drill: ShotModel's
## dive_side) or one he sets off on before the release goes once he's reacted to the arm coming
## through (GO_REACT, his LUNGE SPEED), timed for a shot at the pace he expects (READ_SPEED) to get
## to him INTO his window. Once he's seen it fly he times it for the ball he saw, give or take
## TIMING_ERR.
const GO_REACT := Vector2(0.12, 0.04)   # s from the release (worst .. best lunge skill), times Attributes.lunge_mult
const LEAD := 0.04
const SEEN_MIN := 0.03
const READ_SPEED := 13.5
const TIMING_ERR := 0.08       # his read of when it gets to him: off by this share (sd)
const INTO := 0.35

## Weights (LEFT, UP, RIGHT) for a shot he can see coming from `info` (normalised), at
## decision level `iq` (Difficulty: 0 EASY .. 1 HARD). `info`: from, keeper_y, pressure (m to
## the nearest defender), close (0..1, Play.close_chance), penalty, memory (Vector3 of where
## earlier shots went: the shooter's near post, the middle, the far post; remember()).
static func read(info: Dictionary, iq: float) -> Vector3:
	var sharp := sharp_read(info, Difficulty.value("gk_memory", iq))
	var naive := naive_read(info)
	return _norm(naive.lerp(sharp, Difficulty.value("gk_read", iq)))

## What a keeper who reads the shot well sees.
static func sharp_read(info: Dictionary, memory_weight: float = 0.0) -> Vector3:
	var from: Vector2 = info.get("from", Vector2(Geo.FIVE_M, Geo.GOAL_Y))
	var ky := float(info.get("keeper_y", Geo.GOAL_Y))
	var room_l := clampf(ky - (Geo.GOAL_Y - Geo.GOAL_HALF), 0.05, Geo.GOAL_HALF * 2.0)
	var room_r := clampf((Geo.GOAL_Y + Geo.GOAL_HALF) - ky, 0.05, Geo.GOAL_HALF * 2.0)
	var ol := pow(room_l, OPEN_POW)
	var o_r := pow(room_r, OPEN_POW)
	var share_l := ol / (ol + o_r)
	# from off to one side: the far post (the shooter's side is -1 up the screen, +1 down it)
	var side := signf(from.y - Geo.GOAL_Y)
	var far := FAR_POST * clampf(absf(from.y - Geo.GOAL_Y) / FAR_FULL, 0.0, 1.0)
	if side > 0.0:
		share_l = clampf(share_l + far, 0.0, 1.0)
	elif side < 0.0:
		share_l = clampf(share_l - far, 0.0, 1.0)
	var close := float(info.get("close", 0.0))
	var central := 1.0 - clampf(absf(from.y - Geo.GOAL_Y) / 4.0, 0.0, 1.0)
	var up := UP_BASE + UP_CLOSE * close * central
	if float(info.get("pressure", 99.0)) < PRESSED_R:
		up += UP_PRESSED
	if bool(info.get("penalty", false)):
		up = UP_PENALTY
	up = clampf(up, 0.05, 0.8)
	var w := Vector3((1.0 - up) * share_l, up, (1.0 - up) * (1.0 - share_l))
	var mem: Vector3 = info.get("memory", Vector3.ZERO)
	var seen := mem.x + mem.y + mem.z
	if memory_weight > 0.0 and seen > 0.0:
		var freq := (mem + Vector3.ONE) / (seen + 3.0)   # near, middle, far
		# as LEFT, UP, RIGHT for this shooter: his near post is his side (straight on: no near post)
		var as_lur := Vector3(freq.x, freq.y, freq.z) if side < 0.0 else Vector3(freq.z, freq.y, freq.x)
		if side == 0.0:
			as_lur = Vector3((freq.x + freq.z) * 0.5, freq.y, (freq.x + freq.z) * 0.5)
		w = w.lerp(as_lur, memory_weight * clampf(seen / MEMORY_FULL, 0.0, 1.0))
	return _norm(w)

## What a keeper who doesn't read it sees: the shooter's side.
static func naive_read(info: Dictionary) -> Vector3:
	var from: Vector2 = info.get("from", Vector2(Geo.FIVE_M, Geo.GOAL_Y))
	var dy := from.y - Geo.GOAL_Y
	if absf(dy) < NAIVE_CENTRAL:
		var s := (1.0 - NAIVE_UP) * 0.5
		return Vector3(s, NAIVE_UP, s)
	var far := 1.0 - NAIVE_NEAR - NAIVE_UP
	return Vector3(NAIVE_NEAR, NAIVE_UP, far) if dy < 0.0 else Vector3(far, NAIVE_UP, NAIVE_NEAR)

## How much of an angle the shooter has, 0 (straight on, or from the corner) .. 1 (ShotModel's
## cross-cage band).
static func angle_k(from: Vector2) -> float:
	var ang := rad_to_deg(atan2(absf(from.y - Geo.GOAL_Y), maxf(Geo.GOAL_X - from.x, 0.3)))
	var c := ShotModel.CROSS_ANGLE
	return clampf((ang - c.x) / (c.y - c.x), 0.0, 1.0) * (1.0 - clampf((ang - c.z) / 20.0, 0.0, 1.0))

## His pick from weights `w` (LEFT, UP, RIGHT) at level `iq`: -1, 0 or +1. Now and then (mistake)
## any of the three; otherwise at random, sharpened (or loosened) by gk_temp.
static func choose(w: Vector3, iq: float, rng: RandomNumberGenerator) -> int:
	var temp := Difficulty.value("gk_temp", iq)
	var slip := rng.randf()
	var r := rng.randf()   # (two dice at every level, so the game's dice run the same whatever it picks)
	if slip < Difficulty.value("mistake", iq):
		return [KeeperDive.LEFT, KeeperDive.CENTRE, KeeperDive.RIGHT][mini(int(r * 3.0), 2)]
	var p := _norm(Vector3(pow(w.x, 1.0 / temp), pow(w.y, 1.0 / temp), pow(w.z, 1.0 / temp)))
	if r < p.x:
		return KeeperDive.LEFT
	if r < p.x + p.y:
		return KeeperDive.CENTRE
	return KeeperDive.RIGHT

## The chances he picks each way (LEFT, UP, RIGHT) at `iq`, before the mistake roll: for tests
## and the balance numbers.
static func pick_odds(w: Vector3, iq: float) -> Vector3:
	var temp := Difficulty.value("gk_temp", iq)
	var p := _norm(Vector3(pow(w.x, 1.0 / temp), pow(w.y, 1.0 / temp), pow(w.z, 1.0 / temp)))
	var m := Difficulty.value("mistake", iq)
	return p * (1.0 - m) + Vector3.ONE * (m / 3.0)

## Which way a shot crossing at `cross_y` went from a keeper at `keeper_y`: what he'd have had to
## pick (and what his memory records). The middle band is a dive's blind spot either side of him.
static func zone_of(cross_y: float, keeper_y: float) -> int:
	var d := cross_y - keeper_y
	if d < -KeeperDive.ZONE:
		return KeeperDive.LEFT
	if d > KeeperDive.ZONE:
		return KeeperDive.RIGHT
	return KeeperDive.CENTRE

## `memory` (near post, middle, far post) with one more shot from `from` that went `zone` (LEFT,
## CENTRE/UP, RIGHT of the keeper). From straight on there's no near post: only the middle counts.
const MEMORY_CENTRAL := 0.8
static func remember(memory: Vector3, zone: int, from: Vector2) -> Vector3:
	if zone == KeeperDive.CENTRE:
		return memory + Vector3(0, 1, 0)
	var dy := from.y - Geo.GOAL_Y
	if absf(dy) < MEMORY_CENTRAL:
		return memory
	var near := (zone == KeeperDive.LEFT) == (dy < 0.0)
	return memory + (Vector3(1, 0, 0) if near else Vector3(0, 0, 1))

## Stage A: for a shooter who's had it `hold` s in range, `range_m` from the middle of the goal,
## does he set off before the release, and how early? `u`: his one die for it (ShotModel rolls it before anything that depends on the aim).
## {commit, lead (s before the release he goes, at most), k (0 a snap shot .. 1 a long hold)}.
## The longer the hold the likelier and the earlier, right or wrong: a long hold isn't a save, it's
## more of a guess.
static func anticipation(hold: float, u: float, range_m: float = 99.0) -> Dictionary:
	var k := smoothstep(HOLD.x, HOLD.y, hold)
	var near := smoothstep(COMMIT_NEAR.x, COMMIT_NEAR.y, range_m)
	var p := maxf(lerpf(COMMIT_P.x, COMMIT_P.y, k), COMMIT_NEAR_P * near)
	k = maxf(k, near)
	var commit := u < p
	var depth := 1.0 - u / p if commit else 0.0   # (how sure he was: the earlier he goes)
	return {"commit": commit, "lead": lerpf(COMMIT_LEAD.x, lerpf(COMMIT_LEAD.x, COMMIT_LEAD.y, k), depth), "k": k}

## How far he leans towards his read after `hold` s (Play: minimal commitment, visible).
static func lean(hold: float) -> float:
	return LEAN_MAX * smoothstep(READ_AT, HOLD.y, hold)

## Stage B: how long after the release he sees where it's going (LUNGE SPEED: `lunge_k` his skill
## for it, `lunge_mult` Attributes.lunge_mult).
static func recognize_time(lunge_k: float, lunge_mult: float) -> float:
	return lerpf(RECOGNIZE.x, RECOGNIZE.y, lunge_k) * lunge_mult

## Stage B: which way he goes for a ball he's seen crossing his line at `hands_y`, from his body at
## `body_y`, going at `go` and getting to him `arrive` s after the release (his read of it). He
## takes the dive that'll have it when it gets there: a block straight up for one at him, a dive
## for one wide of him. Neither will (too wide, too soon)? He still goes the way it's going.
static func react_side(b: Dictionary, body_y: float, hands_y: float, go: float, arrive: float, reach_k: float) -> int:
	return reaction_dive(b, body_y, hands_y, go, arrive, reach_k).side

## The dive itself: a block, or a lunge only as far as this ball needs (REACT_HOLD of the way along
## his arm, never past his full lunge), since he's seen where it's going.
const REACT_HOLD := 0.55
static func reaction_dive(b: Dictionary, body_y: float, hands_y: float, go: float, arrive: float, reach_k: float) -> KeeperDive:
	var way := KeeperDive.LEFT if hands_y < body_y else KeeperDive.RIGHT
	var lunge := KeeperDive.from_body(b, way, body_y, reach_k)
	lunge.lunge = clampf(absf(hands_y - body_y) - lunge.arm * reach_k * REACT_HOLD, 0.1, float(b.lunge))
	var block := KeeperDive.from_body(b, KeeperDive.CENTRE, body_y, reach_k)
	var best: KeeperDive = null
	var best_at := INF
	for d: KeeperDive in [block, lunge]:
		d.t = arrive - go
		var at := d.covers(hands_y)
		d.t = 0.0
		if at >= 0.0 and at < best_at:
			best_at = at
			best = d
	if block.duplicate_at(arrive - go).covers(hands_y) >= 0.0 and absf(hands_y - body_y) <= KeeperDive.ZONE:
		return block   # (at him: he stays big)
	if best != null:
		return best
	return block if absf(hands_y - body_y) <= KeeperDive.ZONE * 0.6 else lunge

## His state, for the screen and the tests: from the dive he's in (or none), whether a shot's
## being wound up in range (`anticipating`) and whether he's read it and is leaning (`leaning`).
static func state_of(pose: KeeperDive, anticipating: bool, leaning: bool = false) -> int:
	if pose != null and not pose.done():
		if pose.hit_t >= 0.0 and pose.hit_t < 0.3:
			return State.BLOCKING
		if pose.phase() == KeeperDive.Phase.PANIC:
			return State.PANIC_RECOVERY
		if pose.recovering() and pose.phase() == KeeperDive.Phase.RECOVER:
			return State.RECOVERING
		if not pose.anticipated:
			return State.REACTING
		match pose.side:
			KeeperDive.LEFT:
				return State.COMMITTED_LEFT
			KeeperDive.RIGHT:
				return State.COMMITTED_RIGHT
		return State.COMMITTED_UP
	if leaning:
		return State.LEANING
	return State.ANTICIPATING if anticipating else State.READY

static func _norm(w: Vector3) -> Vector3:
	var s := w.x + w.y + w.z
	return w / s if s > 0.0 else Vector3.ONE / 3.0
