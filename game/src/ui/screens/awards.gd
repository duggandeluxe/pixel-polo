extends BaseScreen
## CONFERENCE AWARDS (the hub's AWARDS; ConfAwards): the five conferences' tabs (PEC, GCC, WWPC,
## NCC, AWPC: yours first time in), a week selector over the weeks already decided (never one to
## come), and that week's four winners as cards in a 2 x 2 grid: the award, his portrait (Portrait,
## in his team's colours), name, team and logo, position and class, his stars, his week's line.
## A card opens his profile (the player page, read only; a player who's gone, as he was when he
## won). A conference with nobody who played that week says NO ELIGIBLE GAMES, an award nobody
## earned NO WINNER. AWARD HISTORY lists every award of the conference ever given, by award and
## season. Nothing here is ever worked out again: it's the saved records (Career.conf_awards).

const CARD := Vector2(232, 92)
const HIST_ROW := 15

static var conf := ""
static var at := -1          # index into ConfAwards.weeks (-1: the latest)
static var history := false
static var hist_cat := 0     # 0 all, then ConfAwards.CATS
static var hist_season := 0  # 0 all, then each season, latest first
static var for_career := 0   # the career the above were picked in (another career starts afresh)

func setup(params: Dictionary) -> void:
	detail = true   # (its team logos: TeamLogo's fine pixels)
	var cid := Game.career.get_instance_id() if Game.career != null else 0
	if cid != for_career:
		for_career = cid
		conf = ""
		at = -1
		history = false
		hist_cat = 0
		hist_season = 0
	if params.has("week"):
		var ws := ConfAwards.weeks(Game.career)
		for i in ws.size():
			if int(ws[i][0]) == int(params.get("year", 0)) and int(ws[i][1]) == int(params.week):
				at = i
		history = false
	if params.has("conf"):
		conf = String(params.conf)

func _ready() -> void:
	back_target = "hub"
	build("CONFERENCE AWARDS", true, true)
	var shown := _confs()
	if conf == "" or not conf in shown:
		conf = c.team().conf if c.team().conf in shown else String(shown[0])
	_render()

## The conferences with awards in this dynasty, CONF_ORDER's order.
func _confs() -> Array:
	var here := Schedule.tournament_confs(c.teams)
	return ConfAwards.CONF_ORDER.filter(func(id): return id in here)

func _render() -> void:
	for ch in body.get_children():
		ch.queue_free()
	var top := UI.hbox(4)
	# (your division's conferences: all of them only fit a row in a Division I dynasty)
	var ids: Array = _confs().filter(func(id): return Colleges.division(id) == Colleges.division(conf))
	var names: Array = ids.map(func(id): return Colleges.conf_abbr(id))
	top.add_child(tabs(names, Colleges.conf_abbr(conf), func(t):
		conf = ids[names.find(t)]
		_render()))
	if c.divisions.size() > 1:
		var d := Colleges.division(conf)
		var nxt: int = c.divisions[(c.divisions.find(d) + 1) % c.divisions.size()]
		var sw := UI.button("DIV %s >" % ["", "I", "II", "III"][nxt], func():
			conf = String(_confs().filter(func(id): return Colleges.division(id) == nxt)[0])
			_render(), "normal", 0, 16)
		sw.name = "DivisionSwitch"
		top.add_child(sw)
	top.add_child(UI.spacer(0, 0, true))
	var hb := UI.button("THIS WEEK" if history else "AWARD HISTORY", func():
		history = not history
		_render(), "normal", 0, 16)
	hb.name = "HistoryToggle"
	top.add_child(hb)
	body.add_child(top)
	var ws := ConfAwards.weeks(c)
	if ws.is_empty():
		body.add_child(UI.spacer(0, 30))
		body.add_child(centered(para("No awards yet: each conference names its four once a week's games are all played.", UI.DIM, 300)))
		return
	if history:
		_history(ws)
		return
	if at < 0 or at >= ws.size():
		at = ws.size() - 1
	body.add_child(_week_bar(ws))
	var grid := GridContainer.new()
	grid.name = "Cards"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 5)
	var wk: Array = ws[at]
	var recs := ConfAwards.of(c, int(wk[0]), int(wk[1]), conf)
	for cat in ConfAwards.CATS:
		grid.add_child(_card(cat, recs.get(cat, {}), recs.is_empty()))
	var cc := centered(grid)
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cc)

## < 2026-27 WEEK 3 >: only the weeks decided.
func _week_bar(ws: Array) -> Control:
	var h := UI.hbox(6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var prev := UI.button("<", func():
		at = maxi(0, at - 1)
		_render(), "normal", 22, 16)
	prev.name = "PrevWeek"
	prev.disabled = at <= 0
	h.add_child(prev)
	var wk: Array = ws[at]
	var l := UI.label("%s  %s" % [String(wk[3]), String(wk[2])], 16, UI.GOLD, "big")
	l.name = "WeekLabel"
	l.custom_minimum_size.x = 180
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(l)
	var nxt := UI.button(">", func():
		at = mini(ws.size() - 1, at + 1)
		_render(), "normal", 22, 16)
	nxt.name = "NextWeek"
	nxt.disabled = at >= ws.size() - 1
	h.add_child(nxt)
	return h

## One award's card: its title, then the winner (portrait, name, team and logo, position and
## class, stars, the week's line); NO WINNER / NO ELIGIBLE GAMES when there's nobody.
func _card(cat: String, rec: Dictionary, no_games: bool) -> Control:
	var title: String = ConfAwards.TITLES[cat]
	if rec.is_empty():
		var empty := UI.canvas(int(CARD.x), int(CARD.y), func(ci: Control):
			Deck.frame(ci, Rect2(Vector2.ZERO, CARD), Deck.NAVY, UI.BORDER)
			Deck.ctext(ci, Rect2(0, 4, CARD.x, 10), title, 8, UI.GOLD)
			Deck.ctext(ci, Rect2(0, CARD.y * 0.5, CARD.x, 10), "NO ELIGIBLE GAMES" if no_games else "NO WINNER", 8, UI.DIM))
		empty.name = "Card_" + cat
		return empty
	var p := ConfAwards.player_of(c, rec)
	var t: PoloTeam = c.teams.get(String(rec.team))
	var b := Deck.card(CARD, func(ci, _r, mode):
		Deck.frame(ci, Rect2(Vector2.ZERO, CARD), Deck.NAVY_HEAD.lightened(0.08) if mode != "normal" else Deck.NAVY, UI.GOLD if mode != "normal" else UI.BORDER)
		Deck.ctext(ci, Rect2(0, 3, CARD.x, 10), title, 8, UI.GOLD)
		ci.draw_rect(Rect2(6, 14, CARD.x - 12, 1), Color(UI.GOLD, 0.4))
		# his portrait in his team's colours (a keeper's cap red)
		var px := Rect2(6, 19, 40, 44)
		ci.draw_rect(px, Color("081650"))
		if p != null and t != null:
			var cap := PoolArt.CAP_KEEPER if p.is_keeper() else t.c1
			ci.draw_texture_rect(Portrait.texture_zoomed(p, cap, t.c2, Portrait.CARD_ZOOM), Rect2(px.position + Vector2(2, 3), Vector2(Portrait.CARD_ZOOM)), false)
		Deck.frame(ci, px, Color(0, 0, 0, 0), UI.BORDER)
		var x := 52.0
		var w := CARD.x - x - 6.0
		Deck.text(ci, x, 23, Deck.fit(String(rec.name).to_upper(), w, 16, "big"), 16, UI.TEXT, "big")
		Deck.text(ci, x + 20, 36, Deck.fit((t.name if t != null else String(rec.team)).to_upper(), w - 20), 8, UI.ACCENT)
		var cls: String = ["", "FRESHMAN", "SOPHOMORE", "JUNIOR", "SENIOR"][clampi(int(rec.cls), 1, 4)]
		Deck.text(ci, x, 47, "%s  -  %s" % [PoloPlayer.POS_SHORT[int(rec.pos)], cls], 8, UI.DIM)
		Deck.star_bar(ci, x, 53, float(rec.stars), float(rec.stars))
		Deck.text(ci, 6, 77, Deck.fit(ConfAwards.line_text(rec), CARD.x - 12), 8, UI.TEXT), func(): _open(rec))
	b.name = "Card_" + cat
	b.set_meta("pid", int(rec.pid))
	if t != null:
		var logo := TeamLogo.widget(t, TeamLogo.SMALL)
		logo.position = Vector2(52, 31)
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(logo)
	return b

## His profile, read only (the player page; a player who's gone, as he was).
func _open(rec: Dictionary) -> void:
	if ConfAwards.player_of(c, rec) == null:
		# (an alumnus from before your dynasty, Legacy: his record is all that's kept)
		Game.toast("%s: A FORMER PLAYER, BEFORE YOUR TIME" % String(rec.name).to_upper(), UI.ACCENT)
		return
	Game.goto("player", {"id": int(rec.pid), "view": true})

# ------------------------------------------------------------------ history
## Every award of this conference ever given, newest first, by award (ALL, POTW...) and season.
func _history(ws: Array) -> void:
	var seasons: Array = []
	for w in ws:
		if not String(w[3]) in seasons:
			seasons.push_front(String(w[3]))
	hist_season = clampi(hist_season, 0, seasons.size())
	var f := UI.hbox(4)
	var cats: Array = ["ALL AWARDS"] + ConfAwards.CATS.map(func(k): return String(ConfAwards.SHORT[k]))
	f.add_child(UI.button(cats[hist_cat], func():
		hist_cat = (hist_cat + 1) % cats.size()
		_render(), "tab", 0, 16))
	f.add_child(UI.button("ALL SEASONS" if hist_season == 0 else String(seasons[hist_season - 1]), func():
		hist_season = (hist_season + 1) % (seasons.size() + 1)
		_render(), "tab", 0, 16))
	body.add_child(f)
	var list := UI.vbox(1)
	list.name = "HistoryList"
	var rows: Array = c.conf_awards.filter(func(a):
		return String(a.conf) == conf and (hist_cat == 0 or String(a.cat) == ConfAwards.CATS[hist_cat - 1]) \
			and (hist_season == 0 or String(a.season) == String(seasons[hist_season - 1])))
	rows.reverse()
	for a in rows.slice(0, 200):
		var rec: Dictionary = a
		var h := UI.hbox(4)
		h.add_child(fixed_label(String(rec.season), 38, UI.DIM))
		h.add_child(fixed_label(String(rec.label), 50, UI.TEXT))
		h.add_child(fixed_label(String(ConfAwards.SHORT[String(rec.cat)]), 34, UI.GOLD))
		h.add_child(fixed_label(Deck.fit(String(rec.name).to_upper(), 90), 90, UI.TEXT))
		h.add_child(fixed_label(Deck.fit(Colleges.short_name(c.teams[String(rec.team)]).to_upper() if c.teams.has(String(rec.team)) else String(rec.team), 70), 70, UI.ACCENT))
		h.add_child(UI.label(Deck.fit(ConfAwards.line_text(rec), 150), 8, UI.DIM, "caps"))
		list.add_child(row_button(h, func(): _open(rec), false, HIST_ROW))
	if rows.is_empty():
		list.add_child(UI.label("Nothing yet.", 8, UI.DIM))
	var sc := UI.scroll(list)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sc)
