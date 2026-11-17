extends BaseScreen
## Select career: the five save slots, stacked. An empty slot starts a new career in it, an
## occupied one loads that career; its trash can (after a confirm) empties a slot. Nothing here ever
## writes over a career.

const CARD_H := 38
const LOGO_H := 32.0   # a career's logo, in game pixels: its artwork file in fine pixels (TeamLogo.FINE)
const LOGO_W := 52.0
const PAD := 6.0       # card border to logo, logo to text
const TRASH := 30      # the trash button, square, centred on its card's row
## The trash can, plain and chunky: one character a whole game pixel, # white.
const TRASH_ART := [
	"...####...",
	"##########",
	"##########",
	"..........",
	".########.",
	".##.##.##.",
	".##.##.##.",
	".##.##.##.",
	".##.##.##.",
	".##.##.##.",
	".##.##.##.",
	".########.",
]
const TRASH_INK := Color(1, 1, 1, 0.88)
const TRASH_EDGE := Color("c8283a")
const TRASH_EDGE_HOT := Color("ff6a76")

## DETAIL MODE (Game.set_detail), as in the Trophy Room: each career's logo is its full-size artwork
## file drawn in fine pixels (two screen pixels at the usual 3x), not the small list mark.
func setup(_params: Dictionary) -> void:
	detail = true

func _ready() -> void:
	build("SELECT CAREER")
	# a big, outlined title (as New Career's), the page's headline
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.set_meta("title_max", 34)   # (BaseScreen._fit_title: its own size, unless it can't fit)
	_title_key = ""
	title_label.add_theme_color_override("font_outline_color", UI.INK)
	title_label.add_theme_constant_override("outline_size", 3)
	_render()
	Sfx.music("menu")

func on_back() -> void:
	Sfx.play("back")
	Game.goto("title", {}, false)

func _render() -> void:
	for ch in body.get_children():
		ch.queue_free()
	var list := UI.vbox(4)
	list.custom_minimum_size.x = 340
	for n in range(1, Game.SLOTS + 1):
		var row := UI.hbox(4)
		var sm := Game.slot_summary(n)
		var card := Deck.card(Vector2(0, CARD_H), _paint.bind(n, sm), _pick.bind(n, sm))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.name = "Slot%d" % n
		row.add_child(card)
		if not sm.is_empty():
			var del := Deck.card(Vector2(TRASH, TRASH), _paint_trash, _ask_delete.bind(n, sm))
			del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			del.tooltip_text = "Delete this career"
			del.name = "Delete%d" % n
			row.add_child(del)
		else:
			row.add_child(UI.spacer(TRASH, 0))   # every card the same width
		list.add_child(row)
		Juice.enter(row, n - 1)
	body.add_child(UI.spacer(0, 0, true))
	body.add_child(centered(list))
	body.add_child(UI.spacer(0, 0, true))

## A navy card with a thin border, gold when it's under the finger: the team's logo at the left,
## then the slot, team and season, left-aligned (an empty slot's text in that same column).
func _paint(ci: CanvasItem, r: Rect2, mode: String, n: int, sm: Dictionary) -> void:
	var hot := mode != "normal"
	var fill := Deck.ROW_HOVER if hot else Deck.NAVY
	if mode == "down":
		r.position += Vector2(0, 1)
	Deck.frame(ci, r, fill, UI.GOLD if hot else Color(1, 1, 1, 0.55))
	var x := r.position.x + PAD + LOGO_W + PAD
	var mid := r.position.y + r.size.y * 0.5
	if sm.is_empty():
		Deck.text(ci, x, mid, "SLOT %d - EMPTY" % n, 8, UI.DIM)
		Deck.rtext(ci, r.end.x - 9, mid, "NEW CAREER", 8, UI.GOLD if hot else UI.DIM2)
		return
	Deck.text(ci, x, mid - 10, "SLOT %d" % n, 8, UI.GOLD)
	var w := r.end.x - 9 - x
	if sm.get("damaged", false):
		Deck.text(ci, x, mid + 1, "SAVE PROBLEM", 8, UI.BAD)
		Deck.text(ci, x, mid + 11, Deck.fit("THIS SAVE CAN'T BE READ", w), 8, UI.DIM)
		return
	var school := Colleges.school(String(sm.get("school", "")))
	var logo := Rect2(r.position.x + PAD, mid - LOGO_H * 0.5, LOGO_W, LOGO_H)
	var tex: Texture2D = null
	if not school.is_empty():
		tex = TeamLogo.art_within(school, Vector2i(int(LOGO_W / TeamLogo.FINE), int(LOGO_H / TeamLogo.FINE)))
	if tex != null:
		# its artwork 1:1 in fine pixels, centred in the logo space, on the fine grid
		var dim := Vector2(tex.get_width(), tex.get_height()) * TeamLogo.FINE
		var at := logo.position + (logo.size - dim) * 0.5
		ci.draw_texture_rect(tex, Rect2((at / TeamLogo.FINE).floor() * TeamLogo.FINE, dim), false)
	elif not school.is_empty():
		TeamLogo.draw_in(ci, logo, school)
	Deck.text(ci, x, mid + 1, Deck.fit(String(sm.team).to_upper(), w), 8, UI.TEXT)
	Deck.text(ci, x, mid + 11, Deck.fit("SEASON %d | %s" % [int(sm.season), String(sm.record)], w), 8, UI.DIM)

## The delete button: a white pixel trash can on navy with a thin red border, brighter under the
## finger, a pixel lower while pressed.
func _paint_trash(ci: CanvasItem, r: Rect2, mode: String) -> void:
	var hot := mode != "normal"
	if mode == "down":
		r.position += Vector2(0, 1)
	Deck.frame(ci, r, Deck.ROW_HOVER if hot else Deck.NAVY, TRASH_EDGE_HOT if hot else TRASH_EDGE)
	var ink := Color.WHITE if hot else TRASH_INK
	var dim := Vector2(String(TRASH_ART[0]).length(), TRASH_ART.size())
	var at := (r.position + (r.size - dim) * 0.5).floor()
	for y in TRASH_ART.size():
		var row: String = TRASH_ART[y]
		for x in row.length():
			if row[x] == "#":
				ci.draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), ink)

func _pick(n: int, sm: Dictionary) -> void:
	if sm.is_empty():
		# a new career goes into this slot; the career in memory (another slot's) is saved already
		Game.career = null
		Game.slot = n
		Game.goto("new_career")
		return
	if sm.get("damaged", false):
		Game.toast("This save can't be read", UI.WARN)
		return
	if not Game.load_career(n):
		Game.toast("This save can't be read", UI.WARN)
		return
	Game.history.clear()
	Game.goto("game_summary" if not Game.career.last_summary.is_empty() else "hub")

func _ask_delete(n: int, sm: Dictionary) -> void:
	var who := "the career in slot %d" % n if sm.get("damaged", false) else "%s (season %d, %s)" % [sm.team, int(sm.season), sm.record]
	Game.dialog("DELETE CAREER?", "This deletes %s for good, with the Polo Points it earned. Your purchased Polo Points are kept." % who, [
		["DELETE", func():
			Game.delete_slot(n)
			Sfx.play("back")
			_render(), "danger"],
		["CANCEL", Callable(), "ghost"]])
