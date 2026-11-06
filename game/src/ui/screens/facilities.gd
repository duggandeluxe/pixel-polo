extends BaseScreen
## TEAM FACILITIES (the Dynasty Hub): facilities (they belong to the school) and staff (they
## follow you to your next job), in three groups of compact rows (name, level, cost): AQUATICS
## (the Aquatic Center, under your home pool's name: Colleges.venue_name), TRAINING (weights,
## medicine, video) and STAFF (the coaches, and the Recruiting Department's office). Tapping a
## row only selects it. The panel underneath shows what the next level does, with the game's own
## numbers, and its UPGRADE button is the one place a purchase happens.

const W := 452                       # the content column; the rest of the page is blue
const GAP := 7
const ROW_H := 22                     # (room for the credit coin, CreditCoin, at its own size)
const COST_W := 44
const LV_W := 34
const MUTED := Color("8f7f45")       # a yellow that can't be pressed
const BTN := Vector2(84, 42)

## "fac:pool", "staff:offense", ...: the row the details panel is about (kept while you play).
static var selected := "fac:pool"

func _ready() -> void:
	build_compact("TEAM FACILITIES")
	_render()

func _refresh() -> void:
	Game.goto("facilities", {}, false)

func _render() -> void:
	for ch in body.get_children():
		ch.queue_free()
	if _item(selected).is_empty():
		selected = "fac:pool"
	body.add_child(UI.spacer(0, 3))
	var col := UI.vbox(GAP)
	col.custom_minimum_size = Vector2(W, 0)
	body.add_child(centered(col))
	var top := UI.hbox(GAP)
	col.add_child(top)
	var left := UI.vbox(GAP)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left)
	var pool := Colleges.venue_name(c.school)
	left.add_child(_list("AQUATICS", ["fac:pool"], pool.to_upper() if pool != "" else c.venue_home().name.to_upper()))
	left.add_child(_list("TRAINING", ["fac:weights", "fac:medical", "fac:video"]))
	top.add_child(_list("STAFF", Career.STAFF_ORDER.map(func(k): return "staff:" + k) + ["fac:recruit"]))
	col.add_child(_details(_item(selected)))
	body.add_child(UI.spacer(0, 0, true))

## Everything a row and the details panel need about one facility or coach.
func _item(id: String) -> Dictionary:
	var parts := id.split(":")
	if parts.size() != 2:
		return {}
	var key := parts[1]
	if parts[0] == "fac" and Career.FAC.has(key):
		return {"id": id, "kind": "fac", "key": key, "name": String(Career.FAC[key].name), "desc": String(Career.FAC[key].desc),
			"lv": c.fac(key), "max": Career.FAC_MAX, "cost": c.facility_cost(key)}
	if parts[0] == "staff" and Career.STAFF.has(key):
		return {"id": id, "kind": "staff", "key": key, "name": String(Career.STAFF[key].name), "desc": String(Career.STAFF[key].desc),
			"lv": int(c.staff.get(key, 0)), "max": Career.STAFF_MAX, "cost": c.staff_cost(key)}
	return {}

# ------------------------------------------------------------------ the two lists
func _list(title: String, ids: Array, note: String = "") -> Control:
	var v := UI.vbox(2)
	var p := navy_panel(v)
	p.name = "Group_" + title
	p.size_flags_vertical = Control.SIZE_FILL
	v.add_child(big_text(title, UI.ACCENT))
	if note != "":
		var nl := UI.label(note, 8, UI.GOLD, "caps")
		nl.name = "HomePool"
		v.add_child(nl)
	for id in ids:
		v.add_child(_row(_item(id)))
	return p

## [ NAME   LV 2/5   [170 CR] ]: tap anywhere on it (the cost too) to select it, never to buy.
func _row(it: Dictionary) -> Control:
	var on: bool = it.id == selected
	var b := Deck.card(Vector2(0, ROW_H), func(ci, r, mode): _paint_row(ci, r, mode, it, on), func():
		selected = it.id
		_render())
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = String(it.desc)
	return b

func _paint_row(ci: CanvasItem, r: Rect2, mode: String, it: Dictionary, on: bool) -> void:
	var w := floorf(r.size.x)
	var border := UI.GOLD if on else (UI.BORDER_HI if mode != "normal" else UI.BORDER)
	Deck.frame(ci, Rect2(0, 0, w, ROW_H), Deck.NAVY, border)
	if on:   # the selection outline is 2 px, like the home screen's table
		Deck.frame(ci, Rect2(1, 1, w - 2, ROW_H - 2), Color(0, 0, 0, 0), UI.GOLD)
	var mid := ROW_H * 0.5
	var cost_x := w - 3 - COST_W
	var lv_x := cost_x - 6 - LV_W
	Deck.text(ci, 6, mid, Deck.fit(String(it.name).to_upper(), lv_x - 10, 8, "body"), 8, UI.TEXT, "body")
	Deck.text(ci, lv_x, mid, "LV", 8, UI.ACCENT)
	Deck.text(ci, lv_x + Deck.text_w("LV "), mid, "%d/%d" % [it.lv, it.max], 8, UI.TEXT)
	var box := Rect2(cost_x, 3, COST_W, ROW_H - 6)
	var maxed: bool = int(it.cost) <= 0
	ci.draw_rect(box, MUTED if maxed else UI.GOLD)
	if maxed:
		Deck.ctext(ci, box, "MAX", 8, UI.INK)
	else:
		CreditCoin.draw_amount(ci, box.position.x, box.get_center().y, str(it.cost), 8, UI.INK, "caps", 16, 1, box.size.x)

# ------------------------------------------------------------------ the details panel
func _details(it: Dictionary) -> Control:
	var maxed: bool = int(it.cost) <= 0
	var afford: bool = maxed or c.wallet() >= int(it.cost)
	var row := UI.hbox(0)
	var p := navy_panel(row)
	# left: name, level, what it does
	var left := UI.vbox(2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(big_text(String(it.name).to_upper(), UI.ACCENT))
	left.add_child(_level_line(int(it.lv), maxed))
	var desc := UI.label(String(it.desc), 8, UI.TEXT, "body")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(170, 0)
	left.add_child(desc)
	row.add_child(vline(Color(1, 1, 1, 0.55), 46, 14))
	# centre: what the next level brings, in the game's own numbers, and the price
	var mid := UI.vbox(1)
	mid.custom_minimum_size = Vector2(132, 0)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(mid)
	mid.add_child(UI.label("MAX LEVEL REACHED" if maxed else "NEXT UPGRADE", 8, UI.GOLD if maxed else UI.ACCENT, "caps"))
	for line in _benefits(it):
		mid.add_child(_bullet(line))
	if not maxed:
		var cost := UI.hbox(5)
		cost.add_child(UI.label("COST:", 8, UI.ACCENT, "caps"))
		cost.add_child(CreditCoin.widget(int(it.cost)))
		mid.add_child(cost)
		if not afford:
			mid.add_child(UI.label("NOT ENOUGH CREDITS", 8, UI.BAD, "caps"))
	row.add_child(UI.spacer(6, 0))
	row.add_child(_upgrade_button(it, maxed, afford))
	return p

## LV 2 -> LV 3 (the next level in yellow); just LV 5 once it's maxed.
func _level_line(lv: int, maxed: bool) -> Control:
	var a := "LV %d" % lv
	var b := "LV %d" % (lv + 1)
	var aw := Deck.text_w(a, 20, "big")
	var w := aw if maxed else aw + 20.0 + Deck.text_w(b, 20, "big")
	var d := UI.canvas(int(w), 15, func(ci):
		Deck.text(ci, 0, 7.5, a, 20, UI.TEXT, "big")
		if maxed:
			return
		# a pixel arrow
		var x := aw + 5.0
		ci.draw_rect(Rect2(x, 7, 8, 2), UI.TEXT)
		ci.draw_rect(Rect2(x + 5, 4, 2, 8), UI.TEXT)
		ci.draw_rect(Rect2(x + 7, 6, 2, 4), UI.TEXT)
		Deck.text(ci, aw + 20.0, 7.5, b, 20, UI.GOLD, "big"))
	d.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return d

func _bullet(t: String) -> Control:
	var h := UI.hbox(4)
	var dot := UI.canvas(2, 2, func(ci): ci.draw_rect(Rect2(0, 0, 2, 2), UI.TEXT))
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	h.add_child(UI.label(t, 8, UI.TEXT, "body"))
	return h

## The one buy button: yellow when it can be bought, muted when it's maxed or too dear.
func _upgrade_button(it: Dictionary, maxed: bool, afford: bool) -> Control:
	var live := not maxed and afford
	var b := Deck.card(BTN, func(ci, _r, mode):
		var fill := (UI.GOLD.lightened(0.15) if mode == "hover" else UI.GOLD) if live else MUTED
		Deck.frame(ci, Rect2(Vector2.ZERO, BTN), fill, UI.BORDER if live else Color(1, 1, 1, 0.45))
		if maxed:
			Deck.ctext(ci, Rect2(0, 0, BTN.x, BTN.y), "MAX LEVEL", 8, UI.INK)
			return
		var tw := Deck.text_w("UPGRADE", 20, "big")
		Deck.text(ci, floorf((BTN.x - tw) * 0.5), 14, "UPGRADE", 20, UI.INK, "big")
		CreditCoin.draw_amount(ci, 0, 31, str(it.cost), 8, UI.INK, "caps", 16, 1, BTN.x), func(): _buy(it))
	b.disabled = not live
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b

## Buys the selected level with the game's own upgrade functions, then saves.
func _buy(it: Dictionary) -> void:
	var fresh := _item(String(it.id))
	if fresh.is_empty() or int(fresh.cost) <= 0 or c.wallet() < int(fresh.cost):
		return
	var ok: bool = c.upgrade_facility(fresh.key) if fresh.kind == "fac" else c.hire_staff(fresh.key)
	if ok:
		Sfx.play("levelup")
		Game.save_career()
	_refresh()

# ------------------------------------------------------------------ the numbers
## What the next level does (or, maxed, what this level does), worked out with the same
## functions the game uses: Development.injury_risk. (Nothing bought here speeds up development:
## players grow only through their own XP and upgrade tokens, and nothing pays credits.)
func _benefits(it: Dictionary) -> Array:
	var lv := int(it.lv)
	var nx := lv if int(it.cost) <= 0 else lv + 1
	var key: String = it.key
	var out: Array = []
	if it.kind == "fac":
		match key:
			"pool", "weights", "video", "recruit":
				out.append("Training XP: no bonus")
			"medical":
				var base: float = Development.injury_risk(2, 1)
				var a: float = Development.injury_risk(2, lv)
				var b: float = Development.injury_risk(2, nx)
				out.append("Injury risk: %s" % _span_raw("-%d%%" % roundi((1.0 - a / base) * 100.0), "-%d%%" % roundi((1.0 - b / base) * 100.0), lv, nx))
	else:
		match key:
			"offense", "defense", "goalie", "recruiter":
				out.append("Training XP: no bonus")
	return out

func _span(a: int, b: int, lv: int, nx: int) -> String:
	return _span_raw("+%d%%" % a, "+%d%%" % b, lv, nx)

func _span_raw(a: String, b: String, lv: int, nx: int) -> String:
	return a if lv == nx else "%s -> %s" % [a, b]

## Back to wherever you came from (MORE, or Training for facilities).
func on_back() -> void:
	Sfx.play("back")
	Game.back("hub")
