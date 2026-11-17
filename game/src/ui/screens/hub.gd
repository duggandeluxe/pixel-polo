extends BaseScreen
## The season home screen: settings and the chips up top, the conference table beside the
## team card, the next five weeks on a timeline, then back / roster / training / coaching /
## PLAY (which opens the matchup preview). Tap the conference table for the standings and
## playoffs, the timeline for the whole season schedule, the team card for the DYNASTY HUB
## (program, league news, records, recruiting, ...).
## Shows anything queued for the coach (welcome, goals, the season review, cards,
## job offers) one dialog at a time.

const TOP_BAR_H := 22    # the top bar's one height (Settings, TOP 20, AWARDS, coins, season): the gear's
const SPAN := 5         # games (or weeks without one) on the timeline

var busy := false   # a game or a week is already on its way (screen changes fade): ignore more taps
## DEV Mode's SEASON OVER preview (elim_lab): the eliminated hub drawn for the loaded career
## whatever its state, read only (nothing is simmed or saved; back goes to the lab).
var preview := false

func _init() -> void:
	detail = true   # (its team logos: TeamLogo's fine pixels)

func setup(params: Dictionary) -> void:
	preview = bool(params.get("elim_preview", false)) and bool(Game.settings.get("dev_mode", false))

## The SEASON OVER hub (Championship Elimination): knocked out, the league still playing.
func _eliminated() -> bool:
	return preview or c.is_eliminated()

func _ready() -> void:
	c = Game.career
	if c == null:
		Game.goto("title")
		return
	if preview:
		build(c.team().name.to_upper(), false, true)
		title_label.get_parent().visible = false
		_render()
		Sfx.music("menu")
		return
	if not c.pending_event.is_empty():
		Game.goto("coach_event", {}, false)   # a coaching event still to answer (a reload): it comes first
		return
	if not CoachEvents.popups(c).is_empty():
		Game.goto("coach_event", {}, false)   # a challenge result not yet seen (the app closed on it): once
		return
	# out of this tournament with nothing left to play in it: the rest of the postseason is simmed at
	# once, to your next game (the NCSA) or through to the off-season (Career.advance_postseason)
	if c.advance_postseason():
		Game.save_career()
	if c.elim_pending():
		Game.goto("season_over", {}, false)   # just knocked out: OH NO! YOUR SEASON IS OVER (once)
		return
	if c.fell_short_pending():
		Game.goto("fell_short", {}, false)   # out of the conference tournament, into the NCSA (once)
		return
	if c.champ_pending():
		Game.goto("champions", {}, false)   # just won the NCSA: CHAMPIONS! (once)
		return
	build(c.team().name.to_upper(), false, true)
	# the home screen draws its own top row (gear, chips), so the stock header goes
	title_label.get_parent().visible = false
	_render()
	Sfx.music("menu")
	Sfx.crowd(0.0)
	await get_tree().process_frame
	if not _process_queue() and not _open_cuts() and not Game.open_upgrades():
		_deadline_warning()
	# the first-ever career's guided tour (once, for good; it waits for any dialog above to close)
	if is_inside_tree() and Game.current_screen == self and not Game.is_changing_screen():
		CareerTour.maybe_start()
		# the first HOT star of this dynasty: its tutorial (once a save; it waits for dialogs too)
		if CareerTour.current() == null:
			HotTutorial.maybe_start()

func on_back() -> void:
	_back()

func _render() -> void:
	body.add_child(_top_bar())
	var top := UI.hbox(6)
	body.add_child(top)
	top.add_child(_tappable(_standings(), func(): Game.goto("conference"), "Full standings and playoffs"))
	top.add_child(_hub_door())
	# spare height splits evenly above and below the schedule
	body.add_child(UI.spacer(0, 2, true))
	var sched := PanelContainer.new()
	sched.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var sv := UI.vbox(3)
	sched.add_child(sv)
	if c.in_offseason():
		sv.add_child(_sched_head("THE OFF-SEASON", "", true, true))   # no badge: the top bar says SEASON OVER
		if c.phase == "cuts":
			sv.add_child(_cuts_banner())
			body.add_child(_tappable(sched, func(): Game.goto("roster_cuts"), "Make your roster cuts"))
		else:
			sv.add_child(_done_banner())
			body.add_child(_tappable(sched, func(): Game.goto("recruiting"), "Your recruits for next season"))
	elif _eliminated():
		sv.add_child(_sched_head("SEASON OVER", "FINAL RECORD  %s  (%s CONF)" % [c.record_text(), c.conf_record_text()], true))
		sv.add_child(_elim_banner())
		sched.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(sched)   # (not one big button: its own buttons inside)
	else:
		sv.add_child(_sched_head("SEASON SCHEDULE", _progress_text(), true))
		sv.add_child(_timeline())
		body.add_child(_tappable(sched, func(): Game.goto("schedule"), "The whole season schedule"))
	body.add_child(UI.spacer(0, 2, true))
	body.add_child(_nav())

# ------------------------------------------------------------------ top bar
func _top_bar() -> Control:
	var h := UI.hbox(5)
	var gear := Deck.icon_button("gear", func(): Game.goto("settings"), 26, 22, "normal", 2)
	gear.tooltip_text = "Settings"
	_light(gear)
	h.add_child(gear)
	# the National Top 20, with where you are in it
	var rank := Poll.rank_in(Poll.latest(c), c.school)
	var top := Deck.button("TOP 20  #%d" % rank if rank > 0 and rank <= Poll.TOP else "TOP 20", func(): Game.goto("top20"), "normal", 0, 22)
	top.tooltip_text = "The National Top 20 poll"
	_light(top)
	h.add_child(top)
	var aw := Deck.button("AWARDS", func(): Game.goto("awards"), "normal", 0, 22)
	aw.name = "Awards"
	aw.tooltip_text = "Conference awards: player, rookie, offensive and defensive player of the week"
	_light(aw)
	h.add_child(aw)
	h.add_child(UI.spacer(0, 0, true))
	if Store.pro:
		h.add_child(_polo_plus())
	h.add_child(credits_chip())
	h.add_child(SeasonBox.new(c.season_years() + ",", c.week_text()))
	# one height for the whole row: the Settings button's, border and all. Every button and chip
	# gets it, and fills it, so their tops and bottoms line up; chip text is centred in it.
	var bar_h := maxf(TOP_BAR_H, gear.get_combined_minimum_size().y)
	for ch in h.get_children():
		ch.size_flags_vertical = Control.SIZE_FILL
		ch.custom_minimum_size.y = bar_h
		for l in ch.find_children("*", "Label", true, false):
			(l as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return h

# ------------------------------------------------------------------ top bar: POLO +
## PIXEL POLO +'s membership badge (shown once it's owned): a raised gold rim over an ink line and
## a neon-green inner ring (the shop's ACTIVE green), a deep navy plate, a little gold crown, POLO
## in white and a big outlined gold plus. A glint sweeps across it now and then and the corner
## sparkle twinkles (not with REDUCE MOTION). Hover lights it up; pressed sinks into its shadow.
## Tap: the Polo Points Shop (its PIXEL POLO + card).
const PP_GOLD_HI := Color("fff2a8")
const PP_GOLD_LO := Color("b8860b")
const PP_NEON := Color("7fe35f")       # UI.GOOD
const PP_NEON_HI := Color("c8ff9e")
const PP_FILL := Color("0a1650")
const PP_FILL_LO := Color("071040")
const PP_GLOSS := Color("1d3a9a")
const PP_CYCLE := 4200                 # ms between glints
const PP_SWEEP := 700                  # ms a glint takes to cross
const PP_CROWN := ["h..h..h", "#..#..#", "##.#.##", "#######", "#g#g#g#", "#######"]
const PP_PLUS := ["..hh..", "..h#..", "hh##hh", "######", "..##..", "..##.."]   # a bold 2 px plus, lit top-left

func _polo_plus() -> Button:
	var tw := ceilf(Deck.text_w("POLO"))
	var w := 31 + int(tw)   # 6 (rim + pad) + crown 7 + 3 + POLO + 3 + plus 6 + 6
	var b := Deck.card(Vector2(w, TOP_BAR_H), func(ci, r, mode): _paint_polo_plus(ci, r, mode, tw), func(): Game.goto("store"))
	b.name = "PoloPlus"
	b.tooltip_text = "PIXEL POLO + is active. Tap for the Polo Points Shop."
	if Juice.enabled():
		var tick := Timer.new()
		tick.wait_time = 0.05
		tick.autostart = true
		tick.timeout.connect(b.queue_redraw)
		b.add_child(tick)
	return b

func _paint_polo_plus(ci: CanvasItem, r0: Rect2, mode: String, tw: float) -> void:
	var down := mode == "down"
	var hover := mode == "hover"
	var r := Rect2(r0.position.floor() + (Vector2(1, 2) if down else Vector2.ZERO), r0.size.floor())
	if not down:
		Deck.frame(ci, Rect2(r.position + Vector2(1, 2), r.size), UI.SHADOW, UI.SHADOW)
	# the gold rim: lit on top, shaded underneath (the other way round pressed in)
	var gold := UI.GOLD.lightened(0.2) if hover else UI.GOLD
	Deck.frame(ci, r, PP_FILL, gold)
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), PP_GOLD_LO if down else PP_GOLD_HI)
	ci.draw_rect(Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 2, 1), gold if down else PP_GOLD_LO)
	# an ink line, then the neon ring
	_pp_ring(ci, r.grow(-1), UI.INK)
	var neon := PP_NEON.darkened(0.25) if down else (PP_NEON_HI if hover else PP_NEON)
	_pp_ring(ci, r.grow(-2), neon)
	ci.draw_rect(Rect2(r.position.x + 3, r.position.y + 2, r.size.x - 6, 1), neon.lightened(0.35) if not down else neon)
	# the plate: two hard bands, a gloss line on top (an ink one pressed in)
	var inner := r.grow(-3)
	var lift := 0.12 if hover else (-0.15 if down else 0.0)
	var hi_band := PP_FILL.lightened(lift) if lift >= 0.0 else PP_FILL.darkened(-lift)
	var lo_band := PP_FILL_LO.lightened(lift) if lift >= 0.0 else PP_FILL_LO.darkened(-lift)
	ci.draw_rect(inner, hi_band)
	ci.draw_rect(Rect2(inner.position.x, inner.end.y - 6, inner.size.x, 6), lo_band)
	ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1)), UI.INK if down else PP_GLOSS.lightened(lift if lift > 0.0 else 0.0))
	var t := Time.get_ticks_msec() % PP_CYCLE if Juice.enabled() else -1
	if t >= 0 and t < PP_SWEEP and not down:
		_pp_glint(ci, inner, float(t) / PP_SWEEP)
	# crown, POLO, the plus
	var mid := r.position.y + floorf(r.size.y * 0.5)
	var x := r.position.x + 6
	var ink := Color(UI.INK, 0.9)
	Deck.pat(ci, Vector2(x + 1, mid - 2), PP_CROWN, {"#": ink, "h": ink, "g": ink})
	Deck.pat(ci, Vector2(x, mid - 3), PP_CROWN, {"#": gold, "h": PP_GOLD_HI, "g": neon})
	x += 10
	Deck.text(ci, x + 1, mid + 1, "POLO", 8, ink)
	Deck.text(ci, x, mid, "POLO", 8, PP_GOLD_HI if hover else UI.TEXT)
	x += tw + 3
	Deck.pat(ci, Vector2(x + 1, mid - 2), PP_PLUS, {"#": ink, "h": ink})
	var plus := gold.darkened(0.15) if down else gold
	Deck.pat(ci, Vector2(x, mid - 3), PP_PLUS, {"#": plus, "h": Color.WHITE if hover else PP_GOLD_HI})
	# the sparkle on the top-right corner of the rim
	if not down:
		var big := t >= PP_SWEEP and t < PP_SWEEP + 500
		var sp := Vector2(r.end.x - 4, r.position.y)
		var arm := 2 if big or hover else 1
		var col := Color.WHITE
		ci.draw_rect(Rect2(sp.x - arm, sp.y, arm * 2 + 1, 1), col)
		ci.draw_rect(Rect2(sp.x, sp.y - arm, 1, arm * 2 + 1), col)

## A 1 px square ring just inside `r`.
func _pp_ring(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), col)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), col)
	ci.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), col)
	ci.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), col)

## A leaning 2 px band of light across the plate, `p` (0..1) of the way over, row by row.
func _pp_glint(ci: CanvasItem, inner: Rect2, p: float) -> void:
	var span := inner.size.x + inner.size.y
	var x0 := inner.position.x - inner.size.y * 0.5 - 2 + floorf(p * span)
	for y in range(int(inner.size.y)):
		var bx := floorf(x0 + (inner.size.y - y) * 0.5)
		var a := maxf(bx, inner.position.x)
		var e := minf(bx + 2, inner.end.x)
		if e > a:
			ci.draw_rect(Rect2(a, inner.position.y + y, e - a, 1), Color(1, 1, 1, 0.16))

## Lets a whole panel be tapped, without changing how it looks.
func _tappable(panel: Control, cb: Callable, tip: String) -> Control:
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	panel.add_child(b)
	return panel

# ------------------------------------------------------------------ top left: the conference
## Your conference, four rows: the top four, or the top three and you when you're lower down.
## Your row gets a gold outline.
func _standings() -> Control:
	var t := c.team()
	var p := UI.panel(Deck.NAVY, UI.BORDER)
	var v := UI.vbox(0)
	p.add_child(v)
	var head := UI.hbox(4)
	v.add_child(head)
	var conf := UI.label(c.conf_abbr(), 20, UI.TEXT, "big")
	conf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conf.clip_text = true
	conf.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(conf)
	var rl := UI.label("RECORD", 8, UI.ACCENT, "caps")
	rl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(rl)
	v.add_child(_hline(UI.ACCENT))
	v.add_child(UI.spacer(0, 1))
	var order := Schedule.conf_table(c.teams, c.table, t.conf)
	var rows: Array = range(mini(4, order.size()))
	var mine := order.find(c.school)
	if mine >= 4:
		rows = [0, 1, 2, mine]
	for i in rows:
		var id: String = order[i]
		var r: Dictionary = c.table[id]
		v.add_child(_table_row(i + 1, Colleges.display_name((c.teams[id] as PoloTeam).name).to_upper(), "%d-%d" % [r.cw, r.cl], id == c.school))
	return p

func _table_row(rank: int, name: String, rec: String, me: bool) -> Control:
	var p := PanelContainer.new()
	# every row gets the same padding, so the outlined row's text lines up with the rest
	var st := UI.sb(Deck.NAVY, UI.GOLD if me else Color.TRANSPARENT, 2 if me else 0, 6, 3)
	p.add_theme_stylebox_override("panel", st)
	var h := UI.hbox(6)
	p.add_child(h)
	h.add_child(fixed_label(str(rank), 10, UI.TEXT))
	var nl := UI.label(name, 8, UI.TEXT)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(nl)
	var rl := fixed_label(rec, 24, UI.TEXT)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(rl)
	return p

func _hline(col: Color) -> Control:
	var d := UI.canvas(0, 1, func(ci): ci.draw_rect(Rect2(0, 0, ci.size.x, 1), col))
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return d

# ------------------------------------------------------------------ top right: the Dynasty Hub's door
## The team card is the way into the DYNASTY HUB (more.gd), two ways: one big button over the card,
## border and all, and the DYNASTY HUB tab hanging from its bottom-right corner. The tab is the
## card's own border carried on down: it shares the card's bottom edge (one line, never two), its
## right side runs straight on from the card's, and it's the nav buttons' blue with their white
## edge, raised bevel and dark-blue shadow, DYNASTY HUB and an arrow in white. Both show a pointer.
## Hovering either lights both (a lighter plate, a lighter blue tab); a press sinks both into the
## page (1 px right, 2 down, like every chunky button) and keeps them down while the hub opens.
## Nothing moves on its own. The tab sits in the blue gap under the card, over nothing else.
## The player's first-ever dynasty also gets the first-time hint beside the tab, until the hub is
## first opened (Career.hub_seen); no later dynasty ever shows it (settings.hub_hint_uid).
const HUB_LABEL := "DYNASTY HUB"
const HUB_TIP := "Your Dynasty Hub: program, news, records and more"
const HUB_HINT := "CLICK HERE TO VIEW YOUR DYNASTY HUB!"
const HUB_ARROW := ["....#..", "....##.", "#######", "....##.", "....#.."]   # a white arrow, 7 x 5
const HUB_TAB_W := 88       # (264 x 33 at 1440 x 810)
const HUB_TAB_H := 12       # rows from the card's bottom edge (shared) to the tab's own bottom edge
const HUB_FILL := {"normal": Color("0b1d5c"), "hover": Color("15297a"), "down": Color("081648")}   # Deck.NAVY, lit, sunk
const HUB_TAB_FILL := {"normal": Color("3b7bff"), "hover": Color("4f8bff"), "down": Color("1f52c9")}   # the nav buttons' (_light)

var hub_card: PanelContainer
var hub_mode := "normal"
var hub_parts: Array = []   # what repaints with the card's face (its waves, the tab)
var hub_buttons: Array = []

func _hub_door() -> Control:
	var wrap := PanelContainer.new()
	wrap.name = "HubDoor"
	wrap.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub_card = _team_card()
	hub_card.name = "TeamCard"
	wrap.add_child(hub_card)
	var b := _hub_button("HubEntry")
	wrap.add_child(b)
	b.add_child(_hub_tab())
	if _hub_hint_due():
		_hub_hint(b)
	return wrap

## The hint belongs to the first dynasty it ever shows in (claimed globally, for good).
func _hub_hint_due() -> bool:
	if c.hub_seen or _quiet():
		return false
	var owner := String(Game.settings.get("hub_hint_uid", ""))
	if owner == "":
		Game.settings.hub_hint_uid = c.uid
		if not Game.test_mode:
			Game.save_settings()
		return true
	return owner == c.uid

## An invisible button for the door (the card's face and the tab do the drawing).
func _hub_button(nm: String) -> Button:
	var b := Button.new()
	b.name = nm
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = HUB_TIP
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	# the face follows the buttons (hover, press, and TouchScroll cancelling a press on a drag)
	b.draw.connect(func(): _hub_sync.call_deferred())
	b.mouse_exited.connect(func(): _hub_sync.call_deferred())
	b.pressed.connect(_open_hub)
	hub_buttons.append(b)
	return b

## The face from both buttons: down if either is pressed, lit if either is hovered.
func _hub_sync() -> void:
	if busy:
		return
	var mode := "normal"
	for b in hub_buttons:
		if not is_instance_valid(b):
			continue
		match (b as Button).get_draw_mode():
			BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED:
				mode = "down"
			BaseButton.DRAW_HOVER:
				if mode == "normal":
					mode = "hover"
	_hub_face(mode)

## The card's look: "normal" (UI.panel's), "hover" or "down"; the tab repaints to match.
func _hub_face(mode: String) -> void:
	if hub_card == null or not is_instance_valid(hub_card) or mode == hub_mode:
		return
	hub_mode = mode
	var down := mode == "down"
	hub_card.add_theme_stylebox_override("panel", UI.chunky(HUB_FILL[mode], UI.BORDER, false, down, 4, 3, UI.BEVEL_SUNK if down else UI.BEVEL_SOFT))
	for n in hub_parts:
		if is_instance_valid(n):
			(n as CanvasItem).queue_redraw()

func _open_hub() -> void:
	if busy:
		return
	busy = true
	Sfx.play("click")
	_hub_face("down")   # it stays pressed in while the screen fades to the hub
	var hint := find_child("HubHint", true, false)
	if hint != null:
		hint.visible = false
	if not c.hub_seen:
		c.hub_seen = true
		Game.save_career()
	Game.goto("more")

## The DYNASTY HUB tab: a button of its own, its right edge on the card's, its top row the card's
## bottom edge. Painted: the shadow (1 right, 2 down), the blue face with its raised bevel, the
## white sides and bottom (cut corners), the shared top line, then the label and arrow on a hard
## 1 px shadow. Pressed: no shadow, the whole tab 1 right and 2 down, as the card goes.
func _hub_tab() -> Button:
	var t := _hub_button("HubTab")
	var w := float(HUB_TAB_W)
	var h := float(HUB_TAB_H)
	t.anchor_left = 1.0
	t.anchor_right = 1.0
	t.anchor_top = 1.0
	t.anchor_bottom = 1.0
	t.offset_right = 0.0
	t.offset_left = -w
	t.offset_top = -1.0       # on the card's bottom edge
	t.offset_bottom = h - 1.0
	var face := UI.canvas(0, 0, func(ci):
		var down := hub_mode == "down"
		var o := Vector2(1, 2) if down else Vector2.ZERO
		var fill: Color = HUB_TAB_FILL.get(hub_mode, HUB_TAB_FILL.normal)
		if not down:
			ci.draw_rect(Rect2(1, 2, w, h - 1), UI.SHADOW)
			ci.draw_rect(Rect2(w, 1, 1, 1), UI.SHADOW)
		ci.draw_rect(Rect2(o + Vector2(1, 1), Vector2(w - 2, h - 2)), fill)
		# the bevel ring as on a full box whose top row is the card's edge
		Deck.bevel_ring(ci, Rect2(o, Vector2(w, h)), fill, UI.BEVEL_SUNK if down else UI.BEVEL_RAISED)
		ci.draw_rect(Rect2(o, Vector2(w, 1)), UI.BORDER)                     # the card's bottom edge, carried on
		ci.draw_rect(Rect2(o + Vector2(0, 1), Vector2(1, h - 2)), UI.BORDER)
		ci.draw_rect(Rect2(o + Vector2(w - 1, 1), Vector2(1, h - 2)), UI.BORDER)
		ci.draw_rect(Rect2(o + Vector2(1, h - 1), Vector2(w - 2, 1)), UI.BORDER)
		var tw := ceilf(Deck.text_w(HUB_LABEL))
		var x := floorf(o.x + (w - tw - 4.0 - 7.0) * 0.5)
		var mid := o.y + floorf(h * 0.5)
		Deck.shadow_text(ci, x, mid, HUB_LABEL, 8, UI.TEXT)
		var ax := Vector2(x + tw + 4.0, mid - 2.0)
		Deck.pat(ci, ax + Vector2.ONE, HUB_ARROW, {"#": Deck.ICON_SHADOW})
		Deck.pat(ci, ax, HUB_ARROW, {"#": UI.TEXT}))
	face.name = "HubTabFace"
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.add_child(face)
	hub_parts.append(face)
	return t

## CLICK HERE TO VIEW YOUR DYNASTY HUB!: a small gold callout just left of the tab, its notch
## pointing right at it. One stepped pop-in when it appears (not with REDUCE MOTION), then still.
## It passes every input through.
func _hub_hint(b: Control) -> void:
	var tw := ceilf(Deck.text_w(HUB_HINT)) + 8.0
	var bh := 11.0
	var hint := UI.canvas(int(tw) + 5, int(bh), func(ci):
		ci.draw_rect(Rect2(1, 0, tw - 2, bh), UI.INK)
		ci.draw_rect(Rect2(0, 1, tw, bh - 2), UI.INK)
		ci.draw_rect(Rect2(1, 1, tw - 2, bh - 2), UI.GOLD)
		ci.draw_rect(Rect2(1, bh - 2, tw - 2, 1), Deck.NOTICE_SHADE)
		# the notch: opens through the right edge and narrows to one pixel
		var cy := floorf(bh * 0.5)
		for i in 5:
			var half := 4 - i
			ci.draw_rect(Rect2(tw - 1 + i, cy - half, 1, half * 2 + 1), UI.INK)
			if half >= 1:
				ci.draw_rect(Rect2(tw - 1 + i, cy - half + 1, 1, half * 2 - 1), UI.GOLD)
		Deck.ctext(ci, Rect2(0, 0, tw, bh - 1), HUB_HINT, 8, UI.INK))
	hint.name = "HubHint"
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	# beside the tab, level with its face
	hint.offset_right = -HUB_TAB_W - 2.0
	hint.offset_left = hint.offset_right - tw - 5.0
	hint.offset_top = floorf((HUB_TAB_H - bh) * 0.5)
	hint.offset_bottom = hint.offset_top + bh
	b.add_child(hint)
	if Juice.enabled():
		hint.pivot_offset = Vector2(tw + 4.0, floorf(bh * 0.5))
		hint.scale = Vector2(0.4, 0.4)
		var t := hint.create_tween()
		for s in [0.7, 1.12, 1.0]:
			t.tween_interval(0.05)
			t.tween_callback(func(): hint.scale = Vector2(s, s))

# ------------------------------------------------------------------ top right: the team
## Big logo on the left; name, WATER POLO, record and rating on the right; a faint pixel
## wave along the bottom.
func _team_card() -> Control:
	var t := c.team()
	var p := UI.panel(Deck.NAVY, UI.BORDER)
	var waves := UI.canvas(0, 0, _draw_waves)
	hub_parts.append(waves)
	p.add_child(waves)
	var h := UI.hbox(8)
	p.add_child(h)
	var logo := TeamLogo.widget(t, TeamLogo.LARGE, 3)
	logo.name = "TeamLogo"
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(logo)
	var v := UI.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(UI.team_title(Colleges.display_name(t.name).to_upper(), t.mascot, 150))
	var wp := UI.label("W A T E R   P O L O", 8, UI.ACCENT, "caps")
	wp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(wp)
	v.add_child(UI.spacer(0, 3))
	var stats := UI.hbox(0)
	v.add_child(stats)
	stats.add_child(_stat("RECORD", c.record_text()))
	var d := UI.canvas(1, 0, func(ci): ci.draw_rect(Rect2(0, 0, 1, ci.size.y), UI.ACCENT))
	stats.add_child(d)
	stats.add_child(_stat("RATING", str(t.overall_display())))
	return p

func _stat(label: String, value: String) -> Control:
	var v := UI.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := UI.label(label, 8, UI.ACCENT, "caps")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var n := UI.label(value, 20, UI.TEXT, "big")
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	return v

## Two rows of stepped pixel waves, a shade off the panel colour.
func _draw_waves(ci: Control) -> void:
	var w := floorf(ci.size.x)
	var y := floorf(ci.size.y) - 3.0
	var col: Color = HUB_FILL.get(hub_mode, Deck.NAVY).lightened(0.07)
	var x := 2.0
	while x < w - 2.0:
		var phase := int(x / 4.0) % 4
		var dy: float = [0.0, -1.0, -2.0, -1.0][phase]
		ci.draw_rect(Rect2(x, y + dy - 3.0, 4, 1), col)
		ci.draw_rect(Rect2(x, y + dy - 2.0, 4, 3.0 - dy), col.darkened(0.02))
		x += 4.0

# ------------------------------------------------------------------ the timeline
## The timeline's entries: one per game of yours (up to three a week), one for a week without
## one. {w: week index, g: the game or {}}.
func _entries() -> Array:
	var out: Array = []
	for i in c.schedule.size():
		var mine := c.my_games(c.schedule[i])
		if mine.is_empty():
			out.append({"w": i, "g": {}})
		for g in mine:
			out.append({"w": i, "g": g})
	return out

## Where the timeline starts: your last result, then your next game (or this week) and what's
## after it; at the season's ends, the first or last five.
func _first_entry(entries: Array) -> int:
	var now := entries.size() - 1
	for k in entries.size():
		var e: Dictionary = entries[k]
		if e.w > c.week or (e.w == c.week and (e.g.is_empty() or e.g.r == null)):
			now = k
			break
	return clampi(now - 1, 0, maxi(0, entries.size() - SPAN))

## What the timeline shows for an entry: a node on the season path.
## state: next / win / loss / upcoming / tbd (playoff not drawn yet) / bye / out
## head: the strip on top (GAME 7, or the playoff round); mark: a milestone tag on its right
## (CONF, or a final's TITLE); opp: the other team (its logo); big: the result, or where it's
## played; name: the opponent along the bottom.
func _week(e: Dictionary) -> Dictionary:
	var i: int = e.w
	var r: Dictionary = c.schedule[i]
	var d := {"name": "", "head": "", "mark": "", "big": "", "state": "upcoming", "opp": null, "final": false}
	var g: Dictionary = e.g
	var playoff := Schedule.is_playoff(r)
	var round := String(Schedule.SHORT_NAMES.get(String(r.kind), String(r.name)))
	d.final = String(r.kind) in ["conf_final", "nat_final"]
	if not Schedule.drawn(r):
		d.merge({"name": String(r.name).capitalize().replace("Conference", "Conf").replace("Ncsa", "NCSA"), "head": round, "big": "TBD", "state": "tbd"}, true)
	elif g.is_empty():
		var bye := not playoff or c.bye_week(i)
		d.merge({"name": "", "head": round if playoff else "WEEK %d" % (i + 1), "big": "BYE" if bye else "OUT", "state": "bye" if bye else "out"}, true)
	else:
		var home: bool = g.h == c.school
		var opp: PoloTeam = c.teams[g.a if home else g.h]
		d.opp = opp
		d.name = Colleges.display_name(opp.name).to_upper()
		d["short"] = String(Colleges.school(opp.id).get("mascot", d.name)).to_upper()
		var n := Schedule.game_no(c.schedule, c.school, g)
		d.head = round if playoff else ("GAME %d" % n if n > 0 else String(r.name))
		if not playoff and Schedule.is_conf_game(r, g):
			d.mark = "CONF"
		elif d.final:
			d.mark = "TITLE"
		d.big = "NEUTRAL" if Schedule.is_neutral(g) else ("HOME" if home else "AWAY")
		if g.r != null:
			var won := Schedule.winner(g) == c.school
			d.big = ("W " if won else "L ") + Schedule.score_text(g, home)
			d.state = "win" if won else "loss"
		elif i == c.week and g == c.my_game():
			d.state = "next"
	return d

## The season so far, beside the heading: 07 / 16 in the regular season (counted from your
## schedule), the round and your record in the playoffs.
func _progress_text() -> String:
	var total := Schedule.team_games(c.schedule, c.school).size()
	if c.week < c.schedule.size() and Schedule.is_playoff(c.schedule[c.week]):
		return "%s  -  %s" % [c.calendar_text(), c.record_text()]
	return "%02d / %d" % [mini(Schedule.games_played(c.schedule, c.school) + 1, total), total]

## The heading row: SEASON SCHEDULE (or THE OFF-SEASON) and where you are. inline puts the count
## as a small badge right beside the heading; otherwise it sits at the far right.
func _sched_head(title: String, right: String, inline := false, center := false) -> Control:
	var h := UI.hbox(6)
	if center:
		h.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := UI.label(title, 20, UI.TEXT, "big")
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not inline:
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	if right == "":
		return h
	var p := PanelContainer.new()
	p.name = "SeasonProgress"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UI.sb(Deck.NAVY, UI.BORDER_HI, 1, 4, 1))
	if inline:
		# an inset: a dark pixel line under the top border, and a 1 px hard shadow beneath
		p.draw.connect(func():
			p.draw_rect(Rect2(1, 1, p.size.x - 2, 1), UI.SHADOW)
			p.draw_rect(Rect2(1, p.size.y, p.size.x, 1), UI.SHADOW))
	var pl := UI.label(right, 8, UI.GOLD, "caps")
	p.add_child(pl)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(p)
	return h

func _timeline() -> Control:
	var entries := _entries()
	var first := _first_entry(entries)
	var weeks: Array = []
	for k in range(first, mini(first + SPAN, entries.size())):
		weeks.append(_week(entries[k]))
	var more := [first > 0, first + SPAN < entries.size()]
	var tl := UI.canvas(0, TL_H, func(ci): _draw_timeline(ci, weeks, more))
	tl.name = "SeasonPath"
	tl.set_meta("weeks", weeks)
	return tl

## The season's over: next season's roster as it stands (NEXT SEASON starts it).
## A light navy wash: SEASON COMPLETE on the left; GRADUATING | SIGNED | NEXT ROSTER on the right
## (orange when over the cap), split by cyan rules like RECORD | RATING.
func _done_banner() -> Control:
	var over := Recruiting.over_by(c)
	# a light wash of navy over the pool blue, not a solid card: the section reads open, not full
	var p := UI.panel(Color(Deck.NAVY, 0.28), UI.BORDER_HI)
	p.name = "SeasonComplete"
	p.custom_minimum_size = Vector2(0, TL_H)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UI.hbox(0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	# left: the headline
	var left := UI.vbox(3)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.3
	h.add_child(left)
	var head := UI.label("SEASON COMPLETE", 16, UI.GOLD, "big")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(head)
	h.add_child(_done_rule())
	# right: the numbers
	var cells := [["GRADUATING", str(Recruiting.graduating(c).size())], ["SIGNED", str(c.incoming.size())],
		["NEXT ROSTER", "%d/%d" % [Recruiting.projected(c), c.roster_max()]]]
	for i in cells.size():
		if i > 0:
			h.add_child(_done_rule())
		var cell := _stat(String(cells[i][0]), String(cells[i][1])) as VBoxContainer
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(cell)
		if i == cells.size() - 1:
			cell.name = "ProjectedRoster"
			if over > 0:
				(cell.get_child(1) as Label).add_theme_color_override("font_color", UI.WARN)
	return p

## A 1 px cyan rule between the banner's sections, inset top and bottom.
func _done_rule() -> Control:
	var d := UI.canvas(1, 0, func(ci): ci.draw_rect(Rect2(0, 4, 1, ci.size.y - 8), UI.ACCENT))
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d

## SEASON OVER (Championship Elimination): knocked out, the rest of the league still playing. Where
## it ended, what's left of the NCSA (results already played only), and the way to the bracket,
## the season so far and the schedule.
func _elim_banner() -> Control:
	var e: Dictionary = c.elim
	var row := UI.hbox(6)
	row.name = "SeasonOver"
	row.custom_minimum_size = Vector2(0, TL_H)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UI.chunky(Color("101a4a"), Color("b04a5a"), false, false, 6, 3, UI.BEVEL_SOFT))
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(plate)
	var v := UI.vbox(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	plate.add_child(v)
	var line1 := UI.label("YOUR TEAM HAS BEEN ELIMINATED FROM CHAMPIONSHIP CONTENTION.", 8, UI.TEXT, "caps")
	line1.clip_text = true
	v.add_child(line1)
	var how := String(e.get("round", "OUT OF THE NCSA CHAMPIONSHIP"))
	if e.has("opp") and c.teams.has(String(e.opp)):
		how += "  -  %s %d-%d VS %s" % ["W" if bool(e.get("won", false)) else "L", int(e.us), int(e.them),
			Colleges.display_name((c.teams[String(e.opp)] as PoloTeam).name).to_upper()]
	var line2 := UI.label("ELIMINATED: " + how if not how.begins_with("NOT SELECTED") else how, 8, UI.BAD, "caps")
	line2.clip_text = true
	line2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(line2)
	var rem := c.remaining_championship()
	var left := "NCSA CHAMPIONSHIP IN PROGRESS"
	if String(rem.champion) != "" and c.teams.has(String(rem.champion)):
		left = "NCSA CHAMPIONS: %s" % (c.teams[String(rem.champion)] as PoloTeam).name.to_upper()
	elif String(rem.round) != "":
		left = "%s:  %d TEAMS STILL COMPETING" % [String(rem.round), (rem.alive as Array).size()]
	var line3 := UI.label(left, 8, UI.GOLD, "caps")
	line3.name = "Remaining"
	line3.clip_text = true
	v.add_child(line3)
	var btns := UI.vbox(2)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(btns)
	for it in [["VIEW BRACKET", "ViewBracket", func(): Game.goto("conference", {"tab": "PLAYOFFS", "fam": "nat"})],
			["SEASON REVIEW", "SeasonReview", func(): Game.goto("recap", {"live": true, "preview": preview})],
			["SCHEDULE", "Schedule", func(): Game.goto("schedule")]]:
		var b := Deck.button(String(it[0]), it[2], "normal", 92, 16)
		b.name = String(it[1])
		_light(b)
		btns.add_child(b)
	return row

## After the season, over the cap: how many must go before next season can start.
func _cuts_banner() -> Control:
	var v := UI.vbox(2)
	v.custom_minimum_size = Vector2(0, TL_H)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := UI.label("ROSTER CUTS REQUIRED", 16, UI.WARN, "big")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var line := UI.label("CURRENT ROSTER: %d / %d    PLAYERS TO CUT: %d" % [c.team().roster.size(), c.roster_max(), Offseason.cuts_needed(c)], 8, UI.TEXT, "caps")
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(line)
	return v

const TL_H := 58          # the path's height: the NEXT GAME tab, then the nodes
const NODE_GAP := 10      # between two nodes: the path runs through it
const NODE_Y := 7         # a node's top (the tab sits on its edge)
const NODE_H := 49
const HEAD_H := 11        # a node's top strip

## The season path: a node per game, joined by the path (solid where it's been played, gold into
## the next game, dotted ahead), arrows off either end when there are more games that way.
func _draw_timeline(ci: Control, weeks: Array, more: Array) -> void:
	var w := floorf(ci.size.x)
	var col_w := w / SPAN
	var mid := NODE_Y + HEAD_H + (NODE_H - HEAD_H) * 0.5
	var nodes: Array = []
	for i in weeks.size():
		var x0 := floorf(col_w * i + NODE_GAP * 0.5)
		nodes.append(Rect2(x0, NODE_Y, floorf(col_w * (i + 1) - NODE_GAP * 0.5) - x0, NODE_H))
	# the path: before the first node, between nodes, after the last
	var played := func(d: Dictionary) -> bool: return String(d.state) in ["win", "loss", "bye", "out"]
	for i in range(-1, weeks.size()):
		var from := 0.0 if i < 0 else (nodes[i] as Rect2).end.x
		var to := w if i == weeks.size() - 1 else (nodes[i + 1] as Rect2).position.x if i + 1 < nodes.size() else w
		if i < 0 and not more[0]:
			continue
		if i == weeks.size() - 1 and not more[1]:
			continue
		var done_before: bool = i < 0 or played.call(weeks[i])
		var into: Dictionary = weeks[i + 1] if i + 1 < weeks.size() else {}
		if done_before and (into.is_empty() or played.call(into)):
			ci.draw_rect(Rect2(from, mid - 1, to - from, 3), UI.TEXT)
		elif done_before and String(into.get("state", "")) == "next":
			ci.draw_rect(Rect2(from, mid - 1, to - from, 3), UI.GOLD)
		elif i >= 0 and i + 1 < weeks.size():
			# still to come (between two cards only: the end arrows mark the edges): one bright 2 x 2 cyan dot, centred in the gap (always NODE_GAP wide) and
			# on the whole card's middle
			var card_mid := floorf(NODE_Y + NODE_H * 0.5)
			ci.draw_rect(Rect2(floorf((from + to) * 0.5) - 1, card_mid - 1, 2, 2), Color("a6f0ff"))
	# the end arrows: centred on the whole card, like the dots between cards
	var arrow_y := floorf(NODE_Y + NODE_H * 0.5)
	if more[0]:
		_arrow(ci, Vector2(1, arrow_y), -1)
	if more[1]:
		_arrow(ci, Vector2(w - 2, arrow_y), 1)
	for i in weeks.size():
		_draw_node(ci, nodes[i], weeks[i])

## A chunky pixel arrowhead with its tip at `at`, pointing `dir` (-1 left, 1 right): more games that
## way. Cyan inside a 1 px ink outline (it reads over the path and the panel alike), 5 x 7.
const PATH_ARROW := ["...oo", "..o#o", ".o##o", "o###o", ".o##o", "..o#o", "...oo"]

func _arrow(ci: Control, at: Vector2, dir: int) -> void:
	var cols := {"o": UI.INK, "#": UI.ACCENT}
	for y in PATH_ARROW.size():
		var row: String = PATH_ARROW[y]
		for x in row.length():
			if cols.has(row[x]):
				# drawn for a left arrow with its tip 1 px out from `at`; mirrored for a right one
				var px := at.x - 1 + x if dir < 0 else at.x + 1 - x
				ci.draw_rect(Rect2(px, at.y - 3 + y, 1, 1), cols[row[x]])

## One game on the path. Completed: a green (win) or red (loss) edge and its score; the next
## game: a yellow frame, a brighter tile and the NEXT GAME tab; still to come: plain navy.
func _draw_node(ci: Control, r: Rect2, d: Dictionary) -> void:
	var state: String = d.state
	var muted := state in ["bye", "out", "tbd"]
	var edge: Color = {"win": UI.GOOD, "loss": UI.BAD, "next": UI.GOLD}.get(state, UI.BORDER_HI if not muted else UI.DIM2)
	var fill := Deck.NAVY_HEAD if state == "next" else (Deck.NAVY if not muted else Color("0a1a50"))
	ci.draw_rect(r, UI.INK)
	ci.draw_rect(r.grow(-1), edge)
	var inner := r.grow(-2)
	if state == "next":
		inner = r.grow(-3)   # (a two-pixel yellow frame)
	ci.draw_rect(inner, fill)
	# the top strip: GAME 7 or the round, and a milestone tag
	var head := Rect2(inner.position, Vector2(inner.size.x, HEAD_H))
	var head_fill := Color("e0b52a") if d.final else UI.INK.lerp(fill, 0.35)
	ci.draw_rect(head, head_fill)
	var head_col := UI.INK if d.final else (UI.GOLD if state == "next" else UI.DIM)
	var mark: String = d.mark
	var mark_w := 0.0
	if mark != "" and not d.final:
		mark_w = Deck.text_w(mark) + 4.0
		var mr := Rect2(head.end.x - mark_w - 1, head.position.y + 1, mark_w, HEAD_H - 2)
		ci.draw_rect(mr, UI.ACCENT.darkened(0.45))
		Deck.ctext(ci, mr, mark, 8, UI.ACCENT)
	Deck.text(ci, head.position.x + 3, head.position.y + HEAD_H * 0.5, Deck.fit(String(d.head), head.size.x - mark_w - 6), 8, head_col, "caps")
	# a result's colour down the left edge
	if state in ["win", "loss"]:
		ci.draw_rect(Rect2(inner.position.x, head.end.y, 2, inner.end.y - head.end.y), edge)
	# the logo (crisp, 1:1) and the result or where it's played
	var body_y := head.end.y + 2
	var big_x := inner.position.x + 5
	if d.opp != null:
		TeamLogo.paint(ci, Vector2(inner.position.x + 5, body_y), d.opp, TeamLogo.MEDIUM)
		big_x += TeamLogo.box(TeamLogo.MEDIUM).x + 3
	var big_col: Color = {"win": UI.GOOD, "loss": UI.BAD, "next": UI.GOLD}.get(state, UI.DIM2 if muted else UI.DIM)
	var big_r := Rect2(big_x, body_y, inner.end.x - big_x - 2, TeamLogo.box(TeamLogo.MEDIUM).y)
	if d.opp == null:
		Deck.ctext(ci, big_r, Deck.fit(String(d.big), big_r.size.x, 8, "caps"), 8, big_col, "caps")
	else:
		Deck.text(ci, big_r.position.x, big_r.position.y + big_r.size.y * 0.5, Deck.fit(String(d.big), big_r.size.x, 8, "body"), 8, big_col, "body")
	# the opponent along the bottom
	if String(d.name) != "":
		var nr := Rect2(inner.position.x + 2, inner.end.y - 11, inner.size.x - 4, 10)
		# (the whole name when it fits, else the mascot: the logo beside it says which)
		var nm := String(d.name) if Deck.text_w(String(d.name), 8, "body") <= nr.size.x else String(d.get("short", d.name))
		Deck.ctext(ci, nr, Deck.fit(nm, nr.size.x, 8, "body"), 8, UI.DIM2 if muted else UI.TEXT, "body")
	# the next game's tab, on its top edge
	if state == "next":
		var tab := String(d.get("tab", "NEXT GAME"))
		var tw := Deck.text_w(tab) + 8.0
		var tr := Rect2(floorf(r.get_center().x - tw * 0.5), 0, tw, 10)
		ci.draw_rect(tr, UI.INK)
		ci.draw_rect(tr.grow(-1), UI.GOLD)
		Deck.ctext(ci, tr, tab, 8, UI.INK)

# ------------------------------------------------------------------ bottom row
func _nav() -> Control:
	var h := UI.hbox(5)
	var back := Deck.icon_button("left", _back, 34, 22, "normal", 2)
	_light(back)
	back.tooltip_text = "Title screen (your career is saved)"
	h.add_child(back)
	var hurt := c.team().roster.filter(func(p: PoloPlayer): return p.is_injured()).size()
	var ups := c.team().roster.filter(func(p: PoloPlayer): return p.tokens > 0).size()
	# COACHING is the gameplan and recruiting screen (facilities and staff are under MORE / Training)
	# after the season there's no practice to plan: the roster cuts take its place
	var middle: Array = ["TRAINING", "training"]
	if c.in_offseason():
		middle = ["CUTS", "roster_cuts"] if c.phase == "cuts" else ["RECRUIT", "recruiting"]
	var injury_notice: Control = null
	# knocked out (SEASON OVER): no more games to coach for, so RECRUITING (the market, directly)
	# takes COACHING's place until the next season starts
	var last: Array = ["RECRUITING", "recruiting"] if _eliminated() else ["COACHING", "coaching"]
	for it in [["ROSTER", "roster"], middle, last]:
		var scr: String = it[1]
		var b := Deck.button(it[0], func(): _open_nav(scr), "normal", 0, 22)
		b.name = "Nav_" + scr
		_light(b)
		b.add_theme_font_override("font", UI.font_big)
		b.add_theme_font_size_override("font_size", 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
		if scr == "roster":
			Deck.nav_status_badges(b, ups > 0, hurt > 0)
		if scr == "training" and hurt > 0 and _injury_notice_due() and not _eliminated() and not _quiet():
			# INJURY ACTIVE: ADJUST PRACTICE? while anyone's hurt: a reminder that opens Training,
			# nothing more (no practice to plan after the season, so no TRAINING and no banner).
			# Answered for the week once Training is opened or RECOVERY is the focus.
			injury_notice = Deck.nav_injury_notice(b, func(): _open_nav("training"))
		if (scr == "coaching" or (scr == "recruiting" and _eliminated())) and c.new_recruits and not _quiet():
			# NEW RECRUITS AVAILABLE: until Recruiting is opened (Recruiting.seen_new)
			Deck.nav_recruits_notice(b, not c.recruits_popped)
			c.recruits_popped = true
			if injury_notice != null:
				# both up: the wide injury banner slides left to clear this one, re-checked on resize
				var rec: Control = b.get_node("RecruitsNotice")
				var apart := Deck.nav_notices_apart.bind(injury_notice, rec)
				h.resized.connect(apart, CONNECT_DEFERRED)
				apart.call_deferred()
	h.add_child(_play_button())
	return h

## A nav button's screen; opening Training answers this week's injury banner.
func _open_nav(scr: String) -> void:
	if scr == "training":
		c.injury_seen = _week_key()
	if scr == "recruiting" and _eliminated():
		Game.goto("recruiting", {"tab": "MARKET"})   # (the market itself: no OPEN RECRUITING on the way)
		return
	Game.goto(scr)

## DISABLE COACHING REMINDERS (Settings): no injury, new recruits or Dynasty Hub callouts.
func _quiet() -> bool:
	return bool(Game.settings.get("no_reminders", false))

func _week_key() -> String:
	return "%d:%d" % [c.year, c.week]

## The injury banner shows until Training is opened this week or RECOVERY is the focus;
## a new week with someone still hurt brings it back.
func _injury_notice_due() -> bool:
	return c.injury_seen != _week_key() and String(c.training.get("focus", "balanced")) != "recovery"

## Medium blue with a white edge, a step lighter than the page.
func _light(b: Button) -> void:
	b.add_theme_stylebox_override("normal", UI.chunky(UI.BG_HI, UI.BORDER))
	b.add_theme_stylebox_override("hover", UI.chunky(Color("4f8bff"), UI.BORDER))
	b.add_theme_stylebox_override("pressed", UI.chunky(UI.BG2, UI.BORDER, false, true))
	b.add_theme_stylebox_override("hover_pressed", UI.chunky(UI.BG2, UI.BORDER, false, true))

## PLAY opens the matchup preview; with no game this week it moves the season on instead.
func _play_button() -> Button:
	var label := "PLAY"
	var cb := _open_matchup
	if c.game_over:
		label = "TITLE"
		cb = _back
	elif c.phase == "cuts":
		label = "ROSTER CUTS"
		cb = func(): Game.goto("roster_cuts")
	elif c.in_offseason():
		label = "NEXT SEASON"
		cb = _next_season
	elif _eliminated():
		label = "SIM TO OFFSEASON  >"
		cb = _sim_offseason
	elif c.game_done_this_week():
		label = "NEXT WEEK"
		cb = _sim_week
	elif not c.has_game():
		label = "SIM WEEK"
		cb = _sim_week
	var b := Deck.button(label, cb, "primary", 0, 22)
	b.name = "PlayButton"
	b.add_theme_font_override("font", UI.font_big)
	b.add_theme_font_size_override("font_size", 16 if label.length() > 12 else 20)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

## SIM TO OFFSEASON: asked first (you may still be recruiting), then every week left at once, the
## league's games only, and on into the off-season (Career.sim_to_offseason: once, ever).
func _sim_offseason() -> void:
	if busy or (not preview and _process_queue()):
		return
	var go := func():
		if busy:
			return
		if preview:
			Game.toast("DEV PREVIEW: NOTHING WAS SIMULATED")
			Game.goto("elim_lab", {}, false)
			return
		busy = true
		c.sim_to_offseason()
		Game.save_career()
		Game.goto("hub", {}, false)
	Game.dialog("READY FOR THE OFFSEASON?", "Your season is complete. Simulate the remaining championship games and advance to the offseason?", [
		["CANCEL", Callable(), "ghost"],
		["SIM TO OFFSEASON  >", go, "primary"]])

# ------------------------------------------------------------------ actions
func _open_matchup() -> void:
	if busy or _process_queue():
		return
	Game.goto("matchup")

func _back() -> void:
	if preview:
		Sfx.play("back")
		Game.goto("elim_lab", {}, false)
		return
	Game.save_career()
	Sfx.play("back")
	Game.goto("title")

func _sim_week() -> void:
	if busy or _eliminated() or _process_queue() or c.game_over or Game.open_upgrades():
		return
	busy = true
	c.sim_week_without_me()
	c.end_week()
	Game.save_career()
	Game.goto("hub", {}, false)

## RECRUITING DEADLINE APPROACHING! (the Roster Needs & Recruiting Deadline update): once a
## season (Career.recruit_warned), when your own games are over (recruiting closes with NEXT
## SEASON) and something's unresolved (Recruiting.deadline: a pinned prospect unsigned, a starting
## place nobody can fill next season, cuts to come). Informational: nothing is signed, paid or
## unpinned. Skipped when every signing slot is used (nothing left to recruit). True if it showed.
func _deadline_warning() -> bool:
	if c.game_over or c.phase == "cuts" or c.recruit_warned == c.season_label():
		return false
	if not (c.in_offseason() or c.next_game().is_empty()):
		return false
	var d := Recruiting.deadline(c)
	# nothing left to do in recruiting once the class is full (every signing slot used)
	if not bool(d.issues) or int(d.slots) <= 0:
		return false
	c.recruit_warned = c.season_label()
	Game.save_career()
	Game.dialog("RECRUITING DEADLINE APPROACHING!", "Your season is over, and recruiting closes when you start next season. Review your recruits and next season's roster before then.\n\n" + Recruiting.deadline_text(d), [
		["REVIEW RECRUITS", func(): Game.goto("recruiting", {"tab": "MARKET"}), "primary"],
		["LATER", Callable(), "ghost"]])
	return true

## NEXT SEASON: says what happens (seniors leave, your signings join, cuts if it's over the cap),
## then runs the roster transition (Career.end_week). That transition closes recruiting: with
## anything unresolved (Recruiting.deadline) the FINAL RECRUITING WARNING comes first, RETURN TO
## RECRUITING (nothing changed) or CONTINUE TO OFFSEASON (the transition, as ever).
func _next_season() -> void:
	if busy or _process_queue() or c.game_over or Game.open_upgrades():
		return
	var go := func():
		if busy:
			return
		busy = true
		c.end_week()
		Game.save_career()
		Game.goto("hub", {}, false)
	var d := Recruiting.deadline(c)
	if bool(d.issues):
		Game.dialog("FINAL RECRUITING WARNING", "You are about to close the recruiting period.\n\n" + Recruiting.deadline_text(d) +
			"\n\nUnsigned recruits from this class will no longer be available after the recruiting period ends. Your %d signed recruit%s join as freshmen." % [
			c.incoming.size(), "" if c.incoming.size() == 1 else "s"], [
			["RETURN TO RECRUITING", func(): Game.goto("recruiting", {"tab": "MARKET"}), "primary"],
			["CONTINUE TO OFFSEASON", go, "ghost"]])
		return
	var over := Recruiting.over_by(c)
	var text := "Your %d senior%s graduate%s and your %d signed recruit%s join as freshmen. Projected roster: %d / %d." % [
		Recruiting.graduating(c).size(), "" if Recruiting.graduating(c).size() == 1 else "s", "s" if Recruiting.graduating(c).size() == 1 else "",
		c.incoming.size(), "" if c.incoming.size() == 1 else "s", Recruiting.projected(c), c.roster_max()]
	if over > 0:
		text += "\n\nYou will need to cut %d player%s before the season starts." % [over, "" if over == 1 else "s"]
	Game.dialog("START %s?" % c.next_season_label(), text, [
		["CONTINUE", go, "primary"],
		["NOT YET", Callable(), "ghost"]])

## After the season, over the cap: the cuts come before anything else (once the queue is done).
## True if they were opened.
func _open_cuts() -> bool:
	if c.phase != "cuts" or c.game_over:
		return false
	Game.goto("roster_cuts", {}, false)
	return true

# ------------------------------------------------------------------ the queue
## Shows the item at the front of the queue. It's only removed once the coach has dealt
## with it, so closing the app on a dialog (a job offer) shows it again next
## time. True if something was shown (the caller should wait).
func _process_queue() -> bool:
	if c.queue.is_empty():
		return false
	var q: Dictionary = c.queue[0]
	match String(q.type):
		"info":
			Game.dialog(q.title, q.text, [["OK", _next_item, "primary"]])
		"season":
			Game.dialog("%s SEASON" % c.season_label(), "A new season begins.\n\nNEW SEASON BONUS: %s" % CreditCoin.tag(int(q.get("bonus", 0)), true), [["LET'S GO", _next_item, "primary"]], "reward")
		"recap":
			Game.goto(String(q.get("screen", "recap")), q)   # the recap screen (or roster_set) removes it
		"offers":
			_offers_dialog(q.offers)
		"card":
			_card_dialog(q)
		"achievement":
			Game.achievement_dialog(q, _next_item)
		"awards":
			_awards_note(q)
		"tourney_award":
			_tourney_award(q)
		"walkons":
			_walkons(q)
		_:
			_drop_item()
			return _process_queue()
	return true

## The week's conference awards are out (ConfAwards): one of yours won one, a dialog (VIEW AWARDS);
## otherwise just a toast, and on with the queue.
func _awards_note(q: Dictionary) -> void:
	var mine: Array = q.get("mine", [])
	if mine.is_empty():
		Game.toast("%s CONFERENCE AWARDS ANNOUNCED" % String(q.get("label", "")))
		_next_item()
		return
	# THE WEEKLY AWARD CELEBRATION (WeeklyAwardShow): each of your winners in turn, from the award
	# records themselves; the queue item leaves (saved) only once the last is closed, so a reload
	# before then shows them again and never after
	var yr := int(q.get("year", c.year))
	var wk := int(q.get("week", 0))
	var recs: Array = c.conf_awards.filter(func(a): return not bool(a.get("hist", false)) and int(a.get("year", -1)) == yr and int(a.get("week", -1)) == wk and String(a.get("team", "")) == c.school)
	if recs.is_empty():
		_next_item()
		return
	WeeklyAwardShow.play(self, c, recs, _next_item)

## A tournament of yours is over (TourneyAwards, after its final): its PLAYER OF THE TOURNAMENT,
## whoever's he is, celebrated as the weekly awards are (WeeklyAwardShow's tournament look). The
## queue item leaves (saved) only once it's closed: a reload before shows it again, never after.
func _tourney_award(q: Dictionary) -> void:
	var yr := int(q.get("year", c.year))
	var tid := String(q.get("tid", ""))
	var recs: Array = c.tourney_awards.filter(func(a): return not bool(a.get("hist", false)) and int(a.get("year", -1)) == yr \
		and String(a.get("tid", "")) == tid and String(a.get("cat", "")) == "pot")
	if recs.is_empty():
		_next_item()
		return
	WeeklyAwardShow.play(self, c, recs.slice(0, 1), _next_item)

## WELCOMING ALL WALK-ONS! (WalkOnShow): open tryouts filled your empty places as the season began.
## VIEW NEW WALK-ONS drops the item (saved: never shown again) and opens the roster with them lit
## up; a reload before then shows it again. Nobody of them still here (never expected): skipped.
func _walkons(q: Dictionary) -> void:
	var ids: Array = (q.get("ids", []) as Array).filter(func(pid): return c.team().find_id(int(pid)) != null)
	if ids.is_empty():
		_next_item()
		return
	WalkOnShow.play(Game.overlay if Game.overlay != null else self, c, q, func():
		_drop_item()
		Game.goto("roster", {"walkons": ids}))

## An event card: two choices, each a trade-off. The card leaves the queue the moment you
## choose, so its effects can never apply twice.
func _card_dialog(q: Dictionary) -> void:
	var cd := Moments.card(String(q.id))
	var p := c.team().find_id(int(q.get("pid", 0)))
	if cd.is_empty() or (p == null and String(cd.get("who", "any")) != "any"):
		_next_item()   # its player has left the program
		return
	var options: Array = []
	for ch in cd.choices:
		var choice: Dictionary = ch
		options.append([Moments.fill(String(choice.label), p), LockerData.chips(choice.effects), func():
			var cost := Career.cost_of(choice.effects)
			if cost > c.wallet():
				# it costs credits you don't have: the card stays until you can pay or pick the other
				StorePrompt.need(c, cost, "That choice", func(): _process_queue())
				return
			_drop_item()
			var lines := c.apply_effects(choice.effects, p)
			Game.save_career()
			var said := Moments.fill(String(choice.get("result", "")), p)
			if not lines.is_empty():
				said = " ".join(lines)
			Game.dialog(String(cd.title), said if said != "" else "Done.", [["OK", _after_choice, "primary"]])])
	_choice_dialog(String(cd.title), Moments.fill(String(cd.text), p), options)

## After a choice: the hub redraws (numbers changed) and the next queued thing shows.
func _after_choice() -> void:
	Game.goto("hub", {}, false)

## A dialog with one row per choice: the choice and what it does.
func _choice_dialog(title: String, text: String, options: Array) -> void:
	var layer := Game.dialog(title, text, [])
	var v: VBoxContainer = layer.get_child(1).get_child(0).get_child(0)
	for o in options:
		var cb: Callable = o[2]
		var row := UI.vbox(0)
		row.add_child(UI.label(String(o[0]), 8, UI.GOLD, "caps"))
		row.add_child(CreditCoin.rich("  " + ", ".join(o[1]), 8, UI.ACCENT))
		v.add_child(row_button(row, func():
			if not is_instance_valid(layer) or layer.is_queued_for_deletion():
				return   # one choice per dialog, even with two taps in the same frame
			layer.queue_free()
			Sfx.play("confirm")
			cb.call(), false, 24))

func _drop_item() -> void:
	if not c.queue.is_empty():
		c.queue.pop_front()
	Game.save_career()

func _next_item() -> void:
	_drop_item()
	if not _process_queue() and not _open_cuts():
		Game.open_upgrades()   # the queue's done: then the roster cuts, or any upgrades still to spend

## JOB OFFERS after a good season: take one, or STAY.
func _offers_dialog(offers: Array) -> void:
	if offers.is_empty():
		_next_item()
		return
	var lines := PackedStringArray()
	for id in offers:
		var t: PoloTeam = c.teams[id]
		lines.append("- %s (%s)" % [t.name, c.conf_name(t.conf)])
	var head := "Word gets around. These schools want you as their head coach:"
	var tail := "\n\nA new job means a new roster, new colours and a new home pool. Your staff come with you."
	var buttons: Array = []
	for id in offers:
		var tid: String = id
		buttons.append(["TAKE %s" % Colleges.short_name(c.teams[tid]).to_upper(), func():
			_drop_item()
			Offseason.take_job(c, tid)
			Game.save_career()
			Game.goto("hub", {}, false), "primary"])
	buttons.append(["STAY", _next_item, "ghost"])
	Game.dialog("JOB OFFERS", head + "\n\n" + "\n".join(lines) + tail, buttons)
