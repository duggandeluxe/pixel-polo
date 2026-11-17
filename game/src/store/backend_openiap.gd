extends RefCounted
## App Store (StoreKit 2) and Google Play through the maintained OpenIAP plugin "godot-iap"
## (https://github.com/hyochan/godot-iap, now developed in https://github.com/hyodotdev/openiap
## under libraries/godot-iap; Godot 4.3+, iOS 15+). The plugin registers the autoload
## `GodotIapPlugin`; Store picks this backend only when that node exists on iOS or Android, and
## this file reaches the plugin by name so the game still parses without it.
##
## Every plugin call here is from the plugin's published API reference (llms-full.txt, checked
## 2026-11-16): init_connection(), fetch_products(Types.ProductRequest), request_purchase(
## Types.RequestPurchaseProps), finish_transaction_dict(purchase, is_consumable),
## restore_purchases(), get_available_purchases(), signals purchase_updated(Dictionary) and
## purchase_error(Dictionary). NOT YET RUN ON A DEVICE: verify in the App Store sandbox / TestFlight.
##
## Order of a purchase: purchase_updated "Purchased" -> Store grants it and writes store.cfg
## (crash-safe) -> only then finish_transaction. A crash in between leaves the transaction
## unfinished, StoreKit delivers it again on the next launch, and Store's credited-transaction list
## (CoinVault.seen) makes sure it pays once.

## Revoking a refunded one-time unlock at startup when the store no longer lists it among the
## player's purchases. OFF until it is confirmed in the sandbox that get_available_purchases() lists
## every owned non-consumable (StoreKit current entitlements) and not only unfinished transactions:
## if it lists only unfinished ones, turning this on would take PIXEL POLO + away from real owners.
## See app_store_release/IN_APP_PURCHASES.md, "Refunds".
const REVOKE_MISSING_ON_SYNC := false

const TYPES_PATH := "res://addons/godot-iap/types.gd"
const QUERY_IN_APP := 0      # Types.ProductQueryType.IN_APP
const QUERY_ALL := 2         # Types.ProductQueryType.ALL

var store: Node
var iap: Node
var Types = null
var _ids: Array = []
var _connected := false
var _finishing := {}         # transaction id -> true: finish already asked

## p_iap / p_types: the plugin's autoload and its types script (tests pass stand-ins).
func _init(p_store: Node, p_iap: Node = null, p_types = null) -> void:
	store = p_store
	iap = p_iap if p_iap != null else p_store.get_tree().root.get_node_or_null("GodotIapPlugin")
	Types = p_types
	if Types == null and ResourceLoader.exists(TYPES_PATH):
		Types = load(TYPES_PATH)
	if iap != null:
		iap.connect("purchase_updated", _on_purchase_updated)
		iap.connect("purchase_error", _on_purchase_error)
		if iap.has_signal("products_fetched"):
			iap.connect("products_fetched", _on_products_fetched)

static func plugin_present(tree: SceneTree) -> bool:
	return tree.root.get_node_or_null("GodotIapPlugin") != null and ResourceLoader.exists(TYPES_PATH)

func ready() -> bool:
	return _connected

func start(ids: Array) -> void:
	_ids = ids
	if iap == null or Types == null:
		return
	_connected = bool(await iap.init_connection())
	if not _connected:
		push_warning("Store: the store connection failed; buttons say the store isn't available.")
		store.state_changed.emit()
		return
	store.state_changed.emit()
	await _fetch_prices()
	await _sync_owned(false)

func _fetch_prices() -> void:
	var req = Types.ProductRequest.new()
	req.skus = _ids.duplicate()
	req.type = QUERY_ALL
	var products = await iap.fetch_products(req)
	if products is Array:
		for p in products:
			_note_product(p)

## iOS can answer the product request later, by signal (payload: products as dictionaries).
func _on_products_fetched(result: Dictionary) -> void:
	for key in ["products", "items", "result"]:
		if result.get(key) is Array:
			for p in result[key]:
				_note_product(p)

func _note_product(p) -> void:
	var id := ""
	var price := ""
	if p is Dictionary:
		id = str(p.get("id", p.get("productId", "")))
		price = str(p.get("displayPrice", p.get("display_price", "")))
	elif p is Object:
		id = str(p.get("id"))
		price = str(p.get("display_price"))
	if id != "" and price != "" and price != "<null>":
		store._on_price(id, price)

func buy(id: String) -> void:
	var props = Types.RequestPurchaseProps.new()
	props.type = QUERY_IN_APP
	props.request = Types.RequestPurchasePropsByPlatforms.new()
	if OS.get_name() == "iOS":
		props.request.apple = Types.RequestPurchaseIOSProps.new()
		props.request.apple.sku = id
	else:
		props.request.google = Types.RequestPurchaseAndroidProps.new()
		props.request.google.skus = [id]
	# the result arrives on purchase_updated / purchase_error
	await iap.request_purchase(props)

## RESTORE PURCHASES (the player asked): the store syncs with Apple (it may ask for the Apple ID),
## then every owned one-time unlock comes back. Consumables are never "restored".
func restore() -> void:
	if not _connected:
		store._on_restore_done("The store isn't available right now.")
		return
	var r = await iap.restore_purchases()
	var ok: bool = r == null or not (r is Object) or bool(r.get("success"))
	if not ok:
		store._on_restore_done("Restore failed. Check your connection and try again.")
		return
	await _sync_owned(true)
	store._on_restore_done("")

## What the store says the player owns: one-time unlocks granted (they're the store's to decide);
## unfinished consumables credited once and finished.
func _sync_owned(_user_asked: bool) -> void:
	var list = await iap.get_available_purchases()
	if not (list is Array):
		return
	var owned := {}
	for p in list:
		var d := _as_dict(p)
		var id := str(d.get("productId", d.get("product_id", "")))
		if id == "":
			continue
		owned[id] = true
		if id in store.NON_CONSUMABLES:
			store._on_owned(id)
		elif store.PRODUCTS.has(id):
			_deliver_consumable(id, d)
	if REVOKE_MISSING_ON_SYNC:
		for nid in store.NON_CONSUMABLES:
			if store.owns(nid) and not owned.has(nid):
				store._on_revoked(nid)

func _as_dict(p) -> Dictionary:
	if p is Dictionary:
		return p
	if p is Object:
		if p.has_method("to_dict"):
			return p.to_dict()
		var d := {}
		for k in ["id", "product_id", "transaction_id", "purchase_state"]:
			d[k] = p.get(k)
		d["productId"] = d.product_id
		d["transactionId"] = d.transaction_id
		d["purchaseState"] = d.purchase_state
		return d
	return {}

func _txn_of(d: Dictionary) -> String:
	var t = d.get("transactionId", d.get("transaction_id", d.get("id", "")))
	return "" if t == null else str(t)

# ------------------------------------------------------------------ plugin signals
func _on_purchase_updated(d: Dictionary) -> void:
	var id := str(d.get("productId", store._inflight))
	var state := str(d.get("purchaseState", "")).to_lower()
	match state:
		"purchased", "restored":
			if id in store.NON_CONSUMABLES:
				if id == store._inflight:
					store._on_purchased(id, _txn_of(d))   # (bought now: PIXEL POLO +'s coins, once)
				else:
					store._on_owned(id)                   # (re-delivered / other device)
					store._finish_inflight(id, true, "")
				_finish(d, false)
			elif store.PRODUCTS.has(id):
				_deliver_consumable(id, d)
		"pending", "deferred":
			store._on_pending(id)   # (Ask to Buy, a payment needing action: arrives later)
		"failed":
			store._on_failed(id, "Purchase failed.", false)
		_:
			pass   # (an unknown state grants nothing)

## A consumable pack: credited once by its transaction id (Store/CoinVault), saved, then finished.
func _deliver_consumable(id: String, d: Dictionary) -> void:
	var txn := _txn_of(d)
	if txn == "":
		push_warning("Store: a %s transaction without an id was not credited." % id)
		return
	store._on_purchased(id, txn)   # (already credited: nothing paid again)
	if store.seen(txn):            # (only finish what is safely on disk)
		_finish(d, true)

func _finish(d: Dictionary, consumable: bool) -> void:
	var txn := _txn_of(d)
	if txn != "" and _finishing.has(txn):
		return
	if txn != "":
		_finishing[txn] = true
	var r = await iap.finish_transaction_dict(d, consumable)
	if r is Object and not bool(r.get("success")):
		_finishing.erase(txn)   # (StoreKit hands it over again later; it can't pay twice)

func _on_purchase_error(e: Dictionary) -> void:
	var id: String = store._inflight
	if id == "":
		return
	var code := str(e.get("code", "")).to_upper()
	if code.contains("CANCEL"):
		store._on_failed(id, "", true)   # (the player said no: no message)
	elif code.contains("PENDING") or code.contains("DEFERRED"):
		store._on_pending(id)
	else:
		var msg := str(e.get("message", ""))
		store._on_failed(id, msg if msg != "" else "Purchase failed.", false)
