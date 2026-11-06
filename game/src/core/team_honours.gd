class_name TeamHonours
## A PROGRAM'S CHAMPIONSHIPS (the Team Trophy Case): every conference tournament and NCSA
## Championship a school has won, from the league's own records:
##   Career.champions_log   each finished season's champions (record_season, when the season
##                          ends: Offseason.begin), {season, conf: {conf id: team}, nat: team}
##   Career.legacy          the seasons before the dynasty (Legacy), the same shape
##   Career.coach.titles    an older save's titles from before the log was kept ("2026-27 NCSA",
##                          "2026-27 Pacific Elite Conference"): your own, so your school's then
##                          (Career.history), counted only for a season the log doesn't have
## Each title its own entry, in the shape Honours gives a player's (the Trophy Room draws both):
## {kind "title", key, cat (conf_champ | ncsa_champ), title, short, season, year (earned), week "",
## conf, team, line "", order}.

const DIVISION_TITLES := {"d2": "DIVISION II CHAMPIONS", "d3": "NCSA DIVISION III NATIONAL CHAMPIONS"}

## The season's champions into the log, once (a season already there is left as it is).
static func record_season(c: Career) -> void:
	var label := c.season_label()
	if c.champions_log.any(func(e): return String(e.season) == label):
		return
	var confs := {}
	for id in c.season.get("conf_champs", []):
		if c.teams.has(id):
			confs[String((c.teams[id] as PoloTeam).conf)] = String(id)
	var e := {"season": label, "conf": confs, "nat": String(c.season.get("champion", ""))}
	e["finals"] = Schedule.finals(c.schedule, c.teams)
	for f in e.finals:
		if String(f.key) in ["d2", "d3"]:
			e[String(f.key)] = String(f.champion)
	c.champions_log.append(e)

## A season's champions as lines for the Record Book: "NCSA: Team" for the seasons before the
## dynasty (no finals are known), "NCSA: Team def. Team 9-7" for yours.
static func lines_of(e: Dictionary, name_of: Callable) -> PackedStringArray:
	var out := PackedStringArray()
	for f in e.get("finals", []):
		out.append("%s: %s def. %s %s" % [String(f.tournament).trim_suffix(" CHAMPIONSHIP"), name_of.call(String(f.champion)), name_of.call(String(f.runner_up)), String(f.score)])
	return out

## Every title school `team_id` has won, oldest first.
static func of(c: Career, team_id: String) -> Array:
	var out: Array = []
	var seen := {}
	for e in c.legacy + c.champions_log:
		var season := String(e.season)
		seen[season] = true
		var conf: Dictionary = e.get("conf", {})
		for cf in conf:
			if String(conf[cf]) == team_id:
				out.append(_entry("conf", String(cf), season, team_id, c.legacy.has(e)))
		if String(e.get("nat", "")) == team_id:
			out.append(_entry("nat", "", season, team_id, c.legacy.has(e)))
		for k in ["d2", "d3"]:
			if String(e.get(k, "")) == team_id:
				out.append(_entry(k, "", season, team_id, c.legacy.has(e)))
	# an older save's own titles, for seasons from before the log
	for t in c.coach.get("titles", []):
		var text := String(t)
		var season := text.get_slice(" ", 0)
		if seen.has(season):
			continue
		var school := c.school
		for h in c.history:
			if String(h.get("year", "")) == season:
				school = String(h.get("team", c.school))
		if school != team_id:
			continue
		var what := text.substr(season.length() + 1)
		if what == "NCSA":
			out.append(_entry("nat", "", season, team_id, false))
		else:
			var cf := ""
			for conf in Colleges.CONFERENCES:
				if String(conf.name) == what:
					cf = String(conf.id)
			if cf == "" and c.teams.has(team_id):
				cf = String((c.teams[team_id] as PoloTeam).conf)
			out.append(_entry("conf", cf, season, team_id, false))
	out.sort_custom(func(a, b): return Honours._before(a.order, b.order))
	return out

static func _entry(kind: String, conf: String, season: String, team: String, hist: bool) -> Dictionary:
	var abbr := Colleges.conf_abbr(conf) if conf != "" else "NCSA"
	var title := "%s CHAMPIONS" % abbr
	if kind in DIVISION_TITLES:
		title = String(DIVISION_TITLES[kind])
		abbr = "DIV. II" if kind == "d2" else "DIV. III"
	return {"kind": "title", "key": ("c|" + conf) if kind == "conf" else (kind if kind in DIVISION_TITLES else "n"),
		"cat": "conf_champ" if kind == "conf" else (kind + "_champ" if kind in DIVISION_TITLES else "ncsa_champ"),
		"title": title, "short": title, "season": season, "year": NationalAwards.earned_year(season), "week": "",
		"conf": abbr, "team": team, "line": "BEFORE YOUR DYNASTY" if hist else "", "order": [season, 0 if kind == "conf" else (2 if kind == "nat" else 1), 0]}
