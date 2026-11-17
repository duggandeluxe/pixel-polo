extends BaseScreen
## THE SEASON REVIEW (the Season Review Redesign) and the roster lock's report.
##
## The season review is a season recap in sections, in the order a season is remembered:
##   the banner        SEASON COMPLETE between gold rules and trophies (DEV PREVIEW when it is one)
##   YOUR SEASON       your team: logo, record, conference and its finish, postseason, any titles
##                     (gold, with the trophy), the final poll, your top scorer, the Polo Points
##   CHAMPIONS         the NCSA champion's trophy card, every conference's
##   SEASON AWARDS     the NCSA's honours and Coach of the Year, a card each (icon, portrait or
##                     logo, winner, team, position, the season that won it)
##   POSTSEASON HONORS the All-Tournament awards: the NCSA's cards, each conference's player
##   ALL-STAR TEAMS    All-NCSA First and Second Team, your All-Conference team: player cards
##   RECORDS BROKEN    each record once, the NCSA's in gold (or NO NEW LEAGUE RECORDS)
## scrolling on the left, and YOUR SEASONS on the right: the totals, then every season you've
## coached (a title season in gold), scrolling on its own.
## Everything comes from SeasonReview (the season's saved results): this screen never works out a
## winner, a champion or a record, and never writes to the career except to take the review off
## the hub's queue when you move on.
##
## DEV PREVIEW (DEV Mode's VIEW SEASON REVIEW, review_lab): params {"preview": true} and either
## {"season": "2026-27"} (a season of yours, from the career) or {"model": {...}, "sample": true}
## (a sample scenario). Nothing is saved or taken off the queue; back goes to the lab.
##
## The roster lock's report keeps the plain list of lines. (A review queued before the redesign
## has no "season": it's taken from the review's title.)

const NAVY := Color("0b1d5c")
const NAVY_HI := Color("14318c")
const NAVY_LO := Color("081650")
const PLATE_GOLD := Color("3d3410")
const PLATE_GOLD_HI := Color("5a4a12")
const RIGHT_W := 136
const CARD_H := 66
## A card title that doesn't fit, shortened (only then).
const SHORT_TITLES := {"DEFENSIVE ": "DEF. ", "OFFENSIVE ": "OFF. ", "OF THE TOURNAMENT": "OF TOURNAMENT"}
const PLAYER_H := 33

const ICONS := {
	"shield": ["#######", "#ooooo#", "#ooooo#", "#ooooo#", ".#ooo#.", "..#o#..", "...#..."],
	"ball": [".#####.", "#oo#oo#", "#o#o#o#", "##ooo##", "#o#o#o#", "#oo#oo#", ".#####."],
	"wall": ["#######", "o#ooo#o", "#######", "ooo#ooo", "#######", "o#ooo#o", "#######"],
	"sprout": ["##...##", "#o#.#o#", ".##.##.", "...#...", "...#...", ".#####.", "#ooooo#"],
	"board": [".##o##.", "#######", "#ooooo#", "#o###o#", "#ooooo#", "#o##oo#", "#######"],
	"medal": ["#.....#", ".#...#.", "..#.#..", "..###..", ".#ooo#.", ".#ooo#.", "..###.."],
	"crown": ["#..#..#", "##.#.##", "#######", "#ooooo#", "#######"],
	"arrow": ["...#...", "..###..", ".#####.", "#######", "..ooo..", "..ooo..", "..ooo.."],
	"team": [".#...#.", "###.###", ".#.#.#.", "#.###.#", "..###..", ".#####."],
	"star": ["...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", "##...##"],
}
const AWARD_ICONS := {"poy": "star", "dpoy": "shield", "foy": "sprout", "arm": "ball", "wall": "wall", "coach": "board",
	"golden_cap": "ball", "keeper": "shield", "pot": "medal", "opot": "ball", "dpot": "shield"}

var data := {}
var m := {}               # the review (SeasonReview.build, or a sample's)
var preview := false
var sample := false
## THE SEASON SO FAR (Championship Elimination): params {"live": true}, the current season's
## review while the league is still playing it (SeasonReview.live): what's still to be decided
## shows as PENDING. Never takes anything off the queue; back is the hub.
var live := false
var _cr: Career = null    # the career the review's players and teams are looked up in (none: a sample)

func setup(params: Dictionary) -> void:
	detail = true   # (its team logos: TeamLogo's fine pixels)
	data = params

func _ready() -> void:
	c = Game.career
	preview = bool(data.get("preview", false)) and bool(Game.settings.get("dev_mode", false))
	var season := String(data.get("season", ""))
	var title := String(data.get("title", "SEASON REVIEW"))
	if season == "" and title.ends_with(" SEASON REVIEW"):
		season = title.get_slice(" ", 0)   # (a review queued before the redesign)
	if preview and data.has("model"):
		sample = true
		m = data.model
		live = bool(m.get("live", false))
	elif bool(data.get("live", false)) and c != null:
		_cr = c
		live = true
		m = SeasonReview.live(c)
	elif season != "" and c != null:
		_cr = c
		m = SeasonReview.build(c, season)
	if m.is_empty():
		_lines_screen(title)
		return
	back_target = "review_lab" if preview else "hub"
	build("%s SEASON REVIEW" % _years(String(m.get("season", season))), preview or live, false)
	body.add_child(_banner())
	var cols := UI.hbox(5)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	var left := UI.vbox(4)
	left.name = "Review"
	var ls := UI.scroll(left)
	ls.name = "ReviewScroll"
	cols.add_child(ls)
	_fill(left)
	cols.add_child(_history_panel())
	if live:
		var b := UI.button("BACK TO DYNASTY  >", on_back, "primary", 0, 22)
		b.name = "Continue"
		body.add_child(b)
	elif preview:
		var b := UI.button("<  BACK TO DEV TOOLS", on_back, "normal", 0, 20)
		b.name = "BackToDev"
		body.add_child(b)
	else:
		var b := UI.button("ON TO %s  >" % String(data.get("next", c.next_season_label() if c != null else "")), _done, "primary", 0, 22)
		b.name = "Continue"
		body.add_child(b)
	Sfx.music("menu")

## "2026-27" -> "2026-2027".
static func _years(season: String) -> String:
	var parts := season.split("-")
	if parts.size() == 2 and parts[0].is_valid_int():
		return "%d-%d" % [int(parts[0]), int(parts[0]) + 1]
	return season

func on_back() -> void:
	if live:
		# (the season so far: nothing to take off the queue; a DEV preview goes back the way it came)
		Sfx.play("back")
		if preview and sample:
			Game.goto("elim_lab", {}, false)
		elif preview:
			Game.goto("hub", {"elim_preview": true}, false)
		else:
			Game.goto("hub")
		return
	if preview:
		Game.goto("review_lab", {}, false)
		return
	_done()

## The review was the front of the hub's queue: it's dealt with now. (Never from a DEV preview.)
func _done() -> void:
	if preview or live:
		on_back()
		return
	if c != null and not c.queue.is_empty() and String(c.queue[0].get("type", "")) == "recap":
		c.queue.pop_front()
		Game.save_career()
	Game.goto("hub")

# ------------------------------------------------------------------ the roster lock's report
func _lines_screen(title: String) -> void:
	build(title, false, false)
	var cols := UI.hbox(8)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	var left := UI.panel(UI.PANEL2, UI.GOLD)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var lv := UI.vbox(3)
	left.add_child(lv)
	for ln in data.get("lines", []):
		lv.add_child(CreditCoin.rich(String(ln), 8, UI.TEXT, "body", 240))
	if c != null:
		cols.add_child(_history_panel())
	body.add_child(UI.button("ON TO %s  >" % String(data.get("next", c.season_label() if c != null else "")), _done, "primary", 0, 22))
	Sfx.music("menu")

# ------------------------------------------------------------------ the sections
func _fill(v: VBoxContainer) -> void:
	var you: Dictionary = m.get("you", {})
	if not you.is_empty():
		v.add_child(_section("YOUR SEASON", "star"))
		v.add_child(_you_card(you))
	# CHAMPIONS
	v.add_child(_section("CHAMPIONS", "crown"))
	var nat: Dictionary = m.get("national", {})
	var any := false
	if not nat.is_empty():
		v.add_child(_title_card("NCSA NATIONAL CHAMPIONS", nat))
		any = true
	elif bool(m.get("national_pending", false)):
		var rem: Dictionary = m.get("remaining", {})
		var left := "%s - %d TEAMS STILL COMPETING" % [String(rem.round), int(rem.alive)] if String(rem.get("round", "")) != "" else "DECIDED IN THE NCSA FINAL"
		v.add_child(_pending("NCSA NATIONAL CHAMPIONS", left, "NationalPending"))
		any = true
	var confs: Array = m.get("confs", [])
	if not confs.is_empty():
		any = true
		v.add_child(_sub("CONFERENCE CHAMPIONS"))
		var g := _grid("ConfChampions")
		for cf in confs:
			g.add_child(_conf_card(cf))
		v.add_child(g)
	if not any:
		v.add_child(_empty("NO CHAMPIONSHIP RESULTS RECORDED"))
	# SEASON AWARDS
	v.add_child(_section("SEASON AWARDS", "medal"))
	var awards: Array = m.get("awards", [])
	if awards.is_empty() and bool(m.get("awards_pending", false)):
		v.add_child(_pending("PLAYER OF THE YEAR, COACH OF THE YEAR AND EVERY NCSA HONOUR", "ANNOUNCED AFTER THE NCSA FINAL", "AwardsPending"))
	elif awards.is_empty():
		v.add_child(_empty("NO SEASON AWARDS RECORDED"))
	else:
		var g := _grid("SeasonAwards")
		for a in awards:
			g.add_child(_award_card(a, String(a.get("title", "")) + ("  (CO)" if bool(a.get("co", false)) else ""), AWARD_ICONS.get(String(a.get("key", "")), "star")))
		v.add_child(g)
	# POSTSEASON HONORS
	v.add_child(_section("POSTSEASON HONORS", "medal"))
	var post: Array = m.get("postseason", [])
	if bool(m.get("nat_honours_pending", false)):
		v.add_child(_pending("NCSA CHAMPIONSHIP - ALL-TOURNAMENT HONORS", "DECIDED AFTER THE NCSA FINAL", "NatHonorsPending"))
	elif post.is_empty():
		v.add_child(_empty("NO TOURNAMENT HONORS RECORDED"))
	var conf_rows: Array = []
	for grp in post:
		if String(grp.get("tid", "")) == "nat":
			v.add_child(_sub(String(grp.get("title", ""))))
			var g := _grid("Postseason_" + String(grp.get("tid", "")))
			for a in grp.get("awards", []):
				g.add_child(_award_card(a, String(a.get("title", "")), AWARD_ICONS.get(String(a.get("cat", "")), "medal")))
			v.add_child(g)
		else:
			for a in grp.get("awards", []):
				if String(a.get("cat", "")) == "pot":
					conf_rows.append([String(grp.get("title", "")), a])
	if not conf_rows.is_empty():
		v.add_child(_sub("CONFERENCE TOURNAMENTS - PLAYER OF THE TOURNAMENT"))
		var g := _grid("ConfTourneyPOT")
		for r in conf_rows:
			g.add_child(_award_card(r[1], String(r[0]), "medal"))
		v.add_child(g)
	# ALL-STAR TEAMS
	var teams: Array = m.get("teams", [])
	v.add_child(_section("ALL-STAR TEAMS", "team"))
	if teams.is_empty() and bool(m.get("teams_pending", false)):
		v.add_child(_pending("ALL-NCSA AND ALL-CONFERENCE TEAMS", "NAMED WHEN THE SEASON ENDS", "TeamsPending"))
	elif teams.is_empty():
		v.add_child(_empty("NO ALL-STAR TEAMS RECORDED"))
	for t in teams:
		v.add_child(_sub(String(t.get("title", ""))))
		var g := _grid("Team_" + String(t.get("title", "")).replace(" ", "_"))
		for p in t.get("players", []):
			g.add_child(_player_card(p))
		v.add_child(g)
	# RECORDS
	v.add_child(_section("RECORDS BROKEN THIS SEASON", "arrow"))
	var recs: Array = m.get("records", [])
	if recs.is_empty():
		v.add_child(_empty("NO NEW LEAGUE RECORDS THIS SEASON"))
	for r in recs:
		v.add_child(_record_card(r))
	# the season so far only: your leaders, and where recruiting stands
	if m.has("leaders"):
		v.add_child(_section("TEAM LEADERS", "star"))
		var ls: Array = m.leaders
		if ls.is_empty():
			v.add_child(_empty("NO STATS RECORDED YET"))
		else:
			var g := _grid("TeamLeaders")
			for a in ls:
				g.add_child(_leader_card(a))
			v.add_child(g)
	if m.has("recruiting"):
		v.add_child(_section("RECRUITING", "arrow"))
		v.add_child(_recruit_card(m.recruiting))
	v.add_child(UI.spacer(0, 4))

## Still to be decided (the season so far): its title, PENDING, and when it will be.
func _pending(title: String, when: String, nm: String) -> Control:
	var e := UI.canvas(0, 26, func(ci: Control):
		var r := Rect2(Vector2(0, 0), Vector2(ci.size.x, 24))
		Deck.frame(ci, r, NAVY_LO, Color(UI.GOLD, 0.45))
		var chip := Rect2(4, 4, Deck.text_w("PENDING") + 8, 16)
		ci.draw_rect(chip, Color(UI.GOLD, 0.2))
		Deck.frame(ci, chip, Color(0, 0, 0, 0), UI.GOLD)
		Deck.ctext(ci, chip, "PENDING", 8, UI.GOLD)
		var x := chip.end.x + 6
		Deck.text(ci, x, 8, Deck.fit(title, ci.size.x - x - 4), 8, UI.TEXT)
		Deck.text(ci, x, 17, Deck.fit(when, ci.size.x - x - 4), 8, UI.DIM))
	e.name = nm
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return e

## A team leader: the stat, the number, who.
func _leader_card(a: Dictionary) -> Control:
	var src = _team_src(String(a.get("team", "")))
	var tex := _portrait(a, src)
	var card := _box(PLAYER_H, func(ci: Control):
		var w := ci.size.x
		Deck.frame(ci, Rect2(0, 0, w, PLAYER_H - 1), NAVY, Color(UI.BORDER, 0.7))
		var px := Rect2(2, 1, 28, PLAYER_H - 3)
		ci.draw_rect(px, NAVY_LO)
		if tex != null:
			ci.draw_texture_rect(tex, Rect2(px.position + Vector2(1, 0), Vector2(Portrait.SIZE)), false)
		var val := str(int(a.get("v", 0)))
		var vw := Deck.text_w(val, 16, "big") + 6
		Deck.text(ci, 34, 9, String(a.get("title", "")), 8, UI.GOLD)
		Deck.text(ci, 34, 22, Deck.fit(String(a.get("name", "")).to_upper(), w - 40 - vw), 8, UI.TEXT)
		Deck.shadow_text(ci, w - vw, 15, val, 16, UI.TEXT, "big"))
	card.name = "Leader_" + String(a.get("key", ""))
	return card

## Signed, pinned, graduating and next season's projected roster.
func _recruit_card(r: Dictionary) -> Control:
	var over := int(r.get("over", 0))
	var card := _box(36, func(ci: Control):
		var w := ci.size.x
		Deck.frame(ci, Rect2(0, 0, w, 34), NAVY, UI.ACCENT, true)
		var cells := [["SIGNED", str(int(r.get("signed", 0)))], ["PINNED", str(int(r.get("pinned", 0)))],
			["GRADUATING", str(int(r.get("graduating", 0)))], ["PROJECTED", "%d / %d" % [int(r.get("projected", 0)), int(r.get("max", 0))]]]
		var cw := floorf((w - 8) / cells.size())
		for i in cells.size():
			var x := 4 + cw * i
			Deck.text(ci, x + 2, 9, String(cells[i][0]), 8, UI.DIM)
			Deck.shadow_text(ci, x + 2, 23, String(cells[i][1]), 16, UI.WARN if i == 3 and over > 0 else UI.TEXT, "big"))
	card.name = "Recruiting"
	return card

## SEASON COMPLETE between gold rules, a trophy at each end; DEV PREVIEW (SAMPLE DATA) on a preview.
func _banner() -> Control:
	var tag := ""
	if preview:
		tag = "DEV PREVIEW - SAMPLE DATA" if sample else "DEV PREVIEW"
	var b := UI.canvas(0, 14, func(ci: Control):
		var w := ci.size.x
		var mid := "SEASON OVER - THE SEASON SO FAR" if live else "SEASON COMPLETE"
		var tw := Deck.text_w(mid)
		var cx := floorf((w - tw) * 0.5)
		for side in [[12.0, cx - 20.0], [cx + tw + 20.0, w - 12.0]]:
			ci.draw_rect(Rect2(side[0], 6, side[1] - side[0], 1), UI.GOLD)
			ci.draw_rect(Rect2(side[0], 8, side[1] - side[0], 1), Color(UI.GOLD, 0.35))
		Deck.trophy(ci, Vector2(cx - 15, 1), UI.GOLD)
		Deck.trophy(ci, Vector2(cx + tw + 6, 1), UI.GOLD)
		_star(ci, Vector2(3, 3))
		_star(ci, Vector2(w - 10, 3))
		Deck.shadow_text(ci, cx, 7, mid, 8, UI.GOLD)
		if tag != "":
			var r := Rect2(w - Deck.text_w(tag) - 26, 1, Deck.text_w(tag) + 10, 12)
			Deck.frame(ci, r, Color("4a0f22"), UI.PINK)
			Deck.ctext(ci, r, tag, 8, UI.PINK))
	b.name = "Banner"
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

## A section's heading: its icon, its name in gold, a gold rule to the edge.
func _section(t: String, icon: String) -> Control:
	var h := UI.canvas(0, 15, func(ci: Control):
		_icon(ci, Vector2(1, 4), icon, UI.GOLD)
		Deck.shadow_text(ci, 12, 8, t, 8, UI.GOLD)
		var x := 16.0 + Deck.text_w(t)
		ci.draw_rect(Rect2(x, 8, ci.size.x - x - 1, 1), Color(UI.GOLD, 0.7))
		ci.draw_rect(Rect2(x, 10, ci.size.x - x - 1, 1), Color(UI.GOLD, 0.25)))
	h.name = "Section_" + t.replace(" ", "_")
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return h

## A heading inside a section, smaller and pale.
func _sub(t: String) -> Control:
	var h := UI.canvas(0, 11, func(ci: Control):
		Deck.text(ci, 2, 6, Deck.fit(t, ci.size.x - 4), 8, UI.DIM)
		ci.draw_rect(Rect2(2, 10, ci.size.x - 4, 1), Color(UI.DIM, 0.25)))
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return h

func _empty(t: String) -> Control:
	var e := UI.canvas(0, 22, func(ci: Control):
		var r := Rect2(Vector2.ZERO, ci.size)
		Deck.frame(ci, r, NAVY_LO, Color(UI.DIM, 0.5))
		Deck.ctext(ci, r, t, 8, UI.DIM))
	e.name = "Empty"
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return e

func _grid(n: String) -> GridContainer:
	var g := GridContainer.new()
	g.name = n
	g.columns = 2
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return g

func _box(h: int, paint: Callable) -> Control:
	var b := UI.canvas(0, h, paint)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

# ------------------------------------------------------------------ YOUR SEASON
func _you_card(y: Dictionary) -> Control:
	var titles: Array = y.get("titles", [])
	var champ := not titles.is_empty()
	var nat := bool(y.get("national", false))
	var src = _team_src(String(y.get("team", "")))
	var rows: Array = []
	var rec := "%d-%d" % [int(y.get("w", 0)), int(y.get("l", 0))]
	if int(y.get("cw", 0)) + int(y.get("cl", 0)) > 0:
		rec += "   (%d-%d CONF)" % [int(y.get("cw", 0)), int(y.get("cl", 0))]
	rows.append(["FINAL RECORD", rec])
	var conf := String(y.get("conf_name", ""))
	if conf != "":
		rows.append(["CONFERENCE", conf.to_upper()])
	if int(y.get("rank", 0)) > 0:
		rows.append(["CONF. FINISH", SeasonReview.ordinal(int(y.rank))])
	if String(y.get("finish", "")) != "":
		rows.append(["POSTSEASON", _finish(String(y.finish), false)])
	if int(y.get("poll", 0)) > 0:
		rows.append(["FINAL POLL", "#%d" % int(y.poll)])
	var extras: Array = []
	if y.has("top"):
		extras.append("TOP SCORER  %s, %d GOALS" % [String(y.top.get("name", "")).to_upper(), int(y.top.get("g", 0))])
	var pts := int(y.get("points", -1))
	var h := 26 + rows.size() * 10 + (16 if champ else 0) + (11 if not extras.is_empty() or pts >= 0 else 0)
	var card := _box(h, func(ci: Control):
		var w := ci.size.x
		var r := Rect2(0, 0, w, h - 2)
		Deck.frame(ci, r, PLATE_GOLD if champ else NAVY, UI.GOLD if champ else UI.BORDER, true, UI.BEVEL_SOFT)
		# the logo in its own well
		var lw := Rect2(5, 5, 44, 44)
		ci.draw_rect(lw, NAVY_LO)
		if src != null:
			TeamLogo.draw_fine_in(ci, lw.grow(-2), src)
		else:
			_no_logo(ci, lw.grow(-3))
		Deck.frame(ci, lw, Color(0, 0, 0, 0), Color(UI.BORDER, 0.6))
		var x := 56.0
		var tw := w - x - 6.0
		var nm := String(y.get("team_name", "")).to_upper()
		var fs := 16 if Deck.text_w(nm, 16, "big") <= tw else 8
		Deck.shadow_text(ci, x, 11, Deck.fit(nm, tw, fs, "big" if fs == 16 else "caps"), fs, UI.GOLD if champ else UI.TEXT, "big" if fs == 16 else "caps")
		ci.draw_rect(Rect2(x, 20, tw, 1), Color(UI.GOLD, 0.5))
		var yy := 28.0
		var lw2 := 0.0
		for row in rows:
			lw2 = maxf(lw2, Deck.text_w(String(row[0])))
		lw2 += 8.0
		for row in rows:
			Deck.text(ci, x, yy, String(row[0]), 8, UI.DIM)
			Deck.text(ci, x + lw2, yy, Deck.fit(String(row[1]), tw - lw2), 8, UI.TEXT)
			yy += 10.0
		if champ:
			var band := Rect2(5, yy - 2, w - 10, 13)
			ci.draw_rect(band, UI.GOLD if nat else Color(UI.GOLD, 0.85))
			Deck.trophy(ci, Vector2(band.position.x + 4, band.position.y + 0.5), UI.INK)
			Deck.text(ci, band.position.x + 18, band.position.y + 6.5, Deck.fit(" + ".join(titles), band.size.x - 22), 8, UI.INK)
			yy += 16.0
		if not extras.is_empty() or pts >= 0:
			var tx := 6.0
			if not extras.is_empty():
				Deck.text(ci, tx, yy, Deck.fit(String(extras[0]), w - 110), 8, UI.ACCENT)
			if pts >= 0:
				var s := "POLO POINTS +%d" % pts
				var px := w - Deck.text_w(s) - 16
				Deck.text(ci, px, yy, s, 8, UI.GOLD)
				Deck.coin(ci, Vector2(w - 13, yy - 4)))
	card.name = "YourSeason"
	return card

# ------------------------------------------------------------------ CHAMPIONS
## The NCSA champion: gold plate, the trophy at 2x, the logo.
func _title_card(label: String, e: Dictionary) -> Control:
	var src = _team_src(String(e.get("team", "")))
	var mine := _is_mine(String(e.get("team", "")))
	var h := 48
	var card := _box(h, func(ci: Control):
		var w := ci.size.x
		var r := Rect2(0, 0, w, h - 2)
		Deck.frame(ci, r, PLATE_GOLD, UI.GOLD, true, UI.BEVEL_SOFT)
		ci.draw_rect(Rect2(3, 3, w - 6, 1), Color(UI.GOLD, 0.5))
		Deck.trophy(ci, Vector2(8, 10), UI.GOLD, 2.0)
		var x := 36.0
		var lb := 40.0
		var tw := w - x - lb - 10.0
		Deck.text(ci, x, 9, Deck.fit(label, tw), 8, UI.GOLD)
		var nm := String(e.get("team_name", "")).to_upper()
		if Deck.text_w(nm, 16, "big") <= tw:
			Deck.shadow_text(ci, x, 22, nm, 16, UI.TEXT, "big")
		else:
			Deck.text(ci, x, 20, Deck.fit(nm, tw), 8, UI.TEXT)
		if e.has("score"):
			Deck.text(ci, x, 35, Deck.fit("%s OVER %s" % [String(e.score), String(e.get("runner_name", "")).to_upper()], tw), 8, UI.DIM)
		if mine:
			_you_tag(ci, Vector2(w - lb - 34, 4))
		if src != null:
			TeamLogo.draw_fine_in(ci, Rect2(w - lb - 6, (h - 2 - lb) * 0.5, lb, lb), src))
	card.name = "NationalChampion"
	return card

func _conf_card(e: Dictionary) -> Control:
	var src = _team_src(String(e.get("team", "")))
	var mine := _is_mine(String(e.get("team", "")))
	var card := _box(36, func(ci: Control):
		var w := ci.size.x
		Deck.frame(ci, Rect2(0, 0, w, 34), NAVY, UI.ACCENT if mine else Color(UI.GOLD, 0.8), true)
		var abbr := String(e.get("abbr", ""))
		var chip := Rect2(4, 4, Deck.text_w(abbr) + 8, 11)
		ci.draw_rect(chip, UI.GOLD)
		Deck.ctext(ci, chip, abbr, 8, UI.INK)
		var lx := w - 32.0
		Deck.text(ci, chip.end.x + 4, 9.5, Deck.fit(String(e.get("conf_name", "")).to_upper(), lx - chip.end.x - 8), 8, UI.DIM)
		Deck.text(ci, 5, 21, Deck.fit(String(e.get("team_name", "")).to_upper(), lx - 9), 8, UI.TEXT)
		if e.has("score"):
			Deck.text(ci, 5, 29, Deck.fit("%s OVER %s" % [String(e.score), String(e.get("runner_name", "")).to_upper()], lx - 9), 8, UI.DIM)
		if src != null:
			TeamLogo.draw_in(ci, Rect2(lx, 5, 28, 24), src)
		else:
			_no_logo(ci, Rect2(lx, 5, 28, 24)))
	card.name = "Conf_" + String(e.get("abbr", ""))
	return card

# ------------------------------------------------------------------ AWARDS
## An award's card: its icon and title on a navy plate, then the winner: portrait (or his team's
## logo, or an empty frame), name, team, position, the line that won it.
func _award_card(a: Dictionary, title: String, icon: String) -> Control:
	var team := String(a.get("team", ""))
	var src = _team_src(team)
	var tex := _portrait(a, src)
	var mine := _is_mine(team)
	var card := _box(CARD_H, func(ci: Control):
		var w := ci.size.x
		Deck.frame(ci, Rect2(0, 0, w, CARD_H - 2), NAVY, UI.ACCENT if mine else UI.BORDER, true)
		ci.draw_rect(Rect2(1, 1, w - 2, 12), NAVY_HI)
		ci.draw_rect(Rect2(1, 13, w - 2, 1), Color(UI.GOLD, 0.6))
		_icon(ci, Vector2(4, 3), icon, UI.GOLD)
		var t := title
		if Deck.text_w(t) > w - 18:
			for k in SHORT_TITLES:
				t = t.replace(k, SHORT_TITLES[k])
		Deck.text(ci, 14, 7, Deck.fit(t, w - 18), 8, UI.GOLD)
		var px := Rect2(4, 17, 30, 33)
		ci.draw_rect(px, NAVY_LO)
		if tex != null:
			ci.draw_texture_rect(tex, Rect2(px.position + Vector2(2, 2), Vector2(Portrait.SIZE)), false)
		elif src != null:
			TeamLogo.draw_fine_in(ci, px.grow(-1), src, true)
		else:
			_no_logo(ci, px.grow(-3))
		Deck.frame(ci, px, Color(0, 0, 0, 0), Color(UI.BORDER, 0.5))
		var x := 38.0
		var tw := w - x - 4.0
		Deck.text(ci, x, 21, Deck.fit(String(a.get("name", "")).to_upper(), tw), 8, UI.TEXT)
		Deck.text(ci, x, 30, Deck.fit(String(a.get("team_name", "")).to_upper(), tw), 8, UI.ACCENT)
		var pos := _pos_text(int(a.get("pos", -1)))
		var line := String(a.get("line", ""))
		Deck.text(ci, x, 39, Deck.fit(pos, tw), 8, UI.DIM)
		# the line that won it: what fits beside the portrait, the rest the card's full width below
		var parts := line.split(" | ", false)
		var one := PackedStringArray()
		while not parts.is_empty() and Deck.text_w("  ".join(one + PackedStringArray([parts[0]]))) <= tw:
			one.append(parts[0])
			parts.remove_at(0)
		if not one.is_empty():
			Deck.text(ci, x, 48, "  ".join(one), 8, UI.TEXT)
		if not parts.is_empty():
			Deck.text(ci, 6, 58, Deck.fit("  ".join(parts), w - 12), 8, UI.TEXT))
	card.name = "Award_" + String(a.get("key", a.get("cat", "")))
	return card

# ------------------------------------------------------------------ ALL-STAR TEAMS
func _player_card(p: Dictionary) -> Control:
	var team := String(p.get("team", ""))
	var src = _team_src(team)
	var tex := _portrait(p, src)
	var mine := _is_mine(team)
	var card := _box(PLAYER_H, func(ci: Control):
		var w := ci.size.x
		Deck.frame(ci, Rect2(0, 0, w, PLAYER_H - 1), NAVY, UI.ACCENT if mine else Color(UI.BORDER, 0.7))
		var px := Rect2(2, 1, 28, PLAYER_H - 3)
		ci.draw_rect(px, NAVY_LO)
		if tex != null:
			ci.draw_texture_rect(tex, Rect2(px.position + Vector2(1, 0), Vector2(Portrait.SIZE)), false)
		elif src != null:
			TeamLogo.draw_fine_in(ci, px.grow(-2), src)
		else:
			_no_logo(ci, px.grow(-3))
		var slot := String(p.get("slot", ""))
		var x := 34.0
		if slot != "":
			var chip := Rect2(x, 4, maxf(16, Deck.text_w(slot) + 6), 10)
			ci.draw_rect(chip, Deck.pos_color(int(p.get("pos", 0))) if int(p.get("pos", -1)) >= 0 else UI.DIM)
			Deck.ctext(ci, chip, slot, 8, UI.INK)
			Deck.text(ci, chip.end.x + 4, 9, Deck.fit(String(p.get("name", "")).to_upper(), w - chip.end.x - 8), 8, UI.TEXT)
		else:
			Deck.text(ci, x, 9, Deck.fit(String(p.get("name", "")).to_upper(), w - x - 4), 8, UI.TEXT)
		Deck.text(ci, x, 22, Deck.fit(String(p.get("team_name", "")).to_upper(), w - x - 4), 8, UI.ACCENT))
	card.name = "Player"
	return card

# ------------------------------------------------------------------ RECORDS
func _record_card(r: Dictionary) -> Control:
	var ncsa := String(r.get("level", "")) == "ncsa"
	var card := _box(36, func(ci: Control):
		var w := ci.size.x
		var edge := UI.GOLD if ncsa else UI.ACCENT
		Deck.frame(ci, Rect2(0, 0, w, 34), PLATE_GOLD if ncsa else NAVY, edge, true)
		ci.draw_rect(Rect2(1, 1, 3, 32), edge)
		var tag := "NCSA RECORD" if ncsa else "SCHOOL RECORD"
		var unit := String(r.get("unit", ""))
		var val := "%d %s" % [int(r.get("v", 0)), unit]
		var vw := maxf(Deck.text_w(val, 16, "big"), Deck.text_w("NEW RECORD")) + 8
		var tw := w - 10 - vw - 4
		Deck.text(ci, 9, 7, Deck.fit("%s  -  %s" % [tag, String(r.get("title", ""))], tw), 8, edge)
		var who := String(r.get("name", "")).to_upper()
		var school := String(r.get("team_name", "")).to_upper()
		if school != "" and school != who:
			who += "  -  " + school
		Deck.text(ci, 9, 18, Deck.fit(who, tw), 8, UI.TEXT)
		if int(r.get("prev", 0)) > 0:
			Deck.text(ci, 9, 28, Deck.fit("PREVIOUS RECORD: %d %s" % [int(r.prev), unit], tw), 8, UI.DIM)
		var vx := w - vw - 2
		Deck.text(ci, vx, 8, "NEW RECORD", 8, UI.DIM)
		Deck.shadow_text(ci, vx, 22, Deck.fit(val, vw, 16, "big"), 16, UI.GOLD if ncsa else UI.TEXT, "big"))
	card.name = "Record_" + String(r.get("key", ""))
	return card

# ------------------------------------------------------------------ YOUR SEASONS
## The dynasty's history: the totals, then each season, newest first, in its own scroll.
func _history_panel() -> Control:
	var hist: Dictionary = m if m.has("history") else (SeasonReview.history(c) if c != null else {})
	var rows: Array = hist.get("history", [])
	var tot: Dictionary = hist.get("totals", {})
	var p := PanelContainer.new()
	p.name = "YourSeasons"
	p.add_theme_stylebox_override("panel", UI.chunky(NAVY, UI.BORDER, false, false, 4, 4, UI.BEVEL_SOFT))
	p.custom_minimum_size = Vector2(RIGHT_W, 0)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(3)
	p.add_child(v)
	var head := UI.canvas(0, 12, func(ci: Control):
		Deck.trophy(ci, Vector2(1, 0), UI.GOLD)
		Deck.shadow_text(ci, 14, 6, "YOUR SEASONS", 8, UI.GOLD)
		ci.draw_rect(Rect2(0, 11, ci.size.x, 1), Color(UI.GOLD, 0.6)))
	v.add_child(head)
	var stats := [["YEARS", int(tot.get("seasons", rows.size()))], ["TITLES", int(tot.get("titles", 0))],
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
	var sc := UI.scroll(list)
	sc.name = "HistoryScroll"
	v.add_child(sc)
	if rows.is_empty():
		var none := UI.label("NO COMPLETED SEASONS YET", 8, UI.DIM, "caps")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(none)
	for h in rows:
		list.add_child(_history_row(h))
	return p

func _history_row(h: Dictionary) -> Control:
	var titles: Array = h.get("titles", [])
	var champ := not titles.is_empty()
	var fin := _finish(String(h.get("finish", "")), true)
	var ht := 39 + (13 if champ else 0)
	var row := _box(ht, func(ci: Control):
		var w := ci.size.x
		Deck.frame(ci, Rect2(0, 0, w, ht - 1), PLATE_GOLD if champ else NAVY_HI, UI.GOLD if champ else Color(UI.BORDER, 0.5))
		Deck.text(ci, 4, 6, _years(String(h.get("year", ""))), 8, UI.GOLD)
		Deck.rtext(ci, w - 4, 6, "%d-%d" % [int(h.get("w", 0)), int(h.get("l", 0))], 8, UI.TEXT)
		Deck.text(ci, 4, 15, Deck.fit(String(h.get("team_name", "")).to_upper(), w - 8), 8, UI.ACCENT)
		if int(h.get("rank", 0)) > 0:
			Deck.text(ci, 4, 24, "CONF. FINISH  %s" % SeasonReview.ordinal(int(h.rank)), 8, UI.DIM)
		Deck.text(ci, 4, 33, Deck.fit(fin, w - 8), 8, UI.DIM)
		if champ:
			Deck.trophy(ci, Vector2(3, 38), UI.GOLD)
			Deck.text(ci, 16, 44, Deck.fit(_titles_short(titles), w - 20), 8, UI.GOLD))
	row.name = "Season_" + String(h.get("year", ""))
	return row

# ------------------------------------------------------------------ helpers
## What a team's logo is drawn from: the dynasty's team, else the school's data; null: no logo.
func _team_src(id: String) -> Variant:
	if id == "":
		return null
	if _cr != null and _cr.teams.has(id):
		return _cr.teams[id]
	var s := Colleges.school(id)
	return s if not s.is_empty() else null

## How a season ended, in caps, without the filler ("LOST IN CONFERENCE QUARTERFINAL"); `short`
## for the history panel ("LOST: CONF. QUARTERFINAL").
static func _finish(s: String, short: bool) -> String:
	var t := s.to_upper().replace("LOST IN THE ", "LOST: " if short else "LOST IN ").replace("MISSED THE ", "MISSED ")
	if short:
		t = t.replace("CONFERENCE", "CONF.").replace("CHAMPIONSHIP", "CHAMP.")
	return t

## ["NCC CHAMPIONS", "NCSA CHAMPIONS"] -> "NCC + NCSA CHAMPIONS".
static func _titles_short(titles: Array) -> String:
	if titles.all(func(t): return String(t).ends_with(" CHAMPIONS")):
		return " + ".join(titles.map(func(t): return String(t).trim_suffix(" CHAMPIONS"))) + " CHAMPIONS"
	return " + ".join(titles)

func _is_mine(id: String) -> bool:
	var you: Dictionary = m.get("you", {})
	return id != "" and id == String(you.get("team", ""))

## A winner's portrait in his team's colours (a keeper's cap red), or null: no player to draw.
func _portrait(e: Dictionary, src: Variant) -> Texture2D:
	var p: PoloPlayer = e.get("p") if e.get("p") is PoloPlayer else null
	if p == null and _cr != null and int(e.get("pid", -1)) >= 0:
		p = ConfAwards.player_of(_cr, {"pid": int(e.pid)})
	if p == null:
		return null
	var cap := Color("2a68f5")
	var trim := Color.WHITE
	if src is PoloTeam:
		cap = src.c1
		trim = src.c2
	elif src is Dictionary:
		cap = Color(String(src.get("c1", "2a68f5")))
		trim = Color(String(src.get("c2", "ffffff")))
	if p.is_keeper():
		cap = PoolArt.CAP_KEEPER
	return Portrait.texture(p, cap, trim)

func _pos_text(pos: int) -> String:
	if pos < 0:
		return ""
	return ["GOALKEEPER", "CENTER", "ATTACKER", "WING", "UTILITY", "TWO-METER DEFENDER"][clampi(pos, 0, 5)]

func _icon(ci: CanvasItem, at: Vector2, icon: String, col: Color) -> void:
	Deck.pat(ci, at, ICONS.get(icon, ICONS.star), {"#": col, "o": col.darkened(0.45)})

func _star(ci: CanvasItem, at: Vector2) -> void:
	Deck.pat(ci, at, ICONS.star, {"#": UI.GOLD})

func _you_tag(ci: CanvasItem, at: Vector2) -> void:
	var r := Rect2(at, Vector2(28, 10))
	ci.draw_rect(r, UI.ACCENT)
	Deck.ctext(ci, r, "YOU", 8, UI.INK)

func _no_logo(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, Color(UI.DIM, 0.12))
	Deck.ctext(ci, r, "?", 8, Color(UI.DIM, 0.6))
