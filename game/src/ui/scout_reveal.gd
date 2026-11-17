class_name ScoutReveal
extends Control
## THE SCOUTING GARAGE DOOR: Coaching's SCOUT OPPONENT, every time. A big pixel-art roll-up door
## (crimson-red metal slats, red being the opponent's colour; a gunmetal roller housing above,
## steel rails either side) drops over
## Coaching with a small mechanical shake. On it, the team you play next, read from the team as it
## is right now: its logo (large, nearest-neighbour, a glow behind it), its full name, its OVR
## (big and gold, a gold highlight round it) and OFFENSE / DEFENSE / GOALKEEPING in the game's
## own stars (PoloTeam.rating_stars, half stars too). The Scout screen loads under the door as
## soon as it's down; after a short hold the door rolls up into its housing, the panels vanishing
## into the top edge one by one with everything on them, the scouting page showing beneath, and
## the overlay is gone. A tap, click or key skips straight to the page; the page can't be touched
## while the door covers it. Display only: nothing here reads or writes anything but the team.
##   Reduce motion: the same picture, no drop, shake, wipes or roll (it simply lifts away).
##   Tests (Game.test_mode): no door, straight to the page, unless a test asks for it.

signal finished

const ScoutScreen := preload("res://src/ui/screens/scout.gd")

# the timeline (seconds)
const T_LAND := 0.24        # the door has dropped into place (the Scout screen loads now)
const T_SHAKE := 0.2        # ...and shakes this long
const T_LOGO := 0.32        # the logo wipes in...
const T_NAME := 0.5         # ...the name...
const T_OVR := 0.66         # ...the overall...
const T_ROWS := 0.8         # ...then the three star rows, one after the other
const ROW_STEP := 0.12
const STAR_STEP := 0.035
const HOLD := 1.5           # the finished showcase, held
const ROLL := 1.0           # the door rolling up
const RETRACT := 0.16       # the housing and rails leaving once it's up

# the door's pieces (viewport pixels)
const MARGIN := Vector2i(10, 6)
const HOUSING_H := 12
const RAIL_W := 6
const SLAT_H := 16
const KICK_H := 12          # the bottom rail and its handle

# red: the opponent's colour in Pixel Polo
const MAROON := Color("3a0610")     # the door behind its slats
const SLAT := Color("a8142a")       # deep crimson
const SLAT_HI := Color("ff4d5e")    # the lit top edges, the rivets
const SLAT_LO := Color("5a0814")    # the grooves
const STEEL := Color("3b3a42")      # gunmetal: the housing, rails and bottom rail
const STEEL_HI := Color("75737f")
const STEEL_LO := Color("1b1a20")
const PLATE := Color("2e0710")      # the plate the team sits on
const PLATE_EDGE := Color("ff5a66")
const KICKER := Color("ff9aa4")     # NEXT OPPONENT
const LABEL := Color("ffc9ce")      # the star rows' labels, the mascot, TAP TO SKIP
const GOLD := Color("ffd23f")

var team: PoloTeam
var motion := true
var t := 0.0
var loaded := false          # the Scout screen is under the door
var done := false
var go_screen := true        # load the Scout screen (tests can show the door alone)
var _sounds := {}

var clip: Control            # the door's opening: everything on the door is clipped to it
var face: Control            # the door itself, slid up through `clip`
var frame: Control           # the housing and rails, over the door

# what's shown, read once from the team as it is now
var logo_tex: Texture2D
var logo_k := 1
var title := ""
var mascot := ""
var ovr := 0
var rows: Array = []         # [label, stars]

static var current: ScoutReveal = null

## SCOUT OPPONENT: the door over the screen, then the Scout screen; straight there when there's
## nobody to scout or in tests. A second press while one is up (or a screen change under way)
## does nothing.
static func scout(motion_override: Variant = null) -> void:
	if is_instance_valid(current) and not current.done:
		return
	if Game.is_changing_screen():
		return
	var opp: PoloTeam = ScoutScreen.next_opponent(Game.career)
	if opp == null or Game.overlay == null or (Game.test_mode and motion_override == null):
		Game.goto("scout")
		return
	var with_motion: bool = (not bool(Game.settings.get("reduce_motion", false))) if motion_override == null else bool(motion_override)
	play(Game.overlay, opp, with_motion)

## Developer Mode's PREVIEW SCOUT GARAGE ANIMATION: the very same door, timing and skip, over
## whatever screen is up, which it reveals as it rolls away. It never loads the Scout screen and
## reads only the team (your next opponent; a sample club with no career or no game left), so
## nothing is scouted, spent or saved. Replay as often as you like (one door at a time).
static func preview(motion_override: Variant = null) -> ScoutReveal:
	if is_instance_valid(current) and not current.done:
		return null
	if Game.overlay == null or Game.is_changing_screen():
		return null
	var opp: PoloTeam = ScoutScreen.next_opponent(Game.career)
	if opp == null:
		opp = League.make_team(1)
	var with_motion: bool = (not bool(Game.settings.get("reduce_motion", false))) if motion_override == null else bool(motion_override)
	return play(Game.overlay, opp, with_motion, false)

static func play(parent: Node, opp: PoloTeam, with_motion: bool = true, load_screen: bool = true) -> ScoutReveal:
	var s := ScoutReveal.new()
	s.name = "ScoutReveal"
	s.team = opp
	s.motion = with_motion
	s.go_screen = load_screen
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.theme = UI.theme
	current = s
	s._read()
	parent.add_child(s)
	s._build()
	return s

## The team's numbers, as every screen shows them, from its roster now.
func _read() -> void:
	title = Colleges.display_name(team.name).to_upper()
	mascot = team.mascot.to_upper()
	if mascot != "" and title.ends_with(mascot):
		mascot = ""   # (a club named for its mascot: the name says it once)
	ovr = team.overall_display()
	rows = [["OFFENSE", PoloTeam.rating_stars(float(team.offense_display()))],
		["DEFENSE", PoloTeam.rating_stars(float(team.defense_display()))],
		["GOALKEEPING", PoloTeam.rating_stars(float(team.goalkeeping_display()))]]
	# the school's drawn logo file that comes out biggest at a whole-number scale in LOGO_BOX (the
	# template for a team with no artwork), never smoothed
	var best := 0
	for tex: Texture2D in [TeamLogo.art(team, Vector2i(40, 40)), TeamLogo.art(team, Vector2i(48, 48)),
			TeamLogo.art(team, Vector2i(60, 60)), TeamLogo.texture(team)]:
		if tex == null:
			continue
		var k := maxi(1, mini(LOGO_BOX.x / tex.get_width(), LOGO_BOX.y / tex.get_height()))
		var area := tex.get_width() * tex.get_height() * k * k
		if area > best:
			best = area
			logo_tex = tex
			logo_k = k
		if tex == TeamLogo.art(team, Vector2i(60, 60)) and best > 0:
			break   # (a school with artwork never falls back to the template)

func _build() -> void:
	clip = Control.new()
	clip.name = "DoorClip"
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	face = Control.new()
	face.name = "Door"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.draw.connect(_draw_face)
	clip.add_child(face)
	frame = Control.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(_draw_frame)
	add_child(frame)
	resized.connect(_place)
	if not motion:
		t = T_LAND
		_land()
	_place()

# ------------------------------------------------------------------ time
func _hold_end() -> float:
	if not motion:
		return T_LAND + HOLD
	return T_ROWS + ROW_STEP * 2 + STAR_STEP * 5 + HOLD

func _process(dt: float) -> void:
	if done:
		return
	var was := t
	t += dt
	if was < T_LAND and t >= T_LAND:
		_land()
	var open_at := _hold_end()
	if not motion and t >= open_at:
		_finish()
		return
	if motion and was < open_at and t >= open_at:
		_sound("gear_up", 0.8, -4.0)
	if motion and t >= open_at + ROLL + RETRACT:
		_finish()
		return
	if motion:
		if was < T_LOGO and t >= T_LOGO:
			_sound("card", 0.9, -6.0)
		if was < T_OVR and t >= T_OVR:
			_sound("score_tick", 1.0, -4.0)
	_place()

## The door's down: the shake, its thud, and the Scout screen loads beneath.
func _land() -> void:
	_sound("clang", 0.55, -8.0)
	if go_screen and not loaded:
		loaded = true
		Game.goto("scout")

func _sound(n: String, pitch: float, db: float) -> void:
	if _sounds.has(n):
		return
	_sounds[n] = true
	Sfx.play(n, pitch, db)

## Skip: straight to the page (the screen loaded first if the door wasn't down yet).
func skip() -> void:
	if done:
		return
	if go_screen and not loaded:
		loaded = true
		Game.goto("scout")
	_finish()

func _finish() -> void:
	if done:
		return
	done = true
	set_process(false)
	if current == self:
		current = null
	finished.emit()
	queue_free()

func _input(ev: InputEvent) -> void:
	if done:
		return
	var press: bool = (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed) \
		or (ev is InputEventKey and ev.pressed and not ev.echo) or (ev is InputEventJoypadButton and ev.pressed)
	if ev is InputEventMouseButton or ev is InputEventScreenTouch or ev is InputEventScreenDrag \
			or ev is InputEventKey or ev is InputEventJoypadButton:
		get_viewport().set_input_as_handled()   # (nothing under the door hears it)
	# (the press that opened the door can't skip it: only once it's down)
	if press and t >= T_LAND:
		skip()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not done:
		skip()

# ------------------------------------------------------------------ the door's place
func door_rect() -> Rect2:
	return Rect2(Vector2(MARGIN), size - Vector2(MARGIN * 2))

## The opening under the housing: where the door hangs.
func opening() -> Rect2:
	var d := door_rect()
	return Rect2(d.position + Vector2(0, HOUSING_H), d.size - Vector2(0, HOUSING_H))

## How far the door is up, 0 (down) .. 1 (all the way into the housing).
func lift() -> float:
	if not motion:
		return 0.0
	if t < T_LAND:
		var k := t / T_LAND
		return 1.0 - k * k                 # (dropping: faster and faster)
	var open_at := _hold_end()
	if t < open_at:
		return 0.0
	var k2 := clampf((t - open_at) / ROLL, 0.0, 1.0)
	# a heavy door: slow to start, then pulled up, easing in at the top
	return k2 * k2 * (3.0 - 2.0 * k2)

## The landing shake: a few pixels, dying away.
func shake() -> Vector2:
	if not motion or t < T_LAND or t > T_LAND + T_SHAKE:
		return Vector2.ZERO
	var s := (t - T_LAND) / T_SHAKE
	var a := roundf((1.0 - s) * 2.0)
	return Vector2(roundf(sin(s * 37.0) * a * 0.5), roundf(sin(s * 53.0 + 1.0) * a))

## The housing and rails leaving, once the door is in: 0 .. 1.
func retract() -> float:
	if not motion:
		return 0.0
	return clampf((t - _hold_end() - ROLL) / RETRACT, 0.0, 1.0)

func _place() -> void:
	if clip == null:
		return
	var o := opening()
	var sh := shake()
	var up := roundf(o.size.y * lift())
	clip.position = (o.position + sh).round()
	clip.size = Vector2(o.size.x, maxf(0.0, o.size.y - up))
	face.position = Vector2(0, -up)
	face.size = o.size
	frame.position = Vector2(0, -roundf(retract() * (MARGIN.y + HOUSING_H + 4))) + sh
	frame.size = size
	queue_redraw()
	face.queue_redraw()
	frame.queue_redraw()

# ------------------------------------------------------------------ drawing
## The screen round the door, darkened while it's down.
func _draw() -> void:
	var d := door_rect()
	var a := 0.78 * (1.0 - lift()) * (1.0 - retract())
	if motion and t < T_LAND:
		a *= t / T_LAND
	if a <= 0.0:
		return
	var c := Color(0.08, 0.01, 0.02, a)
	draw_rect(Rect2(0, 0, size.x, d.position.y), c)
	draw_rect(Rect2(0, d.end.y, size.x, size.y - d.end.y), c)
	draw_rect(Rect2(0, d.position.y, d.position.x, d.size.y), c)
	draw_rect(Rect2(d.end.x, d.position.y, size.x - d.end.x, d.size.y), c)

## The roller housing on top and the two rails, over the door's edges.
func _draw_frame() -> void:
	var d := door_rect()
	var ci := frame
	# the rails
	for x in [d.position.x - RAIL_W + 2, d.end.x - 2]:
		var r := Rect2(x, d.position.y + HOUSING_H, RAIL_W, d.size.y - HOUSING_H)
		ci.draw_rect(r, STEEL)
		ci.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), STEEL_HI)
		ci.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), STEEL_LO)
		ci.draw_rect(Rect2(r.position.x + 2, r.position.y, 2, r.size.y), STEEL_LO)   # (the track)
		var y := r.position.y + 10
		while y < r.end.y - 4:
			ci.draw_rect(Rect2(r.position.x + 1, y, 1, 1), STEEL_HI)
			ci.draw_rect(Rect2(r.end.x - 2, y, 1, 1), STEEL_HI)
			y += 28
	# the housing: the drum the door rolls into, its ribs turning while it moves
	var h := Rect2(d.position.x - RAIL_W + 2, d.position.y, d.size.x + (RAIL_W - 2) * 2, HOUSING_H)
	ci.draw_rect(h.grow(1), UI.INK)
	ci.draw_rect(h, STEEL)
	ci.draw_rect(Rect2(h.position, Vector2(h.size.x, 1)), STEEL_HI)
	ci.draw_rect(Rect2(h.position.x, h.end.y - 2, h.size.x, 2), STEEL_LO)
	var turn := int(roundf(lift() * 160.0)) % 6
	var x2 := h.position.x + 6 + turn
	while x2 < h.end.x - 6:
		ci.draw_rect(Rect2(x2, h.position.y + 3, 2, HOUSING_H - 6), STEEL_LO)
		ci.draw_rect(Rect2(x2 + 2, h.position.y + 3, 1, HOUSING_H - 6), STEEL_HI.darkened(0.2))
		x2 += 6
	# the end caps, bolted
	for cx in [h.position.x, h.end.x - 10]:
		ci.draw_rect(Rect2(cx, h.position.y, 10, HOUSING_H), STEEL_HI.darkened(0.25))
		ci.draw_rect(Rect2(cx + 4, h.position.y + 5, 2, 2), STEEL_LO)
	# the shadow the housing throws on the door just under it
	if clip.size.y > 0.0:
		for i in 3:
			ci.draw_rect(Rect2(d.position.x, h.end.y + i, d.size.x, 1), Color(0, 0, 0, 0.35 - i * 0.1))

## The door: its slats, the plate on it with the team, the bottom rail with its handle.
func _draw_face() -> void:
	var ci := face
	var s := face.size
	var w := s.x
	ci.draw_rect(Rect2(Vector2.ZERO, s), MAROON)
	# the slats: the full width, a lit top edge, a dark groove under each
	var y := 0.0
	var i := 0
	while y < s.y - KICK_H:
		var hh := minf(SLAT_H, s.y - KICK_H - y)
		ci.draw_rect(Rect2(0, y, w, hh), SLAT if i % 2 == 0 else SLAT.darkened(0.06))
		ci.draw_rect(Rect2(0, y, w, 1), SLAT_HI)
		ci.draw_rect(Rect2(0, y + hh - 2, w, 1), SLAT_LO)
		ci.draw_rect(Rect2(0, y + hh - 1, w, 1), UI.INK)
		ci.draw_rect(Rect2(0, y + floorf(hh * 0.5), w, 1), Color(SLAT_HI, 0.25))
		for rx in [4.0, w - 6.0]:
			ci.draw_rect(Rect2(rx, y + 5, 2, 2), SLAT_HI)
			ci.draw_rect(Rect2(rx + 1, y + 6, 1, 1), SLAT_LO)
		y += SLAT_H
		i += 1
	# the bottom rail and its handle
	var k := Rect2(0, s.y - KICK_H, w, KICK_H)
	ci.draw_rect(k, STEEL)
	ci.draw_rect(Rect2(k.position, Vector2(w, 1)), STEEL_HI)
	ci.draw_rect(Rect2(0, s.y - 1, w, 1), UI.INK)
	var hw := 44.0
	var hx := floorf((w - hw) * 0.5)
	ci.draw_rect(Rect2(hx, k.position.y + 3, hw, 5), STEEL_LO)
	ci.draw_rect(Rect2(hx + 1, k.position.y + 4, hw - 2, 3), STEEL_HI)
	ci.draw_rect(Rect2(hx + 1, k.position.y + 6, hw - 2, 1), STEEL.darkened(0.2))
	if t >= T_LAND and lift() == 0.0:
		Deck.text(ci, 8, k.position.y + KICK_H * 0.5, "TAP TO SKIP", 8, Color(LABEL, 0.7))
	# the frame round the door
	ci.draw_rect(Rect2(Vector2.ZERO, s), UI.INK, false, 1.0)
	ci.draw_rect(Rect2(Vector2(1, 1), s - Vector2(2, 2)), Color(SLAT_HI, 0.6), false, 1.0)
	_draw_plate(ci, s)
	# the metal catching the light as the door moves: a pale band sweeping down its face
	var m := lift()
	if motion and m > 0.0 and m < 1.0:
		var by := floorf(fmod(m * 3.0, 1.0) * (s.y + 40.0)) - 20.0
		for j in 4:
			ci.draw_rect(Rect2(2, by + j * 3, w - 4, 2), Color(1, 1, 1, 0.08 - j * 0.015))

const LOGO_BOX := Vector2i(180, 80)
const PLATE_W := 290.0

## The team, centred on the door.
func _draw_plate(ci: CanvasItem, s: Vector2) -> void:
	var cx := floorf(s.x * 0.5)
	var top := 6.0
	var bot := s.y - KICK_H - 6.0
	var p := Rect2(cx - PLATE_W * 0.5, top, PLATE_W, bot - top)
	ci.draw_rect(Rect2(p.position + Vector2(3, 3), p.size), Color(0, 0, 0, 0.4))
	ci.draw_rect(p, PLATE)
	ci.draw_rect(p, UI.INK, false, 1.0)
	ci.draw_rect(p.grow(-1), PLATE_EDGE, false, 1.0)
	for corner in [p.position + Vector2(3, 3), Vector2(p.end.x - 5, p.position.y + 3), Vector2(p.position.x + 3, p.end.y - 5), p.end - Vector2(5, 5)]:
		ci.draw_rect(Rect2(corner, Vector2(2, 2)), SLAT_HI)
	# the kicker
	Deck.text(ci, p.position.x, p.position.y + 9, "NEXT OPPONENT", 8, KICKER, "caps", 1, p.size.x)
	# the logo, a soft glow behind it, wiped in from the top in whole rows
	var lr := Rect2(cx - LOGO_BOX.x * 0.5, p.position.y + 18, LOGO_BOX.x, LOGO_BOX.y)
	if t >= T_LOGO or not motion:
		var k := 1.0 if not motion else clampf((t - T_LOGO) / 0.18, 0.0, 1.0)
		var dim := Vector2(logo_tex.get_width(), logo_tex.get_height()) * logo_k
		var at := (lr.position + (lr.size - dim) * 0.5).floor()
		var gc := (at + dim * 0.5).floor()
		var gr := maxf(dim.x, dim.y) * 0.5 + 10.0
		for g in 4:
			ci.draw_circle(gc, gr - g * 7.0, Color(PLATE_EDGE, 0.07 * k))
		var rows_shown := floorf(logo_tex.get_height() * (k if motion else 1.0))
		if rows_shown > 0:
			ci.draw_texture_rect_region(logo_tex, Rect2(at, Vector2(dim.x, rows_shown * logo_k)),
				Rect2(0, 0, logo_tex.get_width(), rows_shown))
	# the name, the mascot under it
	var ny := lr.end.y + 13
	if t >= T_NAME or not motion:
		var k2 := 1.0 if not motion else clampf((t - T_NAME) / 0.12, 0.0, 1.0)
		var off := 0.0 if not motion else floorf((1.0 - k2) * 3.0) * 2.0
		var fs := 20
		while fs > 8 and Deck.text_w(title, fs, "big") > p.size.x - 16:
			fs -= 4
		Deck.shadow_text(ci, p.position.x, ny + off, title, fs, Color(UI.TEXT, k2), "big", 1, p.size.x)
		if mascot != "":
			Deck.text(ci, p.position.x, ny + 14 + off, mascot, 8, Color(LABEL, k2), "caps", 1, p.size.x)
	# the overall: big gold number, OVR beside it, a gold highlight round them
	var oy := ny + 34
	if t >= T_OVR or not motion:
		var since := t - T_OVR if motion else 9.0
		var num := str(ovr)
		var nw := Deck.text_w(num, 24, "big")
		var tw := Deck.text_w("OVR", 16, "big")
		var bw := nw + 4 + tw
		var bx := floorf(cx - bw * 0.5)
		var pop := 0.0 if since > 0.1 else floorf((0.1 - since) * 30.0)
		var box := Rect2(bx - 8, oy - 12, bw + 16, 24).grow(pop)
		var glow := 1.0 if since < 0.15 else lerpf(1.0, 0.55, clampf((since - 0.15) / 0.3, 0.0, 1.0))
		ci.draw_rect(box, Color(GOLD, 0.12 * glow))
		ci.draw_rect(box, Color(GOLD, glow), false, 1.0)
		ci.draw_rect(box.grow(-2), Color(GOLD, 0.3 * glow), false, 1.0)
		Deck.shadow_text(ci, bx, oy, num, 24, GOLD, "big")
		Deck.shadow_text(ci, bx + nw + 4, oy + 1, "OVR", 16, UI.TEXT, "big")
	# OFFENSE, DEFENSE, GOALKEEPING: the label, then the game's stars at twice the size, lit one by one
	var lw := Deck.text_w("GOALKEEPING", 8, "caps")
	var sw := Deck.star_bar_w() * 2.0
	var gx := floorf(cx - (lw + 10 + sw) * 0.5)
	for r in rows.size():
		var ry := oy + 24 + r * 20
		var start := T_ROWS + r * ROW_STEP
		if motion and t < start:
			continue
		Deck.text(ci, gx, ry, String(rows[r][0]), 8, LABEL)
		var fills := Deck.star_fills(float(rows[r][1]), float(Deck.STAR_PLACES))
		ci.draw_set_transform(Vector2(gx + lw + 10, ry - 9), 0.0, Vector2(2, 2))
		for n in fills.size():
			var lit_at := start + n * STAR_STEP
			if motion and t < lit_at:
				break
			var hop := 1.0 if motion and t - lit_at < 0.05 else 0.0
			Deck.star_place(ci, Vector2(Deck.star_x(n), -hop), fills[n])
		ci.draw_set_transform(Vector2.ZERO)
