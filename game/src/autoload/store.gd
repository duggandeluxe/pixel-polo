extends Node
## Store: in-app purchases. Pixel Polo + (one-time unlock) and Yellow Coin packs.
## Ported from Retro Swim with the same product ids, so its App Store setup steps carry over.
##
## Backends (picked at startup):
##   * StoreKit 2 on iOS          - godot-storekit2 plugin (class GodotStoreKit2)
##   * Google Play Billing        - GodotGooglePlayBilling plugin (JNI singleton)
##   * Test store in the editor   - no money, clearly labelled; never in an exported game (web,
##                                   desktop or phone: those have a real store or none)
## A phone build without its plugin has no store: buttons say so instead of faking purchases.
##
## ONE CURRENCY: YELLOW COINS (Wallet has the rules). What's bought here is `bank`, a CoinVault in
## user://store.cfg (never in a career save): shared by every career, spent once, never lost to a
## new career, a deleted one or RESET. Blue Coins are gone: EconomyMigration converted them, once
## per account (`econ_v`); `ledger` is their old vault, kept for the Coin Exchange's history.
## Every purchase is credited once (its store transaction id: seen()).
##
## Prices shown in the UI come from the store (localized) once it answers; until then the
## USD list price below is shown. Product IDs must match App Store Connect / Play Console
## (see docs/SPEC.md, section 4).

signal products_updated
signal state_changed
signal purchase_finished(product_id: String, ok: bool, message: String)

const SAVE_PATH := "user://store.cfg"

const PRO_ID := "pro_unlock"
const TEAMS_ID := "all_teams_unlock"
## One-time unlocks the store keeps track of (the rest are consumables): owned for good, restored
## on a new device, never bought twice.
const NON_CONSUMABLES := ["pro_unlock", "all_teams_unlock", "division2_pack", "division3_pack"]
const STARTER_ID := "starter_pack"
const PLAYOFF_ID := "playoff_bundle"
## The four Yellow Coin packs on sale. (Their ids stay blue_*: a product id can't change once it's
## on the App Store and Play Console; the coins are the old Blue Coin amounts x 5.)
## The older products stay in PRODUCTS only so a purchase still pending on the store's side
## arrives; nothing sells them.
const PACK_IDS := ["blue_100", "blue_350", "blue_650", "blue_1400"]

## The catalog. "credits" packs are consumables; PRO is a non-consumable. The starter pack is a
## consumable the game only offers once; the playoff bundle is only on sale around the playoffs.
const PRODUCTS := {
	"pro_unlock": {"type": "pro", "title": "PIXEL POLO +", "usd": 7.99},
	"all_teams_unlock": {"type": "teams", "title": "ALL 30 TEAMS", "usd": 2.99},
	"division2_pack": {"type": "division", "pack": "div2", "title": "DIVISION II EXPANSION PACK", "usd": 2.99},
	"division3_pack": {"type": "division", "pack": "div3", "title": "DIVISION III EXPANSION PACK", "usd": 3.99},
	"blue_100": {"type": "pack", "title": "STARTER PACK", "credits": 500, "usd": 1.99},
	"blue_350": {"type": "pack", "title": "GAMEDAY PACK", "credits": 1750, "usd": 5.99},
	"blue_650": {"type": "pack", "title": "ALL-STAR PACK", "credits": 3250, "usd": 9.99},
	"blue_1400": {"type": "pack", "title": "LEGENDARY PACK", "credits": 7000, "usd": 19.99},
	"credits_100": {"type": "pack", "title": "HANDFUL", "credits": 100, "usd": 0.99},
	"credits_250": {"type": "pack", "title": "BALL BAG", "credits": 250, "usd": 1.99},
	"credits_700": {"type": "pack", "title": "CAP RACK", "credits": 700, "usd": 4.99, "badge": "COACH'S PICK"},
	"credits_1600": {"type": "pack", "title": "POOL DECK", "credits": 1600, "usd": 9.99},
	"credits_3600": {"type": "pack", "title": "GRANDSTAND", "credits": 3600, "usd": 19.99},
	"credits_6500": {"type": "pack", "title": "DYNASTY VAULT", "credits": 6500, "usd": 29.99, "badge": "BEST VALUE"},
	"starter_pack": {"type": "starter", "title": "STARTER PACK", "credits": 600, "usd": 1.99},
	"playoff_bundle": {"type": "playoff", "title": "PLAYOFF BUNDLE", "credits": 900, "usd": 4.99},
}
## What PIXEL POLO + gives (the shop's card and wherever a PRO feature is locked), both division
## packs among it (division_access).
const PRO_COINS := 500                # once per legitimate purchase: pro_coins
const PRO_PERKS := [
	"500 Yellow Coins",
	"Player Name & Number Customization",
	"Division II Expansion Pack",
	"Division III Expansion Pack",
]
## The expansion packs. Each is a real one-time product, but it's only for sale once the platform
## has confirmed it with a price (division_for_sale): until the product exists in App Store Connect
## and Play Console the shop says COMING SOON and nothing can be bought. `usd` is the planned list
## price, never charged or shown from here. Ownership (division_access) is the account's; which
## dynasties use a pack is each career's own (Career.divisions).
const DIVISIONS := {
	"div2": {"title": "DIVISION II EXPANSION PACK", "tag": "DIVISION II", "product": "division2_pack", "div": 2, "usd": 2.99, "desc": "Seven WWPA programs, and the Division II Championship with its NCSA bid."},
	"div3": {"title": "DIVISION III EXPANSION PACK", "tag": "DIVISION III", "product": "division3_pack", "div": 3, "usd": 3.99, "desc": "Seventeen SCIAC, MPSF East and NWPC programs, and the NCSA Division III Championship."},
}
const GOLD_CAP := "ffcf3f"

var pro := false
var packs: Array = []                 # the division packs bought ("div2", "div3"; Pixel Polo + owners have both anyway)
var all_teams := false                # ALL 30 TEAMS owned: every school open on the Road to Glory (Progression.is_unlocked)
var pro_coins := false                # PRO's coins have been paid (or never will be): never again
var econ_v := 0                       # EconomyMigration's version on this account
var bank := CoinVault.new()           # the shared YELLOW COINS: bought, converted, refunded, granted
var ledger := CoinVault.new()         # the retired Blue Coin vault: the old exchange's history, no balance
var looks := VisualUpgrades.new()     # the visual upgrades owned (account-wide)
## The shared coins' balance (bank.balance), for reading; Wallet spends it.
var vault: int:
	get:
		return bank.balance
	set(v):
		bank.balance = maxi(0, v)
var starter_bought := false
var starter_offered := false
var playoff_offered := ""             # season label the playoff popup was last shown in
var gold_cap := false
var caps_owned: Array = []            # (the old Cap Shop: records only, nothing reads them)
var cap_selected := "classic"
var receipts: Array = []              # [{"id","credits","t"}], newest last, capped
var _pending: Array = []              # product ids waiting on approval (Ask to Buy / pending)
var _prices := {}                     # product id -> localized price string from the store
var _inflight := ""                   # product id the player is buying right now
var _backend = null
var backend_name := "none"            # storekit | play | test | none
## After RESET GAME (reset_all): the store's own word that one-time unlocks are owned (its startup
## sync, a re-announced transaction) is set aside, so the reset really leaves the game without
## them; RESTORE PURCHASES (or buying again) brings them back, as on a new device.
var hold_owned := false

## A store transaction already credited.
func seen(txn: String) -> bool:
	return bank.seen(txn) or ledger.seen(txn)

## Buys a visual upgrade's next tier with Yellow Coins: the coins and the unlock in one go, and
## both files written at once, so reloading can't keep the one without the other. "" or why not.
func buy_tier(id: String, c: Career = Game.career) -> String:
	var why := looks.buy_tier(id, c)
	if why == "":
		vault_changed()
		Game.save_career()
	return why

func equip_level(id: String, lv: int) -> void:
	if looks.equip(id, lv):
		vault_changed()

## Does this account have division pack `id` ("div2", "div3"): bought, or with Pixel Polo +. Only a
## verified purchase or restore ever sets either.
## With the lower divisions hibernated (Colleges.ENABLE_LOWER_DIVISIONS) no pack is in the game: the
## purchase record (`packs`, PRO) is kept as it is and counts again once they're back.
func division_access(id: String) -> bool:
	return DIVISIONS.has(id) and Colleges.division_enabled(int(DIVISIONS[id].div)) and (pro or id in packs)

## The same by division number (Colleges.D2, D3); Division I is the base game.
func division_owned(d: int) -> bool:
	return d == Colleges.D1 or division_access("div%d" % d)

## Can the pack be bought now: only once the platform's store has confirmed the product with a
## price. Nothing else ever opens the button, the editor's test store included. (Hibernated: never.)
func division_for_sale(id: String) -> bool:
	return DIVISIONS.has(id) and Colleges.division_enabled(int(DIVISIONS[id].div)) and available() and _prices.has(String(DIVISIONS[id].product))

## The packs the shop lists: none while the lower divisions are hibernated.
func listed_divisions() -> Array:
	return DIVISIONS.keys().filter(func(id): return Colleges.division_enabled(int(DIVISIONS[id].div)))

## What PIXEL POLO + gives, as the screens list it: PRO_PERKS less any hibernated division's pack.
func pro_perks() -> Array:
	return PRO_PERKS.filter(func(x): return not String(x).begins_with("Division") or Colleges.lower_divisions)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	if ClassDB.class_exists("GodotStoreKit2"):
		_backend = load("res://src/store/backend_storekit.gd").new(self)
		backend_name = "storekit"
	elif Engine.has_singleton("GodotGooglePlayBilling"):
		_backend = load("res://src/store/backend_play.gd").new(self)
		backend_name = "play"
	elif OS.has_feature("editor"):
		_backend = load("res://src/store/backend_test.gd").new(self)
		backend_name = "test"
	if _backend != null:
		_backend.start(PRODUCTS.keys())

# ------------------------------------------------------------------ queries
func available() -> bool:
	return _backend != null and _backend.ready()

func is_test_store() -> bool:
	return backend_name == "test"

func product(id: String) -> Dictionary:
	return PRODUCTS.get(id, {})

## Does the player own one-time unlock `id` (as last verified by the store)?
func owns(id: String) -> bool:
	match id:
		PRO_ID:
			return pro
		TEAMS_ID:
			return all_teams
	var pack := String(product(id).get("pack", ""))
	return pack != "" and pack in packs

func credits_of(id: String) -> int:
	return int(product(id).get("credits", 0))

func price(id: String) -> String:
	if _prices.has(id):
		return _prices[id]
	return "$%.2f" % float(product(id).get("usd", 0.0))

# ------------------------------------------------------------------ actions
func buy(id: String) -> void:
	if not PRODUCTS.has(id):
		return
	# refusals are announced on the next frame so a caller can await purchase_finished after buy()
	if not available():
		purchase_finished.emit.call_deferred(id, false, "The store isn't available right now.")
		return
	if id in NON_CONSUMABLES and owns(id):
		purchase_finished.emit.call_deferred(id, true, "You already own %s." % product(id).get("title", id))
		return
	if id == STARTER_ID and starter_bought:
		purchase_finished.emit.call_deferred(id, false, "The starter pack is a one-time offer.")
		return
	if _inflight != "":
		return
	_inflight = id
	_backend.buy(id)

func restore() -> void:
	if hold_owned:
		hold_owned = false   # (you asked for them back: the reset's hold is over)
		_save()
	if not available():
		purchase_finished.emit.call_deferred("restore", false, "The store isn't available right now.")
		return
	_backend.restore()

## The vault moved (Wallet.spend took from it): saved at once, so it never depends on a career save.
func vault_changed() -> void:
	_save()
	state_changed.emit()

## A career's save is on disk (Game.save_career): what it spent from the vault is final.
func commit_career(uid: String) -> void:
	if uid != "" and bank.commit(uid) > 0:
		_save()

## A career is loaded or deleted (Game): vault coins it spent on something its save never got are
## refunded ("*": every career, RESET EVERYTHING). Returns the coins refunded.
func reconcile_career(uid: String) -> int:
	if uid == "":
		return 0
	var back := bank.reconcile(uid)
	if back > 0:
		_save()
		state_changed.emit()
	return back

# ------------------------------------------------------------------ backend callbacks
func _on_price(id: String, localized: String) -> void:
	if localized != "":
		_prices[id] = localized
		products_updated.emit()

func _on_owned(id: String) -> void:
	## a non-consumable the store says the player owns (startup sync / restore)
	if hold_owned:
		return   # (reset: only RESTORE PURCHASES brings it back)
	if id in NON_CONSUMABLES and not owns(id):
		_grant(id, "restored")

## A completed purchase. token = store transaction token when there is one (Play), used to
## never grant the same purchase twice.
func _on_purchased(id: String, token: String = "") -> void:
	if seen(token):
		_finish_inflight(id, false, "")   # already credited: no second toast
		return
	if id in NON_CONSUMABLES and owns(id):
		_finish_inflight(id, true, "")
		return
	if hold_owned and id in NON_CONSUMABLES and id != _inflight:
		return   # (reset: a transaction the store re-announces doesn't bring it back; buying it does)
	var consumable: bool = not id in NON_CONSUMABLES
	if consumable and token == "" and id != _inflight and not id in _pending:
		# StoreKit re-announces transactions it has already delivered; only credit consumables
		# the player is buying right now or that were waiting on approval.
		return
	_pending.erase(id)
	_grant(id, "purchase", token)
	_finish_inflight(id, true, "")

func _on_pending(id: String) -> void:
	if not id in _pending:
		_pending.append(id)
	_save()
	_finish_inflight(id, false, "Purchase pending: it will arrive once it's approved.")

func _on_failed(id: String, message: String, canceled: bool) -> void:
	_finish_inflight(id, false, "" if canceled else message)

func _on_revoked(id: String) -> void:
	if id == PRO_ID and pro:
		pro = false
	elif id == TEAMS_ID and all_teams:
		all_teams = false   # (refunded: back to the schools earned on the Road to Glory)
	elif String(product(id).get("pack", "")) in packs:
		packs.erase(String(product(id).pack))   # (a dynasty already playing it keeps its teams)
	else:
		return
	_save()
	state_changed.emit()

func _on_restore_done(message: String) -> void:
	var owned := NON_CONSUMABLES.filter(func(id): return owns(id)).map(func(id): return String(product(id).title))
	purchase_finished.emit("restore", message == "", message if message != "" else (("Restored: %s." % ", ".join(owned)) if not owned.is_empty() else "Nothing to restore."))

## Every outcome is announced (listeners filter by product id); the in-flight lock only clears
## for the purchase the player started.
func _finish_inflight(id: String, ok: bool = true, message: String = "") -> void:
	if _inflight == id:
		_inflight = ""
	purchase_finished.emit(id, ok, message)

# ------------------------------------------------------------------ granting
func _grant(id: String, why: String, token: String = "") -> void:
	var p := product(id)
	match p.get("type", ""):
		"pro":
			pro = true
			# the coins come with a real purchase, once: a restore, a re-announced transaction or
			# another device's sync never pays them, and it's never asked again after one
			if why == "purchase" and not pro_coins:
				bank.credit(PRO_COINS, "pro-coins", "PIXEL POLO +", "entitlement")
			pro_coins = true
		"teams":
			all_teams = true   # (only who you can pick: no achievement, no roster, no rating changes)
		"division":
			if not String(p.pack) in packs:
				packs.append(String(p.pack))   # (no coins, no teams here: a dynasty adds them itself)
		"pack", "starter", "playoff":
			if not bank.credit(int(p.credits), token, String(p.get("title", id))):
				return   # (that transaction was already credited)
			if p.type == "starter":
				starter_bought = true
				gold_cap = true
				cap_selected = "gold"   # the starter pack's gold trim goes straight on
			if p.type == "playoff":
				_apply_playoff()
	receipts.append({"id": id, "credits": int(p.get("credits", 0)), "why": why, "txn": token, "t": int(Time.get_unix_time_from_system())})
	if receipts.size() > 50:
		receipts = receipts.slice(receipts.size() - 50)
	_save()
	Sfx.play("coins")
	if id != _inflight and why == "purchase":
		# arrived in the background (an approved Ask to Buy, a purchase made on another device)
		Game.toast("%s arrived: %s" % [p.get("title", id), CreditCoin.tag(int(p.get("credits", 0)), true)] if p.has("credits") else "%s unlocked" % p.get("title", id), UI.GOLD)
	state_changed.emit()

## Everyone healthy.
func _apply_playoff() -> void:
	var c = Game.career
	if c == null:
		return
	for p in c.team().roster:
		Development.heal(p)
	c.add_news("PLAYOFF BUNDLE: ice baths, physio, a pep rally. The whole team is fit and fired up.")
	Game.save_career()

# ------------------------------------------------------------------ persistence
func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	pro = cf.get_value("s", "pro", false)
	all_teams = cf.get_value("s", "all_teams", false)
	packs = cf.get_value("s", "packs", [])
	bank = CoinVault.from_dict({"balance": int(cf.get_value("s", "vault", 0)), "credited": cf.get_value("s", "tokens", []),
		"open": cf.get_value("s", "open_txns", []), "sources": cf.get_value("s", "sources", {})})
	ledger = CoinVault.from_dict({"balance": int(cf.get_value("s", "blue", 0)), "credited": cf.get_value("s", "blue_tokens", []),
		"exchanges": cf.get_value("s", "exchanges", []), "exchanged": cf.get_value("s", "exchanged", {})})
	looks = VisualUpgrades.from_dict(cf.get_value("s", "looks", {}))
	pro_coins = cf.get_value("s", "pro_coins", false)
	econ_v = cf.get_value("s", "econ_v", 0)
	starter_bought = cf.get_value("s", "starter_bought", false)
	starter_offered = cf.get_value("s", "starter_offered", false)
	playoff_offered = cf.get_value("s", "playoff_offered", "")
	gold_cap = cf.get_value("s", "gold_cap", false)
	caps_owned = cf.get_value("s", "caps_owned", [])
	cap_selected = cf.get_value("s", "cap_selected", "classic")
	receipts = cf.get_value("s", "receipts", [])
	_pending = cf.get_value("s", "pending", [])
	hold_owned = cf.get_value("s", "hold_owned", false)
	migrate_economy()

## EconomyMigration on this account; saved in the one write that marks it done.
func migrate_economy() -> Dictionary:
	var s := {"v": econ_v, "bank": bank, "old": ledger, "looks": looks, "pro": pro, "pro_coins": pro_coins}
	var out := EconomyMigration.run(s)
	if bool(out.ran):
		econ_v = int(s.v)
		pro_coins = bool(s.pro_coins)
		_save()
	return out

func _save() -> void:
	if Game.test_mode:
		return
	var cf := ConfigFile.new()
	cf.set_value("s", "pro", pro)
	cf.set_value("s", "pro_coins", pro_coins)
	cf.set_value("s", "econ_v", econ_v)
	cf.set_value("s", "sources", bank.sources)
	cf.set_value("s", "all_teams", all_teams)
	cf.set_value("s", "packs", packs)
	cf.set_value("s", "vault", bank.balance)
	cf.set_value("s", "open_txns", bank.open)
	cf.set_value("s", "blue", ledger.balance)
	cf.set_value("s", "blue_tokens", ledger.credited)
	cf.set_value("s", "exchanges", ledger.exchanges)
	cf.set_value("s", "exchanged", ledger.exchanged)
	cf.set_value("s", "looks", looks.to_dict())
	cf.set_value("s", "starter_bought", starter_bought)
	cf.set_value("s", "starter_offered", starter_offered)
	cf.set_value("s", "playoff_offered", playoff_offered)
	cf.set_value("s", "gold_cap", gold_cap)
	cf.set_value("s", "caps_owned", caps_owned)
	cf.set_value("s", "cap_selected", cap_selected)
	cf.set_value("s", "receipts", receipts)
	cf.set_value("s", "tokens", bank.credited)
	cf.set_value("s", "pending", _pending)
	cf.set_value("s", "hold_owned", hold_owned)
	cf.save(SAVE_PATH)

## RESET GAME (Settings): PRO, ALL 30 TEAMS and the starter / playoff offers are gone from the
## game; one-time unlocks stay away until RESTORE PURCHASES (or buying again) asks for them
## (hold_owned). SHARED COINS STAY: no store can restore consumable coins, so they, their records
## of credited transactions and the receipts are kept (anything a deleted career had taken without
## saving refunded first), and so are the visual upgrades, the old exchange's history, and that
## PRO's coins have been paid.
func reset_all() -> void:
	bank.reconcile("*")
	var kept := bank
	var kept_ledger := ledger
	var kept_looks := looks
	var kept_receipts := receipts
	var kept_coins := pro_coins
	var kept_v := econ_v
	reset_for_tests()
	bank = kept
	ledger = kept_ledger
	looks = kept_looks
	receipts = kept_receipts
	pro_coins = kept_coins
	econ_v = kept_v
	hold_owned = true
	_save()
	state_changed.emit()

## Test harness: forget everything (never called by the game).
func reset_for_tests() -> void:
	pro = false
	all_teams = false
	packs = []
	pro_coins = false
	econ_v = EconomyMigration.VERSION
	bank = CoinVault.new()
	ledger = CoinVault.new()
	looks = VisualUpgrades.new()
	starter_bought = false
	starter_offered = false
	playoff_offered = ""
	gold_cap = false
	caps_owned = []
	cap_selected = "classic"
	receipts = []
	_pending = []
	_inflight = ""
	hold_owned = false
