class_name ResultsPanel
extends RefCounted
## The full-time panel over the darkened pool: FINAL, both clubs (logo, name), the score and
## the season records as they stand after this game. DETAILS rolls the box score out underneath
## (shots, goals, assists, steals, blocks, exclusions drawn); HIDE DETAILS rolls it back. Drawn straight onto the
## match canvas like the rest of the HUD; draw() hands back the buttons it drew so the screen
## can hit-test taps: [[Rect2, label, Callable]].

const NAVY := Color("071b3f")
const BTN_NAVY := Color("0b2057")
const RED := Color("ff4545")
const CYAN := Color("45dfff")
const YELLOW := Color("ffd83d")
const W := 300.0
const BASE_H := 152.0          # collapsed: FINAL, clubs, scores, records, buttons
const STATS_H := 87.0          # what DETAILS adds
const STATS_AT := 128.0        # where the details (then the buttons) start, from the top
const BTN_H := 18.0
const EXPAND_TIME := 0.2
const ROW_GAP := 0.07          # one row after another, top to bottom
const ROW_TIME := 0.12
const ROW_H := 13.0
const SCORE_AT := 0.35         # the clubs show first, the scores pop in after this long
const ROWS := ["SHOTS", "GOALS", "ASSISTS", "STEALS", "BLOCKS", "EXCLUSIONS DRAWN"]

var t := 0.0                   # seconds since the final whistle
var open := false
var k := 0.0                   # 0 collapsed .. 1 expanded
var open_t := 0.0              # seconds since DETAILS was pressed
var stats: Array = []          # per row: [yours, theirs]
var records := {}              # {"us": "6-7 (2-4)", "them": "9-4 (5-1)"}, or {} (no season)

## `rec`: the records to show (Career.records_after), {} for none.
func setup(st: MatchState, rec: Dictionary) -> ResultsPanel:
	records = rec
	stats = [
		[st.shots[0], st.shots[1]],
		[st.score[0], st.score[1]],
		[(st.assist_by[0] as Array).size(), (st.assist_by[1] as Array).size()],
		[st.steals[0], st.steals[1]],
		[st.blocks[0], st.blocks[1]],
		[st.exclusions[0], st.exclusions[1]],
	]
	return self

## DETAILS / HIDE DETAILS. Pressing it again mid-roll just turns the roll round.
func toggle() -> void:
	open = not open
	if open:
		open_t = 0.0

## The buttons take taps once the scores are up (a tap left over from the last play can't
## skip the result).
func ready() -> bool:
	return t >= SCORE_AT

func step(dt: float) -> void:
	t += dt
	open_t += dt
	k = move_toward(k, 1.0 if open else 0.0, dt / EXPAND_TIME)

## The panel's rectangle right now (it grows down as it opens, staying clear of the scoreboard).
func rect(size: Vector2) -> Rect2:
	var area_top := 26.0
	var area_h := size.y - area_top - 4.0
	var top_c := area_top + maxf(0.0, (area_h - BASE_H) / 2.0)
	var top_e := area_top + maxf(0.0, (area_h - BASE_H - STATS_H) / 2.0)
	var h := roundf(BASE_H + STATS_H * k)
	return Rect2(roundf((size.x - W) / 2.0), roundf(lerpf(top_c, top_e, k)), W, h)

## `actions`: the buttons after DETAILS, last one primary: [[label, Callable]].
func draw(ci: CanvasItem, size: Vector2, st: MatchState, us: PoloTeam, them: PoloTeam, actions: Array) -> Array:
	var r := rect(size)
	ci.draw_rect(r, NAVY)
	ci.draw_rect(r, UI.BORDER, false, 1.0)
	var x0 := r.position.x
	var y0 := r.position.y
	UI.text(ci, Vector2(x0, y0 + 25), "FINAL", 24, RED, "big", HORIZONTAL_ALIGNMENT_CENTER, W)
	# the clubs, side by side with a line between
	ci.draw_rect(Rect2(x0 + W / 2.0, y0 + 34, 1, 88), Color(1, 1, 1, 0.3))
	var win := st.winner()
	for side in 2:
		var team: PoloTeam = us if side == 0 else them
		var cx := x0 + (W * 0.25 if side == 0 else W * 0.75)
		TeamLogo.paint(ci, Vector2(cx - 20, y0 + 30), team, TeamLogo.LARGE)
		UI.text(ci, Vector2(cx - W / 4.0, y0 + 81), _fit(team, W / 2.0 - 4), 8, UI.TEXT, "caps", HORIZONTAL_ALIGNMENT_CENTER, W / 2.0)
		if t < SCORE_AT:
			continue
		var pop := clampf((t - SCORE_AT) / 0.1, 0.0, 1.0)
		var score := Schedule.side_text(st.score, st.shootout if st.in_shootout else [], side)
		UI.text(ci, Vector2(cx - W / 4.0, y0 + 109), score, int(lerpf(36.0, 28.0, pop)),
			YELLOW if win == side else UI.TEXT, "big", HORIZONTAL_ALIGNMENT_CENTER, W / 2.0)
		if not records.is_empty():
			UI.text(ci, Vector2(cx - W / 4.0, y0 + 121), String(records["us" if side == 0 else "them"]), 8,
				UI.TEXT, "caps", HORIZONTAL_ALIGNMENT_CENTER, W / 2.0)
	_draw_stats(ci, x0 + 8, y0 + STATS_AT, W - 16)
	return _draw_buttons(ci, x0, y0 + STATS_AT + STATS_H * k, actions)

## The box score: yours | what | theirs, a thin line between rows. The panel grows to show it;
## each row slides down into place a beat after the one above, only once there's room for it.
func _draw_stats(ci: CanvasItem, x: float, y: float, w: float) -> void:
	if k <= 0.0:
		return
	var shown := STATS_H * k
	var line := Color(1, 1, 1, 0.15)
	ci.draw_rect(Rect2(x, y, w, 1), line)
	if not open:
		return   # rolling back up: the rows go first
	for i in ROWS.size():
		var p := clampf((open_t - 0.06 - ROW_GAP * i) / ROW_TIME, 0.0, 1.0)
		var slot := y + 4.0 + i * ROW_H
		if p <= 0.0 or slot + ROW_H > y + shown:
			continue
		var ry := roundf(slot - (1.0 - p) * 6.0)
		var a := p
		UI.text(ci, Vector2(x, ry + 11), str(stats[i][0]), 16, Color(UI.TEXT, a), "big", HORIZONTAL_ALIGNMENT_CENTER, 70)
		UI.text(ci, Vector2(x, ry + 10), ROWS[i], 8, Color(CYAN, a), "caps", HORIZONTAL_ALIGNMENT_CENTER, w)
		UI.text(ci, Vector2(x + w - 70, ry + 11), str(stats[i][1]), 16, Color(YELLOW, a), "big", HORIZONTAL_ALIGNMENT_CENTER, 70)
		ci.draw_rect(Rect2(x, slot + ROW_H, w, 1), Color(line, line.a * a))

## DETAILS (navy, white border, an arrow) and the actions, the last one the yellow CONTINUE.
func _draw_buttons(ci: CanvasItem, x0: float, y: float, actions: Array) -> Array:
	var n := actions.size() + 1
	var gap := 6.0
	var bw := floorf((W - 16 - gap * (n - 1)) / n)
	var out: Array = []
	var bx := x0 + 8
	var labels: Array = [["HIDE DETAILS" if open else "DETAILS", toggle]]
	labels.append_array(actions)
	for i in n:
		var b := Rect2(bx, roundf(y), bw, BTN_H)
		var primary := i == n - 1
		var label: String = labels[i][0]
		# the game's raised button face (cut corners, the bevel): the same look as every menu button
		Deck.frame(ci, b, YELLOW if primary else BTN_NAVY, UI.BORDER if not primary else UI.INK, false, UI.BEVEL_RAISED)
		var col := NAVY if primary else UI.TEXT
		var tw := UI.text_width(label, 8, "caps")
		var tx := roundf(b.position.x + (bw - tw - (8.0 if i == 0 else 0.0)) / 2.0)
		UI.text(ci, Vector2(tx, b.position.y + 12), label, 8, col, "caps")
		if i == 0:
			_arrow(ci, Vector2(tx + tw + 4, b.position.y + 7), open, col)
		out.append([b, label, labels[i][1]])
		bx += bw + gap
	return out

## A little pixel arrow: down to open, up to close.
static func _arrow(ci: CanvasItem, p: Vector2, up: bool, col: Color) -> void:
	for row in 3:
		var w := 5 - row * 2
		var yy := p.y + (2 - row if up else row)
		ci.draw_rect(Rect2(p.x + row, yy, w, 1), col)

## The club's name, shortened to fit `w` px if it has to.
static func _fit(team: PoloTeam, w: float) -> String:
	var n := team.name.to_upper()
	if UI.text_width(n, 8, "caps") <= w:
		return n
	n = n.replace(" UNIVERSITY", " U.").replace(" COLLEGE", " C.")
	if UI.text_width(n, 8, "caps") <= w:
		return n
	return Deck.fit(Colleges.short_name(team).to_upper(), w)
