class_name LuckySpinPanel
extends Control
## THE LUCKY SPIN PANEL (the shop's LUCKY SPIN card opens it over the shop): the wheel, WATCH AD &
## SPIN, the allowance (SPINS AVAILABLE: 2/2, or NEXT SPINS IN: 05:59:59), the odds, what a spin
## pays, and the win. The spin is decided and paid by Store before the wheel moves
## (Store.spin_claimed); this only shows it. A result paid while the panel was shut (the app closed
## mid-spin, say) is shown when it opens (LuckySpin.pending).
##
## In the editor's test store the button is TEST AD & SPIN, with a Developer row: what the test ad
## does (reward / closed early / failed / none loaded), the slice to land on, +1 HOUR on the test
## clock, and the test wallet. Test spins have their own allowance and wallet: never the real ones.

const W := 452
const ODDS := [[5, "8 OF 11"], [10, "2 OF 11"], [15, "1 OF 11"]]
const EXPLAIN := "Watch a short ad to spin the wheel. Every spin wins Polo Points, and they go into the wallet every dynasty shares. 2 spins every 6 hours."

var test := false
var wheel: LuckyWheel
var _status: Label
var _btn: Button
var _note: Label
var _wallet: Label
var _ad_btn: Button
var _force_btn: Button
var _result := {}
var _waiting := false           # an ad is up: the button waits
var _blink_t := -1.0
var _tick := 0.0
var _banner: Control = null
var _confetti: Array = []       # [pos, vel, color] in whole pixels
var _fx: Control

static func open() -> LuckySpinPanel:
	var p := LuckySpinPanel.new()
	Game.overlay.add_child(p)
	return p

func _ready() -> void:
	test = Store.spin_testing()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := PanelContainer.new()
	p.name = "LuckySpinPopup"
	p.add_theme_stylebox_override("panel", UI.popup_frame(UI.GOLD, Deck.NAVY, 8, 6))
	var vw := get_viewport().get_visible_rect().size.x
	p.custom_minimum_size = Vector2(minf(W, vw - 12.0), 0)
	center.add_child(p)
	var h := UI.hbox(10)
	p.add_child(h)
	# the wheel, on its own dark plate
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UI.chunky(Color("071447"), Color("14318c"), false, false, 5, 4, UI.BEVEL_SUNK))
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(plate)
	wheel = LuckyWheel.new(56, true, true)
	wheel.name = "Wheel"
	wheel.landed.connect(_landed)
	plate.add_child(wheel)
	# the right side
	var v := UI.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var head := UI.hbox(4)
	v.add_child(head)
	var title := UI.label("LUCKY SPIN", 20, UI.GOLD, "big")
	title.name = "SpinTitle"
	title.add_theme_color_override("font_shadow_color", Color(0.01, 0.03, 0.12, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := Deck.icon_button("x", close, 20, 18)
	x.name = "Close"
	head.add_child(x)
	_status = UI.label("", 8, UI.TEXT, "caps")
	_status.name = "SpinStatus"
	v.add_child(_status)
	v.add_child(_odds())
	var ex := UI.label(EXPLAIN, 8, UI.DIM)
	ex.name = "SpinExplain"
	ex.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ex.custom_minimum_size = Vector2(200, 0)
	v.add_child(ex)
	_btn = Deck.button("TEST AD & SPIN" if test else "WATCH AD & SPIN", _spin, "primary", 0, 22)
	_btn.name = "SpinButton"
	v.add_child(_btn)
	_note = UI.label("", 8, UI.WARN)
	_note.name = "SpinNote"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(200, 0)
	v.add_child(_note)
	if test:
		v.add_child(_dev_row())
	# the celebration's layer (confetti), over everything
	_fx = UI.canvas(0, 0, _draw_fx)
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fx)
	Store.spin_claimed.connect(_claimed)
	Ads.ad_finished.connect(_ad_done)
	Ads.availability_changed.connect(_refresh)
	Sfx.play("card")
	_refresh()
	var st := Store.spin_state(test)
	if not st.pending.is_empty():   # paid while the wheel wasn't watching: show it now
		_result = st.pending.duplicate()
		wheel.show_at(int(_result.seg))
		_landed(int(_result.seg))

func _exit_tree() -> void:
	for pair in [[Store.spin_claimed, _claimed], [Ads.ad_finished, _ad_done], [Ads.availability_changed, _refresh]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])

func close() -> void:
	Sfx.play("back")
	if not _result.is_empty():
		Store.spin_shown(test)   # (paid already: closing mid-spin loses nothing)
	queue_free()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

## The odds table: a swatch of the slice's colour, the prize, its slices, its chance.
func _odds() -> Control:
	var g := GridContainer.new()
	g.name = "SpinOdds"
	g.columns = 4
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 1)
	for row in ODDS:
		var pp := int(row[0])
		var col: Color = LuckyWheel.C15 if pp == 15 else (LuckyWheel.C10 if pp == 10 else LuckyWheel.C5[0])
		var sw := UI.canvas(9, 9, func(ci: Control):
			ci.draw_rect(Rect2(0, 0, 9, 9), LuckyWheel.INK)
			ci.draw_rect(Rect2(1, 1, 7, 7), col)
			ci.draw_rect(Rect2(1, 1, 7, 1), col.lightened(0.3)))
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		g.add_child(sw)
		g.add_child(CreditCoin.widget_text("+%d" % pp, 8, UI.GOLD if pp == 15 else UI.TEXT, 10))
		g.add_child(UI.label("%s SLICES" % row[1], 8, UI.DIM, "caps"))
		g.add_child(UI.label("%.1f%%" % (LuckySpin.probability(pp) * 100.0), 8, UI.GOLD if pp == 15 else UI.DIM, "caps"))
	return g

## TEST AD & SPIN's Developer row (editor only).
func _dev_row() -> Control:
	var box := UI.vbox(2)
	box.name = "SpinDev"
	var r := UI.hbox(3)
	box.add_child(r)
	_ad_btn = Deck.button("", func():
		var order := ["reward", "cancel", "fail", "none"]
		Ads.test_next = order[(order.find(Ads.test_next) + 1) % order.size()]
		_refresh(), "ghost", 0, 16)
	_ad_btn.name = "DevAd"
	r.add_child(_ad_btn)
	_force_btn = Deck.button("", func():
		Store.spin_test_force = _next_force(Store.spin_test_force)
		_refresh(), "ghost", 0, 16)
	_force_btn.name = "DevForce"
	r.add_child(_force_btn)
	var hr := Deck.button("+1 HOUR", func():
		Store.spin_test_skip += 3600
		_refresh(), "ghost", 0, 16)
	hr.name = "DevHour"
	r.add_child(hr)
	for b in [_ad_btn, _force_btn, hr]:
		b.add_theme_font_size_override("font_size", 8)
	_wallet = UI.label("", 8, UI.WARN, "caps")
	_wallet.name = "DevWallet"
	box.add_child(_wallet)
	return box

## RANDOM -> a 5 -> a 10 -> the 15 -> RANDOM (the first slice of each).
static func _next_force(f: int) -> int:
	var cur := -1 if f < 0 else int(LuckySpin.SEGMENTS[f])
	var nxt := {-1: 5, 5: 10, 10: 15, 15: -1}[cur] as int
	return -1 if nxt < 0 else LuckySpin.SEGMENTS.find(nxt)

func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 0.25:
		_tick = 0.0
		_refresh_status()
	if _blink_t >= 0.0:
		_blink_t += delta
		wheel.blink = int(_blink_t * 8.0) % 2 == 0 and _blink_t < 1.2
		wheel.queue_redraw()
		if _blink_t >= 1.2:
			_blink_t = -1.0
			wheel.blink = true   # (it stays lit)
	if not _confetti.is_empty():
		for c in _confetti:
			c[1].y += 220.0 * delta
			c[0] += c[1] * delta
		_confetti = _confetti.filter(func(c): return c[0].y < size.y + 4)
		_fx.queue_redraw()

func _refresh() -> void:
	if not is_instance_valid(_btn):
		return
	_refresh_status()
	if test:
		_ad_btn.text = "AD: %s" % {"reward": "REWARD", "cancel": "CLOSED EARLY", "fail": "FAILS", "none": "NO AD"}[Ads.test_next]
		_force_btn.text = "WIN: %s" % ("RANDOM" if Store.spin_test_force < 0 else "%d PP" % int(LuckySpin.SEGMENTS[Store.spin_test_force]))
		_wallet.text = "TEST WALLET: %d PP  (NOT YOUR REAL POLO POINTS)" % Store.spin_test_bank.balance

func _refresh_status() -> void:
	var st := Store.spin_state(test)
	var now := Store.spin_now(test)
	var n := st.available(now)
	_status.text = st.status_text(now)
	_status.add_theme_color_override("font_color", UI.GOOD if n > 0 else UI.DIM)
	var busy := wheel.spinning() or _waiting or Ads.busy()
	var ok := n > 0 and Ads.ad_ready() and not busy
	_btn.disabled = not ok
	if _waiting or Ads.busy():
		_btn.text = "AD PLAYING..."
	elif wheel.spinning():
		_btn.text = "SPINNING..."
	elif n <= 0:
		_btn.text = "COME BACK SOON"
	elif not Ads.ad_ready():
		_btn.text = "NO AD AVAILABLE"
	else:
		_btn.text = "TEST AD & SPIN" if test else "WATCH AD & SPIN"
	if n > 0 and not Ads.ad_ready() and not busy and _note.text == "":
		_note.text = "Ads aren't available on this device right now." if Ads.backend_name == "none" else "No ad is ready yet. Try again in a minute."
		_note.set_meta("auto", true)
	elif _note.get_meta("auto", false) and (Ads.ad_ready() or n <= 0):
		_note.text = ""
		_note.set_meta("auto", false)

func _spin() -> void:
	if wheel.spinning() or _waiting:
		return
	_clear_result()
	_note.text = ""
	_note.set_meta("auto", false)
	if Store.spin_state(test).available(Store.spin_now(test)) <= 0:
		return
	if not Ads.show_rewarded():
		_note.text = "No ad is ready yet. Try again in a minute."
		_refresh()
		return
	_waiting = true
	_refresh()

## Store paid a spin (from this panel's ad, or one that finished while it was opening).
func _claimed(res: Dictionary) -> void:
	if bool(res.get("test", false)) != test:
		return
	_waiting = false
	_clear_result()
	_result = res
	wheel.spin_to(int(res.seg), bool(Game.settings.get("reduce_motion", false)))
	_refresh()

func _ad_done(ok: bool, message: String) -> void:
	_waiting = false
	if not ok and message != "":
		_note.text = message
		_note.set_meta("auto", false)
		Sfx.play("error")
	_refresh()

func _clear_result() -> void:
	if is_instance_valid(_banner):
		_banner.queue_free()
	_banner = null
	_confetti.clear()
	wheel.win = -1
	wheel.blink = false
	wheel.queue_redraw()

## The wheel stopped: the slice flashes, the win is announced, and the shop's balance moves.
func _landed(seg: int) -> void:
	var pp := int(LuckySpin.SEGMENTS[seg])
	_blink_t = 0.0
	_show_banner(pp)
	if pp >= 15:
		Sfx.play("record")
		_burst()
	elif pp >= 10:
		Sfx.play("levelup")
	else:
		Sfx.play("coins")
	Store.spin_shown(test)
	_result = {}
	_refresh()

## YOU WON +5 PP! / YOU WON +10 PP! / JACKPOT! +15 PP!: the game's reward plate, over the wheel.
func _show_banner(pp: int) -> void:
	var jack := pp >= 15
	var t := "JACKPOT! +%d PP!" % pp if jack else "YOU WON +%d PP!" % pp
	var b := PanelContainer.new()
	b.name = "SpinWin"
	# the jackpot: a solid gold plate, ink letters, a pale-gold doubled edge; the rest: navy, gold edge
	b.add_theme_stylebox_override("panel", UI.chunky(UI.GOLD, Color("fff2a8"), true, false, 6, 2, UI.BEVEL_DOUBLE) if jack
		else UI.chunky(Color("0a1440"), UI.GOLD, true, false, 6, 2, UI.BEVEL_RAISED))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UI.label(t, 16, UI.INK if jack else UI.GOLD, "big")
	l.name = "SpinWinText"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not jack:
		l.add_theme_color_override("font_shadow_color", Color(0.01, 0.03, 0.12, 0.9))
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)
	b.add_child(l)
	add_child(b)
	move_child(b, get_child_count() - 2)   # (under the confetti)
	_banner = b
	var place := func():
		if not is_instance_valid(b) or not is_instance_valid(wheel):
			return
		var wr := wheel.get_global_rect()
		var bs := b.get_combined_minimum_size()
		b.position = (Vector2(wr.get_center().x - bs.x * 0.5, wr.end.y - bs.y + 2) - get_global_rect().position).round()
	place.call_deferred()
	if Juice.enabled():
		b.modulate.a = 0.0
		create_tween().tween_property(b, "modulate:a", 1.0, 0.12)

## The jackpot's confetti: gold, white and cyan pixels from above the wheel.
func _burst() -> void:
	if bool(Game.settings.get("reduce_motion", false)):
		return
	var c := wheel.get_global_rect().get_center() - get_global_rect().position
	var cols := [UI.GOLD, Color.WHITE, LuckyWheel.C10, Color("fff2a8")]
	for i in 46:
		var a := randf_range(-PI * 0.9, -PI * 0.1)
		_confetti.append([c + Vector2(randf_range(-20, 20), -30), Vector2(cos(a), sin(a)) * randf_range(60, 150), cols[i % cols.size()]])

func _draw_fx(ci: Control) -> void:
	for c in _confetti:
		var p: Vector2 = (c[0] as Vector2).floor()
		ci.draw_rect(Rect2(p, Vector2(2, 2)), c[2])
