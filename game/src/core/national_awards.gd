class_name NationalAwards
## THE NCSA'S ANNUAL HONOURS (the National Awards & Trophy Room update), once a season, after the
## NCSA final (Offseason.begin -> Awards.run), from every player of all 30 schools and the whole
## season he played: regular season, conference tournament and NCSA, played or simulated (his
## season stats, PoloPlayer.stats: every game added once as it was recorded).
##   poy    NCSA PLAYER OF THE YEAR      the best season of all (overall_values: a field player's
##                                       season (season_value, ConfAwards' POTW score) against the
##                                       field's, a keeper's defending against the keepers', both in
##                                       spreads of their own group, a keeper's less POY_GK_HANDICAP:
##                                       a keeper only for a historic season)
##   dpoy   NCSA DEFENSIVE PLAYER OF THE YEAR   def_value: each man's defending against his own
##                                       kind's (keepers: saves beyond the league's save rate, goals
##                                       against, steals; field: steals and blocks), in spreads of
##                                       that group, a keeper's counted GK_PREF more: keepers most
##                                       years, an extraordinary field defender now and then
##   foy    NCSA FRESHMAN OF THE YEAR    the best freshman season (overall_values, FOY_GK_HANDICAP)
##   arm    NCSA GOLDEN ARM AWARD        the most goals, all season (ties: co-winners)
##   wall   NCSA IRON WALL AWARD         the most saves by a keeper, all season (ties: co-winners)
##   first / second   ALL-NCSA FIRST and SECOND TEAM   seven each (C, 2MD, two ATK, two WG, GK by the
##                                       lineup's own rules: PoloTeam.fits, a lefty only on the
##                                       right), the best seasons first; nobody on both
## POY, DPOY and FOY are three different men (POY first; DPOY and FOY then shared so both are
## given whenever they can be); Golden Arm, Iron Wall and the All-NCSA teams may overlap them.
## Each honour is its own record in Career.awards: {year (the season, "2026-27"), award, name, team
## (the school he won it for), pid, pos, conf (his school's conference then), line (the season that
## won it), slot (All-NCSA: "C"...)}. Never worked out again: Career.national_done holds the seasons.

const MAJOR := ["poy", "dpoy", "foy"]
const TITLES := {"poy": "NCSA Player of the Year", "dpoy": "NCSA Defensive Player of the Year",
	"foy": "NCSA Freshman of the Year", "arm": "NCSA Golden Arm Award", "wall": "NCSA Iron Wall Award",
	"first": "All-NCSA First Team", "second": "All-NCSA Second Team"}
const KEYS := ["poy", "dpoy", "foy", "arm", "wall", "first", "second"]
## A season's value: half its totals, half its per-game rate scaled to a full season (over at least
## MIN_GAMES, so one big game off the bench isn't a season).
const MIN_GAMES := 6.0
## DPOY: a keeper's defending counts this many of his group's spreads more than a field player's.
const GK_PREF := 2.5
## POY / FOY: a keeper's defending counts this many spreads less than a field player's season.
const POY_GK_HANDICAP := 0.6   # (12 simulated seasons: the best keeper 0.5-1.3 spreads behind the best field season)
const FOY_GK_HANDICAP := 1.0
## The All-NCSA lineup, by PoloTeam.SLOTS place (0 GK, 1 C, 2 WG/LFTY, 3 ATK/LFTY, 4 2MD, 5 ATK, 6 WG).
const TEAM_PLACES := [0, 1, 4, 3, 5, 2, 6]
const PLACE_NAMES := {0: "GK", 1: "C", 2: "WG", 3: "ATK", 4: "2MD", 5: "ATK", 6: "WG"}

## "2026-27" -> 2027: the year an award is earned in (a season's finishing year).
static func earned_year(season: String) -> int:
	var parts := season.split("-")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		return int(parts[0]) + 1
	return int(season) if season.is_valid_int() else 0

## The season's honours (once): records into Career.awards, lines for the season review.
static func run(c: Career) -> Array:
	var season := c.season_label()
	if season in c.national_done:
		return []
	c.national_done.append(season)
	var everyone: Array = []   # {p, team}
	for id in c.teams:
		for p: PoloPlayer in (c.teams[id] as PoloTeam).roster:
			if p.stat("gp") > 0:
				everyone.append({"p": p, "team": String(id)})
	if everyone.is_empty():
		return []
	var games := _median_games(everyone)
	var lines: Array = []
	var give := func(key: String, e: Dictionary, extra: Dictionary = {}) -> void:
		var rec := _record(c, key, e, extra)
		c.awards.append(rec)
		if String(e.team) == c.school:
			c.add_news("%s: %s" % [String(TITLES[key]).to_upper(), rec.name])
	# the three majors, three different men
	var overall := overall_values(everyone, games, POY_GK_HANDICAP)
	var poy = _top(everyone, func(e): return float(overall[(e.p as PoloPlayer).id]))
	var picked := {}
	if poy != null:
		give.call("poy", poy)
		picked[(poy.p as PoloPlayer).id] = true
		lines.append("%s: %s (%s)" % [TITLES.poy, _name(poy.p), _team_name(c, poy.team)])
	var rest := everyone.filter(func(e): return not picked.has((e.p as PoloPlayer).id))
	var def_scores := def_values(rest)
	var dpoy_list := _ranked(rest, func(e): return float(def_scores[(e.p as PoloPlayer).id]))
	var fresh := overall_values(everyone, games, FOY_GK_HANDICAP)
	var foy_list := _ranked(rest.filter(func(e): return WalkOns.is_rookie(e.p as PoloPlayer)), func(e): return float(fresh[(e.p as PoloPlayer).id]))
	var dpoy = dpoy_list[0] if not dpoy_list.is_empty() else null
	var foy = foy_list[0] if not foy_list.is_empty() else null
	if dpoy != null and foy != null and dpoy.p == foy.p:
		# the same man best at both: whichever leaves the other its next-best
		var alt_d = dpoy_list[1] if dpoy_list.size() > 1 else null
		var alt_f = foy_list[1] if foy_list.size() > 1 else null
		if alt_f != null:
			foy = alt_f
		elif alt_d != null:
			dpoy = alt_d
		else:
			foy = null
	if dpoy != null:
		give.call("dpoy", dpoy)
		lines.append("%s: %s (%s)" % [TITLES.dpoy, _name(dpoy.p), _team_name(c, dpoy.team)])
	if foy != null:
		give.call("foy", foy)
		lines.append("%s: %s (%s)" % [TITLES.foy, _name(foy.p), _team_name(c, foy.team)])
	# the statistical titles: the totals, ties shared
	for key in ["arm", "wall"]:
		var stat := "g" if key == "arm" else "sv"
		var pool: Array = everyone if key == "arm" else everyone.filter(func(e): return (e.p as PoloPlayer).is_keeper())
		var most := 0
		for e in pool:
			most = maxi(most, (e.p as PoloPlayer).stat(stat))
		if most <= 0:
			continue
		var winners := pool.filter(func(e): return (e.p as PoloPlayer).stat(stat) == most)
		for e in winners:
			give.call(key, e, {"co": winners.size() > 1})
		lines.append("%s: %s, %d %s" % [TITLES[key], ", ".join(winners.map(func(e): return _name(e.p))), most, "goals" if key == "arm" else "saves"])
	# the All-NCSA teams
	var taken := {}
	for key in ["first", "second"]:
		var team: Dictionary = pick_team(everyone.filter(func(e): return not taken.has((e.p as PoloPlayer).id)), games, def_values(everyone))
		for place in team:
			var e: Dictionary = team[place]
			taken[(e.p as PoloPlayer).id] = true
			give.call(key, e, {"slot": PLACE_NAMES[place]})
		lines.append("%s: %s" % [TITLES[key], ", ".join(TEAM_PLACES.filter(func(pl): return team.has(pl)).map(func(pl): return "%s %s" % [PLACE_NAMES[pl], (team[pl].p as PoloPlayer).short_name()]))])
	return lines

# ------------------------------------------------------------------ the values
## A season's line as ConfAwards scores a week: his stats with games played set to one (the raw
## total), then half the total, half the per-game rate times a full season.
static func season_value(p: PoloPlayer, cat: String, games: float) -> float:
	var ln: Dictionary = p.stats.duplicate()
	var gp := float(p.stat("gp"))
	ln["gp"] = 1
	var total := ConfAwards.score(p, ln, cat)
	return 0.5 * total + 0.5 * total / maxf(gp, MIN_GAMES) * games

## Everyone's overall season on one scale ({pid: value}): a field player's season_value against
## the field's regulars, a keeper's defending against the keepers' (def_values without the DPOY
## preference), each in spreads of its own group, a keeper's less `gk_handicap`.
static func overall_values(entries: Array, games: float, gk_handicap: float) -> Dictionary:
	var defs := def_values(entries)
	var field := entries.filter(func(e): return not (e.p as PoloPlayer).is_keeper())
	var raw := {}
	for e in field:
		raw[(e.p as PoloPlayer).id] = season_value(e.p, "potw", games)
	var out := _spreads(field, raw)
	for e in entries:
		var p: PoloPlayer = e.p
		if p.is_keeper():
			out[p.id] = float(defs[p.id]) - GK_PREF - gk_handicap
	return out

## `raw` ({pid: value}) as spreads from the mean of `group`'s regulars (MIN_GAMES or more).
static func _spreads(group: Array, raw: Dictionary) -> Dictionary:
	var regular: Array = group.filter(func(e): return (e.p as PoloPlayer).stat("gp") >= MIN_GAMES)
	if regular.is_empty():
		regular = group
	var mean := 0.0
	for e in regular:
		mean += float(raw[(e.p as PoloPlayer).id]) / regular.size()
	var spread := 0.0
	for e in regular:
		spread += pow(float(raw[(e.p as PoloPlayer).id]) - mean, 2.0) / regular.size()
	spread = maxf(sqrt(spread), 0.001)
	var out := {}
	for e in group:
		out[(e.p as PoloPlayer).id] = (float(raw[(e.p as PoloPlayer).id]) - mean) / spread
	return out

## Every player's DPOY value ({pid: value}): his defending against his own kind's, in spreads.
static func def_values(entries: Array) -> Dictionary:
	var keepers := entries.filter(func(e): return (e.p as PoloPlayer).is_keeper())
	var field := entries.filter(func(e): return not (e.p as PoloPlayer).is_keeper())
	var sv := 0
	var faced := 0
	for e in keepers:
		sv += (e.p as PoloPlayer).stat("sv")
		faced += (e.p as PoloPlayer).stat("sv") + (e.p as PoloPlayer).stat("ga")
	var par := float(sv) / maxf(1.0, faced)   # (the league's save rate this season)
	var raw := {}
	for e in keepers:
		var p: PoloPlayer = e.p
		raw[p.id] = _blend(float(p.stat("sv")) - par * float(p.stat("sv") + p.stat("ga")) + 2.0 * p.stat("st"), p)
	for e in field:
		var p: PoloPlayer = e.p
		raw[p.id] = _blend(float(p.stat("st")) + float(p.stat("bl")) - 0.5 * p.stat("pf5"), p)
	var out := _spreads(keepers, raw)
	out.merge(_spreads(field, raw))
	for e in keepers:
		out[(e.p as PoloPlayer).id] += GK_PREF
	return out

## Half a season's total, half its per-game rate over a full season (at least MIN_GAMES).
static func _blend(total: float, p: PoloPlayer) -> float:
	return 0.5 * total + 0.5 * total / maxf(float(p.stat("gp")), MIN_GAMES) * 20.0

## The All-NCSA lineup from `entries`: {place: entry}. The best seasons first (field: POY's value,
## keepers: their defending), each to his own place if it's open, else a place he may legally play.
static func pick_team(entries: Array, games: float, defs: Dictionary) -> Dictionary:
	var value := func(e: Dictionary) -> float:
		var p: PoloPlayer = e.p
		return float(defs.get(p.id, 0.0)) if p.is_keeper() else season_value(p, "potw", games)
	var order := _ranked(entries, value)
	var team := {}
	for rank in [0, 1]:
		for e in order:
			if team.size() == TEAM_PLACES.size():
				break
			var p: PoloPlayer = e.p
			if team.values().any(func(x): return x.p == p):
				continue
			for place in TEAM_PLACES:
				if not team.has(place) and PoloTeam.fit_rank(p, place) == rank:
					team[place] = e
					break
	return team

# ------------------------------------------------------------------ helpers
static func _ranked(entries: Array, value: Callable) -> Array:
	var scored: Array = entries.map(func(e): return [float(value.call(e)), -(e.p as PoloPlayer).id, e])
	scored.sort_custom(func(a, b): return a[0] > b[0] if a[0] != b[0] else a[1] > b[1])
	return scored.map(func(x): return x[2])

static func _top(entries: Array, value: Callable):
	var r := _ranked(entries, value)
	return r[0] if not r.is_empty() else null

static func _median_games(entries: Array) -> float:
	var gs: Array = entries.map(func(e): return (e.p as PoloPlayer).stat("gp"))
	gs.sort()
	return float(maxi(1, gs[gs.size() / 2]))

static func _name(p: PoloPlayer) -> String:
	return "%s %s" % [p.first, p.last]

static func _team_name(c: Career, id: String) -> String:
	return String(c.teams[id].name) if c.teams.has(id) else Colleges.team_name(id)

static func _record(c: Career, key: String, e: Dictionary, extra: Dictionary) -> Dictionary:
	var p: PoloPlayer = e.p
	var line := {}
	for k in ["gp", "g", "a", "st", "bl", "sv", "ga", "ed", "pd"]:
		if p.stat(k) != 0:
			line[k] = p.stat(k)
	c.award_players[str(p.id)] = JSON.stringify(p.to_dict())   # (his profile as he was, for when he's gone)
	var rec := {"year": c.season_label(), "award": key, "name": _name(p), "team": String(e.team), "pid": p.id,
		"pos": p.pos, "conf": String((c.teams[e.team] as PoloTeam).conf) if c.teams.has(e.team) else "", "line": line}
	rec.merge(extra)
	return rec

## The supporting line of an award record, in words: "91 GOALS", "205 SAVES", or the season.
static func line_text(rec: Dictionary) -> String:
	var ln: Dictionary = rec.get("line", {})
	if ln.is_empty():
		return ""   # (a pre-dynasty award, Legacy: no stats claimed)
	match String(rec.get("award", "")):
		"arm":
			return "%d GOALS" % int(ln.get("g", 0))
		"wall":
			return "%d SAVES" % int(ln.get("sv", 0))
	var parts := PackedStringArray(["%d GP" % int(ln.get("gp", 0))])
	if int(rec.get("pos", -1)) == PoloPlayer.Pos.GK:
		var faced := int(ln.get("sv", 0)) + int(ln.get("ga", 0))
		parts.append("%d SAVES" % int(ln.get("sv", 0)))
		if faced > 0:
			parts.append("%d%% SAVED" % roundi(100.0 * int(ln.get("sv", 0)) / faced))
	else:
		for k in [["g", "G"], ["a", "A"], ["st", "ST"], ["bl", "BL"]]:
			parts.append("%d %s" % [int(ln.get(k[0], 0)), k[1]])
	return " | ".join(parts)
