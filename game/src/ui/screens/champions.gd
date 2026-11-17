extends BaseScreen
## CHAMPIONS! NCSA NATIONAL CHAMPIONS (the OH NO! screen's other half): shown once, straight after
## the postgame of the NCSA final you won (the hub sends you here: Career.champ_pending). A title
## night, in two beats. First the quiet: a dark pool, and one firework rocket climbing slowly out
## of the water on its sparkling trail while the crowd holds its breath. Then it bursts, and the
## burst lets everything go at once: a white flash, one huge shell in your colours and gold,
## confetti flung out of it, CHAMPIONS! growing out of the blast, the stadium lights coming up
## and sweeping, and the national trophy rising out of the pool between your logo (lit, bobbing)
## and theirs, the final score under it. Then VIEW SEASON REVIEW: the season's own review, already
## waiting on the hub's queue (or the hub, which shows what's queued ahead of it). Once you leave,
## it's seen (Career.champ.shown, saved).
##
## DEV preview (elim_lab): params {"preview": true, "model": {...}} draws a made-up title, nothing
## read from or written to the career; the button goes back to the lab.

const SKY_TOP := Color("040b2e")
const SKY_LOW := Color("10205e")
const GLOW := Color("6a4a10")        # the gold on the horizon
const GOLD_HI := Color("fff2a8")
const GOLD_LO := Color("b8860b")
const GOLD_INK := Color("5a3a00")
const WATER := Color("0a1a52")
const WATER_HI := Color("2a4c96")
const WATER_Y := 200.0               # the waterline (480 x 270)
## The rocket climbs for BOOM_T seconds; everything else is timed from its burst.
const BOOM_T := 2.6
const BURST_Y := 50.0                # where it bursts: CHAMPIONS! grows out of it
const SLAM_T := BOOM_T + 0.3         # CHAMPIONS! at full size
const TYPE_T := BOOM_T + 0.5         # NCSA NATIONAL CHAMPIONS types out
const TYPE_CPS := 30.0
const TROPHY_T := BOOM_T + 0.45      # the trophy starts to rise
const RISE := 0.6
const SCORE_T := BOOM_T + 0.85       # the logos and the score are in
const TEXT_T := BOOM_T + 1.3         # the message and the button
const DONE_T := BOOM_T + 2.0
const BURST_LIFE := 3.2              # the shell's sparks, falling and twinkling out
const FW_T := BOOM_T + 0.7           # then the small fireworks, all over the sky...
const FW_EVERY := 0.55               # ...one this often, for as long as you stay
const FW_LIFE := 1.25

var data := {}
var m := {}
var preview := false
var t := 0.0
var art: Control
var go_btn: Button
var left_done := false
var _pops_heard := 0
var _cols: Array = []                # the show's colours: gold, your two, white

func setup(params: Dictionary) -> void:
	data = params

func _ready() -> void:
	c = Game.career
	theme = UI.theme
	preview = bool(data.get("preview", false)) and bool(Game.settings.get("dev_mode", false))
	if preview and data.has("model"):
		m = data.model
	elif c != null and not c.champ.is_empty():
		m = model_of(c)
	if m.is_empty():
		Game.goto("hub", {}, false)
		return
	var me = m.get("team")
	var c1 := UI.ACCENT
	var c2 := Color.WHITE
	if me is PoloTeam:
		c1 = (me as PoloTeam).c1
		c2 = (me as PoloTeam).c2
	elif me is Dictionary:
		c1 = Color(String(me.get("c1", "2a68f5")))
		c2 = Color(String(me.get("c2", "ffffff")))
	# (a team colour too dark to read on the night sky is lifted)
	_cols = [UI.GOLD, c1 if c1.get_luminance() > 0.25 else c1.lightened(0.45), c2 if c2.get_luminance() > 0.25 else c2.lightened(0.45), Color.WHITE, GOLD_HI]
	art = UI.canvas(0, 0, _paint)
	art.name = "ChampionsArt"
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	go_btn = Deck.button("VIEW SEASON REVIEW  >", _view_review, "primary", 210, 28)
	go_btn.name = "ViewSeasonReview"
	go_btn.add_theme_font_override("font", UI.font_big)
	go_btn.add_theme_font_size_override("font_size", 16)
	go_btn.anchor_left = 0.5
	go_btn.anchor_right = 0.5
	go_btn.anchor_top = 1.0
	go_btn.anchor_bottom = 1.0
	go_btn.offset_left = -105
	go_btn.offset_right = 105
	go_btn.offset_top = -38
	go_btn.offset_bottom = -10
	add_child(go_btn)
	if Juice.enabled():
		go_btn.modulate.a = 0.0
		Sfx.music("")      # (the quiet before it: the music comes in with the burst)
		Sfx.crowd(0.15)
	else:
		Sfx.music("victory")
		t = DONE_T   # (REDUCE MOTION, or a test: the last frame, at once)
	set_process(Juice.enabled())

func _process(delta: float) -> void:
	var was := t
	t = minf(t + delta, 600.0)
	if t < BOOM_T:
		Sfx.crowd(lerpf(0.15, 0.5, t / BOOM_T))   # (the crowd rising with the rocket)
	if was < BOOM_T and t >= BOOM_T:
		Sfx.play("bang")
		Sfx.play("cheer")
		Sfx.crowd(1.0)
		Sfx.music("victory")
	var n := int(floorf((t - FW_T) / FW_EVERY)) + 1 if t >= FW_T else 0
	if n > _pops_heard and _pops_heard < 4:
		_pops_heard = n
		Sfx.play("bang", randf_range(0.95, 1.2), -12.0)
	if was < TROPHY_T + RISE and t >= TROPHY_T + RISE:
		Sfx.play("record")
	if was < DONE_T + 2.0 and t >= DONE_T + 2.0:
		Sfx.crowd(0.35)
	go_btn.modulate.a = clampf((t - TEXT_T) / 0.3, 0.0, 1.0)
	art.queue_redraw()

func on_back() -> void:
	_view_review()

## What the screen shows, from the career's title (Career.champ).
static func model_of(cr: Career) -> Dictionary:
	var e: Dictionary = cr.champ
	var out := {"team": cr.team(), "season": String(e.get("season", cr.season_label())), "us": int(e.get("us", 0)), "them": int(e.get("them", 0)),
		"so": e.get("so", []), "record": String(e.get("record", "")), "conf_title": bool(e.get("conf_title", false)),
		"conf_abbr": cr.conf_abbr()}
	if cr.teams.has(String(e.get("opp", ""))):
		out["opp"] = cr.teams[String(e.opp)]
	return out

## Seen: the season's review (queued by the off-season), or the hub with what's ahead of it.
func _view_review() -> void:
	if left_done:
		return
	left_done = true
	Sfx.play("confirm")
	Sfx.crowd(0.0)
	if preview:
		Game.goto("elim_lab", {}, false)
		return
	c.champ["shown"] = true
	Game.save_career()
	if not c.queue.is_empty() and String(c.queue[0].get("type", "")) == "recap":
		var q: Dictionary = c.queue[0]
		Game.goto(String(q.get("screen", "recap")), q, false)   # (the recap takes itself off the queue)
		return
	Game.goto("hub", {}, false)

# ------------------------------------------------------------------ the picture
func _paint(ci: Control) -> void:
	var s := ci.size
	var w := s.x
	var cx := floorf(w * 0.5)
	_sky(ci, s)
	_spotlights(ci, s)
	_rocket(ci, cx)
	_fireworks(ci, s)
	_burst(ci, cx)
	var a := clampf((t - BOOM_T - 0.2) / 0.3, 0.0, 1.0)
	var chip := "NCSA FINAL"
	var tw := Deck.text_w(chip) + 14
	var r := Rect2(floorf(cx - tw * 0.5), 10, tw, 13)
	Deck.frame(ci, r, Color(GOLD_INK, 0.9 * a), Color(UI.GOLD, a))
	Deck.ctext(ci, r, chip, 8, Color(GOLD_HI, a))
	var sl := String(m.get("season", ""))
	if sl != "":
		Deck.ctext(ci, Rect2(0, 25, w, 9), "%s SEASON" % sl, 8, Color(UI.DIM, 0.85 * a))
	_rays(ci, cx)
	_champions(ci, cx)
	_typed(ci, cx)
	_trophy_rise(ci, cx)
	_matchup(ci, cx)
	_water(ci, s)
	_confetti(ci, s)
	var ma := clampf((t - TEXT_T) / 0.4, 0.0, 1.0)
	if ma > 0.0:
		var line := "THE NATIONAL TITLE IS YOURS!"
		if bool(m.get("conf_title", false)):
			line = "%s AND NCSA CHAMPIONS. WHAT A SEASON!" % String(m.get("conf_abbr", "CONFERENCE"))
		Deck.ctext(ci, Rect2(0, 178, w, 10), line, 8, Color(UI.TEXT, ma))
		var rec := String(m.get("record", ""))
		Deck.ctext(ci, Rect2(0, 189, w, 10), "FINAL RECORD %s  -  A SEASON TO REMEMBER!" % rec if rec != "" else "A SEASON TO REMEMBER!", 8, Color(UI.GOLD, ma))
	# the flash when it bursts
	if t >= BOOM_T and t < BOOM_T + 0.3:
		ci.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 0.97, 0.85, 0.65 * (1.0 - (t - BOOM_T) / 0.3)))

## A night sky in hard bands, the stadium's gold glow low on the horizon, a few stars.
func _sky(ci: CanvasItem, s: Vector2) -> void:
	var bands := 9
	for i in bands:
		var y0 := floorf(WATER_Y * i / bands)
		var y1 := floorf(WATER_Y * (i + 1) / bands)
		var col := SKY_TOP.lerp(SKY_LOW, float(i) / (bands - 1))
		if i >= bands - 3:
			col = col.lerp(GLOW, 0.2 * (i - (bands - 4)) * _lit())
		ci.draw_rect(Rect2(0, y0, s.x, y1 - y0), col.darkened(0.35 * (1.0 - _lit())))
	for i in 26:
		var x := fmod(i * 97.0 + 13.0, s.x)
		var y := fmod(i * 53.0 + 7.0, WATER_Y * 0.6)
		var tw := 0.3 + 0.3 * sin(t * 2.1 + i)
		ci.draw_rect(Rect2(floorf(x), floorf(y), 1, 1), Color(1.0, 0.95, 0.8, tw))

## How far the stadium has lit up: dark while the rocket climbs, full soon after the burst.
func _lit() -> float:
	return clampf((t - BOOM_T) / 0.5, 0.0, 1.0)

## Two stadium spotlights sweeping up from the pool's corners (on with the burst).
func _spotlights(ci: CanvasItem, s: Vector2) -> void:
	var a := _lit()
	if a <= 0.0:
		return
	for side in [-1.0, 1.0]:
		var base := Vector2(s.x * 0.5 + side * (s.x * 0.5 + 10.0), WATER_Y)
		var ang: float = -PI * 0.5 + side * (-0.45 + 0.28 * sin(t * 0.7 + (0.0 if side < 0.0 else 2.0)))
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)
		var tip := base + dir * 320.0
		var pts := PackedVector2Array([base, tip + perp * 34.0, tip - perp * 34.0])
		ci.draw_colored_polygon(pts, Color(1.0, 0.93, 0.7, 0.07 * a))
		var inner := PackedVector2Array([base, tip + perp * 14.0, tip - perp * 14.0])
		ci.draw_colored_polygon(inner, Color(1.0, 0.95, 0.8, 0.06 * a))

## The one firework: a fizzing spark head out of the pool, climbing slowly (slower near the top),
## wobbling a little, a trail of sparks dropping away behind it. Gone at the burst.
func _rocket_at(tt: float, cx: float) -> Vector2:
	var k := clampf(tt / BOOM_T, 0.0, 1.0)
	var ez := 1.0 - pow(1.0 - k, 1.7)
	return Vector2(cx + sin(tt * 7.0) * 1.2, lerpf(WATER_Y - 2.0, BURST_Y, ez))

func _rocket(ci: CanvasItem, cx: float) -> void:
	if t >= BOOM_T:
		return
	# the trail: where it was, sparks falling away and dimming
	for j in range(1, 46):
		var past := t - j * 0.035
		if past < 0.0:
			break
		var q := _rocket_at(past, cx)
		var age := j * 0.035
		var drift := Vector2(sin(j * 2.3) * age * 7.0, age * age * 30.0)
		var al := 1.0 - float(j) / 46.0
		var col: Color = GOLD_HI if j < 6 else (UI.GOLD if j < 16 else Color(1.0, 0.55, 0.2))
		ci.draw_rect(Rect2((q + drift + Vector2(0, 3)).floor(), Vector2(2 if j < 12 else 1, 2 if j < 8 else 1)), Color(col, al))
		if j % 3 == 0:
			ci.draw_rect(Rect2((q + drift * 1.8 + Vector2(-2 + j % 5, 4)).floor(), Vector2(1, 1)), Color(GOLD_HI, al * 0.7))
	var p := _rocket_at(t, cx).floor()
	# a soft glow round the head, brighter as it nears the top
	var g := 0.18 + 0.25 * (t / BOOM_T)
	# (stepped rings, wider in the middle: round, never a box)
	for ring in [[6, 0.18], [4, 0.3], [2, 0.45]]:
		var r: int = ring[0]
		var gc := Color(1.0, 0.78, 0.3, g * float(ring[1]))
		ci.draw_rect(Rect2(p.x + 1 - r, p.y - 1, r * 2, 4), gc)
		ci.draw_rect(Rect2(p.x - 1, p.y + 1 - r, 4, r * 2), gc)
		ci.draw_rect(Rect2(p.x + 1 - r + 2, p.y + 1 - r + 2, r * 2 - 4, r * 2 - 4), gc)
	# the head: a white-hot core in a gold halo, pulsing
	var big := int(t * 24.0) % 2 == 0
	ci.draw_rect(Rect2(p.x - 1, p.y - 1, 4, 4), UI.GOLD)
	ci.draw_rect(Rect2(p.x, p.y - 2, 2, 6), UI.GOLD)
	ci.draw_rect(Rect2(p.x - 2, p.y, 6, 2), UI.GOLD)
	ci.draw_rect(Rect2(p.x, p.y, 2, 2), Color.WHITE)
	if big:
		ci.draw_rect(Rect2(p.x - 1, p.y, 4, 2), GOLD_HI)
		ci.draw_rect(Rect2(p.x, p.y - 1, 2, 4), GOLD_HI)
	# fizz: little sparks spitting off the head every which way
	for i in 6:
		var ph := fmod(t * 9.0 + i * 0.37, 1.0)
		var th := float(i) * 1.9 + floorf(t * 9.0 + i * 0.37) * 2.7
		var d := 2.0 + ph * 6.0
		ci.draw_rect(Rect2(floorf(p.x + 1 + cos(th) * d), floorf(p.y + 1 + sin(th) * d), 1, 1), Color(GOLD_HI, 1.0 - ph))

## The small fireworks after the big one: a shell every FW_EVERY seconds, all over the sky,
## bursting round in the show's colours, sparks falling and twinkling out. The same shells every
## time (no dice).
func _fireworks(ci: CanvasItem, s: Vector2) -> void:
	if t < FW_T:
		return
	var last := int(floorf((t - FW_T) / FW_EVERY))
	for k in range(maxi(0, last - 3), last + 1):
		var age := t - FW_T - k * FW_EVERY
		if age < 0.0 or age > FW_LIFE:
			continue
		var bx := 40.0 + fmod(k * 173.0 + 61.0, s.x - 80.0)
		var by := 34.0 + fmod(k * 59.0 + 17.0, 70.0)
		var col: Color = _cols[k % _cols.size()]
		var col2: Color = _cols[(k + 2) % _cols.size()]
		var climb := 0.18
		if age < climb:
			# the shell going up on its trail
			var y := lerpf(WATER_Y, by, age / climb)
			ci.draw_rect(Rect2(floorf(bx), floorf(y), 2, 2), Color(GOLD_HI, 0.95))
			ci.draw_rect(Rect2(floorf(bx), floorf(y) + 3, 1, 6), Color(GOLD_HI, 0.4))
			continue
		var ba := age - climb
		var n := 30
		var sp := 44.0 + float(k % 3) * 10.0
		for i in n:
			var th := TAU * i / n + k * 0.37
			var d := sp * (1.0 - exp(-ba * 3.2))
			var px := bx + cos(th) * d
			var py := by + sin(th) * d + ba * ba * 26.0
			var fade := sqrt(maxf(0.0, 1.0 - ba / (FW_LIFE - climb)))
			if fade <= 0.0:
				continue
			var twinkle := 1.0 if ba < 0.5 else (0.4 + 0.6 * float((i + int(ba * 20.0)) % 2))
			var cc := (col if i % 2 == 0 else col2)
			var ps := 2.0 if ba < 0.55 else 1.0
			ci.draw_rect(Rect2(floorf(px), floorf(py), ps, ps), Color(cc, fade * twinkle))
			if ba < 0.35:
				ci.draw_rect(Rect2(floorf(bx + cos(th) * d * 0.6), floorf(by + sin(th) * d * 0.6), 1, 1), Color(cc, 0.5 * fade))
		if ba < 0.1:
			ci.draw_rect(Rect2(bx - 4, by - 4, 9, 9), Color(1, 1, 1, 0.9))
			ci.draw_rect(Rect2(bx - 8, by - 1, 17, 3), Color(1, 1, 1, 0.5))
			ci.draw_rect(Rect2(bx - 1, by - 8, 3, 17), Color(1, 1, 1, 0.5))

## The burst: one huge shell in three rings (gold and white outside, your colours within), each
## spark flung out, slowing, falling and twinkling; then little gold crackles round where it
## was. The same shell every time (no dice).
func _burst(ci: CanvasItem, cx: float) -> void:
	var ba := t - BOOM_T
	if ba < 0.0 or ba > BURST_LIFE:
		return
	var o := Vector2(cx, BURST_Y)
	var rings := [[90, 240.0, 0], [64, 165.0, 1], [44, 95.0, 2]]
	for ring in rings:
		var n: int = ring[0]
		var reach: float = ring[1]
		var which: int = ring[2]
		for i in n:
			var th := TAU * i / n + which * 0.21
			var d := reach * (0.85 + 0.3 * fmod(i * 0.618, 1.0)) * (1.0 - exp(-ba * 2.6))
			var px := o.x + cos(th) * d
			var py := o.y + sin(th) * d * 0.9 + ba * ba * 14.0
			var life := BURST_LIFE * (0.6 + 0.4 * fmod(i * 0.381 + which * 0.2, 1.0))
			if ba > life:
				continue
			var fade := sqrt(1.0 - ba / life)
			var twinkle := 1.0 if ba < 0.8 else (0.3 + 0.7 * float((i + int(ba * 14.0)) % 2))
			var col: Color
			match which:
				0:
					col = UI.GOLD if i % 3 != 0 else Color.WHITE
				1:
					col = _cols[1] if i % 2 == 0 else _cols[2]
				_:
					col = GOLD_HI if i % 2 == 0 else _cols[1]
			var ps := 2.0 if ba < 0.9 else 1.0
			ci.draw_rect(Rect2(floorf(px), floorf(py), ps, ps), Color(col, fade * twinkle))
			# its streak back towards the centre while it's flying fast
			if ba < 0.45:
				for q in 3:
					var dd := d * (0.82 - q * 0.12)
					ci.draw_rect(Rect2(floorf(o.x + cos(th) * dd), floorf(o.y + sin(th) * dd * 0.9 + ba * ba * 14.0), 1, 1), Color(col, 0.5 * fade * (1.0 - q * 0.3)))
	# the core flash
	if ba < 0.18:
		var k := 1.0 - ba / 0.18
		ci.draw_rect(Rect2(o.x - 7, o.y - 7, 15, 15), Color(1, 1, 1, 0.95 * k))
		ci.draw_rect(Rect2(o.x - 18, o.y - 1, 37, 3), Color(1, 1, 1, 0.7 * k))
		ci.draw_rect(Rect2(o.x - 1, o.y - 18, 3, 37), Color(1, 1, 1, 0.7 * k))
	# crackles: little gold pops scattered round where the shell was
	if ba > 0.9 and ba < 1.8:
		for i in 18:
			var at := 0.9 + fmod(i * 0.137, 0.8)
			var age := ba - at
			if age < 0.0 or age > 0.14:
				continue
			var cp := o + Vector2(cos(i * 2.4) * (40.0 + fmod(i * 23.0, 70.0)), sin(i * 2.4) * (24.0 + fmod(i * 17.0, 40.0)) + 20.0)
			ci.draw_rect(Rect2(cp.x - 1, cp.y, 3, 1), GOLD_HI)
			ci.draw_rect(Rect2(cp.x, cp.y - 1, 1, 3), GOLD_HI)

## Confetti, flung out of the burst in every direction, slowing, then fluttering down for as long
## as you stay (a piece that falls off the bottom floats in again from the top).
func _confetti(ci: CanvasItem, s: Vector2) -> void:
	var tt := t - BOOM_T
	if tt <= 0.0:
		return
	for i in 120:
		var th := TAU * fmod(i * 0.618, 1.0)
		var spd := 50.0 + fmod(i * 37.0, 130.0)
		var fall := 16.0 + float(i % 7) * 4.0
		var fling := (1.0 - exp(-tt * 2.4)) / 2.4
		var x := s.x * 0.5 + cos(th) * spd * fling + sin(tt * 2.6 + i) * 5.0 * minf(tt, 1.0)
		var y := BURST_Y + sin(th) * spd * fling * 0.8 + fall * tt
		if y > s.y + 4.0:
			y = fmod(y - s.y - 4.0, s.y + 14.0) - 10.0
		x = fposmod(x, s.x)
		var flip := int(tt * 6.0 + i) % 3
		var sz: Vector2 = [Vector2(3, 2), Vector2(2, 3), Vector2(1, 2)][flip]
		var col: Color = _cols[i % _cols.size()]
		ci.draw_rect(Rect2(floorf(x), floorf(y), sz.x, sz.y), Color(col, 0.95))

## Light behind the trophy: slow rays turning round it once it's up.
func _rays(ci: CanvasItem, cx: float) -> void:
	var a := clampf((t - TROPHY_T) / 0.6, 0.0, 1.0)
	if a <= 0.0:
		return
	var c0 := Vector2(cx, 118)
	for i in 12:
		var th := TAU * i / 12.0 + t * 0.25
		var d1 := Vector2(cos(th - 0.09), sin(th - 0.09)) * 120.0
		var d2 := Vector2(cos(th + 0.09), sin(th + 0.09)) * 120.0
		ci.draw_colored_polygon(PackedVector2Array([c0, c0 + d1, c0 + d2]), Color(1.0, 0.85, 0.35, 0.06 * a))

## CHAMPIONS! at twice the big font: it slams down from huge, then a glint runs across it.
func _champions(ci: CanvasItem, cx: float) -> void:
	var txt := "CHAMPIONS!"
	var sc := 2.0
	if t < BOOM_T:
		return
	if t < SLAM_T:
		var k := (t - BOOM_T) / (SLAM_T - BOOM_T)
		sc = lerpf(0.4, 2.35, 1.0 - pow(1.0 - k, 3.0))   # (out of the blast, a touch too big...)
	elif t < SLAM_T + 0.16:
		sc = lerpf(2.35, 2.0, (t - SLAM_T) / 0.16)         # (...and settling)
	var a := clampf((t - BOOM_T) / 0.1, 0.0, 1.0)
	var tw := Deck.text_w(txt, 20, "big") * sc
	var shake := 0.0
	if t > SLAM_T and t < SLAM_T + 0.3:
		shake = roundf(sin((t - SLAM_T) * 60.0) * 1.5 * (1.0 - (t - SLAM_T) / 0.3))
	var pos := Vector2(floorf(cx - tw * 0.5), floorf(50.0 + shake))
	ci.draw_set_transform(pos, 0.0, Vector2(sc, sc))
	Deck.text(ci, 1, 1, txt, 20, Color(UI.INK, a), "big")
	Deck.text(ci, 0.5, 0.5, txt, 20, Color(GOLD_LO, a), "big")
	Deck.text(ci, 0, 0, txt, 20, Color(UI.GOLD, a), "big")
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the glint, every few seconds once it's landed
	var gt := fmod(t - SLAM_T - 0.4, 3.0)
	if t > SLAM_T + 0.4 and gt < 0.45:
		var gx := pos.x - 10.0 + (tw + 20.0) * (gt / 0.45)
		for y in range(-11, 12):
			ci.draw_rect(Rect2(floorf(gx - y * 0.4), pos.y + y, 2, 1), Color(1, 1, 1, 0.55))
	# sparkles at its corners
	if t > SLAM_T:
		for i in 4:
			var ph := fmod(t * 1.7 + i * 0.6, 1.0)
			if ph < 0.4:
				var sp := Vector2(pos.x - 8 + (tw + 16) * float(i % 2), pos.y - 12 + 24 * float(i / 2))
				var arm := 2 if ph < 0.2 else 1
				ci.draw_rect(Rect2(sp.x - arm, sp.y, arm * 2 + 1, 1), GOLD_HI)
				ci.draw_rect(Rect2(sp.x, sp.y - arm, 1, arm * 2 + 1), GOLD_HI)

## NCSA NATIONAL CHAMPIONS, typed out under it.
func _typed(ci: CanvasItem, cx: float) -> void:
	if t < TYPE_T:
		return
	var full := "NCSA NATIONAL CHAMPIONS"
	var n := mini(full.length(), int((t - TYPE_T) * TYPE_CPS))
	var tw := Deck.text_w(full, 16, "big")
	Deck.shadow_text(ci, floorf(cx - tw * 0.5), 80, full.substr(0, n), 16, UI.TEXT, "big")

## The trophy rises into place between the logos, and shines.
func _trophy_rise(ci: CanvasItem, cx: float) -> void:
	if t < TROPHY_T:
		return
	var k := clampf((t - TROPHY_T) / RISE, 0.0, 1.0)
	var ez := 1.0 - pow(1.0 - k, 3.0)
	var top := lerpf(150.0, 92.0, ez)
	var bob := roundf(sin(t * 2.2) * 1.0) if k >= 1.0 else 0.0
	_cup(ci, Vector2(cx, floorf(top + bob)), 2.0, clampf(k * 2.0, 0.0, 1.0))

## The NCSA trophy, drawn in hard pixels: a deep bowl with its rim and highlight, two looped
## handles, the stem and its knot, a stepped base with a plaque. `top` is the rim's centre.
func _cup(ci: CanvasItem, top: Vector2, s: float, a: float) -> void:
	var gold := Color(UI.GOLD, a)
	var hi := Color(GOLD_HI, a)
	var lo := Color(GOLD_LO, a)
	var ink := Color(GOLD_INK, a)
	var R := func(x: float, y: float, w: float, h: float, col: Color):
		ci.draw_rect(Rect2(floorf(top.x + x * s), floorf(top.y + y * s), w * s, h * s), col)
	# handles (behind the bowl): loops out to each side
	for side in [-1, 1]:
		var x0 := -12.0 if side < 0 else 9.0
		R.call(x0, 1, 3, 1, lo)
		R.call(x0 if side < 0 else x0 + 2, 2, 1, 4, lo)
		R.call(x0, 6, 3, 1, lo)
	# the bowl: widest at the rim, narrowing to the stem
	var halves := [9, 9, 9, 9, 8, 8, 7, 6, 5, 4]
	for y in halves.size():
		var hw: int = halves[y]
		R.call(-hw, y, hw * 2, 1, gold)
		R.call(-hw, y, 2, 1, hi)                 # its lit left side
		R.call(hw - 2, y, 2, 1, lo)              # its shaded right
	R.call(-9, 0, 18, 1, hi)                     # the rim
	R.call(-10, 0, 1, 1, lo)
	R.call(9, 0, 1, 1, lo)
	R.call(-5, 2, 1, 5, Color(1, 1, 1, 0.6 * a))   # a white glint down the bowl
	R.call(-1, 3, 2, 3, ink)                     # the NCSA star, stamped
	R.call(-2, 4, 4, 1, ink)
	# stem, knot, base
	R.call(-1, 10, 2, 3, lo)
	R.call(-3, 13, 6, 1, gold)
	R.call(-1, 14, 2, 2, lo)
	R.call(-5, 16, 10, 1, gold)
	R.call(-6, 17, 12, 3, ink)
	R.call(-6, 17, 12, 1, lo)
	R.call(-3, 18, 6, 1, Color(UI.GOLD, 0.8 * a))   # the plaque
	# its sparkle, now and then
	var ph := fmod(t * 0.9, 1.0)
	if a >= 1.0 and ph < 0.3:
		var sp := Vector2(top.x - 7 * s, top.y + 1 * s)
		var arm := 3 if ph < 0.15 else 2
		ci.draw_rect(Rect2(sp.x - arm, sp.y, arm * 2 + 1, 1), Color.WHITE)
		ci.draw_rect(Rect2(sp.x, sp.y - arm, 1, arm * 2 + 1), Color.WHITE)

## Your logo (lit, in a gold frame, bobbing) and theirs (dimmed) either side; the final score
## under the trophy.
func _matchup(ci: CanvasItem, cx: float) -> void:
	var a := clampf((t - SCORE_T + 0.4) / 0.4, 0.0, 1.0)
	if a <= 0.0:
		return
	var box := Vector2(TeamLogo.box(TeamLogo.LARGE))
	var y := 100.0
	var lx := floorf(cx - 120 - box.x * 0.5)
	var rx := floorf(cx + 120 - box.x * 0.5)
	var slide := floorf((1.0 - a) * 24.0)
	var me = m.get("team")
	var opp = m.get("opp")
	if me != null:
		var bob := roundf(sin(t * 3.0) * 1.0) if a >= 1.0 else 0.0
		var fr := Rect2(lx - slide - 4, y - 4 + bob, box.x + 8, box.y + 8)
		var pulse := 0.55 + 0.45 * sin(t * 4.0)
		ci.draw_rect(fr.grow(1), Color(UI.GOLD, 0.25 * pulse * a))
		Deck.frame(ci, fr, Color(GOLD_INK, 0.5 * a), Color(UI.GOLD, a))
		TeamLogo.paint(ci, Vector2(lx - slide, y + bob), me, TeamLogo.LARGE)
		Deck.ctext(ci, Rect2(lx - 50 - slide, y + box.y + 8, box.x + 100, 9), _short(me), 8, Color(UI.GOLD, a))
	if opp != null:
		TeamLogo.paint(ci, Vector2(rx + slide, y + 2), opp, TeamLogo.LARGE)
		ci.draw_rect(Rect2(rx + slide, y + 2, box.x, box.y), Color(SKY_TOP, 0.4 * a))   # (dimmed: the runners-up)
		Deck.ctext(ci, Rect2(rx - 50 + slide, y + box.y + 8, box.x + 100, 9), _short(opp), 8, Color(UI.DIM, a))
	if t < SCORE_T:
		return
	var score := _final(m)
	var sw := Deck.text_w(score, 20, "big") * 1.5
	ci.draw_set_transform(Vector2(floorf(cx - sw * 0.5), 150), 0.0, Vector2(1.5, 1.5))
	Deck.text(ci, 1, 1, score, 20, UI.INK, "big")
	Deck.text(ci, 0, 0, score, 20, UI.GOLD, "big")
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The final's score, "9 - 7" or after a shootout "10(3) - 10(2)".
static func _final(m: Dictionary) -> String:
	return Schedule.final_text([int(m.get("us", 0)), int(m.get("them", 0))], m.get("so", []), " - ")

func _short(team: Variant) -> String:
	if team is PoloTeam:
		return Colleges.display_name((team as PoloTeam).name).to_upper()
	if team is Dictionary:
		return String((team as Dictionary).get("name", "")).to_upper()
	return ""

## The pool, lit gold by the show: stepped waves and the trophy's reflection shimmering.
func _water(ci: CanvasItem, s: Vector2) -> void:
	ci.draw_rect(Rect2(0, WATER_Y, s.x, s.y - WATER_Y), WATER)
	ci.draw_rect(Rect2(0, WATER_Y, s.x, 1), Color(GOLD_HI, 0.6))
	var off := int(t * 6.0) % 16
	var x := 0.0
	while x < s.x:
		var ph := int((x + off) / 4.0) % 4
		var dy: float = [0.0, -1.0, -2.0, -1.0][ph]
		ci.draw_rect(Rect2(x, WATER_Y + 3 + dy, 4, 1), WATER_HI)
		ci.draw_rect(Rect2(x, WATER_Y + 12 + dy, 4, 1), Color(WATER_HI, 0.5))
		x += 4.0
	# the gold reflection, broken up by the waves
	var ra := clampf((t - TROPHY_T) / 0.6, 0.0, 1.0)
	if ra > 0.0:
		var cx := floorf(s.x * 0.5)
		for i in 8:
			var rw := 18.0 - i * 2.0 + sin(t * 3.0 + i) * 3.0
			ci.draw_rect(Rect2(floorf(cx - rw * 0.5 + sin(t * 2.0 + i * 1.3) * 2.0), WATER_Y + 4 + i * 3, floorf(rw), 1), Color(UI.GOLD, 0.35 * ra * (1.0 - i / 8.0)))
		# the splash as it broke the surface
		var k := t - TROPHY_T
		if k < 0.5:
			for i in 8:
				var dir := -1.0 if i < 4 else 1.0
				var j := float(i % 4)
				var px := cx + dir * (6.0 + k * (30.0 + j * 12.0))
				var py := WATER_Y - k * (40.0 + j * 10.0) + k * k * 160.0
				ci.draw_rect(Rect2(floorf(px), floorf(py), 1, 1), Color(0.85, 0.92, 1.0, 1.0 - k * 2.0))
