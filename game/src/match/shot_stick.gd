class_name ShotStick
## The shooting stick: a fixed wedge on the left of the screen, wide side left, its knob resting
## in the narrow point on the right. Pull the knob back (left) for power and up or down to aim,
## the slingshot's way round: up aims low, down aims high. It's the only way you shoot: a touch
## has to come down on it (hit) to be a shot at all, and one that comes down anywhere else never
## is, wherever it goes. It never shoots by itself: it only says where a pull would aim (target),
## and AimGuide pulls there, so the guide, the raised ball, the red X and the release are the
## slingshot's own (see match_screen, AimGuide.stick_at).
##
## Power is the knob's travel left alone; aim is its angle from the rest point, so the wedge's own
## fan: straight back along a ray changes the power and keeps the aim, straight up or down at one
## pull changes the aim and keeps the power. Wherever the shooter is, the same stick.

const REACH := 70.0          # px of knob travel left for full power
const SPREAD := 0.54         # the fan: px of travel up or down per px back (tan of its half-angle)
const DEAD := 6.0            # px of travel back before it's a shot at all (the slingshot's MIN_PULL)
const PAD := 12.0            # the wedge's rounded edge, round the knob's fan
const KNOB_R := 8
const GRAB := 6.0            # px past the wedge a touch still takes the stick
const SNAP := 18.0           # the knob's spring back to rest (visual only)
const FADE := 7.0            # in and out, per second

## The widest aim, metres either side of the goal's middle: as wide as a slingshot shot can go
## (Play.aim_info's SHOT_WIDE past the post), so the stick aims everywhere the slingshot can; a
## hair inside it, so the fan's edge is a shot to the last bit of rounding.
const AIM_SPAN := Geo.GOAL_HALF + Play.SHOT_WIDE - 0.02

const FILL := Color("0a2a78", 0.38)
const BAND := Color("0b2f8f", 0.72)
const RIM := Color("6fa8ff", 0.75)
const RAY := Color("8fb8ff", 0.22)
const KNOB := Color("8fb4ff")
const KNOB_DARK := Color("1d3f9e")

var rest := Vector2.ZERO     # the knob's rest point on screen (the wedge's narrow point)
var knob := Vector2.ZERO     # the knob, px from rest: x <= 0 back, y down
var grab := Vector2.ZERO     # where the finger came down, less where the knob was
var travel := 0.0            # the furthest the finger's been from there (px): a tap or a pull
var shown := 0.0             # 0 hidden .. 1 on screen
var _spans := {}             # pad -> [[y, x0, x1]...] for the wedge's rows, from rest (layout)

## On the left over the pool, in from the edge into the open water (its wide side IN_FROM of the
## screen's width across), clear of the scoreboard, of DRIVE on top of it (CallStrip.layout) and of
## the holder's tag along the bottom. On the screen, never in the pool: the camera doesn't move it.
const IN_FROM := 0.14

func layout(size: Vector2, ins: Vector2) -> void:
	var cy := roundf((PoolView.HUD_H + size.y) * 0.5) + 8.0
	var at := Vector2(roundf(ins.x + size.x * IN_FROM) + PAD + REACH, cy)
	if at != rest or _spans.is_empty():
		rest = at
		_spans.clear()

## Up while you've the ball to shoot, down otherwise; held up while it's in your hand.
func step(dt: float, available: bool, held: bool) -> void:
	shown = move_toward(shown, 1.0 if (available or held) else 0.0, dt * FADE)
	if not held:
		knob = knob.lerp(Vector2.ZERO, clampf(dt * SNAP, 0.0, 1.0))
		if knob.length() < 0.5:
			knob = Vector2.ZERO

## Is screen point `pos` on the stick (on the wedge or its knob)?
func hit(pos: Vector2) -> bool:
	return _dist(pos - rest) <= PAD + GRAB

## The box round everything hit() takes, on screen (DRIVE goes on top of it).
func area() -> Rect2:
	var out := PAD + GRAB
	var half := SPREAD * REACH + out
	return Rect2(rest.x - REACH - out, rest.y - half, REACH + out * 2.0, half * 2.0)

## A finger came down at `pos`: the knob's back at rest and from here on moves with it.
func take(pos: Vector2) -> void:
	knob = Vector2.ZERO
	grab = pos
	travel = 0.0

## The finger's at `pos`: the knob follows, inside the fan.
func drag(pos: Vector2) -> void:
	knob = clamp_knob(pos - grab)
	travel = maxf(travel, pos.distance_to(grab))

static func clamp_knob(k: Vector2) -> Vector2:
	var back := clampf(-k.x, 0.0, REACH)
	var side := SPREAD * back
	return Vector2(-back, clampf(k.y, -side, side))

## 0 at the dead zone's edge .. 1 at full pull: the share of the slingshot's power range.
static func power_t(k: Vector2) -> float:
	return clampf((-k.x - DEAD) / (REACH - DEAD), 0.0, 1.0)

## -1 (knob at the top of the fan) .. 1 (the bottom): its angle, whatever the pull.
static func aim_t(k: Vector2) -> float:
	var back := -k.x
	return clampf(k.y / (SPREAD * back), -1.0, 1.0) if back > 0.0 else 0.0

static func live(k: Vector2) -> bool:
	return -k.x >= DEAD

## Where on the goal line knob `k` aims, metres across the pool. Inverted: up aims low, down
## aims high (as a slingshot pull does).
static func cross_y(k: Vector2) -> float:
	return Geo.GOAL_Y - aim_t(k) * AIM_SPAN

## The pool spot a slingshot pull would aim at, from `from`, to shoot like knob `k` (null in the
## dead zone): along the line through the goal at cross_y, past the shot line by as many metres
## of AimGuide's SHOT_EXTRA as power_t says, so AimGuide.power works it back out to exactly
## SHOT_BASE + (1 - SHOT_BASE) * power_t, from anywhere.
static func target(from: Vector2, k: Vector2) -> Variant:
	if not live(k):
		return null
	var goal := Vector2(Geo.GOAL_X, cross_y(k))
	var dir := (goal - from).normalized()
	if dir.x <= 0.0:
		return goal   # (behind the goal line: no shot, whatever)
	var reach := maxf((Play.SHOT_ZONE_X - from.x) / dir.x, 0.0)
	# (a hair past the line, so it's a shot to the last bit of rounding; and aim_info's 0.3 m)
	var dist := maxf(reach + 0.001 + power_t(k) * AimGuide.SHOT_EXTRA, 0.31 / dir.x)
	return from + dir * dist

## The knob that shoots like a slingshot pull aimed at `world` would, from `from` (target's
## inverse): its line's crossing of the goal is the aim, how far past the shot line it goes the
## power. Tests and the coach's ghost finger.
static func knob_for(from: Vector2, world: Vector2) -> Vector2:
	var dir := (world - from).normalized()
	if dir.x <= 0.0:
		return Vector2.ZERO
	var cross := from.y + dir.y * (Geo.GOAL_X - from.x) / dir.x
	var a := clampf((Geo.GOAL_Y - cross) / AIM_SPAN, -1.0, 1.0)
	var reach := maxf((Play.SHOT_ZONE_X - from.x) / dir.x, 0.0)
	var pt := clampf((from.distance_to(world) - reach) / AimGuide.SHOT_EXTRA, 0.0, 1.0)
	var back := DEAD + pt * (REACH - DEAD)
	return Vector2(-back, a * SPREAD * back)

# ------------------------------------------------------------------ drawing
func draw(ci: CanvasItem, held: bool) -> void:
	if shown <= 0.01:
		return
	var a := shown
	_band(ci, PAD, PAD - 1.0, RIM, a)
	_band(ci, PAD - 1.0, PAD - 3.0, BAND, a)
	_band(ci, PAD - 3.0, -1.0, FILL, a)
	# the fan's three rays, faint: the top, the middle and the bottom aim
	for s in [-1.0, 0.0, 1.0]:
		var end := rest + Vector2(-REACH, SPREAD * REACH * s)
		ci.draw_line(rest + Vector2(-KNOB_R - 2, (KNOB_R + 2) * SPREAD * s), end, Color(RAY, RAY.a * a), 1.0)
	var c := (rest + knob).round()
	_disc(ci, c + Vector2(0, 1), KNOB_R + 1, Color(PoolArt.INK, PoolArt.INK.a * a))
	_disc(ci, c, KNOB_R + 1, Color(KNOB_DARK, a))
	_disc(ci, c, KNOB_R - 1, Color(KNOB.lightened(0.15) if held else KNOB, a))
	_disc(ci, c + Vector2(-2, -3), 2, Color(1, 1, 1, 0.75 * a))

## The wedge's rows between the shape `outer` px out from the fan and the one `inner` px out
## (inner < 0: none), as spans that never overlap, so a translucent colour never doubles up.
func _band(ci: CanvasItem, outer: float, inner: float, col: Color, a: float) -> void:
	var o: Array = _rows(outer)
	var i: Dictionary = {}
	if inner >= 0.0:
		for r in _rows(inner):
			i[r[0]] = r
	var c := Color(col, col.a * a)
	for r in o:
		var y: int = r[0]
		if not i.has(y):
			ci.draw_rect(Rect2(rest.x + r[1], rest.y + y, r[2] - r[1] + 1, 1), c)
			continue
		var ir: Array = i[y]
		if ir[1] > r[1]:
			ci.draw_rect(Rect2(rest.x + r[1], rest.y + y, ir[1] - r[1], 1), c)
		if r[2] > ir[2]:
			ci.draw_rect(Rect2(rest.x + ir[2] + 1, rest.y + y, r[2] - ir[2], 1), c)

## The rows of the shape `pad` px out from the knob's fan (rounded everywhere): [[y, x0, x1]...],
## px from rest. Worked out once per size.
func _rows(pad: float) -> Array:
	if _spans.has(pad):
		return _spans[pad]
	var out := []
	var top := ceili(SPREAD * REACH + pad)
	for y in range(-top, top + 1):
		var x0 := INF
		var x1 := -INF
		for x in range(-ceili(REACH + pad), ceili(pad) + 1):
			if _dist(Vector2(x, y)) <= pad:
				x0 = minf(x0, x)
				x1 = maxf(x1, x)
		if x0 <= x1:
			out.append([y, int(x0), int(x1)])
	_spans[pad] = out
	return out

## How far point `p` (px from rest) is outside the knob's fan (0 inside it).
static func _dist(p: Vector2) -> float:
	var a := Vector2.ZERO
	var b := Vector2(-REACH, -SPREAD * REACH)
	var c := Vector2(-REACH, SPREAD * REACH)
	if p.x >= -REACH and absf(p.y) <= SPREAD * -p.x:
		return 0.0
	return minf(minf(_seg(p, a, b), _seg(p, a, c)), _seg(p, b, c))

static func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))

## A filled pixel disc of radius `r` at `c`.
static func _disc(ci: CanvasItem, c: Vector2, r: int, col: Color) -> void:
	for dy in range(-r, r + 1):
		var w := roundi(sqrt(maxf(0.0, (r + 0.5) * (r + 0.5) - dy * dy)))
		ci.draw_rect(Rect2(c.x - w, c.y + dy, w * 2 + 1, 1), col)
