class_name StarFx
extends Node
## The HOT star animations, one component for every star bar that shows form (the roster's
## cards, a player's page, the Developer Mode labs). Add one as a child of the Control that
## draws the bar and call draw() from its _draw instead of Deck.star_bar: it draws the same
## places (Deck.star_fills, Deck.star_place: up to POTENTIAL, gold for CURRENT, red after it for HOT, then
## POTENTIAL), and the places a form change alters are the ones that move, right where they are
## (no icons, nothing added to the row):
##   heat    a star turns red: a warm glow, it flashes yellow and orange as it grows, pops red,
##           bounces, a pixel sparkle and a few embers, then settles. 0.9 s
##   cool    a level of heat gone (VERY HOT to HOT, HOT to NORMAL): a pulse, the red star steps
##           back to empty, a white sparkle. 0.4 s
## Then, while HOT, a very faint idle on his last red star: a warm pulse and now and then one
## ember, a few seconds apart.
## All of it is whole pixels in a handful of flat colours, steps not gradients; a star grows by a
## 1 px rim, never scaled. Only drawing: form, stars and saves are
## never touched. Off with Settings > Reduce motion and in tests (Juice.enabled), unless `force`.

const HEAT_TIME := 0.9
const COOL_TIME := 0.4
## The form states in order, coolest first: HEAT UP and COOL DOWN move one along it.
const LADDER := PlayerForm.LEVELS

const WARM := Color("ff9a2a")
const FLASH := Color("fff3a0")
const EMBER_Y := Color("ffe14a")
const EMBER_R := Color("ff4a2a")
const SPARK := Color("ffffff")
const CLEAR := Color(0, 0, 0, 0)
## Rims: flat colours that read as a faint glow on the navy cards (no see-through pixels).
const RIM_WARM := Color("c0601f")
const RIM_GOLD := Color("c89a2a")
const RIM_FLASH := Color("ffe14a")
const RIM_POP := Color("e0602a")
const RIM_EMBER := Color("7a2418")
const RIM_WHITE := Color("9fb0d8")
const PLUS := [".#.", "#.#", ".#."]
const HOT_IDLE := 3.2          # seconds between a HOT star's idle pulses

## Stars already on show this session: key -> the form they were last shown in (watch()).
static var _seen := {}

var host: CanvasItem           # redrawn as the animation moves; the parent by default
var kind := ""                 # the transition playing: "heat", "cool", or ""
var t := 0.0                   # seconds into it
var speed := 1.0:
	set(v):
		speed = v
		if _tw != null and _tw.is_valid():
			_tw.set_speed_scale(v)
var particles := true          # the embers and sparks
var loop := false              # replay the transition over and over
var force := false             # play even with reduce motion on (Developer Mode)
var bare := false              # only the lit part of each star: no hollow outline past it (the Roster screen)
var from_state := PlayerForm.NORMAL
var to_state := PlayerForm.NORMAL
var _tw: Tween
var _pending := false
var _parts: Array = []
var _seed := 0
var _state := PlayerForm.NORMAL     # the form draw() was last asked for
var _shape: Dictionary = Deck.STAR_SHAPE   # the star draw() was last asked for (Deck.STAR_SHAPE)
var _idle_key := ""
var _clock := 0.0

func _ready() -> void:
	if host == null:
		host = get_parent() as CanvasItem
	_clock = float(_seed % 997) * 0.37   # cards don't pulse in step
	if _pending:
		_pending = false
		_start()

static func motion_on() -> bool:
	return Juice.enabled()

## The transition from one form to another: hotter plays "heat", cooler "cool".
static func kind_of(from: String, to: String) -> String:
	if from == to:
		return ""
	return "heat" if PlayerForm.level_of(to) > PlayerForm.level_of(from) else "cool"

static func duration(k: String) -> float:
	return {"heat": HEAT_TIME, "cool": COOL_TIME}.get(k, 0.0)

## One step along LADDER (+1 hotter, -1 cooler), stopping at the ends.
static func step(state: String, by: int) -> String:
	return LADDER[clampi(LADDER.find(state) + by, 0, LADDER.size() - 1)]

## What watch() knows a player by.
static func key_of(p: PoloPlayer) -> String:
	return "%d %s %s" % [p.id, p.first, p.last]

## Shows `state` for `key` (a player): if it was last shown in another form this session (or,
## the first time, `was` - his form before his last game - differs), that change plays once.
## Redrawing or rebuilding a screen never replays it.
func watch(key: String, state: String, was: String = "") -> void:
	_seed = absi(hash(key))
	var before: String = _seen.get(key, was if was != "" else state)
	_seen[key] = state
	if before != state:
		play(before, state)

## Plays the change from `from` to `to`. A new one replaces whatever is playing (it starts from
## where the last one was going), so rapid changes never stack up.
func play(from: String, to: String, force_it: bool = false) -> void:
	if force_it:
		force = true
	if from == to:
		return
	from_state = from
	to_state = to
	kind = kind_of(from, to)
	_start()

## The last transition again (form unchanged).
func replay() -> void:
	if from_state != to_state:
		kind = kind_of(from_state, to_state)
		_start()

## The change from `from` to `to` held at `time` seconds in, on the caller's own clock (no tween:
## the postgame HOT star reveal steps it itself). Returns the form to draw() with: `from` before
## it starts, `to` once it has (and settled after it ends).
func pose(from: String, to: String, time: float) -> String:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null
	var k := kind_of(from, to)
	if k == "" or time < 0.0 or time >= duration(k):
		kind = ""
		return from if time < 0.0 else to
	if kind != k or from_state != from or to_state != to:
		_parts = make_particles(k, _seed) if particles else []
	from_state = from
	to_state = to
	kind = k
	t = time
	return to

func playing() -> bool:
	return kind != ""

func _start() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null
	if not (force or motion_on()):
		kind = ""
		_redraw()
		return
	if not is_inside_tree():
		_pending = true
		return
	t = 0.0
	_parts = make_particles(kind, _seed) if particles else []
	var d := duration(kind)
	_tw = create_tween()
	_tw.set_speed_scale(speed)
	_tw.tween_method(_set_t, 0.0, d, d)
	_tw.finished.connect(_done)
	_redraw()

func _set_t(v: float) -> void:
	t = v
	_redraw()

func _done() -> void:
	_tw = null
	if loop and kind != "":
		_start()
		return
	kind = ""
	_redraw()

func _redraw() -> void:
	if host != null and is_instance_valid(host):
		host.queue_redraw()

## The idle pulses: only redraw when what they show changes (a few frames every few seconds).
func _process(delta: float) -> void:
	if kind != "" or _state == PlayerForm.NORMAL or not (force or motion_on()):
		return
	_clock += delta * speed
	var k := str(idle_look(_state, _clock))
	if k != _idle_key:
		_idle_key = k
		_redraw()

# ------------------------------------------------------------------ what a frame looks like
## A step of the way from a to b (in `n` flat steps, never a smooth blend).
static func _steps(a: Color, b: Color, k: float, n: int = 3) -> Color:
	var i := floorf(clampf(k, 0.0, 1.0) * n)
	return b if i >= n else a.lerp(b, i / n)

## A changing star at `time` into a transition: {stage ("from": as it was, "to": as it is now,
## "flash": all one colour, `flash`; "blend": stepping from the old colour to the new), flash,
## size (+1 grown by a rim in `glow`), glow, outline (a rim in its own colour), sparkle (0 none,
## 1 a plus, 2 a pixel)}.
static func look(k: String, time: float) -> Dictionary:
	var out := {"stage": "to", "flash": CLEAR, "size": 0, "glow": CLEAR, "outline": CLEAR, "sparkle": 0}
	match k:
		"heat":
			if time < 0.12:        # a warm glow round the star as it was
				out.stage = "from"
				out.outline = RIM_WARM if int(time / 0.06) % 2 == 0 else RIM_GOLD
			elif time < 0.25:      # flashes yellow to orange, grows
				out.stage = "flash"
				out.flash = _steps(EMBER_Y, WARM, (time - 0.12) / 0.13, 2)
				out.size = 1
				out.glow = RIM_GOLD
			elif time < 0.31:      # bright
				out.stage = "flash"
				out.flash = FLASH
				out.size = 1
				out.glow = RIM_FLASH
			elif time < 0.55:      # red: a pop, a bounce, the sparkle
				out.size = 1 if time < 0.38 or (time >= 0.44 and time < 0.48) else 0
				out.glow = RIM_POP
				out.sparkle = 1 if time < 0.44 else 2
			elif time < 0.7:       # settling: a last warm edge
				out.outline = RIM_EMBER
		"cool":
			if time < 0.1:
				out.stage = "from"
				out.size = 1
				out.glow = RIM_WHITE
			elif time < 0.3:
				out.stage = "blend"
			out.sparkle = 1 if time >= 0.14 and time < 0.26 else (2 if time >= 0.26 and time < 0.38 else 0)
	return out

## The settled bar while HOT, `clock` seconds in: {warm (the red stars a step warmer), ember
## (pixels above the last red star, -1 none)}. Mostly nothing.
static func idle_look(state: String, clock: float) -> Dictionary:
	var out := {"warm": false, "ember": -1}
	if PlayerForm.level_of(state) > 0:
		var u := fmod(clock, HOT_IDLE)
		out.warm = u >= 0.12 and u < 0.42
		if int(clock / HOT_IDLE) % 2 == 0 and u >= 0.1 and u < 0.7:
			out.ember = int((u - 0.1) / 0.15)
	return out

## The pixels that fly, single pixels only: [{x, y, vx, vy, g, t0, t1, col}], from the changing
## star's top left. The same transition always throws the same ones.
static func make_particles(k: String, seed_: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([k, seed_])
	var out: Array = []
	match k:
		"heat":
			for i in 3:            # embers rise while it warms
				var t0 := 0.03 + i * 0.07
				out.append({"x": rng.randi_range(0, 4), "y": 0, "vx": 0.0, "vy": -rng.randf_range(14.0, 20.0), "g": 0.0,
					"t0": t0, "t1": t0 + 0.2, "col": [EMBER_Y, WARM, EMBER_Y][i]})
			for i in 3:            # sparks as it pops, gone as it settles
				var t0 := 0.31 + rng.randf() * 0.04
				out.append({"x": 2 + rng.randi_range(-1, 1), "y": 0, "vx": rng.randf_range(-12.0, 12.0), "vy": -rng.randf_range(18.0, 26.0),
					"g": 40.0, "t0": t0, "t1": minf(t0 + rng.randf_range(0.16, 0.24), 0.62), "col": [EMBER_Y, WARM, EMBER_R][i]})
	return out

## The places whose look a change from one form to another alters (a five-star going HOT: his
## fifth star, gold to red).
static func changed_places(cur: float, pot: float, from: String, to: String) -> Array:
	var n := span(cur, pot, from, to)
	var a := Deck.star_fills(cur, pot, PlayerForm.red_stars(from), n)
	var b := Deck.star_fills(cur, pot, PlayerForm.red_stars(to), n)
	var out: Array = []
	for i in a.size():
		if _shows(a[i]) != _shows(b[i]):
			out.append(i)
	return out

## The places a change from one form to another covers: the longer of the two bars (a red star
## past his POTENTIAL comes and goes with its place, but plays its animation in it first).
static func span(cur: float, pot: float, from: String, to: String) -> int:
	return maxi(Deck.star_count(cur, pot, PlayerForm.red_stars(from)), Deck.star_count(cur, pot, PlayerForm.red_stars(to)))

## What a place shows: its gold, its form fill and colour (only where form shows), POTENTIAL.
static func _shows(f: Dictionary) -> String:
	var form := float(f.form) > float(f.gold)
	return "%s %s %s %s" % [f.gold, f.form if form else f.gold, Color(f.form_col).to_html() if form else "", f.pot]

## His last red star, -1 when there is none.
static func form_place(cur: float, pot: float, state: String) -> int:
	var fills := Deck.star_fills(cur, pot, PlayerForm.red_stars(state))
	for i in range(fills.size() - 1, -1, -1):
		if float(fills[i].form) > float(fills[i].gold):
			return i
	return -1

# ------------------------------------------------------------------ drawing
## Draws his stars (as Deck.star_bar does: up to his POTENTIAL, no padding to five) as they look right now. `y` is the top of the
## stars; `shape` the star (Deck.STAR_SHAPE, the one star). Returns the width drawn.
func draw(ci: CanvasItem, x: float, y: float, cur: float, pot: float, state: String, empty: Color = Color(1, 1, 1, 0.14),
		shape: Dictionary = Deck.STAR_SHAPE) -> float:
	_state = state
	_shape = shape
	x = floorf(x)
	y = floorf(y)
	var w := Deck.star_bar_w_for(cur, pot, PlayerForm.red_stars(state), shape)
	var sw: int = shape.w
	var mid := sw >> 1
	var at := func(i: int) -> Vector2: return Vector2(x + Deck.star_x(i, shape), y)
	if kind == "":
		var fills := Deck.star_fills(cur, pot, PlayerForm.red_stars(state))
		var il := idle_look(state, _clock) if state != PlayerForm.NORMAL and (force or motion_on()) else idle_look(PlayerForm.NORMAL, 0.0)
		if il.warm:
			for f in fills:
				f.form_col = Color(f.form_col).lerp(WARM.lightened(0.3), 0.34)
		for i in fills.size():
			Deck.star_place(ci, at.call(i), fills[i], empty, 0, _to(fills[i], sw), shape)
		var fp := form_place(cur, pot, state)
		if fp >= 0:
			var p: Vector2 = at.call(fp)
			if int(il.ember) >= 0:
				ci.draw_rect(Rect2(p.x + mid, p.y - 1 - int(il.ember), 1, 1), WARM if int(il.ember) < 2 else EMBER_R)
		return w
	var n := span(cur, pot, from_state, to_state)
	w = Deck.star_bar_w(shape, n)
	var from_f := Deck.star_fills(cur, pot, PlayerForm.red_stars(from_state), n)
	var to_f := Deck.star_fills(cur, pot, PlayerForm.red_stars(to_state), n)
	var changed := changed_places(cur, pot, from_state, to_state)
	for i in to_f.size():
		if changed.has(i):
			_place(ci, at.call(i), from_f[i], to_f[i], look(kind, t), empty)
		else:
			Deck.star_place(ci, at.call(i), to_f[i], empty, 0, _to(to_f[i], sw), shape)
	if not changed.is_empty():
		# the embers and the sparkle come off the top changed star
		_draw_extras(ci, at.call(changed.back()), look(kind, t))
	return w

## The columns of a place to draw: all of them, or (bare) only as far as it's lit.
func _to(f: Dictionary, sw: int) -> int:
	return Deck._cols(maxf(float(f.form), float(f.gold)), _shape) if bare else sw

## A changing star as `lk` says: its rim, then the star (as it was, as it is, one flash colour,
## or a step between).
func _place(ci: CanvasItem, at: Vector2, was: Dictionary, now: Dictionary, lk: Dictionary, empty: Color) -> void:
	var star: Array = _shape.star
	var w: int = _shape.w
	var c1 := Deck.place_color(now)
	if c1.a == 0.0:
		c1 = empty
	var rim_col: Color = lk.outline
	if int(lk.size) > 0:
		rim_col = lk.glow
	if rim_col.a > 0.0:
		for px in rim(star):
			ci.draw_rect(Rect2(at + Vector2(px), Vector2.ONE), rim_col)
	match String(lk.stage):
		"from":
			Deck.star_place(ci, at, was, empty, 0, w, _shape)
		"flash":
			Deck.pat(ci, at, star, {"#": lk.flash})
		"blend":
			var c0 := Deck.place_color(was)
			if c0.a == 0.0:
				c0 = empty
			Deck.pat(ci, at, star, {"#": _steps(c0, c1, (t - 0.1) / 0.2, 2)})
		_:
			Deck.star_place(ci, at, now, empty, 0, w, _shape)

## The pixels one out from a pattern (left, right, up, down), each once: a 1 px rim.
static func rim(rows: Array) -> Array:
	var on := {}
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] != ".":
				on[Vector2i(x, y)] = true
	var out := {}
	for px: Vector2i in on:
		for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			if not on.has(px + d):
				out[px + d] = true
	return out.keys()

## The flying pixels and the sparkle, around the changing star at `at`.
func _draw_extras(ci: CanvasItem, at: Vector2, lk: Dictionary) -> void:
	var w: int = _shape.w
	# make_particles throws them off a 5-wide star: centred on a wider one
	var off := Vector2((w - 5) >> 1, 0)
	for p in _parts:
		if t < float(p.t0) or t >= float(p.t1):
			continue
		var dt := t - float(p.t0)
		var pos := (at + off + Vector2(float(p.x) + float(p.vx) * dt, float(p.y) + float(p.vy) * dt + 0.5 * float(p.g) * dt * dt)).floor()
		ci.draw_rect(Rect2(pos, Vector2.ONE), p.col)
	var sp := SPARK
	match int(lk.sparkle):
		1:
			Deck.pat(ci, at + Vector2(w - 1, -3), PLUS, {"#": sp})
		2:
			ci.draw_rect(Rect2(at.x + w, at.y - 2, 1, 1), sp)
