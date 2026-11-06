class_name BarHit
extends RefCounted
## BAR-IN! / BAR-DOWN!: now and then a goal that went in tight to the frame is shown clanging in
## off the inside of a post (BAR-IN!) or off the underside of the bar (BAR-DOWN!). Presentation
## only: the goal was already given by ShotModel before any of this is looked at, and nothing
## here touches the play's dice (it rolls its own, seeded from the shot).
##   pick()        at the release of a shot ShotModel has made a goal: is it one, and which
##                 surface? Off the shot's real placement (cross_y, height), never at random text
##   APPROACH      the last NUDGE_TIME of the flight bends it the last few cm onto the frame
##                 (Ball.look: the drawing only)
##   IMPACT        on the line: CLANG! / BANG!, the burst on the contact point, a shake
##   HIT_STOP      FREEZE_FRAMES rendered frames with the play stopped (play_scale 0): the ball
##                 on the frame, the keeper frozen; the word already bursting in
##   RICOCHET      the ball rockets off the frame across the inside of the goal (path)
##   NET_IMPACT    ...into the far side of the net, which snaps back and shivers (Ball's "net")
##   COMPLETE      the word's gone; GoalShow (started PRE late) carries on as for any goal

enum Kind { NONE, LEFT_POST, RIGHT_POST, CROSSBAR }
## Developer Mode (Settings > Developer Mode > SPECIAL GOAL EFFECTS): this session's override of the
## pick's die. NORMAL: as always; ALWAYS: every goal tight enough to the frame for one (pick's
## chance above 0) is shown off it; NEVER: none are. Never saved, and the match screen only reads
## it with Developer Mode on (Play.bar_mode); turning Developer Mode off puts it back to NORMAL.
enum Override { NORMAL, ALWAYS, NEVER }
const OVERRIDE_NAMES := ["NORMAL", "ALWAYS", "NEVER"]
static var override: int = Override.NORMAL

## The override a match plays with: Developer Mode's, only while it's on.
static func mode_for(dev_on: bool) -> int:
	return override if dev_on else Override.NORMAL

## Developer Mode's tests: where a goal crosses the line for each ("left", "right", "bar", "ul", "ur")
## and where it's shot from: {cross_y, height, from, kind (what pick() makes of it)}. A corner goes
## in tight to both the post and the bar at once, so the shot's line decides it (surface: TIE), and
## `corner_bar` picks which: from out wide on that side (coming back across the goal) it's the bar,
## from straight on the post.
const DEMO_GAP := 0.02           # m off the frame
const DEMO_FROM := Vector2(24.6, 10.0)
static func demo(test: String, corner_bar: bool = false) -> Dictionary:
	var left := Geo.GOAL_Y - (Geo.GOAL_HALF - POST_EDGE - DEMO_GAP)
	var right := Geo.GOAL_Y + (Geo.GOAL_HALF - POST_EDGE - DEMO_GAP)
	var under := height_for(BAR_Z - DEMO_GAP)
	var from := DEMO_FROM
	var out := {}
	match test:
		"left":
			out = {"cross_y": left, "height": 0.45}
		"right":
			out = {"cross_y": right, "height": 0.45}
		"bar":
			out = {"cross_y": Geo.GOAL_Y - 0.6, "height": under}
		"ul", "ur":
			var cy := left if test == "ul" else right
			out = {"cross_y": cy, "height": under}
			if corner_bar:
				from = Vector2(DEMO_FROM.x, Geo.GOAL_Y + 3.0 * signf(cy - Geo.GOAL_Y))   # from out wide on that side
		_:
			return {}
	out["from"] = from
	out["kind"] = int(surface(float(out.cross_y), line_z(float(out.height)), from).kind)
	return out

## The `height` (ShotModel's 0..1) that crosses the line at `z` m (line_z backwards).
static func height_for(z: float) -> float:
	return clampf(inverse_lerp(KeeperDuel.LINE_Z.x, KeeperDuel.LINE_Z.y, z), 0.0, 1.0)
enum Phase { NONE, APPROACH, IMPACT, HIT_STOP, RICOCHET, NET_IMPACT, COMPLETE }

# ------------------------------------------------------------------ placement
## Distances are pool metres from the ball's centre to the frame, the way ShotModel judges a
## post (a centre within POST_EDGE inside the post line is still a goal) and the way the ball is
## drawn crossing the line (KeeperDuel.LINE_Z: its top, the bar, is BAR_Z).
const BAR_Z := 0.9               # the crossbar, m off the water (PoolArt.draw_goal, KeeperDuel.LINE_Z.y)
const POST_EDGE := 0.04          # ShotModel: "post" from 0.04 inside the line out
## The chance, by how close to the frame it went in: [distance, chance], straight lines between.
## Almost touching ~37 %, extremely close ~26 %, near ~11 %, an ordinary corner ~2 %, the middle
## (ORDINARY or more off every bit of frame) never. ~20 % of the goals within NEAR of it.
const CURVE := [[0.0, 0.40], [0.04, 0.34], [0.10, 0.17], [0.18, 0.05], [0.30, 0.0]]
const ALMOST := 0.04             # the bands, for tests and the report
const EXTREME := 0.10
const NEAR := 0.18               # a qualifying corner goal: this close to a post or the bar
const ORDINARY := 0.30
const TIE := 0.02                # post and bar this close to equally near: the shot's line decides
const CONTACT := 0.08            # contact: the ball's centre this far inside the post line...
const CONTACT_Z := 0.1           # ...or under the bar
const NUDGE_MAX := 0.18          # the most the flight is bent to touch the frame; more: a plain goal
const NUDGE_TIME := 0.14         # s before the line the bend starts

# ------------------------------------------------------------------ the ricochet
const RICOCHET := 0.22           # s, post: off the post, across the goal into the far side netting
const DROP := 0.07               # s, bar: straight down off the bar...
const ACROSS := 0.17             # s, ...then on across the goal
const LINE_IN := 0.02            # m behind the line where it meets the frame

# ------------------------------------------------------------------ the show
const FREEZE_FRAMES := 3         # the hit-stop, in rendered frames (the contact frame and two more)
const PRE := 0.35                # s GoalShow is held back (GOAL! comes PRE + GoalShow.IMPACT_AT in)
const SHAKE := 1.0               # the jolt (PoolView.shake: gone in ~0.12 s)
const BURST := 0.28              # s the burst on the frame lasts
const EXPAND := 0.11             # the word: compressed to over size...
const SETTLE := 0.17             # ...back to size
const WOBBLE := [0.17, 0.25]     # ...one shake...
const OUT_AT := 0.40             # ...held over the ricochet, then shrinks away...
const OUT := 0.18                # ...in this long
const WORD := 34                 # px font size at full size
const YELLOW := Color("ffd83d")
const ORANGE := Color("ff8a1f")
const RED := Color("e8382c")
const INK := Color("0a0a12")

## The selection: what the presentation of a shot ShotModel made a goal is. `shot`: its result
## (cross_y, height), `from`: where it left his hand. `roll` < 0: its own die (seeded from the
## shot, never the play's rng); 0..1: that roll (tests). Never changes `shot`.
## {on, kind, text, d, chance, at (Vector3 contact), nudge (Vector2: dy, dz), dir (+-1 across)}
static func pick(shot: Dictionary, from: Vector2, roll: float = -1.0) -> Dictionary:
	var out := {"on": false, "kind": Kind.NONE, "text": "", "d": INF, "chance": 0.0}
	if String(shot.get("outcome", "")) != "goal" or not shot.has("cross_y"):
		return out
	var cy := float(shot.cross_y)
	var z := line_z(float(shot.get("height", 0.5)))
	var s := surface(cy, z, from)
	var d := float(s.d)
	var p := chance(d)
	out.d = d
	out.chance = p
	out.kind = int(s.kind)
	if p <= 0.0:
		return out
	if roll < 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([snappedf(cy, 0.0001), snappedf(z, 0.0001), snappedf(from.x, 0.001), snappedf(from.y, 0.001)])
		roll = rng.randf()
	if roll >= p:
		return out
	# the contact: on the frame where it went in, a few cm moved at most
	var at := Vector3(Geo.GOAL_X + LINE_IN, cy, z)
	var side := signf(cy - Geo.GOAL_Y) if cy != Geo.GOAL_Y else signf(cy - from.y)
	if side == 0.0:
		side = 1.0
	var dir := -side   # across, away from the near post
	if int(s.kind) == Kind.CROSSBAR:
		at.z = BAR_Z - CONTACT_Z
		at.y = clampf(cy, Geo.GOAL_Y - Geo.GOAL_HALF + CONTACT, Geo.GOAL_Y + Geo.GOAL_HALF - CONTACT)
	else:
		at.y = Geo.GOAL_Y + side * (Geo.GOAL_HALF - CONTACT)
		at.z = minf(z, BAR_Z - CONTACT_Z)
	var nudge := Vector2(at.y - cy, at.z - z)
	if absf(nudge.x) > NUDGE_MAX or absf(nudge.y) > NUDGE_MAX:
		return out   # too far off the frame to look like it hit it: a plain goal
	out.on = true
	out.text = "BAR-DOWN!" if int(s.kind) == Kind.CROSSBAR else "BAR-IN!"
	out.at = at
	out.nudge = nudge
	out.dir = dir
	return out

## The ball's height crossing the line for ShotModel's `height` (as Play.shot_z draws it).
static func line_z(height: float) -> float:
	return lerpf(KeeperDuel.LINE_Z.x, KeeperDuel.LINE_Z.y, clampf(height, 0.0, 1.0))

## The nearest frame surface to a ball crossing at (cy, z): {kind, d}. Posts by side (LEFT_POST:
## the post at low y, on a shooter's left attacking +x); the bar by height. Near enough the same:
## the post it was travelling towards, else the bar.
static func surface(cy: float, z: float, from: Vector2) -> Dictionary:
	var gap := Geo.GOAL_HALF - absf(cy - Geo.GOAL_Y)
	var d_post := maxf(0.0, gap - POST_EDGE)
	var d_bar := maxf(0.0, BAR_Z - z)
	var post := Kind.LEFT_POST if cy < Geo.GOAL_Y else Kind.RIGHT_POST
	if absf(d_post - d_bar) <= TIE:
		var towards := signf(cy - from.y) == signf(cy - Geo.GOAL_Y)
		return {"kind": post if towards else Kind.CROSSBAR, "d": minf(d_post, d_bar)}
	if d_post < d_bar:
		return {"kind": post, "d": d_post}
	return {"kind": Kind.CROSSBAR, "d": d_bar}

## The chance at `d` m off the frame (CURVE).
static func chance(d: float) -> float:
	if d <= 0.0:
		return float(CURVE[0][1])
	for i in CURVE.size() - 1:
		var a: Array = CURVE[i]
		var b: Array = CURVE[i + 1]
		if d <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (d - float(a[0])) / (float(b[0]) - float(a[0])))
	return 0.0

## How much of the bend (nudge) a ball in flight has on, 0..1: none until NUDGE_TIME from the line.
static func bend(b: Ball) -> float:
	var vx := (b.to.x - b.from.x) / maxf(b.dur, 0.001)
	if vx <= 0.0:
		return 1.0
	var left := (Geo.GOAL_X - b.pos.x) / vx
	return 1.0 - smoothstep(0.0, NUDGE_TIME, left)

## The ricochet's length, s.
static func ricochet_time(bar: Dictionary) -> float:
	return DROP + ACROSS if int(bar.kind) == Kind.CROSSBAR else RICOCHET

## Where the ball is `s` seconds into the ricochet (x, y, z): from the contact across the inside
## of the goal to the far side of the back of the net (`back`: Ball.net_back_x), fast off the frame
## and easing in to the net. Off a post: straight across. Off the bar: down hard first, then across.
static func path(bar: Dictionary, s: float, back: float) -> Vector3:
	var at: Vector3 = bar.at
	var dir := float(bar.dir)
	var lo := Geo.GOAL_Y - Geo.GOAL_HALF + Ball.NET_POST_PAD
	var hi := Geo.GOAL_Y + Geo.GOAL_HALF - Ball.NET_POST_PAD
	if s <= 0.0:
		return at
	if int(bar.kind) != Kind.CROSSBAR:
		var to := Vector3(back, hi if dir > 0.0 else lo, 0.35)
		var u := clampf(s / RICOCHET, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - u, 2.4)
		var q := at.lerp(to, e)
		q.z += 0.12 * sin(PI * e)   # a touch of lift off the post
		return q
	var low := Vector3(lerpf(at.x, back, 0.35), clampf(at.y + dir * 0.25, lo, hi), 0.08)
	if s < DROP:
		var u0 := s / DROP
		return at.lerp(low, u0 * u0 * 0.4 + u0 * 0.6)   # straight down off the bar, still speeding up
	var to2 := Vector3(back, clampf(at.y + dir * 1.7, lo, hi), 0.3)
	var u1 := clampf((s - DROP) / ACROSS, 0.0, 1.0)
	return low.lerp(to2, 1.0 - pow(1.0 - u1, 2.2))

# ------------------------------------------------------------------ the show, on the match screen
var phase: int = Phase.NONE
var t := 0.0                     # real seconds since the contact
var freeze := 0                  # rendered frames of hit-stop left
var ball: Ball = null            # the goal's ball (its bar, its ricochet clock)
var kind: int = Kind.NONE
var text := ""

## The ball's on the frame (Play's goal, its ball carrying a bar from pick): the clang, the jolt,
## the hit-stop. `view`: the camera, for the shake.
func start(b: Ball, view: PoolView = null) -> void:
	clear()
	if b == null or not bool(b.bar.get("on", false)):
		return
	ball = b
	kind = int(b.bar.kind)
	text = String(b.bar.text)
	t = 0.0
	freeze = FREEZE_FRAMES
	phase = Phase.IMPACT
	if kind == Kind.CROSSBAR:
		Sfx.play("bang", 1.0, -1.0)
	else:
		Sfx.play("clang", 1.0, -2.0)
	Game.vibrate(35)
	if view != null:
		view.shake = maxf(view.shake, SHAKE)

func clear() -> void:
	phase = Phase.NONE
	t = 0.0
	freeze = 0
	ball = null
	kind = Kind.NONE
	text = ""

func active() -> bool:
	return phase != Phase.NONE and phase != Phase.COMPLETE

## The play's speed: stopped for the hit-stop.
func play_scale() -> float:
	return 0.0 if freeze > 0 else 1.0

## One rendered frame, `dt` real seconds.
func step(dt: float) -> void:
	if not active():
		return
	if freeze > 0:
		freeze -= 1
		phase = Phase.HIT_STOP
	t += dt
	if freeze > 0:
		return
	var r := ricochet_time(ball.bar)
	if ball.bar_t < r:
		phase = Phase.RICOCHET
	elif t < OUT_AT + OUT:
		phase = Phase.NET_IMPACT
	else:
		phase = Phase.COMPLETE
		ball = null

## The word's size, 0..: compressed, bursting past full size, back, then shrinking away.
static func pop(s: float) -> float:
	if s < EXPAND:
		return lerpf(0.55, 1.3, 1.0 - pow(1.0 - s / EXPAND, 2.0))
	if s < SETTLE:
		return lerpf(1.3, 1.0, (s - EXPAND) / (SETTLE - EXPAND))
	if s < OUT_AT:
		return 1.0
	return lerpf(1.0, 0.3, clampf((s - OUT_AT) / OUT, 0.0, 1.0))

static func shake_x(s: float) -> float:
	if s < WOBBLE[0] or s >= WOBBLE[1]:
		return 0.0
	return [3.0, -3.0, 2.0, -1.0][clampi(int((s - WOBBLE[0]) / 0.02), 0, 3)]

## In the pool, over the ball: the burst on the contact point, the speed trail, the splash under
## the bar. Everything is worked out from the clocks: nothing is kept between frames.
func draw_world(ci: CanvasItem, v: PoolView) -> void:
	if not active() or ball == null:
		return
	var at: Vector3 = ball.bar.at
	var c := v.to_screen(Vector2(at.x, at.y), at.z)
	var away := v.to_screen(Vector2(at.x, at.y + float(ball.bar.dir)), at.z) - c
	if kind == Kind.CROSSBAR:
		away = Vector2(away.normalized().x * 0.5, 1.0)
	away = away.normalized() if away.length() > 0.01 else Vector2.DOWN
	# the speed trail behind the ball as it rockets across
	var r := ricochet_time(ball.bar)
	if ball.bar_t > 0.0 and ball.bar_t < r + 0.04:
		var back := ball.net_back_x()
		for k in range(1, 4):
			var q := path(ball.bar, ball.bar_t - 0.02 * k, back)
			var p := v.to_screen(Vector2(q.x, q.y), q.z)
			var a := (0.6 - 0.16 * k) * (1.0 - clampf((ball.bar_t - r) / 0.04, 0.0, 1.0))
			ci.draw_rect(Rect2(p.x - 1, p.y - 1, 3, 2), Color(1, 0.96, 0.75, a))
	# off the bar: the slap on the water where it comes down
	if kind == Kind.CROSSBAR and ball.bar_t >= DROP and ball.bar_t < DROP + 0.25:
		var low := path(ball.bar, DROP, ball.net_back_x())
		GoalShow._splash(ci, v.to_screen(Vector2(low.x, low.y)), (ball.bar_t - DROP) / 0.25)
	if t >= BURST:
		return
	_burst(ci, c.round(), away, t)

## The comic-book burst at `c` (screen px), `s` seconds in: a white-hot centre, a yellow flash,
## sharp spikes going yellow to orange to red at the tips, a little shockwave thrown the way the
## ball goes (`away`), and a few fragments falling away.
static func _burst(ci: CanvasItem, c: Vector2, away: Vector2, s: float) -> void:
	var u := s / BURST
	var grow := 1.0 - pow(1.0 - clampf(s / 0.06, 0.0, 1.0), 2.0)
	var shrink := 1.0 - clampf((s - 0.12) / 0.12, 0.0, 1.0)
	if s < 0.08:
		var f := 1.0 - s / 0.08
		ci.draw_rect(Rect2(c.x - 6, c.y - 1, 13, 3), Color(YELLOW, f))
		ci.draw_rect(Rect2(c.x - 1, c.y - 6, 3, 13), Color(YELLOW, f))
	# spikes: eight ways, long and short in turn, stepped out in 2 px squares
	for i in 8:
		var ang := TAU * i / 8.0 + PI / 8.0
		var d := Vector2(cos(ang), sin(ang))
		var len := (18.0 if i % 2 == 0 else 11.0) * grow * shrink
		var k := 3.0
		while k <= len:
			var col := YELLOW if k < len * 0.45 else (ORANGE if k < len * 0.8 else RED)
			var q := (c + d * k).round()
			ci.draw_rect(Rect2(q.x - 1, q.y - 1, 2, 2), col)
			k += 2.0
	# the white-hot centre
	if s < 0.14:
		ci.draw_rect(Rect2(c.x - 2, c.y - 1, 5, 3), Color.WHITE)
		ci.draw_rect(Rect2(c.x - 1, c.y - 2, 3, 5), Color.WHITE)
	# the shockwave, an arc of pixels thrown the way the ball goes
	if s < 0.18:
		var rad := 6.0 + 90.0 * s
		var base := away.angle()
		for j in range(-4, 5):
			var q := (c + Vector2.from_angle(base + j * 0.22) * rad).round()
			ci.draw_rect(Rect2(q.x, q.y, 1, 1), Color(1, 1, 1, 0.9 * (1.0 - s / 0.18)))
	# fragments
	for j in 7:
		var ang := TAU * (j * 0.137 + 0.05) + away.angle() * 0.5
		var sp := 70.0 + 25.0 * (j % 3)
		var q := c + Vector2.from_angle(ang) * sp * s + Vector2(0, 260.0 * s * s)
		ci.draw_rect(Rect2(roundf(q.x), roundf(q.y), 2 if j % 3 == 0 else 1, 1),
			Color(ORANGE if j % 2 == 0 else YELLOW, 1.0 - u))

## Over the HUD: BAR-IN! / BAR-DOWN! bursting out above the goal, on the comic-book spikes.
func draw(ci: CanvasItem, size: Vector2, v: PoolView) -> void:
	if not active() or ball == null or t >= OUT_AT + OUT:
		return
	var sc := pop(t)
	var a := 1.0 - clampf((t - OUT_AT) / OUT, 0.0, 1.0)
	var fs := word_fs(text, sc, size.x - 24.0)
	var w := _width(text, fs)
	var cap := roundf(fs * 0.55)
	var at: Vector3 = ball.bar.at
	var top := v.to_screen(Vector2(at.x, Geo.GOAL_Y - Geo.GOAL_HALF), BAR_Z)
	var cx := clampf(v.to_screen(Vector2(at.x, at.y), at.z).x, w * 0.5 + 12.0, size.x - w * 0.5 - 12.0) + shake_x(t)
	var cy := clampf(top.y - cap - 18.0, PoolView.HUD_H + cap + 14.0, size.y - cap - 20.0)   # (its spikes clear of the bar)
	spikes(ci, Vector2(roundf(cx), roundf(cy)), w * 0.5 + 10.0, cap + 10.0, a)
	lettering(ci, Vector2(cx, cy), text, fs, a)

## The word itself, centred on `c` (also every top-of-screen callout's, Hud.callout): every
## letter on one flat baseline; `deep` and `mid` underneath, a thick black edge, `face` on top (in layers, so
## one letter's edge never covers the next one's face).
static func lettering(ci: CanvasItem, c: Vector2, text: String, fs: int, a: float,
		face: Color = YELLOW, mid: Color = ORANGE, deep: Color = RED) -> void:
	var w := _width(text, fs)
	var cap := roundf(fs * 0.55)
	var at_x: Array[Vector2] = []
	var x := roundf(c.x - w * 0.5)
	var n := text.length()
	for i in n:
		at_x.append(Vector2(x, roundf(c.y + cap * 0.5)))
		x += UI.text_width(text[i], fs, "big")
	var layers := [[[Vector2(3, 4)], deep], [[Vector2(2, 2)], mid],
		[[Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2), Vector2(-2, -2), Vector2(2, -2),
			Vector2(-2, 2), Vector2(2, 2)], INK], [[Vector2.ZERO], face]]
	for l: Array in layers:
		for i in n:
			for d: Vector2 in l[0]:
				UI.text(ci, at_x[i] + d, text[i], fs, Color(l[1], a), "big")

## The font size for `text` at pop scale `sc`, shrunk to fit `room` px across.
static func word_fs(text: String, sc: float, room: float) -> int:
	return maxi(8, int(floorf(minf(WORD * sc, WORD * room / maxf(1.0, _width(text, WORD))))))

static func _width(s: String, fs: int) -> float:
	var w := 0.0
	for ch in s:
		w += UI.text_width(ch, fs, "big")
	return w

## A jagged starburst behind the word: red, then orange inside it, points on whole pixels.
static func spikes(ci: CanvasItem, c: Vector2, rx: float, ry: float, a: float) -> void:
	for layer in 2:
		var k := 1.0 if layer == 0 else 0.78
		var pts := PackedVector2Array()
		for i in 18:
			var ang := TAU * i / 18.0
			var r := (1.0 if i % 2 == 0 else 0.72) * k
			pts.append((c + Vector2(cos(ang) * rx * r, sin(ang) * ry * r)).round())
		ci.draw_colored_polygon(pts, Color(RED if layer == 0 else ORANGE, 0.92 * a))
