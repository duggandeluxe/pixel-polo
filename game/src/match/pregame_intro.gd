class_name PregameIntro
extends RefCounted
## THE PREGAME ENTRANCE (the Pregame Aquatic Center Cinematic update): before a match you play,
## about 4.5 s from a dim hallway, through two glass doors with the two schools' logos on them,
## into the pool and down to the game's own camera. Pure presentation: the match screen holds its
## whole loop while this runs (no clock, no shot clock, no possession, no statistic), then hands
## over exactly once (done). A tap / click / key skips it at any moment.
##
##   0.0 - 0.7   the closed doors: HOME's logo on the left door, AWAY's on the right (the
##               schedule's designated home, so a neutral site keeps its bracket order); the pool
##               glows faintly through the blue glass
##   0.7 - 1.6   the doors swing out towards us (each a trapezoid turning on its outer hinge, its
##               logo going with it), a glint running across the glass
##   1.6 - 2.7   the camera walks in: the hallway (walls, tiled floor, frame) scales out past the
##               edges around the doorway until the doorway is the whole screen. No 3D: the pool
##               was behind the doors all along (one continuous picture, no fade, no cut)
##   2.7 - 3.8   the reveal: the pool (PoolArt, the venue's own) from the whole pool down to the
##               game's own opening camera, both sevens treading water on their lines
##   3.3 - 4.5   the matchup: HOME vs AWAY with their logos and the game's designation (REGULAR
##               SEASON / CONFERENCE TOURNAMENT / NCSA CHAMPIONSHIP), then it slides away
## The Pregame Presentation levels (the Premium Visual Upgrades update) add to this; Level 1 is all
## of the above, free. Level 2: arena lights on the reveal, a livelier crowd, the logos popping in.
## Level 3: your starting seven introduced, a real portrait and name each, the team's flag. Level 4,
## the STARTING SEVEN SHOWCASE: no one-at-a-time introductions; the home team's seven real faces
## together on one broadcast graphic, then the away team's, then a grander matchup. Who's on it is
## read once in set_level, from the seven the match itself starts. The clock holds through all of
## this (the match waits as it always does) and every level skips at a tap.
## Reduce Motion (calm): the doors, then open, then the pool already at the game's camera and the
## matchup: no swing, no walk, no pan (2.6 s). Level 4's two graphics still show, as stills.
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

var home: PoloTeam
var away: PoloTeam
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
var lineup: Array = []             # Level 3's introductions, in order: [PoloPlayer, PoloTeam]
var sevens: Array = []             # Level 4's graphics, home then away: {team, men (goal first)}
var _us: PoloTeam
var _them: PoloTeam
var _fx := GoalFx.new()
var _rv := PoolView.new()          # the reveal's camera
var _line: Sprint                  # both sevens on their lines (Sprint's line-up, never stepped)
var _cues := {}

## `us`/`them` are the match's sides (the line-up); `home_is_us` puts the right logo on the left door.
func _init(us: PoloTeam, them: PoloTeam, home_is_us: bool, p_label: String = "", p_venue: String = "", p_pool: PoolDef = null) -> void:
	home = us if home_is_us else them
	away = them if home_is_us else us
	label = p_label
	venue = p_venue
	pool = p_pool
	calm = bool(Game.settings.get("reduce_motion", false))
	_line = Sprint.new(us, them, 0.0)
	_us = us
	_them = them

## The worn level: the introductions it brings.
func set_level(lv: int) -> void:
	level = clampi(lv, 1, VisualUpgrades.MAX_LEVEL)
	lineup.clear()
	sevens.clear()
	_fx.level = level
	_fx.calm = calm
	_fx.c1 = home.c1
	_fx.c2 = home.c2
	if level == 3:
		for p: PoloPlayer in _us.starters():
			lineup.append([p, _us])
	if level >= 4:
		for tm: PoloTeam in [home, away]:
			sevens.append({"team": tm, "men": tm.starters().duplicate()})

const CARD_TIME := [0.0, 0.0, 0.42, 0.0]   # s each man's on screen, by level
const LINEUP_AT := 3.0                     # the reveal holds here for the introductions
const SHOW_TIME := 1.8                     # s each team's Starting Seven is up
const SHOW_GAP := 0.3                      # s between the two
const SHOW_WIPE := 0.12                    # s of each half of the columns in and out
const CALM_SHOW_AT := 1.0                  # Reduce Motion: where the graphics go
## The faces, the biggest that fit: the portrait doubled, the roster card's, the portrait itself.
const FACE_SIZES := [Vector2i(52, 58), Vector2i(36, 40), Vector2i(26, 29)]

## How long the introductions take.
func extra() -> float:
	if not sevens.is_empty():
		return SHOW_TIME * sevens.size() + (0.0 if calm else SHOW_GAP * (sevens.size() - 1))
	return lineup.size() * float(CARD_TIME[level - 1])

## When the Starting Seven begins, and team `i`'s graphic.
func show_from() -> float:
	return CALM_SHOW_AT if calm else LINEUP_AT

func seven_at(i: int) -> float:
	return show_from() + i * (SHOW_TIME + (0.0 if calm else SHOW_GAP))

func in_showcase() -> bool:
	return not sevens.is_empty() and t >= show_from() and t < show_from() + extra()

## Which team's graphic is up: 0 home, 1 away, -1 neither.
func seven_index() -> int:
	if not in_showcase():
		return -1
	return 0 if t < seven_at(1) - (0.0 if calm else SHOW_GAP * 0.5) else 1

## The clock the reveal and matchup run on: it stops for the introductions.
func _tl() -> float:
	if (calm and sevens.is_empty()) or t < show_from():
		return t
	return maxf(show_from(), t - extra())

func in_lineup() -> bool:
	return not lineup.is_empty() and not calm and t >= LINEUP_AT and t < LINEUP_AT + extra()

## Which man's card is up (-1 none).
func card_index() -> int:
	if not in_lineup():
		return -1
	return clampi(int((t - LINEUP_AT) / float(CARD_TIME[level - 1])), 0, lineup.size() - 1)

func length() -> float:
	if calm:
		return CALM_TOTAL + (extra() if not sevens.is_empty() else 0.0)
	return TOTAL + extra()

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
	var open_at := 0.6 if calm else DOORS_AT
	if _cue("door", open_at):
		Sfx.play("turn", 0.55, -6.0)       # (the doors: a soft low whoosh)
	if _cue("hall", open_at + 0.2):
		Sfx.crowd(0.2)                     # (the pool's ambience coming through)
	if _cue("pool", 1.0 if calm else DOLLY_END - 0.3):
		Sfx.play("splash", 0.8, -12.0)
		Sfx.crowd(0.35)
	for i in sevens.size():
		if _cue("seven%d" % i, seven_at(i)):
			Sfx.play("card", 1.2, -6.0)
	if _cue("vs", (1.1 if calm else MATCHUP_AT) + (extra() if not sevens.is_empty() else 0.0)):
		Sfx.play("card", 1.0, -6.0)

# ------------------------------------------------------------------ where we are
static func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)

## How open the doors are, 0..1.
func open_amount() -> float:
	if calm:
		return 0.0 if t < 0.6 else 1.0
	return _ease((t - DOORS_AT) / (OPEN_END - DOORS_AT))

## How far in we've walked: the hallway's scale (1 .. DOLLY_ZOOM), easing in like a step forward.
func dolly() -> float:
	if calm:
		return 1.0
	var u := clampf((t - OPEN_END + 0.25) / (DOLLY_END - OPEN_END + 0.25), 0.0, 1.0)
	return lerpf(1.0, DOLLY_ZOOM, u * u)

## The hallway's gone (we're through the doors).
func through() -> bool:
	return (t >= 1.0) if calm else (dolly() >= DOLLY_ZOOM - 0.01)

## The reveal's progress, 0 (the whole pool) .. 1 (the game's camera).
func reveal() -> float:
	if calm:
		return 1.0
	return _ease((_tl() - (DOLLY_END - 0.4)) / (REVEAL_END - DOLLY_END + 0.4))

## The matchup panel: 0 hidden .. 1 in place.
func matchup() -> float:
	var at := 1.1 if calm else MATCHUP_AT
	var out := TOTAL - 0.3
	var tl := _tl()
	if tl < at:
		return 0.0
	if calm:
		return 1.0
	if tl > out:
		return 1.0 - _ease((tl - out) / 0.3)
	return _ease((tl - at) / 0.3)

## What's on screen now, for Developer Mode and the tests.
func stage() -> String:
	if in_showcase():
		return "HOME SEVEN" if seven_index() == 0 else "AWAY SEVEN"
	if calm and sevens.is_empty():
		return "DOORS" if t < 0.6 else ("OPEN" if t < 1.0 else "MATCHUP")
	if calm:
		return "DOORS" if t < 0.6 else "MATCHUP" if t >= CALM_SHOW_AT else "OPEN"
	if t < DOORS_AT:
		return "CLOSED"
	if t < OPEN_END:
		return "OPENING"
	if not through():
		return "DOORWAY"
	if in_lineup():
		return "LINEUP"
	if _tl() < MATCHUP_AT:
		return "REVEAL"
	return "MATCHUP"

# ------------------------------------------------------------------ drawing
func draw(ci: CanvasItem, size: Vector2) -> void:
	if not _covered():
		_pool(ci, size)
	if not through():
		_hallway(ci, size)
	elif level >= 2 and not calm:
		_fx.lights(ci, size, t, 1.0 if level >= 3 else 0.7)
	if in_lineup():
		_card(ci, size)
	if in_showcase():
		_showcase(ci, size)
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
	PoolArt.draw_pool(ci, _rv, t, size, 0.2 if level < 2 else 0.8, pool, crowd, {}, style)
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

## The hallway around the doorway, scaled about the centre by the walk (dolly).
func _hallway(ci: CanvasItem, size: Vector2) -> void:
	var z := dolly()
	var c := Vector2(roundf(size.x * 0.5), roundf(size.y * 0.5))
	var P := func(v: Vector2) -> Vector2: return (c + (v - c) * z).round()
	# the doorway, before the walk: 150 x 160, its foot well down the screen
	var ow := 150.0
	var oh := 160.0
	var o0 := Vector2(c.x - ow * 0.5, size.y * 0.86 - oh)
	var tl: Vector2 = P.call(o0)
	var br: Vector2 = P.call(o0 + Vector2(ow, oh))
	var o := Rect2(tl, br - tl)
	# walls, ceiling and floor round the doorway (the doorway itself left open)
	ci.draw_rect(Rect2(0, 0, size.x, maxf(0.0, o.position.y)), WALL)
	ci.draw_rect(Rect2(0, o.position.y, maxf(0.0, o.position.x), o.size.y), WALL)
	ci.draw_rect(Rect2(o.end.x, o.position.y, maxf(0.0, size.x - o.end.x), o.size.y), WALL)
	# wall panels: seams every so often, a lighter band at handle height, a metal baseboard
	var seam := 48.0 * z
	var sx0 := fposmod(c.x - ow * 0.5 * z, seam)
	var x := sx0
	while x < size.x:
		if x < o.position.x - 2 or x > o.end.x + 2:
			ci.draw_rect(Rect2(roundf(x), 0, 1, o.end.y), SEAM)
		x += seam
	var band_y: float = P.call(Vector2(0, o0.y + oh * 0.55)).y
	ci.draw_rect(Rect2(0, band_y, maxf(0.0, o.position.x), maxf(1.0, roundf(3 * z))), WALL_LO)
	ci.draw_rect(Rect2(o.end.x, band_y, maxf(0.0, size.x - o.end.x), maxf(1.0, roundf(3 * z))), WALL_LO)
	var floor_top := o.end.y
	ci.draw_rect(Rect2(0, floor_top, size.x, maxf(0.0, size.y - floor_top)), FLOOR_A)
	ci.draw_rect(Rect2(0, floor_top - maxf(1.0, roundf(2 * z)), maxf(0.0, o.position.x), maxf(1.0, roundf(2 * z))), METAL)
	ci.draw_rect(Rect2(o.end.x, floor_top - maxf(1.0, roundf(2 * z)), maxf(0.0, size.x - o.end.x), maxf(1.0, roundf(2 * z))), METAL)
	# floor tiles: rows that widen towards us, lines running to the doors
	var row := 0
	var y := floor_top
	var hgt := 3.0 * z
	while y < size.y:
		if row % 2 == 1:
			ci.draw_rect(Rect2(0, roundf(y), size.x, maxf(1.0, roundf(hgt))), FLOOR_B)
		y += hgt
		hgt *= 1.55
		row += 1
	for i in range(-6, 7):
		var foot := Vector2(c.x + i * ow / 6.0 * z, floor_top)
		var far := Vector2(c.x + i * ow * 1.3 * z, size.y + 40)
		ci.draw_line(foot, far, FLOOR_LINE, 1.0)
	# light from the pool across the floor, more as the doors open
	var a := open_amount()
	if a > 0.0:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(o.position.x, floor_top), Vector2(o.end.x, floor_top),
			Vector2(o.end.x + o.size.x * 0.6, size.y), Vector2(o.position.x - o.size.x * 0.6, size.y)]), Color(SPILL, SPILL.a * a))
	# ceiling lights and the sign over the doors
	for i in 3:
		var lx: float = P.call(Vector2(c.x - 120 + i * 120, 0)).x
		var ly: float = P.call(Vector2(0, o0.y - 34)).y
		ci.draw_rect(Rect2(lx - 14 * z, ly, 28 * z, maxf(1.0, 2 * z)), LIGHT)
	if z < 1.6:
		var sign := (venue if venue != "" else "AQUATIC CENTER").to_upper()
		var sy: float = P.call(Vector2(0, o0.y - 14)).y
		Deck.ctext(ci, Rect2(0, sy - 5, size.x, 10), Deck.fit(sign, size.x - 40), 8, UI.ACCENT)
	# the frame
	var fw := maxf(2.0, roundf(5.0 * z))
	ci.draw_rect(Rect2(o.position.x - fw, o.position.y - fw, o.size.x + fw * 2, fw), METAL)
	ci.draw_rect(Rect2(o.position.x - fw, o.position.y, fw, o.size.y), METAL)
	ci.draw_rect(Rect2(o.end.x, o.position.y, fw, o.size.y), METAL)
	ci.draw_rect(Rect2(o.position.x - fw, o.position.y - fw, o.size.x + fw * 2, 1), METAL_HI)
	ci.draw_rect(Rect2(o.position.x - 1, o.position.y, 1, o.size.y), METAL_HI)
	# the doors
	_door(ci, o, -1, home, a, z)
	_door(ci, o, 1, away, a, z)

## One door: `side` -1 the left (hinged on the doorway's left), +1 the right; `a` how open.
## It turns towards us on its hinge: its free edge comes in and grows a little taller.
func _door(ci: CanvasItem, o: Rect2, side: int, team: PoloTeam, a: float, z: float) -> void:
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
	ci.draw_colored_polygon(poly, GLASS)
	# the glint running across the glass
	var g := fposmod(t * 0.6 + (0.0 if side < 0 else 0.5), 1.0)
	for k in 2:
		var u := clampf(g + k * 0.12, 0.0, 1.0)
		var top := h0.lerp(f0, clampf(u + 0.15, 0.0, 1.0))
		var bot := h1.lerp(f1, u)
		ci.draw_line(top, bot, GLINT, 1.0)
	# its logo, a decal on the glass, turning with the door
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
	ci.draw_polyline(PackedVector2Array([h0, f0, f1, h1, h0]), METAL, fw)
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
	if level >= 4:
		ci.draw_rect(Rect2(x - 3, y - 3, w + 6, h + 6), UI.GOLD, false, 1.0)
	var pop := 0.0 if level < 2 or calm else roundf(sin(clampf((t - MATCHUP_AT - extra()) / 0.3, 0.0, 1.0) * PI) * 3.0)
	TeamLogo.draw_in(ci, Rect2(x + 6, top + 2 - pop, lw, 36), home)
	TeamLogo.draw_in(ci, Rect2(x + w - 6 - lw, top + 2 - pop, lw, 36), away)
	var col_w := (w - lw * 2 - 12 - 30) * 0.5
	var hn := Colleges.display_name(home.name).to_upper()
	var an := Colleges.display_name(away.name).to_upper()
	Deck.ctext(ci, Rect2(x + 6 + lw, top + 8, col_w, 10), Deck.fit(hn, col_w - 4), 8, Color.WHITE)
	Deck.ctext(ci, Rect2(x + w - 6 - lw - col_w, top + 8, col_w, 10), Deck.fit(an, col_w - 4), 8, Color.WHITE)
	Deck.ctext(ci, Rect2(x + 6 + lw + col_w, top + 10, 30, 16), "VS", 16, UI.GOLD, "big")
	Deck.ctext(ci, Rect2(x + 6 + lw, top + 20, col_w, 10), "HOME", 8, UI.DIM)
	Deck.ctext(ci, Rect2(x + w - 6 - lw - col_w, top + 20, col_w, 10), "AWAY", 8, UI.DIM)

## The man being introduced: his real portrait, number, name and position, his team's flag.
func _card(ci: CanvasItem, size: Vector2) -> void:
	var e: Array = lineup[card_index()]
	var p: PoloPlayer = e[0]
	var tm: PoloTeam = e[1]
	var ct := float(CARD_TIME[level - 1])
	var u := fposmod(t - LINEUP_AT, ct) / ct
	var w := minf(size.x - 16.0, 300.0)
	var h := 52.0
	var x := roundf((size.x - w) * 0.5 + (0.0 if u > 0.2 else (0.2 - u) * -200.0))
	var y := size.y - h - 20.0
	Deck.frame(ci, Rect2(x, y, w, h), Color("0b1d5c"), Color.WHITE)
	ci.draw_rect(Rect2(x + 1, y + 1, 6, h - 2), tm.c1)
	ci.draw_rect(Rect2(x + 7, y + 1, 2, h - 2), tm.c2)
	Portrait.draw_zoomed(ci, Vector2(x + 34, y + 4), p, tm, Vector2i(42, 44))
	Deck.text(ci, x + 60, y + 15, "#%d  %s %s" % [p.number, p.first.to_upper(), p.last.to_upper()], 8, Color.WHITE)
	Deck.text(ci, x + 60, y + 29, p.pos_long().to_upper(), 8, UI.ACCENT)
	Deck.text(ci, x + 60, y + 41, Colleges.display_name(tm.name).to_upper(), 8, UI.GOLD)
	TeamLogo.draw_in(ci, Rect2(x + w - 44, y + 8, 40, 36), tm)

## A Starting Seven graphic fills the screen now (nothing behind it to draw).
func _covered() -> bool:
	if not in_showcase():
		return false
	var st := t - show_from()
	return calm or (st >= SHOW_WIPE and st < extra() - SHOW_WIPE)

## Level 4's centrepiece: the graphic that's up, and the columns in, between and out.
func _showcase(ci: CanvasItem, size: Vector2) -> void:
	var i := seven_index()
	var st := t - show_from()
	if _covered():
		_seven(ci, size, sevens[i], 99.0 if calm else t - seven_at(i))
	if calm:
		return
	var w := SHOW_WIPE
	var end := extra()
	var gap := st - SHOW_TIME
	var u := 0.0
	if st < w * 2.0:
		u = 1.0 - absf(st / w - 1.0)
	elif st > end - w * 2.0:
		u = 1.0 - absf((end - st) / w - 1.0)
	elif gap >= 0.0 and gap < SHOW_GAP:
		u = 1.0 - absf(gap / SHOW_GAP * 2.0 - 1.0)
	if u > 0.0:
		ReplayShow.columns(ci, size, u)

## The size the faces are drawn at on a screen this big: all seven always fit, across.
static func face_size(size: Vector2) -> Vector2i:
	for s: Vector2i in FACE_SIZES:
		if _row_w(s) <= size.x - 8.0 and s.y + 60.0 <= size.y:
			return s
	return FACE_SIZES[FACE_SIZES.size() - 1]

static func _row_w(s: Vector2i) -> float:
	return (s.x + 6.0) * 7.0 + (4.0 if s.x >= 52 else 2.0) * 6.0

## The very picture the Roster and the player page show of him.
static func face(p: PoloPlayer, tm: PoloTeam, s: Vector2i) -> Texture2D:
	var col := Portrait.colors_ours(p, tm)
	if s.x % Portrait.SIZE.x == 0 and s.y % Portrait.SIZE.y == 0:
		return Portrait.texture(p, col[0], col[1])
	return Portrait.texture_zoomed(p, col[0], col[1], s)

## One team's graphic, `lt` s after it began: the logo, the name, the heading, then the seven as one.
func _seven(ci: CanvasItem, size: Vector2, s: Dictionary, lt: float) -> void:
	var tm: PoloTeam = s.team
	var men: Array = s.men
	ci.draw_rect(Rect2(Vector2.ZERO, size), UI.INK)
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color("0b1d5c"))
	if not calm:
		for sx: float in [size.x * 0.2, size.x * 0.8]:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(sx - 4, 0), Vector2(sx + 4, 0), Vector2(size.x * 0.5 + 70, size.y), Vector2(size.x * 0.5 - 70, size.y)]), Color(1, 1, 0.9, 0.07))
	ci.draw_rect(Rect2(0, 0, size.x, 5), tm.c1)
	ci.draw_rect(Rect2(0, 5, size.x, 2), tm.c2)
	ci.draw_rect(Rect2(0, size.y - 7, size.x, 2), tm.c2)
	ci.draw_rect(Rect2(0, size.y - 5, size.x, 5), tm.c1)
	var fs := face_size(size)
	var big := fs.x >= 52
	var cw := fs.x + 6.0
	var ch := fs.y + (18.0 if big else 15.0)
	var gap := 4.0 if big else 2.0
	var stacked := size.y >= 210.0
	var name := Deck.fit(Colleges.display_name(tm.name).to_upper(), size.x - (24.0 if stacked else 70.0), 16, "big")
	var head_h := 104.0 if stacked else 38.0
	var top := floorf((size.y - head_h - 6.0 - ch) * 0.5)
	var logo_in := _ease(lt / 0.2)
	var slide := 0.0 if calm else roundf((1.0 - logo_in) * -14.0)
	if stacked:
		TeamLogo.draw_in(ci, Rect2(floorf((size.x - 60.0) * 0.5), top + slide, 60, 60), tm)
		if lt >= 0.12:
			Deck.shadow_text(ci, 0, top + 74, name, 16, Color.WHITE, "big", HORIZONTAL_ALIGNMENT_CENTER, size.x)
		if lt >= 0.2:
			Deck.ctext(ci, Rect2(0, top + 87, size.x, 12), "STARTING SEVEN", 8, UI.GOLD)
	else:
		var tw := maxf(Deck.text_w(name, 16, "big"), Deck.text_w("STARTING SEVEN"))
		var lx := floorf((size.x - tw - 46.0) * 0.5)
		TeamLogo.draw_in(ci, Rect2(lx, top + slide, 40, 36), tm)
		if lt >= 0.12:
			Deck.shadow_text(ci, lx + 46, top + 11, name, 16, Color.WHITE, "big")
		if lt >= 0.2:
			Deck.text(ci, lx + 46, top + 27, "STARTING SEVEN", 8, UI.GOLD)
	var row_w := cw * men.size() + gap * (men.size() - 1)
	var x0 := floorf((size.x - row_w) * 0.5)
	var y0 := top + head_h + 6.0
	for i in men.size():
		var k := 1.0 if calm else _ease((lt - 0.26 - i * 0.025) / 0.16)
		if k <= 0.0:
			continue
		_face_card(ci, Rect2(x0 + i * (cw + gap), y0 + roundf((1.0 - k) * 16.0), cw, ch), men[i], tm, i == 0, fs, big)
	if not calm and lt > 0.75 and lt < 1.2:   # the light across the row, once
		var sx0 := lerpf(x0 - 30.0, x0 + row_w + 10.0, (lt - 0.75) / 0.45)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(sx0 + 20, y0), Vector2(sx0 + 34, y0), Vector2(sx0 + 14, y0 + ch), Vector2(sx0, y0 + ch)]), Color(1, 1, 1, 0.16))

## One man's frame: his face on his team's colour, his cap number and name. The goal's is gold.
func _face_card(ci: CanvasItem, r: Rect2, p: PoloPlayer, tm: PoloTeam, gk: bool, fs: Vector2i, big: bool) -> void:
	ci.draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(tm.c2, 0.75))
	Deck.frame(ci, r, Deck.NAVY, UI.GOLD if gk else Color.WHITE)
	var pic := Rect2(r.position + Vector2(3, 3), Vector2(fs))
	ci.draw_rect(pic, tm.c1.darkened(0.55))
	ci.draw_rect(Rect2(pic.position, Vector2(pic.size.x, 2)), tm.c1)
	ci.draw_texture_rect(face(p, tm, fs), pic, false)
	var ly := pic.end.y + (8.0 if big else 6.0)
	var num := str(p.number)
	if big:
		Deck.text(ci, r.position.x + 4, ly, num, 8, UI.GOLD)
		var nx := r.position.x + 7 + Deck.text_w(num)
		Deck.text(ci, nx, ly, Deck.fit(p.last.to_upper(), r.end.x - nx - 3), 8, Color.WHITE)
	else:
		Deck.ctext(ci, Rect2(r.position.x, ly - 5, r.size.x, 10), num, 8, UI.GOLD)
	if gk:
		var w := Deck.text_w("GK") + 4
		ci.draw_rect(Rect2(pic.end.x - w, pic.position.y, w, 10), UI.GOLD)
		Deck.text(ci, pic.end.x - w + 2, pic.position.y + 5, "GK", 8, UI.INK)

## The text of the matchup (tests, the lab).
func matchup_text() -> String:
	return "%s %s VS %s" % [label, Colleges.display_name(home.name).to_upper(), Colleges.display_name(away.name).to_upper()]

## The designation for a career game: REGULAR SEASON, CONFERENCE TOURNAMENT or NCSA CHAMPIONSHIP.
static func label_for(round: Dictionary, g: Dictionary = {}) -> String:
	var kind := String(round.get("kind", ""))
	if g.has("k"):
		return "NCSA DIVISION III CHAMPIONSHIP"
	if kind.begins_with("conf_"):
		return "CONFERENCE TOURNAMENT"
	if kind.begins_with("nat_"):
		return "NCSA CHAMPIONSHIP"
	return "REGULAR SEASON"
