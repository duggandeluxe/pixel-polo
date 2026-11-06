class_name GameSim
## The scoring engine: a whole game decided from the two teams' ratings (OVR, OFF, DEF), worked
## out from their seven starters' attributes when the game is played (PoloTeam.ratings: never a
## stored or original number), and their players' form, for every game you don't play. Form comes in once, as the team's
## LIVE - BASE added to its OFF and DEF (live_ratings); nothing else here looks at form. Expected goals on neutral water, then the home pool's 5%, then
## a total and a margin sampled around them (separately), split into four quarters; a level game
## goes to overtime. The winner is whoever ends up with more goals: nothing is decided in advance.
## Each game has its own seed (saved with the result), so it can be played again the same way.

## Neutral-pool expected scores, for teams A and B (higher ratings are better):
##   GAP = OVR(A) - OVR(B); STYLE(T) = OFF(T) - OVR(T)
##   TOTAL = 21.5 + 0.24 x (85 - average DEF) + 0.42 x |GAP| + 0.35 x (STYLE(A) + STYLE(B))
##   MATCH_A = OFF(A) - DEF(B); MATCH_B = OFF(B) - DEF(A)
##   MARGIN = 0.475 x (MATCH_A - MATCH_B) + 0.10 x (STYLE(A) - STYLE(B))
##   EXPECTED_A = (TOTAL + MARGIN) / 2; EXPECTED_B = (TOTAL - MARGIN) / 2
const BASE_TOTAL := 21.5
const DEF_PIVOT := 85.0
const DEF_TOTAL := 0.24
const GAP_TOTAL := 0.42
const STYLE_TOTAL := 0.35
const MATCH_MARGIN := 0.475
const STYLE_MARGIN := 0.10
## The home pool: the host's expected goals x 1.05, the visitors' x 0.95. Once, in the expected
## scores; never on the rating, the win chance or again in overtime. Neutral sites have none.
const HOME_BOOST := 1.05
const AWAY_DROP := 0.95
## The final score: the total sampled around the expected total (never under MIN_TOTAL), the
## margin sampled on its own.
const TOTAL_SD := 3.1
const MARGIN_SD := 4.5
const MIN_TOTAL := 15
const QUARTERS := 4
## Overtime: two 3-minute periods at the game's own scoring rates (a quarter is 8 minutes), then
## the next goal wins.
const OT_PERIODS := 2
const OT_SHARE := 3.0 / 32.0
const POSSESSIONS := 24        # each side, for the keepers' saves

## [OVR, OFF, DEF] for the engine: the seven starters' permanent stars and lean (PoloTeam.ratings).
static func sim_ratings(t: PoloTeam) -> Array:
	return t.ratings()

## The ratings a game is played with: BASE ([OVR, OFF, DEF], sim_ratings) with the team's form
## (PoloTeam.form_delta, the engine's HEAT UP term), added once to OFF and to DEF; OVR stays their
## average. The starters' style (OFF - OVR) is kept. With everyone NORMAL it's just BASE.
## `delta`: the form to play with instead of the team's own now, and `base` the BASE (a saved
## game replayed: the players may have moved on since).
static func live_ratings(t: PoloTeam, delta: Variant = null, base: Array = []) -> Array:
	var r := base if base.size() == 3 else sim_ratings(t)
	var d := float(t.form_delta() if delta == null else int(delta))
	if d == 0.0:
		return r
	return [float(r[0]) + d, float(r[1]) + d, float(r[2]) + d]

## Expected goals [a's, b's] for a game between them, before it's played: the engine's own
## odds for it, on the ratings it will be played with (LIVE: BASE and the teams' form), the home
## pool or neutral site in them. The postgame grade measures against this (PlayerForm.expected),
## so a HOT team has to beat what its form already promises to stay HOT. `a_home`: a is the host.
static func pregame_expected(a: PoloTeam, b: PoloTeam, a_home: bool, neutral: bool) -> Array:
	if a_home:
		return expected(live_ratings(a), live_ratings(b), neutral)
	var e := expected(live_ratings(b), live_ratings(a), neutral)
	return [e[1], e[0]]

## Expected goals [A, B] on neutral water; `a` and `b` are [OVR, OFF, DEF].
static func neutral_expected(a: Array, b: Array) -> Array:
	var gap := float(a[0]) - float(b[0])
	var style_a := float(a[1]) - float(a[0])
	var style_b := float(b[1]) - float(b[0])
	var avg_def := (float(a[2]) + float(b[2])) / 2.0
	var total := BASE_TOTAL + DEF_TOTAL * (DEF_PIVOT - avg_def) + GAP_TOTAL * absf(gap) + STYLE_TOTAL * (style_a + style_b)
	var match_a := float(a[1]) - float(b[2])
	var match_b := float(b[1]) - float(a[2])
	var margin := MATCH_MARGIN * (match_a - match_b) + STYLE_MARGIN * (style_a - style_b)
	return [(total + margin) / 2.0, (total - margin) / 2.0]

## Expected goals [home, away]: neutral, then the home pool's 5% unless it's a neutral site.
static func expected(home: Array, away: Array, neutral: bool) -> Array:
	var e := neutral_expected(home, away)
	if neutral:
		return e
	return [e[0] * HOME_BOOST, e[1] * AWAY_DROP]

## One overtime period's expected goals: the game's own rates (the home pool already in them).
static func ot_expected(xg: Array) -> Array:
	return [float(xg[0]) * OT_SHARE, float(xg[1]) * OT_SHARE]

## A final score around `xg` ([home, away] expected goals):
## {s: [h, a], reg: [h, a], q: [[h by quarter], [a ...]], ot: [[h by period], [a ...]], w: 0|1}.
## `ot` is empty unless regulation ended level; a sudden-death goal is a period of its own.
static func score(xg: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total_exp := float(xg[0]) + float(xg[1])
	var margin_exp := float(xg[0]) - float(xg[1])
	var total := maxi(MIN_TOTAL, roundi(rng.randfn(total_exp, TOTAL_SD)))
	var margin := rng.randfn(margin_exp, MARGIN_SD)
	var h := clampi(roundi((total + margin) / 2.0), 0, total)
	var reg := [h, total - h]
	var q := [[0, 0, 0, 0], [0, 0, 0, 0]]
	for side in 2:
		for _i in reg[side]:
			q[side][rng.randi() % QUARTERS] += 1
	var s := [reg[0], reg[1]]
	var ot := [[], []]
	if s[0] == s[1]:
		var rate := ot_expected(xg)
		for _p in OT_PERIODS:
			for side in 2:
				var n := poisson(rate[side], rng)
				ot[side].append(n)
				s[side] += n
		if s[0] == s[1]:
			# sudden death: the next goal, at the two sides' rates
			var first := 0 if rng.randf() * (rate[0] + rate[1]) < rate[0] else 1
			ot[first].append(1)
			ot[1 - first].append(0)
			s[first] += 1
	return {"s": s, "reg": reg, "q": q, "ot": ot, "w": 0 if s[0] > s[1] else 1}

static func poisson(mean: float, rng: RandomNumberGenerator) -> int:
	var limit := exp(-mean)
	var k := 0
	var p := rng.randf()
	while p > limit and k < 50:
		k += 1
		p *= rng.randf()
	return k

## A game between `home` and `away` from `seed_value`: the score, then who scored, assisted
## and saved (for the stats and record books), then every player's stat line (player_lines).
## {score: [h, a], so: [], winner: 0|1, goals: [[PoloPlayer...], [...]], assists, saves: [h, a],
##  q, ot, seed, xg: [h, a] expected goals, neutral, fd: [h, a] the form it was played with
##  (LIVE - BASE), lines: [{id: line}, {id: line}]}
## `fd`: play it with this form instead of the teams' own now, `rt` with these BASE ratings
## ([home's, away's]) instead of their players' now (replaying a saved game: replay).
static func play(home: PoloTeam, away: PoloTeam, seed_value: int, neutral := false, fd: Array = [], rt: Array = []) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if fd.size() != 2:
		fd = [home.form_delta(), away.form_delta()]
	rt = [_snapped(rt[0] if rt.size() == 2 else sim_ratings(home)), _snapped(rt[1] if rt.size() == 2 else sim_ratings(away))]
	var xg := expected(live_ratings(home, fd[0], rt[0]), live_ratings(away, fd[1], rt[1]), neutral)
	var sc := score(xg, rng)
	var out := {"score": sc.s, "so": [], "winner": sc.w, "goals": [[], []], "assists": [[], []], "saves": [0, 0],
		"q": sc.q, "ot": sc.ot, "seed": seed_value, "xg": xg, "neutral": neutral, "missed": [0, 0], "fd": [int(fd[0]), int(fd[1])],
		"rt": rt}
	var teams := [home, away]
	for side in 2:
		var att: PoloTeam = teams[side]
		var field := att.starters().slice(1)
		for _i in int(sc.s[side]):
			var shooter := _pick(field, func(p): return PlayerForm.shot_weight(p), rng)
			out.goals[side].append(shooter)
			if rng.randf() < 0.55:
				var others := field.filter(func(p): return p != shooter)
				if not others.is_empty():
					out.assists[side].append(others[rng.randi() % others.size()])
		# the other keeper's saves: some of the possessions that didn't score
		var missed := maxi(POSSESSIONS + rng.randi_range(-3, 3), int(sc.s[side]) + 4) - int(sc.s[side])
		for _i in missed:
			if rng.randf() < 0.42:
				out.saves[1 - side] += 1
		out.missed[side] = missed
	out["lines"] = player_lines(home, away, out, seed_value)
	return out

## The rest of a non-scoring possession that the other keeper didn't save: a field block, a shot
## wide or off the post, or no shot at all (PlayerForm.ENV "sim" expects exactly these).
const BLOCK_SHARE := 0.25
const WIDE_SHARE := 0.35
## ...and of the rest (no shot at all), this share is a turnover, charged to a ball carrier
## (the weaker passers likelier); this share of turnovers a steal by a man on the other side (the
## better defenders likelier), the rest a lost ball. Tuned to played games' rates (--test
## sim_stats_measure: about 0.85 turnovers a side, nearly all steals).
const TURNOVER_SHARE := 0.34
const STEAL_SHARE := 0.95
## Exclusions a side draws, on average; the centre draws CENTER_EXCL times his share.
const EXCL_MEAN := 6.0
const CENTER_EXCL := 2.5

## Each player's stat line for the postgame grade (PlayerForm.raw_points), [{id: line} home,
## {id: line} away]. Field: g goals, sh shots (goals plus misses: every shot the keeper saved,
## a defender blocked or that went wide), bl field blocks, ed exclusions drawn, ga goals against,
## to turnovers, st steals, ex exclusions committed (the grade reads none of these three);
## the keeper: sv saves, ga goals against. Goals and saves are the game's own; the misses,
## blocks and exclusions come from their own dice (a seed made from the game's), so nothing the
## game already decided (the score, who scored, the saves) changes.
static func player_lines(home: PoloTeam, away: PoloTeam, res: Dictionary, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x5eed11e5
	var teams := [home, away]
	var lines := [{}, {}]
	for side in 2:
		var t: PoloTeam = teams[side]
		var seven := t.starters()
		for p in seven:
			lines[side][p.id] = {"gk": true, "sv": 0, "ga": 0} if p == seven[0] else {"g": 0, "sh": 0, "bl": 0, "ed": 0, "ga": 0, "to": 0, "st": 0, "ex": 0}
	for side in 2:
		var att: PoloTeam = teams[side]
		var def: PoloTeam = teams[1 - side]
		var mine: Dictionary = lines[side]
		var theirs: Dictionary = lines[1 - side]
		var a_field := att.starters().slice(1)
		var d_field := def.starters().slice(1)
		for p: PoloPlayer in res.goals[side]:
			if mine.has(p.id):
				mine[p.id].g += 1
				mine[p.id].sh += 1
		var saved := int(res.saves[1 - side])
		var rest := maxi(0, int(res.missed[side]) - saved)
		var misses := saved
		for _i in rest:
			var roll := rng.randf()
			if roll < BLOCK_SHARE:
				misses += 1
				var b := _pick(d_field, func(p): return PlayerForm.block_weight(p), rng)
				if b != null:
					theirs[b.id].bl += 1
			elif roll < BLOCK_SHARE + WIDE_SHARE:
				misses += 1
			elif rng.randf() < TURNOVER_SHARE:
				# no shot: the ball lost, and most often taken
				var lost := _pick(a_field, func(p): return PlayerForm.turnover_weight(p), rng)
				if lost != null:
					mine[lost.id].to += 1
					if rng.randf() < STEAL_SHARE:
						var thief := _pick(d_field, func(p): return PlayerForm.block_weight(p), rng)
						if thief != null:
							theirs[thief.id].st += 1
		for _i in misses:
			var s := _pick(a_field, func(p): return PlayerForm.shot_weight(p), rng)
			if s != null:
				mine[s.id].sh += 1
		for _i in poisson(EXCL_MEAN, rng):
			var e := _pick(a_field, func(p): return PlayerForm.excl_weight(p, CENTER_EXCL), rng)
			if e != null:
				mine[e.id].ed += 1
				# ...and the man of theirs sent out for it: whoever was on him (the centre's own
				# defender most often when the centre drew it), the stronger likelier
				var x := _pick(d_field, func(p): return PlayerForm.excl_commit_weight(p, e), rng)
				if x != null:
					theirs[x.id].ex += 1
		for id in mine:
			mine[id].ga = int(res.score[1 - side])
		var gk: PoloPlayer = att.starters()[0] if not att.starters().is_empty() else null
		if gk != null:
			mine[gk.id].sv = int(res.saves[side])
	return lines

## One of `list`, with odds by `weight`.
static func _pick(list: Array, weight: Callable, rng: RandomNumberGenerator) -> PoloPlayer:
	var total := 0.0
	for p in list:
		total += maxf(0.0, float(weight.call(p)))
	if list.is_empty() or total <= 0.0:
		return null
	var roll := rng.randf() * total
	for p: PoloPlayer in list:
		roll -= maxf(0.0, float(weight.call(p)))
		if roll <= 0.0:
			return p
	return list[list.size() - 1]

## What a game keeps of it in the schedule: {s, so, w, q, ot, sd, rt}: rt the two sides' BASE
## ratings it was played with (the team overall moves with the players during a season), and fd,
## the form, when either side had any (so the seed replays it exactly: replay).
static func result_of(res: Dictionary) -> Dictionary:
	var out := {"s": res.score, "so": res.so, "w": res.winner, "q": res.q, "ot": res.ot, "sd": res.seed}
	if res.has("rt"):
		out["rt"] = (res.rt as Array).map(func(side): return (side as Array).map(func(v): return roundi(float(v) * RT_PER)))
	var fd: Array = res.get("fd", [0, 0])
	if int(fd[0]) != 0 or int(fd[1]) != 0:
		out["fd"] = [int(fd[0]), int(fd[1])]
	return out

## A saved game played again from its result (`r`: result_of): the same seed, the same form and
## ratings (an older result without them: the teams' now).
static func replay(home: PoloTeam, away: PoloTeam, r: Dictionary, neutral := false) -> Dictionary:
	var rt: Array = r.get("rt", [])
	return play(home, away, int(r.sd), neutral, r.get("fd", [0, 0]), rt.map(func(x): return Array(x).map(func(v): return float(v) / RT_PER)))

## A result's ratings are kept as whole ten-thousandths (whole numbers, like the rest of the schedule).
const RT_PER := 10000.0

## [OVR, OFF, DEF] to 4 decimals, as a save keeps them (so a replay reads back what was played).
static func _snapped(r: Array) -> Array:
	return r.map(func(v): return snappedf(float(v), 0.0001))

## Five rounds each, then sudden death.
static func shootout(a: PoloTeam, b: PoloTeam, rng: RandomNumberGenerator) -> Array:
	var s := [0, 0]
	var teams := [a, b]
	var rounds := 0
	while true:
		rounds += 1
		for side in 2:
			var shooter := OppSim._pick_shooter(teams[side], rng)
			var gk: PoloPlayer = teams[1 - side].keeper()
			if rng.randf() < clampf(0.74 + (shooter.shoot - gk.keeping) * 0.004, 0.55, 0.9):
				s[side] += 1
		if rounds >= 5 and s[0] != s[1]:
			break
		if rounds < 5:
			var left := 5 - rounds
			if s[0] > s[1] + left or s[1] > s[0] + left:
				break
		if rounds > 30:
			s[rng.randi() % 2] += 1
			break
	return s
