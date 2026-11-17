extends BaseScreen
## After a career game, revealed a tap at a time like an old arcade sports game:
##   1. FINAL: the score (it bounces in), WIN / LOSS, who it was against, your records, the credits.
##      Behind the panel: pixel confetti for a win, a dim blue drift for a loss.
##   2. tap: if any of your players heated up in this game (HOT, or HOT to VERY HOT), the score
##      shrinks up to a strip and HotReveal shows each of them on his own roster card, his new red
##      star heating up (HEATING UP! / ON FIRE!), then moves on by itself (a tap skips the rest).
##      Nobody heated up: no such stage. The grades themselves (RAW, EXPECTED, +/-) are still
##      made and kept (PlayerForm.grade_team, his page's LAST GAME); they're just not shown here.
##   3. then straight on to PLAYER DEVELOPMENT (the bulletin board: every player's XP bar
##      filling), then maybe a coaching event; the postgame ends the week. There's no POLO POINTS
##      breakdown stage: FINAL already shows what the game paid, and the header the balance.
## Taps during a transition do nothing, so one tap never skips two stages. Every effect is
## worked out from the time alone (no per-frame state), so it costs next to nothing.

enum Stage { FINAL, HOT, NEXT }

const NAVY := Color("071b3f")
const YELLOW := Color("ffd83d")
const MOVE := 0.35            # a stage's panels move this long
const COMPACT_H := 36.0
const HINT_H := 14.0          # TAP TO CONTINUE, at the bottom
const SCORE_SIZE := 47.0      # the final score, full size (it shrinks to COMPACT_SCORE in the strip)
const COMPACT_SCORE := 26.0
const WIN_FX := 2.0           # the confetti falls and fades over this long
const LOSS_FX := 1.5

var done := false
var stage := Stage.FINAL
var t := 0.0                  # seconds since this stage began
var cv: Control
var s: Dictionary
var g: Dictionary
var won := false
var opp: PoloTeam
var bits: Array = []          # confetti / drift: {x, y, vy, sway, col, delay, size}, px from the panel's top centre
var form: Array = []          # your seven's grades (PlayerForm.grade_team rows), keeper first
var heaters: Array = []       # the ones whose form went up (HotReveal.heaters)
var reveal: HotReveal
var revealed := false         # the HOT reveal played: the result is already a strip

func _ready() -> void:
	c = Game.career
	if c == null or c.last_summary.is_empty():
		Game.goto("hub")
		return
	s = c.last_summary
	g = s.game
	won = s.won
	opp = c.teams[s.opp]
	build(String(s.round), false, true)
	form = s.get("form", [])
	_make_bits()
	cv = UI.canvas(0, 0, _draw_stage)
	cv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.mouse_filter = Control.MOUSE_FILTER_STOP
	cv.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # the logo stays pixels
	cv.gui_input.connect(_on_input)
	body.add_child(cv)
	heaters = HotReveal.heaters(form)
	reveal = HotReveal.new()
	reveal.finished.connect(_reveal_done)
	cv.add_child(reveal)
	Sfx.music("menu")
	_celebrate_records()

## A record your team broke in this game (Records.breaks): celebrated once (RecordShow), after
## the score has landed; reopening the summary doesn't play it again.
func _celebrate_records() -> void:
	var broke: Array = s.get("records", [])
	if broke.is_empty() or s.get("records_shown", false) or Game.test_mode:
		return
	s["records_shown"] = true
	await get_tree().create_timer(0.9).timeout
	if is_inside_tree():
		RecordShow.play(self, broke)

## The pixels behind the FINAL panel: yellow and white confetti for a win, a few blue ones
## drifting down for a loss. Seeded from the game, so the same result always looks the same.
func _make_bits() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(g.h) + str(g.a) + str(c.week))
	var n := 30 if won else 14
	for i in n:
		var col: Color
		if won:
			col = YELLOW if i % 3 != 0 else Color.WHITE
		else:
			col = Color("3d6fd6") if i % 2 == 0 else Color("1d4ab8")
		bits.append({"x": rng.randf_range(-190.0, 190.0), "y": rng.randf_range(-30.0, 40.0),
			"vy": rng.randf_range(16.0, 32.0) if won else rng.randf_range(8.0, 16.0),
			"sway": rng.randf_range(0.0, TAU), "col": col,
			"delay": rng.randf_range(0.0, 0.5 if won else 0.3), "size": 3 if (won and i % 4 == 0) else 2})

func _process(dt: float) -> void:
	t += dt
	if cv != null:
		cv.queue_redraw()

## How long the current stage takes to settle (taps wait for it).
func _busy_for() -> float:
	match stage:
		Stage.HOT:
			return 0.2
	return 0.35

func _on_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	tap(ev.position)

## A tap (`pos` in canvas px): on FINAL, the HOT reveal if anyone heated up, else on to PLAYER
## DEVELOPMENT; during the reveal, skip it.
func tap(_pos: Vector2 = Vector2.ZERO) -> void:
	if done or t < _busy_for():
		return
	match stage:
		Stage.FINAL:
			Sfx.play("click")
			t = 0.0
			if reveal.start(heaters, c.team()):
				stage = Stage.HOT
				revealed = true
			else:
				stage = Stage.NEXT
				_continue()
		Stage.HOT:
			reveal.skip()

## The reveal is over (played out, or skipped): on to PLAYER DEVELOPMENT.
func _reveal_done() -> void:
	if stage != Stage.HOT:
		return
	stage = Stage.NEXT
	t = 0.0
	_continue()

# ------------------------------------------------------------------ drawing
static func _ease(x: float) -> float:
	var u := clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u) * (1.0 - u)

func _draw_stage(ci: Control) -> void:
	var sz := ci.size
	var k := 0.0 if stage == Stage.FINAL else _ease(t / MOVE)
	if stage == Stage.NEXT and revealed:
		k = 1.0   # already a strip (the HOT reveal shrank it)
	_draw_result(ci, sz, k)
	if stage != Stage.NEXT and stage != Stage.HOT and t >= _busy_for():
		_draw_hint(ci, sz)

## Where the FINAL panel sits, full size.
func _full_rect(sz: Vector2) -> Rect2:
	var lines: Array = (s.get("lines", []) as Array).slice(0, 3)
	var h := 146.0 + 10.0 * lines.size() + (14.0 if s.get("simmed", false) else 0.0)
	var w := minf(290.0, sz.x - 16.0)
	return Rect2(roundf((sz.x - w) / 2.0), roundf(maxf(2.0, (sz.y - HINT_H - h) / 2.0)), w, h)

## The result panel: big in the middle (k = 0), a strip at the top (k = 1). In between it
## slides up and shuts from the bottom, the score riding up into the strip.
func _draw_result(ci: Control, sz: Vector2, k: float) -> void:
	var full := _full_rect(sz)
	if stage == Stage.FINAL:
		_draw_fx_behind(ci, full)
	var cw := minf(300.0, sz.x - 16.0)
	var compact := Rect2(roundf((sz.x - cw) / 2.0), 2.0, cw, COMPACT_H)
	var r := Rect2(full.position.lerp(compact.position, k).round(), full.size.lerp(compact.size, k).round())
	# the panel itself settles in: a touch big, then its size
	if stage == Stage.FINAL and t < 0.3:
		var grow := roundf(sin(clampf(t / 0.3, 0.0, 1.0) * PI) * 4.0)
		r = r.grow(grow)
	ci.draw_rect(r, Color(NAVY, 0.9))
	ci.draw_rect(r, UI.BORDER, false, 1.0)
	var x := r.position.x
	var w := r.size.x
	var y := full.position.y if k == 0.0 else r.position.y
	var bottom := r.end.y - 2.0
	var res_col := UI.GOOD if won else UI.BAD
	# everything but the score sits at its full-size place and is cut off as the panel shuts
	var row := func(dy: float, text: String, size: int, col: Color, font: String) -> void:
		if y + dy <= bottom and k < 0.98:
			UI.text(ci, Vector2(x, roundf(y + dy)), text, size, col, font, HORIZONTAL_ALIGNMENT_CENTER, w)
	row.call(19.0, "FINAL", 16, UI.TEXT, "big")
	_draw_result_word(ci, x, w, y, bottom, k, res_col)
	row.call(104.0, ("VS " if s.home else "AT ") + opp.name.to_upper(), 8, UI.DIM, "caps")
	row.call(117.0, "RECORD %s    CONF %s" % [c.record_text(), c.conf_record_text()], 8, UI.TEXT, "caps")
	if y + 139.0 <= bottom and k < 0.98:
		CreditCoin.draw_amount(ci, x, roundf(y + 133.0), CreditCoin.text(int(s.earned), true), 20, YELLOW, "big", 20, 1, w)
	var lines: Array = (s.get("lines", []) as Array).slice(0, 3)
	for i in lines.size():
		var ln := String(lines[i])
		row.call(152.0 + i * 10.0, Deck.fit(ln, w - 12.0), 8, YELLOW if ln.begins_with("NEW ATTRIBUTE") else UI.WARN, "caps")
	if s.get("simmed", false):
		row.call(full.size.y - 6.0, "(SIMULATED)", 8, UI.DIM, "caps")
	# the score: bounces in at first, then rides up into the strip, the clubs right beside it
	var pop := 1.0
	if stage == Stage.FINAL:
		var u := clampf(t / 0.3, 0.0, 1.0)
		pop = lerpf(0.6, 1.0, u) + sin(u * PI) * 0.18
	var size := int(roundf(lerpf(SCORE_SIZE, COMPACT_SCORE, k) * pop))
	var sy := roundf(lerpf(y + 70.0, y + 28.0, k))
	var score := Schedule.score_text(g, s.home).replace("-", " - ")
	var sw := UI.text_width(score, size, "big")
	var cx := x + w / 2.0
	UI.text(ci, Vector2(roundf(cx - sw / 2.0), sy), score, size, UI.TEXT, "big")
	var gap := lerpf(14.0, 10.0, k)
	var id_y := roundf(sy - lerpf(8.0, 3.0, k))
	var room := w / 2.0 - sw / 2.0 - gap - 6.0
	if k < 0.5:
		# full size: the clubs' logos either side of the score, as big as the room allows
		# (shrinking as the panel starts to shut; the strip goes back to names)
		var lb := minf(minf(room, 60.0), lerpf(60.0, 28.0, k * 2.0))
		var ly := roundf(sy - 15.0 * pop - lb / 2.0)
		TeamLogo.draw_in(ci, Rect2(roundf(cx - sw / 2.0 - gap - (room + lb) / 2.0), ly, lb, lb), c.team())
		TeamLogo.draw_in(ci, Rect2(roundf(cx + sw / 2.0 + gap + (room - lb) / 2.0), ly, lb, lb), opp)
	else:
		# the strip: the clubs by their short names, as big as the room beside the score allows
		var styles := [[16, "big"], [8, "caps"], [8, "body"]]
		Hud.draw_name(ci, Hud.fit_name(c.team(), room, styles), Vector2(roundf(cx - sw / 2.0 - gap - room), id_y), HORIZONTAL_ALIGNMENT_RIGHT, room)
		Hud.draw_name(ci, Hud.fit_name(opp, room, styles), Vector2(roundf(cx + sw / 2.0 + gap), id_y), HORIZONTAL_ALIGNMENT_LEFT, room)
	if k > 0.6:
		var a := clampf((k - 0.6) / 0.4, 0.0, 1.0)
		UI.text(ci, Vector2(x + 6, y + 13), "FINAL", 8, Color(UI.DIM, a), "caps")
		var rt := "WIN" if won else "LOSS"
		UI.text(ci, Vector2(x + w - 6 - UI.text_width(rt, 8, "caps"), y + 13), rt, 8, Color(res_col, a), "caps")

## WIN scales up into place; LOSS fades in, settling down a few pixels. Both a beat after the score.
func _draw_result_word(ci: Control, x: float, w: float, y: float, bottom: float, k: float, col: Color) -> void:
	if k >= 0.98 or y + 90.0 > bottom:
		return
	var u := clampf((t - 0.25) / 0.3, 0.0, 1.0) if stage == Stage.FINAL else 1.0
	if u <= 0.0:
		return
	if won:
		var size := int(roundf(lerpf(10.0, 16.0, u) + sin(u * PI) * 3.0))
		UI.text(ci, Vector2(x, roundf(y + 90.0)), "WIN", size, col, "big", HORIZONTAL_ALIGNMENT_CENTER, w)
	else:
		var dy := roundf(lerpf(-6.0, 0.0, u))
		UI.text(ci, Vector2(x, roundf(y + 90.0 + dy)), "LOSS", 16, Color(col, u), "big", HORIZONTAL_ALIGNMENT_CENTER, w)

## Behind the FINAL panel. A win: pixel confetti falling (and fading by WIN_FX) and a few
## sparkles blinking just off the corners. A loss: a dark blue shade round the panel and a
## few blue pixels drifting down, gone by LOSS_FX. The panel is drawn over all of it.
func _draw_fx_behind(ci: Control, panel: Rect2) -> void:
	var life := WIN_FX if won else LOSS_FX
	if t >= life:
		return
	var top := panel.position + Vector2(panel.size.x / 2.0, 0)
	if not won:
		var a := sin(clampf(t / life, 0.0, 1.0) * PI) * 0.45
		ci.draw_rect(panel.grow(12.0), Color(0.0, 0.03, 0.15, a))
	for b in bits:
		var bt := t - float(b.delay)
		if bt < 0.0:
			continue
		var fade := clampf((life - t) / 0.5, 0.0, 1.0)
		var p := top + Vector2(float(b.x) + sin(bt * 3.0 + float(b.sway)) * (3.0 if won else 1.5),
			float(b.y) + bt * float(b.vy))
		var sz := int(b.size)
		ci.draw_rect(Rect2(p.round(), Vector2(sz, sz)), Color(b.col, fade))
	if won:
		# four sparkles, one off each corner, each blinking once
		var corners := [panel.position + Vector2(-6, -4), Vector2(panel.end.x + 5, panel.position.y - 4),
			Vector2(panel.position.x - 6, panel.end.y + 3), panel.end + Vector2(5, 3)]
		for i in corners.size():
			var st := t - (0.25 + i * 0.18)
			if st < 0.0 or st > 0.24:
				continue
			_sparkle(ci, (corners[i] as Vector2).round(), YELLOW if i % 2 == 0 else Color.WHITE, 1 if st < 0.08 or st > 0.16 else 2)

## A little plus-shaped pixel sparkle, `r` px from its centre.
static func _sparkle(ci: CanvasItem, p: Vector2, col: Color, r: int) -> void:
	ci.draw_rect(Rect2(p.x - r, p.y, r * 2 + 1, 1), col)
	ci.draw_rect(Rect2(p.x, p.y - r, 1, r * 2 + 1), col)

func _draw_hint(ci: Control, sz: Vector2) -> void:
	var blink := 0.6 + 0.4 * sin(t * 5.0)
	var txt := "TAP TO CONTINUE"
	var tw := UI.text_width(txt, 8, "caps")
	var tx := roundf((sz.x - tw - 9.0) / 2.0)
	var col := Color(UI.TEXT, blink)
	UI.text_shadow(ci, Vector2(tx, sz.y - 4), txt, 8, col, "caps")
	ResultsPanel._arrow(ci, Vector2(tx + tw + 4, sz.y - 9), false, col)

## A club's name in caps, shortened to fit `w` px if it has to.
static func _fit(team: PoloTeam, w: float) -> String:
	return ResultsPanel._fit(team, w)

func on_back() -> void:
	_continue()

## On to PLAYER DEVELOPMENT (your roster's XP on the bulletin board), the last postgame screen
## (then maybe a coaching event; the postgame ends the week).
func _continue() -> void:
	if done:
		return
	done = true
	Game.goto("player_development")
