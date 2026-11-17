extends BaseScreen
## Developer Mode's VIEW SEASON REVIEW (Settings > Developer Tools): the season review screen
## (recap, the very one a season ends on) whenever you like, without playing a season out.
##   YOUR SEASONS      every season the loaded career has finished: its real review, read from the
##                     career (SeasonReview.build) and never written to
##   SAMPLE SCENARIOS  made-up seasons for testing the layout, built here and handed to the screen
##                     as data (shown with DEV PREVIEW - SAMPLE DATA): a normal season, conference
##                     and national champions, a record-breaking season, every award, very few, a
##                     long dynasty, long names with missing portraits and logos, nothing at all
## Read only: a preview never takes a review off the hub's queue, never saves, and no sample is
## ever written to a career (it isn't one: plain data, made fresh each time). Developer Mode off,
## the screen sends you back to Settings.

const SCENARIOS := [["NORMAL SEASON", "normal"], ["CONFERENCE CHAMPIONS", "conf"], ["NATIONAL CHAMPIONS", "national"],
	["RECORD-BREAKING SEASON", "records"], ["MANY AWARD WINNERS", "many"], ["VERY FEW AWARDS", "few"],
	["LONG DYNASTY (14 SEASONS)", "dynasty"], ["LONG NAMES, NO ART", "stress"], ["EMPTY SECTIONS", "empty"]]

## Made-up names (nobody in any dynasty: the samples never borrow a real player).
const FIRSTS := ["Tomas", "Ezra", "Mateo", "Rhys", "Dario", "Felix", "Nico", "Owen", "Luka", "Ivan", "Jonah", "Marco",
	"Theo", "Rafael", "Kai", "Silas", "Anders", "Bruno", "Cyrus", "Dmitri", "Elio", "Gavin", "Hugo", "Jasper"]
const LASTS := ["Castro", "Whitfield", "Moreau", "Albescu", "Pryce", "Okafor", "Lindqvist", "Varga", "Delacroix", "Nakamura",
	"Petrovic", "Haldane", "Ferreira", "Quist", "Sorensen", "Abernathy", "Kowalczyk", "Ibarra", "Tanaka", "Muller",
	"Rousseau", "Grigoryan", "Sutherland", "Vasquez"]
const YOU := "LIUB"

func _ready() -> void:
	back_target = "dev_settings"
	if not bool(Game.settings.get("dev_mode", false)):
		Game.goto.call_deferred("settings", {}, false)
		return
	build("SEASON REVIEW PREVIEW")
	var v := UI.vbox(4)
	var sc := UI.scroll(v)
	body.add_child(sc)
	v.add_child(UI.label("YOUR SEASONS (READ ONLY)", 16, UI.GOLD, "big"))
	var seasons := SeasonReview.seasons(c)
	if seasons.is_empty():
		var none := UI.label("No finished seasons in the loaded career. Use a sample scenario below." if c != null
			else "No career is loaded. Use a sample scenario below, or load a career to preview its seasons.", 8, UI.DIM)
		none.name = "NoSeasons"
		v.add_child(none)
	else:
		var g := _grid("RealSeasons")
		for s in seasons:
			var season: String = s
			var h: Dictionary = {}
			for e in c.history:
				if String(e.get("year", "")) == season:
					h = e
			var b := UI.button("%s  %s  %d-%d" % [season, Colleges.team_name(String(h.get("team", ""))).to_upper(), int(h.get("w", 0)), int(h.get("l", 0))],
				func(): Game.goto("recap", {"preview": true, "season": season}), "normal", 0, 18)
			b.name = "Season_" + season
			b.clip_text = true
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(b)
		v.add_child(g)
	v.add_child(UI.spacer(0, 4))
	v.add_child(UI.label("SAMPLE SCENARIOS (DEV DATA ONLY)", 16, UI.GOLD, "big"))
	var sg := _grid("Samples")
	for s in SCENARIOS:
		var kind: String = s[1]
		var b := UI.button(String(s[0]), func(): Game.goto("recap", {"preview": true, "sample": true, "model": sample(kind)}), "ghost", 0, 18)
		b.name = "Sample_" + kind
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sg.add_child(b)
	v.add_child(sg)
	var note := UI.label("Previews are read only: nothing is saved, no award or record is given, the season doesn't move.", 8, UI.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)

func _grid(n: String) -> GridContainer:
	var g := GridContainer.new()
	g.name = n
	g.columns = 2
	g.add_theme_constant_override("h_separation", 3)
	g.add_theme_constant_override("v_separation", 3)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return g

# ------------------------------------------------------------------ the samples
## A sample scenario's review, in SeasonReview's shape. The same every time (no randomness).
static func sample(kind: String) -> Dictionary:
	var n := [0]   # (the next made-up player)
	var player := func(team: String, pos: int, long: bool) -> Dictionary:
		var i: int = n[0]
		n[0] += 1
		var p := PoloPlayer.new()
		p.id = 900000 + i
		p.first = FIRSTS[i % FIRSTS.size()]
		p.last = LASTS[(i * 7) % LASTS.size()]
		if long:
			p.first = "Maximilian-Alexander"
			p.last = "Vanderhoeven-Castellanos"
		p.pos = pos
		p.skin = i % 4
		var e := {"name": "%s %s" % [p.first, p.last], "team": team, "team_name": _tname(team), "pos": pos, "pid": -1}
		if kind != "stress":
			e["p"] = p   # (stress: no portraits, so the fallbacks show)
		return e
	var m := {"season": "2026-27", "you": {}, "national": {}, "confs": [], "awards": [], "postseason": [],
		"teams": [], "records": [], "history": [], "totals": {"seasons": 0, "conf": 0, "nat": 0, "titles": 0}}
	if kind == "empty":
		return m
	# your season
	var you := {"team": YOU, "team_name": _tname(YOU), "conf": "NWPC", "conf_name": "Northeast Coast Conference", "conf_abbr": "NCC",
		"w": 12, "l": 4, "cw": 6, "cl": 2, "rank": 2, "finish": "Lost in the conference semifinal", "poll": 14, "titles": [],
		"national": false, "points": 45}
	match kind:
		"conf":
			you.merge({"w": 17, "l": 3, "cw": 8, "cl": 0, "rank": 1, "finish": "Lost in the NCSA quarterfinal", "poll": 7, "titles": ["NCC CHAMPIONS"]}, true)
		"national":
			you.merge({"w": 22, "l": 1, "cw": 8, "cl": 0, "rank": 1, "finish": "NCSA champions", "poll": 1, "titles": ["NCC CHAMPIONS", "NCSA CHAMPIONS"], "national": true}, true)
		"few":
			you.merge({"w": 5, "l": 11, "cw": 2, "cl": 6, "rank": 6, "finish": "Missed the conference tournament", "poll": 0}, true)
	if kind == "stress":
		you.merge({"team": "", "team_name": "The Extraordinarily Long-Named Polytechnic Institute Fighting Hammerheads",
			"conf_name": "Northeast Coast Intercollegiate Water Polo Athletic Conference"}, true)
	var top: Dictionary = player.call(YOU, PoloPlayer.Pos.DRIVER, false)
	you["top"] = {"name": top.name, "g": 41 if kind != "records" else 77}
	m.you = you
	# champions
	var nat := YOU if kind == "national" else "CULA"
	m.national = {"team": nat, "team_name": _tname(nat), "runner_up": "CUSC", "runner_name": _tname("CUSC"), "score": "11-9"}
	var confs := [["MPSF", "CULA", "STAM"], ["BIGWEST", "LBSC", "CUSD"], ["WCC", "SJCU", "PPCU"],
		["NWPC", YOU if kind in ["conf", "national"] else "PRIN", "HVRD"], ["MAWPC", "FORDU", "NANA"]]
	if kind == "few":
		confs = confs.slice(0, 2)
	for cf in confs:
		var e := {"conf": cf[0], "abbr": Colleges.conf_abbr(cf[0]), "conf_name": String(Colleges.conference(cf[0]).get("name", "")),
			"team": cf[1], "team_name": _tname(cf[1]), "runner_up": cf[2], "runner_name": _tname(cf[2]), "score": "%d-%d" % [9 + confs.find(cf), 7]}
		if kind == "stress":
			e.team = ""
			e.team_name = "Saint Bartholomew-Fitzgerald Memorial University Sea Lions"
			e.conf_name = "Extremely Long Regional Intercollegiate Conference Name"
		m.confs.append(e)
	# season awards
	var award := func(key: String, team: String, pos: int, line: String, co: bool) -> Dictionary:
		var e: Dictionary = player.call(team, pos, kind == "stress")
		e.merge({"key": key, "title": SeasonReview.AWARD_TITLES[key], "line": line, "co": co})
		return e
	m.awards.append(award.call("poy", "CULA", PoloPlayer.Pos.DRIVER, "24 GP | 58 G | 31 A | 22 ST | 6 BL", false))
	if kind != "few":
		m.awards.append(award.call("dpoy", "STAM", PoloPlayer.Pos.GK, "24 GP | 241 SAVES | 64% SAVED", false))
		m.awards.append(award.call("foy", YOU, PoloPlayer.Pos.WING, "20 GP | 33 G | 18 A | 14 ST | 2 BL", false))
		m.awards.append(award.call("arm", "LBSC", PoloPlayer.Pos.CENTER, "61 GOALS", false))
		m.awards.append(award.call("wall", "STAM", PoloPlayer.Pos.GK, "241 SAVES", false))
	if kind == "many":
		m.awards.append(award.call("arm", "FORDU", PoloPlayer.Pos.DRIVER, "61 GOALS", true))
		m.awards[3].co = true
	var coach := {"key": "coach", "title": SeasonReview.AWARD_TITLES.coach, "name": "Coach Rinaldi" if kind != "national" else "Coach Harlow",
		"team": YOU if kind == "national" else "HVRD", "pos": -1, "pid": -1, "line": ""}
	coach["team_name"] = _tname(String(coach.team))
	m.awards.append(coach)
	# postseason
	if kind != "few":
		var nat_grp := {"tid": "nat", "title": "NCSA CHAMPIONSHIP", "awards": []}
		for cat in TourneyAwards.CATS:
			var e: Dictionary = player.call(nat, [PoloPlayer.Pos.DRIVER, PoloPlayer.Pos.CENTER, PoloPlayer.Pos.GK][TourneyAwards.CATS.find(cat)], kind == "stress")
			e.merge({"cat": cat, "title": TourneyAwards.TITLES[cat], "line": "4 GAMES | 14 GOALS | 6 ASSISTS | 5 STEALS" if cat != "dpot" else "4 GAMES | 52 SAVES | 31 AGAINST | 63% SAVED"})
			nat_grp.awards.append(e)
		m.postseason.append(nat_grp)
		for cf in confs:
			var e: Dictionary = player.call(cf[1], PoloPlayer.Pos.WING, kind == "stress")
			e.merge({"cat": "pot", "title": TourneyAwards.TITLES.pot, "line": "3 GAMES | 9 GOALS | 4 ASSISTS"})
			m.postseason.append({"tid": "conf:" + String(cf[0]), "title": "%s TOURNAMENT" % Colleges.conf_abbr(cf[0]), "awards": [e]})
	# the all-star teams
	var slots := [["GK", PoloPlayer.Pos.GK], ["C", PoloPlayer.Pos.CENTER], ["2MD", PoloPlayer.Pos.DEFENDER], ["ATK", PoloPlayer.Pos.DRIVER],
		["ATK", PoloPlayer.Pos.DRIVER], ["WG", PoloPlayer.Pos.WING], ["WG", PoloPlayer.Pos.WING]]
	var schools := ["CULA", "CUSC", "STAM", "ALC", "LBSC", "SJCU", "FORDU", YOU, "PRIN", "HVRD", "CUSD", "ICU"]
	var titles := ["ALL-NCSA FIRST TEAM", "ALL-NCSA SECOND TEAM", "ALL-NCC TEAM"] if kind != "few" else ["ALL-NCC TEAM"]
	for t in titles:
		var players: Array = []
		for s in slots:
			var e: Dictionary = player.call(schools[n[0] % schools.size()], s[1], kind == "stress")
			e["slot"] = s[0]
			players.append(e)
		m.teams.append({"title": t, "players": players})
	# records
	var rec := func(level: String, key: String, v: int, prev: int, name: String, team: String) -> Dictionary:
		return {"level": level, "key": key, "title": String(Records.NAMES[key]).to_upper(), "v": v, "prev": prev, "name": name,
			"team_name": _tname(team) if team != "" else name, "unit": String(SeasonReview.UNITS[key])}
	if kind == "records":
		m.records = [rec.call("ncsa", "season_goals", 77, 72, "T. Castro", YOU), rec.call("ncsa", "game_goals", 9, 8, "E. Whitfield", "CULA"),
			rec.call("ncsa", "season_wins", 28, 27, _tname(YOU), YOU), rec.call("ncsa", "game_margin", 19, 17, _tname("STAM"), "STAM"),
			rec.call("school", "season_assists", 44, 39, "M. Moreau", YOU), rec.call("school", "season_saves", 263, 240, "R. Albescu", YOU),
			rec.call("school", "game_team_goals", 24, 21, _tname(YOU), YOU)]
	elif kind in ["many", "stress"]:
		m.records = [rec.call("ncsa", "season_goals", 74, 72, "Maximilian-Alexander Vanderhoeven-Castellanos" if kind == "stress" else "T. Castro", "CULA"),
			rec.call("school", "season_wins", 19, 18, _tname(YOU), YOU)]
	elif kind == "national":
		m.records = [rec.call("school", "season_wins", 25, 21, _tname(YOU), YOU)]
	# the dynasty
	var count: int = {"normal": 1, "conf": 2, "national": 4, "records": 3, "many": 5, "few": 1, "dynasty": 14, "stress": 12}.get(kind, 1)
	var h: Array = []
	var tot := {"seasons": count, "conf": 0, "nat": 0, "titles": 0}
	for i in count:
		var yr: int = 2026 - int(i)
		var tl: Array = []
		if i == 0:
			tl = you.titles.duplicate()
		elif kind == "dynasty" and i % 3 == 1:
			tl = ["NCC CHAMPIONS"] + (["NCSA CHAMPIONS"] if i == 4 else [])
		elif kind == "national" and i == 2:
			tl = ["NCC CHAMPIONS"]
		for t in tl:
			if String(t).begins_with("NCSA"):
				tot.nat += 1
			else:
				tot.conf += 1
		var team := YOU if i < 6 else "IONA"
		var tname := _tname(team) if kind != "stress" else "The Extraordinarily Long-Named Polytechnic Institute"
		h.append({"year": "%d-%02d" % [yr, (yr + 1) % 100], "team": team, "team_name": tname, "w": int(you.w) if i == 0 else 10 + (i * 5) % 9,
			"l": int(you.l) if i == 0 else 3 + (i * 3) % 7, "rank": int(you.rank) if i == 0 else 1 + i % 5,
			"finish": String(you.finish) if i == 0 else ["Lost in the conference final", "Missed the NCSA Championship", "Lost in the NCSA quarterfinal"][i % 3],
			"titles": tl})
	tot.titles = tot.conf + tot.nat
	m.history = h
	m.totals = tot
	return m

static func _tname(id: String) -> String:
	return Colleges.team_name(id) if id != "" else ""
