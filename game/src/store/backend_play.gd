extends RefCounted
## Google Play Billing through the GodotGooglePlayBilling plugin (Billing Library 9, plugin
## repo godot-sdk-integrations/godot-google-play-billing). Talks to the JNI singleton directly so
## the game still compiles when the addon isn't installed.
##
## Flow: startConnection -> connected -> queryProductDetails (prices) + queryPurchases (owned /
## unconsumed) -> purchase -> on_purchase_updated -> grant -> consume (credits) or acknowledge (PRO).
## Purchase tokens are remembered by Store, so a crash between "grant" and "consume" can't pay twice.

const R_OK := 0
const R_USER_CANCELED := 1
const R_ITEM_ALREADY_OWNED := 7
const ST_PURCHASED := 1
const ST_PENDING := 2

var store: Node
var bp: Object
var _ids: Array = []
var _connected := false
var _details_ok := false
var _retry := 0

func _init(p_store: Node) -> void:
	store = p_store
	bp = Engine.get_singleton("GodotGooglePlayBilling")
	bp.initPlugin()
	bp.connect("connected", _on_connected)
	bp.connect("disconnected", _on_disconnected)
	bp.connect("connect_error", _on_connect_error)
	bp.connect("query_product_details_response", _on_details)
	bp.connect("query_purchases_response", _on_purchases)
	bp.connect("on_purchase_updated", _on_purchase_updated)
	bp.connect("consume_purchase_response", func(_r): pass)
	bp.connect("acknowledge_purchase_response", func(_r): pass)

func ready() -> bool:
	return _connected and _details_ok

func start(ids: Array) -> void:
	_ids = ids
	bp.startConnection()

func buy(id: String) -> void:
	var r: Dictionary = bp.purchase(id, "", "", false)
	if int(r.get("response_code", -1)) != R_OK:
		store._on_failed(id, "Couldn't open Google Play (%s)." % r.get("debug_message", "error"), false)

func restore() -> void:
	bp.queryPurchases("inapp", false)
	store.get_tree().create_timer(1.5).timeout.connect(func(): store._on_restore_done(""))

# ------------------------------------------------------------------ callbacks
func _on_connected() -> void:
	_connected = true
	_retry = 0
	bp.queryProductDetails(PackedStringArray(_ids), "inapp")
	bp.queryPurchases("inapp", false)

func _on_disconnected() -> void:
	_connected = false
	_reconnect()

func _on_connect_error(_code: int, _msg: String) -> void:
	_connected = false
	_reconnect()

func _reconnect() -> void:
	if _retry >= 5:
		return
	_retry += 1
	store.get_tree().create_timer(2.0 * _retry).timeout.connect(func(): bp.startConnection())

func _on_details(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != R_OK:
		return
	_details_ok = true
	for d in r.get("product_details", []):
		var offers = d.get("one_time_purchase_offer_details_list", null)
		if offers is Array and offers.size() > 0:
			store._on_price(str(d.get("product_id", "")), str(offers[0].get("formatted_price", "")))
	store.products_updated.emit()

func _on_purchases(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != R_OK:
		return
	for p in r.get("purchases", []):
		_handle_purchase(p)

func _on_purchase_updated(r: Dictionary) -> void:
	var code := int(r.get("response_code", -1))
	if code == R_OK:
		for p in r.get("purchases", []):
			_handle_purchase(p)
	elif code == R_USER_CANCELED:
		store._on_failed(store._inflight, "", true)
	elif code == R_ITEM_ALREADY_OWNED:
		bp.queryPurchases("inapp", false)
		store._on_failed(store._inflight, "You already own this. Restoring it.", false)
	else:
		store._on_failed(store._inflight, "Purchase failed (%s)." % r.get("debug_message", code), false)

func _handle_purchase(p: Dictionary) -> void:
	var ids: Array = Array(p.get("product_ids", []))
	if ids.is_empty():
		return
	var id: String = ids[0]
	var token: String = p.get("purchase_token", "")
	match int(p.get("purchase_state", 0)):
		ST_PURCHASED:
			if id in store.NON_CONSUMABLES:
				store._on_owned(id)
				store._finish_inflight(id, true, "")
				if not p.get("is_acknowledged", false):
					bp.acknowledgePurchase(token)
			else:
				store._on_purchased(id, token)
				bp.consumePurchase(token)
		ST_PENDING:
			store._on_pending(id)
