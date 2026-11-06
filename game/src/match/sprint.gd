class_name Sprint
extends RefCounted
## The swim-off that starts every quarter: both teams line up on their own goal line, and you
## tap as fast as you can to get your sprinter to the ball first.

const LINE_X := 0.6          # the field players' line, just off the goal line
const SPRINTER_X := 1.2      # the sprinter, in the middle of it
const START_GAP := Geo.HALF - SPRINTER_X
const LANES := [12.5, 7.5, 15.0, 5.0, 17.5]   # where the other five line up across the pool
const BASE_SPEED := 2.0
const TAP_BOOST := 0.5
const MAX_BOOST := 1.4
const BOOST_DECAY := 1.1
const JET_BONUS := 0.15      # a JET sprinter swims this much faster (m/s)

var countdown := 1.8
var ours: Swimmer
var theirs: Swimmer
var others: Array[Swimmer] = []
var ball := Vector2(Geo.HALF, Geo.GOAL_Y)
var their_speed := 2.2
var boost := 0.0
var taps := 0
var done := false
var we_won := false
var whistled := false
## Multiplayer: the other sprinter is a real player on another phone. Their position comes
## from set_remote(); reaching the ball only marks `arrived`, and the host decides who won.
var remote := false
var arrived := false

func _init(us: PoloTeam, them: PoloTeam, p_their_speed: float) -> void:
	their_speed = p_their_speed
	ours = _line_up(us, Swimmer.Side.US, 1.0)
	theirs = _line_up(them, Swimmer.Side.THEM, -1.0)

## Everyone on their own goal line, keeper in goal; the fastest field player goes for the ball.
func _line_up(t: PoloTeam, side: int, dir: float) -> Swimmer:
	var st := t.starters()
	var field := st.slice(1)
	var fastest: PoloPlayer = field[0]
	for p: PoloPlayer in field:
		if p.speed > fastest.speed:
			fastest = p
	var line_x := LINE_X if dir > 0.0 else Geo.LENGTH - LINE_X
	var sprinter: Swimmer = null
	var i := 0
	for p: PoloPlayer in field:
		var s := Swimmer.new(p, side)
		s.facing = dir
		if p == fastest:
			s.pos = Vector2(Geo.HALF - dir * START_GAP, Geo.GOAL_Y)
			sprinter = s
		else:
			s.pos = Vector2(line_x, LANES[i % LANES.size()])
			s.target = s.pos
			others.append(s)
			i += 1
	var gk := Swimmer.new(st[0], side, true)
	gk.pos = Vector2(Geo.KEEPER_X if dir < 0.0 else Geo.LENGTH - Geo.KEEPER_X, Geo.GOAL_Y)
	gk.target = gk.pos
	gk.facing = dir
	others.append(gk)
	sprinter.target = sprinter.pos
	return sprinter

func tap() -> void:
	if countdown <= 0.0 and not done:
		taps += 1
		boost = minf(boost + TAP_BOOST, MAX_BOOST)

func started() -> bool:
	return countdown <= 0.0

func step(dt: float) -> void:
	for s in others:
		s.step(dt)
	if countdown > 0.0:
		countdown -= dt
		if countdown <= 0.0:
			whistled = true
			for s in others:
				if not s.keeper:
					s.target = s.pos + Vector2(s.facing * 8.0, 0.0)
		return
	boost = maxf(0.0, boost - dt * BOOST_DECAY)
	if done:
		ours.target = ours.pos
		theirs.target = theirs.pos
		ours.step(dt)
		theirs.step(dt)
		return
	var sp := BASE_SPEED + boost + (JET_BONUS if Traits.has(ours.player, "jet") else 0.0)
	if remote:
		if not arrived:
			ours.pos.x += sp * dt
			ours.vel = Vector2(sp, 0.0)
			ours.anim += dt * (2.0 + sp * 3.0)
			arrived = ours.pos.x >= ball.x - 0.45
		else:
			ours.vel = Vector2.ZERO
		return
	ours.pos.x += sp * dt
	ours.vel = Vector2(sp, 0.0)
	ours.anim += dt * (2.0 + sp * 3.0)
	theirs.pos.x -= their_speed * dt
	theirs.vel = Vector2(-their_speed, 0.0)
	theirs.anim += dt * (2.0 + their_speed * 3.0)
	if ours.pos.x >= ball.x - 0.45:
		done = true
		we_won = true
	elif theirs.pos.x <= ball.x + 0.45:
		done = true
		we_won = false

## Where the camera looks: between your sprinter and the ball, so it starts on your line and
## follows him up the pool.
func focus() -> Vector2:
	return Vector2(lerpf(ours.pos.x, ball.x, 0.5), Geo.GOAL_Y)

func bodies() -> Array[Swimmer]:
	var out: Array[Swimmer] = [ours, theirs]
	out.append_array(others)
	return out

## How far our sprinter has come (sent to the other phone).
func progress() -> float:
	return ours.pos.x - (Geo.HALF - START_GAP)

## The other phone's sprinter, `d` metres from his start.
func set_remote(d: float) -> void:
	var x := Geo.HALF + START_GAP - d
	theirs.vel = Vector2(-(theirs.pos.x - x) * 8.0, 0.0)
	theirs.anim += absf(theirs.pos.x - x) * 2.0
	theirs.pos.x = maxf(ball.x + 0.45, x)

## The host's call.
func finish(won: bool) -> void:
	done = true
	we_won = won
