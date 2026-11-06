class_name Hud
## Scoreboard, shot clock, banners and the in-match cards, drawn straight onto the canvas.

const PANEL_BG := Color("0b2057")   # the menus' dark navy
const LED := Color("ff5a5a")
# the match keeps its dark scoreboard look whatever the menus' palette is
const CARD := Color("18264a")
const LINE := Color("3b5a9a")
const DIM := Color("8b9bc2")
## The room for a team's name on the scoreboard, each side: never less than NAME_MIN (the board
## doesn't shrink for "ERIE"), never more than NAME_MAX (the shot clock on its left and the play
## calls on its right still fit).
const NAME_MIN := 30.0
const NAME_MAX := 89.0

static func cap_chip(ci: CanvasItem, pos: Vector2, cap: Color, trim: Color) -> void:
	ci.draw_rect(Rect2(pos.x, pos.y + 1, 7, 5), cap)
	ci.draw_rect(Rect2(pos.x + 1, pos.y, 5, 1), cap)
	ci.draw_rect(Rect2(pos.x + 2, pos.y + 3, 3, 2), trim)
	ci.draw_rect(Rect2(pos.x, pos.y, 7, 6), Color(0, 0, 0, 0.25), false, 1.0)

## Top-centre scoreboard: CAP STATEN ISLAND 3  Q2 3:12  2 BRONX CAP, each team by its short name
## (Colleges.short_name). Both names get the same room, so the clock stays in the middle. Returns
## the board.
## `fx` (GoalShow.board_fx): a goal going up on the board, {side, add, t (seconds since), col
## (the scorer's cap), big}: that side's number (the shootout's, in a shootout) shows `add`
## more than the state, drops in, swells and settles, over a flash of the team's colour.
static func scoreboard(ci: CanvasItem, w: float, st: MatchState, us: PoloTeam, them: PoloTeam,
		us_cap: Color, them_cap: Color, them_trim: Color = Color.TRANSPARENT, fx: Dictionary = {}) -> Rect2:
	var a := fit_name(us, NAME_MAX)
	var b := fit_name(them, NAME_MAX)
	var slot := maxf(NAME_MIN, maxf(float(a.w), float(b.w)))
	var bw := 126.0 + 2.0 * slot
	var x := roundf((w - bw) / 2.0)
	var r := Rect2(x, 2, bw, 21)
	ci.draw_rect(r, PANEL_BG)
	ci.draw_rect(r, UI.BORDER, false, 1.0)
	cap_chip(ci, Vector2(x + 5, 9), us_cap, us.c1)
	draw_name(ci, a, Vector2(x + 14, 15), HORIZONTAL_ALIGNMENT_CENTER, slot)
	var score := [int(st.score[0]), int(st.score[1])]
	var pens := [int(st.shootout[0]), int(st.shootout[1])]
	var fs := int(fx.get("side", -1))
	if fs >= 0:
		var up: Array = pens if st.in_shootout else score
		up[fs] += int(fx.get("add", 1))
	var mid := "Q%d  %s" % [st.quarter, st.clock_text()]
	var mid_col := UI.TEXT
	if st.in_shootout:
		mid = "PENS %d-%d" % [pens[0], pens[1]]
		if fs >= 0 and float(fx.t) < SCORE_FLASH * 1.5:
			mid_col = UI.GOLD
	for i in 2:
		var cx := x + (15.0 if i == 0 else 89.0) + slot
		if i == fs and not st.in_shootout:
			_score_pop(ci, cx, score[i], fx)
		else:
			UI.text(ci, Vector2(cx, 20), str(score[i]), 20, UI.GOLD, "big", HORIZONTAL_ALIGNMENT_CENTER, 22)
	UI.text(ci, Vector2(x + 37 + slot, 15), mid, 8, mid_col, "caps", HORIZONTAL_ALIGNMENT_CENTER, 52)
	draw_name(ci, b, Vector2(x + 112 + slot, 15), HORIZONTAL_ALIGNMENT_CENTER, slot)
	cap_chip(ci, Vector2(x + 114 + 2.0 * slot, 9), them_cap, them.c2 if them_trim.a == 0.0 else them_trim)
	return r

const SCORE_FLASH := 0.3       # s the scoring side's number flashes its team colour
const SCORE_POP := 0.4         # s it swells and settles

## The number that just went up (in the 22 px slot from `x`): it drops in, swells (more for a
## `big` goal: a tie, a winner), and flashes the team's colour behind it, in a dark outline.
static func _score_pop(ci: CanvasItem, x: float, n: int, fx: Dictionary) -> void:
	var u := float(fx.get("t", 1.0))
	var drop := clampf(u / 0.06, 0.0, 1.0)
	var swell := drop * (1.0 - smoothstep(0.06, SCORE_POP, u))
	var s := int(roundf(20.0 * (1.0 + (0.65 if bool(fx.get("big", false)) else 0.45) * swell)))
	var col: Color = fx.get("col", UI.GOLD)
	if u < SCORE_FLASH:
		var on := int(u / 0.075) % 2 == 0
		ci.draw_rect(Rect2(x - 1, 3, 24, 19), Color(col, 0.95) if on else Color(UI.GOLD, 0.35))
	if u < SCORE_POP + 0.1:
		ci.draw_rect(Rect2(x - 1, 3, 24, 19), UI.GOLD, false, 1.0)
	var base := roundf(20.0 + (s - 20) * 0.28 - 6.0 * (1.0 - drop))
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		UI.text(ci, Vector2(x, base) + d, str(n), s, PANEL_BG, "big", HORIZONTAL_ALIGNMENT_CENTER, 22)
	UI.text(ci, Vector2(x, base), str(n), s, UI.GOLD, "big", HORIZONTAL_ALIGNMENT_CENTER, 22)

## How a team's short name (Colleges.short_name) fits in `max_w` px: {lines, size, font, w}. The
## first of `styles` ([size, font]) it fits on one line, else two lines in the last one, the
## place over the mascot ("LOS ANGELES" / "MOUNTAIN LIONS"); cut short only if none of that fits.
static func fit_name(t: PoloTeam, max_w: float, styles: Array = [[8, "caps"], [8, "body"]]) -> Dictionary:
	var n := Colleges.short_name(t).to_upper()
	for st in styles:
		if UI.text_width(n, st[0], st[1]) <= max_w:
			return {"lines": [n], "size": st[0], "font": st[1], "w": UI.text_width(n, st[0], st[1])}
	var last: Array = styles[-1]
	var top := n.trim_suffix(" " + t.mascot.to_upper())
	var two := [top, t.mascot.to_upper()]
	if top != n and two.all(func(l): return UI.text_width(l, last[0], last[1]) <= max_w):
		return {"lines": two, "size": last[0], "font": last[1], "w": two.map(func(l): return UI.text_width(l, last[0], last[1])).max()}
	return {"lines": [Deck.fit(n, max_w, last[0], last[1])], "size": last[0], "font": last[1], "w": max_w}

## Draws a fit_name: one line on `pos` (its baseline), or two either side of it.
static func draw_name(ci: CanvasItem, d: Dictionary, pos: Vector2, align: int, w: float, col: Color = UI.TEXT) -> void:
	var lines: Array = d.lines
	var ys := [0.0] if lines.size() == 1 else [-4.0, 4.0]
	for i in lines.size():
		UI.text(ci, pos + Vector2(0, ys[i]), String(lines[i]), int(d.size), col, String(d.font), align, w)

## The shot clock: SC and the seconds in LED red. The last five beat like a heart: each new
## second (5, 4, 3, 2, 1) one solid red digit with a black edge, centred on the box, pops in at
## SC_PULSE x the normal digits, eases down to their size over SC_SHRINK s and holds there till
## the next one (0, as it runs out, sits at rest). All read straight off `secs` (the play's
## clock): no timer of its own, so it stops whenever the play does and is gone on a reset.
const SC_FINAL := 5
const SC_RED := Color("ff2020")
const SC_INK := Color("0a0a12")
const SC_FS := 20              # the normal digits' size: the countdown's resting size
const SC_PULSE := 1.5          # ...and how much bigger each new second starts
const SC_SHRINK := 0.25        # s to ease back down
## Each digit's inked width per px of font size ("big" starts every digit's ink at the pen and
## ends it short of the advance by a varying gap, so the advance won't centre it), and its ink
## height (0.525): measured off the font.
const SC_INK_W := [1.0 / 3.0, 1.0 / 6.0, 0.38, 0.38, 1.0 / 3.0, 1.0 / 3.0]

static func shot_clock(ci: CanvasItem, pos: Vector2, secs: float) -> void:
	var r := Rect2(pos, Vector2(30, 21))
	ci.draw_rect(r, PANEL_BG)
	ci.draw_rect(r, UI.BORDER, false, 1.0)
	var s := maxi(0, int(ceilf(secs)))
	if s > SC_FINAL:
		UI.text(ci, pos + Vector2(3, 8), "SC", 8, UI.TEXT, "body")
		UI.text(ci, pos + Vector2(11, 19), "%02d" % s, SC_FS, LED, "big")
		return
	var u := clampf((float(s) - secs) / SC_SHRINK, 0.0, 1.0) if s > 0 else 1.0
	var fs := int(roundf(SC_FS * lerpf(SC_PULSE, 1.0, 1.0 - pow(1.0 - u, 3.0))))
	var d := str(s)
	var c := r.get_center()
	var ink := Vector2(roundf(fs * float(SC_INK_W[s])), roundf(fs * 0.525))
	var at := Vector2(roundf(c.x - ink.x / 2.0), roundf(c.y + (ink.y + 1.0) / 2.0))
	for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1),
			Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		UI.text(ci, at + o, d, fs, SC_INK, "big")
	UI.text(ci, at, d, fs, SC_RED, "big")

## The power play's countdown. `down`: it's your team that's a man short.
static func man_up(ci: CanvasItem, w: float, secs: float, down: bool = false) -> void:
	var t := "%s   %d" % ["5 ON 6" if down else "6 ON 5", int(ceilf(secs))]
	var tw := UI.text_width(t, 8, "caps") + 10
	var r := Rect2(roundf((w - tw) / 2.0), 25, tw, 11)
	ci.draw_rect(r, Color(UI.GOLD, 0.92))
	UI.text(ci, r.position + Vector2(5, 8), t, 8, Color("1a1206"), "caps")

## Under the shot clock on your attack: the formation their defence is in (DefenseFormation),
## right-aligned to `right_top`.
static func formation_tag(ci: CanvasItem, right_top: Vector2, text: String) -> void:
	var tw := UI.text_width(text, 8, "caps") + 8
	var r := Rect2(roundf(right_top.x - tw), right_top.y, tw, 11)
	ci.draw_rect(r, Color(CARD, 0.85))
	ci.draw_rect(r, LINE, false, 1.0)
	UI.text(ci, r.position + Vector2(0, 8), text, 8, DIM, "caps", HORIZONTAL_ALIGNMENT_CENTER, tw)

static func pause_button(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, UI.PANEL)
	ci.draw_rect(r, UI.BORDER, false, 1.0)
	ci.draw_rect(Rect2(r.position + Vector2(6, 5), Vector2(2, r.size.y - 10)), UI.TEXT)
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 8, 5), Vector2(2, r.size.y - 10)), UI.TEXT)

## Big centred word with a dark outline, popping in with `pop` 0..1; `alpha` fades it out.
static func banner(ci: CanvasItem, size: Vector2, text: String, col: Color, pop: float, sub: String = "",
		alpha: float = 1.0) -> void:
	var s := int(lerpf(56.0, 40.0, clampf(pop * 4.0, 0.0, 1.0)))
	var y := size.y * 0.45
	for d in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 3), Vector2(2, 3), Vector2(-2, 3)]:
		UI.text(ci, Vector2(0, y) + d, text, s, Color(Color("0a1226"), alpha), "big", HORIZONTAL_ALIGNMENT_CENTER, size.x)
	UI.text(ci, Vector2(0, y), text, s, Color(col, col.a * alpha), "big", HORIZONTAL_ALIGNMENT_CENTER, size.x)
	if sub != "":
		UI.text_shadow(ci, Vector2(0, y + 14), sub, 8, Color(UI.TEXT, alpha), "caps", HORIZONTAL_ALIGNMENT_CENTER, size.x)

## Every gameplay callout (see EventBanner), in BAR-DOWN!'s style and on its clocks (BarHit):
## the word bursts in small, overshoots, snaps back and gives one shake (BarHit.pop, shake_x),
## holds, then shrinks away as it fades over the last BarHit.OUT seconds. Lettering is BarHit's
## (black edge, two drop layers in the event's shades), no strip behind it, centred just under
## the scoreboard and the man-up pill, its overshoot clear of both. `t`: seconds on screen;
## `left`: seconds until it's gone.
const CALLOUT_TOP := 39.0      # px: under the scoreboard and the man-up pill
const CALLOUT_Y := 58.0        # px: the word's centre (its 1.3x overshoot clears CALLOUT_TOP)
const CALLOUT_BOTTOM := 74.0   # px: under the settled word's drop layers (dive_note, the drill's segue line)
const CALLOUT_BG := Color(0, 0, 0, 0.88)
## The drop layers under each callout colour [mid, deep]; YELLOW's are BAR-DOWN!'s own.
const CALLOUT_SHADES := {
	"ffd83d": [BarHit.ORANGE, BarHit.RED],              # EventBanner.YELLOW
	"45dfff": [Color("2a7fe0"), Color("1a2f8a")],       # CYAN
	"ff4545": [Color("b0182a"), Color("4a0812")],       # RED
	"ffffff": [Color("8a9ab8"), Color("34405e")],       # WHITE
}

static func callout(ci: CanvasItem, size: Vector2, text: String, col: Color, t: float, left: float = INF) -> void:
	if text == "" or t < 0.0 or left <= 0.0:
		return
	var out := 1.0 - clampf(left / BarHit.OUT, 0.0, 1.0)   # 0 until the exit, 1 when gone
	var sc := BarHit.pop(t) if t < BarHit.OUT_AT else 1.0
	sc *= lerpf(1.0, 0.3, out)
	var a := col.a * (1.0 - out)
	var fs := BarHit.word_fs(text, sc, size.x - 24.0)
	var c := Vector2(roundf(size.x * 0.5 + BarHit.shake_x(t)), CALLOUT_Y)
	var sh: Array = CALLOUT_SHADES.get(col.to_html(false), [col.darkened(0.35), col.darkened(0.7)])
	BarHit.lettering(ci, c, text, fs, a, Color(col, 1.0), sh[0], sh[1])

## A centred card: title, lines revealed one by one, optional footer.
static func card(ci: CanvasItem, size: Vector2, title: String, title_col: Color, lines: Array,
		shown: int, footer: String = "", w: float = 300.0) -> Rect2:
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.1, 0.55))
	var h := 44.0 + lines.size() * 13.0 + (14.0 if footer != "" else 0.0)
	var r := Rect2(roundf((size.x - w) / 2.0), roundf((size.y - h) / 2.0), w, h)
	ci.draw_rect(r, CARD)
	ci.draw_rect(r, UI.GOLD, false, 1.0)
	UI.text(ci, r.position + Vector2(0, 22), title, 20, title_col, "big", HORIZONTAL_ALIGNMENT_CENTER, w)
	for i in mini(shown, lines.size()):
		var ln = lines[i]
		var txt: String = ln if ln is String else String(ln[0])
		var col: Color = UI.TEXT if ln is String else ln[1]
		UI.text(ci, r.position + Vector2(0, 42 + i * 13), txt, 8, col, "caps", HORIZONTAL_ALIGNMENT_CENTER, w)
	if footer != "":
		UI.text(ci, r.position + Vector2(0, h - 6), footer, 8, DIM, "body", HORIZONTAL_ALIGNMENT_CENTER, w)
	return r

## Bottom-left: who has the ball. #1 FARRELL  GK, his stars, his personal fouls ("1 EX": this
## game's, MatchState.pf; -1 hides it), his trait. The stars are his roster card's
## (Deck.star_bar: gold CURRENT, his HOT stars red), no number and no POTENTIAL.
static func holder_tag(ci: CanvasItem, pos: Vector2, p: PoloPlayer, ex: int = -1) -> void:
	var tg := tag_parts(p, ex)
	ci.draw_rect(Rect2(pos, tg.size), Color(0.02, 0.04, 0.1, 0.75))
	UI.text(ci, pos + Vector2(4, 9), tg.text, 8, UI.TEXT, "caps")
	Deck.star_bar(ci, pos.x + tg.stars_x, pos.y + 2, tg.stars, tg.stars, tg.red)
	if tg.ex != "":
		UI.text(ci, pos + Vector2(tg.ex_x, 9), tg.ex, 8, ex_color(ex), "caps")
	if tg.trait != "":
		UI.text(ci, pos + Vector2(tg.trait_x, 9), tg.trait, 8, UI.GOLD, "caps")

## A personal-foul count's colour: 0-1 plain, 2 (FOUL TROUBLE) yellow, 3 (ROLLED) red.
const EX_WARN := Color("ffd83d")
const EX_OUT := Color("ff4545")
static func ex_color(n: int) -> Color:
	return EX_OUT if n >= MatchState.ROLL_AT else (EX_WARN if n == MatchState.ROLL_AT - 1 else Color("e6ecff"))

## What the tag shows and where (px from its left): {text, stars (CURRENT, in halves), red (his
## form's red stars, PlayerForm.red_stars), ex ("2 EX", or ""), trait, stars_x, ex_x, trait_x, size}.
static func tag_parts(p: PoloPlayer, ex: int = -1) -> Dictionary:
	var t := "%s  %s" % [p.tag(), p.pos_text()]
	var tw := UI.text_width(t, 8, "caps")
	var tr := Traits.title(p.trait_id)
	var trw := UI.text_width(tr, 8, "caps") + 6 if tr != "" else 0.0
	var sw := Deck.star_bar_w_for(p.stars, p.stars, PlayerForm.red_stars(p.form_state()))
	var ex_t := "%d EX" % ex if ex >= 0 else ""
	var exw := UI.text_width(ex_t, 8, "caps") + 6 if ex_t != "" else 0.0
	return {"text": t, "stars": PlayerForm.snap_half(p.stars), "red": PlayerForm.red_stars(p.form_state()), "trait": tr, "ex": ex_t,
		"stars_x": tw + 10.0, "ex_x": tw + sw + 16.0, "trait_x": tw + sw + 16.0 + exw, "size": Vector2(tw + sw + 16.0 + exw + trw, 12.0)}

## The roll-out notice, for ROLL_NOTE_TIME under the callouts: PLAYER ROLLED! (yours: who, 3
## PERSONAL FOULS, OUT FOR THE REST OF THE GAME, his replacement) or OPPONENT ROLLED! (shorter).
const ROLL_NOTE_TIME := 3.0
static func roll_note(ci: CanvasItem, size: Vector2, note: Dictionary, age: float) -> void:
	if note.is_empty() or age < 0.0 or age > ROLL_NOTE_TIME:
		return
	var a := clampf((ROLL_NOTE_TIME - age) / 0.3, 0.0, 1.0)
	var lines: Array = note.lines
	var w := 196.0
	var h := 14.0 + lines.size() * 10.0
	var r := Rect2(roundf((size.x - w) / 2.0), CALLOUT_BOTTOM + 2.0, w, h)
	ci.draw_rect(r, Color(0.02, 0.04, 0.1, 0.85 * a))
	ci.draw_rect(r, Color(EX_OUT, a), false, 1.0)
	UI.text(ci, r.position + Vector2(0, 10), String(note.title), 8, Color(EX_OUT, a), "caps", HORIZONTAL_ALIGNMENT_CENTER, w)
	for i in lines.size():
		UI.text(ci, r.position + Vector2(0, 20 + i * 10), String(lines[i]), 8, Color(UI.TEXT, a), "caps", HORIZONTAL_ALIGNMENT_CENTER, w)

## Under the GOAL callout, for a moment: why your dive didn't stop it (TOO EARLY / TOO LATE).
const DIVE_NOTE_TIME := 1.4

static func dive_note(ci: CanvasItem, size: Vector2, text: String, age: float, y: float = -1.0) -> void:
	if text == "" or age < 0.0 or age > DIVE_NOTE_TIME:
		return
	var a := clampf((DIVE_NOTE_TIME - age) / 0.25, 0.0, 1.0)
	if y < 0.0:
		y = CALLOUT_BOTTOM
	var w := UI.text_width(text, 8, "caps") + 12.0
	ci.draw_rect(Rect2(roundf((size.x - w) / 2.0), y, w, 12), Color(CALLOUT_BG, CALLOUT_BG.a * a))
	UI.text(ci, Vector2(0, y + 9), text, 8, Color(UI.GOLD, a), "caps", HORIZONTAL_ALIGNMENT_CENTER, size.x)

## A small centred label under the scoreboard (the venue).
static func pill(ci: CanvasItem, size: Vector2, text: String, col: Color) -> void:
	var tw := UI.text_width(text, 8, "caps") + 12
	var r := Rect2(roundf((size.x - tw) / 2.0), 30, tw, 12)
	ci.draw_rect(r, Color(0.02, 0.04, 0.1, 0.8))
	ci.draw_rect(r, col, false, 1.0)
	UI.text(ci, r.position + Vector2(0, 9), text, 8, col, "caps", HORIZONTAL_ALIGNMENT_CENTER, tw)

## The quarter-break card, after the 1st, 2nd and 3rd quarters (full time goes straight to the
## results): END OF 2ND QUARTER, the score big, the team codes beside it, and `footer`.
const ORDINALS := ["1ST", "2ND", "3RD", "4TH"]

static func break_card(ci: CanvasItem, size: Vector2, quarter: int, score: Array, us: PoloTeam,
		them: PoloTeam, footer: String = "TAP TO CONTINUE") -> Rect2:
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.1, 0.55))
	var title := "END OF %s QUARTER" % ORDINALS[clampi(quarter - 1, 0, 3)]
	# the score row, centred as a whole: BRONX  1 - 1  ERIE; long names in the small caps
	var us_n := Colleges.short_name(us).to_upper()
	var them_n := Colleges.short_name(them).to_upper()
	var gaps := [12.0, 8.0, 8.0, 12.0]
	var row := 0.0
	var parts: Array = []
	for name_size in [16, 8]:
		parts = [[us_n, name_size, "caps", UI.TEXT], [str(score[0]), 40, "big", UI.GOLD], ["-", 40, "big", UI.GOLD],
			[str(score[1]), 40, "big", UI.GOLD], [them_n, name_size, "caps", UI.TEXT]]
		row = 0.0
		for i in parts.size():
			row += UI.text_width(String(parts[i][0]), int(parts[i][1]), String(parts[i][2])) + (gaps[i] if i < gaps.size() else 0.0)
		if row + 24.0 <= size.x - 32.0:
			break
	var w := maxf(maxf(196.0, UI.text_width(title, 16, "big") + 36.0), row + 24.0)
	var h := 92.0
	var r := Rect2(roundf((size.x - w) / 2.0), roundf((size.y - h) / 2.0), w, h)
	ci.draw_rect(r, CARD)
	ci.draw_rect(r, UI.GOLD, false, 1.0)
	UI.text(ci, r.position + Vector2(0, 21), title, 16, UI.TEXT, "big", HORIZONTAL_ALIGNMENT_CENTER, w)
	var x := roundf(r.position.x + (w - row) / 2.0)
	var base := r.position.y + 62.0
	for i in parts.size():
		var pt: Array = parts[i]
		var y := base if int(pt[1]) == 40 else base - 6.0
		UI.text(ci, Vector2(x, y), String(pt[0]), int(pt[1]), pt[3], String(pt[2]))
		x += UI.text_width(String(pt[0]), int(pt[1]), String(pt[2])) + (gaps[i] if i < gaps.size() else 0.0)
	UI.text(ci, r.position + Vector2(0, h - 9), footer, 8, DIM, "body", HORIZONTAL_ALIGNMENT_CENTER, w)
	return r
