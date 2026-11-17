class_name Legacy
## THE GENERATED PLAYER LEGACY (the Generated Player Legacy & Historical Awards update): a new
## dynasty's world already has a past. Once, when a career begins (Career.begin), the three
## seasons before it are written into the same records real seasons fill, marked "hist":
##   Career.conf_awards     weekly awards (POTW, OPOTW, DPOTW keepers only, ROTW freshmen only),
##                          by conference and week, one a player a week, never shared
##   Career.tourney_awards  each conference tournament's and the NCSA tournament's Player,
##                          Offensive and Defensive Player of the Tournament
##   Career.awards          the NCSA's own: POY, DPOY, FOY (three different men), the Golden Arm
##                          (the goals leader) and the Iron Wall (the saves leader: ties shared),
##                          the All-NCSA First and Second Teams (the lineup's places, nobody twice)
##   Career.legacy          each past season's champions: every conference tournament's and the
##                          NCSA's (team history: the Record Book)
## So a player's Career Accolades and Trophy Room show them like any other (Honours), each under
## the conference he won it in, the year he earned it, his permanent id.
##
## How it's believable rather than handed out:
##   - only the seasons a player was in college: a senior three, a junior two, a sophomore one,
##     a freshman none; his class that season is his class now less the seasons since
##   - his level that season is today's worked back (his growth since, a little each year, at
##     its own pace) plus that season's form: today's best were usually good, not always
##   - each season's league includes the players since graduated (alumni made up for it,
##     ALUMNI_A_TEAM a school, as good as their programs), so plenty of the past's trophies
##     belong to men no longer on a roster
##   - every award picked league-wide, by conference and by week, as the real ones are
## The Golden Arm's and Iron Wall's totals are each eligible man's made-up season total, the winner
## the most (so the record it shows is consistent); nothing else claims a stat. Nothing here
## touches a rating, XP, potential, form or a current-season stat. Its own dice (seeded from the
## dynasty's seed), so the rest of the career is made exactly as it was without it.

const SEASONS := 3
const ALUMNI_A_TEAM := 8          # graduated men a school, spread over the three seasons
const GROWTH := Vector2(0.15, 0.55)   # OVERALL points a player grew each college year
const FORM_SD := 0.45             # a season's form, give or take
const WEEK_SD := 2.0              # a week's form (weekly awards: anybody's week)
const REPEAT := 0.6               # each weekly award he's won this season counts this much against him (the honours go round)
const SKILL_LEAN := 0.6           # how much his attack / defence attributes pull his season's off / def from his overall
const KEEPER_POTW := 0.9          # a keeper's week counts this much less for POTW (as the real one: rare)
const POY_KEEPER := 1.4           # ...and his season this much less for POY (extraordinary only)
const DPOY_KEEPER := 1.6          # a keeper's defending this much more for DPOY (favoured)
const NAT_TEAMS := 8

## Writes the past seasons (once: a career that has them, or has played, is left alone).
static func generate(c: Career) -> void:
	if not c.legacy.is_empty() or c.conf_awards.any(func(a): return bool(a.get("hist", false))):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([c.rng.seed, "legacy"])
	var men := _men(c, rng)
	var weeks := maxi(1, c.schedule.filter(func(r): return not Schedule.is_playoff(r)).size())
	for k in range(SEASONS, 0, -1):
		var season := "%d-%02d" % [c.year - k, (c.year - k + 1) % 100]
		var on: Array = men.filter(func(m): return _class_then(m, k) >= 1 and _class_then(m, k) <= 4)
		for m in on:
			_season_form(m, k, rng)
		_weekly(c, on, season, k, weeks, rng)
		var champs := _tournaments(c, on, season, k, rng)
		_national(c, on, season, k, rng)
		c.legacy.append({"season": season, "conf": champs.conf, "nat": champs.nat})
	# every current player with a past award: his profile kept, so his records still open him
	# after he's gone (as a real award keeps one: ConfAwards.player_of)
	var won := {}
	for a in c.conf_awards + c.tourney_awards + c.awards:
		if bool(a.get("hist", false)) and int(a.pid) >= 0:
			won[int(a.pid)] = true
	for m in men:
		var p: PoloPlayer = m.p
		if won.has(p.id) and not c.award_players.has(str(p.id)):
			c.award_players[str(p.id)] = JSON.stringify(p.to_dict())

# ------------------------------------------------------------------ the men
## Everyone who played in those seasons: today's players and the alumni. Each {p (a PoloPlayer:
## today's, or an alumnus made here), team, conf, cls (class now; an alumnus: 4 + seasons since
## he left), grow, now (his OVERALL now / at graduation)}.
static func _men(c: Career, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var ids: Array = c.teams.keys()
	ids.sort()
	var n := 0
	for id in ids:
		var t: PoloTeam = c.teams[id]
		var level := 0.0
		for p in t.roster:
			out.append({"p": p, "team": id, "conf": t.conf, "cls": p.year, "grow": rng.randf_range(GROWTH.x, GROWTH.y), "now": p.rating10()})
			level += p.rating10() / maxf(1.0, t.roster.size())
		for i in ALUMNI_A_TEAM:
			var like: PoloPlayer = t.roster[rng.randi() % t.roster.size()]
			var a := PoloPlayer.new()
			var nm := CollegeGen.random_name(rng)
			a.first = String(nm[0])
			a.last = String(nm[1])
			a.pos = like.pos
			a.lefty = like.lefty
			n += 1
			a.id = -1000 - n   # (no roster's: an alumnus' records name him, nobody else)
			var gone := 1 + i % SEASONS        # graduated this many seasons ago
			a.year = 4
			out.append({"p": a, "team": id, "conf": t.conf, "cls": 4 + gone, "grow": rng.randf_range(GROWTH.x, GROWTH.y),
				"now": clampf(level + rng.randfn(0.0, 0.8), 1.0, 10.0), "alumnus": true})
	return out

## His class k seasons ago (0 or less: not in college yet).
static func _class_then(m: Dictionary, k: int) -> int:
	return int(m.cls) - k

## His level k seasons ago, and that season's form: his season's overall, attack and defence.
static func _season_form(m: Dictionary, k: int, rng: RandomNumberGenerator) -> void:
	var p: PoloPlayer = m.p
	var since := float(k) if not m.has("alumnus") else maxf(0.0, float(k) - (int(m.cls) - 4))
	var base := float(m.now) - since * float(m.grow)
	var form := rng.randfn(0.0, FORM_SD)
	var off := base
	var dfn := base
	if not m.has("alumnus") and p.attrs.has("sho"):
		off = base + SKILL_LEAN * ((Attributes.value(p, "sho") + Attributes.value(p, "pas")) * 0.5 - p.rating10())
		dfn = base + SKILL_LEAN * (Attributes.value(p, "dfn") - p.rating10())
	m["perf"] = base + form
	m["off"] = off + form
	m["def"] = dfn + form

static func _who(m: Dictionary, season: String, k: int) -> Dictionary:
	var p: PoloPlayer = m.p
	return {"pid": p.id, "name": "%s %s" % [p.first, p.last], "team": String(m.team), "pos": p.pos, "cls": _class_then(m, k), "hist": true}

# ------------------------------------------------------------------ weekly
## Each conference's four weekly awards, every week: POTW, then OPOTW (a field player's attack),
## DPOTW (a keeper), ROTW (a freshman), four different men (ConfAwards' rules).
static func _weekly(c: Career, on: Array, season: String, k: int, weeks: int, rng: RandomNumberGenerator) -> void:
	var confs := {}
	for m in on:
		if not confs.has(m.conf):
			confs[m.conf] = []
		(confs[m.conf] as Array).append(m)
	var cs: Array = confs.keys()
	cs.sort()
	for conf in cs:
		var pool: Array = confs[conf]
		var wins := {}   # this season's weekly awards a man
		for w in weeks:
			var wk := {}
			for m in pool:
				wk[m] = rng.randfn(0.0, WEEK_SD)
			var taken := {}
			var pick := func(cat: String, ok: Callable, value: Callable) -> void:
				var best = null
				var bv := -INF
				for m in pool:
					if taken.has(m) or not ok.call(m):
						continue
					var v: float = value.call(m) + float(wk[m]) - REPEAT * int(wins.get(m, 0))
					if v > bv:
						bv = v
						best = m
				if best == null:
					return
				taken[best] = true
				wins[best] = int(wins.get(best, 0)) + 1
				var rec := _who(best, season, k)
				rec.merge({"year": c.year - k, "season": season, "week": w, "label": "WEEK %d" % (w + 1), "conf": conf, "cat": cat,
					"stars": 0.0, "line": {}, "score": 0.0})
				c.conf_awards.append(rec)
			pick.call("potw", func(m): return true, func(m): return float(m.perf) - (KEEPER_POTW if (m.p as PoloPlayer).is_keeper() else 0.0))
			pick.call("opotw", func(m): return not (m.p as PoloPlayer).is_keeper(), func(m): return float(m.off))
			pick.call("dpotw", func(m): return (m.p as PoloPlayer).is_keeper(), func(m): return float(m.def))
			pick.call("rotw", func(m): return _class_then(m, k) == 1, func(m): return float(m.perf))

# ------------------------------------------------------------------ the tournaments
## Each conference's champion (its teams that season, by their men's level and a tournament's
## luck), the NCSA's from the conference champions and the best others; each tournament's three
## awards from its finalists. Returns {conf: {conf: team}, nat: team}.
static func _tournaments(c: Career, on: Array, season: String, k: int, rng: RandomNumberGenerator) -> Dictionary:
	var by_team := {}
	for m in on:
		if not by_team.has(m.team):
			by_team[m.team] = []
		(by_team[m.team] as Array).append(m)
	var strength := {}
	for id in by_team:
		var ms: Array = (by_team[id] as Array).duplicate()
		ms.sort_custom(func(a, b): return float(a.perf) > float(b.perf))
		var s := 0.0
		for m in ms.slice(0, 7):
			s += float(m.perf) / 7.0
		strength[id] = s
	var conf_champs := {}
	var finals := {}
	var confs := {}
	for id in by_team:
		var cf := String((c.teams[id] as PoloTeam).conf)
		if not confs.has(cf):
			confs[cf] = []
		(confs[cf] as Array).append(id)
	var cs: Array = confs.keys()
	cs.sort()
	for cf in cs:
		if (confs[cf] as Array).size() < 2:
			continue   # (a one-school conference has no tournament)
		var ranked := _ranked_teams(confs[cf], strength, rng)
		conf_champs[cf] = ranked[0]
		finals[cf] = ranked.slice(0, 2)
		_tourney_awards(c, by_team, ranked.slice(0, 2), "conf:" + cf, cf, season, k)
	# the NCSA's field: the conference champions, then the strongest of the rest
	var field: Array = conf_champs.values()
	var rest: Array = by_team.keys().filter(func(id): return not id in field)
	rest.sort_custom(func(a, b): return float(strength[a]) > float(strength[b]))
	field.append_array(rest.slice(0, NAT_TEAMS - field.size()))
	var nat := _ranked_teams(field, strength, rng)
	_tourney_awards(c, by_team, nat.slice(0, 2), "nat", "", season, k)
	return {"conf": conf_champs, "nat": nat[0]}

static func _ranked_teams(ids: Array, strength: Dictionary, rng: RandomNumberGenerator) -> Array:
	var luck := {}
	for id in ids:
		luck[id] = float(strength[id]) + rng.randfn(0.0, 0.35)
	var out := ids.duplicate()
	out.sort_custom(func(a, b): return float(luck[a]) > float(luck[b]))
	return out

## A tournament's Player (the champion's best), Offensive (the finalists' best attacker) and
## Defensive (the finalists' best defender, keepers favoured) of the Tournament: three men.
static func _tourney_awards(c: Career, by_team: Dictionary, finalists: Array, tid: String, conf: String, season: String, k: int) -> void:
	var champ: Array = by_team[finalists[0]]
	var both: Array = []
	for id in finalists:
		both.append_array(by_team[id])
	var taken := {}
	var give := func(cat: String, pool: Array, value: Callable) -> void:
		var best = null
		for m in pool:
			if not taken.has(m) and (best == null or float(value.call(m)) > float(value.call(best))):
				best = m
		if best == null:
			return
		taken[best] = true
		var rec := _who(best, season, k)
		rec.merge({"year": c.year - k, "season": season, "tid": tid, "conf": conf if conf != "" else String(best.conf), "cat": cat,
			"stars": 0.0, "line": {}, "score": 0.0})
		c.tourney_awards.append(rec)
	give.call("pot", champ, func(m): return float(m.perf))
	give.call("opot", both.filter(func(m): return not (m.p as PoloPlayer).is_keeper()), func(m): return float(m.off))
	give.call("dpot", both, func(m): return float(m.def) + (DPOY_KEEPER if (m.p as PoloPlayer).is_keeper() else 0.0))

# ------------------------------------------------------------------ the NCSA's awards
static func _national(c: Career, on: Array, season: String, k: int, rng: RandomNumberGenerator) -> void:
	var gk := func(m): return (m.p as PoloPlayer).is_keeper()
	var give := func(key: String, m: Dictionary, extra: Dictionary) -> void:
		var rec := _who(m, season, k)
		rec.merge({"year": season, "award": key, "conf": String(m.conf), "line": {}})
		rec.merge(extra, true)
		c.awards.append(rec)
	var best := func(pool: Array, value: Callable):
		var b = null
		for m in pool:
			if b == null or float(value.call(m)) > float(value.call(b)):
				b = m
		return b
	# POY, DPOY, FOY: three different men
	var poy = best.call(on, func(m): return float(m.perf) - (POY_KEEPER if gk.call(m) else 0.0))
	give.call("poy", poy, {})
	var rest: Array = on.filter(func(m): return m != poy)
	var dpoy = best.call(rest, func(m): return float(m.def) + (DPOY_KEEPER if gk.call(m) else 0.0))
	give.call("dpoy", dpoy, {})
	var fresh: Array = rest.filter(func(m): return m != dpoy and _class_then(m, k) == 1)
	if not fresh.is_empty():
		give.call("foy", best.call(fresh, func(m): return float(m.perf)), {})
	# the Golden Arm and the Iron Wall: every eligible man's season total, the most wins (ties share)
	for key in ["arm", "wall"]:
		var pool: Array = on.filter(func(m): return gk.call(m) == (key == "wall"))
		var totals := {}
		var most := 0
		for m in pool:
			var v := 0
			if key == "arm":
				v = maxi(0, roundi(28.0 + (float(m.off) - 5.0) * 10.0 + rng.randfn(0.0, 7.0)))
			else:
				v = maxi(0, roundi(150.0 + (float(m.def) - 5.0) * 14.0 + rng.randfn(0.0, 14.0)))
			totals[m] = v
			most = maxi(most, v)
		var winners: Array = pool.filter(func(m): return int(totals[m]) == most)
		for m in winners:
			give.call(key, m, {"line": {"g": most} if key == "arm" else {"sv": most}, "co": winners.size() > 1})
	# the All-NCSA teams: the lineup's places (PoloTeam.fits), the season's best first, nobody twice
	var used := {}
	for key in ["first", "second"]:
		var order: Array = on.filter(func(m): return not used.has(m))
		order.sort_custom(func(a, b): return float(a.perf) > float(b.perf))
		for place in NationalAwards.TEAM_PLACES:
			for m in order:
				if used.has(m) or not PoloTeam.fits(m.p, int(place)):
					continue
				used[m] = true
				give.call(key, m, {"slot": String(NationalAwards.PLACE_NAMES[place])})
				break

## The seasons this career's history covers (Record Book: marked BEFORE THE DYNASTY).
static func is_history(c: Career, season: String) -> bool:
	return c.legacy.any(func(e): return String(e.season) == season)
