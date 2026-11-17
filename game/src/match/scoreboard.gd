class_name Scoreboard
extends RefCounted
## THE SCOREBOARD UPGRADE (VisualUpgrades "scoreboard"): the top-centre board's three looks, each a
## reusable piece drawn straight onto a canvas in whole pixels, never smoothed. Every tier shows the
## same facts off the same MatchState: both teams, both scores (the shootout's in a shootout), the
## quarter and the game clock, with the shot clock beside it (shot_clock). Cosmetic only: nothing
## in the rules reads the tier, and switching it mid-match only changes what the next frame draws.
##   1 CLASSIC    the dark navy board, a thin white edge, small logos, abbreviations, yellow scores
##   2 ENHANCED   a double edge, team-colour sections with small logos, bigger scores in wells
##   3 PREMIUM    a silver frame, team-colour panels with full names where they fit and bigger
##                logos, layered score panels, its own clock panel; the scores roll over on a goal
## Every board stays within MAX_W (the shot clock on its left, the play calls and the pause button
## on its right), and within MAX_BOTTOM (the man-up pill and the callouts below it: below()).

const TOP := 3
const NAMES := ["CLASSIC", "ENHANCED", "PREMIUM"]
const MAX_W := 304.0           # (the widest Classic board: Hud.NAME_MAX a side)
const MAX_BOTTOM := 29.0

## Developer Mode's SCOREBOARD VISUAL PREVIEW: a tier worn in every match this session instead of
## the owned one (0: none). Never saved; only while Developer Mode is on (tier()).
static var override := 0

const INK := Color("050c26")
const NAVY := Color("0b2057")
const FACE := Color("0f2463")
const WELL := Color("070f2c")
const EDGE2 := Color("5f86c8")         # Enhanced's inner edge
const SILVER_HI := Color("f4f7fb")
const SILVER := Color("b9c3d1")
const SILVER_LO := Color("6b778a")
const GOLD_LO := Color("8a5a12")
const LED_WELL := Color("1a0610")

const ROLL := 0.24             # s an old score takes to roll out and the new one in (Premium)
const FLASH := 0.6             # s a scoring panel's edge flashes

## The tier this match shows: Developer Mode's override, else the level worn.
static func tier() -> int:
	if override > 0 and bool(Game.settings.get("dev_mode", false)):
		return clampi(override, 1, TOP)
	return clampi(Store.looks.worn("scoreboard"), 1, TOP)

## Draws tier `tier`'s board; returns its rect (every pixel it covers, the centre panel included).
## `fx`: GoalShow.board_fx (a goal going up on the board).
static func draw(ci: CanvasItem, tier: int, w: float, st: MatchState, us: PoloTeam, them: PoloTeam,
		us_cap: Color, them_cap: Color, them_trim: Color = Color.TRANSPARENT, fx: Dictionary = {}) -> Rect2:
	var trims := [us.c1, them.c2 if them_trim.a == 0.0 else them_trim]
	match clampi(tier, 1, TOP):
		2:
			return _enhanced(ci, w, facts(st, fx), [us, them], [us_cap, them_cap], trims)
		3:
			return _premium(ci, w, facts(st, fx), [us, them], [us_cap, them_cap], trims)
	return Hud.classic_board(ci, w, st, us, them, us_cap, them_cap, them_trim, fx)

## How wide tier `tier`'s board is for these two teams (draw()'s rect, without drawing it): the
## same sums as _enhanced, _premium and Hud.classic_board.
static func width(tier: int, us: PoloTeam, them: PoloTeam) -> float:
	match clampi(tier, 1, TOP):
		2:
			var slot := maxf(E_SLOT_MIN, maxf(float(abbr_label(us).w), float(abbr_label(them).w)))
			return 2.0 * (E_PAD + slot) + 2.0 * E_WELL + E_MID + 10.0
		3:
			var slot := clampf(maxf(float(name_label(us, P_SLOT[1]).w), float(name_label(them, P_SLOT[1]).w)), P_SLOT[0], P_SLOT[1])
			return 2.0 * (P_BAY + P_PAD + slot) + 2.0 * P_WELL + P_MID + 10.0 + 2.0
	var slot := maxf(Hud.NAME_MIN, maxf(float(abbr_label(us).w), float(abbr_label(them).w)))
	var o := 2.0 * Hud.C_PAD + Hud.C_LOGO.x - 14.0
	return 126.0 + 2.0 * o + 2.0 * slot

## The first free row under a board (the man-up pill, the formation tag).
static func below(board: Rect2) -> float:
	return board.end.y + 2.0

## The numbers a board shows: {score, pens, fs (the side whose score is going up, -1), pen_fs (a
## shootout goal's side), shoot, q, clock, fx}. A goal on its way up already counts (`fx.add`).
static func facts(st: MatchState, fx: Dictionary) -> Dictionary:
	var score := [int(st.score[0]), int(st.score[1])]
	var pens := [int(st.shootout[0]), int(st.shootout[1])]
	var fs := int(fx.get("side", -1))
	if fs >= 0:
		var up: Array = pens if st.in_shootout else score
		up[fs] += int(fx.get("add", 1))
	return {"score": score, "pens": pens, "fs": -1 if st.in_shootout else fs, "pen_fs": fs if st.in_shootout else -1,
		"shoot": st.in_shootout, "q": st.quarter, "clock": st.clock_text(), "fx": fx}

## A team's scoreboard abbreviation: a one-word place's first three letters (BRONX: BRO), a longer
## place's initials (SAN DIEGO: SD), and the mascot's initial too where two schools share a place
## (LOS ANGELES BEARS: LAB). A team that isn't a school keeps its own short code.
static func abbr(t: PoloTeam) -> String:
	var s := Colleges.school(t.id)
	if s.is_empty() or String(s.name) != t.name:
		var id := t.id.to_upper()
		if id.length() >= 2 and id.length() <= 4:
			return id
		return t.name.to_upper().replace(" ", "").substr(0, 3)
	var place := Colleges.place(t.id).to_upper()
	var words := place.split(" ", false)
	var out := ""
	if OWN_ABBR.has(place):
		out = OWN_ABBR[place]
	elif words.size() == 1:
		out = place if place.length() <= 4 else place.substr(0, 3)
	else:
		for wd in words:
			out += wd[0]
	if Colleges.short_name(t).to_upper() != place:
		out += String(s.mascot).to_upper()[0]
	return out

## Places whose first three letters another place already has (BRONX's BRO).
const OWN_ABBR := {"BROOKLYN": "BKN"}

## The abbreviation as a Hud.fit_name.
static func abbr_label(t: PoloTeam) -> Dictionary:
	var a := abbr(t)
	return {"lines": [a], "size": 8, "font": "caps", "w": UI.text_width(a, 8, "caps")}

## The team's short name if it fits `max_w` whole (one line, or place over mascot), else its
## abbreviation.
static func name_label(t: PoloTeam, max_w: float) -> Dictionary:
	var d := Hud.fit_name(t, max_w)
	if " ".join(d.lines) == Colleges.short_name(t).to_upper():
		return d
	return abbr_label(t)

## A team's colour behind white letters (a light one deepened so they read).
static func team_fill(c: Color) -> Color:
	return c.darkened(0.45) if c.get_luminance() > 0.5 else c

# ------------------------------------------------------------------ 2: ENHANCED
const E_H := 23.0
const E_WELL := 28.0
const E_MID := 50.0
const E_SLOT_MIN := 24.0
const E_PAD := 32.0             # a team panel's width past its name slot (the logo and margins)

static func _enhanced(ci: CanvasItem, w: float, f: Dictionary, teams: Array, _caps: Array, _trims: Array) -> Rect2:
	var names := [abbr_label(teams[0]), abbr_label(teams[1])]
	var slot := maxf(E_SLOT_MIN, maxf(float(names[0].w), float(names[1].w)))
	var pw := E_PAD + slot
	var bw := 2.0 * pw + 2.0 * E_WELL + E_MID + 10.0
	var x := roundf((w - bw) / 2.0)
	var r := Rect2(x, 2, bw, E_H)
	ci.draw_rect(Rect2(r.position + Vector2(1, 1), r.size), Color(0, 0, 0, 0.35))
	ci.draw_rect(r, UI.BORDER)
	ci.draw_rect(r.grow(-1), INK)
	ci.draw_rect(r.grow(-2), EDGE2)
	var inner := r.grow(-3)
	ci.draw_rect(inner, NAVY)
	var y := inner.position.y
	var h := inner.size.y
	var cy := y + h / 2.0
	for i in 2:
		var t: PoloTeam = teams[i]
		var px := inner.position.x if i == 0 else inner.end.x - pw
		var fill := team_fill(t.c1)
		var trim := TeamLogo.trim_for(t.c1, t.c2)
		ci.draw_rect(Rect2(px, y, pw, h), fill)
		ci.draw_rect(Rect2(px, y, pw, 1), fill.lightened(0.22))
		ci.draw_rect(Rect2(px, y + h - 2, pw, 2), fill.darkened(0.3))
		ci.draw_rect(Rect2(px if i == 0 else px + pw - 2, y, 2, h), trim)
		var logo_x := px + 4.0 if i == 0 else px + 8.0 + slot
		var name_x := px + 27.0 if i == 0 else px + 5.0
		TeamLogo.draw_in(ci, Rect2(logo_x, roundf(cy - 6.0), 20, 12), t)
		_name(ci, names[i], Vector2(name_x, roundf(cy + 2.5)), slot, UI.TEXT)
		var wx := px + pw + 1.0 if i == 0 else px - 1.0 - E_WELL
		ci.draw_rect(Rect2(px + pw if i == 0 else px - 1.0, y, 1, h), INK)
		var well := Rect2(wx, y, E_WELL, h)
		ci.draw_rect(well, WELL)
		ci.draw_rect(Rect2(wx, y, E_WELL, 1), INK)
		ci.draw_rect(Rect2(wx, y + h - 1, E_WELL, 1), Hud.LINE)
		if i == int(f.fs):
			_pop(ci, well, int(f.score[i]), 24, f.fx)
		else:
			_num(ci, well, int(f.score[i]), 24, UI.GOLD)
		ci.draw_rect(Rect2(wx + E_WELL if i == 0 else wx - 1.0, y, 1, h), INK)
	var mid := Rect2(inner.position.x + pw + E_WELL + 2.0, y, E_MID, h)
	ci.draw_rect(mid, Color("122a6e"))
	ci.draw_rect(Rect2(mid.position.x, y, E_MID, 1), Color("23409a"))
	_mid_line(ci, mid, f, roundf(cy + 2.5), roundf(cy + 4.0), UI.GOLD, UI.TEXT)
	return Rect2(r.position, r.size + Vector2(1, 1))

# ------------------------------------------------------------------ 3: PREMIUM
const P_Y := 1.0
const P_H := 26.0
const P_BAY := 30.0            # the logo bay (a 28 x 20 logo)
const P_WELL := 28.0
const P_MID := 52.0
const P_SLOT := [30.0, 50.0]
const P_PAD := 10.0            # a team panel's width past its logo bay and name slot

static func _premium(ci: CanvasItem, w: float, f: Dictionary, teams: Array, _caps: Array, _trims: Array) -> Rect2:
	var names := [name_label(teams[0], P_SLOT[1]), name_label(teams[1], P_SLOT[1])]
	var slot := clampf(maxf(float(names[0].w), float(names[1].w)), P_SLOT[0], P_SLOT[1])
	var pw := P_BAY + P_PAD + slot
	var bw := 2.0 * pw + 2.0 * P_WELL + P_MID + 10.0
	var x := roundf((w - bw) / 2.0)
	var r := Rect2(x, P_Y, bw, P_H)
	_notched(ci, Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.4))
	_notched(ci, r, INK)
	_metal(ci, r.grow(-1), SILVER_HI, SILVER, SILVER_LO)
	ci.draw_rect(r.grow(-2), INK)
	var inner := r.grow(-3)
	ci.draw_rect(inner, FACE)
	var y := inner.position.y
	var h := inner.size.y
	var cy := y + h / 2.0
	for i in 2:
		var t: PoloTeam = teams[i]
		var px := inner.position.x if i == 0 else inner.end.x - pw
		var fill := team_fill(t.c1)
		var trim := TeamLogo.trim_for(t.c1, t.c2)
		ci.draw_rect(Rect2(px, y, pw, h), fill)
		ci.draw_rect(Rect2(px, y, pw, 1), fill.lightened(0.3))
		ci.draw_rect(Rect2(px, y + 1, pw, 1), fill.lightened(0.14))
		ci.draw_rect(Rect2(px, y + h - 3, pw, 1), fill.darkened(0.18))
		ci.draw_rect(Rect2(px, y + h - 2, pw, 2), fill.darkened(0.38))
		# the logo bay at the outer end, edged in the trim
		var bay := Rect2(px if i == 0 else px + pw - P_BAY, y, P_BAY, h)
		ci.draw_rect(bay, INK)
		ci.draw_rect(Rect2(bay.end.x - 1 if i == 0 else bay.position.x, y, 1, h), trim)
		TeamLogo.draw_in(ci, Rect2(bay.position.x + 1, y, 28, 20), t)
		# the stepped trim stripe slanting into the score panel
		var edge := px + pw if i == 0 else px
		for row in int(h):
			var step := float(row / 7)
			var sx := edge - 4.0 + step if i == 0 else edge + 2.0 - step
			ci.draw_rect(Rect2(sx, y + row, 2, 1), trim)
		var name_x := px + P_BAY + 3.0 if i == 0 else px + 7.0
		_name(ci, names[i], Vector2(name_x, roundf(cy + 2.5)), slot, UI.TEXT, true)
		# the score panel: silver over ink over the well
		var wx := px + pw + 1.0 if i == 0 else px - 1.0 - P_WELL
		var well := Rect2(wx, y - 1, P_WELL, h + 2)
		ci.draw_rect(well, INK)
		_metal(ci, well, SILVER_HI, SILVER, SILVER_LO)
		ci.draw_rect(well.grow(-1), INK)
		ci.draw_rect(well.grow(-2), WELL)
		if i == int(f.fs):
			_roll(ci, well.grow(-2), int(f.score[i]), 24, f.fx)
		else:
			_num(ci, well.grow(-2), int(f.score[i]), 24, UI.GOLD, 0.0, GOLD_LO)
	# the clock's own panel, a pixel proud of the board above and below
	var mid := Rect2(inner.position.x + pw + P_WELL + 2.0, P_Y - 1.0, P_MID, P_H + 2.0)
	_notched(ci, mid, INK)
	_metal(ci, mid.grow(-1), SILVER_HI, SILVER, SILVER_LO)
	var mf := mid.grow(-2)
	ci.draw_rect(mf, NAVY)
	var tab := Rect2(mf.position.x + 1, mf.position.y + 1, mf.size.x - 2, 9)
	ci.draw_rect(tab, Color("23409a"))
	ci.draw_rect(Rect2(tab.position.x, tab.end.y, tab.size.x, 1), SILVER_LO)
	if bool(f.shoot):
		UI.text(ci, Vector2(tab.position.x, tab.end.y - 2), "SHOOTOUT", 8, UI.GOLD, "body", HORIZONTAL_ALIGNMENT_CENTER, tab.size.x)
		var pc := UI.GOLD if int(f.pen_fs) >= 0 and float(f.fx.get("t", 9.0)) < Hud.SCORE_FLASH * 1.5 else UI.TEXT
		UI.text(ci, Vector2(mf.position.x, mf.end.y - 2), "%d-%d" % [f.pens[0], f.pens[1]], 20, pc, "big", HORIZONTAL_ALIGNMENT_CENTER, mf.size.x)
	else:
		UI.text(ci, Vector2(tab.position.x, tab.end.y - 2), _q_text(int(f.q)), 8, UI.GOLD, "caps", HORIZONTAL_ALIGNMENT_CENTER, tab.size.x)
		clock(ci, mf.get_center().x, mf.end.y - 2, String(f.clock), 20, UI.TEXT, INK)
	_glint(ci, r, 7.0)
	return Rect2(x, 0, bw + 2.0, P_Y + P_H + 2.0)

# ------------------------------------------------------------------ the shot clock
## The shot clock beside tier `tier`'s board: the same seconds and the same final-five heartbeat
## (Hud.sc_digits) in each tier's own box. Returns its rect.
static func shot_clock(ci: CanvasItem, tier: int, board: Rect2, secs: float) -> Rect2:
	match clampi(tier, 1, TOP):
		2:
			# SC beside the digits (not over them): the pair centred in the box, the digits'
			# ink centred top to bottom
			var r := Rect2(board.position.x - 37, 2, 34, E_H)
			ci.draw_rect(Rect2(r.position + Vector2(1, 1), r.size), Color(0, 0, 0, 0.35))
			ci.draw_rect(r, UI.BORDER)
			ci.draw_rect(r.grow(-1), INK)
			ci.draw_rect(r.grow(-2), EDGE2)
			var inner := r.grow(-3)
			ci.draw_rect(inner, NAVY)
			var lw := UI.text_width("SC", 8, "body")
			var dw := UI.text_width("%02d" % maxi(0, int(ceilf(secs))), Hud.SC_FS, "big")
			var label := "SC" if lw + 2.0 + dw <= inner.size.x - 2.0 else ""
			var gw := (lw + 2.0 + dw) if label != "" else dw
			var gx := roundf(inner.get_center().x - gw / 2.0)
			var base := roundf(inner.get_center().y + Hud.SC_FS * 0.525 / 2.0)
			Hud.sc_digits(ci, r, secs, label, Vector2(gx, base), Vector2(gx + gw - dw, base))
			return r
		3:
			var r := Rect2(board.position.x - 37, P_Y, 34, P_H)
			var hot := ceilf(secs) <= Hud.SC_FINAL
			_notched(ci, Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.4))
			_notched(ci, r, INK)
			if hot:
				_metal(ci, r.grow(-1), Color("ffb3b3"), Hud.SC_RED, Color("7a0a14"))
			else:
				_metal(ci, r.grow(-1), SILVER_HI, SILVER, SILVER_LO)
			ci.draw_rect(r.grow(-2), INK)
			ci.draw_rect(r.grow(-3), LED_WELL)
			if not hot:
				UI.text(ci, Vector2(r.position.x, r.position.y + 10), "SHOT", 8, UI.GOLD, "body", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			Hud.sc_digits(ci, Rect2(r.position + Vector2(0, 4), r.size - Vector2(0, 4)), secs, "", Vector2.ZERO, r.position + Vector2(7, 23))
			return Rect2(r.position, r.size + Vector2(2, 2))
	var pos := Vector2(board.position.x - 34, 2)
	Hud.shot_clock(ci, pos, secs)
	return Rect2(pos, Vector2(30, 21))

# ------------------------------------------------------------------ pieces
## A clock ("3:12") in the big font, centred on `cx`, its baseline `base`: the minutes and the
## seconds with a colon of two square pixels between them (the font's own is a sliver).
static func clock(ci: CanvasItem, cx: float, base: float, text: String, size: int, col: Color, shadow := Color.TRANSPARENT) -> void:
	var parts := text.split(":")
	if parts.size() != 2:
		UI.text(ci, Vector2(cx - 40.0, base), text, size, col, "big", HORIZONTAL_ALIGNMENT_CENTER, 80.0)
		return
	var dot := 2.0 if size < 24 else 3.0
	var wa := UI.text_width(parts[0], size, "big")
	var x0 := roundf(cx - clock_w(text, size) / 2.0)
	var xc := x0 + wa + 1.0
	var ink := roundf(size * 0.525)
	var ys := [base - roundf(ink * 0.8), base - roundf(ink * 0.35)]
	for pass_i in (2 if shadow.a > 0.0 else 1):
		var sh := pass_i == 0 and shadow.a > 0.0
		var o := Vector2(0, 1) if sh else Vector2.ZERO
		var c := shadow if sh else col
		UI.text(ci, Vector2(x0, base) + o, parts[0], size, c, "big")
		for y: float in ys:
			ci.draw_rect(Rect2(Vector2(xc, y) + o, Vector2(dot, dot)), c)
		UI.text(ci, Vector2(xc + dot + 2.0, base) + o, parts[1], size, c, "big")

## clock()'s width.
static func clock_w(text: String, size: int) -> float:
	var parts := text.split(":")
	if parts.size() != 2:
		return UI.text_width(text, size, "big")
	return UI.text_width(parts[0], size, "big") + 3.0 + (2.0 if size < 24 else 3.0) + UI.text_width(parts[1], size, "big")

static func _q_text(q: int) -> String:
	return "Q%d" % q

## A Hud.fit_name in `w` px from `pos` (its baseline), centred, with an ink shadow if `shadow`.
static func _name(ci: CanvasItem, d: Dictionary, pos: Vector2, w: float, col: Color, shadow := false) -> void:
	if shadow:
		Hud.draw_name(ci, d, pos + Vector2(1, 1), HORIZONTAL_ALIGNMENT_CENTER, w, Color(INK, 0.85))
	Hud.draw_name(ci, d, pos, HORIZONTAL_ALIGNMENT_CENTER, w, col)

## The quarter and the clock on one line (Enhanced): Q2 in small caps, 3:12 in the big font; the
## shootout's running score in its place.
static func _mid_line(ci: CanvasItem, r: Rect2, f: Dictionary, small_y: float, big_y: float, q_col: Color, c_col: Color) -> void:
	var a := "PENS" if bool(f.shoot) else _q_text(int(f.q))
	var b := "%d-%d" % [f.pens[0], f.pens[1]] if bool(f.shoot) else String(f.clock)
	if bool(f.shoot) and int(f.pen_fs) >= 0 and float(f.fx.get("t", 9.0)) < Hud.SCORE_FLASH * 1.5:
		c_col = UI.GOLD
	var aw := UI.text_width(a, 8, "caps")
	var bw := clock_w(b, 16)
	var x0 := roundf(r.position.x + (r.size.x - aw - 4.0 - bw) / 2.0)
	UI.text(ci, Vector2(x0, small_y), a, 8, q_col, "caps")
	clock(ci, x0 + aw + 4.0 + bw / 2.0, big_y, b, 16, c_col, Color(INK, 0.8))

## `n` in the big font, its ink centred in `r` (`dy` px down), over an optional drop shadow.
static func _num(ci: CanvasItem, r: Rect2, n: int, size: int, col: Color, dy := 0.0, shadow := Color.TRANSPARENT) -> void:
	var base := roundf(r.get_center().y + size * 0.525 / 2.0 + dy)
	var s := str(n)
	var x := r.position.x + 1.0
	if shadow.a > 0.0:
		UI.text(ci, Vector2(x, base + 1), s, size, Color(shadow, shadow.a * col.a), "big", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	UI.text(ci, Vector2(x, base), s, size, col, "big", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

## Enhanced's goal: Classic's (Hud._score_pop) in the well: the team's colour flashes behind it,
## the number drops in and swells and settles, in a dark outline.
static func _pop(ci: CanvasItem, well: Rect2, n: int, size: int, fx: Dictionary) -> void:
	var u := float(fx.get("t", 1.0))
	var drop := clampf(u / 0.06, 0.0, 1.0)
	var swell := drop * (1.0 - smoothstep(0.06, Hud.SCORE_POP, u))
	var s := int(roundf(size * (1.0 + (0.5 if bool(fx.get("big", false)) else 0.3) * swell)))
	var col: Color = fx.get("col", UI.GOLD)
	if u < Hud.SCORE_FLASH:
		var on := int(u / 0.075) % 2 == 0
		ci.draw_rect(well, Color(col, 0.95) if on else Color(UI.GOLD, 0.35))
	if u < Hud.SCORE_POP + 0.1:
		ci.draw_rect(well, UI.GOLD, false, 1.0)
	var dy := -6.0 * (1.0 - drop)
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		_num(ci, Rect2(well.position + d, well.size), n, s, NAVY, dy)
	_num(ci, well, n, s, UI.GOLD, dy)

## Premium's goal: the old score rolls up and out as the new one rolls in from below
## (ROLL s), the panel flashes the team's colour and its edge glows, then the new number gives
## one small swell. Reduce Motion: just the flash.
static func _roll(ci: CanvasItem, r: Rect2, n: int, size: int, fx: Dictionary) -> void:
	var u := float(fx.get("t", 9.0))
	var col: Color = fx.get("col", UI.GOLD)
	var calm := HotFire.calm()
	if u < FLASH:
		var a := 1.0 - u / FLASH
		ci.draw_rect(r, Color(col, 0.55 * a))
		ci.draw_rect(r.grow(1), Color(UI.GOLD, a), false, 1.0)
	if calm or u >= ROLL:
		var sw := 0.0 if calm else 1.0 - smoothstep(0.0, 0.25, u - ROLL)
		var s := int(roundf(size * (1.0 + (0.2 if bool(fx.get("big", false)) else 0.12) * sw)))
		_num(ci, r, n, s, UI.GOLD, 0.0, GOLD_LO)
		return
	var p := u / ROLL
	var e := 1.0 - pow(1.0 - p, 2.0)
	var travel := 5.0
	_num(ci, r, n - int(fx.get("add", 1)), size, Color(UI.GOLD, 1.0 - e), -roundf(travel * e), GOLD_LO)
	_num(ci, r, n, size, Color(UI.GOLD, e), roundf(travel * (1.0 - e)), GOLD_LO)

## `r` filled with `col`, its four corner pixels left out.
static func _notched(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, r.size.y), col)
	ci.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), col)
	ci.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), col)

## A 1 px metal ring on `r`'s edge: lit along the top, mid down the left, shaded right and below.
static func _metal(ci: CanvasItem, r: Rect2, hi: Color, mid: Color, lo: Color) -> void:
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), hi)
	ci.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), mid)
	ci.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), lo)
	ci.draw_rect(Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 2, 1), lo)
	ci.draw_rect(Rect2(r.position.x + 2, r.position.y + 1, 2, 1), Color(hi, 0.6))

## A glint running along a metal frame's top now and then (every `period` s); none under Reduce
## Motion or in tests (screenshots stay steady).
static func _glint(ci: CanvasItem, r: Rect2, period: float) -> void:
	if HotFire.calm() or Game.test_mode:
		return
	var ph := fmod(Time.get_ticks_msec() / 1000.0, period)
	if ph > 0.7:
		return
	var x := roundf(r.position.x + 2.0 + (r.size.x - 6.0) * ph / 0.7)
	ci.draw_rect(Rect2(x, r.position.y + 1, 3, 1), Color(1, 1, 1, 0.85))
	ci.draw_rect(Rect2(x + 4, r.position.y + 1, 1, 1), Color(1, 1, 1, 0.5))
	ci.draw_rect(Rect2(r.end.x - 4 - (x - r.position.x), r.end.y - 2, 2, 1), Color(1, 1, 1, 0.35))
