class_name GoalFx
extends RefCounted
## THE GOAL CELEBRATION UPGRADES (the Premium Visual Upgrades update): what the worn Goal
## Celebrations level adds over the goal show (GoalShow), for any goal in a game you play. Level 1
## adds nothing: the classic show, BAR-DOWN! and BAR-IN! are everybody's.
##   Level 2 SHOWTIME    bigger GOAL!, stronger splashes, a brief shake, small confetti
##   Level 3 SUPERSTAR   + arena lights, larger confetti, a spotlight on the scorer, a louder crowd
##   Level 4 LEGENDARY   + fireworks, lasers, flashes, confetti everywhere, a massive GOAL!; more
##                       of all of it for a game winner
## It runs inside the show's own time and adds none: the goal, the clocks and the restart don't
## know it's there. Drawn from the show's clock alone, in whole pixels, nothing kept per particle.
## Reduce Motion (calm): no shake or flashes, the lights and lasers stand still, less confetti.

const GOLD := Color("ffd83d")
const CYAN := Color("45dfff")
const PINK := Color("ff6fae")
const WORD_ADD := [0, 4, 8, 16]         # GOAL!'s size added, by level
const CONFETTI := [0, 44, 100, 210]
const DROPS := [0, 12, 18, 26]
const SHAKE := [0.0, 1.0, 1.15, 1.5]
const EXCITE := [0.0, 0.0, 1.3, 1.7]

var level := 1
var calm := false
var c1 := Color.WHITE
var c2 := Color.BLACK
var show: GoalShow = null
var _cues := {}

## A goal: the level worn, the scoring team's own colours.
func start(lv: int, p_show: GoalShow, p_c1: Color, p_c2: Color, p_calm: bool) -> void:
	level = clampi(lv, 1, VisualUpgrades.MAX_LEVEL)
	show = p_show
	c1 = p_c1
	c2 = p_c2
	calm = p_calm
	_cues = {}
	show.word_add = WORD_ADD[level - 1]

func clear() -> void:
	show = null

func active() -> bool:
	return show != null and show.active() and level >= 2

func winner() -> bool:
	return show != null and show.kind == "winner"

## What this level draws, for the tests and Developer Mode.
func parts() -> Dictionary:
	var n: int = CONFETTI[level - 1]
	return {"confetti": n / 2 if calm else n, "drops": DROPS[level - 1], "lights": level >= 3, "spot": level >= 3, "lasers": 6 if level >= 4 else 0,
		"fireworks": (0 if level < 4 else (8 if winner() else 5)) - (2 if calm and level >= 4 else 0), "flash": level >= 4 and not calm, "shake": level >= 2 and not calm}

## A frame: the shake and the sounds at their cues.
func tick(view: PoolView) -> void:
	if not active() or show.t < GoalShow.IMPACT_AT or _cues.has("hit"):
		return
	_cues["hit"] = true
	if view != null and not calm:
		view.shake = maxf(view.shake, float(SHAKE[level - 1]))
	if level >= 3:
		Sfx.play("cheer", 1.0, -4.0)
	if level >= 4:
		Sfx.play("bang", 0.7, -12.0)

## A fixed 0..1 for (`a`, `b`).
static func _n(a: int, b: int) -> float:
	var v := sin(float(a) * 12.9898 + float(b) * 78.233) * 43758.5453
	return v - floorf(v)

func _col(i: int) -> Color:
	return [c1, c2, GOLD, Color.WHITE][i % 4]

## Everything under the show's words.
func draw(ci: CanvasItem, size: Vector2, v: PoolView) -> void:
	if not active() or show.t < GoalShow.IMPACT_AT - 0.05:
		return
	var t := show.t
	var fade := 1.0 - clampf((t - show.out_at()) / GoalShow.OUT, 0.0, 1.0)
	var p := parts()
	if bool(p.lights):
		lights(ci, size, t, fade)
	if bool(p.spot) and show.hero != null and v != null:
		_spot(ci, v, t, fade)
	if int(p.lasers) > 0:
		_lasers(ci, size, t, int(p.lasers), fade)
	if v != null:
		_splash(ci, v, t, int(p.drops))
	if int(p.fireworks) > 0:
		fireworks(ci, size, t, int(p.fireworks))
	confetti(ci, size, t, int(p.confetti), fade)
	if bool(p.flash):
		for at in [GoalShow.IMPACT_AT, GoalShow.IMPACT_AT + 0.16, GoalShow.IMPACT_AT + 0.34]:
			if t >= at and t < at + 0.05:
				ci.draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.22))

func confetti(ci: CanvasItem, size: Vector2, t: float, n: int, fade: float) -> void:
	for i in int(n * fade):
		var u := t - GoalShow.IMPACT_AT - 0.2 * _n(i, 1)
		if u < 0.0:
			continue
		var x := roundf(_n(i, 2) * size.x + sin(u * 3.0 + i) * 7.0)
		var y := roundf(-6.0 + u * (70.0 + 80.0 * _n(i, 3)))
		if y > size.y:
			continue
		var flip := (int(u * 9.0) + i) % 2 == 0
		var big := 1 if level >= 3 and i % 3 == 0 else 0
		ci.draw_rect(Rect2(x, y, (3 if flip else 2) + big, (2 if flip else 3) + big), _col(i))

## Water thrown up off the goal line.
func _splash(ci: CanvasItem, v: PoolView, t: float, n: int) -> void:
	var u := t - GoalShow.IMPACT_AT + 0.25
	if u < 0.0 or u > 0.7 or n <= 0:
		return
	var p := v.to_screen(show.mouth)
	var away := -1.0 if show.mouth.x > Geo.HALF else 1.0
	for i in n:
		var sp := 30.0 + 70.0 * _n(i, 4)
		var a := -PI * 0.5 + (_n(i, 5) - 0.3) * 1.2 * away
		var q := p + Vector2(cos(a), sin(a)) * sp * u + Vector2(0, 150.0 * u * u)
		ci.draw_rect(Rect2(roundf(q.x), roundf(q.y), 2 if i % 3 == 0 else 1, 1), Color.WHITE if i % 2 == 0 else UI.WATER_SHINE)

## Arena lights: beams from the roof, sweeping (standing still when calm).
func lights(ci: CanvasItem, size: Vector2, t: float, fade: float) -> void:
	var n := 4 if level >= 4 else 2
	for i in n:
		var from := Vector2(size.x * (float(i) + 0.5) / n, -4.0)
		var sw := 0.0 if calm else sin(t * 2.2 + i * 1.7)
		var to := from.x + sw * size.x * 0.3
		var col := (c1 if i % 2 == 0 else Color.WHITE).lightened(0.2)
		ci.draw_colored_polygon(PackedVector2Array([from, Vector2(to - 26, size.y), Vector2(to + 26, size.y)]), Color(col, 0.16 * fade))

## The scorer in a pool of light, a gold ring on the water round him.
func _spot(ci: CanvasItem, v: PoolView, t: float, fade: float) -> void:
	if t < GoalShow.CELEBRATE_AT:
		return
	var o := v.to_screen(show.hero.pos)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(o.x - 3, -4), Vector2(o.x + 3, -4), Vector2(o.x + 20, o.y + 5), Vector2(o.x - 20, o.y + 5)]), Color(1, 1, 0.9, 0.16 * fade))
	PoolArt.draw_ellipse_ring(ci, (o + Vector2(0, 3)).round(), 18, 6, GOLD, 1)

func _lasers(ci: CanvasItem, size: Vector2, t: float, n: int, fade: float) -> void:
	if fade <= 0.3:
		return
	for i in n:
		var from := Vector2(size.x * (i + 0.5) / n, 0.0)
		var sw := 0.5 if calm else 0.5 + 0.5 * sin(t * 3.4 + i * 1.1)
		var to := Vector2(size.x * sw, size.y * (0.55 + 0.4 * _n(i, 6)))
		ci.draw_line(from, to, [CYAN, PINK, GOLD, c1][i % 4], 1.0)

func fireworks(ci: CanvasItem, size: Vector2, t: float, n: int) -> void:
	for k in n:
		var at := GoalShow.IMPACT_AT + 0.02 + k * 0.17
		var u := t - at
		if u < 0.0 or u > 1.0:
			continue
		var c := Vector2(roundf(size.x * (0.12 + 0.76 * _n(k, 7))), roundf(size.y * (0.14 + 0.3 * _n(k, 8))))
		var col: Color = [GOLD, c1, CYAN, PINK, Color.WHITE][k % 5]
		if u < 0.25:
			var y := lerpf(size.y, c.y, u / 0.25)
			ci.draw_rect(Rect2(c.x, roundf(y), 1, 3), GOLD)
			continue
		var b := u - 0.25
		for i in 28:
			var a := TAU * i / 28.0
			var q := c + Vector2(cos(a), sin(a)) * (92.0 * b * (0.55 + 0.45 * _n(i, k))) + Vector2(0, 40.0 * b * b)
			var sz := 3 if b < 0.25 else (2 if b < 0.5 else 1)
			ci.draw_rect(Rect2(roundf(q.x), roundf(q.y), sz, sz), col if i % 3 != 0 else Color.WHITE)
