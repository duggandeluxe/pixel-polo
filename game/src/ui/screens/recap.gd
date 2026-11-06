extends BaseScreen
## The season review (and the roster lock): how the season went, who left, who signed, and
## your history.

var data := {}

func setup(params: Dictionary) -> void:
	data = params

func _ready() -> void:
	c = Game.career
	build(String(data.get("title", "SEASON REVIEW")), false, false)
	var cols := UI.hbox(8)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	var left := UI.panel(UI.PANEL2, UI.GOLD)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var lv := UI.vbox(3)
	left.add_child(lv)
	for ln in data.get("lines", []):
		lv.add_child(CreditCoin.rich(String(ln), 8, UI.TEXT, "body", 240))
	var right := UI.panel()
	right.custom_minimum_size = Vector2(170, 0)
	cols.add_child(right)
	var rv := UI.vbox(1)
	right.add_child(rv)
	rv.add_child(UI.label("YOUR SEASONS", 8, UI.GOLD))
	var hist: Array = c.history.duplicate()
	hist.reverse()
	for h in hist.slice(0, 8):
		rv.add_child(UI.label("%s %s  %d-%d" % [h.year, Colleges.team_name(String(h.team)), h.w, h.l], 8, UI.TEXT))
		rv.add_child(UI.label("  " + String(h.finish), 8, UI.DIM))
	var titles: Array = c.coach.get("titles", [])
	if not titles.is_empty():
		rv.add_child(UI.label("TITLES: %d" % titles.size(), 8, UI.GOLD))
	body.add_child(UI.button("ON TO %s  >" % String(data.get("next", c.season_label())), _done, "primary", 0, 22))
	Sfx.music("menu")

func on_back() -> void:
	_done()

## The review was the front of the hub's queue: it's dealt with now.
func _done() -> void:
	if not c.queue.is_empty() and String(c.queue[0].get("type", "")) == "recap":
		c.queue.pop_front()
		Game.save_career()
	Game.goto("hub")
