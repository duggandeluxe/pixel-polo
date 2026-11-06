class_name TrophyArt
## The trophy room's trophies (the Trophy Room Visual Redesign): real trophies, pixel art made
## for DETAIL MODE (Game.set_detail), W x H art pixels drawn at two-thirds of a game pixel each,
## unfiltered, one dark outline round each.
##
## One system, so they read as one artist's set:
##   - every trophy stands on the same plinth (a dark wooden step on a wooden block with a brass
##     name plate), so the bases line up across a shelf, and is centred on it
##   - every metal has one four-tone ramp (shadow, dark, mid, light, highlight), lit from the upper
##     left; round things get the same cylindrical shading
##   - every trophy fits between TOP_MIN and the plinth, the most prestigious the tallest
## The trophies, each its own silhouette:
##   poy     a fluted gold column with a gold water polo ball on it (the tallest)
##   dpoy    a silver heater shield (dark rim, bevel, an inset border, a lightly engraved ball),
##           its point set into a black stepped pedestal
##   foy     a bevelled gold star on a slim stem (a rising star)
##   arm     a gold goal, its net engraved, a ball in the top corner (scoring)
##   wall    a gunmetal tower, stone courses and battlements, a gold ball set in it
##   first   a traditional gold two-handled cup on a footed stem
##   second  the same cup in silver, a little smaller
##   pot     a crystal obelisk, a ball etched in it (Player of the Tournament)
##   opot    a gold medallion with a ball, on a stand (Offensive Player of the Tournament)
##   dpot    a silver medallion with a shield, on a stand (Defensive Player of the Tournament)
## The NCSA's tournament trophies (ncsa) carry a gold star on their name plate; the
## conferences' plates are plain. Made once each into a texture and cached.

const W := 40
const H := 48
const TOP_MIN := 3        # nothing above this row
const STEP_Y := 35        # the plinth's top step: every trophy stands here

## The metals: [shadow, dark, mid, light, highlight].
const GOLD_R := [Color("6e4a06"), Color("b07d10"), Color("e2ac22"), Color("ffd84a"), Color("fff4b8")]
const SILVER_R := [Color("454c5a"), Color("7f8899"), Color("b4bdcb"), Color("dde3ec"), Color("ffffff")]
const IRON_R := [Color("1c1f27"), Color("363b47"), Color("555c6a"), Color("7f8797"), Color("aab2c0")]
const CRYSTAL_R := [Color("1d4fb8"), Color("3a86e8"), Color("74c4f7"), Color("bfe8ff"), Color("ffffff")]
const BRONZE_R := [Color("4a2408"), Color("8a4c16"), Color("c47a2c"), Color("eaa95a"), Color("ffe0b0")]
const WOOD_R := [Color("2a1408"), Color("4a2612"), Color("6b3a1e"), Color("8f5530"), Color("b47447")]
const OUT := Color("0a0f24")

## (kept for anything that names the old palette)
const GOLD := Color("ffd84a")
const SILVER := Color("dde3ec")

static var _cache := {}

## The trophy for honour `cat` (Honours' cat), as a texture of W x H.
static func texture(cat: String, ncsa := true) -> ImageTexture:
	var key := "%s|%s" % [cat, ncsa]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(image(cat, ncsa))
	return _cache[key]

## The trophy as an image (texture(), tests).
static func image(cat: String, ncsa := true) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_paint(img, cat, ncsa)
	_outline(img)
	return img

## Which trophy an honour gets (Honours entry -> its cat for texture()).
static func cat_of(e: Dictionary) -> String:
	match String(e.kind):
		"tourney", "national", "legacy", "title":
			return String(e.cat)
	return "poy"

static func _paint(img: Image, cat: String, ncsa: bool) -> void:
	_plinth(img, (ncsa and cat in ["pot", "opot", "dpot"]) or cat in ["ncsa_champ", "d3_champ"])
	match cat:
		"poy":
			_foot(img, 34, 12, GOLD_R)
			_cyl(img, 17, 22, 6, 12, GOLD_R)              # the column
			for y in range(23, 33):                       # its fluting
				_px(img, 18, y, GOLD_R[1])
				_px(img, 21, y, GOLD_R[1])
			_cyl(img, 15, 21, 10, 2, GOLD_R)              # its capital
			_cyl(img, 16, 19, 8, 2, GOLD_R)               # the cup the ball sits in
			_ball(img, 20, 11, 7, GOLD_R)
		"first":
			_cup(img, 6, 15, 22, GOLD_R)
		"second":
			_cup(img, 9, 13, 20, SILVER_R)
		"dpoy":
			_dpoy(img)
		"foy":
			_foot(img, 34, 10, GOLD_R)
			_cyl(img, 19, 23, 2, 11, GOLD_R)
			_star(img, 20, 13, 11, GOLD_R)
		"arm":
			_goal(img, GOLD_R)
		"wall":
			_tower(img, IRON_R)
		"pot":
			_foot(img, 34, 12, CRYSTAL_R)
			_obelisk(img, CRYSTAL_R)
		"conf_champ":
			_champ_cup(img, SILVER_R, false)
		"ncsa_champ":
			_champ_cup(img, GOLD_R, true)
		"d2_champ":   # (the Division II Championship: crystal, II on the bowl)
			_champ_cup(img, CRYSTAL_R, false)
			_numeral(img, 2)
		"d3_champ":   # (the NCSA Division III Championship: bronze on the grand plinth, III on the bowl)
			_champ_cup(img, BRONZE_R, false)
			_numeral(img, 3)
		"celebration":   # (an ordinary win's cup: no honour, never in the Trophy Room)
			_cup(img, 9, 13, 20, GOLD_R)
		"opot":
			_medal(img, GOLD_R, "ball")
		"dpot":
			_medal(img, SILVER_R, "shield")
		_:
			_cup(img, 9, 13, 20, SILVER_R)

# ------------------------------------------------------------------ the shared pieces
static func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, col)

static func _rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for yy in h:
		for xx in w:
			_px(img, x + xx, y + yy, col)

static func _solid(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H and img.get_pixel(x, y).a > 0.0

## One row from x0 to x1 (inclusive), shaded as a lit cylinder: a dark left rim, the light side,
## a highlight stripe, the body, the shaded side, a shadow rim.
static func _band(img: Image, y: int, x0: int, x1: int, r: Array) -> void:
	var w := x1 - x0 + 1
	for x in range(x0, x1 + 1):
		var t := (x - x0 + 0.5) / float(w)
		var c: Color = r[2]
		if w <= 2:
			c = r[3] if x == x0 else r[1]
		elif t < 0.1:
			c = r[1]
		elif t < 0.25:
			c = r[3]
		elif t < 0.36:
			c = r[4]
		elif t < 0.62:
			c = r[2]
		elif t < 0.88:
			c = r[1]
		else:
			c = r[0]
		_px(img, x, y, c)

## A cylinder `w` wide from (x, y), `h` rows.
static func _cyl(img: Image, x: int, y: int, w: int, h: int, r: Array) -> void:
	for yy in h:
		_band(img, y + yy, x, x + w - 1, r)

## A spreading foot ending on the step: `w` wide at the bottom row `bottom`, 3 rows.
static func _foot(img: Image, bottom: int, w: int, r: Array) -> void:
	for k in 3:
		var ww := w - (2 - k) * 2
		_band(img, bottom - 2 + k, 20 - ww / 2, 20 + ww / 2 - 1, r)

## The plinth: a dark wooden step (STEP_Y) on a wooden block, a brass name plate on its face
## (a gold star on it for the NCSA's).
static func _plinth(img: Image, star: bool) -> void:
	for y in range(STEP_Y, 38):
		_band(img, y, 11, 28, [WOOD_R[0], WOOD_R[1], WOOD_R[1], WOOD_R[2], WOOD_R[3]])
	for x in range(11, 29):
		_px(img, x, STEP_Y, WOOD_R[3])
	for y in range(38, 47):
		_band(img, y, 8, 31, WOOD_R)
	for x in range(8, 32):
		_px(img, x, 38, WOOD_R[4])
		_px(img, x, 46, WOOD_R[0])
	# the brass plate
	_rect(img, 13, 40, 14, 4, GOLD_R[2])
	_rect(img, 13, 40, 14, 1, GOLD_R[3])
	_rect(img, 13, 43, 14, 1, GOLD_R[1])
	_px(img, 13, 40, GOLD_R[4])
	if star:
		for p in [Vector2i(20, 40), Vector2i(19, 41), Vector2i(20, 41), Vector2i(21, 41), Vector2i(19, 42), Vector2i(21, 42)]:
			_px(img, p.x, p.y, GOLD_R[4])
		_px(img, 20, 42, GOLD_R[1])
	else:
		_rect(img, 15, 41, 10, 1, GOLD_R[1])   # (engraving)

static func _disc(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r * r + r:
				_px(img, cx + x, cy + y, col)

## A sphere in metal `r`: shaded from the upper left.
static func _sphere(img: Image, cx: int, cy: int, rad: int, r: Array) -> void:
	for y in range(-rad, rad + 1):
		for x in range(-rad, rad + 1):
			var d2 := x * x + y * y
			if d2 > rad * rad + rad:
				continue
			var lit := (-x - y) / float(rad * 2) + 0.15 - sqrt(float(d2)) / float(rad) * 0.35
			var c: Color = r[2]
			if lit > 0.45:
				c = r[4]
			elif lit > 0.2:
				c = r[3]
			elif lit < -0.45:
				c = r[0]
			elif lit < -0.15:
				c = r[1]
			_px(img, cx + x, cy + y, c)

## A water polo ball in metal: the sphere, its seams engraved.
static func _ball(img: Image, cx: int, cy: int, rad: int, r: Array) -> void:
	_sphere(img, cx, cy, rad, r)
	_seams(img, cx, cy, rad, r[1])

## A water polo ball's seams: two curves across it and one round it.
static func _seams(img: Image, cx: int, cy: int, rad: int, col: Color) -> void:
	for k in range(-rad + 1, rad):
		var y1 := int(round(sqrt(maxf(0.0, rad * rad - k * k)) * 0.45))
		_px(img, cx + k, cy - y1 + 1, col)
		_px(img, cx + k, cy + y1 - 1, col)
	for y in range(-rad + 2, rad - 1):
		_px(img, cx + int(round(sin(y / float(rad) * 1.4) * rad * 0.35)), cy + y, col)

static func _ring(img: Image, cx: int, cy: int, rad: int, col: Color) -> void:
	for i in 64:
		var a := i * TAU / 64.0
		_px(img, cx + int(round(cos(a) * rad)), cy + int(round(sin(a) * rad)), col)

## A one-pixel dark outline round the whole sprite, so it reads on any background.
static func _outline(img: Image) -> void:
	var solid := {}
	for y in H:
		for x in W:
			if img.get_pixel(x, y).a > 0.0:
				solid[Vector2i(x, y)] = true
	for k in solid:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = k + d
			if not solid.has(n) and n.x >= 0 and n.y >= 0 and n.x < W and n.y < H:
				img.set_pixel(n.x, n.y, OUT)

# ------------------------------------------------------------------ the trophies
## A traditional two-handled cup: a lipped bowl `w` wide from `top` (`bowl` rows, rounding in to
## the stem), a collar, a slim stem, a spreading foot on the step; ear handles either side.
static func _cup(img: Image, top: int, bowl: int, w: int, r: Array) -> void:
	_band(img, top, 20 - w / 2 - 1, 20 + w / 2, r)                  # the lip
	for x in range(20 - w / 2 + 1, 20 + w / 2 - 1):
		_px(img, x, top + 1, r[0])                                  # the inside of the rim
	for y in range(1, bowl):
		var t := float(y) / bowl
		var half := int(round((w / 2.0) * (1.0 - 0.72 * pow(t, 2.2))))
		if y == 1:
			_px(img, 20 - half, top + 1, r[1])
			_px(img, 20 + half - 1, top + 1, r[0])
			continue
		_band(img, top + y, 20 - half, 20 + half - 1, r)
	var y0 := top + bowl
	_cyl(img, 17, y0, 6, 2, r)                                      # the collar
	_cyl(img, 19, y0 + 2, 2, 31 - (y0 + 2), r)                      # the stem
	_cyl(img, 18, 30, 4, 1, r)                                      # its knot
	_foot(img, 34, 12, r)
	# the handles: ears from under the lip to halfway down the bowl
	var hy0 := top + 2
	var hy1 := top + int(bowl * 0.62)
	for side: int in [-1, 1]:
		var edge := 20 + side * (w / 2) + (0 if side > 0 else -1)
		for y in range(hy0, hy1 + 1):
			var out := 3 if y > hy0 and y < hy1 else 1
			var x := edge + side * out
			_px(img, x, y, r[3] if side < 0 else r[1])
			if y == hy0 or y == hy1:
				for k in range(1, 3):
					_px(img, edge + side * k, y, r[2])

## A CHAMPIONSHIP CUP (the team trophy case): a deep lidded cup on a tall footed stem, wide ear
## handles, a ball on the lid; the NCSA's gold and grander (a laurel band round the bowl, a star
## on its plate), a conference's silver.
## `n` gold bars on a championship cup's bowl: its division's Roman numeral.
static func _numeral(img: Image, n: int) -> void:
	for i in n:
		var x := 20 - n * 2 + i * 4 + 1
		for y in range(15, 21):
			_px(img, x, y, GOLD_R[3])
			_px(img, x + 1, y, GOLD_R[1])

static func _champ_cup(img: Image, r: Array, grand: bool) -> void:
	_cyl(img, 19, 25, 2, 7, r)                                     # the stem
	_cyl(img, 17, 23, 6, 2, r)                                     # its collar
	_cyl(img, 18, 29, 4, 1, r)                                     # a knot
	_foot(img, 34, 14, r)
	# the bowl: deep, nearly straight-sided, rounding into the collar
	var top := 12
	var bowl := 11
	for y in bowl:
		var t := float(y) / bowl
		var half := int(round(10.0 * (1.0 - 0.55 * pow(t, 3.0))))
		_band(img, top + y, 20 - half, 20 + half - 1, r)
	_band(img, top, 9, 30, r)                                       # the rim
	if grand:
		for x in range(11, 29, 2):                                  # a laurel band
			_px(img, x, top + 5, GOLD_R[4])
			_px(img, x + 1, top + 6, GOLD_R[1])
	# the lid and its ball
	_band(img, top - 1, 11, 28, r)
	_band(img, top - 2, 13, 26, r)
	_band(img, top - 3, 16, 23, r)
	_cyl(img, 19, top - 5, 2, 2, r)
	_sphere(img, 20, top - 7, 3, GOLD_R)
	# wide ear handles
	for side: int in [-1, 1]:
		var e := 20 + side * 10 + (0 if side > 0 else -1)
		for y in range(top + 1, top + 10):
			var out := 4 if y > top + 2 and y < top + 8 else (2 if y == top + 1 or y == top + 9 else 3)
			_px(img, e + side * out, y, r[3] if side < 0 else r[1])
			_px(img, e + side * (out - 1), y, r[2])
		_px(img, e + side, top + 1, r[2])
		_px(img, e + side, top + 9, r[2])

## A heater shield `w` wide from `top`, `h` tall: square shoulders, curving to a point; bevelled,
## the light on its left half, a raised rim.
static func _shield(img: Image, top: int, h: int, w: int, r: Array) -> void:
	var halves: Array = []
	for y in h:
		var t := float(y) / h
		# straight sides to 55%, then two gently curved edges meeting in a point
		var half := w / 2.0 if t < 0.55 else (w / 2.0) * (1.0 - pow((t - 0.55) / 0.45, 1.35))
		halves.append(maxi(1, int(round(half))))
	for y in h:
		var half: int = halves[y]
		for x in range(20 - half, 20 + half):
			var c: Color = r[3] if x < 20 else r[2]
			_px(img, x, top + y, c)
	# the raised rim, then an inset border line two pixels in
	for y in h:
		var half: int = halves[y]
		_px(img, 20 - half, top + y, r[1])
		_px(img, 20 + half - 1, top + y, r[0])
		if y >= 2 and y < h - 3 and half > 3:
			_px(img, 20 - half + 2, top + y, r[4])
			_px(img, 20 + half - 3, top + y, r[1])
	for x in range(20 - w / 2, 20 + w / 2):
		_px(img, x, top, r[4] if x < 20 else r[3])
		if x > 20 - w / 2 + 1 and x < 20 + w / 2 - 2:
			_px(img, x, top + 2, r[4] if x < 20 else r[1])

## DEFENSIVE PLAYER OF THE YEAR: a traditional silver heater shield, symmetrical, its sides
## straight then curving to a point; a darker silver rim, a lit bevel on its upper left, a shaded
## one lower right, an inset border, a soft diagonal sheen and a small engraved ball. Its point is
## set into a two-step black pedestal on the plinth.
static func _dpoy(img: Image) -> void:
	var r: Array = SILVER_R
	var k: Array = IRON_R
	# the shield: half-widths a row, symmetric about the middle (x 20 is the right half's first)
	var top := 4
	var h := 25                                       # (its point on the pedestal's cap)
	var halves: Array = []
	for y in h:
		var t := float(y) / (h - 1)
		var half := 10.0
		if y == 0:
			half = 9.0                                   # (rounded top corners)
		elif t > 0.5:
			half = 10.0 * (1.0 - pow((t - 0.5) / 0.5, 1.7))   # (convex edges meeting in a point)
		halves.append(maxi(1, int(round(half))))
	for y in h:
		var half: int = halves[y]
		for x in range(20 - half, 20 + half):
			var dx := x - 20 + 0.5
			# the face: lighter to the upper left, a soft sheen across it, darker to the lower right
			var lit := -dx / 10.0 * 0.5 - (y - h * 0.5) / float(h) * 0.5
			var sheen := absf((x - 20) + (y - 10) * 0.8) < 0.9 and lit <= 0.05
			var c: Color = r[3] if lit > 0.05 else r[2]
			if lit < -0.32:
				c = r[1]
			if sheen and y > 2 and y < h - 6:
				c = r[4]
			_px(img, x, top + y, c)
	# the inset border, two pixels in: a light line on the lit sides, a dark one on the others
	for y in range(2, h - 3):
		var half: int = halves[y] - 2
		if half < 2:
			continue
		_px(img, 20 - half, top + y, r[4])
		_px(img, 20 + half - 1, top + y, r[1])
	for x in range(20 - halves[2] + 2, 20 + halves[2] - 2):
		_px(img, x, top + 2, r[4] if x < 20 else r[3])
	# the rim: one darker pixel all round (the outline goes outside it)
	for y in h:
		var half: int = halves[y]
		_px(img, 20 - half, top + y, r[1])
		_px(img, 20 + half - 1, top + y, r[0])
		if y == h - 1 or halves[mini(y + 1, h - 1)] < half:
			# the edge steps in below: the rows under the step are rim too
			var below: int = halves[mini(y + 1, h - 1)] if y < h - 1 else 0
			for x in range(20 - half, 20 - below):
				_px(img, x, top + y, r[1])
			for x in range(20 + below, 20 + half):
				_px(img, x, top + y, r[0])
	for x in range(20 - halves[0], 20 + halves[0]):
		_px(img, x, top, r[1])
	# the engraved ball, small, in the upper middle
	_ring(img, 20, top + 10, 4, r[1])
	_seams(img, 20, top + 10, 4, r[1])
	# the pedestal, in front of the shield's point (set into it): a black block on a wider step
	for y in range(31, STEP_Y):
		_band(img, y, 13, 26, [k[0], k[1], k[1], k[2], k[3]])
	for x in range(13, 27):
		_px(img, x, 31, k[3])
	for y in range(25, 31):
		_band(img, y, 15, 24, [k[0], k[1], k[2], k[2], k[3]])
	for x in range(15, 25):
		_px(img, x, 25, k[4])
	_rect(img, 18, 28, 4, 1, r[2])                    # (a small silver strip on its face)

## A five-pointed star `rad` across from (cx, cy), bevelled: each point lit on one side.
static func _star(img: Image, cx: int, cy: int, rad: int, r: Array) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := deg_to_rad(-90.0 + i * 36.0)
		var rr := float(rad) if i % 2 == 0 else rad * 0.44
		pts.append(Vector2(cx + 0.5 + cos(a) * rr, cy + 0.5 + sin(a) * rr))
	for y in range(cy - rad, cy + rad + 1):
		for x in range(cx - rad, cx + rad + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			if not Geometry2D.is_point_in_polygon(p, pts):
				continue
			# which facet: the angle round the centre against the nearest point's
			var a := fposmod(atan2(p.y - cy - 0.5, p.x - cx - 0.5) + PI / 2.0, TAU)
			var seg := fposmod(a, TAU / 5.0) / (TAU / 5.0)
			var c: Color = r[3] if seg < 0.5 else r[1]
			if absf(seg - 0.5) < 0.06 or seg < 0.04 or seg > 0.96:
				c = r[2]
			if y < cy - rad * 0.4 and seg < 0.5:
				c = r[4]
			_px(img, x, y, c)

## A goal: two posts and a crossbar in gold, the net engraved behind (a solid back, a lattice),
## a ball tucked in the top corner, on two small feet.
static func _goal(img: Image, r: Array) -> void:
	var x0 := 9
	var x1 := 30
	var y0 := 8
	var y1 := 31
	for y in range(y0 + 3, y1):
		for x in range(x0 + 3, x1 - 2):
			var net := (x - x0) % 3 == 0 or (y - y0) % 3 == 0
			_px(img, x, y, r[2] if net else r[0])
	_cyl(img, x0, y0, x1 - x0 + 1, 3, r)                        # the crossbar
	for x in [x0, x1 - 2]:
		_cyl(img, x, y0, 3, y1 - y0, r)                          # the posts
	_cyl(img, x0, y1, x1 - x0 + 1, 1, r)                         # the bottom rail
	_rect(img, x0 + 1, y1 + 1, 4, 3, r[1])                       # its feet on the step
	_rect(img, x1 - 4, y1 + 1, 4, 3, r[1])
	_rect(img, x0 + 1, y1 + 1, 4, 1, r[3])
	_rect(img, x1 - 4, y1 + 1, 4, 1, r[3])
	_ball(img, 24, 15, 5, r)

## A tower: a gunmetal body on the step, stone courses, battlements, a gold ball set in its face.
static func _tower(img: Image, r: Array) -> void:
	var x0 := 11
	var w := 18
	for y in range(9, STEP_Y):
		_band(img, y, x0, x0 + w - 1, [r[0], r[1], r[2], r[3], r[3]])
	for m in 4:                                              # the battlements: 3 on, 2 off
		var mx := x0 + m * 5
		for y in range(5, 9):
			_band(img, y, mx, mx + 2, [r[1], r[3], r[3], r[2], r[1]])
	for y in range(13, STEP_Y - 1, 4):                       # the stone courses
		for x in range(x0 + 1, x0 + w - 1):
			_px(img, x, y, r[0])
		var off := 2 if (y / 4) % 2 == 0 else 5
		for x in range(x0 + off, x0 + w - 1, 6):
			for k in range(1, 4):
				if y + k < STEP_Y:
					_px(img, x, y + k, r[0])
	_rect(img, x0, 9, w, 1, r[4])                            # the ledge under the battlements
	# the ball, set in a round recess
	_disc(img, 20, 20, 6, r[0])
	_ball(img, 20, 20, 5, GOLD_R)

## A crystal obelisk: a pointed top, gently tapering faces (light, clear, shade), a ball etched in it.
static func _obelisk(img: Image, r: Array) -> void:
	for y in range(TOP_MIN + 1, 32):
		var half := 0
		if y < 10:
			half = 1 + int((y - TOP_MIN - 1) * 0.9)
		else:
			half = int(round(lerpf(7.0, 5.0, (y - 10) / 22.0)))
		for x in range(20 - half, 20 + half):
			var t := (x - (20 - half)) / float(half * 2)
			var c: Color = r[2]
			if t < 0.2:
				c = r[3]
			elif t < 0.3:
				c = r[4]
			elif t > 0.7:
				c = r[1]
			if t > 0.92:
				c = r[0]
			_px(img, x, y, c)
	_ring(img, 20, 19, 4, r[4])
	_seams(img, 20, 19, 4, r[4])

## A medallion on a stand: a thick rimmed disc (`emblem` struck on it), a short neck, a foot.
static func _medal(img: Image, r: Array, emblem: String) -> void:
	_foot(img, 34, 12, r)
	_cyl(img, 18, 25, 4, 8, r)
	_sphere(img, 20, 14, 10, r)                                 # the rim
	_disc(img, 20, 14, 7, r[1])
	_sphere(img, 20, 14, 7, [r[1], r[1], r[2], r[3], r[3]])     # the face
	if emblem == "ball":
		_ring(img, 20, 14, 4, r[0])
		_seams(img, 20, 14, 4, r[0])
	else:
		for y in 8:
			var half := 4 if y < 4 else 4 - (y - 3)
			for x in range(20 - half, 20 + half):
				_px(img, x, 10 + y, r[0] if x >= 20 else r[1])
