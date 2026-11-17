extends RefCounted
## The last seconds of a period (OffenseAI._final): their attack, with the ball and the game clock
## running down, gets a shot away before the buzzer, from outside 6 m too; a shot the buzzer beats
## is no shot; no ball, no shot. Played through MatchFlow (their look, the wind-up, the game clock,
## Play.buzzer), many seeds a scenario.
##   godot --headless --path game -- --test final_shot

const DT := 1.0 / 60.0
const SEEDS := 24

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("final_shot")
	_normal()
	_halfway()
	_man_up()
	_late_steal()
	_counter()
	_shot_clock_unchanged()
	_too_late()
	_no_ball()

func _teams() -> Array:
	return [League.make_team(2, 1), League.make_team(3, 1)]

## Their half-court possession, the ball at `at` with his man a step goal side of him, `left`
## game-clock seconds to go and a full shot clock.
func _flow(seed_value: int, at: Vector2, left: float) -> MatchFlow:
	var t := _teams()
	var f := MatchFlow.new(t[0], t[1], seed_value, MatchState.QUARTER_MIN)
	f.auto_keeper = 0.5
	f._start_defense(Play.Kind.HALF_COURT)
	var p := f.play
	p.freeze = 0.0
	p.holder.pos = at
	var g := p.on_ball_guard(p.holder)
	if g != null:
		g.pos = at + (Geo.goal_center() - at).normalized() * 1.6
	for s in p.bodies():
		s.target = s.pos
		s.vel = Vector2.ZERO
	p.start_shot_clock(Play.SHOT_CLOCK)
	f.state.clock = left
	return f

## Plays it out: {shot: game clock left when a shot left his hand (-1: none), passes, outcome}.
func _play(f: MatchFlow, max_t := 12.0) -> Dictionary:
	var p := f.play
	var out := {"shot": -1.0, "passes": 0, "outcome": "", "clock_end": 0.0}
	var last := p.ball.state
	var t := 0.0
	while not p.over and t < max_t:
		f.tick_defense(DT)
		var st := p.ball.state
		if st != last:
			if st == Ball.State.SHOT and float(out.shot) < 0.0:
				out.shot = f.state.clock
			elif st == Ball.State.PASS:
				out.passes = int(out.passes) + 1
			last = st
		t += DT
	out.outcome = String(p.result.get("outcome", ""))
	out.clock_end = f.state.clock
	return out

## Every released shot left his hand with time on the clock.
func _before_buzzer(runs: Array) -> bool:
	for o in runs:
		if float(o.shot) == 0.0:
			return false
	return true

func _count(runs: Array, pred: Callable) -> int:
	var n := 0
	for o in runs:
		if pred.call(o):
			n += 1
	return n

# A: in range, 4 s left
func _normal() -> void:
	var runs := []
	for i in SEEDS:
		runs.append(_play(_flow(100 + i, Vector2(24.5, 14.3), 4.0)))
	var shots := _count(runs, func(o): return float(o.shot) > 0.0)
	var few_passes := _count(runs, func(o): return int(o.passes) <= OffenseAI.FINAL_PASSES)
	r.check(shots >= SEEDS - 1, "final: 4 s left in range, a shot before the buzzer (%d of %d)" % [shots, SEEDS])
	r.check(few_passes == SEEDS, "final: ...one pass at most (%d of %d)" % [few_passes, SEEDS])
	r.check(_before_buzzer(runs), "final: ...every one away with time on the clock")

# B: at halfway, 2 s left: a desperation shot, and it's still as hard as ever
func _halfway() -> void:
	var runs := []
	var goals := 0
	for i in SEEDS:
		var o := _play(_flow(200 + i, Vector2(15.5, 10.0 + (i % 5) - 2.0), 2.0))
		runs.append(o)
		if o.outcome == "goal":
			goals += 1
	var shots := _count(runs, func(o): return float(o.shot) > 0.0)
	r.check(shots >= SEEDS - 2, "final: 2 s left at halfway, a long shot rather than holding it (%d of %d)" % [shots, SEEDS])
	r.check(goals <= SEEDS / 4, "final: ...and from 15 m it rarely goes in (%d of %d)" % [goals, SEEDS])

# C: a power play, 3 s left: no swinging it round the perimeter
func _man_up() -> void:
	var runs := []
	for i in SEEDS:
		var f := _flow(300 + i, Vector2(25.0, 12.5), 3.0)
		var p := f.play
		p._exclusion(p.defenders[1])
		p.freeze = 0.0
		f.state.clock = 3.0
		runs.append(_play(f))
	var shots := _count(runs, func(o): return float(o.shot) > 0.0)
	var few := _count(runs, func(o): return int(o.passes) <= OffenseAI.FINAL_PASSES)
	r.check(shots >= SEEDS - 1, "final: 6 on 5 with 3 s left, a shot (%d of %d)" % [shots, SEEDS])
	r.check(few == SEEDS, "final: ...not passed round the perimeter (%d of %d at most one pass)" % [few, SEEDS])

# E: caught out at 9 m with 1.5 s left (a late steal): straight up with it
func _late_steal() -> void:
	var runs := []
	for i in SEEDS:
		runs.append(_play(_flow(400 + i, Vector2(21.0, 8.0), 1.5)))
	var shots := _count(runs, func(o): return float(o.shot) > 0.0)
	var no_pass := _count(runs, func(o): return int(o.passes) == 0)
	r.check(shots >= SEEDS - 2, "final: 1.5 s left at 9 m, a shot (%d of %d)" % [shots, SEEDS])
	r.check(no_pass >= SEEDS - 2, "final: ...no pass first (%d of %d)" % [no_pass, SEEDS])
	r.check(_before_buzzer(runs), "final: ...every one away with time on the clock")

# the break with 4.5 s left from 16 m: it carries on, then shoots before the buzzer
func _counter() -> void:
	var runs := []
	for i in SEEDS:
		var f := _flow(500 + i, Vector2(14.0, 10.0), 4.5)
		f.play.carry = true
		f.play.counter_t = 5.0
		runs.append(_play(f))
	var shots := _count(runs, func(o): return float(o.shot) > 0.0)
	r.check(shots >= SEEDS - 2, "final: on the break with 4.5 s left, a shot before the buzzer (%d of %d)" % [shots, SEEDS])
	r.check(_before_buzzer(runs), "final: ...every one away with time on the clock")

# the shot clock is not the game clock: 2 s on the shot clock at halfway with the quarter young,
# no shot from out there (a shot clock violation, as ever)
func _shot_clock_unchanged() -> void:
	var shots := 0
	for i in SEEDS:
		var f := _flow(600 + i, Vector2(15.5, 10.0), 90.0)
		var p := f.play
		for a in p.attackers:
			if a != p.holder:
				a.out = true   # (nobody to give it to)
		p.start_shot_clock(2.0)
		var o := _play(f, 4.0)
		if float(o.shot) > 0.0:
			shots += 1
	r.check(shots == 0, "final: shot clock running out at halfway mid-quarter, still no shot from there (%d)" % shots)

# G: 0.2 s left: the wind-up takes longer, so the buzzer goes first and there's no shot
func _too_late() -> void:
	var ok := 0
	for i in SEEDS:
		var o := _play(_flow(700 + i, Vector2(24.5, 10.0), 0.2))
		if float(o.shot) < 0.0 and o.outcome == "buzzer" and float(o.clock_end) == 0.0:
			ok += 1
	r.check(ok == SEEDS, "final: 0.2 s left, the buzzer beats the wind-up: no shot, no extra time (%d of %d)" % [ok, SEEDS])

# F: the ball loose as the clock goes: nobody's shot appears from nowhere
func _no_ball() -> void:
	var ok := 0
	for i in SEEDS:
		var f := _flow(800 + i, Vector2(20.0, 10.0), 1.0)
		var p := f.play
		p.holder = null
		p.ball.pos = Vector2(18.0, 3.0)
		p._go_loose(Vector2.ZERO)
		var o := _play(f, 3.0)
		if float(o.shot) < 0.0:
			ok += 1
	r.check(ok == SEEDS, "final: a loose ball at the buzzer, no shot (%d of %d)" % [ok, SEEDS])
