class_name PoloTeam
extends RefCounted
## A club: identity, cap colours and a roster (seven in a career, a keeper and six field
## players, all in the water every game; your own program can carry three more on its bench).

const STARTERS := 7   # in the water at once, the keeper included
## Your lineup's places (the roster screen): the keeper, the six in the order the match lines
## them up (PlaySetup.TAGS: the centre, 1 the right wing, 2 the right flat, 3 the point, 4 the
## left flat, 5 the left wing), then the three on the bench.
const LINEUP_SPOTS := ["gk", "cf", "rw", "rf", "pt", "lf", "lw", "s1", "s2", "s3"]
## TEAM OVERALL (docs: "Retro Polo 2.0 — Complete Team Overall, Initial Roster Generation &
## Attribute-Based Gameplay System"): from the seven designated starters only, never stored.
##   EFFECTIVE stars = CURRENT stars (Attributes.stars_of his four attributes) + active HEAT UP stars
##   ACTUAL OVR = OVR_ZERO + OVR_PER_STAR x (sum of the seven's EFFECTIVE stars / 7), unrounded
##   DISPLAYED OVR = ACTUAL rounded once, at the end (display_ovr)
## Seven five-stars are 99; HEAT UP can take a man past five stars and the team past 100, uncapped.
## It is information only: nothing in the pool reads it (Tempo, ShotModel, KeeperDuel, Play).
const OVR_ZERO := 34.5
const OVR_PER_STAR := 13.0

var id := ""          # three-letter code for the scoreboard
var name := ""        # "Adriatic Orcas"
var c1 := Color.WHITE # primary (their caps when they wear dark)
var c2 := Color.BLACK # trim / numbers
var roster: Array[PoloPlayer] = []
# career only
var mascot := ""
var conf := ""
var prestige := 50.0
## The school's original overall (Colleges.SCHOOLS `ovr`): the INITIAL TEAM STRENGTH TARGET its
## very first roster is generated to (CollegeGen.make_initial_roster), in a brand-new career only.
## Kept for the record and never read again: team overall, the sims, recruiting, development and
## the pool all come from the players (team_overall). 0: none (a quick-match club, an older save).
var initial_strength_target := 0.0
var pool := Pools.DEFAULT_ID
var is_player := false
## Who plays where, set on the roster screen: player ids in LINEUP_SPOTS order, -1 an empty
## place. Empty (every AI team, an older save): the team picks its own seven (starters()).
var lineup: Array = []

## THE SEVEN STARTING PLACES (Position Identity update), the lineup's first seven in
## LINEUP_SPOTS order, each a kind (SLOTS). The match lines them up by PlaySetup.TAGS: cf the
## centre, rw "1" the right wing, rf "2" the right flat, pt "3" the point, lf "4", lw "5". The
## right side (rw, rf) is where a lefty plays: WG/LFTY and ATK/LFTY while there's a lefty on the
## roster (slot_name), plain WG and ATK otherwise.
##   GK      a keeper only
##   C       a centre or a 2MD (a centre first)
##   2MD     a 2MD, a centre or a utility (a 2MD first); in an emergency anybody (fill_places).
##           A utility is the coach's choice only: the team's own seven (fill_places) still puts
##           a centre or 2MD under the posts
##   ATK, WG an attacker, wing or utility, never a lefty
##   ATK/LFTY, WG/LFTY  an attacker, wing, utility or lefty: two lefties at most ever start
##   bench   anybody
enum Slot { GK, C, TWO_MD, ATK, WG, ATK_L, WG_L }
const SLOTS := [Slot.GK, Slot.C, Slot.WG_L, Slot.ATK_L, Slot.TWO_MD, Slot.ATK, Slot.WG]
const SLOT_NAMES := ["GK", "C", "2MD", "ATK", "WG", "ATK/LFTY", "WG/LFTY"]
const PERIMETER := [PoloPlayer.Pos.DRIVER, PoloPlayer.Pos.WING, PoloPlayer.Pos.UTILITY]
const POSTS := [PoloPlayer.Pos.CENTER, PoloPlayer.Pos.DEFENDER]
## The order fill_places fills the places in: goal, the two posts, the lefty places, the rest.
const FILL_ORDER := [0, 1, 4, 3, 2, 5, 6]

## The seven who play, in LINEUP_SPOTS order (SLOTS): your lineup's, a rolled man's place going
## to the best legal man from the bench (_lineup_starters), or the team's own position-aware
## seven (_auto_starters). Never more than seven.
func starters() -> Array[PoloPlayer]:
	# Remembered against everything the choice reads (_starters_key): a screen asks for the seven
	# dozens of times while it draws (OVR, OFF, DEF, power...), and working them out without a
	# lineup is ~1 ms each. Any change to the lineup or a player that matters picks them again.
	var key := _starters_key()
	if key != _st_key:
		_st_key = key
		_st_seven = _pick_starters()
	return _st_seven.duplicate()

var _st_key: Array = []
var _st_seven: Array[PoloPlayer] = []

## Everything starters() depends on: the lineup, and for every man on the roster (in order) who
## he is and what fill_places / _auto_starters / _lineup_starters read of him.
func _starters_key() -> Array:
	var k: Array = [lineup.duplicate()]
	for p in roster:
		k.append_array([p, p.id, p.pos, p.lefty, p.rolled, p.susp, p.overall(), p.keeping, p.pro,
			p.attrs.get("str"), p.attrs.get("dfn")])
	return k

func _pick_starters() -> Array[PoloPlayer]:
	if not lineup.is_empty():
		var seven := _lineup_starters()
		if seven.size() == STARTERS:
			return seven
	return _auto_starters()

## Any lefty on the roster, the bench too: the right side's places read ATK/LFTY and WG/LFTY.
func has_lefty() -> bool:
	return roster.any(func(q: PoloPlayer): return q.is_lefty())

## Starting place `i`'s name as the roster screen shows it ("" on the bench).
func slot_name(i: int) -> String:
	if i < 0 or i >= STARTERS:
		return ""
	var k: int = SLOTS[i]
	if not has_lefty():
		k = Slot.ATK if k == Slot.ATK_L else (Slot.WG if k == Slot.WG_L else k)
	return SLOT_NAMES[k]

## Can `p` play place `i` of the lineup (the rules above; the bench takes anybody).
static func fits(p: PoloPlayer, i: int) -> bool:
	return fit_rank(p, i) <= 1

## How well `p` fits place `i`: 0 his own (a centre at C, a 2MD at 2MD, an attacker at ATK, a
## wing at WG, a lefty or a utility on a lefty place...), 1 still legal, 2 only in an emergency
## (a field player anywhere in the field), 3 never by choice (a keeper in the field, a field
## player in goal: only when there is nobody else at all).
static func fit_rank(p: PoloPlayer, i: int) -> int:
	if i >= STARTERS:
		return 0
	var k: int = SLOTS[i]
	if (k == Slot.GK) != p.is_keeper():
		return 3
	match k:
		Slot.GK:
			return 0
		Slot.C:
			return 0 if p.pos == PoloPlayer.Pos.CENTER and not p.is_lefty() else (1 if p.pos == PoloPlayer.Pos.DEFENDER and not p.is_lefty() else 2)
		Slot.TWO_MD:
			if p.is_lefty():
				return 2
			if p.pos == PoloPlayer.Pos.DEFENDER:
				return 0
			return 1 if p.pos in [PoloPlayer.Pos.CENTER, PoloPlayer.Pos.UTILITY] else 2
		Slot.ATK_L, Slot.WG_L:
			if p.is_lefty():
				return 0
			return 1 if p.pos in PERIMETER else 2
		_:
			if p.is_lefty() or not p.pos in PERIMETER:
				return 2
			var own := PoloPlayer.Pos.DRIVER if k == Slot.ATK else PoloPlayer.Pos.WING
			return 0 if p.pos == own else 1

## How natural `p` is in place `i` (higher better; only to choose between legal men): his own
## position, then a utility, then the rest.
static func _natural(p: PoloPlayer, i: int) -> int:
	var k: int = SLOTS[i]
	if k in [Slot.ATK, Slot.ATK_L, Slot.WG, Slot.WG_L]:
		if p.is_lefty():
			return 3 if k == Slot.ATK_L else 2
		var own := PoloPlayer.Pos.DRIVER if k in [Slot.ATK, Slot.ATK_L] else PoloPlayer.Pos.WING
		return 2 if p.pos == own else (1 if p.pos == PoloPlayer.Pos.UTILITY else 0)
	return 2 - fit_rank(p, i)

## Is a seven (LINEUP_SPOTS order) legal: everybody where the rules let him, two lefties at most.
static func legal(seven: Array) -> bool:
	if seven.size() < STARTERS:
		return false
	for i in STARTERS:
		if seven[i] == null or not fits(seven[i], i):
			return false
	return true

## The lineup's seven, a place whose man can't play (ROLLED) going to the best legal man left
## (fill_places: the bench first, then anyone else on the roster; with only a lefty left for a
## plain ATK or WG, the right side shuffles so he plays there). Short of seven only when nobody
## at all is left.
func _lineup_starters() -> Array[PoloPlayer]:
	var seven: Array = []
	var spares: Array = []
	for i in range(STARTERS, lineup.size()):
		var q := find_id(int(lineup[i]))
		if q != null:
			spares.append(q)
	for q in roster:
		if not lineup.has(q.id):
			spares.append(q)
	for i in STARTERS:
		var p: PoloPlayer = find_id(int(lineup[i])) if i < lineup.size() else null
		seven.append(p if p != null and p.is_available() and not seven.has(p) else null)
	fill_places(seven, spares.filter(func(q: PoloPlayer): return q.is_available() and not seven.has(q)), true)
	var out: Array[PoloPlayer] = []
	for p in seven:
		if p == null:
			return out
		out.append(p)
	return out

## Fills the empty (null) places of `seven` (LINEUP_SPOTS order) from `pool`, in place:
##  1. goal, then the posts: the best legal men, a centre at C and a 2MD at 2MD where they can be,
##  2. the perimeter: the best legal men (two lefties at most, and only for the lefty places),
##     each where he's most natural,
##  3. a plain ATK or WG with only a lefty left: a righty on the right side moves over to it
##     and the lefty takes the right side (both legal),
##  4. anything still empty, an emergency: the best field player for it (a 2MD's place by
##     Strength and Defense, a lefty last), then a keeper in the field or a field player in goal.
## The best man is the best overall. `sub`: a substitution (a rolled man's place): one place on
## the perimeter goes to the man most natural in it (his own position, then a utility), the
## best of those.
static func fill_places(seven: Array, pool: Array, sub := false) -> void:
	pool = pool.duplicate()
	var better := func(a: PoloPlayer, b: PoloPlayer) -> bool:
		return a.overall() > b.overall() if not is_equal_approx(a.overall(), b.overall()) else a.id < b.id
	pool.sort_custom(better)
	# 1. goal, then the posts: the best legal men (a substitute: his own position first), a centre
	# at C and a 2MD at 2MD when they can be, two of a kind the better at his own place
	if seven[0] == null:
		seven[0] = _take(pool, func(q): return fit_rank(q, 0) == 0)
	var posts: Array = [1, 4].filter(func(i): return seven[i] == null)
	var men: Array = pool.filter(func(q): return fits(q, 1))
	if sub and posts.size() == 1:
		men.sort_custom(func(a, b): return fit_rank(a, posts[0]) < fit_rank(b, posts[0]) if fit_rank(a, posts[0]) != fit_rank(b, posts[0]) else better.call(a, b))
	men = men.slice(0, posts.size())
	if posts.size() == 2 and men.size() == 2:
		var as_is: int = fit_rank(men[0], 1) + fit_rank(men[1], 4)
		var turned: int = fit_rank(men[1], 1) + fit_rank(men[0], 4)
		if as_is > turned or (as_is == turned and men[0].pos == PoloPlayer.Pos.DEFENDER):
			men.reverse()
	for k in men.size():
		seven[posts[k]] = men[k]
		pool.erase(men[k])
	# 2. the perimeter
	var open: Array = [2, 3, 5, 6].filter(func(i): return seven[i] == null)
	var lefty_open: Array = open.filter(func(i): return i in [2, 3])
	var room := mini(2 - seven.filter(func(q): return q != null and q.is_lefty()).size(), lefty_open.size())
	var picked: Array = []
	if sub and open.size() == 1:
		var i: int = open[0]
		var cands: Array = pool.filter(func(q): return fits(q, i) and (not q.is_lefty() or room > 0))
		cands.sort_custom(func(a, b): return _natural(a, i) > _natural(b, i) if _natural(a, i) != _natural(b, i) else better.call(a, b))
		picked = cands.slice(0, 1)
	for q: PoloPlayer in ([] if sub and open.size() == 1 else pool):
		if picked.size() >= open.size():
			break
		if not q.is_keeper() and q.pos in PERIMETER and not q.is_lefty():
			picked.append(q)
		elif q.is_lefty() and picked.filter(func(x): return x.is_lefty()).size() < room:
			picked.append(q)
	for q in picked:
		pool.erase(q)
	_place_perimeter(seven, open, picked)
	# 3. a lefty for a plain place: shuffle the right side
	for i in [5, 6]:
		if seven[i] != null:
			continue
		var lefty: PoloPlayer = _take(pool, func(q): return q.is_lefty(), false)
		if lefty == null or seven.filter(func(q): return q != null and q.is_lefty()).size() >= 2:
			break
		for j in [3, 2]:
			if seven[j] != null and not seven[j].is_lefty() and fits(seven[j], i):
				seven[i] = seven[j]
				seven[j] = lefty
				pool.erase(lefty)
				break
	# 4. emergencies
	var wrestle := func(a: PoloPlayer, b: PoloPlayer) -> bool:
		if a.is_lefty() != b.is_lefty():
			return b.is_lefty()
		var sa := a.attr("str") + a.attr("dfn")
		var sb := b.attr("str") + b.attr("dfn")
		return sa > sb if not is_equal_approx(sa, sb) else better.call(a, b)
	for i in FILL_ORDER:
		if seven[i] != null:
			continue
		var cands: Array = pool.filter(func(q): return fit_rank(q, i) <= 2)
		if i in [1, 4]:
			cands.sort_custom(wrestle)
		else:
			cands.sort_custom(func(a, b): return b.is_lefty() if a.is_lefty() != b.is_lefty() else better.call(a, b))
		if cands.is_empty():
			cands = pool.duplicate()
			if i == 0:
				cands.sort_custom(func(a, b): return a.keeping > b.keeping)
		if not cands.is_empty():
			seven[i] = cands[0]
			pool.erase(cands[0])

## The first man in `pool` `ok` with (taken out of it); null if none.
static func _take(pool: Array, ok: Callable, erase := true) -> PoloPlayer:
	for q: PoloPlayer in pool:
		if ok.call(q):
			if erase:
				pool.erase(q)
			return q
	return null

## Puts `men` into the places `open` (perimeter, LINEUP_SPOTS indexes): every lefty on a lefty
## place, everybody else wherever he's most natural (the best of every arrangement: four places
## at most).
static func _place_perimeter(seven: Array, open: Array, men: Array) -> void:
	if men.is_empty():
		return
	var best: Array = []
	var best_score := -1
	for perm in _perms(open, men.size()):
		var score := 0
		var ok := true
		for k in men.size():
			if not fits(men[k], perm[k]):
				ok = false
				break
			score += _natural(men[k], perm[k])
		if ok and score > best_score:
			best_score = score
			best = perm
	if best.is_empty():
		return
	for k in men.size():
		seven[best[k]] = men[k]

## Every ordered choice of `n` of `items`.
static func _perms(items: Array, n: int) -> Array:
	if n == 0:
		return [[]]
	var out: Array = []
	for i in items.size():
		var rest := items.duplicate()
		rest.remove_at(i)
		for tail in _perms(rest, n - 1):
			out.append([items[i]] + tail)
	return out

## Clears every ROLLED flag (a game's over, or a new one starts).
static func clear_rolls(t: PoloTeam) -> void:
	for p in t.roster:
		p.rolled = false

## Has the coach set who plays where?
func has_lineup() -> bool:
	return not lineup.is_empty()

## Keeps the lineup in step with the roster and legal: anyone gone leaves his place empty, a
## starter where he can't play (an older save, a lefty in a plain place) goes to the bench, an
## empty starting place goes to the best legal man (fill_places: the bench first, then a
## newcomer), and newcomers fill the empty bench places, best first. Anyone past the ten stays
## on the roster, off the lineup. A no-op with no lineup.
func sync_lineup() -> void:
	if lineup.is_empty():
		return
	var seen := {}
	var out: Array = []
	for i in LINEUP_SPOTS.size():
		var pid := int(lineup[i]) if i < lineup.size() else -1
		out.append(pid if find_id(pid) != null and not seen.has(pid) else -1)
		seen[pid] = true
	var seven: Array = []
	var lefties := 0
	var benched: Array = []
	for i in STARTERS:
		var q := find_id(int(out[i]))
		if q != null and q.is_lefty():
			lefties += 1
		if q != null and (not fits(q, i) or (q.is_lefty() and lefties > 2)):
			benched.append(q)
			q = null
		seven.append(q)
	var bench: Array = []
	for j in range(STARTERS, out.size()):
		var q := find_id(int(out[j]))
		if q != null:
			bench.append(q)
	var free: Array = roster.filter(func(q: PoloPlayer): return not out.has(q.id))
	free.sort_custom(func(a: PoloPlayer, b: PoloPlayer): return a.overall() > b.overall())
	fill_places(seven, bench + benched + free)
	# the bench keeps its places; whoever left it for the seven leaves his place empty, and a
	# benched starter, then the newcomers (best first), take the empty ones
	var waiting: Array = (benched + free).filter(func(q): return not seven.has(q))
	for i in STARTERS:
		out[i] = seven[i].id if seven[i] != null else -1
	for j in range(STARTERS, out.size()):
		var q := find_id(int(out[j]))
		if q != null and seven.has(q):
			out[j] = -1
	for j in range(STARTERS, out.size()):
		if out[j] == -1 and not waiting.is_empty():
			out[j] = (waiting.pop_front() as PoloPlayer).id
	lineup = out

## The team's own seven (no lineup), position-aware: the best legal man for every place
## (fill_places), not just the best seven. An injured keeper keeps his place.
func _auto_starters() -> Array[PoloPlayer]:
	var fit := roster.filter(func(p: PoloPlayer): return p.is_available())
	var keepers := fit.filter(func(p: PoloPlayer): return p.is_keeper())
	# (by permanent quality: an injured keeper keeps his place, PoloPlayer.is_available)
	var kq := func(p: PoloPlayer) -> float: return float(p.keeping) if p.pro else p.overall()
	keepers.sort_custom(func(a: PoloPlayer, b: PoloPlayer): return a.overall() > b.overall() if kq.call(a) == kq.call(b) else kq.call(a) > kq.call(b))
	var seven: Array = [null, null, null, null, null, null, null]
	if not keepers.is_empty():
		seven[0] = keepers[0]
	fill_places(seven, fit.filter(func(p): return p != seven[0]))
	var out: Array[PoloPlayer] = []
	for p in seven:
		if p != null:
			out.append(p)
	return out

## Cuts the roster down to `size` (for saves from the 16-man days): the seven who start (so the
## team on the field is the one it was), then the best keeper, center and center-D, the best two
## drivers and two utilities, then the best field players left. With no keeper on the roster,
## whoever keeps goal best stays. Returns the players let go.
func trim_to(size: int) -> Array[PoloPlayer]:
	var cut: Array[PoloPlayer] = []
	if roster.size() <= size:
		return cut
	if size == STARTERS:
		return _keep_seven()
	var pool: Array = roster.duplicate()
	pool.sort_custom(func(a: PoloPlayer, b: PoloPlayer): return a.overall() > b.overall())
	var keep: Array = []
	for p in starters().slice(0, mini(size, STARTERS)):
		keep.append(p)
		pool.erase(p)
	for pos in CollegeGen.ROSTER_POS:
		if keep.size() >= size or keep.any(func(q: PoloPlayer): return q.pos == pos):
			continue
		for p: PoloPlayer in pool:
			if p.pos == pos:
				keep.append(p)
				pool.erase(p)
				break
	if not keep.any(func(p: PoloPlayer): return p.is_keeper()):
		var best: PoloPlayer = pool[0]
		for p: PoloPlayer in pool:
			if p.keeping > best.keeping:
				best = p
		keep.append(best)
		pool.erase(best)
	# the last spots: the best field players, a second keeper only if nobody else is left
	var field := pool.filter(func(p: PoloPlayer): return not p.is_keeper())
	var rest := pool.filter(func(p: PoloPlayer): return p.is_keeper())
	for p in field + rest:
		if keep.size() >= size:
			break
		keep.append(p)
	for p in roster:
		if not keep.has(p):
			cut.append(p)
	roster = roster.filter(func(p: PoloPlayer): return keep.has(p))
	return cut

## Down to the seven-man roster (an older save's bigger one): the seven who started, so the
## team on the field is the one it was. Returns the players let go.
func _keep_seven() -> Array[PoloPlayer]:
	var keep := starters()
	var cut: Array[PoloPlayer] = []
	for p in roster:
		if not keep.has(p):
			cut.append(p)
	roster = roster.filter(func(p: PoloPlayer): return keep.has(p))
	return cut

func keeper() -> PoloPlayer:
	return starters()[0]

func attack_rating() -> float:
	var s := starters().slice(1)
	var total := 0.0
	for p: PoloPlayer in s:
		total += p.shoot * 0.45 + p.passing * 0.3 + p.speed * 0.25
	return total / maxf(1.0, s.size())

func defense_rating() -> float:
	var s := starters().slice(1)
	var total := 0.0
	for p: PoloPlayer in s:
		total += p.defense * 0.5 + p.strength * 0.25 + p.speed * 0.25
	return total / maxf(1.0, s.size())

func find(number: int) -> PoloPlayer:
	for p in roster:
		if p.number == number:
			return p
	return null

func find_id(pid: int) -> PoloPlayer:
	for p in roster:
		if p.id == pid:
			return p
	return null

## The caps this team wears against the other side's `other` caps: its primary colour, or its
## second one when the primary would be hard to tell apart (a light primary against white caps).
func cap_against(other: Color) -> Color:
	return c2 if _clash(c1, other) and not _clash(c2, other) else c1

## The trim on those caps: the team colour the cap isn't.
func trim_against(other: Color) -> Color:
	return c1 if cap_against(other) == c2 and c1 != c2 else c2

static func _clash(a: Color, b: Color) -> bool:
	var d := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
	return absf(a.get_luminance() - b.get_luminance()) < 0.25 and d < 0.5

## ------------------------------------------------------------------ TEAM OVERALL
## ACTUAL OVR for an average of `avg_stars` a starter, and back (the stars a starter it asks for).
static func ovr_for_stars(avg_stars: float) -> float:
	return OVR_ZERO + OVR_PER_STAR * avg_stars

static func stars_for_ovr(ovr_value: float) -> float:
	return (ovr_value - OVR_ZERO) / OVR_PER_STAR

## DISPLAYED OVR: ACTUAL rounded to the nearest whole number, an exact half down (99.5, seven
## five-stars, is the spec's 99). Snapped first so float dust never decides a half.
static func display_ovr(actual: float) -> int:
	return int(ceilf(snappedf(actual, 0.000001) - 0.5))

## A man's HEAT UP stars while they're active: the red stars his form shows (one HOT, two VERY HOT).
static func heat_stars(p: PoloPlayer) -> int:
	return PlayerForm.red_stars(p.form_state())

## His EFFECTIVE stars for the team overall: CURRENT plus active HEAT UP, never capped at five.
static func ovr_stars(p: PoloPlayer, with_heat: bool = true) -> float:
	return p.stars + (float(heat_stars(p)) if with_heat else 0.0)

## ACTUAL OVR (unrounded) of the seven designated starters (starters()); the bench never counts.
## A place nobody can fill counts as no stars. `with_heat` false: permanent stars only.
func team_overall(with_heat: bool = true) -> float:
	var total := 0.0
	for p: PoloPlayer in starters():
		total += ovr_stars(p, with_heat)
	return ovr_for_stars(total / STARTERS)

## The team's OVR as every screen shows it (HEAT UP included).
func overall_display() -> int:
	return display_ovr(team_overall(true))

## BASE OVR: permanent stars only (HEAT UP left out), displayed.
func base_ovr() -> int:
	return display_ovr(team_overall(false))

## LIVE OVR: with the seven's active HEAT UP stars (the same as overall_display).
func live_ovr() -> int:
	return overall_display()

## The team's overall rating, unrounded (HEAT UP included): what the lists, polls, schedule
## and recruiting read. Always the players' (team_overall); never a stored number.
func rating() -> float:
	return team_overall(true)

## OFF and DEF, either side of the permanent OVR by the starters' own lean: how much better the
## six field starters' PASSING and SHOOTING are than their STRENGTH and DEFENSE (STYLE_PER_POINT
## rating points per attribute point, STYLE_MAX at most). OVR is always their average.
const STYLE_PER_POINT := 3.25
const STYLE_MAX := 4.0

func style() -> float:
	var field := starters().filter(func(p: PoloPlayer): return not p.is_keeper())
	if field.is_empty():
		return 0.0
	var gap := 0.0
	for p: PoloPlayer in field:
		gap += (Attributes.value(p, "pas") + Attributes.value(p, "sho") - Attributes.value(p, "str") - Attributes.value(p, "dfn")) / 2.0
	return clampf(gap / field.size() * STYLE_PER_POINT, -STYLE_MAX, STYLE_MAX)

func off_rating() -> float:
	return team_overall(false) + style()

func def_rating() -> float:
	return team_overall(false) - style()

## [OVR, OFF, DEF] from the roster as it is now, permanent stars only (what the scoring engine
## plays with, GameSim.sim_ratings, and the season's snapshot).
func ratings() -> Array:
	var o := team_overall(false)
	var st := style()
	return [o, o + st, o - st]

## ------------------------------------------------------------------ OFFENSE, DEFENSE, GOALKEEPING
## The team's displayed OFFENSE, DEFENSE and GOALKEEPING (every screen that shows them): straight
## from the same seven starters as the overall, their permanent 0-10 attributes (HEAT UP and
## injuries never move them), each a weighted average on 0-10 then ROUND(score / 10 x 99),
## 0..99. OFFENSE and DEFENSE are the field starters' average, GOALKEEPING the starting keeper's.
## Always worked out from the players now, so a new starter or an upgrade shows at once. (The
## scoring engine keeps its own numbers, ratings().)
const OFFENSE_WEIGHTS := {"sho": 0.40, "pas": 0.35, "str": 0.25}
const DEFENSE_WEIGHTS := {"dfn": 0.65, "str": 0.35}
const KEEPING_WEIGHTS := {"blk": 0.35, "lun": 0.30, "leg": 0.20, "com": 0.15}

## A 0-10 score on the 0-99 team scale.
static func rating_99(score: float) -> int:
	return clampi(roundi(snappedf(score / Attributes.MAX * 99.0, 0.000001)), 0, 99)

static func _weighted(p: PoloPlayer, weights: Dictionary) -> float:
	var s := 0.0
	for k in weights:
		s += Attributes.value(p, k) * float(weights[k])
	return s

## The six field starters' average weighted score (0-10); 0 with none.
func _field_score(weights: Dictionary) -> float:
	var field := starters().filter(func(p: PoloPlayer): return not p.is_keeper())
	if field.is_empty():
		return 0.0
	var total := 0.0
	for p: PoloPlayer in field:
		total += _weighted(p, weights)
	return total / field.size()

func offense_score() -> float:
	return _field_score(OFFENSE_WEIGHTS)

func defense_score() -> float:
	return _field_score(DEFENSE_WEIGHTS)

## The starting keeper's weighted score (0-10); 0 with no keeper in the seven.
func keeping_score() -> float:
	var seven := starters()
	return _weighted(seven[0], KEEPING_WEIGHTS) if not seven.is_empty() and seven[0].is_keeper() else 0.0

## A team OFF or DEF overall (offense_display, defense_display) as stars, the way every screen
## shows it (the Offensive & Defensive Star Ratings update): the nearest half of rating / 20, 0-5.
## Display only: the number itself is what the game plays with.
static func rating_stars(rating: float) -> float:
	return clampf(roundf(rating / 10.0) * 0.5, 0.0, 5.0)

func offense_display() -> int:
	return rating_99(offense_score())

func defense_display() -> int:
	return rating_99(defense_score())

func goalkeeping_display() -> int:
	return rating_99(keeping_score())

## The scoring engine's HEAT UP term (GameSim.live_ratings), unchanged from before the 2.0 team
## overall: how far the seven's form moves the average of their PlayerForm star points, in
## rating points. The sims' existing HEAT UP effect, not the team overall.
func form_delta() -> int:
	return _star_avg(func(p: PoloPlayer): return p.eff_star_value()) - _star_avg(func(p: PoloPlayer): return p.star_value())

func _star_avg(stars_of: Callable) -> int:
	var seven := starters()
	if seven.is_empty():
		return 0
	var total := 0.0
	for p: PoloPlayer in seven:
		total += PlayerForm.star_points(float(stars_of.call(p)))
	return roundi(total / seven.size())

## Strength on a 0-100 scale from the roster: attack, defence and the keeper.
func power() -> float:
	return attack_rating() * 0.4 + defense_rating() * 0.35 + float(keeper().keeping) * 0.25

## The roster's attacking strength (moves OFF at the roster lock).
func off_power() -> float:
	return attack_rating()

## The roster's defending strength, the keeper included (moves DEF at the roster lock).
func def_power() -> float:
	return defense_rating() * 0.58 + float(keeper().keeping) * 0.42

## A free cap number for a newcomer (1 and 13 are the keepers' caps).
func free_number(keeper_cap: bool) -> int:
	var used := {}
	for p in roster:
		used[p.number] = true
	var options: Array = [1, 13, 21] if keeper_cap else range(2, 13) + range(14, 21) + range(22, 30)
	for n in options:
		if not used.has(n):
			return n
	return 99

func to_dict() -> Dictionary:
	return {"id": id, "name": name, "c1": c1.to_html(false), "c2": c2.to_html(false),
		"mascot": mascot, "conf": conf, "prestige": snappedf(prestige, 0.0001), "pool": pool, "is_player": is_player,
		"init_target": initial_strength_target,
		"roster": roster.map(func(p: PoloPlayer): return p.to_dict())}.merged({"lineup": lineup} if not lineup.is_empty() else {})

static func from_dict(d: Dictionary) -> PoloTeam:
	var t := PoloTeam.new()
	t.id = String(d.get("id", ""))
	t.name = String(d.get("name", ""))
	t.c1 = Color(String(d.get("c1", "ffffff")))
	t.c2 = Color(String(d.get("c2", "000000")))
	t.mascot = String(d.get("mascot", ""))
	t.conf = String(d.get("conf", ""))
	t.prestige = float(d.get("prestige", 50.0))
	t.pool = String(d.get("pool", Pools.DEFAULT_ID))
	t.is_player = bool(d.get("is_player", false))
	# (an older save's locked OVR, OFF and DEF are left unread: the overall is the players')
	t.initial_strength_target = float(d.get("init_target", 0.0))
	for pd in d.get("roster", []):
		t.roster.append(PoloPlayer.from_dict(pd))
	PlayerForm.trim_hot(t)   # (a save from before the HOT SLOTS cap: never more than three hot)
	t.lineup = Array(d.get("lineup", [])).map(func(v): return int(v))
	return t
