extends RefCounted
## THE UNIVERSAL RED X (Play.sure_block, ShotModel.sure_block): the aim guide's X against any field
## defender, any formation, only when the block is certain, at the point the ball meets him, and
## exactly what the shot then does.
##   godot --headless --path game -- --test red_x

var r   # the test runner

const ROLLS := 300

var _flow: MatchFlow = null

func run(runner) -> void:
	r = runner
	print("universal red X")
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	var names := {DefenseFormation.F.PRESS: "PRESS", DefenseFormation.F.M_DROP: "M-DROP", DefenseFormation.F.FIVE_DROP: "5 DROP",
		DefenseFormation.F.FOUR_FIVE: "4-5 DROP", DefenseFormation.F.THREE_FOUR: "3-4 DROP"}
	for f in names:
		_case(names[f], f, false)
	_case("6 ON 5", DefenseFormation.F.PRESS, true)
	_possible_only()
	_keeper_never()
	_moves_in()

func _play(f: int, man_up: bool) -> Play:
	if _flow == null:
		var c := Career.new_game("SJCU", "A", "B", 11)
		c.queue.clear()
		_flow = MatchFlow.new(c.team(), c.teams["CULA"], 99, 2.0)
	_flow._start_attack(Play.Kind.HALF_COURT)
	var p := _flow.play
	p.drive_timer = 99.0
	p.formation = f
	for i in 90:
		p.step(1.0 / 60.0)   # (the formation sets up)
	if man_up:
		p._exclusion(p.defenders[4], p.attackers[4])
		p.freeze = 0.0
		p.restart = false
		for i in 60:
			p.step(1.0 / 60.0)
	return p

func _tag(p: Play, t: String) -> Swimmer:
	for a in p.attackers:
		if a.tag == t:
			return a
	return null

## The shooter at the point, his guard set on him (pressed long enough), square in his line to
## the goal, a good defender, the rest of the defence clear of the shot.
func _setup(p: Play, guard_dfn: float) -> Swimmer:
	var s := _tag(p, "3")
	p.give_ball(s)
	p.restart = false
	p.pass_first = false
	s.pos = Vector2(24.6, 10.0)
	var g: Swimmer = null
	for d in p.defenders:
		if not d.out and d != p.defenders[4]:
			g = d
			break
	for d in p.defenders:
		d.mark = null if d != g else s
		d.press = DefenseFormation.Press.HOLD
		d.press_on = null
		if d != g and not d.out:
			d.pos = Vector2(18.0, d.pos.y)
	g.pos = s.pos + Vector2(0.9, 0.0)   # in front of him, on his line to the goal
	g.guard_on = s
	g.guard_t = Play.GUARD_TIME + 1.0
	g.player.defense = int(guard_dfn * 10.0)   # (0-100: what ShotModel.blocker reads)
	return g

## What the real shot does, released now at `cross_y` with `power`: blocked how many times in ROLLS.
func _blocked(p: Play, cross_y: float, power: float) -> int:
	var n := 0
	var s := p.holder
	var mods := p.shot_mods(s)
	var rng := RandomNumberGenerator.new()
	for k in ROLLS:
		rng.seed = 900 + k
		var res := ShotModel.resolve(s.pos, cross_y, power, p.shot_skill(s, mods), 0.9, p._blockers(s), p.keeper.pos.y, 50.0, rng, false, mods,
			{"exact": true, "release": Attributes.release_read(s.player) + p.keeper_late, "arms": p._arms(s), "pace": p.shot_pace(s),
			"contact": p.contact_on(s), "speed_k": p.cpu_speed_k(power)})
		if String(res.outcome) == "block":
			n += 1
	return n

func _case(name: String, f: int, man_up: bool) -> void:
	var p := _play(f, man_up)
	var g := _setup(p, 10.0)
	var power := 0.2
	var x := p.sure_block(Geo.GOAL_Y, power)
	r.check(not x.is_empty(), "%s: a set guard square in the line, a soft shot: red X" % name)
	if x.is_empty():
		return
	var at: Vector2 = x.at
	r.check(absf(at.y - Geo.GOAL_Y) < 0.05 and at.x > p.holder.pos.x and at.x <= g.pos.x + 0.01,
		"%s: ...on the shot's line, where it meets him (%.2f, %.2f)" % [name, at.x, at.y])
	r.check(_blocked(p, Geo.GOAL_Y, power) == ROLLS, "%s: ...and that shot is blocked every time (%d rolls)" % [name, ROLLS])
	# aimed round him: the X goes
	var around := Geo.GOAL_Y + 1.4
	r.check(p.sure_block(around, power).is_empty(), "%s: aimed round him, no X" % name)

## A man in the lane who can get a hand to it, but isn't certain to: no X (though it's blocked sometimes).
func _possible_only() -> void:
	var p := _play(DefenseFormation.F.PRESS, false)
	var g := _setup(p, 10.0)
	g.mark = null          # off the ball: not his guard, hands only stretching (OFF_BALL_HANDS)
	g.guard_on = null
	g.guard_t = 0.0
	g.pos = p.holder.pos + Vector2(2.5, 0.25)
	var x := p.sure_block(Geo.GOAL_Y, 0.2)
	var n := _blocked(p, Geo.GOAL_Y, 0.2)
	r.check(x.is_empty() and n > 0 and n < ROLLS, "a man off the ball in the lane: blocked %d of %d, a chance, so no X" % [n, ROLLS])
	var p2 := _play(DefenseFormation.F.PRESS, false)
	var g2 := _setup(p2, 10.0)
	var x2 := p2.sure_block(Geo.GOAL_Y, 1.0)
	var n2 := _blocked(p2, Geo.GOAL_Y, 1.0)
	r.check(x2.is_empty() == (n2 < ROLLS), "the same guard against a full-power shot: X %s, blocked %d of %d (an X only when it's every time)" % ["no" if x2.is_empty() else "yes", n2, ROLLS])
	g2.player.defense = 10
	var x3 := p2.sure_block(Geo.GOAL_Y, 0.2)
	r.check(x3.is_empty() or _blocked(p2, Geo.GOAL_Y, 0.2) == ROLLS, "a weak guard in the same spot: an X only if it's certain")

func _keeper_never() -> void:
	var p := _play(DefenseFormation.F.PRESS, false)
	var g := _setup(p, 10.0)
	g.pos = Vector2(18.0, 3.0)
	g.mark = null
	p.keeper.pos = Vector2(Geo.KEEPER_X, Geo.GOAL_Y)
	r.check(p.sure_block(Geo.GOAL_Y, 0.2).is_empty(), "a shot straight at the keeper: never a red X")

## The guard steps into the line: the X comes; out of it again, it goes.
func _moves_in() -> void:
	var p := _play(DefenseFormation.F.PRESS, false)
	var g := _setup(p, 10.0)
	var on := g.pos
	g.pos = on + Vector2(0.0, 1.6)
	var before := p.sure_block(Geo.GOAL_Y, 0.2).is_empty()
	g.pos = on
	var during := not p.sure_block(Geo.GOAL_Y, 0.2).is_empty()
	r.check(before and during, "a defender moving into the line: no X, then the X")
