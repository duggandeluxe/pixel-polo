extends BaseScreen
## THE ROSTER SET (the Roster Set Redesign): the off-season roster report, between seasons.
##   the header         "2026-2027 ROSTER TRANSITION", PREPARING FOR THE 2027-2028 SEASON between
##                      gold and blue rules
##   TEAM SUMMARY       logo, team, the seasons it goes between, final roster, scholarships, walk-ons
##   NEXT SEASON OUTLOOK OVR, OFF, DEF and GK as every screen shows them, each with its change from
##                      the season's start when that was kept (never a made-up "before")
##   GRADUATING PLAYERS, INCOMING FRESHMEN, ROSTER CUTS, SIGNED ELSEWHERE: a card a player
##                      (portrait, number, name, position, class, stars)
##   PLAYER DEVELOPMENT your returning players' stars, before and after the year's development
##   CAREER MILESTONES  your graduates' career records, when there are any
## scrolling on the left; YOUR SEASONS (DynastyHistory) on the right; ON TO 2027-2028 > anchored
## at the bottom. Everything comes from the report Offseason kept (RosterReport): the screen never
## works anything out and never writes to the career, except to take the report off the hub's
## queue when you move on (as the recap screen did).
##
## DEV PREVIEW (DEV Mode's VIEW ROSTER SET): opened with no report. Shows the dynasty's last real
## report (RosterReport.latest) or a sample scenario (RosterReport.sample), DEV PREVIEW across
## the top, < > through the scenarios, and RETURN TO DEV MODE in place of the continue button.
## Nothing is saved, queued or taken off the queue. Developer Mode off: straight back to settings.

const NAVY := DynastyHistory.NAVY
const NAVY_HI := DynastyHistory.NAVY_HI
const NAVY_LO := DynastyHistory.NAVY_LO
const PLATE_GOLD := DynastyHistory.PLATE_GOLD
const CARD_H := 35
const CARD_MIN_W := 136
const DEV_ROW_H := 12
const GRAD_FILL := Color("1a2350")      # departing: muted slate
const GRAD_EDGE := Color("8a94b8")
const CUT_FILL := Color("2e1230")       # cut: muted red
const CUT_EDGE := Color("c8545a")
const FRESH_EDGE := UI.GOLD
const UP := UI.GOOD
const DOWN := UI.BAD
const SAME := Color("8f98b8")
const ARROW_R := ["#...", "##..", "###.", "##..", "#..."]
const ARROW_UP := ["..#..", ".###.", "#####"]
const ARROW_DN := ["#####", ".###.", "..#.."]
const ROSTER_ICON := [".##...##.", "####.####", ".##...##.", "#####.###", "####.####", "####.####"]

## The scenario a DEV preview shows (kept while the screen is reopened for the next one).
static var scenario := ""

var data := {}
var r := {}               # the report
var dev := false          # a DEV preview: read-only, back to DEV Mode
var _team: Variant = null # what your logo and caps are drawn from (a PoloTeam, or a school's data)
var _grids: Array = []

func setup(params: Dictionary) -> void:
	data = params

func _ready() -> void:
	c = Game.career
	dev = not data.has("report")
	if dev and not bool(Game.settings.get("dev_mode", false)):
		Game.goto("settings", {}, false)   # (DEV preview only exists in Developer Mode)
		return
	r = (data.report as Dictionary) if not dev else _preview_report()
	_team = _team_src(String(r.get("team", "")), String(r.get("team_name", "")))
	back_target = "dev_settings" if dev else "hub"
	build("%s ROSTER TRANSITION" % String(r.get("from", "")), dev, false)
	body.add_child(_banner())
	if dev:
		body.add_child(_dev_bar())
	var cols := UI.hbox(6)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	var list := UI.vbox(4)
	list.name = "Report"
	var sc := UI.scroll(list)
	sc.name = "ReportScroll"
	cols.add_child(sc)
	_fill(list)
	cols.add_child(DynastyHistory.panel(_history(), 136))
	var go: Button
	if dev:
		go = Deck.button("RETURN TO DEV MODE", on_back, "primary", 0, 22)
		go.name = "ReturnDev"
	else:
		go = Deck.button("ON TO %s  >" % String(r.get("to", data.get("next", ""))), _done, "primary", 0, 22)
		go.name = "Continue"
	body.add_child(go)
	Sfx.music("menu")

func on_back() -> void:
	if dev:
		Sfx.play("back")
		Game.goto("dev_settings", {}, false)
		return
	_done()

## The report was the front of the hub's queue: it's dealt with now. (Never in a DEV preview.)
func _done() -> void:
	if dev:
		return
	if c != null and not c.queue.is_empty() and String(c.queue[0].get("type", "")) == "recap":
		c.queue.pop_front()
		Game.save_career()
	Game.goto("hub")

# ------------------------------------------------------------------ DEV preview
## The scenarios on offer: the dynasty's last real off-season first, when it has one.
func scenarios() -> Array:
	var out: Array = []
	if not RosterReport.latest(c).is_empty():
		out.append(["real", "LAST REAL OFFSEASON"])
	out.append_array(RosterReport.SCENARIOS)
	return out

func _preview_report() -> Dictionary:
	var list := scenarios()
	var keys: Array = list.map(func(s): return String(s[0]))
	if not scenario in keys:
		scenario = String(keys[0])
	if scenario == "real":
		var rep := RosterReport.latest(c)
		rep["preview"] = true
		return rep
	var id := c.school if c != null else "BROW"
	var nm := String(c.team().name) if c != null else Colleges.team_name(id)
	return RosterReport.sample(scenario, id, nm)

func _dev_bar() -> Control:
	var list := scenarios()
	var keys: Array = list.map(func(s): return String(s[0]))
	var i := keys.find(scenario)
	var h := UI.hbox(4)
	h.name = "DevBar"
	var step := func(d: int):
		scenario = String(keys[posmod(i + d, keys.size())])
		Game.goto("roster_set", {}, false)
	var prev := Deck.icon_button("left", step.bind(-1), 20, 16)
	prev.name = "PrevScenario"
	h.add_child(prev)
	var lbl := UI.canvas(0, 16, func(ci: Control):
		var rr := Rect2(Vector2.ZERO, ci.size - Vector2(0, 1))
		Deck.frame(ci, rr, NAVY_LO, Color(UI.PINK, 0.8))
		var t := "%s  (%d/%d)" % [String(list[i][1]), i + 1, list.size()]
		Deck.ctext(ci, rr, Deck.fit(t, rr.size.x - 8), 8, UI.TEXT))
	lbl.name = "Scenario"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(lbl)
	var nxt := Deck.icon_button("right", step.bind(1), 20, 16)
	nxt.name = "NextScenario"
	h.add_child(nxt)
	return h

# ------------------------------------------------------------------ the report
func _fill(v: VBoxContainer) -> void:
	v.add_child(_summary())
	v.add_child(_outlook())
	var grads: Array = r.get("grads", [])
	_players(v, "GRADUATING PLAYERS", "Graduates", grads, "grad", "NO GRADUATING PLAYERS THIS SEASON")
	var fresh: Array = r.get("fresh", [])
	_players(v, "INCOMING FRESHMEN", "Freshmen", fresh, "fresh", "NO INCOMING FRESHMEN")
	var cuts: Array = r.get("cuts", [])
	_players(v, "ROSTER CUTS", "Cuts", cuts, "cut", "NO ROSTER CUTS")
	var away: Array = r.get("elsewhere", [])
	if not away.is_empty():
		_players(v, "SIGNED ELSEWHERE", "Elsewhere", away, "away", "")
	_development(v)
	var notes: Array = r.get("notes", [])
	if not notes.is_empty():
		var nv := _panel(v, "CAREER MILESTONES", "Milestones", UI.GOLD, -1)
		for ln in notes:
			var l := UI.label(String(ln).to_upper(), 8, UI.TEXT, "caps")
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nv.add_child(l)

## The banner under the title: PREPARING FOR THE NEXT SEASON between gold and blue rules, the
## roster icon and an arrow either side (DEV PREVIEW on the right when it is one).
func _banner() -> Control:
	var mid := "PREPARING FOR THE %s SEASON" % String(r.get("to", ""))
	var tag := ""
	if dev:
		tag = "DEV PREVIEW" if String(r.get("scenario", "")) == "" else "DEV PREVIEW - SAMPLE"
	var b := UI.canvas(0, 13, func(ci: Control):
		var w := ci.size.x
		var tw := Deck.text_w(mid)
		var cx := floorf((w - tw) * 0.5)
		var right_end := w - 4.0
		if tag != "":
			var tr := Rect2(w - Deck.text_w(tag) - 10, 0, Deck.text_w(tag) + 10, 12)
			Deck.frame(ci, tr, Color("4a0f22"), UI.PINK)
			Deck.ctext(ci, tr, tag, 8, UI.PINK)
			right_end = tr.position.x - 4
			cx = minf(cx, right_end - tw - 24)
		for side in [[4.0, cx - 18.0], [cx + tw + 18.0, right_end]]:
			if side[1] > side[0]:
				ci.draw_rect(Rect2(side[0], 5, side[1] - side[0], 1), UI.GOLD)
				ci.draw_rect(Rect2(side[0], 7, side[1] - side[0], 1), UI.ACCENT)
		Deck.pat(ci, Vector2(cx - 14, 3), ROSTER_ICON, {"#": UI.GOLD})
		Deck.pat(ci, Vector2(cx + tw + 7, 4), ARROW_R, {"#": UI.GOLD})
		Deck.pat(ci, Vector2(cx + tw + 11, 4), ARROW_R, {"#": UI.ACCENT})
		Deck.shadow_text(ci, cx, 6, mid, 8, UI.GOLD))
	b.name = "Banner"
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

## A navy panel with its heading (a gold rule to the edge, the count on the right when `count`
## isn't -1) in `v`; returns the column its content goes in.
func _panel(v: VBoxContainer, title: String, name: String, col: Color, count: int, edge: Color = UI.BORDER) -> VBoxContainer:
	var p := PanelContainer.new()
	p.name = name
	p.add_theme_stylebox_override("panel", UI.chunky(NAVY, edge, false, false, 5, 4, UI.BEVEL_SOFT))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := UI.vbox(3)
	p.add_child(inner)
	var cnt := "" if count < 0 else ("%d PLAYER%s" % [count, "" if count == 1 else "S"])
	var head := UI.canvas(0, 11, func(ci: Control):
		Deck.shadow_text(ci, 1, 5, title, 8, col)
		var x := Deck.text_w(title) + 6.0
		var x_end := ci.size.x - (Deck.text_w(cnt) + 6.0 if cnt != "" else 0.0)
		if x_end > x:
			ci.draw_rect(Rect2(x, 5, x_end - x, 1), Color(col, 0.7))
			ci.draw_rect(Rect2(x, 7, x_end - x, 1), Color(col, 0.25))
		if cnt != "":
			Deck.rtext(ci, ci.size.x - 1, 5, cnt, 8, UI.DIM))
	head.name = "Head"
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(head)
	if v != null:
		v.add_child(p)
	return inner

func _empty(t: String) -> Control:
	var e := UI.canvas(0, 18, func(ci: Control):
		var rr := Rect2(Vector2.ZERO, ci.size)
		Deck.frame(ci, rr, NAVY_LO, Color(UI.DIM, 0.5))
		Deck.ctext(ci, rr, Deck.fit(t, rr.size.x - 6), 8, UI.DIM))
	e.name = "Empty"
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return e

## A grid whose columns follow its width (cards at least `min_w` wide).
func _grid(name: String, min_w: int) -> GridContainer:
	var g := GridContainer.new()
	g.name = name
	g.columns = 2
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.resized.connect(func():
		var n := clampi(int((g.size.x + 4) / (min_w + 4)), 1, 4)
		if n != g.columns:
			g.columns = n)
	_grids.append(g)
	return g

# ------------------------------------------------------------------ TEAM SUMMARY
func _summary() -> Control:
	var p := PanelContainer.new()
	p.name = "TeamSummary"
	p.add_theme_stylebox_override("panel", UI.chunky(NAVY, UI.BORDER, false, false, 5, 4, UI.BEVEL_SOFT))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UI.hbox(6)
	p.add_child(h)
	var team: Variant = _team
	var logo := UI.canvas(40, 40, func(ci: Control):
		if team != null:
			TeamLogo.draw_in(ci, Rect2(Vector2.ZERO, Vector2(40, 40)), team)
		else:
			Deck.frame(ci, Rect2(0, 0, 40, 40), NAVY_LO, Color(UI.DIM, 0.5))
			Deck.ctext(ci, Rect2(0, 0, 40, 40), "?", 8, UI.DIM))
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.name = "Logo"
	h.add_child(logo)
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var nm := String(r.get("team_name", "")).to_upper()
	var from := String(r.get("from", ""))
	var to := String(r.get("to", ""))
	var top := UI.canvas(0, 28, func(ci: Control):
		var w := ci.size.x
		if Deck.text_w(nm, 16, "big") <= w:
			Deck.shadow_text(ci, 0, 7, nm, 16, UI.TEXT, "big")
		else:
			Deck.shadow_text(ci, 0, 7, Deck.fit(nm, w), 8, UI.TEXT)
		var x := 0.0
		Deck.text(ci, x, 21, from, 8, UI.DIM)
		x += Deck.text_w(from) + 4
		Deck.pat(ci, Vector2(x, 19), ARROW_R, {"#": UI.GOLD})
		Deck.pat(ci, Vector2(x + 4, 19), ARROW_R, {"#": UI.GOLD})
		x += 12
		Deck.text(ci, x, 21, to, 8, UI.GOLD))
	top.name = "Name"
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(top)
	var chips := HFlowContainer.new()
	chips.name = "Chips"
	chips.add_theme_constant_override("h_separation", 3)
	chips.add_theme_constant_override("v_separation", 2)
	v.add_child(chips)
	var n := int(r.get("roster", 0))
	chips.add_child(_chip_box("FINAL ROSTER: %d PLAYERS" % n, UI.TEXT, Color(UI.BORDER, 0.6)))
	if r.has("schol"):
		chips.add_child(_chip_box("SCHOLARSHIPS USED: %d / %d" % [int(r.schol), int(r.get("schol_max", Career.SCHOL_MAX))], UI.TEXT, Color(UI.BORDER, 0.6)))
	if int(r.get("walkons", 0)) > 0:
		chips.add_child(_chip_box("WALK-ONS: %d" % int(r.walkons), UI.DIM, Color(UI.DIM, 0.5)))
	var last: Array = _history().get("history", [])
	if not last.is_empty() and (last[0].titles as Array).any(func(t): return String(t).to_upper().begins_with("NCSA")):
		chips.add_child(_chip_box("DEFENDING NCSA CHAMPIONS", UI.GOLD, UI.GOLD, PLATE_GOLD))
	return p

func _chip_box(t: String, col: Color, edge: Color, fill: Color = NAVY_LO) -> Control:
	var w := int(Deck.text_w(t)) + 8
	var b := UI.canvas(w, 12, func(ci: Control):
		var rr := Rect2(Vector2.ZERO, ci.size)
		Deck.frame(ci, rr, fill, edge)
		Deck.ctext(ci, rr, t, 8, col))
	b.name = "Chip"
	return b

# ------------------------------------------------------------------ NEXT SEASON OUTLOOK
func _outlook() -> Control:
	var inner := _panel(null, "NEXT SEASON OUTLOOK", "Outlook", UI.GOLD, -1, UI.GOLD)
	inner.add_child(UI.label("%s TEAM RATINGS" % String(r.get("to", "")), 8, UI.DIM, "caps"))
	var rt: Dictionary = r.get("ratings", {})
	var row := UI.hbox(4)
	row.name = "Ratings"
	inner.add_child(row)
	row.add_child(_tile("OVERALL", "OVR", rt, "ovr", false))
	row.add_child(_tile("OFFENSE", "OFF", rt, "off", true))
	row.add_child(_tile("DEFENSE", "DEF", rt, "def", true))
	row.add_child(_tile("GOALKEEPING", "GK", rt, "gk", false))
	return inner.get_parent() as Control

## One rating: its name, its value (a number, or five stars), and how it moved since the season
## started (only when that was kept).
func _tile(long: String, short: String, rt: Dictionary, key: String, stars: bool) -> Control:
	var has := rt.has(key)
	var val := float(rt.get(key, 0))
	var was_key := key + "_was"
	var t := UI.canvas(0, 42, func(ci: Control):
		var w := ci.size.x
		var rr := Rect2(0, 0, w, 41)
		Deck.frame(ci, rr, NAVY_HI, Color(UI.GOLD, 0.6))
		var title := long if Deck.text_w(long) <= w - 8 else short
		Deck.ctext(ci, Rect2(0, 2, w, 10), title, 8, UI.DIM)
		if not has:
			Deck.ctext(ci, Rect2(0, 13, w, 14), "-", 8, UI.DIM)
		elif stars:
			var sw := Deck.star_bar_w()
			Deck.stars(ci, floorf((w - sw) * 0.5), 15, val, 5, PlayerForm.GOLD)
		else:
			var s := str(int(val))
			Deck.text(ci, floorf((w - Deck.text_w(s, 20, "big")) * 0.5), 20, s, 20, UI.ovr_color(val) if key == "ovr" else UI.TEXT, "big")
		if has and rt.has(was_key):
			var d := val - float(rt[was_key])
			var txt := ""
			var col := SAME
			if absf(d) < 0.01:
				txt = "NO CHANGE"
			else:
				col = UP if d > 0 else DOWN
				txt = (("%+.1f" % d) if stars else ("%+d" % int(d)))
			var tw := Deck.text_w(txt) + (7.0 if absf(d) >= 0.01 else 0.0)
			var x := floorf((w - tw) * 0.5)
			if absf(d) >= 0.01:
				Deck.pat(ci, Vector2(x, 31), ARROW_UP if d > 0 else ARROW_DN, {"#": col})
				x += 7
			Deck.text(ci, x, 33, txt, 8, col))
	t.name = "Rating_" + short
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size.x = 58
	return t

# ------------------------------------------------------------------ the player sections
func _players(v: VBoxContainer, title: String, name: String, list: Array, kind: String, none: String) -> void:
	var col := {"grad": GRAD_EDGE, "fresh": UI.GOLD, "cut": CUT_EDGE, "away": CUT_EDGE}[kind] as Color
	var inner := _panel(v, title, name, col, list.size(), UI.GOLD if kind == "fresh" and not list.is_empty() else UI.BORDER)
	if list.is_empty():
		inner.add_child(_empty(none))
		return
	var g := _grid("Cards", CARD_MIN_W)
	inner.add_child(g)
	for e in list:
		g.add_child(_card(e, kind))

## A player's card: portrait (or its empty plate), number and name, position and class, stars
## (a freshman's up to his POTENTIAL); signed elsewhere, where he went and its logo.
func _card(e: Dictionary, kind: String) -> Control:
	var p := RosterReport.stub(e)
	var fill: Color = {"grad": GRAD_FILL, "fresh": NAVY_HI, "cut": CUT_FILL, "away": CUT_FILL}[kind]
	var edge: Color = {"grad": GRAD_EDGE, "fresh": FRESH_EDGE, "cut": CUT_EDGE, "away": CUT_EDGE}[kind]
	var text_col := UI.TEXT if kind == "fresh" else Color("d7dcef")
	var portrait: Texture2D = null if bool(e.get("no_portrait", false)) else _portrait(p)
	var dest: Variant = _team_src(String(e.get("to", "")), String(e.get("to_name", ""))) if kind == "away" else null
	var b := UI.canvas(CARD_MIN_W, CARD_H + (6 if kind == "away" else 0), func(ci: Control):
		var w := ci.size.x
		var hh := ci.size.y
		Deck.frame(ci, Rect2(0, 0, w - 1, hh - 2), fill, edge, true)
		var plate := Rect2(3, 3, 26, 29)
		ci.draw_rect(plate, UI.INK)
		if portrait != null:
			ci.draw_texture_rect(portrait, plate, false, Color(1, 1, 1, 0.75) if kind != "fresh" else Color.WHITE)
		else:
			Deck.ctext(ci, plate, "?", 8, Color(UI.DIM, 0.6))
		var x := 33.0
		var right := w - 5.0
		var num := ("#%d " % p.number) if p.number > 0 and kind != "away" else ""
		if num != "":
			Deck.text(ci, x, 7, num, 8, UI.DIM)
		var nx := x + Deck.text_w(num)
		Deck.text(ci, nx, 7, Deck.fit(p.last.to_upper(), right - nx), 8, text_col)
		var pos := p.pos_text()
		Deck.text(ci, x, 17, pos, 8, Deck.pos_color(p.pos))
		var yr := p.year_text().to_upper()
		Deck.text(ci, x + Deck.text_w(pos) + 5, 17, yr, 8, UI.GOOD if kind == "fresh" else UI.DIM)
		if kind == "fresh":
			var tag := "NEW"
			var tr := Rect2(right - Deck.text_w(tag) - 4, 12, Deck.text_w(tag) + 5, 10)
			ci.draw_rect(tr, UI.GOLD)
			Deck.ctext(ci, tr, tag, 8, UI.INK)
		var pot := p.pot_stars if kind == "fresh" else p.stars
		var bw := Deck.star_bar(ci, x, 23, p.stars, pot)
		Deck.text(ci, x + bw + 3, 27, PlayerForm.star_text(p.stars), 8, UI.GOLD)
		if kind == "away":
			var lr := Rect2(x, 34, 20, 12)
			if dest != null:
				TeamLogo.draw_in(ci, lr, dest)
			var to := "TO " + String(e.get("to_name", "")).to_upper()
			Deck.text(ci, x + 23, 38, Deck.fit(to, right - x - 23), 8, UI.ACCENT))
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.name = "Player_%d" % p.id
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = "%s %s" % [p.first, p.last]
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	return b

# ------------------------------------------------------------------ PLAYER DEVELOPMENT
func _development(v: VBoxContainer) -> void:
	var rows: Array = (r.get("dev", []) as Array).duplicate()
	var inner := _panel(v, "PLAYER DEVELOPMENT", "Development", UI.ACCENT, rows.size())
	if rows.is_empty():
		inner.add_child(_empty("NO RETURNING PLAYERS"))
		return
	rows.sort_custom(func(a, b):
		var da := float(a.now) - float(a.was)
		var db := float(b.now) - float(b.was)
		if not is_equal_approx(da, db):
			return da > db
		return float(a.now) > float(b.now))
	var up := rows.filter(func(e): return float(e.now) - float(e.was) >= 0.01).size()
	var down := rows.filter(func(e): return float(e.now) - float(e.was) <= -0.01).size()
	inner.add_child(UI.label("%d IMPROVED   %d DECLINED   %d UNCHANGED" % [up, down, rows.size() - up - down], 8, UI.DIM, "caps"))
	var g := _grid("Rows", CARD_MIN_W)
	g.add_theme_constant_override("v_separation", 2)
	inner.add_child(g)
	for e in rows:
		g.add_child(_dev_row(e))

func _dev_row(e: Dictionary) -> Control:
	var was := float(e.was)
	var now := float(e.now)
	var d := now - was
	var col := UP if d >= 0.01 else (DOWN if d <= -0.01 else SAME)
	var pos := RosterReport.pos_text(e)
	var nm := RosterReport.name_of(e)
	var b := UI.canvas(CARD_MIN_W, DEV_ROW_H, func(ci: Control):
		var w := ci.size.x
		ci.draw_rect(Rect2(0, 0, w, DEV_ROW_H - 1), NAVY_HI)
		ci.draw_rect(Rect2(0, 0, 2, DEV_ROW_H - 1), col)
		Deck.text(ci, 5, 5, pos, 8, Deck.pos_color(int(e.get("pos", 0))))
		var x := 5.0 + 22.0
		# from the right: the star, the new stars, the arrow, the old stars
		var r_x := w - 3.0
		Deck.pat(ci, Vector2(r_x - 7, 2), [".#.", "###", ".#."], {"#": UI.GOLD})
		r_x -= 10
		var now_t := PlayerForm.star_text(now)
		Deck.rtext(ci, r_x, 5, now_t, 8, col)
		r_x -= Deck.text_w(now_t) + 3
		if absf(d) >= 0.01:
			Deck.pat(ci, Vector2(r_x - 5, 4), ARROW_UP if d > 0 else ARROW_DN, {"#": col})
		else:
			Deck.pat(ci, Vector2(r_x - 4, 3), ARROW_R, {"#": col})
		r_x -= 9
		var was_t := PlayerForm.star_text(was)
		Deck.rtext(ci, r_x, 5, was_t, 8, UI.DIM)
		r_x -= Deck.text_w(was_t) + 4
		Deck.text(ci, x, 5, Deck.fit(nm, r_x - x), 8, UI.TEXT))
	b.name = "Dev_%d" % int(e.get("id", 0))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

# ------------------------------------------------------------------ helpers
## YOUR SEASONS: a sample's own, else the dynasty's (SeasonReview.history).
func _history() -> Dictionary:
	if r.has("history"):
		return r.history
	return SeasonReview.history(c) if c != null else {}

## What a team's logo is drawn from: the dynasty's team (when its name is the one given), else
## the school's data under that name; null: nothing to draw from.
func _team_src(id: String, name: String) -> Variant:
	if c != null and c.teams.has(id) and (name == "" or String(c.teams[id].name) == name):
		return c.teams[id]
	if id == "" and name == "":
		return null
	var s := Colleges.school(id)
	return {"id": id, "name": name if name != "" else String(s.get("name", id)), "c1": String(s.get("c1", "2a68f5")), "c2": String(s.get("c2", "ffffff"))}

## A player's headshot in your caps (a keeper's red).
func _portrait(p: PoloPlayer) -> Texture2D:
	var cols: Array
	if _team is PoloTeam:
		cols = Portrait.colors_ours(p, _team)
	else:
		cols = [PoolArt.CAP_KEEPER if p.is_keeper() else Color("f2f2e9"), UI.ACCENT]
	return Portrait.texture(p, cols[0], cols[1])
