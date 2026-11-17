class_name AimGuide
## The slingshot: a pull, the reticle the other way from the ball carrier, release to shoot. Aim
## past the goal line; the pull length is power. Only the ShotStick pulls it (stick_at): a finger
## pulling back on the water is no shot, and nothing's drawn for it (draw).
## Passing is a tap: on a teammate, the ball goes to him wherever he is (tap_mate); anywhere else
## in the pool, to that spot (see is_tap). A pull never passes, a tap never shoots.

const M_PER_PX := 0.1        # metres of aim per pixel of pull, the same both ways
const FULL_PULL := 70.0      # pixels of pull for full power on a pass
const SHOT_BASE := 0.4       # a shot that just reaches the goal...
const SHOT_EXTRA := 4.0      # ...and this many metres of extra pull is a full-power one
const MIN_PULL := 10.0       # shorter than this and the release cancels
const TAP_SLOP := MIN_PULL   # a touch that moves less than this is a tap, more is a pull
const MARK_TIME := 0.35      # seconds the tapped pass spot stays marked
const TAP_MATE_PX := 14.0    # a tap this close (screen px) to a teammate's body is a pass to him

const DOT_GAP := 9.0         # screen px between guide dots
const END_GAP := 12.0        # dots stop this far short of the target so they don't cover it
const DRIFT := 1.4           # how fast the dots crawl towards the target (gaps per second)
const POWER_W := 31.0        # power bar width, px
const POWER_CELLS := 6

var active := false
var index := -1
var start := Vector2.ZERO
var now := Vector2.ZERO
var mark := Vector2.ZERO     # where the last tap passed to (pool metres)...
var mark_t := -99.0          # ...and when (the screen's clock)
var stick := false           # the pull is the ShotStick's (stick_at), not a finger on the water...
var stick_live := false      # ...and its knob is out of the dead zone: any pull is then a shot's

func begin(i: int, p: Vector2, from_stick := false) -> void:
	active = true
	index = i
	start = p
	now = p
	stick = from_stick
	stick_live = false

func cancel() -> void:
	active = false
	index = -1
	stick = false
	stick_live = false

## The ShotStick's aim: pull so the throw goes at `world` (ShotStick.target), or no pull (null,
## the stick's dead zone). Every frame, from wherever the shooter is now.
func stick_at(holder: Swimmer, world: Variant) -> void:
	stick_live = world != null
	now = start + (pull_for(holder, world) if stick_live else Vector2.ZERO)

func pull() -> Vector2:
	return now - start

## For a shot, power is how far you pull past the goal, not how far away the goal is:
## a point shot and a 2 m tip-in both start soft and get harder the further you pull.
func power(holder: Swimmer = null) -> float:
	if holder != null:
		var d := target(holder) - holder.pos
		if d.x > 0.3 and holder.pos.x + d.x >= Play.SHOT_ZONE_X:
			var reach := d.length() * (Play.SHOT_ZONE_X - holder.pos.x) / d.x
			return clampf(SHOT_BASE + (1.0 - SHOT_BASE) * (d.length() - maxf(reach, 0.0)) / SHOT_EXTRA, 0.25, 1.0)
	return clampf(pull().length() / FULL_PULL, 0.25, 1.0)

func long_enough() -> bool:
	return stick_live if stick else pull().length() >= MIN_PULL

## The finger barely moved: a tap (pass), never a shot. The stick never passes.
func is_tap() -> bool:
	return not stick and pull().length() < TAP_SLOP

## The pool spot a tap at screen point `pos` means, or null: the scoreboard strip and the deck
## around the water aren't passes.
static func tap_spot(v: PoolView, pos: Vector2) -> Variant:
	if pos.y < PoolView.HUD_H:
		return null
	var w := v.to_world(pos)
	return w if Geo.in_pool(w) else null

## The teammate a tap at screen point `pos` is on, or null: the nearest one whose body (the
## head and shoulders, drawn above his spot on the water) is within TAP_MATE_PX of it. Any man in
## the attack, however far across the pool, and never the man with the ball.
static func tap_mate(v: PoolView, p: Play, pos: Vector2) -> Swimmer:
	if pos.y < PoolView.HUD_H:
		return null
	var best: Swimmer = null
	var bd := TAP_MATE_PX
	for a in p.attackers:
		if a == p.holder or a.out:
			continue
		var dd := v.unzoom(pos).distance_to(v.to_screen(a.pos) + Vector2(0, -5)) * v.cine.get_scale().x   # (in screen px, pushed in or not)
		if dd < bd:
			bd = dd
			best = a
	return best

## A tap passed to `world` at time `now_t`: mark the spot for a moment.
func show_mark(world: Vector2, now_t: float) -> void:
	mark = world
	mark_t = now_t

## Where the throw goes, in pool metres: the other way from the pull.
func target(holder: Swimmer) -> Vector2:
	return holder.pos - pull() * M_PER_PX

## The pull (screen px from the touch-down point) that aims at `world`: tests and the tour.
static func pull_for(holder: Swimmer, world: Vector2) -> Vector2:
	return (holder.pos - world) / M_PER_PX

func draw(ci: CanvasItem, v: PoolView, play: Play, t: float) -> void:
	if t - mark_t >= 0.0 and t - mark_t < MARK_TIME:
		# the tapped pass spot: one small dot on the water, gone in a blink
		PoolArt.draw_dot(ci, v.to_screen(mark).round(), Color(UI.TEXT, 0.85), 1)
	if not active or not stick or not play.can_throw() or not long_enough():
		return
	var h := play.holder
	var info := play.aim_info(target(h))
	match String(info.mode):
		"shot", "no_shot":
			var col := UI.GOLD if info.mode == "shot" else Hud.DIM
			var goal_pt := v.to_screen(info.point, 0.45)
			var from := v.to_screen(h.pos, 0.9)
			var stop := play.sure_block(float(info.cross_y), power(h)) if info.mode == "shot" else {}
			# the dots say how hard: white soft, yellow mid, red-orange full (the reticle stays gold)
			var dot_col := power_color(power_t(h)) if info.mode == "shot" else col
			if not stop.is_empty():
				# into a certain block (any field defender: Play.sure_block): the line stops there, a
				# red X where it's blocked (every time). A block that only might happen: no X
				var at := v.to_screen(stop.at, 0.9)
				_dots_along(ci, [from, at] as Array[Vector2], dot_col, t, END_GAP * 0.5)
				blocked_x(ci, at.round())
			else:
				_dots_along(ci, [from, goal_pt] as Array[Vector2], dot_col, t)
				_reticle(ci, goal_pt, col)
			if info.mode == "no_shot":
				UI.text_shadow(ci, from + Vector2(-34, -20), "FREE THROW: PASS FIRST", 8, UI.WARN, "body")
			else:
				# under the swimmer's waterline, clear of the body
				_power_bar(ci, v.to_screen(h.pos) + Vector2(-POWER_W / 2.0, 9), power(h), t)

## The pull-back strength, 0 (a shot that just reaches the goal) .. 1 (full power): power()'s
## shot range, SHOT_BASE..1, as a share. For the dots' colour only; power() is what's thrown.
func power_t(holder: Swimmer = null) -> float:
	return clampf((power(holder) - SHOT_BASE) / (1.0 - SHOT_BASE), 0.0, 1.0)

## The guide dots' colour for pull-back strength `k` (power_t), in three flat steps so it reads at
## a glance and never shimmers between shades: white (soft), yellow (mid), red-orange (full).
const DOT_SOFT := Color("f4f4ee")
const DOT_MID := Color("ffd84a")
const DOT_FULL := Color("ff4f1a")
const DOT_STEPS := [1.0 / 3.0, 2.0 / 3.0]

static func power_color(k: float) -> Color:
	if k < DOT_STEPS[0]:
		return DOT_SOFT
	if k < DOT_STEPS[1]:
		return DOT_MID
	return DOT_FULL

## Guide dots at an even screen spacing along a polyline, crawling towards its end.
func _dots_along(ci: CanvasItem, pts: Array[Vector2], col: Color, t: float, end_gap := END_GAP) -> void:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	var d := DOT_GAP + fposmod(t * DRIFT, 1.0) * DOT_GAP
	var seg := 1
	var seg_start := 0.0
	while d < total - end_gap and seg < pts.size():
		var seg_len := pts[seg - 1].distance_to(pts[seg])
		if d > seg_start + seg_len:
			seg_start += seg_len
			seg += 1
			continue
		var k := (d - seg_start) / maxf(seg_len, 0.001)
		PoolArt.draw_dot(ci, pts[seg - 1].lerp(pts[seg], k).round(), col, 1)
		d += DOT_GAP

## The guaranteed block: a tiny bright red X (a guide dot's size and a bit) on a dark rim, at `c`.
const X_RED := Color("ff2a2a")
const X_PIXELS := [Vector2i(-2, -2), Vector2i(-1, -1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2),
	Vector2i(2, -2), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-2, 2)]

static func blocked_x(ci: CanvasItem, c: Vector2) -> void:
	for q: Vector2i in X_PIXELS:
		ci.draw_rect(Rect2(c.x + q.x - 1, c.y + q.y - 1, 3, 3), PoolArt.INK)
	for q: Vector2i in X_PIXELS:
		ci.draw_rect(Rect2(c.x + q.x, c.y + q.y, 1, 1), X_RED)

## A bold target circle with a centre pip, on the goal mouth.
func _reticle(ci: CanvasItem, p: Vector2, col: Color) -> void:
	PoolArt.draw_ellipse_ring(ci, p.round(), 7, 7, col, 2)
	PoolArt.draw_dot(ci, p.round(), col, 0)

## Segmented so power reads at a glance: green, then gold, then flashing red at full pull.
func _power_bar(ci: CanvasItem, p: Vector2, pw: float, t: float) -> void:
	var col := UI.GOOD
	if pw > 0.85:
		col = UI.BAD if int(t * 10.0) % 2 == 0 else UI.WARN
	elif pw > 0.6:
		col = UI.GOLD
	var cell := floorf((POWER_W - 1.0) / POWER_CELLS)
	ci.draw_rect(Rect2(p - Vector2(1, 1), Vector2(cell * POWER_CELLS + 3, 7)), PoolArt.INK)
	var lit := roundi(pw * POWER_CELLS)
	for i in range(POWER_CELLS):
		var x := p.x + 1 + i * cell
		ci.draw_rect(Rect2(x, p.y, cell - 1, 5), col if i < lit else Color(1, 1, 1, 0.16))
		if i < lit:
			ci.draw_rect(Rect2(x, p.y, cell - 1, 1), col.lightened(0.4))
