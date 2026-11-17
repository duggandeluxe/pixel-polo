class_name WalkOns
## AUTOMATIC WALK-ON RECRUITMENT & ROSTER COMPLETION. When a new season begins (Offseason.finish,
## once the roster is set), every program short of its places (Career.roster_cap) holds open
## tryouts: exactly enough walk-ons join to fill it, never more, nobody already there touched.
## Yours and the AI's alike, at the same odds; only yours is announced (WalkOnShow, from the
## queue's "walkons" item).
##
##   positions   keepers first (one at least, then up to KEEPER_TARGET, never past
##               Career.keeper_cap), then field players at the roster shape's needs
##               (CollegeGen.needed_pos: the same positions anyone else is made at)
##   stars       one draw each, STAR_ODDS (0.5 30%, 1 35%, 1.5 25%, 2 7%, 2.5 3%): never more
##               than 2.5. Four whole-number attributes made around that rating (the keeper's
##               four for a keeper), then checked with the game's own star calculation
##               (Attributes.stars_of) and moved or remade until they rate it exactly
##   potential   none: every ceiling IS the attribute (PoloPlayer.walk_on, held by
##               Attributes.sync on every change and every load), so no token, XP, training or
##               event can ever add a point. Hot / Cold form still plays as for anyone
##   who         a name, hometown, skin, hair and face as any player gets (CollegeGen.make_player,
##               give_home, Portrait); a class year from FR to SR, a quarter each; eligible for
##               the rookie awards in his first season here whatever his year
##               (PoloPlayer.walkon_rookie)
##   cost        nothing: no Polo Points, no market place, no scouting; never in the recruiting
##               pool or the program's recruiting class

## Each walk-on's CURRENT stars and their odds (whole percents, a hundred in all).
const STAR_ODDS := [[0.5, 30], [1.0, 35], [1.5, 25], [2.0, 7], [2.5, 3]]
const MAX_STARS := 2.5
## Keepers a program should carry (held to Career.keeper_cap).
const KEEPER_TARGET := 2
## How far one attribute strays from the player's average, so no two are made alike.
const SPREAD := 1.4
const TRIES := 12

## One walk-on's stars, from STAR_ODDS (one draw of `rng`).
static func roll_stars(rng: RandomNumberGenerator) -> float:
	var r := rng.randi_range(0, 99)
	for e in STAR_ODDS:
		r -= int(e[1])
		if r < 0:
			return float(e[0])
	return float(STAR_ODDS[0][0])

## The positions `t`'s empty places are filled at, in order: a keeper first if it has none, the
## field players a legal lineup needs (Career.FIELD_MAX), keepers to KEEPER_TARGET, the rest
## field players. Exactly as many as the places left (none when it's full).
static func plan(c: Career, t: PoloTeam, rng: RandomNumberGenerator) -> Array:
	var open := maxi(0, c.roster_cap(t.id) - t.roster.size())
	var gks := t.roster.filter(func(p: PoloPlayer): return p.is_keeper()).size()
	var field := t.roster.size() - gks
	var want_gk := mini(KEEPER_TARGET, c.keeper_cap(t.id))
	var out: Array = []
	while out.size() < open:
		if gks == 0 or (field >= Career.FIELD_MAX and gks < want_gk):
			out.append(PoloPlayer.Pos.GK)
			gks += 1
		else:
			_field(t, rng, out)
			field += 1
	return out

## A field position for the next walk-on: what the roster (and the walk-ons planned before him)
## is short of, never a keeper.
static func _field(t: PoloTeam, rng: RandomNumberGenerator, planned: Array) -> void:
	var pos := CollegeGen.needed_pos(t, rng, planned)
	if pos == PoloPlayer.Pos.GK:
		pos = CollegeGen.field_pos(rng)
	planned.append(pos)

## One walk-on at `pos`, rated `stars` (STAR_ODDS' steps): a player like any other, his four
## attributes rating exactly `stars` by the game's own calculation, every ceiling his attribute.
static func make(rng: RandomNumberGenerator, pos: int, stars: float, used: Dictionary) -> PoloPlayer:
	stars = clampf(stars, Attributes.STAR_FLOOR, MAX_STARS)
	var yr := rng.randi_range(1, 4)   # FR, SO, JR, SR: a quarter each
	var span := Attributes.star_range(stars)
	var target := rng.randf_range(span.x, span.y - 0.01)
	# his name, look and the rest made the ordinary way around that level
	var p := CollegeGen.make_player(rng, pos, Attributes.legacy_of(target) - CollegeGen.YEAR_BONUS[yr], yr, used)
	var keys := p.key_ratings()
	var vals := {}
	for _try in TRIES:
		var lean := CollegeGen.prospect_lean(rng, p)
		for k in keys:
			vals[k] = clampi(roundi(target + float(lean.get(k, 0.0)) + rng.randfn(0.0, SPREAD)), 0, 10)
		CollegeGen.fit_stars(rng, vals, stars)
		if is_equal_approx(_rates(vals), stars):
			break
	p.attrs = {}
	p.attr_pot = {}
	for k in keys:
		p.attrs[k] = float(vals[k])
		p.attr_pot[k] = float(vals[k])
	p.shape = []
	p.dev = ""
	p.walk_on = true
	p.walkon_rookie = true
	Attributes.sync(p)
	p.star_base = snappedf(p.overall(), 0.0001)
	p.stars_locked = p.stars
	CollegeGen.roll_lefty(rng, p)
	p.trait_id = Traits.best_for(p)
	CollegeGen.give_home(p, rng)
	return p

## The stars a set of whole-number attributes rates (Attributes.stars_of of their average).
static func _rates(vals: Dictionary) -> float:
	var s := 0.0
	for k in vals:
		s += float(vals[k])
	return Attributes.stars_of(s / maxf(1.0, vals.size()))

## Fills `t` to its places with walk-ons (plan, roll_stars, make): each a new id and a free cap
## number, no scholarship. Returns the players added (none when it was full).
static func fill(c: Career, t: PoloTeam) -> Array:
	var used := {}
	for p in t.roster:
		used[p.last] = true
	var added: Array = []
	for pos in plan(c, t, c.rng):
		var p := make(c.rng, int(pos), roll_stars(c.rng), used)
		p.id = c.new_id()
		p.schol = false
		Offseason.join(c, t, p)
		added.append(p)
	return added

## The rookie awards' test (ConfAwards ROOKIE OF THE WEEK, NationalAwards FRESHMAN OF THE YEAR):
## a freshman, or a walk-on in his first season here.
static func is_rookie(p: PoloPlayer) -> bool:
	return p.year == 1 or p.walkon_rookie
