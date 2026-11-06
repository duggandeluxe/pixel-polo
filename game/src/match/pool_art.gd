class_name PoolArt
## Pixel art for the pool, the players and the ball, drawn with plain rects so it stays
## crisp at 480x270. Players face the way they swim; sprites mirror with `facing`.

const LANE_GREEN := Color("31e27c")
const WATER_DARK := Color("064fc0")    # dark water accents: the water a swimmer sits in
const CAP_KEEPER := Color("d9423b")
const FRAME := Color("f2f2e9")
const BALL := Color("ffd84a")
const BALL_LINE := Color("2e5bd6")
const EYE := Color("1a1a1a")
const CROWD := ["ffcf3f", "ff6fae", "39c2ff", "f2f2e9", "5fd35f", "ff8a3d", "b388ff", "c9d3dd"]

# ------------------------------------------------------------------ pool
## `pool` is the venue (Pools); null draws the default pool. `crowd` 0..1 is how full the
## stands are.
## `net`: a ball in a net, {x: that goal's line, y: where it hit, t: Ball.net_t}, and the net
## gives where it's hit.
static func draw_pool(ci: CanvasItem, v: PoolView, t: float, size: Vector2, excite: float,
		pool: PoolDef = null, crowd: float = 1.0, net: Dictionary = {}, style: Dictionary = {}) -> void:
	if pool == null:
		pool = Pools.get_def()
	ci.draw_rect(Rect2(Vector2.ZERO, size), pool.deck)
	_deck_tiles(ci, v, size, pool)
	_stands(ci, v, t, size, excite, pool, crowd, style)
	var a := v.to_screen(Vector2(-1.5, 0.0))
	var b := v.to_screen(Vector2(Geo.LENGTH + 1.5, Geo.WIDTH))
	var wr := Rect2(a, b - a).abs()
	ci.draw_rect(Rect2(wr.position - Vector2(3, 3), wr.size + Vector2(6, 6)), pool.deck_dark)
	ci.draw_rect(wr, pool.water)
	# the deep middle of the pool: one flat band of the secondary blue
	ci.draw_rect(Rect2(wr.position + Vector2(0, wr.size.y * 0.3), Vector2(wr.size.x, wr.size.y * 0.4)), pool.water_deep)
	for yy in [2.5, 7.5, 12.5, 17.5]:
		var l0 := v.to_screen(Vector2(-0.5, yy))
		var l1 := v.to_screen(Vector2(Geo.LENGTH + 0.5, yy))
		ci.draw_rect(Rect2(minf(l0.x, l1.x), l0.y, absf(l1.x - l0.x), 3), pool.tile_line)
	for i in 110:
		var wx := fposmod(i * 7.31 + t * (0.25 + (i % 5) * 0.05), 33.0) - 1.5
		var wy := fposmod(i * 3.77 + sin(t * 0.7 + i) * 0.3, Geo.WIDTH)
		var sp := v.to_screen(Vector2(wx, wy))
		if sp.x < -4 or sp.x > size.x or sp.y < 0 or sp.y > size.y:
			continue
		ci.draw_rect(Rect2(sp.x, sp.y, 2 + i % 3, 1), pool.water_shine)
	for m in [[2.0, UI.LANE_RED], [5.0, UI.LANE_YELLOW], [6.0, LANE_GREEN]]:
		_dash_line(ci, v, m[0], m[1])
		_dash_line(ci, v, Geo.LENGTH - m[0], m[1])
	_dash_line(ci, v, Geo.HALF, UI.LANE_WHITE)
	_rope(ci, v, -0.1)
	_rope(ci, v, Geo.WIDTH + 0.1)
	var give := Ball.net_bulge(float(net.get("t", -1.0)))
	var hit_y := float(net.get("y", Geo.GOAL_Y))
	var fx := net_fx(net, t)
	var nx := float(net.get("x", -1.0))
	draw_goal(ci, v, 0.0, -1.0, give if nx == 0.0 else 0.0, hit_y, fx if nx == 0.0 else {})
	draw_goal(ci, v, Geo.GOAL_X, 1.0, give if nx == Geo.GOAL_X else 0.0, hit_y, fx if nx == Geo.GOAL_X else {})

const NET_SHIVER := 0.35   # s the net shivers after a ball comes in off the frame (BarHit)...
const SHIVER_PX := 1.5     # ...this many px at first

## A ball in off the frame (BarHit; MatchScreen._net's in_t / in_y): the net snaps back where it
## came in as well as where it lands, and shivers after each. {} for any other goal.
static func net_fx(net: Dictionary, t: float) -> Dictionary:
	if not net.has("in_t"):
		return {}
	var in_t := float(net.in_t)
	var hit_t := float(net.get("t", -1.0))
	var shiver := 1.0 - clampf(in_t / NET_SHIVER, 0.0, 1.0)
	if hit_t >= 0.0:
		shiver = maxf(shiver, 1.0 - clampf(hit_t / NET_SHIVER, 0.0, 1.0))
	return {"give2": 0.7 * Ball.net_bulge(in_t), "y2": float(net.get("in_y", Geo.GOAL_Y)),
		"shiver": shiver, "ph": t}

static func _deck_tiles(ci: CanvasItem, v: PoolView, size: Vector2, pool: PoolDef) -> void:
	var col := Color(pool.deck_dark, 0.45)
	var x0 := v.to_screen(Vector2(floorf(v.cam.x), 0)).x
	var x := fposmod(x0, v.sx()) - v.sx()
	while x < size.x:
		ci.draw_rect(Rect2(roundf(x), 0, 1, size.y), col)
		x += v.sx()
	var y0 := v.to_screen(Vector2(0, floorf(v.cam.y))).y
	var y := fposmod(y0, v.sy()) - v.sy()
	while y < size.y:
		ci.draw_rect(Rect2(0, roundf(y), size.x, 1), col)
		y += v.sy()

## The grandstand along the far side (world y < 0); scrolls away as the camera drops.
## Empty seats show when the crowd is thin.
## `style` (CrowdArt.style: the Crowd Atmosphere level and whose fans they are); {} is the plain crowd.
static func _stands(ci: CanvasItem, v: PoolView, t: float, size: Vector2, excite: float, pool: PoolDef, crowd: float, style: Dictionary = {}) -> void:
	var bottom := v.to_screen(Vector2(0, -1.0)).y
	if bottom <= 0.0:
		return
	var rows := pool.rows
	var top := bottom - 2.0 - rows * 8.0
	ci.draw_rect(Rect2(0, 0, size.x, maxf(0.0, top)), pool.roof)
	ci.draw_rect(Rect2(0, maxf(0.0, top), size.x, bottom - maxf(0.0, top)), pool.stands)
	var seat := pool.stands.lightened(0.12)
	var scroll := v.cam.x * v.sx() * 0.6
	for row in rows:
		var y := top + row * 8.0
		if y < -8.0:
			continue
		var back := rows - 1 - row
		var first := int(floor(scroll / 7.0)) - 1
		var x := -fposmod(scroll, 7.0) - 7.0 + (row % 2) * 3.0
		var i := first
		while x < size.x:
			var seed := absi(i * 7 + row * 13 + (i * i) % 11)
			if float((seed * 37 + i * 11) % 100) / 100.0 >= crowd:
				ci.draw_rect(Rect2(x - 1, y + 4, 5, 3), seat)
				x += 7.0
				i += 1
				continue
			var col := Color(CROWD[seed % CROWD.size()]).darkened(0.1 + back * 0.1)
			var jump := 0.0
			if excite > 0.0:
				jump = -roundf(absf(sin(t * 13.0 + seed)) * 3.0 * excite)
			var skin := Color(PoloPlayer.SKIN[seed % 6]).darkened(0.2 + back * 0.08)
			if not style.is_empty():
				col = CrowdArt.fan_colour(style, col, seed, i, row, back, v)
				jump = minf(jump, CrowdArt.fan_jump(style, t, i, v))
				if jump < -1.0:
					ci.draw_rect(Rect2(x - 1, y - 2 + jump, 1, 3), skin)   # (arms up)
					ci.draw_rect(Rect2(x + 3, y - 2 + jump, 1, 3), skin)
			ci.draw_rect(Rect2(x, y + jump, 3, 3), skin)
			ci.draw_rect(Rect2(x - 1, y + 3 + jump, 5, 4), col)
			x += 7.0
			i += 1
	ci.draw_rect(Rect2(0, bottom, size.x, 1), pool.stands_rail)
	ci.draw_rect(Rect2(0, bottom + 1, size.x, 2), pool.stands_edge)
	if not style.is_empty():
		CrowdArt.draw_extras(ci, v, t, size, style, top, bottom, scroll)

static func _dash_line(ci: CanvasItem, v: PoolView, x: float, col: Color) -> void:
	var yy := 0.4
	var h := maxf(2.0, roundf(v.sy() * 0.4))   # 6 px in the normal view
	while yy < Geo.WIDTH - 0.4:
		var p := v.to_screen(Vector2(x, yy))
		ci.draw_rect(Rect2(p.x, p.y, 1, h), col)
		yy += 1.0

static func _rope(ci: CanvasItem, v: PoolView, y: float) -> void:
	var x := -1.5
	var k := 0
	while x <= Geo.LENGTH + 1.5:
		var d := minf(x, Geo.LENGTH - x)
		var col := UI.LANE_WHITE if k % 2 == 0 else UI.LANE_BLUE
		if d >= 0.0:
			if d < 2.0:
				col = UI.LANE_RED
			elif d < 5.0:
				col = UI.LANE_YELLOW
			elif d < 6.0:
				col = LANE_GREEN
		var p := v.to_screen(Vector2(x, y))
		ci.draw_rect(Rect2(p.x - 1, p.y - 1, 3, 2), col)
		x += 0.5
		k += 1

## A goal on the line x = gx, the net hanging out towards `dir`. `give` 0..1: the net is
## stretched back round `hit_y` (a ball just hit it, see Ball.net_bulge); the frame never moves.
## `fx` (net_fx): a second give round fx.y2 and a shiver, for a ball in off the frame.
static func draw_goal(ci: CanvasItem, v: PoolView, gx: float, dir: float, give: float = 0.0,
		hit_y: float = Geo.GOAL_Y, fx: Dictionary = {}) -> void:
	var up := 0.9 * v.sz()
	if v.mirror:
		dir = -dir
	var back := Geo.NET_DEPTH * v.sx() * dir
	var far := v.to_screen(Vector2(gx, Geo.GOAL_Y - Geo.GOAL_HALF))
	var near := v.to_screen(Vector2(gx, Geo.GOAL_Y + Geo.GOAL_HALF))
	if maxf(far.x, far.x + back) < -4.0 or minf(far.x, far.x + back) > v.width + 4.0:
		return
	# the net, one row every 3 px down the mouth: where its back is on that row
	var rows: Array[Vector2] = []   # (screen y, back offset in px)
	var ny := far.y
	while ny < near.y + 3.0:
		var y := minf(ny, near.y)
		var wy := lerpf(Geo.GOAL_Y - Geo.GOAL_HALF, Geo.GOAL_Y + Geo.GOAL_HALF, (y - far.y) / maxf(1.0, near.y - far.y))
		var k := give * clampf(1.0 - absf(wy - hit_y) / 1.0, 0.0, 1.0)
		var wob := 0.0
		if not fx.is_empty():
			k = maxf(k, float(fx.give2) * clampf(1.0 - absf(wy - float(fx.y2)) / 0.8, 0.0, 1.0))
			wob = roundf(SHIVER_PX * float(fx.shiver) * sin(rows.size() * 2.1 + float(fx.ph) * 70.0))
		rows.append(Vector2(y, roundf(back + dir * Ball.NET_GIVE * v.sx() * k) + dir * wob))
		ny += 3.0
	# the roof and the back of the net, a strip per row
	var net := Color(1, 1, 1, 0.16)
	for i in rows.size() - 1:
		var a := rows[i]
		var b := rows[i + 1]
		ci.draw_colored_polygon(PackedVector2Array([Vector2(far.x, a.x - up), Vector2(far.x, b.x - up),
			Vector2(far.x + b.y, b.x - up * 0.55), Vector2(far.x + a.y, a.x - up * 0.55)]), net)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(far.x + a.y, a.x - up * 0.55), Vector2(far.x + b.y, b.x - up * 0.55),
			Vector2(far.x + b.y, b.x), Vector2(far.x + a.y, a.x)]), net)
	# mesh
	var mesh := Color(1, 1, 1, 0.35)
	for r in rows:
		ci.draw_line(Vector2(far.x, r.x - up), Vector2(far.x + r.y, r.x - up * 0.55), mesh)
	for i in rows.size() - 1:
		var a := rows[i]
		var b := rows[i + 1]
		ci.draw_line(Vector2(far.x + a.y, a.x - up * 0.55), Vector2(far.x + b.y, b.x - up * 0.55), mesh)
		ci.draw_line(Vector2(far.x + a.y, a.x), Vector2(far.x + b.y, b.x), mesh)
	# frame: posts and crossbar
	ci.draw_rect(Rect2(far.x - 1, far.y - up, 2, up), FRAME)
	ci.draw_rect(Rect2(near.x - 1, near.y - up, 2, up + 1), FRAME)
	ci.draw_rect(Rect2(far.x - 1, far.y - up - 1, 2, near.y - far.y + 2), FRAME)
	ci.draw_rect(Rect2(near.x - 2, near.y + 1, 4, 1), Color(UI.WATER_SHINE, 0.7))

# ------------------------------------------------------------------ players
## `design`: a cap design (Caps) drawn over the cap; "" or "classic" for none.
static func draw_body(ci: CanvasItem, v: PoolView, s: Swimmer, cap: Color, trim: Color, design: String = "") -> void:
	var sea := v.to_screen(s.pos)   # the waterline: it stays put when he bounces up (s.hop)
	var o := sea - Vector2(0, roundf(s.hop))
	var skin := s.player.skin_color()
	var dark := skin.darkened(0.2)
	var f := 1 if (s.facing >= 0.0) != v.mirror else -1
	var px := func(dx: int, dy: int, w: int, h: int, c: Color) -> void:
		var rx := o.x + dx if f > 0 else o.x - dx - w
		ci.draw_rect(Rect2(rx, o.y + dy, w, h), c)
	if s.keeper and s.pose != null and not s.pose.done():
		_keeper_dive(ci, v, s, o, px, cap, trim, design, skin, dark)
		return
	var rip := Color(UI.WATER_SHINE, 0.65)
	var wob := int(fposmod(s.anim * 1.4, 2.0))
	ci.draw_rect(Rect2(sea.x - 8 - wob, sea.y + 2, 16 + wob * 2, 1), rip)
	ci.draw_rect(Rect2(sea.x - 7, sea.y - 1, 14, 4), Color(WATER_DARK, 0.75))
	var swimming := s.speed() > 0.8 and s.arm < 0.3 and not s.keeper and s.cheer < 0.5
	var lean := 1 if swimming else 0
	# man-down (ManDownZone): a zone man shifting, too slow to be swimming, leans into it (his
	# shoulders and head a pixel the way he's going along the pool) and leaves a wake behind him,
	# so the zone sliding with the ball reads at a glance (the art only: he moves no faster)
	if s.zlane >= 0 and not swimming and not s.keeper and s.speed() > 0.3:
		var sv := Vector2(s.vel.x * (-1.0 if v.mirror else 1.0), s.vel.y * 0.5)
		if absf(s.vel.x) > 0.2:
			lean = 1 if (sv.x > 0.0) == (f > 0) else -1
		var back := -sv.normalized()
		var k := fposmod(s.anim * 3.0, 2.0)
		var w1 := (sea + back * (9.0 + k)).round()
		var w2 := (sea + back * (13.0 + k)).round()
		ci.draw_rect(Rect2(w1.x - 2, w1.y + 1, 4, 1), Color(1, 1, 1, 0.75))
		ci.draw_rect(Rect2(w2.x - 1, w2.y + 1, 3, 1), Color(1, 1, 1, 0.4))
	# shoulders breaking the surface
	px.call(-6 + lean, -4, 12, 3, dark)
	px.call(-5 + lean, -5, 10, 1, dark)
	# his hands (the Position Identity update): the right hand drawn on the side he faces, the
	# left behind his head (`back`: arm_px mirrors the pair). A lefty holds, passes and shoots with
	# his left; a block's arm is the hand its collision is on (block_hand, dive_hand).
	var ball_px := arm_px(px, s.player != null and s.player.is_lefty())
	if s.keeper:
		if s.cheer_style == "" or not Celebrations.draw_pose(px, s, skin):
			_keeper_arms(px, s, skin)
	elif s.cheer > 0.5 and s.cheer_style != "" and Celebrations.draw_pose(px, s, skin):
		pass   # (a celebration's pose)
	elif s.cheer > 0.5:
		# a goal: a fist punched up out of the water, the other hand sculling
		px.call(4, -17, 2, 13, skin)
		px.call(3, -19, 4, 3, skin)
		px.call(-9, -4, 3, 1, skin)
	elif absf(s.dive) >= 0.2:
		_block_arms(arm_px(px, dive_hand(s) < 0.0), s, skin)
	elif s.block_arm > 0.05 or s.zreach > 0.05:
		# a piston's block, or a man-down zone man's hand up in the lane (never fully up: no block)
		_raised_arm(arm_px(px, block_hand(s) < 0.0), maxf(s.block_arm, s.zreach), skin)
	elif s.snap > 0.0:
		# the throw's follow-through: the arm whips forward (a lefty's from behind his head)
		if s.player != null and s.player.is_lefty():
			px.call(-6, -11, 2, 4, skin)
			px.call(-5, -13, 11, 2, skin)
			px.call(7, -4, 3, 1, skin)
		else:
			px.call(4, -9, 2, 5, skin)
			px.call(5, -11, 6, 2, skin)
			px.call(-9, -4, 3, 1, skin)
	elif s.arm > 0.4:
		# ball raised over the head in his shooting hand, the other hand sculling
		ball_px.call(4, -16, 2, 12, skin)
		ball_px.call(-9, -4, 3, 1, skin)
	elif s.grip > 0.3 and not swimming:
		# the 2 m battle: locked up, the arms working against each other, the water churned
		var tug := int(fposmod(s.anim * 1.6, 2.0))
		if s.hook:
			px.call(-10, -7 + tug, 4, 2, skin)   # the centre: an arm hooked back round his man, sealing him
			px.call(6, -4, 3, 1, skin)
		else:
			px.call(5, -7 + tug, 5, 2, skin)     # a hand on his man
			px.call(-9, -4 - tug, 3, 1, skin)
		px.call(-11 + tug, 0, 2, 1, Color.WHITE)
		px.call(9 - tug, -1, 2, 1, rip)
	elif swimming:
		var ph := sin(s.anim * 2.4)
		px.call(6, -6 if ph > 0.0 else -3, 4, 2, skin)
		px.call(-9, -4 if ph > 0.0 else -7, 3, 2, skin)
		var k := int(fposmod(s.anim * 3.0, 3.0))
		px.call(-11 - k, -2 + (k % 2), 2, 1, Color.WHITE)
		px.call(-13 - k, 0, 3, 1, Color(1, 1, 1, 0.7))
	else:
		# eggbeater: ripples each side
		var e := int(fposmod(s.anim * 2.0, 2.0))
		px.call(-10, 0 - e, 2, 1, rip)
		px.call(8, -1 + e, 2, 1, rip)
	# head, cap with ear guard, face on the side we're facing
	px.call(-3 + lean, -11, 7, 7, skin)
	px.call(-4 + lean, -12, 8, 4, cap)
	px.call(-3 + lean, -13, 6, 1, cap)
	px.call(-4 + lean, -8, 3, 3, cap)
	px.call(-2 + lean, -13, 3, 1, cap.lightened(0.35))
	px.call(-3 + lean, -12, 1, 1, cap.lightened(0.2))
	_cap_design(px, lean, cap, trim, design)
	_ear_guard(px, lean, cap, trim)
	if design == "checker":
		for yy in 3:
			for xx in 4:
				if (xx + yy) % 2 == 0:
					px.call(-3 + lean + xx, -9 + yy, 1, 1, trim)
	px.call(2 + lean, -9, 1, 1, EYE)
	px.call(3 + lean, -7, 1, 1, dark)
	if s.out:
		UI.text(ci, Vector2(o.x - 6, o.y - 16), "EX", 8, UI.BAD, "body")

## Stripes, bands and shine on top of the cap (see Caps).
static func _cap_design(px: Callable, lean: int, cap: Color, trim: Color, design: String) -> void:
	match design:
		"stripe":
			px.call(-3 + lean, -12, 7, 1, trim)
		"twin":
			px.call(-3 + lean, -13, 6, 1, trim)
			px.call(-4 + lean, -11, 8, 1, trim)
		"band":
			px.call(0 + lean, -13, 2, 5, trim)
		"chrome":
			px.call(-2 + lean, -13, 4, 1, Color.WHITE)
			px.call(1 + lean, -12, 2, 1, Color(1, 1, 1, 0.8))
		"champs":
			px.call(-3 + lean, -12, 7, 1, Color.WHITE)
			px.call(-2 + lean, -13, 2, 1, Color("fff6c4"))

## The ear guard, exaggerated: a big round cup overhanging the back of the head, with a dark
## rim, a bright top edge, a vent hole and the team trim along the bottom.
static func _ear_guard(px: Callable, lean: int, cap: Color, trim: Color) -> void:
	var rim := cap.darkened(0.5)
	px.call(-3 + lean, -10, 4, 1, rim)
	px.call(-4 + lean, -9, 6, 4, rim)
	px.call(-3 + lean, -5, 4, 1, rim)
	px.call(-3 + lean, -9, 4, 4, cap.lightened(0.18))   # a shade up from the cap so dark caps still separate
	px.call(-3 + lean, -9, 2, 1, cap.lightened(0.6))
	px.call(-2 + lean, -8, 2, 2, cap.darkened(0.55))
	px.call(-3 + lean, -6, 4, 1, trim)

static func _keeper_arms(px: Callable, s: Swimmer, skin: Color) -> void:
	var d := s.dive
	if s.slump > 0.5 and absf(d) < 0.2:
		# beaten: arms down by his sides, hands on the water
		px.call(-9, -6, 2, 3, skin)
		px.call(7, -6, 2, 3, skin)
		return
	if absf(d) < 0.2:
		# set: both hands up
		px.call(-9, -15, 2, 11, skin)
		px.call(7, -15, 2, 11, skin)
		return
	# lunge: arm stretched towards the dive (up or down the screen), splash under it
	var reach := int(6 + absf(d) * 9)
	if d > 0.0:
		px.call(6, -4, 2, reach, skin)
		px.call(4, -4 + reach, 6, 1, Color.WHITE)
	else:
		px.call(6, -4 - reach, 2, reach, skin)
	px.call(-9, -10, 2, 6, skin)

# ------------------------------------------------------------------ the keeper's dive
## A keeper mid-dive or mid-block (s.pose, KeeperDive). The body is at s.pos (KeeperDive.body_y);
## the leading hand is drawn exactly at the edge of his reach, at the height shots cross the
## line, so where you see his hand is where he saves. LEFT/RIGHT: a flat lunge up or down the
## screen, head and shoulders leading, one arm stretched out, the other tucked, legs trailing,
## a splash where he pushed off. CENTRE: he springs up out of the water, both arms high.
## The phases read at a glance (KeeperDive.phase): his hands catch a white glint only while he's
## up and can block (ACTIVE); falling he slaps back into the water with a splash and sinks; then
## he bobs back up out of a widening ring (RECOVER), arms down, before he can go again.
const DIVE_SPLASH := 0.3      # the push-off splash lasts this long
const IMPACT_TIME := 0.18     # the flash where the ball meets his hand
const GLINT := Color(1, 1, 1, 0.85)

static func _keeper_dive(ci: CanvasItem, v: PoolView, s: Swimmer, o: Vector2, px: Callable,
		cap: Color, trim: Color, design: String, skin: Color, dark: Color) -> void:
	var pose := s.pose
	var e := pose.ext()
	var sd := pose.side
	var white := Color.WHITE
	var start := v.to_screen(Vector2(s.pos.x, pose.base_y))
	var hand_up := roundi(KeeperDive.BALL_Z * v.sz())
	var reach_px := roundi(pose.reach() * v.sy())
	var ph := pose.phase()
	if ph == KeeperDive.Phase.RECOVER or ph == KeeperDive.Phase.READY:
		# back in the water: head and shoulders bobbing up out of a widening ring, arms down
		var u := clampf((pose.t - pose.down_at()) / KeeperDive.RECOVERY, 0.0, 1.0)
		var sink := roundi(4.0 * (1.0 - u))
		var ring := 7 + roundi(5.0 * u)
		ci.draw_rect(Rect2(o.x - ring, o.y + 2, ring * 2, 1), Color(UI.WATER_SHINE, 0.8 * (1.0 - u)))
		ci.draw_rect(Rect2(o.x - 7, o.y - 1, 14, 4), Color(WATER_DARK, 0.75))
		px.call(-6, -4 + sink, 12, 3, dark)
		_keeper_head(px, sink, cap, trim, design, skin, dark)
		if s.arm > 0.5:
			# a ball he caught (Play.held_at, KeeperDive.held): his hand under it, on the water in
			# front of him, then coming up with it as he does (the rest of him as ever)
			var k := pose.hold_rise()
			var hx := roundi(lerpf(KeeperDive.TUCK.x, 0.2, k) * v.sx())
			var hy := -roundi(lerpf(KeeperDive.TUCK.z, 0.9, k) * v.sz()) + 2
			px.call(hx - 1, hy, 3, 2, skin)
			if -4 + sink > hy + 2:
				px.call(hx, hy + 2, 2, -4 + sink - hy - 2, skin)
		return
	if ph == KeeperDive.Phase.FALL:
		# slapping back down: spray off both sides of him
		var u := clampf((pose.t - pose.fall_at()) / KeeperDive.FALL, 0.0, 1.0)
		var sp := 3.0 + 8.0 * u
		for d: Vector2 in [Vector2(-1.0, -0.5), Vector2(1.0, -0.7), Vector2(-0.7, 0.3), Vector2(0.8, 0.4)]:
			var q := o + Vector2(d.x * sp, d.y * sp * 0.6 - 2.0 * sin(u * PI))
			ci.draw_rect(Rect2(roundf(q.x), roundf(q.y), 1, 1), Color(1, 1, 1, 0.85 * (1.0 - u)))
	# push-off splash and the water he leaves behind
	if pose.t < DIVE_SPLASH:
		var u := pose.t / DIVE_SPLASH
		var a := 1.0 - u
		var spread := 2.0 + 7.0 * u
		var drops := [Vector2(-1.0, -0.6), Vector2(1.0, -0.8), Vector2(-0.6, 0.4), Vector2(0.7, 0.5), Vector2(0.0, -1.0)]
		for d: Vector2 in drops:
			var away := Vector2(d.x * spread, (d.y - 0.6 * sd) * spread * 0.6) if sd != 0 else Vector2(d.x * spread * 1.3, d.y * spread * 0.5)
			var q := start + away + Vector2(0, -3.0 * sin(u * PI))
			ci.draw_rect(Rect2(roundf(q.x), roundf(q.y), 2 if absf(d.x) > 0.8 else 1, 1), Color(1, 1, 1, 0.9 * a))
		if sd != 0 and absf(o.y - start.y) > 2.0:
			ci.draw_rect(Rect2(o.x - 1, minf(o.y, start.y), 2, absf(o.y - start.y)), Color(1, 1, 1, 0.35 * a))
	if ph == KeeperDive.Phase.PANIC:
		_keeper_panic(ci, v, s, o, px, cap, trim, design, skin, dark, hand_up)
	elif sd == KeeperDive.CENTRE:
		# the block: up out of the water, both arms high, a ring of splash round him
		var lift := roundi(6.0 * e) - (roundi(3.0 * (1.0 - e)) if ph == KeeperDive.Phase.FALL else 0)
		var arm_len := 10 + roundi(6.0 * e)
		var ring := 8 + roundi(3.0 * e)
		ci.draw_rect(Rect2(o.x - ring, o.y + 1, ring * 2, 2), Color(UI.WATER_SHINE, 0.8))
		ci.draw_rect(Rect2(o.x - 7, o.y - 1, 14, 3), Color(WATER_DARK, 0.75))
		if pose.t < DIVE_SPLASH:
			var a2 := 1.0 - pose.t / DIVE_SPLASH
			for k in [-1, 1]:
				ci.draw_rect(Rect2(o.x + k * (ring + 1) - (1 if k < 0 else 0), o.y - 1 - roundi(3.0 * a2), 2, 2), Color(1, 1, 1, 0.9 * a2))
		px.call(-5, -4 - lift, 10, 4 + lift, dark)                 # chest out of the water
		px.call(-6, -5 - lift, 12, 2, dark)                        # shoulders
		px.call(-7, -5 - lift - arm_len, 2, arm_len, skin)         # both arms straight up...
		px.call(5, -5 - lift - arm_len, 2, arm_len, skin)
		px.call(-8, -7 - lift - arm_len, 4, 2, skin)               # ...hands open
		px.call(4, -7 - lift - arm_len, 4, 2, skin)
		if ph == KeeperDive.Phase.ACTIVE:
			px.call(-8, -8 - lift - arm_len, 4, 1, GLINT)
			px.call(4, -8 - lift - arm_len, 4, 1, GLINT)
		_keeper_head(px, -lift, cap, trim, design, skin, dark)
	else:
		# the lunge: everything leans the way he's going
		var lean := roundi(5.0 * e) * sd                           # head and shoulders lead
		var low := roundi(3.0 * e)                                 # flat out, lower in the water
		if ph == KeeperDive.Phase.FALL:
			low = 3 + roundi(2.0 * (1.0 - e))                      # ...and going under as he falls
		var stretch := roundi(4.0 * e)
		var top := mini(0, sd * stretch)
		ci.draw_rect(Rect2(o.x - 8, o.y - 1 + top, 16, 3 + stretch), Color(WATER_DARK, 0.75))
		ci.draw_rect(Rect2(o.x - 9, o.y + 2 + maxi(0, sd * stretch), 18, 1), Color(UI.WATER_SHINE, 0.65))
		# legs trailing behind, kicking
		var kick := int(fposmod(pose.t * 30.0, 2.0))
		px.call(-4, 1 - sd * (5 + roundi(3.0 * e)), 3, 1, Color(WATER_DARK, 0.9))
		px.call(-6 - kick, 1 - sd * (7 + roundi(3.0 * e)), 2, 1, Color(1, 1, 1, 0.7))
		# shoulders stretched along the dive
		px.call(-5, -5 + mini(0, sd * stretch) + low, 10, 3 + stretch, dark)
		# the trailing arm, tucked in
		px.call(-8, -4 - sd * 3 + low, 2, 3, skin)
		# the leading arm: shoulder to hand, the hand right at the edge of his reach (across the
		# goal; reaching out in front of him too, so a dive down the screen still shows its arm)
		var sh := Vector2(2, -5 + lean + low)
		var hand := Vector2(3 + roundi((2.0 if sd < 0 else 7.0) * e), sd * reach_px - hand_up)
		if sd > 0:
			_keeper_head(px, lean + low, cap, trim, design, skin, dark)   # (the arm goes over it)
		var steps := maxi(1, roundi(sh.distance_to(hand)))
		for i in steps + 1:
			var q := sh.lerp(hand, i / float(steps)).round()
			px.call(int(q.x), int(q.y), 2, 2, skin)
		px.call(int(hand.x) - 1, int(hand.y) - 1, 4, 3, skin)
		if ph == KeeperDive.Phase.ACTIVE:
			px.call(int(hand.x) - 1, int(hand.y) - 2, 4, 1, GLINT)
		if sd < 0:
			_keeper_head(px, lean + low, cap, trim, design, skin, dark)
	# the ball meeting his hand
	if pose.hit_t >= 0.0 and pose.hit_t < IMPACT_TIME:
		var h := v.to_screen(Vector2(s.pos.x, pose.hit_y), KeeperDive.BALL_Z)
		var a3 := 1.0 - pose.hit_t / IMPACT_TIME
		var r := 2 + roundi(3.0 * (1.0 - a3))
		var c := Color(1, 1, 1, a3)
		ci.draw_rect(Rect2(h.x - r, h.y, 2, 1), c)
		ci.draw_rect(Rect2(h.x + r - 1, h.y, 2, 1), c)
		ci.draw_rect(Rect2(h.x, h.y - r, 1, 2), c)
		ci.draw_rect(Rect2(h.x, h.y + r - 1, 1, 2), c)
		ci.draw_rect(Rect2(h.x - 1, h.y - 1, 2, 2), Color(1, 1, 1, a3 * 0.8))

## The panic (KeeperDive.turn): he went the wrong way and he's clawing back. Off balance, low in
## the water on the side he went, torso twisted back, head turned to the ball, the arm he went with
## still trailing out the wrong way and coming in, the other one flung back across his body, its
## hand right at the edge of the reach he's clawed back (what you see is what can save it), legs
## thrashing, spray thrown off the way his momentum was taking him.
static func _keeper_panic(ci: CanvasItem, v: PoolView, s: Swimmer, o: Vector2, px: Callable,
		cap: Color, trim: Color, design: String, skin: Color, dark: Color, hand_up: int) -> void:
	var pose := s.pose
	var sd := pose.side if pose.side != KeeperDive.CENTRE else -int(pose.turn_dir())
	var back := int(pose.turn_dir())
	var tau := pose.t - pose.turn_t
	var twist := clampf(tau / KeeperDive.PANIC_SWING, 0.0, 1.0)
	var low := 2 + roundi(2.0 * pose.turn_c)
	var shake := int(fposmod(pose.t * 40.0, 2.0))
	ci.draw_rect(Rect2(o.x - 8, o.y - 1 + mini(0, sd * 3), 16, 5), Color(WATER_DARK, 0.75))
	ci.draw_rect(Rect2(o.x - 9, o.y + 3 + maxi(0, sd * 2), 18, 1), Color(UI.WATER_SHINE, 0.65))
	# momentum: spray still flying off the way he went
	for i in 3:
		var q := o + Vector2(-3 + i * 3, sd * (6 + i * 2 + roundi(6.0 * twist)) - 2)
		ci.draw_rect(Rect2(roundf(q.x), roundf(q.y), 1, 1), Color(1, 1, 1, 0.8 - 0.2 * i))
	# legs thrashing under him
	px.call(-5 - shake, 2 - sd * 4, 3, 1, Color(1, 1, 1, 0.7))
	px.call(-3 + shake, 1 - sd * 6, 2, 1, Color(WATER_DARK, 0.9))
	# torso twisted: hips still carried the way he went, shoulders wrenched back round
	var tw := roundi(2.0 * twist) * back
	px.call(-4, -3 + low + sd * 2, 8, 2, dark)                  # hips, still going
	px.call(-5, -5 + low + sd + tw, 10, 3, dark)                # shoulders, coming round
	# the arm he went with: still out the wrong way, coming in
	var lead_px := roundi(pose.lead_reach() * v.sy())
	if lead_px > 1:
		var sh0 := Vector2(-3, -5 + low + sd * 2)
		var h0 := Vector2(-6, sd * lead_px - hand_up + low)
		var n0 := maxi(1, roundi(sh0.distance_to(h0)))
		for i in n0 + 1:
			var q := sh0.lerp(h0, i / float(n0)).round()
			px.call(int(q.x), int(q.y), 2, 2, skin)
	# head turned back to the ball, a beat behind the body (off balance: thrown the way he went)
	_keeper_head(px, low + sd * 2 + roundi(twist) * back, cap, trim, design, skin, dark)
	# the arm flung back for the ball, over everything: its hand at the edge of what he's clawed
	# back (what you see is what can save it), two flecks of water off it
	var sh := Vector2(3, -4 + low + tw)
	var hand := Vector2(10, back * roundi(pose.reach() * v.sy()) - hand_up + low)   # (out in front of him, over the water)
	var steps := maxi(1, roundi(sh.distance_to(hand)))
	for i in steps + 1:
		var q := sh.lerp(hand, i / float(steps)).round()
		px.call(int(q.x), int(q.y), 2, 2, skin)
	px.call(int(hand.x) - 1, int(hand.y) - 1, 3, 3, skin)   # (open hand, no glint: a desperate one)
	px.call(int(hand.x) + 3, int(hand.y) - back * 2, 1, 1, Color(1, 1, 1, 0.9))
	px.call(int(hand.x) + 2, int(hand.y) - back * 4, 1, 1, Color(1, 1, 1, 0.6))

## The keeper's head and cap, `dy` px up or down the screen from where it normally sits.
static func _keeper_head(px: Callable, dy: int, cap: Color, trim: Color, design: String, skin: Color, dark: Color) -> void:
	var at := func(dx: int, y: int, w: int, h: int, c: Color) -> void:
		px.call(dx, y + dy, w, h, c)
	at.call(-3, -11, 7, 7, skin)
	at.call(-4, -12, 8, 4, cap)
	at.call(-3, -13, 6, 1, cap)
	at.call(-4, -8, 3, 3, cap)
	at.call(-2, -13, 3, 1, cap.lightened(0.35))
	_cap_design(at, 0, cap, trim, design)
	_ear_guard(at, 0, cap, trim)
	at.call(2, -9, 1, 1, EYE)
	at.call(3, -7, 1, 1, dark)

## A field player going for a block: the arm on the ball's side shoots up, hand open, reaching
## further (and leaning) the further off him the ball passes. One arm, always: the other hand
## stays down, sculling (only a keeper gets both up).
## `px` with its arms the other way round (`back`: the left hand, drawn behind his head; the
## other hand then in front): x mirrored about his middle.
static func arm_px(px: Callable, back: bool) -> Callable:
	if not back:
		return px
	return func(dx: int, dy: int, w: int, h: int, c: Color) -> void: px.call(-dx - w, dy, w, h, c)

## Which hand a piston's raised arm is: his left (-1) or right (+1). The arm goes up on the side
## the shot's line passes him (DefenseFormation.arm_side), the hand out across that line
## (arm_zone: block_side along the line's normal), and the art shows that very hand: the one on
## that side of the pool, across, as he faces (his right is +y facing +x).
## A man-down zone man's hand up in the lane (ManDownZone: zreach) is chosen the same way.
static func block_hand(s: Swimmer) -> float:
	var on := s.press_on
	var side := s.block_side
	if on == null and s.zreach > 0.0 and s.zreach_on != null:
		on = s.zreach_on
		side = s.zside
	if on != null:
		var y := (on.pos - s.pos).orthogonal().y * side
		if absf(y) > 0.01 and s.facing != 0.0:
			return 1.0 if signf(y) == signf(s.facing) else -1.0
	return -1.0 if side > 0.0 else 1.0

## Which hand a defender reaching for a shot uses (Play._reach_for_shot: `dive` the side of the
## pool, across, the ball passes him): his right (+1) is the +y side facing +x, the -y side facing
## -x.
static func dive_hand(s: Swimmer) -> float:
	return 1.0 if signf(s.dive) == signf(s.facing) or s.facing == 0.0 else -1.0

static func _block_arms(px: Callable, s: Swimmer, skin: Color) -> void:
	var d := s.dive
	var a := absf(d)
	var tall := int(9 + a * (7.0 if d < 0.0 else 3.0))
	var lean := int(a * (2.0 if d < 0.0 else 4.0))
	px.call(4, -6, 2 + lean, 2, skin)                 # shoulder out to the arm
	px.call(4 + lean, -4 - tall, 2, tall, skin)       # the arm, straight up
	px.call(3 + lean, -6 - tall, 4, 2, skin)          # open hand
	px.call(-9, -4, 3, 1, skin)                       # the other hand, down on the water

## A piston's block (DefenseFormation's pressure): one arm going up as he swims out, `k` of the
## way (0 down .. 1 fully up: the block's on); the other hand down, sculling.
static func _raised_arm(px: Callable, k: float, skin: Color) -> void:
	var tall := int(roundf(lerpf(2.0, 11.0, clampf(k, 0.0, 1.0))))
	px.call(4, -6, 2, 2, skin)                        # shoulder
	px.call(4, -4 - tall, 2, tall, skin)              # the arm
	if k >= 0.99:
		px.call(3, -6 - tall, 4, 2, skin)             # up: the hand open
	px.call(-9, -4, 3, 1, skin)

## The marker over the player you're throwing from: a chunky gold arrow on a dark rim.
static func draw_holder_marker(ci: CanvasItem, v: PoolView, s: Swimmer, t: float) -> void:
	var o := v.to_screen(s.pos)
	var bob := roundf(sin(t * 6.0))
	var y := o.y - 29 + bob
	# rim first, then the arrow on top, so it stays readable on any water
	ci.draw_rect(Rect2(o.x - 5, y - 1, 11, 3), INK)
	ci.draw_rect(Rect2(o.x - 4, y + 2, 9, 1), INK)
	ci.draw_rect(Rect2(o.x - 3, y + 3, 7, 1), INK)
	ci.draw_rect(Rect2(o.x - 2, y + 4, 5, 1), INK)
	ci.draw_rect(Rect2(o.x - 1, y + 5, 3, 1), INK)
	ci.draw_rect(Rect2(o.x - 4, y, 9, 2), UI.GOLD)
	ci.draw_rect(Rect2(o.x - 3, y + 2, 7, 1), UI.GOLD)
	ci.draw_rect(Rect2(o.x - 2, y + 3, 5, 1), UI.GOLD)
	ci.draw_rect(Rect2(o.x - 1, y + 4, 3, 1), UI.GOLD)
	ci.draw_rect(Rect2(o.x - 4, y, 9, 1), UI.GOLD.lightened(0.4))

## A ring at the waterline: open teammate, or the one your pass is going to.
static func draw_ring(ci: CanvasItem, v: PoolView, s: Swimmer, col: Color) -> void:
	draw_ellipse_ring(ci, v.to_screen(s.pos) + Vector2(0, 3), 12, 4, col, 2)

# ------------------------------------------------------------------ guide pieces
const INK := Color("08203f", 0.9)   # the dark rim that keeps guide marks readable on the water

## One chunky guide dot centred on `c`: a (2h+1) square core inside a dark rim with cut corners.
static func draw_dot(ci: CanvasItem, c: Vector2, col: Color, h: int = 1) -> void:
	var side := 2 * h + 1
	ci.draw_rect(Rect2(c.x - h, c.y - h - 1, side, side + 2), INK)
	ci.draw_rect(Rect2(c.x - h - 1, c.y - h, side + 2, side), INK)
	ci.draw_rect(Rect2(c.x - h, c.y - h, side, side), col)
	ci.draw_rect(Rect2(c.x - h, c.y - h, side, 1), col.lightened(0.45))

## A flat ellipse ring `thick` px wide with a 1 px dark drop shadow. Drawn as non-overlapping
## spans per row, so translucent colours never double up.
static func draw_ellipse_ring(ci: CanvasItem, c: Vector2, rx: int, ry: int, col: Color, thick: int = 2) -> void:
	_ring_spans(ci, c + Vector2(0, 1), rx, ry, INK, thick)
	_ring_spans(ci, c, rx, ry, col, thick)

static func _half_width(r: int, dy: int, ry: int) -> int:
	var k := dy / (ry + 0.5)
	return roundi(r * sqrt(maxf(0.0, 1.0 - k * k)))

static func _ring_spans(ci: CanvasItem, c: Vector2, rx: int, ry: int, col: Color, thick: int) -> void:
	var irx := rx - thick
	var iry := ry - 1
	for dy in range(-ry, ry + 1):
		var xo := _half_width(rx, dy, ry)
		if absi(dy) > iry or irx <= 0:
			ci.draw_rect(Rect2(c.x - xo, c.y + dy, xo * 2 + 1, 1), col)
			continue
		var xi := _half_width(irx, dy, iry)
		ci.draw_rect(Rect2(c.x - xo, c.y + dy, xo - xi, 1), col)
		ci.draw_rect(Rect2(c.x + xi + 1, c.y + dy, xo - xi, 1), col)

# ------------------------------------------------------------------ ball
# ------------------------------------------------------------------ catch and shoot
const GLOW := Color("ffd83d")      # the catch-and-shoot gold
const FLASH_TIME := 0.12           # a catch-and-shoot release: the white flash round the ball...
const TRAIL_TIME := 0.3            # ...and the streak behind it, this long into the flight
const RING_TIME := 0.25            # ...and the white ring bursting off the shooter
const RING_FLASH := 0.05           # ...with a pop of white on his chest as it starts
const RING_BLUE := Color("a8dcff") # the ring's inner edge turns this as it grows
## The ring's beats: [seconds, diameter px, opacity]. Eased out between them.
const RING_KEYS := [[0.0, 12.0, 1.0], [0.08, 25.0, 0.9], [0.18, 32.0, 0.45], [0.25, 32.0, 0.0]]

## Under the catcher: a soft gold ring, as strong as his catch-and-shoot bonus (`k` 0..1).
static func draw_catch_ring(ci: CanvasItem, v: PoolView, s: Swimmer, k: float) -> void:
	if k <= 0.0:
		return
	_ring_spans(ci, v.to_screen(s.pos) + Vector2(0, 3), 11, 4, Color(GLOW, 0.75 * k), 1)

## Over the ball in his hand: a few gold pixels round it, fading with the bonus.
static func draw_catch_glow(ci: CanvasItem, v: PoolView, b: Ball, k: float) -> void:
	if k <= 0.0:
		return
	var p := v.to_screen(b.pos, b.z) + Vector2(1, 0)
	var col := Color(GLOW, 0.55 * k)
	ci.draw_rect(Rect2(p.x - 2, p.y - 4, 4, 1), col)
	ci.draw_rect(Rect2(p.x - 2, p.y + 3, 4, 1), col)
	ci.draw_rect(Rect2(p.x - 4, p.y - 2, 1, 4), col)
	ci.draw_rect(Rect2(p.x + 3, p.y - 2, 1, 4), col)
	ci.draw_rect(Rect2(p.x - 3, p.y - 3, 1, 1), col)
	ci.draw_rect(Rect2(p.x + 2, p.y - 3, 1, 1), col)
	ci.draw_rect(Rect2(p.x - 3, p.y + 2, 1, 1), col)
	ci.draw_rect(Rect2(p.x + 2, p.y + 2, 1, 1), col)

## THE SHOOTER'S POWER, SEEN (presentation only: the shot flies exactly as ShotModel says): a
## streak behind every shot as long, thick and bright as the shooter's own shot pace
## (Attributes.shot_pace: his Shooting), so a weak shooter's shot leaves a faint wisp and a great
## one's a long gold streak with speed lines. Its strength (shooter_power) runs 0, the weakest pace, to 1, the hardest.
const POWER_PACE := Vector2(45.0, 82.5)   # the pace that reads as no power .. full power
const POWER_GOLD := 0.65                  # from here the streak turns gold, speed lines show

static func shooter_power(pace: float) -> float:
	return clampf((pace - POWER_PACE.x) / (POWER_PACE.y - POWER_PACE.x), 0.0, 1.0)

## A shot in play (Ball, SHOT, its shooter known): his streak.
static func draw_shot_power(ci: CanvasItem, v: PoolView, b: Ball) -> void:
	if b.state != Ball.State.SHOT or b.shooter == null or b.shooter.player == null:
		return
	var at := b.look()
	draw_power_trail(ci, v, at, b.to - b.from, shooter_power(Attributes.shot_pace(b.shooter.player)))

## The streak behind a ball at `at` (x, y, height) flying along `dir`, for `power` 0..1.
static func draw_power_trail(ci: CanvasItem, v: PoolView, at: Vector3, dir: Vector2, power: float) -> void:
	if dir.length() < 0.001:
		return
	var d := dir.normalized()
	var n := 1 + roundi(power * 6.0)                 # 1 puff .. 7
	var step := 0.22 + 0.12 * power                    # metres between puffs: a longer streak
	var thick := 1.0 if power < 0.35 else (2.0 if power < POWER_GOLD else 3.0)
	var col := Color.WHITE.lerp(UI.GOLD, clampf((power - (POWER_GOLD - 0.05)) / 0.25, 0.0, 1.0))
	var base := 0.2 + 0.75 * power
	# one unbroken streak: each puff reaches back to the next, fading and thinning towards the tail
	var prev := v.to_screen(Vector2(at.x, at.y), at.z)
	for i in range(1, n + 1):
		var q := v.to_screen(Vector2(at.x, at.y) - d * (step * i), at.z)
		var a := base * (1.0 - float(i - 1) / n)
		var h := maxf(1.0, thick - floorf(float(i - 1) * thick / n))
		var x0 := roundf(minf(prev.x, q.x))
		var x1 := roundf(maxf(prev.x, q.x))
		var y := roundf((prev.y + q.y) * 0.5 - h * 0.5)
		ci.draw_rect(Rect2(x0, y, maxf(1.0, x1 - x0), h), Color(col, a))
		prev = q
	if power >= POWER_GOLD:
		# speed lines over and under the streak
		var p := v.to_screen(Vector2(at.x, at.y), at.z)
		var tail := v.to_screen(Vector2(at.x, at.y) - d * (step * n), at.z)
		var span := p.distance_to(tail)
		var sd := (tail - p).normalized()
		for off: float in [-4.0, 4.0]:
			var o: Vector2 = Vector2(-sd.y, sd.x) * off
			var s0: Vector2 = p + sd * 4.0 + o
			for k in int(span * 0.6):
				var q: Vector2 = s0 + sd * k
				ci.draw_rect(Rect2(roundf(q.x), roundf(q.y), 1, 1), Color(col, 0.55 * (1.0 - k / maxf(1.0, span * 0.6))))

## A catch-and-shoot on its way (the shot's `catch_shoot` > 0): a white flash round the ball as
## it leaves the hand, then a short fading streak behind it. Worked out from the flight alone,
## so nothing is left behind once the shot is over.
static func draw_shot_fx(ci: CanvasItem, v: PoolView, b: Ball) -> void:
	if b.state != Ball.State.SHOT or float(b.shot.get("catch_shoot", 0.0)) <= 0.0:
		return
	var flown := b.t * b.dur
	if flown > TRAIL_TIME:
		return
	var at := b.look()
	var p := v.to_screen(Vector2(at.x, at.y), at.z)
	var dir := (b.to - b.from).normalized()
	var fade := 1.0 - flown / TRAIL_TIME
	for i in range(1, 4):
		var back := Vector2(at.x, at.y) - dir * (0.35 * i)
		var q := v.to_screen(back, at.z)
		var a := fade * (0.55 - 0.15 * i)
		ci.draw_rect(Rect2(q.x - 1, q.y - 1, 3, 2), Color(1, 1, 1, a))
	if flown < FLASH_TIME:
		var fa := 1.0 - flown / FLASH_TIME
		var w := Color(1, 1, 1, 0.8 * fa)
		ci.draw_rect(Rect2(p.x - 3, p.y - 5, 8, 1), w)
		ci.draw_rect(Rect2(p.x - 3, p.y + 4, 8, 1), w)
		ci.draw_rect(Rect2(p.x - 5, p.y - 3, 1, 6), w)
		ci.draw_rect(Rect2(p.x + 6, p.y - 3, 1, 6), w)

## A catch-and-shoot release (Play.release_t, `t` s ago): a pop of white on the shooter's chest,
## then a ring bursting off it (RING_KEYS), white turning light blue on the inside, 2 px once
## it's out. Gone after RING_TIME. Never on a plain catch.
static func draw_release_ring(ci: CanvasItem, v: PoolView, s: Swimmer, t: float) -> void:
	if s == null or t < 0.0 or t >= RING_TIME:
		return
	var c := (v.to_screen(s.pos) + Vector2(0, -6)).round()
	var d := 32.0
	var a := 0.0
	for i in RING_KEYS.size() - 1:
		var k0: Array = RING_KEYS[i]
		var k1: Array = RING_KEYS[i + 1]
		if t < k1[0]:
			var u: float = (t - float(k0[0])) / (float(k1[0]) - float(k0[0]))
			d = lerpf(k0[1], k1[1], 1.0 - (1.0 - u) * (1.0 - u))
			a = lerpf(k0[2], k1[2], u)
			break
	var r := roundi(d * 0.5)
	_ring_spans(ci, c, r, r, Color(1, 1, 1, a), 1)
	if r >= 9:
		var inner := Color.WHITE.lerp(RING_BLUE, clampf(t / 0.18, 0.0, 1.0))
		_ring_spans(ci, c, r - 1, r - 1, Color(inner, a), 1)
	if t < RING_FLASH:
		var w := Color(1, 1, 1, 1.0 - 0.4 * t / RING_FLASH)
		ci.draw_rect(Rect2(c.x - 2, c.y - 1, 5, 3), w)
		ci.draw_rect(Rect2(c.x - 1, c.y - 2, 3, 5), w)

## A ball hitting the back of the net: a short pop of white where it hits and a few drops
## thrown back off the net, gone after SPLASH_TIME.
const SPLASH_TIME := 0.22

static func draw_net_splash(ci: CanvasItem, v: PoolView, b: Ball) -> void:
	if not b.in_net() or b.net_t < 0.0 or b.net_t >= SPLASH_TIME:
		return
	var u := b.net_t / SPLASH_TIME
	var a := 1.0 - u
	var p := v.to_screen(Vector2(b.net_back_x(), b.pos.y), maxf(b.z, 0.15))
	# off the net: back towards the mouth on screen, whichever way the net hangs
	var away := -signf(v.to_screen(Vector2(b.net_line + b.net_side, 0)).x - v.to_screen(Vector2(b.net_line, 0)).x)
	if b.net_t < 0.06:
		var w := Color(1, 1, 1, 0.85)
		ci.draw_rect(Rect2(p.x - 1, p.y - 4, 3, 1), w)
		ci.draw_rect(Rect2(p.x - 1, p.y + 3, 3, 1), w)
		ci.draw_rect(Rect2(p.x + 3 * away, p.y - 1, 1, 3), w)
	for d in [Vector2(5, -6), Vector2(7, -2), Vector2(4, 3), Vector2(8, -5)]:
		var q := p + Vector2(d.x * away, d.y) * (0.4 + u) + Vector2(0, 10.0 * u * u)
		ci.draw_rect(Rect2(roundf(q.x), roundf(q.y), 1 if d.x < 6 else 2, 1), Color(1, 1, 1, 0.8 * a))

static func draw_ball(ci: CanvasItem, v: PoolView, b: Ball) -> void:
	var at := b.look()
	var g := v.to_screen(Vector2(at.x, at.y))
	var p := v.to_screen(Vector2(at.x, at.y), at.z)
	if at.z > 0.15:
		ci.draw_rect(Rect2(g.x - 1, g.y, 4, 1), Color(0, 0, 0, 0.3))
	else:
		ci.draw_rect(Rect2(p.x - 3, p.y + 2, 8, 1), Color(UI.WATER_SHINE, 0.7))
	ci.draw_rect(Rect2(p.x - 1, p.y - 2, 4, 4), BALL)
	ci.draw_rect(Rect2(p.x - 2, p.y - 1, 6, 2), BALL)
	ci.draw_rect(Rect2(p.x - 2, p.y, 6, 1), BALL_LINE)
	ci.draw_rect(Rect2(p.x, p.y - 2, 1, 1), Color("fff6c4"))
