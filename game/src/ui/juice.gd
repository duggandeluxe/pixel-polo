class_name Juice
extends RefCounted
## Small, quick menu motion: things fade and settle in, purchases pop, totals count up.
## Off with Settings > Reduce motion, and in tests. Only scale and modulate move (containers own
## position and size), so a layout pass mid-animation can't leave anything out of place.

const IN_TIME := 0.16
const STAGGER := 0.035
const MAX_DELAY := 0.25

static func enabled() -> bool:
	return not Game.test_mode and not bool(Game.settings.get("reduce_motion", false))

## Fades a control in from 96% size; i staggers a list (capped so long lists don't drag).
static func enter(n: Control, i: int = 0) -> void:
	if not enabled() or not is_instance_valid(n):
		return
	var delay := minf(i * STAGGER, MAX_DELAY)
	n.modulate.a = 0.0
	n.scale = Vector2(0.96, 0.96)
	_center_pivot(n)
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "modulate:a", 1.0, IN_TIME).set_delay(delay)
	tw.tween_property(n, "scale", Vector2.ONE, IN_TIME).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## A quick pop for something you just bought or unlocked.
static func pop(n: Control, amount: float = 0.12) -> void:
	if not enabled() or not is_instance_valid(n):
		return
	_center_pivot(n)
	n.scale = Vector2.ONE * (1.0 + amount)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Counts a button's or label's number from `from` to `to` (the credits chip after a purchase).
static func count(n: Control, from: int, to: int, fmt: String = "%d") -> void:
	if not is_instance_valid(n):
		return
	if not enabled() or from == to:
		n.set("text", fmt % to)
		return
	var tw := n.create_tween()
	tw.tween_method(func(v: float): n.set("text", fmt % int(round(v))), float(from), float(to), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

static func _center_pivot(n: Control) -> void:
	n.pivot_offset = n.size * 0.5
	if n.size == Vector2.ZERO:
		# not laid out yet: centre once it has a size
		n.resized.connect(func(): n.pivot_offset = n.size * 0.5, CONNECT_ONE_SHOT)
