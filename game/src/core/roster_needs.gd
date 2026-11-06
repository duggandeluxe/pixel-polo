class_name RosterNeeds
## ROSTER NEEDS (the Roster Needs & Recruiting Deadline update): next season's positional coverage,
## from the roster as it will be (Recruiting: this roster less the graduating seniors, plus the
## recruits actually signed; a pinned prospect is not a signing and never counts).
##
## The five needs are the starting seven's places by kind (PoloTeam.SLOTS):
##   GK   the goal                    C    the centre's place
##   2MD  the two-metre defender's    ATK  the two attackers' places (one may be a lefty's)
##   WG   the two wings' places (one may be a lefty's)
## Who can play where is the lineup's own rule (PoloTeam.fits), so a utility or a lefty counts
## wherever he may legally play, but a lineup is a real assignment: one man, one place (best_seven
## tries them). Statuses:
##   NEED     no legal seven fills this kind's places (red)
##   THIN     they're filled, but losing one man who can play them would leave a place empty, or
##            there's nobody spare for them (yellow)
##   COVERED  filled, and any one man who plays them can be lost with every place filled as
##            before (cyan)
## Nothing here is saved: it's worked out from the roster every time it's shown.

const GROUPS := ["GK", "C", "2MD", "ATK", "WG"]
## The lineup places (PoloTeam.SLOTS indices) of each kind.
const PLACES := {"GK": [0], "C": [1], "2MD": [4], "ATK": [3, 5], "WG": [2, 6]}
const NEED := "NEED"
const THIN := "THIN"
const COVERED := "COVERED"

## Next season's players: the returning ones (no seniors) and the signed incoming recruits;
## `extra`: more players to try (a prospect as if he were signed).
static func next_roster(c: Career, extra: Array = []) -> Array:
	var out: Array = c.team().roster.filter(func(p: PoloPlayer): return p.year < 4)
	for r in c.incoming:
		out.append(r.p)
	out.append_array(extra)
	return out

## The most places of the seven `players` can fill legally at once, one man a place (a maximum
## matching: Kuhn's augmenting paths, each place trying its natural men first): {filled (count),
## at (place -> player)}.
static func best_seven(players: Array) -> Dictionary:
	var owner := {}   # player -> place
	var at := {}      # place -> player
	for place in PoloTeam.FILL_ORDER:
		_augment(players, int(place), owner, at, {})
	return {"filled": at.size(), "at": at}

static func _augment(players: Array, place: int, owner: Dictionary, at: Dictionary, seen: Dictionary) -> bool:
	var cands: Array = players.filter(func(p: PoloPlayer): return PoloTeam.fits(p, place))
	cands.sort_custom(func(a: PoloPlayer, b: PoloPlayer): return PoloTeam.fit_rank(a, place) < PoloTeam.fit_rank(b, place))
	for p: PoloPlayer in cands:
		if seen.has(p):
			continue
		seen[p] = true
		if not owner.has(p) or _augment(players, int(owner[p]), owner, at, seen):
			owner[p] = place
			at[place] = p
			return true
	return false

## Can `players` field a complete legal seven?
static func legal(players: Array) -> bool:
	return int(best_seven(players).filled) == PoloTeam.STARTERS

## Who could play kind `g` at all (any of its places).
static func eligible(players: Array, g: String) -> Array:
	return players.filter(func(p: PoloPlayer): return (PLACES[g] as Array).any(func(i): return PoloTeam.fits(p, i)))

## Every kind's status for `players`: {g: {status, eligible (count), names}}, plus "ready":
## READY | DEPTH RECOMMENDED | NEEDS ATTENTION and "legal".
static func evaluate(players: Array) -> Dictionary:
	var seven := best_seven(players)
	var at: Dictionary = seven.at
	var full := int(seven.filled) == PoloTeam.STARTERS
	var out := {"legal": full}
	var any_need := false
	var any_thin := false
	for g in GROUPS:
		var places: Array = PLACES[g]
		var el := eligible(players, g)
		var status := COVERED
		if not places.all(func(i): return at.has(i)):
			status = NEED
		elif el.size() <= places.size():
			status = THIN   # (nobody spare who can play it)
		else:
			# depth: lose any one man who can play it, and its places must all still be filled with
			# nothing else lost (as many of the seven filled as before)
			for p in el:
				var after := best_seven(players.filter(func(q): return q != p))
				var ok := int(after.filled) == int(seven.filled) and places.all(func(i): return (after.at as Dictionary).has(i))
				if not ok:
					status = THIN
					break
		any_need = any_need or status == NEED
		any_thin = any_thin or status == THIN
		out[g] = {"status": status, "eligible": el.size(), "names": el.map(func(p: PoloPlayer): return p.short_name())}
	out["ready"] = "NEEDS ATTENTION" if any_need or not full else ("DEPTH RECOMMENDED" if any_thin else "READY")
	return out

## Next season's needs (evaluate(next_roster)).
static func of(c: Career, extra: Array = []) -> Dictionary:
	return evaluate(next_roster(c, extra))

## The kinds still NEED / THIN.
static func short_of(needs: Dictionary, status: String) -> Array:
	return GROUPS.filter(func(g): return String(needs[g].status) == status)

## Which NEED or THIN kinds signing `p` would improve (his tag on the market: TEAM NEED). Uses
## only his position (public), never his potential.
static func fills(c: Career, p: PoloPlayer, now: Dictionary = {}) -> Array:
	if now.is_empty():
		now = of(c)
	var after := of(c, [p])
	var rank := {NEED: 0, THIN: 1, COVERED: 2}
	return GROUPS.filter(func(g): return String(now[g].status) != COVERED and int(rank[String(after[g].status)]) > int(rank[String(now[g].status)]))

## The one-line strip's words: "GK THIN | C COVERED | ...".
static func strip_text(needs: Dictionary) -> String:
	return " | ".join(GROUPS.map(func(g): return "%s %s" % [g, needs[g].status]))
