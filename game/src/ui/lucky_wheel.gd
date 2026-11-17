class_name LuckyWheel
extends Control
## THE LUCKY SPIN WHEEL: LuckySpin.SEGMENTS as pixel art, 11 equal slices, the fixed pointer at
## the top, the Polo Point coin in the hub. It's drawn pixel by pixel into an Image at the game's own
## resolution (never a rotated, filtered texture), so every frame of the spin is crisp: a 1 px ink
## outline, a gold rim with its bulbs, ink spokes between the slices and a lit inner edge.
##
## spin_to(seg) turns the wheel so slice `seg` stops under the pointer. The result was decided
## before the call (LuckySpin.claim) and the wheel only shows it. It ticks as each spoke passes
## the pointer, and emits `landed` once.

signal landed(seg: int)

const N := 11
const SEG_W := TAU / N
## 5 PP slices in two blues (alternating), 10 PP cyan, 15 PP gold.
const C5 := [Color("2a68f5"), Color("1d4ab8")]
const C10 := Color("5cc8ff")
const C15 := Color("ffd23f")
const INK := Color("06103a")
const RIM := Color("e0a526")
const RIM_D := Color("a8650f")
const BULB := Color("fff2a8")
const HUB := Color("0b1d5c")

var radius := 52
var labels := true              # the amounts on the slices (the big wheel)
var pointer := true
var rot := 0.0                  # the wheel's turn, clockwise, radians
var win := -1                   # the slice lit after landing (-1 none)
var blink := false              # the lit slice's flash, on or off

var _img: Image
var _tex: ImageTexture
var _ang := PackedFloat32Array()
var _dist := PackedFloat32Array()
var _cols: Array = []           # each slice's fill
var _drawn_rot := -999.0
var _drawn_win := -2
var _drawn_blink := false
# the spin
var _from := 0.0
var _to := 0.0
var _t := 0.0
var _dur := 0.0
var _target := -1
var _last_top := -1
var _kick := 0.0

func _init(r: int = 52, with_labels: bool = true, with_pointer: bool = true) -> void:
	radius = r
	labels = with_labels
	pointer = with_pointer
	var d := 2 * radius + 1
	custom_minimum_size = Vector2(d, d + (6 if pointer else 0))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var five := 0
	for v in LuckySpin.SEGMENTS:
		if int(v) == 15:
			_cols.append(C15)
		elif int(v) == 10:
			_cols.append(C10)
		else:
			_cols.append(C5[five % 2])
			five += 1
	_ang.resize(d * d)
	_dist.resize(d * d)
	for y in d:
		for x in d:
			var dx := x - radius
			var dy := y - radius
			_ang[y * d + x] = fposmod(atan2(float(dx), float(-dy)), TAU)   # 0 at the top, clockwise
			_dist[y * d + x] = sqrt(float(dx * dx + dy * dy))
	_img = Image.create(d, d, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)

## The slice under the pointer at turn `r`.
static func slice_at_top(r: float) -> int:
	return int(fposmod(-r, TAU) / SEG_W) % N

## The turn that puts slice `seg`'s centre (plus `off` of a slice, -0.5..0.5) under the pointer.
static func rot_for(seg: int, off: float = 0.0) -> float:
	return fposmod(-(seg + 0.5 + off) * SEG_W, TAU)

func spinning() -> bool:
	return _target >= 0

## Spins to slice `seg`: quick at first, slowing to a stop under the pointer (`quick`: Reduce
## Motion's short version).
func spin_to(seg: int, quick: bool = false) -> void:
	win = -1
	_target = seg
	_from = rot
	var off := randf_range(-0.32, 0.32)   # (where in the slice it stops: never near a spoke)
	var turns := 2 if quick else 5
	_to = _from + turns * TAU + fposmod(rot_for(seg, off) - fposmod(_from, TAU), TAU)
	_t = 0.0
	_dur = 1.1 if quick else 3.8
	_last_top = slice_at_top(rot)
	set_process(true)

## Shows slice `seg` under the pointer at once (a result already credited, shown again).
func show_at(seg: int) -> void:
	rot = rot_for(seg)
	win = seg
	queue_redraw()

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	if _kick > 0.0:
		_kick = maxf(0.0, _kick - delta)
		queue_redraw()
	if _target < 0:
		if _kick <= 0.0:
			set_process(false)
		return
	_t = minf(_dur, _t + delta)
	var k := _t / _dur
	rot = _from + (_to - _from) * (1.0 - pow(1.0 - k, 4.0))   # ease out: fast, then a long slow-down
	var top := slice_at_top(rot)
	if top != _last_top:
		_last_top = top
		_kick = 0.06
		Sfx.play("score_tick")
	queue_redraw()
	if _t >= _dur:
		var seg := _target
		_target = -1
		rot = _to
		win = seg
		queue_redraw()
		landed.emit(seg)

func _draw() -> void:
	if not is_equal_approx(rot, _drawn_rot) or win != _drawn_win or blink != _drawn_blink:
		_render()
	var top := 6.0 if pointer else 0.0
	draw_texture(_tex, Vector2(0, top))
	if labels:
		_draw_labels(Vector2(radius, radius + top))
	# the hub: the Polo Point coin, 2x
	var coin := 20 if radius >= 40 else 10
	var ch := CreditCoin.height(coin)
	CreditCoin.draw(self, Vector2(radius - ch * 0.5 + 0.5, radius + top - ch * 0.5 + 0.5).floor(), coin)
	if pointer:
		_draw_pointer(Vector2(radius, top))

## The amounts, upright, riding round with their slices.
func _draw_labels(c: Vector2) -> void:
	for i in N:
		var a := rot + (i + 0.5) * SEG_W
		var at := (c + Vector2(sin(a), -cos(a)) * (radius * 0.64)).round()
		var v := int(LuckySpin.SEGMENTS[i])
		var s := str(v)
		var w := Deck.text_w(s, 8)
		var ink := v != 5
		if not ink:
			Deck.text(self, at.x - roundf(w * 0.5) + 1, at.y + 1, s, 8, INK)
		Deck.text(self, at.x - roundf(w * 0.5), at.y, s, 8, INK if ink else Color.WHITE)

## The pointer: a gold arrowhead pointing down into the wheel, outlined in ink; it kicks up a pixel
## as each spoke passes.
const POINTER := [
	".ooooooooo.",
	"oGHHHHHHGGo",
	"oGHGGGGGGSo",
	".oGGGGGGSo.",
	"..oGGGGSo..",
	"...oGGSo...",
	"....oSo....",
	".....o.....",
]

func _draw_pointer(top: Vector2) -> void:
	var at := Vector2(top.x - 5, top.y - 6 - (1 if _kick > 0.0 else 0))
	Deck.pat(self, at, POINTER, {"o": INK, "G": C15, "H": BULB, "S": RIM_D})

## The wheel's pixels at the current turn.
func _render() -> void:
	_drawn_rot = rot
	_drawn_win = win
	_drawn_blink = blink
	var d := 2 * radius + 1
	var data := PackedByteArray()
	data.resize(d * d * 4)
	var r := float(radius)
	var hub := 12.0 if radius >= 40 else 6.0
	var inv := 1.0 / SEG_W
	for i in d * d:
		var dist := _dist[i]
		var col: Color
		if dist > r + 0.5:
			continue   # (transparent: the bytes stay 0)
		elif dist > r - 0.5:
			col = INK
		elif dist > r - 3.5:
			# the gold rim: lit upper half, darker lower, a bulb at every spoke
			var a0 := fposmod(_ang[i] - rot, TAU) * inv
			var f0 := a0 - floorf(a0)
			var bulb := minf(f0, 1.0 - f0) * SEG_W * dist < 1.3 and dist > r - 2.5 and dist < r - 1.0
			col = BULB if bulb else (RIM if dist > r - 2.5 else RIM_D)
		elif dist > r - 4.5:
			col = INK
		elif dist < hub - 0.5:
			col = HUB
		elif dist < hub + 0.5:
			col = INK
		else:
			var a := fposmod(_ang[i] - rot, TAU) * inv
			var seg := int(a) % N
			var f := a - floorf(a)
			if minf(f, 1.0 - f) * SEG_W * dist < 0.6:
				col = INK   # a spoke
			else:
				col = _cols[seg]
				if seg == win and blink:
					col = col.lightened(0.45)
				elif dist > r - 6.5:
					col = col.lightened(0.18)   # the lit inner edge under the rim
				elif dist < hub + 2.5:
					col = col.darkened(0.25)    # the shade round the hub
		var o := i * 4
		data[o] = int(col.r8)
		data[o + 1] = int(col.g8)
		data[o + 2] = int(col.b8)
		data[o + 3] = 255
	_img.set_data(d, d, false, Image.FORMAT_RGBA8, data)
	_tex.update(_img)
