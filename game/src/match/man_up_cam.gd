class_name ManUpCam
extends RefCounted
## THE 6 ON 5 CAMERA: an exclusion pushes the camera in on the power play like a broadcast camera,
## with a short impact shake as it lands, holds there while it's 6 on 5, and eases back out after.
##
##   exclusion -> IN (ZOOM over IN_TIME, ease-out; the shake SHAKE_FROM..SHAKE_TO) -> HOLD -> OUT
##   (back to 1 over OUT_TIME, smooth, no shake) -> IDLE
##
## It's one transform for the whole world layer (MatchScreen._draw_all: the pool, its markings, the
## goal, every player, the ball, the aim guide), scaled about `pivot` (the screen point of the
## attack's 4-2) with the shake on top: nothing is scaled by itself and nothing in the play moves.
## The HUD, the stick and the buttons are drawn after it, untouched. Taps go back through it
## (PoolView.cine, to_world). Art only: the play never reads any of it.

const ZOOM := 1.25          # the 6 on 5 view: the 4-2, its goal and the deck behind it still in shot
const IN_TIME := 0.45       # the push in (ease-out)
const OUT_TIME := 0.5       # the ease back out (no shake)
const SHAKE_FROM := 0.35    # the impact: as the push lands...
const SHAKE_TO := 0.6       # ...gone by here
const SHAKE_PX := 4.0       # screen px at the start of it (the 480 x 270 view), dying away fast
const SHAKE_HZ := Vector2(17.0, 13.0)   # across, up and down
const SHAKE_Y := 0.75       # the up-and-down's share of SHAKE_PX

enum Phase { IDLE, IN, HOLD, OUT }
var phase := Phase.IDLE
var t := 0.0
var from := 1.0
var scale := 1.0
var offset := Vector2.ZERO
var shaking := false
var pivot := Vector2.ZERO   # screen point it zooms about (set by the screen every frame it's on)

## An exclusion: push in (from wherever it is now), with the shake unless `shake` is false.
func push(shake := true) -> void:
	phase = Phase.IN
	t = 0.0
	from = scale
	shaking = shake

## The power play's over (or the play is): ease back out.
func release() -> void:
	if phase in [Phase.IN, Phase.HOLD]:
		phase = Phase.OUT
		t = 0.0
		from = scale

func active() -> bool:
	return phase != Phase.IDLE

## One frame. `on`: it's 6 on 5 on the water now (back in after their shot: in again, quietly).
func step(dt: float, on: bool) -> void:
	if on and phase in [Phase.IDLE, Phase.OUT]:
		push(false)
	elif not on:
		release()
	t += dt
	offset = Vector2.ZERO
	match phase:
		Phase.IN:
			var u := clampf(t / IN_TIME, 0.0, 1.0)
			scale = lerpf(from, ZOOM, 1.0 - pow(1.0 - u, 3.0))
			if shaking:
				offset = shake_at(t)
			if t >= (maxf(IN_TIME, SHAKE_TO) if shaking else IN_TIME):
				phase = Phase.HOLD
				scale = ZOOM
				offset = Vector2.ZERO
		Phase.HOLD:
			scale = ZOOM
		Phase.OUT:
			var u := clampf(t / OUT_TIME, 0.0, 1.0)
			scale = lerpf(from, 1.0, u * u * (3.0 - 2.0 * u))
			if u >= 1.0:
				phase = Phase.IDLE
				scale = 1.0
		_:
			scale = 1.0

## The impact, `at` s into the push: full on at SHAKE_FROM, gone (squared off) by SHAKE_TO, in whole px.
static func shake_at(at: float) -> Vector2:
	if at < SHAKE_FROM or at > SHAKE_TO:
		return Vector2.ZERO
	var s := at - SHAKE_FROM
	var k := 1.0 - s / (SHAKE_TO - SHAKE_FROM)
	var a := SHAKE_PX * k * k
	return Vector2(cos(s * TAU * SHAKE_HZ.x) * a, sin(s * TAU * SHAKE_HZ.y + 0.6) * a * SHAKE_Y).round()

## The world layer's transform: scaled about the pivot, the shake on top; the identity at rest
## (pixel for pixel the normal view).
func xform() -> Transform2D:
	if is_equal_approx(scale, 1.0) and offset == Vector2.ZERO:
		return Transform2D.IDENTITY
	return Transform2D(0.0, Vector2(scale, scale), 0.0, (pivot * (1.0 - scale) + offset).round())
