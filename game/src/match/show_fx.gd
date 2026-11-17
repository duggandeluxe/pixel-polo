class_name ShowFx
extends RefCounted
## Screen-wide party effects for the big presentations (PregameIntro's
## arena lights), at that presentation's own level (1-4). Drawn from a clock alone,
## in whole pixels, nothing kept per particle. Reduce Motion (calm): the lights stand still.
## (Goal Celebrations have their own, at the goal: GoalFx.)

const GOLD := Color("ffd83d")
const START := 0.25     # the clock's zero: the effects open this far in (GoalShow.IMPACT_AT, as ever)

var level := 1
var calm := false
var c1 := Color.WHITE
var c2 := Color.BLACK

## A fixed 0..1 for (`a`, `b`).
static func _n(a: int, b: int) -> float:
	var v := sin(float(a) * 12.9898 + float(b) * 78.233) * 43758.5453
	return v - floorf(v)

func _col(i: int) -> Color:
	return [c1, c2, GOLD, Color.WHITE][i % 4]

## Confetti falling over the whole screen, `n` pieces.
func confetti(ci: CanvasItem, size: Vector2, t: float, n: int, fade: float) -> void:
	for i in int(n * fade):
		var u := t - START - 0.2 * _n(i, 1)
		if u < 0.0:
			continue
		var x := roundf(_n(i, 2) * size.x + sin(u * 3.0 + i) * 7.0)
		var y := roundf(-6.0 + u * (70.0 + 80.0 * _n(i, 3)))
		if y > size.y:
			continue
		var flip := (int(u * 9.0) + i) % 2 == 0
		var big := 1 if level >= 3 and i % 3 == 0 else 0
		ci.draw_rect(Rect2(x, y, (3 if flip else 2) + big, (2 if flip else 3) + big), _col(i))

## Arena lights: beams from the roof, sweeping (standing still when calm).
func lights(ci: CanvasItem, size: Vector2, t: float, fade: float) -> void:
	var n := 4 if level >= 4 else 2
	for i in n:
		var from := Vector2(size.x * (float(i) + 0.5) / n, -4.0)
		var sw := 0.0 if calm else sin(t * 2.2 + i * 1.7)
		var to := from.x + sw * size.x * 0.3
		var col := (c1 if i % 2 == 0 else Color.WHITE).lightened(0.2)
		ci.draw_colored_polygon(PackedVector2Array([from, Vector2(to - 26, size.y), Vector2(to + 26, size.y)]), Color(col, 0.16 * fade))
