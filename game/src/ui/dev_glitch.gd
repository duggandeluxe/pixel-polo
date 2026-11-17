class_name DevGlitch
extends Control
## THE DEV RECRUIT GLITCH: a DEV Recruit's light-blue card (DevArt), digitally unstable. Attached
## (attach) to his Recruiting Market card and to the big card on his profile, keyed on
## PoloPlayer.dev_recruit (DevArt.is_dev) by the screens, never on his name.
##
## It is its own node on the SCREEN (not inside the card, nor inside the page's ScrollContainer), so
## nothing in the card's own containers clips it; it follows the card every frame. Its rect is the
## card's body grown by the room it may glitch into (_room): up to REACH px past each edge, but
## never further than CLEAR px short of anything else on the page (a neighbouring recruit card, the
## projection strip, the Player Attributes and Recruiting panels), and only half the gap toward
## another glitching card, so two DEV cards' escapes never meet. clip_contents holds every pixel
## to that rect.
##
## Intermittent, not constant (_burst_at): time is cut into SLOT-long slots and a few slots, chosen
## by a seeded hash, hold a short burst (now and then a STRONG one). In a burst, at BURST_HZ:
##   bands       horizontal sections of the card shifted 2-5 px (the shift shader reads the screen,
##               nearest, whole pixels), escaping past its edge; a strong burst tints some cyan
##   scanlines   a faint scanline wash and bright interference lines that run out past the border
##   border      the blue edge flickering cyan / white (part of it; all of it in a strong burst)
##   fragments   cyan, electric-blue and white pixels around the edges, inside and outside
## Between bursts, at AMBIENT_HZ, an occasional spark or two near the edge and, rarely, a border flash.
## The big profile card (strength > 1) does all of it a bit harder and around the portrait too
## (a descendant with the "glitch_hot" meta).
##
## Reduce Motion (Juice off): a still glitch-style border instead (a cyan edge broken with white,
## a few fixed fragments at the corners); no shader, nothing moves.

const REACH := 12.0       # how far past the card's border the glitch may reach, room allowing
const CLEAR := 2.0        # what it always leaves free in front of anything else on the page
const SLOT := 0.3         # the burst schedule's slot (s)
const BURST_HZ := 20.0
const AMBIENT_HZ := 6.0
const MAX_BANDS := 8
const META := "dev_glitch"   # on a glitching card: its neighbours leave it half the gap

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 size = vec2(1.0);
uniform int count = 0;
uniform vec4 band[8];   // where the shifted pixels land: x0, y0, x1, y1 (local px)
uniform vec4 info[8];   // dx (local px), cyan tint
void fragment() {
	vec2 p = floor(UV * size);
	// screen uv per local pixel (whatever the window's scale: Detail Mode too)
	float per = dFdx(SCREEN_UV.x) / max(dFdx(UV.x * size.x), 1e-6);
	float a = COLOR.a;
	vec4 outc = vec4(0.0);
	for (int i = 0; i < 8; i++) {
		if (i >= count) { break; }
		vec4 b = band[i];
		if (p.x >= b.x && p.x < b.z && p.y >= b.y && p.y < b.w) {
			vec3 s = texture(screen_tex, SCREEN_UV - vec2(info[i].x * per, 0.0)).rgb;
			outc = vec4(mix(s, vec3(0.224, 0.91, 1.0), info[i].y), a);
		}
	}
	COLOR = outc;
}
"""

## Tests: run the animation though Juice is off (test mode), at a fixed `clock` when it's >= 0.
static var live := false
static var clock := -1.0
static var _shader: Shader

var target: Control
var body_of := Callable()     # (target) -> Rect2 in the target's own coordinates; default its rect
var strength := 1.0           # 1: the market card; more: the profile's big card
var seed_value := 0
var body := Rect2()           # the card's body, in this node's coordinates
var room := Vector4.ZERO      # l, t, r, b: how far past the body it may draw
var _shift: ColorRect
var _sparks: Control
var _key := ""
var _hot: Array = []

## Glitches `target` (a DEV Recruit's card) on `screen`. opts: seed, strength, body (Callable).
static func attach(screen: Control, target: Control, opts: Dictionary = {}) -> DevGlitch:
	var g := DevGlitch.new()
	g.name = "DevGlitch_%s" % target.name
	g.target = target
	g.strength = float(opts.get("strength", 1.0))
	g.seed_value = int(opts.get("seed", 0))
	g.body_of = opts.get("body", Callable())
	target.set_meta(META, true)
	target.set_meta("glitch", g)
	target.tree_exiting.connect(g.queue_free)
	screen.add_child(g)
	return g

## True while it animates (Juice on, or the tests' `live`).
static func moving() -> bool:
	return live or Juice.enabled()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_shift = ColorRect.new()
	_shift.name = "Shift"
	_shift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shift.color = Color.WHITE
	_shift.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	_shift.material = mat
	_shift.visible = false
	add_child(_shift)
	_sparks = Control.new()
	_sparks.name = "Sparks"
	_sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparks.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sparks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sparks.draw.connect(_paint)
	add_child(_sparks)
	_process(0.0)

func _now() -> float:
	return clock if clock >= 0.0 else Time.get_ticks_msec() / 1000.0

func _process(_dt: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var on := target.is_visible_in_tree() and absf(target.get_global_transform().get_scale().x - 1.0) < 0.01
	var bg := _body_global() if on else Rect2()
	var clip := _scroll_clip()
	if on and clip.size.x > 0.0 and not clip.encloses(bg):
		on = false   # (scrolled partly out of the page: no glitch over the header)
	if not on:
		visible = false
		return
	visible = true
	room = _room(bg)
	var allowed := Rect2(bg.position - Vector2(room.x, room.y), bg.size + Vector2(room.x + room.z, room.y + room.w))
	global_position = allowed.position
	size = allowed.size
	body = Rect2(Vector2(room.x, room.y), bg.size)
	modulate.a = _alpha()
	var t := _now()
	var still := not moving()
	var b := {} if still else _burst_at(t)
	var frame := -1 if still else (int(floorf(t * BURST_HZ)) if not b.is_empty() else int(floorf(t * AMBIENT_HZ)))
	var key := "%s|%d|%s|%s" % ["S" if still else ("B" if not b.is_empty() else "A"), frame, str(allowed), str(room)]
	if key != _key:
		_key = key
		_update_shift(b, frame)
		_sparks.queue_redraw()

## The card's body in canvas coordinates, whole pixels.
func _body_global() -> Rect2:
	var r := Rect2(Vector2.ZERO, target.size) if not body_of.is_valid() else (body_of.call(target) as Rect2)
	var xf := target.get_global_transform()
	return Rect2((xf * r.position).floor(), (r.size * xf.get_scale()).floor())

## The nearest ScrollContainer's rect (the page), or an empty one.
func _scroll_clip() -> Rect2:
	var n := target.get_parent()
	while n != null and n != get_parent():
		if n is ScrollContainer:
			return (n as Control).get_global_rect()
		n = n.get_parent()
	return Rect2()

## The modulate the card is drawn with (a screen fading in): its alpha, all the way up.
func _alpha() -> float:
	var a := 1.0
	var n: Node = target
	while n != null and n is CanvasItem:
		a *= (n as CanvasItem).modulate.a * (n as CanvasItem).self_modulate.a if n == target else (n as CanvasItem).modulate.a
		if n == get_parent():
			break
		n = n.get_parent()
	return a

## How far past each edge of `b` it may draw: REACH, the screen's edge, and every other control
## beside the card, at each level up to the screen (its siblings, its containers' siblings):
## CLEAR px short of it, or half the gap toward another glitching card.
func _room(b: Rect2) -> Vector4:
	var scr := (get_parent() as Control).get_global_rect()
	var l := minf(REACH, b.position.x - scr.position.x)
	var tp := minf(REACH, b.position.y - scr.position.y)
	var rt := minf(REACH, scr.end.x - b.end.x)
	var bt := minf(REACH, scr.end.y - b.end.y)
	var n: Node = target
	while n != null and n != get_parent() and n.get_parent() != null:
		for s in n.get_parent().get_children():
			if s == n or s is DevGlitch or not s is Control or not (s as Control).is_visible_in_tree():
				continue
			var o := (s as Control).get_global_rect()
			if o.size.x <= 0.0 or o.size.y <= 0.0 or o.intersects(b):
				continue   # (a background or a container around the card: not beside it)
			var half: bool = (s as Control).has_meta(META)
			var gap := func(d: float) -> float: return maxf(0.0, floorf(d * 0.5) if half else d - CLEAR)
			var rows := o.position.y < b.end.y + REACH and o.end.y > b.position.y - REACH
			var cols := o.position.x < b.end.x + REACH and o.end.x > b.position.x - REACH
			if rows and o.end.x <= b.position.x:
				l = minf(l, gap.call(b.position.x - o.end.x))
			if rows and o.position.x >= b.end.x:
				rt = minf(rt, gap.call(o.position.x - b.end.x))
			if cols and o.end.y <= b.position.y:
				tp = minf(tp, gap.call(b.position.y - o.end.y))
			if cols and o.position.y >= b.end.y:
				bt = minf(bt, gap.call(o.position.y - b.end.y))
		n = n.get_parent()
	return Vector4(maxf(0.0, floorf(l)), maxf(0.0, floorf(tp)), maxf(0.0, floorf(rt)), maxf(0.0, floorf(bt)))

# ------------------------------------------------------------------ the schedule
## The burst at time `t`, or {} between bursts: {k (its slot), strong}.
func _burst_at(t: float) -> Dictionary:
	var k := int(floorf(t / SLOT))
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, k, "slot"])
	var big := strength > 1.0
	if r.randf() >= (0.2 if big else 0.15):
		return {}
	var strong := r.randf() < (0.3 if big else 0.22)
	var dur := r.randf_range(0.2, 0.3) if strong else r.randf_range(0.07, 0.18)
	var start := float(k) * SLOT + r.randf() * maxf(0.0, SLOT - dur)
	if t < start or t >= start + dur:
		return {}
	return {"k": k, "strong": strong}

func _rng(frame: int, what: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, frame, what])
	return r

# ------------------------------------------------------------------ the bands (the shader)
func _update_shift(burst: Dictionary, frame: int) -> void:
	if burst.is_empty():
		_shift.visible = false
		return
	var strong: bool = burst.strong
	var big := strength > 1.0
	var r := _rng(frame, "bands")
	var bands := []
	var n := r.randi_range(3, 5) if strong else r.randi_range(1, 2)
	if big:
		n += 1
	for i in n:
		var h := float(r.randi_range(1, 4 if strong else 2) + (2 if big and r.randf() < 0.5 else 0))
		var y := body.position.y + 1.0 + floorf(r.randf() * maxf(1.0, body.size.y - h - 2.0))
		var dx := float(r.randi_range(3, 5) if strong else r.randi_range(2, 3)) * (1.0 if r.randf() < 0.5 else -1.0)
		var x0 := body.position.x
		var x1 := body.end.x
		var roll := r.randf()
		if roll < 0.3:
			# a section at one edge only (the border breaking out)
			var w := floorf(body.size.x * r.randf_range(0.15, 0.4))
			if dx > 0.0:
				x0 = x1 - w
			else:
				x1 = x0 + w
		elif roll < 0.45:
			# a section inside the card
			var w := floorf(body.size.x * r.randf_range(0.2, 0.5))
			x0 = body.position.x + floorf(r.randf() * (body.size.x - w))
			x1 = x0 + w
		if big and roll >= 0.3:
			h = minf(h, 2.0)   # (across the big card's text: thin tears, so it stays readable)
		var tint := (0.35 if r.randf() < 0.4 else 0.0) if strong else 0.0
		bands.append([Vector4(minf(x0, x0 + dx), y, maxf(x1, x1 + dx), y + h), Vector4(dx, tint, 0, 0)])
	# the profile's portrait: a slice of its edge knocked sideways
	if big:
		for hot in _hot_rects():
			if r.randf() < (0.8 if strong else 0.45):
				var hr: Rect2 = hot
				var h := float(r.randi_range(2, 6))
				var y := hr.position.y + 2.0 + floorf(r.randf() * maxf(1.0, hr.size.y - h - 4.0))
				var dx := float(r.randi_range(2, 5)) * (1.0 if r.randf() < 0.5 else -1.0)
				var w := floorf(hr.size.x * r.randf_range(0.2, 0.45))
				var x0 := hr.end.x - w if dx > 0.0 else hr.position.x
				bands.append([Vector4(minf(x0, x0 + dx), y, maxf(x0 + w, x0 + w + dx), y + h), Vector4(dx, 0.0, 0, 0)])
	bands = bands.slice(0, MAX_BANDS)
	var mat := _shift.material as ShaderMaterial
	var bv := []
	var iv := []
	for x in bands:
		bv.append(x[0])
		iv.append(x[1])
	while bv.size() < MAX_BANDS:
		bv.append(Vector4.ZERO)
		iv.append(Vector4.ZERO)
	mat.set_shader_parameter("size", size)
	mat.set_shader_parameter("count", bands.size())
	mat.set_shader_parameter("band", PackedVector4Array(bv))
	mat.set_shader_parameter("info", PackedVector4Array(iv))
	_shift.visible = not bands.is_empty()

## The portrait's rect (descendants with the "glitch_hot" meta), in this node's coordinates.
func _hot_rects() -> Array:
	_hot = _hot.filter(func(x): return is_instance_valid(x))
	if _hot.is_empty():
		_hot = target.find_children("*", "", true, false).filter(func(x): return x is Control and x.has_meta("glitch_hot"))
	var out := []
	for h in _hot:
		if (h as Control).is_visible_in_tree():
			var gr := (h as Control).get_global_rect()
			out.append(Rect2(gr.position - global_position, gr.size).intersection(body))
	return out.filter(func(x): return (x as Rect2).size.x > 8.0 and (x as Rect2).size.y > 8.0)

# ------------------------------------------------------------------ the pixels
func _paint() -> void:
	var ci := _sparks
	if not moving():
		_paint_still(ci)
		return
	var t := _now()
	var burst := _burst_at(t)
	if burst.is_empty():
		_paint_ambient(ci, int(floorf(t * AMBIENT_HZ)))
	else:
		_paint_burst(ci, int(floorf(t * BURST_HZ)), bool(burst.strong))

static func _col(r: RandomNumberGenerator) -> Color:
	var roll := r.randf()
	return Color.WHITE if roll < 0.3 else (DevArt.CYAN if roll < 0.75 else DevArt.ELECTRIC)

## A fragment near an edge: on a random side, from `inside` px in to its room out.
func _fragment(ci: CanvasItem, r: RandomNumberGenerator, inside: float, out_frac: float = 1.0) -> void:
	var b := body
	var w := float(r.randi_range(1, 3))
	var h := float(r.randi_range(1, 2))
	var side := r.randi_range(0, 3)
	var pos := Vector2.ZERO
	match side:
		0:   # left
			var reach := room.x * out_frac
			pos = Vector2(b.position.x - floorf(r.randf_range(-inside, reach)) - w, b.position.y + floorf(r.randf() * (b.size.y - h)))
		1:   # top
			var reach := room.y * out_frac
			pos = Vector2(b.position.x + floorf(r.randf() * (b.size.x - w)), b.position.y - floorf(r.randf_range(-inside, reach)) - h)
		2:   # right
			var reach := room.z * out_frac
			pos = Vector2(b.end.x + floorf(r.randf_range(-inside, reach)), b.position.y + floorf(r.randf() * (b.size.y - h)))
		_:   # bottom
			var reach := room.w * out_frac
			pos = Vector2(b.position.x + floorf(r.randf() * (b.size.x - w)), b.end.y + floorf(r.randf_range(-inside, reach)))
	ci.draw_rect(Rect2(pos, Vector2(w, h)), _col(r))

## The edge, in `col`, on the sides `mask` keeps (l, t, r, b), with cut corners like DevArt.border.
func _edge(ci: CanvasItem, col: Color, mask: Array = [true, true, true, true]) -> void:
	var b := body
	if mask[1]:
		ci.draw_rect(Rect2(b.position.x + 1, b.position.y, b.size.x - 2, 1), col)
	if mask[3]:
		ci.draw_rect(Rect2(b.position.x + 1, b.end.y - 1, b.size.x - 2, 1), col)
	if mask[0]:
		ci.draw_rect(Rect2(b.position.x, b.position.y + 1, 1, b.size.y - 2), col)
	if mask[2]:
		ci.draw_rect(Rect2(b.end.x - 1, b.position.y + 1, 1, b.size.y - 2), col)

func _paint_ambient(ci: CanvasItem, frame: int) -> void:
	var r := _rng(frame, "ambient")
	var big := strength > 1.0
	if r.randf() < (0.5 if big else 0.4):
		for _i in r.randi_range(1, 4 if big else 3):
			_fragment(ci, r, 1.0, 0.5)
	if r.randf() < 0.06:
		_edge(ci, DevArt.CYAN if r.randf() < 0.5 else Color.WHITE, [r.randf() < 0.5, r.randf() < 0.5, true, r.randf() < 0.5])

func _paint_burst(ci: CanvasItem, frame: int, strong: bool) -> void:
	var r := _rng(frame, "burst")
	var b := body
	var big := strength > 1.0
	var k := strength * (2.0 if strong else 1.0)
	# the scanline wash: every other row a shade darker, the card's own blue
	var wash := Color(DevArt.EDGE, 0.1 if strong else 0.06)
	var y := b.position.y + 1.0 + float(frame % 2)
	while y < b.end.y - 1.0:
		ci.draw_rect(Rect2(b.position.x + 1, y, b.size.x - 2, 1), wash)
		y += 2.0
	# interference: bright lines across the card, running out past the border
	for _i in r.randi_range(1, 2) + (r.randi_range(1, 3) if strong else 0):
		var ly := b.position.y + floorf(r.randf() * b.size.y)
		var lx0 := b.position.x - floorf(r.randf() * room.x)
		var lx1 := b.end.x + floorf(r.randf() * room.z)
		if r.randf() < 0.5:   # (often just a run off one side)
			if r.randf() < 0.5:
				lx1 = b.position.x + floorf(b.size.x * r.randf_range(0.2, 0.5))
			else:
				lx0 = b.end.x - floorf(b.size.x * r.randf_range(0.2, 0.5))
		ci.draw_rect(Rect2(lx0, ly, lx1 - lx0, 1), Color(Color.WHITE if r.randf() < 0.4 else DevArt.CYAN, 0.55 if strong else 0.4))
	# escape strips: short runs of the card's ice leaving through its side
	for _i in roundi((2 if strong else 1) * strength):
		var right := r.randf() < 0.5
		var rm := room.z if right else room.x
		if rm < 2.0:
			continue
		var sw := float(r.randi_range(2, int(rm)))
		var sy := b.position.y + 2.0 + floorf(r.randf() * (b.size.y - 4.0))
		var sx := b.end.x if right else b.position.x - sw
		var col := DevArt.ICE_HI if r.randf() < 0.5 else DevArt.CYAN
		ci.draw_rect(Rect2(sx, sy, sw, 1), col)
		ci.draw_rect(Rect2(sx + (sw - 1.0 if right else 0.0), sy, 1, 1), Color.WHITE)
	# the border: cyan / white, part of it (all of it when strong)
	var bc := DevArt.CYAN if frame % 2 == 0 else Color.WHITE
	_edge(ci, bc, [true, true, true, true] if strong else [r.randf() < 0.6, r.randf() < 0.6, r.randf() < 0.6, r.randf() < 0.6])
	# fragments around the edges, in and out
	for _i in roundi(r.randi_range(6, 10) * k):
		_fragment(ci, r, 3.0)
	# a strong burst on the big card: pixel clusters at the corners
	if strong and big:
		for cpt in [b.position, Vector2(b.end.x, b.position.y), Vector2(b.position.x, b.end.y), b.end]:
			if r.randf() < 0.6:
				var dx := -1.0 if cpt.x <= b.position.x else 1.0
				var dy := -1.0 if cpt.y <= b.position.y else 1.0
				for _j in 3:
					var off := Vector2(floorf(r.randf() * 5.0) * dx, floorf(r.randf() * 5.0) * dy)
					ci.draw_rect(Rect2(cpt + off - Vector2(1, 1), Vector2(2, 2) if r.randf() < 0.3 else Vector2(1, 1)), _col(r))

## Reduce Motion: the still glitch-style border.
func _paint_still(ci: CanvasItem) -> void:
	var b := body
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, "still"])
	_edge(ci, DevArt.CYAN)
	# white breaks in the cyan edge
	for _i in roundi(6 * strength):
		var top := r.randf() < 0.5
		var w := float(r.randi_range(2, 5))
		var x := b.position.x + 3.0 + floorf(r.randf() * (b.size.x - 6.0 - w))
		ci.draw_rect(Rect2(x, b.position.y if top else b.end.y - 1.0, w, 1), Color.WHITE)
	for _i in roundi(4 * strength):
		var left := r.randf() < 0.5
		var hh := float(r.randi_range(2, 4))
		var y := b.position.y + 3.0 + floorf(r.randf() * (b.size.y - 6.0 - hh))
		ci.draw_rect(Rect2(b.position.x if left else b.end.x - 1.0, y, 1, hh), Color.WHITE)
	# a few fixed fragments by the corners, just outside (as far as the room allows, at most 2 px)
	for corner in 4:
		var left := corner % 2 == 0
		var top := corner < 2
		var ox := minf(2.0, room.x if left else room.z)
		var oy := minf(2.0, room.y if top else room.w)
		# beside the corner, off the side: a cyan pixel 4 px along the edge
		var sx := b.position.x - ox if left else b.end.x + ox - 1.0
		var sy := b.position.y + 4.0 if top else b.end.y - 5.0
		if ox >= 1.0:
			ci.draw_rect(Rect2(sx, sy, 1, 1), DevArt.CYAN)
		# above / below it: a white 2 px run
		var tx := b.position.x + 4.0 if left else b.end.x - 6.0
		var ty := b.position.y - oy if top else b.end.y + oy - 1.0
		if oy >= 1.0:
			ci.draw_rect(Rect2(tx, ty, 2, 1), Color.WHITE)
