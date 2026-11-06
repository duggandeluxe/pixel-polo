class_name Ball
extends RefCounted
## The ball: held, in the air (pass or shot), or loose on the water.

enum State { HELD, PASS, SHOT, LOOSE, DEAD }

var state: int = State.HELD
var pos := Vector2.ZERO
var z := 0.0                 # height above the water, metres
var from := Vector2.ZERO
var to := Vector2.ZERO
var t := 0.0                 # 0..1 along a pass or shot
var dur := 0.5
var lead := 0.0              # a shot: seconds it had already flown when it left `from` (the hand's length)
var peak := 0.5              # pass arc height
var receiver: Swimmer = null
var passer: Swimmer = null
var shooter: Swimmer = null
var shot: Dictionary = {}    # ShotModel result while a shot is travelling
var checked: Array = []      # defenders who already tried to pick off this pass
var drift := Vector2.ZERO    # loose ball
var tipped_by: Swimmer = null   # ...knocked loose off a pass by this defender (Play._deflect)
var tipped_from: Swimmer = null # ...thrown by this man (the box score's turnover if they win it)
## A goal shown off the frame (BarHit.pick: BAR-IN! / BAR-DOWN!), {} for any other ball. Drawing only.
var bar := {}
var bar_t := -1.0            # seconds into its ricochet (-1: not off the frame yet)
## A keeper's catch: where the ball met him, and how long ago (INF: no catch going on). For
## SECURE_TIME it eases from there into his hands (put), so it never jumps or hangs. Drawing only.
const SECURE_TIME := 0.16
var secure_from := Vector3.ZERO
var secure_t := INF

func launch(p_from: Vector2, p_to: Vector2, duration: float, arc: float, s: int) -> void:
	state = s
	from = p_from
	to = p_to
	pos = p_from
	t = 0.0
	dur = maxf(duration, 0.08)
	lead = 0.0
	peak = arc
	checked.clear()
	tipped_by = null
	tipped_from = null
	net_line = -1.0
	bar = {}
	bar_t = -1.0
	secure_t = INF   # (out of his hands: nothing holds it any more)

## Caught (a keeper's save): from where it is now it eases into the hands it's put in.
func secure() -> void:
	secure_from = Vector3(pos.x, pos.y, z)
	secure_t = 0.0

## In someone's hands at `at` (x, y, height): there, or on its way there just after a catch.
func put(at: Vector3) -> void:
	if secure_t < SECURE_TIME:
		var u := secure_t / SECURE_TIME
		at = secure_from.lerp(at, u * u * (3.0 - 2.0 * u))
	pos = Vector2(at.x, at.y)
	z = at.z

func in_flight() -> bool:
	return state == State.PASS or state == State.SHOT

func bar_on() -> bool:
	return bool(bar.get("on", false))

## Where the ball is drawn (x, y, z): where it is, except a shot going in off the frame, bent the
## last few cm onto it (BarHit.bend) as it reaches the line.
func look() -> Vector3:
	var at := Vector3(pos.x, pos.y, z)
	if state == State.SHOT and bar_on():
		var k := BarHit.bend(self)
		var n: Vector2 = bar.nudge
		at.y += n.x * k
		at.z += n.y * k
	return at

# ------------------------------------------------------------------ a goal: into the net
## A goal carries on past the line at the shot's speed and stops against the back of the net,
## then sits in it. Only the drawing sees this: the goal was already given at the line.
const NET_BALL_R := 0.12     # the ball's half width (px / PoolView.SX): it stops touching the net
const NET_POST_PAD := 0.15   # ...and stays this far inside the posts
const NET_SETTLE := 0.08     # it gives back this much off the net as it settles
const NET_GIVE := 0.17       # the net stretches back this far where it's hit (m)...
const NET_OUT := 0.05        # ...in this many seconds...
const NET_BACK := 0.25       # ...and is back where it was this long after the hit

var net_line := -1.0         # the goal line it went in over (-1: not in a net)
var net_side := 1.0          # +1: the net hangs out towards +x
var net_vel := Vector2.ZERO
var net_t := -1.0            # seconds since it hit the back of the net (-1: still on its way)

## Into the net at goal line `line`, moving at `vel` (m/s); the net hangs out towards `side`.
func into_net(vel: Vector2, line: float, side: float) -> void:
	net_line = line
	net_side = side
	net_vel = vel
	net_t = -1.0
	if signf(net_vel.x) != side:
		net_vel.x = 0.0
	if bar_on():
		# off the frame: it's on the post / under the bar, then ricochets (BarHit.path)
		var at: Vector3 = bar.at
		pos = Vector2(at.x, at.y)
		z = at.z
		bar_t = 0.0

func in_net() -> bool:
	return net_line >= 0.0

## Where the back of the net stops the ball.
func net_back_x() -> float:
	return net_line + net_side * (Geo.NET_DEPTH - NET_BALL_R)

## Advance the ball in the net by `dt`. True on the step it hits the back.
func step_net(dt: float) -> bool:
	if not in_net():
		return false
	var lo := Geo.GOAL_Y - Geo.GOAL_HALF + NET_POST_PAD
	var hi := Geo.GOAL_Y + Geo.GOAL_HALF - NET_POST_PAD
	var back := net_back_x()
	if net_t < 0.0 and bar_t >= 0.0:
		bar_t += dt
		var q := BarHit.path(bar, bar_t, back)
		pos = Vector2(q.x, q.y)
		z = q.z
		if bar_t >= BarHit.ricochet_time(bar):
			pos.x = back
			net_t = 0.0
			return true
		return false
	if net_t < 0.0:
		pos += net_vel * dt
		pos.y = clampf(pos.y, lo, hi)
		# under the roof of the net, which slopes down from the crossbar to the back
		var depth := clampf((pos.x - net_line) * net_side / Geo.NET_DEPTH, 0.0, 1.0)
		z = minf(z, lerpf(0.75, 0.38, depth))
		if (pos.x - back) * net_side >= 0.0:
			pos.x = back
			net_t = 0.0
			return true
		return false
	net_t += dt
	# it rides the net back out, then drops off it and floats there
	var give := NET_GIVE * net_bulge(net_t) - NET_SETTLE * smoothstep(0.1, 0.4, net_t)
	pos.x = back + net_side * give
	z = move_toward(z, 0.1, dt * 1.6)
	return false

## How far the net is stretched back, 0..1, `t` seconds after the ball hit it (t < 0: not hit).
static func net_bulge(t: float) -> float:
	if t < 0.0 or t >= NET_BACK:
		return 0.0
	if t < NET_OUT:
		return t / NET_OUT
	var u := (t - NET_OUT) / (NET_BACK - NET_OUT)
	return (1.0 - u) * (1.0 - u)
