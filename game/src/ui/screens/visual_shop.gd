extends BaseScreen
## VISUAL UPGRADES (the Dynasty Hub's card): a gallery of five cards, all on one screen (no
## scrolling): two rows of two, then SCOREBOARD across the bottom. Each opens its own page
## (upgrade_detail.gd: the levels, previews, buying and wearing). Polo Points pay for them,
## Store.looks owns them, every dynasty has them. More are in the Polo Points Shop. Back is
## always the Dynasty Hub.

var art_t := 2.0              # the cards' clock (stands still with Reduce Motion: the GOAL! frame)
var art_wait := 0.0
var cards: Array = []
var balance_label: Label = null   # the header's Polo Points number (PoloBalance)
var rival: PoloTeam = null   # the cards' other team (VisualUpgrades.preview_rival_id), read on every render

func _ready() -> void:
	c = Game.career
	if c == null:
		Game.goto("title")
		return
	back_target = "more"
	build("VISUAL UPGRADES", true, true)
	Store.state_changed.connect(_refresh)
	Store.products_updated.connect(_refresh)
	_render()

func _exit_tree() -> void:
	if Store.state_changed.is_connected(_refresh):
		Store.state_changed.disconnect(_refresh)
	if Store.products_updated.is_connected(_refresh):
		Store.products_updated.disconnect(_refresh)

func _refresh() -> void:
	if is_inside_tree():
		_render()

func _render() -> void:
	for ch in body.get_children():
		ch.queue_free()
	for ch in header_right.get_children():
		header_right.remove_child(ch)   # (out of the tree now, so the new chips keep their names)
		ch.queue_free()
	header_right.add_child(_balance_box())
	header_right.add_child(_store_button())
	var v := UI.vbox(GAP)
	v.name = "UpgradeGrid"
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(v)
	cards = []
	rival = c.teams.get(VisualUpgrades.preview_rival_id(c))   # (only drawn: its colours, its logo)
	_upgrades(v)

## The header's balance, "1537 (coin)": a navy box with a blue edge, the amount and coin centred.
## Only shows the balance (never clickable); _render redraws it whenever Polo Points move.
func _balance_box() -> Control:
	var h := CreditCoin.height(16) + 2
	var p := PanelContainer.new()
	p.name = "PoloBalance"
	p.add_theme_stylebox_override("panel", UI.chunky(Deck.NAVY, UI.ACCENT, false, false, 6, 1, UI.BEVEL_NONE))
	p.custom_minimum_size = Vector2(0, maxi(18, h))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var amt := CreditCoin.widget(Wallet.yellow(c), 8, UI.GOLD)
	amt.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(centered(amt))
	_ignore_mouse(p)
	balance_label = amt.find_child("Amount", true, false)
	return p

## Career-only Polo Points (earned, or spent from the dynasty's own) send no Store signal, so the
## box checks the wallet each frame and updates its number the moment it moves.
func _sync_balance() -> void:
	if c == null or not is_instance_valid(balance_label):
		return
	var t := CreditCoin.text(Wallet.yellow(c))
	if balance_label.text != t:
		balance_label.text = t

## STORE (coin): the blue button that opens the Polo Points Shop.
func _store_button() -> Button:
	var b := Deck.button("STORE", func(): Game.goto("store"), "normal", 0, maxi(18, CreditCoin.height(16) + 2))
	CreditCoin.set_button(b, "STORE" + CreditCoin.TAG)
	b.name = "StoreButton"
	b.tooltip_text = "Polo Points Shop"
	return b

# ------------------------------------------------------------------ VISUAL UPGRADES
## The cards fill the page between the header and the bottom, each row an equal share (at 480 x
## 270, 1440 x 810 on screen: about 77 px a row); never shorter than CARD_H, so the scene (ART_W x
## ART_H, as the scenes are drawn) always fits beside the words.
const CARD_H := 72
const ART_W := 96
const ART_H := 62
const GAP := 4
## The rows: the first four in pairs, the last one (SCOREBOARD) the full width.
const ROWS := [["goal", "crowd"], ["broadcast", "pregame"], ["scoreboard"]]

## The art moves about ten times a second (never with Reduce Motion, never in a test).
func _process(dt: float) -> void:
	_sync_balance()
	if cards.is_empty() or not Juice.enabled():
		return
	art_t += dt
	art_wait -= dt
	if art_wait <= 0.0:
		art_wait = 0.1
		for b: Control in cards:
			b.queue_redraw()

## Five cards: what it is, how far you've come, tap for its page.
func _upgrades(v: VBoxContainer) -> void:
	var i := 0
	for ids: Array in ROWS:
		var row := UI.hbox(GAP + 1)
		row.name = "Row%d" % i
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(row)
		for id: String in ids:
			var card := _upgrade_card(VisualUpgrades.cat(id), ids.size() == 1)
			row.add_child(card)
			cards.append(card)
			Juice.enter(card, i)
			i += 1

func _upgrade_card(cd: Dictionary, wide: bool) -> Control:
	var id := String(cd.id)
	var paint := func(ci: Control, r: Rect2, mode: String):
		if wide:
			_paint_wide(ci, r, mode, cd)
		else:
			_paint_card(ci, r, mode, cd)
	var b := Deck.card(Vector2(0, CARD_H), paint, func(): Game.goto("upgrade_detail", {"cat": id}))
	b.name = "Upgrade_" + id
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return b

## The card's frame, its corners and its scene (on the left, as tall as the card allows, centred);
## returns [the box, the scene's rect].
func _paint_frame(ci: Control, r: Rect2, mode: String, id: String) -> Array:
	var maxed := _maxed(id)
	var hot := mode != "normal"
	var down := mode == "down"
	var box := Rect2(r.position + (Vector2(1, 2) if down else Vector2.ZERO), r.size - Vector2(1, 2))
	var edge := UI.GOLD if (hot or maxed) else UI.BORDER
	Deck.frame(ci, box, Deck.NAVY_HEAD.lightened(0.08) if mode == "hover" else Deck.NAVY, edge, not down)
	for k in 4:   # the corners
		var cx := box.position.x + (3.0 if k % 2 == 0 else box.size.x - 6.0)
		var cy := box.position.y + (box.size.y - 6.0 if k >= 2 else 3.0)
		ci.draw_rect(Rect2(cx, cy, 3, 1), edge)
		ci.draw_rect(Rect2(cx + (0 if k % 2 == 0 else 2), cy + (0 if k < 2 else -2), 1, 3), edge)
	var ah := clampf(floorf(box.size.y - 12.0), ART_H, ART_H + 12.0)
	var art := Rect2(box.position.x + 6, box.position.y + floorf((box.size.y - ah) * 0.5), ART_W, ah)
	Deck.frame(ci, art.grow(1), UI.INK, UI.GOLD if hot else UI.ACCENT)
	var team := c.team()
	UpgradeArt.draw(ci, id, art, art_t, team.c1, team.c2, team, rival)
	return [box, art]

## The name in the big font: on one line if it fits `w`, else on two (split at the space that
## evens them best). Returns the y under it.
func _title(ci: Control, x: float, y: float, w: float, title: String) -> float:
	if Deck.text_w(title, 16, "big") <= w or not title.contains(" "):
		Deck.shadow_text(ci, x, y + 7, Deck.fit(title, w, 16, "big"), 16, UI.GOLD, "big")
		return y + 15
	var words := title.split(" ")
	var cut := 1
	var best := INF
	for k in range(1, words.size()):
		var d := absf(Deck.text_w(" ".join(words.slice(0, k)), 16, "big") - Deck.text_w(" ".join(words.slice(k)), 16, "big"))
		if d < best:
			best = d
			cut = k
	Deck.shadow_text(ci, x, y + 7, Deck.fit(" ".join(words.slice(0, cut)), w, 16, "big"), 16, UI.GOLD, "big")
	Deck.shadow_text(ci, x, y + 19, Deck.fit(" ".join(words.slice(cut)), w, 16, "big"), 16, UI.GOLD, "big")
	return y + 26

## The progress bar: a segment a level, lit as far as you own, a tick under the one worn.
func _segments(ci: Control, x: float, y: float, id: String) -> void:
	var lk := Store.looks
	var maxed := _maxed(id)
	for n in VisualUpgrades.top(id):
		var seg := Rect2(x + n * 19, y, 17, 6)
		var owned: bool = lk.owns_celeb(n) if id == "goal" else n < lk.level(id)
		ci.draw_rect(seg, UI.INK)
		ci.draw_rect(seg.grow(-1), (UI.GOLD if maxed else UI.ACCENT) if owned else Deck.NAVY_HEAD)
		if n + 1 == lk.worn(id):
			ci.draw_rect(Rect2(seg.position.x + 6, seg.end.y + 1, 5, 1), UI.TEXT)

## The cue and its arrow, ending at `x_right`, on the line through `y`.
func _cue(ci: Control, x_right: float, y: float, id: String, hot: bool) -> void:
	var t := cue(id)
	var aw := Deck.text_w(t)
	var nudge := 1.0 if (hot or int(art_t * 3.0) % 2 == 0) else 0.0
	var x := x_right - aw - 9
	Deck.text(ci, x, y, t, 8, UI.GOLD if (hot or _maxed(id)) else UI.TEXT)
	for i in 4:   # the arrow
		ci.draw_rect(Rect2(x + aw + 4 + nudge + i, y - 3 + i, 1, 7 - i * 2), UI.GOLD)

## Its line, in as many lines of `w` as there's room for above `bottom` (the last one cut short
## with a dot if it runs over).
func _tagline(ci: Control, x: float, y: float, w: float, bottom: float, id: String) -> void:
	var lines: Array = _lines(String(UpgradeArt.TAGS[id]).to_upper(), w)
	var room := maxi(1, int((bottom - y) / 8.0) + 1)
	for li in mini(lines.size(), room):
		var line: String = lines[li]
		if li == room - 1 and lines.size() > room:
			line = Deck.fit(" ".join(lines.slice(li)), w)
		Deck.text(ci, x, y + li * 8, line, 8, UI.ACCENT)

## A half-width card: the scene on the left; on the right the name, its line, how far you've
## come (the bar) and the way in.
func _paint_card(ci: Control, r: Rect2, mode: String, cd: Dictionary) -> void:
	var id := String(cd.id)
	var maxed := _maxed(id)
	var f := _paint_frame(ci, r, mode, id)
	var box: Rect2 = f[0]
	var art: Rect2 = f[1]
	var tx := art.end.x + 7
	var tw := box.end.x - tx - 7
	var y := _title(ci, tx, box.position.y + 5, tw, String(cd.name))
	ci.draw_rect(Rect2(tx, y, tw, 1), UI.GOLD if maxed else UI.ACCENT)
	var by := box.end.y - 22
	_tagline(ci, tx, y + 6, tw, by - 7, id)
	Deck.text(ci, tx, by, Deck.fit(progress(id), tw), 8, UI.GOLD if maxed else UI.TEXT)
	_segments(ci, tx, by + 5, id)
	_cue(ci, box.end.x - 7, box.end.y - 8, id, mode != "normal")

## The full-width card (SCOREBOARD, along the bottom): the scene on the left, its name, line and
## progress in the middle, the way in as a button on the right.
func _paint_wide(ci: Control, r: Rect2, mode: String, cd: Dictionary) -> void:
	var id := String(cd.id)
	var hot := mode != "normal"
	var maxed := _maxed(id)
	var f := _paint_frame(ci, r, mode, id)
	var box: Rect2 = f[0]
	var art: Rect2 = f[1]
	# the button, on the right, centred
	var lit := UI.GOLD if (hot or maxed) else UI.ACCENT
	var bw := Deck.text_w(cue(id)) + 26
	var btn := Rect2(box.end.x - 12 - bw, box.position.y + floorf(box.size.y * 0.5) - 11, bw, 22)
	Deck.frame(ci, btn, Deck.NAVY_HEAD.lightened(0.14) if hot else Deck.NAVY_HEAD, lit, mode != "down")
	ci.draw_rect(Rect2(btn.position + Vector2(2, 2), Vector2(btn.size.x - 4, 1)), Color(lit, 0.5))
	_cue(ci, btn.end.x - 6, btn.position.y + 11, id, hot)
	# the middle
	var tx := art.end.x + 10
	var tw := btn.position.x - 12 - tx
	var y := _title(ci, tx, box.position.y + 6, tw, String(cd.name))
	ci.draw_rect(Rect2(tx, y, tw, 1), UI.GOLD if maxed else UI.ACCENT)
	var by := box.end.y - 22
	_tagline(ci, tx, y + 8, tw, by - 7, id)
	Deck.text(ci, tx, by, progress(id), 8, UI.GOLD if maxed else UI.TEXT)
	_segments(ci, tx, by + 5, id)

## Everything in it owned (Goal Celebrations: all three bought, whatever order).
func _maxed(id: String) -> bool:
	if id == "goal":
		return Store.looks.celebs.size() >= VisualUpgrades.FIREWORKS
	return Store.looks.level(id) >= VisualUpgrades.top(id)

func progress(id: String) -> String:
	if id == "goal":
		return "%d / %d OWNED" % [Store.looks.celebs.size(), VisualUpgrades.FIREWORKS]
	return "LEVEL %d / %d UNLOCKED" % [Store.looks.level(id), VisualUpgrades.top(id)]

func cue(id: String) -> String:
	if id == "goal":
		return "ALL OWNED" if _maxed(id) else "VIEW CELEBRATIONS"
	return "MAXED OUT" if Store.looks.level(id) >= VisualUpgrades.top(id) else "VIEW UPGRADES"

## `t` in lines of at most `w` px, whole words.
static func _lines(t: String, w: float) -> Array:
	t = Loc.t(t)   # (the player's LANGUAGE: translated whole, then wrapped)
	var out: Array = []
	var line := ""
	for word: String in Loc.units(t):
		var next := word if line == "" else line + Loc.gap() + word
		if Deck.text_w(next) <= w or line == "":
			line = next
		else:
			out.append(line)
			line = word
	out.append(line)
	return out
