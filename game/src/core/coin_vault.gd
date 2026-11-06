class_name CoinVault
extends RefCounted
## THE SHARED YELLOW COINS (the Universal Coin Wallet update): coins that belong to no dynasty,
## shared by every career on this device, spent once: bought in the store, converted from retired
## Blue Coins, refunds for retired items, Pixel Polo +'s grant. `sources` keeps those kinds apart
## for the books; to the player they're simply Yellow Coins. The real one is Store.bank (kept in
## user://store.cfg, never in a career save, so loading an older career can't bring spent coins
## back and deleting one can't take bought ones away); Developer Mode's COIN WALLET TESTING
## makes its own, so a test credit never touches the real one.
##
##   credit(n, txn)       a verified purchase in: once per store transaction id (seen())
##   debit(n, uid, what)  coins out for a career (`uid`, Career.uid), journaled as OPEN until that
##                        career's save is written (commit). If the game stops before the save,
##                        the action that was paid for never reached the save either, so the next
##                        load of that career (or its deletion) refunds it (reconcile): never
##                        charged without the thing bought, never the thing without the charge.
##   commit(uid)          the career's save is on disk: its open debits are final
##   reconcile(uid)       refunds `uid`'s open debits ("" or "*": everyone's)
## The balance never goes below 0. Limits, honestly: it's a file on the device (no account
## server): it doesn't follow you to another device, and someone who edits or copies their own
## app files can change it. The store's own records (RESTORE PURCHASES) bring back one-time
## unlocks, never consumable coins (no platform restores those).

const SEEN_MAX := 1000

var balance := 0
var credited: Array = []      # store transaction ids already credited (newest last)
var open: Array = []          # debits not yet saved with their career: {id, n, uid, what, t}
var last := {}                # the last thing that happened (Developer Mode)
## THE OLD EXCHANGE'S LEDGER (the exchange is gone; Store.ledger keeps what it did): every
## yellow-to-blue exchange ever made, so an older save can't get back coins it already exchanged
## (Wallet.reconcile_exchanges). Those blue coins became Yellow Coins when Blue Coins retired.
var exchanges: Array = []     # {id, uid, yellow, blue, t}, newest last
var exchanged := {}           # career uid -> yellow coins it has ever exchanged
var sources := {}             # kind (purchased, migrated, refund, entitlement) -> coins ever credited
var _seq := 0

func seen(txn: String) -> bool:
	return txn != "" and txn in credited

## A purchase's coins in. False (nothing added) when that transaction was already credited.
func credit(n: int, txn: String = "", what: String = "PURCHASE", kind: String = "purchased") -> bool:
	if n <= 0 or seen(txn):
		return false
	balance += n
	sources[kind] = int(sources.get(kind, 0)) + n
	if txn != "":
		credited.append(txn)
		if credited.size() > SEEN_MAX:
			credited = credited.slice(credited.size() - SEEN_MAX)
	last = {"k": "credit", "n": n, "txn": txn, "what": what}
	return true

func exchanged_by(uid: String) -> int:
	return int(exchanged.get(uid, 0))

## Coins out for career `uid` ("" for something kept outside any career, final at once). Returns
## the debit's id, or "" when there aren't enough (nothing taken).
func debit(n: int, uid: String, what: String) -> String:
	if n <= 0 or n > balance:
		return ""
	balance -= n
	_seq += 1
	var id := "d%d-%d" % [int(Time.get_unix_time_from_system()), _seq]
	if uid != "":
		open.append({"id": id, "n": n, "uid": uid, "what": what, "t": int(Time.get_unix_time_from_system())})
	last = {"k": "debit", "n": n, "txn": id, "what": what, "uid": uid}
	return id

## `uid`'s save is written: its open debits are final. Returns how many.
func commit(uid: String) -> int:
	var before := open.size()
	open = open.filter(func(o): return String(o.uid) != uid)
	return before - open.size()

## One debit is final now (what it paid for was written in the same save as this: a visual
## upgrade, kept in the store's own file).
func finish(txn: String) -> void:
	open = open.filter(func(o): return String(o.id) != txn)

## Refunds `uid`'s open debits (its save never caught up with them); "*" refunds every one.
## Returns the coins refunded.
func reconcile(uid: String) -> int:
	var back := 0
	var keep: Array = []
	for o in open:
		if uid == "*" or String(o.uid) == uid:
			back += int(o.n)
		else:
			keep.append(o)
	open = keep
	balance += back
	if back > 0:
		last = {"k": "refund", "n": back, "txn": "", "what": "UNFINISHED", "uid": uid}
	return back

func to_dict() -> Dictionary:
	return {"balance": balance, "credited": credited.duplicate(), "open": open.duplicate(true),
		"exchanges": exchanges.duplicate(true), "exchanged": exchanged.duplicate(), "sources": sources.duplicate()}

static func from_dict(d: Dictionary) -> CoinVault:
	var v := CoinVault.new()
	v.balance = maxi(0, int(d.get("balance", 0)))
	v.credited = (d.get("credited", []) as Array).map(func(x): return String(x))
	v.open = (d.get("open", []) as Array).filter(func(o): return o is Dictionary and int(o.get("n", 0)) > 0)
	v.exchanges = (d.get("exchanges", []) as Array).duplicate(true)
	v.exchanged = (d.get("exchanged", {}) as Dictionary).duplicate()
	v.sources = (d.get("sources", {}) as Dictionary).duplicate()
	return v
