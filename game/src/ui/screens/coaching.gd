extends BaseScreen
## COACHING: two panels side by side. PICK YOUR DEFENSE (left): the four drops (DefenseFormation.
## DROPS), one picked at a time, its description, its playbook diagram (PlayDiagram: the drop's
## X's and O's, still) and SCOUT OPPONENT. The pick is
## Career.gameplan, saved the moment it's made; every match copies it at kick-off (MatchFlow.
## set_gameplan) and nothing in a match writes it back. PRESS isn't here: it's always on the bar.
## RECRUITING (right): OPEN RECRUITING (the market: Recruiting), this season's signings (X / 4),
## the projected roster against the cap, and up to three of your incoming recruits, each opening
## his own profile on the Recruiting screen. Facilities and staff (Facilities, still under MORE
## and Training) aren't here.

const GAP := 6
const DROP_H := 26
const BIG_BTN_H := 30
const TARGET_H := 30
const DESC_H := 20          # the description's room (two lines, the longest), so nothing jumps
const PLAYBOOK_MIN_H := 60
const PlayDiagram := preload("res://src/ui/play_diagram.gd")

func _init() -> void:
	detail = true   # (the playbook's arrows: drawn in the window's own pixels, finer than the rest)

func _ready() -> void:
	back_target = "hub"
	if c == null:
		c = Game.career
	if c != null and c.is_eliminated():
		# SEASON OVER: no next opponent to plan or scout for; the market instead (as the hub's RECRUITING)
		Game.goto.call_deferred("recruiting", {"tab": "MARKET"}, false)
		return
	build_compact("COACHING")
	_render()

func _render() -> void:
	for ch in body.get_children():
		ch.queue_free()
	body.add_child(UI.spacer(0, 2))
	var row := UI.hbox(GAP)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	row.add_child(_defense())
	row.add_child(_recruiting())
	body.add_child(UI.spacer(0, 1))

# ------------------------------------------------------------------ left: PICK YOUR DEFENSE
func _defense() -> Control:
	var v := UI.vbox(5)
	var p := navy_panel(v)
	p.name = "DefensePanel"
	p.size_flags_vertical = Control.SIZE_FILL
	v.add_child(big_text("PICK YOUR DEFENSE", UI.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(grid)
	for f in DefenseFormation.DROPS:
		grid.add_child(_drop_button(f))
	var desc := UI.label(String(DefenseFormation.DROP_TEXT[c.gameplan]), 8, UI.TEXT, "body")
	desc.name = "DropText"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(0, DESC_H)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
	var book: Control = PlayDiagram.new()
	book.name = "Playbook"
	book.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book.size_flags_vertical = Control.SIZE_EXPAND_FILL
	book.custom_minimum_size = Vector2(0, PLAYBOOK_MIN_H)
	book.setup(c.gameplan)
	v.add_child(book)
	var scout := _gold_button("SCOUT OPPONENT", func(): ScoutReveal.scout(), true)   # (the garage door first: ScoutReveal)
	scout.name = "ScoutOpponent"
	v.add_child(scout)
	return p

func _drop_button(f: int) -> Control:
	var on := f == c.gameplan
	var b := Deck.card(Vector2(0, DROP_H), func(ci, r, mode):
		var fill := UI.GOLD if on else (Deck.NAVY_HEAD.lightened(0.08) if mode == "hover" else Deck.NAVY_HEAD)
		Deck.frame(ci, Rect2(Vector2.ZERO, r.size), fill, UI.BORDER)
		Deck.ctext(ci, Rect2(Vector2.ZERO, r.size), DefenseFormation.NAMES[f], 8, UI.INK if on else UI.TEXT), func(): pick(f))
	b.name = "Drop_%d" % f
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.set_meta("selected", on)
	return b

## Your pick: saved at once, and the next match starts with it.
func pick(f: int) -> void:
	if not DefenseFormation.is_drop(f) or f == c.gameplan:
		return
	c.gameplan = f
	Game.save_career()
	_render()

# ------------------------------------------------------------------ right: RECRUITING
func _recruiting() -> Control:
	var v := UI.vbox(5)
	var p := navy_panel(v)
	p.name = "RecruitingPanel"
	p.size_flags_vertical = Control.SIZE_FILL
	v.add_child(big_text("RECRUITING", UI.ACCENT))
	var open := _gold_button("OPEN RECRUITING", func(): Game.goto("recruiting", {"from": "coaching"}), false, true)
	open.name = "OpenRecruiting"
	v.add_child(open)
	var over := Recruiting.over_by(c)
	var status := UI.label("SIGNED %d / %d    PROJECTED %d / %d" % [Recruiting.signed_count(c), Recruiting.SIGN_MAX, Recruiting.projected(c), c.roster_max()], 8, UI.ACCENT, "caps")
	status.name = "RecruitingStatus"
	v.add_child(status)
	if over > 0:
		var warn := UI.label("%d PLAYER%s MUST BE CUT AFTER THE SEASON" % [over, "" if over == 1 else "S"], 8, UI.WARN, "caps")
		warn.name = "CutWarning"
		v.add_child(warn)
	var list := UI.vbox(4)
	list.name = "Targets"
	v.add_child(list)
	if c.incoming.is_empty():
		var none := UI.label("NO RECRUITS SIGNED YET", 8, UI.DIM, "caps")
		none.name = "NoTargets"
		list.add_child(none)
	for r in c.incoming.slice(0, Recruiting.SIGN_MAX):   # (every signing: up to the four allowed)
		list.add_child(_target(r))
	v.add_child(UI.spacer(0, 0, true))
	return p

## J. THOMPSON / CF | his stars (Deck.star_bar: up to his POTENTIAL), and JOINS NEXT SEASON. Tap: his profile on the
## Recruiting screen's INCOMING tab.
func _target(r: Dictionary) -> Control:
	var pl: PoloPlayer = r.p
	var nm := "%s. %s" % [pl.first.substr(0, 1), pl.last.to_upper()]
	var st := pl.stars
	var b := Deck.card(Vector2(0, TARGET_H), func(ci, rr, mode):
		var w := floorf(rr.size.x)
		Deck.frame(ci, Rect2(0, 0, w, TARGET_H), Deck.NAVY_HEAD.lightened(0.08) if mode == "hover" else Deck.NAVY_HEAD, UI.BORDER)
		var pt := "NEXT SEASON"
		var pw := Deck.text_w(pt)
		Deck.text(ci, 6, 9, Deck.fit(nm, w - pw - 18), 8, UI.TEXT)
		var pos: String = pl.pos_text() + "  |"
		Deck.text(ci, 6, 21, pos, 8, UI.ACCENT)
		Deck.star_bar(ci, 6 + Deck.text_w(pos + " "), 17, st, pl.pot_stars, 0, Color(1, 1, 1, 0.18))
		Deck.text(ci, w - 6 - pw, TARGET_H * 0.5, pt, 8, UI.GOOD), func():
			Game.goto("recruiting", {"tab": "INCOMING", "sel": pl.id, "from": "coaching"}))
	b.name = "Target_%d" % pl.id
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

# ------------------------------------------------------------------ pieces
## A big yellow button the panel's width; `scope` adds the binoculars, `arrow` the arrow after it.
func _gold_button(t: String, cb: Callable, scope: bool = false, arrow: bool = false) -> Control:
	var b := Deck.card(Vector2(0, BIG_BTN_H), func(ci, r, mode):
		var w := floorf(r.size.x)
		var face := Deck.button_face(ci, Rect2(0, 0, w, BIG_BTN_H), UI.GOLD, UI.BORDER, mode)
		var tw := Deck.text_w(t, 20, "big") + (16.0 if scope else 0.0) + (14.0 if arrow else 0.0)
		var x := floorf(face.position.x + (w - tw) * 0.5)
		var my := face.position.y + BIG_BTN_H * 0.5
		if scope:
			_binoculars(ci, Vector2(x, my - 4))
			x += 16.0
		Deck.text(ci, x, my, t, 20, UI.INK, "big")
		if arrow:
			_arrow(ci, Vector2(x + Deck.text_w(t, 20, "big") + 6.0, my)), cb)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

## A pixel pair of binoculars, 12 x 8.
static func _binoculars(ci: CanvasItem, at: Vector2) -> void:
	for dx in [0.0, 7.0]:
		ci.draw_rect(Rect2(at + Vector2(dx, 2), Vector2(5, 6)), UI.INK)
		ci.draw_rect(Rect2(at + Vector2(dx + 1, 0), Vector2(3, 2)), UI.INK)
		ci.draw_rect(Rect2(at + Vector2(dx + 1, 5), Vector2(3, 2)), UI.GOLD.lightened(0.3))
	ci.draw_rect(Rect2(at + Vector2(5, 3), Vector2(2, 2)), UI.INK)

static func _arrow(ci: CanvasItem, mid: Vector2) -> void:
	ci.draw_rect(Rect2(mid.x, mid.y - 1, 7, 2), UI.INK)
	ci.draw_rect(Rect2(mid.x + 4, mid.y - 4, 2, 8), UI.INK)
	ci.draw_rect(Rect2(mid.x + 6, mid.y - 2, 2, 4), UI.INK)

func on_back() -> void:
	Sfx.play("back")
	Game.goto("hub")
