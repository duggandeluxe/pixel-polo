class_name Portrait
extends RefCounted
## A player's front-facing headshot (the Player Portrait Sprite Upgrade): the sports-card portrait
## on his roster and recruiting card and on his page. Pixel art made for its size, SIZE (26 x 29
## px: the card's portrait panel exactly at 1x, whole multiples on his page), one pixel a pixel,
## drawn unfiltered:
##   his water polo cap (your cap colours, a keeper's red), its brim trim, a shine on the dome; the
##   round ear guards with their holes; the chin strap; his face (its width, jaw and length), its
##   outline and shading; brows, eyes, nose and mouth in a handful of shapes each; his facial hair
##   and the hair that shows round the cap (PlayerArt.looks, so it's the same hair the pool sprite
##   has); neck and shoulders by his build.
## Everything is picked from his id (traits(): "portrait", id), so a player looks the same on every
## screen, every game and every load, and nothing is saved. Made once into a texture and cached.

const SIZE := Vector2i(26, 29)
const CX := 13                     # the face is symmetric about the line between columns 12 and 13
const EYE_WHITE := Color("f2efe6")
const PUPIL := Color("1c1410")
const LIP := Color("9a4a3c")

const BROWS := ["flat", "flat", "thick", "angry", "worried", "raised"]
const EYES := ["wide", "wide", "dot", "tall", "narrow"]
const NOSES := ["small", "long", "wide", "button"]
const MOUTHS := ["neutral", "neutral", "smile", "grin", "serious", "smirk"]
const JAWS := ["round", "square", "pointed"]

static var _cache := {}

## His portrait's traits: {face_w, jaw, chin, eye, gap, look, brow, nose, mouth} and his
## PlayerArt.looks (hair, hairdo, face: his facial hair, build). Always the same for the same player.
static func traits(p: PoloPlayer) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["portrait", p.id if p.id != 0 else hash(p.first + " " + p.last)])
	var t := PlayerArt.looks(p)
	t["face_w"] = [10, 12, 12][rng.randi_range(0, 2)]
	t["jaw"] = JAWS[rng.randi_range(0, JAWS.size() - 1)]
	t["chin"] = 17 + rng.randi_range(0, 1)
	t["eye"] = EYES[rng.randi_range(0, EYES.size() - 1)]
	t["gap"] = [2, 2, 4][rng.randi_range(0, 2)]
	t["look"] = rng.randi_range(-1, 1)       # where a wide eye's pupil sits: in, centre (in), out
	t["brow"] = BROWS[rng.randi_range(0, BROWS.size() - 1)]
	t["nose"] = NOSES[rng.randi_range(0, NOSES.size() - 1)]
	t["mouth"] = MOUTHS[rng.randi_range(0, MOUTHS.size() - 1)]
	return t

## The headshot as a texture (cached): his cap `cap`, its trim `trim`; `blink` his eyes shut.
static func texture(p: PoloPlayer, cap: Color, trim: Color, blink := false) -> Texture2D:
	var key := "%d|%s|%d|%s|%s|%s" % [p.id, p.first + p.last, p.skin, cap.to_html(), trim.to_html(), blink]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 600:
		_cache.clear()
	var tex := ImageTexture.create_from_image(image(p, cap, trim, blink))
	_cache[key] = tex
	return tex

## Your team's colours for him, as the match has them: your cap design's base and trim; a
## keeper's cap red with your colour for its trim.
static func colors_ours(p: PoloPlayer, team: PoloTeam) -> Array:
	if p.is_keeper():
		return [PoolArt.CAP_KEEPER, team.c1]
	return [Caps.base_color(Caps.selected(), Color("f2f2e9")), Caps.trim_color(Caps.selected(), team.c1)]

## The card's headshot size (the Portrait Zoom update): the same art about 38% bigger.
const CARD_ZOOM := Vector2i(36, 40)

## The headshot at `size` (cached): every pixel of it one of the art's own, picked nearest
## (no new colours, no blur), the columns mirror-symmetric about the face's centre line so both
## eyes, cheeks and ear guards come out the same width. (An even width never lands a column on a
## source pixel's edge, so the mapping mirrors exactly.)
static func texture_zoomed(p: PoloPlayer, cap: Color, trim: Color, size: Vector2i, blink := false) -> Texture2D:
	var key := "%d|%s|%d|%s|%s|%s|%s" % [p.id, p.first + p.last, p.skin, cap.to_html(), trim.to_html(), blink, size]
	if _cache.has(key):
		return _cache[key]
	var src := image(p, cap, trim, blink)
	var out := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		var sy := mini(SIZE.y - 1, int(floorf((y + 0.5) * SIZE.y / float(size.y))))
		for x in size.x:
			var sx := mini(SIZE.x - 1, int(floorf((x + 0.5) * SIZE.x / float(size.x))))
			out.set_pixel(x, y, src.get_pixel(sx, sy))
	var tex := ImageTexture.create_from_image(out)
	_cache[key] = tex
	return tex

## Draws him zoomed to `size` (texture_zoomed) with his top centre at `top`.
static func draw_zoomed(ci: CanvasItem, top: Vector2, p: PoloPlayer, team: PoloTeam, size: Vector2i, blink := false) -> void:
	var col := colors_ours(p, team)
	var tex := texture_zoomed(p, col[0], col[1], size, blink)
	ci.draw_texture_rect(tex, Rect2(Vector2(roundf(top.x - size.x * 0.5), top.y), Vector2(size)), false)

## Draws him `scale` x (whole numbers) with his bottom centre at `bottom`.
static func draw_ours(ci: CanvasItem, bottom: Vector2, p: PoloPlayer, team: PoloTeam, scale := 1, blink := false) -> void:
	var col := colors_ours(p, team)
	var tex := texture(p, col[0], col[1], blink)
	var sz := Vector2(SIZE) * scale
	ci.draw_texture_rect(tex, Rect2(Vector2(roundf(bottom.x - sz.x * 0.5), bottom.y - sz.y), sz), false)

# ------------------------------------------------------------------ the pixels
static func image(p: PoloPlayer, cap: Color, trim: Color, blink := false) -> Image:
	var img := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var t := traits(p)
	var put := func(x: int, y: int, col: Color) -> void:
		if x >= 0 and y >= 0 and x < SIZE.x and y < SIZE.y:
			img.set_pixel(x, y, col)
	var row := func(x0: int, x1: int, y: int, col: Color) -> void:
		for x in range(x0, x1 + 1):
			put.call(x, y, col)
	var skin := p.skin_color()
	var shade := skin.darkened(0.16)
	var deep := skin.darkened(0.3)
	var line := skin.darkened(0.6)
	var hair: Color = t.hair
	var fw: int = t.face_w
	var left := CX - fw / 2
	var right := CX - 1 + fw / 2
	var chin: int = t.chin
	var build: int = t.build
	# ---- shoulders and neck (behind everything)
	var neck_w := 6 + (2 if build >= 1 else 0)
	var nl := CX - neck_w / 2
	var nr := CX - 1 + neck_w / 2
	var sh_w := 18 + build * 2
	var y := chin + 4
	var w := neck_w + 6
	while y < SIZE.y:
		var a := CX - w / 2
		var b := CX - 1 + w / 2
		row.call(a, b, y, skin)
		row.call(CX + 1, b, y, shade)                 # the light from the left
		put.call(a, y, line)
		put.call(b, y, line)
		if y == chin + 4:
			row.call(a, b, y - 1, line)              # the shoulders' top edge
		w = mini(sh_w, w + 4)
		y += 1
	# the collarbones
	put.call(CX - 4, chin + 6, deep)
	put.call(CX + 3, chin + 6, deep)
	for yy in range(chin + 1, chin + 4):
		row.call(nl, nr, yy, shade)
		put.call(nl - 1, yy, line)
		put.call(nr + 1, yy, line)
	row.call(nl, nr, chin + 1, deep)                  # the shadow under his chin
	# long hair or a mullet behind the neck
	if String(t.hairdo) in ["long", "mullet"]:
		for yy in range(chin - 2 if t.hairdo == "long" else chin, chin + 3):
			put.call(nl - 2, yy, hair)
			put.call(nr + 2, yy, hair)
	# ---- the face
	var inset: Array = {"round": [1, 2, 3], "square": [0, 1, 2], "pointed": [1, 2, 4]}[t.jaw]
	for yy in range(7, chin + 1):
		var k := yy - (chin - 2)
		var i: int = inset[k] if k >= 0 else 0
		row.call(left + i, right - i, yy, skin)
		row.call(right - i - 1, right - i, yy, shade)   # his right cheek in shadow
		put.call(left + i - 1, yy, line)
		put.call(right - i + 1, yy, line)
	var ci_last: int = inset[2]
	row.call(left + ci_last, right - ci_last, chin + 1, line)   # under the chin
	row.call(left, right, 7, shade)                   # the cap's shadow on his forehead
	put.call(left + 2, 8, skin.lightened(0.18))
	put.call(left + 3, 8, skin.lightened(0.18))
	# ---- facial hair, under the features
	var whisker := hair.lerp(skin, 0.15)
	match String(t.face):
		"stubble":
			for yy in range(chin - 3, chin + 1):
				for x in range(left + 1, right):
					if (x + yy) % 2 == 0 and img.get_pixel(x, yy) != Color(0, 0, 0, 0) and img.get_pixel(x, yy) != line:
						put.call(x, yy, skin.darkened(0.28))
		"beard":
			for yy in range(13, chin + 1):
				var k := yy - (chin - 2)
				var i: int = inset[k] if k >= 0 else 0
				put.call(left + i, yy, whisker)
				put.call(right - i, yy, whisker)
				if yy >= chin - 1:
					row.call(left + i, right - i, yy, whisker)
			row.call(CX - 3, CX + 2, 14, whisker)
		"mustache":
			row.call(CX - 2, CX + 1, 14, whisker)
		"goatee":
			row.call(CX - 2, CX + 1, chin - 1, whisker)
			row.call(CX - 1, CX, chin, whisker)
	# ---- brows
	var brow_col := hair.darkened(0.25)
	var gap: int = t.gap
	var ew := 1 if String(t.eye) in ["dot", "tall"] else 2
	var le := CX - gap / 2 - ew          # the left eye's first column
	var re := CX + gap / 2               # the right eye's first column
	var bl := [le - 1, le + ew - 1]      # a brow spans its eye and a pixel outside
	var br := [re, re + ew]
	match String(t.brow):
		"flat":
			row.call(bl[0], bl[1], 9, brow_col)
			row.call(br[0], br[1], 9, brow_col)
		"thick":
			row.call(bl[0], bl[1], 9, brow_col)
			row.call(br[0], br[1], 9, brow_col)
			row.call(bl[0], bl[1] - 1, 8, brow_col)
			row.call(br[0] + 1, br[1], 8, brow_col)
		"angry":
			put.call(bl[0], 8, brow_col)
			row.call(bl[0] + 1, bl[1], 9, brow_col)
			put.call(br[1], 8, brow_col)
			row.call(br[0], br[1] - 1, 9, brow_col)
		"worried":
			row.call(bl[0], bl[1] - 1, 9, brow_col)
			put.call(bl[1], 8, brow_col)
			put.call(br[0], 8, brow_col)
			row.call(br[0] + 1, br[1], 9, brow_col)
		"raised":
			row.call(bl[0], bl[1], 9, brow_col)
			row.call(br[0], br[1], 8, brow_col)
	# ---- eyes
	if blink:
		row.call(le, le + ew - 1, 11, line)
		row.call(re, re + ew - 1, 11, line)
	else:
		match String(t.eye):
			"wide":
				var look: int = t.look
				for e in [[le, true], [re, false]]:
					var x0: int = e[0]
					var inner: bool = e[1]
					# white and pupil; the pupil inward unless he looks out
					var pupil_right := inner if look <= 0 else not inner
					put.call(x0, 10, EYE_WHITE)
					put.call(x0 + 1, 10, EYE_WHITE)
					put.call(x0 + (1 if pupil_right else 0), 10, PUPIL)
					put.call(x0 + (1 if pupil_right else 0), 11, PUPIL)
					put.call(x0 + (0 if pupil_right else 1), 11, shade)
			"dot":
				put.call(le, 10, PUPIL)
				put.call(re, 10, PUPIL)
			"tall":
				for x0 in [le, re]:
					put.call(x0, 10, PUPIL)
					put.call(x0, 11, PUPIL)
			"narrow":
				row.call(le, le + 1, 11, PUPIL)
				row.call(re, re + 1, 11, PUPIL)
				row.call(le, le + 1, 10, deep)
				row.call(re, re + 1, 10, deep)
	# ---- nose
	match String(t.nose):
		"small":
			put.call(CX, 13, deep)
		"long":
			put.call(CX, 11, shade)
			put.call(CX, 12, deep)
			row.call(CX - 1, CX, 13, deep)
		"wide":
			put.call(CX - 2, 13, deep)
			put.call(CX + 1, 13, deep)
			put.call(CX - 1, 12, skin.lightened(0.12))
		"button":
			row.call(CX - 1, CX, 13, deep)
	# ---- mouth (a mustache sits above it)
	var my := 15 if chin >= 17 else 14
	match String(t.mouth):
		"neutral":
			row.call(CX - 2, CX + 1, my, LIP)
		"smile":
			row.call(CX - 2, CX + 1, my, LIP)
			put.call(CX - 3, my - 1, LIP)
			put.call(CX + 2, my - 1, LIP)
		"grin":
			row.call(CX - 2, CX + 1, my, EYE_WHITE)
			put.call(CX - 3, my, LIP)
			put.call(CX + 2, my, LIP)
			row.call(CX - 2, CX + 1, my + 1, LIP)
		"serious":
			row.call(CX - 1, CX, my, LIP)
			put.call(CX - 2, my + 1, LIP)
			put.call(CX + 1, my + 1, LIP)
		"smirk":
			row.call(CX - 2, CX + 1, my, LIP)
			put.call(CX + 2, my - 1, LIP)
	# ---- hair that shows round the cap
	match String(t.hairdo):
		"sideburns":
			for yy in range(7, 10):
				put.call(left, yy, hair)
				put.call(right, yy, hair)
		"fringe":
			for x in [CX - 3, CX - 2, CX, CX + 2]:
				put.call(x, 7, hair)
		"tuft":
			put.call(left + 1, 7, hair)
			put.call(left + 2, 7, hair)
		"curls":
			for x in [left, left + 2, right - 2, right]:
				put.call(x, 7, hair)
	# ---- the cap: dome, brim, shine
	var cap_dark := cap.darkened(0.42)
	var cap_mid := cap.darkened(0.14)
	var dome := [[fw - 4, 0], [fw - 1, 1], [fw + 2, 2], [fw + 2, 3], [fw + 2, 4], [fw + 2, 5], [fw + 2, 6]]
	for d in dome:
		var dw: int = d[0]
		var dy: int = d[1]
		var a := CX - dw / 2 - (dw % 2)
		var b := CX - 1 + dw / 2
		row.call(a, b, dy, cap)
		row.call(CX + 2, b, dy, cap_mid)              # the dome turning away from the light
		put.call(a, dy, cap_dark)
		put.call(b, dy, cap_dark)
		if dy == 0:
			row.call(a, b, dy, cap_dark)
	row.call(CX - (fw + 2) / 2, CX - 1 + (fw + 2) / 2, 6, trim)   # the brim's trim
	put.call(CX - (fw + 2) / 2, 6, cap_dark)
	put.call(CX - 1 + (fw + 2) / 2, 6, cap_dark)
	row.call(CX - 4, CX - 2, 1, cap.lightened(0.4))   # the shine
	put.call(CX - 5, 2, cap.lightened(0.4))
	# ---- the ear guards: round, the cap's colour, a ring of holes
	for side in [-1, 1]:
		var gx := left - 3 if side < 0 else right   # (over the face's edge column only: never an eye)
		var cols := [[1, 2], [0, 3], [0, 3], [0, 3], [1, 2]]
		for i in cols.size():
			var gy := 8 + i
			var span: Array = cols[i]
			for x in range(gx + int(span[0]), gx + int(span[1]) + 1):
				put.call(x, gy, cap)
			put.call(gx + int(span[0]), gy, cap_dark)
			put.call(gx + int(span[1]), gy, cap_dark)
		put.call(gx + 1, 7, cap_dark)
		put.call(gx + 2, 7, cap_dark)
		put.call(gx + 1, 13, cap_dark)
		put.call(gx + 2, 13, cap_dark)
		put.call(gx + 1, 10, cap_dark)                # the holes
		put.call(gx + 2, 10, cap_dark)
		put.call(gx + 1, 9, cap_mid)
		put.call(gx + 2, 11, cap_mid)
		# the strap from the guard down under his chin
		var sx := gx + (1 if side < 0 else 2)
		var sy := 14
		while sy <= chin + 1:
			put.call(sx, sy, trim.darkened(0.2))
			sy += 1
			if sy % 2 == 0:
				sx += 1 if side < 0 else -1
	return img
