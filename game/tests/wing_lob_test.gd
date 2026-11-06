extends RefCounted
## THE WING-TO-WING LOB (Play.is_wing_lob, WING_LOB_PEAK): a ball from wing to wing across the goal
## goes up and over the keeper, by the same height rules every pass is settled with.
##   godot --headless --path game -- --test wing_lob

var r   # the test runner

const DT := 1.0 / 60.0
const TRIES := 120

func run(runner) -> void:
	r = runner
	print("wing-to-wing lob")
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	var lob := _throws(true)
	var flat := _throws(false)
	r.check(lob.keeper == 0 and lob.caught >= TRIES * 0.95,
		"wing to wing, the keeper right in its line: never his (%d of %d caught by the far wing)" % [lob.caught, TRIES])
	r.check(flat.keeper > 0, "(the same ball thrown flat, the old way: he takes %d of %d)" % [flat.keeper, TRIES])
	r.check(lob.top > 2.5 and lob.top < 3.1 and lob.mid_u > 0.4 and lob.mid_u < 0.6,
		"the lob's arc: up to %.2f m, highest %.0f%% of the way" % [lob.top, lob.mid_u * 100.0])
	r.check(absf(lob.dur - flat.dur) < 0.001, "its pace is the pass's own (%.2f s either way)" % lob.dur)
	r.check(lob.land_z < 1.3, "it comes down to catching height at the far wing (%.2f m)" % lob.land_z)
	# what is and isn't a wing-to-wing lob
	var p := _play(7)
	for a in p.attackers:
		a.pos = a.home   # (set up: a fresh possession starts with the attack still swimming in)
	var w1 := _tag(p, "1")
	var w5 := _tag(p, "5")
	r.check(Play.is_wing_lob(w1.pos, w5.pos, w1, w5) and Play.is_wing_lob(w5.pos, w1.pos, w5, w1), "1 -> 5 and 5 -> 1: lobs")
	r.check(not Play.is_wing_lob(w1.pos, _tag(p, "3").pos, w1, _tag(p, "3")) and not Play.is_wing_lob(w1.pos, _tag(p, "C").pos, w1, _tag(p, "C")),
		"a wing's ball to the point or the centre: an ordinary pass")
	r.check(not Play.is_wing_lob(Vector2(14.0, 16.0), Vector2(14.0, 4.0), w1, w5), "the wings out on a break, far from the goal: an ordinary pass")
	r.check(is_equal_approx(Play.peak_for(w1.pos, _tag(p, "3").pos, w1, _tag(p, "3")), Play.pass_peak(w1.pos.distance_to(_tag(p, "3").pos))),
		"every other pass loops as it always did")

var _flow: MatchFlow = null

## A fresh possession (one career and match for all of them: making careers is slow).
func _play(seed_v: int) -> Play:
	if _flow == null:
		var c := Career.new_game("SJCU", "A", "B", 7)
		c.queue.clear()
		_flow = MatchFlow.new(c.team(), c.teams["CULA"], 99, 2.0)
	_flow._start_attack(Play.Kind.HALF_COURT)
	_flow.play.rng.seed = seed_v
	return _flow.play

func _tag(p: Play, t: String) -> Swimmer:
	for a in p.attackers:
		if a.tag == t:
			return a
	return null

## TRIES wing-to-wing balls with the keeper standing right in their line; `lob` false: thrown flat.
func _throws(lob: bool) -> Dictionary:
	var out := {"keeper": 0, "caught": 0, "top": 0.0, "mid_u": 0.0, "dur": 0.0, "land_z": 0.0}
	for i in TRIES:
		var p := _play(100 + i)
		var w1 := _tag(p, "1")
		var w5 := _tag(p, "5")
		for s in p.attackers + p.defenders:
			s.vel = Vector2.ZERO
		for d in p.defenders:
			d.pos = Vector2(15.0, d.pos.y)   # (only the keeper near it)
		w1.pos = Vector2(27.6, 15.0)
		w5.pos = Vector2(27.6, 5.0)
		p.give_ball(w1)
		p.pass_to(w5)
		if not lob:
			p.ball.peak = Play.pass_peak(p.ball.from.distance_to(p.ball.to))
		# the keeper out on the ball's line, in front of his goal, where it crosses
		p.keeper.pos = p.ball.from.lerp(p.ball.to, 0.5) + Vector2(0.3, 0.0)
		out.dur = p.ball.dur
		var top := 0.0
		var top_u := 0.0
		while p.ball.state == Ball.State.PASS:
			p._fly_pass(DT)
			if p.ball.z > top:
				top = p.ball.z
				top_u = p.ball.t
			if p.ball.state == Ball.State.PASS:
				out.land_z = p.ball.z
		if p.over and p.result.get("text", "") == "KEEPER CLAIMS IT":
			out.keeper += 1
		elif p.holder == w5:
			out.caught += 1
		out.top = top
		out.mid_u = top_u
	return out
