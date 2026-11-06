extends "res://src/ui/screens/visual_lab.gd"
## One visual upgrade's page (a card in visual_shop.gd's gallery): the big preview window, what the
## selected level is, and its levels along the bottom. The window is VISUAL UPGRADE TESTING's own
## stage, so a preview is the real effect at that level, owned or not: nothing spent, no real
## match, nothing saved. Buying and wearing go through Store as ever: one level at a time, a
## confirmation first, any owned level worn for free. Instant Replay has no levels: one purchase
## card, then ENABLE / DISABLE and its presentation. Back is the gallery.

const AUTO := ["goal", "crowd", "broadcast"]   # short enough to play when a level's picked
const INFO_W := 172
const TIER_H := 50

static var open_cat := "goal"     # (back from the store: the same page)

var sel := 1                      # the level selected
var played := false               # it's been shown: PREVIEW says REPLAY PREVIEW
var info: VBoxContainer
var tier_row: HBoxContainer

func lab_title() -> String:
	return String(VisualUpgrades.cat(open_cat).name)

func setup(params: Dictionary) -> void:
	open_cat = String(params.get("cat", open_cat))

func _ready() -> void:
	super()
	for r: Control in rows_ui:
		r.visible = false
	for i in VisualUpgrades.CATS.size():
		if String(VisualUpgrades.CATS[i].id) == open_cat:
			cat_i = i
	game_i = 3   # the biggest game there is: every level at its best
	header_right.add_child(credits_chip())
	# the window and the panel, the levels below
	var top := UI.hbox(4)
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(top)
	var window := UI.panel(UI.INK, UI.GOLD)
	window.name = "PreviewWindow"
	window.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.add_child(window)
	stage_cv.get_parent().remove_child(stage_cv)
	window.add_child(stage_cv)
	var side := UI.panel(Deck.NAVY, UI.BORDER)
	side.custom_minimum_size = Vector2(INFO_W, 0)
	top.add_child(side)
	info = UI.vbox(2)
	info.name = "LevelInfo"
	side.add_child(info)
	tier_row = UI.hbox(3)
	tier_row.name = "Tiers"
	body.add_child(tier_row)
	Store.state_changed.connect(_refresh)
	sel = Store.looks.worn(cat_id())
	_refresh()
	_first.call_deferred()

func _first() -> void:
	select(2 if is_replay() else sel)

func is_replay() -> bool:
	return cat_id() == "replay"

## A cost's "the coin": its number and the yellow coin.
static func price_text(n: int) -> String:
	return CreditCoin.tag(n)

func _exit_tree() -> void:
	if Store.state_changed.is_connected(_refresh):
		Store.state_changed.disconnect(_refresh)

func on_back() -> void:
	Sfx.play("back")
	Sfx.crowd(0.0)
	Game.back("visual_shop")

## The stands as a big game has them, so a level shows all it can do.
func lab_style() -> Dictionary:
	return CrowdArt.style(lv, us, them, false, lab_crowd(), calm or HotFire.calm(), 1) if cat_id() == "crowd" else {}

## TAP TO SKIP, on the window.
func _input(event: InputEvent) -> void:
	if (show != null or cine != null) and event is InputEventMouseButton and event.pressed and stage_cv.get_global_rect().has_point(event.position):
		skip_preview()

func skip_preview() -> void:
	test_skip()
	_labels()

func _next_show() -> void:
	super()
	if show != null:
		show.who = "YOUR PLAYER"

## LOCKED, AVAILABLE (the next to buy), UNLOCKED or EQUIPPED.
func tier_state(n: int) -> String:
	var lk := Store.looks
	if lk.worn(cat_id()) == n:
		return "EQUIPPED"
	if n <= lk.level(cat_id()):
		return "UNLOCKED"
	return "AVAILABLE" if n == lk.level(cat_id()) + 1 else "LOCKED"

## Picks a level: its description, and its preview when that's a short one.
func select(n: int) -> void:
	sel = n
	played = false
	_stop()
	lv = n
	_labels()
	_refresh()
	if cat_id() in AUTO:
		play_level()
	else:
		settled()

func _stop() -> void:
	if show != null:
		show.skip()
	show = null
	cine = null
	bc = null
	queue.clear()
	scoring = false
	goal_run = false

## PREVIEW / REPLAY PREVIEW: the real thing at the selected level, from the top.
func play_level() -> void:
	_stop()
	lv = sel
	if cat_id() == "crowd":
		cheer = 1.6
	preview()
	played = true
	_refresh()

func _refresh() -> void:
	if not is_inside_tree() or info == null:
		return
	for ch in header_right.get_children():
		header_right.remove_child(ch)
		ch.queue_free()
	header_right.add_child(credits_chip())
	_tiers()
	_info()

func _tiers() -> void:
	for ch in tier_row.get_children():
		tier_row.remove_child(ch)
		ch.queue_free()
	tier_row.visible = not is_replay()
	if is_replay():
		return
	for i in VisualUpgrades.top(cat_id()):
		var n: int = i + 1
		var b := Deck.card(Vector2(0, TIER_H), func(ci: Control, r: Rect2, mode: String): _paint_tier(ci, r, mode, n), func(): select(n))
		b.name = "Tier_%d" % n
		b.set_meta("state", tier_state(n))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tier_row.add_child(b)

func _paint_tier(ci: Control, r: Rect2, mode: String, n: int) -> void:
	var st := tier_state(n)
	var picked := n == sel
	var top_tier := n == VisualUpgrades.top(cat_id())
	var down := mode == "down"
	var box := Rect2(r.position + (Vector2(1, 2) if down else Vector2.ZERO), r.size - Vector2(1, 2))
	var fill: Color = Deck.NAVY_HEAD.lightened(0.14) if picked else (Deck.NAVY_HEAD if st != "LOCKED" else Deck.NAVY)
	var edge: Color = UI.GOLD if (picked or mode == "hover" or top_tier) else UI.BORDER
	Deck.frame(ci, box, fill, edge, not down)
	if picked:   # the selected one: a second line, and a notch up to its description
		ci.draw_rect(Rect2(box.position + Vector2(2, 2), Vector2(box.size.x - 4, 1)), UI.GOLD)
		ci.draw_rect(Rect2(box.position + Vector2(2, box.size.y - 3), Vector2(box.size.x - 4, 1)), UI.GOLD)
	if top_tier:   # the ultimate tier's corners
		for k in 2:
			ci.draw_rect(Rect2(box.position + Vector2(3 if k == 0 else box.size.x - 8, 4), Vector2(5, 2)), UI.GOLD)
	var x := box.position.x + 6
	var y := box.position.y
	var tier: Array = VisualUpgrades.cat(cat_id()).tiers[n - 1]
	Deck.shadow_text(ci, x, y + 13, "LEVEL %d" % n, 16, UI.GOLD if st != "LOCKED" else UI.DIM, "big")
	var short: String = tier[2] if tier.size() > 2 else tier[0]   # (a name too long for the card)
	Deck.text(ci, x, y + 26, Deck.fit(short, box.size.x - 11), 8, UI.TEXT if st != "LOCKED" else UI.DIM)
	var sy := y + 39
	match st:
		"EQUIPPED":
			_pill(ci, x, sy, "EQUIPPED", UI.GOLD, UI.INK)
		"UNLOCKED":
			_pill(ci, x, sy, "UNLOCKED", UI.ACCENT, UI.INK)
		_:
			var price := str(VisualUpgrades.price_of(cat_id(), n))
			var col := UI.TEXT if st == "AVAILABLE" else UI.DIM
			if st == "LOCKED":   # the padlock
				ci.draw_rect(Rect2(x + 1, sy - 5, 5, 2), col)
				ci.draw_rect(Rect2(x, sy - 3, 7, 6), col)
			var at := x + (10.0 if st == "LOCKED" else 0.0)
			Deck.text(ci, at, sy, price, 8, col)
			var coin := CreditCoin.height(16)
			ci.draw_texture_rect(CreditCoin.texture(16), Rect2(Vector2(at + Deck.text_w(price) + CreditCoin.GAP, roundf(sy - 2 - coin * 0.5)), Vector2(coin, coin)), false)

func _pill(ci: Control, x: float, y: float, t: String, fill: Color, ink: Color) -> void:
	ci.draw_rect(Rect2(x, y - 5, Deck.text_w(t) + 6, 10), fill)
	Deck.text(ci, x + 3, y, t, 8, ink)

func _info() -> void:
	for ch in info.get_children():
		info.remove_child(ch)
		ch.queue_free()
	if is_replay():
		_replay_card()
		return
	var id := cat_id()
	var lk := Store.looks
	var tier: Array = VisualUpgrades.cat(id).tiers[sel - 1]
	var st := tier_state(sel)
	info.add_child(para(String(UpgradeArt.TAGS[id]), UI.ACCENT, INFO_W - 12))
	var worn := UI.label("WEARING LEVEL %d" % lk.worn(id), 8, UI.DIM, "caps")
	worn.name = "Wearing"
	info.add_child(worn)
	var head := UI.label("LEVEL %d: %s" % [sel, tier[0]], 8, UI.GOLD, "caps")
	head.name = "LevelHead"
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size = Vector2(INFO_W - 12, 0)
	info.add_child(head)
	var d := para(String(tier[1]), UI.TEXT, INFO_W - 12)
	d.name = "LevelDesc"
	info.add_child(d)
	var gap := UI.spacer(0, 0)
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(gap)
	if st == "LOCKED":
		info.add_child(UI.label("PREVIEW AVAILABLE", 8, UI.ACCENT, "caps"))
	var pv := UI.button("REPLAY PREVIEW" if played else "PREVIEW LEVEL %d" % sel, play_level, "ghost", 0, 18)
	pv.name = "DetailPreview"
	info.add_child(pv)
	info.add_child(_action(st))

## INSTANT REPLAY's one purchase card. Owned: UNLOCKED, ENABLE / DISABLE, and its presentation.
func _replay_card() -> void:
	var owned := Store.looks.level("replay") >= 2
	var head := UI.label("INSTANT REPLAY", 16, UI.GOLD, "big")
	head.name = "LevelHead"
	info.add_child(head)
	var d := para(String(VisualUpgrades.cat("replay").tiers[1][1]), UI.TEXT, INFO_W - 12)
	d.name = "LevelDesc"
	info.add_child(d)
	var gap := UI.spacer(0, 0)
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(gap)
	var pv := UI.button("PREVIEW REPLAY", play_level, "ghost", 0, 18)
	pv.name = "DetailPreview"
	info.add_child(pv)
	if not owned:
		var price := CreditCoin.rich("%s  ONE-TIME UNLOCK" % CreditCoin.tag(VisualUpgrades.REPLAY_PRICE), 8, UI.GOLD, "caps")
		price.name = "ReplayPrice"
		info.add_child(price)
		var b := UI.button("UNLOCK INSTANT REPLAY", func(): _act("AVAILABLE"), "primary", 0, 20)
		b.name = "DetailAction"
		info.add_child(b)
		return
	var st := UI.label("UNLOCKED", 8, UI.GOOD, "caps")
	st.name = "ReplayOwned"
	info.add_child(st)
	var on := replay_on()
	var t := UI.button("DISABLE REPLAYS" if on else "ENABLE REPLAYS", func(): set_replay(not on), "primary", 0, 20)
	t.name = "DetailAction"
	info.add_child(t)
	var cine := String(Game.settings.get("replay_style", "cinematic")) != "basic"
	var pres := UI.button("STYLE: %s" % ("CINEMATIC" if cine else "BASIC"), func():
		Game.settings.replay_style = "basic" if cine else "cinematic"
		Game.save_settings()
		_refresh(), "ghost", 0, 16)
	pres.name = "ReplayStyle"
	info.add_child(pres)

## Automatic replays are on: worn, and not switched off in Settings (the same switch).
static func replay_on() -> bool:
	return Store.looks.worn("replay") >= 2 and bool(Game.settings.get("auto_replay", true))

static func set_replay(on: bool) -> void:
	if on:
		Store.equip_level("replay", 2)
	Game.settings.auto_replay = on
	Game.save_settings()
	Store.state_changed.emit()

## The one thing this level can do now.
func _action(st: String) -> Button:
	var id := cat_id()
	var lk := Store.looks
	var b := UI.button("", func(): _act(st), "primary", 0, 20)
	b.name = "DetailAction"
	match st:
		"EQUIPPED":
			b.text = "EQUIPPED"
			b.disabled = true
		"UNLOCKED":
			b.text = "EQUIP LEVEL %d" % sel
		"LOCKED":
			b.text = "UNLOCK LEVEL %d FIRST" % (lk.level(id) + 1)
			b.disabled = true
		_:
			if lk.tier_block(id, c) == "COMING IN A LATER UPDATE":
				b.text = "COMING IN A LATER UPDATE"
				b.disabled = true
			else:
				CreditCoin.set_button(b, "UNLOCK  " + CreditCoin.tag(lk.next_price(id)))
	return b

func _act(st: String) -> void:
	var id := cat_id()
	if st == "UNLOCKED":
		Store.equip_level(id, sel)
		Sfx.play("confirm")
		return
	var n := Store.looks.level(id) + 1
	var price := Store.looks.next_price(id)
	var why := Store.looks.tier_block(id, c)
	if why == "NOT ENOUGH YELLOW COINS":
		StorePrompt.need(c, price, String(VisualUpgrades.cat(id).name), Callable())
		return
	if why != "":
		Game.toast(why, UI.WARN)
		return
	var what := "UNLOCK INSTANT REPLAY?" if is_replay() else "UNLOCK %s LEVEL %d?" % [VisualUpgrades.cat(id).name, n]
	Game.dialog(what, "COST: %s\nYOU HAVE: %s" % [CreditCoin.tag(price), CreditCoin.tag(c.wallet())], [
		["CANCEL", Callable(), "ghost"],
		["CONFIRM", func(): do_buy(id), "primary"]])

## The confirmed purchase: says it's done only once it is.
func do_buy(id: String) -> void:
	var why := Store.buy_tier(id)
	if why == "":
		Sfx.play("coins")
		Game.toast("INSTANT REPLAY UNLOCKED" if id == "replay" else "LEVEL %d UNLOCKED" % Store.looks.level(id), UI.GOLD)
	else:
		Game.toast(why, UI.WARN)
