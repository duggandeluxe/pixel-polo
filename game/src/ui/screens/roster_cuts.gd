extends BaseScreen
## ROSTER CUTS REQUIRED (Offseason, phase "cuts"): after the season your roster, the freshmen in,
## is over its cap (or carries too many keepers). Drawn in the Roster Set's look (navy panels,
## gold-ruled headings, the banner between gold and blue rules):
##   the banner        TRIM YOUR ROSTER FOR THE NEXT SEASON (ROSTER SET once it's legal)
##   the status panel  one line: ROSTER CUTS REQUIRED, PLAYERS TO CUT, and the warning that cuts are final
##   YOUR ROSTER       every player a row (portrait, position, name, class year, CURRENT and
##                     POTENTIAL stars) with VIEW PLAYER CARD (his player page; its back comes
##                     here) and CUT PLAYER. Each cut is confirmed, is for good and refunds nothing.
## Nobody is cut for you. CONTINUE TO NEXT SEASON only once the roster is legal
## (Offseason.roster_legal).

const NAVY := DynastyHistory.NAVY
const NAVY_HI := DynastyHistory.NAVY_HI
const NAVY_LO := DynastyHistory.NAVY_LO
const CUT_FILL := Color("2e1230")       # the Roster Set's muted red
const CUT_EDGE := Color("c8545a")
const ROW_H := 24
const PLATE := Vector2i(18, 20)
## Where each column starts in a row (and its header).
const X_POS := 26.0
const X_NAME := 50.0
const X_YR := 132.0
const X_NOW := 156.0
const X_POT := 214.0
const INFO_W := 268
const ARROW_R := ["#...", "##..", "###.", "##..", "#..."]
const SCISSORS := ["#...#", ".#.#.", "..#..", ".#.#.", "##.##", "##.##"]

func _ready() -> void:
	c = Game.career
	if c == null or c.phase != "cuts":
		Game.goto("hub")
		return
	back_target = "hub"
	build("ROSTER CUTS", false, false)
	_render()
	Sfx.music("menu")

func _render() -> void:
	for ch in body.get_children():
		ch.queue_free()
	var legal := Offseason.roster_legal(c)
	body.add_child(_banner(legal))
	body.add_child(_status(legal))
	body.add_child(_roster_panel())
	var go := Deck.button("CONTINUE TO NEXT SEASON  >", _continue, "primary", 0, 22)
	go.name = "Continue"
	go.disabled = not legal
	go.tooltip_text = "" if legal else "Cut %d more first." % _to_cut()
	body.add_child(go)

func _to_cut() -> int:
	return maxi(Offseason.cuts_needed(c), Offseason.keepers_over(c))

## The banner under the title: its line between gold and blue rules, scissors and arrows either side.
func _banner(legal: bool) -> Control:
	var mid := ("ROSTER SET - READY FOR THE %s SEASON" if legal else "TRIM YOUR ROSTER FOR THE %s SEASON") % c.next_season_label()
	var col := UI.GOOD if legal else UI.GOLD
	var b := UI.canvas(0, 13, func(ci: Control):
		var w := ci.size.x
		var tw := Deck.text_w(mid)
		var cx := floorf((w - tw) * 0.5)
		for side in [[4.0, cx - 18.0], [cx + tw + 18.0, w - 4.0]]:
			if side[1] > side[0]:
				ci.draw_rect(Rect2(side[0], 5, side[1] - side[0], 1), col)
				ci.draw_rect(Rect2(side[0], 7, side[1] - side[0], 1), UI.ACCENT)
		Deck.pat(ci, Vector2(cx - 12, 3), SCISSORS, {"#": col})
		Deck.pat(ci, Vector2(cx + tw + 7, 4), ARROW_R, {"#": col})
		Deck.pat(ci, Vector2(cx + tw + 11, 4), ARROW_R, {"#": UI.ACCENT})
		Deck.shadow_text(ci, cx, 6, mid, 8, col))
	b.name = "Banner"
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

# ------------------------------------------------------------------ the status panel
func _status(legal: bool) -> Control:
	var p := PanelContainer.new()
	p.name = "CutsStatus"
	p.add_theme_stylebox_override("panel", UI.chunky(NAVY, UI.GOOD if legal else CUT_EDGE, false, false, 5, 2, UI.BEVEL_SOFT))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# One line: the heading, how many to cut, and the warning that cuts are final.
	var h := UI.hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(h)
	var title := "ROSTER SET" if legal else "ROSTER CUTS REQUIRED"
	h.add_child(UI.label(title, 8, UI.GOOD if legal else UI.WARN, "caps"))
	var n := _to_cut()
	var cut_l := UI.label("PLAYERS TO CUT: %d" % n, 8, UI.GOOD if n == 0 else UI.WARN, "caps")
	cut_l.name = "ToCut"
	h.add_child(cut_l)
	h.add_child(UI.label("CUTS ARE FINAL. NO POLO POINTS ARE REFUNDED.", 8, UI.DIM, "caps"))
	return p

# ------------------------------------------------------------------ YOUR ROSTER
func _roster_panel() -> Control:
	var players: Array = c.team().roster.duplicate()
	var p := PanelContainer.new()
	p.name = "Roster"
	p.add_theme_stylebox_override("panel", UI.chunky(NAVY, UI.BORDER, false, false, 5, 4, UI.BEVEL_SOFT))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := UI.vbox(2)
	p.add_child(inner)
	var cnt := "%d PLAYERS" % players.size()
	var head := UI.canvas(0, 11, func(ci: Control):
		var title := "YOUR ROSTER"
		Deck.shadow_text(ci, 1, 5, title, 8, UI.GOLD)
		var x := Deck.text_w(title) + 6.0
		var x_end := ci.size.x - Deck.text_w(cnt) - 6.0
		if x_end > x:
			ci.draw_rect(Rect2(x, 5, x_end - x, 1), Color(UI.GOLD, 0.7))
			ci.draw_rect(Rect2(x, 7, x_end - x, 1), Color(UI.GOLD, 0.25))
		Deck.rtext(ci, ci.size.x - 1, 5, cnt, 8, UI.DIM))
	head.name = "Head"
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(head)
	inner.add_child(_columns())
	var list := UI.vbox(2)
	list.name = "Players"
	var sc := UI.scroll(list)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(sc)
	players.sort_custom(func(a: PoloPlayer, b: PoloPlayer):
		if a.is_keeper() != b.is_keeper():
			return a.is_keeper()
		return a.overall() > b.overall())
	for q in players:
		list.add_child(_row(q))
	return p

func _columns() -> Control:
	var h := UI.canvas(0, 9, func(ci: Control):
		for col in [[X_POS, "POS"], [X_NAME, "PLAYER"], [X_YR, "YR"], [X_NOW, "NOW"], [X_POT, "POTENTIAL"]]:
			Deck.text(ci, col[0], 4, col[1], 8, UI.DIM2))
	h.name = "Columns"
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return h

## One player: the row drawn (stripe in his position's colour, portrait, position, name, year,
## stars), and VIEW PLAYER CARD and CUT PLAYER at its right.
func _row(p: PoloPlayer) -> Control:
	var row := MarginContainer.new()
	row.name = "Player_%d" % p.id
	row.custom_minimum_size = Vector2(0, ROW_H)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pcol := Deck.pos_color(p.pos)
	var cols := Portrait.colors_ours(p, c.team())
	var face := Portrait.texture_zoomed(p, cols[0], cols[1], PLATE)
	var fresh := p.year == 1
	var bg := UI.canvas(0, ROW_H, func(ci: Control):
		var w := ci.size.x
		Deck.frame(ci, Rect2(0, 0, w, ROW_H - 1), NAVY_HI, Color(UI.BORDER_HI, 0.35))
		ci.draw_rect(Rect2(1, 1, 2, ROW_H - 3), pcol)
		var plate := Rect2(5, 2, PLATE.x, PLATE.y)
		ci.draw_rect(plate, UI.INK)
		ci.draw_texture_rect(face, plate, false)
		var my := floorf((ROW_H - 1) * 0.5)
		Deck.text(ci, X_POS, my, p.pos_text(), 8, pcol)
		var nm := "%s %s" % [p.first.substr(0, 1), p.last.to_upper()]
		Deck.text(ci, X_NAME, my, Deck.fit(nm, X_YR - X_NAME - 4), 8, UI.TEXT)
		Deck.text(ci, X_YR, my, p.year_text().to_upper(), 8, UI.GOOD if fresh else UI.DIM)
		Deck.star_bar(ci, X_NOW, my - 4, p.stars, p.stars)
		Deck.star_bar(ci, X_POT, my - 4, p.stars, p.pot_stars))
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.custom_minimum_size.x = INFO_W
	row.add_child(bg)
	var h := UI.hbox(3)
	h.alignment = BoxContainer.ALIGNMENT_END
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UI.margin(h, 0, 0, 4, 0))
	var view := flat_button("VIEW PLAYER CARD", func(): _view(p), NAVY, UI.ACCENT, UI.TEXT, 16)
	view.name = "View"
	view.tooltip_text = "Open %s's player card" % p.short_name()
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(view)
	var block := Offseason.cut_block(c, p)
	var cut := flat_button("CUT PLAYER", func(): _ask_cut(p), CUT_FILL, CUT_EDGE, Color("ffd6d6"), 16)
	cut.name = "Cut"
	cut.disabled = block != ""
	if cut.disabled:
		cut.modulate = Color(1, 1, 1, 0.45)
	cut.tooltip_text = block if block != "" else "Release him for good"
	cut.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(cut)
	return row

func _view(p: PoloPlayer) -> void:
	Sfx.play("click")
	Game.goto("player", {"id": p.id, "return_to": "roster_cuts"})

func _ask_cut(p: PoloPlayer) -> void:
	Game.dialog("CUT %s?" % p.short_name().to_upper(), "%s (%s, %s, %s*) leaves the program for good.\n\nNo Polo Points are refunded." % [
		p.short_name(), p.pos_text(), p.year_text(), PlayerForm.star_text(p.stars)], [
		["CUT PLAYER", func():
			var err := Offseason.cut(c, p)
			if err != "":
				Game.toast(err, UI.WARN)
				Sfx.play("error")
				return
			Sfx.play("click")
			Game.save_career()
			_render(), "primary"],
		["CANCEL", Callable(), "ghost"]])

func _continue() -> void:
	var err := Offseason.finish_cuts(c)
	if err != "":
		Game.toast(err, UI.WARN)
		return
	Game.save_career()
	Game.goto("hub", {}, false)

## No way around the cuts: back is the hub, which sends you here again.
func on_back() -> void:
	Sfx.play("back")
	Game.goto("hub")
