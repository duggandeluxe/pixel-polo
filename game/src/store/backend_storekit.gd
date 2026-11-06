extends RefCounted
## App Store through StoreKit 2 (plugin godot-sdk-integrations/godot-storekit2, class
## GodotStoreKit2). The plugin finishes verified transactions itself.
##
## Signals from the plugin: product_info_received(info), transaction_state_changed(transaction),
## synchronized(error). A purchase's result and background transactions (Ask to Buy approvals,
## refunds, purchases on other devices) all arrive on transaction_state_changed; Store only
## credits consumables it is waiting for, so a re-announced transaction can't pay twice.

enum { TS_FAILED, TS_REFUNDED, TS_PENDING, TS_DEFERRED, TS_PURCHASED, TS_RESTORED, TS_EXPIRED, TS_CANCELED }

var store: Node
var sk: Object

func _init(p_store: Node) -> void:
	store = p_store
	sk = ClassDB.instantiate("GodotStoreKit2")
	sk.connect("product_info_received", _on_info)
	sk.connect("transaction_state_changed", _on_transaction)
	sk.connect("synchronized", _on_sync)

func ready() -> bool:
	return sk != null

func start(ids: Array) -> void:
	for id in ids:
		sk.request_product_info(id)

func buy(id: String) -> void:
	sk.purchase_product(id, 1)

func restore() -> void:
	sk.sync()

func _on_info(info: Dictionary) -> void:
	if str(info.get("error", "")) != "":
		return
	var id := str(info.get("product_id", ""))
	store._on_price(id, str(info.get("localized_price", "")))
	if id in store.NON_CONSUMABLES and info.get("is_purchased", false):
		store._on_owned(id)

func _on_transaction(t: Dictionary) -> void:
	var err := str(t.get("error", ""))
	var id := str(t.get("product_id", store._inflight))
	if err != "" and not t.has("transaction_state"):
		store._on_failed(store._inflight, err, false)
		return
	match int(t.get("transaction_state", TS_FAILED)):
		TS_PURCHASED, TS_RESTORED:
			if id in store.NON_CONSUMABLES:
				store._on_owned(id)
				store._finish_inflight(id, true, "")
			else:
				# its transaction id, when the plugin gives one: credited once (CoinVault.seen)
				store._on_purchased(id, str(t.get("transaction_id", t.get("id", ""))))
		TS_PENDING, TS_DEFERRED:
			store._on_pending(id)
		TS_CANCELED:
			store._on_failed(id, "", true)
		TS_REFUNDED:
			store._on_revoked(id)
		_:
			store._on_failed(id, err if err != "" else "Purchase failed.", false)

func _on_sync(error: String) -> void:
	# after a sync StoreKit re-reports what's owned through product info
	if error == "":
		for nid in store.NON_CONSUMABLES:
			sk.request_product_info(nid)
	store.get_tree().create_timer(1.0).timeout.connect(func(): store._on_restore_done(error))
