class_name DeckPanel
extends MarginContainer
## A Deck Blue panel: a 1 px border with cut corners and its title sitting in the top border.
## Children go inside like any MarginContainer. Doesn't take touches, so lists still scroll through it.

const TITLE_PAD := 3          # space either side of the title in the border
const BORDER_Y := 4           # the top border line sits this far down when there is a title

var title := ""
var fill := Color(0, 0, 0, 0)
var border := UI.BORDER

func _init(t: String = "", f: Color = Color(0, 0, 0, 0)) -> void:
	title = t
	fill = f
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("margin_left", 6)
	add_theme_constant_override("margin_right", 6)
	add_theme_constant_override("margin_top", 10 if t != "" else 5)
	add_theme_constant_override("margin_bottom", 5)

func _draw() -> void:
	var top := float(BORDER_Y) if title != "" else 0.0
	var r := Rect2(0, top, floorf(size.x), floorf(size.y) - top)
	if fill.a > 0.0:
		draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), fill)
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	# sides and bottom (corners left out for the pixel-art cut)
	draw_rect(Rect2(x0, y0 + 1, 1, r.size.y - 2), border)
	draw_rect(Rect2(x1 - 1, y0 + 1, 1, r.size.y - 2), border)
	draw_rect(Rect2(x0 + 1, y1 - 1, r.size.x - 2, 1), border)
	if title == "":
		draw_rect(Rect2(x0 + 1, y0, r.size.x - 2, 1), border)
		return
	var tw := Deck.text_w(title)
	var tx := floorf(x0 + (r.size.x - tw) * 0.5)
	# the top border in two pieces with the title in the gap
	draw_rect(Rect2(x0 + 1, y0, maxf(0.0, tx - TITLE_PAD - x0 - 1), 1), border)
	var gx := tx + tw + TITLE_PAD
	draw_rect(Rect2(gx, y0, maxf(0.0, x1 - 1 - gx), 1), border)
	Deck.text(self, tx, y0 + 0.5, title, 8, UI.TEXT)
