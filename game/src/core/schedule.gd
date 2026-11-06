class_name Schedule
## The season's rounds, one a week.
##   10 regular-season weeks: every team plays 16 games, up to 3 a week (Friday, Saturday,
##   Sunday). Conference play is a round robin (twice round in a conference that says so, see
##   Colleges.conf_rr); the rest are non-conference games, coast to coast.
##   Then the conference tournaments (every team, byes for the top seeds when a conference
##   is smaller than 8: quarterfinal, semifinal, final) and the 12-team NCSA Championship
##   (seeds 1-4 sit out the first round): the five tournament champions, and seven at-large
##   teams straight down the SELECTION poll (Poll), seeded by that poll.
## Players see a team's regular-season games numbered GAME 1-16 (game_no); the weeks are the
## calendar underneath.
## Every game is at the home team's pool, except the NCSA semifinals and final: a neutral site
## ("nu"), where nobody gets the home pool's edge (GameSim).
## A round is {kind, name, games: [{h, a, r, d, c}]}; r is null until played:
##   {s: [home goals, away goals], so: [] or [home, away] shootout, w: 0 home / 1 away}.
##   d is the game day in the week (0 Fri, 1 Sat, 2 Sun), c marks a conference game. Saves
##   from before kept one game a week, with kind "nonconf" / "conf" telling them apart.
## Playoff rounds start empty and are drawn when the round before them is done; `drawn` marks
## a drawn round (a round can be drawn and still have no game for some conference).

const REGULAR_WEEKS := 10
const REGULAR_GAMES := 16
const DAYS := 3
const NCSA_FIELD := 12
const PLAYOFF_KINDS := ["conf_qf", "conf_semi", "conf_final", "nat_r1", "nat_qf", "nat_sf", "nat_final"]
const ROUND_NAMES := {
	"reg": "REGULAR SEASON",
	"nonconf": "FALL INVITATIONAL",
	"conf": "CONFERENCE PLAY",
	"conf_qf": "CONFERENCE QUARTERFINAL",
	"conf_semi": "CONFERENCE SEMIFINAL",
	"conf_final": "CONFERENCE FINAL",
	"nat_r1": "NCSA FIRST ROUND",
	"nat_qf": "NCSA QUARTERFINAL",
	"nat_sf": "NCSA SEMIFINAL",
	"nat_final": "NCSA FINAL",
}
## The playoff rounds for the header chip.
const SHORT_NAMES := {"conf_qf": "CONF QF", "conf_semi": "CONF SF", "conf_final": "CONF FINAL",
	"nat_r1": "NCSA R1", "nat_qf": "NCSA QF", "nat_sf": "NCSA SF", "nat_final": "NCSA FINAL"}
## Rounds played at a neutral site.
const NEUTRAL_KINDS := ["nat_sf", "nat_final"]
## THE NCSA DIVISION III CHAMPIONSHIP: a separate four-team tournament, played in the weeks of the
## NCSA's first two rounds, so the calendar is the same whoever's on it. Its games are in those
## rounds' lists, marked `k` with their own kind (game_kind), never `kind`: everything that reads
## the NCSA by round (its bracket, its awards, its poll) reads only its own games. The semifinals
## are at the better seed's pool; the final and the third-place game at a neutral site.
const D3_FIELD := 4
const D3_NAMES := {"d3_sf": "NCSA DIVISION III SEMIFINAL", "d3_final": "NCSA DIVISION III NATIONAL CHAMPIONSHIP", "d3_third": "NCSA DIVISION III THIRD-PLACE GAME"}
const D3_SHORT := {"d3_sf": "D3 SF", "d3_final": "D3 FINAL", "d3_third": "D3 3RD"}
const D3_SEMI_ROUND := "nat_r1"    # the week of its semifinals...
const D3_FINAL_ROUND := "nat_qf"   # ...and of its final

static func build(teams: Dictionary, rng: RandomNumberGenerator) -> Array:
	var games := regular_games(teams, rng)
	var rounds: Array = []
	for _try in 40:
		rounds = _calendar(teams, games, rng)
		if not rounds.is_empty():
			break
	assert(not rounds.is_empty(), "the regular season didn't fit in %d weeks" % REGULAR_WEEKS)
	for k in PLAYOFF_KINDS:
		rounds.append({"kind": k, "name": ROUND_NAMES[k], "games": []})
	return rounds

# ------------------------------------------------------------------ who plays whom
## Every regular-season game, not yet put in a week: [{h, a, c, f}].
static func regular_games(teams: Dictionary, rng: RandomNumberGenerator) -> Array:
	var ids: Array = teams.keys()
	ids.sort()
	var games: Array = []
	var need := {}
	for id in ids:
		need[id] = REGULAR_GAMES
	# conference play: every pair once (twice in a double round robin, home and away)
	for cid in Colleges.conf_ids_of(teams):
		var members: Array = ids.filter(func(id): return (teams[id] as PoloTeam).conf == cid)
		for i in members.size():
			for j in range(i + 1, members.size()):
				var a: String = members[i]
				var b: String = members[j]
				for k in Colleges.conf_rr(cid):
					# a double round robin is home and away: those home sides are fixed ("f")
					games.append({"h": a if k % 2 == 0 else b, "a": b if k % 2 == 0 else a, "c": true, "f": Colleges.conf_rr(cid) > 1})
					need[a] -= 1
					need[b] -= 1
	# the rest against other conferences
	for pr in _nonconf_pairs(teams, ids, need, rng):
		games.append({"h": pr[0], "a": pr[1], "c": false, "f": false})
	_balance_homes(games, ids, rng)
	return games

## Non-conference pairs that give every team exactly `need` games, nobody twice:
##   1. a region that can't fill its schedules inside itself (the East) plays every
##      non-conference pairing it has;
##   2. what it still needs comes from the other coast, spread evenly over its teams and
##      matched by strength;
##   3. everyone else fills up inside their own region, against other conferences.
static func _nonconf_pairs(teams: Dictionary, ids: Array, need: Dictionary, rng: RandomNumberGenerator) -> Array:
	var regions := {}
	for id in ids:
		var rg := Colleges.region((teams[id] as PoloTeam).conf)
		if not regions.has(rg):
			regions[rg] = []
		regions[rg].append(id)
	var left := need.duplicate()
	var pairs: Array = []
	var met := {}
	var full: Array = []   # regions that take all their own pairings
	for rg in regions:
		var members: Array = regions[rg]
		var fits := members.all(func(t): return members.filter(func(u): return _other_conf(teams, t, u)).size() <= int(left[t]))
		if not fits:
			continue
		full.append(rg)
		for i in members.size():
			for j in range(i + 1, members.size()):
				if _other_conf(teams, members[i], members[j]):
					_pair(pairs, met, left, members[i], members[j])
	# across the country: the full regions' leftovers, given to the rest as evenly as they'll take
	var givers: Array = ids.filter(func(t): return Colleges.region(teams[t].conf) in full and int(left[t]) > 0)
	var takers: Array = ids.filter(func(t): return not Colleges.region(teams[t].conf) in full)
	if not givers.is_empty():
		var total := 0
		for t in givers:
			total += int(left[t])
		var cap := {}
		var order := _shuffled(takers, rng)
		for i in order.size():
			cap[order[i]] = mini(int(left[order[i]]), total / order.size() + (1 if i < total % order.size() else 0))
		givers.sort_custom(func(a, b): return int(left[a]) > int(left[b]) if int(left[a]) != int(left[b]) else String(a) < String(b))
		for g in givers:
			var opts: Array = takers.filter(func(t): return int(cap[t]) > 0 and not met.has(_pair_key(g, t)))
			var noise := {}
			for t in opts:
				noise[t] = rng.randf()
			# the most room first (that keeps it solvable), then the closest in strength
			opts.sort_custom(func(a, b):
				if int(cap[a]) != int(cap[b]):
					return int(cap[a]) > int(cap[b])
				return _closeness(teams, g, a) + noise[a] < _closeness(teams, g, b) + noise[b])
			var n := int(left[g])
			for t in opts.slice(0, n):
				cap[t] -= 1
				_pair(pairs, met, left, g, t)
	# everyone left fills up at home, against other conferences
	for rg in regions:
		var members: Array = regions[rg].filter(func(t): return int(left[t]) > 0)
		if members.is_empty():
			continue
		var found: Array = []
		for _try in 20:
			found = _fill_up(teams, members, left.duplicate(), met, rng)
			if not found.is_empty():
				break
		assert(not found.is_empty(), "no non-conference schedule for the %s" % rg)
		for pr in found:
			_pair(pairs, met, left, pr[0], pr[1])
	return pairs

## Pairs inside `members` (other conferences only, no pair already in `met`) giving each team
## exactly `left` more games: the closest games in strength go in first, then any team still
## short swaps its way in (an existing pair x-y becomes u-x and v-y). [] if it can't be done.
static func _fill_up(teams: Dictionary, members: Array, left: Dictionary, met: Dictionary, rng: RandomNumberGenerator) -> Array:
	var cands: Array = []
	for i in members.size():
		for j in range(i + 1, members.size()):
			var a: String = members[i]
			var b: String = members[j]
			if _other_conf(teams, a, b) and not met.has(_pair_key(a, b)):
				cands.append([a, b, _closeness(teams, a, b) + rng.randf() * 8.0])
	cands.sort_custom(func(x, y): return x[2] < y[2])
	var edges := {}   # pair key -> [a, b]
	var ok := func(a: String, b: String) -> bool:
		return _other_conf(teams, a, b) and not met.has(_pair_key(a, b)) and not edges.has(_pair_key(a, b))
	for c in cands:
		if int(left[c[0]]) > 0 and int(left[c[1]]) > 0:
			edges[_pair_key(c[0], c[1])] = [c[0], c[1]]
			left[c[0]] -= 1
			left[c[1]] -= 1
	for _step in 4000:
		var short: Array = members.filter(func(t): return int(left[t]) > 0)
		if short.is_empty():
			return edges.values()
		var u: String = short[rng.randi() % short.size()]
		var others: Array = short.filter(func(t): return t != u) if int(left[u]) == 1 else short
		var v: String = others[rng.randi() % others.size()] if not others.is_empty() else u
		if u != v and ok.call(u, v):
			edges[_pair_key(u, v)] = [u, v]
			left[u] -= 1
			left[v] -= 1
			continue
		# swap: drop a pair x-y, add u-x and v-y
		var keys: Array = edges.keys()
		for _k in 60:
			var e: Array = edges[keys[rng.randi() % keys.size()]]
			var x: String = e[0]
			var y: String = e[1]
			if rng.randi() % 2 == 0:
				x = e[1]
				y = e[0]
			if x == u or x == v or y == u or y == v:
				continue
			if ok.call(u, x) and ok.call(v, y) and (u != v or x != y):
				edges.erase(_pair_key(x, y))
				edges[_pair_key(u, x)] = [u, x]
				edges[_pair_key(v, y)] = [v, y]
				left[u] -= 1
				left[v] -= 1
				break
	return []

static func _pair(pairs: Array, met: Dictionary, left: Dictionary, a: String, b: String) -> void:
	pairs.append([a, b])
	met[_pair_key(a, b)] = true
	left[a] -= 1
	left[b] -= 1

static func _other_conf(teams: Dictionary, a: String, b: String) -> bool:
	return a != b and (teams[a] as PoloTeam).conf != (teams[b] as PoloTeam).conf

## How far apart two teams are in strength (smaller is the better game).
static func _closeness(teams: Dictionary, a: String, b: String) -> float:
	return absf((teams[a] as PoloTeam).rating() - (teams[b] as PoloTeam).rating())

static func _pair_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

static func _shuffled(arr: Array, rng: RandomNumberGenerator) -> Array:
	var out := arr.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out

## Home and away: as close to 8 and 8 as it goes. Fixed games ("f") keep their home side.
static func _balance_homes(games: Array, ids: Array, rng: RandomNumberGenerator) -> void:
	var homes := {}
	for id in ids:
		homes[id] = 0
	for g in games:
		if g.f:
			homes[g.h] += 1
	for g in _shuffled(games.filter(func(x): return not x.f), rng):
		if homes[g.a] < homes[g.h] or (homes[g.a] == homes[g.h] and rng.randi() % 2 == 0):
			var t: String = g.h
			g.h = g.a
			g.a = t
		homes[g.h] += 1
	var half := REGULAR_GAMES / 2
	for _pass in 50:
		var moved := false
		for g in games:
			if g.f:
				continue
			if homes[g.h] > half and homes[g.a] < half:
				homes[g.h] -= 1
				homes[g.a] += 1
				var t: String = g.h
				g.h = g.a
				g.a = t
				moved = true
		if not moved:
			break

# ------------------------------------------------------------------ when
## Puts the games in weeks and days: road trips across the country first (two or three games
## in one week), then conference games (later in the season), then the rest (earlier), each
## where both teams have the least on. [] if a game found no room (try again).
static func _calendar(teams: Dictionary, games: Array, rng: RandomNumberGenerator) -> Array:
	var busy := {}   # team -> {week*DAYS + day: true}
	var per_week := {}   # team -> [games per week]
	for id in teams:
		busy[id] = {}
		var pw: Array = []
		pw.resize(REGULAR_WEEKS)
		pw.fill(0)
		per_week[id] = pw
	for g in games:
		g.erase("w")   # where a game ends up: "w" week, "day"
	# road trips: each team's away games on the other coast, two or three to a trip
	var trips := {}
	for g in games:
		if Colleges.region(teams[g.h].conf) != Colleges.region(teams[g.a].conf):
			if not trips.has(g.a):
				trips[g.a] = []
			trips[g.a].append(g)
	var travellers: Array = trips.keys()
	travellers.sort()
	for t in _shuffled(travellers, rng):
		var away: Array = _shuffled(trips[t], rng)
		var chunks: Array = []
		while not away.is_empty():
			var k := 3 if away.size() == 3 or away.size() >= 5 else mini(2, away.size())
			chunks.append(away.slice(0, k))
			away = away.slice(k)
		for chunk in chunks:
			if not _place_trip(chunk, t, busy, per_week, rng):
				for g in chunk:
					if not _place_one(g, busy, per_week, rng):
						return []
	var rest: Array = _shuffled(games.filter(func(g): return not g.has("w")), rng)
	rest.sort_custom(func(a, b): return int(a.c) > int(b.c))   # conference games first: fewer weeks suit them
	for g in rest:
		if not _place_one(g, busy, per_week, rng):
			return []
	var rounds: Array = []
	for w in REGULAR_WEEKS:
		rounds.append({"kind": "reg", "name": ROUND_NAMES.reg, "games": []})
	for g in games:
		rounds[g.w].games.append({"h": g.h, "a": g.a, "r": null, "d": g.day, "c": bool(g.c)})
	for r in rounds:
		(r.games as Array).sort_custom(func(x, y): return int(x.d) < int(y.d) if int(x.d) != int(y.d) else String(x.h) < String(y.h))
	return rounds

## A trip: all of `chunk` (the traveller's away games) in one week, on different days.
static func _place_trip(chunk: Array, traveller: String, busy: Dictionary, per_week: Dictionary, rng: RandomNumberGenerator) -> bool:
	var weeks := _shuffled(range(REGULAR_WEEKS), rng)
	weeks.sort_custom(func(a, b): return per_week[traveller][a] < per_week[traveller][b])
	for w in weeks:
		if per_week[traveller][w] + chunk.size() > DAYS:
			continue
		var days := []
		var ok := true
		for g in chunk:
			var day := -1
			for d in DAYS:
				if d in days or busy[g.h].has(w * DAYS + d) or busy[g.a].has(w * DAYS + d) or per_week[g.h][w] >= DAYS:
					continue
				day = d
				break
			if day < 0:
				ok = false
				break
			days.append(day)
		if not ok:
			continue
		for i in chunk.size():
			_put(chunk[i], w, days[i], busy, per_week)
		return true
	return false

## One game in the best free slot: conference games late, non-conference early, and the
## weeks where both teams have the least on.
static func _place_one(g: Dictionary, busy: Dictionary, per_week: Dictionary, rng: RandomNumberGenerator) -> bool:
	var best := []
	var best_score := INF
	for w in REGULAR_WEEKS:
		if per_week[g.h][w] >= DAYS or per_week[g.a][w] >= DAYS:
			continue
		var load := float(per_week[g.h][w] + per_week[g.a][w])
		var when := float(REGULAR_WEEKS - 1 - w) if g.c else float(w)
		for d in DAYS:
			if busy[g.h].has(w * DAYS + d) or busy[g.a].has(w * DAYS + d):
				continue
			var score := load * 4.0 + when * 0.6 + rng.randf() * 1.5
			if score < best_score:
				best_score = score
				best = [w, d]
	if best.is_empty():
		return false
	_put(g, best[0], best[1], busy, per_week)
	return true

static func _put(g: Dictionary, w: int, d: int, busy: Dictionary, per_week: Dictionary) -> void:
	busy[g.h][w * DAYS + d] = true
	busy[g.a][w * DAYS + d] = true
	per_week[g.h][w] += 1
	per_week[g.a][w] += 1
	g.w = w
	g.day = d

# ------------------------------------------------------------------ games and rounds
static func _game(a: String, b: String, a_home: bool) -> Dictionary:
	return {"h": a if a_home else b, "a": b if a_home else a, "r": null, "d": 1}

## What a game is in the postseason: its own `k` (the Division III tournament), else its round's kind.
static func game_kind(round: Dictionary, g: Dictionary) -> String:
	return String(g.get("k", round.get("kind", "")))

## The round's games of the NCSA itself (a round can also carry Division III's).
static func nat_games(round: Dictionary) -> Array:
	return (round.games as Array).filter(func(g): return not g.has("k"))

## A neutral-site game: no home pool for either team.
static func is_neutral(g: Dictionary) -> bool:
	return bool(g.get("nu", false))

## `id`'s regular-season games in the order they're played: [[week index, game], ...].
static func team_games(rounds: Array, id: String) -> Array:
	var out: Array = []
	for w in rounds.size():
		var r: Dictionary = rounds[w]
		if is_playoff(r):
			continue
		var mine: Array = (r.games as Array).filter(func(g): return g.h == id or g.a == id)
		mine.sort_custom(func(a, b): return int(a.get("d", 0)) < int(b.get("d", 0)))
		for g in mine:
			out.append([w, g])
	return out

## The game's number in `id`'s regular season, 1-16 (0 for a playoff game or not his).
static func game_no(rounds: Array, id: String, g: Dictionary) -> int:
	var games := team_games(rounds, id)
	for i in games.size():
		if games[i][1] == g:
			return i + 1
	return 0

## How many of `id`'s regular-season games are played.
static func games_played(rounds: Array, id: String) -> int:
	return team_games(rounds, id).filter(func(e): return e[1].r != null).size()

static func is_playoff(round: Dictionary) -> bool:
	return String(round.kind) in PLAYOFF_KINDS

## A playoff round whose games are set (or a regular-season week).
static func drawn(round: Dictionary) -> bool:
	return not is_playoff(round) or round.get("drawn", false) or not (round.games as Array).is_empty()

## A conference game? (Older saves only know it from the round.)
static func is_conf_game(round: Dictionary, g: Dictionary) -> bool:
	return bool(g.get("c", String(round.get("kind", "")) == "conf"))

## What a game is, for the screens: the playoff round, or conference / non-conference.
static func game_label(round: Dictionary, g: Dictionary) -> String:
	if g.has("k"):
		return String(D3_NAMES.get(String(g.k), ""))
	if is_playoff(round) or String(round.get("kind", "")) != "reg":
		return String(round.get("name", ""))
	return "CONFERENCE" if is_conf_game(round, g) else "NONCONFERENCE"

static func winner(g: Dictionary) -> String:
	if g.r == null:
		return ""
	return String(g.h) if int(g.r.w) == 0 else String(g.a)

static func loser(g: Dictionary) -> String:
	if g.r == null:
		return ""
	return String(g.a) if int(g.r.w) == 0 else String(g.h)

static func score_text(g: Dictionary, h_first: bool = true) -> String:
	if g.r == null:
		return "-"
	var s: Array = g.r.s
	var t := "%d-%d" % [s[0], s[1]] if h_first else "%d-%d" % [s[1], s[0]]
	if not (g.r.so as Array).is_empty():
		var so: Array = g.r.so
		t += " (%d-%d P)" % ([so[0], so[1]] if h_first else [so[1], so[0]])
	return t

# ------------------------------------------------------------------ standings
static func empty_row() -> Dictionary:
	return {"w": 0, "l": 0, "cw": 0, "cl": 0, "gf": 0, "ga": 0}

## Counts a regular-season result into the table.
static func record(table: Dictionary, g: Dictionary, conference: bool) -> void:
	var s: Array = g.r.s
	var h: Dictionary = table[g.h]
	var a: Dictionary = table[g.a]
	h.gf += int(s[0])
	h.ga += int(s[1])
	a.gf += int(s[1])
	a.ga += int(s[0])
	var win: Dictionary = h if int(g.r.w) == 0 else a
	var lose: Dictionary = a if int(g.r.w) == 0 else h
	win.w += 1
	lose.l += 1
	if conference:
		win.cw += 1
		lose.cl += 1

## Conference order: conference wins, goal difference, overall wins, prestige.
static func conf_table(teams: Dictionary, table: Dictionary, conf: String) -> Array:
	var ids: Array = teams.keys().filter(func(id): return (teams[id] as PoloTeam).conf == conf)
	ids.sort_custom(func(x, y):
		var a: Dictionary = table[x]
		var b: Dictionary = table[y]
		if a.cw != b.cw:
			return a.cw > b.cw
		if a.gf - a.ga != b.gf - b.ga:
			return a.gf - a.ga > b.gf - b.ga
		if a.w != b.w:
			return a.w > b.w
		if teams[x].prestige != teams[y].prestige:
			return teams[x].prestige > teams[y].prestige
		return String(x) < String(y))   # dead level: a fixed order, never a random one
	return ids

# ------------------------------------------------------------------ playoffs
## Seed numbers in bracket order for a bracket of `size` (a power of two): 1 v size, then the
## halves so the top seeds can only meet late. 8 -> [1, 8, 4, 5, 2, 7, 3, 6].
static func bracket_order(size: int) -> Array:
	var order := [1]
	var n := 1
	while n < size:
		n *= 2
		var next: Array = []
		for s in order:
			next.append(s)
			next.append(n + 1 - s)
		order = next
	return order

## The bracket's slots for `seeds` (best first): a team id, or "" where a bye sits.
static func _slots(seeds: Array, size: int) -> Array:
	return bracket_order(size).map(func(s): return String(seeds[s - 1]) if s <= seeds.size() else "")

## The games between neighbouring slots where both are filled, the better seed at home.
static func _slot_games(slots: Array, seeds: Array) -> Array:
	var out: Array = []
	for i in range(0, slots.size(), 2):
		var a: String = slots[i]
		var b: String = slots[i + 1]
		if a != "" and b != "":
			out.append(_game(a, b, seeds.find(a) <= seeds.find(b)))
	return out

## The slots of the next round: each pair's winner, or whoever had the bye.
static func _advance(slots: Array, games: Array) -> Array:
	var out: Array = []
	for i in range(0, slots.size(), 2):
		var a: String = slots[i]
		var b: String = slots[i + 1]
		if a == "" or b == "":
			out.append(a if b == "" else b)
			continue
		var w := ""
		for g in games:
			if (g.h == a and g.a == b) or (g.h == b and g.a == a):
				w = winner(g)
		out.append(w)
	return out

## The rounds of a playoff family ("conf" or "nat") in a schedule, and where the first is.
static func _family(rounds: Array, fam: String) -> Array:
	var out: Array = []
	for i in rounds.size():
		if String(rounds[i].kind).begins_with(fam + "_") and is_playoff(rounds[i]):
			out.append(i)
	return out

## Draws the playoff round at `index` from the rounds before it.
static func fill_playoff(rounds: Array, index: int, teams: Dictionary, table: Dictionary, season: Dictionary) -> void:
	var round: Dictionary = rounds[index]
	var kind := String(round.kind)
	var fam := "conf" if kind.begins_with("conf_") else "nat"
	var fam_rounds := _family(rounds, fam)
	var first: bool = fam_rounds[0] == index
	var size := 1 << fam_rounds.size()
	var prev: Dictionary = rounds[index - 1]
	var games: Array = []
	if fam == "conf":
		if first:
			# every team in, seeded by its conference record; the top seeds get the byes
			var seeds := {}
			var slots := {}
			for cid in tournament_confs(teams):
				var top: Array = conf_table(teams, table, cid).slice(0, size)
				seeds[cid] = top
				slots[cid] = _slots(top, size)
				games.append_array(_slot_games(slots[cid], top))
			season["conf_seeds"] = seeds
			season["conf_slots"] = slots
		elif season.has("conf_slots"):
			var slots: Dictionary = season.conf_slots
			for cid in slots:
				slots[cid] = _advance(slots[cid], prev.games)
				games.append_array(_slot_games(slots[cid], season.conf_seeds[cid]))
		else:
			# a save from before: the semifinal winners meet, conference by conference
			var seeds: Dictionary = season.get("conf_seeds", {})
			for i in range(0, prev.games.size(), 2):
				var a := winner(prev.games[i])
				var b := winner(prev.games[i + 1])
				var top: Array = seeds.get((teams[a] as PoloTeam).conf, [])
				games.append(_game(a, b, top.find(a) <= top.find(b)))
	else:
		if first:
			var champs: Array = []
			for g in prev.games:
				champs.append(winner(g))
			season["conf_champs"] = champs
			# the SELECTION poll: the one out after the conference finals (made now if a save has none)
			var polls: Array = season.get("polls", [])
			var poll: Dictionary = Poll.latest_of(polls)
			if poll.is_empty() or int(poll.wk) != index - 1:
				poll = Poll.make(teams, rounds, index - 1, season.get("poll_prior", Poll.hierarchy(teams)), poll)
			# only Division I and the one Division II champion can be in the NCSA's field: a
			# Division III team is never in it, however high it's ranked
			var autos := nat_autos(teams, champs)
			var ranks: Array = (poll.ranks as Array).filter(func(id): return Colleges.division((teams[id] as PoloTeam).conf) == Colleges.D1 or id in autos)
			var field := select_field(ranks, autos, mini(NCSA_FIELD, size))
			season["at_large"] = field.filter(func(id): return not id in autos)
			season["nat_seeds"] = field
			season["nat_slots"] = _slots(field, size)
			games = _slot_games(season.nat_slots, field)
			for id in champs:
				if String((teams[id] as PoloTeam).conf) == Colleges.D2_CONF:
					season["d2_champ"] = id
			games.append_array(_draw_d3(teams, poll.ranks, champs, season))
		elif season.has("nat_slots"):
			season["nat_slots"] = _advance(season.nat_slots, prev.games)
			games = _slot_games(season.nat_slots, season.nat_seeds)
			if kind == D3_FINAL_ROUND:
				games.append_array(_d3_final(prev, season))
		else:
			var seeds: Array = season.get("nat_seeds", [])
			for i in range(0, prev.games.size(), 2):
				var a := winner(prev.games[i])
				var b := winner(prev.games[i + 1])
				games.append(_game(a, b, seeds.find(a) <= seeds.find(b)))
	if kind in NEUTRAL_KINDS:
		for g in games:
			g["nu"] = true
	round.games = games
	round["drawn"] = true

## The conferences with a tournament: every conference with at least two teams here. (The NWPC's
## one school has none: it's never given a made-up final or an automatic bid.)
static func tournament_confs(teams: Dictionary) -> Array:
	return Colleges.conf_ids_of(teams).filter(func(cid): return teams.keys().filter(func(id): return (teams[id] as PoloTeam).conf == cid).size() >= 2)

## The NCSA's automatic bids out of this year's tournament champions: Division I's, and Division
## II's one (the WWPA's champion; no other Division II team can be in the field). Division III's
## champions go to their own tournament.
static func nat_autos(teams: Dictionary, champs: Array) -> Array:
	return champs.filter(func(id): return Colleges.division((teams[id] as PoloTeam).conf) != Colleges.D3)

## THE DIVISION III FIELD from the SELECTION poll: the SCIAC and MPSF East champions (automatic
## bids), then the best-ranked other Division III teams until there are four, nobody twice; seeded
## by the poll, whoever got in how. [] with no Division III in this dynasty.
static func d3_field(teams: Dictionary, ranks: Array, champs: Array) -> Array:
	var d3: Array = ranks.filter(func(id): return Colleges.division((teams[id] as PoloTeam).conf) == Colleges.D3)
	if d3.size() < D3_FIELD:
		return []
	var field: Array = champs.filter(func(id): return id in d3)
	for id in d3:
		if field.size() >= D3_FIELD:
			break
		if not id in field:
			field.append(id)
	field.sort_custom(func(x, y): return ranks.find(x) < ranks.find(y))
	return field

## The Division III semifinals (1 v 4, 2 v 3), and the season's record of how it was drawn.
static func _draw_d3(teams: Dictionary, ranks: Array, champs: Array, season: Dictionary) -> Array:
	var field := d3_field(teams, ranks, champs)
	if field.is_empty():
		return []
	season["d3_seeds"] = field
	season["d3_at_large"] = field.filter(func(id): return not id in champs)
	season["d3_slots"] = _slots(field, D3_FIELD)
	return _d3_marked(_slot_games(season.d3_slots, field), "d3_sf")

static func _d3_marked(games: Array, k: String) -> Array:
	for g in games:
		g["k"] = k
		g["nu"] = k != "d3_sf"
		if not g.nu:
			g.erase("nu")
	return games

## The Division III final, and its semifinal losers' third-place game (it decides nothing else).
static func _d3_final(prev: Dictionary, season: Dictionary) -> Array:
	if not season.has("d3_slots"):
		return []
	var semis: Array = (prev.games as Array).filter(func(g): return String(g.get("k", "")) == "d3_sf")
	var seeds: Array = season.d3_seeds
	var losers: Array = semis.map(func(g): return loser(g))
	season["d3_slots"] = _advance(season.d3_slots, semis)
	season["d3_third"] = losers
	var out: Array = _d3_marked(_slot_games(season.d3_slots, seeds), "d3_final")
	if losers.size() == 2:
		out.append_array(_d3_marked([_game(losers[0], losers[1], seeds.find(losers[0]) <= seeds.find(losers[1]))], "d3_third"))
	return out

## The game of Division III kind `k` ("d3_final"...), {} if it isn't there yet.
static func d3_game(rounds: Array, k: String) -> Dictionary:
	for r in rounds:
		for g in r.games:
			if String(g.get("k", "")) == k:
				return g
	return {}

## This season's finals as history: [{key, tournament, champion, runner_up, score}], key "nat", "d3",
## "d2" or "conf:<id>". The WWPA's final is two entries, its own and the Division II Championship:
## one game, two achievements.
static func finals(rounds: Array, teams: Dictionary) -> Array:
	var out: Array = []
	var add := func(key: String, name: String, g: Dictionary) -> void:
		out.append({"key": key, "tournament": name, "champion": winner(g), "runner_up": loser(g), "score": score_text(g, g.h == winner(g))})
	for r in rounds:
		for g in r.games:
			if g.r == null:
				continue
			if String(g.get("k", "")) == "d3_final":
				add.call("d3", "NCSA DIVISION III CHAMPIONSHIP", g)
			elif g.has("k"):
				continue
			elif String(r.kind) == "conf_final":
				var cf := String((teams[winner(g)] as PoloTeam).conf)
				add.call("conf:" + cf, "%s CHAMPIONSHIP" % Colleges.conf_abbr(cf), g)
				if cf == Colleges.D2_CONF:
					add.call("d2", "DIVISION II CHAMPIONSHIP", g)
			elif String(r.kind) == "nat_final":
				add.call("nat", "NCSA CHAMPIONSHIP", g)
	return out

## The NCSA field from the SELECTION poll (`ranks`, every team best first): the conference
## tournament champions (automatic bids, wherever they're ranked), then the poll read from #1
## down, skipping them, until the field is full; no other picks. Seeded in poll order.
static func select_field(ranks: Array, champs: Array, field_size: int) -> Array:
	var field: Array = champs.duplicate()
	for id in ranks:
		if field.size() >= field_size:
			break
		if not id in field:
			field.append(id)
	field.sort_custom(func(x, y): return ranks.find(x) < ranks.find(y))
	return field

## Still in this playoff round's bracket (playing, or sitting out a bye)?
static func alive(season: Dictionary, round: Dictionary, id: String, conf: String) -> bool:
	var kind := String(round.get("kind", ""))
	if kind.begins_with("conf_"):
		return id in (season.get("conf_slots", {}).get(conf, []) as Array)
	if kind.begins_with("nat_"):
		if id in (season.get("nat_slots", []) as Array):
			return true
		return kind in [D3_SEMI_ROUND, D3_FINAL_ROUND] and (id in (season.get("d3_slots", []) as Array) or id in (season.get("d3_third", []) as Array))
	return false

## The seed shown next to a playoff team, or 0.
static func seed_of(season: Dictionary, kind: String, id: String, conf: String) -> int:
	if id in (season.get("d3_seeds", []) as Array):
		return (season.d3_seeds as Array).find(id) + 1
	if kind.begins_with("nat"):
		return (season.get("nat_seeds", []) as Array).find(id) + 1
	if kind.begins_with("conf_"):
		return (season.get("conf_seeds", {}).get(conf, []) as Array).find(id) + 1
	return 0
