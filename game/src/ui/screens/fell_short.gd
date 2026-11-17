extends BaseScreen
## FELL JUST SHORT! (the automatic postseason advance): shown once, when a conference tournament
## loss still got you into the NCSA (Career.fell_short_pending; the hub sends you here once the
## rest of the conference tournament and the NCSA draw are simmed). Between OH NO! and CHAMPIONS!:
## a dusk over the pool, the sun going down on the conference run (its loss on a red plate,
## ELIMINATED stamped across it), your logo on a pennant in your colours, and then the hope: the
## NCSA plate in gold, QUALIFIED! stamped on with sparks and a beam of light coming up behind it.
## CONTINUE TO NCSA TOURNAMENT plays any NCSA bye of yours through and opens your first NCSA
## matchup (Career.continue_to_ncsa). Once you leave, it's seen (season.fell_short.shown, saved).
## Never the OH NO! screen: the season isn't over.
##
## DEV preview: params {"preview": true, "model": {...}} draws a made-up one, nothing read from or
## written to the career; the button goes back to the lab.

const SKY := [Color("070c30"), Color("101845"), Color("1d1d55"), Color("33205a"), Color("552456"), Color("7a2c4a"), Color("a33e3e"), Color("c85a34"), Color("e07a32")]
const SUN := Color("ff9a3c")
const SUN_HI := Color("ffd27a")
const RED := Color("e05068")
const RED_LO := Color("5a1626")
const GOLD_HI := Color("fff2a8")
const GOLD_LO := Color("8a5a00")
const WATER := Color("0d1a55")
const WATER_HI := Color("2a3f86")
const WATER_Y := 214.0               # the waterline (480 x 270)
const DROP_T := 0.5                  # FELL JUST SHORT! has landed
const TYPE_T := 0.75                 # ...BUT YOUR SEASON ISN'T OVER! starts typing
const TYPE_CPS := 30.0
const LEFT_T := 1.35                 # the conference plate slides in
const STAMP_L := 1.75                # ELIMINATED
const LOGO_T := 1.5                  # your pennant and logo
const RIGHT_T := 2.15                # the NCSA plate slides in
const STAMP_R := 2.55                # QUALIFIED!
const TEXT_T := 2.95                 # the message
const BTN_T := 3.3                   # the button
const DONE_T := 3.6
const PLATE_W := 136.0
const PLATE_H := 70.0
const PLATE_Y := 100.0

var data := {}
var m := {}
var preview := false
var t := 0.0
var art: Control
var go_btn: Button
var left_done := false
var _heard := 0

func setup(params: Dictionary) -> void:
	data = params

func _ready() -> void:
	c = Game.career
	theme = UI.theme
	preview = bool(data.get("preview", false)) and bool(Game.settings.get("dev_mode", false))
	if preview and data.has("model"):
		m = data.model
	elif c != null and not (c.season.get("fell_short", {}) as Dictionary).is_empty():
		m = model_of(c)
	if m.is_empty():
		Game.goto("hub", {}, false)
		return
	art = UI.canvas(0, 0, _paint)
	art.name = "FellShortArt"
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	go_btn = Deck.button("CONTINUE TO NCSA TOURNAMENT  >", _continue, "primary", 260, 26)
	go_btn.name = "ContinueToNCSA"
	go_btn.add_theme_font_override("font", UI.font_big)
	go_btn.add_theme_font_size_override("font_size", 16)
	go_btn.anchor_left = 0.5
	go_btn.anchor_right = 0.5
	go_btn.anchor_top = 1.0
	go_btn.anchor_bottom = 1.0
	go_btn.offset_left = -130
	go_btn.offset_right = 130
	go_btn.offset_top = -34
	go_btn.offset_bottom = -8
	add_child(go_btn)
	Sfx.music("")
	Sfx.crowd(0.0)
	if Juice.enabled():
		go_btn.modulate.a = 0.0
		Sfx.play("whistle")
	else:
		t = DONE_T   # (REDUCE MOTION, or a test: the last frame, at once)
		_heard = 3
	set_process(Juice.enabled())

func _process(delta: float) -> void:
	t = minf(t + delta, DONE_T + 60.0)
	if _heard < 1 and t >= STAMP_L:
		_heard = 1
		Sfx.play("gasp")
	if _heard < 2 and t >= STAMP_R:
		_heard = 2
		Sfx.play("cheer")
	go_btn.modulate.a = clampf((t - BTN_T) / 0.3, 0.0, 1.0)
	art.queue_redraw()

func on_back() -> void:
	_continue()

## What the screen shows, from the career's note of it (season.fell_short).
static func model_of(cr: Career) -> Dictionary:
	var f: Dictionary = cr.season.get("fell_short", {})
	var out := {"team": cr.team(), "season": String(f.get("season", cr.season_label())), "round": String(f.get("round", "")),
		"us": int(f.get("us", 0)), "them": int(f.get("them", 0)), "so": f.get("so", []), "seed": int(f.get("seed", 0)),
		"at_large": bool(f.get("at_large", true)), "record": String(f.get("record", cr.record_text()))}
	if cr.teams.has(String(f.get("opp", ""))):
		out["opp"] = cr.teams[String(f.opp)]
	return out

## Seen; any NCSA bye played through, and on to your first NCSA game (the hub first when it has
## notes or upgrades waiting: its PLAY opens the same matchup).
func _continue() -> void:
	if left_done:
		return
	left_done = true
	Sfx.play("confirm")
	if preview:
		Game.goto(String(data.get("back", "elim_lab")), {}, false)
		return
	c.continue_to_ncsa()
	Game.save_career()
	if c.has_game() and c.queue.is_empty() and Game.upgrade_target().is_empty():
		Game.goto("matchup", {}, false)
	else:
		Game.goto("hub", {}, false)

# ------------------------------------------------------------------ the picture
func _paint(ci: Control) -> void:
	var s := ci.size
	var w := s.x
	var cx := floorf(w * 0.5)
	_sky(ci, s)
	_beam(ci, cx)
	_water(ci, s, cx)
	var sl := String(m.get("season", ""))
	if sl != "":
		Deck.ctext(ci, Rect2(0, 6, w, 9), "%s POSTSEASON" % sl, 8, Color(UI.DIM2, 0.8 * clampf(t / 0.3, 0.0, 1.0)))
	_title(ci, cx, w)
	_typed(ci, cx)
	_pennant(ci, cx)
	_conf_plate(ci, cx)
	_ncsa_plate(ci, cx)
	_message(ci, w)

## Dusk in hard bands: night on top, the sunset low, a half sun going down on the waterline.
func _sky(ci: CanvasItem, s: Vector2) -> void:
	var n := SKY.size()
	for i in n:
		var y0 := floorf(WATER_Y * i / n)
		var y1 := floorf(WATER_Y * (i + 1) / n)
		ci.draw_rect(Rect2(0, y0, s.x, y1 - y0), SKY[i])
	for i in 18:
		var x := fmod(i * 97.0 + 13.0, s.x)
		var y := fmod(i * 53.0 + 7.0, WATER_Y * 0.4)
		ci.draw_rect(Rect2(floorf(x), floorf(y), 1, 1), Color(0.8, 0.85, 1.0, 0.25 + 0.2 * sin(t * 1.3 + i)))
	# the sun, sinking a little as the screen plays: the conference run going down
	var sx := floorf(s.x * 0.22)
	var sink := minf(t / DONE_T, 1.0) * 6.0
	var rad := 22.0
	for dy in range(-int(rad), 1):
		var hw := floorf(sqrt(maxf(rad * rad - dy * dy, 0.0)))
		var y := WATER_Y + dy + sink
		if y >= WATER_Y:
			continue
		var col := SUN_HI if dy < -rad * 0.55 else SUN
		ci.draw_rect(Rect2(sx - hw, y, hw * 2.0, 1), Color(col, 0.85))

## Once you're QUALIFIED!: a gold beam coming up out of the water behind the NCSA plate.
func _beam(ci: CanvasItem, cx: float) -> void:
	var k := clampf((t - STAMP_R) / 0.5, 0.0, 1.0)
	if k <= 0.0:
		return
	var bx := cx + 145.0
	var top := lerpf(WATER_Y, 0.0, k)
	var pulse := 0.10 + 0.04 * sin(t * 2.4)
	for i in 5:
		var hw := 8.0 + i * 7.0
		ci.draw_rect(Rect2(floorf(bx - hw), floorf(top), hw * 2.0, WATER_Y - floorf(top)), Color(UI.GOLD, pulse * (1.0 - i * 0.17)))

## The pool at dusk: the sunset in streaks on it, the beam's gold too once it's up.
func _water(ci: CanvasItem, s: Vector2, cx: float) -> void:
	ci.draw_rect(Rect2(0, WATER_Y, s.x, s.y - WATER_Y), WATER)
	ci.draw_rect(Rect2(0, WATER_Y, s.x, 1), Color(SUN, 0.6))
	var off := int(t * 6.0) % 16
	var x := 0.0
	while x < s.x:
		var ph := int((x + off) / 4.0) % 4
		var dy: float = [0.0, -1.0, -2.0, -1.0][ph]
		ci.draw_rect(Rect2(x, WATER_Y + 4 + dy, 4, 1), WATER_HI)
		x += 4.0
	var sx := floorf(s.x * 0.22)
	for i in 6:
		var hw := 16.0 - i * 2.0 + 2.0 * sin(t * 2.0 + i)
		ci.draw_rect(Rect2(floorf(sx - hw), WATER_Y + 3 + i * 4, floorf(hw * 2.0), 1), Color(SUN, 0.5 - i * 0.07))
	var k := clampf((t - STAMP_R) / 0.5, 0.0, 1.0)
	if k > 0.0:
		for i in 6:
			var hw := 12.0 - i + 2.0 * sin(t * 2.6 + i)
			ci.draw_rect(Rect2(floorf(cx + 145.0 - hw), WATER_Y + 3 + i * 4, floorf(hw * 2.0), 1), Color(UI.GOLD, (0.55 - i * 0.08) * k))

## FELL JUST SHORT!: it drops in and comes up a pixel or two short of its mark, then settles.
func _title(ci: CanvasItem, cx: float, w: float) -> void:
	var txt := "FELL JUST SHORT!"
	var tw0 := Deck.text_w(txt, 20, "big")
	var sc := minf(2.0, floorf((w - 24.0) / tw0 * 4.0) / 4.0)
	var tw := tw0 * sc
	var yy := 36.0
	if t < DROP_T:
		var k := t / DROP_T
		yy = lerpf(-24.0, 40.0, k * k)
	elif t < DROP_T + 0.25:
		yy = lerpf(40.0, 36.0, (t - DROP_T) / 0.25)   # (it overshoots, and falls back short)
	var x := floorf(cx - tw * 0.5)
	var me = m.get("team")
	var under := Color("7a2c18")
	if me is PoloTeam:
		under = (me as PoloTeam).c1.darkened(0.35)
	ci.draw_set_transform(Vector2(x, floorf(yy)), 0.0, Vector2(sc, sc))
	Deck.text(ci, 1, 1, txt, 20, UI.INK, "big")
	Deck.text(ci, 0.5, 0.5, txt, 20, under, "big")
	Deck.text(ci, 0, 0, txt, 20, Color("ffb65a"), "big")
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _typed(ci: CanvasItem, cx: float) -> void:
	if t < TYPE_T:
		return
	var full := "...BUT YOUR SEASON ISN'T OVER!"
	var n := mini(full.length(), int((t - TYPE_T) * TYPE_CPS))
	var tw := Deck.text_w(full, 20, "big")
	Deck.shadow_text(ci, floorf(cx - tw * 0.5), 66, full.substr(0, n), 20, UI.GOLD, "big")

## Your logo on a pennant in your colours, between the two plates.
func _pennant(ci: CanvasItem, cx: float) -> void:
	var a := clampf((t - LOGO_T) / 0.4, 0.0, 1.0)
	if a <= 0.0:
		return
	var me = m.get("team")
	var c1 := UI.ACCENT
	var c2 := Color.WHITE
	if me is PoloTeam:
		c1 = (me as PoloTeam).c1
		c2 = (me as PoloTeam).c2
	var pw := 56.0
	var top := PLATE_Y - 6.0 + floorf((1.0 - a) * 12.0)
	var ph := 64.0
	var px := floorf(cx - pw * 0.5)
	ci.draw_rect(Rect2(px - 1, top - 1, pw + 2, ph + 2), Color(UI.INK, a))
	ci.draw_rect(Rect2(px, top, pw, ph), Color(c1, a))
	ci.draw_rect(Rect2(px, top, pw, 3), Color(c2, a))
	ci.draw_rect(Rect2(px, top + ph - 5, pw, 2), Color(c2, a))
	# the swallowtail: the notch cut out of the bottom in the sky's colour
	for i in 10:
		var hw := floorf((10 - i) * 1.4)
		ci.draw_rect(Rect2(cx - hw, top + ph - i, hw * 2.0, 1), Color(SKY[5], a))
	ci.draw_rect(Rect2(px - 4, top - 4, pw + 8, 3), Color(UI.DIM2, a))   # (its pole)
	var box := Vector2(TeamLogo.box(TeamLogo.LARGE))
	if me != null:
		TeamLogo.paint(ci, Vector2(floorf(cx - box.x * 0.5), top + 10), me, TeamLogo.LARGE)
	var label := _short(me)
	var rec := String(m.get("record", ""))
	if rec != "":
		label += "  " + rec
	Deck.ctext(ci, Rect2(cx - 100, PLATE_Y + PLATE_H + 3, 200, 9), Deck.fit(label, 200), 8, Color(UI.TEXT, a))

## The conference tournament: the loss that ended it, ELIMINATED stamped across.
func _conf_plate(ci: CanvasItem, cx: float) -> void:
	var a := clampf((t - LEFT_T) / 0.3, 0.0, 1.0)
	if a <= 0.0:
		return
	var x := floorf(cx - 40.0 - PLATE_W - (1.0 - a) * 60.0)
	var r := Rect2(x, PLATE_Y, PLATE_W, PLATE_H)
	Deck.frame(ci, r, Color(Color("1a1036"), 0.92 * a), Color(RED, a), true)
	ci.draw_rect(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, 11), Color(RED_LO, a))
	Deck.ctext(ci, Rect2(r.position.x, r.position.y + 3, r.size.x, 9), "CONFERENCE TOURNAMENT", 8, Color(UI.TEXT, a))
	var opp = m.get("opp")
	var line := "L " + Schedule.final_text([int(m.get("us", 0)), int(m.get("them", 0))], m.get("so", []))
	var iw := r.size.x - 8
	Deck.ctext(ci, Rect2(r.position.x + 4, r.position.y + 17, iw, 9), Deck.fit(line, iw), 8, Color(UI.BAD, a))
	if opp != null:
		Deck.ctext(ci, Rect2(r.position.x + 4, r.position.y + 26, iw, 9), Deck.fit("VS " + _short(opp), iw), 8, Color(UI.TEXT, a))
	Deck.ctext(ci, Rect2(r.position.x + 4, r.position.y + 35, iw, 9), Deck.fit(String(m.get("round", "")), iw), 8, Color(UI.DIM2, a))
	_stamp(ci, Rect2(r.position.x + 14, r.position.y + 48, r.size.x - 28, 16), "ELIMINATED", RED, RED_LO, STAMP_L, -1.0)

## The NCSA: in the field, gold, QUALIFIED! stamped on with sparks.
func _ncsa_plate(ci: CanvasItem, cx: float) -> void:
	var a := clampf((t - RIGHT_T) / 0.3, 0.0, 1.0)
	if a <= 0.0:
		return
	var x := floorf(cx + 40.0 + (1.0 - a) * 60.0)
	var r := Rect2(x, PLATE_Y, PLATE_W, PLATE_H)
	var lit := clampf((t - STAMP_R) / 0.3, 0.0, 1.0)
	var edge := Color(UI.GOLD, a).lerp(Color(GOLD_HI, a), lit * (0.5 + 0.5 * sin(t * 4.0)))
	Deck.frame(ci, r, Color(Color("14204e"), 0.92 * a), edge, true)
	ci.draw_rect(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, 11), Color(GOLD_LO, a))
	Deck.ctext(ci, Rect2(r.position.x, r.position.y + 3, r.size.x, 9), "NCSA TOURNAMENT", 8, Color(UI.TEXT, a))
	var seed := int(m.get("seed", 0))
	var line := ("#%d SEED" % seed) if seed > 0 else "IN THE FIELD"
	Deck.ctext(ci, Rect2(r.position.x + 4, r.position.y + 19, r.size.x - 8, 9), line, 8, Color(UI.GOLD, a))
	Deck.ctext(ci, Rect2(r.position.x + 4, r.position.y + 30, r.size.x - 8, 9), "AT-LARGE BID" if bool(m.get("at_large", true)) else "SELECTED", 8, Color(UI.DIM, a))
	_stamp(ci, Rect2(r.position.x + 14, r.position.y + 48, r.size.x - 28, 16), "QUALIFIED!", UI.GOOD, Color("1f5a2a"), STAMP_R, 1.0)
	# the sparks off the stamp
	var sp := t - STAMP_R
	if sp > 0.0 and sp < 1.2:
		var o := r.position + Vector2(r.size.x * 0.5, 56)
		for i in 14:
			var ang := -PI * (0.05 + 0.9 * float(i) / 13.0)
			var d := sp * (40.0 + (i % 4) * 14.0)
			var p := o + Vector2(cos(ang), sin(ang)) * d + Vector2(0, sp * sp * 50.0)
			var col := GOLD_HI if i % 3 == 0 else UI.GOLD
			ci.draw_rect(Rect2(floorf(p.x), floorf(p.y), 2 if i % 2 == 0 else 1, 1 if i % 2 == 0 else 2), Color(col, 1.0 - sp / 1.2))

## A rubber stamp: it lands big and slams down to size, a little tilted.
func _stamp(ci: CanvasItem, r: Rect2, txt: String, col: Color, lo: Color, at: float, tilt: float) -> void:
	if t < at:
		return
	var k := clampf((t - at) / 0.16, 0.0, 1.0)
	var sc := lerpf(1.8, 1.0, k)
	var a := clampf(k * 1.5, 0.0, 1.0)
	var ctr := r.get_center()
	ci.draw_set_transform(ctr, deg_to_rad(4.0 * tilt), Vector2(sc, sc))
	var half := r.size * 0.5
	ci.draw_rect(Rect2(-half, r.size), Color(lo, 0.85 * a))
	ci.draw_rect(Rect2(-half, Vector2(r.size.x, 1)), Color(col, a))
	ci.draw_rect(Rect2(-half + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), Color(col, a))
	ci.draw_rect(Rect2(-half, Vector2(1, r.size.y)), Color(col, a))
	ci.draw_rect(Rect2(-half + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), Color(col, a))
	var tw := Deck.text_w(txt, 16, "big")
	Deck.text(ci, floorf(-tw * 0.5) + 1, 1, txt, 16, Color(UI.INK, a), "big")
	Deck.text(ci, floorf(-tw * 0.5), 0, txt, 16, Color(col, a), "big")
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The message, word-wrapped to the screen.
func _message(ci: CanvasItem, w: float) -> void:
	var a := clampf((t - TEXT_T) / 0.4, 0.0, 1.0)
	if a <= 0.0:
		return
	var lines := _wrap("YOUR CONFERENCE TOURNAMENT RUN HAS COME TO AN END, BUT YOUR SEASON ISN'T OVER YET! YOU'VE EARNED A SPOT IN THE NCSA TOURNAMENT, AND THERE'S STILL A CHANCE TO COMPETE FOR THE NATIONAL CHAMPIONSHIP!", minf(w - 40.0, 400.0))
	var y := 186.0
	# a dark band behind it, so it reads over the sunset
	var bw := 0.0
	for ln in lines:
		bw = maxf(bw, Deck.text_w(String(ln)))
	ci.draw_rect(Rect2(floorf((w - bw) * 0.5) - 8, y - 3, bw + 16, lines.size() * 10.0 + 4), Color(SKY[0], 0.72 * a))
	for i in lines.size():
		var col := UI.TEXT if i < lines.size() - 1 else UI.GOLD
		Deck.ctext(ci, Rect2(0, y + i * 10.0, w, 10), String(lines[i]), 8, Color(col, a))

static func _wrap(s: String, width: float) -> Array:
	s = Loc.t(s)   # (the player's LANGUAGE: translated whole, then wrapped)
	var out: Array = []
	var cur := ""
	for word: String in Loc.units(s):
		var tryit := word if cur == "" else cur + Loc.gap() + word
		if cur != "" and Deck.text_w(tryit) > width:
			out.append(cur)
			cur = word
		else:
			cur = tryit
	if cur != "":
		out.append(cur)
	return out

func _short(team: Variant) -> String:
	if team is PoloTeam:
		return Colleges.display_name((team as PoloTeam).name).to_upper()
	if team is Dictionary:
		return String((team as Dictionary).get("name", "")).to_upper()
	return ""
