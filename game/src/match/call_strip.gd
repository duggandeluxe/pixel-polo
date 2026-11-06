class_name CallStrip
extends RefCounted
## DRIVE▾, your play call: a big button right on top of the shooting stick opens a strip of
## three calls beside it. Pick a side and that man drives at the goal now; pass to him in
## stride. While the strip is open the pool slows and L / M / R tags show who'd go. DRIVE never
## shoots and the stick never calls: their touch areas never meet (GAP).

const SIDES := ["left", "middle", "right"]
const LABELS := {"left": "LEFT", "middle": "MIDDLE", "right": "RIGHT"}
const TAGS := {"left": "L", "middle": "M", "right": "R"}
const ROW_W := 72.0
const ROW_H := 18.0
const BUTTON := Vector2(75, 29)   # half as big again as it was (50 x 19)
const GAP := 5.0                  # between it and the stick's touch area under it

var open := false
var button := Rect2()
var rows := {}               # side -> Rect2

## Lays the button out centred on top of the shooting stick, `stick` its touch area
## (ShotStick.area), with the strip beside it to the right, clear of the stick (call every frame
## before drawing).
func layout(stick: Rect2) -> void:
	button = Rect2(roundf(stick.get_center().x - BUTTON.x / 2.0), roundf(stick.position.y - GAP - BUTTON.y), BUTTON.x, BUTTON.y)
	rows.clear()
	for i in SIDES.size():
		rows[SIDES[i]] = Rect2(button.end.x + 3, button.position.y + i * (ROW_H + 2), ROW_W, ROW_H)

## Can you call a drive right now?
static func available(p: Play) -> bool:
	return p != null and not p.over and p.man_up <= 0.0 and p.kind != Play.Kind.PENALTY \
		and p.holder != null and p.holder.side == Swimmer.Side.US

## A touch went down at `pos`. Returns "" if it isn't ours (the screen carries on with it),
## "menu" if it opened/closed the strip or was swallowed, or the side that was called.
func press(pos: Vector2, p: Play) -> String:
	if not available(p):
		open = false
		return ""
	if button.has_point(pos):
		open = not open
		Sfx.play("click")
		return "menu"
	if not open:
		return ""
	for side in SIDES:
		if (rows[side] as Rect2).has_point(pos) and p.drive_candidate(side) != null:
			open = false
			p.call_drive(side)
			Sfx.play("whistle", 1.4, -10.0)
			return side
	open = false   # a tap anywhere else just closes it
	return "menu"

func draw(ci: CanvasItem, v: PoolView, p: Play, t: float) -> void:
	if not available(p):
		open = false
		return
	_draw_button(ci, button, "DRIVE", open, true)
	if not open:
		return
	for side in SIDES:
		var who := p.drive_candidate(side)
		var r: Rect2 = rows[side]
		_draw_button(ci, r, LABELS[side], false, who != null, side)
		if who != null:
			# a tag over the man who'd go
			var hp := v.to_screen(who.pos) + Vector2(-4, -36 - (1 if int(t * 4.0) % 2 == 0 else 0))
			ci.draw_rect(Rect2(hp, Vector2(9, 9)), PoolArt.INK)
			ci.draw_rect(Rect2(hp + Vector2(1, 1), Vector2(7, 7)), UI.GOLD)
			UI.text(ci, hp + Vector2(0, 8), TAGS[side], 8, PoolArt.INK, "caps", HORIZONTAL_ALIGNMENT_CENTER, 9)

## A dark HUD button; `arrow` is "" (a ▾ for the menu button), "left" (▲), "middle" (►) or "right" (▼).
## The big DRIVE button has its word centred in the space left of the arrow.
func _draw_button(ci: CanvasItem, r: Rect2, text: String, lit: bool, enabled: bool, arrow: String = "") -> void:
	ci.draw_rect(r, Color(0, 0, 0, 0.55) if not lit else Color(Hud.CARD, 0.95))
	ci.draw_rect(r, UI.GOLD if lit else Hud.LINE, false, 1.0)
	var col := UI.TEXT if enabled else Hud.DIM
	if r.size.y > ROW_H + 2.0:
		UI.text(ci, r.position + Vector2(2, roundf(r.size.y / 2.0) + 3), text, 8, col, "caps", HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16)
	else:
		UI.text(ci, r.position + Vector2(4, r.size.y - 6), text, 8, col, "caps")
	var c := Vector2(r.end.x - 8, r.position.y + r.size.y / 2.0)
	var tri: PackedVector2Array
	match arrow:
		"left":
			tri = [c + Vector2(-3, 2), c + Vector2(3, 2), c + Vector2(0, -3)]
		"right":
			tri = [c + Vector2(-3, -2), c + Vector2(3, -2), c + Vector2(0, 3)]
		"middle":
			tri = [c + Vector2(-2, -3), c + Vector2(-2, 3), c + Vector2(3, 0)]
		_:
			tri = [c + Vector2(-3, -1), c + Vector2(3, -1), c + Vector2(0, 2)]
	ci.draw_colored_polygon(tri, UI.GOLD if enabled else Hud.DIM)
