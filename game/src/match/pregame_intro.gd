class_name PregameIntro
extends RefCounted
## THE PREGAME ENTRANCE (the Pregame Aquatic Center Cinematic update): before a match you play,
## about 4.5 s from a dim hallway, through two glass doors with the two schools' logos on them,
## into the pool and down to the game's own camera. Pure presentation: the match screen holds its
## whole loop while this runs (no clock, no shot clock, no possession, no statistic), then hands
## over exactly once (done). A tap / click / key skips it at any moment.
##
##   0.0 - 0.7   the closed doors: your team's logo on the left door, the opponent's on the
##               right (wherever the game is played; HOME/AWAY stay as labels); the pool
##               glows faintly through the blue glass
##   0.7 - 1.6   the doors swing out towards us (each a trapezoid turning on its outer hinge, its
##               logo going with it), a glint running across the glass
##   1.6 - 2.7   the camera walks in: the hallway (walls, tiled floor, frame) scales out past the
##               edges around the doorway until the doorway is the whole screen. No 3D: the pool
##               was behind the doors all along (one continuous picture, no fade, no cut)
##   2.7 - 3.8   the reveal: the pool (PoolArt, the venue's own) from the whole pool down to the
##               game's own opening camera, both sevens treading water on their lines
##   3.3 - 4.5   the matchup: YOURS vs THEIRS (each labelled HOME / AWAY) with their logos and the game's designation (REGULAR
##               SEASON / CONFERENCE TOURNAMENT / NCSA CHAMPIONSHIP), then it slides away
## The Pregame Presentation levels (the entrance progression update):
##   Level 1, free: a plain aquatic-center entrance. The same timeline as above, but light concrete
##            walls, clear glass doors with no logos and no sign, a still reflection, no light
##            spilling in, no arena lights.
##   Level 2: all of the above as it was (the navy hall, the logo doors, the venue's sign, the
##            glint): the entrance that used to be Level 1, unchanged.
##   Level 3: first the walk down a dark blue-grey corridor (HALL_TIME, under ceiling lights) up to
##            Level 2's logo doors, then the doors, the walk through and a flash of the bright pool,
##            arena lights on the reveal, a livelier crowd, the logos popping in. The top level.
## The corridor runs first, so `t` is the whole entrance's clock and _s() the doors-and-pool clock
## the constants below are written in (the same as `t` at Levels 1-2). The clock holds through all
## of this (the match waits as it always does) and every level skips at a tap.
## Reduce Motion (calm): the doors, then open, then the pool already at the game's camera and the
## matchup: no corridor, no swing, no walk, no pan (2.6 s).
## The pool, players, logos and caps are the game's own (PoolArt, Sprint's line-up, TeamLogo);
## the doors and hallway are drawn here in whole pixels. Sounds go through Sfx (Settings' sound
## switch applies).

const DOORS_AT := 0.7
const OPEN_END := 1.6
const DOLLY_END := 2.7
const REVEAL_END := 3.8
const MATCHUP_AT := 3.3
const TOTAL := 4.5
const CALM_TOTAL := 2.6
const DOLLY_ZOOM := 4.2            # how far the hallway scales out as we walk through
const OPEN_ANGLE := 78.0           # degrees each door swings
const SKIP_TEXT := "TAP TO SKIP  >>"

const WALL := Color("0c1230")
const WALL_LO := Color("0a0f26")
const FLOOR_A := Color("2a3463")
const FLOOR_B := Color("212a52")
const FLOOR_LINE := Color("3b4785")
const SEAM := Color("161e45")
const METAL := Color("2b3140")
const METAL_HI := Color("5a667f")
const GLASS := Color(0.10, 0.27, 0.52, 0.78)   # (blue and dense: the pool only glows through)
const GLINT := Color(1, 1, 1, 0.35)
const LIGHT := Color("dff4ff")
const HANDLE := Color("c9d3dd")
const SPILL := Color(0.55, 0.85, 1.0, 0.12)

const HALL_TIME := 1.4             # Level 3: the corridor walk before the doors' timeline
const HALL_FROM := 0.3             # how small the far end (the doors) starts, its scale
const HALL_ARRIVE := 0.45          # (the doors' clock) when the walk reaches them, before they open
const BLOOM := 0.32                # the bright pool's flash as we come through (alpha at its peak)

## The walls and the doors, by level. Level 2's are the constants above, exactly as they were.
const LOOK_BASIC := {"wall": Color("6e7a87"), "wall_lo": Color("616c78"), "floor_a": Color("56616c"),
	"floor_b": Color("4f5963"), "line": Color("65707b"), "seam": Color("626d79"), "metal": Color("3b4350"),
	"metal_hi": Color("a3afbc"), "glass": Color(0.60, 0.78, 0.88, 0.5), "glint": Color(1, 1, 1, 0.45),
	"light": Color("eef3f6"), "spill": 0.0, "logos": false, "sign": false, "still_glint": true}
const LOOK_GAMEDAY := {"wall": WALL, "wall_lo": WALL_LO, "floor_a": FLOOR_A, "floor_b": FLOOR_B,
	"line": FLOOR_LINE, "seam": SEAM, "metal": METAL, "metal_hi": METAL_HI, "glass": GLASS, "glint": GLINT,
	"light": LIGHT, "spill": 1.0, "logos": true, "sign": true, "still_glint": false}
## Level 3: Level 2's doors (frame, glass, logos, sign) at the end of a dark blue-grey corridor.
const LOOK_DARK := {"wall": Color("131a26"), "wall_lo": Color("0e141e"), "floor_a": Color("1a2230"),
	"floor_b": Color("161d2a"), "line": Color("273143"), "seam": Color("0c111a"), "metal": METAL,
	"metal_hi": METAL_HI, "glass": GLASS, "glint": GLINT, "light": Color("cfe3f2"), "spill": 1.6,
	"logos": true, "sign": true, "still_glint": false, "ceil": Color("0a0e16"), "side": Color("10161f"),
	"side_lo": Color("0c1119")}

var home: PoloTeam
var away: PoloTeam
var left: PoloTeam                 # the player's team (`us`): always the left door and card side
var right: PoloTeam
var _left_home := true             # (the left side is the designated home)
var label := ""                    # the game's designation ("" for none)
var venue := ""
var pool: PoolDef
var crowd := 0.6
var t := 0.0
var done := false
var skipped := false
var calm := false
var hold := -1.0                   # Developer Mode: freeze at this time (-1: play)
var end_view: PoolView             # the game's own opening camera (the reveal ends on it)
var paint_body: Callable           # (ci, view, swimmer): the match's own caps on the line-up
var style := {}                    # the stands (CrowdArt.style)
var level := 1                     # the worn Pregame Presentation level
var _us: PoloTeam
var _them: PoloTeam
var _fx := ShowFx.new()   # (the arena lights: ShowFx)
var _rv := PoolView.new()          # the reveal's camera
var _line: Sprint                  # both sevens on their lines (Sprint's line-up, never stepped)
var _cues := {}

## `us`/`them` are the match's sides (the line-up); `us` is always on the left, `home_is_us` only
## decides which side is labelled HOME (and whose colours light the arena).
func _init(us: PoloTeam, them: PoloTeam, home_is_us: bool, p_label: String = "", p_venue: String = "", p_pool: PoolDef = null) -> void:
	home = us if home_is_us else them
	away = them if home_is_us else us
	left = us
	right = them
	_left_home = home_is_us
	label = p_label
	venue = p_venue
	pool = p_pool
	calm = bool(Game.settings.get("reduce_motion", false))
	_line = Sprint.new(us, them, 0.0)
	_us = us
	_them = them

## The worn level (1 .. the category's top).
func set_level(lv: int) -> void:
	level = clampi(lv, 1, VisualUpgrades.top("pregame"))
	_fx.level = level
	_fx.calm = calm
	_fx.c1 = home.c1
	_fx.c2 = home.c2

## How long the corridor walk runs before the doors' timeline (Level 3; never in Reduce Motion).
static func lead_for(lv: int, p_calm: bool) -> float:
	return HALL_TIME if lv >= 3 and not p_calm else 0.0

func lead() -> float:
	return lead_for(level, calm)

## The doors-and-pool clock (the constants' own): `t` less the corridor walk.
func _s() -> float:
	return t - lead()

## The walls and doors this level is drawn with.
func _look() -> Dictionary:
	return LOOK_BASIC if level <= 1 else (LOOK_GAMEDAY if level == 2 else LOOK_DARK)

func length() -> float:
	return CALM_TOTAL if calm else lead() + TOTAL

## One frame: the clock, the sounds at their cues, done at the end.
func step(dt: float) -> void:
	if done:
		return
	if hold >= 0.0:
		t = hold
	else:
		t += dt
	for s in _line.bodies():
		s.anim += dt
	_sounds()
	if hold < 0.0 and t >= length():
		done = true

## Skips to the game (once; nothing else happens).
func skip() -> void:
	if done:
		return
	skipped = true
	done = true

func _cue(key: String, at: float) -> bool:
	if t >= at and not _cues.has(key):
		_cues[key] = true
		return true
	return false

func _sounds() -> void:
	var l := lead()
	if l > 0.0 and _cue("corridor", 0.0):
		Sfx.crowd(0.08)                    # (the pool far off, muffled down the corridor)
	var open_at := (0.6 if calm else DOORS_AT) + l
	if _cue("door", open_at):
		Sfx.play("turn", 0.55, -6.0)       # (the doors: a soft low whoosh)
	if _cue("hall", open_at + 0.2):
		Sfx.crowd(0.2)                     # (the pool's ambience coming through)
	if _cue("pool", (1.0 if calm else DOLLY_END - 0.3) + l):
		Sfx.play("splash", 0.8, -12.0)
		Sfx.crowd(0.35)
	if _cue("vs", (1.1 if calm else MATCHUP_AT) + l):
		Sfx.play("card", 1.0, -6.0)

# ------------------------------------------------------------------ where we are
static func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)

## How open the doors are, 0..1.
func open_amount() -> float:
	if calm:
		return 0.0 if _s() < 0.6 else 1.0
	return _ease((_s() - DOORS_AT) / (OPEN_END - DOORS_AT))

## How far in we've walked: the hallway's scale (1 .. DOLLY_ZOOM), easing in like a step forward.
## Level 3 first walks the corridor: the far end grows from HALL_FROM to 1 (the doors filling
## the view as at Level 2's start), the distance closing at an even walk that eases to a stop.
func dolly() -> float:
	if calm:
		return 1.0
	var s := _s()
	if lead() > 0.0 and s < HALL_ARRIVE:
		var u := _ease(t / (lead() + HALL_ARRIVE))
		return 1.0 / lerpf(1.0 / HALL_FROM, 1.0, u)
	var u := clampf((s - OPEN_END + 0.25) / (DOLLY_END - OPEN_END + 0.25), 0.0, 1.0)
	return lerpf(1.0, DOLLY_ZOOM, u * u)

## The hallway's gone (we're through the doors).
func through() -> bool:
	return (_s() >= 1.0) if calm else (dolly() >= DOLLY_ZOOM - 0.01)

## Level 3: the bright pool's flash as we step out of the dark (0 none .. BLOOM).
func bloom() -> float:
	if lead() <= 0.0:
		return 0.0
	var s := _s()
	if s < DOLLY_END - 0.3 or s > DOLLY_END + 0.3:
		return 0.0
	if s < DOLLY_END:
		return BLOOM * _ease((s - (DOLLY_END - 0.3)) / 0.3)
	return BLOOM * (1.0 - _ease((s - DOLLY_END) / 0.3))

## The reveal's progress, 0 (the whole pool) .. 1 (the game's camera).
func reveal() -> float:
	if calm:
		return 1.0
	return _ease((_s() - (DOLLY_END - 0.4)) / (REVEAL_END - DOLLY_END + 0.4))

## The matchup panel: 0 hidden .. 1 in place.
func matchup() -> float:
	var at := 1.1 if calm else MATCHUP_AT
	var out := TOTAL - 0.3
	var tl := _s()
	if tl < at:
		return 0.0
	if calm:
		return 1.0
	if tl > out:
		return 1.0 - _ease((tl - out) / 0.3)
	return _ease((tl - at) / 0.3)

## What's on screen now, for Developer Mode and the tests.
func stage() -> String:
	var s := _s()
	if calm:
		return "DOORS" if s < 0.6 else ("OPEN" if s < 1.0 else "MATCHUP")
	if s < 0.0:
		return "HALLWAY"
	if s < DOORS_AT:
		return "CLOSED"
	if s < OPEN_END:
		return "OPENING"
	if not through():
		return "DOORWAY"
	if s < MATCHUP_AT:
		return "REVEAL"
	return "MATCHUP"

# ------------------------------------------------------------------ drawing
func draw(ci: CanvasItem, size: Vector2) -> void:
	_pool(ci, size)
	if not through():
		_hallway(ci, size)
	elif level >= 3 and not calm:
		_fx.lights(ci, size, t, 0.7)
	var b := bloom()
	if b > 0.0:
		ci.draw_rect(Rect2(Vector2.ZERO, size), Color(0.86, 0.96, 1.0, b))
	_matchup(ci, size)
	if not done and hold < 0.0:
		var w := Deck.text_w(SKIP_TEXT) + 10
		ci.draw_rect(Rect2(size.x - w - 4, size.y - 15, w, 12), Color(UI.INK, 0.7))
		Deck.text(ci, size.x - w + 1, size.y - 9, SKIP_TEXT, 8, UI.TEXT)

## The pool and the sevens, through the doors and then the whole screen: from the whole pool
## (the wide view) down to the game's own opening camera.
func _pool(ci: CanvasItem, size: Vector2) -> void:
	_rv.width = size.x
	_rv.height = size.y
	_rv.mirror = false
	var wide := size.x / ((Geo.LENGTH + PoolView.WIDE_MARGIN * 2.0) * PoolView.SX)
	var k := reveal()
	var end_zoom := end_view.zoom if end_view != null else 1.0
	_rv.zoom = lerpf(wide, end_zoom, k)
	_rv.zoom_to = _rv.zoom
	var from := _rv._want(Vector2(Geo.HALF, Geo.GOAL_Y))
	var to := end_view.cam if end_view != null else _rv._want(_line.focus())
	_rv.cam = from.lerp(to, k)
	PoolArt.draw_pool(ci, _rv, t, size, 0.2 if level < 3 else 0.8, pool, crowd, {}, style)
	var bodies: Array[Swimmer] = _line.bodies().duplicate()
	bodies.sort_custom(func(a: Swimmer, b: Swimmer): return a.pos.y < b.pos.y)
	for s in bodies:
		if paint_body.is_valid():
			paint_body.call(ci, _rv, s)
		else:
			PoolArt.draw_body(ci, _rv, s, PoolArt.CAP_KEEPER if s.keeper else (Color.WHITE if s.side == Swimmer.Side.US else Color("1d3b7a")), Color("1d3b7a"))
	var b := Ball.new()
	b.pos = _line.ball
	PoolArt.draw_ball(ci, _rv, b)

## The hallway around the doorway, scaled about the centre by the walk (dolly), in this level's
## look. Below scale 1 (Level 3's corridor walk) the same picture is the corridor's far end,
## the corridor drawn round it; from 1 up it's the whole screen, exactly as Level 2 always was.
func _hallway(ci: CanvasItem, size: Vector2) -> void:
	var z := dolly()
	var L := _look()
	var c := Vector2(roundf(size.x * 0.5), roundf(size.y * 0.5))
	var P := func(v: Vector2) -> Vector2: return (c + (v - c) * z).round()
	# the far end's own edges: the screen, or a smaller picture down the corridor
	var lo := Vector2.ZERO
	var hi := size
	if z < 1.0:
		lo = P.call(Vector2.ZERO)
		hi = P.call(size)
		_corridor(ci, size, z, c, lo, hi, L)
	# the doorway, before the walk: 150 x 160, its foot well down the screen
	var ow := 150.0
	var oh := 160.0
	var o0 := Vector2(c.x - ow * 0.5, size.y * 0.86 - oh)
	var tl: Vector2 = P.call(o0)
	var br: Vector2 = P.call(o0 + Vector2(ow, oh))
	var o := Rect2(tl, br - tl)
	# walls, ceiling and floor round the doorway (the doorway itself left open)
	ci.draw_rect(Rect2(lo.x, lo.y, hi.x - lo.x, maxf(0.0, o.position.y - lo.y)), L.wall)
	ci.draw_rect(Rect2(lo.x, o.position.y, maxf(0.0, o.position.x - lo.x), o.size.y), L.wall)
	ci.draw_rect(Rect2(o.end.x, o.position.y, maxf(0.0, hi.x - o.end.x), o.size.y), L.wall)
	# wall panels: seams every so often, a lighter band at handle height, a metal baseboard
	var seam := 48.0 * z
	var sx0 := fposmod(c.x - ow * 0.5 * z, seam)
	var x := sx0
	while x < hi.x:
		if x >= lo.x and (x < o.position.x - 2 or x > o.end.x + 2):
			ci.draw_rect(Rect2(roundf(x), lo.y, 1, o.end.y - lo.y), L.seam)
		x += seam
	var band_y: float = P.call(Vector2(0, o0.y + oh * 0.55)).y
	ci.draw_rect(Rect2(lo.x, band_y, maxf(0.0, o.position.x - lo.x), maxf(1.0, roundf(3 * z))), L.wall_lo)
	ci.draw_rect(Rect2(o.end.x, band_y, maxf(0.0, hi.x - o.end.x), maxf(1.0, roundf(3 * z))), L.wall_lo)
	var floor_top := o.end.y
	ci.draw_rect(Rect2(lo.x, floor_top, hi.x - lo.x, maxf(0.0, hi.y - floor_top)), L.floor_a)
	ci.draw_rect(Rect2(lo.x, floor_top - maxf(1.0, roundf(2 * z)), maxf(0.0, o.position.x - lo.x), maxf(1.0, roundf(2 * z))), L.metal)
	ci.draw_rect(Rect2(o.end.x, floor_top - maxf(1.0, roundf(2 * z)), maxf(0.0, hi.x - o.end.x), maxf(1.0, roundf(2 * z))), L.metal)
	# floor tiles: rows that widen towards us, lines running to the doors
	var row := 0
	var y := floor_top
	var hgt := 3.0 * z
	while y < hi.y:
		if row % 2 == 1:
			ci.draw_rect(Rect2(lo.x, roundf(y), hi.x - lo.x, minf(maxf(1.0, roundf(hgt)), hi.y - roundf(y))), L.floor_b)
		y += hgt
		hgt *= 1.55
		row += 1
	for i in range(-6, 7):
		var foot := Vector2(c.x + i * ow / 6.0 * z, floor_top)
		var far := Vector2(c.x + i * ow * 1.3 * z, size.y + 40)
		if z < 1.0:   # (stopping at the far end's edge: the corridor's own floor carries on)
			far = foot.lerp(far, (hi.y - floor_top) / (far.y - floor_top))
		ci.draw_line(foot, far, L.line, 1.0)
	# light from the pool across the floor, more as the doors open (not at Level 1); down the
	# corridor, the faint glow of the pool through the shut glass
	var a := open_amount()
	var spill: float = L.spill
	if spill > 0.0 and a > 0.0:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(o.position.x, floor_top), Vector2(o.end.x, floor_top),
			Vector2(o.end.x + o.size.x * 0.6, size.y), Vector2(o.position.x - o.size.x * 0.6, size.y)]), Color(SPILL, minf(1.0, SPILL.a * a * spill)))
	if z < 1.0:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(o.position.x, floor_top), Vector2(o.end.x, floor_top),
			Vector2(o.end.x + o.size.x * 1.2, size.y), Vector2(o.position.x - o.size.x * 1.2, size.y)]), Color(SPILL, 0.05))
	# ceiling lights and the sign over the doors (none at Level 1; down the corridor its plate
	# glows and the name comes clear as we close in)
	for i in 3:
		var lx: float = P.call(Vector2(c.x - 120 + i * 120, 0)).x
		var ly: float = P.call(Vector2(0, o0.y - 34)).y
		ci.draw_rect(Rect2(lx - 14 * z, ly, 28 * z, maxf(1.0, 2 * z)), L.light)
	if bool(L.sign) and z < 1.6:
		var sign := (venue if venue != "" else "AQUATIC CENTER").to_upper()
		var sy: float = P.call(Vector2(0, o0.y - 14)).y
		if z < 1.0:
			var pw := roundf(minf(Deck.text_w(Deck.fit(sign, size.x - 40)) + 8.0, size.x - 32.0) * z)
			ci.draw_rect(Rect2(roundf(c.x - pw * 0.5), roundf(sy - 6 * z), pw, maxf(2.0, roundf(12 * z))), Color(UI.ACCENT, 0.12))
		if z >= 0.85:
			Deck.ctext(ci, Rect2(0, sy - 5, size.x, 10), Deck.fit(sign, size.x - 40), 8, UI.ACCENT)
	# the frame
	var fw := maxf(2.0, roundf(5.0 * z))
	ci.draw_rect(Rect2(o.position.x - fw, o.position.y - fw, o.size.x + fw * 2, fw), L.metal)
	ci.draw_rect(Rect2(o.position.x - fw, o.position.y, fw, o.size.y), L.metal)
	ci.draw_rect(Rect2(o.end.x, o.position.y, fw, o.size.y), L.metal)
	ci.draw_rect(Rect2(o.position.x - fw, o.position.y - fw, o.size.x + fw * 2, 1), L.metal_hi)
	ci.draw_rect(Rect2(o.position.x - 1, o.position.y, 1, o.size.y), L.metal_hi)
	# the doors
	_door(ci, o, -1, left, a, z, L)
	_door(ci, o, 1, right, a, z, L)

## Level 3's corridor, from the screen's edges in to the far end (`lo`..`hi`, the doors' wall
## at scale `z`): a dark ceiling and floor, two side walls, and fixed things along it (tile
## joints, pilasters, ceiling lights with their soft pools below) that pass us as we walk.
## A thing `g` from the far end (in units of the walk) is at scale 1 / (1 / z - g).
func _corridor(ci: CanvasItem, size: Vector2, z: float, c: Vector2, lo: Vector2, hi: Vector2, L: Dictionary) -> void:
	var ceil_c: Color = L.get("ceil", L.wall)
	var side: Color = L.get("side", L.wall)
	var side_lo: Color = L.get("side_lo", L.wall_lo)
	ci.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(hi.x, lo.y), lo]), ceil_c)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0, size.y), Vector2(lo.x, hi.y), hi, size]), L.floor_a)
	ci.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, lo, Vector2(lo.x, hi.y), Vector2(0, size.y)]), side)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(size.x, 0), size, hi, Vector2(hi.x, lo.y)]), side)
	# the cross-section at scale q: its top, floor, left and right
	var sec := func(q: float) -> Rect2:
		var a := (c - c * q).round()
		var b := (c + (size - c) * q).round()
		return Rect2(a, b - a)
	# a darker band low on each wall, the baseboard along the foot
	var band := 0.62
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0, size.y * band), Vector2(lo.x, lerpf(lo.y, hi.y, band)),
		Vector2(lo.x, hi.y), Vector2(0, size.y)]), side_lo)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(size.x, size.y * band), Vector2(hi.x, lerpf(lo.y, hi.y, band)),
		hi, size]), side_lo)
	ci.draw_line(Vector2(0, size.y), Vector2(lo.x, hi.y), L.metal, 2.0)
	ci.draw_line(size, hi, L.metal, 2.0)
	# lines down the floor to the far end
	for i in range(-4, 5):
		var fx := c.x + i * size.x * 0.16
		ci.draw_line(Vector2(fx, size.y), Vector2(c.x + (fx - c.x) * z, hi.y), L.line, 1.0)
	var near := 1.0 / z
	# tile joints across the floor, every so often
	var g := 0.14
	while g < near - 0.6:
		var q := 1.0 / (near - g)
		var r: Rect2 = sec.call(q)
		if r.end.y < size.y:
			ci.draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 1), L.line)
		g += 0.14
	# pilasters and ceiling lights, each a light-pool on the floor beneath it
	g = 0.28
	var k := 0
	while g < near - 0.55:
		var q := 1.0 / (near - g)
		var r: Rect2 = sec.call(q)
		var pw := maxf(1.0, roundf(4.0 * q))
		ci.draw_rect(Rect2(r.position.x - pw, r.position.y, pw, r.size.y), L.seam)
		ci.draw_rect(Rect2(r.end.x, r.position.y, pw, r.size.y), L.seam)
		if k % 2 == 0:
			var lw := roundf(34.0 * q)
			var lh := maxf(1.0, roundf(3.0 * q))
			var ly := r.position.y + roundf(2.0 * q)
			var fy := r.end.y
			var lc: Color = L.light
			ci.draw_colored_polygon(PackedVector2Array([Vector2(c.x - lw * 0.5, ly + lh), Vector2(c.x + lw * 0.5, ly + lh),
				Vector2(c.x + lw * 1.6, fy), Vector2(c.x - lw * 1.6, fy)]), Color(lc, 0.035))
			ci.draw_rect(Rect2(roundf(c.x - lw * 1.4), roundf(fy - 5.0 * q), roundf(lw * 2.8), maxf(1.0, roundf(10.0 * q))), Color(lc, 0.05))
			ci.draw_rect(Rect2(roundf(c.x - lw * 0.9), roundf(fy - 3.0 * q), roundf(lw * 1.8), maxf(1.0, roundf(6.0 * q))), Color(lc, 0.05))
			ci.draw_rect(Rect2(roundf(c.x - lw * 0.5), ly, lw, lh), lc)
		g += 0.28
		k += 1

## One door: `side` -1 the left (hinged on the doorway's left), +1 the right; `a` how open.
## It turns towards us on its hinge: its free edge comes in and grows a little taller. Level 1's
## glass is clear and plain (no logo, a still reflection); the others' carry the school's logo.
func _door(ci: CanvasItem, o: Rect2, side: int, team: PoloTeam, a: float, z: float, L: Dictionary) -> void:
	var th := deg_to_rad(OPEN_ANGLE) * a
	var half := o.size.x * 0.5
	var hinge_x := o.position.x if side < 0 else o.end.x
	var reach := half * cos(th)
	var grow := o.size.y * 0.18 * sin(th)
	var free_x := hinge_x - side * reach
	if side < 0:
		free_x = hinge_x + reach
	var h0 := Vector2(hinge_x, o.position.y).round()
	var h1 := Vector2(hinge_x, o.end.y).round()
	var f0 := Vector2(free_x, o.position.y - grow * 0.5).round()
	var f1 := Vector2(free_x, o.end.y + grow * 0.5).round()
	if absf(free_x - hinge_x) < 1.0:
		return
	var poly := PackedVector2Array([h0, f0, f1, h1])
	ci.draw_colored_polygon(poly, L.glass)
	# the glint running across the glass (Level 1: a reflection that stays put)
	var g := 0.22 if bool(L.still_glint) else fposmod(t * 0.6 + (0.0 if side < 0 else 0.5), 1.0)
	for k in 2:
		var u := clampf(g + k * 0.12, 0.0, 1.0)
		var top := h0.lerp(f0, clampf(u + 0.15, 0.0, 1.0))
		var bot := h1.lerp(f1, u)
		ci.draw_line(top, bot, L.glint, 1.0)
	# its logo, a decal on the glass, turning with the door
	if bool(L.logos):
		var tex: Texture2D = TeamLogo.art_within(team, Vector2i(48, 48))
		var dim := Vector2(48, 48)
		if tex == null:
			tex = TeamLogo.texture(team)
			dim = Vector2(tex.get_width(), tex.get_height()) * 2.0
		else:
			dim = Vector2(tex.get_width(), tex.get_height())
		var mid := (h0 + f0 + f1 + h1) * 0.25
		var sx := (absf(free_x - hinge_x) / half) * z
		var sy := ((o.size.y + grow) / o.size.y) * z
		if sx > 0.15:
			ci.draw_set_transform(mid.round(), 0.0, Vector2(sx, sy))
			ci.draw_texture_rect(tex, Rect2((-dim * 0.5).round(), dim), false, Color(1, 1, 1, 0.92))
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	# its frame and handle
	var fw := maxf(2.0, roundf(3.0 * z))
	ci.draw_polyline(PackedVector2Array([h0, f0, f1, h1, h0]), L.metal, fw)
	var hx := f0.x + side * 6.0 * z * (absf(free_x - hinge_x) / half)
	var hy := (f0.y + f1.y) * 0.5
	ci.draw_rect(Rect2(roundf(hx - z), roundf(hy - 8 * z), maxf(2.0, roundf(2 * z)), roundf(16 * z)), HANDLE)

## HOME vs AWAY, their logos, and the game's designation, sliding down from the top.
func _matchup(ci: CanvasItem, size: Vector2) -> void:
	var m := matchup()
	if m <= 0.0:
		return
	var w := minf(size.x - 24, 360.0)
	var h := 56.0 if label != "" else 46.0
	var x := roundf((size.x - w) * 0.5)
	var y := roundf(lerpf(-h - 4, 30.0, m))
	Deck.frame(ci, Rect2(x, y, w, h), Deck.NAVY, Color.WHITE)
	var top := y + 4
	if label != "":
		Deck.ctext(ci, Rect2(x, top, w, 10), label, 8, UI.ACCENT)
		top += 10
	var lw := 40.0
	var pop := 0.0 if level < 3 or calm else roundf(sin(clampf((_s() - MATCHUP_AT) / 0.3, 0.0, 1.0) * PI) * 3.0)
	TeamLogo.draw_in(ci, Rect2(x + 6, top + 2 - pop, lw, 36), left)
	TeamLogo.draw_in(ci, Rect2(x + w - 6 - lw, top + 2 - pop, lw, 36), right)
	var col_w := (w - lw * 2 - 12 - 30) * 0.5
	var hn := Colleges.display_name(left.name).to_upper()
	var an := Colleges.display_name(right.name).to_upper()
	Deck.ctext(ci, Rect2(x + 6 + lw, top + 8, col_w, 10), Deck.fit(hn, col_w - 4), 8, Color.WHITE)
	Deck.ctext(ci, Rect2(x + w - 6 - lw - col_w, top + 8, col_w, 10), Deck.fit(an, col_w - 4), 8, Color.WHITE)
	Deck.ctext(ci, Rect2(x + 6 + lw + col_w, top + 10, 30, 16), "VS", 16, UI.GOLD, "big")
	Deck.ctext(ci, Rect2(x + 6 + lw, top + 20, col_w, 10), "HOME" if _left_home else "AWAY", 8, UI.DIM)
	Deck.ctext(ci, Rect2(x + w - 6 - lw - col_w, top + 20, col_w, 10), "AWAY" if _left_home else "HOME", 8, UI.DIM)

## The text of the matchup (tests, the lab).
func matchup_text() -> String:
	return "%s %s VS %s" % [label, Colleges.display_name(left.name).to_upper(), Colleges.display_name(right.name).to_upper()]

## The designation for a career game: REGULAR SEASON, CONFERENCE TOURNAMENT or NCSA CHAMPIONSHIP.
static func label_for(round: Dictionary, g: Dictionary = {}) -> String:
	var kind := String(round.get("kind", ""))
	if kind.begins_with("conf_"):
		return "CONFERENCE TOURNAMENT"
	if kind.begins_with("nat_"):
		return "NCSA CHAMPIONSHIP"
	return "REGULAR SEASON"
