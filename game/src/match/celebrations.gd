class_name Celebrations
extends RefCounted
## WHAT THE PLAYERS DO WHEN THEY CELEBRATE: the free poses everybody has. Art only: a Swimmer's
## cheer_style is read by nothing but his drawing, and the pick is a hash of the moment, never the
## match's dice.

const FREE := ["", "both", "wave"]     # "": the fist punched up

## The pose for goal number `n` of this match.
static func pick(n: int) -> String:
	return String(FREE[posmod(hash(n * 2654435 + FREE.size()), FREE.size())])

## The scorer in `style`.
static func apply(show: GoalShow, style: String) -> void:
	if show.hero != null:
		show.hero.cheer_style = style

## Draws his arms for `s.cheer_style`. False: the normal art.
static func draw_pose(px: Callable, s: Swimmer, skin: Color) -> bool:
	var k := int(Time.get_ticks_msec() / 140.0) % 2
	match s.cheer_style:
		"both":
			px.call(4, -17, 2, 13, skin)
			px.call(-6, -17, 2, 13, skin)
		"wave":
			px.call(4 + k * 2, -18, 2, 14, skin)
			px.call(-9, -4, 3, 1, skin)
		_:
			return false
	return true
