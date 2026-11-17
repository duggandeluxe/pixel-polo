extends BaseScreen
## Developer Mode's ATTRIBUTE BAR EFFECTS (Settings > Developer Mode): every look the player page's
## ten-box attribute bar can take, drawn with the real Deck.attr_boxes, so the HOT fire and the
## injury can be judged side by side. HOT is half a burning box after his own, VERY HOT a whole
## one (Attributes.hot_bonus); injured boxes are plain red. Nothing here touches a career.

const BAR_H := 15
const LABEL_W := 150

## [name, note, attribute, ceiling, options]
const ROWS := [
	["NORMAL", "6/10, ceiling 8", 6.0, 8.0, {}],
	["HOT", "+0.5: half a box on fire", 6.0, 8.0, {"fire": 0.5}],
	["VERY HOT", "+1.0: a whole box on fire", 6.0, 8.0, {"fire": 1.0}],
	["INJURED -2", "plain red", 6.0, 8.0, {"pen": 2.0}],
	["HOT + INJURED -1", "both at once", 6.0, 8.0, {"pen": 1.0, "fire": 0.5}],
	["VERY HOT + INJURED -2", "both at once", 6.0, 8.0, {"pen": 2.0, "fire": 1.0}],
	["HOT, PART-WAY BOX", "5.5/10", 5.5, 8.0, {"fire": 0.5}],
	["VERY HOT, UPGRADE READY", "the + stays on top", 6.0, 8.0, {"fire": 1.0, "tokens": 1}],
	["VERY HOT AT 10/10", "no room: takes the last box", 10.0, 10.0, {"fire": 1.0}],
]

var t := 0.0
var bars: Array[Control] = []

func _ready() -> void:
	build("ATTRIBUTE BAR EFFECTS")
	var lead := UI.label("HOT STAR FIRE AND INJURIES ON THE ATTRIBUTE BAR: THE REAL DRAWING, EVERY CASE", 8, UI.DIM, "caps")
	lead.name = "Lead"
	body.add_child(lead)
	var list := UI.vbox(3)
	list.name = "Rows"
	for row in ROWS:
		list.add_child(_row(row))
	body.add_child(UI.scroll(list))

func _row(row: Array) -> Control:
	var h := UI.hbox(6)
	h.name = "Row_" + String(row[0]).replace(" ", "_").replace("/", "_").replace(",", "").replace("+", "").replace("(", "").replace(")", "").replace("-", "")
	var words := UI.vbox(0)
	words.custom_minimum_size = Vector2(LABEL_W, 0)
	words.add_child(UI.label(String(row[0]), 8, UI.TEXT, "caps"))
	words.add_child(UI.label(String(row[1]), 8, UI.DIM))
	h.add_child(words)
	var v: float = row[2]
	var top: float = row[3]
	var o: Dictionary = row[4]
	var cv := UI.canvas(0, BAR_H, func(ci: Control):
		var oo := o.duplicate()
		oo["t"] = t
		Deck.attr_boxes(ci, Rect2(0, 0, ci.size.x, BAR_H), v, top, oo))
	cv.name = "Bar"
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(cv)
	bars.append(cv)
	return h

func _process(dt: float) -> void:
	t += dt
	for cv in bars:
		if is_instance_valid(cv):
			cv.queue_redraw()

func on_back() -> void:
	Sfx.play("back")
	Game.back("dev_settings")
