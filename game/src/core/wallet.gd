class_name Wallet
extends RefCounted
## THE COIN SERVICE: every coin the game grants or spends goes through here. There is ONE currency,
## YELLOW COINS, and one balance the player sees: yellow(). Behind it, kept apart only for the books:
##
##   DYNASTY  Career.credits: given and earned in a dynasty, saved with it, gone with it.
##   SHARED   Store.bank: coins that belong to no dynasty, in every career, never lost to a new or
##            a deleted one: bought in the Polo Points Shop, converted from retired Blue Coins,
##            refunds for retired items, Pixel Polo +'s grant (CoinVault.sources says which).
##
## Spending takes the dynasty's own first, then the shared ones, journaled against the career until
## its save commits them (CoinVault.debit), so nothing is paid twice or for nothing. The vault
## arguments default to the real one; Developer Mode passes sandboxes.
##
## The old Coin Exchange is gone, but an older save can still be behind what it took: the record of
## it lives on in Store.ledger, and reconcile_exchanges takes those coins off when that save loads.

const YELLOW := "yellow"
## The retired Blue Coin's value in Yellow Coins: the exchange's rate, what every balance,
## price and refund converted at (EconomyMigration).
const RATE := 5

## The last spend or grant, for Developer Mode: {k, cur, n, earned, legacy, what}.
static var last := {}

static func legacy_vault(v: CoinVault = null) -> CoinVault:
	return v if v != null else Store.bank

## The dynasty's own Yellow Coins.
static func dynasty_yellow(c: Career) -> int:
	return c.credits if c != null else 0

## The shared Yellow Coins.
static func legacy_yellow(v: CoinVault = null) -> int:
	return legacy_vault(v).balance

## Every Yellow Coin this dynasty can spend: the one balance the game shows.
static func yellow(c: Career, v: CoinVault = null) -> int:
	return dynasty_yellow(c) + legacy_yellow(v)

static func can_afford_yellow(c: Career, n: int, v: CoinVault = null) -> bool:
	return n >= 0 and n <= yellow(c, v)

## Coins in (CreditRewards and Coaching Events, through Career.add_credits): the dynasty's own.
## `convertible` is an old save's book-keeping for reconcile_exchanges.
static func grant_yellow(c: Career, n: int, why: String, convertible: bool = true) -> int:
	if c == null or n <= 0:
		return 0
	c.credits += n
	if convertible:
		c.convertible = mini(c.convertible, c.credits - n) + n
		c.cv_earned += n
	(c.season.get("credit_log", []) as Array).append([why, n])
	last = {"k": "grant", "cur": YELLOW, "n": n, "earned": n, "legacy": 0, "what": why}
	return n

## Spends `n`: the dynasty's own first, then shared ones (journaled against the career until its
## save: CoinVault.debit). All or nothing. {ok, earned, legacy, txn}.
static func spend_yellow(c: Career, n: int, what: String = "SPEND", v: CoinVault = null) -> Dictionary:
	var lv := legacy_vault(v)
	if n <= 0 or n > yellow(c, lv):
		return {"ok": false, "earned": 0, "legacy": 0, "txn": ""}
	var from_earned := mini(n, dynasty_yellow(c))
	var from_legacy := n - from_earned
	var txn := ""
	if from_legacy > 0:
		txn = lv.debit(from_legacy, c.uid if c != null else "", what)
		if txn == "":
			return {"ok": false, "earned": 0, "legacy": 0, "txn": ""}
	if c != null:
		c.credits -= from_earned
		c.convertible = mini(c.convertible, c.credits)
	if lv == Store.bank and from_legacy > 0:
		Store.vault_changed()
	last = {"k": "spend", "cur": YELLOW, "n": n, "earned": from_earned, "legacy": from_legacy, "what": what, "txn": txn}
	return {"ok": true, "earned": from_earned, "legacy": from_legacy, "txn": txn}

## A dynasty just loaded: if its save is behind the old exchange's ledger (a save from before an
## exchange, or the game stopped before it saved), the coins it already exchanged come off, as far
## as the coins it earned go (never its others). Returns the coins taken.
static func reconcile_exchanges(c: Career, v: CoinVault = null) -> int:
	if c == null:
		return 0
	var total := (v if v != null else Store.ledger).exchanged_by(c.uid)
	var take := mini(maxi(0, total - c.cv_out), clampi(c.convertible, 0, c.credits))
	c.cv_out = total
	if take > 0:
		c.credits -= take
		c.convertible = clampi(c.convertible - take, 0, c.credits)
	return take
