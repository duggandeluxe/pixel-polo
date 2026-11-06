extends BaseScreen
## ROSTER CUTS REQUIRED (Offseason, phase "cuts"): after the season your roster, the freshmen in,
## is over its cap (or carries too many keepers). Every player is listed (name, position, class
## year, CURRENT and POTENTIAL stars, his four attributes) with CUT PLAYER; each cut is confirmed,
## is for good and refunds nothing. Nobody is cut for you. CONTINUE TO NEXT SEASON only once the
## roster is legal (Offseason.roster_legal).

const COL_POS := 18
const COL_NAME := 62
const COL_YEAR := 16
const COL_STARS := 49
const COL_ATTR := 27        # "COM 10"

func _ready() -> void:
	c = Game.career
	if c == null or c.phase != "cuts":
		Game.goto("hub")
		return
	back_target = "hub"
	build("ROSTER CUTS", false, true)
	_render()

func _render() -> void:
	for ch in body.get_children():
		ch.queue_free()
	var need := Offseason.cuts_needed(c)
	var gk_over := Offseason.keepers_over(c)
	var legal := Offseason.roster_legal(c)
	var top := UI.panel(Color(0, 0, 0, 0.18) if legal else Color(UI.BAD, 0.28), UI.GOOD if legal else UI.WARN)
	top.name = "CutsStatus"
	var tv := UI.vbox(1)
	top.add_child(tv)
	var th := UI.hbox(10)
	tv.add_child(th)
	th.add_child(UI.label("ROSTER CUTS REQUIRED" if not legal else "ROSTER SET", 8, UI.WARN if not legal else UI.GOOD, "caps"))
	th.add_child(UI.label("CURRENT ROSTER: %d / %d" % [c.team().roster.size(), c.roster_max()], 8, UI.TEXT, "caps"))
	var cut_l := UI.label("PLAYERS TO CUT: %d" % maxi(need, gk_over), 8, UI.GOOD if legal else UI.WARN, "caps")
	cut_l.name = "ToCut"
	th.add_child(cut_l)
	if gk_over > 0:
		th.add_child(UI.label("MAX %d GOALKEEPERS" % c.keeper_cap(c.school), 8, UI.WARN, "caps"))
	tv.add_child(UI.label("CUTS ARE FINAL. NO CREDITS ARE REFUNDED.", 8, UI.DIM, "caps"))
	body.add_child(top)
	body.add_child(_header())
	var list := UI.vbox(1)
	list.name = "Players"
	var sc := UI.scroll(list)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sc)
	var players: Array = c.team().roster.duplicate()
	players.sort_custom(func(a: PoloPlayer, b: PoloPlayer):
		if a.is_keeper() != b.is_keeper():
			return a.is_keeper()
		return a.overall() > b.overall())
	for p in players:
		list.add_child(_row(p))
	var go := UI.button("CONTINUE TO NEXT SEASON  >", _continue, "primary", 0, 22)
	go.name = "Continue"
	go.disabled = not legal
	go.tooltip_text = "" if legal else "Cut %d more first." % maxi(need, gk_over)
	body.add_child(go)

func _header() -> Control:
	var h := UI.hbox(3)
	h.add_child(fixed_label("POS", COL_POS, UI.DIM))
	h.add_child(fixed_label("PLAYER", COL_NAME, UI.DIM))
	h.add_child(fixed_label("YR", COL_YEAR, UI.DIM))
	h.add_child(fixed_label("NOW", COL_STARS, UI.DIM))
	h.add_child(fixed_label("POTENTIAL", COL_STARS, UI.DIM))
	h.add_child(fixed_label("ATTRIBUTES", COL_ATTR * 4, UI.DIM))
	return UI.margin(h, 3, 0, 3, 0)

func _row(p: PoloPlayer) -> Control:
	var h := UI.hbox(3)
	h.name = "Player_%d" % p.id
	h.add_child(fixed_label(p.pos_text(), COL_POS, UI.ACCENT))
	var nm := fixed_label(Deck.fit("%s %s" % [p.first.substr(0, 1), p.last.to_upper()], COL_NAME, 8), COL_NAME)
	nm.clip_text = true
	h.add_child(nm)
	h.add_child(fixed_label(p.year_text().to_upper(), COL_YEAR, UI.GOOD if p.year == 1 else UI.TEXT))
	h.add_child(_stars(p.stars, p.stars))
	h.add_child(_stars(p.stars, p.pot_stars))
	for k in Attributes.keys_for(p):
		h.add_child(fixed_label("%s %d" % [String(k).to_upper().substr(0, 3), roundi(Attributes.value(p, k))], COL_ATTR, UI.TEXT))
	h.add_child(UI.spacer(0, 0, true))
	var block := Offseason.cut_block(c, p)
	var b := UI.button("CUT PLAYER", func(): _ask_cut(p), "normal", 60, 14)
	b.name = "Cut"
	b.disabled = block != ""
	b.tooltip_text = block if block != "" else "Release him for good"
	h.add_child(b)
	return UI.margin(h, 3, 1, 3, 1)

func _stars(cur: float, pot: float) -> Control:
	var d := UI.canvas(COL_STARS, 9, func(ci): Deck.star_bar(ci, 0, 0, cur, pot, 0, Color(1, 1, 1, 0.3)))
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return d

func _ask_cut(p: PoloPlayer) -> void:
	Game.dialog("CUT %s?" % p.short_name().to_upper(), "%s (%s, %s, %s*) leaves the program for good.\n\nNo credits are refunded." % [
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
