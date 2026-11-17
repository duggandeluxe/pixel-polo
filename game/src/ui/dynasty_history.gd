class_name DynastyHistory
## YOUR SEASONS, the dynasty history panel shared by the season review and the roster set screens
## (the same look as the Season Review Redesign's): a navy panel, its gold heading, the totals in
## four tiles (SEASONS, TITLES in gold once there's one, CONF., NATIONAL), then every season
## newest first in its own scroll, each a compact card: the years and record, the team, the
## conference finish, and a title season in gold with the trophy and what it won.
## Takes SeasonReview.history's shape ({history, totals}); draws only what it's given.

const NAVY := Color("0b1d5c")
const NAVY_HI := Color("14318c")
const NAVY_LO := Color("081650")
const PLATE_GOLD := Color("3d3410")
const WIDTH := 150

## The panel, `w` wide, filling the height it's given.
static func panel(hist: Dictionary, w: int = WIDTH) -> Control:
	var rows: Array = hist.get("history", [])
	var tot: Dictionary = hist.get("totals", {})
	var p := PanelContainer.new()
	p.name = "YourSeasons"
	p.add_theme_stylebox_override("panel", UI.chunky(NAVY, UI.BORDER, false, false, 4, 4, UI.BEVEL_SOFT))
	p.custom_minimum_size = Vector2(w, 0)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(3)
	p.add_child(v)
	var head := UI.canvas(0, 12, func(ci: Control):
		Deck.trophy(ci, Vector2(1, 0), UI.GOLD)
		Deck.shadow_text(ci, 14, 6, "YOUR SEASONS", 8, UI.GOLD)
		ci.draw_rect(Rect2(0, 11, ci.size.x, 1), Color(UI.GOLD, 0.6)))
	v.add_child(head)
	var stats := [["SEASONS", int(tot.get("seasons", rows.size()))], ["TITLES", int(tot.get("titles", 0))],
		["CONF.", int(tot.get("conf", 0))], ["NATIONAL", int(tot.get("nat", 0))]]
	var tiles := UI.canvas(0, 40, func(ci: Control):
		var tw := floorf((ci.size.x - 3) * 0.5)
		for i in stats.size():
			var r := Rect2((i % 2) * (tw + 3), (i / 2) * 20, tw, 18)
			var gold: bool = i == 1 and int(stats[i][1]) > 0
			Deck.frame(ci, r, PLATE_GOLD if gold else NAVY_LO, UI.GOLD if gold else Color(UI.DIM, 0.5))
			Deck.text(ci, r.position.x + 4, r.position.y + 9, String(stats[i][0]), 8, UI.DIM)
			Deck.rtext(ci, r.end.x - 4, r.position.y + 9, str(stats[i][1]), 8, UI.GOLD if gold else UI.TEXT))
	tiles.name = "Totals"
	v.add_child(tiles)
	var list := UI.vbox(3)
	list.name = "Seasons"
	var sc := UI.scroll(list)
	sc.name = "HistoryScroll"
	v.add_child(sc)
	if rows.is_empty():
		var none := UI.label("NO COMPLETED SEASONS YET", 8, UI.DIM, "caps")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(none)
	for h in rows:
		list.add_child(row(h))
	return p

## One season's card.
static func row(h: Dictionary) -> Control:
	var titles: Array = h.get("titles", [])
	var champ := not titles.is_empty()
	var ht := 40 if champ else 30
	var r := UI.canvas(0, ht, func(ci: Control):
		var w := ci.size.x
		Deck.frame(ci, Rect2(0, 0, w, ht - 1), PLATE_GOLD if champ else NAVY_HI, UI.GOLD if champ else Color(UI.BORDER, 0.5))
		Deck.text(ci, 4, 6, years(String(h.get("year", ""))), 8, UI.GOLD)
		Deck.rtext(ci, w - 4, 6, "%d-%d" % [int(h.get("w", 0)), int(h.get("l", 0))], 8, UI.TEXT)
		Deck.text(ci, 4, 15, Deck.fit(String(h.get("team_name", "")).to_upper(), w - 8), 8, UI.ACCENT)
		var fin := String(h.get("finish", "")).to_upper()
		if int(h.get("rank", 0)) > 0:
			fin = "CONF %s%s" % [SeasonReview.ordinal(int(h.rank)), ("  -  " + fin) if fin != "" else ""]
		Deck.text(ci, 4, 24, Deck.fit(fin, w - 8), 8, UI.DIM)
		if champ:
			Deck.trophy(ci, Vector2(3, 29), UI.GOLD)
			Deck.text(ci, 16, 34, Deck.fit(" + ".join(titles).to_upper(), w - 20), 8, UI.GOLD))
	r.name = "Season_" + String(h.get("year", ""))
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r

## "2026-27" -> "2026-2027" (anything else as it is).
static func years(season: String) -> String:
	var parts := season.split("-")
	if parts.size() == 2 and parts[0].length() == 4 and parts[1].length() == 2:
		return "%s-%d" % [parts[0], int(parts[0]) + 1]
	return season
