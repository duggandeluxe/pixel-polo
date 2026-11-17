extends Control
## Coaching's playbook: a still, top-down whiteboard of the picked drop (the Coaching screen's PICK
## YOUR DEFENSE). Only X's, O's and arrows: the goal at the top, the attack's 6 on 6 umbrella
## (PlaySetup.HOME_6V6) as O's, the defence as X's, and each man the drop puts between two attackers
## (the splitters, the droppers between their man and the centre) halfway between them, an arrow
## out to each of the two.
##
## Everybody else stands where DefenseFormation puts him (the same formulas and constants:
## sag_spot, deny_spot, the wing pressure, the centre's guard behind), read with the ball on the
## right wing ("1"; the 5 DROP's on the "4", next to the man it gives up), which isn't drawn.
## Nothing here touches a match.

const F := DefenseFormation.F
const BALL := "1"
const BALL_FIVE := "4"
const TAGS := ["1", "2", "3", "4", "5", "C"]
## Who's between whom, each drop: [defender, attacker, attacker].
const SPLITS := {
	F.M_DROP: [["2", "2", "3"], ["4", "4", "3"]],   # (D3 isn't splitting: he's on the centre, fronting him)
	F.FOUR_FIVE: [["4", "4", "C"], ["5", "5", "C"]],
	F.FIVE_DROP: [["4", "4", "5"]],   # (D5 is on the centre; D4 splits his man and A5)
	F.THREE_FOUR: [["3", "3", "C"], ["4", "4", "C"]],
}

# the view: the attacking half nearest the goal, the goal at the top, as wide as the board allows
const X_TOP := 30.6
const X_BOT := 22.5
const HEAD_H := 11
const PAD := 4

const BOARD := Color("061234")
const WATER := Color("0a1f55")
const X_COL := Color("4f9bff")
const O_COL := Color("ffffff")
const ARROW := Color("56607a")       # a dark grey: the arrows sit back behind the X's and O's

var formation: int = F.M_DROP
var plan: Dictionary = {}

func setup(f: int) -> void:
	formation = f
	plan = build(f)
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if plan.is_empty():
		setup(formation)

# ------------------------------------------------------------------ the formation (DefenseFormation's spots)
static func _goal() -> Vector2:
	return Geo.goal_center()

## Goal side of `m`, `d` off him: man to man (DefenseFormation's own 1.1 m).
static func _gside(m: Vector2, d: float = 1.1) -> Vector2:
	return m + (_goal() - m).normalized() * d

static func _drop_spot(c: Vector2, b: Vector2) -> Vector2:
	return c + (b - c).normalized() * DefenseFormation.DROP_FRONT

static func _behind(c: Vector2, b: Vector2) -> Vector2:
	return c + ((_goal() - c).normalized() + (c - b).normalized()).normalized() * DefenseFormation.CENTER_BEHIND

static func _danger(at: Vector2) -> float:
	return OffenseAI.spot_quality(at) * (0.6 + 0.08 * 5.0)   # (an average Shooting)

static func _split(a1: Vector2, a2: Vector2, b: Vector2) -> Vector2:
	var w := 0.5 + clampf((_danger(a2) - _danger(a1)) * 2.0, -1.0, 1.0) * DefenseFormation.SPLIT_SHADE
	w += DefenseFormation.SPLIT_BALL * (1.0 if a2.distance_to(b) < a1.distance_to(b) else -1.0)
	var mid := a1.lerp(a2, clampf(w, 0.15, 0.85))
	return mid + (_goal() - mid).normalized() * DefenseFormation.SPLIT_SAG

static func _sag(m: Vector2, front: Vector2) -> Vector2:
	var man := _gside(m)
	var inward := front - man
	var sag := minf(inward.length() * DefenseFormation.FIVE_SAG, DefenseFormation.FIVE_SAG_MAX) * (1.0 - DefenseFormation.FIVE_HOLD * clampf(_danger(m), 0.0, 1.0))
	return man + inward.limit_length(sag)

static func _out_spot(m: Vector2, c: Vector2, front: Vector2, double: bool) -> Vector2:
	var man := _gside(m)
	if not double:
		return man.lerp(front, DefenseFormation.PISTON_SAG)
	var out := man - c
	var side := c + (out.normalized() if out.length() > 0.3 else Vector2.UP) * DefenseFormation.DOUBLE_SIDE
	var spot := man.lerp(side, DefenseFormation.DOUBLE_SAG)
	if spot.distance_to(front) < DefenseFormation.DOUBLE_SEP:
		spot = front + (spot - front).normalized() * DefenseFormation.DOUBLE_SEP
	return spot

static func _deny(m: Vector2, b: Vector2) -> Vector2:
	var along := (b - m).normalized()
	var side := along.orthogonal()
	if side.dot(_goal() - m) < 0.0:
		side = -side
	return m + along * DefenseFormation.WING_DENY_UP + side * DefenseFormation.WING_DENY_SIDE

## The picture for drop `f`: {att: tag -> spot, def: defender tag -> spot, splits (SPLITS[f])}.
static func build(f: int) -> Dictionary:
	var a := {}
	for k in TAGS:
		a[k] = PlaySetup.HOME_6V6[k]
	var ball := BALL_FIVE if f == F.FIVE_DROP else BALL
	var b: Vector2 = a[ball]
	var c: Vector2 = a["C"]
	var front := _drop_spot(c, b)
	var d := {}
	for k in TAGS:
		d[k] = _gside(a[k])                        # man to man, goal side
	d["C"] = _behind(c, b)                         # the centre's guard behind him
	match f:
		F.M_DROP, F.THREE_FOUR:                    # both wings pressed: the one with it tight, the other denied
			d["1"] = _gside(a["1"], DefenseFormation.WING_GAP)
			d["5"] = _deny(a["5"], b)
			if f == F.M_DROP:                      # D3 collapsed onto the centre, in front of him (no arrows)
				d["3"] = _drop_spot(c, a["3"])
		F.FIVE_DROP:
			for k in ["1", "2", "3"]:              # the rest of the perimeter tight on their men
				d[k] = _gside(a[k], DefenseFormation.WING_GAP)
			d["5"] = _drop_spot(c, a["5"])         # D5 fronting the centre, on the A5 side (no arrows)
	if f in [F.FOUR_FIVE, F.THREE_FOUR, F.FIVE_DROP]:   # the centre's guard round the right side of him, goal side
		var g: Vector2 = d["C"]
		d["C"] = Vector2(g.x, c.y + absf(g.y - c.y))
	var splits: Array = SPLITS.get(f, [])
	for s in splits:
		d[s[0]] = (a[s[1]] as Vector2).lerp(a[s[2]], 0.5)
	if f in MIRRORED:                                  # drawn the other way round, across the goal's centre line
		for k in TAGS:
			a[k] = _mirror(a[k])
			d[k] = _mirror(d[k])
	return {"att": a, "def": d, "splits": splits}

## The drops whose picture is flipped left to right (the ball on the left wing instead).
const MIRRORED := [F.FOUR_FIVE, F.FIVE_DROP, F.THREE_FOUR]

static func _mirror(m: Vector2) -> Vector2:
	return Vector2(m.x, 2.0 * Geo.GOAL_Y - m.y)

# ------------------------------------------------------------------ drawing
var _s := 7.0
var _o := Vector2.ZERO
var _y0 := 0.0
var _y1 := Geo.WIDTH

func _pt(m: Vector2) -> Vector2:
	return (_o + Vector2(m.y - _y0, X_TOP - m.x) * _s).round()

func _draw() -> void:
	if plan.is_empty():
		return
	var w := floorf(size.x)
	var h := floorf(size.y)
	Deck.frame(self, Rect2(0, 0, w, h), BOARD, Color(0.36, 0.78, 1.0, 0.7))
	Deck.text(self, PAD + 2, 7, String(DefenseFormation.NAMES[formation]), 8, UI.GOLD)
	var avail := Vector2(w - PAD * 2, h - HEAD_H - PAD)
	_s = maxf(2.0, floorf(minf(avail.x / 16.0, avail.y / (X_TOP - X_BOT)) * 2.0) / 2.0)
	var span := minf(Geo.WIDTH, avail.x / _s)      # as much of the pool across as fits, centred
	_y0 = Geo.GOAL_Y - span * 0.5
	_y1 = Geo.GOAL_Y + span * 0.5
	_o = Vector2(PAD + floorf((avail.x - roundf(span * _s)) * 0.5), HEAD_H)
	_pool()
	var a: Dictionary = plan.att
	for k in TAGS:
		_o_mark(_pt(a[k]), O_COL)
	for k in TAGS:
		_x_mark(_pt(plan.def[k]), X_COL)
	for s in plan.splits:
		var at := _pt(plan.def[s[0]])
		for m in [s[1], s[2]]:
			_arrow(at, _pt(a[m]), ARROW, 4.0, 4.0)

## The water and the goal.
func _pool() -> void:
	var top := _pt(Vector2(X_TOP, _y0))
	var bot := _pt(Vector2(X_BOT, _y1))
	draw_rect(Rect2(top, bot - top), WATER)
	# the goal: an open bracket, its back across the top and the posts down to the goal line, open to the pool
	var p1 := _pt(Vector2(Geo.GOAL_X, Geo.GOAL_Y - Geo.GOAL_HALF))
	var p2 := _pt(Vector2(Geo.GOAL_X, Geo.GOAL_Y + Geo.GOAL_HALF))
	var nb := _pt(Vector2(Geo.GOAL_X + Geo.NET_DEPTH, 0)).y
	draw_rect(Rect2(p1.x - 1, nb, p2.x - p1.x + 2, 2), O_COL)
	draw_rect(Rect2(p1.x - 1, nb, 2, p1.y - nb + 1), O_COL)
	draw_rect(Rect2(p2.x - 1, nb, 2, p1.y - nb + 1), O_COL)

# ------------------------------------------------------------------ pixels
func _px(at: Vector2, sz: Vector2, col: Color) -> void:
	draw_rect(Rect2(at.round(), sz), col)

## A 5 x 5 X, centred on `at`.
func _x_mark(at: Vector2, col: Color) -> void:
	for i in 5:
		_px(at + Vector2(i - 2, i - 2), Vector2.ONE, col)
		_px(at + Vector2(2 - i, i - 2), Vector2.ONE, col)

## A 5 x 5 O ring, centred on `at`.
func _o_mark(at: Vector2, col: Color) -> void:
	_px(at + Vector2(-1, -2), Vector2(3, 1), col)
	_px(at + Vector2(-1, 2), Vector2(3, 1), col)
	_px(at + Vector2(-2, -1), Vector2(1, 3), col)
	_px(at + Vector2(2, -1), Vector2(1, 3), col)

## One window pixel, in game pixels: on a DETAIL MODE screen (Game.set_detail) a third of one at
## the usual 3x; anywhere else, a whole one.
func _fine() -> float:
	var win := get_window()
	if win == null or win.content_scale_mode != Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
		return 1.0
	return 1.0 / maxf(1.0, floorf(float(win.size.y) / float(ProjectSettings.get_setting("display/window/size/viewport_height", 270))))

## A solid arrow from `a` to `b`, `from_gap` / `to_gap` game px clear of each end, its head at `b`:
## a line one window pixel wide, its head 2 game px long (finer than everything else here).
func _arrow(a: Vector2, b: Vector2, col: Color, from_gap: float, to_gap: float) -> void:
	var d := b - a
	var n := d.length()
	if n <= from_gap + to_gap + 2.0:
		return
	var k := _fine()
	var u := d / n
	var p0 := a + u * from_gap
	var p1 := b - u * to_gap
	_fline(p0, p1, col, k)
	for side: float in [-1.0, 1.0]:
		_fline(p1 - u * 2.0 + u.orthogonal() * 1.3 * side, p1, col, k)

## A line of `k` x `k` squares (`k` game px each) from `p0` to `p1`, on the `k` grid.
func _fline(p0: Vector2, p1: Vector2, col: Color, k: float) -> void:
	var steps := int(ceilf(maxf(absf(p1.x - p0.x), absf(p1.y - p0.y)) / k))
	for i in steps + 1:
		var q := p0.lerp(p1, float(i) / maxf(1.0, steps))
		draw_rect(Rect2((q / k).floor() * k, Vector2(k, k)), col)
