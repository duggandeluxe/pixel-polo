extends RefCounted
## LIVE SIM (the pause menu's SIM): the rest of the match played by the computer for both sides,
## fast-forwarded. A: from the start to full time. B: from the middle, nothing reset. C: every goal
## slows down to be seen, both ways, the board right. D: RETURN TO GAME hands control back, nothing
## lost. E: fouls, exclusions, 6 on 5, penalties and the clocks. F: the periods go by by themselves.
## G: a career game's postgame (stats, XP, the record) exactly as a played one. H: the cost of a
## frame and the speed. I: switching back and forth. Plus: the pause menus, and fairness (an even
## match stays even).
##   godot --headless --path game -- --test sim

const DT := 1.0 / 60.0
const MAX_FRAMES := 60 * 60 * 8   # 8 real minutes: far more than a SIM match takes

var r   # the test runner

func run(runner, only: String = "") -> void:
	r = runner
	print("live sim")
	Store.reset_for_tests()
	for part in ["menus", "start_in_sim", "pregame_sim_to_end", "from_start", "mid_match", "goal_slowdown", "return_to_game", "rules", "switching", "career_game", "sim_to_end", "fairness"]:
		if only != "" and only != part:
			continue
		var t0 := Time.get_ticks_msec()
		await call("_" + part)
		print("    (%s: %.1f s)" % [part, (Time.get_ticks_msec() - t0) / 1000.0])
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

# ------------------------------------------------------------------ helpers
func _screen(seed_v: int, extra: Dictionary = {}) -> Variant:
	var cfg := {"us": League.make_team(2, 1), "them": League.make_team(3, 1), "seed": seed_v, "minutes": 2.0}
	cfg.merge(extra, true)
	Game.match_cfg = cfg
	Game.goto("match", Game.match_cfg)
	await r.get_tree().process_frame
	return Game.current_screen

## The buttons of the top dialog, by their text.
func _dialog_buttons() -> Array[Button]:
	var out: Array[Button] = []
	if Game.overlay == null or Game.overlay.get_child_count() == 0:
		return out
	var layer: Node = Game.overlay.get_child(Game.overlay.get_child_count() - 1)
	for b in layer.find_children("*", "Button", true, false):
		out.append(b as Button)
	return out

func _labels(bs: Array[Button]) -> Array:
	return bs.map(func(b: Button): return b.text)

func _press_button(text: String) -> bool:
	for b in _dialog_buttons():
		if b.text == text:
			b.pressed.emit()
			return true
	return false

func _clear_dialogs() -> void:
	if Game.overlay == null:
		return
	for c in Game.overlay.get_children():
		c.queue_free()
	await r.get_tree().process_frame

## Real frames until `cond` holds (or the guard): how many it took.
func _until(ms, cond: Callable, guard: int = MAX_FRAMES) -> int:
	var n := 0
	while not cond.call() and n < guard:
		ms._process(DT)
		n += 1
	return n

func _frames(ms, secs: float) -> void:
	for _i in int(ceilf(secs / DT)):
		ms._process(DT)

## Box-score sanity: every goal once, shots at least the goals, nothing negative.
func _box_ok(st: MatchState) -> bool:
	return st.goal_by[0].size() == int(st.score[0]) and st.goal_by[1].size() == int(st.score[1]) \
		and int(st.shots[0]) >= int(st.score[0]) and int(st.shots[1]) >= int(st.score[1]) \
		and int(st.saves[0]) >= 0 and int(st.saves[1]) >= 0

# ------------------------------------------------------------------ the pause menus
func _menus() -> void:
	var ms = await _screen(11)
	_until(ms, func(): return ms.flow.phase == MatchFlow.Phase.ATTACK or ms.flow.phase == MatchFlow.Phase.DEFENSE)
	ms._pause()
	await r.get_tree().process_frame
	r.check(_labels(_dialog_buttons()) == ["RESUME", "SIM", "QUIT MATCH"], "the pause menu: RESUME, SIM, QUIT MATCH (%s)" % str(_labels(_dialog_buttons())))
	var bs := _dialog_buttons()
	r.check(bs.size() == 3 and bs[0].size.y == bs[1].size.y and bs[1].size.y == bs[2].size.y, "...all three the same height")
	_press_button("RESUME")
	await r.get_tree().process_frame
	r.check(not ms.paused and not ms.sim, "RESUME: back to the game as ever, no SIM")
	ms._pause()
	await r.get_tree().process_frame
	_press_button("SIM")
	await r.get_tree().process_frame
	r.check(ms.sim and not ms.paused and ms.flow.sim_us, "SIM: the broadcast starts, the brain plays your side")
	ms._process(DT)
	ms._sim_pause()
	await r.get_tree().process_frame
	r.check(_labels(_dialog_buttons()) == ["CONTINUE SIM", "RETURN TO GAME", "QUIT MATCH"], "SIM's pause: CONTINUE SIM, RETURN TO GAME, QUIT MATCH (%s)" % str(_labels(_dialog_buttons())))
	var steps: int = ms.sim_steps
	ms._process(DT)
	r.check(ms.sim_steps == steps, "...and while it's up nothing moves")
	_press_button("CONTINUE SIM")
	await r.get_tree().process_frame
	_frames(ms, 0.5)
	r.check(ms.sim and ms.sim_steps > steps, "CONTINUE SIM: on it goes")
	# PAUSE on the screen (a touch on it) opens SIM's pause; any other touch does nothing
	ms.canvas.queue_redraw()
	await r.get_tree().process_frame
	r.check(ms.sim_rect.size.x > 0.0, "the PAUSE control is on the screen")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = Vector2(240, 150)
	ms._input(tap)
	r.check(not ms.paused, "a touch on the pool does nothing in SIM")
	tap.position = ms.sim_rect.get_center()
	ms._input(tap)
	await r.get_tree().process_frame
	r.check(ms.paused and _labels(_dialog_buttons()).has("RETURN TO GAME"), "a touch on PAUSE opens SIM's pause")
	await _clear_dialogs()
	ms.paused = false
	# JUMP IN, bottom right: RETURN TO GAME in one tap, from exactly where it is (no menu)
	ms.canvas.queue_redraw()
	await r.get_tree().process_frame
	var jr: Rect2 = ms.jump_rect
	var vp: Vector2 = ms.canvas.size
	r.check(jr.size.x > 0.0 and jr.get_center().x > vp.x * 0.5 and jr.get_center().y > vp.y * 0.5, "JUMP IN is on the screen, bottom right (%s)" % str(jr))
	var st0: Array = ms.flow.state.score.duplicate()
	var clock0: float = ms.flow.state.clock
	tap.position = jr.get_center()
	ms._input(tap)
	r.check(ms.jump_down > 0.0 and not ms.paused, "a touch on JUMP IN: it shows pressed in, no menu")
	ms._input(tap)   # (a second tap while it's pressed: nothing more)
	_until(ms, func(): return ms.jump_down <= 0.0, 30)
	r.check(not ms.paused and (ms.sim_return or not ms.sim), "...then control coming back")
	r.check(ms.flow.state.score[0] >= st0[0] and ms.flow.state.score[1] >= st0[1] and ms.flow.state.clock <= clock0 + 0.001, "...nothing reset: the score and the clock carry on")
	_until(ms, func(): return not ms.sim, 60 * 30)
	r.check(not ms.sim and not ms.flow.sim_us, "...and your side is yours again")
	ms.canvas.queue_redraw()
	await r.get_tree().process_frame
	r.check(ms.jump_rect.size.x == 0.0, "...JUMP IN gone with the broadcast")
	ms._pause()
	await r.get_tree().process_frame
	_press_button("SIM")
	await r.get_tree().process_frame
	# a career match: SIM TO END in both menus (no forfeit), and it asks first
	Game.career = Career.new_game("WAGN", "A", "B", 77)
	var c := Game.career
	var cms = await _screen(12, {"us": c.team(), "them": c.opponent(), "career": true, "home": c.is_home()})
	_until(cms, func(): return cms.flow.phase == MatchFlow.Phase.ATTACK or cms.flow.phase == MatchFlow.Phase.DEFENSE)
	cms._pause()
	await r.get_tree().process_frame
	r.check(_labels(_dialog_buttons()) == ["RESUME", "SIM", "SIM TO END"], "career: RESUME, SIM, SIM TO END (%s)" % str(_labels(_dialog_buttons())))
	var cbs := _dialog_buttons()
	r.check(cbs.size() == 3 and cbs[2].size == cbs[1].size, "...SIM TO END the same size as the others")
	_press_button("SIM TO END")
	await r.get_tree().process_frame
	r.check(_labels(_dialog_buttons()) == ["CANCEL", "SIM TO END"] and cms.paused, "SIM TO END asks first: CANCEL, SIM TO END (%s)" % str(_labels(_dialog_buttons())))
	_press_button("CANCEL")
	await r.get_tree().process_frame
	r.check(_labels(_dialog_buttons()) == ["RESUME", "SIM", "SIM TO END"] and cms.paused and not cms.sim and cms.sim_ends == 0, "...CANCEL: back to the pause menu, nothing started")
	_press_button("SIM")
	await r.get_tree().process_frame
	_frames(cms, 1.0)
	cms._sim_pause()
	await r.get_tree().process_frame
	r.check(_labels(_dialog_buttons()) == ["CONTINUE SIM", "RETURN TO GAME", "SIM TO END"], "career SIM pause: ... SIM TO END")
	_press_button("SIM TO END")
	await r.get_tree().process_frame
	r.check(_labels(_dialog_buttons()).has("CANCEL"), "SIM TO END asks first from SIM's pause too")
	_press_button("CANCEL")
	await r.get_tree().process_frame
	r.check(_labels(_dialog_buttons()).has("CONTINUE SIM") and cms.sim and cms.paused and cms.sim_ends == 0, "...CANCEL: back to SIM's pause")
	_press_button("CONTINUE SIM")
	await r.get_tree().process_frame
	r.check(cms.sim and not cms.paused, "...and the broadcast carries on")
	Game.career = null
	await _clear_dialogs()

# ------------------------------------------------------------------ START IN SIM (the game preview)
## A career's next game, its preview open: the hub's way in.
func _preview(seed_v: int) -> Career:
	Store.reset_for_tests()
	Game.career = Career.new_game("WAGN", "Test", "Coach", seed_v)
	var c := Game.career
	c.queue.clear()
	var guard := 0
	while not c.has_game() and guard < 5:
		guard += 1
		c.end_week()
	for q in c.upgrades_due():
		Development.ai_spend(q)
	Game.goto("matchup")
	await r.get_tree().process_frame
	await r.get_tree().process_frame
	return c

## The preview's SIM TO END: the whole game at once, straight to the summary, never the match
## screen; a played game's postgame; once only.
func _pregame_sim_to_end() -> void:
	var c := await _preview(83)
	var scr = Game.current_screen
	var play: Button = scr.find_child("Play", true, false)
	var simb: Button = scr.find_child("Sim", true, false)
	var end: Button = scr.find_child("SimToEnd", true, false)
	r.check(end != null and end.text == "SIM TO END", "the preview's third button reads SIM TO END")
	r.check(play != null and simb != null and end != null and play.get_parent() == end.get_parent() and simb.get_index() < end.get_index(),
		"...in one row: PLAY GAME | START IN SIM | SIM TO END")
	r.check(simb != null and end != null and simb.get_combined_minimum_size() == end.get_combined_minimum_size()
			and play.get_combined_minimum_size().x > end.get_combined_minimum_size().x,
		"...the two sims the same size, PLAY GAME the biggest")
	var view := Rect2(Vector2.ZERO, scr.get_viewport_rect().size)
	if DisplayServer.get_name() != "headless":
		r.check(view.encloses(end.get_global_rect()) and view.encloses(play.get_global_rect()), "...all three on screen")
	var g := c.my_game()
	var home := c.is_home()
	var wins0 := int(c.coach.wins) + int(c.coach.losses)
	var hist0: int = c.dyn_hist.size()
	var gp_before := 0
	for p in c.team().roster:
		gp_before += p.stat("gp")
	var t0 := Time.get_ticks_msec()
	end.pressed.emit()
	end.pressed.emit()   # (a second tap: nothing more)
	var ms_taken := Time.get_ticks_msec() - t0
	await r.get_tree().process_frame
	r.check(Game.current_name == "game_summary", "SIM TO END: straight to the game summary, no match screen (%s)" % Game.current_name)
	r.check(ms_taken < 1000, "...at once (%d ms)" % ms_taken)
	r.check(g.r != null, "...the result's on the schedule")
	var rec: Array = g.r.s if g.r != null else [-1, -1]
	var mine: Array = [rec[0], rec[1]] if home else [rec[1], rec[0]]
	r.check(int(mine[0]) != int(mine[1]) or not (g.r.so as Array).is_empty(), "...a real result (%s)" % str(mine))
	var gp := 0
	var goals := 0
	for p in c.team().roster:
		gp += p.stat("gp")
		goals += p.stat("pg_g")
	r.check(gp - gp_before >= 7, "...the seven credited with a game (%d)" % (gp - gp_before))
	r.check(goals == int(mine[0]), "...every goal of ours in the players' stats (%d of %d)" % [goals, int(mine[0])])
	r.check(int(c.coach.wins) + int(c.coach.losses) == wins0 + 1, "...counted once on the coach's record")
	r.check(c.dyn_hist.size() == mini(hist0 + 1, Difficulty.DYN_WINDOW), "...and once for DYNAMIC difficulty")
	var sm: Dictionary = c.last_summary
	r.check(not sm.is_empty() and sm.has("xp") and sm.has("review") and not bool(sm.get("simmed", false)),
		"...XP, the postgame review, as a played game")
	Game.career = null

func _start_in_sim() -> void:
	# PLAY GAME: the match as ever, yours from the whistle
	var c := await _preview(81)
	var play: Button = Game.current_screen.find_child("Play", true, false)
	var simb: Button = Game.current_screen.find_child("Sim", true, false)
	r.check(simb != null and simb.text == "START IN SIM", "the preview's second button reads START IN SIM (%s)" % (simb.text if simb else "none"))
	r.check(play != null and play.text == "PLAY GAME  >", "...beside PLAY GAME, unchanged")
	play.pressed.emit()
	await r.get_tree().process_frame
	var pms = Game.current_screen
	r.check(Game.current_name == "match" and not bool(Game.match_cfg.get("start_sim", true)), "PLAY GAME: the match, no SIM asked for")
	pms._process(DT)
	r.check(not pms.sim and pms.sim_runs == 0 and not pms.flow.sim_us, "...and it's yours to play")
	var cfg_play: Dictionary = Game.match_cfg.duplicate()
	# START IN SIM: the very same match, the broadcast on from 0:00 at 0-0
	c = await _preview(82)
	var g := c.my_game()
	var home := c.is_home()
	var gp_before := 0
	for p in c.team().roster:
		gp_before += p.stat("gp")
	(Game.current_screen.find_child("Sim", true, false) as Button).pressed.emit()
	await r.get_tree().process_frame
	r.check(not _labels(_dialog_buttons()).has("SIM IT"), "START IN SIM: no SIM THIS GAME? dialog, straight in (%s)" % str(_labels(_dialog_buttons())))
	r.check(Game.current_name == "match" and bool(Game.match_cfg.get("start_sim", false)), "...the match screen opens")
	var keys_same := true
	for k in cfg_play:
		keys_same = keys_same and Game.match_cfg.has(k)
	r.check(keys_same and Game.match_cfg.size() == cfg_play.size(), "...set up exactly as PLAY GAME's, but for start_sim")
	var ms = Game.current_screen
	var f: MatchFlow = ms.flow
	r.check(f.state.score == [0, 0] and f.state.quarter == 1 and is_equal_approx(f.state.clock, f.state.quarter_len) and f.phase == MatchFlow.Phase.SPRINT,
		"...at 0-0, Q1, the clock full, the opening sprint")
	ms._process(DT)
	r.check(ms.sim and f.sim_us and ms.sim_runs == 1, "...the live SIM on from kickoff")
	_frames(ms, 3.0)
	r.check(f.phase != MatchFlow.Phase.FINAL and f.state.quarter == 1 and f.state.clock < f.state.quarter_len, "...and it plays out, not straight to a result (Q%d %.1f s)" % [f.state.quarter, f.state.clock])
	_until(ms, func(): return f.state.quarter >= 2 or f.phase == MatchFlow.Phase.FINAL)
	_until(ms, func(): return f.phase in [MatchFlow.Phase.ATTACK, MatchFlow.Phase.DEFENSE] and f.play != null and not f.play.over, 60 * 60)
	# take over: nothing restarts
	var q := f.state.quarter
	var clock := f.state.clock
	var score: Array = f.state.score.duplicate()
	var pf: Dictionary = f.state.pf.duplicate()
	var excl: Array = f.state.exclusions.duplicate()
	ms._sim_pause()
	await r.get_tree().process_frame
	_press_button("RETURN TO GAME")
	await r.get_tree().process_frame
	_until(ms, func(): return not ms.sim, 60 * 20)
	r.check(not ms.sim and not f.sim_us and f.auto_keeper < 0.0, "RETURN TO GAME: your team's yours")
	r.check(f.state.quarter == q and f.state.clock <= clock and f.state.clock > clock - 20.0 and f.state.score == score,
		"...the same quarter, clock and score (Q%d, %d-%d)" % [q, score[0], score[1]])
	var kept := true
	for k in pf:
		kept = kept and int(f.state.pf.get(k, 0)) >= int(pf[k])
	r.check(kept and int(f.state.exclusions[0]) >= int(excl[0]) and int(f.state.exclusions[1]) >= int(excl[1]), "...fouls and exclusions kept")
	# back to SIM to full time, then the career as for any played game
	ms._start_sim()
	_until(ms, func(): return f.phase == MatchFlow.Phase.FINAL)
	r.check(f.phase == MatchFlow.Phase.FINAL and _box_ok(f.state), "...to full time, the box score whole")
	var final: Array = f.state.score.duplicate()
	ms._process(DT)
	ms._to_career()
	await r.get_tree().process_frame
	await r.get_tree().process_frame
	r.check(Game.current_name == "game_summary" and g.r != null, "the game summary, the result on the schedule")
	var rec: Array = g.r.s if g.r != null else [-1, -1]
	r.check(([rec[0], rec[1]] if home else [rec[1], rec[0]]) == final, "...the real score")
	var gp := 0
	for p in c.team().roster:
		gp += p.stat("gp")
	r.check(gp - gp_before >= 7 and c.last_summary.has("xp") and c.last_summary.has("review"), "...stats, XP and the postgame review as a played game")
	r.check(not c.has_game() or c.my_game() != g, "...and that game can't be played again")
	Game.career = null
	await _clear_dialogs()

# ------------------------------------------------------------------ A: from the start
func _from_start() -> void:
	var ms = await _screen(21)
	var f: MatchFlow = ms.flow
	r.check(f.phase == MatchFlow.Phase.SPRINT, "A: the match opens on the sprint")
	ms._start_sim()
	var quarters := {}
	var t0 := Time.get_ticks_msec()
	var n := 0
	var worst := 0.0
	var share := {}   # real frames by what was on (the speed report)
	while f.phase != MatchFlow.Phase.FINAL and n < MAX_FRAMES:
		var u := Time.get_ticks_usec()
		ms._process(DT)
		worst = maxf(worst, (Time.get_ticks_usec() - u) / 1000.0)
		quarters[f.state.quarter] = true
		n += 1
		var why := "play"
		if ms.goal_show.active():
			why = "goal"
		elif f.phase == MatchFlow.Phase.BREAK:
			why = "break"
		elif f.state.in_shootout:
			why = "shootout"
		elif f.phase == MatchFlow.Phase.SPRINT:
			why = "sprint"
		elif ms._sim_target() <= ms.SIM_SHOT:
			why = "shot"
		elif ms._sim_target() <= ms.SIM_HOLD:
			why = "hold"
		elif ms.sim_rate < ms._sim_target() - 0.1:
			why = "ramp"
		share[why] = share.get(why, 0) + 1
	var wall := (Time.get_ticks_msec() - t0) / 1000.0
	var parts: Array = []
	for k in share:
		parts.append("%s %.1f s" % [k, share[k] * DT])
	print("    A: real time by moment: %s" % ", ".join(parts))
	r.check(f.phase == MatchFlow.Phase.FINAL, "A: SIM from the opening sprint plays all the way to full time by itself")
	r.check(quarters.has(1) and quarters.has(2) and quarters.has(3) and quarters.has(4), "F: through all four periods, no taps (%s)" % str(quarters.keys()))
	r.check(not ms.sim and not f.sim_us and f.auto_keeper < 0.0, "full time: SIM's off, the results as ever")
	r.check(_box_ok(f.state), "the box score adds up (%d-%d, shots %d/%d)" % [f.state.score[0], f.state.score[1], f.state.shots[0], f.state.shots[1]])
	r.check(int(f.state.score[0]) + int(f.state.score[1]) > 0 and int(f.state.shots[0]) > 3 and int(f.state.shots[1]) > 3, "both teams attack and shoot")
	ms._process(DT)
	r.check(ms.results != null, "G: the full-time panel comes up")
	var secs := n * DT
	var speed: float = ms.sim_speed()
	print("    A: a full SIM match: %.1f s on the screen (%d frames), %.1fx normal overall; %.2f s of CPU here, worst frame %.2f ms; %d-%d" \
		% [secs, n, speed, wall, worst, f.state.score[0], f.state.score[1]])
	r.check_between(speed, 4.0, 18.0 * ms.SIM_PACE, "H: the speed it managed, overall (x normal, stoppages and goals included)")
	r.check(worst < 50.0, "H: no frame anywhere near a freeze (worst %.2f ms)" % worst)

# ------------------------------------------------------------------ B: from the middle
func _mid_match() -> void:
	var ms = await _screen(33, {"autoplay": true})   # (the bot plays your first few minutes)
	var f: MatchFlow = ms.flow
	var g := 0
	while not (f.state.quarter >= 2 and f.phase in [MatchFlow.Phase.ATTACK, MatchFlow.Phase.DEFENSE] \
			and f.play != null and not f.play.over and f.play.elapsed > 3.0) and g < 60 * 60 * 10:
		if f.phase == MatchFlow.Phase.BREAK:
			f.break_done()   # (the break card: the tap you'd give it)
		ms._process(DT)
		g += 1
	r.check(f.state.quarter >= 2 and f.play != null, "B: a few minutes played by hand, into Q%d" % f.state.quarter)
	var play: Play = f.play
	var clock := f.state.clock
	var q := f.state.quarter
	var score: Array = f.state.score.duplicate()
	var shot := play.shot_clock
	var at: Array = play.bodies().map(func(s: Swimmer): return s.pos)
	var ball := play.ball.pos
	var holder := play.holder
	var pf: Dictionary = f.state.pf.duplicate()
	ms._pause()
	_press_button("SIM")   # (no frame in between: what SIM starts from is checked before anything moves)
	var same := f.play == play and f.state.clock == clock and f.state.quarter == q and f.state.score == score \
		and play.shot_clock == shot and play.ball.pos == ball and play.holder == holder and f.state.pf == pf
	for i in at.size():
		same = same and play.bodies()[i].pos == at[i]
	r.check(same, "B: SIM starts from exactly there: the same possession, clock, shot clock, score, fouls, every man and the ball")
	ms._process(DT)
	r.check(f.play == play and f.state.clock <= clock and f.state.clock > clock - 0.5, "...and runs on from it (%.2f -> %.2f)" % [clock, f.state.clock])
	_until(ms, func(): return f.phase == MatchFlow.Phase.FINAL)
	r.check(f.phase == MatchFlow.Phase.FINAL and _box_ok(f.state) and int(f.state.score[0]) >= int(score[0]) and int(f.state.score[1]) >= int(score[1]),
		"...to full time, the goals before it still there")

# ------------------------------------------------------------------ C: goals slow down
func _goal_slowdown() -> void:
	var ms = await _screen(45)
	var f: MatchFlow = ms.flow
	ms._start_sim()
	var sides := {}
	var shows := 0
	var lengths: Array[float] = []
	var rate_ok := true
	var board_ok := true
	var shots_seen := 0
	var shots_fast := 0
	var n := 0
	while f.phase != MatchFlow.Phase.FINAL and n < MAX_FRAMES and shows < 8:
		ms._process(DT)
		n += 1
		# a shot in the air a moment: shown slower
		if f.play != null and f.phase in [MatchFlow.Phase.ATTACK, MatchFlow.Phase.DEFENSE] and f.play.ball.state == Ball.State.SHOT:
			shots_seen += 1
			if ms.sim_rate > float(ms.SIM_SHOT) * 1.6:
				shots_fast += 1
		if ms.goal_show.active():
			shows += 1
			var side: int = ms.goal_show.side
			sides[side] = true
			var before: Array = f.state.score.duplicate()
			var frames := 0
			var settled := 0
			while ms.goal_show.active() and frames < 60 * 6:
				ms._process(DT)
				frames += 1
				if frames > 12 and ms.goal_show.active():
					settled += 1
					if ms.sim_rate > ms.SIM_GOAL + 0.05:
						rate_ok = false
			lengths.append(frames * DT)
			_until(ms, func(): return f.phase != MatchFlow.Phase.ATTACK and f.phase != MatchFlow.Phase.DEFENSE \
				or (f.play != null and not f.play.over), 60 * 3)
			var after: Array = f.state.score
			board_ok = board_ok and int(after[side]) == int(before[side]) + 1 and int(after[1 - side]) == int(before[1 - side])
	r.check(shows >= 2, "C: goals in SIM: %d shows seen" % shows)
	r.check(sides.has(0) and sides.has(1), "...for both teams (%s)" % str(sides.keys()))
	r.check(rate_ok, "...every one shown at the goal's slow speed (<= %.1fx) through its show" % ms.SIM_GOAL)
	var lo := 9.9
	var hi := 0.0
	for l in lengths:
		lo = minf(lo, l)
		hi = maxf(hi, l)
	print("    C: goal shows on the screen: %.2f .. %.2f s" % [lo, hi])
	r.check(lo >= 1.0 and hi <= 2.6, "...each held about 1-2 real seconds (%.2f .. %.2f s)" % [lo, hi])
	r.check(board_ok, "...the board goes up by exactly one, for the right team")
	r.check(shots_seen > 0 and shots_fast <= shots_seen * 0.15, "shots in the air are shown slowed down (%d of %d frames still fast, as it eases in)" % [shots_fast, shots_seen])

# ------------------------------------------------------------------ D: RETURN TO GAME
func _return_to_game() -> void:
	var ms = await _screen(57)
	var f: MatchFlow = ms.flow
	ms._start_sim()
	_frames(ms, 6.0)
	ms._sim_pause()
	await r.get_tree().process_frame
	var clock := f.state.clock
	var score: Array = f.state.score.duplicate()
	_press_button("RETURN TO GAME")
	await r.get_tree().process_frame
	var n := _until(ms, func(): return not ms.sim, 60 * 20)
	r.check(not ms.sim, "D: RETURN TO GAME hands back (%d frames to a safe moment)" % n)
	r.check(not f.sim_us and f.auto_keeper < 0.0 and not ms.sim_return, "...your attack and your keeper are yours again")
	r.check(ms._sim_safe(), "...at a safe moment (phase %d, no shot, no show, no hold)" % f.phase)
	r.check(f.state.clock <= clock and f.state.clock > clock - 20.0 and int(f.state.score[0]) >= int(score[0]), "...the clock and score carry on from where they were")
	await r.get_tree().process_frame   # (the canvas draws: the HUD's rects)
	r.check(ms.pause_rect.size.x > 0.0 and ms.sim_rect.size.x == 0.0, "...the normal HUD's back (the pause button, no SIM tag)")
	if f.phase == MatchFlow.Phase.ATTACK and f.play != null:
		_until(ms, func(): return f.play.can_throw() or f.play.over or f.phase != MatchFlow.Phase.ATTACK, 60 * 10)
		if f.phase == MatchFlow.Phase.ATTACK and f.play.can_throw():
			r.check(ms._stick_ready(f.play), "...the shooting stick is up for you again")
	# play goes on at normal speed: one frame is one frame
	var steps: int = ms.sim_steps
	var normal := true
	for _i in 30:
		var c2 := f.state.clock
		var pl: Play = f.play
		ms._process(DT)
		if pl != null and f.play == pl and not pl.over:
			normal = normal and f.state.clock >= c2 - DT * 1.3   # (within a possession: a frame's worth, as in play)
	r.check(ms.sim_steps == steps and normal and not ms.sim, "...at normal speed (%d/%d steps, %s, sim %s)" % [ms.sim_steps, steps, normal, ms.sim])
	# during a stoppage it waits: a goal's show
	ms._start_sim()
	_until(ms, func(): return ms.goal_show.active() or f.phase == MatchFlow.Phase.FINAL)
	if ms.goal_show.active():
		ms._sim_return_now()
		r.check(ms.sim and ms.sim_return, "RETURN TO GAME during a goal's show: it waits")
		var shown: int = ms.goal_show.side
		var sc: Array = f.state.score.duplicate()
		_until(ms, func(): return not ms.sim, 60 * 20)
		r.check(not ms.sim and ms._sim_safe() and not ms.goal_show.active(), "...and hands back once the show's over and play's live")
		r.check(int(f.state.score[shown]) == int(sc[shown]) + 1 and _box_ok(f.state), "...the goal counted once, nothing doubled")

# ------------------------------------------------------------------ E: the rules at speed
func _rules() -> void:
	var excl := 0
	var man_up_seen := false
	var even_again := false
	var pens := 0
	var fouls := 0
	var shot_ok := true
	var man_ok := true
	var clock_ok := true
	var resets := 0
	for sd in [61, 62, 63]:
		var ms = await _screen(sd)
		var f: MatchFlow = ms.flow
		ms._start_sim()
		var last_clock := f.state.clock
		var last_q := f.state.quarter
		var last_play: Play = null
		var last_shot := 0.0
		var last_man := 0.0
		var n := 0
		while f.phase != MatchFlow.Phase.FINAL and n < MAX_FRAMES:
			ms._process(DT)
			n += 1
			if f.state.quarter == last_q and f.state.clock > last_clock + 0.001:
				clock_ok = false   # (the game clock only ever runs down within a period)
			if f.state.quarter != last_q:
				last_q = f.state.quarter
			last_clock = f.state.clock
			var p: Play = f.play
			if p == null or not f.phase in [MatchFlow.Phase.ATTACK, MatchFlow.Phase.DEFENSE]:
				continue
			if p != last_play:
				last_play = p
				last_shot = p.shot_clock
				last_man = p.man_up
				if p.shot_clock > Play.SHOT_CLOCK - 0.01 or p.kind == Play.Kind.PENALTY:
					resets += 1
				continue
			if p.shot_clock < -0.001 or p.shot_clock > Play.SHOT_CLOCK + 0.001:
				shot_ok = false
			if p.man_up > 0.0:
				man_up_seen = true
				if p.man_up < last_man - 0.5:
					man_ok = false   # (it runs down a step's worth at a time, never jumps)
				if p.man_up <= last_man:
					even_again = true   # (seen running down)
			if p.man_up < 0.0:
				man_ok = false
			last_shot = p.shot_clock
			last_man = p.man_up
		excl += int(f.state.exclusions[0]) + int(f.state.exclusions[1])
		pens += f.state.pen_drawn_by[0].size() + f.state.pen_drawn_by[1].size()
		for k in f.state.pf:
			fouls += int(f.state.pf[k])
		r.check(_box_ok(f.state), "E: seed %d: the box score adds up at speed" % sd)
	print("    E: 3 SIM matches: %d exclusions, %d penalties, %d personal fouls, %d fresh shot clocks" % [excl, pens, fouls, resets])
	r.check(excl > 0 and man_up_seen and even_again, "E: exclusions called and 6 on 5 played, its timer running down (%d, %s, %s)" % [excl, man_up_seen, even_again])
	r.check(fouls >= excl, "...each one a personal foul on the man who committed it")
	r.check(shot_ok and man_ok, "...the shot clock and exclusion timers stay in range")
	r.check(clock_ok, "...the game clock only ever runs down, never jumps back")
	r.check(resets > 0, "...the shot clock starts over for new possessions")

# ------------------------------------------------------------------ I: back and forth
func _switching() -> void:
	var ms = await _screen(71, {"autoplay": true})
	var f: MatchFlow = ms.flow
	var ok := true
	for i in 6:
		ms._start_sim()
		ok = ok and ms.sim and f.sim_us and f.auto_keeper >= 0.0
		_frames(ms, 2.0 + i * 0.7)
		if f.phase == MatchFlow.Phase.FINAL:
			break
		ms._sim_return_now()
		_until(ms, func(): return not ms.sim, 60 * 20)
		ok = ok and not ms.sim and not f.sim_us and f.auto_keeper == ms.duel_skill
		_frames(ms, 1.5)   # (a little by hand: the autoplay bot)
		if f.phase == MatchFlow.Phase.FINAL:
			break
	r.check(ok, "I: SIM on and off %d times: control changes hands cleanly every time" % ms.sim_runs)
	ms._start_sim()
	_until(ms, func(): return f.phase == MatchFlow.Phase.FINAL)
	r.check(f.phase == MatchFlow.Phase.FINAL and _box_ok(f.state), "...and the match still finishes, the box score whole")
	r.check(f.state.goal_by[0].size() + f.state.goal_by[1].size() == int(f.state.score[0]) + int(f.state.score[1]), "...no goal counted twice")

# ------------------------------------------------------------------ G: a career game, simmed
func _career_game() -> void:
	Store.reset_for_tests()
	Game.career = Career.new_game("WAGN", "Test", "Coach", 78)
	var c := Game.career
	c.queue.clear()
	var guard := 0
	while not c.has_game() and guard < 5:
		guard += 1
		c.end_week()
	var g := c.my_game()
	var home := c.is_home()
	var gp_before := 0
	for p in c.team().roster:
		gp_before += p.stat("gp")
	var ms = await _screen(5, {"us": c.team(), "them": c.opponent(), "career": true, "home": home, "pool": c.venue().id})
	var f: MatchFlow = ms.flow
	ms._start_sim()
	_until(ms, func(): return f.phase == MatchFlow.Phase.FINAL)
	r.check(f.phase == MatchFlow.Phase.FINAL, "G: a career game simmed from the whistle to full time")
	var final: Array = f.state.score.duplicate()
	var goals: int = f.state.goal_by[0].size()
	ms._process(DT)
	r.check(ms.results != null, "...the full-time panel, with the season records")
	ms._to_career()
	await r.get_tree().process_frame
	await r.get_tree().process_frame
	r.check(Game.current_name == "game_summary", "...then the game summary, as a played game")
	r.check(g.r != null, "...the result's on the schedule")
	var rec: Array = g.r.s if g.r != null else [-1, -1]
	var mine: Array = [rec[0], rec[1]] if home else [rec[1], rec[0]]
	r.check(mine == final, "...with the real score, not a forfeit (%s vs %s)" % [mine, final])
	var gp := 0
	var g_stat := 0
	for p in c.team().roster:
		gp += p.stat("gp")
		g_stat += p.stat("g")
	r.check(gp - gp_before >= 7, "...the seven credited with a game (%d)" % (gp - gp_before))
	r.check(g_stat == goals, "...every goal in the players' stats (%d of %d)" % [g_stat, goals])
	var sm: Dictionary = c.last_summary
	r.check(not sm.is_empty() and sm.has("xp") and sm.has("review"), "...XP awarded and the postgame review built")
	Game.career = null

# ------------------------------------------------------------------ SIM TO END
## A career game played into the 2nd quarter, then SIM TO END: nothing reset, the rest run at once
## by the same engine, full time, the postgame exactly as a played game's (not a forfeit), once.
func _sim_to_end() -> void:
	Store.reset_for_tests()
	Game.career = Career.new_game("WAGN", "Test", "Coach", 79)
	var c := Game.career
	c.queue.clear()
	var guard := 0
	while not c.has_game() and guard < 5:
		guard += 1
		c.end_week()
	var g := c.my_game()
	var home := c.is_home()
	var gp_before := 0
	for p in c.team().roster:
		gp_before += p.stat("gp")
	var ms = await _screen(6, {"us": c.team(), "them": c.opponent(), "career": true, "home": home, "pool": c.venue().id, "autoplay": true})
	var f: MatchFlow = ms.flow
	_until(ms, func(): return f.state.quarter >= 2 and f.state.clock < f.state.quarter_len * 0.5 		and (f.phase == MatchFlow.Phase.ATTACK or f.phase == MatchFlow.Phase.DEFENSE))
	ms.autoplay = false   # (from here on as a player's game: the pause menu is the way)
	var score0: Array = f.state.score.duplicate()
	var goals0: Array = [f.state.goal_by[0].duplicate(), f.state.goal_by[1].duplicate()]
	var shots0: Array = f.state.shots.duplicate()
	var q0: int = f.state.quarter
	var clock0: float = f.state.clock
	ms._pause()
	await r.get_tree().process_frame
	_press_button("SIM TO END")
	await r.get_tree().process_frame
	var clock_open: float = f.state.clock
	_frames(ms, 1.0)
	r.check(is_equal_approx(f.state.clock, clock_open) and f.state.score == score0, "SIM TO END's popup: the clock and score stand still while it's up")
	_press_button("SIM TO END")
	_press_button("SIM TO END")   # (a second tap: nothing more)
	r.check(ms.sim_ends == 1 and not ms.paused, "confirmed: SIM TO END run, once")
	ms._sim_to_end_now()
	r.check(ms.sim_ends == 1, "...and can't be run twice")
	print("    sim to end: %.2f ms, Q%d %.1f %s -> final %d-%d" % [ms.sim_end_ms, q0, clock0, str(score0), f.state.score[0], f.state.score[1]])
	r.check(f.phase == MatchFlow.Phase.FINAL and not ms.sim, "...full time at once, in the same call (no frames of play)")
	r.check(ms.results != null, "...the full-time panel already up: no loading screen in between")
	r.check(ms.sim_end_ms >= 0.0 and ms.sim_end_ms < 500.0, "...in under half a second (%.2f ms)" % ms.sim_end_ms)
	r.check(Sfx.sfx_on == bool(Game.settings.get("sfx", true)), "...the sound back as it was")
	var kept := true
	for side in 2:
		kept = kept and int(f.state.score[side]) >= int(score0[side]) and int(f.state.shots[side]) >= int(shots0[side])
		for i in goals0[side].size():
			kept = kept and f.state.goal_by[side][i] == goals0[side][i]
	r.check(kept, "...every goal and shot from before kept, nothing reset (%s -> %s)" % [str(score0), str(f.state.score)])
	r.check(_box_ok(f.state), "...the box score adds up, no goal counted twice")
	r.check(f.state.winner() == 0 or f.state.winner() == 1, "...a winner, by the normal rules")
	ms._process(DT)
	r.check(ms.results != null, "...the full-time panel")
	var final: Array = f.state.score.duplicate()
	var goals: int = f.state.goal_by[0].size()
	ms._to_career()
	ms._to_career()   # (twice: recorded once)
	await r.get_tree().process_frame
	await r.get_tree().process_frame
	r.check(Game.current_name == "game_summary", "...then the game summary, as a played game")
	var rec: Array = g.r.s if g.r != null else [-1, -1]
	var mine: Array = [rec[0], rec[1]] if home else [rec[1], rec[0]]
	r.check(mine == final, "...the real score on the schedule, not a forfeit (%s vs %s)" % [mine, final])
	var gp := 0
	var g_stat := 0
	for p in c.team().roster:
		gp += p.stat("gp")
		g_stat += p.stat("g")
	r.check(gp - gp_before >= 7 and gp - gp_before <= c.team().roster.size(), "...credited with one game each (%d)" % (gp - gp_before))
	r.check(g_stat == goals, "...every goal in the players' stats once (%d of %d)" % [g_stat, goals])
	var sm: Dictionary = c.last_summary
	r.check(not sm.is_empty() and sm.has("xp") and sm.has("review"), "...XP awarded and the postgame review built")
	Game.career = null

# ------------------------------------------------------------------ fairness
## Two equal teams, simmed from the start: your side wins about as often as theirs and scores
## about as much (SIM is a change of who decides and how fast it's shown, never of balance).
func _fairness() -> void:
	var gf := 0
	var ga := 0
	var w := 0
	var l := 0
	var n := int(OS.get_environment("SIM_FAIR_N")) if OS.get_environment("SIM_FAIR_N") != "" else 10
	for i in n:
		var cfg := {"us": League.make_team(2, 1), "them": League.make_team(2, 1), "seed": 900 + i, "minutes": 2.0}
		var ms = await _screen(900 + i, cfg)
		ms._start_sim()
		_until(ms, func(): return ms.flow.phase == MatchFlow.Phase.FINAL)
		var st: MatchState = ms.flow.state
		gf += int(st.score[0])
		ga += int(st.score[1])
		match st.winner():
			0:
				w += 1
			1:
				l += 1
	print("    fairness: %d even SIM matches: %d-%d in games, goals %d-%d" % [n, w, l, gf, ga])
	r.check(absf(gf - ga) <= maxf(6.0, 0.25 * (gf + ga) / 2.0), "fairness: two equal teams simmed score about the same (%d - %d)" % [gf, ga])
