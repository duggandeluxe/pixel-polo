class_name HalftimePanel
extends RefCounted
## The halftime break's MID-GAME ADJUSTMENT. Under the HALFTIME card, a yellow button
## opens it (only at halftime, only until you've decided: MatchFlow.can_adjust). Left: the four
## drops, the one you're on highlighted, the pick's description and CONFIRM ADJUSTMENT. Right:
## their first half (MatchFlow.half_stats, frozen at the end of Q2). Nothing changes until you
## confirm (MatchFlow.adjust_drop); once it's open, Q3 can't start until you do, and once you have
## the button is gone for the match. The decision is only which drop your bar offers: no
## formation plays any differently.

const BTN := Vector2(184, 26)       # the card's button
const MARGIN := 8.0
const GAP := 8.0
const DROP_H := 28.0
const CONFIRM_H := 30.0
const ROW_H := 15.0

var open := false
var pick := -1                       # the drop picked on the panel, not yet confirmed
var button := Rect2()                # the card's button, while it's up
var drops: Array[Rect2] = []         # the four drops (DefenseFormation.DROPS' order)
var confirm := Rect2()

## The button under the halftime card (`card`: Hud.break_card's rect). Before the decision it's
## the way in; after it, a plain note of your second-half drop.
func draw_button(ci: CanvasItem, size: Vector2, card: Rect2, flow: MatchFlow) -> void:
	button = Rect2(roundf((size.x - BTN.x) / 2.0), card.end.y + 6.0, BTN.x, BTN.y)
	if flow.can_adjust():
		var lit := int(Time.get_ticks_msec() / 400) % 2 == 0
		Deck.frame(ci, button, UI.GOLD.lightened(0.1) if lit else UI.GOLD, UI.BORDER, false, UI.BEVEL_RAISED)
		Deck.ctext(ci, button, "MID-GAME ADJUSTMENT", 8, UI.INK)
	elif flow.adjusted:
		Deck.frame(ci, button, Deck.NAVY, Color(1, 1, 1, 0.45))
		Deck.ctext(ci, button, "2ND HALF: %s" % DefenseFormation.NAMES[flow.drop], 8, UI.GOLD)

## A tap at halftime: true if the adjustment took it (open, a pick, the confirm, or anything at
## all while it's open: Q3 waits for the confirm).
func tap(pos: Vector2, flow: MatchFlow) -> bool:
	if open:
		for i in drops.size():
			if drops[i].has_point(pos):
				pick = DefenseFormation.DROPS[i]
				Sfx.play("click")
				return true
		if confirm.has_point(pos) and flow.adjust_drop(pick):
			open = false
			Sfx.play("click")
			Sfx.play("whistle", 1.5, -14.0)
		return true
	if flow.can_adjust() and button.grow(1.0).has_point(pos):
		open = true
		pick = flow.drop
		Sfx.play("click")
		return true
	return false

func draw(ci: CanvasItem, size: Vector2, flow: MatchFlow) -> void:
	if not open:
		return
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.1, 0.75))
	var w := floorf((size.x - MARGIN * 2.0 - GAP) / 2.0)
	var h := size.y - MARGIN * 2.0
	_left(ci, Rect2(MARGIN, MARGIN, w, h), flow)
	_right(ci, Rect2(MARGIN + w + GAP, MARGIN, w, h), flow)

# ------------------------------------------------------------------ left: the decision
func _left(ci: CanvasItem, r: Rect2, flow: MatchFlow) -> void:
	Deck.frame(ci, r, Deck.NAVY, UI.BORDER, false, UI.BEVEL_SOFT)
	var x := r.position.x + 8.0
	var iw := r.size.x - 16.0
	var y := r.position.y + 13.0
	title(ci, x, y, "MID-GAME ADJUSTMENT", iw)
	y += 14.0
	Deck.text(ci, x, y, "1ST HALF: %s" % DefenseFormation.NAMES[flow.first_drop], 8, UI.DIM)
	y += 9.0
	drops.clear()
	var bw := floorf((iw - 6.0) / 2.0)
	for i in DefenseFormation.DROPS.size():
		var f: int = DefenseFormation.DROPS[i]
		var b := Rect2(x + (i % 2) * (bw + 6.0), y + floorf(i / 2.0) * (DROP_H + 5.0), bw, DROP_H)
		drops.append(b)
		var on := f == pick
		Deck.frame(ci, b, UI.GOLD if on else Deck.NAVY_HEAD, UI.BORDER, false, UI.BEVEL_DOUBLE if on else UI.BEVEL_RAISED)
		Deck.ctext(ci, b, DefenseFormation.NAMES[f], 8, UI.INK if on else UI.TEXT)
	y += DROP_H * 2.0 + 12.0
	for line in wrap_text(String(DefenseFormation.DROP_TEXT.get(pick, "")), iw):
		Deck.text(ci, x, y, line, 8, UI.TEXT, "body")
		y += 10.0
	confirm = Rect2(x, r.end.y - 8.0 - CONFIRM_H, iw, CONFIRM_H)
	Deck.text(ci, x, confirm.position.y - 9.0, "2ND HALF: %s" % DefenseFormation.NAMES[pick], 8, UI.GOLD)
	Deck.frame(ci, confirm, UI.GOLD, UI.BORDER, false, UI.BEVEL_RAISED)
	Deck.ctext(ci, confirm, "CONFIRM ADJUSTMENT", 16, UI.INK, "big")

## "HALFTIME  BRONX 7 - 5 ERIE" in `w` px: the longest of these that fits, so the score always
## shows whole: the short names (Colleges.short_name), then without HALFTIME, then the mascots.
static func score_line(us: PoloTeam, them: PoloTeam, sc: Array, w: float) -> String:
	var a := Colleges.short_name(us).to_upper()
	var b := Colleges.short_name(them).to_upper()
	var tries := ["HALFTIME  %s %d - %d %s" % [a, sc[0], sc[1], b], "%s %d - %d %s" % [a, sc[0], sc[1], b],
		"%s %d - %d %s" % [us.mascot.to_upper(), sc[0], sc[1], them.mascot.to_upper()]]
	for t in tries:
		if Deck.text_w(t) <= w:
			return t
	return Deck.fit(tries[tries.size() - 1], w)

# ------------------------------------------------------------------ right: their first half
func _right(ci: CanvasItem, r: Rect2, flow: MatchFlow) -> void:
	Deck.frame(ci, r, Deck.NAVY, UI.BORDER, false, UI.BEVEL_SOFT)
	var x := r.position.x + 8.0
	var iw := r.size.x - 16.0
	var y := r.position.y + 13.0
	title(ci, x, y, "OPPONENT FIRST-HALF STATS", iw)
	y += 12.0
	var st: Dictionary = flow.half_stats if not flow.half_stats.is_empty() else flow.opp_stats()
	TeamLogo.paint(ci, Vector2(x, y), flow.them, TeamLogo.MEDIUM)
	var lx := TeamLogo.box(TeamLogo.MEDIUM).x + 6.0
	Deck.text(ci, x + lx, y + 6.0, Deck.fit(flow.them.name.to_upper(), iw - lx, 8), 8, UI.TEXT)
	var sc: Array = st.score
	Deck.text(ci, x + lx, y + 16.0, score_line(flow.us, flow.them, sc, iw - lx), 8, UI.GOLD)
	y += 28.0
	var rows := [["CENTER GOALS", str(st.centre)], ["PERIMETER GOALS", str(st.perimeter)], ["TOTAL SHOTS", str(st.shots)],
		["SHOOTING %", "%d%%" % st.pct], ["EXCLUSIONS DRAWN", str(st.exclusions)], ["5-METER PENALTIES DRAWN", str(st.penalties)]]
	for row in rows:
		ci.draw_rect(Rect2(x, y, iw, 1), Color(1, 1, 1, 0.25))
		Deck.text(ci, x, y + ROW_H * 0.5 + 1.0, String(row[0]), 8, UI.TEXT)
		Deck.text(ci, x, y + ROW_H * 0.5 + 1.0, String(row[1]), 8, UI.GOLD, "caps", HORIZONTAL_ALIGNMENT_RIGHT, iw)
		y += ROW_H
	ci.draw_rect(Rect2(x, y, iw, 1), Color(1, 1, 1, 0.25))

## A panel's title: the big font when it fits in `w`, the small caps when it doesn't.
static func title(ci: CanvasItem, x: float, y: float, t: String, w: float) -> void:
	if Deck.text_w(t, 16, "big") <= w:
		Deck.text(ci, x, y, t, 16, UI.ACCENT, "big")
	else:
		Deck.text(ci, x, y, t, 8, UI.ACCENT)

## `text` in lines no wider than `w` (the body font at 8).
static func wrap_text(text: String, w: float) -> Array:
	text = Loc.t(text)   # (the player's LANGUAGE: translated whole, then wrapped)
	var out: Array = []
	var line := ""
	for word: String in Loc.units(text):
		var trial := word if line == "" else line + Loc.gap() + word
		if UI.text_width(trial, 8) > w and line != "":
			out.append(line)
			line = word
		else:
			line = trial
	if line != "":
		out.append(line)
	return out
