extends RefCounted
## Desktop test store: purchases succeed after a short delay and cost nothing. The store screen
## labels it TEST STORE. Store.gd never picks this backend on a phone.

var store: Node

func _init(p_store: Node) -> void:
	store = p_store

func ready() -> bool:
	return true

func start(_ids: Array) -> void:
	pass

func buy(id: String) -> void:
	await store.get_tree().create_timer(0.35).timeout
	store._on_purchased(id, "test-%s-%d" % [id, Time.get_ticks_usec()])

func restore() -> void:
	await store.get_tree().create_timer(0.2).timeout
	store._on_restore_done("")
