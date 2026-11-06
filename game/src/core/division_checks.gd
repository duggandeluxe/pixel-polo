class_name DivisionChecks
## The Division II & III expansion's checks, for Developer Mode's DIVISION EXPANSION TESTING screen
## (division_lab) and `--test divisions`. Sandboxed: every career here is a throwaway
## (Career.sandbox) that's never saved, and the Store is only ever read, so no purchase, coin or
## Road to Glory record can move.

const GROUPS := {"TEAMS": "SCHOOL DATABASE", "ROSTERS": "ROSTERS", "SCHEDULE": "SCHEDULES", "POSTSEASON": "POSTSEASON", "SAVES": "SAVES"}
## The four test configurations: [name, divisions, schools].
const CONFIGS := [["DIV I ONLY", [1], 30], ["DIV I + II", [1, 2], 37], ["DIV I + III", [1, 3], 47], ["ALL DIVISIONS", [1, 2, 3], 54]]

static var _out: Array = []

static func _ok(cond: bool, text: String) -> void:
	_out.append({"ok": cond, "text": text})

## Group `g`'s checks: [{ok, text}].
static func run(g: String) -> Array:
	_out = []
	match g:
		"TEAMS":
			_teams()
		"ROSTERS":
			_rosters()
			_recruiting()
		"SCHEDULE":
			_schedules()
		"POSTSEASON":
			_postseason()
		"SAVES":
			_saves()
	return _out

## A throwaway career with `divs` on.
static func sandbox(school: String, divs: Array, seed_value: int) -> Career:
	var c := Career.new_setup(seed_value, divs)
	c.sandbox = true
	c.begin(school, "Dev", "Test", divs)
	c.queue = []
	return c

## Plays the rest of `c`'s season, every game simmed, up to "done".
static func sim_season(c: Career) -> void:
	for _i in 60:
		if c.phase != "season":
			return
		while c.has_game():
			c.sim_my_game()
		c.end_week()

## On to the next season: every upgrade spent, every cut made.
static func next_season(c: Career) -> void:
	for p: PoloPlayer in c.team().roster:
		Development.ai_spend(p)
	c.end_week()
	while c.phase == "cuts":
		var fit: Array = c.team().roster.filter(func(p): return Offseason.cut_block(c, p) == "")
		if fit.is_empty():
			break
		Offseason.cut(c, fit[0])
		if Offseason.roster_legal(c):
			Offseason.finish_cuts(c)

# ------------------------------------------------------------------ the database
static func _teams() -> void:
	var all := Colleges.all_schools()
	var ids := {}
	for s in all:
		ids[String(s.short)] = true
	_ok(all.size() == 54 and ids.size() == 54, "54 school definitions, every id unique")
	_ok(Colleges.schools_of(1).size() == 30 and Colleges.schools_of(2).size() == 7 and Colleges.schools_of(3).size() == 17, "30 Division I, 7 Division II, 17 Division III")
	for n in [["WWPA", 7], ["SCIAC", 9], ["MPSFE", 7], ["NEWPC", 1]]:
		_ok(Colleges.schools_in(n[0]).size() == n[1], "%s has %d school%s" % [Colleges.conf_abbr(n[0]), n[1], "" if n[1] == 1 else "s"])
	_ok(Colleges.CONFERENCES.size() == 5 and Colleges.conf_abbr("NWPC") == "NCC" and Colleges.conf_abbr("MPSF") == "PEC", "the five Division I conferences are untouched")
	_ok(Colleges.conf_abbr("NEWPC") == "NWPC" and Colleges.conf_abbr("MPSFE") == "MPSF EAST", "the real NWPC and MPSF East keep their own ids")
	_ok(all.all(func(s): return String(s.get("venue", "")) != "" and String(s.get("city", "")).contains(", ")), "every school has a home pool and a city")
	_ok(Colleges.EXPANSION_SCHOOLS.all(func(s): return String(s.get("real", "")) != ""), "every expansion school records its real inspiration")
	var names := {}
	for s in all:
		names[String(s.name)] = true
	_ok(names.size() == 54, "no two schools share a name (Erie, Claremont, Los Angeles)")
	var logos := Colleges.EXPANSION_SCHOOLS.filter(func(s): return TeamLogo.art(s, Vector2i(60, 60)) == null or TeamLogo.art(s, Vector2i(20, 12)) == null or TeamLogo.art(s, Vector2i(20, 12), true) == null)
	_ok(logos.is_empty(), "all 24 logos load at every size%s" % ("" if logos.is_empty() else ": missing " + String(logos[0].name)))
	_ok(Colleges.EXPANSION_SCHOOLS.all(func(s): return RecordBook.EXPANSION.has(String(s.short))), "every expansion school has a fixed record book")

# ------------------------------------------------------------------ rosters
static func _rosters() -> void:
	var c := Career.new_setup(31, [1, 2, 3])
	var bad: Array = []
	var off_target: Array = []
	var seen := {}
	var dupes := 0
	for s in Colleges.EXPANSION_SCHOOLS:
		var t: PoloTeam = c.teams[s.short]
		if t.roster.size() != Career.ROSTER_MAX + Career.BENCH_MAX or t.starters().size() != 7 or t.keeper() == null:
			bad.append(s.name)
		if t.base_ovr() != int(s.ovr):
			off_target.append("%s %d" % [s.name, t.base_ovr()])
		for p: PoloPlayer in t.roster:
			if seen.has(p.id):
				dupes += 1
			seen[p.id] = true
			var clean: bool = p.key_ratings().all(func(k): return p.attr(k) >= 0.0 and p.attr(k) <= Attributes.MAX)
			if not clean or p.home == "" or p.first == "" or p.pot_stars < p.stars - 0.01 or p.year < 1 or p.year > 4:
				bad.append("%s: %s" % [s.name, p.short_name()])
	_ok(bad.is_empty(), "every school: ten valid players, a keeper, names, classes, hometowns, attributes%s" % ("" if bad.is_empty() else " (" + String(bad[0]) + ")"))
	_ok(off_target.is_empty(), "every team's OVR, from its players, is its target%s" % ("" if off_target.is_empty() else " (" + String(off_target[0]) + ")"))
	_ok(dupes == 0, "no player id is used twice")
	var a := Career.new_setup(32)
	var b := Career.new_setup(32, [1, 2, 3])
	var same: bool = a.teams.keys().all(func(id): return JSON.stringify(a.teams[id].to_dict()) == JSON.stringify(b.teams[id].to_dict()))
	_ok(same, "the thirty's players are the same with the expansion on or off")
	_ok(a.rng.state == b.rng.state, "...and so are the career's dice")
	var e := Career.new_setup(33, [1, 2, 3])
	var f := Career.new_setup(33, [1, 2, 3])
	_ok(JSON.stringify(e.teams.D3_04.to_dict()) == JSON.stringify(f.teams.D3_04.to_dict()), "the same seed makes the same expansion players")

## One off-season with everyone in: the expansion's programs recruit and grow like the thirty, and
## each program's own freshman class means the supply grows with the schools, rarity unchanged.
static func _recruiting() -> void:
	var share := {}
	for cfg in [[1], [1, 2, 3]]:
		var c := sandbox("CULA", cfg, 34)
		var before := {}
		var ids := {}
		for id in c.teams:
			before[id] = (c.teams[id] as PoloTeam).base_ovr()
			ids[id] = (c.teams[id] as PoloTeam).roster.map(func(p): return p.id)
		sim_season(c)
		next_season(c)
		var fresh := 0
		var elite := 0
		var moved := 0
		var legal := true
		var replaced := true
		for id in c.teams:
			var t: PoloTeam = c.teams[id]
			legal = legal and t.roster.size() >= Career.ROSTER_MAX and t.roster.size() <= Career.ROSTER_MAX + Career.BENCH_MAX and t.keeper() != null
			moved += 1 if t.base_ovr() != int(before[id]) else 0
			var news: Array = t.roster.filter(func(p): return not p.id in ids[id])
			replaced = replaced and (id == c.school or not news.is_empty())
			fresh += news.size()
			elite += news.filter(func(p): return p.pot_stars >= 4.75).size()
		share[cfg.size()] = float(elite) / maxf(1.0, fresh)
		if cfg.size() == 3:
			_ok(legal, "after an off-season every program of the 54 has a legal roster")
			_ok(replaced, "every CPU program replaced its graduates")
			_ok(moved > 27, "team strength moves with the players (%d of 54 changed)" % moved)
			_ok(fresh > 54, "the supply grows with the schools: %d newcomers" % fresh)
	_ok(float(share[3]) <= float(share[1]) + 0.05, "no flood of five-star prospects: %.1f%% of newcomers with 30 schools, %.1f%% with 54" % [float(share[1]) * 100.0, float(share[3]) * 100.0])

# ------------------------------------------------------------------ schedules
static func schedule_problems(c: Career) -> Array:
	var out: Array = []
	var busy := {}
	var count := {}
	var homes := {}
	for w in c.schedule.size():
		var r: Dictionary = c.schedule[w]
		if Schedule.is_playoff(r):
			continue
		for g in r.games:
			for id in [String(g.h), String(g.a)]:
				var slot := "%s|%d|%d" % [id, w, int(g.d)]
				if busy.has(slot):
					out.append("double-booked: " + slot)
				busy[slot] = true
				count[id] = int(count.get(id, 0)) + 1
			homes[g.h] = int(homes.get(g.h, 0)) + 1
	for id in c.teams:
		if int(count.get(id, 0)) != Schedule.REGULAR_GAMES:
			out.append("%s plays %d" % [id, int(count.get(id, 0))])
		if absi(int(homes.get(id, 0)) - Schedule.REGULAR_GAMES / 2) > 3:
			out.append("%s has %d home games" % [id, int(homes.get(id, 0))])
	return out

static func cross_division_games(c: Career) -> int:
	var n := 0
	for r in c.schedule:
		if Schedule.is_playoff(r):
			continue
		for g in r.games:
			if Colleges.division_of(String(g.h)) != Colleges.division_of(String(g.a)):
				n += 1
	return n

static func _schedules() -> void:
	for cfg in CONFIGS:
		var bad: Array = []
		var cross := 0
		for sd in 3:
			var c := sandbox("CULA", cfg[1], 40 + sd)
			if c.teams.size() != int(cfg[2]):
				bad.append("%d teams" % c.teams.size())
			bad.append_array(schedule_problems(c))
			cross += cross_division_games(c)
		_ok(bad.is_empty(), "%s: %d schools, 16 games each, nobody double-booked%s" % [cfg[0], cfg[2], "" if bad.is_empty() else " (" + String(bad[0]) + ")"])
		if int(cfg[2]) > 30:
			_ok(cross > 0, "%s: cross-division games on the schedule (%d a season)" % [cfg[0], cross / 3])

# ------------------------------------------------------------------ the postseason
## Everything one finished season must be (the checks read it, whatever its results were).
static func season_problems(c: Career) -> Array:
	var out: Array = []
	var s: Dictionary = c.season
	var field: Array = s.get("nat_seeds", [])
	if field.size() != Schedule.NCSA_FIELD:
		out.append("the NCSA field is %d" % field.size())
	var unique := {}
	for id in field:
		unique[id] = true
	if unique.size() != field.size():
		out.append("a team twice in the NCSA field")
	if field.any(func(id): return Colleges.division_of(String(id)) == Colleges.D3):
		out.append("a Division III team in the NCSA")
	var d2: Array = field.filter(func(id): return Colleges.division_of(String(id)) == Colleges.D2)
	if c.divisions.has(Colleges.D2):
		if d2.size() != 1 or String(d2[0]) != String(s.get("d2_champ", "")):
			out.append("Division II's NCSA place: %s" % str(d2))
	elif not d2.is_empty():
		out.append("Division II in a dynasty without it")
	if c.divisions.has(Colleges.D3):
		var four: Array = s.get("d3_seeds", [])
		var distinct := {}
		for id in four:
			distinct[id] = true
		if four.size() != Schedule.D3_FIELD or distinct.size() != four.size():
			out.append("the Division III field: %s" % str(four))
		for cf in ["SCIAC", "MPSFE"]:
			var champ: Array = (s.conf_champs as Array).filter(func(id): return String((c.teams[id] as PoloTeam).conf) == cf)
			if champ.size() != 1 or not champ[0] in four:
				out.append("%s's champion isn't in the field" % cf)
		if Schedule.d3_game(c.schedule, "d3_final").get("r") == null:
			out.append("no Division III final")
		if Schedule.d3_game(c.schedule, "d3_third").get("r") == null:
			out.append("no third-place game")
	elif s.has("d3_seeds"):
		out.append("a Division III field in a dynasty without it")
	for r in c.schedule:
		var day := {}
		for g in r.games:
			for id in [String(g.h), String(g.a)]:
				var slot := "%s|%d" % [id, int(g.d)]
				if Schedule.is_playoff(r) and day.has(slot):
					out.append("%s twice in the %s" % [id, r.kind])
				day[slot] = true
	return out

static func _postseason() -> void:
	var c := sandbox("D2_02", [1, 2, 3], 50)
	sim_season(c)
	var seeds: Dictionary = c.season.conf_seeds
	var qf: Dictionary = {}
	for r in c.schedule:
		if String(r.kind) == "conf_qf":
			qf = r
	var in_wwpa: Array = (qf.games as Array).filter(func(g): return String(c.teams[g.h].conf) == "WWPA")
	var top := String(seeds.WWPA[0])
	_ok((seeds.WWPA as Array).size() == 7 and in_wwpa.size() == 3 and not in_wwpa.any(func(g): return g.h == top or g.a == top), "WWPA: seven teams, seed 1 has the bye")
	_ok((seeds.SCIAC as Array).size() == 8 and not seeds.has("NEWPC"), "SCIAC: top eight; the NWPC has no tournament")
	_ok((seeds.MPSFE as Array).size() == 7, "MPSF East: all seven")
	var problems := season_problems(c)
	_ok(problems.is_empty(), "a whole season: 12 in the NCSA, one from Division II, none from III, 4 in Division III%s" % ("" if problems.is_empty() else " (" + String(problems[0]) + ")"))
	var log: Dictionary = c.champions_log[c.champions_log.size() - 1]
	var keys: Array = (log.finals as Array).map(func(f): return String(f.key))
	_ok(keys.has("nat") and keys.has("d2") and keys.has("d3") and keys.has("conf:WWPA") and keys.has("conf:SCIAC") and keys.has("conf:MPSFE"), "all six championship histories kept")
	_ok((log.finals as Array).all(func(f): return String(f.champion) != "" and String(f.runner_up) != "" and String(f.score) != "" and String(f.tournament) != ""), "each with its champion, runner-up, score and name")
	var honours := TeamHonours.of(c, String(log.d3))
	_ok(honours.any(func(e): return String(e.cat) == "d3_champ"), "the Division III champion's trophy")
	_ok(TeamHonours.of(c, String(log.d2)).any(func(e): return String(e.cat) == "d2_champ"), "the Division II champion's trophy")
	_ok(not TeamHonours.of(c, String(log.nat)).any(func(e): return String(e.cat) == "d3_champ" and String(e.season) == String(log.season) and String(log.d3) != String(log.nat)), "no trophy that wasn't won")
	# the rules on any poll: a top Division III team, a Division II champion out of the Top 20
	var teams := c.teams
	var ranks: Array = teams.keys()
	ranks.sort_custom(func(a, b): return (0 if Colleges.division_of(a) == 3 else 1) < (0 if Colleges.division_of(b) == 3 else 1))
	var champs: Array = ["D2_07", "CULA", "CSFU", "SMCC", "HURST", "IONA", "D3_01", "D3_16"]
	var autos := Schedule.nat_autos(teams, champs)
	var eligible: Array = ranks.filter(func(id): return Colleges.division_of(id) == 1 or id in autos)
	var field := Schedule.select_field(eligible, autos, Schedule.NCSA_FIELD)
	_ok(field.size() == 12 and "D2_07" in field and not field.any(func(id): return Colleges.division_of(id) == 3), "Division III ranked first: still not in the NCSA; the WWPA champion in, wherever it's ranked")
	var d3 := Schedule.d3_field(teams, ranks, champs)
	_ok(d3.size() == 4 and "D3_01" in d3 and "D3_16" in d3, "the two Division III champions get in, whatever their rank")
	var cam: Array = ["D3_17"] + ranks.filter(func(id): return id != "D3_17")
	_ok("D3_17" in Schedule.d3_field(teams, cam, ["D3_01", "D3_16"]), "Cambridge can qualify at-large")

# ------------------------------------------------------------------ saves
static func reload(c: Career) -> Career:
	var d = JSON.parse_string(JSON.stringify(c.to_dict()))
	var out := Career.from_dict(d)
	out.sandbox = true
	return out

static func _saves() -> void:
	var c := sandbox("GWU", [1], 60)
	_ok(c.teams.size() == 30, "a Division I dynasty: 30 schools")
	var d = JSON.parse_string(JSON.stringify(c.to_dict()))
	d.erase("divisions")
	d.erase("div_pending")
	d.erase("div_answers")
	d.v = 9
	var old := Career.from_dict(d)
	_ok(old.divisions == [Colleges.D1] and old.teams.size() == 30, "a save from before the update loads as Division I, nothing added")
	var owned := func(_d): return true
	_ok(c.division_invites(owned) == [2, 3], "owning both packs invites both")
	c.answer_division(2, true)
	c.answer_division(3, false)
	_ok(c.division_invites(owned).is_empty(), "each invitation is only asked once")
	_ok(c.teams.size() == 30 and reload(c).teams.size() == 30, "ADD NEXT SEASON adds nobody this season")
	sim_season(c)
	var history := JSON.stringify(c.champions_log)
	c = reload(c)
	_ok(c.div_pending == [2] and c.div_answers.get("3") == "no", "the decision survives a reload")
	next_season(c)
	_ok(c.teams.size() == 37 and c.divisions == [1, 2], "Division II joined at the season boundary: 37 schools")
	_ok(JSON.stringify(c.champions_log) == history, "championship history untouched")
	_ok(schedule_problems(c).is_empty(), "the new season's schedule fits all 37")
	_ok(c.table.size() == 37, "...and so does the table")
	var ids := JSON.stringify(c.teams.D2_02.to_dict())
	c = reload(c)
	c = reload(c)
	_ok(c.teams.size() == 37 and JSON.stringify(c.teams.D2_02.to_dict()) == ids, "loading twice recreates nobody")
	c.add_division(Colleges.D2)
	_ok(c.teams.size() == 37, "activating again adds nobody")
	c.queue_division(Colleges.D3)
	sim_season(c)
	next_season(c)
	_ok(c.teams.size() == 54 and c.divisions == [1, 2, 3], "Division III joined next: 54 schools")
	_ok(schedule_problems(c).is_empty(), "the 54-school schedule is valid")
	var pids := {}
	var twice := 0
	for id in c.teams:
		for p: PoloPlayer in (c.teams[id] as PoloTeam).roster:
			twice += 1 if pids.has(p.id) else 0
			pids[p.id] = true
	_ok(twice == 0, "no player on two rosters")
	_ok(c.cr_claims.filter(func(x): return String(x) == "%d:start" % c.year).size() == 1, "one season bonus this season: a new division pays no coins")
	var a := sandbox("CULA", [1, 3], 61)
	var b := sandbox("CULA", [1, 2], 62)
	_ok(a.teams.size() == 47 and b.teams.size() == 37 and reload(a).teams.size() == 47 and reload(b).teams.size() == 37, "saves with different packs stay as they are")
