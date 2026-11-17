class_name SeasonBox
extends MarginContainer
## The Dynasty Hub's season tracker, top right: "2026-2027, WEEK 3" on a retro scoreboard plate.
## A navy board with a hard ink outline, a light-blue rim (white along the top), a drop shadow
## like the chunky buttons beside it, and the week on its own darker plate behind a gold divider.
## Everything is 1 px rects, so it stays crisp at any integer scale.

const NAVY := Color("0b1d5c")        # the board
const NAVY_HI := Color("1a3a8f")     # its top bevel row
const NAVY_LO := Color("071440")     # its bottom bevel row
const PLATE := Color("050d2e")       # behind the week
const RIM := Color("8fb4ff")         # the light-blue rim
const SHADOW_H := 2                  # px of drop shadow under the board (UI.chunky's)
const FRAME := 2                     # outline + rim

var _season: Label
var _week: Label
var _week_pad: MarginContainer
var _row: HBoxContainer

## season: "2026-2027,"; week: "WEEK 3" (or a phase, "ROSTER CUTS").
func _init(season: String = "", week: String = "") -> void:
	name = "SeasonBox"
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "The season and the week of it"
	add_theme_constant_override("margin_left", FRAME)
	add_theme_constant_override("margin_right", FRAME)
	add_theme_constant_override("margin_top", FRAME)
	add_theme_constant_override("margin_bottom", FRAME + SHADOW_H)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 0)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	var sp := _pad(5, 4)
	_season = UI.label(season, 8, UI.TEXT, "caps")
	_season.name = "Season"
	sp.add_child(_season)
	_row.add_child(sp)
	_week_pad = _pad(5, 5)
	_week = UI.label(week, 8, UI.GOLD, "caps")
	_week.name = "Week"
	_week_pad.add_child(_week)
	_row.add_child(_week_pad)
	resized.connect(queue_redraw)
	_row.sort_children.connect(queue_redraw)

func text() -> String:
	return "%s %s" % [_season.text, _week.text]

func _pad(l: int, r: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_top", 0)
	m.add_theme_constant_override("margin_bottom", 0)
	return m

func _draw() -> void:
	var w := floorf(size.x)
	var h := floorf(size.y) - SHADOW_H
	if w < 8 or h < 8:
		return
	# the drop shadow, under the board, corners notched
	draw_rect(Rect2(1, h, w - 2, SHADOW_H), UI.SHADOW)
	# the ink outline, corners notched (a pixel corner, not a rounded one)
	draw_rect(Rect2(1, 0, w - 2, h), UI.INK)
	draw_rect(Rect2(0, 1, w, h - 2), UI.INK)
	# the rim: white along the top, light blue down the sides and bottom
	draw_rect(Rect2(1, 1, w - 2, h - 2), RIM)
	draw_rect(Rect2(2, 1, w - 4, 1), UI.TEXT)
	# the board, with a bevel row top and bottom
	var inner := Rect2(FRAME, FRAME, w - FRAME * 2, h - FRAME * 2)
	draw_rect(inner, NAVY)
	draw_rect(Rect2(inner.position.x, inner.position.y, inner.size.x, 1), NAVY_HI)
	draw_rect(Rect2(inner.position.x, inner.end.y - 1, inner.size.x, 1), NAVY_LO)
	# the week's plate, behind a gold divider with a dark line beside it
	var px := floorf(_row.position.x + _week_pad.position.x)
	if _week.text != "" and px > inner.position.x and px < inner.end.x:
		var plate := Rect2(px, inner.position.y, inner.end.x - px, inner.size.y)
		draw_rect(plate, PLATE)
		draw_rect(Rect2(plate.position.x, plate.position.y, 1, plate.size.y), UI.GOLD)
		draw_rect(Rect2(plate.position.x + 1, plate.position.y, 1, plate.size.y), UI.INK)
		# gold studs where the divider meets the rim
		draw_rect(Rect2(px - 1, 1, 3, 1), UI.GOLD)
		draw_rect(Rect2(px - 1, h - 2, 3, 1), UI.GOLD)
	# gold studs in the board's top corners
	draw_rect(Rect2(inner.position.x, inner.position.y, 1, 1), UI.GOLD)
	draw_rect(Rect2(inner.end.x - 1, inner.position.y, 1, 1), UI.GOLD)
