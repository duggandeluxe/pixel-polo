class_name PoolView
extends RefCounted
## Camera + projection: pool metres to screen pixels in a tilted top-down view. The camera
## follows the play along the pool and across it, like the field in Retro Bowl.

const SX := 30.0        # px per metre along the pool
const SY := 15.0        # px per metre across it (squashed: we look in at an angle)
const SZ := 18.0        # px per metre of height
const HUD_H := 24.0     # the scoreboard strip at the top of the screen

var cam := Vector2(15.0, 2.0)   # world point at the top-left of the pool area
var width := 480.0
var height := 270.0
var shake := 0.0
## Defending: the pool is drawn the other way round, so they attack left, towards your goal,
## while the play itself still runs attacking x = 30 (see MatchFlow's defence).
var mirror := false
## 1 is the normal close view. The sprint pulls back to show the whole pool (wide()); the
## camera eases back to 1 with follow() once play starts.
var zoom := 1.0
var zoom_to := 1.0

## The 6 on 5 push in (ManUpCam): the transform the whole world layer is drawn through, on top of
## everything here (to_screen is the world layer's own coordinates). Taps come back through it
## (to_world, unzoom). The identity the rest of the time.
var cine := Transform2D.IDENTITY

const WIDE_MARGIN := 2.0   # m of deck shown past each goal line in the wide view

func _mx(x: float) -> float:
	return Geo.LENGTH - x if mirror else x

func sx() -> float:
	return SX * zoom

func sy() -> float:
	return SY * zoom

func sz() -> float:
	return SZ * zoom

func visible_size() -> Vector2:
	return Vector2(width / sx(), (height - HUD_H) / sy())

## The whole pool, end to end (the sprint). Snaps there; wide(false) eases back in.
func wide(on: bool) -> void:
	zoom_to = width / ((Geo.LENGTH + WIDE_MARGIN * 2.0) * SX) if on else 1.0
	if on:
		zoom = zoom_to

## Centre the camera on `focus` (metres), clamped so we never look past the stands. A view
## wider than the pool (or taller) is centred on it.
func _want(focus: Vector2) -> Vector2:
	var vis := visible_size()
	return Vector2(
		_clamp_or_centre(_mx(focus.x) - vis.x * 0.5, -2.3, Geo.LENGTH + 2.3 - vis.x),
		_clamp_or_centre(focus.y - vis.y * 0.5, -2.6, Geo.WIDTH + 1.6 - vis.y))

static func _clamp_or_centre(v: float, lo: float, hi: float) -> float:
	return clampf(v, lo, hi) if lo <= hi else (lo + hi) * 0.5

func follow(focus: Vector2, dt: float) -> void:
	var k := clampf(dt * 3.5, 0.0, 1.0)
	if zoom != zoom_to:
		zoom = lerpf(zoom, zoom_to, k)
		if absf(zoom - zoom_to) < 0.004:
			zoom = zoom_to
	cam = cam.lerp(_want(focus), k)
	shake = maxf(0.0, shake - dt * 8.0)

func snap_to(focus: Vector2) -> void:
	zoom = zoom_to
	cam = _want(focus)

## Where the camera should look during an attack: between the ball and the goal.
static func attack_focus(ball: Vector2) -> Vector2:
	return Vector2(lerpf(ball.x, 27.5, 0.45), lerpf(ball.y, Geo.GOAL_Y, 0.45))

## Your attack (you tap to pass): along the pool as attack_focus, but across it the whole attack,
## wing to wing, whenever it fits, so every man is on screen to be tapped, the far corner too.
## When it doesn't fit (a break, spread over the pool), the ball's side, but the ball always in view.
const FRAME_MARGIN := 1.4      # m kept clear above the top man (his head) and below the bottom one
func attack_frame(p: Play) -> Vector2:
	var b := p.ball.pos
	var f := attack_focus(b)
	var lo := b.y
	var hi := b.y
	for a in p.attackers:
		if not a.out:
			lo = minf(lo, a.pos.y)
			hi = maxf(hi, a.pos.y)
	var half := visible_size().y * 0.5 / cine.get_scale().y - FRAME_MARGIN   # (pushed in: less fits)
	if hi - lo <= half * 2.0:
		f.y = (lo + hi) * 0.5
	return Vector2(f.x, clampf(f.y, b.y - half, b.y + half))

func to_screen(p: Vector2, z: float = 0.0) -> Vector2:
	var jitter := Vector2(sin(shake * 37.0), cos(shake * 23.0)) * shake * 1.5
	return Vector2(roundf((_mx(p.x) - cam.x) * sx()), roundf(HUD_H + (p.y - cam.y) * sy() - z * sz())) + jitter.round()

## A point on the actual screen (a tap) back into the world layer's coordinates.
func unzoom(s: Vector2) -> Vector2:
	return cine.affine_inverse() * s

func to_world(s: Vector2) -> Vector2:
	s = unzoom(s)
	return Vector2(_mx(s.x / sx() + cam.x), (s.y - HUD_H) / sy() + cam.y)
