extends BaseScreen
## THE POLO POINTS SHOP: Polo Points (PP) for real money (the four packs) and PIXEL POLO +. What
## Polo Points buy is everywhere else. Nothing here flashes, counts down or pretends to be a discount.
##
## The look (the game's newer screens: chunky frames, hard 1 px / 2 px shadows, the bevel ring):
##   the four packs   one card each, the same size, a step richer per tier (TIERS): the amount
##                    first, the pack's name in its band, a coin pile, the price on a gold badge.
##                    Hovered, the edge lights; pressed, the whole card goes down into its shadow.
##   PIXEL POLO +     a royal-navy plate with a doubled gold edge, a star badge, the perks.
##   LUCKY SPIN       a deep-navy strip with a little wheel turning slowly, the allowance
##                    (SPINS AVAILABLE: 2/2 or NEXT SPINS IN: ...) and SPIN THE WHEEL, which opens
##                    the wheel over the shop (LuckySpinPanel).
##   the bottom       the wallet note in its own strip; RESTORE PURCHASES (a quiet ghost button) and,
##                    in the editor's test store only, a small TEST STORE tag.
## The motion (none with Reduce Motion): a coin sparkle now and then on the bigger packs, and a gold
## shimmer that crosses the Legendary card every few seconds.

func _ready() -> void:
	c = Game.career
	build("POLO POINTS SHOP", true, c != null)
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
	_animated.clear()
	for ch in body.get_children():
		ch.queue_free()
	for ch in header_right.get_children():
		header_right.remove_child(ch)   # (out of the tree now, so the new chips keep their names)
		ch.queue_free()
	header_right.add_child(credits_chip())
	var v := UI.vbox(4)
	body.add_child(UI.scroll(v))
	_coin_shop(v)

# ------------------------------------------------------------------ motion
var anim_t := 0.0
var _frame := -1
var _animated: Array = []    # the pack cards' art canvases that move (sparkle, shimmer)

var _status_t := 0.0

func _process(delta: float) -> void:
	_status_t += delta
	if _status_t >= 0.5:   # (the spin countdown ticks even with Reduce Motion)
		_status_t = 0.0
		_spin_status()
	if bool(Game.settings.get("reduce_motion", false)):
		return
	anim_t += delta
	var f := int(anim_t * 12.0)   # 12 steps a second: pixel art moves in steps
	if f == _frame:
		return
	_frame = f
	for a in _animated:
		if is_instance_valid(a):
			a.queue_redraw()
	if is_instance_valid(_mini_wheel):
		_mini_wheel.rot = f * (TAU / 96.0)   # (a slow turn, in steps)
		_mini_wheel.queue_redraw()

# ------------------------------------------------------------------ the shop
func _coin_shop(v: VBoxContainer) -> void:
	var g := GridContainer.new()
	g.name = "CoinPacks"
	g.columns = 2
	g.add_theme_constant_override("h_separation", 5)
	g.add_theme_constant_override("v_separation", 5)
	v.add_child(g)
	for i in range(Store.PACK_IDS.size()):
		g.add_child(_pack_card(Store.PACK_IDS[i], i))
	v.add_child(_pro_card())
	v.add_child(_spin_card())
	v.add_child(_wallet_note())
	v.add_child(_footer())

const WALLET_NOTE := "Purchased Polo Points stay with you across every dynasty. Your dynasty's own Polo Points are always spent first."

## The wallet note: its own quiet strip under the purchases, the coin at its left.
func _wallet_note() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.chunky(Color(0.02, 0.06, 0.25, 0.22), Color(1, 1, 1, 0.16), false, false, 5, 3, UI.BEVEL_NONE))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UI.hbox(5)
	p.add_child(h)
	h.add_child(CreditCoin.icon(10))
	var wl := UI.label(WALLET_NOTE, 8, UI.DIM)
	wl.name = "WalletNote"
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wl.custom_minimum_size = Vector2(300, 0)
	h.add_child(wl)
	return p

## RESTORE PURCHASES (secondary: the quiet ghost button) and, only in the editor's test store (never
## in an exported game: Store picks that backend in the editor alone), a small TEST STORE tag.
func _footer() -> Control:
	var f := UI.hbox(6)
	f.name = "StoreFooter"
	var rb := Deck.button("RESTORE PURCHASES", _restore, "ghost", 0, 16)
	rb.name = "Restore"
	rb.add_theme_font_size_override("font_size", 8)
	f.add_child(rb)
	f.add_child(UI.spacer(0, 0, true))
	if Store.is_test_store():
		var tag := UI.canvas(int(Deck.text_w("TEST STORE")) + 8, 11, func(ci: Control):
			Deck.frame(ci, Rect2(0, 0, ci.size.x, 11), Color("47270b"), UI.WARN)
			Deck.text(ci, 4, 5.5, "TEST STORE", 8, UI.WARN))
		tag.name = "TestStoreTag"
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		f.add_child(tag)
		var tl := UI.label("Desktop only: nothing is charged.", 8, UI.DIM2)
		tl.name = "StoreNote"
		tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		f.add_child(tl)
	elif not Store.available():
		var nl := UI.label("The store isn't available right now. Check your connection and try again.", 8, UI.DIM)
		nl.name = "StoreNote"
		nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		f.add_child(nl)
	return f

# ------------------------------------------------------------------ the pack cards
## Each tier's card, a step richer than the last: fill, edge, the band's trim line, the name's
## colour, the POLO POINTS line's colour, and the coin pile (stack heights, front coins).
const TIERS := [
	{"fill": "1d4ab8", "edge": "ffffff", "trim": "5c86e8", "name": "ffffff", "unit": "c3d4ff", "stacks": [4, 2], "front": 1},
	{"fill": "1a42ae", "edge": "ffffff", "trim": "ffd23f", "name": "ffffff", "unit": "ffd23f", "stacks": [6, 4, 3], "front": 1},
	{"fill": "16389c", "edge": "ffd23f", "trim": "ffd23f", "name": "ffe98a", "unit": "ffd23f", "stacks": [8, 6, 9], "front": 2},
	{"fill": "0c2272", "edge": "ffd23f", "trim": "ffe98a", "name": "ffd23f", "unit": "ffd23f", "stacks": [9, 7, 11, 6], "front": 3},
]
const PACK_H := 60
const BAND_H := 13          # the name band across the card's top

func _pack_card(id: String, tier: int) -> Control:
	var p := Store.product(id)
	var b := Button.new()
	b.name = "Pack_" + id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, PACK_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = "%s: %s Polo Points for %s" % [String(p.title).capitalize(), _fmt(int(p.credits)), Store.price(id)]
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())   # (the card paints itself: _paint_pack)
	var art := UI.canvas(0, 0, func(ci: Control): _paint_pack(ci, b, id, tier))
	art.name = "PackArt"
	art.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # (the band's stripes tile)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(art)
	for sig in [b.mouse_entered, b.mouse_exited, b.button_down, b.button_up]:
		sig.connect(art.queue_redraw)
	if tier >= 1:
		_animated.append(art)
	b.pressed.connect(func():
		Sfx.play("click")
		StorePrompt.buy_then(id))
	b.set_meta("coins", int(p.credits))
	b.disabled = not Store.available()   # (no store, no working button)
	if b.disabled:
		b.modulate = Color(1, 1, 1, 0.55)
	return b

## One pack card: its frame (the shadow under it; pressed, it sits where the shadow was), the name
## band, the coin pile, the amount with its coin, POLO POINTS, and the price badge.
func _paint_pack(ci: Control, b: Button, id: String, tier: int) -> void:
	var t: Dictionary = TIERS[tier]
	var p := Store.product(id)
	var down := not b.disabled and b.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]
	var hover := not b.disabled and b.is_hovered()
	var fill := Color(t.fill)
	var edge := Color(t.edge)
	if hover:
		edge = UI.GOLD if edge.s < 0.05 else Color("fff2a8")
	var r := Rect2(0, 0, ci.size.x - 1, ci.size.y - 2).abs()
	if down:
		r.position += Vector2(1, 2)
	Deck.frame(ci, r, fill, edge, not down, UI.BEVEL_SOFT)
	var o := r.position
	var w := r.size.x
	var h := r.size.y
	# the name band: a step lighter, striped from All-Star up, a trim line under it
	var band := Rect2(o.x + 1, o.y + 1, w - 2, BAND_H)
	ci.draw_rect(Rect2(band.position + Vector2(1, 0), band.size - Vector2(2, 0)), fill.lightened(0.07))
	if tier >= 2:
		Deck.stripes(ci, Rect2(band.position + Vector2(1, 1), band.size - Vector2(2, 1)), fill.lightened(0.07), 0.04)
	ci.draw_rect(Rect2(o.x + 1, o.y + 1 + BAND_H, w - 2, 1), Color(t.trim))
	if tier >= 1:   # the gold accent under the trim: a second, darker line
		ci.draw_rect(Rect2(o.x + 1, o.y + 2 + BAND_H, w - 2, 1), Color(t.trim).darkened(0.45))
	if tier == 3:   # the Legendary trim: a second gold ring inside the edge
		_ring(ci, Rect2(o + Vector2(2, 2), r.size - Vector2(4, 4)), Color("b8860b"))
	if hover:       # hovered: a light inner ring along the edge
		_ring(ci, Rect2(o + Vector2(1, 1), r.size - Vector2(2, 2)), Color(1, 1, 1, 0.22))
	if tier == 3:
		_shimmer(ci, Rect2(o + Vector2(3, 3), r.size - Vector2(6, 6)))
	# the name, a crown before the Legendary's
	var nx := o.x + 6
	if tier == 3:
		_crown(ci, Vector2(nx, o.y + 3))
		nx += 13
	Deck.shadow_text(ci, nx, o.y + 1 + BAND_H * 0.5, String(p.title), 8, Color(t.name))
	# the coin pile, bottom-left
	_draw_pile(ci, Vector2(o.x + 7, o.y + h - 6), tier)
	# the amount (the focal point) and its coin; POLO POINTS under it
	var ax := o.x + 54
	var amount := _fmt(int(p.credits))
	Deck.text(ci, ax + 1, o.y + 31, amount, 20, Color(0.02, 0.06, 0.25, 0.7), "big")
	CreditCoin.draw_amount(ci, ax, o.y + 30, amount, 20, UI.GOLD, "big", 20)
	Deck.text(ci, ax, o.y + 47, "POLO POINTS", 8, Color(t.unit))
	# the price badge, bottom-right: a gold button-in-the-card
	var pr := Store.price(id)
	var pw := Deck.text_w(pr) + 12
	var pb := Rect2(o.x + w - pw - 7, o.y + h - 19, pw, 13)
	Deck.frame(ci, pb, Color("ffe27a") if hover else UI.GOLD, UI.BORDER if tier < 2 else Color("fff2a8"), true, UI.BEVEL_RAISED)
	Deck.text(ci, pb.position.x, pb.position.y + 6.5, pr, 8, UI.INK, "caps", 1, pb.size.x)
	_sparkle(ci, Vector2(o.x + 7, o.y + h - 6), tier)

## A 1 px ring with cut corners just inside `r`.
func _ring(ci: CanvasItem, r: Rect2, col: Color) -> void:
	r = Rect2(r.position.floor(), r.size.floor())
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), col)
	ci.draw_rect(Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 2, 1), col)
	ci.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), col)
	ci.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), col)

## The Legendary shimmer: every SHIMMER_EVERY seconds a slanted band of light crosses the card in
## SHIMMER_FOR seconds, in whole pixels, never past the gold ring. Still with Reduce Motion.
const SHIMMER_EVERY := 4.5
const SHIMMER_FOR := 0.75

func _shimmer(ci: CanvasItem, r: Rect2) -> void:
	var k := fmod(anim_t, SHIMMER_EVERY) / SHIMMER_FOR
	if anim_t <= 0.0 or k >= 1.0:
		return
	var span := r.size.x + r.size.y
	var x0 := r.position.x - r.size.y * 0.5 + floorf(k * span)
	for y in int(r.size.y):
		var x := floorf(x0 + (r.size.y - y) * 0.5)
		for band in [[0.0, 3.0, 0.16], [3.0, 1.0, 0.08]]:
			var a := maxf(x + band[0], r.position.x)
			var e := minf(x + band[0] + band[1], r.end.x)
			if e > a:
				ci.draw_rect(Rect2(a, r.position.y + y, e - a, 1), Color(1, 0.95, 0.7, band[2]))

## A sparkle now and then on a coin of the bigger packs: a little four-point glint, its own beat
## per card so they never blink together.
func _sparkle(ci: CanvasItem, base: Vector2, tier: int) -> void:
	if tier < 1 or anim_t <= 0.0:
		return
	var every := 3.6 - tier * 0.5
	var ph := fmod(anim_t + tier * 1.3, every)
	if ph > 0.5:
		return
	var stacks: Array = TIERS[tier].stacks
	var n := int(floorf((anim_t + tier * 1.3) / every))
	var s := n % stacks.size()
	var top := Vector2(base.x + s * 10 + 6, base.y - int(stacks[s]) * 3 - 1)
	var big := ph > 0.12 and ph < 0.38
	var lt := Color("fff8d0")
	ci.draw_rect(Rect2(top, Vector2.ONE), Color.WHITE)
	ci.draw_rect(Rect2(top + Vector2(-1, 0), Vector2(3, 1)), lt)
	ci.draw_rect(Rect2(top + Vector2(0, -1), Vector2(1, 3)), lt)
	if big:
		ci.draw_rect(Rect2(top + Vector2(-2, 0), Vector2(1, 1)), lt)
		ci.draw_rect(Rect2(top + Vector2(2, 0), Vector2(1, 1)), lt)
		ci.draw_rect(Rect2(top + Vector2(0, -2), Vector2(1, 1)), lt)
		ci.draw_rect(Rect2(top + Vector2(0, 2), Vector2(1, 1)), lt)
		ci.draw_rect(Rect2(top, Vector2.ONE), Color.WHITE)

## The Legendary crown: 11 x 8, gold with a dark outline and a lit row.
const CROWN := [
	"o....o....o",
	"oo..ooo..oo",
	"o#o.o#o.o#o",
	"o##o###o##o",
	"o#########o",
	"o#h#h#h#h#o",
	"o#########o",
	"ooooooooooo",
]

func _crown(ci: CanvasItem, at: Vector2) -> void:
	Deck.pat(ci, at, CROWN, {"o": UI.INK, "#": UI.GOLD, "h": Color("fff2a8")})

# ------------------------------------------------------------------ PIXEL POLO +
func _pro_card() -> Control:
	var own := Store.pro
	var edge := UI.GOOD if own else UI.GOLD
	var p := PanelContainer.new()
	p.name = "ProCard"
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", UI.chunky(Color("0b1d5c"), edge, true, false, 6, 4, UI.BEVEL_DOUBLE))
	var deco := UI.canvas(0, 0, func(ci: Control):   # faint stripes and a lit line under the edge
		Deck.stripes(ci, Rect2(Vector2(-4, -2), ci.size + Vector2(8, 4)), Color("0b1d5c"), 0.025)
		ci.draw_rect(Rect2(-4, -2, ci.size.x + 8, 1), Color(edge, 0.25)))
	deco.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	p.add_child(deco)
	var h := UI.hbox(7)
	p.add_child(h)
	var badge := UI.canvas(26, 26, func(ci: Control): _pro_badge(ci, own))
	badge.name = "ProBadge"
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(badge)
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var head := UI.hbox(6)
	v.add_child(head)
	var title := UI.label("PIXEL POLO +", 20, edge, "big")
	title.name = "ProTitle"
	title.add_theme_color_override("font_shadow_color", Color(0.01, 0.03, 0.12, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	head.add_child(title)
	var tag_t := "ACTIVE" if own else "PREMIUM UPGRADE"
	var tag := UI.canvas(int(Deck.text_w(tag_t)) + 8, 11, func(ci: Control):
		Deck.frame(ci, Rect2(0, 0, ci.size.x, 11), edge, UI.BORDER)
		Deck.text(ci, 4, 5.5, tag_t, 8, UI.INK))
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tag)
	var perks := GridContainer.new()
	perks.name = "ProPerks"
	perks.columns = 2
	perks.add_theme_constant_override("h_separation", 12)
	perks.add_theme_constant_override("v_separation", 2)
	v.add_child(perks)
	for perk in Store.pro_perks():
		var row := UI.hbox(4)
		row.add_child(_tick(own))
		row.add_child(UI.label(String(perk), 8, UI.DIM if own else UI.TEXT))
		perks.add_child(row)
	if not own:
		var right := UI.vbox(2)
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(right)
		var once := UI.label("ONE-TIME", 8, UI.GOLD, "caps")
		once.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right.add_child(once)
		var buy := Deck.button(Store.price(Store.PRO_ID), func(): StorePrompt.buy_then(Store.PRO_ID), "primary", 76, 24)
		buy.name = "BuyPro"
		buy.disabled = not Store.available()
		right.add_child(buy)
	return p

## The PIXEL POLO + badge: a raised gold-edged plate with the game's star, 2x.
func _pro_badge(ci: Control, own: bool) -> void:
	Deck.frame(ci, Rect2(0, 0, 25, 24), Color("14318c"), UI.GOOD if own else UI.GOLD, true, UI.BEVEL_RAISED)
	var at := Vector2(4, 3)
	Deck.pat(ci, at, Deck.STAR, {"#": UI.INK}, 2.0)
	Deck.pat(ci, at, Deck.STAR_INNER, {"#": UI.GOOD if own else UI.GOLD}, 2.0)
	ci.draw_rect(Rect2(at + Vector2(8, 4), Vector2(2, 2)), Color("fff2a8"))   # the glint

## A perk's tick: a small gold check (green once owned).
func _tick(own: bool) -> Control:
	var col := UI.GOOD if own else UI.GOLD
	var t := UI.canvas(7, 6, func(ci: Control):
		Deck.pat(ci, Vector2(0, 0), ["......#", ".....##", "#...##.", "##.##..", ".###...", "..#...."], {"#": col}))
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t

func _restore() -> void:
	Game.toast("Restoring purchases...", UI.ACCENT)
	var w := StorePrompt.Waiter.new()
	w.id = "restore"   # (every one-time unlock: PRO, ALL 30 TEAMS)
	StorePrompt._waiters.append(w)
	Store.purchase_finished.connect(w.done)
	Store.restore()

# ------------------------------------------------------------------ LUCKY SPIN
var _mini_wheel: LuckyWheel
var _spin_line: Label

## The LUCKY SPIN strip: the little wheel, what it is, the allowance, SPIN THE WHEEL. Quieter than
## the packs (no price, no gold plate), but its own colour: the wheel's cyan edge.
func _spin_card() -> Control:
	var p := PanelContainer.new()
	p.name = "LuckySpinCard"
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", UI.chunky(Color("071447"), LuckyWheel.C10, true, false, 6, 3, UI.BEVEL_DOUBLE))
	var deco := UI.canvas(0, 0, func(ci: Control):
		Deck.stripes(ci, Rect2(Vector2(-4, -2), ci.size + Vector2(8, 4)), Color("071447"), 0.03))
	deco.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	p.add_child(deco)
	var h := UI.hbox(7)
	p.add_child(h)
	_mini_wheel = LuckyWheel.new(17, false, true)
	_mini_wheel.name = "MiniWheel"
	_mini_wheel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_mini_wheel)
	var v := UI.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(v)
	var head := UI.hbox(6)
	v.add_child(head)
	var t := UI.label("LUCKY SPIN", 16, UI.GOLD, "big")
	t.name = "SpinTitle"
	t.add_theme_color_override("font_shadow_color", Color(0.01, 0.03, 0.12, 0.9))
	t.add_theme_constant_override("shadow_offset_x", 1)
	t.add_theme_constant_override("shadow_offset_y", 1)
	head.add_child(t)
	var tag_t := "FREE WITH AN AD"
	var tag := UI.canvas(int(Deck.text_w(tag_t)) + 8, 11, func(ci: Control):
		Deck.frame(ci, Rect2(0, 0, ci.size.x, 11), LuckyWheel.C10, UI.BORDER)
		Deck.text(ci, 4, 5.5, tag_t, 8, UI.INK))
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tag)
	var d := UI.label("Watch an ad, spin the wheel: every spin wins 5, 10 or 15 Polo Points.", 8, UI.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(200, 0)
	v.add_child(d)
	_spin_line = UI.label("", 8, UI.GOOD, "caps")
	_spin_line.name = "SpinLine"
	v.add_child(_spin_line)
	var b := Deck.button("SPIN THE WHEEL", func(): LuckySpinPanel.open(), "primary", 92, 22)
	b.name = "OpenSpin"
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	_spin_status()
	return p

func _spin_status() -> void:
	if not is_instance_valid(_spin_line):
		return
	var st := Store.spin_state()
	var now := Store.spin_now()
	_spin_line.text = st.status_text(now)
	_spin_line.add_theme_color_override("font_color", UI.GOOD if st.available(now) > 0 else UI.DIM)

# ------------------------------------------------------------------ the coin pile
## The pack's coins, from `base` (bottom-left): stacks of side-on coins that grow with the tier
## (TIERS.stacks), a soft shadow under them, and the Polo Points coin face-on in front.
func _draw_pile(ci: CanvasItem, base: Vector2, tier: int) -> void:
	var stacks: Array = TIERS[tier].stacks
	ci.draw_rect(Rect2(base.x - 1, base.y, stacks.size() * 10 + 2, 1), Color(0.02, 0.06, 0.25, 0.45))
	for s in stacks.size():
		for k in int(stacks[s]):
			_side_coin(ci, Vector2(base.x + s * 10, base.y - 3 - k * 3))
	var fronts := int(TIERS[tier].front)
	for i in fronts:
		var fx := base.x + 4 + i * 12 + (stacks.size() - fronts) * 5
		CreditCoin.draw(ci, Vector2(fx, base.y - 9), 10)

## A coin seen side-on: 9 wide, 3 tall (the lit top, the gold, the dark edge).
func _side_coin(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_rect(Rect2(p.x + 1, p.y, 7, 1), Color("fff2a8"))
	ci.draw_rect(Rect2(p.x, p.y + 1, 9, 1), UI.GOLD)
	ci.draw_rect(Rect2(p.x + 1, p.y + 2, 7, 1), Color("a8650f"))
	ci.draw_rect(Rect2(p.x + 7, p.y + 1, 2, 1), Color("e0a526"))

static func _fmt(n: int) -> String:
	var s := str(n)
	if n >= 1000:
		s = "%d,%03d" % [n / 1000, n % 1000]
	return s
