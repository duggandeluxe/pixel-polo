extends "res://src/ui/screens/visual_lab.gd"
## One visual upgrade's page (a card in visual_shop.gd's gallery): the big preview window, what the
## selected level is, and its levels along the bottom. The window is VISUAL UPGRADE TESTING's own
## stage, so a preview is the real effect at that level, owned or not: nothing spent, no real
## match, nothing saved. Buying and wearing go through Store as ever: one level at a time, a
## confirmation first, any owned level worn for free. Back is the gallery.

const AUTO := ["goal", "crowd", "broadcast", "scoreboard"]   # short enough to play when a level's picked
const INFO_W := 172
const TIER_H := 50
const CELEB_H := 54
## A celebration card's frame, Level 0 to 3: plainer to grander (no padlocks: none is locked).
const CELEB_EDGE := [Color("5b6b8c"), Color("4fc3ff"), Color("b78bff"), Color("ffd83d")]

static var open_cat := "goal"     # (back from the store: the same page)

var sel := 1                      # the level selected
var played := false               # it's been shown: PREVIEW says PREVIEW AGAIN
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
	select(sel)

## GOAL CELEBRATIONS: four separate celebrations (level `sel` - 1: 0 CLASSIC .. 3 FIREWORKS).
func is_goal() -> bool:
	return cat_id() == "goal"

## A cost's "the coin": its number and the Polo Points coin.
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
	return CrowdArt.style(lv, us, them, false, lab_crowd(), calm or HotFire.calm(), 1, LAB_SEED) if cat_id() == "crowd" else {}

## TAP TO SKIP, on the window.
func _input(event: InputEvent) -> void:
	if cine != null and event is InputEventMouseButton and event.pressed and stage_cv.get_global_rect().has_point(event.position):
		skip_preview()

func skip_preview() -> void:
	test_skip()
	_labels()

## LOCKED, AVAILABLE (the next to buy), UNLOCKED or EQUIPPED. Goal Celebrations: PURCHASE, OWNED
## or EQUIPPED (any one can be bought, whatever's owned: nothing is ever locked).
func tier_state(n: int) -> String:
	var lk := Store.looks
	if is_goal():
		if lk.worn_celeb() == n - 1:
			return "EQUIPPED"
		return "OWNED" if lk.owns_celeb(n - 1) else "PURCHASE"
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
	cine = null
	bc = null
	queue.clear()
	goal_run = false

## PREVIEW / PREVIEW AGAIN: the real thing at the selected level, from the top.
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
	for i in VisualUpgrades.top(cat_id()):
		var n: int = i + 1
		var b := Deck.card(Vector2(0, CELEB_H if is_goal() else TIER_H), func(ci: Control, r: Rect2, mode: String): _paint_any(ci, r, mode, n), func(): select(n))
		b.name = "Tier_%d" % n
		b.set_meta("state", tier_state(n))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tier_row.add_child(b)

func _paint_any(ci: Control, r: Rect2, mode: String, n: int) -> void:
	if is_goal():
		_paint_celeb(ci, r, mode, n)
	else:
		_paint_tier(ci, r, mode, n)

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
	if is_goal():
		_celeb_card()
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
	var pv := UI.button("PREVIEW AGAIN" if played else "PREVIEW LEVEL %d" % sel, play_level, "ghost", 0, 18)
	pv.name = "DetailPreview"
	info.add_child(pv)
	info.add_child(_action(st))

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
	if is_goal():
		_celeb_act(st)
		return
	var id := cat_id()
	if st == "UNLOCKED":
		Store.equip_level(id, sel)
		Sfx.play("confirm")
		return
	var n := Store.looks.level(id) + 1
	var price := Store.looks.next_price(id)
	var why := Store.looks.tier_block(id, c)
	if why == "NOT ENOUGH POLO POINTS":
		StorePrompt.need(c, price, String(VisualUpgrades.cat(id).name), Callable())
		return
	if why != "":
		Game.toast(why, UI.WARN)
		return
	var what := "UNLOCK %s LEVEL %d?" % [VisualUpgrades.cat(id).name, n]
	Game.dialog(what, "COST: %s\nYOU HAVE: %s" % [CreditCoin.tag(price), CreditCoin.tag(c.wallet())], [
		["CANCEL", Callable(), "ghost"],
		["CONFIRM", func(): do_buy(id), "primary"]])

## The confirmed purchase: says it's done only once it is.
func do_buy(id: String) -> void:
	var why := Store.buy_tier(id)
	if why == "":
		Sfx.play("coins")
		Game.toast("LEVEL %d UNLOCKED" % Store.looks.level(id), UI.GOLD)
	else:
		Game.toast(why, UI.WARN)

# ------------------------------------------------------------------ GOAL CELEBRATIONS
## A celebration's card along the bottom: its little scene, LEVEL n, its name, and what it is to
## you (EQUIPPED, OWNED, or PURCHASE and its price). The frame grows grander with the level.
func _paint_celeb(ci: Control, r: Rect2, mode: String, n: int) -> void:
	var lvl := n - 1
	var st := tier_state(n)
	var picked := n == sel
	var down := mode == "down"
	var box := Rect2(r.position + (Vector2(1, 2) if down else Vector2.ZERO), r.size - Vector2(1, 2))
	var edge: Color = UI.GOLD if (picked or mode == "hover") else CELEB_EDGE[lvl]
	Deck.frame(ci, box, Deck.NAVY_HEAD.lightened(0.14) if picked else Deck.NAVY_HEAD, edge, not down)
	if picked:
		ci.draw_rect(Rect2(box.position + Vector2(2, 2), Vector2(box.size.x - 4, 1)), UI.GOLD)
		ci.draw_rect(Rect2(box.position + Vector2(2, box.size.y - 3), Vector2(box.size.x - 4, 1)), UI.GOLD)
	for k in lvl:   # prestige: a pip a level
		ci.draw_rect(Rect2(box.end.x - 8 - k * 5, box.position.y + 5, 3, 3), CELEB_EDGE[lvl])
	if lvl == VisualUpgrades.FIREWORKS:   # the premium one's corners
		for k in 2:
			ci.draw_rect(Rect2(box.position + Vector2(3 if k == 0 else box.size.x - 8, box.size.y - 6), Vector2(5, 2)), UI.GOLD)
	var icon := Rect2(box.position + Vector2(5, 5), Vector2(28, 26))
	Deck.frame(ci, icon.grow(1), UI.INK, CELEB_EDGE[lvl])
	var team := c.team() if c != null else us
	UpgradeArt.celeb_icon(ci, icon, lvl, art_clock(), team.c1, team.c2)
	var x := icon.end.x + 5
	var y := box.position.y
	Deck.shadow_text(ci, x, y + 13, "LEVEL %d" % lvl, 16, UI.GOLD, "big")
	var tier: Array = VisualUpgrades.cat("goal").tiers[lvl]
	Deck.text(ci, x, y + 26, Deck.fit(String(tier[2]), box.end.x - x - 4), 8, UI.TEXT)
	var px := box.position.x + 5
	var sy := y + 42
	match st:
		"EQUIPPED":
			_pill(ci, px, sy, "EQUIPPED", UI.GOLD, UI.INK)
		"OWNED":
			_pill(ci, px, sy, "OWNED", UI.ACCENT, UI.INK)
		_:
			_pill(ci, px, sy, "PURCHASE", UI.TEXT, UI.INK)
			var price := str(VisualUpgrades.celeb_price(lvl))
			var at := px + Deck.text_w("PURCHASE") + 11
			Deck.text(ci, at, sy, price, 8, UI.TEXT)
			var coin := CreditCoin.height(16)
			ci.draw_texture_rect(CreditCoin.texture(16), Rect2(Vector2(at + Deck.text_w(price) + CreditCoin.GAP, roundf(sy - 2 - coin * 0.5)), Vector2(coin, coin)), false)

## The cards' little scenes' clock (standing still with Reduce Motion).
func art_clock() -> float:
	return t if Juice.enabled() else 2.0

## The selected celebration: what it is, where you stand with it, PREVIEW, and PURCHASE / EQUIP.
func _celeb_card() -> void:
	var lk := Store.looks
	var lvl := sel - 1
	var tier: Array = VisualUpgrades.cat("goal").tiers[lvl]
	var st := tier_state(sel)
	info.add_child(para("Buy any one, in any order. Equip one at a time.", UI.ACCENT, INFO_W - 12))
	var worn := UI.label("EQUIPPED: %s" % VisualUpgrades.celeb_name(lk.worn_celeb()), 8, UI.DIM, "caps")
	worn.name = "Wearing"
	worn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	worn.custom_minimum_size = Vector2(INFO_W - 12, 0)
	info.add_child(worn)
	var head := UI.label("LEVEL %d: %s" % [lvl, tier[0]], 8, UI.GOLD, "caps")
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
	var pv := UI.button("PREVIEW AGAIN" if played else "PREVIEW", play_level, "ghost", 0, 18)
	pv.name = "DetailPreview"
	info.add_child(pv)
	var b := UI.button("", func(): _act(st), "primary", 0, 20)
	b.name = "DetailAction"
	match st:
		"EQUIPPED":
			b.text = "EQUIPPED"
			b.disabled = true
		"OWNED":
			b.text = "EQUIP"
		_:
			CreditCoin.set_button(b, "PURCHASE  " + CreditCoin.tag(VisualUpgrades.celeb_price(lvl)))
	info.add_child(b)

func _celeb_act(st: String) -> void:
	var lvl := sel - 1
	if st == "OWNED":
		Store.equip_celeb(lvl)
		Sfx.play("confirm")
		Game.toast("%s EQUIPPED" % VisualUpgrades.celeb_name(lvl), UI.GOLD)
		return
	if st != "PURCHASE":
		return
	var price := VisualUpgrades.celeb_price(lvl)
	var why := Store.looks.celeb_block(lvl, c)
	if why == "NOT ENOUGH POLO POINTS":
		StorePrompt.need(c, price, VisualUpgrades.celeb_name(lvl), Callable())
		return
	if why != "":
		Game.toast(why, UI.WARN)
		return
	Game.dialog("BUY %s?" % VisualUpgrades.celeb_name(lvl), "COST: %s\nYOU HAVE: %s" % [CreditCoin.tag(price), CreditCoin.tag(c.wallet())], [
		["CANCEL", Callable(), "ghost"],
		["CONFIRM", func(): do_buy_celeb(lvl), "primary"]])

## The confirmed purchase: says it's done only once it is (and wears it).
func do_buy_celeb(lvl: int) -> void:
	var why := Store.buy_celeb(lvl)
	if why == "":
		Sfx.play("coins")
		Game.toast("%s UNLOCKED AND EQUIPPED" % VisualUpgrades.celeb_name(lvl), UI.GOLD)
	else:
		Game.toast(why, UI.WARN)

var _art_wait := 0.0

## The celebration cards' scenes move about ten times a second (never with Reduce Motion).
func lab_tick(dt: float) -> void:
	super(dt)
	if not is_goal() or tier_row == null or not Juice.enabled():
		return
	_art_wait -= dt
	if _art_wait <= 0.0:
		_art_wait = 0.1
		for b in tier_row.get_children():
			(b as Control).queue_redraw()
