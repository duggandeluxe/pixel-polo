extends RefCounted
## The 6 on 5's clock and the period's end:
##  - the 6 on 5 timer holds until the power play's first pass, then runs
##  - a 6 on 5 still running at the buzzer carries over: the team that had it gets it again, set up,
##    if it wins the sprint, and not if the other team wins it; a goal ends it (no carry)
##   godot --headless --path game -- --test man_up_carry

const DT := 1.0 / 60.0

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("man_up_carry")
	_waits_for_pass()
	_carry(0, true, true)    # yours, you win the sprint: 6 on 5 again
	_carry(0, false, false)  # yours, they win it: nothing
	_carry(1, false, true)   # theirs, they win it: 6 on 5 again (you're a man down)
	_carry(1, true, false)   # theirs, you win it: nothing
	_goal_ends_it()

func _flow(seed_value: int) -> MatchFlow:
	var f := MatchFlow.new(League.make_team(2, 1), League.make_team(3, 1), seed_value, MatchState.QUARTER_MIN)
	f.auto_keeper = 0.5
	return f

func _waits_for_pass() -> void:
	var f := _flow(11)
	f._start_attack(Play.Kind.HALF_COURT)
	var p := f.play
	p._exclusion(p.defenders[2], p.attackers[2])
	var start := p.man_up
	for _i in 240:   # 4 s: the whistle's freeze, then the free throw held
		p.step(DT)
		if p.over:
			break
	r.check(not p.over and is_equal_approx(p.man_up, start) and not p.man_up_live,
		"man-up: the timer holds until the first pass (%.2f of %.2f)" % [p.man_up, start])
	var mate: Swimmer = null
	for a in p.attackers:
		if a != p.holder and not a.out and a.tag != "C":
			mate = a
	p._pass(mate.pos, mate)
	for _i in 60:
		p.step(DT)
		if p.over:
			break
	r.check(p.man_up_live and p.man_up < start - 0.5, "man-up: ...then runs once it's passed (%.2f)" % p.man_up)

## A 6 on 5 for `side` (0 yours) with time left at the buzzer; the sprint won by you (`we_won`).
func _carry(side: int, we_won: bool, expect: bool) -> void:
	var f := _flow(20 + side * 2 + int(we_won))
	if side == 0:
		f._start_attack(Play.Kind.HALF_COURT)
	else:
		f._start_defense(Play.Kind.HALF_COURT)
	var p := f.play
	var d := p.defenders[3]
	p._exclusion(d, p.attackers[3])
	p.man_up = 7.0
	f.state.clock = 0.0
	p.freeze = 0.0
	p.ball.state = Ball.State.HELD
	p.buzzer()
	if side == 0:
		f.attack_done()
	else:
		f.defense_done()
	var label := "%s 6 on 5, %s sprint" % ["your" if side == 0 else "their", "you win the" if we_won else "they win the"]
	r.check(f.phase == MatchFlow.Phase.BREAK and not f.carry_man_up.is_empty(), "carry: %s: the leftover is noted at the buzzer" % label)
	f.break_done()
	f.sprint_done(we_won)
	var q := f.play
	if expect:
		r.check(q != null and q.man_up > 6.9 and q.excluded != null and q.excluded.player == d.player and q.excluded.out,
			"carry: %s: set up 6 on 5 at once, same man out (%.1f s)" % [label, q.man_up if q else -1.0])
		var in_42 := true
		for a in q.attackers:
			in_42 = in_42 and a.home == PlaySetup.HOME_4_2[a.tag] and a.pos.distance_to(a.home) < 0.01
		r.check(in_42, "carry: %s: ...in the 4-2" % label)
		r.check(not q.man_up_live, "carry: %s: ...its clock waiting for the first pass" % label)
	else:
		r.check(q != null and q.man_up <= 0.0 and q.excluded == null, "carry: %s: an even start" % label)
	r.check(f.carry_man_up.is_empty(), "carry: %s: used once" % label)

func _goal_ends_it() -> void:
	var f := _flow(40)
	f._start_attack(Play.Kind.HALF_COURT)
	var p := f.play
	p._exclusion(p.defenders[3], p.attackers[3])
	f.state.clock = 0.0
	p.freeze = 0.0
	p._finish("goal", "GOAL", {"scorer": p.attackers[0].player})
	f.attack_done()
	r.check(f.carry_man_up.is_empty(), "carry: a goal at the buzzer ends the 6 on 5: nothing carries")
