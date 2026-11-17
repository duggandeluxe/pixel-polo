class_name FormationBar
extends RefCounted
## Your defence's one control while they attack: CALL DROP, a single big button bottom right (as
## wide as the room right of your keeper's tag gives it, to W_MAX; H_SHARE of the pool's height on
## screen). Every possession starts in your normal defence (PRESS) with the button up; tap it and
## your gameplan's drop is called (MatchFlow.user_formations()[1]: Coaching's pick, or your halftime
## decision for Q3 and Q4), whichever drop that is: the label never changes. It's a one-way call,
## not a toggle: the button stays down (deeper blue, cyan edge, a check) for the rest of the
## possession, and another tap does nothing. A new possession (a new Play) brings it back up.
## A 6 on 5 (an exclusion, man_up) takes it off the screen altogether, called or not: that defence
## is the exclusion's own (PlaySetup, PlayAI), automatic. When it's even again and you're still
## defending, it's back, up (Play._reopen_call). All of the button is its touch area (hit). While
## their shot is coming (the wind-up, the shot) a tap is your dive, never a call: it fades and lets
## it through.

const H_SHARE := 0.15          # of the pool's height on screen (270 px high: 37 px)...
const H_MIN := 26.0            # ...within these
const H_MAX := 44.0
const W_MAX := 124.0           # one button, bigger than the old PRESS | M-DROP pair's each (96)
const BUTTONS := 1
const LABEL := "CALL DROP"
const PAD := 30.0              # room for the icon and the edges around the label
const MARGIN := 3.0            # off the bottom and right edges
const DEPTH := 2.0             # px of raised edge under the button; pressed, it sinks by this
const FLASH := 0.24            # s of the call's flash, in three hard steps

# the button's own palette (navy and electric blue, the HUD's family)
const NAVY := Color("0f1d4d")
const NAVY_DOWN := Color("071447")
const SHADE := Color("040a1f")
const BLUE := Color("2f8cff")
const BLUE_HI := Color("8fd0ff")
const CYAN := Color("4ff0ff")
const WHITE := Color("f4f8ff")

# pixel icons, 9 wide: '#' edge, 'o' mark, '.' nothing
const SHIELD := ["#########", "#.......#", "#...o...#", "#...o...#", "#.ooooo.#",
	"#..ooo..#", ".#..o..#.", "..#...#..", "...#.#...", "....#...."]
const CHECK := [".......oo", "......oo.", ".....oo..", "o...oo...", "oo.oo....",
	".ooo.....", "..o......"]

var rects: Array[Rect2] = []
var _flash_play: Play = null   # the possession whose call has flashed (once each)
var _flash_t0 := -INF

## Laid out bottom right, from `left` (the end of your keeper's tag, bottom left) to the right
## edge, every frame before drawing. The screen, never the pool: the camera doesn't move it.
func layout(size: Vector2, insets: Vector2, left: float = 0.0) -> void:
	rects.clear()
	var right := size.x - insets.y - MARGIN
	var w := clampf(floorf(right - left), UI.text_width(LABEL, 8, "caps") + PAD, W_MAX)
	var h := clampf(roundf((size.y - PoolView.HUD_H) * H_SHARE), H_MIN, H_MAX)
	rects.append(Rect2(roundf(right - w), roundf(size.y - MARGIN - h), w, h))

## The top of the button (the hint line goes above it), or the screen's bottom when it's not up.
func top(size: Vector2) -> float:
	return rects[0].position.y if not rects.is_empty() else size.y

## Is the button up: your defence, their attack in play at even strength (not a penalty, not
## after the whistle, not a 6 on 5).
static func shown(flow: MatchFlow) -> bool:
	var p := flow.play
	return flow.phase == MatchFlow.Phase.DEFENSE and p != null and p.defending and not p.over \
		and p.kind != Play.Kind.PENALTY and p.defenders.size() == 6 and p.man_up <= 0.0 and p.excluded == null

## The drop's called this possession (or on: SIM called it before you took over).
static func called(p: Play) -> bool:
	return p.formation_locked or p.drop_pending >= 0 or DefenseFormation.is_drop(p.formation)

## Their shot's coming: taps are dives.
static func standing_down(flow: MatchFlow) -> bool:
	return flow.can_dive() or flow.duel != null

## Which button `pos` is on (-1: none): 0 CALL DROP.
func hit(pos: Vector2) -> int:
	for i in rects.size():
		if rects[i].grow(1.0).has_point(pos):
			return i
	return -1

## A touch went down at `pos`: true if the button took it (the call, or a tap once it's called,
## swallowed so it doesn't do anything else). Never while a dive is on.
func press(pos: Vector2, flow: MatchFlow) -> bool:
	if not shown(flow) or standing_down(flow):
		return false
	if hit(pos) < 0:
		return false
	var p := flow.play
	if called(p):
		p.formation_locked = true   # (already on: it stays on, and stays yours)
		return true
	if flow.select_formation(flow.user_formations()[1]):
		Sfx.play("click")
		Sfx.play("whistle", 1.5, -14.0)
	return true

func draw(ci: CanvasItem, flow: MatchFlow, t: float) -> void:
	if not shown(flow) or rects.is_empty():
		return
	var p := flow.play
	var on := called(p)
	if on and _flash_play != p:
		_flash_play = p
		_flash_t0 = t
	elif not on and _flash_play == p:
		_flash_play = null   # (called off by a 6 on 5: the next call flashes again)
	var fade := 0.35 if standing_down(flow) else 1.0
	var r := rects[0]
	var sink := DEPTH if on else 0.0
	var body := Rect2(r.position + Vector2(0, sink), Vector2(r.size.x, r.size.y - DEPTH))
	# the raised edge underneath (pressed, the button sits down on it)
	ci.draw_rect(Rect2(r.position.x, r.end.y - DEPTH - 1.0, r.size.x, DEPTH + 1.0), Color(SHADE, 0.95 * fade))
	ci.draw_rect(body, Color(NAVY_DOWN if on else NAVY, 0.95 * fade))
	# thick pixel border: a dark rim, then the colour band two pixels deep
	ci.draw_rect(body, Color(SHADE, fade), false, 1.0)
	var edge := CYAN if on else BLUE
	_frame(ci, body.grow(-1.0), Color(edge, fade))
	_frame(ci, body.grow(-2.0), Color(edge, 0.55 * fade))
	if on:   # pressed: the shadow falls across the top inside
		ci.draw_rect(Rect2(body.position + Vector2(3, 3), Vector2(body.size.x - 6, 1)), Color(SHADE, 0.7 * fade))
	else:    # raised: a lit top edge, a shaded bottom one
		ci.draw_rect(Rect2(body.position + Vector2(3, 3), Vector2(body.size.x - 6, 1)), Color(BLUE_HI, 0.8 * fade))
		ci.draw_rect(Rect2(body.position.x + 3, body.end.y - 4, body.size.x - 6, 1), Color(SHADE, 0.6 * fade))
	# the icon left (the shield and its arrow; called, the check), the label in the rest
	var icon: Array = CHECK if on else SHIELD
	var ix := body.position.x + 7.0
	var iy := roundf(body.position.y + (body.size.y - icon.size()) / 2.0)
	_pixels(ci, Vector2(ix, iy), icon, Color(BLUE, fade), Color(UI.GOLD if on else WHITE, fade))
	var tx := ix + 9.0 + 3.0
	UI.text(ci, Vector2(tx, roundf(body.position.y + body.size.y / 2.0) + 3), LABEL, 8, Color(WHITE, fade), "caps",
		HORIZONTAL_ALIGNMENT_CENTER, body.end.x - 4.0 - tx)
	# the call's flash: once, white, three hard steps down (no glow, no easing)
	var since := t - _flash_t0
	if on and _flash_play == p and since >= 0.0 and since < FLASH:
		var step := int(since / (FLASH / 3.0))
		ci.draw_rect(body, Color(WHITE, [0.75, 0.4, 0.15][mini(step, 2)] * fade))
		_frame(ci, body.grow(1.0 + step * 2.0), Color(CYAN, (1.0 - step * 0.3) * fade))

## A one-pixel frame inside `r`.
static func _frame(ci: CanvasItem, r: Rect2, c: Color) -> void:
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), c)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), c)
	ci.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), c)
	ci.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), c)

## A pixel icon at `at`, one pixel a character.
static func _pixels(ci: CanvasItem, at: Vector2, rows: Array, edge: Color, mark: Color) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var c := row[x]
			if c == "#":
				ci.draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), edge)
			elif c == "o":
				ci.draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), mark)
