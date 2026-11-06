class_name VisualUpgrades
extends RefCounted
## THE VISUAL UPGRADES: six categories, bought with Yellow Coins. Account-wide: the real one is
## Store.looks (user://store.cfg, never a career save), so every dynasty has them and deleting or
## making one changes nothing. Cosmetic only: nothing in the game's rules ever reads this.
## Level 1 of each is free and always owned; a tier is bought after the one below it; any owned
## level can be worn. Developer Mode makes its own, so a test never touches the real one.
## Each has its own shape: four levels, Broadcast three, Instant Replay one unlock (top()).
##
## BUILT says how far each category's effects really exist: a tier above it isn't on sale, however
## many coins you have, because nobody should pay for something that does nothing.

const PRICES := [0, 125, 250, 500]    # Level 1 .. 4, each bought separately (incremental)
const REPLAY_PRICE := 500             # INSTANT REPLAY: one purchase, for good, in every dynasty
const MAX_LEVEL := 4                  # the most levels any category has (top(): this one's)
const CATS := [
	{"id": "goal", "name": "GOAL CELEBRATIONS", "tiers": [
		["CLASSIC", "The standard goal show, BAR-DOWN! and BAR-IN! included."],
		["SHOWTIME", "Bigger GOAL! text, stronger splashes, a brief shake and small confetti."],
		["SUPERSTAR", "Arena lights, larger confetti, a louder crowd and more focus on the scorer."],
		["LEGENDARY", "Fireworks, lasers, flashing lights and confetti explosions."]]},
	{"id": "replay", "name": "INSTANT REPLAY", "tiers": [
		["LOCKED", "No automatic replay: every goal goes straight to the restart."],
		["INSTANT REPLAY", "Relive your best goals in slow motion and see exactly how the ball beat the goalkeeper."]]},
	{"id": "crowd", "name": "CROWD ATMOSPHERE", "tiers": [
		["SMALL CROWD", "Visible spectators with simple cheers and reactions."],
		["HOME SUPPORT", "More variety, school-coloured clothing and better cheering."],
		["STUDENT SECTION", "Student sections, waving flags, team banners and chants."],
		["SOLD OUT!", "Crowd waves, giant flags and synchronized cheering when the game matters."]]},
	{"id": "broadcast", "name": "BROADCAST PRESENTATION", "tiers": [
		["CLASSIC BROADCAST", "The scoreboard, clocks, team names and match information."],
		["GAMEDAY BROADCAST", "Animated logos, better scoreboard transitions and scoring notices."],
		["ENHANCED BROADCAST", "Player stat popups, save graphics, lower-thirds and portraits."]]},
	{"id": "victory", "name": "VICTORY PRESENTATION", "tiers": [
		["CLASSIC VICTORY", "The standard victory graphic, the winning team and the final score."],
		["FIREWORKS VICTORY", "The victory graphic with a real fireworks show in your team's colors."],
		["TEAM HUDDLE", "The pool deck by your bench: the team gathers, huddles up and celebrates under the fireworks."],
		["TROPHY CELEBRATION", "The whole team in robes around a trophy, raising it together under fireworks and confetti."]]},
	{"id": "pregame", "name": "PREGAME PRESENTATION", "tiers": [
		["THE ENTRANCE", "The glass-door entrance, the pool reveal and the matchup."],
		["GAMEDAY ENTRANCE", "Better lighting, logo animations and matchup graphics."],
		["PRIMETIME ENTRANCE", "Starting lineup introductions, portraits and team flags."],
		["STARTING SEVEN SHOWCASE", "The ultimate pregame experience! Watch the arena entrance cinematic and see both teams' starting seven introduced with their actual player portraits.", "STARTING SEVEN"]]},
]
const THEME_DEFAULT := "classic"      # (a save field from the retired broadcast themes)

## The highest tier of each category whose effects exist so far.
const BUILT := {"goal": 4, "replay": 2, "crowd": 4, "broadcast": 3, "victory": 4, "pregame": 4}

var unlocked := {}       # category id -> highest level owned (2-4; absent: 1)
var equipped := {}       # category id -> level worn
var packs: Array = []    # (empty since the cosmetic packs retired: EconomyMigration refunded them)
var enabled: Array = []
var theme := THEME_DEFAULT
var retired_packs: Array = []   # the packs that were owned and refunded, for the record
var bought: Array = []   # every purchase: {txn, what, n, cur}; older entries (no cur) are Blue Coins

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
	if n <= 1:
		return 0
	return REPLAY_PRICE if id == "replay" else int(PRICES[n - 1])

## What a whole category costs.
static func category_cost(id: String) -> int:
	var n := 0
	for i in top(id):
		n += price_of(id, i + 1)
	return n

func level(id: String) -> int:
	return clampi(int(unlocked.get(id, 1)), 1, top(id))

func worn(id: String) -> int:
	return clampi(int(equipped.get(id, level(id))), 1, level(id))

## The next tier's price (0 at the top).
func next_price(id: String) -> int:
	return price_of(id, level(id) + 1) if level(id) < top(id) else 0

## Why the next tier can't be bought ("" if it can). `check_built` false: Developer Mode's sandbox.
func tier_block(id: String, c: Career, vault: CoinVault = null, check_built := true) -> String:
	if cat(id).is_empty():
		return "No such upgrade."
	if level(id) >= top(id):
		return "MAX LEVEL UNLOCKED"
	if check_built and level(id) + 1 > int(BUILT.get(id, 1)):
		return "COMING IN A LATER UPDATE"
	if not Wallet.can_afford_yellow(c, next_price(id), vault):
		return "NOT ENOUGH YELLOW COINS"
	return ""

## Buys the next tier with Yellow Coins (the dynasty's own first, Wallet.spend_yellow): the coins
## and the unlock together, or neither. The unlock lives in the store's file, not the career, so
## the shared coins' part is final at once and Store.buy_tier saves both files. "" or why not.
func buy_tier(id: String, c: Career, vault: CoinVault = null, check_built := true) -> String:
	var why := tier_block(id, c, vault, check_built)
	if why != "":
		return why
	var n := next_price(id)
	var r := Wallet.spend_yellow(c, n, "UPGRADE %s" % id, vault)
	if not bool(r.ok):
		return "NOT ENOUGH YELLOW COINS"
	if String(r.txn) != "":
		Wallet.legacy_vault(vault).finish(String(r.txn))
	var to := level(id) + 1
	bought.append({"txn": String(r.txn), "what": "%s:%d" % [id, to], "n": n, "cur": Wallet.YELLOW})
	unlocked[id] = to
	equipped[id] = to
	return ""

## Wears any owned level. False if it isn't owned.
func equip(id: String, lv: int) -> bool:
	if lv < 1 or lv > level(id):
		return false
	equipped[id] = lv
	return true

func to_dict() -> Dictionary:
	return {"unlocked": unlocked.duplicate(), "equipped": equipped.duplicate(), "packs": packs.duplicate(),
		"enabled": enabled.duplicate(), "theme": theme, "retired_packs": retired_packs.duplicate(), "bought": bought.duplicate(true)}

static func from_dict(d: Dictionary) -> VisualUpgrades:
	var v := VisualUpgrades.new()
	v.unlocked = (d.get("unlocked", {}) as Dictionary).duplicate()
	v.equipped = (d.get("equipped", {}) as Dictionary).duplicate()
	v.packs = (d.get("packs", []) as Array).duplicate()
	v.enabled = (d.get("enabled", []) as Array).duplicate()
	v.theme = String(d.get("theme", THEME_DEFAULT))
	v.retired_packs = (d.get("retired_packs", []) as Array).duplicate()
	v.bought = (d.get("bought", []) as Array).duplicate(true)
	return v
