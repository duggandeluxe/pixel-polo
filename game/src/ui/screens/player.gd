extends BaseScreen
## One player, the one you tapped on the roster. Left: his card (his portrait, idling in the
## water; name; his hometown (Hometowns); position, cap number, year and age; then CURRENT OVERALL and POTENTIAL, each a
## row of stars: Attributes.stars_of his four attributes' average and of their ceilings'
## average). No numbers for his overall and no form here: HOT form shows on the roster and after
## games. Right: PLAYER ATTRIBUTES: his numerical XP towards his next upgrade and his
## UPGRADES AVAILABLE (tokens: Development), then his four (PASSING, SHOOTING, STRENGTH, DEFENSE,
## or a keeper's COMMUNICATION, LUNGE SPEED, BLOCKING, LEG STRENGTH) as ten boxes each
## (Deck.attr_boxes: light green what he owns, red what his injury takes off for now, filled cyan
## the next point when he has a token to spend, hollow cyan up to the ceiling, grey past it);
## then PLAYER STATISTICS, his season and career numbers, and his awards if he has any. His
## hidden development level is never shown.
##
## His CURRENT OVERALL row shows his HOT form exactly as his roster card does (the same red stars,
## Deck.star_fills, animated by StarFx); POTENTIAL never does. Tapping the card (anywhere but its
## edit and recovery buttons) flips it, a quick pixel squash, to PLAYER MOMENTUM: his status, a bar
## towards his next red star (or what's left of the one he has), the next milestone and his
## bonus, all from PlayerForm.momentum, the same numbers that move his heat. Tap again to flip back.
##
## Tapping a filled cyan box spends one token on it (Career.boost -> Development.spend: +1, never
## past the ceiling; no credits) and everything happens in place: the box flashes and turns
## green, the cyan moves on to the next box (if he has another token), any red injury boxes move
## right with the new point, his stars and XP line update, and the career saves.
##
## RECRUIT MODE (the Recruiting Player Cards update: a market or incoming recruit's card opens
## this page with {id, recruit: true}): the same page, everything about him shown (his CURRENT
## and POTENTIAL stars, his four attributes and their ceilings: there's no scouting). No XP,
## upgrades, statistics, edit or flip. The statistics' place holds RECRUITING: his price (the
## number, then the coin) and SIGN RECRUIT (its confirmation is the market's: the Recruiting
## screen's ask_sign), or SIGNED - JOINS NEXT SEASON once he's yours.

const CYAN := Color("45dfff")          # the statistics' headings
const INJURY_RED := Color("ff5a6a")   # the injury note over the boxes
const PORTRAIT_BG := Color("081650")
const POOL := Color("0a4fd0")
const OPEN_TIME := 0.2         # the page fading in
const UP_TIME := 0.4           # a bought box's flash
const IMPROVE_TIME := 0.9      # his CURRENT stars going up: the row's label flashes
const FLIP_TIME := 0.3         # the card turning over: half to squash, half to open
const FLIP_STEPS := 6.0        # ...in this many whole steps each way (pixel-style, no smooth blur)
## The back of the card: the bar's colour by status.
const MOMENTUM_COLS := {"NEUTRAL": Color("45dfff"), "HOT": Color("ff4a2a"), "ON FIRE": Color("ff2a2a"),
	"COOLING DOWN": Color("5c8cff")}
const ICE_BLUE := Color("5c8cff")
## A little turning arrow, the flip hint.
const FLIP_ICON := [".###.#", "#...##", "#..###", "#.....", "#....#", ".####."]
const LEFT_W := 172
const NAME_W := 92             # an attribute's name, before its boxes
const BOX_H := 15

var pid := 0
var p: PoloPlayer
var t := 0.0
var up := {}                   # the upgrade animating: {key, from, to, box, t0}
var improved := {}             # his CURRENT stars moved by it: {from, to, t0}
var buying := false            # an upgrade going through (a second tap meanwhile does nothing)
var drawn := 0                 # how many times the page has been built (a button from an older one is dead)
var card: PanelContainer       # his card (front or back)
var back_side := false         # showing PLAYER MOMENTUM
var flipping := false          # a flip under way (taps meanwhile do nothing)
var cols: Control
var animated: Array[Control] = []   # canvases redrawn every frame
var mandatory := false         # the upgrades after a game or training (Game.open_upgrades): every one is spent here
var leaving := false           # on to the next player with an upgrade (once)
var recruit := false           # a recruit's profile (RECRUIT MODE): his market record is `rec`
var viewonly := false          # any player's profile, read only (the conference awards' winners)
var scouting := false          # ...an opponent's, from Scout Opponent: nothing of his potential at all
var rec := {}
const RecruitingScreen := preload("res://src/ui/screens/recruiting.gd")

func setup(params: Dictionary) -> void:
	pid = int(params.get("id", 0))
	mandatory = bool(params.get("mandatory", false))
	recruit = bool(params.get("recruit", false))
	viewonly = bool(params.get("view", false))
	scouting = bool(params.get("scout", false))
	viewonly = viewonly or scouting

func _ready() -> void:
	back_target = "roster"
	c = Game.career
	if recruit:
		back_target = "recruiting"
		rec = Recruiting.find(c, pid)
		p = rec.get("p")
		if p == null:
			Game.goto("recruiting")
			return
	elif viewonly:
		# READ ONLY (an award winner): wherever he plays now, else as he was when he won
		back_target = "scout" if scouting else "awards"
		p = ConfAwards.player_of(c, {"pid": pid})
		if p == null:
			Game.goto(back_target)
			return
	else:
		p = c.team().find_id(pid)
	if p == null:
		Game.goto("roster")
		return
	build(_title(), false, true)
	var back := Deck.icon_button("left", on_back, 30, 22, "normal", 2)
	back.tooltip_text = "Back"
	header_left.add_child(back)
	_render()
	if mandatory:
		back_target = "hub"
		Game.toast("NEW ATTRIBUTE UPGRADE AVAILABLE!")

## How to come back to this page as it is (the trophy room's back).
func _back_params() -> Dictionary:
	return {"id": pid, "view": viewonly and not scouting, "scout": scouting, "recruit": recruit}

## In the mandatory upgrades, back only once every one of his is spent.
func on_back() -> void:
	if mandatory and Development.pending(p) > 0:
		Game.toast("SPEND %d MORE UPGRADE%s FIRST" % [Development.pending(p), "" if Development.pending(p) == 1 else "S"])
		return
	if mandatory:
		_next_player()
		return
	if recruit or viewonly:
		Sfx.play("back")
		Game.goto("recruiting" if recruit else ("scout" if scouting else "awards"))
		return
	super.on_back()

## The next player with upgrades to spend, or home once there's nobody left.
func _next_player() -> void:
	if leaving:
		return
	leaving = true
	if not Game.open_upgrades():
		Game.goto("hub", {}, false)

func _title() -> String:
	if recruit:
		return "RECRUIT  %s" % p.last.to_upper()
	return "#%d %s" % [p.number, p.last.to_upper()]

func _process(dt: float) -> void:
	t += dt
	if cols != null and is_instance_valid(cols):
		cols.modulate.a = clampf(t / OPEN_TIME, 0.0, 1.0)
	for cv in animated:
		if is_instance_valid(cv):
			cv.queue_redraw()

## Everything again, in place, with the header's title and credits brought up to date.
func _refresh() -> void:
	title_label.text = _title()
	_update_chip()
	_render()

func _update_chip() -> void:
	if header_right == null or header_right.get_child_count() == 0:
		return
	var old := header_right.get_child(0)
	var chip := credits_chip()
	header_right.add_child(chip)
	header_right.move_child(chip, 0)
	old.queue_free()

func _render() -> void:
	for ch in body.get_children():
		ch.queue_free()
	animated.clear()
	drawn += 1
	var row := UI.hbox(6)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols = row
	cols.modulate.a = clampf(t / OPEN_TIME, 0.0, 1.0)
	body.add_child(row)
	row.add_child(_left())
	row.add_child(_right())

# ------------------------------------------------ left: his card
func _left() -> Control:
	card = PanelContainer.new()
	card.name = "Card"
	card.add_theme_stylebox_override("panel", UI.chunky(Deck.NAVY, UI.BORDER, false, false, 6, 6))
	card.custom_minimum_size = Vector2(LEFT_W, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	if not recruit and not viewonly:   # (a recruit's card doesn't flip: no momentum yet)
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.tooltip_text = "Flip the card"
		card.gui_input.connect(_card_input)
	card.resized.connect(func(): card.pivot_offset = card.size * 0.5)
	var front := _front()
	front.name = "Front"
	var back := _back()
	back.name = "Back"
	card.add_child(front)
	card.add_child(back)
	front.visible = not back_side
	back.visible = back_side
	return card

## The front: everything as it was, the flip hint on the portrait.
func _front() -> Control:
	var v := UI.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_portrait())
	var full := "%s %s" % [p.first.to_upper(), p.last.to_upper()]
	v.add_child(UI.canvas(0, 13, func(ci: Control):
		Deck.ctext(ci, Rect2(0, 0, ci.size.x, 13), Deck.fit(full, ci.size.x, 16, "big"), 16, UI.TEXT, "big")))
	# his hometown, under his name (Hometowns: his for good; an old save's shown with its real state)
	if p.home != "":
		var town := Hometowns.shown(p.home).to_upper()
		var home := UI.canvas(0, 9, func(ci: Control):
			Deck.ctext(ci, Rect2(0, 0, ci.size.x, 9), Deck.fit(town, ci.size.x), 8, UI.ACCENT))
		home.name = "Hometown"
		home.set_meta("text", town)
		v.add_child(home)
	var info := UI.label(recruit_info(p) if recruit else info_text(p), 8, UI.ACCENT, "caps")
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.clip_text = true
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(info)
	v.add_child(_rule())
	v.add_child(_star_row("CURRENT OVERALL", true))
	if not scouting:   # (scouting: his potential is his program's secret, not even a placeholder)
		v.add_child(_star_row("POTENTIAL", false))
	if recruit or viewonly:
		return v
	var hint := UI.canvas(0, 9, func(ci: Control): _flip_hint(ci, "FLIP CARD"))
	hint.name = "FlipHint"
	v.add_child(hint)
	return v

## "DRV  |  RECRUIT  |  AGE 18  |  FRESNO": position, recruit, age, home.
static func recruit_info(q: PoloPlayer) -> String:
	return "%s  |  RECRUIT  |  AGE %d" % [q.pos_text(), q.age]

## The back: PLAYER MOMENTUM (PlayerForm.momentum), the same navy and pixel type.
func _back() -> Control:
	var m := PlayerForm.momentum(p)
	var v := UI.vbox(3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_meta("momentum", m)
	var col := momentum_color(m)
	var line := func(h: int, paint: Callable) -> void:
		v.add_child(UI.canvas(0, h, paint))
	line.call(13, func(ci: Control): Deck.ctext(ci, Rect2(0, 0, ci.size.x, 13), "PLAYER MOMENTUM", 16, UI.GOLD, "big"))
	line.call(9, func(ci: Control): Deck.ctext(ci, Rect2(0, 0, ci.size.x, 9), Deck.fit("%s %s" % [p.first.substr(0, 1), p.last.to_upper()], ci.size.x), 8, UI.TEXT))
	v.add_child(_rule())
	line.call(22, func(ci: Control):
		Deck.text(ci, 2, 4, "CURRENT STATUS", 8, UI.ACCENT)
		Deck.text(ci, 2, 16, String(m.status), 16, col, "big"))
	# his stars as they are now, red ones and all (the same bar as the front)
	line.call(10, func(ci: Control):
		var bw := Deck.star_bar_w_for(p.stars, p.pot_stars, int(m.stars))
		Deck.star_bar(ci, roundf((ci.size.x - bw) * 0.5), 1, p.stars, p.pot_stars, int(m.stars), Color(1, 1, 1, 0.14), Deck.STAR_SHAPE))
	line.call(24, func(ci: Control):
		var w := ci.size.x
		Deck.text(ci, 2, 4, String(m.bar_label), 8, UI.ACCENT)
		var pct := "%d%%" % roundi(float(m.bar) * 100.0)
		var bw := w - 4.0 - Deck.text_w("100%") - 6.0
		Deck.seg_bar(ci, Rect2(2, 11, bw, 9), 10, roundi(float(m.bar) * 10.0), col, UI.INK)
		Deck.rtext(ci, w - 2, 15.5, pct, 8, UI.TEXT))
	line.call(20, func(ci: Control):
		Deck.text(ci, 2, 4, "NEXT MILESTONE", 8, UI.ACCENT)
		Deck.text(ci, 2, 14, String(m.next), 8, UI.TEXT))
	line.call(20, func(ci: Control):
		var n := int(m.stars)
		Deck.text(ci, 2, 4, "CURRENT BONUS", 8, UI.ACCENT)
		Deck.text(ci, 2, 14, "NONE" if n == 0 else "+%d HOT STAR%s" % [n, "" if n == 1 else "S"], 8, PlayerForm.FIRE_RED if n > 0 else UI.TEXT))
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gap)
	line.call(10, func(ci: Control): _flip_hint(ci, "FLIP BACK", true))
	return v

## The bar's and the status word's colour: cyan when neutral, yellow towards red while heating up,
## red HOT, bright red ON FIRE, blue cooling down.
static func momentum_color(m: Dictionary) -> Color:
	var st := String(m.status)
	if st == "HEATING UP":
		return UI.GOLD.lerp(PlayerForm.FIRE_RED, clampf(float(m.bar), 0.0, 1.0) * 0.6)
	return MOMENTUM_COLS.get(st, Color("45dfff"))

## "FLIP CARD" / "FLIP BACK" with the turning arrow, small and dim, at the right (or centred).
static func _flip_hint(ci: Control, label: String, centre: bool = false) -> void:
	var tw := Deck.text_w(label) + 9.0
	var x := roundf((ci.size.x - tw) * 0.5) if centre else ci.size.x - tw - 3.0
	var y := ci.size.y - 7.0
	Deck.pat(ci, Vector2(x, y - 2.0), FLIP_ICON, {"#": UI.DIM2})
	Deck.text(ci, x + 9.0, y + 1.0, label, 8, UI.DIM2)

## A tap or click on the card (its buttons keep theirs) turns it over.
func _card_input(ev: InputEvent) -> void:
	var tap: bool = (ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and ev.pressed) \
		or (ev is InputEventScreenTouch and ev.pressed and not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	if tap:
		card.accept_event()
		flip()

## Turns the card over: it squashes to nothing in FLIP_STEPS whole steps, the other side comes
## up, and it opens again (at once with motion off). A flip under way ignores more taps.
func flip() -> void:
	if flipping or card == null:
		return
	if not Juice.enabled():
		_turn()
		return
	flipping = true
	card.pivot_offset = card.size * 0.5
	var squash := func(v: float): card.scale.x = maxf(0.02, roundf(v * FLIP_STEPS) / FLIP_STEPS)
	var tw := create_tween()
	tw.tween_method(squash, 1.0, 0.0, FLIP_TIME * 0.5)
	tw.tween_callback(_turn)
	tw.tween_method(squash, 0.0, 1.0, FLIP_TIME * 0.5)
	tw.tween_callback(func():
		card.scale.x = 1.0
		flipping = false)
	Sfx.play("click")

func _turn() -> void:
	back_side = not back_side
	for side in card.get_children():
		side.visible = (String(side.name) == "Back") == back_side

## His portrait: the same sprite as in the pool, big, on dark navy with the pool at the bottom.
## It takes whatever height the card has left, so a healthy player's portrait is taller.
func _portrait() -> Control:
	var team := c.team()
	if viewonly:
		for id in c.teams:   # (another program's player: his own caps)
			if (c.teams[id] as PoloTeam).find_id(p.id) != null:
				team = c.teams[id]
	var stage := UI.canvas(0, 80, func(ci: Control):
		var w := ci.size.x
		var h := ci.size.y
		ci.draw_rect(Rect2(1, 1, w - 2, h - 2), PORTRAIT_BG)
		var water := roundf(h - maxf(12.0, h * 0.14))
		# his headshot (Portrait), as big as whole pixels allow, shoulders in the water; idling: the
		# water stirs, he bobs a pixel now and then, and blinks every few seconds
		var sc := clampi(int(floorf((water - 4.0) / (Portrait.SIZE.y - 3))), 2, 5)
		var bob := float(sc) if fposmod(t, 2.4) > 1.2 else 0.0
		var blink := fposmod(t + float(pid % 7) * 0.37, 3.6) < 0.12
		Portrait.draw_ours(ci, Vector2(roundf(w / 2.0), water + 3.0 * sc + bob), p, team, sc, blink)
		_draw_pool(ci, Rect2(1, water - 1.0, w - 2, h - water + 1.0))
		if p.lefty:
			Deck.shadow_text(ci, 6, 9, "LEFTY", 8, UI.GOLD)
		Deck.frame(ci, Rect2(0, 0, w, h), Color(0, 0, 0, 0), UI.BORDER))
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.clip_contents = true
	animated.append(stage)
	if recruit or viewonly:
		return stage   # (nothing to edit: he isn't yours, or isn't yours to change here)
	var eb := flat_button("", func():
		if Store.pro:
			_edit()
		else:
			StorePrompt.pro_locked("Player Name & Number Customization"), Deck.NAVY_HEAD, UI.BORDER_HI, UI.TEXT, 14)
	eb.name = "EditPlayer"
	eb.icon = Deck.icon_texture("edit")
	eb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eb.custom_minimum_size = Vector2(16, 14)
	eb.tooltip_text = "EDIT PLAYER" if Store.pro else "EDIT PLAYER (PIXEL POLO +)"
	eb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	eb.offset_left = -19
	eb.offset_right = -3
	eb.offset_top = 3
	eb.offset_bottom = 17
	stage.add_child(eb)
	return stage

## The pool at the bottom of the portrait: a lighter surface line and a few pixel splashes that
## hop between two heights.
func _draw_pool(ci: Control, r: Rect2) -> void:
	ci.draw_rect(r, POOL)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), UI.WATER_LIGHT)
	var step := int(t / 0.5)
	for i in 10:
		var x := r.position.x + 3.0 + fposmod(float(i * 41 + 7), r.size.x - 8.0)
		var lift := float((i + step) % 2) * 2.0
		var big := i % 3 == 0
		var sz := 3.0 if big else 2.0
		ci.draw_rect(Rect2(roundf(x), r.position.y - sz - lift + 1.0, sz, sz), UI.WATER_SHINE if big else UI.WATER_LIGHT)
		ci.draw_rect(Rect2(roundf(x + 9.0), r.position.y + 3.0 + float(i % 3) * 2.0, 2, 2), Color(UI.WATER_LIGHT, 0.6))

## "C  |  #7  |  FR  |  AGE 19": position, cap number, year, age.
static func info_text(q: PoloPlayer) -> String:
	return "%s  |  #%d  |  %s  |  AGE %d" % [q.pos_text(), q.number, q.year_text(), q.age]

## A label over a row of the roster's big stars, centred: CURRENT OVERALL (his stars, with his HOT
## form's red stars exactly as on his roster card: StarFx, Deck.star_fills) or POTENTIAL (his
## ceilings', permanent: never any form), gold up to them and empty places after. When an
## upgrade lifts his stars the CURRENT label flashes gold a moment.
func _star_row(label: String, current: bool) -> Control:
	var state := p.form_state() if current else PlayerForm.NORMAL
	var fx: StarFx = StarFx.new() if current else null
	var row := UI.canvas(0, 20, func(ci: Control):
		var w := ci.size.x
		var col := UI.ACCENT
		var it := t - float(improved.get("t0", -99.0))
		if current and not improved.is_empty() and it < IMPROVE_TIME and fposmod(it, 0.3) < 0.15:
			col = UI.GOLD
		Deck.ctext(ci, Rect2(0, 0, w, 8), label, 8, col)
		# CURRENT: gold, then hollow up to his POTENTIAL (none once he's there); POTENTIAL: gold to it
		var v := p.stars if current else p.pot_stars
		var to := v if scouting else p.pot_stars   # (scouting: no hollow stars after his own)
		var bw := Deck.star_bar_w_for(v, to, PlayerForm.red_stars(state))
		if fx != null:
			fx.bare = scouting
			fx.draw(ci, roundf((w - bw) * 0.5), 11, v, to, state, Color(1, 1, 1, 0.14), Deck.STAR_SHAPE)
		else:
			Deck.star_bar(ci, roundf((w - bw) * 0.5), 11, v, v, 0, Color(1, 1, 1, 0.14), Deck.STAR_SHAPE))
	if current:
		row.add_child(fx)
		fx.watch(StarFx.key_of(p), state, String(p.last_game.get("was", "")))
	row.name = "Stars_" + ("Current" if current else "Potential")
	row.set_meta("stars", p.stars if current else p.pot_stars)
	row.set_meta("red", PlayerForm.red_stars(state))
	animated.append(row)
	return row

# ------------------------------------------------ right: attributes, numbers
func _right() -> Control:
	var right := UI.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var attrs := _attributes()
	attrs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(attrs)
	var stats := _recruiting() if recruit else _numbers()
	stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(stats)
	return right

## RECRUITING (a recruit's page): his price as the number and the coin and SIGN RECRUIT; signed,
## SIGNED - JOINS NEXT SEASON instead. A signing he can't have
## (credits, the season's four, the phase) is greyed with the reason under it.
func _recruiting() -> Control:
	var v := UI.vbox(3)
	_heading(v, "RECRUITING")
	var signed: bool = rec in c.incoming
	var row := UI.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	if signed:
		var done := UI.label("SIGNED - JOINS NEXT SEASON", 16, UI.GOOD, "big")
		done.name = "SignedNote"
		row.add_child(done)
	else:
		row.add_child(UI.label("PRICE", 8, UI.ACCENT, "caps"))
		var price := CreditCoin.widget(int(rec.price), 16, UI.GOLD, false, 20, "big")
		price.name = "Price"
		row.add_child(price)
	if signed:
		return navy_panel(v)
	var btns := UI.hbox(6)
	v.add_child(btns)
	var block := Recruiting.sign_block(c, rec)
	var sign := UI.button("SIGN RECRUIT", func():
		RecruitingScreen.ask_sign(c, rec, func(_err): _refresh()), "primary", 0, 20)
	sign.name = "Sign"
	sign.disabled = block != ""
	sign.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(sign)
	# PIN / UNPIN: a bookmark on the market (Recruiting.toggle_pin), free, never a signing
	var pinned := Recruiting.is_pinned(rec)
	var pin := UI.button("UNPIN" if pinned else "PIN", func():
		var err := Recruiting.toggle_pin(c, rec)
		if err != "":
			Game.toast(err, UI.WARN)
			Sfx.play("error")
			return
		Sfx.play("click")
		Game.toast("%s %s" % [p.short_name(), "PINNED: he stays on the market through refreshes" if Recruiting.is_pinned(rec) else "UNPINNED"], UI.GOLD)
		Game.save_career()
		_refresh(), "tab_on" if pinned else "normal", 70, 20)
	pin.name = "Pin"
	pin.tooltip_text = "Keep him on the market through refreshes. Free: it doesn't sign him."
	btns.add_child(pin)
	# a TEAM NEED he'd fill (RosterNeeds: his position only)
	var fills := RosterNeeds.fills(c, p)
	if not fills.is_empty():
		var tn := UI.label("TEAM NEED: %s" % ", ".join(fills), 8, UI.GOLD, "caps")
		tn.name = "TeamNeed"
		v.add_child(tn)
	if block != "":
		var why := CreditCoin.rich(block, 8, UI.WARN, "body", 200)
		why.name = "Why"
		v.add_child(why)
	return navy_panel(v)

## A panel heading only as tall as its letters, a note at the right, a line under it.
func _heading(v: VBoxContainer, title: String, aside: String = "", aside_col: Color = UI.ACCENT) -> void:
	var h := UI.canvas(0, 11, func(ci: Control):
		Deck.text(ci, 0, 5.5, title, 16, UI.TEXT, "big")
		if aside != "":
			Deck.rtext(ci, ci.size.x, 5.5, Deck.fit(aside, ci.size.x - Deck.text_w(title, 16, "big") - 6.0), 8, aside_col))
	h.name = "Heading_" + title.replace(" ", "_")
	h.set_meta("aside", aside)
	v.add_child(h)
	v.add_child(_rule())

## XP: 85 / 216  UPGRADES AVAILABLE: 1. (Never his hidden level.) Fully developed (every
## attribute at its ceiling): MAX POTENTIAL REACHED instead of his XP.
func _xp_line() -> Control:
	var need := Development.xp_needed(p)
	var xp_txt := "MAX POTENTIAL REACHED" if Development.is_maxed(p) else "XP: %d / %d" % [p.xp, need]
	var up_txt := "UPGRADES AVAILABLE: %d" % p.tokens
	var line := UI.canvas(0, 11, func(ci: Control):
		var w := ci.size.x
		Deck.text(ci, 0, 5.5, xp_txt, 8, UI.TEXT)
		var col := UI.GOLD if p.tokens > 0 and fposmod(t, 0.8) < 0.5 else (UI.GOLD if p.tokens > 0 else UI.ACCENT)
		Deck.rtext(ci, w, 5.5, up_txt, 8, col))
	line.name = "XpLine"
	line.set_meta("text", "%s  %s" % [xp_txt, up_txt])
	animated.append(line)
	return line

func _rule() -> Control:
	var d := UI.canvas(0, 1, func(ci): ci.draw_rect(Rect2(0, 0, ci.size.x, 1), Deck.EDGE))
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return d

## The XP line, then NAME  [ten boxes]: one row an attribute, the rows sharing the panel's
## height. The filled cyan box is a real (invisible) button over the drawing ("Up_" + key), so a
## mouse click and a tap both buy; there's one only while he has a token and room in that row.
## The heading's note: his injury, if he has one. Under the XP line, NEW ATTRIBUTE UPGRADE
## AVAILABLE! while he has a token to spend.
func _attributes() -> Control:
	var v := UI.vbox(2)
	if recruit or viewonly:
		return _recruit_attributes(v)
	_heading(v, "PLAYER ATTRIBUTES", ("INJURED — " + Development.injury_text(p)) if p.is_injured() else "", INJURY_RED)
	v.add_child(_xp_line())
	if p.tokens > 0 and Development.has_room(p):
		var msg := "NEW ATTRIBUTE UPGRADE AVAILABLE!"
		var note := UI.canvas(0, 9, func(ci: Control):
			Deck.ctext(ci, Rect2(0, 0, ci.size.x, 9), msg, 8, UI.GOLD if fposmod(t, 0.8) < 0.55 else UI.TEXT))
		note.name = "UpgradeNote"
		note.set_meta("text", msg)
		animated.append(note)
		v.add_child(note)
	for k in p.key_ratings():
		var key: String = k
		var row := UI.hbox(4)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(row)
		var nm := UI.canvas(NAME_W, BOX_H, func(ci: Control):
			Deck.shadow_text(ci, 0, BOX_H * 0.5, String(Attributes.NAMES[key]).to_upper(), 8, UI.TEXT))
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(nm)
		var b := Button.new()
		var cv := UI.canvas(0, BOX_H, func(ci: Control): _draw_boxes(ci, key, b))
		cv.name = "Boxes_" + key
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		animated.append(cv)
		row.add_child(cv)
		_buy_button(b, cv, key)
	return navy_panel(v)

## A recruit's four: his ten boxes each, up to his attribute and hollow up to its ceiling. No XP,
## no buying: he isn't yours.
func _recruit_attributes(v: VBoxContainer) -> Control:
	_heading(v, "PLAYER ATTRIBUTES")
	for k in p.key_ratings():
		var key: String = k
		var row := UI.hbox(4)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(row)
		var nm := UI.canvas(NAME_W, BOX_H, func(ci: Control):
			Deck.shadow_text(ci, 0, BOX_H * 0.5, String(Attributes.NAMES[key]).to_upper(), 8, UI.TEXT))
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(nm)
		var cv := UI.canvas(0, BOX_H, func(ci: Control):
			# (scouting: his current points only: the ceiling at them, nothing cyan past)
			Deck.attr_boxes(ci, Rect2(0, 0, ci.size.x, BOX_H), p.attr(key), p.attr(key) if scouting else Attributes.ceiling(p, key)))
		cv.name = "Boxes_" + key
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(cv)
	return navy_panel(v)

## The filled cyan box's button: no look of its own (the boxes are drawn), on it the pointing
## hand. Only there while he has a token and the row has room.
func _buy_button(b: Button, cv: Control, key: String) -> void:
	b.name = "Up_" + key
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var box := Deck.buy_box(p.attr(key), Attributes.ceiling(p, key))
	var can := box >= 0 and Development.can_spend(p, key)
	b.visible = can
	b.disabled = not can
	b.tooltip_text = "Upgrade %s (1 upgrade)" % String(Attributes.NAMES[key]).to_lower()
	b.set_meta("box", box if can else -1)
	# (a button the last purchase already replaced can't buy again: two quick taps are one upgrade)
	var built := drawn
	b.pressed.connect(func():
		if built == drawn:
			_buy(key))
	cv.add_child(b)
	var place := func():
		if box >= 0:
			var r := Deck.box_rect(Rect2(Vector2.ZERO, cv.size), box)
			b.position = r.position
			b.size = r.size
	cv.resized.connect(place)
	place.call()

func _draw_boxes(ci: Control, key: String, b: Button) -> void:
	var r := Rect2(0, 0, ci.size.x, BOX_H)
	var o := {"tokens": p.tokens, "pen": float(Development.penalty(p, key)), "hover": b.is_hovered()}
	if String(up.get("key", "")) == key:
		o["flash"] = int(up.box)
		o["flash_t"] = clampf((t - float(up.t0)) / UP_TIME, 0.0, 1.0)
	Deck.attr_boxes(ci, r, p.attr(key), Attributes.ceiling(p, key), o)

## Spends a token on `key`'s cyan box: Career.boost checks again that he has a token and room
## (whatever the screen showed), takes exactly one token and adds the point; then the page is
## redrawn in place and the career saved. A tap while one is going through is ignored.
func _buy(key: String) -> void:
	if buying or not Development.can_spend(p, key):
		return
	buying = true
	var before := p.attr(key)
	var stars_before := p.stars
	var box := Deck.buy_box(before, Attributes.ceiling(p, key))
	if c.boost(p, key):
		Sfx.play("levelup")
		Game.save_career()
		up = {"key": key, "from": before, "to": p.attr(key), "box": box, "t0": t}
		improved = {}
		if p.stars > stars_before:
			improved = {"from": stars_before, "to": p.stars, "t0": t}
		_refresh()
		if mandatory and Development.pending(p) == 0:
			# his last one: the box flashes, then the next player's (or home)
			if not Game.test_mode:
				await get_tree().create_timer(UP_TIME + 0.5).timeout
			if is_inside_tree():
				_next_player()
	buying = false

## This season and his career, by position. A number the game doesn't keep yet shows "-".
func _numbers() -> Control:
	var v := UI.vbox(2)
	_heading(v, "PLAYER STATISTICS")
	var cols_def: Array
	if p.is_keeper():
		cols_def = [["GP", "gp"], ["SAVES", "sv"], ["ALLOWED", "ga"], ["SAVE %", "sv%"]]
	else:
		cols_def = [["GP", "gp"], ["GOALS", "g"], ["ASSISTS", "a"], ["STEALS", "st"], ["BLOCKS", "bl"]]
	v.add_child(UI.canvas(0, 40, func(ci: Control):
		var w := ci.size.x
		var first := 76.0
		var cw := floorf((w - first) / cols_def.size())
		for i in cols_def.size():
			Deck.ctext(ci, Rect2(first + i * cw, 1, cw, 10), cols_def[i][0], 8, CYAN)
		var rows := [["THIS SEASON", p.stats], ["CAREER", p.totals]]
		for r in rows.size():
			var y := 12.0 + r * 14.0
			ci.draw_rect(Rect2(0, y, w, 1), Color(Deck.EDGE, 0.45))   # a thin line over each row
			Deck.text(ci, 4, y + 7.5, rows[r][0], 8, UI.ACCENT)
			for i in cols_def.size():
				Deck.ctext(ci, Rect2(first + i * cw, y + 1, cw, 13), stat_text(rows[r][1], cols_def[i][1]), 8, UI.TEXT)))
	if not p.awards.is_empty():
		var aw := UI.label("AWARDS  -  " + ", ".join(p.awards.slice(maxi(0, p.awards.size() - 2))), 8, UI.GOLD, "caps")
		aw.clip_text = true
		v.add_child(aw)
	# CAREER ACCOLADES, in the room under the table (Honours: the saved records, his own), and his
	# TROPHY CASE on the right of its heading (the trophy room: every honour on its own)
	_heading(v, "CAREER ACCOLADES")
	var head: Control = v.get_child(v.get_child_count() - 2)
	var tc := _trophy_case_button(func(): Game.goto("trophy_room", {"id": p.id, "back": _back_params()}))
	tc.tooltip_text = "%s's trophy room" % p.short_name()
	head.add_child(tc)
	var place := func(): tc.position = Vector2(head.size.x - tc.size.x, 0)
	head.resized.connect(place)
	tc.resized.connect(place)
	var acc := accolades(c, p.id)
	var cv := UI.canvas(0, ACC_LINE, func(ci: Control): draw_accolades(ci, acc))
	cv.name = "Accolades"
	cv.set_meta("entries", acc)
	cv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cv)
	return navy_panel(v)

## The TROPHY CASE button: small enough for the heading's own row (11 high), yellow, the words in ink.
func _trophy_case_button(cb: Callable) -> Button:
	var t := "TROPHY CASE"
	var w := int(Deck.text_w(t)) + 10
	var b := Button.new()
	b.name = "TrophyCase"
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 11)
	b.size = Vector2(w, 11)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	var face := UI.canvas(w, 11, func(ci: Control):
		var lit := b.is_hovered()
		Deck.frame(ci, Rect2(0, 0, w, 11), UI.GOLD.lightened(0.15) if lit else UI.GOLD, UI.BORDER)
		Deck.ctext(ci, Rect2(0, 0, w, 11), t, 8, UI.INK))
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(face)
	b.mouse_entered.connect(face.queue_redraw)
	b.mouse_exited.connect(face.queue_redraw)
	return b

const ACC_LINE := 10           # an accolade's line

## His honours, all career, only those he's won (Honours: the records themselves, by his id,
## never his team, so never counted twice and never renamed by a move): [[count, full name, short],
## ...], each with the years he won it: "1x NCSA DEFENSIVE PLAYER OF THE YEAR (2029)", "3x NCC
## DEFENSIVE PLAYER OF THE WEEK (2027: 1, 2028: 2)". The NCSA's first, then All-Tournament, weekly,
## and an older save's season awards. The TROPHY CASE has every one of them on its own.
static func accolades(car: Career, pid: int) -> Array:
	return Honours.grouped(Honours.of(car, pid, ConfAwards.player_of(car, {"pid": pid}) if car != null else null))

## How the accolades fit `size`: full names a line each if they fit, else the short names, else
## the short names in two columns. {mode: "full" | "short" | "two", lines}.
static func accolade_layout(entries: Array, size: Vector2) -> Dictionary:
	var rows := floori(size.y / ACC_LINE)
	var widest := func(i: int) -> float:
		var w := 0.0
		for e in entries:
			w = maxf(w, Deck.text_w("%dx %s" % [int(e[0]), String(e[i])]))
		return w
	if entries.size() <= rows and widest.call(1) <= size.x:
		return {"mode": "full"}
	if entries.size() <= rows and widest.call(2) <= size.x:
		return {"mode": "short"}
	return {"mode": "two"}

## The accolades: "2x" in yellow, the award's name after it; NO CAREER ACCOLADES YET without any.
static func draw_accolades(ci: Control, entries: Array) -> void:
	var sz := ci.size
	if entries.is_empty():
		Deck.ctext(ci, Rect2(0, 0, sz.x, ACC_LINE), "NO CAREER ACCOLADES YET", 8, UI.DIM)
		return
	var lay := accolade_layout(entries, sz)
	ci.set_meta("mode", lay.mode)
	var cols := 2 if lay.mode == "two" else 1
	var col_w := sz.x / cols
	for i in entries.size():
		var e: Array = entries[i]
		var x := 4.0 + (i % cols) * col_w
		var y := floorf(i / cols) * ACC_LINE + ACC_LINE * 0.5
		var count := "%dx" % int(e[0])
		Deck.text(ci, x, y, count, 8, UI.GOLD)
		var tx := x + Deck.text_w(count + " ")
		Deck.text(ci, tx, y, Deck.fit(String(e[1] if lay.mode == "full" else e[2]), col_w - (tx - (i % cols) * col_w) - 4.0), 8, UI.TEXT)

## One number for the table. Games, goals, assists, steals and saves have always been kept;
## blocks, exclusions drawn ("EXCL") and goals allowed only since they started being counted,
## so until then they're "-".
## SAVE % = saves / (saves + goals allowed), from the games where both were kept.
static func stat_text(d: Dictionary, key: String) -> String:
	if key == "sv%":
		if not d.has("ga") or not d.has("sva"):
			return "-"
		var sv := float(d.sva)
		var shots := sv + float(d.ga)
		return "-" if shots <= 0.0 else "%.1f%%" % (100.0 * sv / shots)
	if key in ["bl", "ga", "ed"] and not d.has(key):
		return "-"
	return str(int(d.get(key, 0)))

## PIXEL POLO +: his name and cap number (PlayerEdit: only those). Nothing's changed until SAVE;
## CANCEL leaves him as he was.
func _edit(first: String = "", last: String = "", number: int = 0) -> void:
	first = first if first != "" else p.first
	last = last if last != "" else p.last
	number = number if number > 0 else p.number
	var form := {"first": first, "last": last, "number": number}
	var layer := Game.dialog("EDIT PLAYER", "PLAYER NAME and CAP NUMBER. Keepers wear 1, 13 or 21.", [
		["CANCEL", Callable(), "ghost"],
		["SAVE", func(): _save_edit(form), "primary"]])
	var v: VBoxContainer = layer.get_child(1).get_child(0).get_child(0)
	var row := UI.hbox(4)
	row.name = "EditRow"
	v.add_child(row)
	v.move_child(row, 2)
	for f in [["first", 70], ["last", 90]]:
		var key: String = f[0]
		var le := LineEdit.new()
		le.name = "Edit_" + key
		le.text = form[key]
		le.max_length = PlayerEdit.NAME_MAX
		le.custom_minimum_size = Vector2(f[1], 18)
		le.text_changed.connect(func(tx): form[key] = tx)
		row.add_child(le)
	var num := SpinBox.new()
	num.name = "Edit_number"
	num.min_value = PlayerEdit.NUMBER_RANGE.x
	num.max_value = PlayerEdit.NUMBER_RANGE.y
	num.value = form.number
	num.custom_minimum_size = Vector2(50, 18)
	num.value_changed.connect(func(n): form["number"] = int(n))
	row.add_child(num)

## SAVE: done, or back to the form with what was typed and the reason.
func _save_edit(form: Dictionary) -> void:
	var why := PlayerEdit.apply(c, p, String(form.first), String(form.last), int(form.number))
	if why != "":
		Game.toast(why, UI.WARN)
		_edit(String(form.first), String(form.last), int(form.number))
		return
	Game.save_career()
	_refresh()
