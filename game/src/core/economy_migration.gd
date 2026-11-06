class_name EconomyMigration
extends RefCounted
## THE ONE-TIME MOVE TO A SINGLE CURRENCY (the Dynasty Refinement update): an account from the days
## of Blue Coins, brought over once. Everything is in Store's own file (user://store.cfg), so
## this is per account, not per dynasty; run() does the work on what it's handed, and Store saves
## the lot, with VERSION in it, in one write: a crash before that write leaves the old file to
## migrate next time, and after it there's nothing left to do. It never reads a dynasty's coins,
## so no Yellow Coin is ever converted a second time.
##
##   1. a Level 4 replay still owned from the 3D replay's withdrawal: its own refund, first
##   2. Blue Coin balance x RATE into the shared Yellow Coins, the old balance retired
##   3. every store transaction already credited stays known, so nothing's delivered twice
##   4. Instant Replay: any paid level becomes the one unlock
##   5. Broadcast Level 4 owners: down to Level 3, the removed level refunded
##   6. cosmetic packs: each one owned refunded, the entitlement retired, the theme back to classic
##   7. PRO owned already: no coins (they're for new purchases), and flagged so none are ever paid

const VERSION := 1
## What the retired things cost in Blue Coins, for an owner with no journal entry for them
## (the journal, VisualUpgrades.bought, is what they actually paid and comes first).
const BROADCAST_L4_BLUE := 100
const PACK_BLUE := {"team_hype": 50, "showboat": 50, "chaos": 50, "keeper": 50, "spirit": 75,
	"theme_network": 50, "theme_neon": 50, "theme_gold": 50}

## `s`: {v, bank, old (the Blue Coin vault), looks, pro, pro_coins}. Updates them in place; v says
## it's done. A run on an account already at VERSION changes nothing. Returns what it did.
static func run(s: Dictionary) -> Dictionary:
	var out := {"ran": false, "blue": 0, "coins": 0, "broadcast": 0, "packs": 0, "replay": false}
	if int(s.v) >= VERSION:
		return out
	var bank: CoinVault = s.bank
	var old: CoinVault = s.old
	var looks: VisualUpgrades = s.looks
	out.ran = true
	# 1. the 3D replay's Level 4, if it never got its refund (it came back as blue)
	if int(looks.unlocked.get("replay", 1)) > 3:
		var back := _paid(looks, "replay:4", 0)
		if back > 0:
			old.balance += back
	# 2. the balance
	var blue := old.balance
	out.blue = blue
	if blue > 0:
		bank.credit(blue * Wallet.RATE, "econ-blue", "BLUE COINS CONVERTED", "migrated")
		out.coins += blue * Wallet.RATE
	old.balance = 0
	# 3. what's been credited stays credited, whichever vault it was in
	for t in old.credited:
		if not bank.seen(String(t)):
			bank.credited.append(String(t))
	# 4. Instant Replay: one unlock (a replay switched off stays off)
	if int(looks.unlocked.get("replay", 1)) >= 2:
		out.replay = true
		looks.unlocked["replay"] = 2
		looks.equipped["replay"] = mini(int(looks.equipped.get("replay", 2)), 2)
	# 5. Broadcast Level 4
	if int(looks.unlocked.get("broadcast", 1)) >= 4:
		var paid := _paid(looks, "broadcast:4", BROADCAST_L4_BLUE)
		looks.unlocked["broadcast"] = 3
		looks.equipped["broadcast"] = mini(int(looks.equipped.get("broadcast", 3)), 3)
		bank.credit(paid * Wallet.RATE, "econ-broadcast4", "BROADCAST LEVEL 4 REFUND", "refund")
		out.broadcast = paid * Wallet.RATE
		out.coins += paid * Wallet.RATE
	# 6. the cosmetic packs
	for id in looks.packs:
		var paid := _paid(looks, String(id), int(PACK_BLUE.get(String(id), 0)))
		if bank.credit(paid * Wallet.RATE, "econ-pack-" + String(id), "COSMETIC PACK REFUND", "refund"):
			out.packs += paid * Wallet.RATE
			out.coins += paid * Wallet.RATE
	looks.retired_packs.append_array(looks.packs)
	looks.packs = []
	looks.enabled = []
	looks.theme = VisualUpgrades.THEME_DEFAULT
	# 7. PRO
	if bool(s.pro):
		s.pro_coins = true
	s.v = VERSION
	return out

## What the journal says was paid for `what` (blue), or `fallback` if it has no entry.
static func _paid(looks: VisualUpgrades, what: String, fallback: int) -> int:
	var n := 0
	for b: Dictionary in looks.bought:
		if String(b.what) == what:
			n += int(b.n)
	return n if n > 0 else fallback
