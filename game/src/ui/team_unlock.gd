class_name TeamUnlock
extends Control
## THE ROAD TO GLORY's unlock show (it replaces the old ACHIEVEMENT UNLOCKED! popup): the hub plays
## it for a queued "achievement" ({id, title, count}) through Game.achievement_dialog.
##   1. the screen dims, ACHIEVEMENT UNLOCKED! slams down (a flash, a shake), the achievement's name
##   2. the newly opened tier's schools rise in a row as dark silhouettes, each under a gold padlock
##   3. one by one the padlocks rattle, spring open and fly off: the card flashes, the logo comes
##      up in its colours with a burst of sparks (each one a step higher in pitch)
##   4. "N NEW PROGRAMS AVAILABLE!" lands, gold rays turn behind the row, confetti, then OK
## A tap before the end skips straight to it. With Reduce motion (or in tests, Juice.enabled off)
## it opens at its end state: every label and the OK button are there from the first frame.
## Developer Tools' PREVIEW TEAM UNLOCK ANIMATION plays it for each tier in turn (preview):
## nothing is awarded or saved.

const CARD := Vector2(46, 46)
const GAP := 4.0
const LOGO := 40
const T_HEAD := 0.2        # the headline starts falling
const T_LAND := 0.38       # ...and lands
const T_TITLE := 0.55
const T_TIER := 0.8
const T_CARDS := 0.9
const CARD_STAGGER := 0.07
const T_LOCKS := 1.6       # the first padlock opens
const LOCK_STEP := 0.26
const RATTLE := 0.28
const LOCKED := Color(0.07, 0.09, 0.22)

static var _preview_tier := 1

var q := {}
var done := Callable()
var ids: Array = []
var t := 0.0
var t_final := 0.0
var t_end := 0.0
var shake := 0.0
var flash := 0.0
var _fired := {}
var _parts: Array = []     # sparks/confetti: {p, v, life, max, col, s, g}
var _rng := RandomNumberGenerator.new()
var _closed := false
var _motion := true

var stage: Control
var head: Label
var title: Label
var count_l: Label
var sub: Label
var ok: Button

## The show for `q` over Game.overlay; `cb` runs when it's closed with OK.
static func play(parent: Node, q_: Dictionary, cb: Callable) -> TeamUnlock:
	var s := TeamUnlock.new()
	s.name = "TeamUnlock"
	s.q = q_
	s.done = cb
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.theme = UI.theme
	s._motion = Juice.enabled()
	s._read()
	parent.add_child(s)
	s._build()
	return s

## Developer Tools: each press shows the next tier's unlock (2..5, round again). Nothing is saved.
static func preview() -> TeamUnlock:
	if Game.overlay == null:
		return null
	_preview_tier = (_preview_tier - 1) % 4 + 2
	var a := Progression.achievement_for_tier(_preview_tier)
	var n: int = Game.progression().schools_in_tier(_preview_tier).size()
	return play(Game.overlay, {"type": "achievement", "id": a.id, "title": a.title, "count": n}, Callable())

## The tier's schools, strongest first (the tier the achievement opens: they're all new with it).
func _read() -> void:
	_rng.randomize()
	var tier := int(Progression.achievement(String(q.get("id", ""))).get("tier", 0))
	var mine: Array = Game.progression().schools_in_tier(tier) if tier > 0 else []
	if int(q.get("count", 0)) > 0:
		for s in Progression.by_rating():
			if String(s.short) in mine:
				ids.append(String(s.short))
	var last := T_LOCKS + (ids.size() - 1) * LOCK_STEP if not ids.is_empty() else 0.9
	t_final = last + 0.5
	t_end = t_final + 0.7

func _tier() -> int:
	return int(Progression.achievement(String(q.get("id", ""))).get("tier", 0))

# ------------------------------------------------------------------ building
func _build() -> void:
	stage = UI.canvas(0, 0, _draw_stage)
	stage.name = "Stage"
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(stage)
	head = _label("ACHIEVEMENT UNLOCKED!", 20, UI.GOLD, "big")
	title = _label(String(q.get("title", "")), 16, UI.TEXT, "big")
	var n := int(q.get("count", 0))
	count_l = _label("%d NEW PROGRAM%s AVAILABLE!" % [n, "" if n == 1 else "S"], 16, UI.GOLD, "big") if n > 0 else null
	sub = _label("Start a new career at any of them from PICK YOUR SCHOOL.", 8, UI.DIM, "body")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ok = UI.button("OK", _close, "primary", 80, 22)
	ok.name = "OK"
	stage.add_child(ok)
	resized.connect(_layout)
	_layout()
	Sfx.play("card")
	if not _motion:
		_skip(false)
	_apply()

func _label(text: String, size: int, col: Color, font: String) -> Label:
	var l := UI.label(text, size, col, font)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font == "big":
		l.add_theme_color_override("font_outline_color", UI.INK)
		l.add_theme_constant_override("outline_size", 2)
	stage.add_child(l)
	return l

## Top of the block: the whole show is ~222 px tall, centred in the window.
func _top() -> float:
	return floorf(maxf(0.0, (_vs().y - 228.0) * 0.5))

func _vs() -> Vector2:
	return size if size.x > 0 else get_viewport_rect().size

func _row_y() -> float:
	return _top() + 83.0

func _layout() -> void:
	var vs := _vs()
	var y := _top()
	for pair in [[head, 10.0, 24.0], [title, 36.0, 20.0], [count_l, 142.0, 20.0], [sub, 164.0, 22.0]]:
		var l: Label = pair[0]
		if l == null:
			continue
		var w := vs.x if l != sub else minf(260.0, vs.x - 32.0)
		l.position = Vector2(floorf((vs.x - w) * 0.5), y + float(pair[1]))
		l.size = Vector2(w, float(pair[2]))
		l.pivot_offset = l.size * 0.5
	ok.position = Vector2(floorf((vs.x - 80.0) * 0.5), y + 192.0)
	ok.size = Vector2(80, 22)

func _card_pos(i: int) -> Vector2:
	var w := ids.size() * CARD.x + (ids.size() - 1) * GAP
	return Vector2(floorf((_vs().x - w) * 0.5) + i * (CARD.x + GAP), _row_y())

# ------------------------------------------------------------------ the timeline
func _process(delta: float) -> void:
	if _closed:
		return
	if t < t_end:
		t = minf(t + delta, t_end)
	_events()
	shake = maxf(0.0, shake - delta * 18.0)
	flash = maxf(0.0, flash - delta * 3.5)
	if _motion and t >= t_final and _rng.randf() < 0.5:
		_confetti(1)
	for p in _parts:
		p.life -= delta
		p.v.y += float(p.g) * delta
		p.v *= 0.985
		p.p += p.v * delta
	_parts = _parts.filter(func(p): return p.life > 0.0)
	_apply()

func _once(key: String, at: float) -> bool:
	if t < at or _fired.has(key):
		return false
	_fired[key] = true
	return true

func _events() -> void:
	if _once("land", T_LAND):
		shake = 4.0
		flash = 0.6
		Sfx.play("bang", 1.0, -6.0)
	for i in ids.size():
		var u := T_LOCKS + i * LOCK_STEP
		if _once("rattle%d" % i, u - RATTLE):
			Sfx.play("click", 0.8 + i * 0.05, -6.0)
		if _once("open%d" % i, u):
			Sfx.play("coins", 1.0 + i * 0.08, -2.0)
			shake = maxf(shake, 1.5)
			_burst(_card_pos(i) + CARD * 0.5, Colleges.school(String(ids[i])))
	if _once("final", t_final):
		shake = maxf(shake, 3.0)
		flash = maxf(flash, 0.35)
		Sfx.play("levelup")
		Sfx.play("cheer", 1.0, -8.0)
		if _motion:
			_confetti(40)

## Straight to the end: every lock open, the button up. `sounds` false: quietly (Reduce motion).
func _skip(sounds: bool = true) -> void:
	t = t_end
	_fired["land"] = true
	for i in ids.size():
		_fired["rattle%d" % i] = true
		_fired["open%d" % i] = true
	if not sounds:
		_fired["final"] = true
	shake = 0.0
	flash = 0.0

func _gui_input(e: InputEvent) -> void:
	var tap: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if tap and t < t_final:
		_skip()
		accept_event()

func _unhandled_input(e: InputEvent) -> void:
	if _closed or not e.is_pressed() or e.is_echo():
		return
	if e.is_action("ui_accept"):
		if t < t_final:
			_skip()
		else:
			_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	if _closed or is_queued_for_deletion():
		return   # one close per notification, even with two taps in the same frame
	_closed = true
	queue_free()
	if done.is_valid():
		done.call()

## Labels and the button follow the clock (scale/alpha only; positions are the layout's).
func _apply() -> void:
	stage.position = Vector2(_rng.randf_range(-shake, shake), _rng.randf_range(-shake, shake)).round() if shake > 0.0 else Vector2.ZERO
	var k := _ease(t, T_HEAD, T_LAND)
	head.modulate.a = k
	head.scale = Vector2.ONE * lerpf(3.0, 1.0, k)
	var kt := _ease(t, T_TITLE, T_TITLE + 0.22, true)
	title.modulate.a = clampf((t - T_TITLE) / 0.15, 0.0, 1.0)
	title.scale = Vector2(lerpf(0.4, 1.0, kt), lerpf(0.4, 1.0, kt))
	if count_l != null:
		var kc := _ease(t, t_final, t_final + 0.2, true)
		count_l.scale = Vector2.ONE * lerpf(2.2, 1.0, kc)
		# a gentle gold pulse once it's in
		var glow := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006) if _motion else 0.0
		count_l.modulate = Color(1.0 + 0.3 * glow, 1.0 + 0.3 * glow, 1.0 + 0.1 * glow, clampf((t - t_final) / 0.1, 0.0, 1.0))
	var ks := clampf((t - t_final - 0.3) / 0.3, 0.0, 1.0)
	sub.modulate.a = ks
	ok.modulate.a = ks
	ok.mouse_filter = Control.MOUSE_FILTER_STOP if ks >= 1.0 else Control.MOUSE_FILTER_IGNORE
	stage.queue_redraw()

## 0..1 from a to b, eased out (back: a little overshoot).
func _ease(now: float, a: float, b: float, back: bool = false) -> float:
	var x := clampf((now - a) / maxf(0.001, b - a), 0.0, 1.0)
	if back:
		var c1 := 1.70158
		return 1.0 + (c1 + 1.0) * pow(x - 1.0, 3) + c1 * pow(x - 1.0, 2)
	return 1.0 - pow(1.0 - x, 3)

# ------------------------------------------------------------------ particles
func _burst(at: Vector2, school: Dictionary) -> void:
	if not _motion:
		return
	var cols := [UI.GOLD, Color.WHITE, Color(String(school.get("c1", "ffffff"))), Color(String(school.get("c2", "ffd23f")))]
	for k in 18:
		var a := _rng.randf() * TAU
		var sp := _rng.randf_range(50.0, 130.0)
		_parts.append({"p": at, "v": Vector2(cos(a), sin(a)) * sp, "life": _rng.randf_range(0.35, 0.7), "max": 0.7,
			"col": cols[k % cols.size()], "s": 2.0 if k % 3 else 3.0, "g": 160.0})

func _confetti(n: int) -> void:
	var vs := _vs()
	var cols := [UI.GOLD, UI.ACCENT, UI.PINK, UI.GOOD, Color.WHITE]
	for k in n:
		_parts.append({"p": Vector2(_rng.randf() * vs.x, -4.0 - _rng.randf() * 30.0), "v": Vector2(_rng.randf_range(-20, 20), _rng.randf_range(30, 70)),
			"life": 4.0, "max": 4.0, "col": cols[_rng.randi() % cols.size()], "s": 2.0, "g": 10.0})

# ------------------------------------------------------------------ drawing
func _draw_stage(ci: CanvasItem) -> void:
	var vs := _vs()
	# the dim, drawn oversize so the shake never shows an edge
	var dim := clampf(t / 0.25, 0.0, 1.0) * 0.88
	ci.draw_rect(Rect2(Vector2(-8, -8), vs + Vector2(16, 16)), Color(0.01, 0.02, 0.08, dim))
	_draw_rays(ci, vs)
	if not ids.is_empty():
		var kt := clampf((t - T_TIER) / 0.25, 0.0, 1.0)
		if kt > 0.0 and _tier() > 0:
			var tier_txt := "TIER %d  -  %s" % [_tier(), Progression.TIER_NAMES[_tier()]]
			ci.draw_string(UI.font_caps, Vector2(0, _row_y() - 7.0), tier_txt, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 8, Color(UI.DIM, kt))
	for i in ids.size():
		_draw_card(ci, i)
	for p in _parts:
		var a := clampf(float(p.life) / 0.25, 0.0, 1.0)
		ci.draw_rect(Rect2((p.p as Vector2).floor(), Vector2(p.s, p.s)), Color(p.col, a))
	if flash > 0.0:
		ci.draw_rect(Rect2(Vector2(-8, -8), vs + Vector2(16, 16)), Color(1, 1, 0.9, flash * 0.5))

## Turning gold rays behind the row: faint once the cards are up, brighter at the finale.
func _draw_rays(ci: CanvasItem, vs: Vector2) -> void:
	var a := clampf((t - T_CARDS) / 0.5, 0.0, 1.0) * 0.06 + clampf((t - t_final) / 0.3, 0.0, 1.0) * 0.08
	if a <= 0.0:
		return
	var c := Vector2(vs.x * 0.5, _row_y() + CARD.y * 0.5)
	var r := vs.length()
	var spin := Time.get_ticks_msec() * 0.0003 if _motion else 0.0
	for k in 12:
		var a0 := spin + k * TAU / 12.0
		var a1 := a0 + TAU / 30.0
		ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * r, c + Vector2(cos(a1), sin(a1)) * r]), Color(UI.GOLD, a))

func _draw_card(ci: CanvasItem, i: int) -> void:
	var school := Colleges.school(String(ids[i]))
	var t_in := T_CARDS + i * CARD_STAGGER
	if t < t_in:
		return
	var rise := _ease(t, t_in, t_in + 0.3, true)
	var u := T_LOCKS + i * LOCK_STEP
	var open := t >= u
	var since := t - u
	var base := _card_pos(i) + Vector2(0, roundf((1.0 - rise) * 40.0))
	var alpha := clampf((t - t_in) / 0.15, 0.0, 1.0)
	# the pop when it opens: 1.2x settling back over 0.25 s
	var pop := 1.0 + 0.2 * clampf(1.0 - since / 0.25, 0.0, 1.0) if open else 1.0
	var center := base + CARD * 0.5
	ci.draw_set_transform(center, 0.0, Vector2(pop, pop))
	var r := Rect2(-CARD * 0.5, CARD)
	var edge := UI.GOLD if open else Color("3a4370")
	ci.draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.5 * alpha))           # hard shadow
	ci.draw_rect(r, Color(UI.INK, alpha))
	ci.draw_rect(r.grow(-1), Color(edge, alpha))
	ci.draw_rect(r.grow(-2), Color(Color("1d2a6b") if open else Color("10163a"), alpha))
	# the logo: a dark silhouette, then its colours
	var tex := TeamLogo.art_within(school, Vector2i(LOGO, LOGO))
	var lr := Rect2(Vector2(-LOGO * 0.5, -LOGO * 0.5), Vector2(LOGO, LOGO))
	var tint := Color(1, 1, 1, alpha) if open else Color(LOCKED, alpha)
	if tex != null:
		var dim := Vector2(tex.get_width(), tex.get_height())
		ci.draw_texture_rect(tex, Rect2((lr.position + (lr.size - dim) * 0.5).floor(), dim), false, tint)
	else:
		var tt := TeamLogo.texture(school)
		ci.draw_texture_rect(tt, Rect2(lr.position, lr.size), false, tint)
	# the white flash as it opens
	if open and since < 0.25:
		ci.draw_rect(r, Color(1, 1, 1, (1.0 - since / 0.25) * 0.85))
	ci.draw_set_transform(Vector2.ZERO)
	# the padlock: rattling before, then springing open and flying off
	var lock_at := center + Vector2(0, 2)
	if not open:
		var jig := 0.0
		if t > u - RATTLE:
			jig = sin((t - (u - RATTLE)) * 70.0) * 2.0
		_draw_lock(ci, lock_at + Vector2(roundf(jig), 0), 0.0, false, alpha)
	elif since < 0.55 and _motion:
		var fly := since / 0.55
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := lock_at + Vector2(side * 30.0 * fly, -60.0 * fly + 110.0 * fly * fly)
		_draw_lock(ci, p, side * fly * 2.5, true, 1.0 - fly)

## A 16 x 13 gold padlock body under a U shackle; open, the shackle springs up and its left leg
## comes clear of the body.
func _draw_lock(ci: CanvasItem, at: Vector2, rot: float, open: bool, a: float) -> void:
	ci.draw_set_transform(at.floor(), rot, Vector2.ONE)
	var ink := Color(UI.INK, a)
	var steel := Color(Color("d3dbe6"), a)
	var top := -16.0 if open else -12.0
	var left_h := 8.0                       # closed: both legs reach the body (y -4)
	var right_h := -4.0 - top
	# shackle: ink outline, then a steel line
	ci.draw_rect(Rect2(-6, top, 12, 3), ink)
	ci.draw_rect(Rect2(-6, top, 3, left_h), ink)
	ci.draw_rect(Rect2(3, top, 3, right_h), ink)
	ci.draw_rect(Rect2(-5, top + 1, 10, 1), steel)
	ci.draw_rect(Rect2(-5, top + 1, 1, left_h - 2), steel)
	ci.draw_rect(Rect2(4, top + 1, 1, right_h - 1), steel)
	# body
	ci.draw_rect(Rect2(-8, -4, 16, 13), ink)
	ci.draw_rect(Rect2(-7, -3, 14, 11), Color(UI.GOLD, a))
	ci.draw_rect(Rect2(-7, 6, 14, 2), Color(Color("b8860b"), a))
	ci.draw_rect(Rect2(-6, -3, 12, 1), Color(1, 1, 0.8, a))
	# keyhole
	ci.draw_rect(Rect2(-2, -1, 4, 3), ink)
	ci.draw_rect(Rect2(-1, 2, 2, 3), ink)
	ci.draw_set_transform(Vector2.ZERO)
