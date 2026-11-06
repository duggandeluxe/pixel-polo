extends BaseScreen
## THE YELLOW COIN SHOP: Yellow Coins for real money (the four packs), PIXEL POLO +, and the
## Division II and III expansion packs, which are listings only until they exist (Store.DIVISIONS:
## their planned price, no button), and not listed at all while the lower divisions are hibernated
## (Colleges.ENABLE_LOWER_DIVISIONS). What coins buy is everywhere else. Nothing here flashes, counts down or
## pretends to be a discount.

func _ready() -> void:
	c = Game.career
	build("YELLOW COIN SHOP", true, c != null)
	Store.state_changed.connect(_refresh)
	Store.products_updated.connect(_refresh)
	_render()

func _exit_tree() -> void:
	if Store.state_changed.is_connected(_refresh):
		Store.state_changed.disconnect(_refresh)
	if Store.products_updated.is_connected(_refresh):
		Store.products_updated.disconnect(_refresh)

func on_back() -> void:
	Sfx.play("back")
	Game.back("hub" if Game.career != null else "title")

func _refresh() -> void:
	if is_inside_tree():
		_render()

func _render() -> void:
	for ch in body.get_children():
		ch.queue_free()
	for ch in header_right.get_children():
		header_right.remove_child(ch)   # (out of the tree now, so the new chips keep their names)
		ch.queue_free()
	header_right.add_child(credits_chip())
	var v := UI.vbox(3)
	body.add_child(UI.scroll(v))
	_coin_shop(v)

# ------------------------------------------------------------------ the shop
func _coin_shop(v: VBoxContainer) -> void:
	var g := GridContainer.new()
	g.name = "CoinPacks"
	g.columns = 2
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	v.add_child(g)
	for i in range(Store.PACK_IDS.size()):
		g.add_child(_pack_card(Store.PACK_IDS[i], i))
	v.add_child(_pro_card())
	var listed := Store.listed_divisions()   # (none while the lower divisions are hibernated: no row at all)
	if not listed.is_empty():
		var d := GridContainer.new()
		d.name = "Divisions"
		d.columns = 2
		d.add_theme_constant_override("h_separation", 4)
		d.add_theme_constant_override("v_separation", 4)
		v.add_child(d)
		for id in listed:
			d.add_child(_division_card(id))
	var f := UI.hbox(4)
	v.add_child(f)
	f.add_child(UI.button("RESTORE PURCHASES", _restore, "ghost", 0, 14))
	var note := ""
	if Store.is_test_store():
		note = "TEST STORE (desktop): nothing is charged. Real prices apply on iPhone and Android."
	elif not Store.available():
		note = "The store isn't available right now. Check your connection and try again."
	var nl := UI.label(note, 8, UI.WARN if Store.is_test_store() else UI.DIM)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.custom_minimum_size = Vector2(200, 0)
	f.add_child(nl)
	var wl := UI.label(WALLET_NOTE, 8, UI.DIM)
	wl.name = "WalletNote"
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wl.custom_minimum_size = Vector2(300, 0)
	v.add_child(wl)

const WALLET_NOTE := "Purchased Yellow Coins stay with you in every dynasty. Your dynasty's own coins are always spent first."

# ------------------------------------------------------------------ cards
func _pack_card(id: String, tier: int) -> Control:
	var p := Store.product(id)
	var badge := ""
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 58)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var edge := UI.GOLD if badge != "" else UI.BORDER
	b.add_theme_stylebox_override("normal", UI.chunky(UI.PANEL2 if badge != "" else UI.PANEL, edge, true, false, 0, 0))
	b.add_theme_stylebox_override("hover", UI.chunky(UI.BG_HI, UI.GOLD, true, false, 0, 0))
	b.add_theme_stylebox_override("pressed", UI.chunky(UI.PANEL2, UI.GOLD, false, true, 0, 0))
	b.add_theme_stylebox_override("hover_pressed", UI.chunky(UI.PANEL2, UI.GOLD, false, true, 0, 0))
	var art := UI.canvas(0, 0, func(ci: Control):
		var w := ci.size.x
		_draw_coins(ci, Vector2(6, 58), tier)
		UI.text_shadow(ci, Vector2(48, 25), _fmt(int(p.credits)), 20, UI.GOLD, "big")
		var bh := CreditCoin.height(20)
		ci.draw_texture_rect(CreditCoin.texture(20), Rect2(Vector2(48 + UI.text_width(_fmt(int(p.credits)), 20, "big") + CreditCoin.GAP, 9), Vector2(bh, bh)), false)
		UI.text(ci, Vector2(48, 35), p.title, 8, UI.TEXT)
		UI.text(ci, Vector2(48, 46), "YELLOW COINS", 8, UI.GOLD, "body", HORIZONTAL_ALIGNMENT_LEFT, w - 52)
		# price pill
		var pr := Store.price(id)
		var pw := UI.text_width(pr, 8) + 10
		Deck.frame(ci, Rect2(w - pw - 4, 4, pw, 12), UI.GOLD, UI.BORDER)
		UI.text(ci, Vector2(w - pw - 4, 13), pr, 8, UI.INK, "body", HORIZONTAL_ALIGNMENT_CENTER, pw)
		if badge != "":
			var bw := UI.text_width(badge, 8) + 8
			ci.draw_rect(Rect2(0, 0, bw, 10), UI.GOLD)
			UI.text(ci, Vector2(0, 8), badge, 8, UI.INK, "body", HORIZONTAL_ALIGNMENT_CENTER, bw))
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(art)
	b.pressed.connect(func():
		Sfx.play("click")
		StorePrompt.buy_then(id))
	b.set_meta("coins", int(p.credits))
	b.disabled = not Store.available()   # (no store, no working button)
	return b

func _pro_card() -> Control:
	var p := UI.panel(UI.PANEL2, UI.GOLD if not Store.pro else UI.GOOD)
	p.name = "ProCard"
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UI.hbox(6)
	p.add_child(h)
	var v := UI.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UI.label("PIXEL POLO +" + ("  -  ACTIVE" if Store.pro else ""), 16, UI.GOLD if not Store.pro else UI.GOOD, "big"))
	for perk in Store.pro_perks():
		v.add_child(UI.label("+ " + perk, 8, UI.TEXT if not Store.pro else UI.DIM))
	if not Store.pro:
		var right := UI.vbox(2)
		h.add_child(right)
		var once := UI.label("ONE-TIME", 8, UI.GOLD)
		once.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right.add_child(once)
		right.add_child(UI.button(Store.price(Store.PRO_ID), func(): StorePrompt.buy_then(Store.PRO_ID), "primary", 64, 22))
	return p

## A division pack's listing: its art and what it is. OWNED once this account has it; a BUY button
## only when the platform has confirmed the product and its price (Store.division_for_sale); until
## then COMING SOON: a panel with no price and nothing to press.
func _division_card(id: String) -> Control:
	var d: Dictionary = Store.DIVISIONS[id]
	var p := UI.panel(UI.PANEL, UI.BORDER)
	p.name = "Division_" + id
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UI.vbox(1)
	p.add_child(box)
	var art := UI.canvas(0, 40, func(ci: Control): _paint_division(ci, id))
	art.name = "DivisionArt"
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(art)
	box.add_child(UI.label(String(d.title), 8, UI.GOLD, "caps"))
	box.add_child(para(String(d.desc), UI.DIM, 208))
	if not Store.division_access(id) and Store.division_for_sale(id):
		var buy := UI.button(Store.price(String(d.product)), func(): StorePrompt.buy_then(String(d.product)), "primary", 64, 18)
		buy.name = "Buy_" + id
		box.add_child(buy)
	return p

## A little pool under the division's banner, the COMING SOON tag across its corner.
func _paint_division(ci: Control, id: String) -> void:
	var r := Rect2(Vector2.ZERO, ci.size)
	var two := id == "div2"
	var sky := Color("0b1d5c") if two else Color("2a0d4a")
	var lane := Color("5fe0ff") if two else Color("ffcf3f")
	ci.draw_rect(r, sky)
	ci.draw_rect(Rect2(0, r.size.y - 14, r.size.x, 14), Color("1b6fd0"))
	var x := 0.0
	while x < r.size.x:   # the lane lines
		ci.draw_rect(Rect2(x, r.size.y - 8, 6, 1), lane)
		ci.draw_rect(Rect2(x + 8, r.size.y - 4, 4, 1), Color("6fc8ff"))
		x += 14.0
	var n := 2 if two else 3   # the cap numbers: II, III
	for i in n:
		var px := 12.0 + i * 16.0
		ci.draw_rect(Rect2(px, r.size.y - 22, 10, 9), Color("f2c9a0"))
		ci.draw_rect(Rect2(px - 1, r.size.y - 26, 12, 6), lane)
		ci.draw_rect(Rect2(px + 3, r.size.y - 25, 4, 1), Color("f2f2e9"))
	UI.text_shadow(ci, Vector2(r.size.x - 8 - UI.text_width(String(Store.DIVISIONS[id].tag), 16, "big"), 16), String(Store.DIVISIONS[id].tag), 16, Color("f2f2e9"), "big")
	var tag := "COMING SOON"
	if Store.division_access(id):
		tag = "OWNED"
	elif Store.division_for_sale(id):
		tag = "AVAILABLE"
	var tw := UI.text_width(tag, 8) + 8
	ci.draw_rect(Rect2(r.size.x - tw - 2, 21, tw, 11), UI.GOLD)
	UI.text(ci, Vector2(r.size.x - tw - 2, 30), tag, 8, UI.INK, "body", HORIZONTAL_ALIGNMENT_CENTER, tw)

func _restore() -> void:
	Game.toast("Restoring purchases...", UI.ACCENT)
	var w := StorePrompt.Waiter.new()
	w.id = "restore"   # (every one-time unlock: PRO, ALL 30 TEAMS)
	StorePrompt._waiters.append(w)
	Store.purchase_finished.connect(w.done)
	Store.restore()

# ------------------------------------------------------------------ art
## Coin stacks that grow with the pack; the biggest pack is a treasure chest.
func _draw_coins(ci: Control, base: Vector2, tier: int) -> void:
	if tier >= 5:
		var x := base.x
		var y := base.y - 22
		ci.draw_rect(Rect2(x, y + 8, 36, 14), Color("7a4a1c"))
		ci.draw_rect(Rect2(x, y + 8, 36, 2), Color("a86a2c"))
		ci.draw_rect(Rect2(x + 16, y + 12, 4, 5), UI.GOLD)
		for i in range(7):
			_coin(ci, Vector2(x + 2 + i * 4.5, y + 5 - (i % 2) * 2))
		ci.draw_rect(Rect2(x - 1, y + 2, 38, 4), Color("5a3412"))
		return
	var stacks := mini(tier + 1, 4)
	for s in range(stacks):
		var n := 2 + tier + (s % 2)
		for k in range(n):
			_coin(ci, Vector2(base.x + s * 9, base.y - 3 - k * 3))

func _coin(ci: Control, p: Vector2) -> void:
	ci.draw_rect(Rect2(p.x + 1, p.y, 6, 1), Color("ffe98a"))
	ci.draw_rect(Rect2(p.x, p.y + 1, 8, 2), UI.GOLD)
	ci.draw_rect(Rect2(p.x + 1, p.y + 3, 6, 1), Color("a8721c"))

static func _fmt(n: int) -> String:
	var s := str(n)
	if n >= 1000:
		s = "%d,%03d" % [n / 1000, n % 1000]
	return s
