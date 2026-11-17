class_name Records
## School and NCSA records: one game, one season, a college career. A record is
## {v, name, team, year}. Every school's book starts from the canonical one (RecordBook: fixed
## data, the same marks and fictional alumni in every dynasty), so there's always something to chase. Breaking one makes the news (no credits:
## CreditRewards is the only way a career earns them).

const KEYS := ["game_goals", "game_saves", "game_team_goals", "game_margin",
	"season_goals", "season_assists", "season_saves", "season_wins", "career_goals", "career_saves",
	"career_assists", "career_steals", "career_blocks"]
const NAMES := {
	"game_goals": "Goals in a game", "game_saves": "Saves in a game",
	"game_team_goals": "Team goals in a game", "game_margin": "Biggest win",
	"season_goals": "Goals in a season", "season_assists": "Assists in a season",
	"season_saves": "Saves in a season", "season_wins": "Wins in a season",
	"career_goals": "Goals, college career", "career_saves": "Saves, college career",
	"career_assists": "Assists, college career", "career_steals": "Steals, college career", "career_blocks": "Blocks, college career",
}
## What can't stand as a record's holder: a mark with one of these for a name is filled from the
## canonical book.
const NO_NAME := ["", "null", "unknown player", "n/a", "tbd", "none"]
## The team marks: the school book names their coach ("coach", a last name: wins in a season) or
## their game ("opp", the opponent's id: team goals, biggest win), not a player.
const TEAM_KEYS := ["season_wins", "game_team_goals", "game_margin"]

## A school's book: the canonical one (RecordBook, identical in every dynasty), copied into this
## career on first use. Only that copy ever changes: breaking a record in one dynasty touches no
## other, and no book is ever generated at load time.
static func school_book(c: Career, team_id: String) -> Dictionary:
	if not c.records.school.has(team_id):
		c.records.school[team_id] = {}
	return _fill_team_holders(c, team_id, _complete(c.records.school[team_id], canon_school(team_id)))

## Gives each team mark in `book` its coach or opponent, once: the one it was set with when
## known, otherwise one chosen (seeded by the school, the mark and its year, so the same on every
## look) and kept in the book from then on. A mark that already has one is never touched.
static func _fill_team_holders(c: Career, team_id: String, book: Dictionary) -> Dictionary:
	var sw: Dictionary = book.get("season_wins", {})
	if not sw.is_empty() and String(sw.get("coach", "")).strip_edges() == "":
		sw["coach"] = _coach_for(c, team_id, sw)
	for k in ["game_team_goals", "game_margin"]:
		var m: Dictionary = book.get(k, {})
		if not m.is_empty() and String(m.get("opp", "")) == "":
			m["opp"] = _opp_for(c, team_id, k, m)
	return book

static func _seed(team_id: String, key: String, m: Dictionary) -> int:
	return posmod(("%s|%s|%s" % [team_id, key, str(m.get("year", ""))]).hash(), 2147483647)

## The coach of the season that set `m`: yours if it's one of your seasons there (Career.history),
## otherwise a former coach's last name.
static func _coach_for(c: Career, team_id: String, m: Dictionary) -> String:
	for h in c.history:
		if String(h.team) == team_id and String(h.year) == str(m.get("year", "")) and String(c.coach.get("last", "")) != "":
			return String(c.coach.last)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed(team_id, "season_wins", m)
	return String(CollegeGen.coach_name(rng)[1])

## The opponent `m` was set against: this season's game that made it when it's still in the
## schedule, otherwise a school from the league (its conference first).
static func _opp_for(c: Career, team_id: String, key: String, m: Dictionary) -> String:
	var w := int(m.get("w", -1))
	if str(m.get("year", "")) == c.season_label() and w >= 0 and w < c.schedule.size():
		for g in (c.schedule[w] as Dictionary).get("games", []):
			if g.r == null or not team_id in [String(g.h), String(g.a)]:
				continue
			var home := String(g.h) == team_id
			var us := int(g.r.s[0 if home else 1])
			var them := int(g.r.s[1 if home else 0])
			if (us if key == "game_team_goals" else us - them) == int(m.v):
				return String(g.a if home else g.h)
	var ids: Array = c.teams.keys().filter(func(id): return String(id) != team_id)
	if ids.is_empty():
		ids = Colleges.SCHOOLS.map(func(s): return String(s.short)).filter(func(id): return id != team_id)
	var conf := String(c.teams[team_id].conf) if c.teams.has(team_id) else String(Colleges.school(team_id).get("conf", ""))
	var same := ids.filter(func(id): return c.teams.has(id) and String(c.teams[id].conf) == conf)
	if not same.is_empty():
		ids = same
	ids.sort()
	return String(ids[_seed(team_id, key, m) % ids.size()])

## A team's whole name ("Cambridge Redhawks") and its mascot ("Redhawks"), as this dynasty has them.
static func full_name(c: Career, id: String) -> String:
	return String(c.teams[id].name) if c.teams.has(id) else Colleges.team_name(id)

static func mascot(c: Career, id: String) -> String:
	var m := String(c.teams[id].mascot) if c.teams.has(id) else ""
	if m == "":
		m = String(Colleges.school(id).get("mascot", ""))
	return m if m != "" else full_name(c, id)

## The school book's HOLDER for record `r` (key `k`): "COACH RINALDI" for wins in a season,
## "2023 HAMMERHEADS VS. CAMBRIDGE REDHAWKS" for team goals and the biggest win, else its player.
static func holder_text(c: Career, k: String, r: Dictionary) -> String:
	match k:
		"season_wins":
			return "COACH " + String(r.get("coach", "")).to_upper()
		"game_team_goals", "game_margin":
			return "%s %s VS. %s" % [str(r.year), mascot(c, String(r.team)).to_upper(), full_name(c, String(r.get("opp", ""))).to_upper()]
	return String(r.name)

static func ncsa_book(c: Career) -> Dictionary:
	return _complete(c.records.ncsa, canon_ncsa())

## Every NCSA record broken in this dynasty, oldest first, kept for good (records.log, saved with
## the books): [{key, v, name, team, year (the season), when ("WEEK 3", "QUARTERFINALS", "END OF
## SEASON"), opp (a team mark's opponent, if known)}]. The canon's pre-dynasty marks are never in
## it. An older save starts it from the dynasty marks still standing in its NCSA book.
static func ncsa_log(c: Career) -> Array:
	if not c.records.has("log"):
		var old: Array = []
		for k in KEYS:
			var m: Dictionary = c.records.ncsa.get(k, {})
			if str(m.get("year", "")).length() > 4 and int(m.get("v", 0)) > 0:
				var e := {"key": k, "v": int(m.v), "name": String(m.get("name", "")), "team": String(m.get("team", "")), "year": str(m.year),
					"when": _when_label(c, k, int(m.get("w", -1)), str(m.year)), "w": int(m.get("w", 99))}
				if m.has("opp"):
					e["opp"] = String(m.opp)
				old.append(e)
		old.sort_custom(func(a, b): return [a.year, a.w] < [b.year, b.w])
		for e in old:
			e.erase("w")
		c.records["log"] = old
	return c.records.log

## When a mark was set: a game's week (the playoffs by their round), a season's or a career's
## at the season's end.
static func _when_label(c: Career, key: String, w: int, year: String) -> String:
	if not key.begins_with("game_") or w < 0:
		return "END OF SEASON"
	if year == c.season_label() and w < c.schedule.size():
		return ConfAwards.week_label(c, w)
	return "WEEK %d" % (w + 1)

## The school's canonical book, as a career's marks: {key: {v, name, team, year}}.
static func canon_school(team_id: String) -> Dictionary:
	var book := {}
	var src: Dictionary = RecordBook.SCHOOLS.get(team_id, {})
	for k in KEYS:
		if src.has(k):
			book[k] = {"v": int(src[k][0]), "name": String(src[k][1]), "team": team_id, "year": int(src[k][2])}
		else:
			# (not one of the thirty: an old test team. Its team id alone says who: never random)
			var m: Array = RecordBook.NCSA[k]
			book[k] = {"v": maxi(1, roundi(float(m[0]) * 0.8)), "name": String(m[1]), "team": team_id, "year": int(m[3])}
	return book

static func canon_ncsa() -> Dictionary:
	var book := {}
	for k in KEYS:
		var m: Array = RecordBook.NCSA[k]
		book[k] = {"v": int(m[0]), "name": String(m[1]), "team": String(m[2]), "year": int(m[3])}
	return book

## Fills what `book` lacks from `canon`, and nothing else: a record missing (or never set, v 0)
## becomes the canonical one; a real value with no holder keeps its value and gets the canonical
## holder; a mark someone in this dynasty set is never touched. So it can run on any save, any
## number of times.
static func _complete(book: Dictionary, canon: Dictionary) -> Dictionary:
	for k in KEYS:
		var m: Dictionary = book.get(k, {})
		if int(m.get("v", 0)) <= 0:
			book[k] = (canon[k] as Dictionary).duplicate()
		elif String(m.get("name", "")).strip_edges().to_lower() in NO_NAME:
			m["name"] = canon[k].name
			m["year"] = canon[k].year if str(m.get("year", "")) == "" else m.year
			if String(m.get("team", "")) == "":
				m["team"] = canon[k].team
	return book

## An older save: every book it has, completed (the ones it hasn't come from the canon when asked).
static func complete_all(c: Career) -> void:
	for id in c.records.school:
		_complete(c.records.school[id], canon_school(id))
	if not c.records.ncsa.is_empty():
		_complete(c.records.ncsa, canon_ncsa())

## Checks one mark against the team's school book and the NCSA book. Returns the news lines.
static func check(c: Career, key: String, value: int, holder: String, team_id: String, extra: Dictionary = {}) -> Array:
	return breaks(c, key, value, holder, team_id, extra).map(func(e): return String(e.line))

## check(), as records broken: [{level ("ncsa" | "school"), key, name, value, holder, team (its
## name), prev ({v, name, year}: the mark it beat), line (the news)}], the NCSA's first. The books
## are updated and the news made exactly as check() always did (a school record that isn't yours
## is kept in its book, not reported). RecordShow celebrates them. `extra` goes into the new marks too (a team mark's "coach" or "opp").
static func breaks(c: Career, key: String, value: int, holder: String, team_id: String, extra: Dictionary = {}) -> Array:
	var out: Array = []
	if value <= 0:
		return out
	var yr := c.season_label()
	var mine := team_id == c.school
	# a team record's holder is the team itself: it isn't named twice
	var team_name := String(c.teams[team_id].name)
	var nb := ncsa_book(c)
	var log := ncsa_log(c)
	if value > int(nb[key].v):
		var prev: Dictionary = (nb[key] as Dictionary).duplicate()
		nb[key] = {"v": value, "name": holder, "team": team_id, "year": yr}
		(nb[key] as Dictionary).merge(extra, true)
		var e := {"key": key, "v": value, "name": holder, "team": team_id, "year": yr,
			"when": _when_label(c, key, c.week if key.begins_with("game_") else -1, yr)}
		e.merge(extra, true)
		e["prev"] = int(prev.get("v", 0))   # (the mark it beat: the season review shows it)
		log.append(e)
		if key.begins_with("game_"):
			nb[key]["w"] = c.week   # (a game's record: the week it was set, for LEAGUE NEWS's LEAGUE RECORDS)
		out.append({"level": "ncsa", "key": key, "name": NAMES[key], "value": value, "holder": holder, "team": team_name, "prev": prev,
			"line": "NCSA RECORD! %s: %d, %s" % [NAMES[key], value, holder] + ("" if holder == team_name else " (%s)" % team_name)})
	var sb := school_book(c, team_id)
	if value > int(sb[key].v):
		var prev: Dictionary = (sb[key] as Dictionary).duplicate()
		sb[key] = {"v": value, "name": holder, "team": team_id, "year": yr}
		(sb[key] as Dictionary).merge(extra, true)
		if key.begins_with("game_"):
			sb[key]["w"] = c.week
		if mine:
			out.append({"level": "school", "key": key, "name": NAMES[key], "value": value, "holder": holder, "team": team_name, "prev": prev,
				"line": "SCHOOL RECORD! %s: %d" % [NAMES[key], value] + ("" if holder == team_name else ", " + holder)})
	# your program's news: only the records your own team set (every school's NCSA marks are in
	# the book, and LEAGUE NEWS's LEAGUE RECORDS shows them)
	if mine:
		for e in out:
			c.add_news(String(e.line))
	return out

static func holder(p: PoloPlayer) -> String:
	return "%s. %s" % [p.first.substr(0, 1), p.last]

## One game's marks for one side: players' goals and saves, the team's goals and margin.
static func check_game(c: Career, team_id: String, goals: Array, keeper: PoloPlayer, saves: int,
		team_goals: int, against: int, opp_id: String = "") -> Array:
	return game_breaks(c, team_id, goals, keeper, saves, team_goals, against, opp_id).map(func(e): return String(e.line))

## check_game(), as records broken (breaks()). `opp_id`: who it was against (the team marks keep it).
static func game_breaks(c: Career, team_id: String, goals: Array, keeper: PoloPlayer, saves: int,
		team_goals: int, against: int, opp_id: String = "") -> Array:
	var out: Array = []
	var counted := {}
	for p in goals:
		counted[p] = int(counted.get(p, 0)) + 1
	for p in counted:
		out.append_array(breaks(c, "game_goals", counted[p], holder(p), team_id))
	if keeper != null:
		out.append_array(breaks(c, "game_saves", saves, holder(keeper), team_id))
	var vs := {"opp": opp_id} if opp_id != "" else {}
	out.append_array(breaks(c, "game_team_goals", team_goals, c.teams[team_id].name, team_id, vs))
	out.append_array(breaks(c, "game_margin", team_goals - against, c.teams[team_id].name, team_id, vs))
	return out

## The season's marks for every team (the off-season calls this before graduation).
static func check_season(c: Career) -> Array:
	return season_breaks(c).map(func(e): return String(e.line))

## check_season(), as records broken (breaks(): each with its line and the mark it beat). The
## books are updated exactly as check_season() always did; this is the one that does it.
static func season_breaks(c: Career) -> Array:
	var out: Array = []
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		for p in t.roster:
			out.append_array(breaks(c, "season_goals", p.stat("g"), holder(p), id))
			out.append_array(breaks(c, "season_assists", p.stat("a"), holder(p), id))
			if p.is_keeper():
				out.append_array(breaks(c, "season_saves", p.stat("sv"), holder(p), id))
		# (your season's coach is you; another school's gets one when its book is read)
		var by := {"coach": String(c.coach.last)} if id == c.school and String(c.coach.get("last", "")) != "" else {}
		out.append_array(breaks(c, "season_wins", int(c.table[id].w) + _playoff_wins(c, id), t.name, id, by))
	return out

## Graduating seniors' college totals.
static func check_career(c: Career, p: PoloPlayer, team_id: String) -> Array:
	var out: Array = []
	out.append_array(check(c, "career_goals", int(p.totals.get("g", 0)), holder(p), team_id))
	out.append_array(check(c, "career_assists", int(p.totals.get("a", 0)), holder(p), team_id))
	out.append_array(check(c, "career_steals", int(p.totals.get("st", 0)), holder(p), team_id))
	out.append_array(check(c, "career_blocks", int(p.totals.get("bl", 0)), holder(p), team_id))
	if p.is_keeper():
		out.append_array(check(c, "career_saves", int(p.totals.get("sv", 0)), holder(p), team_id))
	return out

static func _playoff_wins(c: Career, id: String) -> int:
	var n := 0
	for r in c.schedule:
		if Schedule.is_playoff(r):
			for g in r.games:
				if Schedule.winner(g) == id:
					n += 1
	return n
