extends BaseScreen
## LEAGUE NEWS (the Dynasty Hub's card): scores, news & records.
##   LEAGUE: AROUND THE CONFERENCE first, on a featured board (only the games your conference's teams
##     played, theirs against each other and against anyone else), then AROUND COLLEGE WATER POLO
##     (every finished game of the week shown, across the country). The week shown is this week once any of its games are
##     in, else the last week that was played (board_week). Only the saved results are read: no
##     game is ever played, or made up, to fill the page. The rows are the postgame scoreboard's
##     old look: dark navy rows, the winner in white with his score in yellow.
##   YOUR PROGRAM: your own program's running news (Career.news: results, signings, injuries...),
##     NCSA records only when your program set them (program_news).
##   LEAGUE RECORDS: every NCSA record broken in this dynasty, oldest first, kept for good (league_records).
## (The league's stories, Career.league_news, are still written and saved by LeagueNews.)

const TABS := ["LEAGUE", "YOUR PROGRAM", "LEAGUE RECORDS"]
const NAVY := Color("071b3f")
const ROW_A := Color(0.03, 0.09, 0.22, 0.88)
const ROW_B := Color(0.03, 0.09, 0.22, 0.66)
const YELLOW := Color("ffd83d")
# AROUND THE CONFERENCE's featured board: still the navy scoreboard, but a royal-blue heading
# strip with its title in gold between two stars, a gold double frame, and rows a shade bluer
const FEAT_HEAD := Color("1f56c9")
const FEAT_A := Color(0.05, 0.15, 0.36, 0.94)
const FEAT_B := Color(0.05, 0.15, 0.36, 0.76)
const FEAT_GOLD := Color("ffd83d")
const FEAT_GOLD_DIM := Color("b8860b")
const HEAD_H := 16.0
const ROW_H := 18.0
const MAX_W := 400.0          # the scoreboard is never wider than this, centred on the page

static var tab := "LEAGUE"

func _init() -> void:
	detail = true   # (as before: its fine pixels)

func _ready() -> void:
	back_target = "more"
	build("LEAGUE NEWS", true, true)
	_render()

func _render() -> void:
	for ch in body.get_children():
		ch.queue_free()
	body.add_child(tabs(TABS, tab, func(t):
		tab = t
		_render()))
	var list := UI.vbox(6 if tab == "LEAGUE" else 0)
	if tab == "LEAGUE":
		list.name = "Scoreboard"
		var wk := board_week(c)
		var label := ConfAwards.week_label(c, wk) if wk >= 0 else ""
		var all := national(c)
		var conf := conference(c)
		# your conference first, featured, then the rest of the country
		var conf_box := _board("AROUND THE CONFERENCE", label, conf, true)
		conf_box.name = "AroundConference"
		list.add_child(conf_box)
		var nat_box := _board("AROUND COLLEGE WATER POLO", label, all)
		nat_box.name = "AroundCollege"
		list.add_child(nat_box)
	elif tab == "YOUR PROGRAM":
		# AROUND YOUR PROGRAM: the LEAGUE board's heading strip, then a row a story (newest first,
		# as Career.news keeps them), or NO PROGRAM NEWS YET
		# (the week on the right: the LEAGUE board's, or this week before a ball is thrown)
		var wk := board_week(c)
		if wk < 0:
			wk = clampi(c.week, 0, maxi(0, c.schedule.size() - 1))
		var label := ConfAwards.week_label(c, wk) if not c.schedule.is_empty() else ""
		list.add_child(_feed_head("AROUND YOUR PROGRAM", label, "ProgramHead"))
		list.add_child(_feed("Stories", program_news(c).map(func(n): return story(c, n)), "NO PROGRAM NEWS YET"))
	else:
		# LEAGUE RECORDS: the NCSA book, every school's marks (Records.ncsa_book)
		list.add_child(_feed_head("COLLEGE WATER POLO RECORDS", "NCSA", "RecordsHead"))
		list.add_child(_feed("LeagueRecords", league_records(c), "NO RECORDS YET"))
	var sc := UI.scroll(list)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sc)

# ------------------------------------------------------------------ the results
## The week the scoreboard shows: this week once any of its games are in, else the last week
## with a result (-1 before a ball is thrown).
static func board_week(c: Career) -> int:
	var i := mini(c.week, c.schedule.size() - 1)
	while i >= 0:
		if (c.schedule[i].get("games", []) as Array).any(func(g): return g.r != null):
			return i
		i -= 1
	return -1

## Every finished game of that week, in the order they were played (each once).
static func national(c: Career) -> Array:
	var wk := board_week(c)
	if wk < 0:
		return []
	var out: Array = []
	for g in c.schedule[wk].games:
		if g.r != null and not out.has(g):
			out.append(g)
	out.sort_custom(func(a, b): return int(a.get("d", 0)) < int(b.get("d", 0)))
	return out

## ...the ones a team from your conference played (in or out of conference).
static func conference(c: Career) -> Array:
	var me: PoloTeam = c.team()
	if me == null:
		return []
	return national(c).filter(func(g): return _conf_of(c, g.h) == me.conf or _conf_of(c, g.a) == me.conf)

static func _conf_of(c: Career, id: String) -> String:
	var t: PoloTeam = c.teams.get(id)
	return t.conf if t != null else ""

# ------------------------------------------------------------------ drawing
## One scoreboard: the heading strip (title, the week on the right), then a row a game, or
## NO RESULTS YET. featured: the conference's look (FEAT_*).
func _board(title: String, label: String, games: Array, featured := false) -> Control:
	var rows := maxi(1, games.size())
	var cv := UI.canvas(0, int(HEAD_H + rows * ROW_H), func(ci: Control):
		var w := minf(MAX_W, ci.size.x)
		var x := roundf((ci.size.x - w) / 2.0)
		var full := Rect2(x, 0, w, HEAD_H + rows * ROW_H)
		ci.draw_rect(Rect2(x, 0, w, HEAD_H), FEAT_HEAD if featured else Color(NAVY, 0.9))
		if featured:
			# a star either side of the gold title, a gold rule under the strip
			_star(ci, Vector2(x + 9, 8))
			UI.text(ci, Vector2(x + 16, 12), title, 8, FEAT_GOLD, "caps")
			_star(ci, Vector2(x + 16 + UI.text_width(title, 8, "caps") + 6, 8))
			ci.draw_rect(Rect2(x, HEAD_H - 1, w, 1), FEAT_GOLD_DIM)
		else:
			UI.text(ci, Vector2(x + 6, 12), title, 8, UI.TEXT, "caps")
		if label != "":
			UI.text(ci, Vector2(x + w - 6 - UI.text_width(label, 8, "caps"), 12), label, 8, Color("cfe0ff") if featured else Color("9fc3ff"), "caps")
		if games.is_empty():
			ci.draw_rect(Rect2(x, HEAD_H, w, ROW_H), FEAT_A if featured else ROW_A)
			UI.text(ci, Vector2(x, HEAD_H + 12), "NO RESULTS YET", 8, UI.DIM, "caps", HORIZONTAL_ALIGNMENT_CENTER, w)
		for i in games.size():
			draw_row(ci, c, games[i], Rect2(x, HEAD_H + i * ROW_H, w, ROW_H), i, featured)
		if featured:
			# the gold double frame: a bright outer line, a darker one just inside
			ci.draw_rect(full.grow(1.0), FEAT_GOLD, false, 1.0)
			ci.draw_rect(full, FEAT_GOLD_DIM, false, 1.0)
		else:
			ci.draw_rect(full, UI.BORDER, false, 1.0))
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return cv

## A small gold pixel star (5 wide) centred on c.
static func _star(ci: CanvasItem, c: Vector2) -> void:
	var p := c.round()
	ci.draw_rect(Rect2(p.x - 0.5, p.y - 2.5, 1, 5), FEAT_GOLD)
	ci.draw_rect(Rect2(p.x - 2.5, p.y - 0.5, 5, 1), FEAT_GOLD)
	ci.draw_rect(Rect2(p.x - 1.5, p.y - 1.5, 3, 3), FEAT_GOLD)

## A result's row: the clubs either side of the score, the winner in white with his score in
## yellow, the loser dimmed; shootout goals in brackets after a shootout; a gold edge on your own game. featured:
## the conference board's bluer rows.
static func draw_row(ci: CanvasItem, c: Career, g: Dictionary, r: Rect2, i: int, featured := false) -> void:
	var x := r.position.x
	var w := r.size.x
	var ry := r.position.y
	var ink: Color = UI.TEXT
	var dim: Color = UI.DIM
	var hi: Color = YELLOW
	if featured:
		ci.draw_rect(r, FEAT_A if i % 2 == 0 else FEAT_B)
	else:
		ci.draw_rect(r, ROW_A if i % 2 == 0 else ROW_B)
	if String(g.h) == c.school or String(g.a) == c.school:
		ci.draw_rect(r.grow(-1.0), UI.GOLD, false, 1.0)
	var mid := roundf(x + w / 2.0)
	var hw: bool = Schedule.winner(g) == String(g.h)
	var so: Array = g.r.get("so", [])
	var ls := Schedule.side_text(g.r.s, so, 0)
	var rs := Schedule.side_text(g.r.s, so, 1)
	# the scores sit either side of the dash; after a shootout each carries its shootout
	# goals, 10(3) - 10(2), and the names make room
	var col := maxf(24.0, maxf(UI.text_width(ls, 16, "big"), UI.text_width(rs, 16, "big")))
	var gap := 8.0 + col + 6.0
	var hn := ResultsPanel._fit(c.teams[g.h] as PoloTeam, w / 2.0 - gap - 6.0)
	var an := ResultsPanel._fit(c.teams[g.a] as PoloTeam, w / 2.0 - gap - 6.0)
	var by := ry + 12.0
	UI.text(ci, Vector2(mid - gap - UI.text_width(hn, 8, "caps"), by), hn, 8, ink if hw else dim, "caps")
	UI.text(ci, Vector2(mid + gap, by), an, 8, dim if hw else ink, "caps")
	UI.text(ci, Vector2(mid - 8 - col, by + 2), ls, 16, hi if hw else dim, "big", HORIZONTAL_ALIGNMENT_CENTER, col)
	UI.text(ci, Vector2(mid - 8, by + 2), "-", 16, dim, "big", HORIZONTAL_ALIGNMENT_CENTER, 16)
	UI.text(ci, Vector2(mid + 8, by + 2), rs, 16, dim if hw else hi, "big", HORIZONTAL_ALIGNMENT_CENTER, col)

# ------------------------------------------------------------------ the feeds
## A feed's heading strip: the scoreboard's (title, the label on the right), open at the bottom
## for its rows.
func _feed_head(title: String, label: String, node_name: String) -> Control:
	var head := UI.canvas(0, int(HEAD_H), func(ci: Control):
		var w := minf(MAX_W, ci.size.x)
		var x := roundf((ci.size.x - w) / 2.0)
		ci.draw_rect(Rect2(x, 0, w, HEAD_H), Color(NAVY, 0.9))
		UI.text(ci, Vector2(x + 6, 12), title, 8, UI.TEXT, "caps")
		if label != "":
			UI.text(ci, Vector2(x + w - 6 - UI.text_width(label, 8, "caps"), 12), label, 8, Color("9fc3ff"), "caps")
		ci.draw_rect(Rect2(x, 0, w, 1), UI.BORDER)
		ci.draw_rect(Rect2(x, 0, 1, HEAD_H), UI.BORDER)
		ci.draw_rect(Rect2(x + w - 1, 0, 1, HEAD_H), UI.BORDER))
	head.name = node_name
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return head

## A feed's rows (NewsRow a row), or its one empty line.
func _feed(node_name: String, rows: Array, empty: String) -> Control:
	var box := UI.vbox(0)
	box.name = node_name
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in rows.size():
		box.add_child(NewsRow.new(rows[i], i, i == rows.size() - 1))
	if rows.is_empty():
		box.add_child(NewsRow.new({"empty": empty}, 0, true))
	return box

## YOUR PROGRAM's stories: Career.news, newest first, less the NCSA records another school set
## (an older save has them: since then only your own are written, Records.breaks). The news
## itself is kept as it was.
static func program_news(c: Career) -> Array:
	return c.news.filter(func(n): return not _others_record(c, String(n.get("t", ""))))

## "NCSA RECORD! Goals in a game: 9, C. Lee (San Jose Warriors)" set by anyone but you. A team's
## mark names the team; a player's names him, then his team in brackets.
static func _others_record(c: Career, t: String) -> bool:
	var m := _rx(r"^NCSA RECORD! (.+?): (\d+), (.+)$").search(t.strip_edges().to_upper())
	if m == null or c.team() == null:
		return false
	var me := String(c.team().name).to_upper()
	var by := m.get_string(3)
	return by != me and not by.ends_with("(%s)" % me)

## LEAGUE RECORDS: every NCSA record broken in this dynasty (Records.ncsa_log), oldest first, each
## kept for good (a mark broken again stays listed): what, how many, who (and his team), its week
## and its season. Nothing from before the dynasty began.
const RECORD_TITLES := {
	"game_goals": ["MOST GOALS - SINGLE GAME", "GOALS"], "game_saves": ["MOST SAVES - SINGLE GAME", "SAVES"],
	"game_team_goals": ["MOST TEAM GOALS - SINGLE GAME", "GOALS"], "game_margin": ["LARGEST MARGIN OF VICTORY", "GOALS"],
	"season_goals": ["MOST GOALS - SEASON", "GOALS"], "season_assists": ["MOST ASSISTS - SEASON", "ASSISTS"],
	"season_saves": ["MOST SAVES - SEASON", "SAVES"], "season_wins": ["MOST WINS - SEASON", "WINS"],
	"career_goals": ["MOST GOALS - CAREER", "GOALS"], "career_saves": ["MOST SAVES - CAREER", "SAVES"],
	"career_assists": ["MOST ASSISTS - CAREER", "ASSISTS"], "career_steals": ["MOST STEALS - CAREER", "STEALS"],
	"career_blocks": ["MOST BLOCKS - CAREER", "BLOCKS"],
}

static func league_records(c: Career) -> Array:
	var out: Array = []
	for r in Records.ncsa_log(c):
		var k := String(r.key)
		var t: Array = RECORD_TITLES.get(k, [String(Records.NAMES.get(k, k)).to_upper(), ""])
		var tid := String(r.get("team", ""))
		var team_name := Records.full_name(c, tid).to_upper()
		var who := String(r.get("name", "")).to_upper()
		var v := int(r.v)
		var sub := team_name if who != team_name and who != "" else ""
		if String(r.get("opp", "")) != "":
			sub = "VS. " + Records.full_name(c, String(r.opp)).to_upper()
		out.append({"key": k, "cat": t[0], "icon": "trophy", "mine": tid == c.school,
			"head": "|%d %s| %s" % [v, t[1], who if who != "" else team_name] if t[1] != "" else "|%d| %s" % [v, who],
			"sub": sub, "when": String(r.get("when", "")), "season": str(r.get("year", ""))})
	return out

# ------------------------------------------------------------------ your program's stories
## A Career.news entry ({t, y, w}), read for the feed: {cat (its kind, small caps), icon, head (the
## headline, "|" around the words in yellow), sub (a detail line, or ""), when (its week),
## season ("" this season, else "2026-27")}. Only the saved text is read: nothing is added to it,
## and a line no rule knows is shown whole as PROGRAM NEWS.
static func story(c: Career, n: Dictionary) -> Dictionary:
	var u := String(n.get("t", "")).strip_edges().to_upper()
	var s := _kind(u, String(c.team().name).to_upper() if c.team() != null else "")
	s.merge({"sub": ""})
	var w := int(n.get("w", 0))
	var y := int(n.get("y", c.year))
	s["when"] = ConfAwards.week_label(c, w) if y == c.year else "WEEK %d" % (w + 1)
	s["season"] = "" if y == c.year else "%d-%02d" % [y, (y + 1) % 100]
	return s

## The line's kind, by the words each of Career.add_news's writers puts in it.
static func _kind(u: String, mine: String) -> Dictionary:
	var m := _rx(r"^(.+) (BEAT|LOSE TO|LOST TO) (.+?) (\d+(?:\(\d+\))?)-(\d+(?:\(\d+\))?)(?: \((\d+)-(\d+) P\))?$").search(u)
	if m != null:
		var won := m.get_string(2) == "BEAT"
		var so := m.get_string(4).contains("(") or m.get_string(6) != ""
		return {"cat": "GAME RESULT", "icon": "ball",
			"head": "%s |%s-%s| %s" % [m.get_string(1), m.get_string(4), m.get_string(5), m.get_string(3)],
			"sub": ("WIN" if won else "LOSS") + ("  -  SHOOTOUT" if so else "")}
	m = _rx(r"^NCSA RECORD! (.+?): (\d+), (.+)$").search(u)
	if m != null:
		return {"cat": "NCSA RECORD", "icon": "trophy", "head": "%s: |%s|" % [m.get_string(1), m.get_string(2)], "sub": "SET BY " + m.get_string(3)}
	m = _rx(r"^SCHOOL RECORD! (.+?): (\d+)(?:, (.+))?$").search(u)
	if m != null:
		return {"cat": "SCHOOL RECORD", "icon": "trophy", "head": "%s: |%s|" % [m.get_string(1), m.get_string(2)],
			"sub": ("SET BY " + m.get_string(3)) if m.get_string(3) != "" else "TEAM RECORD"}
	m = _rx(r"^((?:NATIONAL|CONFERENCE) CHAMPIONS)! (.+)$").search(u)
	if m != null:
		return {"cat": m.get_string(1), "icon": "trophy", "head": _mark(m.get_string(2), mine)}
	if u.begins_with("COACH OF THE YEAR! "):
		return {"cat": "COACH OF THE YEAR", "icon": "medal", "head": u.trim_prefix("COACH OF THE YEAR! ")}
	m = _rx(r"^SELECTED! (.+?)( \(A FIRST-ROUND BYE\))?$").search(u)
	if m != null:
		return {"cat": "NCSA SELECTION", "icon": "up", "head": _mark_seed(m.get_string(1)), "sub": "FIRST-ROUND BYE" if m.get_string(2) != "" else ""}
	m = _rx(r"^(.+ ARE THE #\d+ SEED IN THE .+ TOURNAMENT)( \(A FIRST-ROUND BYE\))?$").search(u)
	if m != null:
		return {"cat": "CONFERENCE SEEDING", "icon": "up", "head": _mark_seed(m.get_string(1)), "sub": "FIRST-ROUND BYE" if m.get_string(2) != "" else ""}
	m = _rx(r"^(\d+) (.+) PLAYERS? NAMED ALL-CONFERENCE$").search(u)
	if m != null:
		return {"cat": "ALL-CONFERENCE", "icon": "medal", "head": "|%s| %s PLAYERS NAMED ALL-CONFERENCE" % [m.get_string(1), m.get_string(2)]}
	m = _rx(r"^(.+): NEW ATTRIBUTE UPGRADE AVAILABLE!$").search(u)
	if m != null:
		return {"cat": "PLAYER UPGRADE", "icon": "star", "head": "|%s|: NEW ATTRIBUTE UPGRADE AVAILABLE!" % m.get_string(1)}
	m = _rx(r"^(.+): (.+) INJURY( IN TRAINING)?$").search(u)
	if m != null:
		return {"cat": "INJURY", "icon": "injury", "head": "|%s|" % m.get_string(1), "sub": m.get_string(2) + " INJURY" + m.get_string(3)}
	if u.begins_with("RECOVERY WEEK: "):
		return {"cat": "RECOVERY WEEK", "icon": "healed", "head": u.trim_prefix("RECOVERY WEEK: ")}
	m = _rx(r"^(.+) GROWS INTO AN? (.+)$").search(u)
	if m != null:
		return {"cat": "PLAYER MILESTONE", "icon": "star", "head": "%s GROWS INTO A |%s|" % [m.get_string(1), m.get_string(2)]}
	m = _rx(r"^DEV RECRUIT SIGNED: (.+) HAS COMMITTED TO (.+)$").search(u)
	if m != null:
		return {"cat": "DEV RECRUIT SIGNED", "icon": "person", "head": "|%s| HAS COMMITTED TO %s" % [m.get_string(1), m.get_string(2)]}
	m = _rx(r"^SIGNED: (.+?) \((.+)\) JOINS NEXT SEASON$").search(u)
	if m != null:
		return {"cat": "RECRUIT SIGNED", "icon": "person", "head": "|%s| JOINS NEXT SEASON" % m.get_string(1), "sub": m.get_string(2)}
	m = _rx(r"^(.+) UPGRADED TO LEVEL (\d+)$").search(u)
	if m != null:
		return {"cat": "FACILITIES", "icon": "up", "head": "%s UPGRADED TO LEVEL |%s|" % [m.get_string(1), m.get_string(2)]}
	if u.begins_with("NEW SEASON: "):
		return {"cat": "NEW SEASON", "icon": "coin", "head": "SEASON BONUS |%s|" % u.trim_prefix("NEW SEASON: ")}
	if u.begins_with("PLAYOFF BUNDLE: "):
		return {"cat": "PLAYOFF BUNDLE", "icon": "healed", "head": u.trim_prefix("PLAYOFF BUNDLE: ")}
	if u.begins_with("REALIGNMENT: "):
		return {"cat": "REALIGNMENT", "icon": "up", "head": u.trim_prefix("REALIGNMENT: ")}
	if u.begins_with("ROSTER CUTS REQUIRED: "):
		return {"cat": "ROSTER", "icon": "person", "head": "ROSTER CUTS REQUIRED: |%s|" % u.trim_prefix("ROSTER CUTS REQUIRED: ")}
	if u.begins_with("RELEASED: ") or u.begins_with("ROSTER SET AT ") or u.contains(", CUT BY "):
		return {"cat": "ROSTER", "icon": "person", "head": u}
	if (u.begins_with("COACH ") and u.contains(" TAKES OVER AT ")) or u.contains(" HIRE A NEW COACH AFTER "):
		return {"cat": "COACHING", "icon": "person", "head": u}
	# the season's awards ("NCSA PLAYER OF THE YEAR! NAME", "...: NAME") and the tournaments' ("ALL-NCSA ...: NAME")
	m = _rx(r"^([A-Z0-9 ()'\-]+)[!:] (.+)$").search(u)
	if m != null and _award_title(m.get_string(1)):
		return {"cat": m.get_string(1), "icon": "medal", "head": "|%s|" % m.get_string(2)}
	return {"cat": "PROGRAM NEWS", "icon": "news", "head": u}

static var _rxs := {}
static func _rx(p: String) -> RegEx:
	if not _rxs.has(p):
		_rxs[p] = RegEx.create_from_string(p)
	return _rxs[p]

## Your team's name, in yellow, where the line names it.
static func _mark(t: String, name: String) -> String:
	return t.replace(name, "|%s|" % name) if name != "" else t

## The seed ("#3"), in yellow.
static func _mark_seed(t: String) -> String:
	var m := _rx("#\\d+").search(t)
	return t if m == null else t.substr(0, m.get_start()) + "|" + m.get_string() + "|" + t.substr(m.get_end())

static func _award_title(t: String) -> bool:
	if t.begins_with("ALL-") or t.ends_with("OF THE YEAR") or t.ends_with("AWARD") or t.ends_with("OF THE TOURNAMENT"):
		return true
	for d in [Awards.TITLES, NationalAwards.TITLES]:
		for k in d:
			if String(d[k]).to_upper() == t:
				return true
	return false

## One row of a feed (AROUND YOUR PROGRAM's stories, LEAGUE RECORDS' marks): its icon on the left,
## its kind / headline / detail in the middle (the headline wraps, and the row grows to fit it),
## its week on the right. Rows take turns at the scoreboard's two navy shades, inside the board's
## white edge. {empty: "NO PROGRAM NEWS YET"} is the board's empty line; {mine: true} (a record
## your program holds) has the scoreboard's gold edge, as your own game does.
class NewsRow extends Control:
	const PAD := 6.0
	const ICON_W := 12.0
	const RIGHT_W := 56.0
	const LINE := 10.0
	const TOP := 4.0
	const BOTTOM := 3.0
	const MIN_H := 26.0
	const EMPTY_H := 40.0
	var s: Dictionary
	var i: int
	var last: bool
	var _lines: Array = []   # the headline's lines: [[word, yellow?], ...]

	## The feed's icons: 9 x 9 pixel art (or Deck's trophy and coin), coloured by the letter.
	const ICON_ART := {
		"ball": ["..YYKYY..", ".YHYKYYY.", "YHYYKYYYY", "YYYYKYYYY", "KKKKKKKKK", "YYYYKYYYY", "YYYYKYYYY", ".YYYKYYY.", "..YYKYY.."],
		"medal": ["RR...BB", ".RR.BB.", "..RBB..", ".YYYYY.", "YYHYYYY", "YHYYYYY", "YYYYYYY", ".YYYYY.", "..YYY.."],
		"up": ["....G....", "...GGG...", "..GGGGG..", ".GGGGGGG.", "GGGGGGGGG", "...GGG...", "...GGG...", "...GGG...", "...GGG..."],
		"injury": ["..RRR..", "..RRR..", "RRRRRRR", "RRRRRRR", "RRRRRRR", "..RRR..", "..RRR.."],
		"healed": ["..GGG..", "..GGG..", "GGGGGGG", "GGGGGGG", "GGGGGGG", "..GGG..", "..GGG.."],
		"person": ["..AAA..", ".AAAAA.", ".AAAAA.", "..AAA..", ".......", ".AAAAA.", "AAAAAAA", "AAAAAAA"],
		"news": ["DDDDDDD", "D.....D", "D.DDD.D", "D.....D", "D.DDD.D", "D.....D", "DDDDDDD"],
	}
	const ICON_COLS := {"Y": UI.GOLD, "K": Color("0b1d5c"), "R": UI.BAD, "B": UI.ACCENT, "H": Color("fff3b0"),
		"G": UI.GOOD, "A": UI.ACCENT, "D": UI.DIM}

	static func draw_icon(ci: CanvasItem, name: String, center: Vector2) -> void:
		if name == "trophy":
			Deck.trophy(ci, (center - Vector2(4.5, 6)).round())
		elif name == "coin":
			var tex := CreditCoin.texture(16)
			ci.draw_texture(tex, (center - tex.get_size() / 2.0).round())
		elif name == "star":
			Deck.pat(ci, (center - Vector2(4.5, 4.5)).round(), Deck.STAR, {"#": UI.GOLD})
		else:
			var rows: Array = ICON_ART.get(name, ICON_ART.news)
			var sz := Vector2(String(rows[0]).length(), rows.size())
			Deck.pat(ci, (center - sz / 2.0).round(), rows, ICON_COLS)


	func _init(story: Dictionary, index: int, is_last: bool) -> void:
		s = story
		i = index
		last = is_last
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(0, EMPTY_H if s.has("empty") else MIN_H)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_layout()
			queue_redraw()

	func _box() -> Rect2:
		var w := minf(MAX_W, size.x)
		return Rect2(roundf((size.x - w) / 2.0), 0, w, size.y)

	func _text_w() -> float:
		return _box().size.x - PAD - ICON_W - PAD - PAD - RIGHT_W

	## The headline's words (yellow between the "|"s), wrapped to the text column.
	func _layout() -> void:
		if s.has("empty") or size.x <= 0.0:
			return
		var words: Array = []
		var parts := String(s.head).split("|")
		for k in parts.size():
			for wd in parts[k].split(" ", false):
				words.append([wd, k % 2 == 1])
		var tw := _text_w()
		var sp := UI.text_width(" ", 8, "caps")
		_lines = [[]]
		var at := 0.0
		for wd in words:
			var ww := _word_w(String(wd[0]))
			if at > 0.0 and at + sp + ww > tw:
				_lines.append([])
				at = 0.0
			at += (sp if at > 0.0 else 0.0) + ww
			_lines[-1].append(wd)
		var n := 1 + _lines.size() + (1 if String(s.sub) != "" else 0)
		var h := maxf(MIN_H, TOP + n * LINE + BOTTOM)
		if not is_equal_approx(custom_minimum_size.y, h):
			custom_minimum_size = Vector2(0, h)

	static func _word_w(wd: String) -> float:
		var t := CreditCoin.norm(wd)
		if t.contains(CreditCoin.TAG):
			return UI.text_width(t.replace(CreditCoin.TAG, ""), 8, "caps") + CreditCoin.GAP + CreditCoin.texture(16).get_width()
		return UI.text_width(t, 8, "caps")

	## A word, with its coin drawn after the number where it has one.
	func _word(x: float, y: float, wd: String, col: Color) -> float:
		var t := CreditCoin.norm(wd)
		var plain := t.replace(CreditCoin.TAG, "")
		UI.text(self, Vector2(x, y), plain, 8, col, "caps")
		var w := UI.text_width(plain, 8, "caps")
		if t.contains(CreditCoin.TAG):
			var tex := CreditCoin.texture(16)
			draw_texture(tex, Vector2(x + w + CreditCoin.GAP, roundf(y - 4 - tex.get_height() / 2.0)))
			w += CreditCoin.GAP + tex.get_width()
		return w

	func _draw() -> void:
		var r := _box()
		var x := r.position.x
		var w := r.size.x
		draw_rect(r, ROW_A if i % 2 == 0 else ROW_B)
		if s.get("mine", false):
			draw_rect(r.grow(-1.0), UI.GOLD, false, 1.0)
		if s.has("empty"):
			UI.text(self, Vector2(x, roundf(size.y / 2.0) + 4), String(s.empty), 8, UI.DIM, "caps", HORIZONTAL_ALIGNMENT_CENTER, w)
		else:
			var tx := x + PAD + ICON_W + PAD
			var y := TOP + 8.0
			draw_icon(self, String(s.icon), Vector2(x + PAD + ICON_W / 2.0, TOP + 4.0 + LINE / 2.0))
			# the kind, light blue; the week on the right (and the season, if it was another)
			UI.text(self, Vector2(tx, y), String(s.cat), 8, Color("9fc3ff"), "caps")
			var when := String(s.when)
			UI.text(self, Vector2(x + w - PAD - UI.text_width(when, 8, "caps"), y), when, 8, Color("9fc3ff"), "caps")
			if String(s.season) != "":
				UI.text(self, Vector2(x + w - PAD - UI.text_width(s.season, 8, "caps"), y + LINE), s.season, 8, UI.DIM, "caps")
			# the headline: white, its key words yellow
			var sp := UI.text_width(" ", 8, "caps")
			for ln in _lines:
				y += LINE
				var at := tx
				for wd in ln:
					at += _word(at, y, String(wd[0]), YELLOW if wd[1] else UI.TEXT) + sp
			if String(s.sub) != "":
				y += LINE
				UI.text(self, Vector2(tx, y), String(s.sub), 8, UI.DIM, "body")
		# the board's white edge down both sides, and under the last row
		draw_rect(Rect2(x, 0, 1, size.y), UI.BORDER)
		draw_rect(Rect2(x + w - 1, 0, 1, size.y), UI.BORDER)
		if last:
			draw_rect(Rect2(x, size.y - 1, w, 1), UI.BORDER)

func on_back() -> void:
	Sfx.play("back")
	Game.goto("more")
