extends BaseScreen
## THE RECORD BOOK (the Dynasty Hub): the dynasty's history, all from what was saved, laid out
## like PROGRAM OVERVIEW and the GAME GUIDE: navy panels, big cyan headings, white labels, the
## marks themselves in gold.
##   TEAM           PROGRAM RECORDS (most wins in a season and the best season: your seasons,
##                  Career.history) and CHAMPIONSHIP HISTORY (the titles won: Career.coach, the
##                  trophy case's count) side by side; under them the SCHOOL RECORD BOOK's team marks
##   PLAYERS        the school book's player records (Records), a panel each for a game, a season
##                  and a college career
##   NCSA           the league's book, the same three panels, with each holder's team
##   SEASON AWARDS  the post-season awards (Awards: Player of the Year...), a panel a season
## WEEKLY AWARDS opens the conference awards' screen and its history (ConfAwards): the one
## awards system, not a second. Only how it looks is this screen's: every number is read the way
## it always was.

const TABS := ["TEAM", "PLAYERS", "NCSA", "SEASON AWARDS"]
const TEAM_KEYS := ["season_wins", "game_team_goals", "game_margin"]
const PLAYER_KEYS := ["game_goals", "game_saves", "season_goals", "season_assists", "season_saves",
	"career_goals", "career_assists", "career_steals", "career_blocks", "career_saves"]
## The player books' panels: a heading and the records under it (by their key's start).
const GROUPS := [["SINGLE GAME", "game_"], ["SINGLE SEASON", "season_"], ["COLLEGE CAREER", "career_"]]
## The book's columns, [heading, width] (px at the 480-wide layout). The school's own book has no
## TEAM column (every holder's yours); the league's does.
const COLS_SCHOOL := [["RECORD", 168], ["VALUE", 40], ["HOLDER", 158], ["YEAR", 52]]
const COLS_NCSA := [["RECORD", 132], ["VALUE", 34], ["HOLDER", 100], ["TEAM", 104], ["YEAR", 44]]
const ROW_GAP := 3
const LINE := Color(1, 1, 1, 0.16)   # the thin rule between a book's rows

static var tab := "TEAM"

func _ready() -> void:
	back_target = "more"
	build("RECORD BOOK", true, true)
	_render()

func _render() -> void:
	for ch in body.get_children():
		ch.queue_free()
	if not tab in TABS:
		tab = "TEAM"
	var top := UI.hbox(4)
	top.add_child(tabs(TABS, tab, func(t):
		tab = t
		_render()))
	top.add_child(UI.spacer(0, 0, true))
	var wk := UI.button("WEEKLY AWARDS  >", func(): Game.goto("awards"), "primary", 0, 16)
	wk.name = "WeeklyAwards"
	top.add_child(wk)
	body.add_child(top)
	var v := UI.vbox(6)
	v.name = "Book"
	var sc := UI.scroll(v)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sc)
	match tab:
		"TEAM":
			_team(v)
		"PLAYERS":
			_groups(v, Records.school_book(c, c.school), PLAYER_KEYS, COLS_SCHOOL)
		"NCSA":
			_groups(v, Records.ncsa_book(c), Records.KEYS, COLS_NCSA)
		"SEASON AWARDS":
			_awards(v)

# ------------------------------------------------------------------ the pieces
## A navy panel holding `content`, named `name` (tests, the layout checks).
func _panel(content: Control, name: String) -> PanelContainer:
	var p := navy_panel(content)
	p.name = name
	return p

## A panel's heading: big, cyan, a rule under it.
func _head(v: VBoxContainer, t: String) -> void:
	v.add_child(big_text(t, UI.ACCENT))
	v.add_child(divider_line())

## One cell: `text` in the caps pixel font, cut to fit `w` (a "." where it's cut), never into the next.
func _cell(text: String, w: int, col: Color, right := false) -> Label:
	var l := UI.label(Deck.fit(text, w), 8, col, "caps")
	l.custom_minimum_size = Vector2(w, 0)
	l.clip_text = true
	if right:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l

func _rule() -> Control:
	var d := UI.canvas(0, 1, func(ci): ci.draw_rect(Rect2(0, 0, ci.size.x, 1), LINE))
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return d

## A headline mark: its name in white (`sub` under it, smaller and dimmer: the season), the mark
## itself big and gold on the right (dim when there's nothing to show yet).
func _mark(v: VBoxContainer, k: String, sub: String, val: String, lit: bool, name: String) -> void:
	var h := UI.hbox(4)
	h.name = name
	var left := UI.vbox(1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(UI.label(k, 8, UI.TEXT, "caps"))
	if sub != "":
		left.add_child(UI.label(sub, 8, UI.DIM2, "caps"))
	h.add_child(left)
	var n := UI.label(val, 16, UI.GOLD if lit else UI.DIM2, "big")
	n.name = "Value"
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	n.add_theme_color_override("font_outline_color", UI.INK)
	n.add_theme_constant_override("outline_size", 2)
	h.add_child(n)
	v.add_child(h)

# ------------------------------------------------------------------ TEAM
## Your program: the seasons you've coached here, the titles, the school book's team marks.
func _team(v: VBoxContainer) -> void:
	var mine: Array = c.history.filter(func(h): return String(h.team) == c.school)
	var most := {}
	var best := {}
	for h in mine:
		if most.is_empty() or int(h.w) > int(most.w):
			most = h
		var pct := float(h.w) / maxf(1.0, float(h.w) + float(h.l))
		if best.is_empty() or pct > float(best.w) / maxf(1.0, float(best.w) + float(best.l)):
			best = h
	var row := UI.hbox(6)
	row.name = "TeamRow"
	v.add_child(row)
	# PROGRAM RECORDS
	var pr := UI.vbox(4)
	_head(pr, "PROGRAM RECORDS")
	var none := "NO FINISHED SEASON YET"
	_mark(pr, "MOST WINS IN A SEASON", String(most.year) if not most.is_empty() else none,
		str(int(most.w)) if not most.is_empty() else "-", not most.is_empty(), "MostWins")
	_mark(pr, "BEST SEASON RECORD", String(best.year) if not best.is_empty() else none,
		"%d-%d" % [int(best.w), int(best.l)] if not best.is_empty() else "-", not best.is_empty(), "BestSeason")
	row.add_child(_panel(pr, "ProgramRecords"))
	# CHAMPIONSHIP HISTORY: the trophy case's count (Career.coach titles: "2026-27 PEC", "2026-27 NCSA")
	var ch := UI.vbox(4)
	_head(ch, "CHAMPIONSHIP HISTORY")
	var titles: Array = c.coach.get("titles", [])
	var nat := titles.filter(func(x): return String(x).ends_with("NCSA")).size()
	var conf := titles.size() - nat
	_mark(ch, "CONFERENCE CHAMPIONSHIPS", "", str(conf), conf > 0, "ConfTitles")
	_mark(ch, "NATIONAL CHAMPIONSHIPS", "", str(nat), nat > 0, "NatTitles")
	row.add_child(_panel(ch, "ChampionshipHistory"))
	# the SCHOOL RECORD BOOK's team marks
	var sb := UI.vbox(ROW_GAP)
	_head(sb, "SCHOOL RECORD BOOK")
	_table(sb, Records.school_book(c, c.school), TEAM_KEYS, COLS_SCHOOL)
	v.add_child(_panel(sb, "SchoolBook"))

# ------------------------------------------------------------------ the books
## A book's records in a panel a group (a game, a season, a career).
func _groups(v: VBoxContainer, book: Dictionary, keys: Array, cols: Array) -> void:
	for g in GROUPS:
		var ks := keys.filter(func(k): return String(k).begins_with(String(g[1])))
		if ks.is_empty():
			continue
		var p := UI.vbox(ROW_GAP)
		_head(p, String(g[0]))
		_table(p, book, ks, cols)
		v.add_child(_panel(p, "Group_" + String(g[1]).trim_suffix("_")))
	var legend := UI.label("GOLD HOLDER: SET BY YOUR PROGRAM.", 8, UI.DIM, "caps")
	legend.name = "Legend"
	v.add_child(legend)

## The table: the column headings, then a row a record (`keys` in `book`), a thin rule between.
func _table(v: VBoxContainer, book: Dictionary, keys: Array, cols: Array) -> void:
	var head := UI.hbox(6)
	for col in cols:
		head.add_child(_cell(String(col[0]), int(col[1]), UI.ACCENT, String(col[0]) == "VALUE"))
	v.add_child(head)
	var first := true
	for k in keys:
		var r: Dictionary = book.get(k, {})
		if r.is_empty():
			continue
		if not first:
			v.add_child(_rule())
		first = false
		var h := UI.hbox(6)
		h.name = "Record_" + String(k)
		h.add_child(_cell(Records.NAMES[k], int(cols[0][1]), UI.TEXT))
		var mine: bool = String(r.team) == c.school and str(r.year).length() > 4
		h.add_child(_cell(str(int(r.v)), int(cols[1][1]), UI.GOLD, true))
		h.add_child(_cell(String(r.name), int(cols[2][1]), UI.GOLD if mine else UI.TEXT))
		var i := 3
		if cols.size() == 5:
			h.add_child(_cell(Colleges.team_name(String(r.team)), int(cols[3][1]), UI.DIM))
			i = 4
		h.add_child(_cell(str(r.year), int(cols[i][1]), UI.DIM))
		v.add_child(h)
	if cols == COLS_SCHOOL and keys == TEAM_KEYS:
		v.add_child(UI.label("GOLD HOLDER: SET BY YOUR PROGRAM.", 8, UI.DIM, "caps"))

# ------------------------------------------------------------------ SEASON AWARDS
## The post-season awards, newest season first, a panel each: the season's awards (Awards), then
## its All-Tournament honours (TourneyAwards), each with the totals that won it and the school he
## won it for (not wherever he plays now).
func _awards(v: VBoxContainer) -> void:
	var seasons: Array = []
	for a in c.awards:
		if not String(a.year) in seasons:
			seasons.append(String(a.year))
	for a in c.tourney_awards:
		if not String(a.season) in seasons:
			seasons.append(String(a.season))
	if seasons.is_empty():
		var p := UI.vbox(4)
		_head(p, "SEASON AWARDS")
		p.add_child(para("The awards are handed out after the season: NCSA Player, Defensive Player and Freshman of the Year, the Golden Arm (most goals), the Iron Wall (most saves), the All-NCSA First and Second Teams, Coach of the Year and the All-Conference team. Every conference tournament and the NCSA Championship name their Player, Offensive and Defensive Player of the Tournament.", UI.TEXT, 440))
		v.add_child(_panel(p, "AwardsEmpty"))
		return
	seasons.sort()
	seasons.reverse()
	for year in seasons:
		var p := UI.vbox(ROW_GAP)
		var past := Legacy.is_history(c, year)
		_head(p, "%s SEASON AWARDS%s" % [year, "  (BEFORE YOUR DYNASTY)" if past else ""])
		for e in c.legacy:
			if String(e.season) == year:
				# that season's champions (Legacy: the league's past)
				var names := PackedStringArray(["NCSA: " + _team_name(String(e.nat))])
				var cfs: Array = (e.conf as Dictionary).keys()
				cfs.sort()
				for cf in cfs:
					names.append("%s: %s" % [Colleges.conf_abbr(String(cf)), _team_name(String(e.conf[cf]))])
				var ch := UI.label("CHAMPIONS  -  " + "   ".join(names), 8, UI.GOLD, "caps")
				ch.name = "Champions"
				ch.custom_minimum_size = Vector2(430, 0)
				ch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				p.add_child(ch)
		for e in c.champions_log:
			if String(e.season) == year and not (e.get("finals", []) as Array).is_empty():
				# that season's finals: who beat whom, for every championship
				for ln in TeamHonours.lines_of(e, func(id): return _team_name(id)):
					var fl := UI.label(ln, 8, UI.GOLD, "caps")
					fl.name = "Final"
					fl.custom_minimum_size = Vector2(430, 0)
					fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					p.add_child(fl)
		v.add_child(_panel(p, "Awards_" + year))
		for a in c.awards:
			if String(a.year) != year:
				continue
			if p.get_child_count() > 2:
				p.add_child(_rule())
			var h := UI.hbox(6)
			var mine: bool = String(a.team) == c.school
			var title := String(Awards.TITLES.get(a.award, a.award))
			if String(a.get("slot", "")) != "":
				title += " - " + String(a.slot)        # All-NCSA: his place on the team
			elif bool(a.get("co", false)):
				title += " (co-winner)"
			h.add_child(_cell(title, 206, UI.TEXT))
			h.add_child(_cell(String(a.name), 112, UI.GOLD if mine else UI.TEXT))
			h.add_child(_cell(_team_name(String(a.team)), 112, UI.DIM))
			p.add_child(h)
			if a.has("pid") and a.has("line") and NationalAwards.line_text(a) != "":
				# the NCSA's own: the season that won it
				var nl := _cell(NationalAwards.line_text(a), 430, UI.DIM2)
				nl.name = "NationalLine"
				p.add_child(nl)
		for a in c.tourney_awards:
			if String(a.season) != year:
				continue
			if p.get_child_count() > 2:
				p.add_child(_rule())
			var h := UI.hbox(6)
			h.name = "Tourney_%s_%s" % [String(a.tid).replace(":", "_"), a.cat]
			var mine: bool = String(a.team) == c.school
			h.add_child(_cell("%s %s" % [TourneyAwards.prefix(String(a.tid)), TourneyAwards.TITLES[a.cat]], 206, UI.TEXT))
			h.add_child(_cell(String(a.name), 112, UI.GOLD if mine else UI.TEXT))
			h.add_child(_cell(_team_name(String(a.team)), 112, UI.DIM))
			p.add_child(h)
			if TourneyAwards.line_text(a) != "":
				var ln := _cell(TourneyAwards.line_text(a), 430, UI.DIM2)
				ln.name = "TourneyLine"
				p.add_child(ln)

func _team_name(id: String) -> String:
	return String(c.teams[id].name) if c.teams.has(id) else Colleges.team_name(id)

func on_back() -> void:
	Sfx.play("back")
	Game.goto("more")
