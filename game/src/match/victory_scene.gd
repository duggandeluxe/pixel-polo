class_name VictoryScene
extends RefCounted
## The pool deck, for the Victory Presentation's Team Huddle and Trophy Celebration (VictoryShow): a
## night-time arena wall with room for the fireworks, the deck, your team's bench, and the men
## themselves standing up. A man is his own Portrait (his real face, cap and colours, at its native
## pixels) on a small standing body: swimsuit for the huddle, a robe in your team's colours for the
## trophy. Whole pixels, drawn straight onto the canvas. Nothing here knows about the match.

const WALL := Color("0a1436")
const WALL_LOW := Color("12235a")
const DECK := Color("7d8fa8")
const DECK_DARK := Color("61738c")
const WATER := Color("1b6fd0")
const WATER_HI := Color("6fc8ff")
const WOOD := Color("7a4a1c")
const BODY_W := 16.0
const BODY_H := 24.0           # shoulders to the soles of his feet
const HEAD_DROP := 6.0         # the portrait's shoulders sit this far over the body's top
const SCALE := 2.0             # the men are drawn at twice the portrait's pixels: big enough to see

## Where the deck starts, down the screen.
static func deck_y(size: Vector2) -> float:
	return roundf(size.y * 0.5)

## The wall, the deck, the water along the front, the school's banners and the bench.
static func stage(ci: CanvasItem, size: Vector2, team: PoloTeam, t: float, calm: bool) -> void:
	var dy := deck_y(size)
	ci.draw_rect(Rect2(0, 0, size.x, dy), WALL)
	ci.draw_rect(Rect2(0, dy - 34, size.x, 34), WALL_LOW)
	for i in 5:   # the rafters' lights
		var x := roundf(size.x * (float(i) + 0.5) / 5.0)
		ci.draw_rect(Rect2(x - 7, 6, 14, 2), Color("ffe9a0"))
	var bx := 26.0
	while bx < size.x - 20.0:   # the banners along the wall
		var sway := 0.0 if calm else roundf(sin(t * 1.6 + bx) * 1.0)
		ci.draw_rect(Rect2(bx, dy - 30, 18, 20 + sway), team.c1)
		ci.draw_rect(Rect2(bx, dy - 30, 18, 3), team.c2)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(bx, dy - 10 + sway), Vector2(bx + 18, dy - 10 + sway), Vector2(bx + 9, dy - 4 + sway)]), team.c1)
		bx += 62.0
	ci.draw_rect(Rect2(0, dy, size.x, size.y - dy), DECK)
	var row := 0
	var y := dy + 7.0
	while y < size.y - 18.0:   # the tile lines
		ci.draw_rect(Rect2(0, y, size.x, 1), DECK_DARK)
		var x := 8.0 + (row % 2) * 14.0
		while x < size.x:
			ci.draw_rect(Rect2(x, y - 6, 1, 6), DECK_DARK)
			x += 28.0
		y += 7.0
		row += 1
	ci.draw_rect(Rect2(0, size.y - 16, size.x, 16), WATER)
	ci.draw_rect(Rect2(0, size.y - 16, size.x, 2), Color("dfe8f2"))
	var wx := -fposmod(0.0 if calm else t * 10.0, 12.0)
	while wx < size.x:
		ci.draw_rect(Rect2(wx, size.y - 9, 6, 1), WATER_HI)
		wx += 12.0
	bench(ci, size, team)

## Your team's bench against the back of the deck, towels over it.
static func bench(ci: CanvasItem, size: Vector2, team: PoloTeam) -> void:
	var dy := deck_y(size)
	var x := roundf(size.x * 0.12)
	var w := roundf(size.x * 0.76)
	ci.draw_rect(Rect2(x, dy - 2, w, 6), WOOD)
	ci.draw_rect(Rect2(x, dy - 2, w, 1), Color("a86a2c"))
	ci.draw_rect(Rect2(x, dy + 1, w, 1), team.c1)
	for k in 4:
		var lx := x + 6 + (w - 16) * k / 3.0
		ci.draw_rect(Rect2(roundf(lx), dy + 4, 4, 6), Color("5a3412"))
	for k in 6:
		var tx := roundf(x + 18 + (w - 44) * k / 5.0)
		ci.draw_rect(Rect2(tx, dy - 3, 10, 5), team.c2 if k % 2 == 0 else Color("f2f2e9"))

## One man standing, his feet at (`x`, `foot`), every pixel `k` screen pixels. `arms`: "down", "up"
## (both raised), "out" (round his mates' shoulders), "hold" (up on the trophy). `robe`: in your
## colours, not his suit.
static func man(ci: CanvasItem, x: float, foot: float, p: PoloPlayer, team: PoloTeam, arms: String, robe: bool, wave := 0.0, k := SCALE) -> void:
	x = roundf(x)
	foot = roundf(foot)
	var box := func(px: float, py: float, w: float, h: float, col: Color) -> void:
		# px from his middle, py up from his feet
		ci.draw_rect(Rect2(x + px * k, foot - py * k, w * k, h * k), col)
	var half := BODY_W * 0.5
	var skin := p.skin_color()
	var sleeve: Color = team.c1 if robe else skin
	var lift := roundf(wave)
	# behind the head: the arms that go up
	if arms == "up" or arms == "hold":
		box.call(-half - 3, BODY_H + 22 + lift, 4, 22 + lift, sleeve)
		box.call(half - 1, BODY_H + 22 - lift, 4, 22 - lift, sleeve)
		box.call(-half - 3, BODY_H + 26 + lift, 4, 4, skin)
		box.call(half - 1, BODY_H + 26 - lift, 4, 4, skin)
		if robe:
			box.call(-half - 3, BODY_H + 22 + lift, 4, 1, team.c2)
			box.call(half - 1, BODY_H + 22 - lift, 4, 1, team.c2)
	if robe:
		# the robe, to below his knees: a dark edge, the lapels and belt in the second colour
		box.call(-half - 1, BODY_H, BODY_W + 2, BODY_H - 5, team.c1)
		box.call(-half - 1, BODY_H, 1, BODY_H - 5, team.c1.darkened(0.3))
		box.call(half, BODY_H, 1, BODY_H - 5, team.c1.darkened(0.3))
		box.call(-half - 1, 6, BODY_W + 2, 1, team.c2)
		box.call(-1, BODY_H - 1, 2, BODY_H - 7, team.c2)
		box.call(-half, BODY_H - 11, BODY_W, 2, team.c2)
		box.call(-half + 3, 5, 4, 3, skin)
		box.call(half - 7, 5, 4, 3, skin)
		box.call(-half + 2, 2, 5, 2, Color("f2f2e9"))
		box.call(half - 7, 2, 5, 2, Color("f2f2e9"))
	else:
		box.call(-half + 1, BODY_H, BODY_W - 2, 12, skin)
		box.call(-half + 1, BODY_H - 12, BODY_W - 2, 5, team.c1)
		box.call(-half + 1, BODY_H - 12, BODY_W - 2, 1, team.c2)
		box.call(-half + 2, BODY_H - 17, 5, BODY_H - 19, skin)
		box.call(half - 7, BODY_H - 17, 5, BODY_H - 19, skin)
		box.call(-half + 1, 2, 6, 2, skin.darkened(0.15))
		box.call(half - 7, 2, 6, 2, skin.darkened(0.15))
	if arms == "down":
		box.call(-half - 3, BODY_H - 1, 4, 13, sleeve)
		box.call(half - 1, BODY_H - 1, 4, 13, sleeve)
	elif arms == "out":
		box.call(-half - 8, BODY_H - 2, BODY_W + 16, 4, sleeve)
	Portrait.draw_ours(ci, Vector2(x, foot - (BODY_H - HEAD_DROP) * k), p, team, int(k))
	if robe:
		# over the portrait's bare shoulders: the robe's, its collar, and the V at his neck
		box.call(-13, BODY_H + 2, 26, 8, team.c1)
		box.call(-13, BODY_H + 2, 1, 8, team.c1.darkened(0.3))
		box.call(12, BODY_H + 2, 1, 8, team.c1.darkened(0.3))
		box.call(-6, BODY_H + 2, 12, 2, team.c2)
		box.call(-2, BODY_H + 2, 4, 3, skin)
		box.call(-1, BODY_H - 1, 2, 3, team.c2)
