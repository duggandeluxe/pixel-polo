extends BaseScreen
## The whole season on one table (tap the timeline on the hub): game number, date, event,
## opponent and result for every game, and every week without one. Regular-season games are
## numbered GAME 1-16 in the order you play them (the weeks are only the calendar underneath);
## a playoff game or a week without a game has no number. This week's row is outlined in gold;
## played games show their score in green or red, the rest a dash; playoff rounds not drawn yet
## say TBD.

const HEAD_H := 12
const ROW_H := 14
const PAD := 4                 # a cell's inset at the row's ends
const WK_W := 32
const NOW_ROW := Color("1a3a9a")
const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

func _ready() -> void:
	back_target = "hub"
	build("SEASON SCHEDULE", true, true)
	var rows := _rows()
	var table := UI.canvas(0, HEAD_H + ROW_H * rows.size() + 2, func(ci: Control): _draw_table(ci, rows))
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.chunky(Deck.NAVY, UI.BORDER, false, false, 6, 4))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(table)
	body.add_child(panel)

## One row per game of yours (up to three a week), one for a week without one:
## {wk, date, event, opp, result, col (the result's), now}.
func _rows() -> Array:
	var out: Array = []
	var next := c.my_game()
	for i in c.schedule.size():
		var r: Dictionary = c.schedule[i]
		var mine := c.my_games(r)
		var base := {"wk": "", "date": date_text(c.year, i, String(r.kind)), "event": String(r.name).to_upper(),
			"opp": "TBD", "opp_col": UI.DIM2, "result": "-", "col": UI.DIM2, "now": false}
		if not Schedule.drawn(r) or mine.is_empty():
			var d := base.duplicate()
			if Schedule.drawn(r):
				d.opp = "BYE" if (not Schedule.is_playoff(r) or c.bye_week(i)) else "OUT"
			d.now = i == c.week
			out.append(_now_mark(d))
			continue
		for g in mine:
			var d := base.duplicate()
			var home: bool = g.h == c.school
			var opp: PoloTeam = c.teams[g.a if home else g.h]
			d.date = date_text(c.year, i, String(r.kind), int(g.get("d", 1)))
			d.event = Schedule.game_label(r, g)
			var n := Schedule.game_no(c.schedule, c.school, g)
			d.wk = str(n) if n > 0 else ""
			d.opp = ("VS " if Schedule.is_neutral(g) else ("" if home else "AT ")) + opp.name.to_upper()
			d.opp_col = UI.TEXT
			if g.r != null:
				var won := Schedule.winner(g) == c.school
				d.result = ("W " if won else "L ") + Schedule.score_text(g, home)
				d.col = UI.GOOD if won else UI.BAD
			d.now = i == c.week and g == next
			out.append(_now_mark(d))
	return out

func _now_mark(d: Dictionary) -> Dictionary:
	if d.now and d.col == UI.DIM2:
		d.result = "< THIS WEEK"
		d.col = UI.GOLD
	return d

## The date a game is played: weekends from the first one in September (`day` 0 Friday,
## 1 Saturday, 2 Sunday), with a week off between the conference final and the NCSA Championship.
static func date_text(year: int, i: int, kind: String, day: int = 1) -> String:
	var sep1 := Time.get_unix_time_from_datetime_dict({"year": year, "month": 9, "day": 1, "hour": 12})
	var wd: int = Time.get_datetime_dict_from_unix_time(sep1).weekday   # 0 = Sunday
	var weeks := i + (1 if kind.begins_with("nat_") else 0)
	var d := Time.get_datetime_dict_from_unix_time(sep1 + ((6 - wd) % 7 + weeks * 7 + day - 1) * 86400)
	return "%s %d" % [MONTHS[int(d.month) - 1], int(d.day)]

## Columns as wide as their longest entry; the opponent gets whatever room is left.
func _draw_table(ci: Control, rows: Array) -> void:
	var w := ci.size.x
	var date_w := Deck.text_w("DATE", 16, "big")
	var event_w := Deck.text_w("EVENT", 16, "big")
	var result_w := Deck.text_w("RESULT", 16, "big")
	for d in rows:
		date_w = maxf(date_w, Deck.text_w(d.date))
		event_w = maxf(event_w, Deck.text_w(d.event))
		result_w = maxf(result_w, Deck.text_w(d.result))
	var x_wk := float(PAD)
	var x_date := x_wk + WK_W + 12.0
	var x_event := x_date + date_w + 14.0
	var x_res := w - PAD - result_w
	var x_opp := x_event + event_w + 14.0
	var opp_w := x_res - 14.0 - x_opp
	for h in [[x_date, "DATE"], [x_event, "EVENT"], [x_opp, "OPPONENT"], [x_res, "RESULT"]]:
		Deck.text(ci, h[0], HEAD_H * 0.5, h[1], 16, UI.ACCENT, "big")
	Deck.ctext(ci, Rect2(x_wk, 0, WK_W, HEAD_H), "GAME", 16, UI.ACCENT, "big")
	for i in rows.size():
		var d: Dictionary = rows[i]
		var y := float(HEAD_H + 1 + i * ROW_H)
		var row := Rect2(0, y, w, ROW_H)
		ci.draw_rect(row, NOW_ROW if d.now else (Deck.ROW_A if i % 2 == 0 else Deck.ROW_B))
		if d.now:
			ci.draw_rect(row, UI.GOLD, false, 1.0)
		var mid := y + ROW_H * 0.5
		var lead := UI.GOLD if d.now else UI.TEXT
		Deck.ctext(ci, Rect2(x_wk, y, WK_W, ROW_H), d.wk, 8, lead)
		Deck.text(ci, x_date, mid, d.date, 8, lead)
		Deck.text(ci, x_event, mid, d.event, 8, UI.TEXT)
		Deck.text(ci, x_opp, mid, Deck.fit(d.opp, opp_w), 8, d.opp_col)
		Deck.text(ci, x_res, mid, d.result, 8, d.col)
