extends BaseScreen
## Select career: the five save slots, stacked. An empty slot starts a new career in it, an
## occupied one loads that career; DELETE (after a confirm) empties a slot. Nothing here ever
## writes over a career.

const CARD_H := 38
const DEL_W := 52

func _ready() -> void:
	build("SELECT CAREER")
	_render()
	Sfx.music("menu")

func on_back() -> void:
	Sfx.play("back")
	Game.goto("title", {}, false)

func _render() -> void:
	for ch in body.get_children():
		ch.queue_free()
	var list := UI.vbox(4)
	list.custom_minimum_size.x = 340
	for n in range(1, Game.SLOTS + 1):
		if Game.slot_hidden(n):
			continue   # (a hibernated Division II/III career: kept on disk, its slot kept, not shown)
		var row := UI.hbox(4)
		var sm := Game.slot_summary(n)
		var card := Deck.card(Vector2(0, CARD_H), _paint.bind(n, sm), _pick.bind(n, sm))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.name = "Slot%d" % n
		row.add_child(card)
		if not sm.is_empty():
			var del := Deck.button("DELETE", _ask_delete.bind(n, sm), "ghost", DEL_W, CARD_H)
			del.name = "Delete%d" % n
			row.add_child(del)
		else:
			row.add_child(UI.spacer(DEL_W, 0))   # every card the same width
		list.add_child(row)
		Juice.enter(row, n - 1)
	body.add_child(UI.spacer(0, 0, true))
	body.add_child(centered(list))
	body.add_child(UI.spacer(0, 0, true))

## A navy card with a thin border, gold when it's under the finger.
func _paint(ci: CanvasItem, r: Rect2, mode: String, n: int, sm: Dictionary) -> void:
	var hot := mode != "normal"
	var fill := Deck.ROW_HOVER if hot else Deck.NAVY
	if mode == "down":
		r.position += Vector2(0, 1)
	Deck.frame(ci, r, fill, UI.GOLD if hot else Color(1, 1, 1, 0.55))
	var x := r.position.x + 9
	var mid := r.position.y + r.size.y * 0.5
	if sm.is_empty():
		Deck.text(ci, x, mid, "SLOT %d - EMPTY" % n, 8, UI.DIM)
		Deck.rtext(ci, r.end.x - 9, mid, "NEW CAREER", 8, UI.GOLD if hot else UI.DIM2)
		return
	Deck.text(ci, x, mid - 10, "SLOT %d" % n, 8, UI.GOLD)
	var w := r.size.x - 18
	if sm.get("damaged", false):
		Deck.text(ci, x, mid + 1, "SAVE PROBLEM", 8, UI.BAD)
		Deck.text(ci, x, mid + 11, "THIS SAVE CAN'T BE READ", 8, UI.DIM)
		return
	Deck.text(ci, x, mid + 1, Deck.fit(String(sm.team).to_upper(), w), 8, UI.TEXT)
	Deck.text(ci, x, mid + 11, "SEASON %d | %s" % [int(sm.season), String(sm.record)], 8, UI.DIM)

func _pick(n: int, sm: Dictionary) -> void:
	if sm.is_empty():
		# a new career goes into this slot; the career in memory (another slot's) is saved already
		Game.career = null
		Game.slot = n
		Game.goto("new_career")
		return
	if sm.get("damaged", false):
		Game.toast("This save can't be read", UI.WARN)
		return
	if not Game.load_career(n):
		Game.toast("This save can't be read", UI.WARN)
		return
	Game.history.clear()
	Game.goto("game_summary" if not Game.career.last_summary.is_empty() else "hub")

func _ask_delete(n: int, sm: Dictionary) -> void:
	var who := "the career in slot %d" % n if sm.get("damaged", false) else "%s (season %d, %s)" % [sm.team, int(sm.season), sm.record]
	Game.dialog("DELETE CAREER?", "This deletes %s for good, with the coins it earned. Your purchased Yellow Coins are kept." % who, [
		["DELETE", func():
			Game.delete_slot(n)
			Sfx.play("back")
			_render(), "danger"],
		["CANCEL", Callable(), "ghost"]])
