extends RefCounted
## Lead passes on the break, in the engine itself (Play.receiver_at, PlayAI.run_onto,
## PlayAI._break_spot), so the same for the tutorial's counter and a match's: a ball 2-3 m in
## front of a swimming man is his, he swims onto it without slowing and carries on at the goal
## with it; nobody turns round for a ball thrown on ahead; one thrown too far can still go begging,
## the keeper still takes one into his water and a defender in the lane still picks some off;
## a ball behind him still sends him back; the set attack's passing is untouched.
##   godot --headless --path game -- --test leadpass

const DT := 1.0 / 60.0

var r   # the test runner (check, check_between)

func run(runner) -> void:
	r = runner
	print("leadpass")
	_leads()
	_overthrown()
	_keeper_takes_it()
	_picked_off()
	_behind()
	_set_attack()
	_match_counters()

## The tutorial's break (CounterDrill: three of ours away up the pool, nobody back), a few strides in.
func _break(seed_value: int, keeper := false) -> Play:
	var f := DrillFlow.new(CounterDrill.new(), League.make_team(0), League.make_team(3), seed_value)
	f.start_rep()
	var p := f.play
	if keeper:
		p.keeper_in = true
		p.keeper.pos = Vector2(Geo.KEEPER_X, Geo.GOAL_Y)
		p.keeper.target = p.keeper.pos
	for i in 20:
		p.step(DT)
	return p

func _mates(p: Play) -> Array:
	return p.attackers.filter(func(a): return a != p.holder)

## Steps the play until `cond` or `secs`; the slowest anybody in the attack swam towards the goal.
func _play_on(p: Play, secs: float, cond: Callable) -> float:
	var slowest := INF
	var t := 0.0
	while t < secs and not p.over and not cond.call():
		p.step(DT)
		t += DT
		for a in p.attackers:
			slowest = minf(slowest, a.vel.x)
	return slowest

# ------------------------------------------------------------------ 2-3 m ahead
func _leads() -> void:
	for lead in [2.0, 3.0]:
		var caught := 0
		var n := 0
		var kept_on := true
		var forward := true
		var slowest := INF
		for seed_value in [1, 2, 3]:
			for side in 2:
				var p := _break(seed_value)
				var mate: Swimmer = _mates(p)[side]
				var spot: Vector2 = mate.pos + mate.vel.normalized() * lead
				r.check(p.receiver_at(spot) == mate, "leadpass: %.0f m in front of a swimmer, he's the receiver" % lead)
				p.pass_at(spot)
				n += 1
				slowest = minf(slowest, _play_on(p, 2.5, func(): return p.holder != null))
				if p.holder == mate:
					caught += 1
					var x0 := mate.pos.x
					for i in 36:
						p.step(DT)
						forward = forward and mate.vel.x > 1.5
					kept_on = kept_on and p.carry and mate == p.holder and mate.pos.x > x0 + 0.8 and mate.vel.x > 1.5
		r.check(caught == n, "leadpass: %.0f m ahead, he takes it every time (%d / %d)" % [lead, caught, n])
		r.check(slowest > 1.5, "leadpass: %.0f m ahead, nobody slows on the way to it (%.2f m/s)" % [lead, slowest])
		r.check(forward and kept_on, "leadpass: %.0f m ahead, he carries on at the goal with it" % lead)

# ------------------------------------------------------------------ too far ahead
func _overthrown() -> void:
	var reversed := false
	var begging := 0
	for lead in [6.0, 9.0, 12.0]:
		for seed_value in [1, 2]:
			var p := _break(seed_value)
			var mate: Swimmer = _mates(p)[seed_value % 2]
			var spot := Geo.clamp_in_pool(mate.pos + Vector2(lead, 0.0))
			p.pass_at(spot)
			var slowest := _play_on(p, 1.5, func(): return p.holder != null)
			reversed = reversed or slowest < 0.0
			if p.holder == null:
				begging += 1
	r.check(not reversed, "leadpass: a ball thrown on ahead, nobody turns back for it")
	r.check(begging > 0, "leadpass: one thrown far enough ahead still goes begging (%d)" % begging)

## A ball thrown on into his water: the keeper's.
func _keeper_takes_it() -> void:
	var p := _break(4, true)
	var mate: Swimmer = _mates(p)[0]
	p.pass_at(Vector2(29.0, Geo.GOAL_Y + 0.5))
	var slowest := _play_on(p, 4.0, func(): return false)
	r.check(p.over and String(p.result.outcome) in ["turnover", "steal"] and String(p.result.text).begins_with("KEEPER"),
		"leadpass: a ball overthrown into the keeper's water is his (%s)" % str(p.result))
	r.check(slowest > -0.2 or mate.pos.x > 20.0, "leadpass: ...and nobody turned back for it before it was gone")

## A defender standing in the lane still gets his chance at it.
func _picked_off() -> void:
	var stolen := 0
	for seed_value in 20:
		var f := DrillFlow.new(CounterDrill.new(), League.make_team(0), League.make_team(3), seed_value)
		f.start_rep()
		var p := f.play
		var mate: Swimmer = _mates(p)[0]
		var spot := mate.pos + Vector2(2.5, 0.0)
		var d := Swimmer.new(League.make_team(3).roster[1], Swimmer.Side.THEM)   # (on the pass's line)
		d.pos = p.holder.pos.lerp(spot, 0.5)
		d.target = d.pos
		p.defenders.append(d)
		p.pass_at(spot)
		_play_on(p, 2.0, func(): return p.holder != null)
		if p.over and String(p.result.outcome) == "steal":
			stolen += 1
	r.check(stolen > 0 and stolen < 20, "leadpass: a defender in the lane still picks some off (%d / 20)" % stolen)

## Behind him: he does have to go back for that one.
func _behind() -> void:
	var p := _break(5)
	var mate: Swimmer = _mates(p)[0]
	var spot := mate.pos - mate.vel.normalized() * 2.5
	p.pass_at(spot)
	r.check(p.ball.receiver == mate, "leadpass: a ball just behind him is still his")
	var slowest := INF
	var t := 0.0
	while t < 2.0 and p.holder == null and not p.over:
		p.step(DT)
		t += DT
		slowest = minf(slowest, mate.vel.x)
	r.check(slowest < 0.0, "leadpass: thrown behind him, he turns back for it (%.2f)" % slowest)

## No break: a ball into the water is still for the nearest man, and he goes to where it lands.
func _set_attack() -> void:
	var f := MatchFlow.new(League.make_team(0), League.make_team(3), 5, MatchState.QUARTER_MIN)
	f._start_attack(Play.Kind.HALF_COURT)
	var p := f.play
	p.carry = false
	var same := true
	for a in p.attackers:
		for off in [Vector2(1.0, 0.5), Vector2(-1.5, 0.0), Vector2(0.5, -2.0)]:
			same = same and p.receiver_at(a.pos + off) == p._receiver_for(a.pos + off)
	r.check(same, "leadpass: the set attack's receiver is the nearest man, as before")
	var mate: Swimmer = _mates(p)[0]
	var spot := mate.pos + Vector2(-1.0, 0.8)
	p.freeze = 0.0
	if p.pass_at(spot):
		p.step(DT)
		r.check(p.ball.state != Ball.State.PASS or p.ball.receiver.target == p.ball.to, "leadpass: in the set attack he swims to where it lands")
	r.check(PlayAI.run_onto(mate, mate.pos + Vector2(2.0, 0.0), true).x > mate.pos.x + 2.0 \
		and PlayAI.run_onto(mate, mate.pos + Vector2(-3.0, 0.0), true) == mate.pos + Vector2(-3.0, 0.0),
		"leadpass: run_onto goes through a ball in front, back for one behind")

## Real counters (defenders coming back, their keeper in): a forward pass to a man on the break
## never turns him round, and the counters still end every way they did.
func _match_counters() -> void:
	var outcomes := {}
	var reversed := 0
	var passes := 0
	for i in 40:
		var f := MatchFlow.new(League.make_team(0), League.make_team(3), 100 + i, MatchState.QUARTER_MIN)
		f._start_attack(Play.Kind.COUNTER)
		var p := f.play
		var t := 0.0
		var thrown := false
		var recv: Swimmer = null
		while t < 12.0 and not p.over:
			if not thrown and p.carry and t > 0.4 and p.can_throw():
				var ahead: Array = _mates(p).filter(func(a): return not a.out and a.tag != "C" and a.is_swimming() and a.vel.x > 1.0)
				if not ahead.is_empty():
					recv = ahead[0]
					thrown = p.pass_to(recv)
					passes += 1 if thrown else 0
			if thrown and recv != null and p.ball.state == Ball.State.PASS and recv.vel.x < -0.2:
				reversed += 1
				recv = null
			if not thrown and t > 3.0 and p.can_throw():
				p.shoot_at(Vector2(Geo.GOAL_X + 1.0, Geo.GOAL_Y - 1.0), 0.8)
			if thrown and p.holder == recv and p.can_throw() and p.holder.pos.x > 24.0:
				p.shoot_at(Vector2(Geo.GOAL_X + 1.0, Geo.GOAL_Y - 1.0), 0.8)
			f.tick_attack(DT)
			t += DT
		var o := String(p.result.get("outcome", "none"))
		outcomes[o] = int(outcomes.get(o, 0)) + 1
	print("  leadpass: match counters %s, %d lead passes" % [str(outcomes), passes])
	r.check(passes >= 10, "leadpass: match counters with a forward pass on (%d)" % passes)
	r.check(reversed == 0, "leadpass: no man on a match break turned back for a forward pass (%d)" % reversed)
	r.check(outcomes.size() >= 2, "leadpass: match counters still end more than one way (%s)" % str(outcomes))
