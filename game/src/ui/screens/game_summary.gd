extends BaseScreen
## After a career game, revealed a tap at a time like an old arcade sports game:
##   1. FINAL: the score (it bounces in), WIN / LOSS, who it was against, your records, the credits.
##      Behind the panel: pixel confetti for a win, a dim blue drift for a loss.
##   2. tap: if any of your players heated up in this game (HOT, or HOT to VERY HOT), the score
##      shrinks up to a strip and HotReveal shows each of them on his own roster card, his new red
##      star heating up (HEATING UP! / ON FIRE!), then moves on by itself (a tap skips the rest).
##      Nobody heated up: no such stage. The grades themselves (RAW, EXPECTED, +/-) are still
##      made and kept (PlayerForm.grade_team, his page's LAST GAME); they're just not shown here.
##   3. the rest of the round rolls down instead (the conference, the tournament, or
##      everyone, by the kind of round).
##   4. tap: those roll away and UP NEXT slides up: the next opponent, then CREDITS EARNED, each
##      reward on its own line (CreditRewards: WIN, UPSET VICTORY, WIN BY 5+, a streak...) and
##      the TOTAL, the balance counting up from before the game. CONTINUE goes to the
##      POSTGAME REVIEW (then maybe a coaching event), which ends the week.
## Taps during a transition do nothing, so one tap never skips two stages. Every effect is
## worked out from the time alone (no per-frame state), so it costs next to nothing.

enum Stage { FINAL, HOT, LEAGUE, NEXT }

const NAVY := Color("071b3f")
const ROW_A := Color(0.03, 0.09, 0.22, 0.88)
const ROW_B := Color(0.03, 0.09, 0.22, 0.66)
const YELLOW := Color("ffd83d")
const MOVE := 0.35            # a stage's panels move this long
const ROW_GAP := 0.05         # the league results roll in one after another
const COMPACT_H := 36.0
const ROW_H := 18.0
const HINT_H := 14.0          # TAP TO CONTINUE, at the bottom
const SCORE_SIZE := 47.0      # the final score, full size (it shrinks to COMPACT_SCORE in the strip)
const COMPACT_SCORE := 26.0
const CR_FILL := 0.8          # the CR bar fills this long once UP NEXT is in
const WIN_FX := 2.0           # the confetti falls and fades over this long
const LOSS_FX := 1.5
const LOGO := 48.0            # the next opponent's logo, px

var done := false
var stage := Stage.FINAL
var t := 0.0                  # seconds since this stage began
var cv: Control
var s: Dictionary
var g: Dictionary
var won := false
var opp: PoloTeam
var league: Array = []        # the round's other games worth showing (see _league_games)
var league_title := ""
var next: Dictionary = {}
var credit_lines: Array = []  # [[label, credits], ...]: what this game paid (CreditRewards)
var cont_rect := Rect2()
var cr_before := 0            # the wallet before this game, and now: the bar fills between them
var cr_after := 0
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
	_league_games()
	form = s.get("form", [])
	next = c.next_game()
	credit_lines = s.get("credits", [])
	cr_after = c.wallet()
	cr_before = int(s.get("cr_before", cr_after - int(s.earned)))
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

## The rest of this round, by what kind of game yours was: your conference's other games this
## week after a conference game, every other game of a tournament round, and the same day's
## games around the country otherwise.
func _league_games() -> void:
	var r: Dictionary = c.cur()
	var kind := "conf" if Schedule.is_conf_game(r, g) and not Schedule.is_playoff(r) else String(r.get("kind", ""))
	if kind == "conf":
		league_title = "AROUND THE %s" % c.conf_abbr()
	elif Schedule.is_playoff(r):
		league_title = "AROUND THE TOURNAMENT"
	else:
		league_title = "AROUND COLLEGE WATER POLO"
	for gg in r.games:
		if gg == g or gg.r == null:
			continue
		if kind != "conf" and int(gg.get("d", 1)) != int(g.get("d", 1)):
			continue
		if kind == "conf" and (c.teams[gg.h] as PoloTeam).conf != c.team().conf and (c.teams[gg.a] as PoloTeam).conf != c.team().conf:
			continue
		league.append(gg)

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
		Stage.LEAGUE:
			return MOVE + ROW_GAP * league.size() + 0.1
		Stage.NEXT:
			return MOVE * 2.0
	return 0.35

func _on_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	tap(ev.position)

## A tap at `pos` (canvas px): the next stage, or CONTINUE on the last one.
func tap(pos: Vector2) -> void:
	if done or t < _busy_for():
		return
	match stage:
		Stage.FINAL:
			Sfx.play("click")
			stage = Stage.LEAGUE
			t = 0.0
			if reveal.start(heaters, c.team()):
				stage = Stage.HOT
				revealed = true
		Stage.HOT:
			reveal.skip()
		Stage.LEAGUE:
			stage = Stage.NEXT
			t = 0.0
			Sfx.play("click")
		Stage.NEXT:
			if cont_rect.has_point(pos):
				_continue()

## The reveal is over (played out, or skipped): on to the round.
func _reveal_done() -> void:
	if stage != Stage.HOT:
		return
	stage = Stage.LEAGUE
	t = 0.0

## The CR shown right now on UP NEXT: counts up from before the game as the bar fills.
func cr_shown() -> int:
	if stage != Stage.NEXT:
		return cr_before
	var u := clampf((t - MOVE * 1.6) / CR_FILL, 0.0, 1.0)
	return int(roundf(lerpf(cr_before, cr_after, u)))

# ------------------------------------------------------------------ drawing
static func _ease(x: float) -> float:
	var u := clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u) * (1.0 - u)

func _draw_stage(ci: Control) -> void:
	var sz := ci.size
	var k := 0.0 if stage == Stage.FINAL else _ease(t / MOVE)
	if stage == Stage.LEAGUE and revealed:
		k = 1.0   # already a strip (the HOT reveal shrank it)
	_draw_result(ci, sz, k)
	if stage == Stage.LEAGUE:
		_draw_league(ci, sz, t - MOVE * 0.6, 0.0)
	elif stage == Stage.NEXT:
		var out := _ease(t / MOVE)
		if out < 1.0:
			_draw_league(ci, sz, 99.0, out)
		_draw_next(ci, sz, _ease((t - MOVE * 0.6) / MOVE))
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
	# the clubs by their short names, as big as the room beside the score allows
	var room := w / 2.0 - sw / 2.0 - gap - 6.0
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

## The rest of the round, rolling down a row at a time from under the heading (`since`: seconds
## since it began). `out` 0..1 rolls it away again, down and off.
func _draw_league(ci: Control, sz: Vector2, since: float, out: float) -> void:
	if since < 0.0:
		return
	var top := 2.0 + COMPACT_H + 6.0 + roundf(out * sz.y)
	# as narrow as the longest names allow
	var name_w := 0.0
	for gg in league:
		name_w = maxf(name_w, UI.text_width(_fit(c.teams[gg.h] as PoloTeam, 150.0), 8, "caps"))
		name_w = maxf(name_w, UI.text_width(_fit(c.teams[gg.a] as PoloTeam, 150.0), 8, "caps"))
	var w := clampf(2.0 * (name_w + 44.0) + 20.0, 280.0, minf(400.0, sz.x - 16.0))
	var x := roundf((sz.x - w) / 2.0)
	var head_h := 16.0
	ci.draw_rect(Rect2(x, top, w, head_h), Color(NAVY, 0.9))
	UI.text(ci, Vector2(x, top + 12), league_title, 10, YELLOW, "caps", HORIZONTAL_ALIGNMENT_CENTER, w)
	var y0 := top + head_h
	if league.is_empty():
		ci.draw_rect(Rect2(x, y0, w, ROW_H), ROW_A)
		UI.text(ci, Vector2(x, y0 + 12), "NO OTHER GAMES THIS ROUND", 8, UI.DIM, "caps", HORIZONTAL_ALIGNMENT_CENTER, w)
		return
	var room := int(floorf((sz.y - HINT_H - y0) / ROW_H))
	var mid := roundf(x + w / 2.0)
	for i in mini(league.size(), room):
		var p := clampf((since - ROW_GAP * i) / 0.15, 0.0, 1.0)
		if p <= 0.0:
			break
		var gg: Dictionary = league[i]
		# rolls down out from under the row above: it shows from the top as it comes
		var ry := y0 + i * ROW_H
		ci.draw_rect(Rect2(x, ry, w, roundf(ROW_H * p)), ROW_A if i % 2 == 0 else ROW_B)
		if p < 0.7:
			continue
		var hw: bool = Schedule.winner(gg) == gg.h
		var hn := _fit(c.teams[gg.h] as PoloTeam, w / 2.0 - 44.0)
		var an := _fit(c.teams[gg.a] as PoloTeam, w / 2.0 - 44.0)
		var by := ry + 12.0
		UI.text(ci, Vector2(mid - 38 - UI.text_width(hn, 8, "caps"), by), hn, 8, UI.TEXT if hw else UI.DIM, "caps")
		UI.text(ci, Vector2(mid + 38, by), an, 8, UI.DIM if hw else UI.TEXT, "caps")
		# the scores sit in fixed columns either side of the dash, one digit or two
		var sc: Array = gg.r.s
		UI.text(ci, Vector2(mid - 32, by + 2), str(sc[0]), 16, YELLOW if hw else UI.DIM, "big", HORIZONTAL_ALIGNMENT_CENTER, 24)
		UI.text(ci, Vector2(mid - 8, by + 2), "-", 16, UI.DIM, "big", HORIZONTAL_ALIGNMENT_CENTER, 16)
		UI.text(ci, Vector2(mid + 8, by + 2), str(sc[1]), 16, UI.DIM if hw else YELLOW, "big", HORIZONTAL_ALIGNMENT_CENTER, 24)
		if not (gg.r.get("so", []) as Array).is_empty():
			UI.text(ci, Vector2(x + w - 26, by), "PENS", 8, UI.DIM, "caps")

## UP NEXT: slides up from the bottom (`k` 0..1) with CONTINUE under it; then the CR bar fills.
func _draw_next(ci: Control, sz: Vector2, k: float) -> void:
	if k <= 0.0:
		cont_rect = Rect2()
		return
	var w := minf(300.0, sz.x - 16.0)
	var h := 88.0 + _credits_h()
	var target := 2.0 + COMPACT_H + 6.0
	var y := roundf(lerpf(sz.y + 4.0, target, k))
	var x := roundf((sz.x - w) / 2.0)
	ci.draw_rect(Rect2(x, y, w, h), Color(NAVY, 0.9))
	ci.draw_rect(Rect2(x, y, w, h), UI.BORDER, false, 1.0)
	UI.text(ci, Vector2(x, y + 13), "UP NEXT", 8, YELLOW, "caps", HORIZONTAL_ALIGNMENT_CENTER, w)
	if next.is_empty():
		UI.text(ci, Vector2(x, y + 50), "SEASON COMPLETE", 16, UI.TEXT, "big", HORIZONTAL_ALIGNMENT_CENTER, w)
	elif next.get("tbd", false):
		UI.text(ci, Vector2(x, y + 26), String(next.round).to_upper(), 8, UI.DIM, "caps", HORIZONTAL_ALIGNMENT_CENTER, w)
		UI.text(ci, Vector2(x, y + 56), "OPPONENT TBD", 16, UI.TEXT, "big", HORIZONTAL_ALIGNMENT_CENTER, w)
	else:
		var nt: PoloTeam = c.teams[next.opp]
		UI.text(ci, Vector2(x, y + 25), String(next.round).to_upper(), 8, UI.DIM, "caps", HORIZONTAL_ALIGNMENT_CENTER, w)
		TeamLogo.draw_in(ci, Rect2(Vector2(x + 12, y + 30), Vector2(LOGO, LOGO)), nt)
		var tx := x + 12 + LOGO + 10
		# VS / AT and the opponent's short name, as big as fits
		var vs := ("VS " if next.home else "AT ") + Colleges.short_name(nt).to_upper()
		var vs_size := 24 if UI.text_width(vs, 24, "big") <= w - (tx - x) - 8 else 16
		UI.text(ci, Vector2(tx, y + 52), vs, vs_size, UI.TEXT, "big")
		UI.text(ci, Vector2(tx, y + 65), _fit(nt, w - (tx - x) - 8), 8, UI.TEXT, "caps")
		UI.text(ci, Vector2(tx, y + 76), "RECORD %s    CONF %s" % [c.record_text(nt.id), c.conf_record_text(nt.id)], 8, UI.DIM, "caps")
	ci.draw_rect(Rect2(x + 8, y + 86, w - 16, 1), Color(1, 1, 1, 0.2))
	_draw_credits(ci, x, y + 88, w)
	# CONTINUE: big and yellow, at the bottom, coming up with the panel
	var bw := minf(198.0, w)
	var by := roundf(lerpf(sz.y + 30.0, sz.y - 24.0, k))
	cont_rect = Rect2(roundf((sz.x - bw) / 2.0), by, bw, 22)
	ci.draw_rect(cont_rect, YELLOW)
	ci.draw_rect(Rect2(cont_rect.position + Vector2(0, cont_rect.size.y - 2), Vector2(bw, 2)), YELLOW.darkened(0.3))
	UI.text(ci, cont_rect.position + Vector2(0, 15), "CONTINUE  >", 8, NAVY, "caps", HORIZONTAL_ALIGNMENT_CENTER, bw)

const CREDIT_ROW := 18.0      # a reward's line: room for the coin beside its number

## CREDITS EARNED's height: the heading, a line a reward (two to a line), the TOTAL.
func _credits_h() -> float:
	var rows := maxi(1, ceili(credit_lines.size() / 2.0))
	return 14.0 + rows * CREDIT_ROW + 22.0

## CREDITS EARNED (this game's rewards, two to a line: "WIN  +3 (coin)"), then the TOTAL and the
## balance, counting up from before the game as the panel settles.
func _draw_credits(ci: Control, x: float, y: float, w: float) -> void:
	UI.text(ci, Vector2(x + 10, y + 11), "CREDITS EARNED", 8, YELLOW, "caps")
	CreditCoin.draw_amount(ci, x + w - 10, y + 7, str(cr_shown()), 8, UI.TEXT, "caps", 16, 2)
	var top := y + 14.0
	if credit_lines.is_empty():
		UI.text(ci, Vector2(x, top + 12), "NO CREDITS THIS GAME" if not won or Schedule.is_playoff(c.cur()) else "", 8, UI.DIM, "caps", HORIZONTAL_ALIGNMENT_CENTER, w)
	var col_w := (w - 20.0) / 2.0
	for i in credit_lines.size():
		var ln: Array = credit_lines[i]
		var cx := x + 10.0 + (i % 2) * col_w
		var cy := top + floorf(i / 2.0) * CREDIT_ROW + CREDIT_ROW * 0.5
		UI.text(ci, Vector2(cx, cy + 3), Deck.fit("%s:" % String(ln[0]), col_w - 44.0), 8, UI.TEXT, "caps")
		CreditCoin.draw_amount(ci, cx + col_w - 6.0, cy, CreditCoin.text(int(ln[1]), true), 8, YELLOW, "caps", 16, 2)
	var ty := top + maxi(1, ceili(credit_lines.size() / 2.0)) * CREDIT_ROW + 11.0
	CreditCoin.draw_amount(ci, x, ty, "TOTAL: %s" % CreditCoin.text(CreditRewards.total(credit_lines), true), 16, YELLOW, "big", 20, 1, w)

## A segmented pixel bar, `p` 0..1 full.
func _bar(ci: Control, r: Rect2, p: float) -> void:
	ci.draw_rect(r, UI.INK)
	var cells := 20
	var cw := floorf((r.size.x - 2.0) / cells)
	var lit := int(floorf(p * cells + 0.0001))
	for i in cells:
		var cr := Rect2(r.position.x + 1 + i * cw, r.position.y + 1, cw - 1, r.size.y - 2)
		ci.draw_rect(cr, YELLOW if i < lit else Color(1, 1, 1, 0.12))

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

## On to the POSTGAME REVIEW (then maybe a coaching event; the postgame ends the week).
func _continue() -> void:
	if done:
		return
	done = true
	Game.goto("postgame_review")
