extends RefCounted
## A goal's show (GoalShow) in a real match screen: the stages in order and on time, the ball
## into the net and the net's give where it hit, the scorer named (never made up), the board
## going up once, the clock stopped, the next possession, the keeper's and the scorer's
## reactions, tie / go-ahead / late / game-winner / shootout variants, the tap to skip, small
## screens, the cost of a frame, and every stat counted exactly once.
##   godot --headless --path game -- --test goal_show
##   godot --path game -- --test goal_show_png <outdir>   (screenshots, needs a window)

const DT := 1.0 / 30.0

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("goal show")
	_classify()
	_timing()
	_shootout_rule()
	await _real_goal()
	await _screen_goals()

# ------------------------------------------------------------------ pure logic
func _state(q: int, clock: float, a: int, b: int) -> MatchState:
	var st := MatchState.new()
	st.quarter = q
	st.clock = clock
	st.score = [a, b]
	return st

func _classify() -> void:
	var c := GoalShow.classify(_state(1, 90.0, 0, 0), 0)
	r.check(c.kind == "lead" and not c.late, "0-0 in Q1: the go-ahead goal (TAKES THE LEAD!), not late")
	c = GoalShow.classify(_state(2, 50.0, 2, 0), 0)
	r.check(c.kind == "" and not c.late, "3-0: a normal goal")
	c = GoalShow.classify(_state(2, 50.0, 1, 2), 0)
	r.check(c.kind == "tie", "1-2 to 2-2: TIE GAME!")
	c = GoalShow.classify(_state(3, 50.0, 2, 1), 1)
	r.check(c.kind == "tie", "...for their goals too")
	c = GoalShow.classify(_state(4, 30.0, 4, 4), 0)
	r.check(c.kind == "lead" and c.late, "4-4 with 0:30 left in the 4th: go-ahead and late, but no GAME WINNER (time's left)")
	c = GoalShow.classify(_state(4, 30.0, 6, 2), 0)
	r.check(c.kind == "" and not c.late, "a blowout late in the 4th isn't a big late goal")
	c = GoalShow.classify(_state(4, 90.0, 3, 3), 0)
	r.check(not c.late, "with 1:30 left it isn't late yet")
	c = GoalShow.classify(_state(4, 0.0, 3, 3), 0)
	r.check(c.kind == "winner" and c.late, "at the final buzzer, breaking a tie: GAME WINNER!")
	c = GoalShow.classify(_state(4, 0.0, 2, 3), 0)
	r.check(c.kind == "tie", "at the final buzzer, levelling: TIE GAME! (a shootout's next), no winner")
	c = GoalShow.classify(_state(3, 0.0, 3, 3), 0)
	r.check(c.kind == "lead", "at the end of the 3rd: no winner")
	var so := _state(4, 0.0, 3, 3)
	so.in_shootout = true
	r.check(GoalShow.classify(so, 1, false).kind == "", "a shootout goal: plain")
	r.check(GoalShow.classify(so, 1, true).kind == "winner", "...unless it settles the shootout")
	r.check(GoalShow.ordinal(1) == "1ST" and GoalShow.ordinal(2) == "2ND" and GoalShow.ordinal(3) == "3RD"
		and GoalShow.ordinal(4) == "4TH" and GoalShow.ordinal(11) == "11TH" and GoalShow.ordinal(22) == "22ND", "ordinals")

func _show(st: MatchState, side: int = 0, decides := false) -> GoalShow:
	var g := GoalShow.new()
	g.start(side, null, st, "", Color.WHITE, Vector2(Geo.GOAL_X, Geo.GOAL_Y), decides)
	return g

func _timing() -> void:
	var g := _show(_state(2, 60.0, 3, 0))
	r.check_between(g.total(), 2.3, 2.8, "a normal goal's show (s)")
	r.check(is_equal_approx(GoalShow.IMPACT_AT, 0.25) and is_equal_approx(GoalShow.CELEBRATE_AT, 0.65)
		and is_equal_approx(g.board_at(), 1.7) and is_equal_approx(g.out_at(), 2.2), "the stages: 0.25 GOAL!, 0.65 scorer, 1.7 board, 2.2 out")
	var seen := []
	while g.active() and g.t < g.total() + 0.1:
		g.step(DT)
		if seen.is_empty() or seen[-1] != g.stage:
			seen.append(g.stage)
	r.check(seen == [GoalShow.Stage.DETECTED, GoalShow.Stage.IMPACT, GoalShow.Stage.CELEBRATION, GoalShow.Stage.SCOREBOARD, GoalShow.Stage.TRANSITION],
		"stages in order: %s" % str(seen))
	g = _show(_state(2, 60.0, 3, 0))
	g.step(0.1)
	r.check(not g.can_skip() and g.time_scale() < 1.0, "the first 0.25 s can't be skipped; the play's slowed for the hit")
	g.step(0.2)
	r.check(g.can_skip() and is_equal_approx(g.time_scale(), 1.0), "...after that a tap skips, at full speed")
	var late := _show(_state(4, 20.0, 5, 5))
	var win := _show(_state(4, 0.0, 5, 5))
	var so_st := _state(4, 0.0, 5, 5)
	so_st.in_shootout = true
	var so := _show(so_st)
	r.check(late.total() > g.total() and win.total() > late.total(), "a late goal holds a little longer, the winner longer still")
	r.check(win.total() <= 3.3, "...never past 3.3 s (%.2f)" % win.total())
	r.check(so.total() < g.total() - 0.4 and so.total() >= 1.5, "a shootout goal's show is shorter (%.2f s)" % so.total())
	r.check(win.headline_swap() == "GAME WINNER!" and _show(_state(2, 60.0, 1, 2)).headline_swap() == "TIE GAME!"
		and _show(_state(1, 90.0, 0, 0)).headline_swap() == "", "GAME WINNER! / TIE GAME! take over the word; a go-ahead keeps GOAL!")
	var b := _show(_state(2, 60.0, 3, 0), 1)
	b.step(1.0)
	r.check(b.board_fx().is_empty(), "the board doesn't move before the scoreboard stage")
	b.step(0.75)
	var fx := b.board_fx()
	r.check(int(fx.get("side", -1)) == 1 and int(fx.get("add", 0)) == 1, "...then the scorer's side goes up by one")
	# never wider than the screen, the biggest word at the top of its punch, the narrowest screen
	for w in [400.0, 480.0, 585.0]:
		var s := GoalShow.word_size("GAME WINNER!", GoalShow.WORD_BIG, 1.28, w)
		r.check(UI.text_width("GAME WINNER!", s, "big") + 4.0 <= w, "GAME WINNER! fits a %d px wide screen" % int(w))

func _shootout_rule() -> void:
	r.check(MatchFlow.shootout_decided(3, 0, 3) and not MatchFlow.shootout_decided(3, 1, 3), "shootout: decided once it can't be caught")
	r.check(MatchFlow.shootout_decided(4, 3, 5) and not MatchFlow.shootout_decided(4, 4, 5), "...and in sudden death")
	var f := MatchFlow.new(League.make_team(2, 1), League.make_team(3, 1), 5, 2.0)
	f.state.in_shootout = true
	f.shootout_round = 4
	f.state.shootout = [3, 3]
	r.check(f.their_penalty_wins(), "their 5th penalty to go 4-3: the game winner")
	f.state.shootout = [3, 2]
	r.check(not f.their_penalty_wins(), "their 5th to level at 3-3: not")
	f.shootout_round = 1
	f.state.shootout = [0, 1]
	r.check(not f.their_penalty_wins(), "their 2nd to lead 2-0: not yet")

# ------------------------------------------------------------------ in a real match screen
func _screen(seed_v: int = 9) -> Variant:
	Game.match_cfg = {"us": League.make_team(2, 1), "them": League.make_team(3, 1), "seed": seed_v, "minutes": 2.0, "autoplay": true}
	Game.goto("match", Game.match_cfg)
	await r.get_tree().process_frame
	return Game.current_screen

func _frames(ms, secs: float) -> void:
	for _i in int(ceilf(secs / DT)):
		ms._process(DT)

func _tap(ms) -> void:
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = Vector2(240, 160)
	ev.index = 0
	ms._input(ev)
	var up := InputEventScreenTouch.new()
	up.position = ev.position
	up.index = 0
	ms._input(up)

## A goal scored for real: the bot plays until it scores.
func _real_goal() -> void:
	var ms = await _screen(21)
	var f: MatchFlow = ms.flow
	var n := 0
	while not (ms.goal_show.active() and f.phase == MatchFlow.Phase.ATTACK) and n < 60000:
		if f.phase == MatchFlow.Phase.BREAK:
			f.break_done()
		if f.phase == MatchFlow.Phase.FINAL:
			break
		ms._process(DT)
		n += 1
	r.check(ms.goal_show.active() and f.phase == MatchFlow.Phase.ATTACK, "TEST 1: the bot scored a real goal and the show started")
	if not ms.goal_show.active():
		return
	var p: Play = f.play
	var g: GoalShow = ms.goal_show
	var before: Array = [f.state.score[0], f.state.score[1]]
	var by_before: int = f.state.goal_by[0].size()
	var clock: float = f.state.clock
	var sc: float = p.shot_clock
	var who: PoloPlayer = p.result.get("scorer")
	r.check(who != null and g.scorer == who, "TEST 3: the scorer on screen is the play's scorer (%s)" % (who.tag() if who else "?"))
	r.check(g.hero != null and g.hero.player == who, "...and it's him in the water who celebrates")
	r.check(p.ball.in_net(), "TEST 2: the ball's into the net, not gone")
	r.check(ms.banner.is_empty(), "no other callout over it")
	var hit := false
	var give := 0.0
	var through := false
	var max_zoom := 1.0
	var cheer := false
	var hopped := false
	var slump := false
	var clock_ok := true
	var board_early := false
	var mates_face := true
	var covered := false
	var scale_seen := 1.0
	var stages: Array[int] = []
	var nets := {}
	while ms.goal_show.active() and f.play == p:
		ms._process(DT)
		if not ms.goal_show.active():
			break
		if stages.is_empty() or stages[-1] != g.stage:
			stages.append(g.stage)
		hit = hit or p.ball.net_t >= 0.0
		give = maxf(give, Ball.net_bulge(p.ball.net_t))
		through = through or (p.ball.pos.x - p.ball.net_back_x()) * p.ball.net_side > Ball.NET_GIVE + 0.01
		max_zoom = maxf(max_zoom, ms.view.zoom)
		scale_seen = minf(scale_seen, g.time_scale())
		if g.stage == GoalShow.Stage.CELEBRATION:
			cheer = cheer or g.hero.cheer > 0.5
			hopped = hopped or g.hero.hop > 1.0
			slump = slump or (g.keeper != null and g.keeper.slump > 0.5)
			if g.top >= 0.0 and g.top != GoalShow.TEXT_TOP:
				covered = true   # (moved: it must sit at the one screen-space spot every goal)
			if g.t - GoalShow.CELEBRATE_AT > 0.3:
				for m in g.mates:
					if absf(m.pos.x - g.hero.pos.x) > 0.3 and m.facing != signf(g.hero.pos.x - m.pos.x):
						mates_face = false
		nets = ms._net()
		clock_ok = clock_ok and f.state.clock == clock and p.shot_clock == sc
		board_early = board_early or (f.state.score[0] != before[0])
	r.check(hit and give > 0.5, "TEST 2: it hits the back of the net and the net stretches (%.2f)" % give)
	r.check(not nets.is_empty() and absf(float(nets.get("y", -9.0)) - p.ball.pos.y) < 0.01, "...where it went in (the net gives at the ball's height)")
	r.check(not through, "...and the ball never goes through the back of it")
	r.check(stages.has(GoalShow.Stage.IMPACT) and stages.has(GoalShow.Stage.CELEBRATION) and stages.has(GoalShow.Stage.SCOREBOARD)
		and stages.has(GoalShow.Stage.TRANSITION), "TEST 1: every stage plays: %s" % str(stages))
	r.check(scale_seen < 1.0, "the play slows for the hit")
	r.check(max_zoom > 1.03 and max_zoom < 1.12, "the camera pushes in a little (%.3f)" % max_zoom)
	r.check(cheer and hopped, "TEST 8: the scorer's fist goes up and he bounces")
	r.check(slump, "TEST 7: the beaten keeper's arms drop")
	r.check(not covered and g.place() == GoalShow.TEXT_TOP, "the GOAL! block sits at the same screen spot every goal (%d px)" % int(g.top))
	r.check(mates_face, "his mates nearby turn to him (%d of them)" % g.mates.size())
	r.check(clock_ok, "TEST 5: the game clock and shot clock stand still through the show")
	r.check(not board_early, "TEST 4: the goal isn't counted while the show's on")
	r.check(not ms.goal_show.active() and f.play != p, "the show ends with the possession")
	r.check(f.state.score[0] == before[0] + 1 and f.state.score[1] == before[1], "TEST 4: your score up by exactly one, theirs the same")
	r.check(f.state.goal_by[0].size() == by_before + 1 and f.state.goal_by[0][-1] == who, "TEST 14: the goal's his, once")
	r.check(is_equal_approx(ms.view.zoom, 1.0), "the camera's back to normal")
	r.check(g.hero == null, "the celebration's cleared")
	if f.phase == MatchFlow.Phase.DEFENSE:
		r.check(f.play.defending and is_equal_approx(f.play.shot_clock, Play.SHOT_CLOCK), "TEST 6: their ball next, a fresh 30")
	else:
		r.check(f.phase == MatchFlow.Phase.BREAK or f.phase == MatchFlow.Phase.FINAL, "TEST 6: their ball next (or the quarter's over)")

## Goals set up straight from the play's end (Play._finish), for every variant.
func _screen_goals() -> void:
	var ms = await _screen(9)
	var f: MatchFlow = ms.flow
	var st := f.state
	var attack := func() -> Play:
		f._start_attack(Play.Kind.HALF_COURT)
		ms._process(DT)   # the screen sees the possession start
		return f.play
	var defend := func() -> Play:
		f._start_defense(Play.Kind.HALF_COURT)
		ms._process(DT)
		return f.play
	# TEST 3 / 14: his name and number, his goals today counted from the box score, the assist once
	var p: Play = attack.call()
	var shooter: Swimmer = p.attackers[2]
	var who: PoloPlayer = shooter.player
	st.add_goal(0, who)
	st.add_goal(0, who)
	var s0: int = st.score[0]
	p.ball.shooter = shooter
	p._finish("goal", "GOAL!", {"scorer": who, "assist": p.attackers[1].player})
	r._feed(ms, p)
	var g: GoalShow = ms.goal_show
	var lines: Array = g._lines()
	r.check(g.active() and lines.size() == 2 and String(lines[0][0]) == ("#%d %s %s" % [who.number, who.first, who.last]).to_upper(),
		"TEST 3: the scorer: %s" % (String(lines[0][0]) if not lines.is_empty() else "-"))
	r.check(String(lines[1][0]) == "3RD GOAL TODAY", "...and his 3rd goal today")
	var assists: int = st.assist_by[0].size()
	_frames(ms, g.total() + 0.2)
	r.check(st.score[0] == s0 + 1 and st.assist_by[0].size() == assists + 1, "TEST 14: the goal and the assist counted once")
	r.check(int(st.scorers[0][who.tag()]) == 3, "...and the box score has his three")
	# no scorer: GOAL! and nothing made up
	p = attack.call()
	p._finish("goal", "GOAL!", {"scorer": null})
	r._feed(ms, p)
	r.check(ms.goal_show.active() and ms.goal_show._lines().is_empty(), "no scorer: GOAL! with no name")
	_frames(ms, ms.goal_show.total() + 0.2)
	# TEST 11: the tap to skip, never twice
	p = attack.call()
	s0 = st.score[0]
	var by0: int = st.goal_by[0].size()
	p._finish("goal", "GOAL!", {"scorer": p.attackers[1].player})
	r._feed(ms, p)
	ms._process(DT)
	_tap(ms)
	r.check(ms.goal_show.active() and ms.end_timer > 1.0, "TEST 11: a tap before the ball's in doesn't skip")
	_frames(ms, 0.3)
	var hold: float = ms.end_timer
	_tap(ms)
	r.check(ms.end_timer == 0.0 and hold > 1.0, "TEST 11: a tap once it's in skips the rest")
	_tap(ms)
	_tap(ms)
	ms._process(DT)
	r.check(not ms.goal_show.active() and st.score[0] == s0 + 1 and st.goal_by[0].size() == by0 + 1, "TEST 11: skipped: counted once, the show gone")
	_frames(ms, 0.5)
	r.check(st.score[0] == s0 + 1, "...and taps after it never count it again")
	r.check(f.phase == MatchFlow.Phase.DEFENSE and not ms.aim.active, "...on to their ball, and the tap didn't throw anything")
	r.check(is_equal_approx(ms.view.zoom, 1.0) and ms.view.zoom_to == 1.0, "...the camera reset")
	# after the show, touches play again (no overlay left blocking them)
	p = attack.call()
	ms._press(Vector2(200, 150), 0)
	r.check(ms.aim.active, "TEST 12: after a goal, the next touch plays as normal")
	ms.aim.cancel()
	# their goal in play: their score once, then your ball
	p = defend.call()
	var t0: int = st.score[1]
	var y0: int = st.score[0]
	p._finish("goal", "GOAL!", {"scorer": p.attackers[1].player})
	r._feed(ms, p)
	r.check(ms.goal_show.active() and ms.goal_show.side == 1 and ms.goal_show.keeper == p.keeper, "their goal: the show, your keeper beaten")
	_frames(ms, 1.0)
	r.check(p.keeper.slump > 0.5, "TEST 7: your keeper's arms drop")
	_frames(ms, ms.goal_show.total())
	r.check(st.score[1] == t0 + 1 and st.score[0] == y0, "their goal counted once, yours unchanged")
	r.check(f.phase == MatchFlow.Phase.ATTACK and not f.play.defending, "TEST 6: then your ball")
	# TEST 9: tie, go-ahead, late, game winner
	st.score = [2, 3]
	p = attack.call()
	p._finish("goal", "GOAL!", {"scorer": p.attackers[1].player})
	r._feed(ms, p)
	r.check(ms.goal_show.kind == "tie", "TEST 9: 2-3 to 3-3: TIE GAME!")
	_frames(ms, GoalShow.CELEBRATE_AT + GoalShow.SWAP_AT + 0.1)
	r.check(ms.goal_show.board_fx().is_empty(), "...the board still waits")
	_frames(ms, ms.goal_show.board_at() - ms.goal_show.t + 0.05)
	r.check(bool(ms.goal_show.board_fx().get("big", false)), "...then goes up with the bigger pulse")
	_frames(ms, 1.0)
	st.score = [3, 3]
	p = defend.call()
	p._finish("goal", "GOAL!", {"scorer": p.attackers[1].player})
	r._feed(ms, p)
	r.check(ms.goal_show.kind == "lead" and ms.goal_show.team != "", "TEST 9: their go-ahead: %s TAKES THE LEAD!" % ms.goal_show.team)
	_frames(ms, ms.goal_show.total() + 0.1)
	st.quarter = 4
	st.score = [4, 4]
	p = attack.call()
	st.clock = 40.0
	p._finish("goal", "GOAL!", {"scorer": p.attackers[1].player})
	r._feed(ms, p)
	r.check(ms.goal_show.late and ms.goal_show.kind == "lead", "TEST 9: the go-ahead with 0:40 left: late, but not the game winner")
	r.check(ms.goal_show.total() > 2.6, "...a little longer (%.2f s)" % ms.goal_show.total())
	_frames(ms, ms.goal_show.total() + 0.1)
	st.score = [5, 5]
	p = attack.call()
	st.clock = 0.0   # (a shot in the air at the buzzer)
	p._finish("goal", "GOAL!", {"scorer": p.attackers[1].player})
	r._feed(ms, p)
	r.check(ms.goal_show.kind == "winner", "TEST 9: at the final buzzer, breaking the tie: GAME WINNER!")
	_frames(ms, ms.goal_show.total() + 0.2)
	r.check(f.phase == MatchFlow.Phase.FINAL and st.winner() == 0 and st.score == [6, 5], "...and the game is over, won 6-5")
	# TEST 10: the shootout: shorter, the shootout score once, the score itself untouched
	ms = await _screen(13)
	f = ms.flow
	st = f.state
	st.quarter = 4
	st.score = [4, 4]
	st.clock = 0.0
	st.in_shootout = true
	f._start_attack(Play.Kind.PENALTY)
	ms._process(DT)
	p = f.play
	p._finish("goal", "GOAL!", {"scorer": p.taker.player if p.taker != null else p.attackers[0].player})
	r._feed(ms, p)
	r.check(ms.goal_show.shootout and ms.goal_show.total() < 2.2 and ms.goal_show.kind == "", "TEST 10: your penalty: the short show (%.2f s)" % ms.goal_show.total())
	r.check(ms.goal_show.hero == null or ms.goal_show.mates.is_empty(), "...the taker on his own")
	_frames(ms, ms.goal_show.total() + 0.1)
	r.check(st.shootout == [1, 0] and st.score == [4, 4], "TEST 10: the shootout goal counted once, the score unchanged")
	r.check(f.phase == MatchFlow.Phase.SHOOTOUT_THEM, "...and on to their penalty")
	# their shootout penalty that wins it: you're in goal and nobody dives (a kick at the keeper
	# can still be saved: take it again until one goes in)
	ms.autoplay = false
	for _try in 12:
		st.shootout = [3, 3]
		f.shootout_round = 4
		f.duel = null
		f.opp = f._their_penalty()
		f.phase = MatchFlow.Phase.SHOOTOUT_THEM
		ms._process(DT)
		f.their_ball_done()
		var guard := 0
		while f.duel != null and not f.duel.done() and guard < 600:
			ms._process(DT)
			guard += 1
		if f.duel != null and f.duel.outcome == "goal":
			break
	ms.autoplay = true
	if f.duel != null and f.duel.outcome == "goal":
		r.check(ms.goal_show.active() and ms.goal_show.kind == "winner" and ms.goal_show.shootout, "TEST 10: their winning penalty: GAME WINNER!, the short show")
		r.check(ms.goal_show.scorer == f.opp.shooter and ms.goal_show.keeper == ms.duel_bodies[0], "...their taker named, your keeper beaten")
		_frames(ms, ms.goal_show.total() + 0.2)
		r.check(st.shootout == [3, 4] and f.phase == MatchFlow.Phase.FINAL and st.winner() == 1, "...counted once: lost 3-4 on penalties")
	else:
		r.check(f.duel != null and f.duel.done(), "their penalty played out (%s): no goal to check" % (f.duel.outcome if f.duel else "-"))
	# TEST 13: a frame of the show costs next to nothing
	ms = await _screen(9)
	f = ms.flow
	f._start_attack(Play.Kind.HALF_COURT)
	ms._process(DT)
	p = f.play
	p._finish("goal", "GOAL!", {"scorer": p.attackers[1].player})
	r._feed(ms, p)
	var t_us := Time.get_ticks_usec()
	var frames := 0
	while ms.goal_show.active() and frames < 200:
		ms._process(DT)
		ms.canvas.queue_redraw()
		frames += 1
	var per := float(Time.get_ticks_usec() - t_us) / maxf(1.0, frames) / 1000.0
	r.check(per < 4.0, "TEST 13: a frame of the show: %.3f ms (logic)" % per)
	Game.goto("title")
	await r.get_tree().process_frame

# ------------------------------------------------------------------ screenshots (needs a window)
## Each stage of a real goal, the variants, and three screen shapes (16:9, a wide phone, 4:3).
static func shots(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	for shape in [[Vector2i(1440, 810), "169"], [Vector2i(1752, 810), "phone"], [Vector2i(1080, 810), "43"]]:
		DisplayServer.window_set_size(shape[0])
		await tree.create_timer(0.3).timeout
		var cfg := {"us": League.make_team(3), "them": League.make_team(0), "seed": 11, "minutes": 3.0, "autoplay": true}
		Game.match_cfg = cfg
		Game.goto("match", cfg)
		await tree.create_timer(0.4).timeout
		var ms = Game.current_screen
		Engine.time_scale = 6.0
		await _wait(tree, func(): return ms.goal_show.active() or ms.flow.phase == MatchFlow.Phase.FINAL, 20000.0)
		Engine.time_scale = 0.25
		await _wait(tree, func(): return ms.goal_show.t >= 0.1)
		await _shot(runner, out, "%s_1_detected" % shape[1])
		await _wait(tree, func(): return ms.goal_show.t >= 0.33)
		await _shot(runner, out, "%s_2_impact" % shape[1])
		await _wait(tree, func(): return ms.goal_show.t >= 1.0)
		await _shot(runner, out, "%s_3_celebration" % shape[1])
		await _wait(tree, func(): return ms.goal_show.t >= ms.goal_show.board_at() + 0.08)
		await _shot(runner, out, "%s_4_scoreboard" % shape[1])
		await _wait(tree, func(): return ms.goal_show.t >= ms.goal_show.out_at() + 0.2)
		await _shot(runner, out, "%s_5_transition" % shape[1])
		Engine.time_scale = 1.0
		await _wait(tree, func(): return not ms.goal_show.active())
		await tree.create_timer(0.2).timeout
		await _shot(runner, out, "%s_6_next" % shape[1])
		if shape[1] != "169":
			continue
		# the variants, from the play's end
		var f: MatchFlow = ms.flow
		for v in [["tie", 4, 50.0, [2, 3], 0], ["lead", 4, 40.0, [3, 3], 1], ["winner", 4, 0.0, [5, 5], 0]]:
			f.state.quarter = v[1]
			f.state.score = v[3]
			if v[4] == 0:
				f._start_attack(Play.Kind.HALF_COURT)
			else:
				f._start_defense(Play.Kind.HALF_COURT)
			f.state.clock = v[2]
			await tree.process_frame
			var p: Play = f.play
			p._finish("goal", "GOAL!", {"scorer": p.attackers[1].player})
			Engine.time_scale = 0.25
			await _wait(tree, func(): return ms.goal_show.active() and ms.goal_show.t >= 1.15)
			await _shot(runner, out, "variant_%s" % v[0])
			await _wait(tree, func(): return ms.goal_show.t >= ms.goal_show.board_at() + 0.06)
			await _shot(runner, out, "variant_%s_board" % v[0])
			Engine.time_scale = 4.0
			await _wait(tree, func(): return not ms.goal_show.active())
			Engine.time_scale = 1.0
			if f.phase == MatchFlow.Phase.FINAL:
				break
	Engine.time_scale = 1.0
	DisplayServer.window_set_size(Vector2i(1440, 810))

## The quarter-break scoreboards (END OF 1ST QUARTER, HALFTIME, END OF 3RD QUARTER, a long name)
## and GOAL! from every kind of play at both ends of the pool, at three screen shapes. Prints
## where the GOAL! block sat each time: it must be the same spot, every time.
##   godot --path game -- --test break_png <outdir>
static func break_shots(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	var spots := {}
	for shape in [[Vector2i(1440, 810), "169"], [Vector2i(1752, 810), "phone"], [Vector2i(1080, 810), "43"]]:
		DisplayServer.window_set_size(shape[0])
		await tree.create_timer(0.3).timeout
		var them := League.make_team(0)
		if shape[1] == "phone":
			them.name = "Northern Pennsylvania Mountain Lions"   # (a club keeps its whole name: the longest case)
		var cfg := {"us": League.make_team(3), "them": them, "seed": 11, "minutes": 3.0, "autoplay": true}
		Game.match_cfg = cfg
		Game.goto("match", cfg)
		await tree.create_timer(0.4).timeout
		var ms = Game.current_screen
		var f: MatchFlow = ms.flow
		# GOAL! from each kind of play, yours (their goal, on the right) and theirs (yours, on the left)
		for v in [["half", Play.Kind.HALF_COURT, 0, false], ["counter", Play.Kind.COUNTER, 0, false],
				["penalty", Play.Kind.PENALTY, 0, false], ["six_on_five", Play.Kind.HALF_COURT, 0, true],
				["theirs", Play.Kind.HALF_COURT, 1, false], ["theirs_counter", Play.Kind.COUNTER, 1, false]]:
			f.state.quarter = 1 + (spots.size() % 3)
			f.state.clock = 200.0
			if v[2] == 0:
				f._start_attack(v[1])
			else:
				f._start_defense(v[1])
			await tree.process_frame
			var p: Play = f.play
			if v[3]:
				p.man_up = Play.MAN_UP_TIME
			ms.view.zoom = 1.0 + 0.04 * (spots.size() % 3)
			p._finish("goal", "GOAL!", {"scorer": p.attackers[mini(1 + spots.size() % 4, p.attackers.size() - 1)].player})
			Engine.time_scale = 0.25
			await _wait(tree, func(): return ms.goal_show.active() and ms.goal_show.t >= 1.15)
			var cam: Vector2 = ms.view.to_screen(ms.goal_show.hero.pos) if ms.goal_show.hero != null else Vector2(-1, -1)
			spots["%s_%s" % [shape[1], v[0]]] = ms.goal_show.top
			print("  GOAL! %s %s: block top %.1f px (scorer on screen at %s, zoom %.3f)" % [shape[1], v[0], ms.goal_show.top, str(cam.round()), ms.view.zoom])
			await _shot(runner, out, "goal_%s_%s" % [shape[1], v[0]])
			Engine.time_scale = 6.0
			await _wait(tree, func(): return not ms.goal_show.active())
			Engine.time_scale = 1.0
		# the three breaks
		for q in [1, 2, 3]:
			f.state.quarter = q
			f.state.score = [[3, 2], [7, 7], [12, 9]][q - 1]
			f._quarter_end()
			await tree.create_timer(0.3).timeout
			await _shot(runner, out, "break_%s_q%d" % [shape[1], q])
			var sc_before: String = str(f.state.score)
			ms._press(Vector2(4, 4), 0)   # the real tap: continue
			print("  break Q%d %s: tap -> %s, Q%d, score %s (was %s)" % [q, shape[1], "ON" if f.phase != MatchFlow.Phase.BREAK else "STUCK",
				f.state.quarter, str(f.state.score), sc_before])
			await tree.process_frame
	var tops := {}
	for k in spots:
		tops[spots[k]] = true
	print("GOAL! block tops seen: %s (%s)" % [str(tops.keys()), "ONE SPOT" if tops.size() == 1 else "MOVED"])
	Engine.time_scale = 1.0
	DisplayServer.window_set_size(Vector2i(1440, 810))

static func _wait(tree: SceneTree, cond: Callable, limit: float = 6000.0) -> void:
	var n := 0.0
	while not cond.call() and n < limit:
		await tree.process_frame
		n += 1.0

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)
