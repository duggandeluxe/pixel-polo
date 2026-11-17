class_name UpgradeArt
extends RefCounted
## The Visual Upgrades gallery's five little scenes, drawn in whole pixels in a box (`r`, about
## 96 x 62): `t` the clock (it steps, so nothing slides smoothly), c1 / c2 your team's colours.
## `us` / `them`: your team and its rival (VisualUpgrades.preview_rival_id), for their logos and the
## rival's colours; without them a plain shield stands in. Card art only: the page behind a card
## previews the real effects (upgrade_detail.gd).

## One line a category, on its card and its page.
const TAGS := {
	"goal": "Turn every goal into a spectacle.",
	"crowd": "Pack the stands and raise the roof.",
	"broadcast": "Make every game look like prime time.",
	"pregame": "Make a grand entrance every game.",
	"scoreboard": "Put every game up on the big board.",
}

const WATER := Color("1b6fd0")
const WATER_HI := Color("6fc8ff")
const DARK := Color("081a44")
const WHITE := Color("f2f2e9")
const GOLD_HI := Color("ffe98a")
const CONFETTI := [Color("ff5a5a"), Color("ffcf3f"), Color("5fe0ff"), Color("7dff8a"), Color("f2f2e9")]

static func draw(ci: CanvasItem, id: String, r: Rect2, t: float, c1: Color, c2: Color, us: PoloTeam = null, them: PoloTeam = null) -> void:
	r = Rect2(r.position.floor(), r.size.floor())
	ci.draw_rect(r, DARK)
	var f := int(t * 8.0)
	match id:
		"goal":
			_goal(ci, r, f, c1)
		"crowd":
			_crowd(ci, r, f, c1, c2)
		"broadcast":
			_broadcast(ci, r, f, c1, c2, us, them)
		"pregame":
			_pregame(ci, r, f, c1, c2, us, them)
		"scoreboard":
			_scoreboard(ci, r, f, c1, c2, us, them)

static func _box(ci: CanvasItem, r: Rect2, x: float, y: float, w: float, h: float, col: Color) -> void:
	ci.draw_rect(Rect2(r.position + Vector2(x, y), Vector2(w, h)), col)

## Water up to the box's bottom from `y`, its top edge rippling.
static func _water(ci: CanvasItem, r: Rect2, y: float, f: int) -> void:
	_box(ci, r, 0, y, r.size.x, r.size.y - y, WATER)
	var x := -((f / 2) % 8)
	while x < r.size.x:
		_box(ci, r, maxf(x, 0), y, minf(4, r.size.x - maxf(x, 0)), 1, WATER_HI)
		x += 8

## A team's mark in the 12 x 14 a shield takes: its real logo, or (no team) the shield in c1 / c2.
static func _mark(ci: CanvasItem, r: Rect2, x: float, y: float, team: PoloTeam, c1: Color, c2: Color) -> void:
	if team == null:
		_shield(ci, r, x, y, c1, c2)
	else:
		TeamLogo.draw_in(ci, Rect2(r.position + Vector2(x, y), Vector2(12, 14)), team)

static func _shield(ci: CanvasItem, r: Rect2, x: float, y: float, c1: Color, c2: Color) -> void:
	_box(ci, r, x, y, 12, 10, WHITE)
	_box(ci, r, x + 1, y + 10, 10, 2, WHITE)
	_box(ci, r, x + 3, y + 12, 6, 2, WHITE)
	_box(ci, r, x + 1, y + 1, 10, 9, c1)
	_box(ci, r, x + 3, y + 10, 6, 2, c1)
	_box(ci, r, x + 4, y + 3, 4, 5, c2)

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

static func _broadcast(ci: CanvasItem, r: Rect2, f: int, c1: Color, c2: Color, us: PoloTeam, them: PoloTeam) -> void:
	var w := r.size.x
	var h := r.size.y
	_box(ci, r, 0, 0, w, h, Color("123a8a"))
	_water(ci, r, 34, f)
	# the scoreboard
	_box(ci, r, 6, 5, w - 12, 25, WHITE)
	_box(ci, r, 7, 6, w - 14, 23, DARK)
	_mark(ci, r, 10, 9, us, c1, c2)
	_mark(ci, r, w - 22, 9, them, c2, c1)
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

static func _pregame(ci: CanvasItem, r: Rect2, f: int, c1: Color, c2: Color, us: PoloTeam, them: PoloTeam) -> void:
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
			_mark(ci, r, sx, h * 0.5 - 8, us if side == 0 else them, c1 if side == 0 else c2, c2 if side == 0 else c1)
		var hx := x + dw - 4 if side == 0 else x + 2
		if hx > 0 and hx < w - 2:
			_box(ci, r, hx, h * 0.5 - 4, 2, 10, Color("c9d3dd"))
	# the frame
	_box(ci, r, 0, 0, w, 6, Color("23344f"))
	_box(ci, r, 0, 0, 10, h, Color("23344f"))
	_box(ci, r, w - 10, 0, 10, h, Color("23344f"))

## The board over the water (the top level, PREMIUM): a silver frame, your colours against a
## rival's, the clock in its own panel, and every so often your score rolling up with a flash.
static func _scoreboard(ci: CanvasItem, r: Rect2, f: int, c1: Color, c2: Color, us: PoloTeam, them: PoloTeam) -> void:
	var w := r.size.x
	var h := r.size.y
	_box(ci, r, 0, 0, w, h, Color("123a8a"))
	for i in 6:   # the arena's lights
		_box(ci, r, 8 + i * 15, 3, 3, 2, Color(1, 1, 1, 0.3 if (f / 6 + i) % 3 == 0 else 0.12))
	_water(ci, r, h - 14, f)
	var y := 17.0
	var x0 := floorf((w - 84.0) / 2.0)
	_box(ci, r, x0 + 1, y + 1, 84, 20, Color(0, 0, 0, 0.35))
	_box(ci, r, x0, y, 84, 20, Scoreboard.SILVER_LO)
	_box(ci, r, x0, y, 84, 1, Scoreboard.SILVER_HI)
	_box(ci, r, x0 + 1, y + 1, 82, 18, Scoreboard.INK)
	# the teams' panels, a shield on each
	var rival := [them.c1, them.c2] if them != null else [Color("1d4ab8"), UI.GOLD]
	for k in 2:
		var px := x0 + 2.0 if k == 0 else x0 + 68.0
		var fill: Color = Scoreboard.team_fill(c1) if k == 0 else (Scoreboard.team_fill(rival[0]) if them != null else rival[0])
		_box(ci, r, px, y + 2, 14, 16, fill)
		_box(ci, r, px, y + 15, 14, 1, c2 if k == 0 else rival[1])
		_mark(ci, r, px + 1, y + 1, us if k == 0 else them, c1 if k == 0 else rival[0], c2 if k == 0 else rival[1])
	# the scores in silver-edged wells, yours going up now and then
	var cyc := f % 40
	var home := 3 + (f / 40) % 6
	for k in 2:
		var wx := x0 + 17.0 if k == 0 else x0 + 54.0
		_box(ci, r, wx, y + 1, 13, 18, Scoreboard.SILVER)
		_box(ci, r, wx + 1, y + 2, 11, 16, Scoreboard.WELL)
		if k == 0 and cyc < 8:
			_box(ci, r, wx + 1, y + 2, 11, 16, Color(c1, 0.6 * (1.0 - cyc / 8.0)))
		var lift := maxf(0.0, 3.0 - cyc) if k == 0 else 0.0
		Deck.text(ci, r.position.x + wx, r.position.y + y + 10 + lift, str(home) if k == 0 else "2", 16, UI.GOLD, "big", HORIZONTAL_ALIGNMENT_CENTER, 13)
		if k == 0 and cyc < 6:
			_box(ci, r, wx, y + 1, 13, 1, UI.GOLD)
	# the clock's own panel, a pixel proud of the board
	var cx := x0 + 31.0
	_box(ci, r, cx, y - 1, 22, 22, Scoreboard.SILVER_LO)
	_box(ci, r, cx, y - 1, 22, 1, Scoreboard.SILVER_HI)
	_box(ci, r, cx + 1, y, 20, 20, Scoreboard.NAVY)
	_box(ci, r, cx + 2, y + 1, 18, 8, Color("23409a"))
	Deck.text(ci, r.position.x + cx + 2, r.position.y + y + 5, "Q4", 8, UI.GOLD, "caps", HORIZONTAL_ALIGNMENT_CENTER, 18)
	var secs := 59 - (f / 8) % 60
	Deck.text(ci, r.position.x + cx, r.position.y + y + 13, ":%02d" % secs, 8, WHITE, "caps", HORIZONTAL_ALIGNMENT_CENTER, 22)

## A Goal Celebration's little scene (`lvl` 0 CLASSIC .. 3 GOALPOST FIREWORKS, the shop's cards; about
## 28 x 26): the goal on the water, and what happens over it. Whole pixels, the clock stepping.
static func celeb_icon(ci: CanvasItem, r: Rect2, lvl: int, t: float, c1: Color, c2: Color) -> void:
	r = Rect2(r.position.floor(), r.size.floor())
	ci.draw_rect(r, DARK)
	var w := r.size.x
	var h := r.size.y
	var f := int(t * 8.0)
	var wy := h - 6.0                       # the waterline
	var gx := w * 0.5 - 7.0                 # the goal: 14 wide, 8 tall
	var gy := wy - 8.0
	_water(ci, r, wy, f)
	for i in 3:                             # the net
		_box(ci, r, gx + 3 + i * 4, gy + 2, 1, 6, Color(1, 1, 1, 0.3))
	_box(ci, r, gx, gy, 14, 2, WHITE)       # the bar and the posts
	_box(ci, r, gx, gy, 2, 8, WHITE)
	_box(ci, r, gx + 12, gy, 2, 8, WHITE)
	var step := f % 16                      # each loops: 16 frames, two seconds
	match lvl:
		0:   # CLASSIC: the ball in the net, the splash
			_box(ci, r, gx + 6, wy - 4, 3, 3, Color("ffd23f"))
			if step < 8:
				_box(ci, r, gx + 3 - step / 2, wy - 2 - step % 3, 1, 1, WATER_HI)
				_box(ci, r, gx + 11 + step / 2, wy - 2 - (step + 1) % 3, 1, 1, WATER_HI)
		1:   # CONFETTI POPPERS: a popper on each post, a fan of confetti up and drifting down
			_box(ci, r, gx, gy - 3, 2, 3, CONFETTI[0])
			_box(ci, r, gx + 12, gy - 3, 2, 3, CONFETTI[2])
			for i in 10:
				var side := -1.0 if i % 2 == 0 else 1.0
				var px := (gx + 1 if i % 2 == 0 else gx + 13) + side * (1 + (i / 2) * 1.6) * minf(step, 6) / 6.0
				var py := gy - 4 - (2 + (i * 7) % 9) * minf(step, 5) / 5.0 + maxf(0, step - 6) * 0.9
				if py < wy - 1:
					_box(ci, r, clampf(px, 0, w - 2), maxf(py, 0), 1 + (i + step) % 2, 1, CONFETTI[i % 5])
		2:   # WATER EXPLOSION: a water cannon on each post, two thick jets arcing up and out, raining back
			for k in 2:
				var side := -1.0 if k == 0 else 1.0
				var bx := gx + (0.0 if k == 0 else 12.0)
				_box(ci, r, bx, gy - 2, 2, 2, Color("8fa3bf"))
				var reach := minf(step, 6) / 6.0 * 1.3          # how far along its arc the jet has got
				var fall := maxf(0, step - 7) * 1.3             # then it breaks up and drops
				for i in 14:
					var e := float(i) / 10.0
					if e > reach or (fall > 0.0 and i % 2 == 1) or step > 13:
						continue
					var px := bx + side * e * 7.0
					var py := gy - 3 - 20.0 * e + 18.0 * e * e + fall
					if py < wy - 1 and py >= 0:
						var thick := 2 if fall == 0.0 else 1
						_box(ci, r, clampf(px, 0, w - 2), py, thick, thick, WHITE if i % 3 == 0 else WATER_HI)
		3:   # GOALPOST FIREWORKS: a rocket off each post, bursting in your colours
			var cols := [c1.lightened(0.45) if c1.get_luminance() < 0.3 else c1, c2.lightened(0.45) if c2.get_luminance() < 0.3 else c2]
			for k in 2:
				var s := (step + k * 3) % 16
				var bx := gx + 1 + k * 12
				var top := 4.0 + k * 2
				if s < 5:
					_box(ci, r, bx, gy - (gy - top) * s / 5.0, 1, 2, GOLD_HI)
				elif s < 13:
					var rad := (s - 5) * 1.3
					for i in 8:
						var a := TAU * i / 8.0
						_box(ci, r, clampf(bx + cos(a) * rad, 0, w - 1), clampf(top + sin(a) * rad * 0.8, 0, h - 1), 1, 1, cols[k] if i % 3 != 0 else WHITE)
