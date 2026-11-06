class_name CounterDrill
extends Drill
## Part 2: lead a swimmer on the break. Three of yours away up the pool, nobody back, no
## keeper: the real counter (Play.carry, PlayAI's break lanes), the carrier swimming it in and
## the other two racing into their lanes, nobody stopping for a pass. Tap a teammate and the
## pass leads him (Play.lead_point); tap the open water in front of him and it goes exactly there,
## and he runs onto it without breaking stride (Play.receiver_at, PlayAI.run_onto). Three passes
## caught by a man who was swimming, thrown in front of him: in his hands, or gathered in his
## stride within RUN_ON of it landing. A ball nobody gets to starts the break over.

const PASSES := 3
const MOVING := 0.8          # m/s: the catcher was swimming when it left the hand...
const AHEAD := 0.25          # ...and it was thrown at least this far in front of him
const START_X := 8.0         # the break picks up this far up the pool
const LANES := {"4": Vector2(START_X, 6.0), "3": Vector2(START_X + 1.0, Geo.GOAL_Y), "2": Vector2(START_X, 14.0)}
const RUN_ON := 1.0          # a lead pass gathered this soon after it lands was taken in his stride
const CHASE := 1.6           # a ball gone loose: he gets this long to get to it, then it starts over
const BREAK_OVER := 0.8      # the break ran out (the attack setting up): a new one this soon after

var passes := 0
var _pass := {}              # the pass in the air: {receiver, moving, ahead}
var _loose_t := -1.0         # seconds the ball's been loose after a pass (-1: it isn't)

func _init() -> void:
	id = "counter"

func instruction() -> String:
	return "LEAD YOUR TEAMMATE INTO OPEN WATER: PASS 2-3 METERS AHEAD"

func progress() -> String:
	return "LEAD PASSES: %d / %d" % [mini(passes, PASSES), PASSES]

func start(flow: DrillFlow) -> void:
	var p := flow.attack()
	strip(p, LANES.keys(), false, "3")
	for a in p.attackers:
		place(a, LANES[a.tag])
		a.vel = Vector2(a.top_speed * (PlaySetup.CARRY_SWIM if a == p.holder else PlaySetup.BREAK_SWIM), 0.0)
	# the break is on (as PlaySetup._counter leaves it): nobody back, everybody away
	p.kind = Play.Kind.COUNTER
	p.counter_t = 5.0
	p.carry = true
	p._hold_ball()
	p.break_n = p.break_numbers()
	_pass = {}
	_loose_t = -1.0

## Judged as it leaves the hand: was he swimming, and is it in front of him?
func thrown(flow: DrillFlow) -> void:
	var b := flow.play.ball
	var r := b.receiver
	_loose_t = -1.0
	if r == null:
		_pass = {"receiver": null, "moving": false, "ahead": 0.0}
		return
	var dir := r.vel.normalized() if r.vel.length() > 0.05 else Vector2.ZERO
	_pass = {"receiver": r, "moving": r.vel.length() >= MOVING, "ahead": (b.to - r.pos).dot(dir)}

func on_event(flow: DrillFlow, e: Dictionary) -> void:
	match String(e.k):
		"recover":
			# a lead pass into the water, gathered in his stride: as good as a catch
			if not _pass.is_empty() and flow.play.holder == _pass.receiver and _loose_t <= RUN_ON:
				_judge(flow)
			_pass = {}
			_loose_t = -1.0
		"catch":
			if not _pass.is_empty():
				_judge(flow)
			_pass = {}

func _judge(flow: DrillFlow) -> void:
	var by: Swimmer = flow.play.holder
	if by == _pass.receiver and _pass.moving and float(_pass.ahead) >= AHEAD:
		passes += 1
		if passes >= PASSES:
			complete = true

func tick(flow: DrillFlow, dt: float) -> void:
	super(flow, dt)
	var p := flow.play
	if p == null or p.over or complete:
		return
	if p.ball.state == Ball.State.LOOSE and not _pass.is_empty():
		_loose_t = maxf(_loose_t, 0.0) + dt
		if _loose_t >= CHASE:
			reset_after(0.0)
	elif not p.carry and p.ball.state == Ball.State.HELD:
		reset_after(BREAK_OVER)   # he swam it in (or it ran out): the attack's setting up, so a new break
