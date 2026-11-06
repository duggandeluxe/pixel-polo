extends BaseScreen
## VISUAL UPGRADES (the Dynasty Hub's card): a gallery of six big cards, each opening its own page
## (upgrade_detail.gd: the levels, previews, buying and wearing). Yellow Coins pay for them,
## Store.looks owns them, every dynasty has them. More coins are in the Yellow Coin Shop. Back is
## always the Dynasty Hub.

var art_t := 2.0              # the cards' clock (stands still with Reduce Motion: the GOAL! frame)
var art_wait := 0.0
var cards: Array = []

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
	var get_coins := UI.button("GET YELLOW COINS", func(): Game.goto("store"), "ghost", 0, 18)
	get_coins.name = "GetCoins"
	header_right.add_child(get_coins)
	header_right.add_child(credits_chip())
	var v := UI.vbox(3)
	body.add_child(UI.scroll(v))
	cards = []
	_upgrades(v)

# ------------------------------------------------------------------ VISUAL UPGRADES
const CARD_H := 100
const ART_W := 96

## The art moves about ten times a second (never with Reduce Motion, never in a test).
func _process(dt: float) -> void:
	if cards.is_empty() or not Juice.enabled():
		return
	art_t += dt
	art_wait -= dt
	if art_wait <= 0.0:
		art_wait = 0.1
		for b: Control in cards:
			b.queue_redraw()

## Six cards, two by three: what it is, how far you've come, tap for its page.
func _upgrades(v: VBoxContainer) -> void:
	var g := GridContainer.new()
	g.name = "UpgradeGrid"
	g.columns = 2
	g.add_theme_constant_override("h_separation", 5)
	g.add_theme_constant_override("v_separation", 5)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(g)
	var i := 0
	for cd in VisualUpgrades.CATS:
		var card := _upgrade_card(cd)
		g.add_child(card)
		cards.append(card)
		Juice.enter(card, i)
		i += 1

func _upgrade_card(cd: Dictionary) -> Control:
	var id := String(cd.id)
	var b := Deck.card(Vector2(0, CARD_H), func(ci: Control, r: Rect2, mode: String): _paint_card(ci, r, mode, cd), func():
		Game.goto("upgrade_detail", {"cat": id}))
	b.name = "Upgrade_" + id
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

func _paint_card(ci: Control, r: Rect2, mode: String, cd: Dictionary) -> void:
	var id := String(cd.id)
	var lk := Store.looks
	var maxed := lk.level(id) >= VisualUpgrades.top(id)
	var hot := mode != "normal"
	var down := mode == "down"
	var box := Rect2(r.position + (Vector2(1, 2) if down else Vector2.ZERO), r.size - Vector2(1, 2))
	var edge := UI.GOLD if (hot or maxed) else UI.BORDER
	Deck.frame(ci, box, Deck.NAVY_HEAD.lightened(0.08) if mode == "hover" else Deck.NAVY, edge, not down)
	# the title band, stepped into the card
	var x := box.position.x
	var y := box.position.y
	ci.draw_rect(Rect2(x + 2, y + 2, box.size.x - 4, 17), Deck.NAVY_HEAD)
	ci.draw_rect(Rect2(x + 2, y + 19, box.size.x - 4, 1), UI.GOLD if maxed else UI.ACCENT)
	Deck.shadow_text(ci, x + 7, y + 10, Deck.fit(String(cd.name), box.size.x - 14, 16, "big"), 16, UI.GOLD, "big")
	# the corners
	for k in 4:
		var cx := x + (3.0 if k % 2 == 0 else box.size.x - 6.0)
		var cy := y + (box.size.y - 6.0 if k >= 2 else 3.0)
		ci.draw_rect(Rect2(cx, cy, 3, 1), edge)
		ci.draw_rect(Rect2(cx + (0 if k % 2 == 0 else 2), cy + (0 if k < 2 else -2), 1, 3), edge)
	# the scene
	var art := Rect2(x + 6, y + 24, ART_W, box.size.y - 31)
	Deck.frame(ci, art.grow(1), UI.INK, UI.GOLD if hot else UI.ACCENT)
	var team := c.team()
	UpgradeArt.draw(ci, id, art, art_t, team.c1, team.c2)
	# where you stand
	var tx := art.end.x + 7
	var tw := box.end.x - tx - 6
	var lines: Array = _lines(String(UpgradeArt.TAGS[id]).to_upper(), tw)
	for li in lines.size():
		Deck.text(ci, tx, y + 28 + li * 10, lines[li], 8, UI.ACCENT)
	var ly := y + 49
	Deck.text(ci, tx, ly, progress(id), 8, UI.GOLD if maxed else UI.TEXT)
	for n in (0 if id == "replay" else VisualUpgrades.top(id)):   # (one unlock has no levels to count)
		var seg := Rect2(tx + n * 19, ly + 6, 17, 6)
		var owned: bool = n < lk.level(id)
		ci.draw_rect(seg, UI.INK)
		ci.draw_rect(seg.grow(-1), (UI.GOLD if maxed else UI.ACCENT) if owned else Deck.NAVY_HEAD)
		if n + 1 == lk.worn(id):
			ci.draw_rect(Rect2(seg.position.x + 6, seg.end.y + 1, 5, 1), UI.TEXT)
	Deck.text(ci, tx, box.end.y - 10, cue(id), 8, UI.GOLD if (hot or maxed) else UI.TEXT)
	var aw := Deck.text_w(cue(id)) + 4
	var nudge := 1.0 if (hot or int(art_t * 3.0) % 2 == 0) else 0.0
	for i in 4:   # the arrow
		ci.draw_rect(Rect2(tx + aw + nudge + i, box.end.y - 13 + i, 1, 7 - i * 2), UI.GOLD)

func progress(id: String) -> String:
	if id == "replay":
		return "UNLOCKED" if Store.looks.level(id) >= 2 else "ONE-TIME UNLOCK"
	return "LEVEL %d / %d UNLOCKED" % [Store.looks.level(id), VisualUpgrades.top(id)]

func cue(id: String) -> String:
	if id == "replay":
		return "VIEW" if Store.looks.level(id) >= 2 else "VIEW UNLOCK"
	return "MAXED OUT" if Store.looks.level(id) >= VisualUpgrades.top(id) else "VIEW UPGRADES"

## `t` in lines of at most `w` px, whole words.
static func _lines(t: String, w: float) -> Array:
	var out: Array = []
	var line := ""
	for word in t.split(" "):
		var next := word if line == "" else line + " " + word
		if Deck.text_w(next) <= w or line == "":
			line = next
		else:
			out.append(line)
			line = word
	out.append(line)
	return out
