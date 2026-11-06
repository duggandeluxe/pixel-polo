extends RefCounted
## THE CENTRE'S REBOUND: a shot off the post or the bar that the centre gathers is an ordinary foul
## for his team (Play._center_rebound_foul), never a steal; anything else about rebounds and the
## centre is as it was.
##   godot --headless --path game -- --test center_rebound

var r   # the test runner

const DT := 1.0 / 60.0

func run(runner) -> void:
	r = runner
	print("centre rebound")
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	for side in [-1.0, 1.0, 0.0]:   # (left post, right post, the bar: one "post" outcome off the frame)
		_centre_gathers(side, false)
	_centre_gathers(1.0, true)
	_before_the_fix()
	_others()

## The same rebound with the fix bypassed (the frame flag cleared): the centre in a drop, the dropper
## right in front of him, holding a live ball at 2 m, gets it taken off him. That's what was wrong.
func _before_the_fix() -> void:
	var stolen := 0
	for i in 30:
		var p := _play(200 + i)
		var c := _tag(p, "C")
		p.formation = DefenseFormation.F.M_DROP
		for k in int(1.5 / DT):
			p.step(DT)   # (the drop sets up: the dropper in front of the centre)
			if p.over:
				break
		if p.over:
			continue
		_off_frame(p, c.pos)
		p.frame_rebound = false   # (the old way)
		p.keeper_rush = false
		p.loose_skip = 0.0
		p.events.clear()
		for k in int(2.5 / DT):
			p.step(DT)
			if p.over:
				break
		if p.over and String(p.result.get("outcome", "")) == "steal" and p.events.any(func(e): return String(e.k) == "recover"):
			stolen += 1
	r.check(stolen > 0, "(without it, the centre's rebound in a drop is stolen off him: %d of 30)" % stolen)

func _play(seed_v: int) -> Play:
	var c := Career.new_game("SJCU", "A", "B", seed_v)
	c.queue.clear()
	var f := MatchFlow.new(c.team(), c.teams["CULA"], 99, 2.0)
	f._start_attack(Play.Kind.HALF_COURT)
	var p := f.play
	p.drive_timer = 99.0
	return p

func _tag(p: Play, t: String) -> Swimmer:
	for a in p.attackers:
		if a.tag == t:
			return a
	return null

## A shot comes off the frame and the loose ball drops at `at`.
func _off_frame(p: Play, at: Vector2, outcome := "post") -> void:
	var shooter := _tag(p, "3")
	p.give_ball(shooter)
	p.ball.shooter = shooter
	p.ball.shot = {"outcome": outcome, "cross_y": Geo.GOAL_Y}
	p.ball.state = Ball.State.SHOT
	p._resolve_shot()
	p.ball.pos = at
	p.ball.drift = Vector2.ZERO

func _count(p: Play, k: String) -> int:
	return p.events.filter(func(e): return String(e.k) == k).size()

## The centre gathers it: closely guarded (`tight`: his guard right on him, in front) or not.
func _centre_gathers(side: float, tight: bool) -> void:
	var p := _play(31 + int(side * 3.0) + (10 if tight else 0))
	var c := _tag(p, "C")
	var g := p._marker(c)
	_off_frame(p, c.pos + Vector2(0.0, 0.3 * side))
	var where := "the bar" if side == 0.0 else ("the left post" if side < 0.0 else "the right post")
	r.check(p.frame_rebound and p.ball.state == Ball.State.LOOSE, "off %s: a live rebound" % where)
	for d in p.defenders:
		if d != g:
			d.pos = Vector2(15.0, d.pos.y)   # (nobody else near it)
	g.pos = c.pos + Vector2(-0.45 if tight else -1.0, 0.0)   # in front of him, between him and the ball's way out
	p.keeper_rush = false
	p.events.clear()
	p.loose_skip = 0.0
	p._loose(DT)
	r.check(p.holder == c and _count(p, "foul") == 1 and _count(p, "center_rebound") == 1,
		"off %s%s: the centre has it, and it's an ordinary foul for his team" % [where, ", closely guarded" if tight else ""])
	r.check(p.restart and p.man_up <= 0.0 and p.kind != Play.Kind.PENALTY and not p.over,
		"...a free throw (the restart), no exclusion, no penalty, still their ball")
	# the next few seconds: no steal, no second whistle for the same rebound
	for i in int(2.5 / DT):
		p.step(DT)
		if p.over:
			break
	var steals := p.events.filter(func(e): return String(e.k) == "end" and String(e.get("outcome", "")) == "steal").size()
	r.check(steals == 0 and _count(p, "center_rebound") == 1,
		"...never a steal, and the foul's given once (%s)" % String(p.result.get("outcome", "still live")))

func _others() -> void:
	# a defender gets there first: their ball
	var p := _play(51)
	var c := _tag(p, "C")
	var g := p._marker(c)
	_off_frame(p, g.pos)
	for d in p.defenders:
		if d != g:
			d.pos = Vector2(15.0, d.pos.y)
	c.pos = g.pos + Vector2(1.5, 0.0)
	p.keeper_rush = false
	p.events.clear()
	p.loose_skip = 0.0
	p._loose(DT)
	r.check(p.over and _count(p, "center_rebound") == 0 and _count(p, "foul") == 0, "a defender gathers it: the defence's ball, no foul")
	# another attacker gathers it: a recovery, nothing more
	var q := _play(52)
	var w := _tag(q, "1")
	_off_frame(q, w.pos)
	for d in q.defenders:
		d.pos = Vector2(15.0, d.pos.y)
	_tag(q, "C").pos = w.pos + Vector2(2.0, 2.0)
	q.keeper_rush = false
	q.events.clear()
	q.loose_skip = 0.0
	q._loose(DT)
	r.check(q.holder == w and _count(q, "foul") == 0 and not q.restart, "a wing gathers it: his ball, no whistle (as before)")
	# a parry the centre gathers isn't off the frame: no foul from it
	var s := _play(53)
	var cc := _tag(s, "C")
	_off_frame(s, cc.pos, "parry")
	for d in s.defenders:
		d.pos = Vector2(15.0, d.pos.y)
	s.keeper_rush = false
	s.events.clear()
	s.loose_skip = 0.0
	s._loose(DT)
	r.check(s.holder == cc and _count(s, "center_rebound") == 0 and not s.frame_rebound, "the centre gathers a parry: no rebound foul (only the frame's)")
	# a pass in to the centre: the entry as ever, no rebound foul in it
	var e := _play(54)
	var ec := _tag(e, "C")
	e.give_ball(_tag(e, "3"))
	e.events.clear()
	e.pass_to(ec)
	for i in int(2.0 / DT):
		e.step(DT)
		if e.over or e.holder == ec:
			break
	r.check(_count(e, "center_rebound") == 0 and not e.frame_rebound, "a pass in to the centre: the centre-defence rules as they were, no rebound foul")
