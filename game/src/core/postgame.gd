class_name Postgame
extends RefCounted
## THE POSTGAME REVIEW: what the bulletin board shows after a career game, built once from the
## game's own recorded events (the match's box score, or a simmed game's result) and kept in the
## summary as `review`. A played game's numbers are all recorded; a simmed game's steals and
## turnovers are estimated from the rosters (`estimated`, marked on the board), and a stat
## nothing gives (a simmed game's 5 m penalties) is null and shows as "-".
##   team:    stat key -> [yours, theirs] (or null)
##   players: your seven who played: {pid, name, pos, year, gk, g, a, sh, st, bl, ed, sv, ga}
## The highlights (top scorer, playmaker, defender, keeper) and the COACH'S NOTES are read from
## those numbers alone, and the coaching events (CoachEvents) check their conditions against them.

## The team sheet's rows: key, label, and whether a simmed game has it.
const TEAM_ROWS := [["g", "GOALS"], ["sh", "SHOTS"], ["pct", "SHOOTING %"], ["a", "ASSISTS"], ["st", "STEALS"],
	["bl", "BLOCKS"], ["ed", "EXCL DRAWN"], ["ex", "EXCL COMMITTED"], ["pd", "5M DRAWN"], ["to", "TURNOVERS"]]

# ------------------------------------------------------------------ building it
## From a played match's box (MatchState.box with `them`): every event both sides recorded.
static func from_box(c: Career, box: Dictionary) -> Dictionary:
	var lines: Array = box.get("lines", [{}, {}])
	var th: Dictionary = box.get("them", {}).get("lists", {})
	var team := {
		"g": [_n(box.score[0]), _n(box.score[1])],
		"sh": [_sum(lines[0], "sh"), _sum(lines[1], "sh")],
		"a": [_count(box.get("assists")), _count(th.get("a"))],
		"st": [_count(box.get("steals")) + _count(box.get("keeper_steals")), _count(th.get("st"))],
		"bl": [_count(box.get("blocks")), _count(th.get("bl"))],
		"ed": [_count(box.get("excl_drawn")), _count(th.get("ed"))],
		"ex": [_count(box.get("excl")), _count(th.get("ex"))],
		"pd": [_count(box.get("pen_drawn")), _count(th.get("pd"))],
		"to": [_count(box.get("turnovers")), _count(th.get("to"))],
		"sv": [_n(box.get("saves", 0)), _n(box.get("them", {}).get("saves", 0))],
	}
	var players: Array = []
	for p: PoloPlayer in box.get("played", []):
		var ln: Dictionary = lines[0].get(p.id, {})
		players.append(_line(p, {"g": _count_of(box.get("goals"), p), "a": _count_of(box.get("assists"), p),
			"sh": int(ln.get("sh", 0)), "st": _count_of(box.get("steals"), p) + _count_of(box.get("keeper_steals"), p),
			"bl": _count_of(box.get("blocks"), p), "ed": _count_of(box.get("excl_drawn"), p),
			"sv": int(ln.get("sv", 0)), "ga": int(ln.get("ga", 0))}))
	return _finish(c, team, players, false)

## From a simmed game (GameSim.play's result, your side `side`, against `opp`): goals, assists,
## shots, blocks, exclusions drawn (and so committed: the other side's drawn) and the keepers'
## saves, as the sim made them. A sim doesn't play out steals or turnovers, so those are
## ESTIMATED from the two rosters (estimate_steals; `estimated` lists them, and the board marks
## them): seeded by the game, so the same game always shows the same numbers. 5 m penalties
## drawn aren't simulated at all: null.
static func from_sim(c: Career, res: Dictionary, side: int, opp: PoloTeam = null) -> Dictionary:
	var lines: Array = res.get("lines", [{}, {}])
	var us := c.team()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([c.year, c.week, c.school, res.score, res.saves])
	var est := estimate_steals(us, opp, rng) if opp != null else {"st": [0, 0], "to": [0, 0], "by": {}}
	var team := {
		"g": [_n(res.score[side]), _n(res.score[1 - side])],
		"sh": [_sum(lines[side], "sh"), _sum(lines[1 - side], "sh")],
		"a": [_count(res.assists[side]), _count(res.assists[1 - side])],
		"st": est.st, "bl": [_sum(lines[side], "bl"), _sum(lines[1 - side], "bl")],
		"ed": [_sum(lines[side], "ed"), _sum(lines[1 - side], "ed")],
		"ex": [_sum(lines[1 - side], "ed"), _sum(lines[side], "ed")], "pd": null, "to": est.to,
		"sv": [_n(res.saves[side]), _n(res.saves[1 - side])],
	}
	var players: Array = []
	for p: PoloPlayer in us.starters():
		var ln: Dictionary = lines[side].get(p.id, {})
		players.append(_line(p, {"g": _count_of(res.goals[side], p), "a": _count_of(res.assists[side], p),
			"sh": int(ln.get("sh", 0)), "st": int(est.by.get(p.id, 0)), "bl": int(ln.get("bl", 0)), "ed": int(ln.get("ed", 0)),
			"sv": int(ln.get("sv", 0)), "ga": int(ln.get("ga", 0))}))
	var rv := _finish(c, team, players, true)
	rv["estimated"] = ["st", "to"]
	return rv

## A simmed game's steals and turnovers, estimated from the rosters: each side's steals around
## STEALS_BASE, up with its field starters' DEFENSE against the other side's OFFENSE
## (PoloTeam.defense_display / offense_display); its turnovers are the other side's steals plus
## loose passes, more with weaker PASSING. Your steals are shared out among your field starters
## by their DEFENSE. {st: [yours, theirs], to: [yours, theirs], by: {pid: steals}}.
const STEALS_BASE := 4.0
const STEALS_PER_POINT := 0.12     # steals per point of DEFENSE over their OFFENSE
const LOOSE_BASE := 2.0
const LOOSE_PER_PASS := 0.5        # loose passes per point of field PASSING under 6
static func estimate_steals(us: PoloTeam, them: PoloTeam, rng: RandomNumberGenerator) -> Dictionary:
	var st := [0, 0]
	var to := [0, 0]
	var sides := [us, them]
	for i in 2:
		var mine: PoloTeam = sides[i]
		var other: PoloTeam = sides[1 - i]
		var mean := STEALS_BASE + (mine.defense_display() - other.offense_display()) * STEALS_PER_POINT
		st[i] = clampi(roundi(rng.randfn(mean, 1.2)), 0, 12)
	for i in 2:
		var mine: PoloTeam = sides[i]
		var pas := 0.0
		var field := mine.starters().filter(func(p: PoloPlayer): return not p.is_keeper())
		for p: PoloPlayer in field:
			pas += Attributes.value(p, "pas")
		pas /= maxf(1.0, field.size())
		var loose := LOOSE_BASE + maxf(0.0, 6.0 - pas) * LOOSE_PER_PASS
		to[i] = int(st[1 - i]) + clampi(roundi(rng.randfn(loose, 1.0)), 0, 8)
	# your steals, player by player: weighted by DEFENSE
	var by := {}
	var field: Array = us.starters().filter(func(p: PoloPlayer): return not p.is_keeper())
	var total := 0.0
	for p: PoloPlayer in field:
		total += maxf(0.5, Attributes.value(p, "dfn"))
	for k in int(st[0]):
		var pick := rng.randf() * total
		for p: PoloPlayer in field:
			pick -= maxf(0.5, Attributes.value(p, "dfn"))
			if pick <= 0.0:
				by[p.id] = int(by.get(p.id, 0)) + 1
				break
	return {"st": st, "to": to, "by": by}

static func _line(p: PoloPlayer, st: Dictionary) -> Dictionary:
	var out := {"pid": p.id, "name": p.short_name(), "last": p.last, "pos": p.pos, "year": p.year, "gk": p.is_keeper()}
	out.merge(st)
	return out

static func _finish(c: Career, team: Dictionary, players: Array, simmed: bool) -> Dictionary:
	var sh: Array = team.sh
	team["pct"] = [_pct(team.g[0], sh[0]), _pct(team.g[1], sh[1])]
	var rv := {"team": team, "players": players, "simmed": simmed, "streak": win_streak(c)}
	rv["notes"] = notes(rv, c.last_notes)
	c.last_notes = rv.notes.duplicate()
	return rv

static func _n(v) -> int:
	return int(v) if v != null else 0

static func _count(list) -> int:
	return (list as Array).size() if list is Array else 0

static func _count_of(list, p: PoloPlayer) -> int:
	return (list as Array).count(p) if list is Array else 0

static func _sum(lines: Dictionary, key: String) -> int:
	var n := 0
	for id in lines:
		n += int((lines[id] as Dictionary).get(key, 0))
	return n

## Goals as a share of shots, a whole percent (null without shots).
static func _pct(goals: int, shots: int):
	return roundi(100.0 * goals / shots) if shots > 0 else null

## Your wins in a row, counting back from your last game played.
static func win_streak(c: Career) -> int:
	var n := 0
	var games: Array = Schedule.team_games(c.schedule, c.school)
	for i in range(games.size() - 1, -1, -1):
		var g: Dictionary = games[i][1]
		if g.r == null:
			continue
		if Schedule.winner(g) != c.school:
			break
		n += 1
	return n

# ------------------------------------------------------------------ the highlights
## The player with the most of `key` (ties: more goals, then the lower id); null if nobody has any.
static func top(rv: Dictionary, score: Callable, keepers: bool = false) -> Dictionary:
	var best := {}
	var best_v := 0.0
	for pl in rv.players:
		if bool(pl.gk) != keepers:
			continue
		var v := float(score.call(pl))
		if v > best_v or (v == best_v and not best.is_empty() and int(pl.pid) < int(best.pid)):
			if v > 0.0:
				best = pl
				best_v = v
	return best

static func top_scorer(rv: Dictionary) -> Dictionary:
	return top(rv, func(pl): return int(pl.g) + int(pl.a) * 0.01)

static func top_playmaker(rv: Dictionary) -> Dictionary:
	return top(rv, func(pl): return int(pl.a) + int(pl.g) * 0.01)

## Steals and blocks (exclusions drawn to break a tie).
static func top_defender(rv: Dictionary) -> Dictionary:
	return top(rv, func(pl): return int(pl.st) + int(pl.bl) + int(pl.ed) * 0.01)

static func keeper(rv: Dictionary) -> Dictionary:
	for pl in rv.players:
		if pl.gk:
			return pl
	return {}

## A keeper's saves over the shots on him (saves and goals), 0..1 (0 without any).
static func save_pct(pl: Dictionary) -> float:
	var faced := int(pl.get("sv", 0)) + int(pl.get("ga", 0))
	return float(pl.get("sv", 0)) / faced if faced > 0 else 0.0

# ------------------------------------------------------------------ the coach's notes
## Two or three observations, each true of this game's numbers. Strongest first; a note that
## was on last game's board steps aside for another true one if there is one (it comes back
## when nothing else fits, so a pattern that goes on is still named).
static func notes(rv: Dictionary, last: Array = []) -> Array:
	var t: Dictionary = rv.team
	var cands: Array = []   # [priority, text]
	var g: Array = t.g
	var pct = t.pct[0]
	if pct != null and int(t.sh[0]) >= 8 and int(pct) < 30:
		cands.append([9, "WE STRUGGLED TO FINISH OUR CHANCES."])
	if pct != null and int(t.sh[0]) >= 8 and int(pct) >= 55:
		cands.append([7, "CLINICAL SHOOTING. WE TOOK OUR CHANCES."])
	if int(g[0]) >= 12:
		cands.append([8, "STRONG OFFENSIVE PERFORMANCE."])
	if int(g[1]) <= 6:
		cands.append([8, "STRONG DEFENSIVE PERFORMANCE."])
	if int(g[1]) >= 14:
		cands.append([8, "WE GAVE UP TOO MANY GOALS."])
	var k := keeper(rv)
	if not k.is_empty() and int(k.sv) >= 10 and save_pct(k) >= 0.6:
		cands.append([9, "OUR GOALKEEPER KEPT US IN THE GAME."])
	if t.to != null and int(t.to[0]) >= 8 and int(t.to[0]) > int(t.to[1]):
		cands.append([8, "BALL SECURITY NEEDS WORK."])
	if t.ex != null and int(t.ex[0]) >= 5 and int(t.ex[0]) > int(t.ex[1]):
		cands.append([7, "TOO MANY EXCLUSIONS COMMITTED."])
	if int(t.ed[0]) >= 5 and int(t.ed[0]) > int(t.ed[1]):
		cands.append([6, "WE DREW EXCLUSIONS ALL GAME."])
	if t.st != null and int(t.st[0]) >= 6:
		cands.append([6, "OUR HANDS WERE ACTIVE: %d STEALS." % int(t.st[0])])
	if int(t.a[0]) >= 6 and int(t.a[0]) >= int(g[0]) / 2:
		cands.append([6, "GREAT BALL MOVEMENT. %d ASSISTS." % int(t.a[0])])
	var cf := 0
	for pl in rv.players:
		if int(pl.pos) == PoloPlayer.Pos.CENTER:
			cf += int(pl.g)
	if cf >= 3:
		cands.append([6, "EXCELLENT CENTER SCORING."])
	if absi(int(g[0]) - int(g[1])) <= 1:
		cands.append([5, "A ONE-GOAL GAME. EVERY POSSESSION MATTERED."])
	if int(g[0]) - int(g[1]) >= 5:
		cands.append([5, "WE CONTROLLED THIS ONE FROM START TO FINISH."])
	if int(g[1]) - int(g[0]) >= 5:
		cands.append([5, "WE WERE OUTPLAYED. BACK TO WORK."])
	cands.sort_custom(func(a, b): return int(a[0]) > int(b[0]) if a[0] != b[0] else String(a[1]) < String(b[1]))
	var fresh: Array = cands.filter(func(cn): return not String(cn[1]) in last)
	var stale: Array = cands.filter(func(cn): return String(cn[1]) in last)
	var out: Array = (fresh + stale).slice(0, 3).map(func(cn): return String(cn[1]))
	if out.is_empty():
		out = ["A STEADY GAME. NOTHING STOOD OUT EITHER WAY."]
	return out
