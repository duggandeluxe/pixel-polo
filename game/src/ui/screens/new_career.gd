extends BaseScreen
## New career: pick a school (the ones you've unlocked on the Road to Glory), then name your coach.

var step := 0
var pick := ""
var first := ""
var last := ""
var schools: Array = []
# the dynasty setup (Game.dynasty_setup): all 30 rosters, made before you pick and kept until a
# career starts from it, so every rating here is the players you'll get, and leaving and coming
# back shows the same ones
var preview: Career

func _ready() -> void:
	preview = Game.dynasty_setup()
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.setup_seed   # (the suggested coach comes with the setup too)
	var nm := CollegeGen.coach_name(rng)
	first = nm[0]
	last = nm[1]
	# the schools you can pick first, then the locked ones by the tier that opens them, each
	# group strongest first (Progression.picker_groups); your first pick is the top card
	glory = Game.progression()
	_regroup()
	pick = String(groups[0].ids[0]) if not groups[0].ids.is_empty() else ""
	# ALL 30 TEAMS arriving while the picker is up (bought here, restored, approved later)
	Store.state_changed.connect(_on_store_changed)
	build("NEW CAREER")
	_title_style()
	_render()
	Sfx.music("menu")

func on_back() -> void:
	if step > 0:
		step -= 1
		_render()
		return
	Sfx.play("back")
	Game.goto("careers", {}, false)

func _render() -> void:
	if step != 0 and is_instance_valid(list_scroll):
		list_at = list_scroll.scroll_vertical
	for ch in body.get_children():
		ch.queue_free()
	for ch in header_right.get_children():
		ch.queue_free()
	if step == 0:
		_step_school()
	else:
		_step_coach()

# ------------------------------------------------------------------ step 1: the school
# THE ROAD TO GLORY as a collection of school cards: a full-width grid under the title, AVAILABLE
# TEAMS first, then a LOCKED group for each tier still to earn, each under its header
# (Progression.picker_groups). A card is the whole choice: logo, name, conference, OFF and DEF
# stars. Tap an unlocked one and it's your pick (`pick`, the yellow card NEXT takes); a locked
# one only says what opens it.
const CARD_MIN_W := 112    # a card at least this wide (a 60 px logo clear of the OVR badge): as many columns as fit (never under MIN_COLS)
const MIN_COLS := 3
const CARD_H := 110
const CARD_GAP := 4
const CARD_FRAME := 2      # the card's thick border, inside a 1 px ink line
const LOGO_BAND := 46      # the top section: the logo (TeamLogo LARGE, 40) on the school's colours
const LOCKED_FILL := Color("081548")              # a locked card: a shade darker than NAVY
const LOCKED_EDGE := Color(1.0, 1.0, 1.0, 0.55)   # ...and its white border, softer
const LOCKED_SHADE := Color(0.62, 0.64, 0.74)     # ...and the whole card faded
const PICK_FILL := Color("1d3f9e")                # your pick's card, a little brighter than NAVY

var cards := {}            # school id -> its card in the grid
var list: VBoxContainer    # the group headers and their grids, in `schools` order
var list_scroll: ScrollContainer
var list_at := -1          # the grid's scroll, kept while you name your coach (-1: not placed yet)
var next_button: Button
var glory: Progression
var groups: Array = []     # Progression.picker_groups, read once when the screen opens
## The division filter over the cards: 0 ALL SCHOOLS, else Colleges.D1..D3.
static var start_filter := 0   # (what the screen opens on: the Road to Glory's tests look at Division I alone)
var div_filter := start_filter
## ACTIVE DIVISIONS for this dynasty: a pack you own starts on; yours is on whatever this says.
var div_off := {}
const FILTERS := [[0, "ALL SCHOOLS"], [1, "DIVISION I"], [2, "DIVISION II"], [3, "DIVISION III"]]

func _step_school() -> void:
	title_label.text = "PICK YOUR SCHOOL"
	var n_open := schools.filter(func(s): return glory.is_unlocked(s.short)).size()
	var sub := para("Start as an underdog. Win in your career to unlock stronger programs: %d of %d open." % [n_open, schools.size()], UI.TEXT, 300)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _offer_shown(n_open):
		# UNLOCK ALL TEAMS beside the line, only while it's for sale to you; once owned the row is
		# just the line again, as if it had never been there
		var row := UI.hbox(6)
		row.name = "OfferRow"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(sub)
		var b := UI.button("UNLOCK ALL TEAMS  %s" % Store.price(Store.TEAMS_ID), _offer_unlock, "primary", 0, 16)
		b.name = "UnlockAllTeams"
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		body.add_child(row)
	else:
		body.add_child(sub)
	# NEXT sits up by the title, so the cards get the whole page under it
	next_button = UI.button("NEXT  >", _next, "primary", 0, 20)
	next_button.name = "Next"
	_gold_button(next_button)
	next_button.add_theme_font_size_override("font_size", 16)
	next_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_right.add_child(next_button)
	_update_next()
	if Colleges.lower_divisions:   # (Division I alone: no filter to choose with)
		var filters := UI.hbox(2)
		filters.name = "DivisionFilters"
		filters.alignment = BoxContainer.ALIGNMENT_CENTER
		for f in FILTERS:
			var d: int = f[0]
			var fb := UI.button(String(f[1]), func():
				div_filter = d
				list_at = 0
				_render(), "tab_on" if div_filter == d else "tab", 0, 14)
			fb.name = "Filter%d" % d
			filters.add_child(fb)
		body.add_child(filters)
	list = UI.vbox(CARD_GAP)
	list_scroll = UI.scroll(list)
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(list_scroll)
	cards.clear()
	var cols := columns()
	for g in groups.filter(_in_filter):
		list.add_child(_group_header(g))
		var grid := GridContainer.new()
		grid.name = "Grid%d" % int(g.tier)
		grid.columns = cols
		grid.add_theme_constant_override("h_separation", CARD_GAP)
		grid.add_theme_constant_override("v_separation", CARD_GAP)
		list.add_child(grid)
		for id in g.ids:
			var card := _school_card(Colleges.school(id))
			cards[id] = card
			grid.add_child(card)
	list.add_child(UI.spacer(0, 1))   # (the last row's bottom border clear of the page's edge)
	_place_list.call_deferred()

## Is this group's division the one the filter shows?
func _in_filter(g: Dictionary) -> bool:
	return div_filter == 0 or int(g.get("div", Colleges.D1)) == div_filter

## Cards to a row: as many CARD_MIN_W cards as the page is wide (4 at the game's 480), never
## fewer than MIN_COLS.
func columns() -> int:
	var w := get_viewport_rect().size.x - 8.0 - safe_insets().x - safe_insets().z - 6.0   # (the page's margins, the scroll bar)
	return maxi(MIN_COLS, int((w + CARD_GAP) / (CARD_MIN_W + CARD_GAP)))

## The schools in the order their cards are shown (the groups, top to bottom, each row left to right).
func card_order() -> Array:
	var out: Array = []
	if not is_instance_valid(list):
		return out
	for grid in list.get_children():
		if grid is GridContainer:
			for card in grid.get_children():
				out.append(cards.find_key(card))
	return out

## The grid's first scroll: where it was (back from YOUR COACH), else the top: AVAILABLE TEAMS.
func _place_list() -> void:
	await get_tree().process_frame
	if not is_instance_valid(list_scroll):
		return
	var bar := list_scroll.get_v_scroll_bar()
	var to := maxi(0, list_at)
	list_scroll.scroll_vertical = clampi(to, 0, maxi(0, int(bar.max_value - bar.page)))

## NEXT goes on only with an unlocked school picked.
func _update_next() -> void:
	if is_instance_valid(next_button):
		next_button.disabled = not (pick != "" and glory.is_unlocked(pick))
		next_button.modulate = Color.WHITE if not next_button.disabled else Color(1, 1, 1, 0.45)

func _next() -> void:
	if pick == "" or not glory.is_unlocked(pick):
		return
	step = 1
	_render()

# ------------------------------------------------------------------ ALL 30 TEAMS (Store)
## The picker's groups and their schools, from the profile and what the store says you own.
func _regroup() -> void:
	groups = glory.picker_groups(preview.teams)
	schools = []
	for g in groups:
		schools.append_array(g.ids.map(func(id): return Colleges.school(id)))
	# (`schools` stays the Road to Glory's thirty; the expansion's come after, a group a conference)
	for cf in Colleges.EXPANSION_CONFERENCES:
		var d := int(cf.div)
		if not Colleges.division_enabled(d):
			continue   # (hibernated: not even a locked group)
		var ids: Array = Colleges.schools_in(String(cf.id)).map(func(s): return String(s.short))
		ids.sort_custom(func(a, b): return (preview.teams[a] as PoloTeam).team_overall(false) > (preview.teams[b] as PoloTeam).team_overall(false))
		var owned := Store.division_owned(d)
		var head := "%s  -  %s" % [Colleges.division_name(d), String(cf.abbr)]
		groups.append({"tier": 10 + groups.size(), "div": d, "open": owned, "ids": ids,
			"title": head if owned else "LOCKED — %s EXPANSION PACK  -  %s" % [Colleges.division_name(d), String(cf.abbr)]})

## The offer's shown only while you don't own it and a school is still locked to you.
func _offer_shown(n_open: int) -> bool:
	return not Store.owns(Store.TEAMS_ID) and n_open < schools.size()

## UNLOCK ALL TEAMS: what it is and what it costs (the store's own price), PURCHASE or CANCEL.
## Nothing opens until the store has verified the purchase (StorePrompt.buy_then).
func _offer_unlock() -> void:
	if Store.owns(Store.TEAMS_ID):
		return   # (owned already: never a second checkout)
	var price := Store.price(Store.TEAMS_ID)
	Game.dialog("UNLOCK ALL 30 TEAMS!", "Get immediate access to every program in Road to Glory.\n\nONE-TIME PURCHASE  -  %s\n\nYou can still unlock every team for free by earning the Road to Glory achievements." % price, [
		["PURCHASE  %s" % price, func(): StorePrompt.buy_then(Store.TEAMS_ID, _on_store_changed), "primary"],
		["CANCEL", Callable(), "ghost"]])

## The store changed (a purchase, a restore, a refund): the groups again, and the page redrawn
## (the offer gone once it's owned). Your pick stays yours while it's still open.
func _on_store_changed() -> void:
	if not is_inside_tree() or step != 0:
		return
	_regroup()
	if pick != "" and not glory.is_unlocked(pick):
		pick = String(groups[0].ids[0]) if not groups[0].ids.is_empty() else ""
	if is_instance_valid(list_scroll):
		list_at = list_scroll.scroll_vertical
	_render()

## A tap on a card: an unlocked school becomes your pick (its card yellow, the last one's back to
## plain); a locked one stays locked and says what opens it. Only the two cards that change are
## redrawn, so the grid keeps its scroll.
func _pick(sid: String) -> void:
	if not glory.is_unlocked(sid):
		Sfx.play("back")
		var why := String(glory.requirement(sid).get("req", "")).to_upper()
		var prog := _progress_text(String(glory.requirement(sid).get("id", "")))
		Game.toast("LOCKED: %s%s" % [why, ("  " + prog) if prog != "" else ""], UI.GOLD)
		return
	Sfx.play("click")
	var was := pick
	pick = sid
	for id in [was, sid]:
		var card: Control = cards.get(id)
		if card != null and is_instance_valid(card):
			card.queue_redraw()
			for ch in card.find_children("*", "", true, false):
				(ch as CanvasItem).queue_redraw()
			_tint_card(card, id)
	_update_next()

## How far you are toward a locked school ("" when there's nothing real to show): this season's
## wins for Tier 2, when there's a career to count them in.
func _progress_text(id: String) -> String:
	if id != "five_wins":
		return ""
	var w := glory.season_wins_now(Game.career, func(n): return Game.slot_exists(n))
	return "" if w < 0 else "(%d/%d)" % [mini(w, Progression.SEASON_WINS), Progression.SEASON_WINS]

## Above each group's cards, one small line: AVAILABLE TEAMS, or LOCKED — what opens them, with
## the lock.
func _group_header(g: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.name = "Header%d" % int(g.tier)
	p.add_theme_stylebox_override("panel", UI.sb(Deck.NAVY_HEAD, Color.TRANSPARENT, 0, 3, 1))
	var h := UI.hbox(4)
	p.add_child(h)
	var open := int(g.tier) == 0 or bool(g.get("open", false))
	if not open:
		h.add_child(_lock_icon(UI.DIM))
	var name_l := UI.label(String(g.title), 8, UI.GOOD if open else UI.ACCENT, "caps")
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	h.add_child(name_l)
	h.add_child(UI.label(str(g.ids.size()), 8, UI.DIM, "caps"))
	for ch in h.get_children():
		ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p

func _lock_icon(col: Color) -> Control:
	var tr := TextureRect.new()
	tr.texture = Deck.icon_texture("lock", col)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.custom_minimum_size = Vector2(7, 8)
	return tr

## A rating on the picker's cards, in stars: the number / 20 to the nearest half (40 is two,
## 70 three and a half, 99 five). Only how the card shows it; the rating itself is untouched.
static func card_stars(rating: float) -> float:
	return PoloTeam.rating_stars(rating)

## One school's card, a retro trading card: a thick frame, the logo big on the school's colours,
## its place and mascot, its conference, then OFF and DEF in stars. Yellow frame and a brighter
## card when it's your pick; a locked school's card faded, with a lock in its corner.
func _school_card(s: Dictionary) -> Button:
	var sid: String = s.short
	var open := glory.is_unlocked(sid)
	var t: PoloTeam = preview.teams[sid]
	var b := Button.new()
	b.name = "Card_" + sid
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, CARD_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_contents = true
	var none := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, none)
	b.pressed.connect(func(): _pick(sid))
	b.mouse_entered.connect(func(): b.queue_redraw())
	b.mouse_exited.connect(func(): b.queue_redraw())
	b.draw.connect(func(): _draw_card(b, s))
	var v := UI.vbox(0)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = CARD_FRAME + 1
	v.offset_right = -CARD_FRAME - 1
	v.offset_top = CARD_FRAME + 1
	v.offset_bottom = -CARD_FRAME - 1
	b.add_child(v)
	# TOP: the logo, big and centred, on the school's colours
	var top := Control.new()
	top.custom_minimum_size = Vector2(0, LOGO_BAND)
	v.add_child(top)
	var mid := CenterContainer.new()
	mid.set_anchors_preset(Control.PRESET_FULL_RECT)
	top.add_child(mid)
	mid.add_child(_card_logo(s))
	# the team's OVR in the corner, as on a player card
	var badge := PanelContainer.new()
	badge.name = "Ovr"
	badge.add_theme_stylebox_override("panel", UI.sb(UI.INK, UI.GOLD, 1, 2, 0))
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# (flush in the corner: a wide logo's 60 px file just clears it)
	var bv := UI.vbox(-3)
	badge.add_child(bv)
	var tag := UI.label("OVR", 8, UI.DIM, "caps")
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(tag)
	var num := UI.label(str(t.overall_display()), 16, UI.GOLD, "big")
	num.name = "OvrNum"
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(num)
	top.add_child(badge)
	# your pick says so: a gold SELECTED tab on the line under the logo
	var tab := PanelContainer.new()
	tab.name = "Selected"
	tab.add_theme_stylebox_override("panel", UI.sb(UI.GOLD, UI.INK, 1, 3, 0))
	var tl := UI.label("SELECTED", 8, UI.INK, "caps")
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab.add_child(tl)
	tab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var low := UI.vbox(0)
	low.alignment = BoxContainer.ALIGNMENT_END
	low.set_anchors_preset(Control.PRESET_FULL_RECT)
	low.offset_bottom = 2   # (sitting on the school's colour rule)
	low.add_child(tab)
	top.add_child(low)
	if not open:
		var lock := _lock_icon(UI.GOLD)
		lock.name = "Lock"
		lock.position = Vector2(3, 3)
		top.add_child(lock)
	# MIDDLE: the place, the mascot, the conference
	v.add_child(UI.spacer(0, 3))
	for line in [[Colleges.place(sid).to_upper(), UI.TEXT, "Place"], [String(s.mascot).to_upper(), UI.GOLD, "Mascot"],
			[Colleges.conf_abbr(s.conf), UI.DIM, "Conf"]]:
		var l := UI.label(String(line[0]), 8, line[1], "caps" if line[2] == "Conf" else "body")
		l.name = String(line[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(l)
	v.add_child(UI.spacer(0, 0, true))
	v.add_child(UI.spacer(0, 3))
	# BOTTOM: OFF and DEF in stars
	for r in [["OFF", t.offense_display()], ["DEF", t.defense_display()]]:
		v.add_child(_star_row(String(r[0]), card_stars(float(r[1]))))
	v.add_child(UI.spacer(0, 3))
	_ignore_mouse(v)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.sort_children.connect(b.queue_redraw)   # (the ratings' well is drawn where its rows land)
	_tint_card(b, sid)
	return b

## The card's logo: the biggest of its artwork files that fits the top section between the corner
## stripes and the OVR badge, at 1:1 (a wide logo like San Jose's gets its 60 px file); a school
## with no artwork, its template at 2x.
const LOGO_FIT := Vector2i(64, LOGO_BAND - 4)

func _card_logo(s: Dictionary) -> Control:
	var tex := TeamLogo.art_within(s, LOGO_FIT)
	if tex == null:
		var w := TeamLogo.widget(s, TeamLogo.LARGE)
		w.name = "Logo"
		return w
	var tr := TextureRect.new()
	tr.name = "Logo"
	tr.texture = tex
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.custom_minimum_size = Vector2(tex.get_width(), tex.get_height())
	return tr

## "OFF ★★★★☆": the tag, then the five-place star bar (half stars too), centred on the card.
func _star_row(tag: String, stars: float) -> Control:
	var h := UI.hbox(4)
	h.name = "Stars" + tag
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.set_meta("stars", stars)
	var l := UI.label(tag, 8, UI.DIM, "caps")
	l.custom_minimum_size.x = 16
	h.add_child(l)
	var bar := UI.canvas(int(Deck.star_bar_w()), 9, func(ci):
		Deck.star_bar(ci, 0, 0, stars, float(Deck.STAR_PLACES)))
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	return h

## Is this school's card the yellow one (your pick, and open to you)?
func card_on(sid: String) -> bool:
	return pick == sid and glory.is_unlocked(sid)

## A locked school's card is the same card, faded; only your pick shows its SELECTED tab.
func _tint_card(b: Control, sid: String) -> void:
	b.modulate = Color.WHITE if glory.is_unlocked(sid) else LOCKED_SHADE
	var tab: Control = b.find_child("Selected", true, false)
	tab.add_theme_stylebox_override("panel", UI.sb(UI.GOLD, UI.INK, 1, 4, 0))
	if tab != null:
		tab.visible = card_on(sid)

## The card itself: an ink line, the thick frame (yellow on your pick), the top section in the
## school's colours with a stripe of each, the rest navy (brighter on your pick).
func _draw_card(b: Button, s: Dictionary) -> void:
	var sid: String = s.short
	var open := glory.is_unlocked(sid)
	var on := card_on(sid)
	var r := Rect2(Vector2.ZERO, b.size)
	var edge := UI.GOLD if on else (UI.BORDER_HI if open else LOCKED_EDGE)
	if not on and open and b.is_hovered():
		edge = UI.BORDER
	b.draw_rect(r, UI.INK)
	b.draw_rect(r.grow(-1), edge)
	var inner := r.grow(-1 - CARD_FRAME)
	if on:
		b.draw_rect(inner, UI.GOLD, false, 1.0)   # (a third ring of gold: the pick stands out)
		inner = inner.grow(-1)
	var fill := PICK_FILL if on else (Deck.NAVY if open else LOCKED_FILL)
	b.draw_rect(inner, fill)
	# the top section: the school's first colour, deep, so every logo stands off it...
	var c1 := Color(s.c1)
	var c2 := Color(s.c2)
	var band := Rect2(inner.position, Vector2(inner.size.x, LOGO_BAND))
	b.draw_rect(band, c1.darkened(0.55).lerp(fill, 0.35))
	# ...two stripes of it down the corners, and the second colour as a rule underneath
	for i in 2:
		var x0 := inner.position.x + 4 + i * 5
		b.draw_rect(Rect2(x0, band.position.y, 3, band.size.y), c1.darkened(0.2))
		var x1 := inner.end.x - 7 - i * 5
		b.draw_rect(Rect2(x1, band.position.y, 3, band.size.y), c1.darkened(0.2))
	b.draw_rect(Rect2(band.position.x, band.end.y - 2, band.size.x, 2), c2)
	b.draw_rect(Rect2(band.position.x, band.end.y, band.size.x, 1), UI.INK)
	# the ratings' well at the bottom
	var row: Control = b.find_child("StarsOFF", true, false)
	var well_y := inner.end.y - 25.0
	if row != null:
		well_y = (row.get_parent() as Control).position.y + row.position.y - 2.0
	b.draw_rect(Rect2(inner.position.x, well_y, inner.size.x, inner.end.y - well_y), UI.INK.lerp(fill, 0.45))

## Both steps share a big, outlined title.
func _title_style() -> void:
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.set_meta("title_max", 30)   # (BaseScreen._fit_title: its own size, unless it can't fit)
	_title_key = ""
	title_label.add_theme_color_override("font_outline_color", UI.INK)
	title_label.add_theme_constant_override("outline_size", 3)

## The big gold call-to-action: jersey lettering, ink border, the usual drop shadow.
func _gold_button(b: Button) -> void:
	b.add_theme_font_override("font", UI.font_big)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", UI.chunky(UI.GOLD, UI.INK))
	b.add_theme_stylebox_override("hover", UI.chunky(Color("ffe27a"), UI.INK))
	b.add_theme_stylebox_override("pressed", UI.chunky(Color("e0b52a"), UI.INK, false, true))
	b.add_theme_stylebox_override("hover_pressed", UI.chunky(Color("e0b52a"), UI.INK, false, true))

# ------------------------------------------------------------------ step 2: the coach
const FORM_LABEL_W := 62
const FIELD_W := 190
const MODE_W := 56

func _step_coach() -> void:
	title_label.text = "YOUR COACH"
	var s: Dictionary = Colleges.school(pick)
	var sub := para("%s is hiring. What's your name, Coach?" % String(s.name), UI.TEXT, 300)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(sub)
	# the form floats in the middle of the page: equal give above and below it
	body.add_child(UI.spacer(0, 4, true))
	var form := UI.vbox(5)
	var center := CenterContainer.new()
	center.add_child(form)
	body.add_child(center)
	for f in [["FIRST NAME", first, func(t): first = t], ["LAST NAME", last, func(t): last = t]]:
		var le := LineEdit.new()
		le.text = f[1]
		le.max_length = 12
		le.custom_minimum_size = Vector2(FIELD_W, 22)
		le.add_theme_font_size_override("font_size", 16)
		le.add_theme_stylebox_override("normal", UI.sb(Deck.NAVY, UI.BORDER_HI, 1, 5, 3))
		le.add_theme_stylebox_override("focus", UI.sb(Deck.NAVY, UI.GOLD, 1, 5, 3))
		le.text_changed.connect(f[2])
		form.add_child(_form_row(f[0], le))
	var modes := UI.hbox(4)
	for m in Difficulty.MODES:
		var mm: String = m
		var on := Difficulty.mode() == mm
		var b := UI.button(Difficulty.NAMES[mm], func():
			Game.settings.difficulty = mm
			Game.save_settings()
			_render(), "normal", MODE_W, 18)
		b.add_theme_font_override("font", UI.font_caps)
		var fill := UI.GOLD if on else Deck.NAVY
		var edge := UI.INK if on else UI.BORDER_HI
		b.add_theme_stylebox_override("normal", UI.chunky(fill, edge))
		b.add_theme_stylebox_override("hover", UI.chunky(UI.GOLD if on else Deck.ROW_HOVER, edge))
		b.add_theme_stylebox_override("pressed", UI.chunky(Color("e0b52a") if on else Deck.ROW_A, edge, false, true))
		b.add_theme_stylebox_override("hover_pressed", UI.chunky(Color("e0b52a") if on else Deck.ROW_A, edge, false, true))
		var fc := UI.INK if on else UI.DIM
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(k, fc)
		modes.add_child(b)
	form.add_child(UI.spacer(0, 2))
	form.add_child(_form_row("DIFFICULTY", modes))
	if Colleges.lower_divisions:   # (Division I alone: nothing to choose)
		form.add_child(UI.spacer(0, 2))
		form.add_child(_form_row("ACTIVE DIVISIONS", _division_row()))
	var desc := para("DYNAMIC: starts at MEDIUM and follows how your last few games went." if Difficulty.mode() == "dynamic" else "You can change this any time in Settings.", UI.TEXT, 300)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(UI.spacer(0, 2))
	body.add_child(desc)
	body.add_child(UI.spacer(0, 10))
	var start := UI.button("START CAREER  >", _start, "primary", 150, 24)
	_gold_button(start)
	var bc := CenterContainer.new()
	bc.add_child(start)
	body.add_child(bc)
	body.add_child(UI.spacer(0, 4, true))

## SELECT ACTIVE DIVISIONS: Division I is the base game; a pack you own switches on or off for this
## dynasty (yours can't be off); one you don't own shows locked and can't be pressed.
func _division_row() -> Control:
	var row := UI.hbox(4)
	row.name = "ActiveDivisions"
	var base := UI.button("I  BASE GAME", Callable(), "normal", 0, 18)
	base.name = "Div1"
	base.disabled = true
	row.add_child(base)
	for d in [Colleges.D2, Colleges.D3]:
		var dv: int = d
		var owned := Store.division_owned(dv)
		var mine := Colleges.division_of(pick) == dv
		var on: bool = owned and (mine or not div_off.get(dv, false))
		var text: String = "LOCKED" if not owned else ("ENABLED" if on else "DISABLED")
		var b := UI.button("%s  %s" % [["", "I", "II", "III"][dv], text], func():
			div_off[dv] = not div_off.get(dv, false)
			_render(), "primary" if on else "normal", 0, 18)
		b.name = "Div%d" % dv
		b.disabled = not owned or mine
		row.add_child(b)
	return row

## The divisions this dynasty will play.
func active_divisions() -> Array:
	var out: Array = [Colleges.D1]
	for d in [Colleges.D2, Colleges.D3]:
		if Colleges.division_enabled(d) and Store.division_owned(d) and (Colleges.division_of(pick) == d or not div_off.get(d, false)):
			out.append(d)
	return out

## A form line: the caps label in a fixed column, then the control.
func _form_row(text: String, control: Control) -> Control:
	var row := UI.hbox(8)
	var l := UI.label(text, 8, UI.DIM, "caps")
	l.custom_minimum_size.x = FORM_LABEL_W
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	row.add_child(l)
	row.add_child(control)
	return row

func _start() -> void:
	var f := first.strip_edges()
	var l := last.strip_edges()
	if f == "" or l == "":
		Game.toast("Your coach needs a first and last name", UI.WARN)
		return
	# (Game.start_career checks the school again: a locked one is refused and nothing is touched)
	if not Game.start_career(pick, _cap(f), _cap(l), -1, active_divisions()):
		Game.toast("That school is locked", UI.WARN)
		step = 0
		_render()
		return
	Game.history.clear()
	Game.goto("drill", {"career": true}, false)   # the tutorial first: it hands on to the hub

static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)
