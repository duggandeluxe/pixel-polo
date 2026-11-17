class_name SeasonReview
## THE SEASON REVIEW, as data (the Season Review Redesign): one finished season gathered from what
## the career already keeps, for the recap screen to draw. It never works anything out again and
## never writes to the career: every winner, champion and record here is one the season produced.
##   you         your season (Career.history): team, record, conference finish, postseason, titles
##               (TeamHonours), your top scorer and the season's Polo Points (the history entry's
##               "review", kept from Offseason.begin)
##   national    the NCSA champion (Career.champions_log; the final's runner-up and score)
##   confs       every conference tournament champion
##   awards      the NCSA's season honours and Coach of the Year (Career.awards)
##   postseason  the All-Tournament awards (Career.tourney_awards), the NCSA's first
##   teams       All-NCSA First and Second Team (Career.awards), your All-Conference team (the
##               history entry's "review")
##   records     the records broken that season, once each: the season's own marks as they were
##               broken (with the mark they beat), the NCSA's log, your school's book
##   history     every season you've coached, newest first, and the totals
## The same shape is what DEV Mode's sample scenarios hand the screen (review_lab), so one screen
## draws both. A team is its id ("team") and its name ("team_name"): a sample can name a team the
## dynasty doesn't have.

## The order the season honours are shown in, and their card titles. (golden_cap and keeper: an
## older save's awards, before the National Awards update.)
const AWARD_ORDER := ["poy", "dpoy", "foy", "arm", "wall", "coach", "golden_cap", "keeper"]
const AWARD_TITLES := {"poy": "PLAYER OF THE YEAR", "dpoy": "DEFENSIVE PLAYER OF THE YEAR", "foy": "FRESHMAN OF THE YEAR",
	"arm": "GOLDEN ARM AWARD", "wall": "IRON WALL AWARD", "coach": "COACH OF THE YEAR", "golden_cap": "GOLDEN CAP",
	"keeper": "KEEPER OF THE YEAR"}
## How a record's value reads ("72 GOALS").
const UNITS := {"game_goals": "GOALS", "game_saves": "SAVES", "game_team_goals": "GOALS", "game_margin": "GOAL MARGIN",
	"season_goals": "GOALS", "season_assists": "ASSISTS", "season_saves": "SAVES", "season_wins": "WINS",
	"career_goals": "GOALS", "career_saves": "SAVES", "career_assists": "ASSISTS", "career_steals": "STEALS", "career_blocks": "BLOCKS"}

## The seasons there is a review of: every season you've coached, newest first.
static func seasons(c: Career) -> Array:
	var out: Array = []
	if c == null:
		return out
	for h in c.history:
		out.push_front(String(h.get("year", "")))
	return out

## Season `season`'s review ({} if there's no career).
static func build(c: Career, season: String) -> Dictionary:
	if c == null:
		return {}
	var h := _history_entry(c, season)
	var extra: Dictionary = h.get("review", {})
	var log_e := _champions(c, season)
	var m := {"season": season, "you": _you(c, season, h, extra), "awards": _awards(c, season),
		"postseason": _postseason(c, season), "teams": _teams(c, season, extra),
		"records": _records(c, season, h, extra)}
	m.merge(_champs(c, log_e))
	m.merge(history(c))
	return m

## THE SEASON SO FAR (Championship Elimination): this season's review while the league is still
## playing it, in build's shape with "live": true. Only what's already decided is in it: your
## record and conference finish, the conference champions, the awards and records given so far.
## What the rest of the NCSA still decides (its champion, the season honours, the All-NCSA
## teams, the NCSA's own tournament awards) is marked pending ("*_pending"), never guessed. Two
## more sections a finished season's review doesn't need: TEAM LEADERS and RECRUITING. Read only.
static func live(c: Career) -> Dictionary:
	if c == null:
		return {}
	var season := c.season_label()
	var me := c.team()
	var row: Dictionary = c.table.get(c.school, Schedule.empty_row())
	var titles: Array = []
	if c.school in (c.season.get("conf_champs", []) as Array):
		titles.append("%s CHAMPIONS" % Colleges.conf_abbr(me.conf))
	var you := {"team": c.school, "team_name": me.name, "conf": me.conf, "conf_name": c.conf_name(), "conf_abbr": c.conf_abbr(),
		"w": int(row.w), "l": int(row.l), "cw": int(row.cw), "cl": int(row.cl), "rank": c.conf_rank(),
		"finish": String(c.season.get("finish", "")), "poll": Poll.rank_in(Poll.latest(c), c.school), "titles": titles, "national": false}
	var top := Offseason._top_scorer(me)
	if top != null:
		you["top"] = {"name": "%s %s" % [top.first, top.last], "pid": top.id, "g": top.stat("g")}
	var pts := 0
	for e in c.season.get("credit_log", []):
		pts += int(e[1])
	you["points"] = pts
	# the champions decided so far
	var finals := Schedule.finals(c.schedule, c.teams)
	var log_e := {"season": season, "conf": {}, "nat": "", "finals": finals}
	for f in finals:
		if String(f.key) == "nat":
			log_e.nat = String(f.champion)
		elif String(f.key).begins_with("conf:"):
			log_e.conf[String(f.key).trim_prefix("conf:")] = String(f.champion)
	var rem := c.remaining_championship()
	var post := _postseason(c, season)
	var m := {"season": season, "live": true, "you": you, "awards": _awards(c, season), "postseason": post,
		"teams": _teams(c, season, {}), "records": _records(c, season, {"team": c.school}, {}),
		"leaders": leaders(me), "recruiting": recruiting(c),
		"national_pending": String(log_e.nat) == "", "awards_pending": true, "teams_pending": true,
		"nat_honours_pending": not post.any(func(g): return String(g.tid) == "nat"),
		"remaining": {"round": String(rem.round), "alive": (rem.alive as Array).size()}}
	m.merge(_champs(c, log_e))
	m.merge(history(c))
	return m

## Your team's statistical leaders this season: [{title, name, pid, v, unit}] (goals, assists,
## steals, blocks, the keeper's saves); a stat nobody has yet is left out.
static func leaders(t: PoloTeam) -> Array:
	var out: Array = []
	for k in [["g", "GOALS"], ["a", "ASSISTS"], ["st", "STEALS"], ["bl", "BLOCKS"], ["sv", "SAVES"]]:
		var best: PoloPlayer = null
		for p in t.roster:
			if p.stat(k[0]) > 0 and (best == null or p.stat(k[0]) > best.stat(k[0])):
				best = p
		if best != null:
			out.append({"key": k[0], "title": k[1], "name": "%s %s" % [best.first, best.last], "pid": best.id, "pos": best.pos,
				"v": best.stat(k[0]), "team": t.id, "team_name": t.name})
	return out

## Where recruiting stands: signed, pinned, graduating, next season's projected roster.
static func recruiting(c: Career) -> Dictionary:
	return {"signed": c.incoming.size(), "pinned": Recruiting.pinned(c).size(), "graduating": Recruiting.graduating(c).size(),
		"projected": Recruiting.projected(c), "max": c.roster_max(), "over": Recruiting.over_by(c)}

## Your seasons, newest first ({history, totals}): year, team, record, conference finish, the
## titles won; and the totals: seasons, conference and national titles.
static func history(c: Career) -> Dictionary:
	var rows: Array = []
	var conf := 0
	var nat := 0
	for h in c.history:
		var titles := _titles(c, String(h.get("year", "")), String(h.get("team", "")))
		for t in titles:
			if String(t.cat) == "conf_champ":
				conf += 1
			else:
				nat += 1
		rows.push_front({"year": String(h.get("year", "")), "team": String(h.get("team", "")), "team_name": _name(c, String(h.get("team", ""))),
			"w": int(h.get("w", 0)), "l": int(h.get("l", 0)), "rank": int(h.get("rank", 0)), "finish": String(h.get("finish", "")),
			"titles": titles.map(func(t): return String(t.title))})
	return {"history": rows, "totals": {"seasons": rows.size(), "conf": conf, "nat": nat, "titles": conf + nat}}

## "1ST", "2ND", "3RD", "11TH".
static func ordinal(n: int) -> String:
	var suffix := "TH"
	if n % 100 < 11 or n % 100 > 13:
		suffix = ["TH", "ST", "ND", "RD", "TH", "TH", "TH", "TH", "TH", "TH"][n % 10]
	return "%d%s" % [n, suffix]

# ------------------------------------------------------------------ the pieces
static func _history_entry(c: Career, season: String) -> Dictionary:
	for h in c.history:
		if String(h.get("year", "")) == season:
			return h
	return {}

static func _champions(c: Career, season: String) -> Dictionary:
	for e in c.champions_log:
		if String(e.get("season", "")) == season:
			return e
	return {}

static func _name(c: Career, id: String) -> String:
	if id == "":
		return ""
	return String(c.teams[id].name) if c.teams.has(id) else Colleges.team_name(id)

## Titles `team` won in `season` (TeamHonours: the log, or an older save's own titles).
static func _titles(c: Career, season: String, team: String) -> Array:
	if team == "":
		return []
	return TeamHonours.of(c, team).filter(func(t): return String(t.season) == season)

static func _you(c: Career, season: String, h: Dictionary, extra: Dictionary) -> Dictionary:
	if h.is_empty():
		return {}
	var id := String(h.get("team", ""))
	var conf := String((c.teams[id] as PoloTeam).conf) if c.teams.has(id) else String(Colleges.school(id).get("conf", ""))
	var y := {"team": id, "team_name": _name(c, id), "conf": conf, "conf_name": String(Colleges.conference(conf).get("name", "")) if conf != "" else "",
		"conf_abbr": Colleges.conf_abbr(conf) if conf != "" else "", "w": int(h.get("w", 0)), "l": int(h.get("l", 0)),
		"cw": int(h.get("cw", 0)), "cl": int(h.get("cl", 0)), "rank": int(h.get("rank", 0)), "finish": String(h.get("finish", "")),
		"poll": int(h.get("poll", 0)), "titles": _titles(c, season, id).map(func(t): return String(t.title)),
		"national": _titles(c, season, id).any(func(t): return String(t.cat) != "conf_champ")}
	if extra.has("top"):
		y["top"] = (extra.top as Dictionary).duplicate()
	if extra.has("points"):
		y["points"] = int(extra.points)
	return y

static func _champs(c: Career, e: Dictionary) -> Dictionary:
	var finals := {}
	for f in e.get("finals", []):
		finals[String(f.key)] = f
	var side := func(key: String, team: String) -> Dictionary:
		var f: Dictionary = finals.get(key, {})
		var r := {"team": team, "team_name": _name(c, team)}
		if not f.is_empty() and String(f.champion) == team:
			r["runner_up"] = String(f.runner_up)
			r["runner_name"] = _name(c, String(f.runner_up))
			r["score"] = String(f.score)
		return r
	var out := {"national": {}, "confs": []}
	if String(e.get("nat", "")) != "":
		out.national = side.call("nat", String(e.nat))
	var confs: Dictionary = e.get("conf", {})
	var order: Array = ConfAwards.CONF_ORDER.duplicate()
	for cf in confs:
		if not String(cf) in order:
			order.append(String(cf))
	for cf in order:
		if not confs.has(cf):
			continue
		var r: Dictionary = side.call("conf:" + String(cf), String(confs[cf]))
		r["conf"] = String(cf)
		r["abbr"] = Colleges.conf_abbr(String(cf))
		r["conf_name"] = String(Colleges.conference(String(cf)).get("name", ""))
		out.confs.append(r)
	return out

static func _awards(c: Career, season: String) -> Array:
	var out: Array = []
	for key in AWARD_ORDER:
		var recs: Array = c.awards.filter(func(a): return String(a.get("year", "")) == season and String(a.get("award", "")) == key)
		for a in recs:
			var team := String(a.get("team", ""))
			out.append({"key": key, "title": AWARD_TITLES[key], "name": String(a.get("name", "")), "team": team, "team_name": _name(c, team),
				"pos": int(a.get("pos", -1)), "pid": int(a.get("pid", -1)), "co": bool(a.get("co", false)),
				"line": NationalAwards.line_text(a) if key in NationalAwards.KEYS else ""})
	return out

static func _postseason(c: Career, season: String) -> Array:
	var recs: Array = c.tourney_awards.filter(func(a): return String(a.get("season", "")) == season)
	var tids: Array = ["nat"] + ConfAwards.CONF_ORDER.map(func(cf): return "conf:" + cf)
	for a in recs:
		if not String(a.tid) in tids:
			tids.append(String(a.tid))
	var out: Array = []
	for tid in tids:
		var here: Array = recs.filter(func(a): return String(a.tid) == tid)
		if here.is_empty():
			continue
		var group := {"tid": tid, "title": _tourney_title(String(tid)), "awards": []}
		for cat in TourneyAwards.CATS:
			for a in here.filter(func(x): return String(x.cat) == cat):
				var team := String(a.get("team", ""))
				group.awards.append({"cat": cat, "title": TourneyAwards.TITLES[cat], "name": String(a.get("name", "")), "team": team,
					"team_name": _name(c, team), "pos": int(a.get("pos", -1)), "pid": int(a.get("pid", -1)), "line": TourneyAwards.line_text(a)})
		out.append(group)
	return out

static func _tourney_title(tid: String) -> String:
	if tid == "nat":
		return "NCSA CHAMPIONSHIP"
	return "%s TOURNAMENT" % Colleges.conf_abbr(tid.trim_prefix("conf:"))

static func _teams(c: Career, season: String, extra: Dictionary) -> Array:
	var out: Array = []
	for key in ["first", "second"]:
		var recs: Array = c.awards.filter(func(a): return String(a.get("year", "")) == season and String(a.get("award", "")) == key)
		if recs.is_empty():
			continue
		var players: Array = []
		for slot in NationalAwards.TEAM_PLACES:
			for a in recs.filter(func(x): return String(x.get("slot", "")) == String(NationalAwards.PLACE_NAMES[slot])):
				if players.any(func(p): return int(p.pid) == int(a.get("pid", -1)) and int(p.pid) >= 0):
					continue
				players.append(_member(c, a, String(a.get("slot", ""))))
		for a in recs:   # (anyone without a place: an older record)
			if not players.any(func(p): return int(p.pid) == int(a.get("pid", -1))):
				players.append(_member(c, a, String(a.get("slot", ""))))
		out.append({"title": "ALL-NCSA FIRST TEAM" if key == "first" else "ALL-NCSA SECOND TEAM", "players": players})
	var ac: Array = extra.get("all_conf", [])
	if not ac.is_empty():
		var cf := String(ac[0].get("conf", ""))
		out.append({"title": "ALL-%s TEAM" % (Colleges.conf_abbr(cf) if cf != "" else "CONFERENCE"),
			"players": ac.map(func(a): return _member(c, a, ""))})
	return out

static func _member(c: Career, a: Dictionary, slot: String) -> Dictionary:
	var team := String(a.get("team", ""))
	var pos := int(a.get("pos", -1))
	if slot == "" and pos >= 0:
		slot = String(PoloPlayer.POS_SHORT[clampi(pos, 0, PoloPlayer.POS_SHORT.size() - 1)])
	return {"name": String(a.get("name", "")), "team": team, "team_name": _name(c, team), "pos": pos, "slot": slot, "pid": int(a.get("pid", -1))}

## The records broken in `season`, once each (a mark broken twice in a season: its best, beating
## the mark that stood before the season). The NCSA's first.
static func _records(c: Career, season: String, h: Dictionary, extra: Dictionary) -> Array:
	var found := {}   # "level|key" -> entry
	var add := func(level: String, key: String, v: int, name: String, team_name: String, prev: int) -> void:
		if v <= 0 or not Records.NAMES.has(key):
			return
		var k := level + "|" + key
		var e: Dictionary = found.get(k, {})
		if e.is_empty():
			found[k] = {"level": level, "key": key, "title": String(Records.NAMES[key]).to_upper(), "v": v, "name": name, "team_name": team_name,
				"prev": prev, "unit": String(UNITS.get(key, ""))}
			return
		if prev > 0 and (int(e.prev) <= 0 or prev < int(e.prev)):
			e.prev = prev
		if v > int(e.v):
			e.v = v
			e.name = name
			e.team_name = team_name
	for r in extra.get("records", []):
		add.call(String(r.level), String(r.key), int(r.v), String(r.name), String(r.team_name), int(r.get("prev", 0)))
	for r in c.records.get("log", []):
		if str(r.get("year", "")) == season:
			add.call("ncsa", String(r.key), int(r.v), String(r.get("name", "")), _name(c, String(r.get("team", ""))), int(r.get("prev", 0)))
	var mine := String(h.get("team", ""))
	var book: Dictionary = c.records.get("school", {}).get(mine, {}) if mine != "" else {}
	for k in book:
		var m: Dictionary = book[k]
		if str(m.get("year", "")) == season:
			add.call("school", String(k), int(m.get("v", 0)), String(m.get("name", "")), _name(c, mine), 0)
	var out: Array = []
	for lvl in ["ncsa", "school"]:
		for k in Records.KEYS:
			var e: Dictionary = found.get(lvl + "|" + k, {})
			if e.is_empty():
				continue
			# your school's mark that is also the NCSA's (the same value, the same holder): shown once
			if lvl == "school":
				var n: Dictionary = found.get("ncsa|" + k, {})
				if not n.is_empty() and int(n.v) == int(e.v) and String(n.name) == String(e.name):
					continue
			if int(e.prev) >= int(e.v):
				e.prev = 0
			out.append(e)
	return out
