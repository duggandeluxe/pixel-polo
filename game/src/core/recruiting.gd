class_name Recruiting
## THE RECRUITING MARKET (the Credit Economy & Recruiting Overhaul). No recruiting points, no
## interest, no offers and no other school in the race: eight prospects are on the market, each
## with his own price in Coaching Credits, and you buy the ones you want outright.
##   - the market (Career.market): MARKET_SIZE prospects, made when a season starts or you
##     REFRESH (the first refresh of a season free, then REFRESH_COSTS), saved with the career
##     and never remade just because a screen opened
##   - SIGN RECRUIT: his price (price_of, saved with him) comes off your credits and he is
##     yours: Career.incoming, joining as a freshman when the season is over (Offseason). No
##     more than SIGN_MAX a season. Roster size never blocks a signing: an over-cap roster is
##     warned about here (projected) and cut by hand after the season (roster_cuts)
##   - no scouting: everything about a prospect, his potential and ceilings too, is shown from
##     the start
##
## A prospect is a Dictionary: {p: PoloPlayer, price: int, legacy: true for a commitment carried
## over from the old recruiting (no price, no limit), pin: true while you've PINNED him}.
##
## PINNED RECRUITS (the Roster Needs & Recruiting Deadline update): pin up to PIN_MAX prospects
## you're considering. A pin is a bookmark, not a commitment: it costs nothing, signs nobody and
## never counts in the roster. A pinned prospect stays on the market through every refresh (only
## the others are replaced) until the recruiting class closes (the next season's new market).
##
## The AI programs don't shop here: after the season each one's graduates are replaced by
## freshmen made for its prestige (ai_class).

const MARKET_SIZE := 8
const SIGN_MAX := 4
## A refresh's cost by how many you've had this season: the first free, the fifth on 10.
const REFRESH_COSTS := [0, 3, 5, 8, 10]
const PIN_MAX := 4         # (a refresh always brings at least MARKET_SIZE - PIN_MAX new faces)

## A market prospect's CURRENT stars, by weight: mostly 2-3.5, fours uncommon, 4.5 rare, never 5.
const STAR_ODDS := [[1.5, 8.0], [2.0, 18.0], [2.5, 24.0], [3.0, 24.0], [3.5, 16.0], [4.0, 8.0], [4.5, 2.0]]
## The hidden growth classes: chance, and the half stars of POTENTIAL over his current stars
## [min, max]. `dev` is the development profile he's recorded with (PoloPlayer.dev).
const GROWTH := {
	"limited": {"chance": 0.25, "steps": Vector2i(0, 1), "dev": "limited"},
	"normal": {"chance": 0.55, "steps": Vector2i(1, 3), "dev": "moderate"},
	"high": {"chance": 0.20, "steps": Vector2i(3, 6), "dev": "high"},
}
## A low-rated prospect (2-2.5 stars) is now and then a sleeper with five-star potential.
const SLEEPER_CHANCE := 0.04
## Five-star POTENTIAL stays rare: a growth class that reaches it keeps it this often (else 4.5).
const FIVE_KEEP := 0.25

## Every prospect's hidden development profile (drawn on its own, whatever his stars): its
## chance and the attribute points of room above his four, [min, max] in all, never past 10 an
## attribute. (CollegeGen uses these for every player it makes.)
const DEV_PROFILES := {
	"near_ceiling": {"chance": 0.20, "room": Vector2i(0, 1)},
	"limited": {"chance": 0.30, "room": Vector2i(1, 3)},
	"moderate": {"chance": 0.30, "room": Vector2i(4, 8)},
	"high": {"chance": 0.15, "room": Vector2i(8, 14)},
	"exceptional": {"chance": 0.05, "room": Vector2i(14, 20)},
}

# ------------------------------------------------------------------ the price
## PRICE = clamp(round(BASE + ATTRIBUTES + POTENTIAL + POSITION), 8, 99), with S his current
## stars, A the sum of his four attributes and U the room to his four ceilings:
##   BASE = PRICE_ZERO + PRICE_LIN x (S - 1.5) + PRICE_SQ x (S - 1.5)^2
##   ATTRIBUTES = round(PRICE_ATTR x A), POTENTIAL = round(PRICE_POT x U)
## The spec's formula is 8 + 3(S - 1.5) + 5(S - 1.5)^2; its intercept and square were tuned (it
## allows that) so the prices land in the target ranges by stars: with 8 there a 1.5-star cost
## 15-20 and a 2-star 19-24, over their 8-14 and 12-19 (--test credit_economy prints the spread).
const PRICE_ZERO := 2.0
const PRICE_LIN := 3.0
const PRICE_SQ := 6.0
const PRICE_ATTR := 0.4
const PRICE_POT := 0.65
const PRICE_MIN := 8
const PRICE_MAX := 99
const POS_PRICE := {PoloPlayer.Pos.GK: 3, PoloPlayer.Pos.CENTER: 2, PoloPlayer.Pos.DEFENDER: 2,
	PoloPlayer.Pos.UTILITY: 1, PoloPlayer.Pos.DRIVER: 0, PoloPlayer.Pos.WING: 0}

## His price from what he is now: stars, attributes, room to grow, position. Set once, when he's
## made (new_recruit), and saved with him: it never moves while he's on the market.
static func price_of(p: PoloPlayer) -> int:
	var s := p.stars - 1.5
	var base := PRICE_ZERO + PRICE_LIN * s + PRICE_SQ * s * s
	var a := 0.0
	var u := 0.0
	for k in Attributes.keys_for(p):
		a += Attributes.value(p, k)
		u += maxf(0.0, Attributes.ceiling(p, k) - Attributes.value(p, k))
	var total := base + roundi(PRICE_ATTR * a) + roundi(PRICE_POT * u) + int(POS_PRICE.get(p.pos, 0))
	return clampi(roundi(total), PRICE_MIN, PRICE_MAX)

# ------------------------------------------------------------------ the market
## A new market: MARKET_SIZE prospects, replacing whatever was on it but the pinned (`keep_pins`
## false: a new recruiting class, the pins gone too).
static func new_market(c: Career, keep_pins: bool = true) -> void:
	var used := {}
	for r in c.incoming:
		used[(r.p as PoloPlayer).last] = true
	var out: Array = c.market.filter(func(r): return bool(r.get("pin", false))) if keep_pins else []
	for r in out:
		used[(r.p as PoloPlayer).last] = true
	while out.size() < MARKET_SIZE:
		var r := new_recruit(c, used)
		used[(r.p as PoloPlayer).last] = true
		out.append(r)
	c.market = out

## A new recruiting season (Career.start_season): a fresh market (last class's pins expire with
## it), the free refresh back.
static func start_season(c: Career) -> void:
	c.refreshes = 0
	new_market(c, false)

## One market prospect: his stars (STAR_ODDS), a growth class for his POTENTIAL (GROWTH, or a
## sleeper's five), his four attributes and ceilings built to them (CollegeGen), and his price.
static func new_recruit(c: Career, used: Dictionary = {}) -> Dictionary:
	var stars := float(_weighted(c.rng, STAR_ODDS))
	var growth := String(_weighted(c.rng, GROWTH.keys().map(func(k): return [k, float(GROWTH[k].chance)])))
	var pot := minf(5.0, stars + 0.5 * c.rng.randi_range(int(GROWTH[growth].steps.x), int(GROWTH[growth].steps.y)))
	if pot >= 5.0 and c.rng.randf() >= FIVE_KEEP:
		pot = 4.5
	if stars <= 2.5 and c.rng.randf() < SLEEPER_CHANCE:
		growth = "high"
		pot = 5.0
	var p := make(c.rng, stars, pot, growth, used)
	p.id = c.new_id()
	return {"p": p, "price": price_of(p), "legacy": false}

## A prospect of CURRENT `stars` and POTENTIAL `pot` (CollegeGen.make_prospect, grow_to), at `pos`
## (-1: any).
static func make(rng: RandomNumberGenerator, stars: float, pot: float, growth: String, used: Dictionary, pos: int = -1) -> PoloPlayer:
	var p := CollegeGen.make_prospect(rng, stars, roll_dev(rng), used, pos)
	CollegeGen.grow_to(rng, p, maxf(pot, p.stars))
	p.dev = String(GROWTH.get(growth, GROWTH.normal).dev)
	return p

## What the next refresh costs.
static func refresh_cost(c: Career) -> int:
	return int(REFRESH_COSTS[mini(c.refreshes, REFRESH_COSTS.size() - 1)])

## Why you can't refresh now ("" if you can).
static func refresh_block(c: Career) -> String:
	if c.phase == "cuts":
		return "The market opens again with the new season."
	if refresh_cost(c) > c.wallet():
		return "Needs %s (you have %s)." % [CreditCoin.tag(refresh_cost(c)), CreditCoin.tag(c.wallet())]
	return ""

## REFRESH RECRUITS: pays the cost, and new prospects replace the market's unpinned ones. Who you've signed
## stays signed and counted. Returns "" or why not.
static func refresh(c: Career) -> String:
	var block := refresh_block(c)
	if block != "":
		return block
	var cost := refresh_cost(c)
	if cost > 0 and not c.spend_credits(cost, "MARKET REFRESH"):
		return "Not enough credits."
	c.refreshes += 1
	new_market(c)
	return ""

# ------------------------------------------------------------------ pins
static func pinned(c: Career) -> Array:
	return c.market.filter(func(r): return bool(r.get("pin", false)))

static func is_pinned(r: Dictionary) -> bool:
	return bool(r.get("pin", false))

## PIN / UNPIN a market prospect. Returns "" or why not. Costs nothing, signs nobody.
static func toggle_pin(c: Career, r: Dictionary) -> String:
	if not r in c.market:
		return "He's no longer on the market."
	if is_pinned(r):
		r.erase("pin")
		return ""
	if c.phase == "cuts":
		return "The market opens again with the new season."
	if pinned(c).size() >= PIN_MAX:
		return "You can pin %d prospects at most." % PIN_MAX
	r["pin"] = true
	return ""

# ------------------------------------------------------------------ the deadline
## Signings left this season (never below 0).
static func slots_left(c: Career) -> int:
	return maxi(0, SIGN_MAX - signed_count(c))

## Everything the deadline warnings need, from the career as it is: {pinned (unsigned pinned
## prospects), slots (signings left), credits, projected, cap, over, needs (RosterNeeds.of),
## need (kinds NEED), thin (kinds THIN), issues (true when something is worth a warning)}.
static func deadline(c: Career) -> Dictionary:
	var needs := RosterNeeds.of(c)
	var pins := pinned(c)
	var d := {"pinned": pins, "slots": slots_left(c), "credits": c.wallet(), "projected": projected(c), "cap": c.roster_max(),
		"over": over_by(c), "needs": needs, "need": RosterNeeds.short_of(needs, RosterNeeds.NEED), "thin": RosterNeeds.short_of(needs, RosterNeeds.THIN)}
	# worth a warning: a pinned prospect still unsigned, a starting place nobody can fill, or cuts to come
	d["issues"] = not pins.is_empty() or not (d.need as Array).is_empty() or int(d.over) > 0
	return d

## The deadline's facts in words (both warnings).
static func deadline_text(d: Dictionary) -> String:
	var lines := PackedStringArray()
	var pins: Array = d.pinned
	lines.append("%d UNSIGNED PINNED RECRUIT%s" % [pins.size(), "" if pins.size() == 1 else "S"])
	for r in pins.slice(0, 4):
		var p: PoloPlayer = r.p
		lines.append("   %s  %s  %s" % [p.last.to_upper(), p.pos_text(), CreditCoin.tag(int(r.price))])
	lines.append("SIGNING SLOTS REMAINING: %d" % int(d.slots))
	lines.append("CREDITS: %s" % CreditCoin.tag(int(d.credits)))
	lines.append("PROJECTED ROSTER: %d / %d%s" % [int(d.projected), int(d.cap), ("  (%d MUST BE CUT)" % int(d.over)) if int(d.over) > 0 else ""])
	for g in d.need:
		lines.append("%s - NEED" % g)
	for g in d.thin:
		lines.append("%s - THIN" % g)
	if int(d.slots) == 0 and not pins.is_empty():
		lines.append("\nYour recruiting class is full: these pinned recruits can't be signed this season.")
	return "\n".join(lines)

# ------------------------------------------------------------------ signing
## Recruits signed this season (the old recruiting's carried-over commitments don't count).
static func signed_count(c: Career) -> int:
	return c.incoming.filter(func(r): return not bool(r.get("legacy", false))).size()

## Why `r` can't be signed now ("" if he can). The roster's size never stops it. `credits`
## false: everything but whether you can pay.
static func sign_block(c: Career, r: Dictionary, credits: bool = true) -> String:
	if c.phase == "cuts":
		return "Signing reopens with the new season."
	if not r in c.market:
		return "He's no longer on the market."
	if signed_count(c) >= SIGN_MAX:
		return "You've signed %d recruits this season, the most allowed." % SIGN_MAX
	if credits and int(r.price) > c.wallet():
		return "Needs %s (you have %s)." % [CreditCoin.tag(int(r.price)), CreditCoin.tag(c.wallet())]
	return ""

## SIGN RECRUIT (after the screen's confirmation): his price comes off, he leaves the market and
## joins Incoming Recruits, yours for next season whatever happens. Returns "" or why not.
static func sign(c: Career, r: Dictionary) -> String:
	var block := sign_block(c, r)
	if block != "":
		return block
	if not c.spend_credits(int(r.price), "RECRUIT"):
		return "Not enough credits."
	c.market.erase(r)
	c.incoming.append(r)
	var p: PoloPlayer = r.p
	c.add_news("SIGNED: %s (%s, %s*) joins next season" % [p.short_name(), p.pos_text(), PlayerForm.star_text(p.stars)])
	return ""

# ------------------------------------------------------------------ next season's roster
## Your seniors, who leave after this season.
static func graduating(c: Career) -> Array:
	return c.team().roster.filter(func(p: PoloPlayer): return p.year >= 4)

## PROJECTED ROSTER = current roster - graduating seniors + signed incoming recruits.
static func projected(c: Career, extra: int = 0) -> int:
	return c.team().roster.size() - graduating(c).size() + c.incoming.size() + extra

## How many must be cut after the season if nothing changes (0: none); `extra` more signings.
static func over_by(c: Career, extra: int = 0) -> int:
	return maxi(0, projected(c, extra) - c.roster_max())

## Next season's keepers (returning and incoming), against Career.keeper_cap.
static func projected_keepers(c: Career, extra: int = 0) -> int:
	var n := c.team().roster.filter(func(p: PoloPlayer): return p.is_keeper() and p.year < 4).size()
	return n + c.incoming.filter(func(r): return (r.p as PoloPlayer).is_keeper()).size() + extra

static func find(c: Career, pid: int) -> Dictionary:
	for r in c.market + c.incoming:
		if (r.p as PoloPlayer).id == pid:
			return r
	return {}

# ------------------------------------------------------------------ the AI programs
## Freshmen for an AI program's empty places (after its seniors graduate): stars around what its
## prestige draws (AI_STARS), potential from the growth classes. Its places are filled by
## position (CollegeGen.needed_pos). Returns them; nobody is added here.
const AI_STARS := Vector2(1.75, 3.25)   # the centre of a class's stars, prestige 15 .. 99 (keeps the league's level: --test balance)
const AI_SPREAD := 0.5

static func ai_class(c: Career, t: PoloTeam, n: int) -> Array:
	var used := {}
	for p in t.roster:
		used[p.last] = true
	var centre := lerpf(AI_STARS.x, AI_STARS.y, clampf((t.prestige - 15.0) / 84.0, 0.0, 1.0))
	var out: Array = []
	var extra: Array = []
	for _i in n:
		var stars := clampf(PlayerForm.snap_half(centre + c.rng.randfn(0.0, AI_SPREAD)), 1.5, 4.5)
		var growth := String(_weighted(c.rng, GROWTH.keys().map(func(k): return [k, float(GROWTH[k].chance)])))
		var pot := minf(5.0, stars + 0.5 * c.rng.randi_range(int(GROWTH[growth].steps.x), int(GROWTH[growth].steps.y)))
		var pos := CollegeGen.needed_pos(t, c.rng, extra)
		var p := make(c.rng, stars, pot, growth, used, pos)
		p.id = c.new_id()
		used[p.last] = true
		extra.append(p.pos)
		out.append(p)
	return out

# ------------------------------------------------------------------ dice
## One of DEV_PROFILES, by its chance.
static func roll_dev(rng: RandomNumberGenerator) -> String:
	return String(_weighted(rng, DEV_PROFILES.keys().map(func(k): return [k, float(DEV_PROFILES[k].chance)])))

## The first of one of [[value, weight], ...], by weight.
static func _weighted(rng: RandomNumberGenerator, pairs: Array) -> Variant:
	var total := 0.0
	for e in pairs:
		total += float(e[1])
	var x := rng.randf() * total
	for e in pairs:
		x -= float(e[1])
		if x < 0.0:
			return e[0]
	return pairs[pairs.size() - 1][0]

# ------------------------------------------------------------------ saving
static func to_save(list: Array) -> Array:
	return list.map(func(r): return {"p": (r.p as PoloPlayer).to_dict(), "price": int(r.price),
		"legacy": bool(r.get("legacy", false)), "pin": bool(r.get("pin", false))})

static func from_save(list: Array) -> Array:
	var out: Array = []
	for d in list:
		if not d is Dictionary or not d.has("p") or not d.has("price"):
			continue
		var p := PoloPlayer.from_dict(d.p)
		var r := {"p": p, "price": clampi(int(d.price), 0, PRICE_MAX), "legacy": bool(d.get("legacy", false))}
		if bool(d.get("pin", false)):
			r["pin"] = true
		out.append(r)
	return out

## The old recruiting's commitment to your school (a save from before this update): one of your
## incoming recruits now, as he was promised, with no price and outside the season's limit.
static func from_commit(_c: Career, d: Dictionary) -> Dictionary:
	return {"p": PoloPlayer.from_dict(d.p), "price": 0, "legacy": true}
