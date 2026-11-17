extends BaseScreen
## The conference standings and the playoff brackets (tap the conference table on the hub).

const TABS := ["STANDINGS", "PLAYOFFS", "TOP 20"]

var tab := "STANDINGS"
var conf := ""

## {"tab": "PLAYOFFS", "fam": "nat"}: straight to a bracket (the SEASON OVER hub's VIEW BRACKET).
func setup(params: Dictionary) -> void:
	if String(params.get("tab", "")) in TABS:
		tab = String(params.tab)
	if String(params.get("fam", "")) in ["conf", "nat"]:
		pfam = String(params.fam)

func _ready() -> void:
	back_target = "hub"
	build("CONFERENCE", true, true)
	conf = c.team().conf
	_render()

func _render() -> void:
	for ch in body.get_children():
		ch.queue_free()
	# the bracket is drawn in DETAIL MODE (PlayoffBracket: finer, sharper, more room); the
	# standings at the game's own pixels as ever
	Game.set_detail(tab == "PLAYOFFS")
	body.add_child(tabs(TABS, tab, func(t):
		if t == "TOP 20":
			Game.goto("top20")
			return
		tab = t
		_render()))
	var v := UI.vbox(1)
	body.add_child(UI.scroll(v))
	match tab:
		"STANDINGS":
			_standings(v)
		"PLAYOFFS":
			_playoffs(v)

# ------------------------------------------------------------------ the standings board
const BOARD_SHARE := 0.92     # the board's share of the page's width, centred
const ROW_H := 18
const COL_RK := 26           # the rank (and the leader's star)
const COL_REC := 34           # CONF and ALL
const COL_GOALS := 42
const COL_NUM := 16           # the rating's number...
const BAR_W := 30             # ...and its bar
const MEDALS := [Color("ffd23f"), Color("c8d2e6"), Color("d08a4a")]   # 1st, 2nd, 3rd
const MINE := Color("1a3a9a")

## The conference's standings board: the five conferences to pick from, the one on show by its
## full name, a row a team (rank, name, conference and overall records, goals, rating and its
## bar), then how the championships are decided. No logos.
func _standings(v: VBoxContainer) -> void:
	var ids := Colleges.conf_ids_of(c.teams)
	ids.reverse()
	var row := UI.hbox(0)
	v.add_child(row)
	var l := Control.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_stretch_ratio = (1.0 - BOARD_SHARE) * 0.5
	row.add_child(l)
	var col := UI.vbox(4)
	col.name = "Board"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = BOARD_SHARE
	row.add_child(col)
	var r := Control.new()
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_stretch_ratio = (1.0 - BOARD_SHARE) * 0.5
	row.add_child(r)
	var board := PanelContainer.new()
	board.add_theme_stylebox_override("panel", UI.sb(Deck.NAVY, UI.BORDER, 2, 6, 5))
	col.add_child(board)
	var bv := UI.vbox(3)
	board.add_child(bv)
	# the five conferences, the same size, yours picked first
	var picks := UI.hbox(4)
	picks.name = "ConfButtons"
	bv.add_child(picks)
	for cid in ids:
		var cc: String = cid
		var on := cc == conf
		var b := UI.button(c.conf_abbr(cc), func():
			conf = cc
			_render(), "tab_on" if on else "tab", 0, 18)
		b.name = "Conf_" + cc
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picks.add_child(b)
	var conf_title := c.conf_name(conf).to_upper()
	var title := UI.label(conf_title, 20 if conf_title.length() <= 36 else 16, UI.GOLD, "big")
	title.name = "ConfTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", UI.INK)
	title.add_theme_constant_override("outline_size", 2)
	bv.add_child(title)
	# the column heads, then a row a team
	var head := _cells(["RK", "TEAM", "CONF", "ALL", "GF-GA", "RATING"], UI.ACCENT)
	head.name = "Head"
	bv.add_child(head)
	var order := Schedule.conf_table(c.teams, c.table, conf)
	var played := order.any(func(id): return int(c.table[id].cw) + int(c.table[id].cl) > 0)
	var rows := UI.vbox(2)
	rows.name = "Rows"
	bv.add_child(rows)
	for i in order.size():
		rows.add_child(_team_row(i, order[i], played))
	col.add_child(_qualification(ids.size()))

## The column heads, in the rows' own columns.
func _cells(heads: Array, colr: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.sb(Color.TRANSPARENT, Color.TRANSPARENT, 0, 4, 0))
	var h := UI.hbox(5)
	p.add_child(h)
	var widths := [COL_RK, -1, COL_REC, COL_REC, COL_GOALS, COL_NUM + 4 + BAR_W]
	for i in heads.size():
		var lab := UI.label(String(heads[i]), 8, colr, "caps")
		if int(widths[i]) < 0:
			lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			lab.custom_minimum_size.x = widths[i]
		h.add_child(lab)
	return p

## One team's row: rank (gold, silver, bronze for the top three), name (big; yours in gold, with
## its border), any badge the season has earned (LEADER, CHAMPION, QUALIFIED), the records, goals
## and its rating with a bar of it.
func _team_row(i: int, id: String, played: bool) -> Control:
	var t: PoloTeam = c.teams[id]
	var rec: Dictionary = c.table[id]
	var me := id == c.school
	var p := PanelContainer.new()
	p.name = "Row_" + id
	var fill := MINE if me else (Deck.ROW_A if i % 2 == 0 else Deck.ROW_B)
	p.add_theme_stylebox_override("panel", UI.sb(fill, UI.GOLD if me else Deck.ROW_HOVER, 1, 4, 0))
	p.custom_minimum_size.y = ROW_H
	var h := UI.hbox(5)
	p.add_child(h)
	var txt := UI.GOLD if me else UI.TEXT
	var rkb := UI.hbox(2)
	rkb.custom_minimum_size.x = COL_RK
	h.add_child(rkb)
	var rk := UI.label(str(i + 1), 16, MEDALS[i] if i < 3 else UI.DIM, "big")
	rk.name = "Rank"
	rk.custom_minimum_size.x = 14
	rk.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rkb.add_child(rk)
	if i == 0 and played:
		# the conference leader: a gold star by the 1
		var st := UI.canvas(9, 9, func(ci): Deck.stars(ci, 0, 0, 1.0, 1, UI.GOLD))
		st.name = "Leader"
		st.tooltip_text = "Conference leader"
		st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rkb.add_child(st)
	var who := UI.hbox(4)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(who)
	var nm := UI.label(Colleges.display_name(t.name).to_upper(), 16, txt, "big")
	nm.name = "Name"
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.add_child(nm)
	for tag in _badges(i, id, played):
		who.add_child(tag)
	h.add_child(_num("%d-%d" % [rec.cw, rec.cl], COL_REC, txt))
	h.add_child(_num("%d-%d" % [rec.w, rec.l], COL_REC, txt))
	h.add_child(_num("%d-%d" % [rec.gf, rec.ga], COL_GOALS, UI.DIM))
	var ovr := t.overall_display()
	var rt := UI.hbox(4)
	rt.name = "Rating"
	rt.set_meta("ovr", ovr)
	rt.add_child(_num(str(ovr), COL_NUM, txt))
	var bar := UI.canvas(BAR_W, 6, func(ci): Deck.bar(ci, Rect2(0, 0, BAR_W, 6), ovr / 100.0, UI.GOLD, UI.INK))
	bar.name = "Bar"
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rt.add_child(bar)
	h.add_child(rt)
	for ch in h.get_children():
		ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p

func _num(text: String, w: int, colr: Color) -> Label:
	var lab := UI.label(text, 8, colr)
	lab.custom_minimum_size.x = w
	return lab

## The label a row has earned, only from what the season has settled: a conference champion, or
## an NCSA berth once the field is picked. (Your team: its gold row; the leader: the star.)
func _badges(_i: int, id: String, _played: bool) -> Array:
	if id in c.season.get("conf_champs", []):
		return [_badge("CHAMPION", UI.GOLD)]
	if id in c.season.get("nat_seeds", []):
		return [_badge("QUALIFIED", UI.GOOD)]
	return []

func _badge(text: String, fill: Color) -> Control:
	var p := PanelContainer.new()
	p.name = "Badge_" + text
	p.add_theme_stylebox_override("panel", UI.sb(fill, UI.INK, 1, 3, 0))
	p.add_child(UI.label(text, 8, UI.INK, "caps"))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p

## CHAMPIONSHIP QUALIFICATION: the rules as the schedule plays them, in a panel of their own.
func _qualification(n_conf: int) -> Control:
	var p := PanelContainer.new()
	p.name = "Qualification"
	p.add_theme_stylebox_override("panel", UI.sb(Deck.NAVY, UI.ACCENT, 1, 6, 4))
	var v := UI.vbox(2)
	p.add_child(v)
	v.add_child(UI.label("CHAMPIONSHIP QUALIFICATION", 8, UI.GOLD, "caps"))
	for line in _qualification_lines(n_conf):
		var lab := UI.label(line, 8, UI.TEXT)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size.x = 200
		v.add_child(lab)
	return p

## The rules for the conference on show: the road to the NCSA.
func _qualification_lines(n_conf: int) -> Array:
	return ["Every team plays its conference tournament, seeded by conference record (the top seeds get byes).",
		"The %d tournament champions and the %d highest-ranked other teams in the final National Top 20 poll make the %d-team NCSA Championship." % [n_conf, Schedule.NCSA_FIELD - n_conf, Schedule.NCSA_FIELD],
		"The field is seeded by that poll; seeds 1-4 skip the first round."]

## The PLAYOFFS tab: a real bracket (PlayoffBracket), rounds left to right to the champions. Any
## conference's tournament (< >, yours first) or the NCSA Championship; all of it read from the
## schedule, nothing played or drawn here.
var pfam := "conf"
var pconf := ""

func _playoffs(v: VBoxContainer) -> void:
	if pconf == "":
		pconf = conf
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL   # (the bracket centres itself in what's left)
	var confs: Array = Schedule.tournament_confs(c.teams)
	if not pconf in confs:
		pconf = String(confs[0])   # (the NWPC has no tournament to show)
	var head := UI.hbox(4)
	head.name = "BracketHead"
	if pfam == "conf" and confs.size() > 1:
		head.add_child(UI.button("<", func(): _step_conf(confs, -1), "normal", 16, 16))
	var m := PlayoffBracket.model(c, pfam, pconf)
	if pfam == "nat" and not m.empty:
		_ncsa_view(v, m)
		return
	var title := c.conf_name(pconf).to_upper() if pfam == "conf" else ("NCSA CHAMPIONSHIP - BRACKET PREVIEW" if m.get("preview", false) else "NCSA CHAMPIONSHIP")
	if pfam == "conf" and title.length() > 34:
		title = Colleges.conf_abbr(pconf) + " CHAMPIONSHIP"
	var tl := UI.label(title, 16, UI.ACCENT, "big")
	tl.name = "BracketTitle"
	head.add_child(tl)
	if pfam == "conf" and confs.size() > 1:
		head.add_child(UI.button(">", func(): _step_conf(confs, 1), "normal", 16, 16))
	head.add_child(UI.spacer(0, 0, true))
	for f in _families():
		var fam: String = f[0]
		head.add_child(UI.button(String(f[1]), func():
			pfam = fam
			_render(), "tab_on" if pfam == fam else "tab", 0, 16))
	v.add_child(head)
	var sub := UI.label(_stage(m), 8, UI.DIM, "caps")
	if m.get("preview", false):
		sub.text = "OFFICIAL PARTICIPANTS ARE DETERMINED AFTER THE CONFERENCE CHAMPIONSHIPS. SEED NUMBERS ARE BRACKET POSITIONS ONLY."
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(440, 0)
	sub.name = "BracketStage"
	v.add_child(sub)
	v.add_child(UI.spacer(0, 2))
	if m.empty:
		var msg := "The playoffs start after the regular season. Every team plays its conference tournament; then %d teams play for the NCSA Championship." % Schedule.NCSA_FIELD
		if pfam == "nat":
			msg = "The NCSA Championship field is set after the conference finals: the %d conference champions and the best-ranked teams in the final Top 20 poll, %d in all." % [Colleges.conf_ids_of(c.teams).size(), Schedule.NCSA_FIELD]
		v.add_child(para(msg, UI.DIM, 400))
		return
	v.add_child(PlayoffBracket.view(c, m, c.school))

## The tournaments to choose between.
func _families() -> Array:
	return [["conf", "CONFERENCE"], ["nat", "NCSA"]]

## The NCSA's bracket, filling the page (no scrolling): no header rows over it; its title, where
## it stands and the CONFERENCE / NCSA buttons in the open space over the final and the champion
## (PlayoffBracket's caption).
func _ncsa_view(v: VBoxContainer, m: Dictionary) -> void:
	var preview: bool = m.get("preview", false)
	m["caption"] = {"title": "NCSA CHAMPIONSHIP", "tag": "BRACKET PREVIEW" if preview else "",
		"sub": "OFFICIAL PARTICIPANTS ARE DETERMINED AFTER THE CONFERENCE CHAMPIONSHIPS. SEED NUMBERS ARE BRACKET POSITIONS ONLY." if preview else _stage(m).replace("NATIONAL CHAMPIONSHIP BRACKET  -  ", "")}
	var tl := UI.label("", 8, UI.ACCENT, "caps")   # (kept for the tests and readers: the title, not drawn)
	tl.name = "BracketTitle"
	tl.text = "NCSA CHAMPIONSHIP - BRACKET PREVIEW" if preview else "NCSA CHAMPIONSHIP"
	tl.visible = false
	v.add_child(tl)
	var view := PlayoffBracket.view(c, m, c.school)
	v.add_child(view)
	# CONFERENCE / NCSA at the right end of the tab row (the page's space all the bracket's)
	var tab_row: Node = body.get_child(body.get_child_count() - 2) if body.get_child_count() >= 2 else null   # (this render's: the old ones are still leaving)
	var row := UI.hbox(4)
	row.name = "BracketButtons"
	for f in _families():
		var fam: String = f[0]
		row.add_child(UI.button(String(f[1]), func():
			pfam = fam
			_render(), "tab_on" if pfam == fam else "tab", 0, 16))
	if tab_row is HBoxContainer:
		tab_row.add_child(UI.spacer(0, 0, true))
		tab_row.add_child(row)
	else:
		v.add_child(row)

func _step_conf(confs: Array, d: int) -> void:
	var i := confs.find(pconf)
	pconf = String(confs[posmod(i + d, confs.size())])
	_render()

## Where the tournament stands, in a line under its name.
func _stage(m: Dictionary) -> String:
	var what := "CONFERENCE CHAMPIONSHIP BRACKET" if pfam == "conf" else "NATIONAL CHAMPIONSHIP BRACKET"
	if m.empty:
		return what
	if m.projected:
		return what + "  -  PROJECTED FROM THE STANDINGS"
	if m.champion != "":
		return what + "  -  CHAMPIONS: " + Colleges.display_name((c.teams[m.champion] as PoloTeam).name).to_upper()
	for r in m.rounds:
		for mt in r.matches:
			if not mt.bye and mt.win == "" and not (mt.a == "" and mt.b == ""):
				return what + "  -  " + String(PlayoffBracket.ROUND_HEADS.get(r.kind, r.kind))
	return what
