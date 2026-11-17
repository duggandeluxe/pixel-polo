extends BaseScreen
## Developer Mode's form lab (Settings > Developer Mode > TEST PLAYER FORM): a sample player's
## card with his stars three times size and at the game's own, and buttons that move his form
## and play the StarFx animations straight away, at half, normal or double speed, with or
## without the particles, once or on a loop. CURRENT and POTENTIAL go from 0 to 5 in halves
## (POTENTIAL never below CURRENT). Nothing here is a real player: no career or save changes.

const CARD := Vector2(214, 140)
const BIG := 3.0                  # the big preview's pixel size
const BIG_AT := Vector2(10, 90)   # its stars' top left
const SMALL_AT := Vector2(160, 100)
const NAME := "SAM PIXEL"

var cur := 3.0
var pot := 5.0
var state := PlayerForm.NORMAL
var fx: StarFx
var card: Control
var controls: VBoxContainer
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	build("FORM LAB")
	rng.randomize()
	var row := UI.hbox(6)
	body.add_child(row)
	card = UI.canvas(int(CARD.x), int(CARD.y), _draw_card)
	fx = StarFx.new()
	fx.force = true      # it's here to be watched, reduce motion or not
	card.add_child(fx)
	row.add_child(card)
	controls = UI.vbox(3)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(controls)
	_controls()

func on_back() -> void:
	Sfx.play("back")
	Game.back("dev_settings")

## Moves his form and plays the change (nothing to play if it's the same form).
func set_form(to: String) -> void:
	var was := state
	if to == was:
		Game.toast("Already %s" % PlayerForm.FORM_NAMES[to], UI.DIM)
		return
	state = to
	fx.play(was, to)
	card.queue_redraw()

func random_form() -> void:
	var others := StarFx.LADDER.filter(func(s): return s != state)
	set_form(others[rng.randi_range(0, others.size() - 1)])

## CURRENT or POTENTIAL by half a star: POTENTIAL is never below CURRENT, so one pushes the other.
func set_stars(which: String, by: float) -> void:
	if which == "cur":
		cur = clampf(cur + by, PlayerForm.MIN_STARS, PlayerForm.MAX_STARS)
		pot = maxf(pot, cur)
	else:
		pot = clampf(pot + by, PlayerForm.MIN_STARS, PlayerForm.MAX_STARS)
		cur = minf(cur, pot)
	card.queue_redraw()
	_controls()

func _controls() -> void:
	for ch in controls.get_children():
		ch.queue_free()
	_row([["HEAT UP", func(): set_form(StarFx.step(state, 1))], ["COOL DOWN", func(): set_form(StarFx.step(state, -1))],
		["RESET", func(): set_form(PlayerForm.NORMAL)]])
	_row([["VERY HOT", func(): set_form(PlayerForm.VERY_HOT)], ["RANDOM FORM", random_form]])
	var sp := _labelled("SPEED")
	for s in [0.5, 1.0, 2.0]:
		var v: float = s
		sp.add_child(UI.button("%sx" % ("0.5" if v < 1.0 else str(int(v))), func():
			fx.speed = v
			_controls(), "tab_on" if is_equal_approx(fx.speed, v) else "tab", 40, 18))
	var tg := UI.hbox(4)
	controls.add_child(tg)
	tg.add_child(UI.button("REPLAY", func():
		if fx.from_state == fx.to_state:
			Game.toast("Nothing to replay yet", UI.DIM)
		fx.replay(), "ghost", 58, 18))
	tg.add_child(_toggle("PARTICLES", fx.particles, func(): fx.particles = not fx.particles))
	tg.add_child(_toggle("LOOP", fx.loop, func():
		fx.loop = not fx.loop
		if fx.loop and not fx.playing():
			fx.replay()))
	for w in [["cur", "CURRENT"], ["pot", "POTENTIAL"]]:
		var which: String = w[0]
		var r := _labelled(w[1])
		r.add_child(UI.button("-", func(): set_stars(which, -0.5), "tab", 22, 18))
		var val := UI.label(PlayerForm.star_text(cur if which == "cur" else pot), 8, UI.GOLD, "caps")
		val.custom_minimum_size = Vector2(22, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_child(val)
		r.add_child(UI.button("+", func(): set_stars(which, 0.5), "tab", 22, 18))
	var note := "On the real cards: ROSTER, then DEV under them."
	if bool(Game.settings.get("reduce_motion", false)):
		note += " Reduce motion is on: these play here anyway, not in the game."
	var p := para(note, UI.DIM, 240)
	controls.add_child(p)
	if Game.career != null:
		controls.add_child(UI.button("ROSTER", func(): Game.goto("roster"), "ghost", 70, 18))

func _row(btns: Array) -> void:
	var h := UI.hbox(4)
	controls.add_child(h)
	for b in btns:
		h.add_child(UI.button(b[0], b[1], "normal", 78, 20))

func _labelled(text: String) -> HBoxContainer:
	var h := UI.hbox(4)
	controls.add_child(h)
	var l := UI.label(text, 8, UI.ACCENT, "caps")
	l.custom_minimum_size = Vector2(62, 0)
	h.add_child(l)
	return h

func _toggle(text: String, on: bool, cb: Callable) -> Button:
	return UI.button("%s %s" % [text, "ON" if on else "OFF"], func():
		cb.call()
		_controls(), "tab_on" if on else "tab", 84, 18)

## The sample card: who he is, his ratings and form, then his stars big and at the game's size
## (on a roster card's strip).
func _draw_card(ci: Control) -> void:
	Deck.frame(ci, Rect2(Vector2.ZERO, CARD), Deck.NAVY, UI.BORDER)
	Deck.text(ci, 8, 9, NAME, 8, UI.TEXT)
	Deck.rtext(ci, CARD.x - 8, 9, "DRV  JR", 8, UI.ACCENT)
	var eff := PlayerForm.effective(cur, state)
	var col := PlayerForm.form_color(state)
	var rows := [["CURRENT", "%s STARS" % PlayerForm.star_text(cur), UI.TEXT], ["POTENTIAL", "%s STARS" % PlayerForm.star_text(pot), UI.TEXT],
		["FORM", String(PlayerForm.FORM_NAMES[state]), col], ["ADJUSTMENT", "%+.1f STAR" % (eff - cur), col],
		["RED STARS", "%d" % PlayerForm.red_stars(state), col]]
	for i in rows.size():
		var y := 21.0 + i * 10.0
		Deck.text(ci, 8, y, rows[i][0], 8, UI.ACCENT)
		Deck.text(ci, 78, y, rows[i][1], 8, rows[i][2])
	# big, whole pixels
	ci.draw_set_transform(BIG_AT, 0.0, Vector2(BIG, BIG))
	fx.draw(ci, 0, 0, cur, pot, state)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the roster card's stars (Deck.STAR_SHAPE, the one star), on a card strip
	Deck.text(ci, SMALL_AT.x - 4, SMALL_AT.y - 12, "IN GAME", 8, UI.DIM)
	ci.draw_rect(Rect2(SMALL_AT.x - 4, SMALL_AT.y - 4, Deck.star_bar_w(Deck.STAR_SHAPE) + 8.0, 15), Color("07144a"))
	fx.draw(ci, SMALL_AT.x, SMALL_AT.y, cur, pot, state, Color(1, 1, 1, 0.14), Deck.STAR_SHAPE)
