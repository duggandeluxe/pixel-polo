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

## A school's book: the canonical one (RecordBook, identical in every dynasty), copied into this
## career on first use. Only that copy ever changes: breaking a record in one dynasty touches no
## other, and no book is ever generated at load time.
static func school_book(c: Career, team_id: String) -> Dictionary:
	if not c.records.school.has(team_id):
		c.records.school[team_id] = {}
	return _complete(c.records.school[team_id], canon_school(team_id))

static func ncsa_book(c: Career) -> Dictionary:
	return _complete(c.records.ncsa, canon_ncsa())

## The school's canonical book, as a career's marks: {key: {v, name, team, year}}.
static func canon_school(team_id: String) -> Dictionary:
	var book := {}
	var src: Dictionary = RecordBook.SCHOOLS.get(team_id, RecordBook.EXPANSION.get(team_id, {}))
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
static func check(c: Career, key: String, value: int, holder: String, team_id: String) -> Array:
	return breaks(c, key, value, holder, team_id).map(func(e): return String(e.line))

## check(), as records broken: [{level ("ncsa" | "school"), key, name, value, holder, team (its
## name), prev ({v, name, year}: the mark it beat), line (the news)}], the NCSA's first. The books
## are updated and the news made exactly as check() always did (a school record that isn't yours
## is kept in its book, not reported). RecordShow celebrates them.
static func breaks(c: Career, key: String, value: int, holder: String, team_id: String) -> Array:
	var out: Array = []
	if value <= 0:
		return out
	var yr := c.season_label()
	var mine := team_id == c.school
	# a team record's holder is the team itself: it isn't named twice
	var team_name := String(c.teams[team_id].name)
	var nb := ncsa_book(c)
	if value > int(nb[key].v):
		var prev: Dictionary = (nb[key] as Dictionary).duplicate()
		nb[key] = {"v": value, "name": holder, "team": team_id, "year": yr}
		out.append({"level": "ncsa", "key": key, "name": NAMES[key], "value": value, "holder": holder, "team": team_name, "prev": prev,
			"line": "NCSA RECORD! %s: %d, %s" % [NAMES[key], value, holder] + ("" if holder == team_name else " (%s)" % team_name)})
	var sb := school_book(c, team_id)
	if value > int(sb[key].v):
		var prev: Dictionary = (sb[key] as Dictionary).duplicate()
		sb[key] = {"v": value, "name": holder, "team": team_id, "year": yr}
		if mine:
			out.append({"level": "school", "key": key, "name": NAMES[key], "value": value, "holder": holder, "team": team_name, "prev": prev,
				"line": "SCHOOL RECORD! %s: %d" % [NAMES[key], value] + ("" if holder == team_name else ", " + holder)})
	for e in out:
		c.add_news(String(e.line))
	return out

static func holder(p: PoloPlayer) -> String:
	return "%s. %s" % [p.first.substr(0, 1), p.last]

## One game's marks for one side: players' goals and saves, the team's goals and margin.
static func check_game(c: Career, team_id: String, goals: Array, keeper: PoloPlayer, saves: int,
		team_goals: int, against: int) -> Array:
	return game_breaks(c, team_id, goals, keeper, saves, team_goals, against).map(func(e): return String(e.line))

## check_game(), as records broken (breaks()).
static func game_breaks(c: Career, team_id: String, goals: Array, keeper: PoloPlayer, saves: int,
		team_goals: int, against: int) -> Array:
	var out: Array = []
	var counted := {}
	for p in goals:
		counted[p] = int(counted.get(p, 0)) + 1
	for p in counted:
		out.append_array(breaks(c, "game_goals", counted[p], holder(p), team_id))
	if keeper != null:
		out.append_array(breaks(c, "game_saves", saves, holder(keeper), team_id))
	out.append_array(breaks(c, "game_team_goals", team_goals, c.teams[team_id].name, team_id))
	out.append_array(breaks(c, "game_margin", team_goals - against, c.teams[team_id].name, team_id))
	return out

## The season's marks for every team (the off-season calls this before graduation).
static func check_season(c: Career) -> Array:
	var out: Array = []
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		for p in t.roster:
			out.append_array(check(c, "season_goals", p.stat("g"), holder(p), id))
			out.append_array(check(c, "season_assists", p.stat("a"), holder(p), id))
			if p.is_keeper():
				out.append_array(check(c, "season_saves", p.stat("sv"), holder(p), id))
		out.append_array(check(c, "season_wins", int(c.table[id].w) + _playoff_wins(c, id), t.name, id))
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
