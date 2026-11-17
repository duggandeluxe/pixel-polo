class_name CollegeGen
## Seeded generation for the college world: names, players, rosters and recruits.

## Every starting seven (Position Identity update): a keeper, a centre, a 2MD, two attackers and
## two wings, one for each of PoloTeam's starting places...
const ROSTER_POS := [
	PoloPlayer.Pos.GK, PoloPlayer.Pos.CENTER, PoloPlayer.Pos.DEFENDER,
	PoloPlayer.Pos.DRIVER, PoloPlayer.Pos.DRIVER,
	PoloPlayer.Pos.WING, PoloPlayer.Pos.WING,
]
## ...and everyone else made (a sub, a prospect, a walk-on) at these odds of a field player: C 15%,
## 2MD 17%, ATK 30%, WG 28%, UT 10% (field_pos). Keepers are made on their own: KEEPER_SHARE of
## the prospects, a sub only where a team needs one.
const FIELD_WEIGHTS := {PoloPlayer.Pos.CENTER: 15, PoloPlayer.Pos.DEFENDER: 17, PoloPlayer.Pos.DRIVER: 30,
	PoloPlayer.Pos.WING: 28, PoloPlayer.Pos.UTILITY: 10}
const KEEPER_SHARE := 1.0 / 13.0
## An attacker this often shoots left-handed (a LFTY). Nobody else is ever made a lefty.
const LEFTY_SHARE := 0.08
## The seven-man program: how many of each position it carries, the shape above. Older saves'
## bigger rosters are cut to their starting seven (PoloTeam.trim_to).
const ROSTER_SHAPE := {PoloPlayer.Pos.GK: 1, PoloPlayer.Pos.CENTER: 1, PoloPlayer.Pos.DEFENDER: 1,
	PoloPlayer.Pos.DRIVER: 2, PoloPlayer.Pos.WING: 2}
## Depth is built this far below the team's level, so the starting seven stay the starters.
const DEPTH_DROP := 7.0
## The ten depth players' class years: with the first eight's two per year, 5 FR, 5 SO, 4 JR, 4 SR.
const DEPTH_YEARS := [1, 2, 3, 4, 1, 2, 3, 4, 1, 2]
const YEAR_BONUS := [0.0, -4.0, -1.0, 2.0, 4.0]
## A high-school prospect's shape (make_prospect): what his position tends to be good at, an
## attribute's lean off his average (a point is a point of attribute). Tendencies, never rules:
## each prospect's lean is scaled by LEAN_SCALE, OFF_TYPE of them lean some other way altogether,
## and every attribute gets NOISE on top. A keeper picks one of KEEPER_TYPES.
## C Strength and Shooting, 2MD Strength and Defense, ATK (and LFTY) Shooting and Passing, WG
## Passing and Shooting, UT balanced.
const LEANS := {
	PoloPlayer.Pos.CENTER: {"str": 1.3, "sho": 1.0, "pas": -1.1, "dfn": -1.2},
	PoloPlayer.Pos.DEFENDER: {"str": 1.1, "dfn": 1.3, "sho": -1.2, "pas": -1.2},
	PoloPlayer.Pos.DRIVER: {"sho": 1.3, "pas": 1.0, "str": -1.2, "dfn": -1.1},
	PoloPlayer.Pos.WING: {"pas": 1.3, "sho": 1.0, "str": -1.2, "dfn": -1.1},
	PoloPlayer.Pos.UTILITY: {},
}
const KEEPER_TYPES := [
	{"blk": 1.4, "leg": 0.4, "lun": -0.8, "com": -1.0},    # the shot blocker
	{"lun": 1.4, "blk": 0.3, "leg": -0.7, "com": -1.0},    # quick off the mark
	{"com": 1.5, "blk": -0.3, "lun": -0.5, "leg": -0.7},   # the organiser
	{"leg": 1.3, "blk": 0.4, "com": -0.6, "lun": -1.1},    # up high and long
	{},                                                    # balanced
]
const LEAN_SCALE := Vector2(0.5, 1.5)
const OFF_TYPE := 0.25
const NOISE := 0.85
## A five-star's average is drawn from 8.0 up to this (the top step has no ceiling but 10).
const TOP_AVERAGE := 9.6
## Walk-ons: about a 1-2 star prospect.
const WALKON_LEVEL := 46.0
## Where college water polo players come from: mostly home-grown, plus the big polo nations.
const NAME_GROUPS := {"anglo": 60, "balkan": 9, "hungarian": 7, "italian": 6, "spanish": 6,
	"greek": 5, "dutch": 3, "german": 2, "portuguese": 2}
## Famous real water polo players: never generated.
const BANNED := ["Filipovic", "Udovicic", "Mandic", "Prlainovic", "Pijetlovic", "Rasovic",
	"Jaksic", "Dedovic", "Manhercz", "Kasas", "Benedek", "Estiarte", "Pozzi", "Fiorentini",
	"Vujasinovic", "Sapic", "Kovacevic"]

static func team_quality(prestige: float) -> float:
	return 40.0 + prestige * 0.35

## Team OVR -> the player level its roster is built around. Player ratings keep their own
## scale (recruits, training caps): a league-average OVR of 76 gets the league's usual roster,
## and the official numbers spread the rosters out from there.
const OVR_TO_QUALITY := 0.3

static func quality_for_ovr(ovr: float) -> float:
	return 59.0 + (ovr - 76.0) * OVR_TO_QUALITY

static func _pick(rng: RandomNumberGenerator, arr: Array) -> Variant:
	return arr[rng.randi() % arr.size()]

static func name_group(rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in NAME_GROUPS:
		total += int(NAME_GROUPS[k])
	var r := rng.randi() % total
	for k in NAME_GROUPS:
		r -= int(NAME_GROUPS[k])
		if r < 0:
			return k
	return "anglo"

## [first, last], avoiding last names already in `used` and banned names.
static func random_name(rng: RandomNumberGenerator, used: Dictionary = {}) -> Array:
	var first := ""
	var last := ""
	for _i in 30:
		var grp: Dictionary = NamesData.GROUPS.get(name_group(rng), NamesData.GROUPS["anglo"])
		first = _pick(rng, grp["M"])
		last = _pick(rng, grp["L"])
		if last.length() <= 11 and not used.has(last) and not last in BANNED and not last in NamesData.BANNED_SURNAMES:
			break
	used[last] = true
	return [first, last]

static func coach_name(rng: RandomNumberGenerator) -> Array:
	var grp: Dictionary = NamesData.GROUPS["anglo"]
	return [_pick(rng, NamesData.COACH_FIRST), _pick(rng, grp["L"])]

## One player around `quality` for his position, with growth room that shrinks with age.
static func make_player(rng: RandomNumberGenerator, pos: int, quality: float, year: int, used: Dictionary) -> PoloPlayer:
	var p := League._make_player(pos, quality + YEAR_BONUS[clampi(year, 1, 4)], rng, used)
	var nm := random_name(rng, used)
	p.first = nm[0]
	p.last = nm[1]
	p.year = year
	p.age = 17 + year + (1 if rng.randf() < 0.3 else 0)
	if not p.is_keeper():
		p.keeping = rng.randi_range(12, 30)
	var room: float = [0.0, rng.randf_range(6, 20), rng.randf_range(4, 15), rng.randf_range(2, 10), rng.randf_range(0, 5)][clampi(year, 1, 4)]
	p.pot = minf(97.0, p.overall() + room)
	PlayerForm.rate_new(p)
	p.trait_id = Traits.best_for(p)
	return p

## ------------------------------------------------------------------ the initial roster
## A brand-new career's rosters (docs: "Retro Polo 2.0 — Complete Team Overall, Initial Roster
## Generation & Attribute-Based Gameplay System"), the only place a school's original overall is
## used: as its INITIAL TEAM STRENGTH TARGET.
##   1. target average starter stars = (target - PoloTeam.OVR_ZERO) / PoloTeam.OVR_PER_STAR
##   2. seven CURRENT star ratings around it (starter_stars): each starter drawn STARTER_SPREAD
##      either side of it, then moved half a star at a time (a bounded number of steps) until the
##      seven's team overall displays as the target, or as near as half stars can get
##   3. every starter's four attributes made for his position and fitted to his stars
##      (make_starter: whole points, LEANS / KEEPER_TYPES, NOISE); his stars are read back from
##      them, never set, and the team overall is checked from those (fix_total)
##   4. his ceilings from a development profile (Recruiting.DEV_PROFILES), the room shrinking with
##      his class year (YEAR_ROOM): talent now, not a promise about later
##   5. a bench only where the roster has room for one (your program: Career.roster_cap), made
##      after the seven are final and never part of the team overall (the lineup keeps the seven)
## Nothing here runs again: not on loading a save, not in a new season.
const STARTER_SPREAD := 0.45   # stars, one starter's spread around the team's target
const MAX_STEPS := 120         # half-star moves at most, fitting the seven to the target
const BENCH_DROP := 0.35       # a sub's stars are drawn this far below the target...
const BENCH_SPREAD := 0.6      # ...this far either side
const BENCH_YEARS := [1, 1, 2, 2, 3, 4]   # subs are mostly underclassmen
## A starter's share of his development profile's room, by class year (a senior has used most of it).
const YEAR_ROOM := [1.0, 1.0, 0.75, 0.5, 0.25]
const ROSTER_SCREEN := "res://src/ui/screens/roster.gd"   # (its formation(): lineup_of)

## The average CURRENT stars a starter that a team of overall `target` asks for.
static func target_stars(target: float) -> float:
	return PoloTeam.stars_for_ovr(target)

## ACTUAL team overall for seven starters whose stars add up to `total`.
static func ovr_of_total(total: float) -> float:
	return PoloTeam.ovr_for_stars(total / PoloTeam.STARTERS)

## The total of seven half-star ratings (0.5 .. 5 each) whose team overall comes closest to
## `target`: a displayed match first, then the nearest ACTUAL overall.
static func best_total(target: float) -> float:
	var best := -1.0
	var best_key := Vector2(INF, INF)
	var n := PoloTeam.STARTERS
	for h in range(n, n * 10 + 1):   # (half stars: 0.5 x 7 .. 5 x 7)
		var total := h * 0.5
		var actual := ovr_of_total(total)
		var key := Vector2(absf(PoloTeam.display_ovr(actual) - target), absf(actual - target))
		if key.x < best_key.x or (key.x == best_key.x and key.y < best_key.y):
			best_key = key
			best = total
	return best

## Seven CURRENT star ratings (half stars, 0.5 .. 5) for a team of overall `target`, natural and
## never all alike when the total allows it; they add up to best_total(target).
static func starter_stars(rng: RandomNumberGenerator, target: float) -> Array:
	var avg := target_stars(target)
	var want := best_total(target)
	var stars: Array = []
	for _i in PoloTeam.STARTERS:
		stars.append(clampf(PlayerForm.snap_half(avg + rng.randfn(0.0, STARTER_SPREAD)), 0.5, Attributes.MAX / 2.0))
	_fit_total(rng, stars, want)
	# never seven of the same: one up, one down, the total kept
	var same := stars.all(func(v): return is_equal_approx(float(v), float(stars[0])))
	if same and float(stars[0]) > 0.5 and float(stars[0]) < 5.0:
		var i := rng.randi_range(0, stars.size() - 1)
		var j := (i + 1 + rng.randi_range(0, stars.size() - 2)) % stars.size()
		stars[i] = float(stars[i]) + 0.5
		stars[j] = float(stars[j]) - 0.5
	return stars

## Moves half stars (one random rating with room each time, at most MAX_STEPS) until `stars` add
## up to `want`.
static func _fit_total(rng: RandomNumberGenerator, stars: Array, want: float) -> void:
	for _i in MAX_STEPS:
		var total := 0.0
		for v in stars:
			total += float(v)
		if is_equal_approx(total, want):
			return
		var up := total < want
		var open: Array = []
		for i in stars.size():
			if (up and float(stars[i]) < 5.0) or (not up and float(stars[i]) > 0.5):
				open.append(i)
		if open.is_empty():
			return
		var k: int = _pick(rng, open)
		stars[k] = float(stars[k]) + (0.5 if up else -0.5)

## One starter of `stars` CURRENT stars at `pos` in class year `year`: his name, age, swimming and
## the rest made the old way at that level (make_player), then four whole-number attributes for
## his position whose average rates exactly `stars` (fit_stars), and his ceilings from a
## development profile (`dev`, or one rolled) with his year's share of its room. Stars are read
## from the attributes (Attributes.sync), never set.
static func make_starter(rng: RandomNumberGenerator, pos: int, stars: float, year: int, used: Dictionary, dev: String = "") -> PoloPlayer:
	var span := Attributes.star_range(stars)
	var target := rng.randf_range(span.x, minf(span.y, TOP_AVERAGE) - 0.01)
	var y := clampi(year, 1, 4)
	var p := make_player(rng, pos, Attributes.legacy_of(target) - YEAR_BONUS[y], y, used)
	var keys := p.key_ratings()
	var lean := prospect_lean(rng, p)
	var now := {}
	for k in keys:
		now[k] = clampi(roundi(target + float(lean.get(k, 0.0)) + rng.randfn(0.0, NOISE)), 0, 10)
	fit_stars(rng, now, stars)
	p.attrs = {}
	p.attr_pot = {}
	for k in keys:
		p.attrs[k] = float(now[k])
		p.attr_pot[k] = float(now[k])
	p.shape = []
	p.dev = dev if dev != "" else Recruiting.roll_dev(rng)
	grow_ceilings(rng, p, p.dev, float(YEAR_ROOM[y]))
	p.star_base = snappedf(p.overall(), 0.0001)
	p.stars_locked = p.stars
	p.trait_id = Traits.best_for(p)
	return p

## Puts the seven's attributes right if their stars ever don't add up to `want` (a rating
## fit_stars couldn't reach): a whole attribute point at a time on the starter furthest off, up
## or down, read back each time; bounded. Returns whether they add up.
static func fix_total(rng: RandomNumberGenerator, seven: Array, want: float) -> bool:
	for _i in MAX_STEPS:
		var total := 0.0
		for p: PoloPlayer in seven:
			total += p.stars
		if is_equal_approx(total, want):
			return true
		var up := total < want
		var p: PoloPlayer = _pick(rng, seven)
		var keys := p.key_ratings().filter(func(k): return (p.attr(k) < Attributes.MAX) if up else (p.attr(k) > 0.0))
		if keys.is_empty():
			continue
		var k: String = _pick(rng, keys)
		var v := p.attr(k) + (1.0 if up else -1.0)
		p.attr_pot[k] = maxf(float(p.attr_pot[k]), v)
		p.attrs[k] = v
		Attributes.sync(p)
	return false

## A school's first roster in a brand-new career, built to `target` (its original overall, kept
## as t.initial_strength_target and never read again): the seven starters at ROSTER_POS, their
## stars from starter_stars dealt to the positions at random, then `bench` subs (BENCH_DROP below
## the target, mostly underclassmen; a backup keeper first when the team may carry one) and a
## lineup that keeps the seven as the starters. The best SCHOL_MAX get scholarships.
static func make_initial_roster(t: PoloTeam, rng: RandomNumberGenerator, next_id: Callable, target: float, bench: int = 0) -> void:
	t.roster.clear()
	t.lineup = []
	t.initial_strength_target = target
	var used := {}
	var stars := starter_stars(rng, target)
	var want := 0.0
	for v in stars:
		want += float(v)
	_shuffle(rng, stars)
	for i in ROSTER_POS.size():
		var p := make_starter(rng, ROSTER_POS[i], float(stars[i]), 1 + (i % 4), used)
		p.id = next_id.call()
		p.number = t.free_number(p.is_keeper())
		t.roster.append(p)
	fix_total(rng, t.roster, want)
	# an attacker is a lefty LEFTY_SHARE of the time (no team is made to have one)
	for p in t.roster:
		roll_lefty(rng, p)
	for p in t.roster:
		give_home(p, rng, t.id)
	award_scholarships(t, Career.SCHOL_MAX)
	if bench > 0:
		add_initial_bench(t, rng, next_id, target, bench)

## A program's subs on a brand-new roster (every program's, Career.new_setup; an older save's,
## Career.fill_benches): a backup keeper first (unless it has one), then flex players, below the
## starters' level. `fix_lineup`: the seven already made are fixed as the starters first
## (lineup_of) and the subs put on its bench, so they never change who starts.
static func add_initial_bench(t: PoloTeam, rng: RandomNumberGenerator, next_id: Callable, target: float, bench: int, fix_lineup := true) -> void:
	var used := {}
	for q in t.roster:
		used[q.last] = true
	var has_backup := t.roster.filter(func(q: PoloPlayer): return q.is_keeper()).size() >= 2
	if fix_lineup:
		t.lineup = lineup_of(t)
	var avg := target_stars(target)
	# never better than the seven: half a star under the weakest starter of his kind at most, so a
	# new bench never changes who starts (PoloTeam.starters picks the best seven)
	var seven := t.roster.duplicate()
	var keeper_top := 5.0
	var field_top := 5.0
	for q: PoloPlayer in seven:
		if q.is_keeper():
			keeper_top = minf(keeper_top, q.stars - 0.5)
		else:
			field_top = minf(field_top, q.stars - 0.5)
	for j in bench:
		var pos: int = PoloPlayer.Pos.GK if j == 0 and not has_backup else field_pos(rng)
		var top := keeper_top if pos == PoloPlayer.Pos.GK else field_top
		var s := clampf(PlayerForm.snap_half(avg - BENCH_DROP + rng.randfn(0.0, BENCH_SPREAD)), 0.5, maxf(0.5, top))
		var p := make_starter(rng, pos, s, _pick(rng, BENCH_YEARS), used)
		roll_lefty(rng, p)
		p.id = next_id.call()
		p.number = t.free_number(p.is_keeper())
		give_home(p, rng, t.id)
		t.roster.append(p)
	if fix_lineup:
		t.sync_lineup()   # (the subs take the bench places)
	award_scholarships(t, Career.SCHOL_MAX)

## A lineup (PoloTeam.LINEUP_SPOTS) with `t`'s seven (its whole roster, before any bench) as the
## starters, each where the roster screen's first visit would put him (its formation():
## PoloTeam's places, a lefty on the right side); the bench places empty.
static func lineup_of(t: PoloTeam) -> Array:
	var f: Dictionary = load(ROSTER_SCREEN).formation(t)
	var out: Array = []
	for i in PoloTeam.LINEUP_SPOTS.size():
		var p: PoloPlayer = f.spots.get(PoloTeam.LINEUP_SPOTS[i]) if i < PoloTeam.STARTERS else null
		out.append(p.id if p != null else -1)
	return out

static func _shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

## The level an existing roster plays at (its starters' 0-100 overall, less the starters' edge):
## what an older save's depth players are built below (Career.upgrade_rosters). The players'
## own, never a school's original rating.
static func roster_level(t: PoloTeam) -> float:
	var seven := t.starters()
	if seven.is_empty():
		return WALKON_LEVEL
	var total := 0.0
	for p: PoloPlayer in seven:
		total += p.overall()
	return total / seven.size() - PlayerForm.STARTER_EDGE

## The 18-man programs' roster (before seven-man rosters; kept for the tests of older saves),
## around the old scale's team `ovr` (quality_for_ovr; 0: from prestige):
## the seven starters and a sub, ten depth players below them (add_depth), eight scholarships.
static func make_roster_18(t: PoloTeam, rng: RandomNumberGenerator, next_id: Callable, ovr: float = 0.0) -> void:
	t.roster.clear()
	var used := {}
	var q := quality_for_ovr(ovr) if ovr > 0 else team_quality(t.prestige)
	var positions: Array = ROSTER_POS + [field_pos(rng)]
	for i in positions.size():
		var year := 1 + (i % 4)
		var p := make_player(rng, positions[i], q, year, used)
		p.id = next_id.call()
		p.number = t.free_number(p.is_keeper())
		t.roster.append(p)
	for p in t.roster:
		roll_lefty(rng, p)
	add_depth(t, rng, next_id, q, 18)
	for p in t.roster:
		give_home(p, rng, t.id)
	award_scholarships(t, 8)

## Tops a roster up to `size` with depth players, `DEPTH_DROP` below `q`, at the positions
## ROSTER_SHAPE is short of. The starting seven never change: a depth player who would start is
## built again, and in the end trimmed below the starter he'd replace. Returns the players added.
static func add_depth(t: PoloTeam, rng: RandomNumberGenerator, next_id: Callable, q: float, size: int) -> Array:
	var used := {}
	for p in t.roster:
		used[p.last] = true
	var starters := t.starters()
	var keep_ids: Array = starters.map(func(p: PoloPlayer): return p.id)
	var added: Array = []
	var k := 0
	while t.roster.size() < size:
		var pos := needed_pos(t, rng)
		var year: int = DEPTH_YEARS[k % DEPTH_YEARS.size()]
		k += 1
		var p: PoloPlayer = null
		for _try in 6:
			p = make_player(rng, pos, q - DEPTH_DROP, year, used)
			if _below_starters(p, starters):
				break
		_hold_below(p, starters)
		p.id = next_id.call()
		p.number = t.free_number(p.is_keeper())
		t.roster.append(p)
		added.append(p)
	# the same seven start (an injured starter's place can still go to the best fit man)
	if t.starters().map(func(p: PoloPlayer): return p.id) != keep_ids and starters.all(func(p: PoloPlayer): return p.is_available()):
		push_warning("%s: depth changed the starting seven" % t.id)
	return added

## Would `p` stay out of these starters' way? A keeper below their keeper; a center below their
## center; anyone else below the weakest starting field player.
static func _below_starters(p: PoloPlayer, starters: Array) -> bool:
	return p.overall() < _bar_for(p, starters) and p.keeping < _keeping_bar(p, starters)

static func _bar_for(p: PoloPlayer, starters: Array) -> float:
	if starters.size() < 2:
		return 999.0
	if p.is_keeper():
		return 999.0
	var field: Array = starters.slice(1)
	var lo := 999.0
	for s: PoloPlayer in field:
		# the center's spot only goes to centers; every other spot to the best field players
		if s == field[0] and s.pos == PoloPlayer.Pos.CENTER and p.pos != PoloPlayer.Pos.CENTER:
			continue
		lo = minf(lo, s.overall())
	return lo

## A keeper's goalkeeping below the starter's (and a field player below him too, so a keeper
## injury still puts the same field player in goal).
static func _keeping_bar(p: PoloPlayer, starters: Array) -> int:
	if starters.is_empty():
		return 999
	var gk: PoloPlayer = starters[0]
	if p.is_keeper():
		return gk.keeping
	return 999

## Newly made players (`made`: freshmen, walk-ons) who'd sit on `t`'s bench never outrank a
## starter he could play for: each who isn't one of PoloTeam.starters is lowered a quarter point
## an attribute at a time until his CURRENT stars are no more than the weakest starter in a
## place he may play (bench_bar), his hidden level then set from what he has
## (Development.initial_level). Nobody already on the roster is touched.
static func hold_bench(t: PoloTeam, made: Array) -> void:
	for p: PoloPlayer in made:
		var seven := t.starters()
		if p in seven:
			continue
		var low := bench_bar(p, seven)
		var guard := 0
		while p.stars > low + 0.001 and guard < 80:
			guard += 1
			for key in p.key_ratings():
				p.attrs[key] = maxf(0.0, p.attr(key) - 0.25)
			Attributes.sync(p)
		if guard > 0:
			p.star_base = snappedf(p.overall(), 0.0001)
			p.stars_locked = p.stars
			p.xp_level = Development.initial_level(p)
			p.xp_start = p.xp_level
			p.trait_id = Traits.best_for(p)

## The stars a sub may have at most: the weakest of `seven` (LINEUP_SPOTS order) in a place he
## may play (PoloTeam.fits: a 2MD is held under the posts, never a wing he couldn't replace);
## with no such place, the weakest of his kind (keeper or field player).
static func bench_bar(p: PoloPlayer, seven: Array) -> float:
	var low := 99.0
	for i in mini(seven.size(), PoloTeam.STARTERS):
		if PoloTeam.fits(p, i):
			low = minf(low, (seven[i] as PoloPlayer).stars)
	if low >= 99.0:
		for s: PoloPlayer in seven:
			if s.is_keeper() == p.is_keeper():
				low = minf(low, s.stars)
	return low

## Lowers `p`'s attributes a quarter point at a time until he's below the starters.
static func _hold_below(p: PoloPlayer, starters: Array) -> void:
	var guard := 0
	while not _below_starters(p, starters) and guard < 200:
		guard += 1
		for key in p.key_ratings():
			p.attrs[key] = maxf(0.0, p.attr(key) - 0.25)
		Attributes.sync(p)
	p.trait_id = Traits.best_for(p)

## `n` on the roster hold the scholarships (a new program, or an old save's roster): the
## upperclassmen first, then the best, so one comes free every year as they graduate (with
## seven men, the best four would often all be underclassmen and leave none to offer).
static func award_scholarships(t: PoloTeam, n: int) -> void:
	var by_ovr: Array = t.roster.duplicate()
	by_ovr.sort_custom(func(a: PoloPlayer, b: PoloPlayer): return a.year > b.year if a.year != b.year else a.overall() > b.overall())
	for i in by_ovr.size():
		(by_ovr[i] as PoloPlayer).schol = i < n

## A hometown for a player who has none (Hometowns.pick; once, for good). `school`: his school's
## id while its starting roster is made (a little local); "" everywhere else (the broad pool).
## Two of `rng`'s draws seed its own dice, as the old pick took two: nothing after it moves.
static func give_home(p: PoloPlayer, rng: RandomNumberGenerator, school: String = "") -> void:
	if p.home != "" or p.region != "":
		return
	var h := RandomNumberGenerator.new()
	h.seed = hash([rng.randi(), rng.randi()])
	p.home = Hometowns.pick(h, school)
	p.region = "US" if Hometowns.is_us(p.home) else "INTL"

## A position for a newcomer: whatever the starting shape is short of, then whatever the
## roster shape (ROSTER_SHAPE) is shortest of, else a flex spot.
static func needed_pos(t: PoloTeam, rng: RandomNumberGenerator, extra: Array = []) -> int:
	var have := {}
	for p in t.roster:
		have[p.pos] = int(have.get(p.pos, 0)) + 1
	for pos in extra:
		have[pos] = int(have.get(pos, 0)) + 1
	var left := have.duplicate()
	for pos in ROSTER_POS:
		if int(left.get(pos, 0)) > 0:
			left[pos] -= 1
		else:
			return pos
	var best := -1
	var gap := 0
	for pos in ROSTER_SHAPE:
		var g := int(ROSTER_SHAPE[pos]) - int(have.get(pos, 0))
		if g > gap:
			gap = g
			best = pos
	return best if best >= 0 else field_pos(rng)

## A high-school prospect rated `stars` (one of Attributes.STAR_STEPS): four whole-number
## attributes for his position (LEANS / KEEPER_TYPES) whose average rates exactly `stars`, then
## his four ceilings from development profile `dev` (grow_ceilings), all made here once. His
## stars are read from what he got, never set. `at` is his position (-1: any).
static func make_prospect(rng: RandomNumberGenerator, stars: float, dev: String, used: Dictionary, at: int = -1) -> PoloPlayer:
	var pos: int = at if at >= 0 else (PoloPlayer.Pos.GK if rng.randf() < KEEPER_SHARE else field_pos(rng))
	var span := Attributes.star_range(stars)
	var target := rng.randf_range(span.x, minf(span.y, TOP_AVERAGE) - 0.01)
	# his name, swimming and the rest made the old way around that level (the year-1 step undone)
	var p := make_player(rng, pos, Attributes.legacy_of(target) - YEAR_BONUS[1], 1, used)
	p.age = 18
	var keys := p.key_ratings()
	var lean := prospect_lean(rng, p)
	var now := {}
	for k in keys:
		now[k] = clampi(roundi(target + float(lean.get(k, 0.0)) + rng.randfn(0.0, NOISE)), 0, 10)
	fit_stars(rng, now, stars)
	p.attrs = {}
	p.attr_pot = {}
	for k in keys:
		p.attrs[k] = float(now[k])
		p.attr_pot[k] = float(now[k])
	p.shape = []
	grow_ceilings(rng, p, dev)
	p.dev = dev
	p.star_base = snappedf(p.overall(), 0.0001)
	p.stars_locked = p.stars
	roll_lefty(rng, p)
	p.trait_id = Traits.best_for(p)
	give_home(p, rng)
	return p

## What a prospect leans towards: his position's LEANS (or a keeper's KEEPER_TYPES), scaled; now
## and then (OFF_TYPE) another position's, so a centre can be a passer.
static func prospect_lean(rng: RandomNumberGenerator, p: PoloPlayer) -> Dictionary:
	var base: Dictionary
	if p.is_keeper():
		base = _pick(rng, KEEPER_TYPES)
	elif rng.randf() < OFF_TYPE:
		base = LEANS[_pick(rng, LEANS.keys())]
	else:
		base = LEANS.get(p.pos, {})
	var k := rng.randf_range(LEAN_SCALE.x, LEAN_SCALE.y)
	var out := {}
	for key in base:
		out[key] = float(base[key]) * k
	return out

## Moves whole points (a random attribute with room each time) until the average rates `stars`.
static func fit_stars(rng: RandomNumberGenerator, vals: Dictionary, stars: float) -> void:
	var keys := vals.keys()
	for _i in 80:
		var avg := 0.0
		for k in keys:
			avg += float(vals[k])
		avg /= keys.size()
		var have := Attributes.stars_of(avg)
		if is_equal_approx(have, stars):
			return
		var up := have < stars
		var open := keys.filter(func(k): return int(vals[k]) < 10 if up else int(vals[k]) > 0)
		if open.is_empty():
			return
		var k = _pick(rng, open)
		vals[k] = int(vals[k]) + (1 if up else -1)

## His four ceilings: his attributes plus the room his development profile `dev` gives
## (Recruiting.DEV_PROFILES: whole points in all, one at a time to an attribute with room, his
## better ones a little likelier), never past 10. The profile sets the room, not his stars;
## `share` of it for a player already some years into college (make_starter).
static func grow_ceilings(rng: RandomNumberGenerator, p: PoloPlayer, dev: String, share: float = 1.0) -> void:
	var prof: Dictionary = Recruiting.DEV_PROFILES.get(dev, Recruiting.DEV_PROFILES.limited)
	var room := roundi(rng.randi_range(int(prof.room.x), int(prof.room.y)) * share)
	var keys := p.key_ratings()
	var lean := {}
	for k in keys:
		lean[k] = rng.randf_range(0.4, 1.6)   # where this one grows: his own, not his position's
	for _i in room:
		var total := 0.0
		var open: Array = []
		for k in keys:
			if float(p.attr_pot[k]) < Attributes.MAX:
				open.append(k)
				total += float(lean[k]) * (0.6 + float(p.attrs[k]) / Attributes.MAX)
		if open.is_empty():
			break
		var x := rng.randf() * total
		var pick: String = open[open.size() - 1]
		for k in open:
			x -= float(lean[k]) * (0.6 + float(p.attrs[k]) / Attributes.MAX)
			if x < 0.0:
				pick = k
				break
		p.attr_pot[pick] = float(p.attr_pot[pick]) + 1.0
	Attributes.sync(p)

## A prospect's ceilings for POTENTIAL `pot_stars` (Recruiting.make): back to his attributes,
## then a point at a time (where he'd grow: as grow_ceilings) until his POTENTIAL rates it. A point
## is a quarter of the average and a star step half a point at least, so it lands on it exactly
## (short of it only when every attribute is already 10).
static func grow_to(rng: RandomNumberGenerator, p: PoloPlayer, pot_stars: float) -> void:
	var keys := p.key_ratings()
	for k in keys:
		p.attr_pot[k] = float(p.attrs[k])
	var lean := {}
	for k in keys:
		lean[k] = rng.randf_range(0.4, 1.6)
	var guard := 0
	while Attributes.stars_of(Attributes.potential(p)) < pot_stars - 0.01 and guard < 40:
		guard += 1
		var total := 0.0
		var open: Array = []
		for k in keys:
			if float(p.attr_pot[k]) < Attributes.MAX:
				open.append(k)
				total += float(lean[k]) * (0.6 + float(p.attrs[k]) / Attributes.MAX)
		if open.is_empty():
			break
		var x := rng.randf() * total
		var pick: String = open[open.size() - 1]
		for k in open:
			x -= float(lean[k]) * (0.6 + float(p.attrs[k]) / Attributes.MAX)
			if x < 0.0:
				pick = k
				break
		p.attr_pot[pick] = minf(Attributes.MAX, float(p.attr_pot[pick]) + 1.0)
	Attributes.sync(p)

## A field position at FIELD_WEIGHTS' odds.
static func field_pos(rng: RandomNumberGenerator) -> int:
	var total := 0
	for k in FIELD_WEIGHTS:
		total += int(FIELD_WEIGHTS[k])
	var roll := rng.randi_range(1, total)
	for k in FIELD_WEIGHTS:
		roll -= int(FIELD_WEIGHTS[k])
		if roll <= 0:
			return k
	return PoloPlayer.Pos.DRIVER

## A newly made attacker is a lefty LEFTY_SHARE of the time (nobody else, ever). His hand is
## all it is: no rating, trait or bonus comes with it.
static func roll_lefty(rng: RandomNumberGenerator, p: PoloPlayer) -> void:
	p.lefty = p.pos == PoloPlayer.Pos.DRIVER and rng.randf() < LEFTY_SHARE

## A walk-on freshman to fill an empty roster spot: about a 1-2 star prospect.
static func make_walkon(rng: RandomNumberGenerator, pos: int, used: Dictionary) -> PoloPlayer:
	var p := make_player(rng, pos, WALKON_LEVEL + PlayerForm.STARTER_EDGE + rng.randf_range(-3.0, 3.0), 1, used)
	p.age = 18
	roll_lefty(rng, p)
	give_home(p, rng)
	return p
