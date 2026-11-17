extends Control
## DEVELOPER ACCESS: Settings' DEV button opens this popup over the page. Four masked slots, a
## number pad (0-9, CLR, DEL), CANCEL and UNLOCK; the keyboard's digits, Backspace, Enter and
## Escape work too. Never more than four digits. The code is checked by DevGate (never shown or
## kept here): right, the DEV screen opens at once; wrong, INCORRECT CODE in red and the digits clear.

const RED := Color("ff5a5a")

var entered := ""
var _slots: Control
var _status: Label
var _panel: PanelContainer

## Opens the popup on the game's overlay.
static func open() -> Control:
	var pad = (load("res://src/ui/dev_pad.gd") as Script).new()
	pad.name = "DevPad"
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # (before it's in: the whole screen)
	Game.overlay.add_child(pad)
	return pad

func _ready() -> void:
	theme = UI.theme
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "Popup"
	_panel.add_theme_stylebox_override("panel", UI.popup_box("info"))
	_panel.custom_minimum_size = Vector2(156, 0)
	center.add_child(_panel)
	var v := UI.vbox(4)
	_panel.add_child(v)
	var plate := PanelContainer.new()
	plate.name = "TitlePlate"
	plate.add_theme_stylebox_override("panel", UI.popup_plate("info"))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UI.label("DEVELOPER ACCESS", 16, UI.GOLD, "big")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(t)
	v.add_child(plate)
	var sc := CenterContainer.new()
	_slots = UI.canvas(4 * 18 + 3 * 4, 18, _draw_slots)
	_slots.name = "Slots"
	sc.add_child(_slots)
	v.add_child(sc)
	_status = UI.label(" ", 8, UI.DIM, "caps")
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_status)
	var g := GridContainer.new()
	g.name = "Keys"
	g.columns = 3
	g.add_theme_constant_override("h_separation", 3)
	g.add_theme_constant_override("v_separation", 3)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "CLR", "0", "DEL"]:
		var key: String = k
		var b: Button
		if key == "CLR":
			b = Deck.button("CLR", clear_digits, "ghost", 0, 18)
			b.name = "Clear"
		elif key == "DEL":
			b = Deck.button("DEL", backspace, "ghost", 0, 18)
			b.name = "Backspace"
		else:
			b = Deck.button(key, func(): add_digit(key), "normal", 0, 18)
			b.name = "Key" + key
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(b)
	v.add_child(g)
	var row := UI.hbox(4)
	var cancel := Deck.button("CANCEL", cancel, "ghost", 0, 20)
	cancel.name = "Cancel"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	var ok := Deck.button("UNLOCK", unlock, "primary", 0, 20)
	ok.name = "Unlock"
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ok)
	v.add_child(row)
	Sfx.play("card")
	if Juice.enabled():
		_panel.pivot_offset = Vector2(_panel.custom_minimum_size.x / 2.0, 60)
		_panel.scale = Vector2(0.9, 0.9)
		create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Four slots: an entered digit is a solid pixel dot (never the digit), the next one gold-edged.
func _draw_slots(ci: Control) -> void:
	for i in DevGate.CODE_LEN:
		var r := Rect2(i * 22, 0, 18, 18)
		var edge := UI.GOLD if i == entered.length() else Color(1, 1, 1, 0.55)
		ci.draw_rect(r, Color(0, 0, 0.12, 0.55))
		ci.draw_rect(r, edge, false, 1.0)
		ci.draw_rect(Rect2(r.position + Vector2(1, r.size.y - 2), Vector2(r.size.x - 2, 1)), Color(1, 1, 1, 0.12))
		if i < entered.length():
			ci.draw_rect(Rect2(r.position + Vector2(6, 6), Vector2(6, 6)), UI.TEXT)
			ci.draw_rect(Rect2(r.position + Vector2(7, 12), Vector2(6, 1)), Color(0, 0, 0.15, 0.6))

func _set_status(t: String, col: Color) -> void:
	_status.text = t if t != "" else " "
	_status.add_theme_color_override("font_color", col)

func add_digit(d: String) -> void:
	if entered.length() >= DevGate.CODE_LEN or not d.is_valid_int() or d.length() != 1:
		return
	entered += d
	_set_status("", UI.DIM)
	_slots.queue_redraw()

func backspace() -> void:
	if entered != "":
		entered = entered.left(entered.length() - 1)
		_slots.queue_redraw()

func clear_digits() -> void:
	entered = ""
	_slots.queue_redraw()

func cancel() -> void:
	entered = ""
	queue_free()

## The code checked (DevGate): right, the DEV screen; wrong, INCORRECT CODE and the digits clear.
func unlock() -> void:
	if is_queued_for_deletion():
		return
	if DevGate.try_unlock(entered):
		entered = ""
		queue_free()
		Sfx.play("confirm")
		Game.goto(DevGate.SCREEN)
		return
	entered = ""
	_slots.queue_redraw()
	_set_status("INCORRECT CODE", RED)
	Sfx.play("error")
	Juice.pop(_status, 0.15)

func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or is_queued_for_deletion():
		return
	var k := (ev as InputEventKey).keycode
	if k >= KEY_0 and k <= KEY_9:
		add_digit(str(k - KEY_0))
	elif k >= KEY_KP_0 and k <= KEY_KP_9:
		add_digit(str(k - KEY_KP_0))
	elif k == KEY_BACKSPACE:
		backspace()
	elif k == KEY_ENTER or k == KEY_KP_ENTER:
		unlock()
	elif k == KEY_ESCAPE:
		cancel()
	else:
		return
	get_viewport().set_input_as_handled()
