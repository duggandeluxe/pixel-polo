extends BaseScreen
## The National Top 20 (TOP 20 on the hub, or the conference screen): the poll's #1-#20 with
## each team's record, conference record, its rank in the poll before and the movement, then
## the teams receiving votes. Your school's row is outlined in gold (and if it's further down,
## a line under the table says where). < and > step through the season's polls.

const HEAD_H := 14
const ROW_H := 17              # a row a team: the name big, as on the conference board
const ROW_GAP := 1
const SEP_H := 14              # the RECEIVING VOTES line
const MEDALS := [Color("ffd23f"), Color("c8d2e6"), Color("d08a4a")]   # #1, #2, #3
const PAD := 4
const MINE := Color("1a3a9a")
const UP := Color("7fe35f")
const DOWN := Color("ff4a4a")

var at := -1                   # the poll on show: its index in the season's polls (-1: the latest)

func _ready() -> void:
	back_target = "hub"
	build("NATIONAL TOP 20", true, true)
	_render()

func _render() -> void:
	for ch in body.get_children():
		ch.queue_free()
	var polls: Array = c.season.get("polls", [])
	if polls.is_empty():
		body.add_child(para("The first poll comes out when the season starts.", UI.DIM, 400))
		return
	var i := polls.size() - 1 if at < 0 else clampi(at, 0, polls.size() - 1)
	var poll: Dictionary = polls[i]
	body.add_child(_browse(i, polls.size(), poll))
	var rows := Poll.rows(c, poll)
	var table := UI.canvas(0, HEAD_H + (ROW_H + ROW_GAP) * rows.size() + (SEP_H if rows.size() > Poll.TOP else 0) + 2, func(ci: Control): _draw_table(ci, rows))
	table.name = "Top20Table"
	table.set_meta("rows", rows)
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.sb(Deck.NAVY, UI.BORDER, 2, 6, 4))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(table)
	var v := UI.vbox(4)
	v.add_child(panel)
	var mine := Poll.rank_in(poll, c.school)
	if mine > Poll.TOP + Poll.RV:
		v.add_child(UI.label("%s: #%d IN THE POLL (UNRANKED)" % [Colleges.display_name(c.team().name).to_upper(), mine], 8, UI.GOLD, "caps"))
	body.add_child(UI.scroll(v))

## < POLL NAME >: the polls before and after this one.
func _browse(i: int, n: int, poll: Dictionary) -> Control:
	var h := UI.hbox(6)
	var back := Deck.icon_button("left", func():
		at = i - 1
		_render(), 24, 16)
	back.disabled = i == 0
	back.tooltip_text = "The poll before"
	h.add_child(back)
	var title := UI.label("%s POLL" % String(poll.get("label", "")), 8, UI.GOLD, "caps")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(title)
	var fwd := Deck.icon_button("right", func():
		at = i + 1 if i + 1 < n - 1 else -1
		_render(), 24, 16)
	fwd.disabled = i >= n - 1
	fwd.tooltip_text = "The poll after"
	h.add_child(fwd)
	return h

func _draw_table(ci: Control, rows: Array) -> void:
	var w := ci.size.x
	var rk_w := Deck.text_w("#22") + 4.0
	var x_rk := float(PAD)
	rk_w = Deck.text_w("#20", 16, "big") + 4.0
	var x_team := x_rk + rk_w + 8.0
	var col_w := maxf(Deck.text_w("PREV", 16, "big"), Deck.text_w("16-16")) + 10.0
	var x_pts := w - PAD - Deck.text_w("PTS", 16, "big")
	var x_move := x_pts - col_w
	var x_prev := x_move - col_w
	var x_conf := x_prev - col_w
	var x_rec := x_conf - col_w
	var team_w := x_rec - 8.0 - x_team
	Deck.text(ci, x_rk, HEAD_H * 0.5, "RK", 16, UI.ACCENT, "big")
	for hd in [[x_team, "TEAM"], [x_rec, "W-L"], [x_conf, "CONF"], [x_prev, "PREV"], [x_move, "MOVE"], [x_pts, "PTS"]]:
		Deck.text(ci, hd[0], HEAD_H * 0.5, hd[1], 16, UI.ACCENT, "big")
	var y := float(HEAD_H + 1)
	for k in rows.size():
		var d: Dictionary = rows[k]
		if d.rv and k == Poll.TOP:
			Deck.text(ci, x_rk, y + SEP_H * 0.5, "RECEIVING VOTES", 8, UI.ACCENT)
			y += SEP_H
		var me: bool = d.id == c.school
		var row := Rect2(0, y, w, ROW_H)
		ci.draw_rect(row, MINE if me else (Deck.ROW_A if k % 2 == 0 else Deck.ROW_B))
		ci.draw_rect(Rect2(0, y + ROW_H, w, ROW_GAP), UI.INK)
		if me:
			ci.draw_rect(row, UI.GOLD, false, 1.0)
		var mid := y + ROW_H * 0.5
		var col := UI.GOLD if me else (UI.DIM if d.rv else UI.TEXT)
		var t: PoloTeam = c.teams[d.id]
		var rk_col: Color = MEDALS[int(d.rank) - 1] if not d.rv and int(d.rank) <= 3 else (UI.DIM if d.rv else col)
		Deck.rtext(ci, x_rk + rk_w, mid, ("RV" if d.rv else str(d.rank)), 16, rk_col, "big")
		Deck.text(ci, x_team, mid, Deck.fit(Colleges.display_name(t.name).to_upper(), team_w, 16, "big"), 16, col, "big")
		Deck.text(ci, x_rec, mid, "%d-%d" % [d.rec[0], d.rec[1]], 8, col)
		Deck.text(ci, x_conf, mid, "%d-%d" % [d.rec[2], d.rec[3]], 8, UI.DIM if not me else col)
		Deck.text(ci, x_prev, mid, str(d.prev) if int(d.prev) > 0 else "-", 8, UI.DIM if not me else col)
		_draw_move(ci, x_move, mid, d.move)
		Deck.text(ci, x_pts, mid, "%.1f" % float(d.pts), 8, UI.DIM)
		y += ROW_H + ROW_GAP

## Up (green triangle and how many places), down (red), NEW in the Top 20, or "-".
func _draw_move(ci: Control, x: float, mid: float, move: Variant) -> void:
	if move is String:
		Deck.text(ci, x, mid, move, 8, UI.GOLD if move == "NEW" else UI.DIM)
		return
	var n := int(move)
	if n == 0:
		Deck.text(ci, x, mid, "-", 8, UI.DIM)
		return
	var col := UP if n > 0 else DOWN
	var tip := mid - 3.0 if n > 0 else mid + 3.0
	var base := mid + 2.0 if n > 0 else mid - 2.0
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x + 3, tip), Vector2(x, base), Vector2(x + 6, base)]), col)
	Deck.text(ci, x + 9, mid, str(absi(n)), 8, col)
