class_name GoalFx
extends RefCounted
## GOAL CELEBRATIONS: the equipped celebration (VisualUpgrades.celeb), played at the goal the ball
## went into, for any goal in a game you play. One at a time, never mixed:
##   0 CLASSIC             the GoalShow alone (GOAL!, the splash): nothing added
##   1 CONFETTI POPPERS    a popper on each back post fires a burst of confetti up and out over
##                         the goal; it flutters down to the water and is gone
##   2 WATER EXPLOSION     a water cannon on each back post: two blue sprays punch up and fan out
##                         away from each other, clusters breaking into drops that rain back, splashes
##                         and rings on the water
##   3 GOALPOST FIREWORKS  a big rocket off each back post, high over the goal, bursting huge in the
##                         scoring team's colours; smaller rockets and crackles after, all shimmering
## Everything is placed off the real goal (show.mouth: either end, mirrored or not, PoolView) and
## its back posts (PoolArt.BACK_ROPE behind the goal line, the cage's 0.9 m up), drawn in whole
## pixels from the show's clock alone: nothing kept per particle, so nothing to clean up, and when
## the show ends (or is skipped) it's all gone. It adds no time and touches nothing in the game: the
## goal, the score, the clocks and the restart don't know it's there.
## Two passes: draw_world in the pool's layer before the swimmers (the poppers' tubes, the water
## cannons, the rockets leaving the posts, the rings on the water), draw over everything after
## (what flies above).
## Reduce Motion (calm): no shake, less of everything, nothing twinkling.

const T0 := 0.08               # s into the show it fires: as the ball hits the net
const POST_UP := 0.9           # m: the top of the cage (PoolArt.draw_goal)
const PALETTE := [Color("ff5a5a"), Color("ffcf3f"), Color("5fe0ff"), Color("7dff8a"), Color("ff6fae"), Color("f2f2e9")]
const SPRAY := Color("9fe4ff")
const FOAM := Color("f2fbff")
const DEEP := Color("2f8cff")
const GOLD := Color("ffd83d")

## Pieces, by celebration (calm: half).
const CONFETTI_N := 44         # a popper
const JET_N := 56              # a water cannon's stream: blobs per strand (close enough to touch)...
const JET_SPRAY := 32          # ...and the drops torn off it
const SPARKS_N := 48           # a big firework's outer shell (and its second shell)...
const CORE_N := 24             # ...its white-gold heart...
const TWINKLE_N := 32          # ...and the glitter scattered further out
const SHELL_SPARKS := 24       # each smaller rocket after them
const CRACKLE_SPARKS := 8      # each little crackle at the end

## Developer Mode's GOAL CELEBRATION PREVIEW: a celebration worn in matches for testing, owned or
## not (-1: none, the real one). In memory only: never saved, gone when the game closes, and
## Store.looks (what's owned and equipped) is never touched.
static var dev_equip := -1

## The celebration a match plays: the test one if Developer Mode set one, else the equipped one.
static func equipped() -> int:
	return dev_equip if dev_equip >= VisualUpgrades.CLASSIC else Store.looks.worn_celeb()

var level := VisualUpgrades.CLASSIC
var calm := false
var c1 := Color.WHITE
var c2 := Color.BLACK
var show: GoalShow = null
var _cues := {}

## A goal: the celebration equipped, the scoring team's own colours.
func start(celeb: int, p_show: GoalShow, p_c1: Color, p_c2: Color, p_calm: bool) -> void:
	level = clampi(celeb, VisualUpgrades.CLASSIC, VisualUpgrades.FIREWORKS)
	show = p_show
	c1 = p_c1
	c2 = p_c2
	calm = p_calm
	_cues = {}

func clear() -> void:
	show = null

func active() -> bool:
	return show != null and show.active() and level != VisualUpgrades.CLASSIC

## What this celebration draws, for the tests and Developer Mode.
func parts() -> Dictionary:
	var k := 2 if calm else 1
	return {
		"poppers": 2 if level == VisualUpgrades.CONFETTI else 0,
		"confetti": CONFETTI_N * 2 / k if level == VisualUpgrades.CONFETTI else 0,
		"cannons": 2 if level == VisualUpgrades.WATER else 0,
		"drops": (JET_N * (1 if calm else JET_STRANDS) + (JET_SPRAY + JET_MIST) / k) * 2 if level == VisualUpgrades.WATER else 0,
		"ripples": 6 if level == VisualUpgrades.WATER else 0,
		"rockets": 2 if level == VisualUpgrades.FIREWORKS else 0,
		"shells": SHELL_AT.size() if level == VisualUpgrades.FIREWORKS else 0,
		"sparks": ((SPARKS_N * 2 + CORE_N + TWINKLE_N) * 2 + (SHELL_SPARKS + CRACKLE_SPARKS) * SHELL_AT.size()) / k \
			if level == VisualUpgrades.FIREWORKS else 0,
		"shake": level == VisualUpgrades.WATER and not calm}

## Seconds since it fired (negative: not yet).
func age() -> float:
	return show.t - T0 if show != null else -1.0

## A frame: the sounds (and the water's jolt) at their cues.
func tick(view: PoolView) -> void:
	if not active():
		return
	var u := age()
	match level:
		VisualUpgrades.CONFETTI:
			if _cue("pop", u >= 0.0):
				Sfx.play("bang", 1.9, -13.0)
		VisualUpgrades.WATER:
			if _cue("boom", u >= 0.0):
				Sfx.play("splash", 0.6, 2.0)
				Sfx.play("dive", 0.7, -6.0)
				if view != null and not calm:
					view.shake = maxf(view.shake, 1.2)
			if _cue("rain", u >= 0.8):
				Sfx.play("splash", 1.3, -8.0)
		VisualUpgrades.FIREWORKS:
			if _cue("launch", u >= 0.0):
				Sfx.play("dive", 1.6, -8.0)
			for k in 2:
				if _cue("burst%d" % k, u >= rocket_burst(k)):
					Sfx.play("bang", 1.1 - 0.15 * k, -4.0)
			for m in SHELL_AT.size():
				if _cue("shell%d" % m, u >= shell_burst(m)):
					Sfx.play("bang", 1.45 + 0.1 * m, -9.0)
				if _cue("crackle%d" % m, u >= float(CRACKLE_AT[m])):
					Sfx.play("bang", 2.2 + 0.15 * m, -15.0)

## True the first frame `now` is (each cue once a goal).
func _cue(id: String, now: bool) -> bool:
	if not now or _cues.has(id):
		return false
	_cues[id] = true
	return true

## A fixed 0..1 for (`a`, `b`).
static func _n(a: int, b: int) -> float:
	var v := sin(float(a) * 12.9898 + float(b) * 78.233) * 43758.5453
	return v - floorf(v)

## How much is left as the show fades back to play (1 .. 0).
func _fade() -> float:
	return 1.0 - clampf((show.t - show.out_at()) / GoalShow.OUT, 0.0, 1.0)

# ------------------------------------------------------------------ where the goal is
## The goal it went into, on screen: {far, near} the tops of its two back posts, {mouth} where
## it crossed the line (on the water), {water} the waterline under the posts, {out} +1 / -1 the
## way into the pool on screen, {s} the camera's zoom (pixels scale with it).
func goal_points(v: PoolView) -> Dictionary:
	return points(v, show.mouth)

## goal_points for a goal crossing the line at `at` (pool metres; at.x is which goal: 0 or GOAL_X).
## {far_w, near_w}: the water at the foot of each back post.
static func points(v: PoolView, at: Vector2) -> Dictionary:
	var gx := at.x
	var back := gx + PoolArt.BACK_ROPE * (1.0 if gx > Geo.HALF else -1.0)
	var far := v.to_screen(Vector2(back, Geo.GOAL_Y - Geo.GOAL_HALF), POST_UP)
	var near := v.to_screen(Vector2(back, Geo.GOAL_Y + Geo.GOAL_HALF), POST_UP)
	var mouth := v.to_screen(Vector2(gx, clampf(at.y, Geo.GOAL_Y - Geo.GOAL_HALF + 0.2, Geo.GOAL_Y + Geo.GOAL_HALF - 0.2)))
	var line := v.to_screen(Vector2(gx, Geo.GOAL_Y))
	var mid := v.to_screen(Vector2(Geo.HALF, Geo.GOAL_Y))
	return {"far": far, "near": near, "mouth": mouth, "water": near.y + roundf(POST_UP * v.sz()),
		"far_w": far + Vector2(0, roundf(POST_UP * v.sz())), "near_w": near + Vector2(0, roundf(POST_UP * v.sz())),
		"out": 1.0 if mid.x > line.x else -1.0, "s": clampf(v.zoom, 0.6, 1.6), "top": far.y}

## A point in the pool's layer onto the screen's (the HUD layer: the 6 on 5 push in, ManUpCam).
static func _lift(v: PoolView, p: Vector2) -> Vector2:
	return (v.cine * p).round()

static func _px(ci: CanvasItem, p: Vector2, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(roundf(p.x), roundf(p.y), w, h), c)

# ------------------------------------------------------------------ the two passes
## In the pool's layer, before the swimmers: what sits on the goal and the water.
func draw_world(ci: CanvasItem, v: PoolView) -> void:
	if not active() or v == null or age() < -0.05:
		return
	var g := goal_points(v)
	match level:
		VisualUpgrades.CONFETTI:
			_poppers(ci, g)
		VisualUpgrades.WATER:
			_cannons(ci, g)
			_jet_ripples(ci, g)
		VisualUpgrades.FIREWORKS:
			_launch(ci, g)

## Over everything (the HUD's layer): what flies above the goal.
func draw(ci: CanvasItem, _size: Vector2, v: PoolView) -> void:
	if not active() or v == null or age() < 0.0:
		return
	var g := goal_points(v)
	for k in ["far", "near", "mouth", "far_w", "near_w"]:
		g[k] = _lift(v, g[k])
	match level:
		VisualUpgrades.CONFETTI:
			_confetti(ci, g)
		VisualUpgrades.WATER:
			_jets(ci, g)
		VisualUpgrades.FIREWORKS:
			_fireworks(ci, g)

# ------------------------------------------------------------------ 1 CONFETTI POPPERS
const POP_LIFE := 2.1          # s a piece can last (it's gone sooner if it reaches the water)

## The two poppers, a little tube on each back post, kicking back as they fire, a puff off the top.
func _poppers(ci: CanvasItem, g: Dictionary) -> void:
	var u := age()
	if u > 1.4:
		return
	for k in 2:
		var p: Vector2 = g.far if k == 0 else g.near
		var kick := 1.0 if u >= 0.0 and u < 0.1 else 0.0
		var col: Color = PALETTE[k * 3]
		_px(ci, p + Vector2(-1, -5 + kick), 3, 5, col)           # the tube
		_px(ci, p + Vector2(-1, -5 + kick), 1, 5, col.lightened(0.4))
		_px(ci, p + Vector2(-2, -6 + kick), 5, 1, GOLD)            # its gold rim
		if u >= 0.0 and u < 0.22:                                   # the puff
			var r := 2.0 + u * 30.0
			var a := 0.9 * (1.0 - u / 0.22)
			for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(0, -1.4), Vector2(-1.3, -0.4), Vector2(1.3, -0.4)]:
				_px(ci, p + Vector2(0, -7) + d * r, 2, 2, Color(1, 1, 1, a))

## Each popper's burst: up and out of its post (the far one up the screen, the near one out over
## the roof), slowing, then fluttering down to the water, each piece gone when it gets there.
func _confetti(ci: CanvasItem, g: Dictionary) -> void:
	var u0 := age()
	var n := CONFETTI_N / (2 if calm else 1)
	var fade := _fade()
	var cols := PALETTE + [c1.lightened(0.15), c2.lightened(0.15)]
	for k in 2:
		var from: Vector2 = (g.far if k == 0 else g.near) + Vector2(0, -7)
		for i in n:
			var u := u0 - 0.04 * _n(i, k + 11)                     # (not quite all at once)
			if u < 0.0 or u > POP_LIFE * (0.75 + 0.25 * _n(i, k + 3)) or _n(i, k + 9) > fade:
				continue
			# launched in a fan, mostly up, leaning out over the pool and away from the other post
			var lean := (_n(i, k + 1) - 0.5) * 2.2
			var a := -PI * 0.5 + lean * 0.62 + float(g.out) * 0.18
			var sp := (95.0 + 95.0 * _n(i, k + 2)) * float(g.s)
			var v0 := Vector2(cos(a) * 1.15, sin(a)) * sp
			if k == 1:
				v0.y *= 0.92
			var q := from + _drag(v0, u, 3.2, 18.0 * float(g.s))
			q.x += sin(u * 7.0 + i * 1.7) * 2.5 * minf(1.0, u * 2.0)   # the flutter as it falls
			if q.y >= float(g.water) + 2.0:
				continue                                            # in the water: gone
			var flip := (int(u * 10.0 + _n(i, 7) * 4.0)) % 3
			var w: int = [2, 1, 2][flip]
			var h: int = [1, 2, 2][flip] if i % 4 != 0 else 1
			_px(ci, q, w, h, cols[(i + k * 3) % cols.size()])

## Where a thrown piece is `u` s on: launched at `v0` px/s, slowed by drag `k`, falling at most
## `vt` px/s (linear drag: the classic closed form, so nothing has to be stepped or kept).
static func _drag(v0: Vector2, u: float, k: float, vt: float) -> Vector2:
	var e := (1.0 - exp(-k * u)) / k
	return v0 * e + Vector2(0, vt * (u - e))

# ------------------------------------------------------------------ 2 WATER EXPLOSION
## A water cannon on each back post, firing together (u: s since they fired):
##   0.00-0.20 ACTIVATE   the cannons kick, a white burst off each nozzle, the jets punch up
##   0.20-0.70 STREAMS    two thick streams climb and fan out, away from each other along the goal
##                        line and out over the pool, spray tearing off them; they peak
##   0.70-1.20 BREAK UP   the streams come apart into falling drops, splashing into the pool
##   1.20-1.50 SETTLE     the last drops and the rings on the water fade away
## Mirror images of each other: the far one leans away from us, the near one towards us. Each
## stream is a run of blobs poured out of the nozzle one after another, each flying on its own
## (gravity, no drag: the closed form, nothing stepped or kept), so it bends into a real arc and,
## as each blob's little difference in speed grows, comes apart into drops by itself.
const JET_LIFE := 1.5          # s, the whole thing
const JET_POUR := 0.5          # s the cannons pour for
const JET_STRANDS := 2         # strands a cannon fires, fanned (the outer one lower and wider)
const JET_G := 620.0           # px/s² the water falls at (zoom 1)
const JET_RISE := 52.0         # px over its nozzle a stream peaks at full power (zoom 1), room allowing
const JET_RISE_MIN := 30.0     # ...and at least, however little room there is over the goal
const JET_OUT := 0.3           # its speed out over the pool, against its speed up...
const JET_SIDE := 0.15         # ...and along the goal line, away from the other cannon
const JET_NOZZLE := 7.0        # px over the post's top the water leaves the cannon
const CYAN := Color("5fe8ff")  # the bright highlights
const STEEL := Color("8fa3bf")

## How hard the cannons are pouring `te` s after they fired: a kick, then steady, then easing off.
static func jet_power(te: float) -> float:
	if te < 0.05:
		return 0.8 + 0.3 * te / 0.05
	if te < 0.2:
		return lerpf(1.1, 1.0, (te - 0.05) / 0.15)
	if te < 0.36:
		return 1.0
	return lerpf(1.0, 0.6, clampf((te - 0.36) / (JET_POUR - 0.36), 0.0, 1.0))

## Cannon `k`'s (0 far, 1 near) launch velocity for strand `j`, at full power, px/s:
## x out over the pool (on screen), y up, z along the goal line (on screen: down is towards us).
## Both peak at the same height: what fits over the far post (its lean away from us lifts it up
## the screen, the first kick a little more), so the far one isn't lost under the scoreboard.
static func _jet_v(g: Dictionary, k: int, j: int) -> Vector3:
	var s := float(g.s)
	var room := ((g.far as Vector2).y - JET_NOZZLE - PoolView.HUD_H * 0.5) / (1.21 + 2.2 * JET_SIDE)
	var rise := clampf(room, JET_RISE_MIN * s, JET_RISE * s)
	var up := sqrt(2.0 * JET_G * s * rise) * (1.0 if j == 0 else 0.86)
	var lean := 1.0 if j == 0 else 1.7
	return Vector3(float(g.out) * JET_OUT * lean * up, up, (-1.0 if k == 0 else 1.0) * JET_SIDE * lean * up)

## Where water fired from cannon `k` at `v` is `a` s on: on screen, and how high over the pool
## (z, under 0: back in).
static func _jet_at(g: Dictionary, k: int, v: Vector3, a: float) -> Vector3:
	var w: Vector2 = g.far_w if k == 0 else g.near_w
	var p: Vector2 = g.far if k == 0 else g.near
	var h := (w.y - p.y + JET_NOZZLE) + v.y * a - 0.5 * JET_G * float(g.s) * a * a
	return Vector3(w.x + v.x * a, w.y + v.z * a - h, h)

## Where cannon `k`'s main stream comes down, on the water.
static func _jet_landing(g: Dictionary, k: int) -> Vector2:
	var v := _jet_v(g, k, 0)
	var w: Vector2 = g.far_w if k == 0 else g.near_w
	var p: Vector2 = g.far if k == 0 else g.near
	var gs := JET_G * float(g.s)
	var t := (v.y + sqrt(v.y * v.y + 2.0 * gs * (w.y - p.y + JET_NOZZLE))) / gs
	return w + Vector2(v.x, v.z) * t

## The cannons on the posts (a squat steel barrel, kicking as it fires, a white burst off the
## nozzle), in the pool's layer: the swimmers in front of the goal go over them.
func _cannons(ci: CanvasItem, g: Dictionary) -> void:
	var u := age()
	if u > JET_LIFE:
		return
	var a := 1.0 - clampf((u - 1.2) / 0.3, 0.0, 1.0)
	for k in 2:
		var p: Vector2 = g.far if k == 0 else g.near
		var kick := 1.0 if u >= 0.0 and u < 0.1 else 0.0
		_px(ci, p + Vector2(-2, -3 + kick), 5, 3, Color(0.23, 0.29, 0.39, a))   # the mount
		_px(ci, p + Vector2(-1, -6 + kick), 3, 4, Color(STEEL, a))            # the barrel
		_px(ci, p + Vector2(-1, -6 + kick), 1, 4, Color(0.84, 0.89, 0.94, a))
		_px(ci, p + Vector2(-2, -7 + kick), 5, 1, Color(CYAN, a))             # its rim
		if u >= 0.0 and u < 0.2:                                            # the burst off it
			var r := 2.0 + u * 40.0
			var f := 1.0 - u / 0.2
			for d in [Vector2(-1, -0.6), Vector2(1, -0.6), Vector2(0, -1.2), Vector2(-1.4, 0), Vector2(1.4, 0), Vector2(-0.6, -1.1), Vector2(0.6, -1.1)]:
				_px(ci, p + Vector2(-1, -JET_NOZZLE - 1) + d * r, 3, 2, Color(FOAM, 0.9 * f))
		if u >= 0.0 and u < JET_POUR:                                       # pouring: it boils at the nozzle
			var b := int(u * 30.0)
			for d in 3:
				_px(ci, p + Vector2(-2 + d * 2, -JET_NOZZLE - 1 - (b + d) % 2), 2, 2, FOAM if (b + d) % 3 else CYAN)

## The rings where the streams come down, a white boil on the water under each, and the foam at
## the foot of each post where the cannon's kick hits the pool.
func _jet_ripples(ci: CanvasItem, g: Dictionary) -> void:
	var u := age()
	if u < 0.0 or u > JET_LIFE:
		return
	var s := float(g.s)
	var fade := _fade()
	for k in 2:
		var w: Vector2 = g.far_w if k == 0 else g.near_w
		if u < 0.35:                                                        # the kick at the post's foot
			var e := u / 0.35
			_oval(ci, w + Vector2(0, 1), roundi((3.0 + 8.0 * e) * s), maxi(1, roundi((1.0 + 2.0 * e) * s)), Color(SPRAY, 0.7 * (1.0 - e) * fade), false)
		var c := _jet_landing(g, k)
		var boil := clampf((u - 0.7) / 0.15, 0.0, 1.0) * (1.0 - clampf((u - 1.05) / 0.35, 0.0, 1.0))
		if boil > 0.0:
			var rw := roundi((5.0 + 5.0 * boil) * s)
			_oval(ci, c, rw, maxi(1, rw / 3), Color(FOAM, 0.75 * boil * fade), true)
		for n in 3:
			var t0: float = [0.74, 0.92, 1.08][n]
			var r := u - t0
			if r < 0.0 or r > 0.42:
				continue
			var e := r / 0.42
			var rx := roundi((4.0 + 20.0 * (1.0 - pow(1.0 - e, 2.0))) * s)
			_oval(ci, c + Vector2(0, 1), rx, maxi(2, rx / 3), Color(SPRAY, 0.85 * (1.0 - e) * fade), false)

## An ellipse on the water in whole pixels: a ring (or, `fill`, a patch of foam).
static func _oval(ci: CanvasItem, c: Vector2, rx: int, ry: int, col: Color, fill: bool) -> void:
	if rx < 1 or ry < 1:
		return
	for dy in range(-ry, ry + 1):
		var hw := roundi(rx * sqrt(maxf(0.0, 1.0 - float(dy * dy) / float(ry * ry))))
		var y := roundf(c.y) + dy
		if fill:
			ci.draw_rect(Rect2(roundf(c.x) - hw, y, 2 * hw + 1, 1), col)
			continue
		var nxt := roundi(rx * sqrt(maxf(0.0, 1.0 - float((absi(dy) + 1) * (absi(dy) + 1)) / float(ry * ry))))
		var w := maxi(1, hw - nxt)   # (fills the steps near the top and bottom, so the ring is unbroken)
		ci.draw_rect(Rect2(roundf(c.x) - hw, y, w, 1), col)
		ci.draw_rect(Rect2(roundf(c.x) + hw - w + 1, y, w, 1), col)

## The water's colours: mostly bright blue and cyan, then light blue, white only for the foam and
## the glints (W_BLUE..W_FOAM: where a 0..1 roll falls, ~30 / 30 / 25 / 15 %).
const W_BLUE := Color("5cc8ff")
const W_LIGHT := Color("a6e4ff")
const W_SHADE := Color("1556c4")    # the shadow under the bigger clusters, so they read on the pool
const W_MIX := [0.30, 0.60, 0.85]
const JET_FAN := 0.18          # how far each blob's launch strays sideways (x, z), of its speed up...
const JET_LIFT := 0.08         # ...and up and down (a little: the far one stays clear of the scoreboard)
const JET_MIST := 28           # the fine cyan mist round a cannon's spray
const SPLASH := 0.16           # s a landing drop's splash lasts

## The water's colour for a 0..1 roll (W_MIX).
static func _water(h: float) -> Color:
	if h < W_MIX[0]:
		return W_BLUE
	if h < W_MIX[1]:
		return CYAN
	if h < W_MIX[2]:
		return W_LIGHT
	return FOAM

## The two sprays over everything: a fine mist round them, then three layers of the streams (a
## shadow under the big clusters, the water, the glints and splashes), then the drops torn off.
func _jets(ci: CanvasItem, g: Dictionary) -> void:
	var u := age()
	if u < 0.0 or u > JET_LIFE:
		return
	var s := float(g.s)
	var fade := _fade() * (1.0 - clampf((u - 1.2) / 0.3, 0.0, 1.0))
	if fade <= 0.0:
		return
	var big := 3 if s < 1.25 else 4
	var strands := 1 if calm else JET_STRANDS
	_mist(ci, g, u, fade)
	for layer in 3:
		for k in 2:
			for j in strands:
				_stream(ci, g, k, j, u, layer, big, fade)
	_spray(ci, g, u, fade)

## The four ways a cluster's loose bits sit off it.
const CLUSTER := [Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1)]

## One strand of cannon `k`'s spray, one layer of it. Every blob leaves the nozzle at its own angle
## and speed, so the strand fans out as it flies: tight clusters of water off the post, coming apart
## into smaller and fewer drops the further they go and the further they fall; a splash where each
## lands.
func _stream(ci: CanvasItem, g: Dictionary, k: int, j: int, u: float, layer: int, big: int, fade: float) -> void:
	var v0 := _jet_v(g, k, j)
	var gs := JET_G * float(g.s)
	var seed := k * 7 + j * 3
	for i in JET_N:
		var te := JET_POUR * float(i) / float(JET_N)
		var a := u - te
		if a < 0.0:
			break                                                           # (not out of the nozzle yet)
		var v := _blob_v(v0, te, i, seed)
		var q := _jet_at(g, k, v, a)
		if q.z < 0.0:
			if layer == 2 and i % 3 != 2:
				_splash(ci, g, k, v, a, i, seed, fade)
			continue
		var p := Vector2(q.x, q.y)
		var past := maxf(0.0, a - v.y / gs)                                 # s past the top of its arc
		var d := clampf(a / 0.8 + past / 0.4, 0.0, 1.0)                    # 0 a cluster .. 1 a scatter of drops
		if _n(i, seed + 4) < 0.06 + 0.4 * d:
			continue                                                        # (the gaps)
		var sz := big if d < 0.35 else (big - 1 if d < 0.7 else 1 + int(_n(i, seed + 5) < 0.3))
		var o := Vector2(sz >> 1, sz >> 1)
		var col := FOAM if a < 0.04 else _water(_n(i, seed + 6))
		# a cluster's loose bits: a pixel or two beside it, drifting off as it goes
		var bits := 0 if sz < 2 else (2 if d < 0.3 else 1)
		var spread := 1.0 + roundf(d * 3.0)
		match layer:
			0:
				if sz >= 2:
					_px(ci, p - o + Vector2(0, 1), sz, sz, Color(W_SHADE, 0.7 * fade))
			1:
				_px(ci, p - o, sz, sz, Color(col, fade))
				for b in bits:
					var dir: Vector2 = CLUSTER[(i + b * 2 + j) % 4]
					var bc := _water(_n(i, seed + 7 + b))
					_px(ci, p + dir * (float(sz >> 1) + spread), maxi(1, sz - 2), 1 if b else maxi(1, sz - 2), Color(bc, fade))
			2:
				if sz >= 2 and i % 4 == 0:
					_px(ci, p - o, 1, 1, Color(FOAM, fade))                 # (the glint)

## Blob `i`'s launch: the strand's velocity at the power it left at, its angle and speed a little
## its own (sideways more than up), so no two take the same path and the spray fans out.
static func _blob_v(v0: Vector3, te: float, i: int, seed: int) -> Vector3:
	var v := v0 * jet_power(te)
	var up := v.y
	v.y *= 1.0 + (_n(i, seed + 2) - 0.5) * JET_LIFT
	v.x += (_n(i, seed + 1) - 0.5) * JET_FAN * up
	v.z += (_n(i, seed + 3) - 0.5) * JET_FAN * up
	return v

## A drop's splash on the water, for SPLASH s after it lands: a fleck of foam where it went in and
## two little drops kicked up and out.
func _splash(ci: CanvasItem, g: Dictionary, k: int, v: Vector3, a: float, i: int, seed: int, fade: float) -> void:
	var w: Vector2 = g.far_w if k == 0 else g.near_w
	var p: Vector2 = g.far if k == 0 else g.near
	var gs := JET_G * float(g.s)
	var land := (v.y + sqrt(v.y * v.y + 2.0 * gs * (w.y - p.y + JET_NOZZLE))) / gs
	var e := (a - land) / SPLASH
	if e < 0.0 or e > 1.0:
		return
	var q := _jet_at(g, k, v, land)
	var at := Vector2(q.x, q.y + q.z)
	if e < 0.45:
		_px(ci, at + Vector2(-1, 0), 3, 1, Color(FOAM, fade * (1.0 - e)))
	var hop := sin(PI * e) * (2.0 + 2.0 * _n(i, seed + 8))
	for side in [-1.0, 1.0]:
		_px(ci, at + Vector2(side * (1.0 + 3.0 * e), -hop), 1, 1, Color(CYAN if side < 0.0 else W_LIGHT, fade * (1.0 - e * 0.5)))

## The mist: tiny cyan specks hanging round each spray, wider than it and gone sooner.
func _mist(ci: CanvasItem, g: Dictionary, u: float, fade: float) -> void:
	var n := JET_MIST / (2 if calm else 1)
	for k in 2:
		for i in n:
			var te := 0.03 + (JET_POUR - 0.05) * _n(i, k + 61)
			var a := u - te
			var life := 0.35 + 0.3 * _n(i, k + 62)
			if a < 0.05 or a > life:
				continue
			var v := _jet_v(g, k, i % JET_STRANDS) * jet_power(te) * 0.8
			var up := v.y
			v.x += (_n(i, k + 63) - 0.5) * 0.7 * up
			v.z += (_n(i, k + 64) - 0.5) * 0.7 * up
			var q := _jet_at(g, k, v, a)
			if q.z < 0.0:
				continue
			var al := 0.6 * (1.0 - a / life) * fade
			_px(ci, Vector2(q.x, q.y), 1, 1, Color(CYAN if i % 3 else W_LIGHT, al))

## The spray: drops torn off each stream as it climbs, flying wide of it.
func _spray(ci: CanvasItem, g: Dictionary, u: float, fade: float) -> void:
	var n := JET_SPRAY / (2 if calm else 1)
	for k in 2:
		for i in n:
			if _n(i, k + 41) > fade:
				continue
			var te := 0.02 + (JET_POUR - 0.08) * _n(i, k + 42)
			var a := u - te
			if a < 0.0:
				continue
			var jit := Vector3(_n(i, k + 43) - 0.5, _n(i, k + 44) - 0.4, _n(i, k + 45) - 0.5) * 0.5
			var v := _jet_v(g, k, i % JET_STRANDS) * jet_power(te) * (Vector3.ONE + jit)
			var q := _jet_at(g, k, v, a)
			if q.z < 0.0:
				continue
			var sz := i % 3
			_px(ci, Vector2(q.x, q.y), 2 if sz == 0 else 1, 2 if sz == 1 else 1, _water(_n(i, k + 46)))

# ------------------------------------------------------------------ 3 GOALPOST FIREWORKS
## A championship show off the back posts (u: s since the goal):
##   0.00-0.30 LAUNCH     a big rocket off each post at once, climbing high on a trail of sparks
##   0.30-0.70 BURST      two huge bursts: a white flash, then three shells (the team's first colour,
##                        its second, a white-gold heart) thrown out round
##   0.70-1.20 SECONDARY  four smaller rockets after them, bursting around and over the goal
##   1.20-1.70 CRACKLE    little gold crackles; the glitter lingers, everything shimmers as it dies
##   1.70-2.00 FADE       the last of the glitter goes
const FW_LIFE := 2.0           # s, the whole thing
const CLIMB := 0.3             # s a big rocket climbs
const RISE_PX := 54.0          # px over its post the far one bursts (the near one: _apex)
const BURST_LIFE := 1.4        # s a big burst's sparks last (some go sooner)
const FW_K := 2.6              # the drag on a spark
const SHELL_AT := [0.42, 0.5, 0.58, 0.66]   # s the smaller rockets leave (far post, near, far, near)
const SHELL_CLIMB := 0.26
const SHELL_LIFE := 0.8
## Where each smaller rocket bursts, px off a big one (x out over the pool, y down): over the
## pool off the far one, over the pool off the near one, up over the deck, out over the mouth.
const SHELL_AIM := [Vector2(30, 14), Vector2(34, 10), Vector2(-16, -14), Vector2(54, -4)]
const CRACKLE_AT := [1.12, 1.22, 1.33, 1.45]
const CRACKLE_AIM := [Vector2(-10, -18), Vector2(24, 12), Vector2(46, -10), Vector2(8, 24)]

## When rocket `k` (0 off the far post, 1 off the near one) bursts, s after the goal.
static func rocket_burst(k: int) -> float:
	return CLIMB + k * 0.04

## When smaller rocket `m` bursts.
static func shell_burst(m: int) -> float:
	return float(SHELL_AT[m]) + SHELL_CLIMB

## Where rocket `k` bursts on screen.
func _apex(g: Dictionary, k: int) -> Vector2:
	var p: Vector2 = g.far if k == 0 else g.near
	var s := float(g.s)
	var far_y: float = (g.far as Vector2).y
	var near_y: float = (g.near as Vector2).y
	# the far one bursts high over the crossbar, the near one over the net, out towards the pool;
	# kept clear of the scoreboard (PoolView.HUD_H) at the heart, its sparks free to fly under it
	var y := far_y - RISE_PX * s if k == 0 else lerpf(far_y, near_y, 0.4) - RISE_PX * 0.5 * s
	return Vector2(p.x + float(g.out) * (6.0 if k == 0 else 20.0) * s, maxf(y, PoolView.HUD_H + 10.0))

## Where smaller rocket `m` bursts.
func _shell_apex(g: Dictionary, m: int) -> Vector2:
	var base := _apex(g, 0) if m % 2 == 0 else _apex(g, 1)
	if m == 3:
		base = _apex(g, 0).lerp(_apex(g, 1), 0.5)
	var d: Vector2 = SHELL_AIM[m]
	var q := base + Vector2(d.x * float(g.out), d.y) * float(g.s)
	return Vector2(q.x, maxf(q.y, PoolView.HUD_H + 8.0))

## The team's colours, made to show up on the water (a dark colour lifted).
func _team(c: Color) -> Color:
	return c.lightened(0.45) if c.get_luminance() < 0.3 else c

## Off the posts, in the pool's layer: the launchers, the flash and smoke as each rocket goes
## (the two big ones together, then the smaller ones), the rockets climbing clear of the frame.
func _launch(ci: CanvasItem, g: Dictionary) -> void:
	var u0 := age()
	if u0 > float(SHELL_AT[3]) + 0.7:
		return
	for k in 2:
		var p: Vector2 = g.far if k == 0 else g.near
		_px(ci, p + Vector2(-2, -3), 5, 3, Color("6b7280"))               # the launcher on the post
		_px(ci, p + Vector2(-1, -4), 3, 1, Color("9aa3b2"))
	for m in 2 + SHELL_AT.size():
		var u := u0 if m < 2 else u0 - float(SHELL_AT[m - 2])
		var p: Vector2 = g.far if m % 2 == 0 else g.near
		var big := m < 2
		if u < 0.0 or u > 0.6:
			continue
		if u < (0.14 if big else 0.08):                                    # the flash
			_px(ci, p + Vector2(-3, -6) if big else p + Vector2(-2, -5), 7 if big else 5, 3, GOLD)
			_px(ci, p + Vector2(-1, -8) if big else p + Vector2(-1, -6), 3, 2 if big else 1, Color.WHITE)
		var sm := clampf(u / 0.6, 0.0, 1.0)                                # the smoke, drifting up
		for d in (4 if big else 2):
			_px(ci, p + Vector2(-3 + d * 2 - sm * 3 * (d - 1), -4 - d * 2 - sm * 10.0), 2, 2, Color(0.85, 0.87, 0.92, 0.6 * (1.0 - sm)))

## The rockets in flight (over the frame), then the bursts, the smaller ones, the crackle.
func _fireworks(ci: CanvasItem, g: Dictionary) -> void:
	var u0 := age()
	if u0 > FW_LIFE + 0.05:
		return
	var fade := _fade() * (1.0 - clampf((u0 - 1.75) / 0.25, 0.0, 1.0))
	if fade <= 0.0:
		return
	var s := float(g.s)
	var team := [_team(c1), _team(c2)]
	var k2 := 2 if calm else 1
	# the smaller rockets and their bursts first: the big ones go over them
	for m in SHELL_AT.size():
		var u := u0 - float(SHELL_AT[m])
		if u < 0.0:
			continue
		var p: Vector2 = (g.far if m % 2 == 0 else g.near) + Vector2(0, -6)
		var top := _shell_apex(g, m)
		if u < SHELL_CLIMB:
			_rocket(ci, p, top, u / SHELL_CLIMB, u, false)
			continue
		var b := u - SHELL_CLIMB
		var col: Color = team[1] if m % 2 == 0 else team[0]
		_flash(ci, top, b, 0.08, 6, col)
		_shell(ci, top, b, SHELL_SPARKS / k2, 72.0 * s, SHELL_LIFE, col, GOLD, 90 + m * 7, 2, s, fade)
	for k in 2:
		var u := u0
		var p: Vector2 = (g.far if k == 0 else g.near) + Vector2(0, -6)
		var top := _apex(g, k)
		if u < rocket_burst(k):
			_rocket(ci, p, top, u / rocket_burst(k), u, true)
			continue
		var b := u - rocket_burst(k)
		if b > BURST_LIFE + 0.5:
			continue
		var main: Color = team[k]
		var other: Color = team[1 - k]
		_flash(ci, top, b, 0.13, 13, main)
		_shell(ci, top, b, SPARKS_N / k2, 128.0 * s, BURST_LIFE, main, Color.WHITE, k * 13 + 5, 3, s, fade)
		_shell(ci, top, b - 0.03, SPARKS_N / k2, 86.0 * s, BURST_LIFE * 0.9, other, GOLD, k * 13 + 30, 2, s, fade)
		_shell(ci, top, b - 0.02, CORE_N / k2, 44.0 * s, BURST_LIFE * 0.7, [Color.WHITE, GOLD, Color("fff3a0")][k], Color.WHITE, k * 13 + 55, 2, s, fade)
		_glitter(ci, top, b, k, main, s, fade)
	# the crackle: little gold pops scattered around it all, late
	for m in CRACKLE_AT.size():
		var b := u0 - float(CRACKLE_AT[m])
		if b < 0.0 or b > 0.45:
			continue
		var d: Vector2 = CRACKLE_AIM[m]
		var at := _apex(g, m % 2) + Vector2(d.x * float(g.out), d.y) * s
		_flash(ci, at, b, 0.05, 3, GOLD)
		_shell(ci, at, b, CRACKLE_SPARKS / k2, 40.0 * s, 0.4, [GOLD, Color.WHITE][m % 2], team[m % 2], 140 + m * 5, 1, s, fade)

## A rocket climbing from `p` to `top` (`e` 0..1 of the way): a bright head, a sputtering trail.
func _rocket(ci: CanvasItem, p: Vector2, top: Vector2, e0: float, u: float, big: bool) -> void:
	var e := 1.0 - pow(1.0 - clampf(e0, 0.0, 1.0), 2.0)
	var q := p.lerp(top, e)
	q.x += sin(u * 40.0) * (0.0 if calm else 0.6)
	if big:
		_px(ci, q + Vector2(-1, -2), 3, 4, Color.WHITE)
		_px(ci, q + Vector2(-2, 0), 5, 1, GOLD)
	else:
		_px(ci, q + Vector2(0, -1), 1, 3, Color.WHITE)
		_px(ci, q + Vector2(-1, 0), 3, 1, GOLD)
	var n := 9 if big else 5
	for j in n:
		var tq := p.lerp(top, maxf(0.0, e - 0.05 * (j + 1)))
		if (int(u * 30.0) + j) % 2 == 0 or calm:
			var w := 2 if big and j < 3 else 1
			_px(ci, tq + Vector2(sin(j * 2.3) * (1.0 + j * 0.3), 0), w, w, Color(GOLD if j % 3 else Color.WHITE, 0.95 - j * (0.8 / n)))

## The white flash at a burst's heart, `b` s in: a pixel disc swelling to `r`, rays, a coloured halo.
func _flash(ci: CanvasItem, at: Vector2, b: float, life: float, r: int, col: Color) -> void:
	if b < 0.0 or b > life:
		return
	var e := b / life
	var rr := maxi(2, roundi(float(r) * (0.35 + 0.65 * e)))
	var a := 1.0 - e * e
	var dr := maxi(1, rr / 2)
	for dy in range(-dr, dr + 1):
		var hw := roundi(dr * sqrt(maxf(0.0, 1.0 - float(dy * dy) / float(dr * dr))))
		_px(ci, at + Vector2(-hw, dy), 2 * hw + 1, 1, Color(1, 1, 1, 0.95 * a))
	_px(ci, at - Vector2(rr * 2, 0), rr * 4 + 1, 1, Color(1, 1, 1, 0.8 * a))
	_px(ci, at - Vector2(0, rr * 2), 1, rr * 4 + 1, Color(1, 1, 1, 0.8 * a))
	for i in 12:
		var t := TAU * i / 12.0
		_px(ci, at + Vector2(cos(t), sin(t) * 0.88) * float(rr + 2), 2, 2, Color(col, 0.85 * a))

## A shell of `n` sparks thrown out round from `at`, `b` s after it burst: slowing, dropping, gone
## by `life` (some sooner); `big` px while fresh, with short tails, shimmering as they die. Every
## sixth spark `alt` (the highlights).
func _shell(ci: CanvasItem, at: Vector2, b: float, n: int, speed: float, life: float, col: Color, alt: Color, seed: int, big: int, s: float, fade: float) -> void:
	if b < 0.0 or b > life:
		return
	for i in n:
		if _n(i, seed) > fade:
			continue
		var end := life * (0.7 + 0.3 * _n(i, seed + 1))
		if b > end:
			continue
		var left := 1.0 - b / end
		if not calm and left < 0.4 and (int(b * 18.0) + i) % 3 == 0:
			continue                                                        # (the shimmer)
		var ang := TAU * (float(i) + 0.4 * _n(i, seed + 2)) / float(n) + float(seed) * 0.37
		var v := Vector2(cos(ang), sin(ang) * 0.88) * speed * (0.85 + 0.3 * _n(i, seed + 3))
		var c: Color = alt if i % 6 == 0 else col
		if left < 0.25:
			c = c.lightened(0.4)                                            # (burning out bright)
		var sz := big if b < 0.22 else (mini(big, 2) if b < 0.6 else 1)
		if b < 0.55 and big > 1:                                            # the tail behind it
			for t in 3:
				var tq := at + _drag(v, maxf(0.0, b - 0.035 * (t + 1)), FW_K, 30.0 * s)
				_px(ci, tq, 1, 1, Color(c, 0.7 - 0.2 * t))
		var q := at + _drag(v, b, FW_K, 30.0 * s)
		_px(ci, q - Vector2(sz >> 1, sz >> 1), sz, sz, c)

## The glitter: sparks scattered further out round big burst `k`, lingering, twinkling as they
## drift down, a little cross on some.
func _glitter(ci: CanvasItem, top: Vector2, b: float, k: int, main: Color, s: float, fade: float) -> void:
	var tn := TWINKLE_N / (2 if calm else 1)
	for i in tn:
		var w := b - 0.18 - 0.25 * _n(i, k + 71)
		if w < 0.0 or w > BURST_LIFE * (0.75 + 0.2 * _n(i, k + 74)) or _n(i, k + 77) > fade:
			continue
		var a := TAU * _n(i, k + 72)
		var r := (40.0 + 52.0 * _n(i, k + 73)) * s * (0.85 + 0.15 * minf(1.0, w * 3.0))
		var q := top + Vector2(cos(a), sin(a) * 0.82) * r + Vector2(0, 16.0 * w * s)
		if not calm and (int(w * 14.0) + i) % 3 == 0:
			continue                                                        # (the twinkle)
		var col: Color = [GOLD, Color.WHITE, main, Color("fff3a0")][i % 4]
		_px(ci, q, 1, 1, col)
		if i % 3 == 0 and w < 0.7:
			_px(ci, q + Vector2(-1, 0), 3, 1, Color(col, 0.55))
			_px(ci, q + Vector2(0, -1), 1, 3, Color(col, 0.55))
