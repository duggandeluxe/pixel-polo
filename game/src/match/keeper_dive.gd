class_name KeeperDive
extends RefCounted
## One dive by your keeper: you tap the LEFT, CENTRE or RIGHT of the goal and he explodes that
## way. Pure logic in pool metres and seconds: KeeperDuel asks it whether the ball is in his hands
## as it crosses the line, and PoolArt draws exactly the same body and arm, so a save is never
## further than what you can see.
##
## Sides are the keeper's own, facing the play: LEFT (-1) is up the screen (pool y down), RIGHT
## (+1) is down it. CENTRE (0) is a block: he springs up out of the water with both arms high.
##
## The clock is on-screen seconds (KeeperDuel converts out of its slow motion), so the dive looks
## the same speed however slow the shot is being shown. Every dive runs the same cycle, and it
## never waits for the shot: time it so the ball arrives while he's up.
##   REACT    0.00 - 0.05  the tap: he gathers himself, nothing out yet
##   RISE     0.05 - 0.17  out to full stretch (an ease-out: fastest at the start, a lunge you
##                         can follow rather than a jump: LUNGE_EASE), his reach growing
##   ACTIVE   0.17 - ...   full stretch: the ball he gets to here is his. LEG STRENGTH sets how
##                         long (Attributes.dive_window: 0.34 s at 5)
##   FALL     FALL s       back into the water: his reach shrinks to nothing, his body comes back
##   RECOVER  RECOVERY s   bobbing up where he dived from, no reach and no new dive
## LUNGE SPEED (and the home pool, ShotModel.HOME_DIVE) is `quick`: REACT and RISE take 1 / quick
## of the time. Dive too early and he's fallen before the ball gets there; too late and it's
## past him while he's still rising. Taps while a dive is running do nothing.
##
## PANIC (the AI keeper only, ShotModel): he went one way before he'd seen the ball (KeeperAI's
## anticipation) and it's going somewhere else. turn() is a desperate correction inside this
## same dive, never a second one: his way out first has to stop (PANIC_BRAKE, longer the further
## he'd gone), then he claws back towards the ball (PANIC_SPEED: LUNGE SPEED's; PANIC_ACCEL: LEG
## STRENGTH's push), twisting to reach back with one arm (PANIC_ARM of his reach, less the more
## committed he was). Whatever his attributes, a dive he'd fully committed to can never cover the
## far side of where he set (PANIC_WALL): back towards the middle, never across the goal.

enum { LEFT = -1, CENTRE = 0, RIGHT = 1 }
enum Phase { REACT, RISE, ACTIVE, FALL, RECOVER, READY, PANIC }
## How far into a dive he is when he sees where the ball's really going (ext at that moment):
## under COMMIT_MIN only a lean (he can still go the other way: a quick correction, not a panic),
## from COMMIT_FULL the jump's all but done.
enum Commit { NONE, MINIMAL, PARTIAL, FULL }
const COMMIT_MIN := 0.3
const COMMIT_FULL := 0.85
const PANIC_BRAKE := 0.12     # s to stop his way out and gather himself, at full commitment (times 1 / quick)
const PANIC_SPEED := 2.4      # m/s back towards the ball at most (times quick)...
const PANIC_ACCEL := 13.0     # ...getting there at this (times his legs' push)
const PANIC_OFF_BALANCE := 0.4   # ...both this much less at full commitment
const PANIC_ARM := 0.55       # the arm he reaches back with: this share of his reach...
const PANIC_ARM_COMMIT := 0.4 # ...this much less at full commitment
const PANIC_SWING := 0.08     # s for the twist that gets that arm round
const PANIC_HOLD := 0.7       # he stays up this share of his window after the turn...
const PANIC_HOLD_MIN := 0.12  # ...never less than this
## The furthest past where he set (base_y), on the side away from his dive, that a turned dive
## can ever cover: lightly committed .. fully. Enforced in covers(), so no attribute buys it back.
const PANIC_WALL := Vector2(1.0, 0.22)

const REACT := 0.05
const EXTEND := 0.12          # the rise, after the reaction
const LUNGE_EASE := 2.2       # the ease-out's power (3 was nearly all in the first frames)
const FALL := 0.16
const RECOVERY := 0.22
const ARM_START := 0.3        # the leading arm is already this much of the way out as he rises
const TRAIL_R := 0.2          # the side he dived away from: only his body, this far
const CENTRE_REACH := 0.85    # a block covers this much of a dive's arm, either side of him
const ZONE := Geo.GOAL_HALF / 3.0   # the middle third of the mouth is CENTRE
const BALL_Z := 0.6           # taps are read at the height shots cross the line

var side := CENTRE
var t := 0.0                  # seconds since the tap
var base_y := Geo.GOAL_Y      # where he dived from (and comes back to)
var lunge := 0.75             # how far his body goes (m)
var arm := 0.5                # how far past his body his leading hand gets (m)
var quick := 1.0              # LUNGE SPEED and the home pool: his reaction and rise are this much faster
var window := Attributes.WINDOW_AT_5   # how long he holds full stretch (LEG STRENGTH)
var reach_k := 1.0            # the shot's height (KeeperDuel.height_k): a low one is harder to get a hand to
var hit_y := NAN              # the save: where the ball met his hand...
var hit_t := -1.0             # ...and how long ago (-1: no save)
var push := 1.0               # LEG STRENGTH's push (Attributes.leg_reach): a panic's claw back
var rise := 1.0               # his rise takes this many times EXTEND (the AI keeper in live play: KeeperAI.RISE)
var anticipated := false      # he set off before he'd seen the ball go (KeeperAI's anticipation)
## The panic (turn): when (his clock), back towards where, how committed he was, and the motion
## it gives him (worked out once in turn()).
var turn_t := INF
var turn_y := NAN
var turn_c := 0.0
var _p_y0 := 0.0              # his body at the turn
var _p_dir := 0.0             # the way back (+1 down the pool, -1 up it)
var _p_away := 0.0            # how fast he was still going the other way (m/s)
var _p_brake := 0.0           # s to stop that
var _p_vmax := 0.0
var _p_acc := 0.0
var _p_end := INF             # his clock when he starts to fall
var _p_wall := INF            # the far-side line he can't cover past (pool y)

func _init(p_side: int, p_base_y: float, p_lunge: float, p_arm: float, p_quick: float = 1.0) -> void:
	side = p_side
	base_y = p_base_y
	lunge = p_lunge
	arm = p_arm
	quick = p_quick

## A keeper's body for a dive, from the numbers his attributes give: how far his body goes
## (lunge) and his arm past it, LEG STRENGTH's (`leg_k` his skill for it, Attributes.keeper_skill;
## `legs` Attributes.leg_reach); how quick it is, LUNGE SPEED's (`lunge_mult`, Attributes.lunge_mult)
## and the home pool's; how long he stays up (`window`, Attributes.dive_window). Every keeper in
## the game dives with this: yours (KeeperDuel) and the AI's (ShotModel), at every difficulty.
static func body(leg_k: float, legs: float, lunge_mult: float, p_window: float, wall := false, home := false) -> Dictionary:
	return {"lunge": lerpf(KeeperDuel.LUNGE.x, KeeperDuel.LUNGE.y, leg_k) * legs,
		"arm": (lerpf(KeeperDuel.ARM.x, KeeperDuel.ARM.y, leg_k) + (KeeperDuel.WALL_REACH if wall else 0.0)) * legs,
		"quick": (ShotModel.HOME_DIVE if home else 1.0) / maxf(lunge_mult, 0.01), "window": p_window, "push": legs}

## The same for `keeper` (his attributes, his form, a WALL's reach).
static func body_of(keeper: PoloPlayer, home := false) -> Dictionary:
	return body(Attributes.keeper_skill(keeper, "leg"), Attributes.leg_reach(keeper), Attributes.lunge_mult(keeper),
		Attributes.dive_window(keeper), keeper != null and Traits.has(keeper, "wall"), home)

## A dive `side` from `base_y` with body `b` (body()), against a shot `reach_k` high.
static func from_body(b: Dictionary, p_side: int, p_base_y: float, p_reach_k: float = 1.0) -> KeeperDive:
	var d := KeeperDive.new(p_side, p_base_y, float(b.lunge), float(b.arm), float(b.quick))
	d.window = float(b.window)
	d.reach_k = p_reach_k
	d.push = float(b.get("push", 1.0))
	d.rise = float(b.get("rise", 1.0))
	return d

## Everything that makes this dive this dive (Play rebuilds the one ShotModel decided the shot with).
func to_dict() -> Dictionary:
	return {"side": side, "base_y": base_y, "lunge": lunge, "arm": arm, "quick": quick, "window": window,
		"reach_k": reach_k, "push": push, "rise": rise, "anticipated": anticipated, "turn_t": turn_t, "turn_y": turn_y if turned() else 0.0}

## The same dive, its clock at `at` (ShotModel looks ahead without moving the real one).
func duplicate_at(at: float) -> KeeperDive:
	var d := KeeperDive.from_dict(to_dict())
	d.t = at
	return d

static func from_dict(dv: Dictionary) -> KeeperDive:
	var d := KeeperDive.new(int(dv.side), float(dv.base_y), float(dv.lunge), float(dv.arm), float(dv.quick))
	d.window = float(dv.get("window", Attributes.WINDOW_AT_5))
	d.reach_k = float(dv.get("reach_k", 1.0))
	d.push = float(dv.get("push", 1.0))
	d.rise = float(dv.get("rise", 1.0))
	d.anticipated = bool(dv.get("anticipated", false))
	if float(dv.get("turn_t", INF)) < INF:
		d.turn(float(dv.turn_t), float(dv.turn_y))
	return d

## Which zone a tap at pool height `y` is: the middle third of the goal mouth is CENTRE,
## above it LEFT, below it RIGHT (off the ends of the goal too).
static func zone_for(y: float) -> int:
	if y < Geo.GOAL_Y - ZONE:
		return LEFT
	if y > Geo.GOAL_Y + ZONE:
		return RIGHT
	return CENTRE

## The zone for a tap at screen height `screen_y`, read across the goal at the height a shot
## crosses it (where you see the ball).
static func zone_at_screen(v: PoolView, screen_y: float) -> int:
	screen_y = v.unzoom(Vector2(v.width * 0.5, screen_y)).y   # (through the 6 on 5 push in, if it's on)
	var y := (screen_y + BALL_Z * v.sz() - PoolView.HUD_H) / v.sy() + v.cam.y
	return zone_for(y)

func advance(dt: float) -> void:
	t += dt
	if hit_t >= 0.0:
		hit_t += dt

## When he starts to move (the end of REACT).
func react_time() -> float:
	return REACT / quick

## When he's at full stretch (the end of RISE).
func extend_time() -> float:
	return (REACT + EXTEND * rise) / quick

## When he starts to fall (the end of ACTIVE, or of a panic).
func fall_at() -> float:
	if turned():
		return _p_end
	return extend_time() + window

## When he's back in the water (the end of FALL).
func down_at() -> float:
	return fall_at() + FALL

func phase() -> int:
	if turned() and t >= turn_t:
		if t < _p_end:
			return Phase.PANIC
		if t < _p_end + FALL:
			return Phase.FALL
		return Phase.RECOVER if t < _p_end + FALL + RECOVERY else Phase.READY
	if t < react_time():
		return Phase.REACT
	if t < extend_time():
		return Phase.RISE
	if t < fall_at():
		return Phase.ACTIVE
	if t < down_at():
		return Phase.FALL
	if t < down_at() + RECOVERY:
		return Phase.RECOVER
	return Phase.READY

## At full stretch: the ball he gets to now is his.
func active() -> bool:
	return phase() == Phase.ACTIVE

## He's turned this dive into a panic (turn()).
func turned() -> bool:
	return turn_t < INF

## How committed this dive is at his clock `at` (Commit): from how far into it he is, nothing else.
func commitment_at(at: float) -> int:
	var was := t
	t = at
	var ph := phase()
	var e := ext()
	t = was
	if ph == Phase.REACT or ph == Phase.READY or at < 0.0:
		return Commit.NONE
	if ph in [Phase.FALL, Phase.RECOVER]:
		return Commit.FULL   # (on his way down: there's nothing left to turn)
	if e < COMMIT_MIN:
		return Commit.MINIMAL
	return Commit.FULL if e >= COMMIT_FULL else Commit.PARTIAL

## He's seen the ball going to `to_y` at his clock `at`, the wrong way for this dive: the panic.
## Not a new dive: he has to stop going the way he went first (the further he'd gone, the longer),
## then claws back, off balance, reaching back with one arm. The motion is worked out here, once,
## from where he is and how fast he's going: body_y(), reach() and covers() then follow it.
func turn(at: float, to_y: float) -> void:
	var was := t
	t = at
	var y0 := body_y()
	var c := ext()
	t = at - 0.01
	var v := (y0 - body_y()) / 0.01     # his speed across the goal as he sees it (pool y / s)
	t = was
	turn_t = at
	turn_y = to_y
	turn_c = c
	_p_y0 = y0
	_p_dir = signf(to_y - y0)
	if _p_dir == 0.0:
		_p_dir = -float(side) if side != CENTRE else 1.0
	_p_away = maxf(0.0, -v * _p_dir)
	_p_brake = PANIC_BRAKE * c / quick   # (stretched out flat, even with nothing left going the wrong way, he has to gather himself)
	var off := 1.0 - PANIC_OFF_BALANCE * c
	_p_vmax = PANIC_SPEED * quick * off
	_p_acc = PANIC_ACCEL * push * off
	_p_end = at + maxf(PANIC_HOLD_MIN, window * PANIC_HOLD)
	_p_wall = INF
	if side != CENTRE:
		var k := clampf((c - COMMIT_MIN) / (COMMIT_FULL - COMMIT_MIN), 0.0, 1.0)
		_p_wall = base_y - float(side) * lerpf(PANIC_WALL.x, PANIC_WALL.y, k)

## How committed he was when he turned (Commit).
func panic_commit() -> int:
	if not turned():
		return Commit.NONE
	if turn_c < COMMIT_MIN:
		return Commit.MINIMAL
	return Commit.FULL if turn_c >= COMMIT_FULL else Commit.PARTIAL

## The way back he's clawing (+1 / -1), 0 if he hasn't turned.
func turn_dir() -> float:
	return _p_dir if turned() else 0.0

## His body `tau` s into the panic: still going the wrong way (slowing), then back.
func _panic_body(tau: float) -> float:
	var s := 0.0
	if tau < _p_brake and _p_brake > 0.0:
		s = -(_p_away * tau - 0.5 * (_p_away / _p_brake) * tau * tau)
	else:
		s = -_p_away * _p_brake * 0.5
		var u := tau - _p_brake
		var tv := _p_vmax / maxf(_p_acc, 0.01)
		if u < tv:
			s += 0.5 * _p_acc * u * u
		else:
			s += 0.5 * _p_acc * tv * tv + _p_vmax * (u - tv)
	# never past the ball (he's going for it with his hand), never past his wall
	s = minf(s, absf(turn_y - _p_y0))
	var y := _p_y0 + _p_dir * s
	if _p_wall < INF:
		y = maxf(y, _p_wall) if side > 0 else minf(y, _p_wall)
	return y

## The arm he reaches back with, `tau` s into the panic.
func _panic_arm(tau: float) -> float:
	return arm * PANIC_ARM * (1.0 - PANIC_ARM_COMMIT * turn_c) * clampf(tau / PANIC_SWING, 0.0, 1.0) * reach_k

## Falling or bobbing back up: no dive left in him.
func recovering() -> bool:
	return t >= fall_at() and not done()

func done() -> bool:
	return t >= down_at() + RECOVERY

## 0..1: how far into the dive he is. Nothing while he reacts, a fast ease-out to full stretch,
## held for his window, then eased back down.
func ext() -> float:
	if turned() and t >= turn_t:
		if t < _p_end:
			return turn_c
		if t < _p_end + FALL:
			var u := (t - _p_end) / FALL
			return turn_c * (1.0 - u * u * (3.0 - 2.0 * u))
		return 0.0
	var rt := react_time()
	if t < rt:
		return 0.0
	var et := extend_time()
	if t < et:
		var u := (t - rt) / (et - rt)
		return 1.0 - pow(1.0 - u, LUNGE_EASE)
	var fa := fall_at()
	if t < fa:
		return 1.0
	if t < fa + FALL:
		var u := (t - fa) / FALL
		return 1.0 - u * u * (3.0 - 2.0 * u)
	return 0.0

## Where his body is now (pool y): pushed out towards the dive, and back. In a panic: the
## motion turn() worked out, then he falls back in where he got to and drifts back to his spot.
func body_y() -> float:
	if turned() and t >= turn_t:
		if t < _p_end:
			return _panic_body(t - turn_t)
		var end := _panic_body(_p_end - turn_t)
		return base_y + (end - base_y) * (ext() / maxf(turn_c, 0.01))
	return base_y + float(side) * lunge * ext()

## How far from his body his hand is now: the leading hand on a dive, either hand on a block.
## Out as he rises, all of it while he's up, and gone as he falls (faster than his body comes back:
## a falling keeper's arms are going down into the water).
func reach() -> float:
	if turned() and t >= turn_t:
		var tau := minf(t, _p_end) - turn_t
		var back := _panic_arm(tau)
		if t < _p_end:
			return back
		var e2 := ext() / maxf(turn_c, 0.01)
		return back * e2 * e2
	var e := ext()
	var a := 0.0
	match phase():
		Phase.RISE:
			a = arm * lerpf(ARM_START, 1.0, e)
		Phase.ACTIVE:
			a = arm
		Phase.FALL:
			a = arm * e * e
	a *= reach_k
	if side == CENTRE:
		return a * CENTRE_REACH
	return a

## The furthest he covers on his dive side right now (pool y), for drawing and tests. In a
## panic: the hand he's reaching back with.
func tip_y() -> float:
	if turned() and t >= turn_t:
		return body_y() + _p_dir * reach()
	return body_y() + float(side if side != CENTRE else 0) * reach()

## A panic: the leading arm he went with, still out the wrong way and coming in as he twists.
func lead_reach() -> float:
	if not turned() or t < turn_t:
		return reach()
	var tau := t - turn_t
	return arm * reach_k * clampf(1.0 - tau / PANIC_SWING, 0.0, 1.0) * (1.0 if t < _p_end else 0.0)

## Is a ball crossing at pool height `y` in his hands right now? -1 if not, else 0..1 for how
## far out along his reach it is (1: fingertips). Diving one way, the other side is only his
## body (TRAIL_R): a dive the wrong way never saves it.
func covers(y: float) -> float:
	if turned() and t >= turn_t:
		return _panic_covers(y)
	var d := y - body_y()
	var r := reach()
	if r <= 0.0:
		return -1.0
	if side == CENTRE:
		return absf(d) / r if absf(d) <= r else -1.0
	var along := d * float(side)
	if along >= 0.0:
		return along / r if along <= r else -1.0
	return 0.0 if -along <= TRAIL_R else -1.0

## A turned dive: the arm reaching back, his body, and what's left of the arm he went with. Never
## past his wall: the far side of where he set is gone once he's committed to the other side.
func _panic_covers(y: float) -> float:
	if _p_wall < INF and (y - _p_wall) * float(side) < 0.0:
		return -1.0
	var b := body_y()
	var d := (y - b) * _p_dir
	if d >= 0.0:
		var r := reach()
		if d <= TRAIL_R * 0.5:
			return 0.0
		return d / r if r > 0.0 and d <= r else -1.0
	var lr := lead_reach()
	if -d <= TRAIL_R * 0.5:
		return 0.0
	return -d / lr if lr > 0.0 and -d <= lr else -1.0

## Would this dive have had a ball at `y` at full stretch? (KeeperDuel.timing: the right way,
## the wrong moment.)
func covers_at_full(y: float) -> bool:
	var was := t
	var tt := turn_t
	t = extend_time()
	turn_t = INF   # (the dive as he went: not the panic)
	var c := covers(y)
	turn_t = tt
	t = was
	return c >= 0.0

## The ball met his hand at `y` (the impact flash).
func hit(y: float) -> void:
	hit_y = y
	hit_t = 0.0

# ------------------------------------------------------------------ a ball he's caught
## Where a ball in his hands is now, from his body (x: m out in front of him, y: m across the
## pool, z: m up), where his art has his hands (PoolArt._keeper_dive): in the hand that's out while
## he's up (both hands over his head on a block, the hand clawing back in a panic), pulled in onto
## the water in front of him (TUCK) as he falls back, kept there while he bobs back up with his
## arms down (the first RISE_FROM of RECOVER), then up to `rest` (where any man holds it:
## Play.held_at) as his hands come up. Done with the dive: `rest`.
const TUCK := Vector3(0.3, 0.0, 0.1)
const RISE_FROM := 0.5

func held(rest: Vector3) -> Vector3:
	match phase():
		Phase.FALL:
			var u := clampf((t - fall_at()) / FALL, 0.0, 1.0)
			return _hand().lerp(TUCK, u * u * (3.0 - 2.0 * u))
		Phase.RECOVER:
			return TUCK.lerp(rest, hold_rise())
		Phase.READY:
			return rest
	return _hand()

## A caught ball coming back up with him: 0 on the water in front of him (TUCK) .. 1 up in his hand
## (`rest`), over the last of RECOVER (PoolArt draws the hand under it).
func hold_rise() -> float:
	if phase() != Phase.RECOVER:
		return 1.0 if phase() == Phase.READY else 0.0
	var u := clampf(((t - down_at()) / RECOVERY - RISE_FROM) / (1.0 - RISE_FROM), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)

## His hand as the art draws it, in metres: a lunge's leading hand at the edge of his reach, BALL_Z
## up; a block's two hands over his head (the ball between them); a panic's hand flung back.
func _hand() -> Vector3:
	var e := ext()
	if turned() and t >= turn_t:
		return Vector3(10.0 / PoolView.SX, turn_dir() * reach(), BALL_Z - (2.0 + 2.0 * turn_c) / PoolView.SZ)
	if side == CENTRE:
		return Vector3(0.0, 0.0, (16.0 + 12.0 * e) / PoolView.SZ)
	return Vector3((3.0 + (2.0 if side < 0 else 7.0) * e) / PoolView.SX, float(side) * reach(), BALL_Z)
