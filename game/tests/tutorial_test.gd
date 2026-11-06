extends RefCounted
## The tutorial's practice run: the GAME GUIDE's button straight into it, all four parts played
## through in one go on the real drill screen with touches (InputEventScreenTouch, what a finger
## and the emulated mouse both send), each part handing on to the next behind its pop-up, the
## mistakes each one doesn't count, the near-side opening the shooting part's keeper leaves,
## RESTART, BACK, picking up where you left off, the TUTORIAL COMPLETE card; and that none of it
## touches a career. (A new career's run: career_tutorial_test.)
##   godot --headless --path game -- --test tutorial

const DT := 1.0 / 30.0

var r   # the test runner (check, check_between)

func run(runner) -> void:
	r = runner
	print("tutorial")
	var settings_before: Array = (Game.settings.get("tutorials_done", []) as Array).duplicate()
	var career_before = Game.career
	var slot_before := Game.last_slot()
	var files_before := _save_files()
	Game.settings["tutorials_done"] = []
	var ms = await _home()
	if ms != null:
		_frontcourt(ms)
		_counter(ms)
		_shooting(ms)
		_keeper(ms)
		await _complete(ms)
	_keeper_rules()
	_near_side()
	await _navigation()
	r.check(Game.career == career_before, "tutorial: no career loaded or made")
	r.check(Game.last_slot() == slot_before and _save_files() == files_before, "tutorial: no career save written")
	Game.settings["tutorials_done"] = settings_before
	Game.save_settings()

# ------------------------------------------------------------------ helpers
func _save_files() -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(Game.save_dir):
		if f.begins_with("career"):
			out.append([f, FileAccess.get_modified_time(Game.save_dir + f)])
	out.sort()
	return out

func _open(params: Dictionary = {}):
	Game.goto("drill", params)
	await r.get_tree().process_frame
	_got_it(Game.current_screen)
	return Game.current_screen

## The part's pop-up, read.
func _got_it(ms) -> void:
	r.check(_press_button(ms, "GOT IT") and ms.popup.is_empty(), "%s: GOT IT starts it" % ms.drill_id)

func _until(ms, cond: Callable, limit: float = 15.0) -> bool:
	var t := 0.0
	while t < limit:
		if cond.call():
			return true
		ms._process(DT)
		t += DT
	return cond.call()

func _steps(ms, secs: float) -> void:
	var t := 0.0
	while t < secs:
		ms._process(DT)
		t += DT

func _touch(ms, pos: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = pos
	e.pressed = down
	e.index = 0
	ms._input(e)

func _tap(ms, pos: Vector2) -> void:
	_touch(ms, pos, true)
	_touch(ms, pos, false)

## The shooting stick pulled back to shoot like a slingshot pull aimed at `world` (ShotStick.knob_for),
## released: the only way to shoot.
func _pull(ms, world: Vector2) -> void:
	ms.stick.layout(ms.get_viewport_rect().size, ms._insets())
	var from: Vector2 = ms.stick.rest
	_touch(ms, from, true)
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = from + ShotStick.knob_for(ms.flow.play.holder.pos, world)
	ms._input(d)
	_touch(ms, d.position, false)

## Where to tap a teammate: on his body, as AimGuide.tap_mate reads it.
func _on(ms, s: Swimmer) -> Vector2:
	return ms.view.to_screen(s.pos) + Vector2(0, -5)

func _press_button(ms, label: String) -> bool:
	for b in ms.buttons_now(ms.get_viewport_rect().size):
		if b[1] == label:
			_tap(ms, (b[0] as Rect2).get_center())
			return true
	return false

func _find_button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text:
		return n
	for ch in n.get_children():
		var b := _find_button(ch, text)
		if b != null:
			return b
	return null

func _tag(p: Play, tag: String) -> Swimmer:
	for a in p.attackers:
		if a.tag == tag:
			return a
	return null

## A part's done: its callout comes up on the same screen, then the next part starts by itself.
func _hands_on(ms, from_id: String, to_id: String) -> void:
	var screen = Game.current_screen
	r.check(_until(ms, func(): return ms.segue_t >= 0.0, 4.0), "%s: done, its callout comes up (%s)" % [from_id, str(Drill.SEGUES.get(from_id))])
	r.check(not ms.card_on, "%s: no completion card between parts" % from_id)
	r.check(from_id in Game.settings.get("tutorials_done", []), "%s: kept as done" % from_id)
	r.check(_until(ms, func(): return ms.drill_id == to_id, 4.0), "%s: %s starts by itself" % [from_id, to_id])
	r.check(Game.current_name == "drill" and Game.current_screen == screen, "%s -> %s: the same screen, no menu" % [from_id, to_id])
	r.check(ms.segue_t < 0.0 and not ms.drill.complete and ms.drill.id == to_id, "%s: starts fresh" % to_id)
	_got_it(ms)

# ------------------------------------------------------------------ the title
func _home():
	Game.goto("title")
	await r.get_tree().process_frame
	var t: Node = Game.current_screen
	var cont := _find_button(t, "CONTINUE")
	var newc := _find_button(t, "NEW CAREER")
	r.check(cont != null and newc != null and _find_button(t, "TUTORIAL") == null, "title: CONTINUE and NEW CAREER (the tutorial opens a career)")
	if newc == null:
		return null
	r.check(cont.disabled == not Game.has_save(), "title: CONTINUE still follows the saves")
	newc.pressed.emit()
	r.check(Game.current_name == "careers", "title: NEW CAREER still opens the career slots")
	Game.goto("title", {}, false)
	await r.get_tree().process_frame
	Game.goto("howto")
	await r.get_tree().process_frame
	(Game.current_screen.find_child("Tutorial", true, false) as Button).pressed.emit()
	await r.get_tree().process_frame
	r.check(Game.current_name == "drill", "guide: PLAY THE TUTORIAL goes straight into the tutorial (%s)" % Game.current_name)
	var ms = Game.current_screen
	_got_it(ms)
	r.check(ms.part == 0 and ms.drill_id == "frontcourt", "tutorial: starts at part 1, passing")
	r.check(ms.part_line().begins_with("PART 1/4"), "tutorial: the strip says which part (%s)" % ms.part_line())
	return ms

# ------------------------------------------------------------------ 1: passing
func _frontcourt(ms) -> void:
	var dr: FrontcourtDrill = ms.drill
	var p: Play = ms.flow.play
	r.check(p.attackers.size() == 6 and p.defenders.is_empty() and not p.bodies().has(p.keeper), "frontcourt: six of ours, no defenders, no keeper")
	r.check(p.holder != null and p.holder.tag == "3" and is_inf(p.shot_clock), "frontcourt: the point has it, no shot clock")
	r.check(dr.instruction() == "TAP A TEAMMATE TO PASS", "frontcourt: first instruction")
	var clock0: float = ms.flow.state.clock
	r.check(_until(ms, func(): return ms.flow.play.can_throw(), 5.0), "frontcourt: the ball's ours to throw")
	# a pull back isn't a pass (pulling is for shooting)
	_pull(ms, Vector2(31.0, 9.0))
	_steps(ms, 0.2)
	r.check(ms.flow.play.ball.state == Ball.State.HELD and dr.passes == 0, "frontcourt: a pull back doesn't throw")
	# five passes between just two men: not done yet
	var tags := ["2", "3"]
	for i in 5:
		_until(ms, func(): return ms.flow.play.can_throw(), 5.0)
		var pp: Play = ms.flow.play
		var mate := _tag(pp, tags[i % 2] if pp.holder.tag != tags[i % 2] else tags[(i + 1) % 2])
		var before := dr.passes
		_tap(ms, _on(ms, mate))
		r.check(pp.ball.state == Ball.State.PASS and pp.ball.receiver == mate, "frontcourt: a tap on a teammate passes to him (%d)" % i)
		r.check(_until(ms, func(): return dr.passes > before, 4.0), "frontcourt: pass %d caught and counted" % (i + 1))
		if i == 0:
			r.check(dr.instruction() == "NICE! KEEP THE BALL MOVING", "frontcourt: the instruction after the first pass")
	r.check(dr.passes == 5 and dr.touched.size() == 2 and not dr.complete, "frontcourt: five passes between two men isn't done")
	r.check(dr.instruction().begins_with("NOW PASS TO SOMEONE"), "frontcourt: asks for a third man")
	_until(ms, func(): return ms.flow.play.can_throw(), 5.0)
	_tap(ms, _on(ms, _tag(ms.flow.play, "4")))
	r.check(_until(ms, func(): return dr.complete, 4.0), "frontcourt: a third man in it completes it")
	r.check(ms.flow.state.clock == clock0 and is_inf(ms.flow.play.shot_clock), "frontcourt: no game clock, no shot clock")
	r.check(ms.flow.play.defenders.is_empty() and not ms.flow.play.over, "frontcourt: no turnovers along the way")
	_hands_on(ms, "frontcourt", "counter")

# ------------------------------------------------------------------ 2: counterattack
func _counter(ms) -> void:
	var dr: CounterDrill = ms.drill
	var p: Play = ms.flow.play
	r.check(ms.part == 1 and ms.part_line().begins_with("PART 2/4"), "counter: part 2")
	r.check(p.attackers.size() == 3 and p.defenders.is_empty() and not p.bodies().has(p.keeper), "counter: three of ours, nobody back, no keeper")
	r.check(p.carry and p.kind == Play.Kind.COUNTER and p.holder.tag == "3", "counter: the break is on, the middle man has it")
	r.check(dr.instruction().begins_with("LEAD YOUR TEAMMATE INTO OPEN WATER") and dr.instruction().contains("2-3 METERS AHEAD"), "counter: the instruction")
	_steps(ms, 0.4)
	var x0 := {}
	for a in p.attackers:
		x0[a] = a.pos.x
	_steps(ms, 0.6)
	var swimming := true
	for a in p.attackers:
		swimming = swimming and a.pos.x > x0[a] + 0.6 and a.vel.x > 1.0
	r.check(swimming, "counter: all three swim up the pool")
	# a tap into the open water 2.5 m in front of a swimming man: he runs onto it, never stopping
	var mate: Swimmer = p.attackers.filter(func(a): return a != p.holder)[0]
	var spot := mate.pos + mate.vel.normalized() * 2.5
	_tap(ms, ms.view.to_screen(spot))
	r.check(p.ball.state == Ball.State.PASS and p.ball.receiver == mate and p.ball.to.distance_to(spot) < 0.3, "counter: a tap 2.5 m ahead of him is a lead pass to him")
	var slowest := INF
	var ok := _until(ms, func():
		slowest = minf(slowest, mate.vel.x)
		return dr.passes == 1, 3.0)
	r.check(ok, "counter: the lead pass into open water counts")
	r.check(slowest > 1.5, "counter: he swims onto it without slowing (%.2f m/s)" % slowest)
	r.check(p.holder == mate and mate.vel.x > 1.5 and p.carry, "counter: ...and carries on at the goal with it")
	# a tap on a teammate leads him too
	_until(ms, func(): return ms.flow.play.can_throw(), 3.0)
	p = ms.flow.play
	var m2: Swimmer = p.attackers.filter(func(a): return a != p.holder and a.vel.length() > 1.0)[0]
	var passer: Swimmer = p.holder
	_tap(ms, _on(ms, m2))
	r.check(p.ball.state == Ball.State.PASS and p.ball.to.x > m2.pos.x + 0.2, "counter: a tap on him passes in front of him (Play.lead_point)")
	ms._process(DT)
	ms._process(DT)
	r.check(passer.vel.x > 1.0 and m2.speed() > 1.0, "counter: passer and receiver keep swimming during the pass")
	r.check(_until(ms, func(): return dr.passes == 2, 3.0), "counter: caught on the move, counted")
	# a pass far out in front of everybody: nobody turns back for it, nobody gets it, and the break starts over
	_until(ms, func(): return ms.flow.play.can_throw() and ms.flow.play.carry, 4.0)
	p = ms.flow.play
	var far := Vector2(minf(p.holder.pos.x + 9.0, 27.5), 2.0)
	_tap(ms, ms.view.to_screen(far))
	r.check(p.ball.state == Ball.State.PASS, "counter: a tap in open water passes there")
	var back := false
	_until(ms, func():
		for a in p.attackers:
			back = back or a.vel.x < -0.2
		return ms.flow.play != p, 4.0)
	r.check(not back, "counter: nobody turns back for a ball thrown on ahead")
	r.check(ms.flow.play != p, "counter: ...and the break starts over")
	r.check(dr.passes == 2 and ms.part == 1, "counter: ...it doesn't count, and the tutorial carries on where it was")
	# a pass to a man who isn't swimming doesn't count either
	p = ms.flow.play
	_steps(ms, 0.5)
	var still: Swimmer = p.attackers.filter(func(a): return a != p.holder)[0]
	still.vel = Vector2.ZERO
	_tap(ms, _on(ms, still))
	_until(ms, func(): return ms.flow.play.ball.state != Ball.State.PASS, 3.0)
	r.check(dr.passes == 2, "counter: a pass to a stationary man doesn't count")
	# one more lead pass finishes it, whatever breaks it takes
	var guard := 0
	while not dr.complete and guard < 12:
		guard += 1
		if not _until(ms, func(): return ms.flow.play.can_throw() and ms.flow.play.carry, 4.0):
			continue
		_steps(ms, 0.3)
		var pp: Play = ms.flow.play
		if not pp.can_throw():
			continue
		var m3: Swimmer = pp.attackers.filter(func(a): return a != pp.holder and a.vel.length() > 1.0)[0]
		_tap(ms, ms.view.to_screen(m3.pos + m3.vel.normalized() * 2.0))
		_until(ms, func(): return ms.flow.play.ball.state == Ball.State.HELD, 3.0)
	r.check(dr.complete and dr.passes == 3, "counter: three lead passes complete it (%d)" % dr.passes)
	_hands_on(ms, "counter", "shooting")

# ------------------------------------------------------------------ 3: shooting
func _shooting(ms) -> void:
	r.check(ShootingDrill.corner_of(8.9) == "cross" and ShootingDrill.corner_of(11.1) == "near" and ShootingDrill.corner_of(10.1) == "middle",
		"shooting: far corner, near corner and the middle from the right")
	var dr: ShootingDrill = ms.drill
	var p: Play = ms.flow.play
	r.check(ms.part == 2 and ms.part_line().begins_with("PART 3/4"), "shooting: part 3")
	r.check(p.attackers.size() == 1 and p.defenders.is_empty() and p.bodies().has(p.keeper), "shooting: one shooter, their keeper, nobody else")
	r.check(p.holder.home == ShootingDrill.SPOT and Geo.range_to_goal(ShootingDrill.SPOT) > 5.0 and Geo.range_to_goal(ShootingDrill.SPOT) < 6.0,
		"shooting: his spot is 5-6 m out, to one side of the goal")
	r.check(dr.instruction().begins_with("PULL BACK TO SHOOT!") and dr.instruction().contains("PULL DOWN TO AIM HIGH") and dr.instruction().ends_with("RELEASE TO FIRE!"),
		"shooting: the current stick's instruction (pull back, down aims high, release) (%s)" % dr.instruction())
	_until(ms, func(): return ms.flow.play.can_throw(), 3.0)
	_steps(ms, 0.4)   # (the stick fades in)
	r.check(ms.stick.shown > 0.5 and ms.stick.area().size.x > 0.0 and FileAccess.get_file_as_string("res://src/tutorial/drill_screen.gd").contains("stick.draw(ci, aim.stick)"),
		"shooting: the match's own shooting stick, drawn on the tutorial's screen")
	r.check(is_nan(p.keeper_spot) and p.keeper_late > 0.0, "shooting: cross-cage, the keeper shades as in a match (a beat slower)")
	# a tap is no pass here
	_until(ms, func(): return ms.flow.play.can_throw(), 3.0)
	_tap(ms, ms.view.to_screen(p.holder.pos + Vector2(-3, -3)))
	r.check(p.ball.state == Ball.State.HELD, "shooting: a tap doesn't throw")
	var shots := 0
	var outcomes := {}
	var exact := true
	var tried_early := false
	var tried_late := false
	var reset_ok := true
	var near_saw_cheat := false
	while not dr.complete and shots < 40:
		if not _until(ms, func(): return ms.flow.play.can_throw() and ms.flow.play.holder.pos.distance_to(ShootingDrill.SPOT) < 0.3, 8.0):
			break
		_steps(ms, 0.5)   # (let the keeper set)
		p = ms.flow.play
		if not p.can_throw():
			continue
		var want := "cross" if not dr.cross_done() else "near"
		# first a near-side shot while it wants cross-cage, then the reverse: neither counts
		if not tried_early:
			want = "near"
			tried_early = true
		elif dr.cross_done() and not tried_late:
			want = "cross"
			tried_late = true
		if dr.cross_done():
			near_saw_cheat = near_saw_cheat or absf(p.keeper_spot - (Geo.GOAL_Y - ShootingDrill.CHEAT)) < 0.01
		# cross-cage into the far corner; near side, half a metre inside the post
		var y := Geo.GOAL_Y + (-1.2 if want == "cross" else 1.2)
		var from := p.holder.pos
		var aim_at := from + (Vector2(Geo.GOAL_X, y) - from) * 1.6   # pulled on well past the goal: a hard shot
		var before := [dr.cross, dr.near]
		_pull(ms, aim_at)
		shots += 1
		r.check(p.ball.state == Ball.State.SHOT, "shooting: a pull back into the goal shoots (%d)" % shots)
		if p.ball.state != Ball.State.SHOT:
			break
		exact = exact and absf(float(p.ball.shot.cross_y) - y) < 0.01
		_until(ms, func(): return ms.flow.play != p or ms.flow.play.can_throw() or dr.complete, 6.0)
		var outc := String(p.result.get("outcome", "rebound"))
		outcomes[outc] = int(outcomes.get(outc, 0)) + 1
		if outc == "goal":
			if want == "near" and before[0] < ShootingDrill.GOALS:
				r.check(dr.near == 0 and dr.cross == before[0], "shooting: a near-side goal doesn't count towards cross-cage")
			if want == "cross" and before[0] >= ShootingDrill.GOALS:
				r.check(dr.near == before[1], "shooting: a cross-cage goal doesn't count towards near side")
		elif outc in ["save", "miss", "turnover"]:
			# back with the shooter on his spot at once, the same part, nothing lost
			reset_ok = reset_ok and ms.flow.play != p and ms.flow.play.holder != null and ms.flow.play.holder.pos == ShootingDrill.SPOT \
				and ms.part == 2 and dr.cross == before[0]
	print("  shooting: %d shots, outcomes %s" % [shots, str(outcomes)])
	r.check(exact, "shooting: the ball goes exactly along the aimed line")
	r.check(tried_early and tried_late, "shooting: the wrong corner tried in each half")
	r.check(reset_ok, "shooting: a save or a miss gives the ball straight back, same part")
	r.check(near_saw_cheat, "shooting: for the near side the keeper cheats across")
	r.check(dr.cross == 1 and dr.near == 1 and dr.complete, "shooting: a cross-cage goal and a near-side goal complete it")
	r.check(shots <= 12, "shooting: done in a handful of shots aimed right (%d)" % shots)
	_hands_on(ms, "shooting", "keeper")

# ------------------------------------------------------------------ 4: goalie blocking
func _keeper(ms) -> void:
	var dr: KeeperDrill = ms.drill
	var p: Play = ms.flow.play
	r.check(ms.part == 3 and ms.part_line().begins_with("PART 4/4"), "keeper: part 4")
	_steps(ms, DT)
	r.check(ms.flow.phase == MatchFlow.Phase.DEFENSE and p.defending and ms.view.mirror, "keeper: their attack, you in goal at the other end")
	r.check(p.attackers.size() == 1 and p.defenders.is_empty() and p.bodies().has(p.keeper), "keeper: one shooter, your keeper, nobody else")
	r.check(dr.instruction().begins_with("YOUR GOALIE TRACKS THE BALL"), "keeper: first, how your keeper moves")
	var shots := 0
	var zones := {KeeperDive.LEFT: 0, KeeperDive.CENTRE: 0, KeeperDive.RIGHT: 0}
	var dives := {KeeperDive.LEFT: 0, KeeperDive.CENTRE: 0, KeeperDive.RIGHT: 0}
	var said := {}
	var wrong_done := false
	var tracked := false
	var never_done := true
	while not dr.complete and shots < 40:
		if not _until(ms, func(): return ms.flow.duel != null, 10.0):
			break
		p = ms.flow.play
		tracked = tracked or absf(p.keeper.pos.y - Geo.GOAL_Y) > 0.01
		said[dr.instruction()] = true
		var d: KeeperDuel = ms.flow.duel
		var zone := KeeperDive.zone_for(d.cross_y)
		zones[zone] += 1
		shots += 1
		var tap_y: float = d.cross_y
		var wrong := not wrong_done and zone != KeeperDive.CENTRE
		if wrong:
			tap_y = Geo.GOAL_Y - float(zone) * 1.2   # the other way
		var saves0 := dr.saves
		var done_ways: Array = [KeeperDive.LEFT, KeeperDive.CENTRE, KeeperDive.RIGHT].filter(func(w): return not dr.needs(w))
		never_done = never_done and not dr.zone in done_ways
		# timed the way a keeper times it (KeeperDuel.ideal_up), not on the first frame of the shot:
		# that edge moved when the shot's pace stopped reading the shooter's team rating
		_until(ms, func(): return d.done() or (d.state == KeeperDuel.State.FLIGHT and d.t >= d.flight - d.ideal_up(0.4) * d.slowmo), 6.0)
		_tap(ms, Vector2(60, ms.view.to_screen(Vector2(0.0, tap_y), KeeperDive.BALL_Z).y))
		var side: int = d.anim.side if d.anim != null else 99
		if d.anim != null:
			dives[side] += 1
			ms._process(DT)
			r.check(p.keeper.pose != null and p.keeper.pose.side == side, "keeper: the lunge plays that way (KeeperDive)")
		_until(ms, func(): return ms.flow.play != p or dr.complete, 6.0)
		if wrong:
			wrong_done = true
			r.check(dr.saves == saves0 and ms.flow.play != p, "keeper: diving the wrong way doesn't save, and the next shot comes")
			r.check(not dr.complete and ms.part == 3 and ms.flow.phase == MatchFlow.Phase.DEFENSE, "keeper: a goal doesn't restart anything")
	print("  keeper: %d shots, shot zones %s, dives %s, saves %s" % [shots, str(zones), str(dives), str(dr.by_side)])
	r.check(tracked, "keeper: he tracks the ball by himself before the shot")
	r.check(said.has("DIVE LEFT OR RIGHT TO BLOCK") and said.has("BLOCK STRAIGHT AHEAD WHEN NEEDED: TAP THE MIDDLE"), "keeper: the dive and block instructions (%s)" % str(said.keys()))
	r.check(dives[KeeperDive.LEFT] > 0 and dives[KeeperDive.RIGHT] > 0 and dives[KeeperDive.CENTRE] > 0, "keeper: taps dive left, right and block")
	r.check(never_done, "keeper: once a way's saved, he never shoots there again")
	r.check(dr.complete and dr.saves >= KeeperDrill.SAVES and dr.by_side[KeeperDive.LEFT] > 0 and dr.by_side[KeeperDive.RIGHT] > 0 and dr.by_side[KeeperDive.CENTRE] > 0,
		"keeper: a save each way completes it (%d)" % dr.saves)

# ------------------------------------------------------------------ the end
func _complete(ms) -> void:
	r.check(_until(ms, func(): return ms.card_on, 4.0), "tutorial: the TUTORIAL COMPLETE card comes up after the last part")
	r.check(ms.segue_t < 0.0, "tutorial: no callout after the last part, the card")
	var labels: Array = ms.buttons_now(ms.get_viewport_rect().size).map(func(b): return b[1])
	r.check(labels.slice(2) == ["MAIN MENU", "NEW CAREER"], "tutorial: MAIN MENU, NEW CAREER (%s)" % str(labels))
	var done: Array = Game.settings.get("tutorials_done", [])
	r.check(Drill.ORDER.all(func(id): return id in done), "tutorial: every part kept as done")
	_press_button(ms, "MAIN MENU")
	await r.get_tree().process_frame
	r.check(Game.current_name == "title", "tutorial: MAIN MENU goes back to the title")

## The blocking drill's rules, without a screen: a way counts only for a save with that way's
## dive; once done the shooter never goes there; all three done: complete; a new run starts over.
func _keeper_rules() -> void:
	var dr := KeeperDrill.new()
	var f := DrillFlow.new(dr, League.make_team(0), League.make_team(3), 13)
	dr.zone = KeeperDive.RIGHT
	dr.dived(KeeperDive.RIGHT)
	dr.on_event(f, {"k": "save"})
	r.check(not dr.needs(KeeperDive.RIGHT) and dr.saves == 1, "keeper rules: a right dive that saves the right shot: right done")
	var draws := {}
	for i in 60:
		draws[dr.next_zone()] = true
	r.check(not draws.has(KeeperDive.RIGHT) and draws.has(KeeperDive.LEFT) and draws.has(KeeperDive.CENTRE), "keeper rules: never right again, the other two still come")
	# a save with the wrong dive, a dive that's beaten, a shot that misses: nothing counts
	dr.zone = KeeperDive.LEFT
	dr.dived(KeeperDive.RIGHT)
	dr.on_event(f, {"k": "save"})
	dr.on_event(f, {"k": "end", "outcome": "goal"})
	dr.dived(KeeperDive.LEFT)
	dr.on_event(f, {"k": "end", "outcome": "goal"})
	dr.on_event(f, {"k": "end", "outcome": "miss"})
	r.check(dr.needs(KeeperDive.LEFT) and dr.saves == 1, "keeper rules: a wrong-way save, a beaten dive, a miss: left still to do")
	dr._dive = {}   # (a new shot: his_throw clears the last dive)
	dr.on_event(f, {"k": "save"})   # (no dive tapped: not his)
	r.check(dr.needs(KeeperDive.LEFT), "keeper rules: a save you didn't dive for doesn't count")
	dr.dived(KeeperDive.LEFT)
	dr.on_event(f, {"k": "save"})
	var only: Array = []
	for i in 20:
		only.append(dr.next_zone())
	r.check(only.all(func(z): return z == KeeperDive.CENTRE), "keeper rules: one way left: always that one")
	dr.zone = KeeperDive.CENTRE
	dr.dived(KeeperDive.CENTRE)
	dr.on_event(f, {"k": "save"})
	r.check(dr.complete, "keeper rules: all three done: the drill's complete")
	var again := KeeperDrill.new()
	r.check(again.needs(KeeperDive.LEFT) and again.needs(KeeperDive.RIGHT) and again.needs(KeeperDive.CENTRE), "keeper rules: RESTART (a new run): every way to do again")
	# a match's shooters are untouched: they never ask the drill
	r.check(not FileAccess.get_file_as_string("res://src/match/match_flow.gd").contains("KeeperDrill") and not FileAccess.get_file_as_string("res://src/core/opp_sim.gd").contains("by_side"),
		"keeper rules: tutorial-only (the match's AI never reads them)")

## The shooting part's keeper, played out from the spot (no screen): with him cheating across and
## diving for the far corner, a near-side shot goes in, soft or hard; one into the far corner he's
## gone to doesn't. Shading to the near post and diving for it, the far corner's there.
func _near_side() -> void:
	var dr := ShootingDrill.new()
	var f := DrillFlow.new(dr, League.make_team(0), League.make_team(3), 11)
	var rates := {}
	for phase in ["cross", "near"]:
		dr.cross = 0 if phase == "cross" else ShootingDrill.GOALS
		for y in ([8.8] if phase == "cross" else [8.8, 11.0, 11.2]):
			for pw in [0.45, 0.85]:
				var goals := 0
				for n in 30:
					f.start_rep()
					var p := f.play
					for i in 30:
						p.step(1.0 / 60.0)
					p._shoot(y, pw, true)
					var t := 0.0
					while not p.over and p.ball.state == Ball.State.SHOT and t < 3.0:
						p.step(1.0 / 60.0)
						t += 1.0 / 60.0
					if p.over and String(p.result.outcome) == "goal":
						goals += 1
				rates["%s %.1f %.2f" % [phase, y, pw]] = goals / 30.0
	print("  near side: %s" % str(rates))
	for k in rates:
		if k.begins_with("near 8.8"):
			r.check(rates[k] <= 0.3, "shooting keeper: a shot where he's gone is saved (%s: %.2f)" % [k, rates[k]])
		else:
			r.check(rates[k] >= 0.8, "shooting keeper: aimed right, it goes in (%s: %.2f)" % [k, rates[k]])
	var m := MatchFlow.new(League.make_team(0), League.make_team(3), 5, MatchState.QUARTER_MIN)
	m._start_attack(Play.Kind.HALF_COURT)
	r.check(is_nan(m.play.keeper_spot) and m.play.keeper_late == 0.0, "match: the keeper is the match's keeper (no tutorial spot or delay)")

# ------------------------------------------------------------------ restart, back, picking up
func _navigation() -> void:
	# picking up where you left off: the first part not done yet
	Game.settings["tutorials_done"] = ["frontcourt", "counter"]
	var ms = await _open()
	r.check(ms.part == 2 and ms.drill_id == "shooting", "tutorial: picks up at the first part not done (%s)" % ms.drill_id)
	var f0: DrillFlow = ms.flow
	_steps(ms, 1.0)
	r.check(_press_button(ms, "RESTART") and ms.flow != f0 and ms.part == 2 and not ms.drill.complete and ms.popup.is_empty(),
		"tutorial: RESTART starts this part over, not the tutorial")
	r.check((Game.settings.get("tutorials_done", []) as Array).has("counter"), "tutorial: RESTART keeps the parts done")
	ms._start_over()
	_got_it(ms)
	r.check(ms.part == 0 and ms.drill_id == "frontcourt" and (Game.settings.get("tutorials_done", []) as Array).is_empty(),
		"tutorial: START OVER runs it from part 1")
	# opening one part by name never clears what's done
	Game.settings["tutorials_done"] = Drill.ORDER.duplicate()
	ms = await _open({"id": "frontcourt"})
	r.check((Game.settings.get("tutorials_done", []) as Array).size() == Drill.ORDER.size(), "tutorial: opening a part by name keeps the parts done")
	ms._start_part(0, false)
	_press_button(ms, "BACK")
	await r.get_tree().process_frame
	r.check(Game.current_name == "title", "tutorial: BACK goes to the main menu")
	# every part on its own still loads and plays
	for id in Drill.ORDER:
		ms = await _open({"id": id})
		_steps(ms, 1.0)
		r.check(ms.drill_id == id and ms.flow.play != null and not ms.flow.finished, "%s: loads and plays" % id)
	# progress inside a part goes on RESTART
	ms = await _open({"id": "frontcourt"})
	_until(ms, func(): return ms.flow.play.can_throw(), 5.0)
	_tap(ms, _on(ms, _tag(ms.flow.play, "2")))
	_until(ms, func(): return ms.drill.passes == 1, 4.0)
	_press_button(ms, "RESTART")
	r.check(ms.drill.passes == 0 and ms.drill.touched.is_empty(), "frontcourt: RESTART clears the part's progress")
	# all four done: TUTORIAL runs it again from the start
	Game.settings["tutorials_done"] = Drill.ORDER.duplicate()
	ms = await _open()
	r.check(ms.part == 0 and (Game.settings.get("tutorials_done", []) as Array).is_empty(), "tutorial: all done, it starts again from part 1")
	Game.goto("title", {}, false)
	await r.get_tree().process_frame
	# the play in a match is untouched: the keeper's in, defenders and all
	var f := MatchFlow.new(League.make_team(0), League.make_team(3), 5, MatchState.QUARTER_MIN)
	f._start_attack(Play.Kind.HALF_COURT)
	r.check(f.play.keeper_in and f.play.bodies().has(f.play.keeper) and f.play.defenders.size() == 6 and f.play.shot_clock == Play.SHOT_CLOCK,
		"match: a normal possession still has six defenders, the keeper and the shot clock")
