class_name TouchScroll
extends ScrollContainer
## A scroll list you can drag from anywhere, including on top of its buttons.
## Buttons take the press, so a plain ScrollContainer never sees a drag that starts on a row.
## This watches the pointer itself: past the deadzone the drag scrolls and the pressed button is cancelled.
##
## A phone reports one finger twice: as ScreenTouch/ScreenDrag and as the mouse events Godot emulates from them
## (a desktop mouse does the reverse). Both kinds are read here. Every update sets the scroll from the finger's
## absolute position, so seeing the same finger twice changes nothing, and the list still scrolls if either
## kind never arrives. ScrollContainer's own touch drag is switched off so only this one moves the list.

const DEADZONE := 6.0          # viewport pixels before a press becomes a drag
const FRICTION := 5.0          # fling slows by this factor per second
const MIN_FLING := 12.0        # px/s below which the fling stops
const FLING_STALE_MS := 90     # a finger that sat still this long before lifting doesn't fling
const SAME_FINGER_PX := 4.0    # a touch and its emulated mouse press land this close
const NO_NATIVE_DRAG := 1000000

static var _live: Array = []   # every TouchScroll in the tree, to find the innermost list under a finger

var _tracking := false         # a finger went down inside this list
var _dragging := false
var _touch_index := -1         # which finger (ScreenTouch index); -1 until a touch event confirms it
var _press_at := Vector2.ZERO  # where the finger first landed
var _start := Vector2.ZERO     # the list follows the finger 1:1 from here
var _start_scroll := 0
var _velocity := 0.0           # px/s, positive = content moves up
var _last_y := 0.0
var _last_ms := 0

func _enter_tree() -> void:
	_live.append(self)

func _exit_tree() -> void:
	_live.erase(self)

func _ready() -> void:
	set_process(false)
	scroll_deadzone = NO_NATIVE_DRAG

func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_press(ev.position, -1)
			elif _tracking:
				_end(ev.canceled)
	elif ev is InputEventScreenTouch:
		if ev.pressed:
			_press(ev.position, ev.index)
		elif _tracking and ev.index == _touch_index:
			_end(ev.canceled)
	elif ev is InputEventMouseMotion:
		if _tracking:
			if ev.button_mask & MOUSE_BUTTON_MASK_LEFT:
				_move(ev.position)
			elif _touch_index < 0:
				_end(true)  # the release was missed (let go outside the window)
	elif ev is InputEventScreenDrag:
		if _tracking and ev.index == _touch_index:
			_move(ev.position)

func _press(pos: Vector2, index: int) -> void:
	if _tracking:
		# The same finger again: the mouse press emulated from a touch, or the touch emulated from a mouse.
		if index >= 0 and _touch_index < 0 and not _dragging and pos.distance_to(_press_at) < SAME_FINGER_PX:
			_touch_index = index
		return
	if not _owns(pos):
		return
	_tracking = true
	_dragging = false
	_touch_index = index
	_press_at = pos
	_start = pos
	_start_scroll = scroll_vertical
	_velocity = 0.0
	_last_y = pos.y
	_last_ms = Time.get_ticks_msec()
	set_process(false)

func _move(pos: Vector2) -> void:
	if not _dragging:
		if absf(pos.y - _start.y) <= DEADZONE:
			return
		_dragging = true
		_cancel_presses()
	var now := Time.get_ticks_msec()
	if now > _last_ms:
		_velocity = lerpf(_velocity, -(pos.y - _last_y) * 1000.0 / (now - _last_ms), 0.4)
		_last_y = pos.y
		_last_ms = now
	scroll_vertical = _start_scroll - int(pos.y - _start.y)

func _end(canceled: bool) -> void:
	var was_dragging := _dragging
	_tracking = false
	_dragging = false
	_touch_index = -1
	if not was_dragging:
		return
	if canceled or Time.get_ticks_msec() - _last_ms > FLING_STALE_MS:
		_velocity = 0.0
	set_process(absf(_velocity) > MIN_FLING)

func _process(dt: float) -> void:
	var before := scroll_vertical
	scroll_vertical = before + int(round(_velocity * dt))
	_velocity *= maxf(0.0, 1.0 - FRICTION * dt)
	if absf(_velocity) < MIN_FLING or (scroll_vertical == before and absf(_velocity * dt) >= 1.0):
		set_process(false)

func _max_scroll() -> int:
	return int(get_v_scroll_bar().max_value - get_v_scroll_bar().page)

## Whether a finger landing here is this list's to scroll: inside it, something to scroll, not on the
## scrollbar, not under a popup, and no list nested inside this one wants the same finger.
func _owns(pos: Vector2) -> bool:
	if not _takes(pos):
		return false
	for o in _live:
		if o != self and is_ancestor_of(o) and o._takes(pos):
			return false
	return true

func _takes(pos: Vector2) -> bool:
	if not is_visible_in_tree() or not get_global_rect().has_point(pos) or _max_scroll() <= 0:
		return false
	var bar := get_v_scroll_bar()
	if bar.visible and bar.get_global_rect().has_point(pos):
		return false
	return not _covered(pos)

## Godot's own way to tell buttons "a scroll started": they drop the press and won't fire on release.
func _cancel_presses() -> void:
	propagate_notification(NOTIFICATION_SCROLL_BEGIN)

## True when something drawn later (a popup or overlay) sits on top of this list at that point.
func _covered(pos: Vector2) -> bool:
	var n: Node = self
	while n.get_parent() != null:
		var p := n.get_parent()
		for i in range(n.get_index() + 1, p.get_child_count()):
			if _blocks(p.get_child(i), pos):
				return true
		n = p
	return false

func _blocks(n: Node, pos: Vector2) -> bool:
	if n is CanvasItem and not n.visible:
		return false
	if n is Control and n.mouse_filter == Control.MOUSE_FILTER_STOP and n.get_global_rect().has_point(pos):
		return true
	for ch in n.get_children():
		if _blocks(ch, pos):
			return true
	return false
