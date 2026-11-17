extends BaseScreen
## OH NO! YOUR SEASON IS OVER! (Championship Elimination): shown once, straight after the postgame
## of the game that ended your championship hopes (the hub sends you here: Career.elim_pending),
## or after the NCSA bracket was drawn without you. A college season ending, not a career: your
## logo and theirs either side of the final score, the round it ended in, a dark-blue night with
## a muted red glow, rain on the water and the ball sinking under it. Then VIEW SEASON REVIEW: the
## season so far (recap, live), or, when it was the NCSA final, the season's own review that's
## already waiting on the hub's queue. Once you leave, it's seen (Career.elim.shown, saved).
##
## DEV preview (elim_lab): params {"preview": true, "model": {...}} draws a made-up elimination,
## nothing read from or written to the career; the button goes back to the lab.

const SKY_TOP := Color("050a24")
const SKY_LOW := Color("0d1640")
const GLOW := Color("4a1426")        # the muted red at the waterline
const OH_NO := Color("e05068")       # muted red
const OH_NO_LO := Color("7a1c30")
const WATER := Color("0a1a52")
const WATER_HI := Color("21407e")
const RAIN := Color(0.6, 0.72, 1.0, 0.22)
const BALL := ["..###..", ".#o#o#.", "##o#o##", "#o###o#", "##o#o##", ".#o#o#.", "..###.."]
const WATER_Y := 196.0               # the waterline (480 x 270)
const DROP_T := 0.55                 # OH NO! has landed
const TYPE_T := 0.9                  # YOUR SEASON IS OVER! starts typing
const TYPE_CPS := 26.0
const SCORE_T := 1.7                 # the logos and the score are in
const BALL_T := 2.1                  # the ball falls in
const TEXT_T := 2.6                  # the message and the button
const DONE_T := 3.2

var data := {}
var m := {}
var preview := false
var t := 0.0
var art: Control
var go_btn: Button
var left_done := false
var _splashed := false

func setup(params: Dictionary) -> void:
	data = params

func _ready() -> void:
	c = Game.career
	theme = UI.theme
	preview = bool(data.get("preview", false)) and bool(Game.settings.get("dev_mode", false))
	if preview and data.has("model"):
		m = data.model
	elif c != null and not c.elim.is_empty():
		m = model_of(c)
	if m.is_empty():
		Game.goto("hub", {}, false)
		return
	art = UI.canvas(0, 0, _paint)
	art.name = "SeasonOverArt"
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
	Sfx.music("")
	Sfx.crowd(0.0)
	if Juice.enabled():
		go_btn.modulate.a = 0.0
		Sfx.play("whistle")
	else:
		t = DONE_T   # (REDUCE MOTION, or a test: the last frame, at once)
	set_process(Juice.enabled())

func _process(delta: float) -> void:
	var was := t
	t = minf(t + delta, DONE_T + 60.0)
	if was < DROP_T and t >= DROP_T:
		Sfx.play("gasp")
	if was < BALL_T + 0.35 and t >= BALL_T + 0.35 and not _splashed:
		_splashed = true
		Sfx.play("splash")
	go_btn.modulate.a = clampf((t - TEXT_T) / 0.3, 0.0, 1.0)
	art.queue_redraw()

func on_back() -> void:
	_view_review()

## What the screen shows, from the career's elimination record (Career.elim).
static func model_of(cr: Career) -> Dictionary:
	var e: Dictionary = cr.elim
	var out := {"team": cr.team(), "season": String(e.get("season", cr.season_label())), "round": String(e.get("round", "")),
		"game_round": String(e.get("game_round", "")), "us": int(e.get("us", 0)), "them": int(e.get("them", 0)),
		"so": e.get("so", []), "won": bool(e.get("won", false)), "final": String(e.get("kind", "")) == "nat_final",
		"selected": bool(e.get("selected", true)), "conf": String(e.get("kind", "")).begins_with("conf_")}
	if cr.teams.has(String(e.get("opp", ""))):
		out["opp"] = cr.teams[String(e.opp)]
	return out

## Seen: the season so far (or, after the NCSA final, the season's review already queued).
func _view_review() -> void:
	if left_done:
		return
	left_done = true
	Sfx.play("confirm")
	if preview:
		Game.goto("elim_lab", {}, false)
		return
	c.elim["shown"] = true
	Game.save_career()
	# the season's own review first (the weeks simmed after you went out may have queued notes ahead
	# of it: they wait on the hub's queue behind it)
	var at := -1
	for i in c.queue.size():
		if String(c.queue[i].get("type", "")) == "recap":
			at = i
			break
	if c.phase != "season" and at > 0:
		c.queue.push_front(c.queue.pop_at(at))
		Game.save_career()
	if c.phase != "season" and not c.queue.is_empty() and String(c.queue[0].get("type", "")) == "recap":
		var q: Dictionary = c.queue[0]
		Game.goto(String(q.get("screen", "recap")), q, false)   # (the recap takes itself off the queue)
		return
	if c.phase != "season":
		Game.goto("hub", {}, false)
		return
	Game.goto("recap", {"live": true}, false)

# ------------------------------------------------------------------ the picture
func _paint(ci: Control) -> void:
	var s := ci.size
	var w := s.x
	var cx := floorf(w * 0.5)
	_sky(ci, s)
	_rain(ci, s)
	# the round it ended in, on a chip
	var round := String(m.get("round", ""))
	if round != "":
		var a := clampf(t / 0.3, 0.0, 1.0)
		var tw := Deck.text_w(round) + 14
		var r := Rect2(floorf(cx - tw * 0.5), 10, tw, 13)
		Deck.frame(ci, r, Color(OH_NO_LO, 0.85 * a), Color(OH_NO, a))
		Deck.ctext(ci, r, round, 8, Color(UI.TEXT, a))
		var sl := String(m.get("season", ""))
		if sl != "":
			Deck.ctext(ci, Rect2(0, 25, w, 9), "%s SEASON" % sl, 8, Color(UI.DIM2, 0.8 * a))
	_oh_no(ci, cx)
	_typed(ci, cx)
	_matchup(ci, cx)
	_water(ci, s)
	_ball(ci, cx)
	# the message
	var ma := clampf((t - TEXT_T) / 0.4, 0.0, 1.0)
	if ma > 0.0:
		# left out of the NCSA after the conference tournament: said so, plainly
		var msg := "YOUR CONFERENCE RUN IS OVER, AND NO NCSA BID CAME." if not bool(m.get("selected", true)) and bool(m.get("conf", false)) 			else "YOUR CHAMPIONSHIP DREAMS HAVE COME TO AN END."
		Deck.ctext(ci, Rect2(0, 166, w, 10), msg, 8, Color(UI.TEXT, ma))
		Deck.ctext(ci, Rect2(0, 177, w, 10), "THERE'S ALWAYS NEXT SEASON!", 8, Color(UI.GOLD, ma))

## A night sky in hard bands, darkest on top, the red glow low on the horizon.
func _sky(ci: CanvasItem, s: Vector2) -> void:
	var bands := 9
	for i in bands:
		var y0 := floorf(WATER_Y * i / bands)
		var y1 := floorf(WATER_Y * (i + 1) / bands)
		var col := SKY_TOP.lerp(SKY_LOW, float(i) / (bands - 1))
		if i >= bands - 3:
			col = col.lerp(GLOW, 0.22 * (i - (bands - 4)))
		ci.draw_rect(Rect2(0, y0, s.x, y1 - y0), col)
	# a few dim stars behind the rain
	for i in 22:
		var x := fmod(i * 97.0 + 13.0, s.x)
		var y := fmod(i * 53.0 + 7.0, WATER_Y * 0.55)
		var tw := 0.25 + 0.2 * sin(t * 1.3 + i)
		ci.draw_rect(Rect2(floorf(x), floorf(y), 1, 1), Color(0.75, 0.82, 1.0, tw))

## Slanting rain, falling steadily (still, without motion: the same streaks).
func _rain(ci: CanvasItem, s: Vector2) -> void:
	for i in 64:
		var x0 := fmod(i * 37.0 + 5.0, s.x + 40.0) - 20.0
		var sp := 150.0 + float(i % 5) * 22.0
		var y := fmod(i * 41.0 + t * sp, WATER_Y + 20.0) - 10.0
		var x := x0 - (y * 0.18)
		for k in 4:
			ci.draw_rect(Rect2(floorf(x - k * 0.75), floorf(y - k * 2.0), 1, 2), RAIN)

## OH NO! at twice the big font: it drops in, bounces, and shakes once.
func _oh_no(ci: CanvasItem, cx: float) -> void:
	var txt := "OH NO!"
	var sc := 2.0
	var tw := Deck.text_w(txt, 20, "big") * sc
	var yy := 50.0
	if t < DROP_T:
		var k := t / DROP_T
		yy = lerpf(-30.0, 50.0, k * k)
	elif t < DROP_T + 0.18:
		yy = 50.0 - 4.0 * sin((t - DROP_T) / 0.18 * PI)
	var dx := 0.0
	if t > DROP_T and t < DROP_T + 0.45:
		dx = roundf(sin((t - DROP_T) * 55.0) * 2.0 * (1.0 - (t - DROP_T) / 0.45))
	var x := floorf(cx - tw * 0.5 + dx)
	ci.draw_set_transform(Vector2(x, floorf(yy)), 0.0, Vector2(sc, sc))
	Deck.text(ci, 1, 1, txt, 20, UI.INK, "big")
	Deck.text(ci, 0.5, 0.5, txt, 20, OH_NO_LO, "big")
	Deck.text(ci, 0, 0, txt, 20, OH_NO, "big")
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## YOUR SEASON IS OVER!, typed out after it.
func _typed(ci: CanvasItem, cx: float) -> void:
	if t < TYPE_T:
		return
	var full := "YOUR SEASON IS OVER!"
	var n := mini(full.length(), int((t - TYPE_T) * TYPE_CPS))
	var tw := Deck.text_w(full, 20, "big")
	var x := floorf(cx - tw * 0.5)
	Deck.shadow_text(ci, x, 80, full.substr(0, n), 20, UI.TEXT, "big")

## Your logo (dimmed, a little lower) and theirs either side of the final score.
func _matchup(ci: CanvasItem, cx: float) -> void:
	var a := clampf((t - SCORE_T + 0.4) / 0.4, 0.0, 1.0)
	if a <= 0.0:
		return
	var box := Vector2(TeamLogo.box(TeamLogo.LARGE))
	var y := 102.0
	var me = m.get("team")
	var opp = m.get("opp")
	var lx := floorf(cx - 120 - box.x * 0.5)
	var rx := floorf(cx + 120 - box.x * 0.5)
	var slide := floorf((1.0 - a) * 24.0)
	if me != null:
		TeamLogo.paint(ci, Vector2(lx - slide, y + 2), me, TeamLogo.LARGE)
		ci.draw_rect(Rect2(lx - slide, y + 2, box.x, box.y), Color(SKY_TOP, 0.35 * a))   # (dimmed: the loss)
		Deck.ctext(ci, Rect2(lx - 50 - slide, y + box.y + 6, box.x + 100, 9), _short(me), 8, Color(UI.DIM, a))
	if opp != null:
		TeamLogo.paint(ci, Vector2(rx + slide, y), opp, TeamLogo.LARGE)
		Deck.ctext(ci, Rect2(rx - 50 + slide, y + box.y + 6, box.x + 100, 9), _short(opp), 8, Color(UI.TEXT, a))
	if t < SCORE_T:
		return
	var us := int(m.get("us", 0))
	var them := int(m.get("them", 0))
	var sr := Rect2(cx - 60, y + 4, 120, 30)
	Deck.ctext(ci, Rect2(sr.position.x, y - 10, sr.size.x, 9), "FINAL", 8, UI.DIM2)
	var score := Schedule.final_text([us, them], m.get("so", []), " - ")
	var sw := Deck.text_w(score, 20, "big") * 1.5
	ci.draw_set_transform(Vector2(floorf(cx - sw * 0.5), y + 10), 0.0, Vector2(1.5, 1.5))
	Deck.text(ci, 1, 1, score, 20, UI.INK, "big")
	Deck.text(ci, 0, 0, score, 20, UI.BAD if not bool(m.get("won", false)) else UI.TEXT, "big")
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var gr := String(m.get("game_round", ""))
	if gr != "" and gr != String(m.get("round", "")):
		Deck.ctext(ci, Rect2(sr.position.x - 30, y + 40, sr.size.x + 60, 9), Deck.fit(gr, sr.size.x + 60), 8, UI.DIM2)

func _short(team: Variant) -> String:
	if team is PoloTeam:
		return Colleges.display_name((team as PoloTeam).name).to_upper()
	if team is Dictionary:
		return String((team as Dictionary).get("name", "")).to_upper()
	return ""

## The pool at night: stepped waves, a little swell.
func _water(ci: CanvasItem, s: Vector2) -> void:
	ci.draw_rect(Rect2(0, WATER_Y, s.x, s.y - WATER_Y), WATER)
	ci.draw_rect(Rect2(0, WATER_Y, s.x, 1), Color(GLOW.lightened(0.3), 0.7))
	var x := 0.0
	var off := int(t * 6.0) % 16
	while x < s.x:
		var ph := int((x + off) / 4.0) % 4
		var dy: float = [0.0, -1.0, -2.0, -1.0][ph]
		ci.draw_rect(Rect2(x, WATER_Y + 3 + dy, 4, 1), WATER_HI)
		ci.draw_rect(Rect2(x, WATER_Y + 12 + dy, 4, 1), Color(WATER_HI, 0.5))
		x += 4.0
	# rain rings on the water
	for i in 7:
		var p := fmod(t * 0.9 + i * 0.37, 1.0)
		var rx := fmod(i * 71.0 + 29.0, s.x)
		var rw := floorf(2.0 + p * 10.0)
		ci.draw_rect(Rect2(floorf(rx - rw * 0.5), WATER_Y + 6 + (i % 3) * 7, rw, 1), Color(0.7, 0.8, 1.0, 0.35 * (1.0 - p)))

## The ball drops into the water and sinks, bubbles coming up after it.
func _ball(ci: CanvasItem, cx: float) -> void:
	if t < BALL_T:
		return
	var k := t - BALL_T
	var bx := floorf(cx - 3)
	var surface := WATER_Y - 3
	var by := 0.0
	if k < 0.35:
		by = lerpf(150.0, surface, (k / 0.35) * (k / 0.35))
	else:
		by = minf(surface + (k - 0.35) * 9.0, WATER_Y + 26.0)
	var under := by > surface
	var ball_col := UI.GOLD if not under else UI.GOLD.lerp(WATER, clampf((by - surface) / 26.0, 0.0, 0.85))
	Deck.pat(ci, Vector2(bx, floorf(by)), BALL, {"#": ball_col, "o": ball_col.darkened(0.45)})
	if k >= 0.35:
		# the splash: two short arcs of droplets
		var sp := k - 0.35
		if sp < 0.5:
			for i in 6:
				var dir := -1.0 if i < 3 else 1.0
				var j := float(i % 3)
				var px := cx + dir * (4.0 + sp * (26.0 + j * 10.0))
				var py := surface - sp * (30.0 + j * 8.0) + sp * sp * 140.0
				ci.draw_rect(Rect2(floorf(px), floorf(py), 1, 1), Color(0.8, 0.9, 1.0, 1.0 - sp * 2.0))
		# bubbles rising from where it sank
		for i in 4:
			var bp := fmod(sp * 0.8 + i * 0.25, 1.0)
			ci.draw_rect(Rect2(floorf(cx - 2 + (i % 2) * 4 + sin(sp * 4.0 + i) * 1.5), floorf(by - bp * 18.0), 1, 1),
				Color(0.7, 0.85, 1.0, 0.6 * (1.0 - bp)))
