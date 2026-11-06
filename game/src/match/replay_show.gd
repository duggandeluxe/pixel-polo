class_name ReplayShow
extends RefCounted
## THE INSTANT REPLAY: a goal shown again from its recorded
## frames (ReplayBuffer) after the goal show, while the match waits at the stoppage. It draws
## copies only: its swimmers and ball are made here, so nothing it does can reach the score, the
## clocks, possession, statistics or XP. Any tap skips it.
##
##   Level 1 NO REPLAY         no show at all: nothing's recorded, the goal goes straight on (free)
##   Level 2 BASIC REPLAY      the game's own camera at normal speed, a small REPLAY tag
##   Level 3 CINEMATIC REPLAY  a TV bug and name strip, letterbox; the camera zooms in on the
##                             shooter, then follows the ball, the slow motion deepening as it
##                             reaches the goal, a freeze on the moment (off the frame: the
##                             BAR-DOWN! / BAR-IN! burst)
## Every view is the recorded positions through a different camera: nothing's invented. Reduce
## Motion: the recorded camera, no wipes, no ramps.

const SKIP_TEXT := "TAP TO SKIP  >>"
const WIPE := 0.18
const FREEZE := 0.7
const RATE := ReplayBuffer.RATE
const NAVY := Color("0b1d5c")
const ZOOM_SHOOTER := 1.7      # Level 3: how far in on the shooter

var clip: Dictionary
const PLAIN := 2              # the last few seconds again, from the game camera
const CINEMATIC := 3          # slow motion, zooms, freeze frames
var level := 1
var calm := false
var who := ""                  # the scorer's name for the strip ("" none)
var team := ""
var col := Color.WHITE
var pool: PoolDef
var crowd := 0.6
var paint_body: Callable       # (ci, view, swimmer): the match's own caps
var style := {}                # the stands (CrowdArt.style)
var done := false
var skipped := false
var t := 0.0
var _plan: Array = []          # segments: {from, to, speed, cam, freeze_at}
var _seg := 0
var _f := 0.0                  # where we are in the clip (frame, fractional)
var _freeze := 0.0
var _froze := false
var _wipe := WIPE
var _rv := PoolView.new()
var _ghosts := {}

## What a match shows: nothing while it's locked or switched off (the upgrade's worn level 1),
## otherwise the owner's presentation.
static func level_for(worn: int, style: String) -> int:
	if worn < 2:
		return 1
	return PLAIN if style == "basic" else CINEMATIC

func _init(p_clip: Dictionary, p_level: int = 1, p_calm: bool = false) -> void:
	clip = p_clip
	level = clampi(p_level, 1, CINEMATIC)
	calm = p_calm
	_plan = plan()
	_f = float(_plan[0].from) if not _plan.is_empty() else 0.0
	if _plan.is_empty():
		done = true

## The clip's segments at this level.
func plan() -> Array:
	var n: int = (clip.frames as Array).size() if clip.has("frames") else 0
	if n == 0:
		return []
	var last := n - 1
	var shot := int(clip.shot)
	var net := int(clip.net)
	match level:
		1:
			return []
		2:
			return [{"from": 0, "to": last, "speed": 1.0, "cam": "rec"}]
	# Level 3: in on the shooter, then after the ball, slowing as it gets there
	if calm:
		return [{"from": maxi(0, shot - int(RATE * 0.6)), "to": last, "speed": 0.4, "cam": "rec", "hold": _moment()}]
	return [{"from": maxi(0, shot - int(RATE * 1.1)), "to": shot, "speed": 0.8, "cam": "shooter"},
		{"from": maxi(0, shot - int(RATE * 0.15)), "to": last, "speed": 0.5, "ramp": 0.18, "cam": "ball", "hold": _moment()}]

## The frame the picture stops on: where it hit the frame, else where it crossed the line.
func _moment() -> int:
	return int(clip.bar) if int(clip.bar) >= 0 else int(clip.net)

func total_frames() -> int:
	return (clip.frames as Array).size()

func skip() -> void:
	if done:
		return
	skipped = true
	done = true

func step(dt: float) -> void:
	if done:
		return
	t += dt
	_wipe = maxf(0.0, _wipe - dt)
	if _freeze > 0.0:
		_freeze -= dt
		return
	var sg: Dictionary = _plan[_seg]
	var speed := float(sg.speed)
	if sg.has("ramp"):
		# the slow motion deepens over the last half second before the moment
		var left := (float(sg.get("hold", sg.to)) - _f) / RATE
		speed = lerpf(float(sg.ramp), speed, clampf(left / 0.5, 0.0, 1.0)) if left > -0.2 else speed
	_f += dt * RATE * speed
	if sg.has("hold") and not _froze and _f >= float(sg.hold):
		_froze = true
		_f = float(sg.hold)
		_freeze = FREEZE
		return
	if _f >= float(sg.to):
		_seg += 1
		if _seg >= _plan.size():
			done = true
			return
		_f = float(_plan[_seg].from)
		_froze = false
		if not calm:
			_wipe = WIPE

func frozen() -> bool:
	return _freeze > 0.0

## The frame on screen now (for the tests too).
func frame_index() -> int:
	return clampi(int(_f), 0, total_frames() - 1)

func cam_mode() -> String:
	return String(_plan[mini(_seg, _plan.size() - 1)].cam) if not _plan.is_empty() else "rec"

func _ghost(src: Swimmer) -> Swimmer:
	if not _ghosts.has(src):
		_ghosts[src] = Swimmer.new(src.player, src.side, src.keeper)
	return _ghosts[src]

## A man as he was in this frame.
func _apply(m: Array) -> Swimmer:
	var g := _ghost(m[0])
	g.pos = m[1]
	g.vel = m[2]
	g.facing = m[3]
	g.anim = m[4]
	g.arm = m[5]
	g.dive = m[6]
	g.hop = m[7]
	g.cheer = m[8]
	g.block_arm = m[9]
	g.block_side = 1.0 if float(m[10]) < 0.0 else -1.0
	g.snap = m[11]
	g.grip = m[12]
	g.hook = m[13]
	g.out = m[14]
	g.slump = m[15]
	g.cheer_style = String(m[18])
	g.pose = (m[16] as KeeperDive).duplicate_at(float(m[17])) if m[16] != null else null
	return g

func _camera(fr: Dictionary, size: Vector2) -> void:
	_rv.width = size.x
	_rv.height = size.y
	_rv.shake = 0.0
	var at: Vector3 = fr.ball.at
	match cam_mode():
		"ball":
			_rv.mirror = bool(fr.mirror)
			_rv.zoom = 1.25
			_rv.zoom_to = 1.25
			_rv.cam = _rv._want(Vector2(at.x, at.y))
		"shooter":
			# the ball's in his hand: from the game's framing in on him as he shoots
			var sg: Dictionary = _plan[_seg]
			var u := clampf((_f - float(sg.from)) / maxf(1.0, float(sg.to) - float(sg.from)), 0.0, 1.0)
			_rv.mirror = bool(fr.mirror)
			_rv.zoom = lerpf(float(fr.zoom), ZOOM_SHOOTER, u * u * (3.0 - 2.0 * u))
			_rv.zoom_to = _rv.zoom
			_rv.cam = _rv._want(Vector2(at.x, at.y))
		_:
			_rv.mirror = bool(fr.mirror)
			_rv.zoom = float(fr.zoom)
			_rv.zoom_to = _rv.zoom
			_rv.cam = fr.cam

func draw(ci: CanvasItem, size: Vector2) -> void:
	if total_frames() == 0:
		return
	var fr: Dictionary = clip.frames[frame_index()]
	_camera(fr, size)
	PoolArt.draw_pool(ci, _rv, t, size, 0.0, pool, crowd, fr.ball.get("net", {}), style)
	var men: Array = (fr.men as Array).duplicate()
	men.sort_custom(func(a: Array, b: Array): return (a[1] as Vector2).y < (b[1] as Vector2).y)
	for m: Array in men:
		var g := _apply(m)
		HotFire.draw_under(ci, _rv, g, t, -1, calm)
		if paint_body.is_valid():
			paint_body.call(ci, _rv, g)
		else:
			PoolArt.draw_body(ci, _rv, g, PoolArt.CAP_KEEPER if g.keeper else (Color.WHITE if g.side == Swimmer.Side.US else Color("1d3b7a")), Color("1d3b7a"))
		HotFire.draw_over(ci, _rv, g, t, -1, calm)
	var bl: Dictionary = fr.ball
	var at: Vector3 = bl.at
	if bool(bl.shot):
		PoolArt.draw_power_trail(ci, _rv, at, bl.dir, float(bl.power))
		HotFire.draw_shot_fire(ci, _rv, at, bl.dir, int(bl.fire), t, float(bl.flown), calm)
	var b := Ball.new()
	b.state = Ball.State.LOOSE
	b.pos = Vector2(at.x, at.y)
	b.z = at.z
	PoolArt.draw_ball(ci, _rv, b)
	_overlay(ci, size)

func _overlay(ci: CanvasItem, size: Vector2) -> void:
	if level >= 3:
		ci.draw_rect(Rect2(0, 0, size.x, 18), Color.BLACK)
		ci.draw_rect(Rect2(0, size.y - 18, size.x, 18), Color.BLACK)
		_bug(ci, size)
	else:
		var tag := "REPLAY"
		var w := Deck.text_w(tag) + 10
		ci.draw_rect(Rect2(6, 6, w, 12), Color(UI.INK, 0.8))
		Deck.text(ci, 11, 12, tag, 8, Color.WHITE)
	if frozen() and String(clip.get("bar_text", "")) != "":
		var c := Vector2(roundf(size.x * 0.5), roundf(size.y * 0.42))
		var word := String(clip.bar_text)
		if not calm:
			BarHit.spikes(ci, c, BarHit._width(word, 32) * 0.5 + 10.0, 28.0, 1.0)
		BarHit.lettering(ci, c, word, 32, 1.0)
	if _wipe > 0.0:
		columns(ci, size, _wipe / WIPE)
	var sw := Deck.text_w(SKIP_TEXT) + 10
	var sy := size.y - (32.0 if level >= 3 else 15.0)
	ci.draw_rect(Rect2(size.x - sw - 4, sy, sw, 12), Color(UI.INK, 0.7))
	Deck.text(ci, size.x - sw + 1, sy + 6, SKIP_TEXT, 8, UI.TEXT)

## The wipe: columns of navy, `u` 1 closed .. 0 gone.
static func columns(ci: CanvasItem, size: Vector2, u: float) -> void:
	var cols := 12
	var cw := ceilf(size.x / cols)
	for i in cols:
		ci.draw_rect(Rect2(i * cw, 0, ceilf(cw * u), size.y), NAVY)

## The TV graphics: the REPLAY bug and the scorer's strip in his team's colour.
func _bug(ci: CanvasItem, size: Vector2) -> void:
	var top := 22.0
	Deck.frame(ci, Rect2(6, top, 62, 14), NAVY, Color.WHITE)
	ci.draw_rect(Rect2(8, top + 2, 4, 10), col)
	Deck.text(ci, 15, top + 7, "REPLAY", 8, UI.GOLD)
	if who == "":
		return
	var y := size.y - 40.0
	var text := who.to_upper()
	var w := Deck.text_w(text) + Deck.text_w(team) + 22
	Deck.frame(ci, Rect2(6, y, w, 14), NAVY, Color.WHITE)
	ci.draw_rect(Rect2(8, y + 2, 4, 10), col)
	Deck.text(ci, 15, y + 7, text, 8, Color.WHITE)
	Deck.text(ci, 19 + Deck.text_w(text), y + 7, team, 8, UI.ACCENT)
