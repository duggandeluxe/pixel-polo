class_name PlayerArt
## A player as he looks in the pool (PoolArt's swimmer), drawn big for cards and the player page,
## with his own looks on top (looks()): what shows of his hair round the cap, his face, his build.

## Hair colours, darkest first. A player's skin tone picks from the start of the list (the darker
## his skin, the fewer, darker colours).
const HAIR := ["1a1410", "2e1d12", "4a2c18", "6b4226", "8a3b1c", "c0581f", "b8913f", "e3c77a"]
const HAIR_BY_SKIN := [8, 8, 6, 5, 3, 2]
const HAIRDOS := ["short", "long", "tuft", "mullet", "curls", "sideburns", "fringe"]
const FACES := ["clean", "clean", "clean", "stubble", "beard", "mustache", "goatee"]

## `bottom`: where his waterline sits (canvas px); `scale`: whole numbers keep the pixels crisp.
## `anim`: the swimmer's animation clock (the water stirs as it runs); `blink`: his eye shut.
static func draw(ci: CanvasItem, bottom: Vector2, p: PoloPlayer, cap: Color, trim: Color, design: String = "",
		scale: float = 3.0, arm := 0.0, anim := 0.0, blink := false) -> void:
	var view := PoolView.new()
	var sw := Swimmer.new(p, Swimmer.Side.US, p.is_keeper())
	sw.facing = 1.0
	sw.arm = arm
	sw.anim = anim
	sw.pos = view.to_world(bottom / scale)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale, scale))
	PoolArt.draw_body(ci, view, sw, cap, trim, design)
	var o := view.to_screen(sw.pos)
	var lk := looks(p)
	_draw_looks(ci, o, p, lk, cap)
	if blink:
		# the eye (PoolArt.draw_body's, facing right, standing still; a pixel lower with a heavy
		# brow) closes: a skin pixel over it
		ci.draw_rect(Rect2(o.x + 2, o.y - 9 + int(lk.brow), 1, 1), p.skin_color())
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Your team's caps (your cap design; keepers in red), as the match draws them.
static func draw_ours(ci: CanvasItem, bottom: Vector2, p: PoloPlayer, team: PoloTeam, scale: float = 3.0, arm := 0.0,
		anim := 0.0, blink := false) -> void:
	if p.is_keeper():
		draw(ci, bottom, p, PoolArt.CAP_KEEPER, team.c1, "", scale, arm, anim, blink)
		return
	var cap := Caps.base_color(Caps.selected(), Color("f2f2e9"))
	draw(ci, bottom, p, cap, Caps.trim_color(Caps.selected(), team.c1), Caps.selected(), scale, arm, anim, blink)

## How he looks: {hair (colour), hairdo, face, nose (0-2), brow (0, 1 heavy), build (0-2)}.
## Always the same for the same player, from his id (his name for a quick-match player), so he
## looks the same all career long; nothing here is saved.
static func looks(p: PoloPlayer) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["looks", p.id if p.id != 0 else hash(p.first + " " + p.last)])
	var n: int = HAIR_BY_SKIN[clampi(p.skin, 0, HAIR_BY_SKIN.size() - 1)]
	return {"hair": Color(HAIR[rng.randi_range(0, n - 1)]), "hairdo": HAIRDOS[rng.randi_range(0, HAIRDOS.size() - 1)],
		"face": FACES[rng.randi_range(0, FACES.size() - 1)], "nose": rng.randi_range(0, 2),
		"brow": 1 if rng.randf() < 0.3 else 0, "build": rng.randi_range(0, 2)}

## His looks over PoolArt.draw_body's swimmer (facing right, `o` his waterline, in its pixels).
## The head is x -3..3, y -11..-5 under the cap; the face is the two columns at the front.
static func _draw_looks(ci: CanvasItem, o: Vector2, p: PoloPlayer, lk: Dictionary, cap: Color) -> void:
	var px := func(dx: int, dy: int, w: int, h: int, col: Color) -> void:
		ci.draw_rect(Rect2(o.x + dx, o.y + dy, w, h), col)
	var skin := p.skin_color()
	var dark := skin.darkened(0.2)
	var hair: Color = lk.hair
	# build: broader shoulders breaking the surface
	if int(lk.build) >= 1:
		px.call(-7, -4, 1, 3, dark)
		px.call(6, -4, 1, 3, dark)
	if int(lk.build) >= 2:
		px.call(-8, -3, 1, 2, dark)
		px.call(7, -3, 1, 2, dark)
		px.call(-5, -5, 3, 1, skin)      # the light catching a big shoulder
	# what shows of his hair round the cap
	match String(lk.hairdo):
		"tuft":
			px.call(-5, -9, 1, 2, hair)
		"long":
			px.call(-5, -10, 1, 5, hair)
			px.call(-6, -7, 1, 3, hair)
		"mullet":
			px.call(-5, -8, 1, 3, hair)
			px.call(-6, -6, 1, 1, hair)
		"curls":
			for d in [Vector2i(-5, -10), Vector2i(-6, -9), Vector2i(-5, -8), Vector2i(-6, -7), Vector2i(-5, -6)]:
				px.call(d.x, d.y, 1, 1, hair)
		"sideburns":
			px.call(2, -8, 1, 2, hair)
		"fringe":
			px.call(3, -9, 1, 1, hair)
	# a heavy brow: the cap's brim comes down over the eye, a pixel lower
	if int(lk.brow) == 1:
		px.call(2, -9, 1, 1, cap)
		px.call(2, -8, 1, 1, PoolArt.EYE)
	match String(lk.face):
		"stubble":
			px.call(2, -5, 2, 1, skin.darkened(0.3))
			px.call(3, -6, 1, 1, skin.darkened(0.3))
		"beard":
			px.call(1, -5, 3, 1, hair)
			px.call(2, -6, 2, 1, hair)
		"mustache":
			px.call(2, -7, 2, 1, hair)
		"goatee":
			px.call(3, -5, 1, 1, hair)
	# his nose, in profile
	if int(lk.nose) >= 1:
		px.call(4, -8, 1, int(lk.nose), skin)
