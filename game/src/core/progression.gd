class_name Progression
extends RefCounted
## THE ROAD TO GLORY: which schools a new career can start at. It's the player's own profile,
## not a career's (user://progression.json, kept by Game beside the slots), so what's earned
## stays earned in every career from then on, whatever happens to the one that earned it.
##
## The 30 schools are put in five tiers once, by their original overall (Colleges `ovr`, the
## school order breaking ties), and the tiers are saved: a later change to a school's rating
## never moves it. Tier 1 (the bottom five) is open from the start; each other tier opens with
## its own achievement, earned in any order (ACHIEVEMENTS). Nothing is ever locked again.
##
## Achievements are read from a career's own results, never counted up as games go by: a
## season's wins are its played games (the schedule's results), a conference final is a
## `conf_final` game you played, a title is that final (or the `nat_final`) won. Reading the same
## results twice finds the same thing, so a game counted twice can't earn anything twice.

const VERSION := 1
## Schools per tier, weakest first (5 + 7 + 7 + 7 + 4 = 30).
const TIER_SIZES := [5, 7, 7, 7, 4]
const TIER_NAMES := ["", "STARTING PROGRAMS", "RISING PROGRAMS", "ESTABLISHED PROGRAMS", "CONTENDERS", "POWERHOUSES"]
const SEASON_WINS := 5
## tier 2..5: what opens it. `req` is the locked school's panel line, `card` its card's (shorter,
## to fit a phone), `head` the picker's group header ("LOCKED — ..."), `title` the notification's.
const ACHIEVEMENTS := [
	{"id": "five_wins", "tier": 2, "title": "FIVE-WIN SEASON", "req": "WIN 5 GAMES IN ONE SEASON", "card": "WIN 5 GAMES IN ONE SEASON", "head": "WIN 5 GAMES"},
	{"id": "conf_final", "tier": 3, "title": "CONFERENCE FINALIST", "req": "REACH A CONFERENCE CHAMPIONSHIP", "card": "REACH CONF CHAMPIONSHIP", "head": "REACH CONFERENCE CHAMPIONSHIP"},
	{"id": "conf_champ", "tier": 4, "title": "CONFERENCE CHAMPION", "req": "WIN A CONFERENCE CHAMPIONSHIP", "card": "WIN CONF CHAMPIONSHIP", "head": "WIN CONFERENCE CHAMPIONSHIP"},
	{"id": "nat_champ", "tier": 5, "title": "NATIONAL CHAMPION", "req": "WIN A NATIONAL CHAMPIONSHIP", "card": "WIN NATIONAL CHAMPIONSHIP", "head": "WIN NATIONAL CHAMPIONSHIP"},
]

var tiers := {}            # school id -> 1..5
var done: Array = []       # achievement ids earned
var unlocked: Array = []   # school ids open to a new career
var earned: Array = []     # how each was earned: {id, year, team, at}
## the latest season seen (the SEASON WINS line on a locked Tier 2 school): {slot, year, team, wins}
var season := {}
var best_wins := 0         # the most wins seen in one season

# ------------------------------------------------------------------ tiers
## Every school, strongest first: original overall, then the school order.
static func by_rating() -> Array:
	var idx := {}
	for i in Colleges.SCHOOLS.size():
		idx[Colleges.SCHOOLS[i].short] = i
	var out: Array = Colleges.SCHOOLS.duplicate()
	out.sort_custom(func(a, b):
		if int(a.ovr) != int(b.ovr):
			return int(a.ovr) > int(b.ovr)
		return int(idx[a.short]) < int(idx[b.short]))
	return out

## The tiers from the ratings: the bottom five are tier 1 ... the top four tier 5.
static func make_tiers() -> Dictionary:
	var order := by_rating()
	order.reverse()
	var out := {}
	var i := 0
	for t in TIER_SIZES.size():
		for k in int(TIER_SIZES[t]):
			if i < order.size():
				out[order[i].short] = t + 1
				i += 1
	# (more schools than the tiers hold, one day: the extra strongest join the top tier)
	while i < order.size():
		out[order[i].short] = TIER_SIZES.size()
		i += 1
	return out

static func fresh() -> Progression:
	var p := Progression.new()
	p.tiers = make_tiers()
	p._open()
	return p

static func achievement(id: String) -> Dictionary:
	for a in ACHIEVEMENTS:
		if a.id == id:
			return a
	return {}

static func achievement_for_tier(t: int) -> Dictionary:
	for a in ACHIEVEMENTS:
		if int(a.tier) == t:
			return a
	return {}

func tier_of(id: String) -> int:
	return int(tiers.get(id, 0))

## Can a new career start at `id`: earned on the Road to Glory (`unlocked`), or every school
## with ALL 30 TEAMS bought (Store.all_teams: the store's entitlement, kept apart from this
## profile, so it never counts as an achievement and buying it earns none).
func is_unlocked(id: String) -> bool:
	var d := Colleges.division_of(id)
	if d != Colleges.D1:
		return Store.division_owned(d)   # (an expansion school: its pack opens it, not the Road)
	return id in unlocked or Store.all_teams

func schools_in_tier(t: int) -> Array:
	return tiers.keys().filter(func(id): return int(tiers[id]) == t)

## The picker's list, in groups: every open school together first, whatever its tier, then each
## tier that still has locked schools, in tier order (an earned tier is gone from the locked
## groups even when an earlier one isn't). Strongest first within each group: by `teams`' actual
## overall (the dynasty setup's generated rosters, PoloTeam.team_overall) when given, then the
## base program rating and school order (by_rating), so equal teams never swap between visits.
## The tiers themselves never move with the rosters. [{tier: 0 for the open group, title, ids}]
func picker_groups(teams: Dictionary = {}) -> Array:
	var order: Array = by_rating().map(func(s): return String(s.short))
	if not teams.is_empty():
		var base := {}
		for i in order.size():
			base[order[i]] = i
		var actual := {}
		for id in order:
			actual[id] = (teams[id] as PoloTeam).team_overall(false) if teams.has(id) else -1.0
		order.sort_custom(func(a, b):
			if not is_equal_approx(float(actual[a]), float(actual[b])):
				return float(actual[a]) > float(actual[b])
			return int(base[a]) < int(base[b]))
	var out: Array = [{"tier": 0, "title": "AVAILABLE TEAMS", "ids": order.filter(func(id): return is_unlocked(id))}]
	for t in range(2, TIER_SIZES.size() + 1):
		var ids: Array = order.filter(func(id): return tier_of(id) == t and not is_unlocked(id))
		if not ids.is_empty():
			out.append({"tier": t, "title": "LOCKED — " + String(achievement_for_tier(t).head), "ids": ids})
	return out

## The achievement a locked school waits on ({} when it's open).
func requirement(id: String) -> Dictionary:
	if is_unlocked(id):
		return {}
	var d := Colleges.division_of(id)
	if d != Colleges.D1:
		var pack := "%s EXPANSION PACK" % Colleges.division_name(d)
		return {"id": "pack", "req": pack, "card": pack, "head": pack, "title": pack, "tier": 0}
	return achievement_for_tier(tier_of(id))

## Adds every school of tier 1 and of each earned achievement's tier. Never takes one away.
func _open() -> void:
	var open_tiers := [1]
	for id in done:
		open_tiers.append(int(achievement(String(id)).get("tier", 0)))
	for sid in tiers:
		if int(tiers[sid]) in open_tiers and not sid in unlocked:
			unlocked.append(sid)

# ------------------------------------------------------------------ earning
## Marks achievements earned (ids not yet done) and opens their schools. Returns the new ones,
## each {id, title, count}: count = schools it opened.
func award(ids: Array, year: String = "", team: String = "") -> Array:
	var out: Array = []
	for id in ids:
		var a := achievement(String(id))
		if a.is_empty() or id in done:
			continue
		var before := unlocked.size()
		done.append(String(id))
		earned.append({"id": String(id), "year": year, "team": team, "at": int(Time.get_unix_time_from_system())})
		_open()
		out.append({"id": String(id), "title": String(a.title), "count": unlocked.size() - before})
	return out

## What a season's results show `school` did, in tier order (four ids at most): `rounds` is a
## career's schedule (Career.schedule, or a save's). Only games with a result count.
static func season_feats(school: String, rounds: Array) -> Array:
	var out: Array = []
	if season_wins(school, rounds) >= SEASON_WINS:
		out.append("five_wins")
	for r in rounds:
		var kind := String(r.get("kind", ""))
		if kind != "conf_final" and kind != "nat_final":
			continue
		for g in r.get("games", []):
			if g.get("r") == null or (g.h != school and g.a != school):
				continue
			var won := Schedule.winner(g) == school
			if kind == "conf_final":
				out.append("conf_final")
				if won:
					out.append("conf_champ")
			elif won:
				out.append("nat_champ")
	return out

## `school`'s games won in a season: every played game in it (regular season and playoffs).
static func season_wins(school: String, rounds: Array) -> int:
	var n := 0
	for r in rounds:
		for g in r.get("games", []):
			if g.get("r") != null and (g.h == school or g.a == school) and Schedule.winner(g) == school:
				n += 1
	return n

## After one of your games: the season's results read again, anything new earned. `slot` is the
## career's save slot (for the season line). Returns the new achievements (see award).
func note(c: Career, slot: int = 0) -> Array:
	var w := season_wins(c.school, c.schedule)
	season = {"slot": slot, "year": c.season_label(), "team": c.school, "wins": w}
	best_wins = maxi(best_wins, w)
	return award(season_feats(c.school, c.schedule), c.season_label(), c.school)

## A career's past seasons, read for what they prove (a save from before the Road to Glory, or a
## career loaded on another profile): a season ended with 5+ wins, the coach's titles (the
## "<season> <conference>" a conference final won adds, the "<season> NCSA" a national title
## adds; a conference title means its final was played). Takes the plain save fields, so it works
## on a career or an unread save. Returns the new achievements.
func reconstruct(titles: Array, history: Array, year: String = "", team: String = "") -> Array:
	var ids: Array = []
	for h in history:
		if h is Dictionary and int(h.get("w", 0)) >= SEASON_WINS:
			ids.append("five_wins")
			best_wins = maxi(best_wins, int(h.get("w", 0)))
	for t in titles:
		var s := String(t)
		if s.ends_with(" NCSA"):
			ids.append("nat_champ")
		elif s.strip_edges() != "":
			ids.append("conf_final")
			ids.append("conf_champ")
	return award(ids, year, team)

## Everything a loaded career proves: its past seasons and this one so far.
func reconstruct_career(c: Career, slot: int = 0) -> Array:
	var out := reconstruct(c.coach.get("titles", []), c.history, c.season_label(), c.school)
	out.append_array(note(c, slot))
	return out

## The same, from a save file not loaded (`d`: Career.to_dict's), when a new profile is made.
## `latest`: the slot played last, whose season becomes the season line.
func reconstruct_save(d: Dictionary, slot: int = 0, latest: bool = false) -> Array:
	var school := String(d.get("school", ""))
	var coach: Dictionary = d.get("coach", {}) if d.get("coach") is Dictionary else {}
	var history: Array = d.get("history", []) if d.get("history") is Array else []
	var rounds: Array = d.get("schedule", []) if d.get("schedule") is Array else []
	var label := "%d-%02d" % [int(d.get("year", Career.START_YEAR)), (int(d.get("year", Career.START_YEAR)) + 1) % 100]
	var out := reconstruct(coach.get("titles", []), history, label, school)
	var w := season_wins(school, rounds)
	best_wins = maxi(best_wins, w)
	if latest:
		season = {"slot": slot, "year": label, "team": school, "wins": w}
	out.append_array(award(season_feats(school, rounds), label, school))
	return out

## This season's wins for the locked Tier 2 line: the career open now, or else the season last
## seen in a save that's still there. -1 when there's none (no line is shown then).
func season_wins_now(c: Career, slot_alive: Callable) -> int:
	if c != null:
		return season_wins(c.school, c.schedule)
	if season.is_empty() or not bool(slot_alive.call(int(season.get("slot", 0)))):
		return -1
	return int(season.get("wins", 0))

# ------------------------------------------------------------------ saving
func to_dict() -> Dictionary:
	return {"version": VERSION, "tiers": tiers, "done": done, "unlocked": unlocked, "earned": earned,
		"season": season, "best_wins": best_wins}

## A saved profile. Its tiers stay as they were saved; a school it doesn't know (one added in a
## later update) gets the tier the ratings give it now. Unknown achievements and schools no
## longer in the game are dropped from what's shown, never from what's earned.
static func from_dict(d: Dictionary) -> Progression:
	var p := Progression.new()
	var now := make_tiers()
	var saved: Dictionary = d.get("tiers", {}) if d.get("tiers") is Dictionary else {}
	for sid in now:
		p.tiers[sid] = clampi(int(saved.get(sid, now[sid])), 1, TIER_SIZES.size())
	for id in d.get("done", []):
		if not achievement(String(id)).is_empty() and not String(id) in p.done:
			p.done.append(String(id))
	for sid in d.get("unlocked", []):
		if p.tiers.has(String(sid)) and not String(sid) in p.unlocked:
			p.unlocked.append(String(sid))
	p.earned = d.get("earned", []) if d.get("earned") is Array else []
	p.season = d.get("season", {}) if d.get("season") is Dictionary else {}
	p.best_wins = int(d.get("best_wins", 0))
	p._open()
	return p
