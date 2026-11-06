extends BaseScreen
## THE POSTGAME REVIEW: after the game summary, the coach's corkboard with the game's reports
## pinned to it (Postgame), all from the game's own numbers; a simmed game's estimates marked "*".
## CONTINUE leaves the board, and only then is a coaching event drawn (CoachEvents.roll): one
## comes on its own screen, or the postgame ends.
##
## THE BULLETIN BOARD (the Postgame Bulletin Board Visual Overhaul): a wood-framed corkboard drawn
## in DETAIL MODE (Game.set_detail: its grain, cork, pins and shadows at two-thirds of a game pixel,
## FINE; its text at the game's own sizes, 12 units the usual 8-pixel type, all exactly sharp):
##   centre top   the FINAL SCORE: a heavy white report, two pins, both schools' logos and names,
##                the scores large, the winner's row marked, a VICTORY / DEFEAT stamp, the round and
##                whether it was a conference game
##   left         TEAM STATS: a printed cream box score (every stat, US / THEM, thin rules, the
##                better side of each row lightly highlighted; the simmed game's footnote)
##   centre       COACH'S NOTES: a yellow notebook page under tape, ruled, a red margin; a green
##                tick by a good note, a red mark by a bad one (from the note's own words)
##   right        four pinned index cards: TOP SCORER, TOP PLAYMAKER, TOP DEFENDER, GOALKEEPER,
##                each with its icon (ball, pass, shield, glove)
## The sheets pin up one after another as the board opens (REVEAL); nothing waits on it.

const CORK := Color("b07a46")
const CORK_D := Color("94622f")
const CORK_L := Color("c48d55")
const FRAME := Color("5a3818")
const FRAME_L := Color("7a4e26")
const PAPER := Color("f4ecd6")
const PAPER2 := Color("fbf7ea")
const NOTE := Color("fff1a6")       # the yellow sticky notes
const PAPER_SHADOW := Color(0.18, 0.1, 0.03, 0.45)
const PAPER_INK := Color("1d2433")
const PAPER_DIM := Color("6a6152")
const PIN_RED := Color("d8312b")
const PIN_BLUE := Color("2f6fe0")
const PIN_HI := Color("ffffff")
const WIN_COL := Color("1f8a3a")
const LOSS_COL := Color("b3261e")

const FINE := 2.0 / 3.0    # game pixels a unit (detail mode)
const T := 12              # the usual 8-pixel type, in units
const T_SMALL := 8         # small print (2 screen pixels a type pixel)
const BIG := 24            # the big type at its usual 16
const HUGE := 36           # the score
const PAPER_CREAM := Color("f3ead2")
const PAPER_WHITE := Color("fdfbf3")
const NOTEBOOK := Color("fbefb0")
const CARD := Color("fff4c2")
const RULE_BLUE := Color(0.35, 0.55, 0.9, 0.35)
const MARGIN_RED := Color(0.85, 0.25, 0.2, 0.45)
const HILITE := Color(1.0, 0.86, 0.2, 0.45)
const TAPE := Color(0.96, 0.92, 0.78, 0.75)
const WOOD_D := Color("3d2410")
const WOOD_L := Color("8a5a2e")
const PIN_GOLD := Color("e8b923")
const REVEAL := [0.0, 0.12, 0.22, 0.32, 0.42, 0.5, 0.58, 0.66]   # s: the board, the score, the stats, the notes, the four cards
const GOOD_WORDS := ["CLINICAL", "STRONG OFFENSIVE", "STRONG DEFENSIVE", "KEPT US", "DREW", "ACTIVE", "GREAT", "EXCELLENT", "CONTROLLED"]
const BAD_WORDS := ["STRUGGLED", "GAVE UP", "NEEDS WORK", "TOO MANY", "OUTPLAYED"]

var s: Dictionary
var rv: Dictionary
var done := false
var board: Control
var t_open := 0.0
static var _cork: ImageTexture = null
static var _grain: ImageTexture = null

func setup(_params: Dictionary) -> void:
	detail = true

func _process(dt: float) -> void:
	if t_open < 1.0:
		t_open += dt
		if board != null:
			board.queue_redraw()

func _ready() -> void:
	c = Game.career
	if c == null or c.last_summary.is_empty():
		Game.goto("hub")
		return
	s = c.last_summary
	rv = s.get("review", {})
	build("POSTGAME REVIEW", false, true)
	board = UI.canvas(0, 0, _draw_board)
	board.name = "Board"
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(board)
	var row := UI.hbox(4)
	row.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(row)
	var cont := UI.button("CONTINUE  >", _continue, "primary", 150, 24)
	cont.name = "Continue"
	row.add_child(cont)
	Sfx.music("menu")

func on_back() -> void:
	_continue()

## Off the board: now (and only now) maybe a coaching event, else the postgame is over.
func _continue() -> void:
	if done:
		return
	done = true
	var ev := CoachEvents.roll(c, rv) if not rv.is_empty() and c.pending_event.is_empty() else c.pending_event
	if not ev.is_empty() or not CoachEvents.unshown(c).is_empty():
		# (what the last decisions came to comes first, then the new event, on the same screen)
		c.pending_event = ev
		Game.save_career()
		Game.goto("coach_event")
		return
	c.close_postgame()
	Game.save_career()
	Game.goto("hub")

# ------------------------------------------------------------------ the board
## Units to game pixels: FINE in detail mode, 1 if it's off (the board still drawn, just larger).
func _k() -> float:
	return FINE if get_window() != null and get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS else 1.0

## How far sheet `i` has pinned up (0..1).
func _shown(i: int) -> float:
	if Game.test_mode:
		return 1.0
	return clampf((t_open - float(REVEAL[mini(i, REVEAL.size() - 1)])) / 0.14, 0.0, 1.0)

func _draw_board(ci: Control) -> void:
	var k := _k()
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var size := ci.size / k
	var r := Rect2(Vector2.ZERO, size).grow(-2.0)
	r.size -= Vector2(3, 3)
	_frame(ci, r)
	var cork := r.grow(-12.0)
	ci.draw_texture_rect(_cork_tex(), cork, true)
	# the frame's shadow on the cork's top and left
	ci.draw_rect(Rect2(cork.position, Vector2(cork.size.x, 3)), Color(0, 0, 0, 0.25))
	ci.draw_rect(Rect2(cork.position, Vector2(3, cork.size.y)), Color(0, 0, 0, 0.2))
	if rv.is_empty():
		var nr := Rect2(cork.get_center() - Vector2(130, 26), Vector2(260, 52))
		_sheet(ci, nr, PAPER_WHITE, [0.5], 1.0)
		UI.text(ci, Vector2(nr.position.x, nr.get_center().y + 4), "NO REPORT FOR THIS GAME", T, PAPER_INK, "caps", HORIZONTAL_ALIGNMENT_CENTER, nr.size.x)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# three columns: the box score, the score over the notes, the four cards
	var pad := 10.0
	var inner := cork.grow(-pad)
	var left_w := floorf(inner.size.x * 0.31)
	var right_w := floorf(inner.size.x * 0.25)
	var mid_w := inner.size.x - left_w - right_w - pad * 2.0
	var top := inner.position.y + 4.0   # (every column's top on one line, under its pins)
	var tall := inner.end.y - top
	var left := Rect2(Vector2(inner.position.x, top), Vector2(left_w, tall))
	var right := Rect2(Vector2(inner.end.x - right_w, top), Vector2(right_w, tall))
	var mid_x := left.end.x + pad
	var score_r := Rect2(Vector2(mid_x, top), Vector2(mid_w, 128))
	var notes_r := Rect2(Vector2(mid_x, score_r.end.y + pad), Vector2(mid_w, tall - score_r.size.y - pad))
	_team_sheet(ci, left, _shown(2))
	_notes(ci, notes_r, _shown(3))
	_score_sheet(ci, score_r, _shown(1))
	_players(ci, right)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The wooden frame: its shadow, the grain, a lit top-left bevel, a dark bottom-right, a nail in each corner.
func _frame(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(0, 0, 0, 0.35))
	ci.draw_texture_rect(_grain_tex(), r, true)
	ci.draw_rect(r, WOOD_D, false, 1.0)
	ci.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), WOOD_L)
	ci.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(1, r.size.y - 2)), WOOD_L)
	ci.draw_rect(Rect2(r.position + Vector2(1, r.size.y - 2), Vector2(r.size.x - 2, 1)), WOOD_D)
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 2, 1), Vector2(1, r.size.y - 2)), WOOD_D)
	var cork := r.grow(-12.0)
	ci.draw_rect(cork.grow(1.0), WOOD_D, false, 1.0)   # (the inner lip)
	for p in [r.position + Vector2(6, 6), Vector2(r.end.x - 7, r.position.y + 6), Vector2(r.position.x + 6, r.end.y - 7), r.end - Vector2(7, 7)]:
		ci.draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color("2a1a0c"))
		ci.draw_rect(Rect2(p - Vector2(1, 1), Vector2(1, 1)), Color("c9a77a"))

static func _cork_tex() -> ImageTexture:
	if _cork == null:
		var img := Image.create(96, 96, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 31
		img.fill(CORK)
		for i in 1400:
			var x := rng.randi() % 96
			var y := rng.randi() % 96
			var roll := rng.randf()
			img.set_pixel(x, y, CORK_D if roll < 0.45 else (CORK_L if roll < 0.85 else Color("7d5026")))
		for i in 14:   # (old pin holes)
			img.set_pixel(rng.randi() % 96, rng.randi() % 96, Color("4a2c12"))
		_cork = ImageTexture.create_from_image(img)
	return _cork

static func _grain_tex() -> ImageTexture:
	if _grain == null:
		var img := Image.create(128, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			var band := 0.5 + 0.5 * sin(y * 0.9) * 0.6
			for x in 128:
				var wave := sin(x * 0.07 + y * 0.6 + sin(x * 0.02) * 2.0)
				var t := clampf(0.35 + 0.25 * band + 0.2 * wave, 0.0, 1.0)
				img.set_pixel(x, y, Color("4e2f14").lerp(Color("7a4a22"), t))
		_grain = ImageTexture.create_from_image(img)
	return _grain

## A pinned sheet: a hard shadow, the paper, an edge a shade darker, a lit top line, its pins (at
## the given shares of its width), a curled corner if asked. `a`: how far it's pinned up (the
## reveal: it fades in, dropping into place).
func _sheet(ci: CanvasItem, r: Rect2, col: Color, pins: Array, a: float, pin_col: Color = PIN_RED, curl := false) -> Rect2:
	r.position.y -= (1.0 - a) * 6.0
	if a <= 0.0:
		return r
	ci.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(PAPER_SHADOW, PAPER_SHADOW.a * a))
	ci.draw_rect(r, Color(col, a))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(Color.WHITE, 0.5 * a))
	ci.draw_rect(r, Color(col.darkened(0.3), a), false, 1.0)
	if curl:
		var c0 := r.end
		ci.draw_colored_polygon(PackedVector2Array([c0 - Vector2(10, 0), c0 - Vector2(0, 10), c0]), Color(CORK_D, a))
		ci.draw_colored_polygon(PackedVector2Array([c0 - Vector2(10, 0), c0 - Vector2(0, 10), c0 - Vector2(10, 10)]), Color(col.darkened(0.12), a))
	for px in pins:
		_pin(ci, Vector2(floorf(r.position.x + r.size.x * float(px)), r.position.y + 4), pin_col, a)
	return r

## A pushpin: its shadow, the head (a darker rim, a highlight).
func _pin(ci: CanvasItem, p: Vector2, col: Color, a := 1.0) -> void:
	ci.draw_rect(Rect2(p + Vector2(-2, 1), Vector2(8, 6)), Color(0, 0, 0, 0.3 * a))         # its shadow, down and right
	ci.draw_rect(Rect2(p + Vector2(-3, -5), Vector2(8, 8)), Color(col.darkened(0.45), a))   # the rim
	ci.draw_rect(Rect2(p + Vector2(-4, -4), Vector2(10, 6)), Color(col.darkened(0.45), a))
	ci.draw_rect(Rect2(p + Vector2(-3, -4), Vector2(8, 6)), Color(col, a))                  # the head
	ci.draw_rect(Rect2(p + Vector2(-2, -5), Vector2(6, 1)), Color(col, a))
	ci.draw_rect(Rect2(p + Vector2(-2, -3), Vector2(3, 2)), Color(col.lightened(0.45), a))  # the shine
	ci.draw_rect(Rect2(p + Vector2(-2, -3), Vector2(1, 1)), Color(Color.WHITE, 0.9 * a))

func _ink(col: Color, a: float) -> Color:
	return Color(col, col.a * a)

## THE FINAL SCORE: the centrepiece.
func _score_sheet(ci: CanvasItem, r: Rect2, a: float) -> void:
	r = _sheet(ci, r, PAPER_WHITE, [0.12, 0.88], a, PIN_GOLD)
	if a <= 0.0:
		return
	var won: bool = s.get("won", false)
	var accent := WIN_COL if won else LOSS_COL
	ci.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 3)), _ink(accent, a))
	UI.text(ci, Vector2(r.position.x, r.position.y + 16), "FINAL SCORE", BIG, _ink(PAPER_INK, a), "big", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	ci.draw_rect(Rect2(r.position.x + 12, r.position.y + 25, r.size.x - 24, 1), _ink(PAPER_DIM, a * 0.6))
	var t: Dictionary = rv.team
	var opp: PoloTeam = c.teams.get(String(s.get("opp", "")))
	var teams := [c.team(), opp]
	var y := r.position.y + 30
	var g0 := int(t.g[0])
	var g1 := int(t.g[1])
	for i in 2:
		var tm: PoloTeam = teams[i]
		var row := Rect2(r.position.x + 8, y, r.size.x - 16, 26)
		var winner := (i == 0 and won) or (i == 1 and not won)
		if winner:
			ci.draw_rect(row, _ink(Color(accent, 0.1), a))
			ci.draw_rect(Rect2(row.position, Vector2(2, row.size.y)), _ink(accent, a))
		var x := row.position.x + 6
		if tm != null:
			TeamLogo.paint(ci, Vector2(x, row.position.y + 3), tm, TeamLogo.MEDIUM, 1, false)
		x += 34
		var sc := str(g0 if i == 0 else g1)
		var sw := UI.text_width(sc, HUGE, "big")
		var name := Colleges.display_name(tm.name).to_upper() if tm != null else "OPPONENT"
		UI.text(ci, Vector2(x, row.get_center().y + 4), Deck.fit(name, row.end.x - 8 - sw - 6 - x, T), T, _ink(PAPER_INK if winner else PAPER_DIM, a), "caps")
		UI.text(ci, Vector2(row.end.x - 6 - sw, row.get_center().y + 10), sc, HUGE, _ink(PAPER_INK if winner else PAPER_DIM, a), "big")
		y += 28
	# the stamp and the game's line
	var so: Array = (s.get("game", {}).get("r", {}) as Dictionary).get("so", []) if s.get("game", {}).get("r") != null else []
	var stamp := ("VICTORY" if won else "DEFEAT") + (" (SO)" if not so.is_empty() else "")
	var stw := UI.text_width(stamp, BIG, "big") + 14
	var sr := Rect2(floorf(r.get_center().x - stw * 0.5), r.end.y - 25, stw, 20)
	ci.draw_rect(sr, _ink(accent, a * 0.85), false, 2.0)
	ci.draw_rect(sr.grow(-3), _ink(accent, a * 0.35), false, 1.0)
	UI.text(ci, Vector2(sr.position.x, sr.get_center().y + 6), stamp, BIG, _ink(accent, a * 0.9), "big", HORIZONTAL_ALIGNMENT_CENTER, sr.size.x)
	var kind := String(s.get("round", "")).to_upper()
	var conf_game := opp != null and String(opp.conf) == String(c.team().conf)
	var line2 := "CONFERENCE GAME" if conf_game else "NONCONFERENCE"
	if kind.contains("CONFERENCE"):
		line2 = "AT HOME" if bool(s.get("home", false)) else "ON THE ROAD"   # (the round already says which)
	var info := "%s  -  %s" % [kind, line2] if kind != "" else line2
	UI.text(ci, Vector2(r.position.x, y + 8), Deck.fit(info, r.size.x - 20, T_SMALL), T_SMALL, _ink(PAPER_DIM, a), "caps", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

## TEAM STATS: a printed box score.
func _team_sheet(ci: CanvasItem, r: Rect2, a: float) -> void:
	r = _sheet(ci, r, PAPER_CREAM, [0.07, 0.93], a, PIN_BLUE, true)
	if a <= 0.0:
		return
	UI.text(ci, Vector2(r.position.x, r.position.y + 17), "TEAM STATS", BIG, _ink(PAPER_INK, a), "big", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	UI.text(ci, Vector2(r.position.x, r.position.y + 30), "OFFICIAL BOX SCORE", T_SMALL, _ink(PAPER_DIM, a), "caps", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var col_them := r.end.x - 10.0
	var col_us := col_them - 44.0
	var y := r.position.y + 44
	UI.text(ci, Vector2(r.position.x + 10, y), "STAT", T, _ink(PAPER_INK, a), "caps")
	UI.text(ci, Vector2(col_us - 40, y), "US", T, _ink(PAPER_INK, a), "caps", HORIZONTAL_ALIGNMENT_RIGHT, 40)
	UI.text(ci, Vector2(col_them - 40, y), "THEM", T, _ink(PAPER_INK, a), "caps", HORIZONTAL_ALIGNMENT_RIGHT, 40)
	ci.draw_rect(Rect2(r.position.x + 8, y + 5, r.size.x - 16, 2), _ink(PAPER_INK, a))
	y += 18
	var est: Array = rv.get("estimated", [])
	var t: Dictionary = rv.team
	var foot := 14.0 if not est.is_empty() else 0.0
	var step := minf(19.0, (r.end.y - 8.0 - foot - y) / Postgame.TEAM_ROWS.size())
	for row in Postgame.TEAM_ROWS:
		var key: String = row[0]
		var label: String = row[1] + ("*" if key in est else "")
		var v = t.get(key)
		# the better side, lightly highlighted (fewer is better for exclusions committed and turnovers)
		if v != null and v[0] != null and v[1] != null and int(v[0]) != int(v[1]):
			var lower_better := key in ["ex", "to"]
			var us_better := (int(v[0]) < int(v[1])) if lower_better else (int(v[0]) > int(v[1]))
			# the box round that number: as wide as it, the same margin each side, the row's own
			# band between its two rules (a few units in), so it sits centred on the figure
			var side := 0 if us_better else 1
			var txt := ("%d%%" % int(v[side])) if key == "pct" else str(int(v[side]))
			var nw := UI.text_width(txt, T, "caps")
			var cx := col_us if us_better else col_them
			var band_top := y + 6.0 - step + 2.0
			var band_bottom := y + 6.0 - 3.0
			ci.draw_rect(Rect2(floorf(cx - nw - 5.0), floorf(band_top), ceilf(nw + 10.0), floorf(band_bottom - band_top)), _ink(HILITE, a))
		UI.text(ci, Vector2(r.position.x + 10, y), label, T, _ink(PAPER_INK, a), "caps")
		for i in 2:
			var txt := "-"
			if v != null and v[i] != null:
				txt = ("%d%%" % int(v[i])) if key == "pct" else str(int(v[i]))
			var cx := col_us if i == 0 else col_them
			UI.text(ci, Vector2(cx - 40, y), txt, T, _ink(PAPER_INK if i == 0 else PAPER_DIM, a), "caps", HORIZONTAL_ALIGNMENT_RIGHT, 40)
		ci.draw_rect(Rect2(r.position.x + 8, y + 6, r.size.x - 16, 1), _ink(Color(PAPER_DIM, 0.3), a))
		y += step
	if not est.is_empty():
		UI.text(ci, Vector2(r.position.x + 10, r.end.y - 8), "* ESTIMATED (SIMULATED GAME)", T_SMALL, _ink(PAPER_DIM, a), "caps")

## The four index cards down the right: who stood out, by the game's numbers.
func _players(ci: CanvasItem, r: Rect2) -> void:
	var notes := [
		["TOP SCORER", "ball", Postgame.top_scorer(rv), func(pl): return "%d GOAL%s" % [int(pl.g), "" if int(pl.g) == 1 else "S"]],
		["TOP PLAYMAKER", "pass", Postgame.top_playmaker(rv), func(pl): return "%d ASSIST%s" % [int(pl.a), "" if int(pl.a) == 1 else "S"]],
		["TOP DEFENDER", "shield", Postgame.top_defender(rv), func(pl): return "%d STL | %d BLK" % [int(pl.st), int(pl.bl)]],
		["GOALKEEPER", "glove", Postgame.keeper(rv), func(pl): return "%d SAVE%s | %d GA" % [int(pl.sv), "" if int(pl.sv) == 1 else "S", int(pl.ga)]],
	]
	var gap := 10.0
	var h := floorf((r.size.y - gap * 3.0) / 4.0)
	var pins := [PIN_RED, PIN_BLUE, PIN_GOLD, Color("3aa655")]
	for i in notes.size():
		var a := _shown(4 + i)
		var nr := Rect2(Vector2(r.position.x, floorf(r.position.y + i * (h + gap))), Vector2(r.size.x, h))
		nr = _sheet(ci, nr, CARD, [0.5], a, pins[i])
		if a <= 0.0:
			continue
		var pad_x := 8.0
		var w := nr.size.x - pad_x * 2.0
		# the heading row under the pin: the icon, then the category
		_icon(ci, String(notes[i][1]), nr.position + Vector2(pad_x, 11), a)
		UI.text(ci, Vector2(nr.position.x + pad_x + 16, nr.position.y + 19), String(notes[i][0]), T_SMALL, _ink(PAPER_DIM, a), "caps")
		ci.draw_rect(Rect2(nr.position.x + 1, nr.position.y + 25, nr.size.x - 2, 1), _ink(Color(MARGIN_RED, 0.6), a))
		var pl: Dictionary = notes[i][2]
		var name := "NOBODY" if pl.is_empty() else String(pl.name).to_upper()
		# a long name drops to the small print rather than being cut (still sharp)
		var ns := T if UI.text_width(name, T, "caps") <= w else T_SMALL
		UI.text(ci, Vector2(nr.position.x + pad_x, nr.position.y + 37), Deck.fit(name, w, ns), ns, _ink(PAPER_INK, a), "caps")
		if not pl.is_empty():
			var stat := String(notes[i][3].call(pl))
			var ss := T if UI.text_width(stat, T, "caps") <= w else T_SMALL
			UI.text(ci, Vector2(nr.position.x + pad_x, nr.position.y + 50), Deck.fit(stat, w, ss), ss, _ink(Color("2a4a8a"), a), "caps")

## A card's little icon, 12 x 12 units: a ball, a pass (two balls and an arrow), a shield, a glove.
func _icon(ci: CanvasItem, kind: String, p: Vector2, a: float) -> void:
	var gold := _ink(Color("e8b923"), a)
	var dark := _ink(Color("8a6512"), a)
	var ink := _ink(PAPER_INK, a)
	match kind:
		"ball":
			ci.draw_rect(Rect2(p + Vector2(3, 1), Vector2(6, 10)), gold)
			ci.draw_rect(Rect2(p + Vector2(1, 3), Vector2(10, 6)), gold)
			ci.draw_rect(Rect2(p + Vector2(2, 2), Vector2(8, 8)), gold)
			ci.draw_rect(Rect2(p + Vector2(1, 5), Vector2(10, 1)), dark)
			ci.draw_rect(Rect2(p + Vector2(5, 1), Vector2(1, 10)), dark)
			ci.draw_rect(Rect2(p + Vector2(3, 3), Vector2(1, 1)), _ink(Color.WHITE, a))
		"pass":
			ci.draw_rect(Rect2(p + Vector2(0, 7), Vector2(4, 4)), gold)
			ci.draw_rect(Rect2(p + Vector2(8, 1), Vector2(4, 4)), gold)
			for k in 4:
				ci.draw_rect(Rect2(p + Vector2(3 + k, 7 - k), Vector2(1, 1)), ink)
			ci.draw_rect(Rect2(p + Vector2(6, 3), Vector2(2, 1)), ink)
			ci.draw_rect(Rect2(p + Vector2(7, 3), Vector2(1, 2)), ink)
		"shield":
			ci.draw_rect(Rect2(p + Vector2(1, 0), Vector2(10, 6)), _ink(Color("7f8899"), a))
			ci.draw_rect(Rect2(p + Vector2(2, 6), Vector2(8, 3)), _ink(Color("7f8899"), a))
			ci.draw_rect(Rect2(p + Vector2(4, 9), Vector2(4, 2)), _ink(Color("7f8899"), a))
			ci.draw_rect(Rect2(p + Vector2(2, 1), Vector2(4, 5)), _ink(Color("dde3ec"), a))
		"glove":
			ci.draw_rect(Rect2(p + Vector2(2, 4), Vector2(8, 7)), _ink(Color("d8312b"), a))
			for k in 4:
				ci.draw_rect(Rect2(p + Vector2(2 + k * 2, 0), Vector2(1, 5)), _ink(Color("d8312b"), a))
			ci.draw_rect(Rect2(p + Vector2(0, 5), Vector2(2, 3)), _ink(Color("d8312b"), a))
			ci.draw_rect(Rect2(p + Vector2(3, 9), Vector2(6, 1)), _ink(Color("8a1c16"), a))

## COACH'S NOTES: a notebook page under a strip of tape, ruled, a red margin; a tick or a mark by a
## note that reads good or bad.
func _notes(ci: CanvasItem, r: Rect2, a: float) -> void:
	r = _sheet(ci, r, NOTEBOOK, [], a)
	if a <= 0.0:
		return
	ci.draw_rect(Rect2(r.get_center().x - 22, r.position.y - 5, 44, 11), _ink(TAPE, a))   # (the tape)
	var top := r.position.y + 34
	for ly in range(int(top), int(r.end.y) - 4, 14):
		ci.draw_rect(Rect2(r.position.x + 2, ly, r.size.x - 4, 1), _ink(RULE_BLUE, a))
	ci.draw_rect(Rect2(r.position.x + 18, r.position.y + 2, 1, r.size.y - 4), _ink(MARGIN_RED, a))
	UI.text(ci, Vector2(r.position.x, r.position.y + 17), "COACH'S NOTES", BIG, _ink(PAPER_INK, a), "big", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var y := top + 11
	for n in rv.get("notes", []):
		var text := String(n)
		var mark := 0
		for w in GOOD_WORDS:
			mark = 1 if text.contains(w) else mark
		for w in BAD_WORDS:
			mark = -1 if text.contains(w) else mark
		var first := true
		for ln in _wrap(text, r.size.x - 34.0):
			if y > r.end.y - 4.0:
				return
			if first and mark == 1:
				# a green tick
				var p := Vector2(r.position.x + 6, y - 6)
				for k2 in 3:
					ci.draw_rect(Rect2(p + Vector2(k2, 3 + k2), Vector2(1, 1)), _ink(WIN_COL, a))
				for k2 in 5:
					ci.draw_rect(Rect2(p + Vector2(3 + k2, 5 - k2), Vector2(1, 1)), _ink(WIN_COL, a))
			elif first and mark == -1:
				ci.draw_rect(Rect2(r.position.x + 7, y - 6, 2, 6), _ink(LOSS_COL, a))
				ci.draw_rect(Rect2(r.position.x + 7, y + 1, 2, 2), _ink(LOSS_COL, a))
			elif first:
				ci.draw_rect(Rect2(r.position.x + 8, y - 3, 3, 3), _ink(PAPER_INK, a))
			UI.text(ci, Vector2(r.position.x + 24, y), String(ln), T, _ink(PAPER_INK, a), "caps")
			if first and mark == -1:
				ci.draw_rect(Rect2(r.position.x + 24, y + 3, minf(UI.text_width(String(ln), T, "caps"), r.size.x - 30), 1), _ink(Color(LOSS_COL, 0.5), a))
			first = false
			y += 14.0

## Words into lines no wider than `w` in the caps type the notes are written in.
func _wrap(t: String, w: float) -> Array:
	var out: Array = []
	var line := ""
	for word in t.split(" ", false):
		var next := word if line == "" else line + " " + word
		if line != "" and UI.text_width(next, T, "caps") > w:
			out.append(line)
			line = word
		else:
			line = next
	if line != "":
		out.append(line)
	return out
