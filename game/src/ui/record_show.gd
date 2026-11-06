class_name RecordShow
extends Control
## THE RECORD CELEBRATION: a record your team just broke (Records.breaks), one at a time over
## whatever screen it's on (the game summary). BAR-DOWN!'s lettering and pop (BarHit):
##   0.00  the screen dims, gold rays turn slowly behind it
##   0.10  NEW NCSA RECORD! (gold) / NEW SCHOOL RECORD! (white and blue) pops in, shakes; the
##         record sound; confetti starts falling
##   0.40  the record's name on a navy plate
##   0.55  the number counts up from the old mark to the new one, lands with a flash
##   1.40  who set it (and for whom)
##   1.65  the mark it beat, struck through
##   1.90  TAP TO CONTINUE (on its own after AUTO s)
## Tap: the next record, or done (finished, then it frees itself). Nothing here changes a record:
## it only shows what it's given. With reduced motion: no rays turning, no confetti.

signal finished

const AUTO := 4.2
const MIN_TAP := 0.6            # s before a tap moves on (so a tap meant for the screen under it doesn't skip it)
const TITLE_AT := 0.10
const PLATE_AT := 0.40
const COUNT_AT := 0.55
const COUNT_END := 1.30
const HOLDER_AT := 1.40
const PREV_AT := 1.65
const TAP_AT := 1.90
const GOLD := Color("ffd83d")
const WHITE := Color("ffffff")

var items: Array = []           # Records.breaks entries
var i := 0
var t := 0.0
var motion := true
var bits: Array = []
var _sound := false

## Plays `items` over `parent` (full rect); `done` once the last is dismissed. `with_motion` null:
## as Settings say (Juice.enabled); true in the Developer Mode preview.
static func play(parent: Node, list: Array, done: Callable = Callable(), with_motion: Variant = null) -> RecordShow:
	var rs := RecordShow.new()
	rs.items = list
	rs.motion = Juice.enabled() if with_motion == null else bool(with_motion)
	rs.set_anchors_preset(Control.PRESET_FULL_RECT)
	rs.mouse_filter = Control.MOUSE_FILTER_STOP
	rs.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if done.is_valid():
		rs.finished.connect(done)
	parent.add_child(rs)
	rs._start()
	return rs

func _start() -> void:
	t = 0.0
	_sound = false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([i, str(items[i].get("key", "")), int(items[i].get("value", 0))])
	bits = []
	for k in 70:
		var cols := [GOLD, WHITE, Color("45dfff"), Color("ff4545")] if _ncsa() else [WHITE, Color("45dfff"), GOLD]
		bits.append({"x": rng.randf_range(0.0, 1.0), "y": rng.randf_range(-0.6, -0.02), "vy": rng.randf_range(40.0, 85.0),
			"sway": rng.randf_range(0.0, TAU), "col": cols[k % cols.size()], "size": 3 if k % 5 == 0 else 2, "delay": rng.randf_range(0.0, 0.5)})

func _ncsa() -> bool:
	return String(items[i].get("level", "school")) == "ncsa"

func _process(dt: float) -> void:
	if items.is_empty():
		return
	t += dt
	if not _sound and t >= TITLE_AT:
		_sound = true
		Sfx.play("record")
	if t >= AUTO:
		_next()
	queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	var tap: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed)
	if tap:
		accept_event()
		if t >= MIN_TAP:
			_next()

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_accept") or ev.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if t >= MIN_TAP:
			_next()

## The next record, or done.
func _next() -> void:
	i += 1
	if i >= items.size():
		finished.emit()
		queue_free()
		set_process(false)
		items = []
		return
	_start()

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	if items.is_empty() or i >= items.size():
		return
	var e: Dictionary = items[i]
	var sz := size
	var ncsa := _ncsa()
	var fade := clampf(t / 0.2, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.02, 0.04, 0.12, 0.9 * fade))
	var cx := roundf(sz.x * 0.5)
	var cy := roundf(sz.y * 0.42)
	_rays(Vector2(cx, cy), fade, ncsa)
	if motion and t >= TITLE_AT:
		_confetti(sz)
	# the card the number and the names sit on
	if t >= PLATE_AT:
		var u := clampf((t - PLATE_AT) / 0.15, 0.0, 1.0)
		var card := Rect2(roundf(cx - 150.0), roundf(cy - 24.0), 300.0, 90.0)
		draw_rect(card, Color(Deck.NAVY, 0.92 * u))
		draw_rect(card, Color(GOLD if ncsa else Color("45dfff"), 0.6 * u), false, 1.0)
	# the word
	if t >= TITLE_AT:
		var s := t - TITLE_AT
		var sc := BarHit.pop(s) if s < BarHit.OUT_AT else 1.0
		var word := "NEW NCSA RECORD!" if ncsa else "NEW SCHOOL RECORD!"
		var fs := BarHit.word_fs(word, sc, sz.x - 30.0)
		var col := GOLD if ncsa else WHITE
		var sh: Array = [BarHit.ORANGE, BarHit.RED] if ncsa else [Color("2a7fe0"), Color("1a2f8a")]
		BarHit.lettering(self, Vector2(cx + BarHit.shake_x(s), cy - 62.0), word, fs, 1.0, col, sh[0], sh[1])
	# the record's name on a plate
	if t >= PLATE_AT:
		var u := clampf((t - PLATE_AT) / 0.15, 0.0, 1.0)
		var name := String(e.get("name", "")).to_upper()
		var w := UI.text_width(name, 16, "big") + 28.0
		var r := Rect2(roundf(cx - w * 0.5), roundf(cy - 34.0 + (1.0 - u) * 8.0), roundf(w), 20.0)
		draw_rect(r, Color(Deck.NAVY, u))
		draw_rect(r, Color(GOLD if ncsa else Color("45dfff"), u), false, 1.0)
		UI.text(self, r.position + Vector2(0, 14), name, 16, Color(WHITE, u), "big", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	# the number, counting up from the old mark
	if t >= COUNT_AT:
		var prev := int((e.get("prev", {}) as Dictionary).get("v", 0))
		var value := int(e.get("value", 0))
		var k := clampf((t - COUNT_AT) / (COUNT_END - COUNT_AT), 0.0, 1.0)
		var shown := roundi(lerpf(prev, value, 1.0 - pow(1.0 - k, 2.0)))
		var land := t - COUNT_END
		var pop := 1.0
		if land >= 0.0 and land < 0.25:
			pop = 1.0 + 0.35 * sin(land / 0.25 * PI)
		var fs := int(roundf(40.0 * pop))
		var txt := str(shown)
		var tw := UI.text_width(txt, fs, "big")
		if land >= 0.0 and land < 0.12:
			draw_circle(Vector2(cx, cy + 12.0), 34.0 * (1.0 - land / 0.12) + 6.0, Color(1, 1, 1, 0.35 * (1.0 - land / 0.12)))
		UI.text(self, Vector2(roundf(cx - tw * 0.5) + 2, roundf(cy + 26.0) + 2), txt, fs, Color(0, 0, 0, 0.6), "big")
		UI.text(self, Vector2(roundf(cx - tw * 0.5), roundf(cy + 26.0)), txt, fs, GOLD if ncsa else WHITE, "big")
	# who set it
	if t >= HOLDER_AT:
		var a := clampf((t - HOLDER_AT) / 0.2, 0.0, 1.0)
		var holder := String(e.get("holder", "")).to_upper()
		var team := String(e.get("team", "")).to_upper()
		var who := holder if holder == team or team == "" else "%s  -  %s" % [holder, team]
		UI.text(self, Vector2(0, roundf(cy + 44.0)), who, 8, Color(Color("5cc8ff"), a), "caps", HORIZONTAL_ALIGNMENT_CENTER, sz.x)
	# the mark it beat, struck through
	if t >= PREV_AT:
		var a := clampf((t - PREV_AT) / 0.2, 0.0, 1.0)
		var p: Dictionary = e.get("prev", {})
		var old := "PREVIOUS: NOT SET" if int(p.get("v", 0)) <= 0 else "PREVIOUS: %d  BY %s (%s)" % [int(p.get("v", 0)), String(p.get("name", "")).to_upper(), str(p.get("year", ""))]
		var ow := UI.text_width(old, 8, "caps")
		var y := roundf(cy + 57.0)
		UI.text(self, Vector2(0, y), old, 8, Color(UI.DIM, a), "caps", HORIZONTAL_ALIGNMENT_CENTER, sz.x)
		if int(p.get("v", 0)) > 0:
			var strike := clampf((t - PREV_AT - 0.15) / 0.2, 0.0, 1.0)
			draw_rect(Rect2(roundf(cx - ow * 0.5), y - 3.0, roundf(ow * strike), 1.0), Color(Color("ff4545"), a))
	if t >= TAP_AT:
		var blink := 1.0 if int(t * 2.0) % 2 == 0 else 0.55
		var more := "  (%d/%d)" % [i + 1, items.size()] if items.size() > 1 else ""
		UI.text(self, Vector2(0, sz.y - 10.0), "TAP TO CONTINUE" + more, 8, Color(WHITE, blink), "caps", HORIZONTAL_ALIGNMENT_CENTER, sz.x)

## Gold (NCSA) or blue (school) rays turning behind it all.
func _rays(c: Vector2, a: float, ncsa: bool) -> void:
	var col := Color(GOLD, 0.10 * a) if ncsa else Color(Color("45dfff"), 0.08 * a)
	var turn := t * 0.25 if motion else 0.0
	var n := 12
	for k in n:
		var a0 := turn + k * TAU / n
		var a1 := a0 + TAU / n * 0.5
		var far := 400.0
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * far, c + Vector2(cos(a1), sin(a1)) * far]), col)

func _confetti(sz: Vector2) -> void:
	var s := t - TITLE_AT
	for b in bits:
		var u := s - float(b.delay)
		if u < 0.0:
			continue
		var y := float(b.y) * sz.y + u * float(b.vy)
		if y > sz.y:
			continue
		var x := float(b.x) * sz.x + sin(u * 3.0 + float(b.sway)) * 6.0
		draw_rect(Rect2(roundf(x), roundf(y), float(b.size), float(b.size)), b.col)
