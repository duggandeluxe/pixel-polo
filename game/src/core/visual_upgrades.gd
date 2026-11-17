class_name VisualUpgrades
extends RefCounted
## THE VISUAL UPGRADES: five categories, bought with Polo Points. Account-wide: the real one is
## Store.looks (user://store.cfg, never a career save), so every dynasty has them and deleting or
## making one changes nothing. Cosmetic only: nothing in the game's rules ever reads this.
## Level 1 of each is free and always owned; a tier is bought after the one below it; any owned
## level can be worn. Developer Mode makes its own, so a test never touches the real one.
## Each has its own shape: four levels, Crowd, Broadcast, Pregame and Scoreboard three (top()). SCOREBOARD has its own prices (SCOREBOARD_PRICES); its old Level 4 ELITE is gone.
## PREGAME PRESENTATION's old Level 4 (the lineup showcase) is gone too: Level 3 PRIMETIME ENTRANCE
## is its top, the prices below it unchanged.
## CROWD ATMOSPHERE's old four levels are three now (CROWD_FROM_OLD).
## GOAL CELEBRATIONS are the exception: four separate celebrations (CELEBS, Level 0 CLASSIC free
## and always owned), each bought on its own, in any order, none needing another; any owned one
## can be equipped, one at a time (celebs, celeb). The tier functions don't sell them (buy_celeb).
##
## BUILT says how far each category's effects really exist: a tier above it isn't on sale, however
## many coins you have, because nobody should pay for something that does nothing.

const PRICES := [0, 125, 250, 500]    # Level 1 .. 4, each bought separately (incremental)
const SCOREBOARD_PRICES := [0, 100, 200]   # SCOREBOARD: Level 1 .. 3 (its own; incremental too)
const MAX_LEVEL := 4                  # the most levels any category has (top(): this one's)
const CATS := [
	{"id": "goal", "name": "GOAL CELEBRATIONS", "tiers": [
		["CLASSIC", "The standard GOAL! show, BAR-DOWN! and BAR-IN! included. Always yours.", "CLASSIC"],
		["CONFETTI POPPERS", "Poppers on both back posts fire bursts of colourful confetti up over the goal, drifting down to the water.", "CONFETTI"],
		["WATER EXPLOSION", "Water cannons on both back posts blast thick jets up and out over the pool, raining back down as ripples roll out.", "WATER BLAST"],
		["GOALPOST FIREWORKS", "Rockets launch from both back posts and burst huge over the goal in your team's colours, more following.", "FIREWORKS"]]},
	{"id": "crowd", "name": "CROWD ATMOSPHERE", "tiers": [
		["SPARSE CROWD", "A quiet college game: about a quarter of the seats taken, fans in everyday clothes scattered round the stands. Always yours."],
		["FULL CROWD", "A packed house: nearly every seat taken, half the fans in your school's colours, and a lot more cheering."],
		["MAXIMUM ATMOSPHERE", "Sold out: a student section bouncing together, waving flags, team banners, a wave round the stands and giant flags.", "MAX ATMOSPHERE"]]},
	{"id": "broadcast", "name": "BROADCAST PRESENTATION", "tiers": [
		["CLASSIC BROADCAST", "The scoreboard, clocks, team names and match information."],
		["GAMEDAY BROADCAST", "Animated logos, better scoreboard transitions and scoring notices."],
		["ENHANCED BROADCAST", "Player stat popups, save graphics, lower-thirds and portraits."]]},
	{"id": "pregame", "name": "PREGAME PRESENTATION", "tiers": [
		["THE ENTRANCE", "Walk through the aquatic center's plain glass doors, out to the pool and the matchup."],
		["GAMEDAY ENTRANCE", "The arena hallway, both schools' logos on the glass doors and the venue's sign over them."],
		["PRIMETIME ENTRANCE", "Walk a dark hallway up to the logo doors, then out into the bright, lit-up pool."]]},
	{"id": "scoreboard", "name": "SCOREBOARD", "tiers": [
		["CLASSIC SCOREBOARD", "A simple dark navy board: team logos and abbreviations, yellow scores, the quarter and the clock.", "CLASSIC"],
		["ENHANCED SCOREBOARD", "A televised college look: double borders, team colors, small logos and bigger scores.", "ENHANCED"],
		["PREMIUM SCOREBOARD", "A conference championship board: a silver frame, full team names, larger logos and scores that roll over on a goal.", "PREMIUM"]]},
]
## Categories no longer sold: an older save's levels of them are dropped (its purchase history in
## `bought` stays, as the record). VICTORY: retired, and the win presentation removed from the game since.
## INSTANT REPLAY: removed from the game (no refund); only EconomyMigration still reads what an old
## save had of it (old_replay), for its one-time Blue Coin refund of the 3D replay's Level 4.
const RETIRED := ["victory", "replay"]
const THEME_DEFAULT := "classic"      # (a save field from the retired broadcast themes)

## The highest tier of each category whose effects exist so far.
const BUILT := {"goal": 4, "crowd": 3, "broadcast": 3, "pregame": 3, "scoreboard": 3}

## CROWD ATMOSPHERE went from four levels to three (crowd_v 1): an older save's levels move to
## the new ones, owned and worn: 1 SMALL CROWD -> 1 SPARSE, 2 HOME SUPPORT and 3 STUDENT SECTION
## -> 2 FULL CROWD, 4 SOLD OUT! -> 3 MAXIMUM ATMOSPHERE (the same thing, renamed).
const CROWD_V := 1
const CROWD_FROM_OLD := [1, 1, 2, 2, 3]   # old level -> new (index 0 unused)

var unlocked := {}       # category id -> highest level owned (2-4; absent: 1)
var equipped := {}       # category id -> level worn
var packs: Array = []    # (empty since the cosmetic packs retired: EconomyMigration refunded them)
var enabled: Array = []
var theme := THEME_DEFAULT
var retired_packs: Array = []   # the packs that were owned and refunded, for the record
var bought: Array = []   # every purchase: {txn, what, n, cur}; older entries (no cur) are Blue Coins
var celebs: Array = []   # GOAL CELEBRATIONS bought (1-3; Level 0 CLASSIC is always owned, never listed)
var celeb := CLASSIC     # the one equipped
var old_replay := 1      # (not saved) the retired INSTANT REPLAY level an old save had: EconomyMigration's

# ------------------------------------------------------------------ GOAL CELEBRATIONS
const CLASSIC := 0
const CONFETTI := 1
const WATER := 2
const FIREWORKS := 3
const CELEB_PRICES := [0, 50, 100, 150]
const CELEB_V := 1       # the save's celebration format (from_dict converts anything older)

static func celeb_name(n: int) -> String:
	return String(cat("goal").tiers[clampi(n, 0, 3)][0])

static func celeb_price(n: int) -> int:
	return int(CELEB_PRICES[clampi(n, 0, 3)])

func owns_celeb(n: int) -> bool:
	return n == CLASSIC or celebs.has(n)

## The equipped celebration (CLASSIC if what's saved isn't owned).
func worn_celeb() -> int:
	return celeb if owns_celeb(celeb) else CLASSIC

## Why celebration `n` can't be bought ("" if it can): independent of every other one.
func celeb_block(n: int, c: Career, vault: CoinVault = null) -> String:
	if n < 0 or n > FIREWORKS:
		return "No such celebration."
	if owns_celeb(n):
		return "ALREADY OWNED"
	if not Wallet.can_afford_yellow(c, celeb_price(n), vault):
		return "NOT ENOUGH POLO POINTS"
	return ""

## Buys celebration `n` with Polo Points and equips it: the coins and the unlock together, or
## neither (as buy_tier). "" or why not.
func buy_celeb(n: int, c: Career, vault: CoinVault = null) -> String:
	var why := celeb_block(n, c, vault)
	if why != "":
		return why
	var price := celeb_price(n)
	var r := Wallet.spend_yellow(c, price, "CELEBRATION %d" % n, vault)
	if not bool(r.ok):
		return "NOT ENOUGH POLO POINTS"
	if String(r.txn) != "":
		Wallet.legacy_vault(vault).finish(String(r.txn))
	bought.append({"txn": String(r.txn), "what": "celeb:%d" % n, "n": price, "cur": Wallet.YELLOW})
	celebs.append(n)
	celebs.sort()
	celeb = n
	return ""

## Equips an owned celebration. False if it isn't owned.
func equip_celeb(n: int) -> bool:
	if not owns_celeb(n):
		return false
	celeb = n
	return true

## An older save's Goal Celebrations tiers (1 CLASSIC .. 4 LEGENDARY, each needing the last) into
## the celebrations: every tier paid for above CLASSIC is the celebration in the same place
## (SHOWTIME: CONFETTI POPPERS, SUPERSTAR: + WATER EXPLOSION, LEGENDARY: + GOALPOST FIREWORKS),
## worn the same way. The old tiers' keys go.
func _convert_old_goal() -> void:
	var had := clampi(int(unlocked.get("goal", 1)), 1, 4)
	var wore := clampi(int(equipped.get("goal", had)), 1, had)
	celebs = []
	for n in range(1, had):
		celebs.append(n)
	celeb = wore - 1
	unlocked.erase("goal")
	equipped.erase("goal")

static func cat(id: String) -> Dictionary:
	for c in CATS:
		if String(c.id) == id:
			return c
	return {}

## The category's top level.
static func top(id: String) -> int:
	var c := cat(id)
	return (c.tiers as Array).size() if not c.is_empty() else MAX_LEVEL

## Level `n`'s price in `id` (incremental: the step up to it).
static func price_of(id: String, n: int) -> int:
	if id == "goal":
		return celeb_price(n - 1)   # (GOAL CELEBRATIONS: that celebration's own price, not a step)
	if n <= 1:
		return 0
	if id == "scoreboard":
		return int(SCOREBOARD_PRICES[n - 1])
	return int(PRICES[n - 1])

## What a whole category costs.
static func category_cost(id: String) -> int:
	var n := 0
	for i in top(id):
		n += price_of(id, i + 1)
	return n

## The highest level owned (GOAL CELEBRATIONS: the dearest one owned, 1 for CLASSIC).
func level(id: String) -> int:
	if id == "goal":
		return 1 + (int(celebs.max()) if not celebs.is_empty() else 0)
	return clampi(int(unlocked.get(id, 1)), 1, top(id))

## The level worn (GOAL CELEBRATIONS: the equipped one, 1 CLASSIC .. 4 GOALPOST FIREWORKS).
func worn(id: String) -> int:
	if id == "goal":
		return worn_celeb() + 1
	return clampi(int(equipped.get(id, level(id))), 1, level(id))

## The next tier's price (0 at the top).
func next_price(id: String) -> int:
	return price_of(id, level(id) + 1) if level(id) < top(id) else 0

## Why the next tier can't be bought ("" if it can). `check_built` false: Developer Mode's sandbox.
func tier_block(id: String, c: Career, vault: CoinVault = null, check_built := true) -> String:
	if cat(id).is_empty():
		return "No such upgrade."
	if id == "goal":
		return "BOUGHT ONE BY ONE"   # (buy_celeb: no tiers to climb)
	if level(id) >= top(id):
		return "MAX LEVEL UNLOCKED"
	if check_built and level(id) + 1 > int(BUILT.get(id, 1)):
		return "COMING IN A LATER UPDATE"
	if not Wallet.can_afford_yellow(c, next_price(id), vault):
		return "NOT ENOUGH POLO POINTS"
	return ""

## Buys the next tier with Polo Points (the dynasty's own first, Wallet.spend_yellow): the coins
## and the unlock together, or neither. The unlock lives in the store's file, not the career, so
## the shared coins' part is final at once and Store.buy_tier saves both files. "" or why not.
func buy_tier(id: String, c: Career, vault: CoinVault = null, check_built := true) -> String:
	var why := tier_block(id, c, vault, check_built)
	if why != "":
		return why
	var n := next_price(id)
	var r := Wallet.spend_yellow(c, n, "UPGRADE %s" % id, vault)
	if not bool(r.ok):
		return "NOT ENOUGH POLO POINTS"
	if String(r.txn) != "":
		Wallet.legacy_vault(vault).finish(String(r.txn))
	var to := level(id) + 1
	bought.append({"txn": String(r.txn), "what": "%s:%d" % [id, to], "n": n, "cur": Wallet.YELLOW})
	unlocked[id] = to
	equipped[id] = to
	return ""

## Wears any owned level. False if it isn't owned.
func equip(id: String, lv: int) -> bool:
	if id == "goal":
		return equip_celeb(lv - 1)
	if lv < 1 or lv > level(id):
		return false
	equipped[id] = lv
	return true

func to_dict() -> Dictionary:
	return {"unlocked": unlocked.duplicate(), "equipped": equipped.duplicate(), "packs": packs.duplicate(),
		"enabled": enabled.duplicate(), "theme": theme, "retired_packs": retired_packs.duplicate(), "bought": bought.duplicate(true),
		"celebs": celebs.duplicate(), "celeb": celeb, "celeb_v": CELEB_V, "crowd_v": CROWD_V}

static func from_dict(d: Dictionary) -> VisualUpgrades:
	var v := VisualUpgrades.new()
	v.unlocked = (d.get("unlocked", {}) as Dictionary).duplicate()
	v.equipped = (d.get("equipped", {}) as Dictionary).duplicate()
	v.packs = (d.get("packs", []) as Array).duplicate()
	v.enabled = (d.get("enabled", []) as Array).duplicate()
	v.theme = String(d.get("theme", THEME_DEFAULT))
	v.retired_packs = (d.get("retired_packs", []) as Array).duplicate()
	v.bought = (d.get("bought", []) as Array).duplicate(true)
	v.old_replay = int(v.unlocked.get("replay", 1))
	for gone in RETIRED:   # (an older save's levels of a category that's no longer sold)
		v.unlocked.erase(gone)
		v.equipped.erase(gone)
	for m: Dictionary in [v.unlocked, v.equipped]:
		# (the retired Level 4s, SCOREBOARD's ELITE and PREGAME's lineup showcase: owned or worn,
		# Level 3, every level below still owned; the purchase stays in `bought`, as the record)
		for id in ["scoreboard", "pregame"]:
			if m.has(id):
				m[id] = clampi(int(m[id]), 1, top(id))
		if m.has("crowd"):   # (CROWD ATMOSPHERE: an older save's four levels into the three)
			var n := int(m["crowd"])
			if int(d.get("crowd_v", 0)) < CROWD_V:
				n = int(CROWD_FROM_OLD[clampi(n, 1, 4)])
			m["crowd"] = clampi(n, 1, top("crowd"))
	if int(d.get("celeb_v", 0)) < CELEB_V:
		v._convert_old_goal()   # (an older save: its Goal Celebrations tiers)
	else:
		for n in d.get("celebs", []):
			if int(n) >= CONFETTI and int(n) <= FIREWORKS and not v.celebs.has(int(n)):
				v.celebs.append(int(n))
		v.celebs.sort()
		v.celeb = int(d.get("celeb", CLASSIC))
	v.celeb = v.worn_celeb()   # (CLASSIC whenever what was worn isn't owned)
	return v

# ------------------------------------------------------------------ the previews' teams
## Who the previews' other team is, for career `c`: your next opponent, else your last one, else a
## real school from your conference (any other school if it has none). "" without a career.
## Reads the career, changes nothing.
static func preview_rival_id(c: Career) -> String:
	if c == null or not c.teams.has(c.school):
		return ""
	var nxt := c.next_game()
	if nxt.has("opp") and c.teams.has(String(nxt.opp)):
		return String(nxt.opp)
	for w in range(mini(c.week, c.schedule.size() - 1), -1, -1):
		var mine: Array = c.my_games(c.schedule[w])
		for i in range(mine.size() - 1, -1, -1):
			var g: Dictionary = mine[i]
			if g.r != null:
				var opp := String(g.a if g.h == c.school else g.h)
				if c.teams.has(opp):
					return opp
	var ids: Array = c.teams.keys()
	ids.sort()
	var conf := String(c.team().conf)
	for id in ids:
		if id != c.school and String(c.teams[id].conf) == conf:
			return id
	for id in ids:
		if id != c.school:
			return id
	return ""

## A copy of career `c`'s team `id` for a preview to play with: its real name, colours, logo and
## roster, cut loose from the save so nothing a preview does can reach it. null if there's none.
static func preview_team(c: Career, id: String) -> PoloTeam:
	if c == null or not c.teams.has(id):
		return null
	return PoloTeam.from_dict((c.teams[id] as PoloTeam).to_dict())
