class_name HotFire
extends RefCounted
## THE HOT STAR FIRE (the Hot Star Gameplay update, refined by the Fire Animation Refinement): a
## hot man's flaming shots in a match, and a VERY HOT man's spark ring. Presentation only:
## nothing here touches a Swimmer, a Ball or a number the game plays with; it reads his Hot Stars
## (Attributes.hot_stars, his form right now) every frame, so it comes and goes with them and
## never outlives them. What he gets for being hot is his attribute bonus (Attributes.hot_bonus).
##
##   Hot Stars   the man                               his shots
##   0           as ever                                as ever
##   1           as ever: no aura, no sparks            the flaming shot
##   2           as ever, and a SPARK RING round the    the same flaming shot
##               water he sits in (draw_under)
## Nobody ever looks like he's burning: the fire belongs to the ball and its trail. The flaming
## shot is the one the first update gave a VERY HOT man (a red-and-orange rim and a flame licking
## off the ball, a long white-gold-to-red trail, embers shed behind it), unchanged, now for one
## Hot Star or two.
##
## Chunky whole-pixel rects in solid colours (a see-through orange over the pool's blue goes
## brown), drawn from his id and the clock alone: no particles to create or keep. The ring's back
## half is drawn BEFORE his body (draw_under: it goes behind him), its front half after
## (draw_over: on the water below his shoulders), so a spark never covers his sprite; and
## the shot's fire before the ball (the ball, its size and where it is, always on top).
## Reduce Motion (calm): the ring stands still (no running highlight, no flashing sparks) and the
## shot keeps its fire without the flicker or the shed embers.
## Only the match screens (and Developer Mode's HOT STAR TESTING, which draws a real swimmer and
## ball through these same calls) draw it: never a portrait, a card or a menu.

## Tests: while this is an Array, every rect goes into it ([Rect2, Color]) instead of onto `ci`.
static var record = null

static func _rect(ci: CanvasItem, r: Rect2, c: Color) -> void:
	if record != null:
		record.append([r, c])
	else:
		ci.draw_rect(r, c)

const RED := Color("e8461e")
const ORANGE := Color("ff8a1f")
const YELLOW := Color("ffd23f")
const CORE := Color("fff3b0")
const RING_GOLD := Color("f0b83a")    # the ring's dotted line: a dim gold, under the bright sparks

const FLICKER_FPS := 12.0     # the shot's flames change shape this often: an arcade flicker

## THE SPARK RING: an ellipse on the water round him, RING_R across and down from RING_C (off
## his waterline), a dotted gold line with RUNS bright runs going round it, and SPARKS tiny
## flashes on its edge that come and go (on for SPARK_ON of each SPARK_CYCLE), each with a pixel
## jumping out from the ring, like a crackle of electricity.
const RING_R := Vector2(12, 4)
const RING_C := Vector2(0, 2)
const RUN_TIME := 1.4         # s for a bright run to go once round
const RUN_LEN := 3            # pixels in a run
const RUNS := 3               # bright runs round the ring (two until the user asked for it 50% stronger)
const SPARKS := 5
const SPARK_CYCLE := 0.55
const SPARK_ON := 0.5

static var _ring: Array = []

## His Hot Stars as the art shows them: 0 none, 1, 2.
static func level_of(s: Swimmer) -> int:
	return Attributes.hot_stars(s.player) if s != null and s.player != null else 0

## Reduce Motion is on: the effects stand still.
static func calm() -> bool:
	return bool(Game.settings.get("reduce_motion", false))

## A fixed 0..1 for (`seed`, `k`): the flicker and the sparks' places.
static func _n(seed: int, k: int) -> float:
	var v := sin(float(seed) * 12.9898 + float(k) * 78.233) * 43758.5453
	return v - floorf(v)

static func _seed(s: Swimmer) -> int:
	return (s.player.id if s.player != null else 0) * 7 + (1 if s.side == Swimmer.Side.US else 0)

## The ring's pixels, in order round it (made once).
static func ring_points() -> Array:
	if _ring.is_empty():
		for i in 64:
			var a := TAU * i / 64.0
			var q := Vector2(roundf(cos(a) * RING_R.x), roundf(sin(a) * RING_R.y))
			if _ring.is_empty() or (_ring[_ring.size() - 1] != q and _ring[0] != q):
				_ring.append(q)
	return _ring

# ------------------------------------------------------------------ the man
## Before his body: the back half of a VERY HOT man's spark ring (it goes behind him). Nothing at
## all for one Hot Star or none.
static func draw_under(ci: CanvasItem, v: PoolView, s: Swimmer, t: float, lv: int = -1, still: bool = calm()) -> void:
	_ring_half(ci, v, s, t, lv, still, false)

## After his body: the ring's front half, on the water below his shoulders (never over his sprite:
## his head and shoulders stand above it).
static func draw_over(ci: CanvasItem, v: PoolView, s: Swimmer, t: float, lv: int = -1, still: bool = calm()) -> void:
	_ring_half(ci, v, s, t, lv, still, true)

static func _ring_half(ci: CanvasItem, v: PoolView, s: Swimmer, t: float, lv: int, still: bool, front: bool) -> void:
	lv = level_of(s) if lv < 0 else lv
	if lv < 2:
		return
	var c := v.to_screen(s.pos).round() + RING_C
	var pts := ring_points()
	var n := pts.size()
	var mine := func(q: Vector2) -> bool: return (q.y >= 0.0) == front
	# the dotted ring
	for i in range(0, n, 2):
		if mine.call(pts[i]):
			_rect(ci, Rect2(c + pts[i], Vector2.ONE), RING_GOLD)
	if still:
		# calm: four bright points standing still, no flashes
		for i in 4:
			var q: Vector2 = pts[(i * n) / 4]
			if mine.call(q):
				_rect(ci, Rect2(c + q, Vector2.ONE), YELLOW)
		return
	# the bright runs going round, evenly spaced
	var head := int(fposmod(t / RUN_TIME, 1.0) * n)
	for run in RUNS:
		for j in RUN_LEN:
			var q: Vector2 = pts[posmod(head + run * n / RUNS - j, n)]
			if mine.call(q):
				_rect(ci, Rect2(c + q, Vector2.ONE), YELLOW if j == 0 else ORANGE)
	# the sparks: now and then, somewhere on the edge, a flash and a pixel jumping out
	var seed := _seed(s)
	for i in SPARKS:
		var life := t / SPARK_CYCLE + _n(seed, 50 + i)
		var gen := int(floorf(life))
		var u := life - gen
		if u > SPARK_ON:
			continue
		var at: Vector2 = pts[int(_n(seed + gen * 11, 70 + i) * n) % n]
		if not mine.call(at):
			continue
		var out := Vector2(signf(at.x), signf(at.y))
		_rect(ci, Rect2(c + at, Vector2.ONE), CORE)
		_rect(ci, Rect2(c + at + out * (1.0 if u < SPARK_ON * 0.33 else (2.0 if u < SPARK_ON * 0.66 else 3.0)), Vector2.ONE), YELLOW if i % 2 == 0 else ORANGE)

# ------------------------------------------------------------------ the ball
## Before the ball: a shot's fire when its shooter has a Hot Star or two (`lv` -1 reads it from
## the ball). Nothing on a pass or in his hand: only the shot burns. Only the picture: the ball's
## own pixels are drawn after, its hitbox and flight untouched.
static func draw_ball_fire(ci: CanvasItem, v: PoolView, b: Ball, t: float, _holder: Swimmer = null, lv: int = -1,
		still: bool = calm()) -> void:
	if b == null or b.state != Ball.State.SHOT:
		return
	draw_shot_fire(ci, v, b.look(), b.to - b.from, level_of(b.shooter) if lv < 0 else lv, t, b.t * b.dur, still)

## THE FLAMING SHOT at `at` (x, y, height) flying along `dir`, `flown` s into its flight: one
## look for any Hot Star (`lv` 1 or 2; 0 none). The first update's VERY HOT shot, unchanged.
static func draw_shot_fire(ci: CanvasItem, v: PoolView, at: Vector3, dir: Vector2, lv: int, t: float, flown: float = 1.0,
		still: bool = calm()) -> void:
	if lv <= 0 or dir.length() < 0.001:
		return
	var d := dir.normalized()
	var p := v.to_screen(Vector2(at.x, at.y), at.z).round()
	var k := 0 if still else int(t * FLICKER_FPS * 1.5)
	# the trail: blobs back along the flight, biggest and whitest at the ball (it grows in over
	# the first tenth of a second, so the release isn't a flash of fire across the shooter)
	var n := 7
	var grow := clampf(flown / 0.1, 0.25, 1.0)
	var step := 0.3 * grow
	for i in range(n, 0, -1):
		var q := v.to_screen(Vector2(at.x, at.y) - d * (step * i), at.z).round()
		var u := float(i) / n                                   # 0 at the ball .. 1 at the tail
		var sz := maxi(1, roundi(lerpf(5.0, 1.0, u)))
		var jit := 0 if still else int(_n(i * 7, k) * 3.0) - 1
		var col := CORE if u < 0.3 else (YELLOW if u < 0.55 else (ORANGE if u < 0.8 else RED))
		_rect(ci, Rect2(q.x - floorf(sz / 2.0), q.y - floorf(sz / 2.0) + jit, sz, sz), col)
	# round the ball: a rim of fire darker than the ball (its 6 x 4 goes on top), so the yellow
	# ball always stands out of its own flames: orange round red
	_rect(ci, Rect2(p.x - 4, p.y - 4, 10, 8), ORANGE)
	_rect(ci, Rect2(p.x - 3, p.y - 3, 8, 6), RED)
	# a tongue off the top of the ball, flickering, licking back from the flight
	var back := -2 if d.x > 0.0 else 2
	var h := 3 + (0 if still else int(_n(3, k) * 3.0))
	_rect(ci, Rect2(p.x + back, p.y - 4 - h, 2, h), ORANGE)
	_rect(ci, Rect2(p.x + back + (1 if back > 0 else 0), p.y - 4 - roundi(h * 0.5), 1, roundi(h * 0.5)), YELLOW)
	if not still:
		# embers shed behind it
		for i in 3:
			var e := fposmod(t * 2.5 + i * 0.33, 1.0)
			var q := v.to_screen(Vector2(at.x, at.y) - d * (0.4 + e * 1.2), at.z).round()
			if e < 0.8:
				_rect(ci, Rect2(q.x + (i - 1) * 2, q.y - 3 + roundi(e * 6.0) * (1 if i % 2 == 0 else -1), 1, 1), RED if i == 1 else YELLOW)

# ------------------------------------------------------------------ Developer Mode
## What the art is doing for a player now: {level, ring (the two-star spark ring), shot (the
## flaming shot)}.
static func status(p: PoloPlayer) -> Dictionary:
	var lv := Attributes.hot_stars(p)
	return {"level": lv, "ring": lv >= 2, "shot": lv >= 1}
