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

## Top-centre scoreboard, in the tier worn (Scoreboard.tier, or `tier` if given: the Scoreboard
## upgrade's four looks). Returns the board (every pixel it covers).
## `fx` (GoalShow.board_fx): a goal going up on the board, {side, add, t (seconds since), col
## (the scorer's cap), big}: that side's number (the shootout's, in a shootout) shows `add`
## more than the state and goes up in the tier's own way.
static func scoreboard(ci: CanvasItem, w: float, st: MatchState, us: PoloTeam, them: PoloTeam,
		us_cap: Color, them_cap: Color, them_trim: Color = Color.TRANSPARENT, fx: Dictionary = {}, tier: int = -1) -> Rect2:
	return Scoreboard.draw(ci, Scoreboard.tier() if tier < 1 else tier, w, st, us, them, us_cap, them_cap, them_trim, fx)

## Level 1, CLASSIC: LOGO CULA 3  Q2 3:12  2 BRO LOGO, each team by its list-mark logo
## (TeamLogo, the 20 x 12 box, 1:1 on the pixel grid) and its abbreviation (Scoreboard.abbr).
## Both get the same room, so the clock stays in the middle; the number that goes up drops in,
## swells and settles, over a flash of the team's colour. The caps passed in are unused (no
## tier shows a cap chip any more).
const C_LOGO := Vector2(20, 12)    # Classic's logo box (TeamLogo.SMALL)
const C_PAD := 3.0                 # board edge to logo, and logo to the name slot
static func classic_board(ci: CanvasItem, w: float, st: MatchState, us: PoloTeam, them: PoloTeam,
		_us_cap: Color, _them_cap: Color, _them_trim: Color = Color.TRANSPARENT, fx: Dictionary = {}) -> Rect2:
	var a := Scoreboard.abbr_label(us)
	var b := Scoreboard.abbr_label(them)
	var slot := maxf(NAME_MIN, maxf(float(a.w), float(b.w)))
	var o := 2.0 * C_PAD + C_LOGO.x - 14.0     # how much further right everything sits than with the old 7 px cap
	var bw := 126.0 + 2.0 * o + 2.0 * slot
	var x := roundf((w - bw) / 2.0)
	var r := Rect2(x, 2, bw, 21)
	ci.draw_rect(r, PANEL_BG)
	ci.draw_rect(r, UI.BORDER, false, 1.0)
	var ly := roundf(r.get_center().y - C_LOGO.y / 2.0)
	TeamLogo.draw_in(ci, Rect2(x + C_PAD, ly, C_LOGO.x, C_LOGO.y), us)
	x += o
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
	TeamLogo.draw_in(ci, Rect2(r.end.x - C_PAD - C_LOGO.x, ly, C_LOGO.x, C_LOGO.y), them)
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
	sc_digits(ci, r, secs, "SC", pos + Vector2(3, 8), pos + Vector2(11, 19))

## The shot clock's seconds in box `r` (any tier's): above the final five, `label` (if any) at
## `label_at` and the two LED digits at `digits_at` (their baseline); in them, the heartbeat
## digit centred on `r`.
static func sc_digits(ci: CanvasItem, r: Rect2, secs: float, label: String, label_at: Vector2, digits_at: Vector2) -> void:
	var s := maxi(0, int(ceilf(secs)))
	if s > SC_FINAL:
		if label != "":
			UI.text(ci, label_at, label, 8, UI.TEXT, "body")
		UI.text(ci, digits_at, "%02d" % s, SC_FS, LED, "big")
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
## `y`: its top (Scoreboard.below the board).
## A two-part pill in the scoreboard's family: the call on a solid accent tab (gold for your 6 on
## 5, red when you're the one short), the seconds in that accent on navy, and a one-pixel bar
## along the bottom draining with the time. The last few seconds blink.
const MU_INK := Color("1a1206")
const MU_RED := Color("ff4545")
const MU_SHADE := Color("040a1f")
const MU_H := 12.0
static func man_up(ci: CanvasItem, w: float, secs: float, down: bool = false, y: float = 25.0) -> void:
	var label := "5 ON 6" if down else "6 ON 5"
	var accent: Color = MU_RED if down else UI.GOLD
	var lw := UI.text_width(label, 8, "caps") + 10.0
	var nw := UI.text_width("20", 8, "caps") + 10.0   # fixed: the pill doesn't jitter as it counts
	var tw := lw + nw
	var r := Rect2(roundf((w - tw) / 2.0), y, tw, MU_H)
	# dark rim, navy body, the accent tab on the left with a lit top edge
	ci.draw_rect(r.grow(1.0), MU_SHADE)
	ci.draw_rect(r, PANEL_BG)
	var tab := Rect2(r.position, Vector2(lw, MU_H))
	ci.draw_rect(tab, accent)
	ci.draw_rect(Rect2(tab.position + Vector2(1, 1), Vector2(lw - 2, 1)), accent.lightened(0.45))
	ci.draw_rect(Rect2(tab.end.x - 1, r.position.y, 1, MU_H), accent.darkened(0.45))
	ci.draw_rect(r, accent, false, 1.0)
	UI.text(ci, tab.position + Vector2(0, 9), label, 8, MU_INK if not down else UI.TEXT, "caps",
		HORIZONTAL_ALIGNMENT_CENTER, lw)
	# the seconds: blink white over the last five
	var s := maxi(0, int(ceilf(secs)))
	var num_col := accent
	if s <= 5 and int(secs * 4.0) % 2 == 0:
		num_col = UI.TEXT
	UI.text(ci, Vector2(tab.end.x, r.position.y + 9), str(s), 8, num_col, "caps", HORIZONTAL_ALIGNMENT_CENTER, nw)
	# the time left: the seconds' half's bottom edge drains from right to left
	var frac := clampf(secs / Play.MAN_UP_TIME, 0.0, 1.0)
	var bar := Rect2(tab.end.x, r.end.y - 2, nw - 1, 2)
	ci.draw_rect(bar, MU_SHADE)
	ci.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * frac), 2)), accent)

## Under the shot clock on your attack: the formation their defence is in (DefenseFormation),
## right-aligned to `right_top`. The shot clock's own box style (navy, the board's border), the
## name in the board's text colour.
static func formation_tag(ci: CanvasItem, right_top: Vector2, text: String) -> void:
	var tw := UI.text_width(text, 8, "caps") + 10.0
	var r := Rect2(roundf(right_top.x - tw), right_top.y, tw, 12)
	ci.draw_rect(r.grow(1.0), MU_SHADE)
	ci.draw_rect(r, PANEL_BG)
	ci.draw_rect(r, UI.BORDER, false, 1.0)
	ci.draw_rect(Rect2(r.position + Vector2(1, r.size.y - 2), Vector2(r.size.x - 2, 1)), Color(LINE, 0.8))
	UI.text(ci, r.position + Vector2(0, 9), text, 8, UI.TEXT, "caps", HORIZONTAL_ALIGNMENT_CENTER, tw)

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

## Bottom-left: who has the ball, either side's (the screen passes Play.holder's player).
## #1 FARRELL, his stars, GK (no trait). The stars are his roster card's (Deck.star_bar: gold
## CURRENT, his HOT stars red), no number and no POTENTIAL. (No personal-foul count: that lives
## in the box score and the roll-out notices, MatchState.pf.) A DEV recruit's (DevRecruits.is_dev,
## never his name) stars are DEV_STAR light blue instead of gold, here only; his HOT red stays red.
const DEV_STAR := Color("66d9ff")
static func holder_tag(ci: CanvasItem, pos: Vector2, p: PoloPlayer) -> void:
	var tg := tag_parts(p)
	ci.draw_rect(Rect2(pos, tg.size), Color(0.02, 0.04, 0.1, 0.75))
	UI.text(ci, pos + Vector2(4, 9), tg.text, 8, UI.TEXT, "caps")
	Deck.star_bar(ci, pos.x + tg.stars_x, pos.y + 2, tg.stars, tg.stars, tg.red, Color(1, 1, 1, 0.14), Deck.STAR_SHAPE,
		DEV_STAR if DevRecruits.is_dev(p) else PlayerForm.GOLD)
	UI.text(ci, pos + Vector2(tg.pos_x, 9), tg.pos, 8, UI.TEXT, "caps")

const EX_OUT := Color("ff4545")   # (the roll-out notice's red)

## What the tag shows and where (px from its left): #4 MOSLEY, his stars, ATK. {text (number and
## name), stars (CURRENT, in halves), red (his form's red stars, PlayerForm.red_stars), pos,
## stars_x, pos_x, size}. (No trait: the tag doesn't show it.)
static func tag_parts(p: PoloPlayer) -> Dictionary:
	var t := p.tag()
	var tw := UI.text_width(t, 8, "caps")
	var ps := p.pos_text()
	var pw := UI.text_width(ps, 8, "caps")
	var sw := Deck.star_bar_w_for(p.stars, p.stars, PlayerForm.red_stars(p.form_state()))
	return {"text": t, "stars": PlayerForm.snap_half(p.stars), "red": PlayerForm.red_stars(p.form_state()), "pos": ps,
		"stars_x": tw + 10.0, "pos_x": tw + sw + 16.0, "size": Vector2(tw + sw + 16.0 + pw + 4.0, 12.0)}

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
static func pill(ci: CanvasItem, size: Vector2, text: String, col: Color, y: float = 30.0) -> void:
	var tw := UI.text_width(text, 8, "caps") + 12
	var r := Rect2(roundf((size.x - tw) / 2.0), y, tw, 12)
	ci.draw_rect(r, Color(0.02, 0.04, 0.1, 0.8))
	ci.draw_rect(r, col, false, 1.0)
	UI.text(ci, r.position + Vector2(0, 9), text, 8, col, "caps", HORIZONTAL_ALIGNMENT_CENTER, tw)

## The quarter-break scoreboard, after the 1st, 2nd and 3rd quarters (full time goes straight
## to the results): a broadcast-style board over the darkened pool. A header band (END OF 1ST
## QUARTER / END OF 3RD QUARTER on blue; HALFTIME on gold, with gold rivets in the corners), then
## the two teams side by side, names in white over their scores in yellow in LED wells, a VS
## chip on the divider between them, and `footer` in the strip along the bottom. A layered pixel
## frame: ink, gold, ink, a bevelled navy face, a hard drop shadow; the corners notched, never
## rounded. `age`: seconds since the break began: it drops in from a few px up and the header
## wipes open (BREAK_IN s), and the prompt's arrow blinks. Taps are never held up by it (the
## screen takes them as before). Returns the board's rect (HalftimePanel's button and the
## broadcast comparison sit off it).
const ORDINALS := ["1ST", "2ND", "3RD", "4TH"]
const BREAK_IN := 0.18               # s the board takes to drop in
const BREAK_PAD := 12.0              # px between the frame and a team's column
const BREAK_INK := Color("050c26")
const BREAK_FACE := Color("12204a")
const BREAK_HI := Color("26397a")    # the bevel's light edge
const BREAK_LO := Color("0a1433")    # ...and its dark one
const BREAK_BAND := Color("1d3f94")  # a quarter's header band
const BREAK_WELL := Color("070f2c")  # the score wells

## The header: HALFTIME after the 2nd, END OF 1ST QUARTER / END OF 3RD QUARTER otherwise.
static func break_title(quarter: int) -> String:
	if quarter == 2:
		return "HALFTIME"
	return "END OF %s QUARTER" % ORDINALS[clampi(quarter - 1, 0, 3)]

static func break_card(ci: CanvasItem, size: Vector2, quarter: int, score: Array, us: PoloTeam,
		them: PoloTeam, footer: String = "TAP TO CONTINUE", age: float = 99.0) -> Rect2:
	var motion := not Game.test_mode and not bool(Game.settings.get("reduce_motion", false))
	if not motion:
		age = 99.0
	var e := 1.0 - pow(1.0 - clampf(age / BREAK_IN, 0.0, 1.0), 3.0)
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.1, 0.6 * clampf(age / 0.12, 0.0, 1.0)))
	var half := quarter == 2
	var title := break_title(quarter)
	# the names: the short names, in the big caps if both fit their column, else the small ones
	var names := [Colleges.short_name(us).to_upper(), Colleges.short_name(them).to_upper()]
	var nsz := 16
	var nw := maxf(UI.text_width(names[0], 16, "caps"), UI.text_width(names[1], 16, "caps"))
	var w := roundf(minf(maxf(maxf(272.0, UI.text_width(title, 16, "big") + 72.0), 2.0 * nw + 47.0 + 2.0 * BREAK_PAD), size.x - 24.0))
	var col_w := floorf((w - 47.0 - 2.0 * BREAK_PAD) / 2.0)   # each team's column, either side of the divider
	if nw > col_w:
		nsz = 8
		for i in 2:
			names[i] = _fit_text(names[i], 8, "caps", col_w)
	var h := 106.0
	var r := Rect2(roundf((size.x - w) / 2.0), roundf((size.y - h) / 2.0) - roundf(10.0 * (1.0 - e)), w, h)
	# the frame: shadow, ink, gold, ink, then the face with its bevel
	_notched(ci, Rect2(r.position + Vector2(3, 3), r.size), Color(0, 0, 0, 0.45))
	_notched(ci, r, BREAK_INK)
	_notched(ci, r.grow(-1), UI.GOLD)
	ci.draw_rect(r.grow(-2), BREAK_INK)
	var face := r.grow(-3)
	ci.draw_rect(face, BREAK_FACE)
	ci.draw_rect(Rect2(face.position, Vector2(face.size.x, 1)), BREAK_HI)
	ci.draw_rect(Rect2(face.position, Vector2(1, face.size.y)), BREAK_HI)
	ci.draw_rect(Rect2(face.position.x, face.end.y - 1, face.size.x, 1), BREAK_LO)
	ci.draw_rect(Rect2(face.end.x - 1, face.position.y, 1, face.size.y), BREAK_LO)
	# the header band, wiping open from the middle
	var band_h := 22.0 if half else 20.0
	var band := Rect2(face.position.x + 3, face.position.y + 3, face.size.x - 6, band_h)
	var open := clampf((age - 0.04) / 0.14, 0.0, 1.0)
	var bw := roundf(band.size.x * lerpf(0.2, 1.0, 1.0 - pow(1.0 - open, 2.0)))
	var shown := Rect2(roundf(band.position.x + (band.size.x - bw) / 2.0), band.position.y, bw, band_h)
	ci.draw_rect(shown, UI.GOLD if half else BREAK_BAND)
	ci.draw_rect(Rect2(shown.position, Vector2(shown.size.x, 1)), Color(1, 1, 1, 0.35 if half else 0.18))
	ci.draw_rect(Rect2(shown.position.x, shown.end.y, shown.size.x, 1), BREAK_INK)
	ci.draw_rect(Rect2(shown.position.x, shown.end.y + 1, shown.size.x, 1), BREAK_HI if half else UI.GOLD)
	if open >= 0.6:
		var cy := band.position.y + roundf(band_h / 2.0)
		var ty := cy + 6.0
		if not half:
			UI.text(ci, Vector2(band.position.x, ty + 1), title, 16, Color(BREAK_INK, 0.8), "big", HORIZONTAL_ALIGNMENT_CENTER, band.size.x)
		UI.text(ci, Vector2(band.position.x, ty), title, 16, UI.INK if half else UI.TEXT, "big", HORIZONTAL_ALIGNMENT_CENTER, band.size.x)
		# pixel diamonds either side of the title (three a side at halftime)
		var tw := UI.text_width(title, 16, "big")
		var cx := band.position.x + band.size.x / 2.0
		for n in (3 if half else 1):
			for sgn: float in [-1.0, 1.0]:
				_diamond(ci, Vector2(roundf(cx + sgn * (tw / 2.0 + 10.0 + 9.0 * n)), cy), UI.INK if half else UI.GOLD)
	if half:   # halftime: gold rivets in the face's corners
		for p: Vector2 in [face.position + Vector2(2, 2), Vector2(face.end.x - 4, face.position.y + 2),
				Vector2(face.position.x + 2, face.end.y - 4), face.end - Vector2(4, 4)]:
			ci.draw_rect(Rect2(p, Vector2(2, 2)), UI.GOLD)
	# the teams: a column each, the name over its score in a well
	var top := band.end.y + 6.0
	var mid := roundf(face.position.x + face.size.x / 2.0)
	for i in 2:
		var x0 := mid - 23.0 - col_w if i == 0 else mid + 24.0
		UI.text_shadow(ci, Vector2(x0, top + (14.0 if nsz == 16 else 11.0)), String(names[i]), nsz, UI.TEXT, "caps",
			HORIZONTAL_ALIGNMENT_CENTER, col_w, Color(BREAK_INK, 0.9))
		var sc := str(int(score[i]))
		var ww := maxf(52.0, UI.text_width(sc, 40, "big") + 20.0)
		var well := Rect2(roundf(x0 + (col_w - ww) / 2.0), top + 20.0, ww, 34.0)
		ci.draw_rect(well, BREAK_WELL)
		ci.draw_rect(Rect2(well.position, Vector2(well.size.x, 1)), BREAK_LO)
		ci.draw_rect(Rect2(well.position.x, well.end.y - 1, well.size.x, 1), BREAK_HI)
		ci.draw_rect(well, Color(UI.GOLD, 0.35), false, 1.0)
		UI.text(ci, Vector2(well.position.x, well.end.y - 5.0), sc, 40, Color(BREAK_INK, 0.9), "big", HORIZONTAL_ALIGNMENT_CENTER, well.size.x)
		UI.text(ci, Vector2(well.position.x, well.end.y - 7.0), sc, 40, UI.GOLD, "big", HORIZONTAL_ALIGNMENT_CENTER, well.size.x)
	# the divider down the middle, broken by the VS chip
	for y in range(int(top), int(top + 54.0), 2):
		ci.draw_rect(Rect2(mid, y, 1, 1), BREAK_HI)
	var vs := Rect2(mid - 9.0, top + 30.0, 19.0, 13.0)
	ci.draw_rect(vs, BREAK_FACE)
	ci.draw_rect(vs, Color(UI.GOLD, 0.6), false, 1.0)
	UI.text(ci, Vector2(vs.position.x, vs.position.y + 10.0), "VS", 8, DIM, "caps", HORIZONTAL_ALIGNMENT_CENTER, vs.size.x)
	# the prompt strip along the bottom: the footer, and for a tap a blinking pixel arrow after it
	var strip := Rect2(face.position.x + 3, face.end.y - 18.0, face.size.x - 6, 15.0)
	ci.draw_rect(strip, Color(BREAK_INK, 0.7))
	ci.draw_rect(Rect2(strip.position, Vector2(strip.size.x, 1)), BREAK_LO)
	var tap := footer == "TAP TO CONTINUE"
	var fw := UI.text_width(footer, 8, "caps")
	var fx := roundf(strip.position.x + (strip.size.x - fw - (10.0 if tap else 0.0)) / 2.0)
	UI.text(ci, Vector2(fx, strip.position.y + 11.0), footer, 8, UI.DIM, "caps")
	if tap:
		var lit := not motion or age < 0.3 or int(age / 0.45) % 2 == 0
		var acol := Color(UI.GOLD, 1.0 if lit else 0.3)
		for j in 4:
			ci.draw_rect(Rect2(fx + fw + 6.0 + j, strip.position.y + 4.0 + j, 1, 7 - 2 * j), acol)
	return r

## `r` filled with `col`, its four corner pixels left out (a pixel frame's notched corner).
static func _notched(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, r.size.y), col)
	ci.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), col)
	ci.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), col)

## A 5 px pixel diamond centred on `c`.
static func _diamond(ci: CanvasItem, c: Vector2, col: Color) -> void:
	ci.draw_rect(Rect2(c.x - 2, c.y, 5, 1), col)
	ci.draw_rect(Rect2(c.x - 1, c.y - 1, 3, 3), col)
	ci.draw_rect(Rect2(c.x, c.y - 2, 1, 5), col)

## `s` cut down (ending in ".") until it fits `w` px.
static func _fit_text(s: String, sz: int, font: String, w: float) -> String:
	if UI.text_width(s, sz, font) <= w:
		return s
	while s.length() > 1 and UI.text_width(s + ".", sz, font) > w:
		s = s.substr(0, s.length() - 1).strip_edges()
	return s + "."
