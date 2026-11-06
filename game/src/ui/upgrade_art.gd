class_name UpgradeArt
extends RefCounted
## The Visual Upgrades gallery's six little scenes, drawn in whole pixels in a box (`r`, about
## 96 x 62): `t` the clock (it steps, so nothing slides smoothly), c1 / c2 your team's colours.
## Card art only: the page behind a card previews the real effects (upgrade_detail.gd).

## One line a category, on its card and its page.
const TAGS := {
	"goal": "Turn every goal into a spectacle.",
	"replay": "Relive your goals in slow motion.",
	"crowd": "Pack the stands and raise the roof.",
	"broadcast": "Make every game look like prime time.",
	"victory": "From fireworks to the trophy: win in style.",
	"pregame": "Make a grand entrance every game.",
}

const WATER := Color("1b6fd0")
const WATER_HI := Color("6fc8ff")
const DARK := Color("081a44")
const WHITE := Color("f2f2e9")
const GOLD_HI := Color("ffe98a")
const CONFETTI := [Color("ff5a5a"), Color("ffcf3f"), Color("5fe0ff"), Color("7dff8a"), Color("f2f2e9")]

static func draw(ci: CanvasItem, id: String, r: Rect2, t: float, c1: Color, c2: Color) -> void:
	r = Rect2(r.position.floor(), r.size.floor())
	ci.draw_rect(r, DARK)
	var f := int(t * 8.0)
	match id:
		"goal":
			_goal(ci, r, f, c1)
		"replay":
			_replay(ci, r, f)
		"crowd":
			_crowd(ci, r, f, c1, c2)
		"broadcast":
			_broadcast(ci, r, f, c1, c2)
		"victory":
			_victory(ci, r, f, c1, c2)
		"pregame":
			_pregame(ci, r, f, c1, c2)

static func _box(ci: CanvasItem, r: Rect2, x: float, y: float, w: float, h: float, col: Color) -> void:
	ci.draw_rect(Rect2(r.position + Vector2(x, y), Vector2(w, h)), col)

## Water up to the box's bottom from `y`, its top edge rippling.
static func _water(ci: CanvasItem, r: Rect2, y: float, f: int) -> void:
	_box(ci, r, 0, y, r.size.x, r.size.y - y, WATER)
	var x := -((f / 2) % 8)
	while x < r.size.x:
		_box(ci, r, maxf(x, 0), y, minf(4, r.size.x - maxf(x, 0)), 1, WATER_HI)
		x += 8

static func _shield(ci: CanvasItem, r: Rect2, x: float, y: float, c1: Color, c2: Color) -> void:
	_box(ci, r, x, y, 12, 10, WHITE)
	_box(ci, r, x + 1, y + 10, 10, 2, WHITE)
	_box(ci, r, x + 3, y + 12, 6, 2, WHITE)
	_box(ci, r, x + 1, y + 1, 10, 9, c1)
	_box(ci, r, x + 3, y + 10, 6, 2, c1)
	_box(ci, r, x + 4, y + 3, 4, 5, c2)

static func _man(ci: CanvasItem, r: Rect2, x: float, y: float, cap: Color, up: bool) -> void:
	_box(ci, r, x, y, 6, 4, cap)
	_box(ci, r, x + 1, y + 4, 4, 2, Color("e0a878"))
	_box(ci, r, x, y + 6, 6, 5, Color("e0a878"))
	if up:
		_box(ci, r, x - 2, y - 1, 2, 7, Color("e0a878"))
		_box(ci, r, x + 6, y - 1, 2, 7, Color("e0a878"))

static func _goal(ci: CanvasItem, r: Rect2, f: int, c1: Color) -> void:
	var w := r.size.x
	_box(ci, r, 0, 0, w, 40, Color("0f2f78"))
	# the net, the posts, the bar
	var gx := w - 44
	for i in 7:
		_box(ci, r, gx + i * 6, 12, 1, 28, Color(1, 1, 1, 0.3))
	for i in 5:
		_box(ci, r, gx, 12 + i * 6, 38, 1, Color(1, 1, 1, 0.3))
	_box(ci, r, gx - 2, 9, 42, 3, WHITE)
	_box(ci, r, gx - 2, 9, 3, 33, WHITE)
	_box(ci, r, gx + 37, 9, 3, 33, WHITE)
	_water(ci, r, 40, f)
	# the shot: a ball on its way in, its trail, then the splash
	var step := f % 24
	var bx := 6.0 + minf(step, 12) * 5.0
	var by := 32.0 - sin(minf(step, 12) / 12.0 * PI) * 10.0
	if step < 12:
		for k in 3:
			_box(ci, r, bx - 6 - k * 5, by + 2 + k, 3, 1, Color(WATER_HI, 0.8 - k * 0.25))
	_box(ci, r, bx + 1, by, 4, 6, Color("ffd23f"))
	_box(ci, r, bx, by + 1, 6, 4, Color("ffd23f"))
	_box(ci, r, bx + 2, by + 1, 2, 1, WHITE)
	if step >= 12:
		var k2 := step - 12
		for i in 6:
			_box(ci, r, gx + 8 + i * 5, 38 - absi((i * 3 + k2) % 9), 2, 2, WATER_HI)
		for i in 4:   # fireworks over the goal
			var a := i * TAU / 4.0 + 0.6
			_box(ci, r, 18 + cos(a) * (k2 + 2), 12 + sin(a) * (k2 + 2) * 0.7, 2, 2, CONFETTI[(i + k2) % 5])
		Deck.shadow_text(ci, r.position.x + 5, r.position.y + 52, "GOAL!", 16, UI.GOLD, "big")
	_box(ci, r, 3, 44, 7, 4, c1)

static func _replay(ci: CanvasItem, r: Rect2, f: int) -> void:
	var w := r.size.x
	var h := r.size.y
	_box(ci, r, 4, 4, w - 8, h - 8, Color("c9d3dd"))
	_box(ci, r, 6, 6, w - 12, h - 12, WATER)
	for i in 4:   # lane ropes
		_box(ci, r, 6, 14 + i * 10, w - 12, 1, Color(WATER_HI, 0.5))
	var step := (f / 2) % 32
	var bx := 12.0 + step * (w - 30) / 32.0
	var by := h * 0.5 + sin(step * 0.4) * 8.0 - 4.0
	for k in 4:   # slow motion: where the ball was
		_box(ci, r, bx - k * 6, by + 1, 5, 4, Color("ffd23f", 0.45 - k * 0.1))
	_box(ci, r, bx + 1, by, 4, 6, Color("ffd23f"))
	_box(ci, r, bx, by + 1, 6, 4, Color("ffd23f"))
	_box(ci, r, 6, 6, 44, 11, Color(DARK, 0.85))
	if (f / 4) % 2 == 0:
		_box(ci, r, 9, 9, 5, 5, Color("ff4040"))
	Deck.text(ci, r.position.x + 17, r.position.y + 12, "REPLAY", 8, WHITE)
	# the rewind arrows, the scrub bar
	for k in 2:
		for i in 4:
			_box(ci, r, w - 26 + k * 7 + i, 12 - i, 1, i * 2 + 1, WHITE)
	_box(ci, r, 10, h - 12, w - 20, 2, Color(DARK, 0.7))
	_box(ci, r, 10, h - 12, (w - 20) * step / 32.0, 2, UI.GOLD)

static func _crowd(ci: CanvasItem, r: Rect2, f: int, c1: Color, c2: Color) -> void:
	var w := r.size.x
	_box(ci, r, 0, 0, w, 7, Color("23344f"))   # the roof and its trusses
	for i in 6:
		_box(ci, r, 4 + i * 17, 7, 1, 4, Color("3f5878"))
	for row in 4:
		var y := 12.0 + row * 9
		_box(ci, r, 0, y + 6, w, 3, Color("13306e").lightened(row * 0.05))
		for i in 16:
			var x := 1.0 + i * 6 + (row % 2) * 3
			if x > w - 5:
				continue
			var bob := 1 if (i * 3 + row * 5 + f / 2) % 7 < 2 else 0
			var shirt: Color = c1 if (i + row) % 3 == 0 else (c2 if (i + row) % 3 == 1 else CONFETTI[(i * 7 + row) % 5])
			_box(ci, r, x + 1, y - bob, 3, 3, Color("e0a878") if (i + row) % 4 else Color("8a5a3a"))
			_box(ci, r, x, y + 3 - bob, 5, 3, shirt)
	for k in 2:   # the flags
		var fx := 20.0 + k * 48
		_box(ci, r, fx, 8, 1, 22, WHITE)
		for i in 7:
			_box(ci, r, fx + 1 + i * 2, 9 + ((i + f / 2) % 4) / 2, 2, 8, c1 if k == 0 else c2)
	_water(ci, r, r.size.y - 11, f)

static func _broadcast(ci: CanvasItem, r: Rect2, f: int, c1: Color, c2: Color) -> void:
	var w := r.size.x
	var h := r.size.y
	_box(ci, r, 0, 0, w, h, Color("123a8a"))
	_water(ci, r, 34, f)
	# the scoreboard
	_box(ci, r, 6, 5, w - 12, 25, WHITE)
	_box(ci, r, 7, 6, w - 14, 23, DARK)
	_shield(ci, r, 10, 9, c1, c2)
	_shield(ci, r, w - 22, 9, c2, c1)
	var home := 3 + (f / 24) % 5
	Deck.shadow_text(ci, r.position.x + 27, r.position.y + 22, str(home), 16, UI.GOLD, "big")
	Deck.shadow_text(ci, r.position.x + w - 36, r.position.y + 22, "2", 16, WHITE, "big")
	_box(ci, r, w * 0.5 - 8, 9, 16, 9, Color("ff4040") if (f / 4) % 2 == 0 else Color("a02828"))
	Deck.text(ci, r.position.x + w * 0.5 - 6, r.position.y + 14, "LIVE", 8, WHITE)
	# the player's stat line, sliding in by steps
	var slide := minf((f % 48) * 6.0, w - 12)
	_box(ci, r, 6, h - 21, slide, 13, UI.GOLD)
	_box(ci, r, 6, h - 21, minf(slide, 4), 13, c1)
	if slide >= w - 12:
		Deck.text(ci, r.position.x + 13, r.position.y + h - 15, "3 GOALS TODAY", 8, UI.INK)

static func _victory(ci: CanvasItem, r: Rect2, f: int, c1: Color, c2: Color) -> void:
	var w := r.size.x
	var h := r.size.y
	_box(ci, r, 0, 0, w, h, Color("0f2f78"))
	for i in 5:   # the lights behind the cup
		_box(ci, r, w * 0.5 - 28 + i * 13, 0, 4, h - 16, Color(1, 1, 1, 0.05))
	_water(ci, r, h - 11, f)
	# the trophy
	var cx := floorf(w * 0.5)
	_box(ci, r, cx - 10, 13, 20, 3, UI.GOLD)
	_box(ci, r, cx - 9, 16, 18, 9, UI.GOLD)
	_box(ci, r, cx - 7, 25, 14, 3, UI.GOLD)
	_box(ci, r, cx - 4, 28, 8, 3, UI.GOLD)
	_box(ci, r, cx - 2, 31, 4, 6, UI.GOLD)
	_box(ci, r, cx - 7, 37, 14, 3, Color("b47a1c"))
	_box(ci, r, cx - 14, 15, 4, 2, UI.GOLD)
	_box(ci, r, cx - 14, 15, 2, 8, UI.GOLD)
	_box(ci, r, cx + 10, 15, 4, 2, UI.GOLD)
	_box(ci, r, cx + 12, 15, 2, 8, UI.GOLD)
	_box(ci, r, cx - 6, 16, 3, 8, GOLD_HI)
	if (f / 3) % 4 < 2:   # the sparkle
		_box(ci, r, cx + 6, 11, 1, 7, WHITE)
		_box(ci, r, cx + 3, 14, 7, 1, WHITE)
	# the team, arms up
	for i in 4:
		var x := 7.0 + i * 11 if i < 2 else w - 13 - (i - 2) * 11
		_man(ci, r, x, h - 22 - (1 if (f / 3 + i) % 2 == 0 else 0), c1, true)
	# the banner
	_box(ci, r, cx - 30, 1, 60, 10, c2)
	_box(ci, r, cx - 30, 10, 60, 1, DARK)
	Deck.text(ci, r.position.x + cx - 22, r.position.y + 6, "CHAMPIONS", 8, WHITE)
	for i in 14:   # the confetti
		var cy := (i * 13 + f * (1 + i % 2)) % int(h - 12)
		_box(ci, r, (i * 29 + (f / 3) % 3) % int(w - 3), cy, 2, 2, CONFETTI[i % 5])

static func _pregame(ci: CanvasItem, r: Rect2, f: int, c1: Color, c2: Color) -> void:
	var w := r.size.x
	var h := r.size.y
	# the pool through the doorway
	var cx := floorf(w * 0.5)
	_box(ci, r, 0, 0, w, h, Color("0f1f4a"))
	_box(ci, r, 10, 6, w - 20, h - 6, Color("9fdcff"))
	_box(ci, r, 10, h * 0.45, w - 20, h * 0.55, WATER)
	for i in 3:
		_box(ci, r, 10, h * 0.45 + 6 + i * 8, w - 20, 1, WATER_HI)
	for i in 3:   # the light that comes through
		_box(ci, r, cx - 22 + i * 19, 6, 6, h - 6, Color(1, 1, 1, 0.18))
	# the doors, sliding apart and back, by steps
	var phase := (f / 2) % 40
	var open := float(clampi(phase - 6, 0, 12) if phase < 26 else clampi(38 - phase, 0, 12)) * 2.0
	var dw := cx - 10
	for side in 2:
		var x := 10.0 - open if side == 0 else cx + open
		var vis_x := maxf(x, 0.0)
		var vis_w := minf(x + dw, w) - vis_x
		_box(ci, r, vis_x, 6, vis_w, h - 6, Color("6fb4e8", 0.82))
		_box(ci, r, vis_x, 6, vis_w, 1, WHITE)
		for g in 3:   # the glass's shine
			var gx := x + 6 + g * 4
			if gx > 0 and gx < w - 2:
				_box(ci, r, gx, 12 + g * 3, 2, 18, Color(1, 1, 1, 0.3))
		var sx := x + dw * 0.5 - 6
		if sx > 1 and sx < w - 13:
			_shield(ci, r, sx, h * 0.5 - 8, c1 if side == 0 else c2, c2 if side == 0 else c1)
		var hx := x + dw - 4 if side == 0 else x + 2
		if hx > 0 and hx < w - 2:
			_box(ci, r, hx, h * 0.5 - 4, 2, 10, Color("c9d3dd"))
	# the frame
	_box(ci, r, 0, 0, w, 6, Color("23344f"))
	_box(ci, r, 0, 0, 10, h, Color("23344f"))
	_box(ci, r, w - 10, 0, 10, h, Color("23344f"))
