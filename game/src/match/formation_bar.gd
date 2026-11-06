class_name FormationBar
extends RefCounted
## Your defence's formation call, along the bottom of the screen while they attack: PRESS and
## your gameplan's drop (MatchFlow.user_formations: Coaching's pick, or your halftime decision
## for Q3 and Q4), two big buttons in a row, tall (H_SHARE of the pool's height on screen) and
## as wide as the room right of your keeper's tag gives them, to W_MAX. The other three drops
## aren't on it at all. All of every button is its touch area (hit: the rects drawn, and a pixel). Every possession starts on PRESS,
## not yet picked (it shows with a gold outline); tap one and it's picked and locked, filled
## gold, the other dimmed, until the ball changes hands. While their shot is coming (the
## wind-up, the shot) a tap is your dive, never a call: the bar fades and lets it through.

const H_SHARE := 0.15          # of the pool's height on screen (270 px high: 37 px)...
const H_MIN := 26.0            # ...within these (the old bar was 13)
const H_MAX := 44.0
const W_MAX := 96.0
const BUTTONS := 2             # PRESS, your drop
const GAP := 3.0
const PAD := 8.0               # text padding inside a button
const MARGIN := 3.0            # off the bottom and right edges

var rects: Array[Rect2] = []

## Laid out bottom right, from `left` (the end of your keeper's tag, bottom left) to the right
## edge, every frame before drawing. The screen, never the pool: the camera doesn't move it.
func layout(size: Vector2, insets: Vector2, left: float = 0.0) -> void:
	rects.clear()
	var w := 0.0
	for n in DefenseFormation.NAMES:
		w = maxf(w, UI.text_width(n, 8, "caps") + PAD)
	var right := size.x - insets.y - MARGIN
	var n := BUTTONS
	w = clampf(floorf((right - left - GAP * (n - 1)) / n), w, W_MAX)
	var h := clampf(roundf((size.y - PoolView.HUD_H) * H_SHARE), H_MIN, H_MAX)
	var x := roundf(right - (w * n + GAP * (n - 1)))
	var y := roundf(size.y - MARGIN - h)
	for i in n:
		rects.append(Rect2(x + i * (w + GAP), y, w, h))

## The top of the bar (the hint line goes above it), or the screen's bottom when it's not up.
func top(size: Vector2) -> float:
	return rects[0].position.y if not rects.is_empty() else size.y

## Is the bar up: your defence, their attack in play (not a penalty, not after the whistle).
static func shown(flow: MatchFlow) -> bool:
	var p := flow.play
	return flow.phase == MatchFlow.Phase.DEFENSE and p != null and p.defending and not p.over \
		and p.kind != Play.Kind.PENALTY and p.defenders.size() == 6

## Their shot's coming: taps are dives.
static func standing_down(flow: MatchFlow) -> bool:
	return flow.can_dive() or flow.duel != null

## Which button `pos` is on (-1: none): 0 PRESS, 1 your drop.
func hit(pos: Vector2) -> int:
	for i in rects.size():
		if rects[i].grow(1.0).has_point(pos):
			return i
	return -1

## A touch went down at `pos`: true if the bar took it (a pick, or a tap on the bar once it's
## locked, swallowed so it doesn't do anything else). Never while a dive is on.
func press(pos: Vector2, flow: MatchFlow) -> bool:
	if not shown(flow) or standing_down(flow):
		return false
	var i := hit(pos)
	if i < 0:
		return false
	if flow.select_formation(flow.user_formations()[i]):
		Sfx.play("click")
		Sfx.play("whistle", 1.5, -14.0)
	return true

func draw(ci: CanvasItem, flow: MatchFlow, t: float) -> void:
	if not shown(flow) or rects.is_empty():
		return
	var p := flow.play
	var fade := 0.35 if standing_down(flow) else 1.0
	var forms := flow.user_formations()
	for i in rects.size():
		var r := rects[i]
		var f: int = forms[i]
		var picked := p.formation_locked and (p.formation == f or p.drop_pending == f)
		var open := not p.formation_locked
		var pending := open and p.formation == f   # PRESS, not picked yet
		var fill := Color(UI.GOLD, 0.95 * fade) if picked else Color(Hud.CARD, (0.9 if open else 0.55) * fade)
		ci.draw_rect(r, fill)
		var edge := Hud.LINE
		if picked:
			edge = UI.INK
		elif pending:
			edge = UI.GOLD if int(t * 2.5) % 2 == 0 else Color(UI.GOLD, 0.6)
		ci.draw_rect(r, Color(edge, fade), false, 1.0)
		var col := UI.INK if picked else (UI.TEXT if open else Hud.DIM)
		UI.text(ci, r.position + Vector2(0, roundf(r.size.y / 2.0) + 3), DefenseFormation.NAMES[f], 8, Color(col, fade), "caps",
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
