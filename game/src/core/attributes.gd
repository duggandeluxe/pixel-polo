class_name Attributes
## Retro Polo 2.0 player attributes (docs: "Complete Player Attribute, Goalkeeper, and Star
## Rating System"). Every player has four attributes on a 0-10 scale, each with its own
## potential ceiling:
##   field players  PASSING, SHOOTING, STRENGTH, DEFENSE
##   goalkeepers    COMMUNICATION, LUNGE SPEED, BLOCKING, LEG STRENGTH
## OVERALL is the plain average of the four and POTENTIAL the average of the four ceilings;
## stars come from each of them through STAR_STEPS (stars_of: 8.0 and up is five stars). That is
## the one star-rating calculation in the game: PoloPlayer.stars / pot_stars are kept equal to it
## by sync(), never set any other way. (Team ratings and form still count a player's exact
## OVERALL / 2, star_value, so the new steps change what's shown, not how the pool plays.)
##
## The pool's older mechanics still read the 0-100 ratings (`shoot`, `passing`, `strength`,
## `defense`, `keeping`): those are now worked out from the attributes here (sync), never set on
## their own, so the attributes are the only source of truth. (`speed`, swimming, is his own:
## see POS_SPEED.) A player
## of OVERALL x plays like a pre-2.0 player of the same stars (legacy_of), and an attribute
## above or below his overall moves its rating SPREAD points a point.
##
## The new mechanics (passing's catch-and-shoot edge, shooting's release, strength and defense in
## the 2 m battle and the press, the keeper's four) are the numbers further down, all of them
## neutral at 5. They read the attributes as he plays them today (play_value: less any injury's
## penalty, Development.eff_value, plus his HOT STARS: hot_bonus, +0.5 to all four a Hot Star, and
## past 10 if that's where it takes him). That one bonus is the whole of HOT form in a game you
## play: the 0-100 ratings the older mechanics read move with it too (PoloPlayer.live:
## HOT_RATING_PER_POINT a point of it), each mechanic reading it once. Stars, OVERALL, POTENTIAL,
## the 0-100 ratings sync keeps and the team overall only ever read the permanent attributes, so
## neither an injury nor a Hot Star ever moves them, and nothing of either is ever saved.

const FIELD := ["pas", "sho", "str", "dfn"]
const KEEPER := ["com", "lun", "blk", "leg"]
const NAMES := {"pas": "Passing", "sho": "Shooting", "str": "Strength", "dfn": "Defense",
	"com": "Communication", "lun": "Lunge Speed", "blk": "Blocking", "leg": "Leg Strength"}
const MAX := 10.0
const PRECISION := 0.0001      # saved to 4 decimals, so OVERALL and POTENTIAL survive a save exactly

# ------------------------------------------------------------------ the 0-100 bridge
## OVERALL -> the pre-2.0 player overall it plays like: stars x 3.6 + 50.8 (PlayerForm's star
## scale: 1 star = 54.4 .. 5 stars = 68.8), so 1.8 a point.
const LEGACY_ZERO := 50.8
const LEGACY_PER_POINT := 1.8
## An attribute a point above (below) his OVERALL is this many 0-100 points above (below) it.
const SPREAD := 6.0
## Swimming speed isn't one of the four: it stays his own physical rating (`speed`, saved, grown
## by practice as it always was) and never counts towards OVERALL. A made-up player (the labs)
## swims at his OVERALL's level, by position.
const POS_SPEED := {PoloPlayer.Pos.GK: -4.0, PoloPlayer.Pos.CENTER: -6.0, PoloPlayer.Pos.DRIVER: 6.0,
	PoloPlayer.Pos.WING: 2.0, PoloPlayer.Pos.UTILITY: 0.0, PoloPlayer.Pos.DEFENDER: -2.0}
const KEEPER_FIELD_DROP := 4.0     # a keeper's swimming, passing and wrestling, under his overall
const KEEPER_SHOOT_DROP := 30.0
## Which 0-100 rating an attribute is read from when a player is converted (an older save, or
## anyone made the pre-2.0 way: CollegeGen, League). Keepers' four come from the ratings
## nearest them.
const FROM_LEGACY := {"pas": "passing", "sho": "shoot", "str": "strength", "dfn": "defense",
	"com": "passing", "lun": "speed", "blk": "keeping", "leg": "strength"}
## The pre-2.0 weighted overall by position (PoloPlayer.legacy_overall), kept only to convert
## training's 0-100 points into attribute points at the same speed as before.
const LEGACY_WEIGHTS := {
	PoloPlayer.Pos.GK: {"keeping": 0.8, "passing": 0.1, "speed": 0.1},
	PoloPlayer.Pos.CENTER: {"strength": 0.36, "shoot": 0.3, "passing": 0.12, "defense": 0.11, "speed": 0.11},
	PoloPlayer.Pos.DEFENDER: {"defense": 0.33, "strength": 0.32, "speed": 0.17, "passing": 0.1, "shoot": 0.08},
	-1: {"shoot": 0.32, "speed": 0.25, "passing": 0.2, "defense": 0.12, "strength": 0.11},
}
## Training's 0-100 points land on these attributes (a point that isn't one attribute's is
## shared out equally).
const TRAIN_TO := {"shoot": ["sho"], "passing": ["pas"], "strength": ["str"], "defense": ["dfn"],
	"speed": ["pas", "sho", "str", "dfn"]}
const KEEPER_TRAIN_TO := {"keeping": ["blk", "lun", "leg"], "passing": ["com"], "speed": ["lun"],
	"strength": ["leg"], "defense": ["com"], "shoot": ["com"]}

# ------------------------------------------------------------------ gameplay (all neutral at 5)
## PASSING: the passer's edge on an immediate catch and shoot (the spec's table, straight lines
## between its points). A share: +0.06 = the shot is 6% more effective.
const PASS_TABLE := [Vector2(0, -0.10), Vector2(2, -0.06), Vector2(5, 0.0), Vector2(8, 0.06), Vector2(10, 0.10), Vector2(11, 0.12)]
## SHOOTING: the release takes this share of the normal time, 1 - (S - 5) x RELEASE_PER_POINT
## (0: 20% slower .. 10: 20% faster): the arm up, their wind-up, and the read it gives away.
const RELEASE_PER_POINT := 0.04
const RELEASE_READ := 0.25         # a release this much quicker (as a share) hides the shot this long (s)
## STRENGTH / DEFENSE in the 2 m battle: each point of the centre's strength over his guard's
## brings his inside water CENTER_WIN_PER_POINT s sooner; each point of the guard's strength and
## defence holds the seal (and gets him round) sooner by the same share.
const CENTER_WIN_PER_POINT := 0.35
const SEAL_PER_POINT := 0.05
const SWITCH_PER_POINT := 0.04
## STRENGTH vs DEFENSE on the perimeter: the press forces an ordinary foul (D - S) x 4% more often.
const FOUL_PER_POINT := 0.04
const FOUL_RANGE := Vector2(0.5, 1.5)
## COMMUNICATION: (C - 5) x 0.1 effective Defense for the keeper's teammates while he's in goal.
const COMM_PER_POINT := 0.1
## LUNGE SPEED: his dive takes 1 - (L - 5) x 0.04 of the normal time (his reaction, his push off,
## his rise to full stretch, his swim across), never further.
const LUNGE_PER_POINT := 0.04
## BLOCKING: a ball he gets to is held (B - 5) x 3% more (less) often than at 5.
const BLOCK_PER_POINT := 0.03
## ...where at 5 one at his fingertips slips through this often (none in the middle of his
## reach: a ball into his body is his), and however good his hands a fingertip one never
## becomes certain: at best he keeps out half of what he'd have let through (FINGERTIP_FLOOR).
const BLOCK_EDGE_LEAK := 0.12
const BLOCK_LEAK_FROM := 0.6       # ...from this far out along his reach
const FINGERTIP_FLOOR := 0.5
## LEG STRENGTH: his reach, (G - 5) x 3% either way; and how long he stays up. A dive's active
## window (KeeperDive: full stretch, before he falls back into the water) lasts
## WINDOW_AT_5 + (G - 5) x WINDOW_PER_POINT on-screen seconds: 0.22 s at 2, 0.34 at 5, 0.50 at 9.
const LEG_REACH_PER_POINT := 0.03
const WINDOW_AT_5 := 0.34
const WINDOW_PER_POINT := 0.04
const WINDOW_RANGE := Vector2(0.14, 0.58)    # (0 .. 11: a VERY HOT 10, HOT_TOP)

# ------------------------------------------------------------------ the ratings
static func keys_for(p: PoloPlayer) -> Array:
	return KEEPER if p.is_keeper() else FIELD

static func value(p: PoloPlayer, key: String) -> float:
	return float(p.attrs.get(key, 5.0))

static func ceiling(p: PoloPlayer, key: String) -> float:
	return maxf(float(p.attr_pot.get(key, value(p, key))), value(p, key))

static func _mean(p: PoloPlayer, d: Dictionary) -> float:
	var keys := keys_for(p)
	var s := 0.0
	for k in keys:
		s += float(d.get(k, 0.0))
	return s / keys.size()

## OVERALL, 0-10: the average of his four, unrounded.
static func overall(p: PoloPlayer) -> float:
	return _mean(p, p.attrs)

## POTENTIAL, 0-10: the average of his four ceilings.
static func potential(p: PoloPlayer) -> float:
	var keys := keys_for(p)
	var s := 0.0
	for k in keys:
		s += ceiling(p, k)
	return s / keys.size()

## The star rating of a 0-10 average (OVERALL, or POTENTIAL from the ceilings): [from, stars],
## best first; below the last step, half a star. Read from the unrounded average.
const STAR_STEPS := [[8.0, 5.0], [7.5, 4.5], [7.0, 4.0], [6.0, 3.5], [5.0, 3.0], [4.0, 2.5],
	[3.0, 2.0], [2.0, 1.5], [1.0, 1.0]]
const STAR_FLOOR := 0.5

## Stars for a 0-10 average (STAR_STEPS): 7.49 is 4, 7.5 is 4.5, 8.0 is 5. The average of four
## 4-decimal attributes is exact to 6 decimals, so it's compared there (no float dust: 7.5 that
## came out as 7.4999999 is still 7.5).
static func stars_of(v: float) -> float:
	var a := snap(v, 1000000.0)
	for step in STAR_STEPS:
		if a >= float(step[0]):
			return float(step[1])
	return STAR_FLOOR

## The lowest average that rates `stars` (STAR_STEPS), and the first that rates more (11 past five).
static func star_range(stars: float) -> Vector2:
	var hi := 11.0
	for step in STAR_STEPS:
		if is_equal_approx(float(step[1]), stars):
			return Vector2(float(step[0]), hi)
		hi = float(step[0])
	return Vector2(0.0, hi)

## A 0-10 rating on the continuous star scale the team ratings and form use: half of it.
static func star_value(v: float) -> float:
	return v / 2.0

## "6.5" / "7.25": a 0-10 rating for the screen, as precise as it is (two decimals at most).
static func text(v: float) -> String:
	var r := snappedf(v, 0.01)
	if is_equal_approx(r, roundf(r * 10.0) / 10.0):
		return "%.1f" % r
	return "%.2f" % r

## `v` to 1 / `per` (a whole number of them, divided: exact where it can be, unlike snappedf).
static func snap(v: float, per: float = 10000.0) -> float:
	return roundf(v * per) / per

## A quick-match club's player (PoloPlayer.pro) is rated on the clubs' own scale: their 0-100
## overall PRO_MID is a 5, PRO_PER_POINT a point either way (the clubs run well past the college
## scale, so on that they'd all be 10s and every attribute effect maxed out).
const PRO_MID := 64.0
const PRO_PER_POINT := 3.6

static func pro_ten_of(legacy: float) -> float:
	return clampf(5.0 + (legacy - PRO_MID) / PRO_PER_POINT, 0.0, MAX)

static func legacy_of(v: float) -> float:
	return LEGACY_ZERO + LEGACY_PER_POINT * v

static func ten_of(legacy: float) -> float:
	return clampf((legacy - LEGACY_ZERO) / LEGACY_PER_POINT, 0.0, MAX)

# ------------------------------------------------------------------ keeping everything in step
## Stars, POTENTIAL and the 0-100 ratings the pool reads, from the attributes. Call it after any
## attribute or ceiling changes (set_value, train... do).
static func sync(p: PoloPlayer) -> void:
	if p.attrs.is_empty():
		return
	for k in keys_for(p):
		p.attrs[k] = clampf(snap(float(p.attrs.get(k, 5.0))), 0.0, MAX)
		p.attr_pot[k] = clampf(snap(maxf(float(p.attr_pot.get(k, p.attrs[k])), p.attrs[k])), p.attrs[k], MAX)
	var o := overall(p)
	p.stars = stars_of(o)
	p.pot_stars = stars_of(potential(p))
	p.pot = legacy_of(potential(p))
	if p.pro:
		return   # (a quick-match club's player keeps the ratings he was made with: PoloPlayer.pro)
	var base := legacy_of(o)
	var r := func(v: float) -> int: return clampi(roundi(v), 1, 99)
	if p.is_keeper():
		# (an injured keeper plays at his four less their penalties)
		base = legacy_of(_mean_eff(p))
		p.keeping = r.call(base)
		p.passing = r.call(base - KEEPER_FIELD_DROP)
		p.strength = r.call(base - KEEPER_FIELD_DROP)
		p.defense = r.call(base - KEEPER_FIELD_DROP)
		p.shoot = r.call(base - KEEPER_SHOOT_DROP)
	else:
		p.shoot = r.call(base + SPREAD * (Development.eff_value(p, "sho") - o))
		p.passing = r.call(base + SPREAD * (Development.eff_value(p, "pas") - o))
		p.strength = r.call(base + SPREAD * (base_play_value(p, "str") - o))
		p.defense = r.call(base + SPREAD * (Development.eff_value(p, "dfn") - o))

## The average of his four as he plays them today (less an injury's penalties).
static func _mean_eff(p: PoloPlayer) -> float:
	var s := 0.0
	for k in keys_for(p):
		s += Development.eff_value(p, k)
	return s / keys_for(p).size()

## One attribute set to `v` (0 .. his ceiling for it).
static func set_value(p: PoloPlayer, key: String, v: float) -> void:
	p.attrs[key] = clampf(v, 0.0, ceiling(p, key))
	sync(p)

## One ceiling set to `v` (his attribute .. 10).
static func set_ceiling(p: PoloPlayer, key: String, v: float) -> void:
	p.attr_pot[key] = clampf(v, value(p, key), MAX)
	sync(p)

## Room left under one ceiling.
static func room(p: PoloPlayer, key: String) -> float:
	return maxf(0.0, ceiling(p, key) - value(p, key))

## A position change (a newcomer moved to another spot): goalkeeper and field attributes are
## different things, so the player is converted again at the same OVERALL and POTENTIAL.
static func repositioned(p: PoloPlayer, was_keeper: bool) -> void:
	if was_keeper == p.is_keeper() or p.attrs.is_empty():
		return
	var o := _mean_of(p.attrs)
	var pt := _mean_of(p.attr_pot)
	p.attrs = {}
	p.attr_pot = {}
	from_legacy(p, o, maxf(pt, o))

static func _mean_of(d: Dictionary) -> float:
	var s := 0.0
	for k in d:
		s += float(d[k])
	return s / maxf(1.0, d.size())

# ------------------------------------------------------------------ conversion
## A player's four attributes and ceilings made from his 0-100 ratings (their shape: what he's
## better and worse at, by position), at exactly OVERALL `o` and POTENTIAL `pot` (0-10). The
## same ratings always give the same attributes. Used for every player made the pre-2.0 way and
## for every player in an older save (migrate), so nobody's stars change.
static func from_legacy(p: PoloPlayer, o: float, pot: float) -> void:
	var keys := keys_for(p)
	o = clampf(o, 0.0, MAX)
	pot = clampf(maxf(pot, o), o, MAX)
	var src: Array = keys.map(func(k): return float(p.get(FROM_LEGACY[k])))
	var mean := 0.0
	for v in src:
		mean += v
	mean /= src.size()
	p.shape = src.map(func(v): return (v - mean) / SPREAD)
	var base: Array = p.shape.map(func(d): return o + d)
	var lo: Array = keys.map(func(_k): return 0.0)
	var hi: Array = keys.map(func(_k): return MAX)
	var ones: Array = keys.map(func(_k): return 1.0)
	var now := fit_mean(base, lo, hi, ones, o)
	# room to grow: a little more where he's already good (his strengths keep growing)
	var weight: Array = now.map(func(v): return 0.5 + v / MAX)
	var pots := fit_mean(now, now, hi, weight, pot)
	p.attrs = {}
	p.attr_pot = {}
	for i in keys.size():
		p.attrs[keys[i]] = now[i]
		p.attr_pot[keys[i]] = pots[i]
	sync(p)

## New ceilings for his attributes as they are, averaging exactly `pot` (0-10): a recruit's
## room to grow, worked out after he was made.
static func refit_potential(p: PoloPlayer, pot: float) -> void:
	var keys := keys_for(p)
	var now: Array = keys.map(func(k): return value(p, k))
	var hi: Array = keys.map(func(_k): return MAX)
	var weight: Array = now.map(func(v): return 0.5 + v / MAX)
	var pots := fit_mean(now, now, hi, weight, clampf(maxf(pot, overall(p)), 0.0, MAX))
	for i in keys.size():
		p.attr_pot[keys[i]] = pots[i]
	sync(p)

## His attributes moved to OVERALL `o` and his ceilings to POTENTIAL `pot`, keeping their shape
## (what he's better and worse at): a player built to a star rating after he was made.
static func refit(p: PoloPlayer, o: float, pot: float) -> void:
	var keys := keys_for(p)
	var mean := overall(p)
	var base: Array = keys.map(func(k): return value(p, k) - mean + o)
	if p.shape.size() == keys.size():
		base = p.shape.map(func(d): return o + float(d))   # (as he was made, before any clipping at 0 or 10)
	var lo: Array = keys.map(func(_k): return 0.0)
	var hi: Array = keys.map(func(_k): return MAX)
	var ones: Array = keys.map(func(_k): return 1.0)
	var now := fit_mean(base, lo, hi, ones, clampf(o, 0.0, MAX))
	for i in keys.size():
		p.attrs[keys[i]] = now[i]
		p.attr_pot[keys[i]] = now[i]
	refit_potential(p, pot)

## An older save's player (no attributes yet): converted at his saved CURRENT and POTENTIAL
## stars, so his OVERALL and POTENTIAL are exactly what they were. Does nothing once he has them.
static func migrate(p: PoloPlayer) -> bool:
	if not p.attrs.is_empty():
		return false
	from_legacy(p, p.stars * 2.0, p.pot_stars * 2.0)
	return true

## x_i = clamp(base_i + L * w_i, lo_i, hi_i), with L chosen so the x average exactly `mean`
## (to PRECISION). Bisection: the average only grows with L.
static func fit_mean(base: Array, lo: Array, hi: Array, w: Array, mean: float) -> Array:
	var n := base.size()
	var at := func(l: float) -> Array:
		var out: Array = []
		for i in n:
			out.append(clampf(float(base[i]) + l * float(w[i]), float(lo[i]), float(hi[i])))
		return out
	var avg := func(xs: Array) -> float:
		var s := 0.0
		for x in xs:
			s += float(x)
		return s / n
	var a := -40.0
	var b := 40.0
	for _i in 80:
		var m := (a + b) * 0.5
		if float(avg.call(at.call(m))) < mean:
			a = m
		else:
			b = m
	var xs: Array = at.call((a + b) * 0.5)
	# to PRECISION, the residual on whichever one has room for it, so the sum is exact
	var target := snap(mean * n)
	var sum := 0.0
	for i in n:
		xs[i] = snap(float(xs[i]))
		sum += float(xs[i])
	var left := snap(target - sum)
	for i in n:
		if absf(left) < PRECISION * 0.5:
			break
		var nv := clampf(float(xs[i]) + left, float(lo[i]), float(hi[i]))
		left = snap(left - (nv - float(xs[i])))
		xs[i] = snap(nv)
	return xs

# ------------------------------------------------------------------ growth
## Development: `points` of training on the 0-100 rating `legacy_key` (Training, the off-season,
## event cards), turned into attribute points at the same speed as before 2.0: what that many
## points did to his overall, over 1.8 a point, four times over (one attribute is a quarter of
## his OVERALL). Never past a ceiling: what one can't take goes to the others with room.
## Returns the attribute points actually gained (negative for a loss).
static func train(p: PoloPlayer, legacy_key: String, points: float) -> float:
	if p.attrs.is_empty():
		return 0.0
	var w: Dictionary = LEGACY_WEIGHTS.get(p.pos, LEGACY_WEIGHTS[-1])
	var gain := 4.0 * points * float(w.get(legacy_key, 0.0)) / LEGACY_PER_POINT
	var to: Array = (KEEPER_TRAIN_TO if p.is_keeper() else TRAIN_TO).get(legacy_key, [])
	if to.is_empty() or is_zero_approx(gain):
		return 0.0
	return add_points(p, to, gain)

## `gain` attribute points shared out over `keys` (equally), each within its floor and ceiling;
## the rest goes to his other attributes with room. Returns what was added.
static func add_points(p: PoloPlayer, keys: Array, gain: float) -> float:
	var before := overall(p) * 4.0
	var left := gain
	for pass_n in 2:
		var pool: Array = keys if pass_n == 0 else keys_for(p)
		for _round in 4:
			var open := pool.filter(func(k): return (room(p, k) > PRECISION) if left > 0.0 else (value(p, k) > PRECISION))
			if open.is_empty() or absf(left) < PRECISION:
				break
			var each := left / open.size()
			for k in open:
				var v := value(p, k)
				var nv := clampf(v + each, 0.0, ceiling(p, k))
				p.attrs[k] = nv
				left -= nv - v
	sync(p)
	return overall(p) * 4.0 - before

# ------------------------------------------------------------------ gameplay
## An attribute as the pool's attribute effects read it: the attribute less any injury's penalty
## (Development.eff_value, never below 0); for a quick-match club's player (PoloPlayer.pro), whose
## own 0-100 ratings already carry how good he is, only what sets him apart: the attribute less
## his OVERALL over 5 (so his level isn't counted twice).
static func play_value(p: PoloPlayer, key: String) -> float:
	return base_play_value(p, key) + hot_bonus(p)

## The same without his Hot Stars (what sync builds the saved 0-100 ratings from).
static func base_play_value(p: PoloPlayer, key: String) -> float:
	if p.pro:
		return clampf(Development.eff_value(p, key) - overall(p) + 5.0, 0.0, MAX)
	return Development.eff_value(p, key)

# ------------------------------------------------------------------ HOT STARS in play
## The Hot Star Gameplay update: a man's Hot Stars (PlayerForm heat: 0, 1 HOT, 2 VERY HOT) add
## HOT_PER_STAR to every one of his four attributes for as long as he has them: +0.5 with one,
## +1.0 with two (the second star's +0.5 on top of the first's, never +1.5). Field players and
## keepers alike. Worked out from his heat every time it's asked, never stored, so it goes the
## moment the stars do, and an old save's heat simply plays.
## It isn't capped at 10: a 10 with one Hot Star plays at 10.5, with two at 11.0 (HOT_TOP), and
## every effect below is good up there (the curves carry on at the same slope; the real limits,
## probabilities and the dive's timings, keep their own bounds).
## Shown nowhere but Developer Mode's HOT STAR TESTING: his page, his card and his boxes keep his
## permanent ten.
const HOT_PER_STAR := 0.5
const HOT_TOP := MAX + 2.0 * HOT_PER_STAR
## The 0-100 points a point of Hot bonus is worth to the older mechanics (PoloPlayer.live): the
## rate HOT form always moved them, so +4 HOT and +8 VERY HOT, as before.
const HOT_RATING_PER_POINT := 8.0

## His Hot Stars now: 0, 1 or 2 (the red stars his form shows, PlayerForm.red_stars).
static func hot_stars(p: PoloPlayer) -> int:
	return PlayerForm.red_stars(p.form_state()) if p != null else 0

## +0.0 / +0.5 / +1.0.
static func hot_bonus(p: PoloPlayer) -> float:
	return HOT_PER_STAR * hot_stars(p)

## One attribute as he plays it in a game right now: play_value, his Hot Stars and all. (The same
## number every effect reads; for Developer Mode's base-against-effective table.)
static func effective(p: PoloPlayer, key: String) -> float:
	return play_value(p, key)

## A 0-10 attribute (Hot Stars and all) as a share of 10, for the effects that lerp along it:
## 0 .. 1.1 at HOT_TOP.
static func unit(v: float) -> float:
	return clampf(v / MAX, 0.0, HOT_TOP / MAX)

## A shot's pace rating (0-100, what Tempo.shooter_shot reads): his own SHOOTING alone, less any
## injury's penalty; never his overall, his other three or his team's. A shooter of PACE_MID
## shoots at Tempo.SHOT_PIVOT (the league's average pace, as before), each point either side
## PACE_PER_POINT; his Hot Stars count (play_value), so a hot 10 shoots harder than a cold one. A keeper, who has no Shooting, and a quick-match club's player (PoloPlayer.pro)
## shoot at their own 0-100 shooting rating.
const PACE_MID := 6.5
const PACE_PER_POINT := 5.75   # (5.0 until the user asked for a 15% wider gap between good and bad shooters)

static func shot_pace(p: PoloPlayer) -> float:
	if p.pro or p.is_keeper() or not p.attrs.has("sho"):
		return p.live("shoot")   # (his 0-100 shooting, his Hot bonus on it as on every rating)
	return Tempo.SHOT_PIVOT + (play_value(p, "sho") - PACE_MID) * PACE_PER_POINT

## The passer's catch-and-shoot edge, -0.10 .. +0.10 (PASS_TABLE).
static func pass_mod(passer: PoloPlayer) -> float:
	if passer == null or passer.is_keeper():
		return 0.0
	return Tempo.curve(PASS_TABLE, play_value(passer, "pas"))

## Share of the normal release time a shooter takes (0.8 .. 1.2).
static func release_mult(shooter: PoloPlayer) -> float:
	if shooter == null or shooter.is_keeper():
		return 1.0
	return 1.0 - (play_value(shooter, "sho") - 5.0) * RELEASE_PER_POINT

## How much later the keeper and the blockers react to this release (s; negative: sooner).
static func release_read(shooter: PoloPlayer) -> float:
	return (1.0 - release_mult(shooter)) * RELEASE_READ

## The defensive organisation bonus from the man in goal: (C - 5) x 0.1. Only a real keeper
## (a field player standing in has no Communication to give).
static func comm_bonus(keeper: PoloPlayer) -> float:
	if keeper == null or not keeper.is_keeper():
		return 0.0
	return (play_value(keeper, "com") - 5.0) * COMM_PER_POINT

## A defender's effective Defense (0-10) with his keeper's organising (`comm`, comm_bonus):
## the one place it's added, once for each defensive calculation that asks.
static func eff_defense(d: PoloPlayer, comm: float) -> float:
	if d == null:
		return 5.0
	if d.is_keeper():
		return clampf(5.0 + comm, 0.0, MAX)
	# (his own Defense and his keeper's organising up to 10 as before; his Hot Stars on top, past it)
	return clampf(base_play_value(d, "dfn") + comm, 0.0, MAX) + hot_bonus(d)

## The same on the 0-100 scale the pool's older defensive numbers use: his live defence (form
## and all) plus what the keeper's organising adds to it (how much a Defense point is worth there).
static func eff_defense_legacy(d: PoloPlayer, comm: float) -> float:
	return d.live("defense") + comm * (SPREAD * 0.75 + LEGACY_PER_POINT * 0.25)

## Forcing an ordinary foul: (D - S) x 4%, the defender's effective Defense against the man on the
## ball's Strength, as a multiplier on how often the press forces one.
static func foul_mult(defense: float, attacker: PoloPlayer) -> float:
	var s := play_value(attacker, "str") if attacker != null and not attacker.is_keeper() else 5.0
	return clampf(1.0 + (defense - s) * FOUL_PER_POINT, FOUL_RANGE.x, FOUL_RANGE.y)

static func strength(p: PoloPlayer) -> float:
	return play_value(p, "str") if p != null and not p.is_keeper() else 5.0

## A keeper's dive takes this share of the normal time (0.8 .. 1.2).
static func lunge_mult(keeper: PoloPlayer) -> float:
	if keeper == null or not keeper.is_keeper():
		return 1.0
	return 1.0 - (play_value(keeper, "lun") - 5.0) * LUNGE_PER_POINT

## His reach as a share of the normal (0.85 .. 1.15).
static func leg_reach(keeper: PoloPlayer) -> float:
	if keeper == null or not keeper.is_keeper():
		return 1.0
	return 1.0 + (play_value(keeper, "leg") - 5.0) * LEG_REACH_PER_POINT

## A keeper's skill (0-1, the scale the 0-100 `keeping` had) for one mechanic, from the attribute
## that owns it: "lun" his reaction and swim, "leg" his reach; his form on top as it always was
## (his Hot bonus, HOT_RATING_PER_POINT a point). A field player standing in goal: his keeping.
static func keeper_skill(keeper: PoloPlayer, key: String) -> float:
	if keeper == null:
		return 0.5
	if not keeper.is_keeper() or keeper.attrs.is_empty() or keeper.pro:
		return clampf(keeper.live("keeping") / 100.0, 0.0, 1.0)
	var form := hot_bonus(keeper) * HOT_RATING_PER_POINT
	return clampf((legacy_of(Development.eff_value(keeper, key)) + form) / 100.0, 0.0, 1.0)

## How long a dive holds full stretch before he falls (on-screen s): 0.14 at 0 .. 0.54 at 10
## (0.58 at 11, a VERY HOT 10).
## Anyone else in goal: an average pair of legs.
static func dive_window(keeper: PoloPlayer) -> float:
	if keeper == null or not keeper.is_keeper():
		return WINDOW_AT_5
	return clampf(WINDOW_AT_5 + (play_value(keeper, "leg") - 5.0) * WINDOW_PER_POINT, WINDOW_RANGE.x, WINDOW_RANGE.y)

static func block_mod(keeper: PoloPlayer) -> float:
	if keeper == null or not keeper.is_keeper():
		return 0.0
	return (play_value(keeper, "blk") - 5.0) * BLOCK_PER_POINT

## The chance a ball that's inside his reach, `along` of the way out to his fingertips (0 body ..
## 1 the very tip), is kept out: at 5 only a fingertip one can slip through (a ball into his body
## is his, as it always was), and Blocking moves it (B - 5) x 3% either way, relative. A poor
## blocker fumbles even ones at him; a fingertip one is never certain (FINGERTIP_FLOOR).
static func hold_chance(along: float, block: float) -> float:
	var edge := clampf((along - BLOCK_LEAK_FROM) / (1.0 - BLOCK_LEAK_FROM), 0.0, 1.0)
	var leak := BLOCK_EDGE_LEAK * edge
	return clampf((1.0 - leak) * (1.0 + block), 0.0, 1.0 - leak * FINGERTIP_FLOOR)
